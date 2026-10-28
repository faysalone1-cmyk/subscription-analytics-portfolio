{{ config(materialized='table') }}

with events as (

    select *
    from {{ ref('stg_subscription_events') }}

),

subscriptions as (

    select
        subscription_id,
        customer_id
    from {{ ref('fct_subscriptions') }}

)

select
    events.subscription_event_id,
    events.subscription_id,
    subscriptions.customer_id,
    events.event_sequence,
    events.event_at,
    events.event_date,
    date_trunc(events.event_date, month) as event_month,
    events.event_type,
    events.from_status,
    events.to_status,
    events.from_plan_version_id,
    events.to_plan_version_id,
    events.event_reason
from events
inner join subscriptions
    on events.subscription_id = subscriptions.subscription_id
