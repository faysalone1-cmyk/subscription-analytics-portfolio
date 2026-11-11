-- Counts subscriptions with current_status = 'active' at the source reporting cutoff.
-- Customer country is a signup attribute. This is not a count of distinct customers.
-- NULL country codes remain visible so missing data cannot silently disappear.
with country_counts as (
    select
        c.country_code,
        count(*) as active_subscriptions,
        countif(c.customer_id is null) as unmatched_customer_rows
    from `skillspring-analytics.skillspring_analytics.fct_subscriptions` as s
    left join `skillspring-analytics.skillspring_analytics.dim_customers` as c
        on s.customer_id = c.customer_id
    where s.current_status = 'active'
    group by c.country_code
),
overall as (
    select count(*) as overall_active_subscriptions
    from `skillspring-analytics.skillspring_analytics.fct_subscriptions`
    where current_status = 'active'
)
select
    country_counts.*,
    overall.overall_active_subscriptions,
    sum(active_subscriptions) over () as country_total,
    sum(active_subscriptions) over () - overall.overall_active_subscriptions as difference
from country_counts
cross join overall
order by active_subscriptions desc, country_code;
