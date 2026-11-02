{{ config(materialized='table') }}

with events as (

    select *
    from {{ ref('stg_product_events') }}

)

select
    product_event_id,
    customer_id,
    session_id,
    occurred_at,
    event_date,
    event_month,
    event_name,
    platform,
    onboarding_step,
    program_id,
    lesson_id
from events
