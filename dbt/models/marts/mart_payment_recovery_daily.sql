with invoice_outcomes as (

    select *
    from {{ ref('int_invoice_payment_outcomes') }}

),

daily_payment_recovery as (

    select
        date(issued_at) as invoice_date,

        count(*) as invoice_count,
        countif(is_paid) as paid_invoice_count,
        countif(is_paid_first_attempt) as paid_first_attempt_invoice_count,
        countif(failed_attempt_count > 0) as initially_failed_invoice_count,
        countif(is_recovered_payment) as recovered_invoice_count,
        countif(payment_outcome = 'open_unpaid') as open_unpaid_invoice_count,
        countif(payment_outcome = 'uncollectible') as uncollectible_invoice_count,
        countif(payment_outcome = 'void') as void_invoice_count,
        countif(attempt_count > 1) as retried_invoice_count,

        sum(attempt_count) as payment_attempt_count,
        sum(failed_attempt_count) as failed_payment_attempt_count,
        countif(has_refund) as refunded_invoice_count,
        sum(refund_count) as refund_transaction_count,

        sum(amount_due_eur) as gross_billed_eur,
        sum(amount_collected_eur) as gross_collected_eur,
        sum(total_refunded_eur) as refunded_eur,
        sum(net_collected_eur) as net_collected_eur,

        safe_divide(
            countif(is_paid),
            count(*)
        ) as collection_rate,

        safe_divide(
            countif(is_paid_first_attempt),
            count(*)
        ) as first_attempt_success_rate,

        safe_divide(
            countif(is_recovered_payment),
            countif(failed_attempt_count > 0)
        ) as payment_recovery_rate

    from invoice_outcomes
    group by invoice_date

)

select *
from daily_payment_recovery
