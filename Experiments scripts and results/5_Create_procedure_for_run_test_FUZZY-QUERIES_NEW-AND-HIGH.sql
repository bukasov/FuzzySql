CREATE OR REPLACE PROCEDURE test_combined_search_perf(p_data_volume IN NUMBER, p_notes IN VARCHAR2) IS
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_elapsed_ms NUMBER;
    v_interval INTERVAL DAY TO SECOND;
BEGIN
    ---------------------------------------------------------
    -- 1. FLAT TABLE (Inline CASE)
    -- Запит з інлайн-математикою для обчислення ступеня релевантності[cite: 24]
    ---------------------------------------------------------
    v_start_time := SYSTIMESTAMP;
    
    FOR r IN (
        SELECT c.model, c.type, c.prod_year, c.engine_capacity,
               LEAST(
                 -- Оцінка для PROD_YEAR
                 CASE 
                   WHEN c.prod_year <= p1.a THEN 0.0
                   WHEN c.prod_year > p1.a AND c.prod_year <= p1.b THEN (c.prod_year - p1.a) / (p1.b - p1.a)
                   WHEN c.prod_year > p1.b AND c.prod_year <= p1.c THEN 1.0
                   WHEN c.prod_year > p1.c AND c.prod_year <= p1.d THEN (p1.d - c.prod_year) / (p1.d - p1.c)
                   ELSE 0.0
                 END,
                 -- Оцінка для ENGINE_CAPACITY
                 CASE 
                   WHEN c.engine_capacity <= p2.a THEN 0.0
                   WHEN c.engine_capacity > p2.a AND c.engine_capacity <= p2.b THEN (c.engine_capacity - p2.a) / (p2.b - p2.a)
                   WHEN c.engine_capacity > p2.b AND c.engine_capacity <= p2.c THEN 1.0
                   WHEN c.engine_capacity > p2.c AND c.engine_capacity <= p2.d THEN (p2.d - c.engine_capacity) / (p2.d - p2.c)
                   ELSE 0.0
                 END
               ) AS FUZZY_DEGREE_MIN
        FROM tbl_cars c
        CROSS JOIN tbl_possibility p1
        CROSS JOIN tbl_possibility p2
        WHERE p1.column_name = 'prod_year' AND p1.linguistic_variable_value = 'NEW'
          AND p2.column_name = 'engine_capacity' AND p2.linguistic_variable_value = 'HIGH'
          -- Фільтрація нульової релевантності напряму по значенням трапеції
          AND c.prod_year > p1.a AND c.prod_year < p1.d
          AND c.engine_capacity > p2.a AND c.engine_capacity < p2.d
    ) LOOP NULL; END LOOP;

    v_end_time := SYSTIMESTAMP;
    v_interval := v_end_time - v_start_time;
    v_elapsed_ms := EXTRACT(DAY FROM v_interval) * 86400000 +
                    EXTRACT(HOUR FROM v_interval) * 3600000 +
                    EXTRACT(MINUTE FROM v_interval) * 60000 +
                    EXTRACT(SECOND FROM v_interval) * 1000;

    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'FLAT_TABLE_INLINE', 'COMBINED_SEARCH', v_elapsed_ms, p_notes);

    ---------------------------------------------------------
    -- 2. EAV MODEL (Запропонований підхід)
    -- Запит для EAV структури з використанням INNER JOIN та агрегації оцінок[cite: 25]
    ---------------------------------------------------------
    v_start_time := SYSTIMESTAMP;
    
    FOR r IN (
        SELECT entity_id, c1.entity_name
          ,LEAST(c1.degree, c2.degree) AS FUZZY_DEGREE_MIN 
          ,c1.degree * c2.degree AS FUZZY_DEGREE_PROD 
          ,c1.degree AS year_is_new_degree
          ,c2.degree AS engine_capacity_is_high_degree
        FROM 
          (SELECT entity_id, entity.entity_name, y1+ (NUMBER_VALUE - x1) * (y2-y1)/(x2-x1) AS degree 
          FROM entity JOIN value USING(entity_id) JOIN attribute USING(attribute_id) JOIN lvv USING(attribute_id) JOIN mf USING(lvv_id)
          WHERE NUMBER_VALUE >= x1 AND NUMBER_VALUE < x2 AND attribute_id=2 AND lvv='NEW') c1 
        INNER JOIN
          (SELECT entity_id, entity.entity_name, y1+ (NUMBER_VALUE - x1) * (y2-y1)/(x2-x1) AS degree 
          FROM entity JOIN value USING(entity_id) JOIN attribute USING(attribute_id) JOIN lvv USING(attribute_id) JOIN mf USING(lvv_id)
          WHERE NUMBER_VALUE >= x1 AND NUMBER_VALUE < x2 AND attribute_id=3 AND lvv='HIGH') c2
        USING(entity_id)
        WHERE c1.degree > 0 AND c2.degree > 0
    ) LOOP NULL; END LOOP;

    v_end_time := SYSTIMESTAMP;
    v_interval := v_end_time - v_start_time;
    v_elapsed_ms := EXTRACT(DAY FROM v_interval) * 86400000 +
                    EXTRACT(HOUR FROM v_interval) * 3600000 +
                    EXTRACT(MINUTE FROM v_interval) * 60000 +
                    EXTRACT(SECOND FROM v_interval) * 1000;

    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'EAV_MODEL', 'COMBINED_SEARCH', v_elapsed_ms, p_notes);

    ---------------------------------------------------------
    -- 3. FLAT TABLE (Original Function)
    -- Оригінальний підхід із викликом функції FP_TRAPEZOID[cite: 26]
    ---------------------------------------------------------
    v_start_time := SYSTIMESTAMP;
    
    FOR r IN (
        SELECT *
        FROM (
          SELECT c.model, c.type, c.prod_year, c.engine_capacity,
            MIN(CASE column_name
                WHEN 'prod_year' THEN FP_TRAPEZOID(prod_year,a,b,c,d)
                WHEN 'engine_capacity' THEN FP_TRAPEZOID(engine_capacity,a,b,c,d) 
                END) AS FUZZY_DEGREE
          FROM tbl_cars c, tbl_possibility
          WHERE (linguistic_variable_value='NEW' or linguistic_variable_value='HIGH') 
            AND (column_name='prod_year' or column_name='engine_capacity')
          GROUP BY c.model, c.type, c.prod_year, c.engine_capacity
        ) 
        WHERE FUZZY_DEGREE > 0
    ) LOOP NULL; END LOOP;

    v_end_time := SYSTIMESTAMP;
    v_interval := v_end_time - v_start_time;
    v_elapsed_ms := EXTRACT(DAY FROM v_interval) * 86400000 +
                    EXTRACT(HOUR FROM v_interval) * 3600000 +
                    EXTRACT(MINUTE FROM v_interval) * 60000 +
                    EXTRACT(SECOND FROM v_interval) * 1000;

    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'FLAT_TABLE_FUNCTION', 'COMBINED_SEARCH', v_elapsed_ms, p_notes);

    COMMIT;
END;
/