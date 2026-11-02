with fact as (

    select *
    from `skillspring-analytics.skillspring_analytics.fct_product_events`

),

staging as (

    select *
    from `skillspring-analytics.skillspring_analytics.stg_product_events`

),

customers as (

    select customer_id
    from `skillspring-analytics.skillspring_analytics.dim_customers`

),

checks as (

    select
        'alignment' as check_group,
        'staging_projection_mismatches' as check_name,
        (
            select count(*)
            from (
                select
                    product_event_id,
                    customer_id,
                    session_id,
                    occurred_at,
                    event_date,
                    event_month,
                    event_name,
                    platform,
                    onboarding_step,
                    program_id,
                    lesson_id
                from fact

                except distinct

                select
                    product_event_id,
                    customer_id,
                    session_id,
                    occurred_at,
                    event_date,
                    event_month,
                    event_name,
                    platform,
                    onboarding_step,
                    program_id,
                    lesson_id
                from staging
            )
        )
        +
        (
            select count(*)
            from (
                select
                    product_event_id,
                    customer_id,
                    session_id,
                    occurred_at,
                    event_date,
                    event_month,
                    event_name,
                    platform,
                    onboarding_step,
                    program_id,
                    lesson_id
                from staging

                except distinct

                select
                    product_event_id,
                    customer_id,
                    session_id,
                    occurred_at,
                    event_date,
                    event_month,
                    event_name,
                    platform,
                    onboarding_step,
                    program_id,
                    lesson_id
                from fact
            )
        ) as violation_count

    union all

    select
        'grain',
        'row_count_difference_from_staging',
        abs(
            (select count(*) from fact)
            -
            (select count(*) from staging)
        )

    union all

    select
        'grain',
        'duplicate_event_ids',
        count(*) - count(distinct product_event_id)
    from fact

    union all

    select
        'derivation',
        'event_date_mismatches',
        countif(event_date != date(occurred_at))
    from fact

    union all

    select
        'derivation',
        'event_month_mismatches',
        countif(event_month != date_trunc(date(occurred_at), month))
    from fact

    union all

    select
        'relationship',
        'missing_customer_dimension_rows',
        countif(customers.customer_id is null)
    from fact
    left join customers
        using (customer_id)

    union all

    select
        'validity',
        'invalid_context_rows',
        countif(
            case
                when event_name = 'session_started'
                    then onboarding_step is not null
                        or program_id is not null
                        or lesson_id is not null

                when event_name in (
                    'onboarding_started',
                    'onboarding_completed'
                )
                    then onboarding_step is not null
                        or program_id is not null
                        or lesson_id is not null

                when event_name = 'onboarding_step_completed'
                    then onboarding_step is null
                        or program_id is not null
                        or lesson_id is not null

                when event_name in (
                    'program_viewed',
                    'program_started'
                )
                    then onboarding_step is not null
                        or program_id is null
                        or lesson_id is not null

                when event_name in (
                    'lesson_started',
                    'lesson_completed'
                )
                    then onboarding_step is not null
                        or program_id is null
                        or lesson_id is null

                else true
            end
        )
    from fact

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
