create schema if not exists s_psql_dds;

create or replace view s_psql_dds.v_dq_alert as
with last_run as (
  select max(execution_date) as last_execution_date
  from s_psql_dds.t_dq_check_results
  where table_name = 's_psql_dm.v_dm_task'
),
checks as (
  select r.*
  from s_psql_dds.t_dq_check_results r
  join last_run lr on r.execution_date = lr.last_execution_date
  where r.table_name = 's_psql_dm.v_dm_task'
)
select
  (select last_execution_date from last_run) as last_execution_date,
  case
    when exists (select 1 from checks where status = 'error') then 'CRITICAL'
    when exists (select 1 from checks where status = 'failed') then 'WARNING'
    else 'OK'
  end as alert_level,
  count(*) filter (where status='passed') as passed_cnt,
  count(*) filter (where status='failed') as failed_cnt,
  count(*) filter (where status='error')  as error_cnt
from checks;
