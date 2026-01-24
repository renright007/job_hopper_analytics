/*
    create our output for cleaned salaies
*/

{{ config(materialized='table') }}

WITH base AS (
 SELECT
   id,
   job_title,
   salary AS salary_raw,


   -- Normalise for easier parsing
   TRIM(REGEXP_REPLACE(salary, r'\s+', ' ')) AS salary_norm,
   UPPER(salary) AS salary_upper
 FROM job_hopper.jobs
),


currency_parsed AS (
 SELECT
   *,
   CASE
     WHEN salary_upper IS NULL THEN NULL
     WHEN REGEXP_CONTAINS(salary_upper, r'\b(NOT LISTED|NOT DISCLOSED|TBD|N/?A|NEGOTIABLE|COMPETITIVE)\b') THEN NULL


     -- ISO codes first (most reliable)
     WHEN REGEXP_CONTAINS(salary_upper, r'\bCAD\b') THEN 'CAD'
     WHEN REGEXP_CONTAINS(salary_upper, r'\bUSD\b') THEN 'USD'
     WHEN REGEXP_CONTAINS(salary_upper, r'\bGBP\b') THEN 'GBP'
     WHEN REGEXP_CONTAINS(salary_upper, r'\bEUR\b') THEN 'EUR'


     -- Symbols
     WHEN STRPOS(salary_norm, '£') > 0 THEN 'GBP'
     WHEN STRPOS(salary_norm, '€') > 0 THEN 'EUR'
     WHEN STRPOS(salary_norm, '$') > 0 THEN 'USD'   -- could be CAD/AUD etc; override with ISO if present
     ELSE 'OTHER'
   END AS currency,
   CASE
     WHEN salary_upper = 'NOT LISTED' THEN NULL
     WHEN REGEXP_CONTAINS(salary_upper, r'\bDAY\b') THEN 'Daily'
     WHEN REGEXP_CONTAINS(salary_upper, r'\bHOUR\b') THEN 'Hourly'
     ELSE 'Yearly'
   END AS pay_period
 FROM base
),


numbers_extracted AS (
 SELECT
   *,
   -- Extract up to two numbers, supports:
   --  - 50,000 / 50000 / 50.5
   --  - 50k / 50.5k
   --  - ranges with hyphen/en dash/em dash/"to"
   REGEXP_EXTRACT_ALL(
     salary_upper,
     r'(\d{1,3}(?:,\d{3})+|\d+(?:\.\d+)?)(?:\s*K)?'
   ) AS nums_raw,


   REGEXP_EXTRACT_ALL(
     salary_upper,
     r'(\d{1,3}(?:,\d{3})+|\d+(?:\.\d+)?)(?:\s*(K))?'
   ) AS nums_with_k  -- used just to detect if K appears with each captured number
 FROM currency_parsed
),


parsed AS (
 SELECT
   id,
   job_title,
   salary_raw,
   currency,
   pay_period,


   SAFE_CAST(REPLACE(nums_raw[SAFE_OFFSET(0)], ',', '') AS NUMERIC) AS n1,
   SAFE_CAST(REPLACE(nums_raw[SAFE_OFFSET(1)], ',', '') AS NUMERIC) AS n2,


   REGEXP_CONTAINS(salary_upper, r'(\d)\s*K\b') AS has_k,
   salary_upper
 FROM numbers_extracted
),


final AS (
 SELECT
   id,
   job_title,
   salary_raw,
   currency,
   pay_period,


   -- Apply K multiplier if needed
   CASE
     WHEN currency IS NULL THEN NULL
     WHEN n1 IS NULL AND n2 IS NULL THEN NULL
     WHEN n2 IS NOT NULL THEN (LEAST(n1, n2) * IF(has_k, 1000, 1))
     WHEN REGEXP_CONTAINS(salary_upper, r'\bFROM\b|\bSTARTING\b') THEN (n1 * IF(has_k, 1000, 1))
     ELSE (n1 * IF(has_k, 1000, 1))
   END AS salary_min,


   CASE
     WHEN currency IS NULL THEN NULL
     WHEN n1 IS NULL AND n2 IS NULL THEN NULL
     WHEN n2 IS NOT NULL THEN (GREATEST(n1, n2) * IF(has_k, 1000, 1))
     WHEN REGEXP_CONTAINS(salary_upper, r'\bUP TO\b|\bMAX\b') THEN (n1 * IF(has_k, 1000, 1))
     ELSE (n1 * IF(has_k, 1000, 1))
   END AS salary_max
 FROM parsed
)


SELECT
 id,
 salary_raw,
 currency,
 pay_period,
 salary_min,
 salary_max,
 CASE
   WHEN salary_min IS NULL OR salary_max IS NULL THEN NULL
   ELSE (salary_min + salary_max) / 2
 END AS salary_midpoint
FROM final
