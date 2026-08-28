-- Validate the loaded SkillSpring raw layer against the deterministic manifest
-- and the most important approved cross-table rules.

with
row_count_checks as (
    select 'row_count' as check_group, 'customers' as check_name, count(*) as actual_value, 50000 as expected_value
    from `skillspring-analytics.skillspring_raw.customers`
    union all
    select 'row_count', 'plans', count(*), 8
    from `skillspring-analytics.skillspring_raw.plans`
    union all
    select 'row_count', 'subscriptions', count(*), 46810
    from `skillspring-analytics.skillspring_raw.subscriptions`
    union all
    select 'row_count', 'subscription_events', count(*), 128957
    from `skillspring-analytics.skillspring_raw.subscription_events`
    union all
    select 'row_count', 'invoices', count(*), 128633
    from `skillspring-analytics.skillspring_raw.invoices`
    union all
    select 'row_count', 'payment_attempts', count(*), 148006
    from `skillspring-analytics.skillspring_raw.payment_attempts`
    union all
    select 'row_count', 'refunds', count(*), 4093
    from `skillspring-analytics.skillspring_raw.refunds`
    union all
    select 'row_count', 'product_events', count(*), 1998136
    from `skillspring-analytics.skillspring_raw.product_events`
    union all
    select 'row_count', 'experiment_assignments', count(*), 8220
    from `skillspring-analytics.skillspring_raw.experiment_assignments`
),
uniqueness_checks as (
    select 'uniqueness' as check_group, 'duplicate_customer_id' as check_name,
        count(*) - count(distinct customer_id) as actual_value, 0 as expected_value
    from `skillspring-analytics.skillspring_raw.customers`
    union all
    select 'uniqueness', 'duplicate_subscription_id', count(*) - count(distinct subscription_id), 0
    from `skillspring-analytics.skillspring_raw.subscriptions`
    union all
    select 'uniqueness', 'duplicate_subscription_event_id', count(*) - count(distinct subscription_event_id), 0
    from `skillspring-analytics.skillspring_raw.subscription_events`
    union all
    select 'uniqueness', 'duplicate_invoice_id', count(*) - count(distinct invoice_id), 0
    from `skillspring-analytics.skillspring_raw.invoices`
    union all
    select 'uniqueness', 'duplicate_payment_attempt_id', count(*) - count(distinct payment_attempt_id), 0
    from `skillspring-analytics.skillspring_raw.payment_attempts`
    union all
    select 'uniqueness', 'duplicate_refund_id', count(*) - count(distinct refund_id), 0
    from `skillspring-analytics.skillspring_raw.refunds`
    union all
    select 'uniqueness', 'duplicate_product_event_id', count(*) - count(distinct product_event_id), 0
    from `skillspring-analytics.skillspring_raw.product_events`
    union all
    select 'uniqueness', 'duplicate_experiment_assignment',
        count(*) - count(distinct concat(customer_id, '#', experiment_id)), 0
    from `skillspring-analytics.skillspring_raw.experiment_assignments`
),
relationship_checks as (
    select 'relationship' as check_group, 'subscriptions_without_customer' as check_name,
        countif(c.customer_id is null) as actual_value, 0 as expected_value
    from `skillspring-analytics.skillspring_raw.subscriptions` s
    left join `skillspring-analytics.skillspring_raw.customers` c using (customer_id)
    union all
    select 'relationship', 'events_without_subscription', countif(s.subscription_id is null), 0
    from `skillspring-analytics.skillspring_raw.subscription_events` e
    left join `skillspring-analytics.skillspring_raw.subscriptions` s using (subscription_id)
    union all
    select 'relationship', 'invoices_without_subscription', countif(s.subscription_id is null), 0
    from `skillspring-analytics.skillspring_raw.invoices` i
    left join `skillspring-analytics.skillspring_raw.subscriptions` s using (subscription_id)
    union all
    select 'relationship', 'attempts_without_invoice', countif(i.invoice_id is null), 0
    from `skillspring-analytics.skillspring_raw.payment_attempts` a
    left join `skillspring-analytics.skillspring_raw.invoices` i using (invoice_id)
    union all
    select 'relationship', 'refunds_without_successful_attempt', countif(a.payment_attempt_id is null or a.payment_status != 'succeeded'), 0
    from `skillspring-analytics.skillspring_raw.refunds` r
    left join `skillspring-analytics.skillspring_raw.payment_attempts` a using (payment_attempt_id)
    union all
    select 'relationship', 'product_events_without_customer', countif(c.customer_id is null), 0
    from `skillspring-analytics.skillspring_raw.product_events` e
    left join `skillspring-analytics.skillspring_raw.customers` c using (customer_id)
    union all
    select 'relationship', 'assignments_without_customer', countif(c.customer_id is null), 0
    from `skillspring-analytics.skillspring_raw.experiment_assignments` a
    left join `skillspring-analytics.skillspring_raw.customers` c using (customer_id)
),
attempt_summary as (
    select invoice_id, countif(payment_status = 'succeeded') as successful_attempts
    from `skillspring-analytics.skillspring_raw.payment_attempts`
    group by invoice_id
),
payment_check as (
    select 'reconciliation' as check_group, 'invoice_payment_status_mismatch' as check_name,
        countif(
            (i.invoice_status = 'paid' and coalesce(a.successful_attempts, 0) != 1)
            or (i.invoice_status != 'paid' and coalesce(a.successful_attempts, 0) != 0)
        ) as actual_value,
        0 as expected_value
    from `skillspring-analytics.skillspring_raw.invoices` i
    left join attempt_summary a using (invoice_id)
),
refund_summary as (
    select payment_attempt_id, sum(amount_refunded_minor_units) as refunded_amount
    from `skillspring-analytics.skillspring_raw.refunds`
    group by payment_attempt_id
),
refund_check as (
    select 'reconciliation' as check_group, 'refund_amount_exceeds_payment' as check_name,
        countif(r.refunded_amount > a.amount_attempted_minor_units) as actual_value,
        0 as expected_value
    from refund_summary r
    join `skillspring-analytics.skillspring_raw.payment_attempts` a using (payment_attempt_id)
),
latest_events as (
    select * except (event_rank)
    from (
        select
            subscription_id,
            to_status,
            to_plan_version_id,
            row_number() over (
                partition by subscription_id
                order by event_sequence desc
            ) as event_rank
        from `skillspring-analytics.skillspring_raw.subscription_events`
    )
    where event_rank = 1
),
snapshot_check as (
    select 'reconciliation' as check_group, 'subscription_snapshot_mismatch' as check_name,
        countif(
            s.current_status is distinct from e.to_status
            or s.current_plan_version_id is distinct from e.to_plan_version_id
        ) as actual_value,
        0 as expected_value
    from `skillspring-analytics.skillspring_raw.subscriptions` s
    join latest_events e using (subscription_id)
),
all_checks as (
    select * from row_count_checks
    union all select * from uniqueness_checks
    union all select * from relationship_checks
    union all select * from payment_check
    union all select * from refund_check
    union all select * from snapshot_check
)
select
    check_group,
    check_name,
    actual_value,
    expected_value,
    actual_value = expected_value as passed
from all_checks
order by check_group, check_name
