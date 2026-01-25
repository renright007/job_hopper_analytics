{{ config(materialized='table') }}

with jobs as (

    select
        id as job_id,
        user_id,
        company_name,
        job_title,
        job_description,
        application_url,
        status,
        sentiment,
        notes,

        safe_cast(nullif(trim(cast(date_added as string)), 'None') as datetime) as date_added_dt,
        safe_cast(nullif(trim(cast(applied_date as string)), 'None') as date)     as applied_date

    from {{ source('job_hopper', 'jobs') }}

),

users as (

    select
        id as user_id,
        username
    from {{ source('job_hopper', 'users') }}

),

salaries as (

    select
        id as job_id,
        salary_raw,
        currency,
        pay_period,
        salary_min,
        salary_max,
        salary_midpoint
    from {{ ref('stg_cleaned_salaries') }}

),

locations as (

    select
        id as job_id,
        location_raw,
        city,
        country
    from {{ ref('stg_cleaned_locations') }}

)

select
    j.job_id,
    j.user_id,
    u.username,

    j.company_name,
    j.job_title,
    j.job_description,
    j.application_url,
    j.status,
    j.sentiment,
    j.notes,

    j.date_added_dt,
    j.applied_date,

    s.salary_raw,
    s.currency,
    s.pay_period,
    s.salary_min,
    s.salary_max,
    s.salary_midpoint,

    l.location_raw,
    l.city,
    l.country

from jobs j
left join salaries  s on s.job_id = j.job_id
left join locations l on l.job_id = j.job_id
left join users     u on u.user_id = j.user_id
order by 11 desc