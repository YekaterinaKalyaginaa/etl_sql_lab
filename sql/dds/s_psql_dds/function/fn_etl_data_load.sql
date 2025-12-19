create or replace function s_psql_dds.fn_etl_data_load(
    start_date date,
    end_date   date
)
returns void
language plpgsql
as $$
begin
    -- ВАЖНО: никаких to_date(...) на сырых строках.
    -- Только try_parse_date(), которая возвращает NULL, если дата мусорная.

    insert into s_psql_dds.t_sql_source_structured (
        customer_id,
        full_name,
        gender,
        age,
        city,
        segment,
        monthly_income,
        signup_date,
        valid_from,
        valid_to
    )
    select
        -- customer_id: берём только цифры
        nullif(regexp_replace(customer_id, '[^0-9]', '', 'g'), '')::int as customer_id,

        -- full_name: trim + пустые в null
        nullif(btrim(full_name), '') as full_name,

        -- gender: нормализуем варианты
        case
            when lower(btrim(gender)) in ('m','male','man','м','муж','мужчина') then 'male'
            when lower(btrim(gender)) in ('f','female','woman','ж','жен','женщина') then 'female'
            else null
        end as gender,

        -- age: берём цифры и режем диапазон 0..120
        case
            when nullif(regexp_replace(age, '[^0-9]', '', 'g'), '') is null then null
            else least(120, greatest(0, nullif(regexp_replace(age, '[^0-9]', '', 'g'), '')::int))
        end as age,

        nullif(btrim(city), '') as city,
        nullif(btrim(segment), '') as segment,

        -- monthly_income: убираем валюты/пробелы, приводим , -> .
        case
            when nullif(btrim(monthly_income), '') is null then null
            else nullif(
                    regexp_replace(
                        replace(replace(lower(btrim(monthly_income)), ' ', ''), ',', '.'),
                        '[^0-9\.]',
                        '',
                        'g'
                    ),
                    ''
                 )::numeric(12,2)
        end as monthly_income,

        -- signup_date: безопасно
        s_psql_dds.try_parse_date(signup_date) as signup_date,

        -- valid_from: безопасно
        s_psql_dds.try_parse_date(valid_from) as valid_from,

        -- valid_to: безопасно + если valid_to < valid_from → делаем valid_to = valid_from
        case
            when s_psql_dds.try_parse_date(valid_to) is null then null
            when s_psql_dds.try_parse_date(valid_from) is not null
                 and s_psql_dds.try_parse_date(valid_to) < s_psql_dds.try_parse_date(valid_from)
            then s_psql_dds.try_parse_date(valid_from)
            else s_psql_dds.try_parse_date(valid_to)
        end as valid_to

    from s_psql_dds.t_sql_source_unstructured

    where
        -- фильтр по периоду ТОЛЬКО через безопасный парсер
        s_psql_dds.try_parse_date(signup_date) between start_date and end_date

    on conflict (customer_id) do update set
        full_name      = excluded.full_name,
        gender         = excluded.gender,
        age            = excluded.age,
        city           = excluded.city,
        segment        = excluded.segment,
        monthly_income = excluded.monthly_income,
        signup_date    = excluded.signup_date,
        valid_from     = excluded.valid_from,
        valid_to       = excluded.valid_to;

end;
$$;
