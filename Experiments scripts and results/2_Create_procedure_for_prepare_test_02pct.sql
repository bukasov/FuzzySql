CREATE OR REPLACE PROCEDURE prepare_test_environment(p_row_count IN NUMBER) IS
BEGIN
    -- 1. Відключення констрейнтів та індексів перед очищенням
    EXECUTE IMMEDIATE 'ALTER TABLE value DISABLE CONSTRAINT value_entity_fk';
    EXECUTE IMMEDIATE 'ALTER TABLE value DISABLE CONSTRAINT value_attribute_fk';
    EXECUTE IMMEDIATE 'ALTER TABLE value DISABLE CONSTRAINT value_entity_attribute_uq';
    
    EXECUTE IMMEDIATE 'ALTER INDEX value_entity_id_idx UNUSABLE';
    EXECUTE IMMEDIATE 'ALTER INDEX value_attribute_id_idx UNUSABLE';
    EXECUTE IMMEDIATE 'ALTER INDEX value_number_value_idx UNUSABLE';

    EXECUTE IMMEDIATE 'ALTER INDEX value_attr_num_idx UNUSABLE';
    
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_prod_year_idx UNUSABLE';
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_engine_cap_idx UNUSABLE';

    -- 2. Очищення старих даних
    EXECUTE IMMEDIATE 'TRUNCATE TABLE value';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE entity';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE tbl_cars';

    -- 3. Генерація для класичної таблиці (Sparse Data: незалежні 2% релевантних)
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
        -- Випадкова кластеризація по роках:
        CASE 
            WHEN DBMS_RANDOM.VALUE(0, 1) < 0.02 THEN TRUNC(DBMS_RANDOM.VALUE(2012, 2022)) -- 2% релевантних (задовольняють NEW)
            ELSE TRUNC(DBMS_RANDOM.VALUE(1990, 2009))                          -- 98% шуму
        END AS prod_year,
        -- Випадкова кластеризація по об''єму двигуна:
        CASE 
            WHEN DBMS_RANDOM.VALUE(0, 1) < 0.02 THEN ROUND(DBMS_RANDOM.VALUE(2.0, 5.0), 1) -- 2% релевантних (задовольняють HIGH)
            ELSE ROUND(DBMS_RANDOM.VALUE(1.0, 1.5), 1)                          -- 98% шуму
        END AS engine_capacity,
        ROUND(DBMS_RANDOM.VALUE(2000, 80000), -2) AS price
    FROM dual CONNECT BY LEVEL <= ' || p_row_count;
    COMMIT;

    -- 4. Генерація сутностей для EAV
    EXECUTE IMMEDIATE 'INSERT /*+ APPEND */ INTO entity (entity_id, class_id, entity_name)
    SELECT id_sam, 1, model FROM tbl_cars';
    COMMIT;

    -- 5. Генерація значень для EAV 
    EXECUTE IMMEDIATE 'INSERT /*+ APPEND */ INTO value (value_id, entity_id, attribute_id, text_value, number_value)
    SELECT (id_sam - 1) * 4 + 1, id_sam, 1, type, NULL FROM tbl_cars UNION ALL
    SELECT (id_sam - 1) * 4 + 2, id_sam, 2, NULL, prod_year FROM tbl_cars UNION ALL
    SELECT (id_sam - 1) * 4 + 3, id_sam, 3, NULL, engine_capacity FROM tbl_cars UNION ALL
    SELECT (id_sam - 1) * 4 + 4, id_sam, 4, NULL, price FROM tbl_cars';
    COMMIT;

    -- 6. Перебудова індексів та включення обмежень
    EXECUTE IMMEDIATE 'ALTER INDEX value_entity_id_idx REBUILD';
    EXECUTE IMMEDIATE 'ALTER INDEX value_attribute_id_idx REBUILD';
    EXECUTE IMMEDIATE 'ALTER INDEX value_number_value_idx REBUILD';

    EXECUTE IMMEDIATE 'ALTER INDEX value_attr_num_idx REBUILD';
    
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_prod_year_idx REBUILD';
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_engine_cap_idx REBUILD';
    
    EXECUTE IMMEDIATE 'ALTER TABLE value ENABLE CONSTRAINT value_entity_attribute_uq';
    EXECUTE IMMEDIATE 'ALTER TABLE value ENABLE CONSTRAINT value_entity_fk';
    EXECUTE IMMEDIATE 'ALTER TABLE value ENABLE CONSTRAINT value_attribute_fk';

    -- 7. Оновлення статистики оптимізатора
	DBMS_STATS.GATHER_SCHEMA_STATS(ownname => USER);
	
    --DBMS_STATS.GATHER_TABLE_STATS(USER, 'TBL_CARS', cascade => TRUE);
    --DBMS_STATS.GATHER_TABLE_STATS(USER, 'ENTITY', cascade => TRUE);
    --DBMS_STATS.GATHER_TABLE_STATS(USER, 'VALUE', cascade => TRUE);
END;
/