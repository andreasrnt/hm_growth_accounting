WITH source AS (
    SELECT
        CONCAT(user_id, FORMAT_TIMESTAMP("%Y%m%d%H%M%S", event_time), CAST(FLOOR(1 + (RAND() * 10)) AS INT64)) AS event_id
        , CAST(event_time AS TIMESTAMP) AS event_time
        , DATE(event_time) AS event_date
        , DATE_TRUNC(DATE(event_time), WEEK(MONDAY)) AS event_week
        , DATE_TRUNC(DATE(event_time), MONTH) AS event_month
        , TRIM(user_id) AS user_id
        , LOWER(TRIM(COALESCE(gender, 'unknown'))) AS gender
        , LOWER(TRIM(event_type)) AS event_type
        , LOWER(TRIM(transaction_category)) AS transaction_category
        , CAST(miles_amount AS FLOAT64) AS miles_amount
        , LOWER(TRIM(platform)) AS platform
        , LOWER(TRIM(COALESCE(utm_source, 'unknown'))) AS utm_source
        , UPPER(TRIM(country)) AS country
    FROM {{ source('heymax', 'event_stream') }}
    WHERE user_id IS NOT NULL
      AND event_time IS NOT NULL
)

SELECT *
FROM source
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY user_id, event_time
    ORDER BY event_time
) = 1