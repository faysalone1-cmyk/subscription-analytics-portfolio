with fact as (

    select *
    from `skillspring-analytics.skillspring_analytics.fct_subscription_events`

),

staging as (

    select *
    from `skillspring-analytics.skillspring_analytics.stg_subscription_events`

),

subscriptions as (

    select
        subscription_id,
        customer_id
    from `skillspring-analytics.skillspring_analytics.fct_subscriptions`

),

sequence_violations as (

    select
        subscription_id
    from fact
    group by subscription_id
    having min(event_sequence) != 1
        or max(event_sequence) != count(*)
        or count(*) != count(distinct event_sequence)

),

checks as (

    select
        'grain' as check_group,
        'duplicate_event_ids' as check_name,
        count(*) - count(distinct subscription_event_id) as violation_count
    from fact

    union all

    select
        'grain',
        'row_count_difference_from_staging',
        abs(
            (select count(*) from fact)
            - (select count(*) from staging)
        )

    union all

    select
        'derivation',
        'event_date_mismatches',
        countif(event_date != date(event_at))
    from fact

    union all

    select
        'derivation',
        'event_month_mismatches',
        countif(event_month != date_trunc(event_date, month))
    from fact

    union all

    select
        'derivation',
        'customer_enrichment_mismatches',
        countif(
            subscriptions.subscription_id is null
            or fact.customer_id is distinct from subscriptions.customer_id
        )
    from fact
    left join subscriptions
        on fact.subscription_id = subscriptions.subscription_id

    union all

    select
        'alignment',
        'staging_projection_mismatches',
        countif(
            staging.subscription_event_id is null
            or fact.subscription_id is distinct from staging.subscription_id
            or fact.event_sequence is distinct from staging.event_sequence
            or fact.event_at is distinct from staging.event_at
            or fact.event_type is distinct from staging.event_type
            or fact.from_status is distinct from staging.from_status
            or fact.to_status is distinct from staging.to_status
            or fact.from_plan_version_id is distinct from staging.from_plan_version_id
            or fact.to_plan_version_id is distinct from staging.to_plan_version_id
            or fact.event_reason is distinct from staging.event_reason
        )
    from fact
    left join staging
        on fact.subscription_event_id = staging.subscription_event_id

    union all

    select
        'sequence',
        'subscription_sequence_violations',
        count(*)
    from sequence_violations

)

select
    check_group,
    check_name,
    violation_count,
    violation_count = 0 as passed
from checks
order by check_group, check_name
