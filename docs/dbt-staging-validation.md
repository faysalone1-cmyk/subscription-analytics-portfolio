# dbt Modeling Lineage and Validation

Initially validated: 2026-08-27
Extended validation: 2026-09-02
Three-layer validation: 2026-09-03

## Purpose

Prove that dbt can reference approved BigQuery raw sources, preserve source grains in staging, combine one-to-many payment data safely at invoice grain, and publish reconciled daily payment-recovery metrics in the separate analytics dataset.

## Declared sources

`dbt/models/staging/_sources.yml` declares all nine tables in `skillspring-analytics.skillspring_raw`:

- Customers
- Plans
- Subscriptions
- Subscription events
- Invoices
- Payment attempts
- Refunds
- Product events
- Experiment assignments

The declaration records their warehouse address and approved grain descriptions without copying the raw data.

## Current lineage

| Raw source | dbt staging view | Grain preserved | Governed transformation |
|---|---|---|---|
| `skillspring_raw.customers` | `skillspring_analytics.stg_customers` | One row per customer | Signup date and reporting region derived from UTC signup timestamp and country code |
| `skillspring_raw.plans` | `skillspring_analytics.stg_plans` | One row per plan version | Exact minor-unit-to-euro conversion plus current-version flag |
| `skillspring_raw.subscriptions` | `skillspring_analytics.stg_subscriptions` | One row per subscription | Reusable paid-conversion and canceled flags |
| `skillspring_raw.invoices` | `skillspring_analytics.stg_invoices` | One row per invoice | Exact minor-unit-to-euro conversion plus paid-status flag |
| `skillspring_raw.payment_attempts` | `skillspring_analytics.stg_payment_attempts` | One row per attempt | Exact minor-unit-to-euro conversion plus retry and success flags |
| `skillspring_raw.refunds` | `skillspring_analytics.stg_refunds` | One row per refund transaction | Exact minor-unit-to-euro conversion with governed payment-attempt lineage and refund reasons |

The downstream lineage is:

| Upstream models | dbt model | Grain | Governed transformation |
|---|---|---|---|
| `stg_invoices`, `stg_payment_attempts`, `stg_refunds` | `int_invoice_payment_outcomes` | One row per invoice | Pre-aggregated attempt and refund history, payment outcome, refund status, and net collected amount |
| `int_invoice_payment_outcomes` | `mart_payment_recovery_daily` | One row per invoice issue date | Daily payment volumes, collection and recovery rates, refund counts, and gross/net EUR totals |

## dbt build evidence

dbt Core 1.11.14 with the BigQuery adapter 1.11.3 parsed:

- 9 sources
- 8 models across staging, intermediate, and mart layers
- 74 generic data tests
- 2 singular business-rule and reconciliation tests

`dbt build --select path:models` created all eight BigQuery views and passed all 76 tests:

- 8 uniqueness tests
- 41 not-null tests
- 17 accepted-value tests
- 8 relationship tests
- 2 singular tests

Final dbt result: `PASS=84 WARN=0 ERROR=0 SKIP=0 TOTAL=84`.

## Independent transformation validation

The version-controlled query `sql/validation/staging_validation.sql` passed all nine capped warehouse checks:

- Three staging row counts exactly matched their raw sources.
- Zero unmapped customer regions.
- Zero incorrect minor-unit-to-euro conversions.
- Zero incorrect retry or success flags.
- Zero incorrect paid-conversion or canceled flags.

Independent Week 2 warehouse review also confirmed:

- All eight plan-version rows retained their approved identifiers, prices, effective dates, exact euro conversions, and current-version flags.
- `stg_invoices` contained 128,633 rows and 128,633 distinct invoice IDs.
- Invoice validation returned zero amount-conversion, paid-flag, paid-timestamp, billing-period, due-timestamp, and non-positive-amount violations.
- Representative open, paid, and uncollectible invoices had consistent amounts, payment timestamps, and paid flags.
- `stg_refunds` contained 4,093 rows and 4,093 distinct refund IDs.
- The version-controlled `sql/validation/refund_staging_validation.sql` returned zero amount-conversion, non-positive-amount, missing-payment, unsuccessful-payment, timestamp-order, currency, and over-refund violations.
- A representative successful payment with two partial refunds retained two distinct refund rows; the combined EUR 13.28 refund remained below the original EUR 31.99 payment.

Independent invoice-outcome and mart review also confirmed:

- `int_invoice_payment_outcomes` contained 128,633 rows and 128,633 distinct invoice IDs.
- Payment outcomes reconciled to 115,755 first-attempt successes, 8,361 recovered invoices, 143 open unpaid invoices, and 4,374 uncollectible invoices.
- All attempt-count, paid-status, outcome-flag, refund, over-refund, conversion, and net-amount checks returned zero violations.
- `mart_payment_recovery_daily` contained 532 rows and 532 distinct invoice dates from 2025-01-15 through 2026-06-30.
- Summed mart totals retained all 128,633 invoices and returned zero daily count, rate, financial, or cross-layer reconciliation differences.
- The two version-controlled singular tests returned zero invalid rows.

## Documentation evidence

`dbt docs generate` cataloged all eight models, 76 tests, and nine sources. Visual review of the generated local site confirmed that model descriptions, column descriptions, warehouse types, attached tests, and lineage are visible. The lineage graph shows raw invoices, payment attempts, and refunds flowing through their staging views into `int_invoice_payment_outcomes`, then into `mart_payment_recovery_daily` and its reconciliation test.

## Result and boundary

The dbt lineage is working and tested from six raw sources to six staging views, one invoice-grain intermediate view, and one daily payment-recovery mart. Three declared sources do not yet have staging models. Broader dimensional models, recurring-revenue and retention marts, metric governance, Python validation, experimentation, and dashboard outputs remain later roadmap deliverables.
