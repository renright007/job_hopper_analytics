with 

source as (

    select * from {{ source('job_hopper', 'users') }}

),

renamed as (

    select
        id,
        username,
        password_hash,
        email,
        created_at

    from source

)

select * from renamed