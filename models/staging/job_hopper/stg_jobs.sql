with 

source as (

    select * from {{ source('job_hopper', 'jobs') }}

),

final as (

    select
        id,
        user_id,
        company_name,
        job_title,
        job_description,
        application_url,
        status,
        sentiment,
        notes,
        location,
        salary,
        -- move casting into staging so downstream models are simple
        safe_cast(nullif(trim(cast(date_added as string)), 'None') as datetime) as date_added_dt,
        safe_cast(nullif(trim(cast(applied_date as string)), 'None') as date)     as applied_date_date

    from source

)

select * from final