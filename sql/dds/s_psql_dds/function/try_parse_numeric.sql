create schema if not exists s_psql_dds;

drop function if exists s_psql_dds.try_parse_numeric(text);

create or replace function s_psql_dds.try_parse_numeric(p_text text)
returns numeric(12,2)
language plpgsql
as $$
declare
    s text;
    int_part text;
    frac_part text;
    norm text;
begin
    if p_text is null then
        return null;
    end if;

    s := lower(btrim(p_text));
    if s = '' then
        return null;
    end if;

    -- оставляем только цифры, точку, запятую, минус
    s := regexp_replace(s, '[^0-9\.,\-]', '', 'g');
    if s = '' or s = '-' then
        return null;
    end if;

    -- если нет разделителей дробной части вообще
    if position('.' in s) = 0 and position(',' in s) = 0 then
        norm := regexp_replace(s, '[^0-9\-]', '', 'g');
        if norm = '' or norm = '-' then
            return null;
        end if;
        return norm::numeric(12,2);
    end if;

    -- берём ПОСЛЕДНИЙ разделитель (.,) как десятичный
    -- всё слева чистим от разделителей тысяч, всё справа оставляем как дробную
    int_part := regexp_replace(regexp_replace(s, '([.,])[^.,]*$', ''), '[^0-9\-]', '', 'g');
    frac_part := regexp_replace(regexp_replace(s, '.*[.,]', ''), '[^0-9]', '', 'g');

    if int_part = '' or int_part = '-' then
        return null;
    end if;

    if frac_part is null or frac_part = '' then
        norm := int_part;
    else
        norm := int_part || '.' || frac_part;
    end if;

    return norm::numeric(12,2);

exception when others then
    return null;
end;
$$;
