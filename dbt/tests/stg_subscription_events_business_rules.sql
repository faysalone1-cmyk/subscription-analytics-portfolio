-- Zero rows means every lifecycle event follows the approved transition contract.

with events as (

    select *
    from {{ ref('stg_subscription_events') }}

),

invalid_transitions as (

    select *
    from events
    where
        (
            event_type = 'trial_started'
            and not (
                event_sequence = 1
                and from_status is null
                and to_status = 'trialing'
                and from_plan_version_id is null
                and to_plan_version_id is not null
            )
        )
        or (
            event_type = 'trial_converted'
            and not (
                from_status = 'trialing'
                and to_status = 'active'
                and from_plan_version_id = to_plan_version_id
            )
        )
        or (
            event_type = 'plan_changed'
            and not (
                from_status = 'active'
                and to_status = 'active'
                and from_plan_version_id != to_plan_version_id
            )
        )
        or (
            event_type = 'past_due'
            and not (
                from_status = 'active'
                and to_status = 'past_due'
                and from_plan_version_id = to_plan_version_id
            )
        )
        or (
            event_type = 'payment_recovered'
            and not (
                from_status = 'past_due'
                and to_status = 'active'
                and from_plan_version_id = to_plan_version_id
            )
        )
        or (
            event_type in ('cancel_requested', 'cancellation_revoked')
            and not (
                from_status = 'active'
                and to_status = 'active'
                and from_plan_version_id = to_plan_version_id
            )
        )
        or (
            event_type = 'canceled'
            and not (
                from_status in ('trialing', 'active', 'past_due')
                and to_status = 'canceled'
                and from_plan_version_id = to_plan_version_id
            )
        )

),

invalid_sequences as (

    select
        subscription_id
    from events
    group by subscription_id
    having min(event_sequence) != 1
        or max(event_sequence) != count(*)
        or count(*) != count(distinct event_sequence)

)

select
    subscription_event_id,
    subscription_id,
    event_type
from invalid_transitions
union all
select
    cast(null as string) as subscription_event_id,
    subscription_id,
    'invalid_sequence' as event_type
from invalid_sequences
