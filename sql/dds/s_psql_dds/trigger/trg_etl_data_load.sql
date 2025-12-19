v_dt := s_psql_dds.try_parse_date(new.signup_date::text);
if v_dt is null then
  v_dt := current_date;
end if;
perform s_psql_dds.fn_etl_data_load(v_dt, v_dt);
