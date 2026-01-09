create schema if not exists s_psql_dm;

create or replace view s_psql_dm.v_dm_task as
select
  customer_id,
  full_name,
  gender_id,
  city_id,
  segment_id,
  age,
  monthly_income,
  signup_date,
  valid_from,
  valid_to
from s_psql_dm.t_dm_task;
