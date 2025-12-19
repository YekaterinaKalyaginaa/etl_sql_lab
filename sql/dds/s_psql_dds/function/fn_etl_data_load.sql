drop function if exists s_psql_dds.fn_etl_data_load(date, date);

create or replace function s_psql_dds.fn_etl_data_load(
    start_date date,
    end_date   date
)
returns void
language plpgsql
as $$
begin
    with src as (
        select
            -- чистим customer_id один раз
            nullif(regexp_replace(customer_id, '[^0-9]', '', 'g'), '') as customer_id_clean,

            -- имя
            nullif(btrim(full_name), '') as full_name,

            -- пол
            case
                when lower(btrim(gender)) in ('m','male','man','м','муж','мужчина') then 'male'
                when lower(btrim(gender)) in ('f','female','woman','ж','жен','женщина') then 'female'
                else null
            end as gender,

            -- возраст
            case
                when nullif(regexp_replace(age, '[^0-9]', '', 'g'), '') is null then null
                else least(120, greatest(0, nullif(regexp_replace(age, '[^0-9]', '', 'g'), '')::int))
            end as age,

            nullif(btrim(city), '')    as city,
            nullif(btrim(segment), '') as segment,

            -- ДОХОД: безопасно (не падает на "12.345.67")
            s_psql_dds.try_parse_numeric(monthly_income) as monthly_income,

            -- ДАТЫ: безопасно (не падает на "32.13.2025")
            s_psql_dds.try_parse_date(signup_date) as signup_dt,
            s_psql_dds.try_parse_date(valid_from)  as valid_from_dt,
            s_psql_dds.try_parse_date(valid_to)    as valid_to_dt

        from s_psql_dds.t_sql_source_unstructured
    ),

    filtered as (
        select *
        from src
        where customer_id_clean is not null
          and signup_dt is not null
          and signup_dt between start_date and end_date
    ),

    final_rows as (
        select
            customer_id_clean::int as customer_id,
            full_name,
            gender,
            age,
            city,
            segment,
            monthly_income,
            signup_dt::date as signup_date,
            valid_from_dt::date as valid_from,
            case
                when valid_to_dt is null then null
                when valid_from_dt is not null and valid_to_dt < valid_from_dt then valid_from_dt::date
                else valid_to_dt::date
            end as valid_to
        from filtered
    ),

    -- ВАЖНО: дедуп по customer_id, чтобы не падать на
    -- "ON CONFLICT DO UPDATE command cannot affect row a second time"
    dedup as (
        select *
        from (
            select
                fr.*,
                row_number() over (
                    partition by fr.customer_id
                    order by fr.signup_date desc nulls last,
                             fr.valid_from desc nulls last
                ) as rn
            from final_rows fr
        ) x
        where x.rn = 1
    )

    insert into s_psql_dds.t_sql_source_structured (
        customer_id,
        full_name,
        gender,
        age,
        city,
        segment,
        monthly_income,
        signup_date,
        valid_from,
        valid_to
    )
    select
        customer_id,
        full_name,
        gender,
        age,
        city,
        segment,
        monthly_income,
        signup_date,
        valid_from,
        valid_to
    from dedup
    on conflict (customer_id) do update
    set
        full_name      = excluded.full_name,
        gender         = excluded.gender,
        age            = excluded.age,
        city           = excluded.city,
        segment        = excluded.segment,
        monthly_income = excluded.monthly_income,
        signup_date    = excluded.signup_date,
        valid_from     = excluded.valid_from,
        valid_to       = excluded.valid_to;

end;
$$;
