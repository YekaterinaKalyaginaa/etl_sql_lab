drop function if exists s_psql_dds.try_parse_numeric(text);

create or replace function s_psql_dds.try_parse_numeric(p_text text)
returns numeric
language plpgsql
as $$
declare
    s text;
    last_dot int;
    last_com int;
    last_sep int;
    int_part text;
    frac_part text;
    cleaned text;
begin
    if p_text is null then
        return null;
    end if;

    -- оставляем только цифры и разделители . ,
    s := regexp_replace(lower(btrim(p_text)), '[^0-9\.,]', '', 'g');

    if s is null or s = '' then
        return null;
    end if;

    -- ищем последнюю точку/запятую (как десятичный разделитель)
    if position('.' in reverse(s)) > 0 then
        last_dot := length(s) - position('.' in reverse(s)) + 1;
    else
        last_dot := 0;
    end if;

    if position(',' in reverse(s)) > 0 then
        last_com := length(s) - position(',' in reverse(s)) + 1;
    else
        last_com := 0;
    end if;

    -- если вообще нет разделителей — просто число
    if last_dot = 0 and last_com = 0 then
        cleaned := s;
        begin
            return cleaned::numeric;
        exception when others then
            return null;
        end;
    end if;

    -- выбираем правый разделитель как десятичный
    last_sep := greatest(last_dot, last_com);

    int_part  := substring(s from 1 for last_sep - 1);
    frac_part := substring(s from last_sep + 1);

    -- убираем все разделители из частей
    int_part  := regexp_replace(int_part,  '[\.,]', '', 'g');
    frac_part := regexp_replace(frac_part, '[\.,]', '', 'g');

    if int_part is null or int_part = '' then
        int_part := '0';
    end if;

    if frac_part is null or frac_part = '' then
        cleaned := int_part;
    else
        cleaned := int_part || '.' || frac_part;
    end if;

    begin
        return cleaned::numeric;
    exception when others then
        return null;
    end;
end;
$$;
