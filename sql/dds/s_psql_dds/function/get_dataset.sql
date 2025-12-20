create schema if not exists s_psql_dds;

drop function if exists s_psql_dds.get_dataset(integer);

create or replace function s_psql_dds.get_dataset(p_rows integer default 100)
returns void
language plpgsql
as $$
declare
    i int;
    base_id int;

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
        'Ivan Petrov','Anna-Maria','Ekaterina Kalagina','Oleg123','Test User','   ',
        'Dmitry','Svetlana Ivanova','John Doe','Мария Петрова'
    ];

    genders text[] := array['M','F','male','female','man','woman','м','ж','МУЖ','ЖЕН','??',''];
    cities  text[] := array['Omsk','omsk','SPb','Ekb','Kazan','', '  ', 'Moscow'];
    segments text[] := array['A','B','C','vip','VIP','??','', '  '];

    -- разные “грязные” форматы денег, включая такие, которые раньше тебя роняли
    incomes text[] := array[
        '1000.50','1 000,50','5000','12.345.67','25 000 руб.','USD 1234.56','', '  ', '10,000.00'
    ];

    -- даты: нормальные, разные форматы, и намеренно сломанные
    dates text[] := array[
        '2025-12-19','19.12.2025','19/12/2025',
        '32.13.2025','99/99/9999','', '  '
    ];
begin
    if p_rows is null or p_rows <= 0 then
        return;
    end if;

    for i in 1..p_rows loop
        base_id := 100000 + i;  -- ВАЖНО: уникальные цифры, чтобы после очистки не было дублей

        v_full_name := names[1 + floor(random() * array_length(names, 1))::int];
        v_gender    := genders[1 + floor(random() * array_length(genders, 1))::int];
        v_age       := (array[
            (floor(random()*90)+5)::int::text,
            '0', '120', '150', '-5', '5 лет', '??', ''
        ])[1 + floor(random()*8)::int];

        v_city      := cities[1 + floor(random() * array_length(cities, 1))::int];
        v_segment   := segments[1 + floor(random() * array_length(segments, 1))::int];
        v_income    := incomes[1 + floor(random() * array_length(incomes, 1))::int];

        v_signup    := dates[1 + floor(random() * array_length(dates, 1))::int];
        v_valid_from:= dates[1 + floor(random() * array_length(dates, 1))::int];
        v_valid_to  := dates[1 + floor(random() * array_length(dates, 1))::int];

        -- добавим “грязь” пробелами иногда
        if random() < 0.2 then v_full_name := '  ' || v_full_name || ' '; end if;
        if random() < 0.2 then v_city := v_city || '  '; end if;

        insert into s_psql_dds.t_sql_source_unstructured
            (customer_id, full_name, gender, age, city, segment, monthly_income, signup_date, valid_from, valid_to)
        values
            (
                -- оставляем цифры уникальными, но добавим мусор вокруг (после очистки всё равно будет base_id)
                case
                    when random() < 0.3 then 'ID-' || base_id::text
                    when random() < 0.6 then base_id::text || 'x'
                    else base_id::text
                end,
                v_full_name,
                v_gender,
                v_age,
                v_city,
                v_segment,
                v_income,
                v_signup,
                v_valid_from,
                v_valid_to
            );
    end loop;

end;
$$;
