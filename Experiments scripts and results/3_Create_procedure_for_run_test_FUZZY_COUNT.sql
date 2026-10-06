CREATE OR REPLACE PROCEDURE test_fuzzy_count_perf(p_data_volume IN NUMBER, p_notes IN VARCHAR2) IS
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    ---------------------------------------------------------
    -- 1. FLAT TABLE (Inline CASE + Indexes)
    ---------------------------------------------------------
    v_start_time := SYSTIMESTAMP;
    FOR r IN (
        SELECT /*+ USE_NL(p c) INDEX(c tbl_cars_engine_cap_idx) */ 
               p.linguistic_variable_value, 
               ROUND(SUM(
                 CASE
                   WHEN c.engine_capacity <= p.a THEN 0.0
                   WHEN c.engine_capacity > p.a AND c.engine_capacity <= p.b THEN (c.engine_capacity - p.a) / (p.b - p.a)
                   WHEN c.engine_capacity > p.b AND c.engine_capacity <= p.c THEN 1.0
                   WHEN c.engine_capacity > p.c AND c.engine_capacity <= p.d THEN (p.d - c.engine_capacity) / (p.d - p.c)
                   ELSE 0.0
                 END
               ), 2) AS FUZZY_COUNT
        FROM tbl_possibility p, tbl_cars c
        WHERE p.column_name = 'engine_capacity'
          AND c.engine_capacity > p.a 
          AND c.engine_capacity < p.d
        GROUP BY p.linguistic_variable_value
    ) LOOP NULL; END LOOP;
    v_end_time := SYSTIMESTAMP;
    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'FLAT_TABLE_INLINE', 'FUZZY_COUNT', get_elapsed_ms(v_start_time, v_end_time), p_notes);

    ---------------------------------------------------------
    -- 2. FLAT TABLE (Inline CASE - NO INDEXES)
    ---------------------------------------------------------
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_prod_year_idx UNUSABLE';
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_engine_cap_idx UNUSABLE';

    v_start_time := SYSTIMESTAMP;
    FOR r IN (
        SELECT p.linguistic_variable_value, 
               ROUND(SUM(
                 CASE
                   WHEN c.engine_capacity <= p.a THEN 0.0
                   WHEN c.engine_capacity > p.a AND c.engine_capacity <= p.b THEN (c.engine_capacity - p.a) / (p.b - p.a)
                   WHEN c.engine_capacity > p.b AND c.engine_capacity <= p.c THEN 1.0
                   WHEN c.engine_capacity > p.c AND c.engine_capacity <= p.d THEN (p.d - c.engine_capacity) / (p.d - p.c)
                   ELSE 0.0
                 END
               ), 2) AS FUZZY_COUNT
        FROM tbl_possibility p, tbl_cars c
        WHERE p.column_name = 'engine_capacity'
          AND c.engine_capacity > p.a 
          AND c.engine_capacity < p.d
        GROUP BY p.linguistic_variable_value
    ) LOOP NULL; END LOOP;
    v_end_time := SYSTIMESTAMP;
    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'FLAT_TABLE_INLINE_NO_IDX', 'FUZZY_COUNT', get_elapsed_ms(v_start_time, v_end_time), p_notes);

    ---------------------------------------------------------
    -- 3. FLAT TABLE (Function FP_TRAPEZOID - NO INDEXES)
    ---------------------------------------------------------
    v_start_time := SYSTIMESTAMP;
    FOR r IN (
        SELECT p.linguistic_variable_value, 
               ROUND(SUM(FP_TRAPEZOID(c.engine_capacity,p.a,p.b,p.c,p.d)),2) AS FUZZY_COUNT
        FROM tbl_cars c, tbl_possibility p
        WHERE FP_TRAPEZOID(c.engine_capacity,p.a,p.b,p.c,p.d)>0 
          AND p.column_name='engine_capacity'
        GROUP BY p.linguistic_variable_value
    ) LOOP NULL; END LOOP;
    v_end_time := SYSTIMESTAMP;
    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'FLAT_TABLE_FUNCTION_NO_IDX', 'FUZZY_COUNT', get_elapsed_ms(v_start_time, v_end_time), p_notes);

    -- Відновлення індексів
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_prod_year_idx REBUILD';
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_engine_cap_idx REBUILD';

    ---------------------------------------------------------
    -- 4. FLAT TABLE (Function FP_TRAPEZOID + Indexes)
    ---------------------------------------------------------
    v_start_time := SYSTIMESTAMP;
    FOR r IN (
        SELECT p.linguistic_variable_value, 
               ROUND(SUM(FP_TRAPEZOID(c.engine_capacity,p.a,p.b,p.c,p.d)),2) AS FUZZY_COUNT
        FROM tbl_cars c, tbl_possibility p
        WHERE FP_TRAPEZOID(c.engine_capacity,p.a,p.b,p.c,p.d)>0 
          AND p.column_name='engine_capacity'
        GROUP BY p.linguistic_variable_value
    ) LOOP NULL; END LOOP;
    v_end_time := SYSTIMESTAMP;
    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'FLAT_TABLE_FUNCTION', 'FUZZY_COUNT', get_elapsed_ms(v_start_time, v_end_time), p_notes);

    ---------------------------------------------------------
    -- 5. EAV MODEL (Запропонований підхід)
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
    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'EAV_MODEL', 'FUZZY_COUNT', get_elapsed_ms(v_start_time, v_end_time), p_notes);

    COMMIT;
END;
/