-- Customer-level active subscription penetration at the synthetic reporting cutoff.
-- Aggregate subscriptions before joining so repeat subscribers count once.
with subscription_summary as (
    select
        customer_id,
        count(*) as subscriptions,
        countif(current_status = 'active') as active_subscriptions
    from `skillspring-analytics.skillspring_analytics.fct_subscriptions`
    group by customer_id
),

customers as (
    select
        c.*,
        coalesce(s.subscriptions, 0) as subscriptions,
        coalesce(s.active_subscriptions, 0) as active_subscriptions
    from `skillspring-analytics.skillspring_analytics.dim_customers` as c
    left join subscription_summary as s using (customer_id)
),

segments as (
    select
        'learning_goal' as segment_type,
        coalesce(learning_goal, '[NULL]') as segment,
        count(*) as customers,
        countif(subscriptions > 0) as customers_with_subscription,
        countif(active_subscriptions > 0) as active_customers,
        sum(active_subscriptions) as active_subscriptions
    from customers
    group by segment

    union all

    select
        'career_country',
        coalesce(country_code, '[NULL]'),
        count(*),
        countif(subscriptions > 0),
        countif(active_subscriptions > 0),
        sum(active_subscriptions)
    from customers
    where learning_goal = 'career'
    group by country_code

    union all

    select
        'career_channel',
        coalesce(acquisition_channel, '[NULL]'),
        count(*),
        countif(subscriptions > 0),
        countif(active_subscriptions > 0),
        sum(active_subscriptions)
    from customers
    where learning_goal = 'career'
    group by acquisition_channel
)

select
    *,
    round(100 * safe_divide(active_customers, customers), 2) as active_customer_pct
from segments
order by segment_type, customers desc, segment;
