with source as (

    select *
    from {{ source('skillspring_raw', 'payment_attempts') }}

),

renamed as (

    select
        payment_attempt_id,
        invoice_id,
        attempt_number,
        attempted_at,
        amount_attempted_minor_units,
        cast(amount_attempted_minor_units as numeric) / 100 as amount_attempted_eur,
        currency_code,
        payment_status,
        failure_reason,
        attempt_number > 1 as is_retry,
        payment_status = 'succeeded' as is_successful
    from source

)

select * from renamed
