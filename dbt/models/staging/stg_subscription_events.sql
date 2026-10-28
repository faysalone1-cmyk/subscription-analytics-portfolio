with source as (

    select *
    from {{ source('skillspring_raw', 'subscription_events') }}

),

renamed as (

    select
        subscription_event_id,
        subscription_id,
        event_sequence,
        event_at,
        date(event_at) as event_date,
        event_type,
        from_status,
        to_status,
        from_plan_version_id,
        to_plan_version_id,
        event_reason
    from source

)

select *
from renamed
