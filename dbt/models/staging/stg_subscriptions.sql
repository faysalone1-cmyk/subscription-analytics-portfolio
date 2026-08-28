with source as (

    select *
    from {{ source('skillspring_raw', 'subscriptions') }}

),

renamed as (

    select
        subscription_id,
        customer_id,
        initial_plan_version_id,
        current_plan_version_id,
        created_at,
        trial_started_at,
        trial_scheduled_end_at,
        paid_started_at,
        current_period_start_at,
        current_period_end_at,
        current_status,
        cancel_requested_at,
        ended_at,
        paid_started_at is not null as converted_to_paid,
        current_status = 'canceled' as is_canceled
    from source

)

select * from renamed
