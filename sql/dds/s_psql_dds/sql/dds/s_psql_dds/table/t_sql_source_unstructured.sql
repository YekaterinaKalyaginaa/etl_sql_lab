create schema if not exists s_psql_dds;

drop table if exists s_psql_dds.t_sql_source_unstructured;

create table s_psql_dds.t_sql_source_unstructured (
    customer_id     varchar,
    full_name       varchar,
    gender          varchar,
    age             varchar,
    city            varchar,
    segment         varchar,
    monthly_income  varchar,
    signup_date     varchar,
    valid_from      varchar,
    valid_to        varchar
);
