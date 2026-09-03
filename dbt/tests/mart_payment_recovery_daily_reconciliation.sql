-- This test passes only when daily mart rules and cross-layer totals reconcile.

with daily_failures as (

    select
        'daily_business_rule' as failure_type,
        cast(invoice_date as string) as failure_key
    from {{ ref('mart_payment_recovery_daily') }}
    where
        invoice_count
            != paid_invoice_count
                + open_unpaid_invoice_count
                + uncollectible_invoice_count
                + void_invoice_count

        or paid_invoice_count
            != paid_first_attempt_invoice_count + recovered_invoice_count

        or recovered_invoice_count > initially_failed_invoice_count

        or retried_invoice_count > initially_failed_invoice_count

        or refunded_invoice_count > paid_invoice_count

        or refund_transaction_count < refunded_invoice_count

        or refunded_eur > gross_collected_eur

        or net_collected_eur
            != gross_collected_eur - refunded_eur

        or collection_rate is distinct from safe_divide(
            paid_invoice_count,
            invoice_count
        )

        or first_attempt_success_rate is distinct from safe_divide(
            paid_first_attempt_invoice_count,
            invoice_count
        )

        or payment_recovery_rate is distinct from safe_divide(
            recovered_invoice_count,
            initially_failed_invoice_count
        )

        or collection_rate not between 0 and 1

        or first_attempt_success_rate not between 0 and 1

        or (
            payment_recovery_rate is not null
            and payment_recovery_rate not between 0 and 1
        )

),

mart_totals as (

    select
        sum(invoice_count) as invoice_count,
        sum(paid_invoice_count) as paid_invoice_count,
        sum(paid_first_attempt_invoice_count) as paid_first_attempt_invoice_count,
        sum(initially_failed_invoice_count) as initially_failed_invoice_count,
        sum(recovered_invoice_count) as recovered_invoice_count,
        sum(open_unpaid_invoice_count) as open_unpaid_invoice_count,
        sum(uncollectible_invoice_count) as uncollectible_invoice_count,
        sum(void_invoice_count) as void_invoice_count,
        sum(payment_attempt_count) as payment_attempt_count,
        sum(failed_payment_attempt_count) as failed_payment_attempt_count,
        sum(refunded_invoice_count) as refunded_invoice_count,
        sum(refund_transaction_count) as refund_transaction_count,
        sum(gross_billed_eur) as gross_billed_eur,
        sum(gross_collected_eur) as gross_collected_eur,
        sum(refunded_eur) as refunded_eur,
        sum(net_collected_eur) as net_collected_eur
    from {{ ref('mart_payment_recovery_daily') }}

),

intermediate_totals as (

    select
        count(*) as invoice_count,
        countif(is_paid) as paid_invoice_count,
        countif(is_paid_first_attempt) as paid_first_attempt_invoice_count,
        countif(failed_attempt_count > 0) as initially_failed_invoice_count,
        countif(is_recovered_payment) as recovered_invoice_count,
        countif(payment_outcome = 'open_unpaid') as open_unpaid_invoice_count,
        countif(payment_outcome = 'uncollectible') as uncollectible_invoice_count,
        countif(payment_outcome = 'void') as void_invoice_count,
        sum(attempt_count) as payment_attempt_count,
        sum(failed_attempt_count) as failed_payment_attempt_count,
        countif(has_refund) as refunded_invoice_count,
        sum(refund_count) as refund_transaction_count,
        sum(amount_due_eur) as gross_billed_eur,
        sum(amount_collected_eur) as gross_collected_eur,
        sum(total_refunded_eur) as refunded_eur,
        sum(net_collected_eur) as net_collected_eur
    from {{ ref('int_invoice_payment_outcomes') }}

),

cross_layer_failures as (

    select
        'cross_layer_reconciliation' as failure_type,
        'all_dates' as failure_key
    from mart_totals as m
    cross join intermediate_totals as i
    where
        m.invoice_count != i.invoice_count
        or m.paid_invoice_count != i.paid_invoice_count
        or m.paid_first_attempt_invoice_count
            != i.paid_first_attempt_invoice_count
        or m.initially_failed_invoice_count
            != i.initially_failed_invoice_count
        or m.recovered_invoice_count != i.recovered_invoice_count
        or m.open_unpaid_invoice_count != i.open_unpaid_invoice_count
        or m.uncollectible_invoice_count != i.uncollectible_invoice_count
        or m.void_invoice_count != i.void_invoice_count
        or m.payment_attempt_count != i.payment_attempt_count
        or m.failed_payment_attempt_count != i.failed_payment_attempt_count
        or m.refunded_invoice_count != i.refunded_invoice_count
        or m.refund_transaction_count != i.refund_transaction_count
        or m.gross_billed_eur != i.gross_billed_eur
        or m.gross_collected_eur != i.gross_collected_eur
        or m.refunded_eur != i.refunded_eur
        or m.net_collected_eur != i.net_collected_eur

)

select *
from daily_failures

union all

select *
from cross_layer_failures
