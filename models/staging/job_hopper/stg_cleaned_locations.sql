{{ config(materialized='table') }}

with base as (

    select
        id,
        location as location_raw,
        upper(location) as location_upper,
        trim(regexp_replace(location, r'\s*-\s*', ', ')) as location_norm,
        split(trim(regexp_replace(location, r'\s*-\s*', ', ')), ', ') as location_split
    from {{ source('job_hopper', 'jobs') }}

),

location_values as (

    select
        *,
        location_split[SAFE_OFFSET(0)] AS city,
        location_split[SAFE_OFFSET(1)] AS region_or_country,
        location_split[SAFE_OFFSET(2)] AS region_or_country_2
    from base

), 

cleaned_values AS (
    SELECT
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