create schema if not exists s_psql_dds;

drop function if exists s_psql_dds.try_parse_date(text);

create or replace function s_psql_dds.try_parse_date(p_text text)
returns date
language plpgsql
as $$
declare
    d date;
    s text;
begin
    if p_text is null then
        return null;
    end if;

    s := btrim(p_text);
    if s = '' then
        return null;
    end if;

    begin
        if s ~ '^\d{4}-\d{2}-\d{2}$' then
            d := to_date(s, 'YYYY-MM-DD');
        elsif s ~ '^\d{2}\.\d{2}\.\d{4}$' then
            d := to_date(s, 'DD.MM.YYYY');
        elsif s ~ '^\d{2}/\d{2}/\d{4}$' then
            d := to_date(s, 'DD/MM/YYYY');
        else
            return null;
        end if;

        return d;

    exception when others then
        return null;
    end;
end;
$$;
