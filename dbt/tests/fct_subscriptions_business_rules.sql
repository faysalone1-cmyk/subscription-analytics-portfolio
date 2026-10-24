-- Zero rows means the subscription milestones obey the approved lifecycle rules.
select
    subscription_id,
    current_status,
    created_at,
    trial_started_at,
    trial_scheduled_end_at,
    paid_started_at,
    current_period_start_at,
    current_period_end_at,
    ended_at
from {{ ref('fct_subscriptions') }}
where
    trial_started_at < created_at
    or trial_scheduled_end_at <= trial_started_at
    or paid_started_at < trial_started_at
    or ended_at < created_at
    or ended_at < trial_started_at
    or ended_at < paid_started_at
    or (
        current_status in ('active', 'past_due')
        and (
            paid_started_at is null
            or current_period_start_at is null
            or current_period_end_at is null
        )
    )
    or (current_period_start_at is null) != (current_period_end_at is null)
    or current_period_end_at <= current_period_start_at
    or current_period_start_at < paid_started_at
    or (current_status = 'canceled' and ended_at is null)
    or (current_status != 'canceled' and ended_at is not null)
    or (current_status = 'trialing' and paid_started_at is not null)
    or cancel_requested_at < created_at
    or cancel_requested_at > ended_at
