/*
    create our output for cleaned city and country
*/

{{ config(materialized='table') }}

WITH base AS (
 SELECT
   jobs.id,
   jobs.location AS location_raw,
   UPPER(jobs.location) AS location_upper,
   -- normalise "City - Country" -> "City, Country"
   TRIM(REGEXP_REPLACE(jobs.location, r'\s*-\s*', ', ')) AS location_norm,
   -- split into array
   SPLIT(TRIM(REGEXP_REPLACE(jobs.location, r'\s*-\s*', ', ')), ', ') AS location_split
 FROM job_hopper.jobs
)


, location_values as (SELECT
 *,
 location_split[SAFE_OFFSET(0)] AS city,
 location_split[SAFE_OFFSET(1)] AS region_or_country,
 location_split[SAFE_OFFSET(2)] AS region_or_country_2
FROM base
)


, cleaned_values AS (SELECT
   id,
   location_raw,
   CASE
       WHEN region_or_country is null THEN 'Remote'
       ELSE city END AS city,
   CASE
       WHEN region_or_country_2 IS NOT NULL THEN region_or_country_2
       WHEN region_or_country IS NOT NULL THEN region_or_country
       ELSE city END AS country
FROM location_values
)


SELECT
   id,
   location_raw,
   city,
   CASE   
       WHEN country IN ('UK', 'GB', 'England') THEN 'United Kingdom'
       WHEN country IN ('CAN') then 'Canada'
       ELSE country END AS country
FROM cleaned_values