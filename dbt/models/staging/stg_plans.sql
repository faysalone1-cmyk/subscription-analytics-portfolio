with source as (

    select *
    from {{ source('skillspring_raw', 'plans') }}

),

renamed as (

    select
        plan_version_id,
        plan_code,
        plan_tier,
        billing_interval,
        price_minor_units,
        cast(price_minor_units as numeric) / 100 as price_eur,
        currency_code,
        trial_days,
        valid_from,
        valid_to,
        valid_to is null as is_current_plan_version
    from source

)

select * from renamed
