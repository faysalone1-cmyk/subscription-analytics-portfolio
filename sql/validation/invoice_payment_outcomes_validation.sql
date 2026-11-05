with invoice_outcomes as (

    select *
    from `skillspring-analytics.skillspring_analytics.int_invoice_payment_outcomes`

),

invoices as (

    select *
    from `skillspring-analytics.skillspring_analytics.stg_invoices`

),

payment_attempts as (

    select *
    from `skillspring-analytics.skillspring_analytics.stg_payment_attempts`

),

refunds as (

    select *
    from `skillspring-analytics.skillspring_analytics.stg_refunds`

),

daily_mart as (

    select *
    from `skillspring-analytics.skillspring_analytics.mart_payment_recovery_daily`

),

expected_attempts as (

    select
        invoice_id,
        count(*) as attempt_count,
        countif(not is_successful) as failed_attempt_count,
        countif(is_successful) as successful_attempt_count,
        max(attempt_number) as latest_attempt_number,
        sum(if(is_successful, amount_attempted_minor_units, 0))
            as amount_collected_minor_units
    from payment_attempts
    group by invoice_id

),

expected_refunds as (

    select
        payment_attempts.invoice_id,
        count(refunds.refund_id) as refund_count,
        sum(refunds.amount_refunded_minor_units) as total_refunded_minor_units
    from refunds
    inner join payment_attempts
        using (payment_attempt_id)
    group by payment_attempts.invoice_id

),

expected_daily as (

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
        sum(net_collected_eur) as net_collected_eur
    from invoice_outcomes
    group by invoice_date

),

checks as (

    select
        'grain' as check_group,
        'row_count_difference_from_invoices' as check_name,
        abs(
            (select count(*) from invoice_outcomes)
            - (select count(*) from invoices)
        ) as violation_count

    union all

    select
        'grain',
        'duplicate_invoice_ids',
        count(*) - count(distinct invoice_id)
    from invoice_outcomes

    union all

    select
        'alignment',
        'missing_or_changed_invoice_rows',
        countif(
            invoices.invoice_id is null
            or invoice_outcomes.subscription_id is distinct from invoices.subscription_id
            or invoice_outcomes.plan_version_id is distinct from invoices.plan_version_id
            or invoice_outcomes.amount_due_minor_units is distinct from invoices.amount_due_minor_units
            or invoice_outcomes.invoice_status is distinct from invoices.invoice_status
            or invoice_outcomes.is_paid is distinct from invoices.is_paid
        )
    from invoice_outcomes
    left join invoices
        using (invoice_id)

    union all

    select
        'attempts',
        'attempt_aggregation_mismatches',
        countif(
            invoice_outcomes.attempt_count
                is distinct from coalesce(expected_attempts.attempt_count, 0)
            or invoice_outcomes.failed_attempt_count
                is distinct from coalesce(expected_attempts.failed_attempt_count, 0)
            or invoice_outcomes.successful_attempt_count
                is distinct from coalesce(expected_attempts.successful_attempt_count, 0)
            or invoice_outcomes.latest_attempt_number
                is distinct from coalesce(expected_attempts.latest_attempt_number, 0)
            or invoice_outcomes.amount_collected_minor_units
                is distinct from coalesce(expected_attempts.amount_collected_minor_units, 0)
        )
    from invoice_outcomes
    left join expected_attempts
        using (invoice_id)

    union all

    select
        'refunds',
        'refund_aggregation_mismatches',
        countif(
            invoice_outcomes.refund_count
                is distinct from coalesce(expected_refunds.refund_count, 0)
            or invoice_outcomes.total_refunded_minor_units
                is distinct from coalesce(expected_refunds.total_refunded_minor_units, 0)
        )
    from invoice_outcomes
    left join expected_refunds
        using (invoice_id)

    union all

    select
        'classification',
        'payment_outcome_mismatches',
        countif(
            payment_outcome is distinct from case
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
            end
        )
    from invoice_outcomes

    union all

    select
        'classification',
        'refund_status_mismatches',
        countif(
            refund_status is distinct from case
                when total_refunded_minor_units = 0 then 'not_refunded'
                when total_refunded_minor_units < amount_collected_minor_units
                    then 'partially_refunded'
                when total_refunded_minor_units = amount_collected_minor_units
                    and amount_collected_minor_units > 0
                    then 'fully_refunded'
                else 'review_required'
            end
        )
    from invoice_outcomes

    union all

    select
        'money',
        'invoice_money_reconciliation_mismatches',
        countif(
            amount_collected_minor_units != if(is_paid, amount_due_minor_units, 0)
            or total_refunded_minor_units > amount_collected_minor_units
            or net_collected_minor_units
                != amount_collected_minor_units - total_refunded_minor_units
            or amount_due_eur != cast(amount_due_minor_units as numeric) / 100
            or amount_collected_eur != cast(amount_collected_minor_units as numeric) / 100
            or total_refunded_eur != cast(total_refunded_minor_units as numeric) / 100
            or net_collected_eur != cast(net_collected_minor_units as numeric) / 100
        )
    from invoice_outcomes

    union all

    select
        'mart',
        'daily_row_count_difference',
        abs(
            (select count(*) from daily_mart)
            - (select count(*) from expected_daily)
        )

    union all

    select
        'mart',
        'daily_metric_mismatches',
        countif(
            daily_mart.invoice_date is null
            or daily_mart.invoice_count != expected_daily.invoice_count
            or daily_mart.paid_invoice_count != expected_daily.paid_invoice_count
            or daily_mart.paid_first_attempt_invoice_count
                != expected_daily.paid_first_attempt_invoice_count
            or daily_mart.initially_failed_invoice_count
                != expected_daily.initially_failed_invoice_count
            or daily_mart.recovered_invoice_count != expected_daily.recovered_invoice_count
            or daily_mart.open_unpaid_invoice_count != expected_daily.open_unpaid_invoice_count
            or daily_mart.uncollectible_invoice_count != expected_daily.uncollectible_invoice_count
            or daily_mart.void_invoice_count != expected_daily.void_invoice_count
            or daily_mart.retried_invoice_count != expected_daily.retried_invoice_count
            or daily_mart.payment_attempt_count != expected_daily.payment_attempt_count
            or daily_mart.failed_payment_attempt_count
                != expected_daily.failed_payment_attempt_count
            or daily_mart.refunded_invoice_count != expected_daily.refunded_invoice_count
            or daily_mart.refund_transaction_count != expected_daily.refund_transaction_count
            or daily_mart.gross_billed_eur != expected_daily.gross_billed_eur
            or daily_mart.gross_collected_eur != expected_daily.gross_collected_eur
            or daily_mart.refunded_eur != expected_daily.refunded_eur
            or daily_mart.net_collected_eur != expected_daily.net_collected_eur
        )
    from expected_daily
    left join daily_mart
        using (invoice_date)

)

select
    check_group,
    check_name,
    violation_count,
    violation_count = 0 as passed
from checks
order by
    check_group,
    check_name
