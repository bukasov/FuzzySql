CREATE OR REPLACE PROCEDURE test_pareto_search_perf(p_data_volume IN NUMBER, p_notes IN VARCHAR2) IS
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_elapsed_ms NUMBER;
    v_interval INTERVAL DAY TO SECOND;
BEGIN
    ---------------------------------------------------------
    -- 1. FLAT TABLE (Inline CASE)
    -- Запит з інлайн-математикою та двома CTE для оптимізації фільтрації[cite: 27]
    ---------------------------------------------------------
    v_start_time := SYSTIMESTAMP;
    
    FOR r IN (
        WITH raw_degrees AS (
          SELECT c.id_sam, c.model, 
                 CASE 
                   WHEN c.prod_year <= p1.a THEN 0.0
                   WHEN c.prod_year > p1.a AND c.prod_year <= p1.b THEN (c.prod_year - p1.a) / (p1.b - p1.a)
                   WHEN c.prod_year > p1.b AND c.prod_year <= p1.c THEN 1.0
                   WHEN c.prod_year > p1.c AND c.prod_year <= p1.d THEN (p1.d - c.prod_year) / (p1.d - p1.c)
                   ELSE 0.0
                 END AS d1,
                 CASE 
                   WHEN c.engine_capacity <= p2.a THEN 0.0
                   WHEN c.engine_capacity > p2.a AND c.engine_capacity <= p2.b THEN (c.engine_capacity - p2.a) / (p2.b - p2.a)
                   WHEN c.engine_capacity > p2.b AND c.engine_capacity <= p2.c THEN 1.0
                   WHEN c.engine_capacity > p2.c AND c.engine_capacity <= p2.d THEN (p2.d - c.engine_capacity) / (p2.d - p2.c)
                   ELSE 0.0
                 END AS d2
          FROM tbl_cars c
          CROSS JOIN tbl_possibility p1
          CROSS JOIN tbl_possibility p2
          WHERE p1.column_name = 'prod_year' AND p1.linguistic_variable_value = 'NEW'
            AND p2.column_name = 'engine_capacity' AND p2.linguistic_variable_value = 'HIGH'
            AND c.prod_year > p1.a AND c.prod_year < p1.d
            AND c.engine_capacity > p2.a AND c.engine_capacity < p2.d
        ),
        cars_degree AS (
          SELECT id_sam, model, d1, d2
          FROM raw_degrees
          WHERE d1 >= 0.3 AND d2 >= 0.3
        )
        SELECT e1.id_sam, e1.model, ROUND(e1.d1, 2) AS d1, ROUND(e1.d2, 2) AS d2
        FROM cars_degree e1 
        LEFT JOIN cars_degree e2 
          ON e2.d1 >= e1.d1 AND e2.d2 >= e1.d2 
         AND (e2.d1 > e1.d1 OR e2.d2 > e1.d2)
        WHERE e2.id_sam IS NULL
    ) LOOP NULL; END LOOP;

    v_end_time := SYSTIMESTAMP;
    v_interval := v_end_time - v_start_time;
    v_elapsed_ms := EXTRACT(DAY FROM v_interval) * 86400000 +
                    EXTRACT(HOUR FROM v_interval) * 3600000 +
                    EXTRACT(MINUTE FROM v_interval) * 60000 +
                    EXTRACT(SECOND FROM v_interval) * 1000;

    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'FLAT_TABLE_INLINE', 'PARETO_SEARCH', v_elapsed_ms, p_notes);

    ---------------------------------------------------------
    -- 2. EAV MODEL (Запропонований підхід)
    -- Запит для EAV структури з розрахунком ступенів та подальшим LEFT JOIN множини Парето[cite: 28]
    ---------------------------------------------------------
    v_start_time := SYSTIMESTAMP;
    
    FOR r IN (
        WITH entities(entity_id, entity_name, d1, d2) AS (
        SELECT entity_id, c1.entity_name
          ,ROUND(c1.degree, 2) AS year_is_new_degree
          ,ROUND(c2.degree, 2) AS engine_capacity_is_high_degree
        FROM 
          (SELECT entity_id, entity.entity_name, y1+ (NUMBER_VALUE - x1) * (y2-y1)/(x2-x1) AS degree 
          FROM entity JOIN value USING(entity_id) JOIN attribute USING(attribute_id) JOIN lvv USING(attribute_id) JOIN mf USING(lvv_id)
          WHERE NUMBER_VALUE >= x1 AND NUMBER_VALUE < x2 AND attribute_id=2 AND lvv='NEW') c1 
        INNER JOIN
          (SELECT entity_id, entity.entity_name, y1+ (NUMBER_VALUE - x1) * (y2-y1)/(x2-x1) AS degree 
          FROM entity JOIN value USING(entity_id) JOIN attribute USING(attribute_id) JOIN lvv USING(attribute_id) JOIN mf USING(lvv_id)
          WHERE NUMBER_VALUE >= x1 AND NUMBER_VALUE < x2 AND attribute_id=3 AND lvv='HIGH') c2
        USING(entity_id)
        WHERE LEAST(c1.degree, c2.degree) >= 0.3)
        SELECT e1.entity_id, e1.entity_name, e1.d1 AS YEAR_IS_NEW_DEGREE, e1.d2 AS ENGINE_CAPACITY_IS_MIDDLE_DEGREE
        FROM entities e1 LEFT JOIN entities e2 
        ON e2.d1 >= e1.d1 AND e2.d2 >= e1.d2
        AND (e2.d1 > e1.d1 OR e2.d2 > e1.d2)
        WHERE e2.entity_id IS NULL
    ) LOOP NULL; END LOOP;

    v_end_time := SYSTIMESTAMP;
    v_interval := v_end_time - v_start_time;
    v_elapsed_ms := EXTRACT(DAY FROM v_interval) * 86400000 +
                    EXTRACT(HOUR FROM v_interval) * 3600000 +
                    EXTRACT(MINUTE FROM v_interval) * 60000 +
                    EXTRACT(SECOND FROM v_interval) * 1000;

    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'EAV_MODEL', 'PARETO_SEARCH', v_elapsed_ms, p_notes);

    ---------------------------------------------------------
    -- 3. FLAT TABLE (Original Function)
    -- Оригінальний підхід із викликом функції FP_TRAPEZOID[cite: 29]
    ---------------------------------------------------------
    v_start_time := SYSTIMESTAMP;
    
    FOR r IN (
        WITH cars_degree AS (
          SELECT id_sam, model, 
                 FP_TRAPEZOID(prod_year, 2010, 2015, 2050, 2050) AS d1, 
                 FP_TRAPEZOID(engine_capacity, 1.6, 2.5, 5, 8) AS d2
          FROM tbl_cars
          WHERE FP_TRAPEZOID(prod_year, 2010, 2015, 2050, 2050) >= 0.3 
            AND FP_TRAPEZOID(engine_capacity, 1.6, 2.5, 5, 8) >= 0.3
        )
        SELECT e1.id_sam, e1.model, e1.d1, e1.d2
        FROM cars_degree e1 
        LEFT JOIN cars_degree e2 
          ON e2.d1 >= e1.d1 AND e2.d2 >= e1.d2 
         AND (e2.d1 > e1.d1 OR e2.d2 > e1.d2)
        WHERE e2.id_sam IS NULL
    ) LOOP NULL; END LOOP;

    v_end_time := SYSTIMESTAMP;
    v_interval := v_end_time - v_start_time;
    v_elapsed_ms := EXTRACT(DAY FROM v_interval) * 86400000 +
                    EXTRACT(HOUR FROM v_interval) * 3600000 +
                    EXTRACT(MINUTE FROM v_interval) * 60000 +
                    EXTRACT(SECOND FROM v_interval) * 1000;

    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'FLAT_TABLE_FUNCTION', 'PARETO_SEARCH', v_elapsed_ms, p_notes);

    COMMIT;
END;
/