create schema if not exists s_psql_dds;

drop table if exists s_psql_dds.t_dq_check_results;

create table s_psql_dds.t_dq_check_results (
  check_id serial primary key,
  check_type varchar,
  table_name varchar,
  execution_date timestamp(6) default current_timestamp,
  status varchar,
  error_message varchar
);
