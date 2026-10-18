CREATE OR REPLACE PROCEDURE test_combined_search_perf(p_data_volume IN NUMBER, p_notes IN VARCHAR2) IS
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;

BEGIN
    ---------------------------------------------------------
    -- 1. FLAT TABLE (Inline CASE + Indexes)
    ---------------------------------------------------------
    v_start_time := SYSTIMESTAMP;
    FOR r IN (
        SELECT /*+ USE_NL(p1 p2 c) INDEX(c tbl_cars_prod_year_idx) */
               c.model, c.type, c.prod_year, c.engine_capacity,
               LEAST(
                 CASE 
                   WHEN c.prod_year <= p1.a THEN 0.0
                   WHEN c.prod_year > p1.a AND c.prod_year <= p1.b THEN (c.prod_year - p1.a) / (p1.b - p1.a)
                   WHEN c.prod_year > p1.b AND c.prod_year <= p1.c THEN 1.0
                   WHEN c.prod_year > p1.c AND c.prod_year <= p1.d THEN (p1.d - c.prod_year) / (p1.d - p1.c)
                   ELSE 0.0
                 END,
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
          AND c.prod_year > p1.a AND c.prod_year < p1.d
          AND c.engine_capacity > p2.a AND c.engine_capacity < p2.d
    ) LOOP NULL; END LOOP;
    v_end_time := SYSTIMESTAMP;
    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'FLAT_TABLE_INLINE_IDX', 'COMBINED_SEARCH', get_elapsed_ms(v_start_time, v_end_time), p_notes);

    ---------------------------------------------------------
    -- 2. FLAT TABLE (Inline CASE - NO INDEXES)
    ---------------------------------------------------------
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_prod_year_idx UNUSABLE';
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_engine_cap_idx UNUSABLE';

    v_start_time := SYSTIMESTAMP;
    FOR r IN (
        SELECT c.model, c.type, c.prod_year, c.engine_capacity,
               LEAST(
                 CASE 
                   WHEN c.prod_year <= p1.a THEN 0.0
                   WHEN c.prod_year > p1.a AND c.prod_year <= p1.b THEN (c.prod_year - p1.a) / (p1.b - p1.a)
                   WHEN c.prod_year > p1.b AND c.prod_year <= p1.c THEN 1.0
                   WHEN c.prod_year > p1.c AND c.prod_year <= p1.d THEN (p1.d - c.prod_year) / (p1.d - p1.c)
                   ELSE 0.0
                 END,
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
          AND c.prod_year > p1.a AND c.prod_year < p1.d
          AND c.engine_capacity > p2.a AND c.engine_capacity < p2.d
    ) LOOP NULL; END LOOP;
    v_end_time := SYSTIMESTAMP;
    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'FLAT_TABLE_INLINE', 'COMBINED_SEARCH', get_elapsed_ms(v_start_time, v_end_time), p_notes);

    ---------------------------------------------------------
    -- 3. FLAT TABLE (Function FP_TRAPEZOID - NO INDEXES)
    ---------------------------------------------------------
    v_start_time := SYSTIMESTAMP;
    FOR r IN (
        SELECT *
        FROM (
          SELECT c.model, c.type, c.prod_year, c.engine_capacity,
            MIN(CASE p.column_name
                WHEN 'prod_year' THEN FP_TRAPEZOID(c.prod_year, p.a, p.b, p.c, p.d)
                WHEN 'engine_capacity' THEN FP_TRAPEZOID(c.engine_capacity, p.a, p.b, p.c, p.d) 
                END) AS FUZZY_DEGREE
          FROM tbl_cars c, tbl_possibility p
          WHERE (p.linguistic_variable_value = 'NEW' OR p.linguistic_variable_value = 'HIGH') 
            AND (
			  (p.column_name = 'prod_year' AND c.prod_year > p.a AND c.prod_year < p.d) 
			  OR 
			  (p.column_name = 'engine_capacity' AND c.engine_capacity > p.a AND c.engine_capacity < p.d)
		  )
          GROUP BY c.model, c.type, c.prod_year, c.engine_capacity
        ) 
        WHERE FUZZY_DEGREE > 0
    ) LOOP NULL; END LOOP;
    v_end_time := SYSTIMESTAMP;
    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'FLAT_TABLE', 'COMBINED_SEARCH', get_elapsed_ms(v_start_time, v_end_time), p_notes);

    -- Відновлення індексів
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_prod_year_idx REBUILD';
    EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_engine_cap_idx REBUILD';

    ---------------------------------------------------------
    -- 4. FLAT TABLE (Function FP_TRAPEZOID + Indexes)
    ---------------------------------------------------------
    v_start_time := SYSTIMESTAMP;
    FOR r IN (
        SELECT *
        FROM (
          SELECT c.model, c.type, c.prod_year, c.engine_capacity,
            MIN(CASE p.column_name
                WHEN 'prod_year' THEN FP_TRAPEZOID(c.prod_year, p.a, p.b, p.c, p.d)
                WHEN 'engine_capacity' THEN FP_TRAPEZOID(c.engine_capacity, p.a, p.b, p.c, p.d) 
                END) AS FUZZY_DEGREE
          FROM tbl_cars c, tbl_possibility p
          WHERE (p.linguistic_variable_value = 'NEW' OR p.linguistic_variable_value = 'HIGH') 
            AND (
			  (p.column_name = 'prod_year' AND c.prod_year > p.a AND c.prod_year < p.d) 
			  OR 
			  (p.column_name = 'engine_capacity' AND c.engine_capacity > p.a AND c.engine_capacity < p.d)
		  )
          GROUP BY c.model, c.type, c.prod_year, c.engine_capacity
        ) 
        WHERE FUZZY_DEGREE > 0
    ) LOOP NULL; END LOOP;
    v_end_time := SYSTIMESTAMP;
    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'FLAT_TABLE_IDX', 'COMBINED_SEARCH', get_elapsed_ms(v_start_time, v_end_time), p_notes);

    ---------------------------------------------------------
    -- 5. EAV MODEL
    ---------------------------------------------------------
    v_start_time := SYSTIMESTAMP;
    FOR r IN (
		WITH matched_entities AS (
            -- 1. Знаходимо потрібні сутності за критеріями (швидкий пошук з GROUP BY)
            SELECT e.entity_id, e.entity_name,
                   MIN(mf.y1 + (v.number_value - mf.x1) * (mf.y2 - mf.y1) / (mf.x2 - mf.x1)) AS FUZZY_DEGREE
            FROM lvv l
            INNER JOIN value v ON l.attribute_id = v.attribute_id
            INNER JOIN entity e ON v.entity_id = e.entity_id
            INNER JOIN mf ON l.lvv_id = mf.lvv_id
            WHERE ((l.attribute_id = 2 AND l.lvv = 'NEW') OR (l.attribute_id = 3 AND l.lvv = 'HIGH'))
              AND v.number_value >= l.bnd_min AND v.number_value < l.bnd_max
              AND v.number_value >= mf.x1 AND v.number_value < mf.x2
            GROUP BY e.entity_id, e.entity_name
            HAVING COUNT(*) = 2
        )
        -- 2. Отримуємо необхідні атрибути, щоб результат 1 в 1 збігався з FLAT
        SELECT m.entity_name AS model,
               v_type.text_value AS type,
               v_year.number_value AS prod_year,
               v_eng.number_value AS engine_capacity,
               m.FUZZY_DEGREE_MIN
        FROM matched_entities m
        LEFT JOIN value v_type ON m.entity_id = v_type.entity_id AND v_type.attribute_id = 1
        LEFT JOIN value v_year ON m.entity_id = v_year.entity_id AND v_year.attribute_id = 2
        LEFT JOIN value v_eng  ON m.entity_id = v_eng.entity_id  AND v_eng.attribute_id = 3
    ) LOOP NULL; END LOOP;
    v_end_time := SYSTIMESTAMP;
    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'EAV_MODEL', 'COMBINED_SEARCH', get_elapsed_ms(v_start_time, v_end_time), p_notes);

    COMMIT;
END;
/