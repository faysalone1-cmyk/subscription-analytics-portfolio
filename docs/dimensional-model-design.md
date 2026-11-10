# SkillSpring Dimensional Model Design

Status: Week 3 dimensional models implemented and validated; physical-design benchmark remains open

## Purpose

Record the implemented analytical grains, keys, join paths, history rules, and BigQuery
physical-design decisions for the Week 3 dimensional models.
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

## Implemented core model grains and keys

| Model | Role | Grain: one row per | Unique key | Repeatable foreign keys | Primary input |
|---|---|---|---|---|---|
| `dim_customers` | Conformed dimension | Customer | `customer_id` | None | `stg_customers` |
| `dim_plan_versions` | Versioned dimension | Commercial plan version | `plan_version_id` | None | `stg_plans` |
| `fct_subscriptions` | Accumulating process fact | Subscription instance | `subscription_id` | `customer_id`, `initial_plan_version_id`, `current_plan_version_id` | `stg_subscriptions` |
| `fct_subscription_events` | Transaction/event fact | Subscription lifecycle event | `subscription_event_id` | `subscription_id`, `customer_id`, `from_plan_version_id`, `to_plan_version_id` | `stg_subscription_events` plus `fct_subscriptions` |
| `int_invoice_payment_outcomes` | Accumulating outcome model | Invoice | `invoice_id` | `subscription_id`, `plan_version_id` | `stg_invoices`, `stg_payment_attempts`, and `stg_refunds` |
| `fct_product_events` | Transaction/event fact | Product event | `product_event_id` | `customer_id` | `stg_product_events` |

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
| Invoice outcomes by customer attributes | Join `int_invoice_payment_outcomes.subscription_id` through `fct_subscriptions` to `dim_customers` | Many invoices to one subscription and one unique customer row |
| Invoice outcomes by billed plan version | `int_invoice_payment_outcomes.plan_version_id` to `dim_plan_versions.plan_version_id` | Many invoices to one exact historical plan-version row |
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
| `int_invoice_payment_outcomes` | An accumulating outcome at one row per invoice. Payment, recovery, refund, and net-collected fields may change as later attempts or refunds arrive. |
| `fct_product_events` | Immutable event history. New customer actions add rows; existing event rows are not rewritten. |

## BigQuery physical design

The Week 3 dimensions and facts are implemented as tables. A dbt build calculates
and stores their results once so repeated analytical queries read the published
model instead of rebuilding its complete upstream logic on every request.

| Model | Materialization | Partition | Cluster | Current-scale decision |
|---|---|---|---|---|
| `dim_customers` | Table | None | None | Roughly 50,000 descriptive rows do not justify physical subdivision. |
| `dim_plan_versions` | Table | None | None | Eight version rows are too small to benefit from partitioning or clustering. |
| `fct_subscriptions` | Table | None | None | Roughly 47,000 subscription rows remain small and are commonly read as a complete population. |
| `fct_subscription_events` | Table | None initially | None initially | Roughly 129,000 rows do not yet justify many small date partitions; re-evaluate after measuring growth and query patterns. |
| `int_invoice_payment_outcomes` | View | None | None | Roughly 129,000 already-aggregated rows remain inexpensive at the current portfolio scale; re-evaluate as invoice history grows. |
| `fct_product_events` | Table | None currently | None currently | Nearly two million rows justify a measured partitioning and clustering benchmark before changing the physical design. |

`event_date` is derived from `occurred_at`. The intended benchmark will compare
the current table with a candidate partition on `event_date` and candidate
clusters on `event_name` and `customer_id` using equivalent filters.

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

- Whether measured growth later justifies partitioning or clustering the smaller
  facts.
- The measured BigQuery dry-run result and final physical design for
  `fct_product_events`.
