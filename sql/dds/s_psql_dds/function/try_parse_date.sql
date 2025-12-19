create or replace function s_psql_dds.try_parse_date(p_text text)
returns date
language plpgsql
as $$
declare
  d date;
begin
  if p_text is null or btrim(p_text) = '' then
    return null;
  end if;

  begin
    if p_text ~ '^\d{4}-\d{2}-\d{2}$' then
      d := to_date(p_text, 'YYYY-MM-DD');
    elsif p_text ~ '^\d{2}\.\d{2}\.\d{4}$' then
      d := to_date(p_text, 'DD.MM.YYYY');
    elsif p_text ~ '^\d{2}/\d{2}/\d{4}$' then
      d := to_date(p_text, 'DD/MM/YYYY');
    else
      return null;
    end if;

    return d;

  exception when others then
    return null;
  end;
end;
$$;
