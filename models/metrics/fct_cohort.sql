{{
  config(
    materialized='table',
    partition_by={'field': 'cohort_period', 'data_type': 'date', 'granularity': 'month'},
    cluster_by=['period']
  )
}}

WITH period_active AS (
    SELECT DISTINCT user_id, event_month AS activity_period, 'Monthly' AS period FROM {{ ref('fct_events') }}
    UNION ALL
    SELECT DISTINCT user_id, event_week  AS activity_period, 'Weekly'  AS period FROM {{ ref('fct_events') }}
)

, cohort AS (
    SELECT
        user_id
        , period
        , activity_period AS cohort_period
        , LEAD(activity_period) OVER (PARTITION BY user_id, period ORDER BY activity_period) AS next_cohort_period
    FROM (
        SELECT
            user_id
            , activity_period
            , period
            , LAG(activity_period) OVER (PARTITION BY user_id, period ORDER BY activity_period) AS prev_period
        FROM period_active
    )
    WHERE prev_period IS NULL
       OR (period = 'Monthly' AND DATE_DIFF(activity_period, prev_period, MONTH) > 1)
       OR (period = 'Weekly'  AND DATE_DIFF(activity_period, prev_period, WEEK)  > 1)
)

, cohort_sizes AS (
    SELECT
        cohort_period
        , period
        , COUNT(DISTINCT user_id) AS total_users_first_period
    FROM cohort
    GROUP BY cohort_period, period
)

, retained AS (
    SELECT
        c.cohort_period
        , c.period
        , a.activity_period AS retained_period
        , COUNT(DISTINCT c.user_id) AS total_users_retained_period
    FROM cohort c
    INNER JOIN period_active a
        ON c.user_id = a.user_id
        AND c.period = a.period
    WHERE a.activity_period >= c.cohort_period
      AND (c.next_cohort_period IS NULL OR a.activity_period < c.next_cohort_period)
    GROUP BY c.cohort_period, c.period, a.activity_period
)

SELECT
    r.period
    , r.cohort_period
    , FORMAT_DATE('%Y-%m-%d', r.cohort_period) AS cohort_label
    , FORMAT_DATE('%Y-%m-%d', r.retained_period) AS retained_period
    , CASE
        WHEN r.period = 'Monthly' THEN DATE_DIFF(r.retained_period, r.cohort_period, MONTH)
        WHEN r.period = 'Weekly'  THEN DATE_DIFF(r.retained_period, r.cohort_period, WEEK)
    END AS periods_since_cohort
    , cs.total_users_first_period
    , r.total_users_retained_period
    , ROUND(100 * SAFE_DIVIDE(r.total_users_retained_period, cs.total_users_first_period), 1) AS retention_rate
FROM retained r
LEFT JOIN cohort_sizes cs
    ON cs.cohort_period = r.cohort_period
    AND cs.period = r.period