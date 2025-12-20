create schema if not exists s_psql_dds;

drop function if exists s_psql_dds.get_dataset(integer);

create or replace function s_psql_dds.get_dataset(p_rows integer)
returns void
language plpgsql
as $$
declare
    i int;
    v_full_name text;
    v_gender text;
    v_age text;
    v_city text;
    v_segment text;
    v_income text;
    v_signup text;
    v_valid_from text;
    v_valid_to text;
begin
    if p_rows is null or p_rows <= 0 then
        return;
    end if;

    for i in 1..p_rows loop
        -- имя (часть пустых/битых)
        v_full_name := (array[
            'Ivan Petrov',
            'Anna-Maria',
            'Ekaterina Kalyagina',
            'Oleg123',
            '   ',
            null,
            'Test User'
        ])[1 + floor(random()*7)::int];

        -- пол (часть мусора)
        v_gender := (array[
            'M','F','male','female','м','ж','жен','??',null,''
        ])[1 + floor(random()*10)::int];

        -- возраст (часть мусора)
        v_age := (array[
            '23','18 лет','-5','0','120','999','abc','5',null,''
        ])[1 + floor(random()*10)::int];

        -- город (часть мусора/разный регистр)
        v_city := (array[
            'Omsk','omsk','Kazan','Ekb','   ',null
        ])[1 + floor(random()*6)::int];

        -- сегмент (часть мусора)
        v_segment := (array[
            'A','B','C','vip','??','',null
        ])[1 + floor(random()*7)::int];

        -- доход (часть мусора/несколько точек)
        v_income := (array[
            '1000.50',
            '1 000,50 руб',
            '12.345.67',
            '$5000',
            '0',
            'abc',
            null,
            ''
        ])[1 + floor(random()*8)::int];

        -- signup_date: часть нормальная, часть битая
        -- важно: ДАТЫ ТУТ СТРОКОЙ (это staging!)
        if random() < 0.70 then
            -- нормальная дата в пределах +/- 3 дней от текущей
            if random() < 0.5 then
                v_signup := to_char(current_date - (floor(random()*7)::int - 3), 'YYYY-MM-DD');
            else
                v_signup := to_char(current_date - (floor(random()*7)::int - 3), 'DD.MM.YYYY');
            end if;
        else
            v_signup := (array[
                '32.13.2025',
                '2025-99-99',
                'not_a_date',
                null,
                ''
            ])[1 + floor(random()*5)::int];
        end if;

        -- valid_from / valid_to: тоже строкой, иногда криво
        if random() < 0.75 then
            v_valid_from := to_char(current_date - floor(random()*30)::int, 'YYYY-MM-DD');
        else
            v_valid_from := (array['32.13.2025','bad',null,''])[1 + floor(random()*4)::int];
        end if;

        if random() < 0.75 then
            v_valid_to := to_char(current_date + floor(random()*60)::int, 'DD/MM/YYYY');
        else
            v_valid_to := (array['32.13.2025','bad',null,''])[1 + floor(random()*4)::int];
        end if;

        insert into s_psql_dds.t_sql_source_unstructured
            (customer_id, full_name, gender, age, city, segment, monthly_income, signup_date, valid_from, valid_to)
        values
            (
                -- customer_id делаем намеренно грязным (иногда буквы)
                case
                    when random() < 0.85 then (100000 + i)::text
                    else 'ID-' || (100000 + i)::text
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
