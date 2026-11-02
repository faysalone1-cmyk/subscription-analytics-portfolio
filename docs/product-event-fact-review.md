# Product Event Fact Review

## Summary

This change adds a governed product-interaction fact table at one row per product event. It stages raw product events, validates event-specific context rules, enriches each event with customer context, and exposes analysis-ready calendar fields.

## Model grain and key

- Model: `fct_product_events`
- Grain: one row per product interaction event
- Primary key: `product_event_id`
- Customer relationship: `customer_id` joins to `dim_customers`

## Lineage

`skillspring_raw.product_events` → `stg_product_events` → `fct_product_events`

Customer enrichment:

`dim_customers` → `fct_product_events`

## Core fields

- `product_event_id`
- `customer_id`
- `session_id`
- `occurred_at`
- `event_date`
- `event_month`
- `event_name`
- `platform`
- `onboarding_step`
- `program_id`
- `lesson_id`

## Validation evidence

- Staging build: PASS=14, WARN=0, ERROR=0
- Staging business-rule test: PASS=1, WARN=0, ERROR=0
- Fact build: PASS=13, WARN=0, ERROR=0
- Independent BigQuery validation: 7 of 7 checks passed with zero violations
- Verified grain, row-count alignment, date derivations, customer relationships, staging projection, and event-context validity

## Data impact

Creates the governed `fct_product_events` BigQuery table. Raw sources, existing staging models, dimensions, subscription facts, and existing reporting grains remain unchanged.

## Security

No credentials, generated raw data, private profiles, or local configuration files are included.

## Remaining scope

The next step is a full-project build, followed by commit, push, pull-request review, CI validation, and merge.
