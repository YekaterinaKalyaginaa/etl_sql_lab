-- Триггер: после вставки в "грязную" таблицу
-- автоматически запускаем ETL-функцию загрузки в structured.

-- 1) функция-триггер
create or replace function s_psql_dds.trg_etl_data_load()
returns trigger
language plpgsql
as $$
declare
  v_dt date;
begin
  -- Берём дату из NEW.signup_date (в varchar), пытаемся распарсить
  v_dt :=
    case
      when NEW.signup_date ~ '^\d{4}-\d{2}-\d{2}$' then to_date(NEW.signup_date, 'YYYY-MM-DD')
      when NEW.signup_date ~ '^\d{2}\.\d{2}\.\d{4}$' then to_date(NEW.signup_date, 'DD.MM.YYYY')
      when NEW.signup_date ~ '^\d{2}/\d{2}/\d{4}$' then to_date(NEW.signup_date, 'DD/MM/YYYY')
      else null
    end;

  -- Если дату не распарсили — просто грузим "за сегодня"
  if v_dt is null then
    v_dt := current_date;
  end if;

  -- 2) Запускаем ETL-функцию на период = один день
  -- ВАЖНО: это подходит, если fn_etl_data_load(p_date_from date, p_date_to date)
  perform s_psql_dds.fn_etl_data_load(v_dt, v_dt);

  return NEW;
end;
$$;

-- 3) сам триггер на таблицу-источник
drop trigger if exists trg_etl_data_load_ai on s_psql_dds.t_sql_source_unstructured;

create trigger trg_etl_data_load_ai
after insert on s_psql_dds.t_sql_source_unstructured
for each row
execute function s_psql_dds.trg_etl_data_load();
