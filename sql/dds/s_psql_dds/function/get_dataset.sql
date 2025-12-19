drop function if exists s_psql_dds.get_dataset(integer);

create or replace function s_psql_dds.get_dataset(p_rows integer)
returns void
language plpgsql
as $$
declare
    i int;

    v_customer_id text;
    v_full_name text;
    v_gender text;
    v_age text;
    v_city text;
    v_segment text;
    v_income text;
    v_signup text;
    v_valid_from text;
    v_valid_to text;

    names text[] := array[
        '  Test User  ', 'Иван   Иванов', '  Anna   Petrova ', 'John  Doe',
        'Мария-Петрова', '  Oleg    Sidorov  ', '  '
    ];

    genders text[] := array['M','F','male','female','man','woman','м','ж','МУЖ','женщина','unknown',''];

    cities text[] := array['Omsk','  Moscow ','spb','New-York','  ', 'Kazan', 'Novosibirsk'];

    segments text[] := array['A','B','C','vip',' mass ','', 'Premium'];

    incomes text[] := array[
        '1000,50', '12 345,67 ₽', '$1,234.56', '1.234,56', '12.345.67',
        '  5000  ', 'RUB 7000', '', 'not_a_number'
    ];

    dates text[] := array[
        '2025-12-20', '20.12.2025', '20/12/2025',
        '32.13.2025', '2025-99-99', '', '  '
    ];

begin
    if p_rows is null or p_rows <= 0 then
        return;
    end if;

    for i in 1..p_rows loop
        -- делаем иногда "грязный" id, иногда нормальный, иногда с мусором
        v_customer_id :=
            case (floor(random()*6))::int
                when 0 then 'ID-' || (100000 + (i % 120))::text
                when 1 then ' ' || (100000 + (i % 120))::text || ' '
                when 2 then replace((100000 + (i % 120))::text, '0', '0 ')  -- пробелы внутри
                when 3 then 'cust#' || (100000 + (i % 120))::text || 'a'
                when 4 then (100000 + (i % 120))::text
                else ''  -- пустой (сломанный)
            end;

        v_full_name := names[1 + floor(random()*array_length(names,1))::int];
        v_gender    := genders[1 + floor(random()*array_length(genders,1))::int];

        -- возраст специально ломаем
        v_age :=
            case (floor(random()*6))::int
                when 0 then (18 + floor(random()*60))::int::text
                when 1 then (18 + floor(random()*60))::int::text || ' years'
                when 2 then 'age:' || (18 + floor(random()*60))::int::text
                when 3 then '-5'
                when 4 then '200'
                else ''
            end;

        v_city    := cities[1 + floor(random()*array_length(cities,1))::int];
        v_segment := segments[1 + floor(random()*array_length(segments,1))::int];
        v_income  := incomes[1 + floor(random()*array_length(incomes,1))::int];

        -- signup_date/valid_from/valid_to тоже мешаем форматами и невалидом
        v_signup    := dates[1 + floor(random()*array_length(dates,1))::int];
        v_valid_from:= dates[1 + floor(random()*array_length(dates,1))::int];
        v_valid_to  := dates[1 + floor(random()*array_length(dates,1))::int];

        insert into s_psql_dds.t_sql_source_unstructured
            (customer_id, full_name, gender, age, city, segment, monthly_income, signup_date, valid_from, valid_to)
        values
            (v_customer_id, v_full_name, v_gender, v_age, v_city, v_segment, v_income, v_signup, v_valid_from, v_valid_to);
    end loop;
end;
$$;
