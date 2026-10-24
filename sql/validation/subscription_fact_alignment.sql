select
(select count(*) from `skillspring-analytics.skillspring_analytics.fct_subscriptions`) as fact_rows,
(select count(*) from `skillspring-analytics.skillspring_analytics.fct_subscriptions` where subscription_id is null) as null_subscription_ids,
(select count(*) from (select customer_id from `skillspring-analytics.skillspring_analytics.dim_customers` group by customer_id having count(*) > 1)) as duplicate_customer_keys,
(select count(*) from (select plan_version_id from `skillspring-analytics.skillspring_analytics.dim_plan_versions` group by plan_version_id having count(*) > 1)) as duplicate_plan_keys,
(select count(*) from `skillspring-analytics.skillspring_analytics.fct_subscriptions` f full outer join `skillspring-analytics.skillspring_analytics.stg_subscriptions` s on f.subscription_id=s.subscription_id where f.subscription_id is null or s.subscription_id is null) as unmatched_subscription_ids,
(select count(*) from `skillspring-analytics.skillspring_analytics.fct_subscriptions` f join `skillspring-analytics.skillspring_analytics.stg_subscriptions` s on f.subscription_id=s.subscription_id where f.current_status is distinct from s.current_status or f.customer_id is distinct from s.customer_id) as source_status_or_customer_mismatches;
