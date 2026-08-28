-- Validate grain preservation and the initial staging transformations.

with checks as (
    select 'row_count' as check_group, 'stg_customers' as check_name,
        count(*) as actual_value, 50000 as expected_value
    from `skillspring-analytics.skillspring_analytics.stg_customers`
    union all
    select 'row_count', 'stg_subscriptions', count(*), 46810
    from `skillspring-analytics.skillspring_analytics.stg_subscriptions`
    union all
    select 'row_count', 'stg_payment_attempts', count(*), 148006
    from `skillspring-analytics.skillspring_analytics.stg_payment_attempts`
    union all
    select 'transformation', 'unmapped_customer_region', countif(region = 'unmapped'), 0
    from `skillspring-analytics.skillspring_analytics.stg_customers`
    union all
    select 'transformation', 'incorrect_euro_conversion',
        countif(amount_attempted_eur * 100 != amount_attempted_minor_units), 0
    from `skillspring-analytics.skillspring_analytics.stg_payment_attempts`
    union all
    select 'transformation', 'incorrect_retry_flag',
        countif(is_retry != (attempt_number > 1)), 0
    from `skillspring-analytics.skillspring_analytics.stg_payment_attempts`
    union all
    select 'transformation', 'incorrect_success_flag',
        countif(is_successful != (payment_status = 'succeeded')), 0
    from `skillspring-analytics.skillspring_analytics.stg_payment_attempts`
    union all
    select 'transformation', 'incorrect_paid_conversion_flag',
        countif(converted_to_paid != (paid_started_at is not null)), 0
    from `skillspring-analytics.skillspring_analytics.stg_subscriptions`
    union all
    select 'transformation', 'incorrect_canceled_flag',
        countif(is_canceled != (current_status = 'canceled')), 0
    from `skillspring-analytics.skillspring_analytics.stg_subscriptions`
)
select
    check_group,
    check_name,
    actual_value,
    expected_value,
    actual_value = expected_value as passed
from checks
order by check_group, check_name
