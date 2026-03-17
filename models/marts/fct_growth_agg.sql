{{
  config(
    materialized='table',
    partition_by={'field': 'activity_period', 'data_type': 'date'},
    cluster_by=['period', 'country', 'acquisition_channel']
  )
}}

WITH base AS (
    SELECT
        e.user_id
        , e.event_date
        , e.event_week
        , e.event_month
        , e.event_type
        , e.transaction_category
        , e.miles_amount
        , e.is_transactional
        , e.is_earning
        , e.is_redemption
        , e.is_social
        , e.is_discovery
        , e.platform
        , e.country
        , e.gender
        , u.first_event_date
        , u.first_event_month
        , u.user_tier
        , u.acquisition_channel
        , u.user_lifespan_days
        , u.days_to_first_transaction
        , u.is_transacting_user
        , u.active_days
        , u.active_months
        , u.total_events
        , u.miles_earned
        , u.miles_redeemed
        , u.net_miles_balance
    FROM {{ ref('fct_events') }} e
    LEFT JOIN {{ ref('dim_users') }} u USING (user_id)
)

, daily AS (
    SELECT
        event_date AS activity_period
        , 'Daily' AS period
        , transaction_category
        , acquisition_channel
        , country
        , platform
        , gender
        , COUNT(DISTINCT user_id) AS total_user
        , SUM(miles_earned) AS total_miles_earned
        , SUM(miles_redeemed) AS total_miles_redeemed
        , SUM(net_miles_balance) AS total_net_miles_balance
        , SUM(CAST(is_earning AS INT64)) AS earning_events
        , SUM(CAST(is_redemption AS INT64)) AS redemption_events
        , SUM(CAST(is_social AS INT64)) AS social_events
        , SUM(CAST(is_discovery AS INT64)) AS discovery_events
        , SUM(miles_amount) AS miles_in_period
    FROM base
    GROUP BY 1,2,3,4,5,6,7
)

, weekly AS (
    SELECT
        event_week AS activity_period
        , 'Weekly' AS period
        , transaction_category
        , acquisition_channel
        , country
        , platform
        , gender
        , COUNT(DISTINCT user_id) AS total_user
        , SUM(miles_earned) AS total_miles_earned
        , SUM(miles_redeemed) AS total_miles_redeemed
        , SUM(net_miles_balance) AS total_net_miles_balance
        , SUM(CAST(is_earning AS INT64)) AS earning_events
        , SUM(CAST(is_redemption AS INT64)) AS redemption_events
        , SUM(CAST(is_social AS INT64)) AS social_events
        , SUM(CAST(is_discovery AS INT64)) AS discovery_events
        , SUM(miles_amount) AS miles_in_period
    FROM base
    GROUP BY 1,2,3,4,5,6,7
)

, monthly AS (
    SELECT
        event_month AS activity_period
        , 'Monthly' AS period
        , transaction_category
        , acquisition_channel
        , country
        , platform
        , gender
        , COUNT(DISTINCT user_id) AS total_user
        , SUM(miles_earned) AS total_miles_earned
        , SUM(miles_redeemed) AS total_miles_redeemed
        , SUM(net_miles_balance) AS total_net_miles_balance
        , SUM(CAST(is_earning AS INT64)) AS earning_events
        , SUM(CAST(is_redemption AS INT64)) AS redemption_events
        , SUM(CAST(is_social AS INT64)) AS social_events
        , SUM(CAST(is_discovery AS INT64)) AS discovery_events
        , SUM(miles_amount) AS miles_in_period
    FROM base
    GROUP BY 1,2,3,4,5,6,7
)

SELECT * FROM daily
UNION ALL
SELECT * FROM weekly
UNION ALL
SELECT * FROM monthly