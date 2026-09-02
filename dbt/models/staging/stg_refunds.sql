with source as (

    select *
    from {{ source('skillspring_raw', 'refunds') }}

),

renamed as (

    select
        refund_id,
        payment_attempt_id,
        refunded_at,
        amount_refunded_minor_units,
        cast(amount_refunded_minor_units as numeric) / 100 as amount_refunded_eur,
        currency_code,
        refund_reason
    from source

)

select * from renamed
