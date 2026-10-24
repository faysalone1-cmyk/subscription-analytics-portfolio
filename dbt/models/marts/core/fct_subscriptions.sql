{{ config(materialized='table') }}

with subscriptions as (

    select *
    from {{ ref('stg_subscriptions') }}

)

select
    subscription_id,
    customer_id,
    initial_plan_version_id,
    current_plan_version_id,
    created_at,
    date(created_at) as created_date,
    date_trunc(date(created_at), month) as created_month,
    trial_started_at,
    trial_scheduled_end_at,
    paid_started_at,
    current_period_start_at,
    current_period_end_at,
    current_status,
    cancel_requested_at,
    ended_at,
    converted_to_paid,
    is_canceled,
    case
        when paid_started_at is not null
            and trial_started_at is not null
            then timestamp_diff(paid_started_at, trial_started_at, day)
    end as trial_to_paid_days,
    case
        when ended_at is not null
            then timestamp_diff(ended_at, created_at, day)
    end as completed_lifetime_days
from subscriptions
