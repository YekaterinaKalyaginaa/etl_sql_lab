create schema if not exists s_psql_dm;

create or replace function s_psql_dm.fn_dm_data_load(start_dt date, end_dt date)
returns void
language plpgsql
as $$
begin
  -- 0) перезапуск диапазона по signup_date (чтобы можно было прогонять заново)
  delete from s_psql_dm.t_dm_task
  where signup_date between start_dt and end_dt;

  -- 1) обновляем справочники из structured (берём уникальные значения)

  insert into s_psql_dm.t_dim_gender(gender_name)
  select distinct lower(btrim(gender))
  from s_psql_dds.t_sql_source_structured
  where gender is not null and btrim(gender) <> ''
  on conflict do nothing;

  insert into s_psql_dm.t_dim_city(city_name)
  select distinct btrim(city)
  from s_psql_dds.t_sql_source_structured
  where city is not null and btrim(city) <> ''
  on conflict do nothing;

  -- сегмент: trim + vip/VIP к одному виду, остальное upper()
  insert into s_psql_dm.t_dim_segment(segment_name)
  select distinct
    case
      when lower(btrim(segment)) = 'vip' then 'VIP'
      else upper(btrim(segment))
    end
  from s_psql_dds.t_sql_source_structured
  where segment is not null and btrim(segment) <> ''
  on conflict do nothing;

  -- 2) грузим факт-таблицу + вытаскиваем id справочников
  insert into s_psql_dm.t_dm_task (
    customer_id, full_name,
    gender_id, city_id, segment_id,
    age, monthly_income,
    signup_date, valid_from, valid_to
  )
  select
    s.customer_id,
    s.full_name,

    g.gender_id,
    c.city_id,
    sg.segment_id,

    s.age,
    s.monthly_income,

    s.signup_date,
    s.valid_from,
    s.valid_to
  from s_psql_dds.t_sql_source_structured s
  left join s_psql_dm.t_dim_gender g
    on g.gender_name = lower(btrim(s.gender))
  left join s_psql_dm.t_dim_city c
    on c.city_name = btrim(s.city)
  left join s_psql_dm.t_dim_segment sg
    on sg.segment_name =
      case
        when s.segment is null or btrim(s.segment) = '' then null
        when lower(btrim(s.segment)) = 'vip' then 'VIP'
        else upper(btrim(s.segment))
      end
  where s.signup_date between start_dt and end_dt
  on conflict (customer_id) do update set
    full_name      = excluded.full_name,
    gender_id      = excluded.gender_id,
    city_id        = excluded.city_id,
    segment_id     = excluded.segment_id,
    age            = excluded.age,
    monthly_income = excluded.monthly_income,
    signup_date    = excluded.signup_date,
    valid_from     = excluded.valid_from,
    valid_to       = excluded.valid_to;

end;
$$;
