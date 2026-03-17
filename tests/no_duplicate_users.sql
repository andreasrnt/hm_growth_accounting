SELECT
    user_id
    , COUNT(*) AS row_count
FROM {{ ref('dim_users') }}
GROUP BY user_id
HAVING COUNT(*) > 1