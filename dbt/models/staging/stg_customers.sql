with source as (

    select *
    from {{ source('skillspring_raw', 'customers') }}

),

renamed as (

    select
        customer_id,
        signup_at,
        date(signup_at) as signup_date,
        country_code,
        case
            when country_code in ('FI', 'SE') then 'northern_europe'
            when country_code in ('DE', 'FR', 'NL', 'IE') then 'western_europe'
            when country_code in ('ES', 'IT') then 'southern_europe'
            else 'unmapped'
        end as region,
        acquisition_channel,
        acquisition_campaign,
        device_type,
        learning_goal
    from source

)

select * from renamed
