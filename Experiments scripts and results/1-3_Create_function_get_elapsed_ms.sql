CREATE OR REPLACE FUNCTION get_elapsed_ms(p_start TIMESTAMP, p_end TIMESTAMP) RETURN NUMBER IS
    v_diff INTERVAL DAY TO SECOND;
BEGIN
    v_diff := p_end - p_start;
    RETURN EXTRACT(DAY FROM v_diff) * 86400000 +
           EXTRACT(HOUR FROM v_diff) * 3600000 +
           EXTRACT(MINUTE FROM v_diff) * 60000 +
           EXTRACT(SECOND FROM v_diff) * 1000;
END;
/