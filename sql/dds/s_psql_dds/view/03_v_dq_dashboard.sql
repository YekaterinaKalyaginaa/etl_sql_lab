create schema if not exists s_psql_dds;

create or replace view s_psql_dds.v_dq_dashboard as
with last_run as (
  select max(execution_date) as last_execution_date
  from s_psql_dds.t_dq_check_results
  where table_name = 's_psql_dm.v_dm_task'
),
checks as (
  select r.*
  from s_psql_dds.t_dq_check_results r
  join last_run lr
    on r.execution_date = lr.last_execution_date
  where r.table_name = 's_psql_dm.v_dm_task'
),
summary as (
  select
    (select last_execution_date from last_run) as last_execution_date,
    count(*) as total_checks,
    sum(case when status = 'passed' then 1 else 0 end) as passed_checks,
    sum(case when status = 'failed' then 1 else 0 end) as failed_checks,
    sum(case when status = 'error'  then 1 else 0 end) as error_checks
  from checks
),
failed_list as (
  select
    string_agg(check_type || ': ' || error_message, ' | ' order by check_type) as failed_details
  from checks
  where status <> 'passed'
),
data_kpis as (
  select
    count(*) as dm_rows_total,
    sum(case when full_name is null then 1 else 0 end) as null_full_name_rows,
    sum(case when monthly_income is null then 1 else 0 end) as null_income_rows,
    sum(case when segment_id is null then 1 else 0 end) as null_segment_id_rows
  from s_psql_dm.v_dm_task
)
select
  s.last_execution_date,
  s.total_checks,
  s.passed_checks,
  s.failed_checks,
  s.error_checks,
  coalesce(f.failed_details, 'all passed') as failed_details,
  k.dm_rows_total,
  k.null_full_name_rows,
  k.null_income_rows,
  k.null_segment_id_rows
from summary s
cross join data_kpis k
left join failed_list f on true;
