CREATE OR REPLACE PROCEDURE prepare_test_environment(p_row_count IN NUMBER) IS
BEGIN
    -- 1. Відключення констрейнтів та індексів
    -- Відключення зовнішніх ключів та унікальних обмежень EAV
    EXECUTE IMMEDIATE 'ALTER TABLE value DISABLE CONSTRAINT value_entity_fk';
    EXECUTE IMMEDIATE 'ALTER TABLE value DISABLE CONSTRAINT value_attribute_fk';
    EXECUTE IMMEDIATE 'ALTER TABLE value DISABLE CONSTRAINT value_entity_attribute_uq';
    
    -- Переведення індексів таблиці value у стан UNUSABLE
    EXECUTE IMMEDIATE 'ALTER INDEX value_entity_id_idx UNUSABLE';
    EXECUTE IMMEDIATE 'ALTER INDEX value_attribute_id_idx UNUSABLE';
    EXECUTE IMMEDIATE 'ALTER INDEX value_number_value_idx UNUSABLE';
    
    -- Переведення індексів класичної таблиці у стан UNUSABLE
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_prod_year_idx UNUSABLE';
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_engine_cap_idx UNUSABLE';

    -- 2. Очищення старих даних
    EXECUTE IMMEDIATE 'TRUNCATE TABLE value';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE entity';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE tbl_cars';

    -- 3. Генерація для класичної таблиці (Flat Table)
    EXECUTE IMMEDIATE 'INSERT /*+ APPEND */ INTO tbl_cars (id_sam, model, type, prod_year, engine_capacity, price)
    SELECT 
        LEVEL,
        ''CAR_'' || LEVEL,
        CASE MOD(LEVEL, 4) WHEN 0 THEN ''SEDAN'' WHEN 1 THEN ''COUPE'' WHEN 2 THEN ''CABRIO'' ELSE ''COMBI'' END,
        ROUND(2010 + DBMS_RANDOM.NORMAL * 5),
        ROUND(DBMS_RANDOM.VALUE(1.0, 5.0), 1),
        ROUND(DBMS_RANDOM.VALUE(1500, 120000), -2)
    FROM dual CONNECT BY LEVEL <= ' || p_row_count;
    COMMIT;

    -- 4. Генерація сутностей для EAV (відповідно до tbl_cars)
    EXECUTE IMMEDIATE 'INSERT /*+ APPEND */ INTO entity (entity_id, class_id, entity_name)
    SELECT id_sam, 1, model FROM tbl_cars';
    COMMIT;

    -- 5. Генерація значень (Values) для EAV
    EXECUTE IMMEDIATE 'INSERT /*+ APPEND */ INTO value (value_id, entity_id, attribute_id, text_value, number_value)
    SELECT (id_sam - 1) * 4 + 1, id_sam, 1, type, NULL FROM tbl_cars UNION ALL
    SELECT (id_sam - 1) * 4 + 2, id_sam, 2, NULL, prod_year FROM tbl_cars UNION ALL
    SELECT (id_sam - 1) * 4 + 3, id_sam, 3, NULL, engine_capacity FROM tbl_cars UNION ALL
    SELECT (id_sam - 1) * 4 + 4, id_sam, 4, NULL, price FROM tbl_cars';
    COMMIT;

    -- 6. Перебудова індексів та включення констрейнтів
    -- Відновлення індексів EAV
    EXECUTE IMMEDIATE 'ALTER INDEX value_entity_id_idx REBUILD';
    EXECUTE IMMEDIATE 'ALTER INDEX value_attribute_id_idx REBUILD';
    EXECUTE IMMEDIATE 'ALTER INDEX value_number_value_idx REBUILD';
    
    -- Відновлення індексів класичної таблиці
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_prod_year_idx REBUILD';
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_engine_cap_idx REBUILD';
    
    -- Включення констрейнтів EAV
    EXECUTE IMMEDIATE 'ALTER TABLE value ENABLE CONSTRAINT value_entity_attribute_uq';
    EXECUTE IMMEDIATE 'ALTER TABLE value ENABLE CONSTRAINT value_entity_fk';
    EXECUTE IMMEDIATE 'ALTER TABLE value ENABLE CONSTRAINT value_attribute_fk';

    -- 7. Оновлення статистики оптимізатора
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'TBL_CARS', cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'ENTITY', cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'VALUE', cascade => TRUE);
END;
/