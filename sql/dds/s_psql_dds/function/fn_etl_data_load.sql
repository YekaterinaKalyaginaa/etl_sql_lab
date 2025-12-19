drop function if exists s_psql_dds.fn_etl_data_load(date, date);

create or replace function s_psql_dds.fn_etl_data_load(
  p_date_from date,
  p_date_to   date
)
returns void
language plpgsql
as $$
begin
  with src as (
    select
      u.*,
      s_psql_dds.try_parse_date(u.signup_date) as signup_dt,
      s_psql_dds.try_parse_date(u.valid_from)  as valid_from_dt,
      s_psql_dds.try_parse_date(u.valid_to)    as valid_to_dt
    from s_psql_dds.t_sql_source_unstructured u
  ),
  cleaned as (
    select
      case
        when btrim(customer_id) ~ '^\d+$' then btrim(customer_id)::int
        else null
      end as customer_id,

      nullif(btrim(full_name), '') as full_name,

      case
        when lower(btrim(gender)) in ('f','female','жен','женщина','w') then 'female'
        when lower(btrim(gender)) in ('m','male','м','муж','мужчина')   then 'male'
        else null
      end as gender,

      case
        when btrim(age) ~ '^\d+$' then btrim(age)::int
        else null
      end as age,

      nullif(btrim(city), '')    as city,
      nullif(btrim(segment), '') as segment,

      case
        when btrim(monthly_income) ~ '^\d+([.,]\d+)?$'
          then replace(btrim(monthly_income), ',', '.')::numeric(12,2)
        else null
      end as monthly_income,

      coalesce(signup_dt, p_date_from)     as signup_date,
      coalesce(valid_from_dt, p_date_from) as valid_from,
      coalesce(valid_to_dt, p_date_to)     as valid_to
    from src
  )
  insert into s_psql_dds.t_sql_source_structured
  (
    customer_id, full_name, gender, age, city, segment,
    monthly_income, signup_date, valid_from, valid_to
  )
  select
    customer_id, full_name, gender, age, city, segment,
    monthly_income, signup_date, valid_from, valid_to
  from cleaned
  where customer_id is not null
    and signup_date between p_date_from and p_date_to
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
