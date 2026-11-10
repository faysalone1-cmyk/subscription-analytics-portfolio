select
    (select count(*)
     from `skillspring-analytics.skillspring_analytics.dim_customers`) as customer_rows,
    (select count(*) - count(distinct customer_id)
     from `skillspring-analytics.skillspring_analytics.dim_customers`) as duplicate_or_null_customer_keys,
    (select countif(
        learning_goal is null
        or learning_goal not in ('career', 'language', 'academic', 'personal')
     )
     from `skillspring-analytics.skillspring_analytics.dim_customers`) as invalid_learning_goals,
    (select count(*)
     from `skillspring-analytics.skillspring_analytics.fct_subscriptions` as s
     left join `skillspring-analytics.skillspring_analytics.dim_customers` as c using (customer_id)
     where c.customer_id is null) as unmatched_subscription_customers,
    (select count(*)
     from `skillspring-analytics.skillspring_analytics.fct_subscriptions`
     where current_status = 'active') as active_subscriptions,
    (select count(distinct customer_id)
     from `skillspring-analytics.skillspring_analytics.fct_subscriptions`
     where current_status = 'active') as active_customers,
    (select count(*)
     from `skillspring-analytics.skillspring_analytics.dim_customers`
     where learning_goal = 'career'
       and (country_code is null or acquisition_channel is null)) as career_missing_country_or_channel;
