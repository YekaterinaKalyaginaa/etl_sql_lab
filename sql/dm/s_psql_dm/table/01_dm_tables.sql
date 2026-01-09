-- dm layer (витрина)
create schema if not exists s_psql_dm;

-- =========================
-- 1) dimensions (справочники)
-- =========================

create table if not exists s_psql_dm.t_dim_gender (
  gender_id   serial primary key,
  gender_name text unique
);

create table if not exists s_psql_dm.t_dim_city (
  city_id   serial primary key,
  city_name text unique
);

create table if not exists s_psql_dm.t_dim_segment (
  segment_id   serial primary key,
  segment_name text unique
);

-- =========================
-- 2) fact table (центр витрины)
-- =========================

drop table if exists s_psql_dm.t_dm_task;

create table s_psql_dm.t_dm_task (
  customer_id    int primary key,  -- натуральный ключ клиента
  full_name      text,

  gender_id      int references s_psql_dm.t_dim_gender(gender_id),
  city_id        int references s_psql_dm.t_dim_city(city_id),
  segment_id     int references s_psql_dm.t_dim_segment(segment_id),

  age            int,
  monthly_income numeric(12,2),

  signup_date    date,
  valid_from     date,
  valid_to       date
);

