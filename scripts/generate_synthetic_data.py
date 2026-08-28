#!/usr/bin/env python3
"""Generate the deterministic SkillSpring synthetic source dataset.

The generator implements the approved contract in docs/source-data-contract.md.
It uses only Python's standard library so the source data can be reproduced
without installing additional packages.
"""

from __future__ import annotations

import argparse
import calendar
import csv
import hashlib
import json
import random
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable


UTC = timezone.utc
DATA_START = datetime(2025, 1, 1, tzinfo=UTC)
DATA_END = datetime(2026, 6, 30, 23, 59, 59, tzinfo=UTC)
PRICE_CHANGE_DATE = date(2026, 1, 1)
DEFAULT_SEED = 20260827
EXPERIMENT_ID = "onboarding_checklist_v1"
EXPERIMENT_START = datetime(2026, 1, 1, tzinfo=UTC)
EXPERIMENT_END = datetime(2026, 3, 31, 23, 59, 59, tzinfo=UTC)


HEADERS: dict[str, list[str]] = {
    "customers": [
        "customer_id",
        "signup_at",
        "country_code",
        "acquisition_channel",
        "acquisition_campaign",
        "device_type",
        "learning_goal",
    ],
    "plans": [
        "plan_version_id",
        "plan_code",
        "plan_tier",
        "billing_interval",
        "price_minor_units",
        "currency_code",
        "trial_days",
        "valid_from",
        "valid_to",
    ],
    "subscriptions": [
        "subscription_id",
        "customer_id",
        "initial_plan_version_id",
        "current_plan_version_id",
        "created_at",
        "trial_started_at",
        "trial_scheduled_end_at",
        "paid_started_at",
        "current_period_start_at",
        "current_period_end_at",
        "current_status",
        "cancel_requested_at",
        "ended_at",
    ],
    "subscription_events": [
        "subscription_event_id",
        "subscription_id",
        "event_sequence",
        "event_at",
        "event_type",
        "from_status",
        "to_status",
        "from_plan_version_id",
        "to_plan_version_id",
        "event_reason",
    ],
    "invoices": [
        "invoice_id",
        "subscription_id",
        "plan_version_id",
        "billing_reason",
        "billing_period_start",
        "billing_period_end",
        "issued_at",
        "due_at",
        "amount_due_minor_units",
        "currency_code",
        "invoice_status",
        "paid_at",
    ],
    "payment_attempts": [
        "payment_attempt_id",
        "invoice_id",
        "attempt_number",
        "attempted_at",
        "amount_attempted_minor_units",
        "currency_code",
        "payment_status",
        "failure_reason",
    ],
    "refunds": [
        "refund_id",
        "payment_attempt_id",
        "refunded_at",
        "amount_refunded_minor_units",
        "currency_code",
        "refund_reason",
    ],
    "product_events": [
        "product_event_id",
        "customer_id",
        "session_id",
        "occurred_at",
        "event_name",
        "platform",
        "onboarding_step",
        "program_id",
        "lesson_id",
    ],
    "experiment_assignments": [
        "customer_id",
        "experiment_id",
        "variant",
        "assigned_at",
        "first_exposed_at",
    ],
}


PLAN_ROWS: list[dict[str, Any]] = [
    {
        "plan_version_id": "standard_monthly_v1",
        "plan_code": "standard_monthly",
        "plan_tier": "standard",
        "billing_interval": "month",
        "price_minor_units": 1499,
        "currency_code": "EUR",
        "trial_days": 14,
        "valid_from": date(2025, 1, 1),
        "valid_to": date(2025, 12, 31),
    },
    {
        "plan_version_id": "standard_annual_v1",
        "plan_code": "standard_annual",
        "plan_tier": "standard",
        "billing_interval": "year",
        "price_minor_units": 14990,
        "currency_code": "EUR",
        "trial_days": 14,
        "valid_from": date(2025, 1, 1),
        "valid_to": date(2025, 12, 31),
    },
    {
        "plan_version_id": "premium_monthly_v1",
        "plan_code": "premium_monthly",
        "plan_tier": "premium",
        "billing_interval": "month",
        "price_minor_units": 2999,
        "currency_code": "EUR",
        "trial_days": 14,
        "valid_from": date(2025, 1, 1),
        "valid_to": date(2025, 12, 31),
    },
    {
        "plan_version_id": "premium_annual_v1",
        "plan_code": "premium_annual",
        "plan_tier": "premium",
        "billing_interval": "year",
        "price_minor_units": 29990,
        "currency_code": "EUR",
        "trial_days": 14,
        "valid_from": date(2025, 1, 1),
        "valid_to": date(2025, 12, 31),
    },
    {
        "plan_version_id": "standard_monthly_v2",
        "plan_code": "standard_monthly",
        "plan_tier": "standard",
        "billing_interval": "month",
        "price_minor_units": 1599,
        "currency_code": "EUR",
        "trial_days": 14,
        "valid_from": date(2026, 1, 1),
        "valid_to": None,
    },
    {
        "plan_version_id": "standard_annual_v2",
        "plan_code": "standard_annual",
        "plan_tier": "standard",
        "billing_interval": "year",
        "price_minor_units": 15990,
        "currency_code": "EUR",
        "trial_days": 14,
        "valid_from": date(2026, 1, 1),
        "valid_to": None,
    },
    {
        "plan_version_id": "premium_monthly_v2",
        "plan_code": "premium_monthly",
        "plan_tier": "premium",
        "billing_interval": "month",
        "price_minor_units": 3199,
        "currency_code": "EUR",
        "trial_days": 14,
        "valid_from": date(2026, 1, 1),
        "valid_to": None,
    },
    {
        "plan_version_id": "premium_annual_v2",
        "plan_code": "premium_annual",
        "plan_tier": "premium",
        "billing_interval": "year",
        "price_minor_units": 31990,
        "currency_code": "EUR",
        "trial_days": 14,
        "valid_from": date(2026, 1, 1),
        "valid_to": None,
    },
]

PLANS_BY_VERSION = {row["plan_version_id"]: row for row in PLAN_ROWS}


def clamp(value: float, lower: float, upper: float) -> float:
    return max(lower, min(value, upper))


def iso_value(value: Any) -> Any:
    if value is None:
        return ""
    if isinstance(value, datetime):
        return value.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")
    if isinstance(value, date):
        return value.isoformat()
    return value


def add_months(value: datetime, months: int) -> datetime:
    month_index = value.month - 1 + months
    year = value.year + month_index // 12
    month = month_index % 12 + 1
    day = min(value.day, calendar.monthrange(year, month)[1])
    return value.replace(year=year, month=month, day=day)


def random_timestamp(rng: random.Random, start: datetime, end: datetime) -> datetime:
    seconds = max(0, int((end - start).total_seconds()))
    return start + timedelta(seconds=rng.randint(0, seconds))


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


class SkillSpringGenerator:
    def __init__(self, customer_count: int, seed: int, output_dir: Path) -> None:
        self.customer_count = customer_count
        self.seed = seed
        self.output_dir = output_dir
        self.rng = random.Random(seed)
        self.counters: defaultdict[str, int] = defaultdict(int)
        self.customers: list[dict[str, Any]] = []
        self.subscriptions: list[dict[str, Any]] = []
        self.subscription_events: list[dict[str, Any]] = []
        self.invoices: list[dict[str, Any]] = []
        self.payment_attempts: list[dict[str, Any]] = []
        self.refunds: list[dict[str, Any]] = []
        self.assignments: list[dict[str, Any]] = []

    def new_id(self, counter: str, prefix: str, width: int = 8) -> str:
        self.counters[counter] += 1
        return f"{prefix}{self.counters[counter]:0{width}d}"

    def plan_version_for(self, plan_code: str, at: datetime) -> str:
        suffix = "v1" if at.date() < PRICE_CHANGE_DATE else "v2"
        return f"{plan_code}_{suffix}"

    def choose_plan_code(self) -> str:
        tier = self.rng.choices(["standard", "premium"], weights=[65, 35], k=1)[0]
        interval = self.rng.choices(["monthly", "annual"], weights=[70, 30], k=1)[0]
        return f"{tier}_{interval}"

    def add_subscription_event(
        self,
        local_events: list[dict[str, Any]],
        subscription_id: str,
        event_at: datetime,
        event_type: str,
        from_status: str | None,
        to_status: str | None,
        from_plan: str | None,
        to_plan: str | None,
        reason: str | None = None,
    ) -> None:
        if event_at > DATA_END:
            return
        local_events.append(
            {
                "subscription_id": subscription_id,
                "event_at": event_at,
                "event_type": event_type,
                "from_status": from_status,
                "to_status": to_status,
                "from_plan_version_id": from_plan,
                "to_plan_version_id": to_plan,
                "event_reason": reason,
                "_order": len(local_events),
            }
        )

    def finalize_subscription_events(self, local_events: list[dict[str, Any]]) -> None:
        local_events.sort(key=lambda row: (row["event_at"], row["_order"]))
        for sequence, row in enumerate(local_events, start=1):
            row["subscription_event_id"] = self.new_id("subscription_event", "SE")
            row["event_sequence"] = sequence
            row.pop("_order")
            self.subscription_events.append(row)

    def create_payment_attempt(
        self,
        invoice_id: str,
        attempt_number: int,
        attempted_at: datetime,
        amount: int,
        succeeded: bool,
    ) -> dict[str, Any]:
        reason = None
        if not succeeded:
            reason = self.rng.choices(
                [
                    "insufficient_funds",
                    "expired_card",
                    "authentication_required",
                    "card_declined",
                    "processing_error",
                ],
                weights=[38, 12, 20, 22, 8],
                k=1,
            )[0]
        row = {
            "payment_attempt_id": self.new_id("payment_attempt", "PA"),
            "invoice_id": invoice_id,
            "attempt_number": attempt_number,
            "attempted_at": attempted_at,
            "amount_attempted_minor_units": amount,
            "currency_code": "EUR",
            "payment_status": "succeeded" if succeeded else "failed",
            "failure_reason": reason,
        }
        self.payment_attempts.append(row)
        return row

    def create_refunds(self, payment: dict[str, Any], amount: int) -> None:
        if self.rng.random() >= 0.03:
            return
        earliest = payment["attempted_at"] + timedelta(days=2)
        if earliest > DATA_END:
            return
        total = amount if self.rng.random() < 0.60 else max(1, int(amount * self.rng.uniform(0.10, 0.80)))
        parts = [total]
        if total > 2 and self.rng.random() < 0.15:
            first = max(1, int(total * self.rng.uniform(0.20, 0.70)))
            parts = [first, total - first]
        refund_time = earliest + timedelta(days=self.rng.randint(0, 12))
        for part in parts:
            if refund_time > DATA_END:
                break
            self.refunds.append(
                {
                    "refund_id": self.new_id("refund", "R"),
                    "payment_attempt_id": payment["payment_attempt_id"],
                    "refunded_at": refund_time,
                    "amount_refunded_minor_units": part,
                    "currency_code": "EUR",
                    "refund_reason": self.rng.choices(
                        [
                            "customer_request",
                            "billing_error",
                            "duplicate_charge",
                            "service_issue",
                            "fraud_reported",
                        ],
                        weights=[45, 15, 8, 25, 7],
                        k=1,
                    )[0],
                }
            )
            refund_time += timedelta(days=self.rng.randint(1, 4))

    def collect_invoice(
        self,
        subscription_id: str,
        plan_version_id: str,
        billing_reason: str,
        period_start: datetime,
        period_end: datetime,
        local_events: list[dict[str, Any]],
    ) -> tuple[str, datetime | None, datetime, datetime, str]:
        plan = PLANS_BY_VERSION[plan_version_id]
        amount = int(plan["price_minor_units"])
        invoice_id = self.new_id("invoice", "INV")
        issued_at = period_start
        due_at = period_start
        last_attempt_at = issued_at
        successful_payment: dict[str, Any] | None = None

        first_attempt_failed = self.rng.random() < 0.10
        if not first_attempt_failed:
            successful_payment = self.create_payment_attempt(
                invoice_id, 1, issued_at + timedelta(minutes=1), amount, True
            )
            last_attempt_at = successful_payment["attempted_at"]
        else:
            first = self.create_payment_attempt(
                invoice_id, 1, issued_at + timedelta(minutes=1), amount, False
            )
            last_attempt_at = first["attempted_at"]
            self.add_subscription_event(
                local_events,
                subscription_id,
                last_attempt_at,
                "past_due",
                "active",
                "past_due",
                plan_version_id,
                plan_version_id,
                "payment_failure",
            )
            will_recover = self.rng.random() < 0.65
            success_number = self.rng.choices([2, 3], weights=[75, 25], k=1)[0]
            for attempt_number in range(2, 4):
                attempted_at = issued_at + timedelta(days=2 * (attempt_number - 1), minutes=1)
                if attempted_at > DATA_END:
                    break
                succeeds_now = will_recover and attempt_number == success_number
                attempt = self.create_payment_attempt(
                    invoice_id, attempt_number, attempted_at, amount, succeeds_now
                )
                last_attempt_at = attempted_at
                if succeeds_now:
                    successful_payment = attempt
                    self.add_subscription_event(
                        local_events,
                        subscription_id,
                        attempted_at,
                        "payment_recovered",
                        "past_due",
                        "active",
                        plan_version_id,
                        plan_version_id,
                        "successful_retry",
                    )
                    break

        if successful_payment:
            invoice_status = "paid"
            paid_at = successful_payment["attempted_at"]
            self.create_refunds(successful_payment, amount)
        else:
            paid_at = None
            old_enough_to_close = issued_at <= DATA_END - timedelta(days=7)
            invoice_status = "uncollectible" if old_enough_to_close else "open"

        self.invoices.append(
            {
                "invoice_id": invoice_id,
                "subscription_id": subscription_id,
                "plan_version_id": plan_version_id,
                "billing_reason": billing_reason,
                "billing_period_start": period_start.date(),
                "billing_period_end": period_end.date(),
                "issued_at": issued_at,
                "due_at": due_at,
                "amount_due_minor_units": amount,
                "currency_code": "EUR",
                "invoice_status": invoice_status,
                "paid_at": paid_at,
            }
        )
        return invoice_status, paid_at, period_start, period_end, plan_version_id

    def conversion_probability(self, customer: dict[str, Any], treatment: bool) -> float:
        channel_adjustment = {
            "organic_search": 0.04,
            "paid_search": -0.01,
            "paid_social": -0.05,
            "referral": 0.08,
            "affiliate": -0.02,
            "direct": 0.01,
        }[customer["acquisition_channel"]]
        probability = (
            0.55
            + channel_adjustment
            + (customer["_engagement"] - 0.5) * 0.25
            + (0.04 if treatment else 0.0)
        )
        return clamp(probability, 0.20, 0.85)

    def create_subscription(
        self,
        customer: dict[str, Any],
        created_at: datetime,
        is_reactivation: bool,
    ) -> dict[str, Any]:
        subscription_id = self.new_id("subscription", "S")
        plan_code = self.choose_plan_code()
        initial_plan_version = self.plan_version_for(plan_code, created_at)
        current_plan_version = initial_plan_version
        trial_end = created_at + timedelta(days=14)
        local_events: list[dict[str, Any]] = []
        self.add_subscription_event(
            local_events,
            subscription_id,
            created_at,
            "trial_started",
            None,
            "trialing",
            None,
            initial_plan_version,
            "reactivation_trial" if is_reactivation else "new_trial",
        )

        sub: dict[str, Any] = {
            "subscription_id": subscription_id,
            "customer_id": customer["customer_id"],
            "initial_plan_version_id": initial_plan_version,
            "current_plan_version_id": current_plan_version,
            "created_at": created_at,
            "trial_started_at": created_at,
            "trial_scheduled_end_at": trial_end,
            "paid_started_at": None,
            "current_period_start_at": None,
            "current_period_end_at": None,
            "current_status": "trialing",
            "cancel_requested_at": None,
            "ended_at": None,
            "_is_initial": not is_reactivation,
            "_engagement": customer["_engagement"],
            "_platform": customer["device_type"],
        }

        if trial_end > DATA_END:
            sub["_access_end"] = DATA_END
            self.finalize_subscription_events(local_events)
            self.subscriptions.append(sub)
            return sub

        treatment = customer.get("_variant") == "treatment" and not is_reactivation
        converts = self.rng.random() < self.conversion_probability(customer, treatment)
        if not converts:
            sub["current_status"] = "canceled"
            sub["ended_at"] = trial_end
            sub["_access_end"] = trial_end
            self.add_subscription_event(
                local_events,
                subscription_id,
                trial_end,
                "canceled",
                "trialing",
                "canceled",
                initial_plan_version,
                initial_plan_version,
                "trial_not_converted",
            )
            self.finalize_subscription_events(local_events)
            self.subscriptions.append(sub)
            return sub

        sub["paid_started_at"] = trial_end
        sub["current_status"] = "active"
        self.add_subscription_event(
            local_events,
            subscription_id,
            trial_end,
            "trial_converted",
            "trialing",
            "active",
            initial_plan_version,
            initial_plan_version,
            "reactivation" if is_reactivation else "first_activation",
        )

        period_start = trial_end
        period_index = 0
        plan_changed = False
        ended = False
        while period_start <= DATA_END and not ended:
            current_plan = PLANS_BY_VERSION[current_plan_version]
            billing_months = 1 if current_plan["billing_interval"] == "month" else 12
            period_end = add_months(period_start, billing_months)
            billing_reason = "initial_subscription" if period_index == 0 else "subscription_cycle"

            if period_index >= 2 and not plan_changed and self.rng.random() < 0.05:
                new_tier = "premium" if current_plan["plan_tier"] == "standard" else "standard"
                interval_code = "monthly" if current_plan["billing_interval"] == "month" else "annual"
                new_code = f"{new_tier}_{interval_code}"
                new_version = self.plan_version_for(new_code, period_start)
                self.add_subscription_event(
                    local_events,
                    subscription_id,
                    period_start,
                    "plan_changed",
                    "active",
                    "active",
                    current_plan_version,
                    new_version,
                    "customer_plan_change",
                )
                current_plan_version = new_version
                current_plan = PLANS_BY_VERSION[current_plan_version]
                billing_reason = "plan_change"
                plan_changed = True

            invoice_status, paid_at, _, _, _ = self.collect_invoice(
                subscription_id,
                current_plan_version,
                billing_reason,
                period_start,
                period_end,
                local_events,
            )
            sub["current_period_start_at"] = period_start
            sub["current_period_end_at"] = period_end

            if invoice_status in {"open", "uncollectible"}:
                if invoice_status == "open":
                    sub["current_status"] = "past_due"
                else:
                    cancel_at = min(DATA_END, period_start + timedelta(days=7))
                    sub["current_status"] = "canceled"
                    sub["ended_at"] = cancel_at
                    sub["current_period_start_at"] = None
                    sub["current_period_end_at"] = None
                    self.add_subscription_event(
                        local_events,
                        subscription_id,
                        cancel_at,
                        "canceled",
                        "past_due",
                        "canceled",
                        current_plan_version,
                        current_plan_version,
                        "payment_failure",
                    )
                ended = True
                break

            churn_probability = (
                0.035 if current_plan["billing_interval"] == "month" else 0.12
            ) + (0.5 - customer["_engagement"]) * 0.03
            if period_end <= DATA_END and self.rng.random() < clamp(churn_probability, 0.01, 0.18):
                requested_at = max(period_start, period_end - timedelta(days=5))
                sub["cancel_requested_at"] = requested_at
                self.add_subscription_event(
                    local_events,
                    subscription_id,
                    requested_at,
                    "cancel_requested",
                    "active",
                    "active",
                    current_plan_version,
                    current_plan_version,
                    "customer_request",
                )
                if self.rng.random() < 0.10:
                    revoked_at = min(period_end - timedelta(minutes=1), requested_at + timedelta(days=2))
                    self.add_subscription_event(
                        local_events,
                        subscription_id,
                        revoked_at,
                        "cancellation_revoked",
                        "active",
                        "active",
                        current_plan_version,
                        current_plan_version,
                        "customer_retained",
                    )
                    sub["cancel_requested_at"] = None
                else:
                    sub["current_status"] = "canceled"
                    sub["ended_at"] = period_end
                    sub["current_period_start_at"] = None
                    sub["current_period_end_at"] = None
                    self.add_subscription_event(
                        local_events,
                        subscription_id,
                        period_end,
                        "canceled",
                        "active",
                        "canceled",
                        current_plan_version,
                        current_plan_version,
                        "customer_request",
                    )
                    ended = True
                    break

            period_start = period_end
            period_index += 1

        sub["current_plan_version_id"] = current_plan_version
        sub["_access_end"] = sub["ended_at"] or DATA_END
        self.finalize_subscription_events(local_events)
        self.subscriptions.append(sub)
        return sub

    def generate_customers_and_commercial_data(self) -> None:
        channels = [
            "organic_search",
            "paid_search",
            "paid_social",
            "referral",
            "affiliate",
            "direct",
        ]
        for index in range(1, self.customer_count + 1):
            signup_at = random_timestamp(self.rng, DATA_START, DATA_END)
            channel = self.rng.choices(channels, weights=[24, 22, 18, 14, 10, 12], k=1)[0]
            customer = {
                "customer_id": f"C{index:06d}",
                "signup_at": signup_at,
                "country_code": self.rng.choices(
                    ["FI", "DE", "FR", "ES", "NL", "SE", "IT", "IE"],
                    weights=[13, 22, 14, 12, 10, 10, 12, 7],
                    k=1,
                )[0],
                "acquisition_channel": channel,
                "acquisition_campaign": (
                    f"{channel}_campaign_{self.rng.randint(1, 5)}"
                    if channel in {"paid_search", "paid_social", "affiliate"}
                    else None
                ),
                "device_type": self.rng.choices(
                    ["ios", "android", "web"], weights=[36, 39, 25], k=1
                )[0],
                "learning_goal": self.rng.choices(
                    ["career", "language", "academic", "personal"],
                    weights=[35, 28, 20, 17],
                    k=1,
                )[0],
                "_engagement": self.rng.betavariate(2.2, 2.2),
            }

            assignment: dict[str, Any] | None = None
            if EXPERIMENT_START <= signup_at <= EXPERIMENT_END:
                variant = self.rng.choice(["control", "treatment"])
                customer["_variant"] = variant
                assignment = {
                    "customer_id": customer["customer_id"],
                    "experiment_id": EXPERIMENT_ID,
                    "variant": variant,
                    "assigned_at": signup_at,
                    "first_exposed_at": None,
                }
                customer["_assignment"] = assignment
                self.assignments.append(assignment)

            self.customers.append(customer)
            trial_probability = 0.90 + (0.01 if customer.get("_variant") == "treatment" else 0.0)
            if self.rng.random() >= trial_probability:
                continue

            created_at = min(
                DATA_END,
                signup_at + timedelta(hours=self.rng.randint(0, 48), minutes=self.rng.randint(0, 59)),
            )
            if assignment and self.rng.random() < 0.93:
                assignment["first_exposed_at"] = min(DATA_END, created_at + timedelta(minutes=1))

            initial = self.create_subscription(customer, created_at, is_reactivation=False)
            if (
                initial["ended_at"]
                and initial["ended_at"] + timedelta(days=44) <= DATA_END
                and self.rng.random() < 0.08
            ):
                return_at = initial["ended_at"] + timedelta(days=self.rng.randint(30, 120))
                if return_at + timedelta(days=14) <= DATA_END:
                    self.create_subscription(customer, return_at, is_reactivation=True)

    def write_csv(self, table: str, rows: Iterable[dict[str, Any]]) -> int:
        path = self.output_dir / f"{table}.csv"
        count = 0
        with path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=HEADERS[table], extrasaction="ignore")
            writer.writeheader()
            for row in rows:
                writer.writerow({column: iso_value(row.get(column)) for column in HEADERS[table]})
                count += 1
        return count

    def write_product_events(self) -> int:
        path = self.output_dir / "product_events.csv"
        event_count = 0
        session_counter = 0

        with path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=HEADERS["product_events"])
            writer.writeheader()

            def emit(
                customer_id: str,
                session_id: str,
                occurred_at: datetime,
                event_name: str,
                platform: str,
                onboarding_step: str | None = None,
                program_id: str | None = None,
                lesson_id: str | None = None,
            ) -> None:
                nonlocal event_count
                if occurred_at > DATA_END:
                    return
                event_count += 1
                row = {
                    "product_event_id": f"PE{event_count:09d}",
                    "customer_id": customer_id,
                    "session_id": session_id,
                    "occurred_at": occurred_at,
                    "event_name": event_name,
                    "platform": platform,
                    "onboarding_step": onboarding_step,
                    "program_id": program_id,
                    "lesson_id": lesson_id,
                }
                writer.writerow({column: iso_value(row[column]) for column in HEADERS["product_events"]})

            for sub in self.subscriptions:
                customer_id = sub["customer_id"]
                platform = sub["_platform"]
                engagement = sub["_engagement"]

                if sub["_is_initial"]:
                    session_counter += 1
                    session_id = f"SES{session_counter:09d}"
                    event_time = sub["created_at"] + timedelta(minutes=1)
                    emit(customer_id, session_id, event_time, "session_started", platform)
                    emit(customer_id, session_id, event_time + timedelta(seconds=10), "onboarding_started", platform)
                    steps = [
                        "goal_selected",
                        "experience_selected",
                        "learning_schedule_set",
                        "first_program_selected",
                    ]
                    completed_all = True
                    treatment_boost = 0.05 if self.customer_variant(customer_id) == "treatment" else 0.0
                    for step_index, step in enumerate(steps):
                        completion_probability = clamp(
                            0.78 + engagement * 0.18 + treatment_boost - step_index * 0.05,
                            0.45,
                            0.98,
                        )
                        if self.rng.random() > completion_probability:
                            completed_all = False
                            break
                        event_time += timedelta(minutes=self.rng.randint(1, 3))
                        emit(
                            customer_id,
                            session_id,
                            event_time,
                            "onboarding_step_completed",
                            platform,
                            onboarding_step=step,
                        )
                    if completed_all:
                        event_time += timedelta(minutes=1)
                        emit(customer_id, session_id, event_time, "onboarding_completed", platform)
                        program_id = f"PRG{self.rng.randint(1, 20):03d}"
                        emit(
                            customer_id,
                            session_id,
                            event_time + timedelta(minutes=1),
                            "program_viewed",
                            platform,
                            program_id=program_id,
                        )
                        if self.rng.random() < 0.80:
                            emit(
                                customer_id,
                                session_id,
                                event_time + timedelta(minutes=2),
                                "program_started",
                                platform,
                                program_id=program_id,
                            )

                if not sub["paid_started_at"]:
                    continue
                access_end = min(DATA_END, sub["_access_end"])
                week_start = sub["paid_started_at"]
                while week_start <= access_end:
                    week_end = min(access_end, week_start + timedelta(days=6, hours=23))
                    session_count = sum(
                        self.rng.random() < probability
                        for probability in (
                            clamp(engagement * 0.65, 0.04, 0.75),
                            clamp(engagement * 0.45, 0.02, 0.55),
                            clamp(engagement * 0.25, 0.01, 0.35),
                        )
                    )
                    for _ in range(session_count):
                        latest_session_start = week_end - timedelta(minutes=40)
                        if latest_session_start < week_start:
                            continue
                        session_counter += 1
                        session_id = f"SES{session_counter:09d}"
                        session_at = random_timestamp(self.rng, week_start, latest_session_start)
                        program_id = f"PRG{self.rng.randint(1, 20):03d}"
                        lesson_id = f"LES{self.rng.randint(1, 12):03d}"
                        emit(customer_id, session_id, session_at, "session_started", platform)
                        if self.rng.random() < 0.25:
                            emit(
                                customer_id,
                                session_id,
                                session_at + timedelta(minutes=1),
                                "program_viewed",
                                platform,
                                program_id=program_id,
                            )
                        if self.rng.random() < 0.10:
                            emit(
                                customer_id,
                                session_id,
                                session_at + timedelta(minutes=2),
                                "program_started",
                                platform,
                                program_id=program_id,
                            )
                        emit(
                            customer_id,
                            session_id,
                            session_at + timedelta(minutes=3),
                            "lesson_started",
                            platform,
                            program_id=program_id,
                            lesson_id=lesson_id,
                        )
                        if self.rng.random() < clamp(0.72 + engagement * 0.24, 0.72, 0.96):
                            emit(
                                customer_id,
                                session_id,
                                session_at + timedelta(minutes=self.rng.randint(12, 35)),
                                "lesson_completed",
                                platform,
                                program_id=program_id,
                                lesson_id=lesson_id,
                            )
                    week_start += timedelta(days=7)
        return event_count

    def customer_variant(self, customer_id: str) -> str | None:
        customer_number = int(customer_id[1:]) - 1
        return self.customers[customer_number].get("_variant")

    def validate_in_memory(self) -> list[str]:
        checks: list[str] = []
        customer_ids = {row["customer_id"] for row in self.customers}
        plan_ids = set(PLANS_BY_VERSION)
        subscription_ids = {row["subscription_id"] for row in self.subscriptions}
        invoice_ids = {row["invoice_id"] for row in self.invoices}
        attempt_ids = {row["payment_attempt_id"] for row in self.payment_attempts}

        assert len(customer_ids) == len(self.customers)
        assert len(subscription_ids) == len(self.subscriptions)
        assert len(invoice_ids) == len(self.invoices)
        assert len(attempt_ids) == len(self.payment_attempts)
        checks.append("primary identifiers are unique")

        assert all(row["customer_id"] in customer_ids for row in self.subscriptions)
        assert all(row["initial_plan_version_id"] in plan_ids for row in self.subscriptions)
        assert all(row["current_plan_version_id"] in plan_ids for row in self.subscriptions)
        assert all(row["subscription_id"] in subscription_ids for row in self.subscription_events)
        assert all(row["subscription_id"] in subscription_ids for row in self.invoices)
        assert all(row["invoice_id"] in invoice_ids for row in self.payment_attempts)
        assert all(row["payment_attempt_id"] in attempt_ids for row in self.refunds)
        assert all(row["customer_id"] in customer_ids for row in self.assignments)
        checks.append("all generated foreign keys resolve")

        attempts_by_invoice: defaultdict[str, list[dict[str, Any]]] = defaultdict(list)
        for attempt in self.payment_attempts:
            attempts_by_invoice[attempt["invoice_id"]].append(attempt)
        for invoice in self.invoices:
            attempts = sorted(
                attempts_by_invoice[invoice["invoice_id"]], key=lambda row: row["attempt_number"]
            )
            assert [row["attempt_number"] for row in attempts] == list(range(1, len(attempts) + 1))
            successes = [row for row in attempts if row["payment_status"] == "succeeded"]
            assert len(successes) <= 1
            if invoice["invoice_status"] == "paid":
                assert len(successes) == 1
                assert invoice["paid_at"] == successes[0]["attempted_at"]
            else:
                assert not successes
        checks.append("payment attempts reconcile to invoice status")

        attempts_by_id = {row["payment_attempt_id"]: row for row in self.payment_attempts}
        refunded: defaultdict[str, int] = defaultdict(int)
        for refund in self.refunds:
            payment = attempts_by_id[refund["payment_attempt_id"]]
            assert payment["payment_status"] == "succeeded"
            assert refund["refunded_at"] >= payment["attempted_at"]
            refunded[refund["payment_attempt_id"]] += refund["amount_refunded_minor_units"]
        for payment_id, amount in refunded.items():
            assert amount <= attempts_by_id[payment_id]["amount_attempted_minor_units"]
        checks.append("refunds reconcile to successful collected amounts")

        assignment_keys = {(row["customer_id"], row["experiment_id"]) for row in self.assignments}
        assert len(assignment_keys) == len(self.assignments)
        assert all(
            row["first_exposed_at"] is None or row["first_exposed_at"] >= row["assigned_at"]
            for row in self.assignments
        )
        checks.append("experiment assignments are unique and chronologically valid")

        return checks

    def prepare_output(self, overwrite: bool) -> None:
        self.output_dir.mkdir(parents=True, exist_ok=True)
        expected = [self.output_dir / f"{table}.csv" for table in HEADERS]
        expected.append(self.output_dir / "manifest.json")
        existing = [path for path in expected if path.exists()]
        if existing and not overwrite:
            names = ", ".join(path.name for path in existing[:3])
            raise SystemExit(
                f"Output already exists ({names}). Use --overwrite to replace only generated artifacts."
            )
        if overwrite:
            for path in existing:
                path.unlink()

    def run(self, overwrite: bool) -> dict[str, Any]:
        self.prepare_output(overwrite)
        self.generate_customers_and_commercial_data()
        checks = self.validate_in_memory()

        counts = {
            "customers": self.write_csv("customers", self.customers),
            "plans": self.write_csv("plans", PLAN_ROWS),
            "subscriptions": self.write_csv("subscriptions", self.subscriptions),
            "subscription_events": self.write_csv(
                "subscription_events", self.subscription_events
            ),
            "invoices": self.write_csv("invoices", self.invoices),
            "payment_attempts": self.write_csv(
                "payment_attempts", self.payment_attempts
            ),
            "refunds": self.write_csv("refunds", self.refunds),
            "experiment_assignments": self.write_csv(
                "experiment_assignments", self.assignments
            ),
        }
        counts["product_events"] = self.write_product_events()

        files = {
            table: {
                "file": f"{table}.csv",
                "rows": counts[table],
                "sha256": sha256_file(self.output_dir / f"{table}.csv"),
            }
            for table in HEADERS
        }
        manifest = {
            "contract": "docs/source-data-contract.md",
            "seed": self.seed,
            "requested_customer_rows": self.customer_count,
            "activity_start": DATA_START.date().isoformat(),
            "reporting_cutoff": DATA_END.date().isoformat(),
            "currency_code": "EUR",
            "validation_checks": checks,
            "files": files,
            "total_rows": sum(counts.values()),
        }
        with (self.output_dir / "manifest.json").open("w", encoding="utf-8") as handle:
            json.dump(manifest, handle, indent=2, sort_keys=True)
            handle.write("\n")
        return manifest


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--customers", type=int, default=50_000)
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("data/generated/full"),
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Replace only the known generated CSV and manifest files in the output directory.",
    )
    args = parser.parse_args()
    if args.customers <= 0:
        parser.error("--customers must be a positive integer")
    return args


def main() -> None:
    args = parse_args()
    generator = SkillSpringGenerator(args.customers, args.seed, args.output_dir)
    manifest = generator.run(args.overwrite)
    print(json.dumps({"status": "ok", "manifest": manifest}, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
