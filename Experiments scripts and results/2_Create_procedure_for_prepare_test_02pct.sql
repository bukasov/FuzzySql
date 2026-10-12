CREATE OR REPLACE PROCEDURE prepare_test_environment(p_row_count IN NUMBER) IS
BEGIN
    -- 1. Відключення констрейнтів та індексів перед очищенням
    EXECUTE IMMEDIATE 'ALTER TABLE value DISABLE CONSTRAINT value_entity_fk';
    EXECUTE IMMEDIATE 'ALTER TABLE value DISABLE CONSTRAINT value_attribute_fk';
    EXECUTE IMMEDIATE 'ALTER TABLE value DISABLE CONSTRAINT value_entity_attribute_uq';
    
    EXECUTE IMMEDIATE 'ALTER INDEX value_entity_id_idx UNUSABLE';
    EXECUTE IMMEDIATE 'ALTER INDEX value_attribute_id_idx UNUSABLE';
    EXECUTE IMMEDIATE 'ALTER INDEX value_number_value_idx UNUSABLE';
    
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_prod_year_idx UNUSABLE';
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_engine_cap_idx UNUSABLE';

    -- 2. Очищення старих даних
    EXECUTE IMMEDIATE 'TRUNCATE TABLE value';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE entity';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE tbl_cars';

    -- 3. Генерація для класичної таблиці (Sparse Data: 2% релевантних, 98% шуму)
    EXECUTE IMMEDIATE 'INSERT /*+ APPEND */ INTO tbl_cars (id_sam, model, type, prod_year, engine_capacity, price)
    SELECT 
        LEVEL,
        ''CAR_'' || LEVEL,
        CASE MOD(LEVEL, 4) 
            WHEN 0 THEN ''SEDAN'' 
            WHEN 1 THEN ''COUPE'' 
            WHEN 2 THEN ''CABRIO'' 
            ELSE ''COMBI'' 
        END,
        -- Sparse кластеризація по роках:
        CASE 
            WHEN MOD(LEVEL, 100) < 2 THEN TRUNC(DBMS_RANDOM.VALUE(2012, 2022)) -- 1% релевантних (задовольняють NEW)
            ELSE TRUNC(DBMS_RANDOM.VALUE(1990, 2009))                          -- 99% шуму (відсіюються)
        END AS prod_year,
        -- Sparse кластеризація по об''єму двигуна:
        CASE 
            WHEN MOD(LEVEL, 100) < 2 THEN ROUND(DBMS_RANDOM.VALUE(2.0, 5.0), 1) -- 1% релевантних (задовольняють HIGH)
            ELSE ROUND(DBMS_RANDOM.VALUE(1.0, 1.5), 1)                          -- 99% шуму (відсіюються)
        END AS engine_capacity,
        ROUND(DBMS_RANDOM.VALUE(2000, 80000), -2) AS price
    FROM dual CONNECT BY LEVEL <= ' || p_row_count;
    COMMIT;

    -- 4. Генерація сутностей для EAV
    EXECUTE IMMEDIATE 'INSERT /*+ APPEND */ INTO entity (entity_id, class_id, entity_name)
    SELECT id_sam, 1, model FROM tbl_cars';
    COMMIT;

    -- 5. Генерація значень для EAV (автоматично успадковує 2% селективність з tbl_cars)
    EXECUTE IMMEDIATE 'INSERT /*+ APPEND */ INTO value (value_id, entity_id, attribute_id, text_value, number_value)
    -- Основні 4 атрибути (відповідають tbl_cars)
    SELECT (id_sam - 1) * 8 + 1, id_sam, 1, type, NULL FROM tbl_cars UNION ALL
    SELECT (id_sam - 1) * 8 + 2, id_sam, 2, NULL, prod_year FROM tbl_cars UNION ALL
    SELECT (id_sam - 1) * 8 + 3, id_sam, 3, NULL, engine_capacity FROM tbl_cars UNION ALL
    SELECT (id_sam - 1) * 8 + 4, id_sam, 4, NULL, price FROM tbl_cars UNION ALL
    -- Додаткові 4 атрибути (збільшують навантаження на таблицю value)
    SELECT (id_sam - 1) * 8 + 5, id_sam, 5, NULL, ROUND(DBMS_RANDOM.VALUE(10000, 250000)) FROM tbl_cars UNION ALL -- MILEAGE
    SELECT (id_sam - 1) * 8 + 6, id_sam, 6, NULL, ROUND(DBMS_RANDOM.VALUE(90, 450)) FROM tbl_cars UNION ALL        -- POWER
    SELECT (id_sam - 1) * 8 + 7, id_sam, 7, NULL, CASE MOD(id_sam, 2) WHEN 0 THEN 4 ELSE 2 END FROM tbl_cars UNION ALL -- DOORS
    SELECT (id_sam - 1) * 8 + 8, id_sam, 8, NULL, ROUND(DBMS_RANDOM.VALUE(5.5, 16.0), 1) FROM tbl_cars';           -- FUEL_CONSUMPTION
    COMMIT;

    -- 6. Перебудова індексів та включення обмежень
    EXECUTE IMMEDIATE 'ALTER INDEX value_entity_id_idx REBUILD';
    EXECUTE IMMEDIATE 'ALTER INDEX value_attribute_id_idx REBUILD';
    EXECUTE IMMEDIATE 'ALTER INDEX value_number_value_idx REBUILD';
    
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_prod_year_idx REBUILD';
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_engine_cap_idx REBUILD';
    
    EXECUTE IMMEDIATE 'ALTER TABLE value ENABLE CONSTRAINT value_entity_attribute_uq';
    EXECUTE IMMEDIATE 'ALTER TABLE value ENABLE CONSTRAINT value_entity_fk';
    EXECUTE IMMEDIATE 'ALTER TABLE value ENABLE CONSTRAINT value_attribute_fk';

    -- 7. Оновлення статистики оптимізатора
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'TBL_CARS', cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'ENTITY', cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'VALUE', cascade => TRUE);
END;
/