\prompt 'Введите значение таблицы: ' table_name
\prompt 'Введите имя схемы: ' start_user_name

\o /dev/null
select set_config('psql.table_name', :'table_name', false);
\o

\o /dev/null
select set_config('psql.start_user_name', :'start_user_name', false);
\o

DO $$
DECLARE
    column_record      record;
    table_id           oid;
    user_name          text;
    my_column_name     text;
    column_number      text;
    column_type        text;
    column_type_id     oid;
    column_comment     text;
    result             text;
    start_user_name    text := current_setting('psql.start_user_name');
    table_name         text := current_setting('psql.table_name');
    primary_key        text;
    foreign_key        text;
BEGIN
    RAISE NOTICE 'Пользователь: %', start_user_name;
    RAISE NOTICE 'Таблица: %', table_name;

    SELECT start_user_name INTO user_name;

    SELECT oid 
    INTO table_id 
    FROM pg_catalog.pg_class 
    WHERE relname = table_name 
      AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = user_name);

    IF NOT FOUND THEN
        RAISE NOTICE 'Таблица % не найдена в схеме %.', table_name, user_name;
        RETURN;
    END IF;

    RAISE NOTICE 'No  Имя столбца    Атрибуты';
    RAISE NOTICE '--- -------------- ------------------------------------------';

    FOR column_record IN 
        SELECT * 
        FROM pg_catalog.pg_attribute 
        WHERE attrelid = table_id 
          AND attnum > 0
    LOOP
        column_number := column_record.attnum::text;
        my_column_name := column_record.attname;
        column_type_id := column_record.atttypid;

        SELECT typname 
        INTO column_type 
        FROM pg_catalog.pg_type 
        WHERE oid = column_type_id;

        IF column_record.atttypmod != -1 THEN
            column_type := column_type || ' (' || (column_record.atttypmod - 4) || ')';
        END IF;

        IF column_record.attnotnull THEN
            column_type := column_type || ' Not null';
        END IF;

        SELECT description 
        INTO column_comment 
        FROM pg_catalog.pg_description 
        WHERE objoid = table_id 
          AND objsubid = column_record.attnum;

        SELECT format('%-3s %-14s %-8s : %s', 
                      column_number, my_column_name, 'Type', column_type)
        INTO result;
        RAISE NOTICE '%', result;

        IF column_comment IS NOT NULL THEN
            RAISE NOTICE '|   Комментарий : %', column_comment;
        END IF;

        SELECT conname
        INTO primary_key
        FROM pg_constraint 
        WHERE conrelid = table_id 
          AND conkey @> ARRAY[column_record.attnum]
          AND contype = 'p';

        IF primary_key IS NOT NULL THEN
            RAISE NOTICE '|   Ключ : PRIMARY KEY';
        END IF;

        SELECT conname
        INTO foreign_key
        FROM pg_constraint 
        WHERE conrelid = table_id 
          AND conkey @> ARRAY[column_record.attnum]
          AND contype = 'f';

        IF foreign_key IS NOT NULL THEN
            RAISE NOTICE '|   Ключ : FOREIGN KEY';
        END IF;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Ошибка: %', SQLERRM;
END $$;
