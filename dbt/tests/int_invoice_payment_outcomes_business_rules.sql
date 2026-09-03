-- This test passes only when it returns zero invalid invoice rows.

select
    invoice_id,
    invoice_status,
    attempt_count,
    failed_attempt_count,
    successful_attempt_count,
    amount_due_minor_units,
    amount_collected_minor_units,
    total_refunded_minor_units,
    net_collected_minor_units,
    payment_outcome,
    refund_status
from {{ ref('int_invoice_payment_outcomes') }}
where
    attempt_count
        != failed_attempt_count + successful_attempt_count

    or latest_attempt_number != attempt_count

    or successful_attempt_count > 1

    or is_paid is distinct from (successful_attempt_count = 1)

    or is_paid_first_attempt is distinct from (
        successful_attempt_count = 1
        and failed_attempt_count = 0
    )

    or is_recovered_payment is distinct from (
        successful_attempt_count = 1
        and failed_attempt_count > 0
    )

    or has_refund is distinct from (refund_count > 0)

    or amount_collected_minor_units
        != if(is_paid, amount_due_minor_units, 0)

    or total_refunded_minor_units > amount_collected_minor_units

    or net_collected_minor_units
        != amount_collected_minor_units - total_refunded_minor_units

    or amount_collected_eur
        != cast(amount_collected_minor_units as numeric) / 100

    or total_refunded_eur
        != cast(total_refunded_minor_units as numeric) / 100

    or net_collected_eur
        != cast(net_collected_minor_units as numeric) / 100

    or (
        is_paid
        and successful_payment_attempt_id is null
    )

    or (
        not is_paid
        and successful_payment_attempt_id is not null
    )

    or payment_outcome = 'review_required'

    or refund_status = 'review_required'
