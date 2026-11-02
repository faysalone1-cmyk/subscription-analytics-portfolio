with source as (

    select *
    from {{ source('skillspring_raw', 'product_events') }}

),

renamed as (

    select
        product_event_id,
        customer_id,
        session_id,
        occurred_at,
        date(occurred_at) as event_date,
        date_trunc(date(occurred_at), month) as event_month,
        event_name,
        platform,
        onboarding_step,
        program_id,
        lesson_id
    from source

)

select *
from renamed
