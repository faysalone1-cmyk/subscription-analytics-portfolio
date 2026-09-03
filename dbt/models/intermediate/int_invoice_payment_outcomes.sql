with invoices as (

    select *
    from {{ ref('stg_invoices') }}

),

payment_attempts as (

    select *
    from {{ ref('stg_payment_attempts') }}

),

refunds as (

    select *
    from {{ ref('stg_refunds') }}

),

attempt_summary as (

    select
        invoice_id,
        count(*) as attempt_count,
        countif(not is_successful) as failed_attempt_count,
        countif(is_successful) as successful_attempt_count,
        max(attempt_number) as latest_attempt_number,
        min(attempted_at) as first_attempted_at,
        max(attempted_at) as last_attempted_at,
        min(if(is_successful, attempted_at, null)) as successful_attempted_at,
        max(if(is_successful, payment_attempt_id, null)) as successful_payment_attempt_id,
        sum(
            if(is_successful, amount_attempted_minor_units, 0)
        ) as amount_collected_minor_units,
        sum(
            if(is_successful, amount_attempted_eur, cast(0 as numeric))
        ) as amount_collected_eur
    from payment_attempts
    group by invoice_id

),

refund_summary as (

    select
        p.invoice_id,
        count(r.refund_id) as refund_count,
        sum(r.amount_refunded_minor_units) as total_refunded_minor_units,
        sum(r.amount_refunded_eur) as total_refunded_eur,
        min(r.refunded_at) as first_refunded_at,
        max(r.refunded_at) as last_refunded_at
    from refunds as r
    inner join payment_attempts as p
        on r.payment_attempt_id = p.payment_attempt_id
    group by p.invoice_id

),

combined as (

    select
        i.invoice_id,
        i.subscription_id,
        i.plan_version_id,
        i.billing_reason,
        i.billing_period_start,
        i.billing_period_end,
        i.issued_at,
        i.due_at,
        i.amount_due_minor_units,
        i.amount_due_eur,
        i.currency_code,
        i.invoice_status,
        i.paid_at,
        i.is_paid,
        coalesce(a.attempt_count, 0) as attempt_count,
        coalesce(a.failed_attempt_count, 0) as failed_attempt_count,
        coalesce(a.successful_attempt_count, 0) as successful_attempt_count,
        coalesce(a.latest_attempt_number, 0) as latest_attempt_number,
        a.first_attempted_at,
        a.last_attempted_at,
        a.successful_attempted_at,
        a.successful_payment_attempt_id,
        coalesce(a.amount_collected_minor_units, 0) as amount_collected_minor_units,
        coalesce(a.amount_collected_eur, cast(0 as numeric)) as amount_collected_eur,
        coalesce(r.refund_count, 0) as refund_count,
        coalesce(r.total_refunded_minor_units, 0) as total_refunded_minor_units,
        coalesce(r.total_refunded_eur, cast(0 as numeric)) as total_refunded_eur,
        r.first_refunded_at,
        r.last_refunded_at
    from invoices as i
    left join attempt_summary as a
        on i.invoice_id = a.invoice_id
    left join refund_summary as r
        on i.invoice_id = r.invoice_id

)

select
    *,
    successful_attempt_count = 1
        and failed_attempt_count = 0 as is_paid_first_attempt,
    successful_attempt_count = 1
        and failed_attempt_count > 0 as is_recovered_payment,
    refund_count > 0 as has_refund,
    amount_collected_minor_units
        - total_refunded_minor_units as net_collected_minor_units,
    amount_collected_eur
        - total_refunded_eur as net_collected_eur,
    case
        when successful_attempt_count = 1 and failed_attempt_count = 0
            then 'paid_first_attempt'
        when successful_attempt_count = 1 and failed_attempt_count > 0
            then 'recovered_after_failure'
        when invoice_status = 'open' and successful_attempt_count = 0
            then 'open_unpaid'
        when invoice_status = 'uncollectible' and successful_attempt_count = 0
            then 'uncollectible'
        when invoice_status = 'void' and successful_attempt_count = 0
            then 'void'
        else 'review_required'
    end as payment_outcome,
    case
        when total_refunded_minor_units = 0
            then 'not_refunded'
        when total_refunded_minor_units < amount_collected_minor_units
            then 'partially_refunded'
        when total_refunded_minor_units = amount_collected_minor_units
            and amount_collected_minor_units > 0
            then 'fully_refunded'
        else 'review_required'
    end as refund_status
from combined
