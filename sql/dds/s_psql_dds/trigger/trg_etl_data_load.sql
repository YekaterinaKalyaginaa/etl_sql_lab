drop function if exists s_psql_dds.trg_etl_data_load();
drop trigger if exists trg_etl_data_load on s_psql_dds.t_sql_source_unstructured;

create or replace function s_psql_dds.trg_etl_data_load()
returns trigger
language plpgsql
as $$
declare
  v_dt date;
begin
  v_dt := s_psql_dds.try_parse_date(new.signup_date);
  if v_dt is null then
    v_dt := current_date;
  end if;

  perform s_psql_dds.fn_etl_data_load(v_dt, v_dt);

  return new;
end;
$$;

create trigger trg_etl_data_load
after insert on s_psql_dds.t_sql_source_unstructured
for each row
execute function s_psql_dds.trg_etl_data_load();
