{{
  config(
    materialized='table',
    incremental_strategy='insert_overwrite',
    partition_by={'field': 'event_date', 'data_type': 'date'},
    cluster_by=['user_id', 'event_type']
  )
}}

SELECT
    e.event_id
    , e.user_id
    , e.event_time
    , e.event_date
    , e.event_week
    , e.event_month
    , u.first_event_date
    , u.first_event_month
    , DATE_DIFF(e.event_date, u.first_event_date, DAY) AS first_touch_days
    , DATE_DIFF(e.event_month, u.first_event_month, MONTH) AS first_touch_months
    , e.event_type
    , e.transaction_category
    , COALESCE(e.miles_amount, 0) AS miles_amount
    , e.miles_amount AS raw_miles_amount
    , e.platform
    , e.utm_source
    , e.country
    , e.gender
    , e.event_type IN ('miles_earned', 'miles_redeemed') AS is_transactional
    , e.event_type = 'miles_earned' AS is_earning
    , e.event_type = 'miles_redeemed' AS is_redemption
    , e.event_type IN ('like', 'share') AS is_social
    , e.event_type = 'reward_search' AS is_discovery
FROM {{ ref('stg_event_stream') }} e
INNER JOIN {{ ref('dim_users') }} u 
    ON e.user_id = u.user_id


--- use this script below for production, with billing activation in BQ ---
-- {% if is_incremental() %}
--   WHERE e.event_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
-- {% endif %}