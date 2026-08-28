# SkillSpring Source-Data Contract

Status: Approved — all table schemas, scale assumptions, and cross-table generation rules approved 2026-08-27

## Purpose

Define what every raw table and column represents before synthetic data is generated or dbt models are written. This prevents downstream SQL, metrics, and dashboards from silently using conflicting meanings.

## Contract rules

- Raw data contains no real personal information.
- Every table has an explicit grain: exactly what one row represents.
- Every row can be identified by a documented primary key.
- Relationships use documented foreign keys.
- Raw timestamps use UTC; reporting dates can be derived later in dbt.
- Raw categorical values use controlled lists so invalid values can be tested.
- Derived business groupings belong in dbt rather than being duplicated in raw data when practical.
- Raw monetary values use integer minor units with an explicit currency code. dbt converts them into exact decimal major units for analysis and presentation.

## Approved entity inventory

| Raw table | Grain | Primary key | Contract status |
|---|---|---|---|
| `customers` | One row per customer | `customer_id` | Approved 2026-08-27 |
| `plans` | One row per plan version | `plan_version_id` | Approved 2026-08-27 |
| `subscriptions` | One row per subscription | `subscription_id` | Approved 2026-08-27 |
| `subscription_events` | One row per subscription state or plan change | `subscription_event_id` | Approved 2026-08-27 |
| `invoices` | One row per amount billed to a subscription | `invoice_id` | Approved 2026-08-27 |
| `payment_attempts` | One row per collection attempt against an invoice | `payment_attempt_id` | Approved 2026-08-27 |
| `refunds` | One row per refund | `refund_id` | Approved 2026-08-27 |
| `product_events` | One row per customer event | `product_event_id` | Approved 2026-08-27 |
| `experiment_assignments` | One row per customer per experiment | `customer_id` + `experiment_id` | Approved 2026-08-27 |

## Table 1: `customers`

Grain: one row per customer.

| Column | BigQuery type | Required? | Meaning |
|---|---|---:|---|
| `customer_id` | `STRING` | Yes | Synthetic unique customer identifier and primary key |
| `signup_at` | `TIMESTAMP` | Yes | UTC timestamp when the account was created |
| `country_code` | `STRING` | Yes | Synthetic two-letter country code used to derive reporting region in dbt |
| `acquisition_channel` | `STRING` | Yes | Channel credited with acquiring the signup |
| `acquisition_campaign` | `STRING` | No | Synthetic campaign identifier; null for traffic without a campaign |
| `device_type` | `STRING` | Yes | Device used at signup |
| `learning_goal` | `STRING` | Yes | Customer segment based on the main reason for using SkillSpring |

### Proposed generation rules

- `customer_id` is unique and never null.
- `signup_at` falls between 2025-01-01 and 2026-06-30.
- `acquisition_channel` is one of `organic_search`, `paid_search`, `paid_social`, `referral`, `affiliate`, or `direct`.
- `device_type` is one of `ios`, `android`, or `web`.
- `learning_goal` is one of `career`, `language`, `academic`, or `personal`.
- No name, email address, phone number, or other personally identifiable field is generated.
- Reporting `region` is derived from `country_code` in dbt so the mapping is governed in one place.

### Planned validation

- Unique and not-null test on `customer_id`.
- Not-null tests on required fields.
- Accepted-value tests on acquisition channel, device type, and learning goal.
- Business-rule test that `signup_at` falls inside the documented activity window.

Approved by Faisal on 2026-08-27, including the decision to derive reporting region from raw `country_code` in dbt.

## Monetary representation

Approved working design: raw monetary amounts are stored as integer minor units with an explicit `currency_code`. For EUR, `2999` minor units represents EUR 29.99. dbt will expose an exact `NUMERIC` amount in euros for analysis and presentation.

This preserves payment-source fidelity, avoids floating-point reconciliation errors, and keeps the reporting layer convenient for analysts.

## Table 2: `plans`

Grain: one row per plan version. A new row is created when a plan's price, trial length, tier, or billing terms change.

| Column | BigQuery type | Required? | Meaning |
|---|---|---:|---|
| `plan_version_id` | `STRING` | Yes | Unique identifier for this version of the plan and primary key |
| `plan_code` | `STRING` | Yes | Stable plan identifier retained across price versions |
| `plan_tier` | `STRING` | Yes | Customer offering level: `standard` or `premium` |
| `billing_interval` | `STRING` | Yes | Billing frequency: `month` or `year` |
| `price_minor_units` | `INT64` | Yes | Plan price in the currency's minor units |
| `currency_code` | `STRING` | Yes | Currency for the plan price; `EUR` in the approved project scope |
| `trial_days` | `INT64` | Yes | Number of free-trial days offered under this plan version |
| `valid_from` | `DATE` | Yes | First date this plan version can be selected |
| `valid_to` | `DATE` | No | Final date this version can be selected; null while current |

### Proposed generation rules

- `plan_version_id` is unique and never null.
- `plan_code` remains stable when a price change creates a new version.
- `plan_tier` is `standard` or `premium`.
- `billing_interval` is `month` or `year`.
- `price_minor_units` is greater than zero and uses `currency_code = EUR`.
- `trial_days` is non-negative.
- Effective date ranges do not overlap for the same `plan_code`.
- `valid_to` is on or after `valid_from` when present.

### Planned validation

- Unique and not-null test on `plan_version_id`.
- Not-null and accepted-value tests on required categorical fields.
- Business-rule tests for positive price, non-negative trial length, valid date order, and non-overlapping versions.
- Reconciliation example proving the raw minor-unit price converts to the expected exact euro amount in dbt.

The plan-version structure and columns were approved by Faisal on 2026-08-27. Numerical amounts previously used to explain minor units were illustrations, not approved plan prices. The following proposed catalog will become the single source for generated plan values only after approval.

### Approved plan catalog

| Plan code | Version | Valid from | Valid to | Price in minor units | Display price | Trial days |
|---|---|---|---|---:|---:|---:|
| `standard_monthly` | `standard_monthly_v1` | 2025-01-01 | 2025-12-31 | 1499 | EUR 14.99 | 14 |
| `standard_annual` | `standard_annual_v1` | 2025-01-01 | 2025-12-31 | 14990 | EUR 149.90 | 14 |
| `premium_monthly` | `premium_monthly_v1` | 2025-01-01 | 2025-12-31 | 2999 | EUR 29.99 | 14 |
| `premium_annual` | `premium_annual_v1` | 2025-01-01 | 2025-12-31 | 29990 | EUR 299.90 | 14 |
| `standard_monthly` | `standard_monthly_v2` | 2026-01-01 | null | 1599 | EUR 15.99 | 14 |
| `standard_annual` | `standard_annual_v2` | 2026-01-01 | null | 15990 | EUR 159.90 | 14 |
| `premium_monthly` | `premium_monthly_v2` | 2026-01-01 | null | 3199 | EUR 31.99 | 14 |
| `premium_annual` | `premium_annual_v2` | 2026-01-01 | null | 31990 | EUR 319.90 | 14 |

The annual price equals ten monthly payments, representing two months free. The 2026 versions create a realistic price change without changing the stable plan codes.

Approved by Faisal on 2026-08-27. These values are the canonical plan catalog for every downstream artifact. A version's `valid_to` is the final date it can be newly selected; an existing subscription can remain on that version until a recorded plan change.

## Table 3: `subscriptions`

Grain: one row per subscription instance. A customer can have more than one subscription over time, but cannot have overlapping trialing or active subscriptions.

| Column | BigQuery type | Required? | Meaning |
|---|---|---:|---|
| `subscription_id` | `STRING` | Yes | Unique subscription identifier and primary key |
| `customer_id` | `STRING` | Yes | Customer that owns the subscription; foreign key to `customers` |
| `initial_plan_version_id` | `STRING` | Yes | Plan version selected when the subscription began |
| `current_plan_version_id` | `STRING` | Yes | Plan version attached to the subscription at the reporting cutoff |
| `created_at` | `TIMESTAMP` | Yes | UTC timestamp when the subscription instance was created |
| `trial_started_at` | `TIMESTAMP` | Yes | UTC timestamp when the free trial began |
| `trial_scheduled_end_at` | `TIMESTAMP` | Yes | Scheduled trial completion timestamp |
| `paid_started_at` | `TIMESTAMP` | No | First timestamp the subscription became paid; null if it never converted |
| `current_period_start_at` | `TIMESTAMP` | No | Start of the current paid billing period at the reporting cutoff |
| `current_period_end_at` | `TIMESTAMP` | No | End of the current paid billing period at the reporting cutoff |
| `current_status` | `STRING` | Yes | Latest snapshot status: `trialing`, `active`, `past_due`, or `canceled` |
| `cancel_requested_at` | `TIMESTAMP` | No | Timestamp when cancellation was requested |
| `ended_at` | `TIMESTAMP` | No | Timestamp when access and the subscription instance ended |

### Proposed generation rules

- `subscription_id` is unique and never null.
- Every `customer_id` and plan-version identifier exists in its parent table.
- A customer can have multiple subscription instances over time but no overlapping `trialing` or `active` periods.
- `trial_scheduled_end_at` is after `trial_started_at` and follows the selected plan version's `trial_days`.
- `paid_started_at` is null for a trial that never converts; otherwise it is on or after `trial_started_at`.
- Current paid-period timestamps are both populated for `active` or `past_due` subscriptions and have a valid date order.
- `ended_at` is required for `canceled` subscriptions and null for subscriptions that have not ended.
- Current fields describe the snapshot at the reporting cutoff; lifecycle history is preserved separately in `subscription_events`.

### Planned validation

- Unique and not-null test on `subscription_id`.
- Relationship tests from customer and plan-version keys to their parent tables.
- Accepted-value test on `current_status`.
- Business-rule tests for trial, paid-period, cancellation, and non-overlap logic.
- Reconciliation from each subscription's current snapshot back to its latest lifecycle event.

Approved by Faisal on 2026-08-27. `subscriptions.customer_id` is the foreign key to `customers.customer_id`; a downstream subscription event, invoice, or payment does not duplicate `customer_id` when the customer can be reached reliably through the subscription relationship.

## Table 4: `subscription_events`

Grain: one row per recorded subscription lifecycle or plan-change event.

| Column | BigQuery type | Required? | Meaning |
|---|---|---:|---|
| `subscription_event_id` | `STRING` | Yes | Unique event identifier and primary key |
| `subscription_id` | `STRING` | Yes | Subscription affected by the event; foreign key to `subscriptions` |
| `event_sequence` | `INT64` | Yes | Positive sequence number that orders events within a subscription |
| `event_at` | `TIMESTAMP` | Yes | UTC timestamp when the event became effective |
| `event_type` | `STRING` | Yes | Recorded action or state change |
| `from_status` | `STRING` | No | Subscription status immediately before the event |
| `to_status` | `STRING` | No | Subscription status immediately after the event |
| `from_plan_version_id` | `STRING` | No | Plan version immediately before a plan change |
| `to_plan_version_id` | `STRING` | No | Plan version immediately after a plan change |
| `event_reason` | `STRING` | No | Controlled reason when the event needs additional context |

### Proposed event types

- `trial_started`
- `trial_converted`
- `plan_changed`
- `past_due`
- `payment_recovered`
- `cancel_requested`
- `cancellation_revoked`
- `canceled`

Upgrade, downgrade, and reactivation are analytical classifications derived in dbt. For example, dbt compares the old and new plan values to classify a `plan_changed` event, and checks a customer's earlier ended subscriptions to classify a later paid start as reactivation.

### Proposed generation rules

- `subscription_event_id` is unique and never null.
- Every `subscription_id` exists in `subscriptions`.
- `event_sequence` is unique within each subscription and increases with `event_at`.
- Events cannot occur before the subscription's `created_at` or after its `ended_at`.
- A `plan_changed` event requires different valid `from_plan_version_id` and `to_plan_version_id` values.
- Status-changing events populate valid `from_status` and `to_status` values.
- The last event for a subscription reconciles with its snapshot `current_status` and `current_plan_version_id`.

### Planned validation

- Unique and not-null test on `subscription_event_id`.
- Relationship tests to subscriptions and plan versions.
- Accepted-value test on `event_type`.
- Unique test on `subscription_id` plus `event_sequence`.
- Business-rule tests for chronology, required event-specific fields, valid transitions, and snapshot reconciliation.

Approved by Faisal on 2026-08-27. Raw events record observable changes; dbt derives analytical classifications such as upgrade, downgrade, and reactivation using plan values and customer subscription history.

## Table 5: `invoices`

Grain: one row per amount billed to a subscription. An invoice states the amount owed; payment attempts separately record efforts to collect it.

| Column | BigQuery type | Required? | Meaning |
|---|---|---:|---|
| `invoice_id` | `STRING` | Yes | Unique invoice identifier and primary key |
| `subscription_id` | `STRING` | Yes | Subscription being billed; foreign key to `subscriptions` |
| `plan_version_id` | `STRING` | Yes | Plan version whose commercial terms produced the charge |
| `billing_reason` | `STRING` | Yes | Why the invoice was created: `initial_subscription`, `subscription_cycle`, or `plan_change` |
| `billing_period_start` | `DATE` | Yes | First service date covered by the invoice |
| `billing_period_end` | `DATE` | Yes | Exclusive end of the service period |
| `issued_at` | `TIMESTAMP` | Yes | UTC timestamp when the invoice was finalized for collection |
| `due_at` | `TIMESTAMP` | Yes | UTC timestamp when payment was due |
| `amount_due_minor_units` | `INT64` | Yes | Amount requested in the currency's minor units |
| `currency_code` | `STRING` | Yes | Invoice currency; `EUR` in the approved scope |
| `invoice_status` | `STRING` | Yes | Status at the reporting cutoff: `open`, `paid`, `uncollectible`, or `void` |
| `paid_at` | `TIMESTAMP` | No | UTC timestamp when full collection completed; null otherwise |

### Proposed generation rules

- `invoice_id` is unique and never null.
- Every subscription and plan version exists in its parent table.
- `billing_period_end` is after `billing_period_start`; the end date is exclusive to prevent overlapping service days.
- `issued_at` is not after `due_at`.
- `amount_due_minor_units` is positive and `currency_code = EUR`.
- A `paid` invoice has `paid_at` and exactly one successful full-amount payment attempt.
- An `open`, `uncollectible`, or `void` invoice has no `paid_at`.
- A `void` invoice has no successful payment attempt.
- A later refund does not change a paid invoice back to unpaid; refunds are recorded separately.

### Planned validation

- Unique and not-null test on `invoice_id`.
- Relationship tests to subscriptions and plan versions.
- Accepted-value tests on billing reason, currency, and invoice status.
- Business-rule tests for billing-period order, timestamp order, positive amount, and status-dependent fields.
- Reconciliation of paid invoices to successful payment attempts and of subscription billing intervals to invoice periods.

Approved by Faisal on 2026-08-27. Customer attributes are reached through the invoice's subscription relationship rather than duplicated, and later refunds do not rewrite the invoice's paid state.

## Table 6: `payment_attempts`

Grain: one row per collection attempt against an invoice. Each retry is a new row even when it repeats the same amount or failure reason.

| Column | BigQuery type | Required? | Meaning |
|---|---|---:|---|
| `payment_attempt_id` | `STRING` | Yes | Unique collection-attempt identifier and primary key |
| `invoice_id` | `STRING` | Yes | Invoice being collected; foreign key to `invoices` |
| `attempt_number` | `INT64` | Yes | Positive sequence number within the invoice |
| `attempted_at` | `TIMESTAMP` | Yes | UTC timestamp when collection was attempted |
| `amount_attempted_minor_units` | `INT64` | Yes | Amount submitted for collection in minor units |
| `currency_code` | `STRING` | Yes | Attempt currency; `EUR` in the approved scope |
| `payment_status` | `STRING` | Yes | Result of this attempt: `succeeded` or `failed` |
| `failure_reason` | `STRING` | No | Provider-style reason for a failed attempt; null when successful |

### Proposed failure reasons

- `insufficient_funds`
- `expired_card`
- `authentication_required`
- `card_declined`
- `processing_error`

### Proposed generation rules

- `payment_attempt_id` is unique and never null.
- Every `invoice_id` exists in `invoices`.
- `attempt_number` starts at 1 and increases without gaps within an invoice.
- `attempted_at` is not before the invoice's `issued_at` and increases with `attempt_number`.
- Amount and currency match the invoice in this simplified full-collection scope.
- A failed attempt requires a failure reason; a successful attempt has a null failure reason.
- An invoice has at most one successful attempt, and no later attempt occurs after success.
- A paid invoice has exactly one successful attempt; an open or uncollectible invoice has none.

### Planned validation

- Unique and not-null test on `payment_attempt_id`.
- Relationship test to invoices.
- Unique test on `invoice_id` plus `attempt_number`.
- Accepted-value tests on payment status, currency, and failure reason.
- Business-rule tests for sequence, chronology, status-dependent failure reason, full-amount matching, and no attempts after success.
- Reconciliation of attempt outcomes to invoice status and paid timestamp.

Approved by Faisal on 2026-08-27. Separate rows are retained for every collection attempt, including repeated failures with the same reason, and collection stops after the first success.

## Table 7: `refunds`

Grain: one row per successful refund transaction against a successful payment attempt. A payment can have multiple partial refunds.

| Column | BigQuery type | Required? | Meaning |
|---|---|---:|---|
| `refund_id` | `STRING` | Yes | Unique refund identifier and primary key |
| `payment_attempt_id` | `STRING` | Yes | Successful payment being refunded; foreign key to `payment_attempts` |
| `refunded_at` | `TIMESTAMP` | Yes | UTC timestamp when the refund succeeded |
| `amount_refunded_minor_units` | `INT64` | Yes | Refunded amount in the currency's minor units |
| `currency_code` | `STRING` | Yes | Refund currency; `EUR` in the approved scope |
| `refund_reason` | `STRING` | Yes | Controlled business reason for the refund |

### Proposed refund reasons

- `customer_request`
- `billing_error`
- `duplicate_charge`
- `service_issue`
- `fraud_reported`

### Proposed generation rules

- `refund_id` is unique and never null.
- Every `payment_attempt_id` exists and has `payment_status = succeeded`.
- `refunded_at` is not before the successful payment's `attempted_at`.
- `amount_refunded_minor_units` is positive and uses the same currency as the payment.
- Multiple partial refunds are allowed, but their cumulative amount cannot exceed the successful payment amount.
- A fully or partially refunded invoice remains `paid`; refund state is calculated separately.

### Planned validation

- Unique and not-null test on `refund_id`.
- Relationship test to payment attempts.
- Accepted-value tests on refund reason and currency.
- Business-rule tests proving the linked attempt succeeded, timestamp order is valid, and cumulative refunds do not exceed the collected amount.
- dbt classification of each payment and invoice as `not_refunded`, `partially_refunded`, or `fully_refunded`.

Approved by Faisal on 2026-08-27. Refunds link to successful payment attempts, multiple partial refunds are allowed, and cumulative refunds cannot exceed the collected amount.

## Table 8: `product_events`

Grain: one row per recorded customer action in the SkillSpring product.

| Column | BigQuery type | Required? | Meaning |
|---|---|---:|---|
| `product_event_id` | `STRING` | Yes | Unique product-event identifier and primary key |
| `customer_id` | `STRING` | Yes | Customer who performed the action; foreign key to `customers` |
| `session_id` | `STRING` | Yes | Synthetic product session containing the action |
| `occurred_at` | `TIMESTAMP` | Yes | UTC timestamp when the action occurred |
| `event_name` | `STRING` | Yes | Controlled name of the recorded product action |
| `platform` | `STRING` | Yes | Platform where the action occurred: `ios`, `android`, or `web` |
| `onboarding_step` | `STRING` | No | Completed onboarding step when applicable |
| `program_id` | `STRING` | No | Synthetic learning-program identifier when applicable |
| `lesson_id` | `STRING` | No | Synthetic lesson identifier when applicable |

### Proposed event names

- `session_started`
- `onboarding_started`
- `onboarding_step_completed`
- `onboarding_completed`
- `program_viewed`
- `program_started`
- `lesson_started`
- `lesson_completed`

### Proposed onboarding steps

- `goal_selected`
- `experience_selected`
- `learning_schedule_set`
- `first_program_selected`

### Proposed generation rules

- `product_event_id` is unique and never null.
- Every `customer_id` exists in `customers`, and events occur on or after that customer's `signup_at`.
- Each `session_id` belongs to exactly one customer.
- `onboarding_step_completed` requires a valid `onboarding_step`; other event names leave it null.
- Program events require `program_id`; lesson events require both `program_id` and `lesson_id`.
- Event timestamps follow a possible sequence: onboarding begins before its steps and completion, and lesson completion follows lesson start.
- Product activity occurs during an eligible trialing or active access period.
- All events fall within the documented activity window.

### Planned validation

- Unique and not-null test on `product_event_id`.
- Relationship test to customers.
- Accepted-value tests on event name, platform, and onboarding step.
- Business-rule tests for event-specific fields, customer/session consistency, eligible access, timestamp window, and plausible event order.
- Funnel reconciliation from onboarding start through onboarding completion, program start, lesson completion, and paid conversion.

Approved by Faisal on 2026-08-27. Product events connect directly to customers because activity begins before paid conversion, while sessions group actions from the same product visit.

## Table 9: `experiment_assignments`

Grain: one row per customer per experiment. The composite primary key is `customer_id` plus `experiment_id`.

| Column | BigQuery type | Required? | Meaning |
|---|---|---:|---|
| `customer_id` | `STRING` | Yes | Randomization unit; foreign key to `customers` |
| `experiment_id` | `STRING` | Yes | Stable identifier for one experiment design and version |
| `variant` | `STRING` | Yes | Randomly assigned experience: `control` or `treatment` |
| `assigned_at` | `TIMESTAMP` | Yes | UTC timestamp when assignment became immutable |
| `first_exposed_at` | `TIMESTAMP` | No | First time the customer actually saw the assigned experience; null if never exposed |

The assignment table deliberately excludes conversion, retention, revenue, refund, or other outcomes. Those are calculated from the canonical behavioral and commercial tables after assignment, preventing duplicated or conflicting outcome definitions.

### Proposed generation rules

- The combination of `customer_id` and `experiment_id` is unique and never null.
- Every assigned customer exists in `customers` and is assigned at or after signup.
- Assignment is immutable: a customer cannot switch variants within an experiment.
- `variant` is `control` or `treatment`, with approximately equal random allocation.
- `first_exposed_at` is null or on/after `assigned_at`.
- Only post-assignment outcomes are eligible for experiment analysis.
- The primary intention-to-treat analysis includes every assigned customer; exposure-based analysis is secondary.

### Planned validation

- Unique test on `customer_id` plus `experiment_id` and not-null tests on both keys.
- Relationship test to customers.
- Accepted-value test on variant.
- Business-rule tests for assignment timing, immutable assignment, and exposure timing.
- Randomization checks comparing group sizes and pre-assignment customer characteristics.
- Join validation proving outcomes occur after assignment and are sourced from canonical models.

Approved by Faisal on 2026-08-27. Assignment remains separate from outcomes, unexposed assigned customers remain in the primary intention-to-treat population, and post-assignment outcomes come from canonical models.

## Proposed synthetic scale

The targets are large enough to demonstrate warehouse modeling and high-volume event analysis while remaining comfortably within the BigQuery Sandbox limits.

| Raw table | Proposed scale |
|---|---:|
| `customers` | 50,000 rows |
| `plans` | 8 rows |
| `subscriptions` | Approximately 47,000 rows, including later subscription instances |
| `subscription_events` | Approximately 180,000 rows |
| `invoices` | Approximately 170,000 rows |
| `payment_attempts` | Approximately 205,000 rows |
| `refunds` | Approximately 5,000 rows |
| `product_events` | Approximately 2,000,000 rows |
| `experiment_assignments` | Approximately 8,000 rows |

Exact counts will be deterministic after generation with a fixed random seed; approximate counts allow business rules to determine the final child-table totals.

## Proposed distribution assumptions

- Approximately 90% of signed-up customers start a free trial.
- Overall trial-to-paid conversion is approximately 55%, with realistic variation by acquisition channel and early product behavior.
- Initial selections are approximately 65% Standard versus 35% Premium and 70% monthly versus 30% annual.
- Approximately 10% of invoice collections fail on the first attempt; a meaningful share recover on a later retry, with no more than three attempts per invoice.
- Approximately 3% of successful payments receive at least one full or partial refund, with variation by plan, acquisition source, and customer experience.
- Product activity is uneven: many customers generate few events while engaged retained customers generate substantially more.
- Experiment assignment is approximately 50/50, with a modest predetermined treatment effect and no intentional material increase in the refund guardrail.
- All important synthetic relationships and planted effects will be documented so portfolio conclusions are presented as demonstrations, not real-world causal claims.

## Proposed cross-table generation rules

- Use a fixed random seed so every generation run produces the same data.
- Create parent records before child records and preserve every documented foreign-key relationship.
- Generate no transactions or product events after the 2026-06-30 reporting cutoff; scheduled trial and billing-period end dates may extend beyond it.
- Select only plan versions available when a new subscription or plan change occurs; existing subscriptions can retain an older version.
- Generate invoices only during paid access periods, then derive attempts, invoice status, and refunds in chronological order.
- Generate product activity only during eligible access periods and after customer signup.
- Generate experiment outcomes only after assignment, while leaving all pre-assignment characteristics unaffected by treatment.
- Introduce controlled edge cases—such as failed retries, partial refunds, cancellation reversal, reactivation, and customers near the 90-day maturity boundary—without violating the contract.

## Open design decisions

No open source-contract decisions remain. Exact generated row counts and validation results must be recorded after the deterministic generator runs.

Approved by Faisal on 2026-08-27. Any later change to a grain, key, canonical value, plan price, generation assumption, or relationship must be documented here before regenerating data.

## Generated result

The deterministic full run completed on 2026-08-27 with 2,512,863 rows, including 50,000 customers and 1,998,136 product events. Exact table counts, checksums, caught defects, and local/warehouse validation evidence are documented in `docs/raw-data-load-validation.md`.
