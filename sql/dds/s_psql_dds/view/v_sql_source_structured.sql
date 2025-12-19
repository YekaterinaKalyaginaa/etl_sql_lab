-- VIEW: удобный "чистый" слой для чтения данных из structured-таблицы

create schema if not exists s_psql_dds;

drop view if exists s_psql_dds.v_sql_source_structured;

create or replace view s_psql_dds.v_sql_source_structured as
select
    customer_id,
    full_name,
    gender,
    age,
    city,
    segment,
    monthly_income,
    signup_date,
    valid_from,
    valid_to,

    -- доп. поля для удобства (если даты есть)
    case
        when valid_from is not null and valid_to is not null
        then (valid_to - valid_from)
        else null
    end as validity_days,

    case
        when valid_to is not null
        then (valid_to - current_date)
        else null
    end as days_to_expire
from s_psql_dds.t_sql_source_structured;
