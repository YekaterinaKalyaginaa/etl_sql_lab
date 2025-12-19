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
with src as (
  select
    nullif(regexp_replace(customer_id, '[^0-9]', '', 'g'), '')::int as customer_id,

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

    --  Даты парсим только через try_parse_date (точки не поддерживаем)
    s_psql_dds.try_parse_date(signup_date) as signup_dt,
    s_psql_dds.try_parse_date(valid_from)  as valid_from_dt,
    s_psql_dds.try_parse_date(valid_to)    as valid_to_dt

  from s_psql_dds.t_sql_source_unstructured
)
select
  customer_id,
  full_name,
  gender,
  age,
  city,
  segment,
  monthly_income,
  signup_dt,
  valid_from_dt,
  case
    when valid_to_dt is null then null
    when valid_from_dt is not null and valid_to_dt < valid_from_dt then valid_from_dt
    else valid_to_dt
  end as valid_to
from src
where signup_dt between start_date and end_date
on conflict (customer_id) do nothing;
