-- Validate the refund grain, governed transformation, and cross-entity business rules.

with refund_checks as (

    select
        count(*) as staged_rows,
        count(distinct r.refund_id) as distinct_refund_ids,
        countif(
            r.amount_refunded_eur
            != cast(r.amount_refunded_minor_units as numeric) / 100
        ) as amount_conversion_mismatches,
        countif(r.amount_refunded_minor_units <= 0) as non_positive_refunds,
        countif(p.payment_attempt_id is null) as missing_payment_attempts,
        countif(
            p.payment_attempt_id is not null
            and p.payment_status != 'succeeded'
        ) as non_successful_payment_attempts,
        countif(
            p.payment_attempt_id is not null
            and r.refunded_at < p.attempted_at
        ) as refunds_before_payment,
        countif(
            p.payment_attempt_id is not null
            and r.currency_code != p.currency_code
        ) as currency_mismatches
    from `skillspring-analytics.skillspring_analytics.stg_refunds` as r
    left join `skillspring-analytics.skillspring_analytics.stg_payment_attempts` as p
        on r.payment_attempt_id = p.payment_attempt_id

),

refund_totals as (

    select
        payment_attempt_id,
        sum(amount_refunded_minor_units) as total_refunded_minor_units
    from `skillspring-analytics.skillspring_analytics.stg_refunds`
    group by payment_attempt_id

),

over_refund_checks as (

    select
        countif(
            rt.total_refunded_minor_units > p.amount_attempted_minor_units
        ) as over_refunded_payment_attempts
    from refund_totals as rt
    left join `skillspring-analytics.skillspring_analytics.stg_payment_attempts` as p
        on rt.payment_attempt_id = p.payment_attempt_id

)

select *
from refund_checks
cross join over_refund_checks
