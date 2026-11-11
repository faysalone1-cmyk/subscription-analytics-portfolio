# Active subscriptions by country

Originally verified on 2026-10-16 and revalidated against live BigQuery on 2026-11-10 using read-only queries in EU.

## Metric and scope

Count subscription instances whose `current_status` is `active`, grouped by the customer dimension's country code. This is neither distinct active customers nor revenue. Status reflects the synthetic dataset's reporting cutoff (2026-06-30), not live business activity on the execution date. Other statuses, including `past_due` and `trialing`, are excluded. Country reflects the customer signup attributes in the source contract.

Sources: `skillspring-analytics.skillspring_analytics.fct_subscriptions` and `dim_customers`. Query: `sql/analysis/active_subscriptions_by_country.sql`.

## Results

| Country code | Active subscriptions |
|---|---:|
| DE | 3,835 |
| FR | 2,497 |
| FI | 2,292 |
| ES | 2,133 |
| IT | 2,126 |
| SE | 1,776 |
| NL | 1,717 |
| IE | 1,325 |
| **Total** | **17,701** |

## Validation evidence

- BigQuery metadata confirmed the fact, staging input, and both dimensions exist.
- Saved dbt run artifact dated 2026-10-12: three successful model builds and 40 passing tests across the fact and two dimensions. These tests were not rerun in this analysis session.
- The fact currently contains 46,810 rows.
- All 12 checks in `sql/validation/subscription_fact_validation.sql` returned zero violations during the original fact review.
- Additional live checks in `sql/validation/subscription_fact_alignment.sql` found zero NULL subscription IDs, duplicate customer keys, duplicate plan keys, unmatched subscription IDs between fact and staging, or customer/status mismatches against staging.
- Country total: 17,701. Independent active count directly from the fact: 17,701. Difference: 0.
- No active subscription had an unmatched customer dimension record.
- The published analysis was rerun on 2026-11-10 and reproduced every country count, a total of 17,701, zero unmatched customer rows, and zero reconciliation difference.

## Interpretation

Germany has the largest active subscription count, at 3,835. Counts alone do not establish higher conversion or retention: those require appropriate population denominators and time windows.

## Workflow evidence

The analysis inspected the governed lineage, queried warehouse metadata, ran independent validation, reconciled the grouped result to the fact total, and documented interpretation limits. The query and review are now published together so the result is reproducible without changing warehouse objects.
