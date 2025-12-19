create or replace function s_psql_dds.fn_etl_data_load(start_date date, end_date date)
returns void
language plpgsql
as $$
begin
    -- делаем перезапуск безопасным: чистим диапазон, который будем грузить заново
    delete from s_psql_dds.t_sql_source_structured
    where signup_date between start_date and end_date;

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

        -- signup_date: несколько популярных форматов
        case
            when signup_date ~ '^\d{4}-\d{2}-\d{2}$' then to_date(signup_date, 'yyyy-mm-dd')
            when signup_date ~ '^\d{2}\.\d{2}\.\d{4}$' then to_date(signup_date, 'dd.mm.yyyy')
            when signup_date ~ '^\d{2}/\d{2}/\d{4}$' then to_date(signup_date, 'dd/mm/yyyy')
            else null
        end as signup_date,

        -- valid_from
        case
            when valid_from ~ '^\d{4}-\d{2}-\d{2}$' then to_date(valid_from, 'yyyy-mm-dd')
            when valid_from ~ '^\d{2}\.\d{2}\.\d{4}$' then to_date(valid_from, 'dd.mm.yyyy')
            when valid_from ~ '^\d{2}/\d{2}/\d{4}$' then to_date(valid_from, 'dd/mm/yyyy')
            else null
        end as valid_from,

        -- valid_to (и если valid_to < valid_from — делаем valid_to = valid_from)
        case
            when valid_to is null then null
            when valid_to ~ '^\d{4}-\d{2}-\d{2}$' then
                case
                    when (case
                            when valid_from ~ '^\d{4}-\d{2}-\d{2}$' then to_date(valid_from, 'yyyy-mm-dd')
                            when valid_from ~ '^\d{2}\.\d{2}\.\d{4}$' then to_date(valid_from, 'dd.mm.yyyy')
                            when valid_from ~ '^\d{2}/\d{2}/\d{4}$' then to_date(valid_from, 'dd/mm/yyyy')
                            else null
                          end) is not null
                         and to_date(valid_to, 'yyyy-mm-dd') <
                             (case
                                when valid_from ~ '^\d{4}-\d{2}-\d{2}$' then to_date(valid_from, 'yyyy-mm-dd')
                                when valid_from ~ '^\d{2}\.\d{2}\.\d{4}$' then to_date(valid_from, 'dd.mm.yyyy')
                                when valid_from ~ '^\d{2}/\d{2}/\d{4}$' then to_date(valid_from, 'dd/mm/yyyy')
                                else null
                              end)
                    then (case
                            when valid_from ~ '^\d{4}-\d{2}-\d{2}$' then to_date(valid_from, 'yyyy-mm-dd')
                            when valid_from ~ '^\d{2}\.\d{2}\.\d{4}$' then to_date(valid_from, 'dd.mm.yyyy')
                            when valid_from ~ '^\d{2}/\d{2}/\d{4}$' then to_date(valid_from, 'dd/mm/yyyy')
                            else null
                          end)
                    else to_date(valid_to, 'yyyy-mm-dd')
                end
            when valid_to ~ '^\d{2}\.\d{2}\.\d{4}$' then
                case
                    when (case
                            when valid_from ~ '^\d{4}-\d{2}-\d{2}$' then to_date(valid_from, 'yyyy-mm-dd')
                            when valid_from ~ '^\d{2}\.\d{2}\.\d{4}$' then to_date(valid_from, 'dd.mm.yyyy')
                            when valid_from ~ '^\d{2}/\d{2}/\d{4}$' then to_date(valid_from, 'dd/mm/yyyy')
                            else null
                          end) is not null
                         and to_date(valid_to, 'dd.mm.yyyy') <
                             (case
                                when valid_from ~ '^\d{4}-\d{2}-\d{2}$' then to_date(valid_from, 'yyyy-mm-dd')
                                when valid_from ~ '^\d{2}\.\d{2}\.\d{4}$' then to_date(valid_from, 'dd.mm.yyyy')
                                when valid_from ~ '^\d{2}/\d{2}/\d{4}$' then to_date(valid_from, 'dd/mm/yyyy')
                                else null
                              end)
                    then (case
                            when valid_from ~ '^\d{4}-\d{2}-\d{2}$' then to_date(valid_from, 'yyyy-mm-dd')
                            when valid_from ~ '^\d{2}\.\d{2}\.\d{4}$' then to_date(valid_from, 'dd.mm.yyyy')
                            when valid_from ~ '^\d{2}/\d{2}/\d{4}$' then to_date(valid_from, 'dd/mm/yyyy')
                            else null
                          end)
                    else to_date(valid_to, 'dd.mm.yyyy')
                end
            when valid_to ~ '^\d{2}/\d{2}/\d{4}$' then
                case
                    when (case
                            when valid_from ~ '^\d{4}-\d{2}-\d{2}$' then to_date(valid_from, 'yyyy-mm-dd')
                            when valid_from ~ '^\d{2}\.\d{2}\.\d{4}$' then to_date(valid_from, 'dd.mm.yyyy')
                            when valid_from ~ '^\d{2}/\d{2}/\d{4}$' then to_date(valid_from, 'dd/mm/yyyy')
                            else null
                          end) is not null
                         and to_date(valid_to, 'dd/mm/yyyy') <
                             (case
                                when valid_from ~ '^\d{4}-\d{2}-\d{2}$' then to_date(valid_from, 'yyyy-mm-dd')
                                when valid_from ~ '^\d{2}\.\d{2}\.\d{4}$' then to_date(valid_from, 'dd.mm.yyyy')
                                when valid_from ~ '^\d{2}/\d{2}/\d{4}$' then to_date(valid_from, 'dd/mm/yyyy')
                                else null
                              end)
                    then (case
                            when valid_from ~ '^\d{4}-\d{2}-\d{2}$' then to_date(valid_from, 'yyyy-mm-dd')
                            when valid_from ~ '^\d{2}\.\d{2}\.\d{4}$' then to_date(valid_from, 'dd.mm.yyyy')
                            when valid_from ~ '^\d{2}/\d{2}/\d{4}$' then to_date(valid_from, 'dd/mm/yyyy')
                            else null
                          end)
                    else to_date(valid_to, 'dd/mm/yyyy')
                end
            else null
        end as valid_to
    from s_psql_dds.t_sql_source_unstructured
    where
        -- используем параметры периода: грузим только записи, чья signup_date попадает в диапазон
        (
            case
                when signup_date ~ '^\d{4}-\d{2}-\d{2}$' then to_date(signup_date, 'yyyy-mm-dd')
                when signup_date ~ '^\d{2}\.\d{2}\.\d{4}$' then to_date(signup_date, 'dd.mm.yyyy')
                when signup_date ~ '^\d{2}/\d{2}/\d{4}$' then to_date(signup_date, 'dd/mm/yyyy')
                else null
            end
        ) between start_date and end_date;

end;
$$;
