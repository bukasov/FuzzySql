CREATE OR REPLACE PROCEDURE test_fuzzy_count_perf(p_data_volume IN NUMBER, p_notes IN VARCHAR2) IS
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_elapsed_ms NUMBER;
    v_interval INTERVAL DAY TO SECOND;
BEGIN
    ---------------------------------------------------------
    -- 1. FLAT TABLE (Inline CASE)
    -- Запит з інлайн-математикою замість виклику функції
    ---------------------------------------------------------
    v_start_time := SYSTIMESTAMP;
    
    FOR r IN (
        SELECT linguistic_variable_value, 
               ROUND(SUM(
                 CASE
                   WHEN engine_capacity <= a THEN 0.0
                   WHEN engine_capacity > a AND engine_capacity <= b THEN (engine_capacity - a) / (b - a)
                   WHEN engine_capacity > b AND engine_capacity <= c THEN 1.0
                   WHEN engine_capacity > c AND engine_capacity <= d THEN (d - engine_capacity) / (d - c)
                   ELSE 0.0
                 END
               ), 2) AS FUZZY_COUNT
        FROM tbl_cars, tbl_possibility
        WHERE column_name = 'engine_capacity'
          AND engine_capacity > a 
          AND engine_capacity < d
        GROUP BY linguistic_variable_value
    ) LOOP NULL; END LOOP;

    v_end_time := SYSTIMESTAMP;
    v_interval := v_end_time - v_start_time;
    v_elapsed_ms := EXTRACT(DAY FROM v_interval) * 86400000 +
                    EXTRACT(HOUR FROM v_interval) * 3600000 +
                    EXTRACT(MINUTE FROM v_interval) * 60000 +
                    EXTRACT(SECOND FROM v_interval) * 1000;

    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'FLAT_TABLE_INLINE', 'FUZZY_COUNT', v_elapsed_ms, p_notes);

    ---------------------------------------------------------
    -- 2. EAV MODEL (Запропонований підхід)
    -- Запит з використанням INNER JOIN по таблицях EAV
    ---------------------------------------------------------
    v_start_time := SYSTIMESTAMP;
    
    FOR r IN (
        SELECT lvv AS linguistic_variable_value, 
               ROUND(SUM(y1+ (NUMBER_VALUE - x1) * (y2-y1)/(x2-x1)),2) AS fuzzy_count
        FROM entity 
            JOIN value USING(entity_id)
            JOIN attribute USING(attribute_id)
            JOIN lvv USING(attribute_id)
            JOIN mf USING(lvv_id)
        WHERE attribute_id=3 AND NUMBER_VALUE >= x1 AND NUMBER_VALUE < x2
        GROUP BY lvv
    ) LOOP NULL; END LOOP;

    v_end_time := SYSTIMESTAMP;
    v_interval := v_end_time - v_start_time;
    v_elapsed_ms := EXTRACT(DAY FROM v_interval) * 86400000 +
                    EXTRACT(HOUR FROM v_interval) * 3600000 +
                    EXTRACT(MINUTE FROM v_interval) * 60000 +
                    EXTRACT(SECOND FROM v_interval) * 1000;

    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'EAV_MODEL', 'FUZZY_COUNT', v_elapsed_ms, p_notes);

    ---------------------------------------------------------
    -- 3. FLAT TABLE (Original Function)
    -- Класичний підхід із викликом скалярної PL/SQL функції
    ---------------------------------------------------------
    v_start_time := SYSTIMESTAMP;
    
    FOR r IN (
        SELECT linguistic_variable_value, 
               ROUND(SUM(FP_TRAPEZOID(engine_capacity,a,b,c,d)),2) AS FUZZY_COUNT
        FROM tbl_cars, tbl_possibility
        WHERE FP_TRAPEZOID(engine_capacity,a,b,c,d)>0 
          AND column_name='engine_capacity'
        GROUP BY linguistic_variable_value
    ) LOOP NULL; END LOOP;

    v_end_time := SYSTIMESTAMP;
    v_interval := v_end_time - v_start_time;
    v_elapsed_ms := EXTRACT(DAY FROM v_interval) * 86400000 +
                    EXTRACT(HOUR FROM v_interval) * 3600000 +
                    EXTRACT(MINUTE FROM v_interval) * 60000 +
                    EXTRACT(SECOND FROM v_interval) * 1000;

    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'FLAT_TABLE_FUNCTION', 'FUZZY_COUNT', v_elapsed_ms, p_notes);

    COMMIT;
END;
/