# Initial dbt Staging Lineage and Validation

Validated: 2026-08-27

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

## Initial lineage

| Raw source | dbt staging view | Grain preserved | Initial governed transformation |
|---|---|---|---|
| `skillspring_raw.customers` | `skillspring_analytics.stg_customers` | One row per customer | Signup date and reporting region derived from UTC signup timestamp and country code |
| `skillspring_raw.subscriptions` | `skillspring_analytics.stg_subscriptions` | One row per subscription | Reusable paid-conversion and canceled flags |
| `skillspring_raw.payment_attempts` | `skillspring_analytics.stg_payment_attempts` | One row per attempt | Exact minor-unit-to-euro conversion plus retry and success flags |

## dbt build evidence

dbt Core 1.11.14 with the BigQuery adapter 1.11.3 parsed:

- 9 sources
- 3 models
- 14 generic data tests

`dbt build --select path:models/staging` created all three BigQuery views and passed all 14 tests:

- 3 uniqueness tests
- 5 not-null tests
- 5 accepted-value tests
- 1 customer-to-subscription relationship test

Final dbt result: `PASS=17 WARN=0 ERROR=0 SKIP=0 TOTAL=17`.

## Independent transformation validation

The version-controlled query `sql/validation/staging_validation.sql` passed all nine capped warehouse checks:

- Three staging row counts exactly matched their raw sources.
- Zero unmapped customer regions.
- Zero incorrect minor-unit-to-euro conversions.
- Zero incorrect retry or success flags.
- Zero incorrect paid-conversion or canceled flags.

## Result and boundary

The first dbt lineage is working and tested from raw source to staging view. Six declared sources do not yet have staging models, and no intermediate models, marts, governed business metrics, or reconciliation reports have been built. Those remain later roadmap deliverables.
