drop table if exists s_psql_dds.t_sql_source_structured;

create table s_psql_dds.t_sql_source_structured (
    customer_id     integer,
    full_name       text,
    gender          text,
    age             integer,
    city            text,
    segment         text,
    monthly_income  numeric(12,2),
    signup_date     date,
    valid_from      date,
    valid_to        date
);
