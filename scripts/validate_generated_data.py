#!/usr/bin/env python3
"""Validate generated SkillSpring CSVs independently of the generator."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


UTC = timezone.utc
REPORTING_CUTOFF = datetime(2026, 6, 30, 23, 59, 59, tzinfo=UTC)
TABLES = [
    "customers",
    "plans",
    "subscriptions",
    "subscription_events",
    "invoices",
    "payment_attempts",
    "refunds",
    "product_events",
    "experiment_assignments",
]


def parse_timestamp(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


class Validator:
    def __init__(self, data_dir: Path, schema_dir: Path) -> None:
        self.data_dir = data_dir
        self.schema_dir = schema_dir
        self.error_count = 0
        self.error_examples: list[str] = []
        self.counts: dict[str, int] = {}
        self.checks: list[str] = []

    def error(self, message: str) -> None:
        self.error_count += 1
        if len(self.error_examples) < 30:
            self.error_examples.append(message)

    def rows(self, table: str):
        path = self.data_dir / f"{table}.csv"
        with path.open("r", encoding="utf-8", newline="") as handle:
            reader = csv.DictReader(handle)
            schema = json.loads((self.schema_dir / f"{table}.json").read_text(encoding="utf-8"))
            expected = [field["name"] for field in schema]
            if reader.fieldnames != expected:
                self.error(f"{table}: CSV header does not match explicit schema")
            count = 0
            for count, row in enumerate(reader, start=1):
                yield row
            self.counts[table] = count

    def validate(self) -> dict[str, Any]:
        manifest_path = self.data_dir / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        for table in TABLES:
            if table not in manifest["files"]:
                self.error(f"manifest: missing {table}")
                continue
            actual = sha256_file(self.data_dir / f"{table}.csv")
            if actual != manifest["files"][table]["sha256"]:
                self.error(f"{table}: SHA-256 does not match manifest")
        self.checks.append("manifest contains every table and file checksums match")

        customer_signup: dict[str, datetime] = {}
        for row in self.rows("customers"):
            customer_id = row["customer_id"]
            if customer_id in customer_signup:
                self.error(f"customers: duplicate {customer_id}")
            signup_at = parse_timestamp(row["signup_at"])
            customer_signup[customer_id] = signup_at
            if row["acquisition_channel"] not in {
                "organic_search",
                "paid_search",
                "paid_social",
                "referral",
                "affiliate",
                "direct",
            }:
                self.error(f"customers: invalid channel for {customer_id}")
        self.checks.append("customer keys, timestamps, and controlled channels are valid")

        plan_ids: set[str] = set()
        plan_amount: dict[str, int] = {}
        for row in self.rows("plans"):
            plan_id = row["plan_version_id"]
            if plan_id in plan_ids:
                self.error(f"plans: duplicate {plan_id}")
            plan_ids.add(plan_id)
            plan_amount[plan_id] = int(row["price_minor_units"])
            if int(row["price_minor_units"]) <= 0 or row["currency_code"] != "EUR":
                self.error(f"plans: invalid amount/currency for {plan_id}")
        self.checks.append("plan keys and canonical EUR prices are valid")

        subscriptions: dict[str, dict[str, Any]] = {}
        access_by_customer: defaultdict[str, list[tuple[datetime, datetime]]] = defaultdict(list)
        for row in self.rows("subscriptions"):
            subscription_id = row["subscription_id"]
            if subscription_id in subscriptions:
                self.error(f"subscriptions: duplicate {subscription_id}")
            if row["customer_id"] not in customer_signup:
                self.error(f"subscriptions: missing customer for {subscription_id}")
            if row["initial_plan_version_id"] not in plan_ids or row["current_plan_version_id"] not in plan_ids:
                self.error(f"subscriptions: missing plan for {subscription_id}")
            created_at = parse_timestamp(row["created_at"])
            ended_at = parse_timestamp(row["ended_at"]) if row["ended_at"] else REPORTING_CUTOFF
            if created_at < customer_signup.get(row["customer_id"], created_at):
                self.error(f"subscriptions: created before signup for {subscription_id}")
            if ended_at < created_at:
                self.error(f"subscriptions: ended before creation for {subscription_id}")
            subscriptions[subscription_id] = row
            access_by_customer[row["customer_id"]].append((created_at, ended_at))
        self.checks.append("subscription keys, parent relationships, and access dates are valid")

        last_event: dict[str, tuple[int, datetime, dict[str, str]]] = {}
        event_ids: set[str] = set()
        for row in self.rows("subscription_events"):
            event_id = row["subscription_event_id"]
            subscription_id = row["subscription_id"]
            if event_id in event_ids:
                self.error(f"subscription_events: duplicate {event_id}")
            event_ids.add(event_id)
            if subscription_id not in subscriptions:
                self.error(f"subscription_events: missing subscription for {event_id}")
                continue
            sequence = int(row["event_sequence"])
            event_at = parse_timestamp(row["event_at"])
            previous = last_event.get(subscription_id)
            if previous and (sequence != previous[0] + 1 or event_at < previous[1]):
                self.error(f"subscription_events: invalid order for {event_id}")
            if not previous and sequence != 1:
                self.error(f"subscription_events: first sequence is not 1 for {subscription_id}")
            last_event[subscription_id] = (sequence, event_at, row)
        for subscription_id, snapshot in subscriptions.items():
            if subscription_id not in last_event:
                self.error(f"subscription_events: no events for {subscription_id}")
                continue
            final = last_event[subscription_id][2]
            if final["to_status"] and final["to_status"] != snapshot["current_status"]:
                self.error(f"subscription_events: status mismatch for {subscription_id}")
            if final["to_plan_version_id"] and final["to_plan_version_id"] != snapshot["current_plan_version_id"]:
                self.error(f"subscription_events: plan mismatch for {subscription_id}")
        self.checks.append("subscription event sequences reconcile to current snapshots")

        invoices: dict[str, dict[str, Any]] = {}
        for row in self.rows("invoices"):
            invoice_id = row["invoice_id"]
            if invoice_id in invoices:
                self.error(f"invoices: duplicate {invoice_id}")
            if row["subscription_id"] not in subscriptions:
                self.error(f"invoices: missing subscription for {invoice_id}")
            if row["plan_version_id"] not in plan_ids:
                self.error(f"invoices: missing plan for {invoice_id}")
            if int(row["amount_due_minor_units"]) != plan_amount.get(row["plan_version_id"]):
                self.error(f"invoices: amount differs from plan for {invoice_id}")
            invoices[invoice_id] = row
        self.checks.append("invoice keys, relationships, and exact plan amounts are valid")

        attempts: dict[str, dict[str, Any]] = {}
        attempts_by_invoice: defaultdict[str, list[dict[str, str]]] = defaultdict(list)
        for row in self.rows("payment_attempts"):
            attempt_id = row["payment_attempt_id"]
            if attempt_id in attempts:
                self.error(f"payment_attempts: duplicate {attempt_id}")
            if row["invoice_id"] not in invoices:
                self.error(f"payment_attempts: missing invoice for {attempt_id}")
            if row["payment_status"] == "failed" and not row["failure_reason"]:
                self.error(f"payment_attempts: missing failure reason for {attempt_id}")
            if row["payment_status"] == "succeeded" and row["failure_reason"]:
                self.error(f"payment_attempts: success has failure reason for {attempt_id}")
            attempts[attempt_id] = row
            attempts_by_invoice[row["invoice_id"]].append(row)
        for invoice_id, invoice in invoices.items():
            rows = sorted(attempts_by_invoice[invoice_id], key=lambda item: int(item["attempt_number"]))
            numbers = [int(item["attempt_number"]) for item in rows]
            if numbers != list(range(1, len(rows) + 1)):
                self.error(f"payment_attempts: sequence gap for {invoice_id}")
            successes = [item for item in rows if item["payment_status"] == "succeeded"]
            if invoice["invoice_status"] == "paid" and len(successes) != 1:
                self.error(f"payment_attempts: paid invoice mismatch for {invoice_id}")
            if invoice["invoice_status"] != "paid" and successes:
                self.error(f"payment_attempts: unpaid invoice has success for {invoice_id}")
        self.checks.append("attempt sequences and outcomes reconcile to invoice status")

        refunded: defaultdict[str, int] = defaultdict(int)
        refund_ids: set[str] = set()
        for row in self.rows("refunds"):
            refund_id = row["refund_id"]
            payment_id = row["payment_attempt_id"]
            if refund_id in refund_ids:
                self.error(f"refunds: duplicate {refund_id}")
            refund_ids.add(refund_id)
            if payment_id not in attempts or attempts[payment_id]["payment_status"] != "succeeded":
                self.error(f"refunds: invalid payment for {refund_id}")
                continue
            refunded[payment_id] += int(row["amount_refunded_minor_units"])
        for payment_id, amount in refunded.items():
            if amount > int(attempts[payment_id]["amount_attempted_minor_units"]):
                self.error(f"refunds: cumulative amount exceeds payment {payment_id}")
        self.checks.append("refunds link to successful attempts without exceeding collection")

        session_owner: dict[str, str] = {}
        event_ids = set()
        valid_events = {
            "session_started",
            "onboarding_started",
            "onboarding_step_completed",
            "onboarding_completed",
            "program_viewed",
            "program_started",
            "lesson_started",
            "lesson_completed",
        }
        for row in self.rows("product_events"):
            event_id = row["product_event_id"]
            customer_id = row["customer_id"]
            if event_id in event_ids:
                self.error(f"product_events: duplicate {event_id}")
            event_ids.add(event_id)
            if customer_id not in customer_signup:
                self.error(f"product_events: missing customer for {event_id}")
                continue
            occurred_at = parse_timestamp(row["occurred_at"])
            if occurred_at < customer_signup[customer_id] or occurred_at > REPORTING_CUTOFF:
                self.error(f"product_events: timestamp outside customer/cutoff range for {event_id}")
            if not any(start <= occurred_at <= end for start, end in access_by_customer[customer_id]):
                self.error(f"product_events: event outside access period for {event_id}")
            owner = session_owner.setdefault(row["session_id"], customer_id)
            if owner != customer_id:
                self.error(f"product_events: session shared by customers {row['session_id']}")
            if row["event_name"] not in valid_events:
                self.error(f"product_events: invalid event name for {event_id}")
            if row["event_name"] == "onboarding_step_completed" and not row["onboarding_step"]:
                self.error(f"product_events: missing onboarding step for {event_id}")
            if row["event_name"] in {"program_viewed", "program_started"} and not row["program_id"]:
                self.error(f"product_events: missing program for {event_id}")
            if row["event_name"] in {"lesson_started", "lesson_completed"} and (
                not row["program_id"] or not row["lesson_id"]
            ):
                self.error(f"product_events: missing lesson context for {event_id}")
        self.checks.append("product events have valid customers, sessions, access periods, and context")

        assignment_keys: set[tuple[str, str]] = set()
        for row in self.rows("experiment_assignments"):
            key = (row["customer_id"], row["experiment_id"])
            if key in assignment_keys:
                self.error(f"experiment_assignments: duplicate {key}")
            assignment_keys.add(key)
            if row["customer_id"] not in customer_signup:
                self.error(f"experiment_assignments: missing customer {key}")
            assigned_at = parse_timestamp(row["assigned_at"])
            if assigned_at < customer_signup.get(row["customer_id"], assigned_at):
                self.error(f"experiment_assignments: assignment before signup {key}")
            if row["first_exposed_at"] and parse_timestamp(row["first_exposed_at"]) < assigned_at:
                self.error(f"experiment_assignments: exposure before assignment {key}")
        self.checks.append("experiment keys, variants, assignment, and exposure timing are valid")

        for table in TABLES:
            expected_count = manifest["files"][table]["rows"]
            if self.counts.get(table) != expected_count:
                self.error(f"{table}: row count differs from manifest")
        self.checks.append("CSV row counts match the manifest")

        return {
            "status": "passed" if self.error_count == 0 else "failed",
            "error_count": self.error_count,
            "error_examples": self.error_examples,
            "checks": self.checks,
            "row_counts": self.counts,
            "total_rows": sum(self.counts.values()),
        }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", type=Path, required=True)
    parser.add_argument("--schema-dir", type=Path, default=Path("data/schemas"))
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    result = Validator(args.data_dir, args.schema_dir).validate()
    print(json.dumps(result, indent=2, sort_keys=True))
    if result["status"] != "passed":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
