# Subscription Event Fact Review

## Summary

This change adds a governed subscription lifecycle-event fact table at one row per subscription event.

The model preserves the event sequence and lifecycle transition fields from staging, enriches every event with its subscription customer, and adds reporting-friendly event date and month fields.

## Model

- Model: `fct_subscription_events`
- Grain: one row per `subscription_event_id`
- Materialization: BigQuery table
- Source model: `stg_subscription_events`
- Subscription context: `fct_subscriptions`
- Customer dimension: `dim_customers`
- Plan dimension: `dim_plan_versions`

## Key fields

- `subscription_event_id`: unique lifecycle-event identifier
- `subscription_id`: subscription associated with the event
- `customer_id`: customer inherited from the subscription fact
- `event_sequence`: ordered position within the subscription lifecycle
- `event_at`: event timestamp
- `event_date`: calendar date derived from `event_at`
- `event_month`: month derived from `event_date`
- `event_type`: lifecycle event classification
- `from_status` and `to_status`: status transition
- `from_plan_version_id` and `to_plan_version_id`: plan transition
- `event_reason`: optional transition context

## Validation evidence

### Model build

The targeted dbt build created the fact table with approximately 129,000 rows.

Result:

- PASS: 19
- WARN: 0
- ERROR: 0
- SKIP: 0

### Independent BigQuery validation

Seven independent checks returned zero violations:

- staging projection alignment
- customer enrichment derivation
- event-date derivation
- event-month derivation
- duplicate event identifiers
- row-count difference from staging
- subscription event-sequence continuity

### Full project integration

The complete dbt project build passed:

- PASS: 164
- WARN: 0
- ERROR: 0
- SKIP: 0
- NO-OP: 0
- TOTAL: 164

## Data impact

This change creates the governed `fct_subscription_events` BigQuery table. Raw tables, existing staging models, dimensions, the subscription fact, and existing reporting grains remain unchanged.

## Security

No credentials, generated raw data, private profiles, or local configuration files are included.

## Remaining scope

The next production deliverable is the invoice-payment outcome fact, followed by the partitioned product-event fact and final portfolio reporting layer.
