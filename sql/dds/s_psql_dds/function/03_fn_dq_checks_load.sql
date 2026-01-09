create or replace function s_psql_dds.fn_dq_checks_load(start_dt date, end_dt date)
returns void
language plpgsql
as $$
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
  -- Чтобы результаты не копились бесконечно: чистим проверки за сегодня по витрине (можно убрать, если не хочешь)
  delete from s_psql_dds.t_dq_check_results
  where table_name = 's_psql_dm.v_dm_task'
    and execution_date::date = current_date;

  -- =========================================================
  -- CHECK 1: COMPLETENESS (полнота) — критичное поле customer_id не должно быть NULL
  -- =========================================================
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

  -- =========================================================
  -- CHECK 2: UNIQUENESS (уникальность) — customer_id должен быть уникален в витрине
  -- =========================================================
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

  -- =========================================================
  -- CHECK 3: VALIDITY (валидность) — segment_id должен ссылаться на справочник и НЕ быть "??"
  -- (у тебя "??" реально есть — поэтому это будет failed, и это нормально для демонстрации DQ)
  -- =========================================================
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

  -- =========================================================
  -- CHECK 4: CONSISTENCY (непротиворечивость) — если valid_to есть, то valid_from тоже должен быть и valid_to >= valid_from
  -- =========================================================
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

  -- =========================================================
  -- CHECK 5: ACCURACY/RECONCILIATION (правильность) — сравним количество строк structured vs dm за период
  -- (не всегда 1-в-1 из-за NULL сегментов/джойнов, но у тебя обычно совпадает)
  -- =========================================================
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

$$;
