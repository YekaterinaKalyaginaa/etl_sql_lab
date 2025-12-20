create schema if not exists s_psql_dds;

drop function if exists s_psql_dds.fn_etl_data_load(date, date);

create or replace function s_psql_dds.fn_etl_data_load(
    start_date date,
    end_date   date
)
returns void
language plpgsql
as $$
begin
    /*
      ETL:
      - берём грязные строки из t_sql_source_unstructured
      - чистим/нормализуем
      - дедуплицируем по customer_id внутри одной загрузки
      - грузим в t_sql_source_structured через UPSERT
    */

    with src as (
        select
            nullif(regexp_replace(customer_id, '[^0-9]', '', 'g'), '')::int as customer_id_clean,
            nullif(btrim(full_name), '') as full_name_raw,
            lower(btrim(gender)) as gender_raw,
            nullif(regexp_replace(age, '[^0-9]', '', 'g'), '') as age_digits,
            nullif(btrim(city), '') as city_raw,
            nullif(btrim(segment), '') as segment_raw,

            s_psql_dds.try_parse_numeric(monthly_income) as income_num,

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
    normalized as (
        select
            customer_id_clean as customer_id,

            full_name_raw as full_name,

            case
                when gender_raw in ('m','male','man','м','муж','мужчина') then 'male'
                when gender_raw in ('f','female','woman','ж','жен','женщина') then 'female'
                else null
            end as gender,

            case
                when age_digits is null then null
                else least(120, greatest(0, age_digits::int))
            end as age,

            city_raw    as city,
            segment_raw as segment,

            income_num as monthly_income,

            signup_dt as signup_date,

            valid_from_dt as valid_from,

            case
                when valid_to_dt is null then null
                when valid_from_dt is not null and valid_to_dt < valid_from_dt then valid_from_dt
                else valid_to_dt
            end as valid_to
        from filtered
    ),
    final_rows as (
        /*
          ВАЖНО: дедуп по customer_id внутри одного INSERT,
          иначе Postgres падает: "ON CONFLICT DO UPDATE cannot affect row a second time".
        */
        select distinct on (customer_id)
            customer_id, full_name, gender, age, city, segment,
            monthly_income, signup_date, valid_from, valid_to
        from normalized
        order by
            customer_id,
            (full_name is not null) desc,
            (gender is not null) desc,
            (age is not null) desc,
            (city is not null) desc,
            (segment is not null) desc,
            (monthly_income is not null) desc,
            signup_date desc nulls last,
            valid_from desc nulls last
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
    from final_rows
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
