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

            full_name,
            gender,
            age,
            city,
            segment,
            monthly_income,

            signup_date,
            valid_from,
            valid_to,

            -- парсим даты безопасно один раз
            s_psql_dds.try_parse_date(signup_date) as signup_dt,
            s_psql_dds.try_parse_date(valid_from)  as valid_from_dt,
            s_psql_dds.try_parse_date(valid_to)    as valid_to_dt
        from s_psql_dds.t_sql_source_unstructured
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
        customer_id_clean::int as customer_id,

        nullif(btrim(full_name), '') as full_name,

        case
            when lower(btrim(gender)) in ('m','male','man','м','муж','мужчина') then 'male'
            when lower(btrim(gender)) in ('f','female','woman','ж','жен','женщина') then 'female'
            else null
        end as gender,

        case
            when nullif(regexp_replace(age, '[^0-9]', '', 'g'), '') is null then null
            else least(120, greatest(0, nullif(regexp_replace(age, '[^0-9]', '', 'g'), '')::int))
        end as age,

        nullif(btrim(city), '') as city,
        nullif(btrim(segment), '') as segment,

        case
            when nullif(btrim(monthly_income), '') is null then null
            else nullif(
                    regexp_replace(
                        replace(replace(lower(btrim(monthly_income)), ' ', ''), ',', '.'),
                        '[^0-9\.]',
                        '',
                        'g'
                    ),
                    ''
                 )::numeric(12,2)
        end as monthly_income,

        signup_dt as signup_date,
        valid_from_dt as valid_from,

        case
            when valid_to_dt is null then null
            when valid_from_dt is not null and valid_to_dt < valid_from_dt then valid_from_dt
            else valid_to_dt
        end as valid_to

    from src
    where
        -- 1) customer_id обязателен (иначе PK/NOT NULL)
        customer_id_clean is not null

        -- 2) фильтр по периоду тоже через безопасный парсер
        and signup_dt between start_date and end_date

    on conflict (customer_id) do update set
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
