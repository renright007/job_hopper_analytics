{{ config(materialized='table') }}

with base as (

    select
        id,
        job_title,
        salary as salary_raw,

        trim(regexp_replace(salary, r'\s+', ' ')) as salary_norm,
        upper(salary) as salary_upper
    from {{ source('job_hopper', 'jobs') }}

),

currency_parsed as (

    select
        *,
        case
            when salary_upper is null then null
            when regexp_contains(salary_upper, r'\b(NOT LISTED|NOT DISCLOSED|TBD|N/?A|NEGOTIABLE|COMPETITIVE)\b') then null

            when regexp_contains(salary_upper, r'\bCAD\b') then 'CAD'
            when regexp_contains(salary_upper, r'\bUSD\b') then 'USD'
            when regexp_contains(salary_upper, r'\bGBP\b') then 'GBP'
            when regexp_contains(salary_upper, r'\bEUR\b') then 'EUR'

            when strpos(salary_norm, '£') > 0 then 'GBP'
            when strpos(salary_norm, '€') > 0 then 'EUR'
            when strpos(salary_norm, '$') > 0 then 'USD'
            else 'OTHER'
        end as currency,

        case
            when salary_upper is null then null
            when regexp_contains(salary_upper, r'\bDAY\b') then 'Daily'
            when regexp_contains(salary_upper, r'\bHOUR\b') then 'Hourly'
            else 'Yearly'
        end as pay_period
    from base

),

numbers_extracted as (

    select
        *,

        -- BigQuery extraction functions allow only ONE capturing group
        regexp_extract_all(
            salary_upper,
            r'(\d{1,3}(?:,\d{3})+|\d+(?:\.\d+)?)'
        ) as nums_raw,

        -- detect whether a "k" suffix appears anywhere (e.g. 50k, 50 k)
        regexp_contains(salary_upper, r'\b\d+(?:\.\d+)?\s*K\b') as has_k

    from currency_parsed

),

parsed as (

    select
        id,
        job_title,
        salary_raw,
        currency,
        pay_period,
        salary_upper,
        has_k,

        safe_cast(replace(nums_raw[safe_offset(0)], ',', '') as numeric) as n1,
        safe_cast(replace(nums_raw[safe_offset(1)], ',', '') as numeric) as n2

    from numbers_extracted

),

final as (

    select
        id,
        salary_raw,
        currency,
        pay_period,

        case
            when currency is null then null
            when n1 is null and n2 is null then null
            when n2 is not null then least(n1, n2) * if(has_k, 1000, 1)
            else n1 * if(has_k, 1000, 1)
        end as salary_min,

        case
            when currency is null then null
            when n1 is null and n2 is null then null
            when n2 is not null then greatest(n1, n2) * if(has_k, 1000, 1)
            else n1 * if(has_k, 1000, 1)
        end as salary_max

    from parsed

)

select
    id,
    salary_raw,
    currency,
    pay_period,
    salary_min,
    salary_max,
    case
        when salary_min is null or salary_max is null then null
        else (salary_min + salary_max) / 2
    end as salary_midpoint
from final
