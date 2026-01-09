create schema if not exists s_psql_dds;

create or replace function s_psql_dds.fn_dq_checks_load(start_dt date, end_dt date)
returns void
language plpgsql
as $$
declare
  v_cnt bigint;
  v_src bigint;
  v_dm  bigint;
begin
  delete from s_psql_dds.t_dq_check_results
  where table_name = 's_psql_dm.v_dm_task'
    and execution_date::date = current_date;

  -- 1) completeness_customer_id
  begin
    select count(*) into v_cnt
    from s_psql_dm.v_dm_task
    where signup_date between start_dt and end_dt
      and customer_id is null;

    insert into s_psql_dds.t_dq_check_results(check_type, table_name, status, error_message)
    values (
      'completeness_customer_id',
      's_psql_dm.v_dm_task',
      case when v_cnt = 0 then 'passed' else 'failed' end,
      'null customer_id rows = ' || v_cnt
    );
  exception when others then
    insert into s_psql_dds.t_dq_check_results(check_type, table_name, status, error_message)
    values ('completeness_customer_id', 's_psql_dm.v_dm_task', 'error', sqlerrm);
  end;

  -- 2) uniqueness_customer_id
  begin
    select count(*) into v_cnt
    from (
      select customer_id
      from s_psql_dm.v_dm_task
      where signup_date between start_dt and end_dt
      group by customer_id
      having count(*) > 1
    ) t;

    insert into s_psql_dds.t_dq_check_results(check_type, table_name, status, error_message)
    values (
      'uniqueness_customer_id',
      's_psql_dm.v_dm_task',
      case when v_cnt = 0 then 'passed' else 'failed' end,
      'duplicate customer_id groups = ' || v_cnt
    );
  exception when others then
    insert into s_psql_dds.t_dq_check_results(check_type, table_name, status, error_message)
    values ('uniqueness_customer_id', 's_psql_dm.v_dm_task', 'error', sqlerrm);
  end;

  -- 3) validity_segment
  begin
    select count(*) into v_cnt
    from s_psql_dm.v_dm_task d
    left join s_psql_dm.t_dim_segment s
      on s.segment_id = d.segment_id
    where d.signup_date between start_dt and end_dt
      and d.segment_id is not null
      and (s.segment_name is null or s.segment_name = '??');

    insert into s_psql_dds.t_dq_check_results(check_type, table_name, status, error_message)
    values (
      'validity_segment',
      's_psql_dm.v_dm_task',
      case when v_cnt = 0 then 'passed' else 'failed' end,
      'bad segment rows (null ref or ??) = ' || v_cnt
    );
  exception when others then
    insert into s_psql_dds.t_dq_check_results(check_type, table_name, status, error_message)
    values ('validity_segment', 's_psql_dm.v_dm_task', 'error', sqlerrm);
  end;

  -- 4) consistency_valid_dates
  begin
    select count(*) into v_cnt
    from s_psql_dm.v_dm_task
    where signup_date between start_dt and end_dt
      and valid_to is not null
      and (valid_from is null or valid_to < valid_from);

    insert into s_psql_dds.t_dq_check_results(check_type, table_name, status, error_message)
    values (
      'consistency_valid_dates',
      's_psql_dm.v_dm_task',
      case when v_cnt = 0 then 'passed' else 'failed' end,
      'bad validity dates rows = ' || v_cnt
    );
  exception when others then
    insert into s_psql_dds.t_dq_check_results(check_type, table_name, status, error_message)
    values ('consistency_valid_dates', 's_psql_dm.v_dm_task', 'error', sqlerrm);
  end;

  -- 5) accuracy_rowcount_structured_vs_dm
  begin
    select count(*) into v_src
    from s_psql_dds.t_sql_source_structured
    where signup_date between start_dt and end_dt;

    select count(*) into v_dm
    from s_psql_dm.v_dm_task
    where signup_date between start_dt and end_dt;

    insert into s_psql_dds.t_dq_check_results(check_type, table_name, status, error_message)
    values (
      'accuracy_rowcount_structured_vs_dm',
      's_psql_dm.v_dm_task',
      case when v_src = v_dm then 'passed' else 'failed' end,
      'structured_rows=' || v_src || ', dm_rows=' || v_dm
    );
  exception when others then
    insert into s_psql_dds.t_dq_check_results(check_type, table_name, status, error_message)
    values ('accuracy_rowcount_structured_vs_dm', 's_psql_dm.v_dm_task', 'error', sqlerrm);
  end;

end;
$$;
