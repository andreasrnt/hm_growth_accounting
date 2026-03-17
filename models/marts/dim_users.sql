{{
  config(
    materialized='table'
  )
}}

WITH first_touch AS (
    SELECT *
    FROM (
        SELECT
            user_id
            , event_date AS first_event_date
            , DATE_TRUNC(event_date, MONTH) AS first_event_month
            , gender AS acquisition_gender
            , country AS acquisition_country
            , platform AS acquisition_platform
            , utm_source AS acquisition_channel
            , ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY event_date ASC) AS rwnmx
        FROM {{ ref('stg_event_stream') }}
    ) x
    WHERE rwnmx = 1
)

, latest_touch AS (
    SELECT *
    FROM (
        SELECT
            user_id
            , event_date AS last_event_date
            , DATE_TRUNC(event_date, MONTH) AS last_event_month
            , gender
            , country
            , platform
            , utm_source AS channel
            , ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY event_date DESC) AS rwnmx
        FROM {{ ref('stg_event_stream') }}
    ) x
    WHERE rwnmx = 1
)

, activity AS (
    SELECT
        user_id
        , COUNT(*) AS total_events
        , COUNT(DISTINCT event_date) AS active_days
        , COUNT(DISTINCT event_month) AS active_months
        , COUNTIF(event_type = 'miles_earned') AS earning_events
        , COUNTIF(event_type = 'miles_redeemed') AS redemption_events
        , SUM(IF(event_type = 'miles_earned',   miles_amount, 0)) AS miles_earned
        , SUM(IF(event_type = 'miles_redeemed', miles_amount, 0)) AS miles_redeemed
        , COUNTIF(event_type = 'reward_search') AS discovery_events
        , COUNTIF(event_type = 'like') AS like_events
        , COUNTIF(event_type = 'share') AS share_events
        , MIN(IF(event_type IN ('miles_earned', 'miles_redeemed'), event_date, NULL)) AS first_transaction_date
    FROM {{ ref('stg_event_stream') }}
    GROUP BY user_id
)

SELECT
    f.user_id
    , f.first_event_date
    , f.first_event_month
    , f.acquisition_channel
    , f.acquisition_platform
    , l.gender
    , l.country
    , l.platform
    , l.last_event_date
    , DATE_DIFF(l.last_event_date, f.first_event_date, DAY) AS user_lifespan_days
    , a.first_transaction_date
    , DATE_DIFF(a.first_transaction_date, f.first_event_date, DAY) AS days_to_first_transaction
    , a.first_transaction_date IS NOT NULL AS is_transacting_user
    , a.total_events
    , a.active_days
    , a.active_months
    , a.earning_events
    , a.redemption_events
    , a.miles_earned
    , a.miles_redeemed
    , a.miles_earned - a.miles_redeemed AS net_miles_balance
    , a.discovery_events
    , a.like_events
    , a.share_events
    , CASE
        WHEN a.active_months >= 2 AND a.total_events >= 10 THEN 'Gold'
        WHEN a.active_months >= 2 AND a.total_events >= 5 THEN 'Silver'
        WHEN a.total_events >= 3 THEN 'Bronze'
        ELSE 'New'
    END AS user_tier
FROM first_touch f
JOIN latest_touch l 
    ON f.user_id = l.user_id
JOIN activity a
    ON f.user_id = a.user_id