CREATE OR REPLACE PROCEDURE test_fuzzy_avg_perf(p_data_volume IN NUMBER, p_notes IN VARCHAR2) IS
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_elapsed_ms NUMBER;
    v_interval INTERVAL DAY TO SECOND;
BEGIN
    ---------------------------------------------------------
    -- 1. FLAT TABLE (Inline CASE)
    -- Запит з інлайн-математикою для обчислення ваги[cite: 21]
    ---------------------------------------------------------
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
            WHERE c.prod_year > p.a AND c.prod_year < p.d
        )
        GROUP BY linguistic_variable_value
    ) LOOP NULL; END LOOP;

    v_end_time := SYSTIMESTAMP;
    v_interval := v_end_time - v_start_time;
    v_elapsed_ms := EXTRACT(DAY FROM v_interval) * 86400000 +
                    EXTRACT(HOUR FROM v_interval) * 3600000 +
                    EXTRACT(MINUTE FROM v_interval) * 60000 +
                    EXTRACT(SECOND FROM v_interval) * 1000;

    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'FLAT_TABLE_INLINE', 'FUZZY_AVG', v_elapsed_ms, p_notes);

    ---------------------------------------------------------
    -- 2. EAV MODEL (Запропонований підхід)
    -- Запит з використанням множинних JOIN для EAV структури[cite: 22]
    ---------------------------------------------------------
    v_start_time := SYSTIMESTAMP;
    
    FOR r IN (
        SELECT lvv AS linguistic_variable_value, ROUND(SUM(weight * value) / SUM(weight), 2) AS FUZZY_AVG
        FROM
        (SELECT entity_id, entity_name, lvv, y1+(NUMBER_VALUE-x1)*(y2-y1)/(x2-x1) AS weight
         FROM entity JOIN value USING(entity_id) JOIN attribute USING(attribute_id) JOIN lvv USING(attribute_id) JOIN mf USING(lvv_id)
         WHERE NUMBER_VALUE >= x1 AND NUMBER_VALUE < x2 AND attribute_id=2)
        JOIN
        (SELECT entity_id, number_value AS value
         FROM entity JOIN value USING(entity_id) JOIN attribute USING(attribute_id)
         WHERE attribute_id=4)
        USING (entity_id)
        GROUP BY lvv
    ) LOOP NULL; END LOOP;

    v_end_time := SYSTIMESTAMP;
    v_interval := v_end_time - v_start_time;
    v_elapsed_ms := EXTRACT(DAY FROM v_interval) * 86400000 +
                    EXTRACT(HOUR FROM v_interval) * 3600000 +
                    EXTRACT(MINUTE FROM v_interval) * 60000 +
                    EXTRACT(SECOND FROM v_interval) * 1000;

    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'EAV_MODEL', 'FUZZY_AVG', v_elapsed_ms, p_notes);

    ---------------------------------------------------------
    -- 3. FLAT TABLE (Original Function)
    -- Класичний підхід із двома викликами скалярної функції FP_TRAPEZOID[cite: 23]
    ---------------------------------------------------------
    v_start_time := SYSTIMESTAMP;
    
    FOR r IN (
        SELECT linguistic_variable_value, ROUND(
          SUM(FP_TRAPEZOID(prod_year,a,b,c,d)*price ) /
          SUM(FP_TRAPEZOID(prod_year,a,b,c,d)),2) AS FUZZY_AVG
        FROM tbl_cars, tbl_possibility
        WHERE FP_TRAPEZOID(prod_year,a,b,c,d)>0 
          AND column_name='prod_year'
        GROUP BY linguistic_variable_value
    ) LOOP NULL; END LOOP;

    v_end_time := SYSTIMESTAMP;
    v_interval := v_end_time - v_start_time;
    v_elapsed_ms := EXTRACT(DAY FROM v_interval) * 86400000 +
                    EXTRACT(HOUR FROM v_interval) * 3600000 +
                    EXTRACT(MINUTE FROM v_interval) * 60000 +
                    EXTRACT(SECOND FROM v_interval) * 1000;

    INSERT INTO experiment_results (data_volume, architecture, query_type, elapsed_ms, notes)
    VALUES (p_data_volume, 'FLAT_TABLE_FUNCTION', 'FUZZY_AVG', v_elapsed_ms, p_notes);

    COMMIT;
END;
/