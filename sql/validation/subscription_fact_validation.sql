-- Independently validate the fct_subscriptions grain, transformations, and joins.

with fact as (

    select *
    from `skillspring-analytics.skillspring_analytics.fct_subscriptions`

),

staged as (

    select *
    from `skillspring-analytics.skillspring_analytics.stg_subscriptions`

),

validated as (

    select
        fact.*,
        customers.customer_id as matched_customer_id,
        initial_plans.plan_version_id as matched_initial_plan_version_id,
        current_plans.plan_version_id as matched_current_plan_version_id
    from fact
    left join `skillspring-analytics.skillspring_analytics.dim_customers` as customers
        on fact.customer_id = customers.customer_id
    left join `skillspring-analytics.skillspring_analytics.dim_plan_versions` as initial_plans
        on fact.initial_plan_version_id = initial_plans.plan_version_id
    left join `skillspring-analytics.skillspring_analytics.dim_plan_versions` as current_plans
        on fact.current_plan_version_id = current_plans.plan_version_id

),

checks as (

    select
        'grain' as check_group,
        'row_count_difference_from_staging' as check_name,
        abs(count(*) - (select count(*) from staged)) as violation_count
    from validated

    union all

    select 'grain', 'duplicate_subscription_ids', count(*) - count(distinct subscription_id)
    from validated

    union all

    select 'derivation', 'created_date_mismatches',
        countif(created_date is distinct from date(created_at))
    from validated

    union all

    select 'derivation', 'created_month_mismatches',
        countif(created_month is distinct from date_trunc(date(created_at), month))
    from validated

    union all

    select 'derivation', 'conversion_flag_mismatches',
        countif(converted_to_paid is distinct from (paid_started_at is not null))
    from validated

    union all

    select 'derivation', 'cancellation_flag_mismatches',
        countif(is_canceled is distinct from (current_status = 'canceled'))
    from validated

    union all

    select 'derivation', 'trial_to_paid_day_mismatches',
        countif(
            trial_to_paid_days is distinct from
            case
                when paid_started_at is not null and trial_started_at is not null
                    then timestamp_diff(paid_started_at, trial_started_at, day)
            end
        )
    from validated

    union all

    select 'derivation', 'completed_lifetime_day_mismatches',
        countif(
            completed_lifetime_days is distinct from
            case
                when ended_at is not null
                    then timestamp_diff(ended_at, created_at, day)
            end
        )
    from validated

    union all

    select 'validity', 'invalid_current_period_ranges',
        countif(
            (current_status in ('active', 'past_due')
                and (current_period_start_at is null or current_period_end_at is null))
            or (current_period_start_at is null) != (current_period_end_at is null)
            or current_period_end_at <= current_period_start_at
        )
    from validated

    union all

    select 'relationship', 'missing_customer_dimension_rows',
        countif(matched_customer_id is null)
    from validated

    union all

    select 'relationship', 'missing_initial_plan_dimension_rows',
        countif(matched_initial_plan_version_id is null)
    from validated

    union all

    select 'relationship', 'missing_current_plan_dimension_rows',
        countif(matched_current_plan_version_id is null)
    from validated

)

select
    check_group,
    check_name,
    violation_count,
    violation_count = 0 as passed
from checks
order by check_group, check_name
