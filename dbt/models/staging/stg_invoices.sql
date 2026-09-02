with source as (

    select *
    from {{ source('skillspring_raw', 'invoices') }}

),

renamed as (

    select
        invoice_id,
        subscription_id,
        plan_version_id,
        billing_reason,
        billing_period_start,
        billing_period_end,
        issued_at,
        due_at,
        amount_due_minor_units,
        cast(amount_due_minor_units as numeric) / 100 as amount_due_eur,
        currency_code,
        invoice_status,
        paid_at,
        invoice_status = 'paid' as is_paid
    from source

)

select * from renamed
