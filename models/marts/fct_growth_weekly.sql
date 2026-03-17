{{
  config(
    materialized='table',
    partition_by={'field': 'activity_date', 'data_type': 'date'},
    cluster_by=['user_classification']
  )
}}

WITH base AS (
    SELECT DISTINCT
        user_id
        , DATE_TRUNC(event_date, WEEK) AS activity_date
        , DATE_TRUNC(first_event_date, WEEK) AS first_period_date
        , gender
        , country
    FROM {{ ref('fct_events') }}
)

, with_lead AS (
    SELECT
        user_id
        , activity_date
        , first_period_date
        , gender
        , country
        , LAG(activity_date) OVER (PARTITION BY user_id ORDER BY activity_date) AS prev_active_date
        , LEAD(activity_date) OVER (PARTITION BY user_id ORDER BY activity_date) AS next_active_date
    FROM base
)

, classified AS (
    SELECT
        user_id
        , activity_date
        , first_period_date
        , gender
        , country
        , prev_active_date
        , CASE
            WHEN activity_date = first_period_date THEN 'New'
            WHEN activity_date = DATE_ADD(prev_active_date, INTERVAL 1 WEEK) THEN 'Retained'
            ELSE 'Resurrected'
        END AS user_classification
    FROM with_lead
)

, churned AS (
    SELECT
        user_id
        , DATE_ADD(activity_date, INTERVAL 1 WEEK) AS activity_date
        , first_period_date
        , gender
        , country
        , activity_date AS prev_active_date
        , 'Churned' AS user_classification
    FROM with_lead
    WHERE next_active_date IS NULL
       OR next_active_date != DATE_ADD(activity_date, INTERVAL 1 WEEK)
)

SELECT *, 'Weekly' AS period FROM classified
UNION ALL
SELECT *, 'Weekly' AS period FROM churned