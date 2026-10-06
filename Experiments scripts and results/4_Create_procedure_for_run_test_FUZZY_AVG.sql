CREATE OR REPLACE PROCEDURE test_fuzzy_avg_perf(p_data_volume IN NUMBER, p_notes IN VARCHAR2) IS
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;

BEGIN
    ---------------------------------------------------------
    -- 1. FLAT TABLE (Inline CASE + Indexes)
    ---------------------------------------------------------
    v_start_time := SYSTIMESTAMP;
    FOR r IN (
        SELECT linguistic_variable_value, 
               ROUND(SUM(weight * price) / SUM(weight), 2) AS FUZZY_AVG
        FROM (
            SELECT /*+ USE_NL(p c) INDEX(c tbl_cars_prod_year_idx) */
                   p.linguistic_variable_value, 
                   c.price,
                   CASE 
                     WHEN c.prod_year <= p.a THEN 0.0
                     WHEN c.prod_year > p.a AND c.prod_year <= p.b THEN (c.prod_year - p.a) / (p.b - p.a)
                     WHEN c.prod_year > p.b AND c.prod_year <= p.c THEN 1.0
                     WHEN c.prod_year > p.c AND c.prod_year <= p.d THEN (p.d - c.prod_year) / (p.d - p.c)
                     ELSE 0.0 
                   END AS weight
            FROM tbl_cars c
            JOIN tbl_possibility p ON p.column_name = 'prod_year'
            WHERE p.linguistic_variable_value = 'NEW' -- Ізолюємо цільову групу 2%
              AND c.prod_year > p.a AND c.prod_year < p.d
        )
        GROUP BY linguistic_variable_value
    ) LOOP NULL; END LOOP;
    v_end_time := SYSTIMESTAMP;
    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'FLAT_TABLE_INLINE', 'FUZZY_AVG', get_elapsed_ms(v_start_time, v_end_time), p_notes);

    ---------------------------------------------------------
    -- 2. FLAT TABLE (Inline CASE - NO INDEXES)
    ---------------------------------------------------------
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_prod_year_idx UNUSABLE';
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_engine_cap_idx UNUSABLE';

    v_start_time := SYSTIMESTAMP;
    FOR r IN (
        SELECT linguistic_variable_value, 
               ROUND(SUM(weight * price) / SUM(weight), 2) AS FUZZY_AVG
        FROM (
            SELECT p.linguistic_variable_value, 
                   c.price,
                   CASE 
                     WHEN c.prod_year <= p.a THEN 0.0
                     WHEN c.prod_year > p.a AND c.prod_year <= p.b THEN (c.prod_year - p.a) / (p.b - p.a)
                     WHEN c.prod_year > p.b AND c.prod_year <= p.c THEN 1.0
                     WHEN c.prod_year > p.c AND c.prod_year <= p.d THEN (p.d - c.prod_year) / (p.d - p.c)
                     ELSE 0.0 
                   END AS weight
            FROM tbl_cars c
            JOIN tbl_possibility p ON p.column_name = 'prod_year'
            WHERE p.linguistic_variable_value = 'NEW' -- Ізолюємо цільову групу 2%
              AND c.prod_year > p.a AND c.prod_year < p.d
        )
        GROUP BY linguistic_variable_value
    ) LOOP NULL; END LOOP;
    v_end_time := SYSTIMESTAMP;
    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'FLAT_TABLE_INLINE_NO_IDX', 'FUZZY_AVG', get_elapsed_ms(v_start_time, v_end_time), p_notes);

    ---------------------------------------------------------
    -- 3. FLAT TABLE (Function FP_TRAPEZOID - NO INDEXES)
    ---------------------------------------------------------
    v_start_time := SYSTIMESTAMP;
    FOR r IN (
        SELECT p.linguistic_variable_value, ROUND(
          SUM(FP_TRAPEZOID(c.prod_year, p.a, p.b, p.c, p.d) * c.price) /
          SUM(FP_TRAPEZOID(c.prod_year, p.a, p.b, p.c, p.d)), 2) AS FUZZY_AVG
        FROM tbl_cars c, tbl_possibility p
        WHERE FP_TRAPEZOID(c.prod_year, p.a, p.b, p.c, p.d) > 0 
          AND p.column_name = 'prod_year'
          AND p.linguistic_variable_value = 'NEW' -- Ізолюємо цільову групу 2%
        GROUP BY p.linguistic_variable_value
    ) LOOP NULL; END LOOP;
    v_end_time := SYSTIMESTAMP;
    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'FLAT_TABLE_FUNCTION_NO_IDX', 'FUZZY_AVG', get_elapsed_ms(v_start_time, v_end_time), p_notes);

    -- Відновлення індексів
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_prod_year_idx REBUILD';
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_engine_cap_idx REBUILD';

    ---------------------------------------------------------
    -- 4. FLAT TABLE (Function FP_TRAPEZOID + Indexes)
    ---------------------------------------------------------
    v_start_time := SYSTIMESTAMP;
    FOR r IN (
        SELECT p.linguistic_variable_value, ROUND(
          SUM(FP_TRAPEZOID(c.prod_year, p.a, p.b, p.c, p.d) * c.price) /
          SUM(FP_TRAPEZOID(c.prod_year, p.a, p.b, p.c, p.d)), 2) AS FUZZY_AVG
        FROM tbl_cars c, tbl_possibility p
        WHERE FP_TRAPEZOID(c.prod_year, p.a, p.b, p.c, p.d) > 0 
          AND p.column_name = 'prod_year'
          AND p.linguistic_variable_value = 'NEW' -- Ізолюємо цільову групу 2%
        GROUP BY p.linguistic_variable_value
    ) LOOP NULL; END LOOP;
    v_end_time := SYSTIMESTAMP;
    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'FLAT_TABLE_FUNCTION', 'FUZZY_AVG', get_elapsed_ms(v_start_time, v_end_time), p_notes);

    ---------------------------------------------------------
    -- 5. EAV MODEL (Запропонований підхід)
    ---------------------------------------------------------
    v_start_time := SYSTIMESTAMP;
    FOR r IN (
        SELECT lvv AS linguistic_variable_value, ROUND(SUM(weight * value) / SUM(weight), 2) AS FUZZY_AVG
        FROM
        (SELECT entity_id, entity_name, lvv, y1+(NUMBER_VALUE-x1)*(y2-y1)/(x2-x1) AS weight
         FROM entity JOIN value USING(entity_id) JOIN attribute USING(attribute_id) JOIN lvv USING(attribute_id) JOIN mf USING(lvv_id)
         WHERE NUMBER_VALUE >= x1 AND NUMBER_VALUE < x2 AND attribute_id=2
           AND lvv = 'NEW') -- Ізолюємо цільову групу 2%
        JOIN
        (SELECT entity_id, number_value AS value
         FROM entity JOIN value USING(entity_id) JOIN attribute USING(attribute_id)
         WHERE attribute_id=4)
        USING (entity_id)
        GROUP BY lvv
    ) LOOP NULL; END LOOP;
    v_end_time := SYSTIMESTAMP;
    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'EAV_MODEL', 'FUZZY_AVG', get_elapsed_ms(v_start_time, v_end_time), p_notes);

    COMMIT;
END;
/