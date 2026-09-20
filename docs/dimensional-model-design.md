# SkillSpring Dimensional Model Design

Status: Week 3 design in progress

## Purpose

Define the analytical grains, keys, join paths, history rules, and BigQuery
physical-design choices before implementing the Week 3 dimensional models.
The design extends the tested Week 2 payment lineage without changing the
approved raw-source contract.

## Modeling principles

1. Declare what one row represents before selecting columns or writing joins.
2. Give every fact a key that is unique at its declared grain.
3. Allow dimension foreign keys to repeat naturally across fact rows.
4. Join facts directly to conformed dimensions where practical.
5. Do not join two detailed facts directly when that would create a many-to-many
   result; aggregate each fact to a compatible grain first.
6. Keep additive counts and amounts in facts and calculate ratios in marts.
7. Preserve exact monetary values and the invoice-level reconciliation controls
   established in Week 2.

## Proposed core model grains and keys

| Model | Role | Grain: one row per | Unique key | Repeatable foreign keys | Primary input |
|---|---|---|---|---|---|
| `dim_customers` | Conformed dimension | Customer | `customer_id` | None | `stg_customers` |
| `dim_plan_versions` | Versioned dimension | Commercial plan version | `plan_version_id` | None | `stg_plans` |
| `fct_subscriptions` | Accumulating process fact | Subscription instance | `subscription_id` | `customer_id`, `initial_plan_version_id`, `current_plan_version_id` | `stg_subscriptions` |
| `fct_subscription_events` | Transaction/event fact | Subscription lifecycle event | `subscription_event_id` | `subscription_id`, `customer_id`, `from_plan_version_id`, `to_plan_version_id` | Planned `stg_subscription_events` plus `stg_subscriptions` |
| `fct_invoice_payment_outcomes` | Accumulating outcome fact | Invoice | `invoice_id` | `subscription_id`, `customer_id`, `plan_version_id` | `int_invoice_payment_outcomes` plus `stg_subscriptions` |
| `fct_product_events` | Transaction/event fact | Product event | `product_event_id` | `customer_id` | Planned `stg_product_events` |

`experiment_assignments` is reserved for the Week 6 experiment workflow. It can
later become a factless fact at one row per customer and experiment without
changing the Week 3 core grains.

## Key interpretation

- A unique key identifies one row at the model's grain. For example,
  `invoice_id` is unique in `fct_invoice_payment_outcomes` because the model has
  one row per invoice.
- A foreign key provides descriptive context and is expected to repeat. Twelve
  monthly invoices for one subscription create twelve invoice fact rows but
  only one distinct `subscription_id`.
- `plan_version_id`, rather than `plan_code`, identifies the exact commercial
  terms used historically. Multiple plan-version rows may share one stable
  `plan_code` while retaining different prices and validity dates.

## Safe join paths

| Analytical question | Safe path | Cardinality and protection |
|---|---|---|
| Invoice outcomes by customer attributes | `fct_invoice_payment_outcomes.customer_id` to `dim_customers.customer_id` | Many invoices to one unique customer row |
| Invoice outcomes by billed plan version | `fct_invoice_payment_outcomes.plan_version_id` to `dim_plan_versions.plan_version_id` | Many invoices to one exact historical plan-version row |
| Product activity by customer attributes | `fct_product_events.customer_id` to `dim_customers.customer_id` | Many events to one unique customer row |
| Subscription lifecycle by customer | `fct_subscription_events.customer_id` to `dim_customers.customer_id` | Many lifecycle events to one unique customer row |
| Plan change analysis | Event `from_plan_version_id` and `to_plan_version_id` joined separately to `dim_plan_versions.plan_version_id` | The same versioned dimension plays two named roles without collapsing history |

Invoice and product-event facts must not be joined directly at detailed row
level. A customer with several invoices and several product events would produce
every invoice-event combination. Each fact must first be aggregated to a shared
customer-and-period grain before their measures are combined.

## History behavior

| Model | History rule |
|---|---|
| `dim_customers` | One row retains the customer's signup and acquisition attributes. These fields are immutable in the approved synthetic contract; future mutable attributes require an explicit Type 1 or Type 2 decision before they are added. |
| `dim_plan_versions` | Never collapse versions to `plan_code`. Each `plan_version_id` preserves its own price and effective dates, allowing a fact to retain the commercial terms valid when it occurred. |
| `fct_subscriptions` | An accumulating snapshot representing the latest known milestones and status at the reporting cutoff. A rebuild may update milestone or current-status columns without changing `subscription_id`. |
| `fct_subscription_events` | Immutable event history. New lifecycle events add rows; existing event rows are not rewritten. |
| `fct_invoice_payment_outcomes` | An accumulating outcome at one row per invoice. Payment, recovery, refund, and net-collected fields may change as later attempts or refunds arrive. |
| `fct_product_events` | Immutable event history. New customer actions add rows; existing event rows are not rewritten. |

## BigQuery physical design

All Week 3 dimensions and facts are proposed as tables. A dbt build calculates
and stores their results once so repeated analytical queries read the published
model instead of rebuilding its complete upstream logic on every request.

| Model | Materialization | Partition | Cluster | Current-scale decision |
|---|---|---|---|---|
| `dim_customers` | Table | None | None | Roughly 50,000 descriptive rows do not justify physical subdivision. |
| `dim_plan_versions` | Table | None | None | Eight version rows are too small to benefit from partitioning or clustering. |
| `fct_subscriptions` | Table | None | None | Roughly 47,000 subscription rows remain small and are commonly read as a complete population. |
| `fct_subscription_events` | Table | None initially | None initially | Roughly 129,000 rows do not yet justify many small date partitions; re-evaluate after measuring growth and query patterns. |
| `fct_invoice_payment_outcomes` | Table | None initially | None initially | Roughly 129,000 already-aggregated rows remain inexpensive at the current portfolio scale; re-evaluate as invoice history grows. |
| `fct_product_events` | Table | `event_date` | `event_name`, then `customer_id` | Nearly two million rows and date/event filters provide a justified pruning path. |

`event_date` is derived from `occurred_at`. A date-range predicate allows
BigQuery to read only relevant date partitions. Within those partitions,
clustering by `event_name` helps skip unrelated event groups, while the second
cluster key supports customer-level filtering and grouping.

Partitioning is not applied automatically to every fact. Small facts would form
many tiny partitions with little expected benefit. The design records current
scale and will change only when measured query behavior supports the tradeoff.

## Efficiency evidence plan

After `fct_product_events` is built, run equivalent BigQuery dry runs against:

1. The unpartitioned product-event input.
2. The partitioned and clustered `fct_product_events` table.

Both queries will filter the same date range and `event_name`. Record estimated
bytes processed, the absolute and percentage difference, and the exact SQL.
This becomes the Week 3 evidence that a physical-design choice improved a real
query rather than merely adding configuration.

## Remaining design decisions

The following choices will be approved only after examining expected query
filters, table sizes, and update behavior:

- Exact columns published by each fact and dimension.
- Required generic and singular tests for each new model.
- Whether measured growth later justifies partitioning or clustering the smaller
  facts.
- The measured BigQuery dry-run result after `fct_product_events` exists.
