{{ config(materialized='table') }}

select
    customer_id,
    signup_at,
    signup_date,
    date_trunc(signup_date, month) as signup_month,
    country_code,
    region,
    acquisition_channel,
    acquisition_campaign,
    device_type,
    learning_goal
from {{ ref('stg_customers') }}
