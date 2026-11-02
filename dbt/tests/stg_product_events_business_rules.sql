with events as (

    select *
    from {{ ref('stg_product_events') }}

),

invalid_context as (

    select
        product_event_id as entity_id,
        'invalid_event_context' as violation_type
    from events
    where
        (
            event_name = 'onboarding_step_completed'
            and onboarding_step is null
        )
        or (
            event_name != 'onboarding_step_completed'
            and onboarding_step is not null
        )
        or (
            event_name in (
                'program_viewed',
                'program_started',
                'lesson_started',
                'lesson_completed'
            )
            and program_id is null
        )
        or (
            event_name not in (
                'program_viewed',
                'program_started',
                'lesson_started',
                'lesson_completed'
            )
            and program_id is not null
        )
        or (
            event_name in ('lesson_started', 'lesson_completed')
            and lesson_id is null
        )
        or (
            event_name not in ('lesson_started', 'lesson_completed')
            and lesson_id is not null
        )

),

invalid_sessions as (

    select
        session_id as entity_id,
        'session_has_multiple_customers' as violation_type
    from events
    group by session_id
    having count(distinct customer_id) != 1

)

select *
from invalid_context

union all

select *
from invalid_sessions
