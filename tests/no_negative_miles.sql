SELECT *
FROM {{ ref('fct_events') }}
WHERE miles_amount < 0