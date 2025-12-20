create schema if not exists s_psql_dds;

drop function if exists s_psql_dds.try_parse_numeric(text);

create or replace function s_psql_dds.try_parse_numeric(p_text text)
returns numeric(12,2)
language plpgsql
as $$
declare
    s text;
    parts text[];
    n numeric;
begin
    if p_text is null then
        return null;
    end if;

    -- 1) базовая чистка
    s := lower(btrim(p_text));
    s := regexp_replace(s, '\s+', '', 'g');        -- убрать пробелы
    s := replace(s, ',', '.');                     -- запятая -> точка
    s := regexp_replace(s, '[^0-9\.\-]', '', 'g'); -- оставить цифры, точку, минус

    -- пустое/мусор
    if s in ('', '-', '.', '-.') then
        return null;
    end if;

    -- 2) если точек много (12.345.67), оставляем последнюю как десятичную
    parts := regexp_split_to_array(s, '\.');
    if array_length(parts, 1) is not null and array_length(parts, 1) > 2 then
        s := array_to_string(parts[1:array_length(parts,1)-1], '') || '.' || parts[array_length(parts,1)];
    end if;

    -- 3) безопасный каст
    begin
        n := s::numeric;
        return round(n, 2)::numeric(12,2);
    exception when others then
        return null;
    end;
end;
$$;
