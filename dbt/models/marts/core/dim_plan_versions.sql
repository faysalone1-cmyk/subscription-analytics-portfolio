{{ config(materialized='table') }}

select
    plan_version_id,
    plan_code,
    plan_tier,
    billing_interval,
    price_minor_units,
    price_eur,
    currency_code,
    trial_days,
    valid_from,
    valid_to,
    is_current_plan_version
from {{ ref('stg_plans') }}
