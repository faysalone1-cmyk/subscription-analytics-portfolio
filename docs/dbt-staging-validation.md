# dbt Staging Lineage and Validation

Initially validated: 2026-08-27
Extended validation: 2026-09-02

## Purpose

Prove that dbt can reference all approved BigQuery raw sources and build tested, grain-preserving staging models in the separate analytics dataset.

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

## dbt build evidence

dbt Core 1.11.14 with the BigQuery adapter 1.11.3 parsed:

- 9 sources
- 6 models
- 34 generic data tests

`dbt build --select path:models/staging` created all six BigQuery views and passed all 34 tests:

- 6 uniqueness tests
- 11 not-null tests
- 13 accepted-value tests
- 4 relationship tests

Final dbt result: `PASS=40 WARN=0 ERROR=0 SKIP=0 TOTAL=40`.

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

## Result and boundary

The expanded dbt lineage is working and tested from six raw sources to six staging views. Three declared sources do not yet have staging models, and no intermediate models, marts, governed business metrics, or reconciliation reports have been built. Those remain later roadmap deliverables.
