
Щоб слідкувати за прогресом періодично дивитися в таблицю логів

SELECT TO_CHAR(log_time, 'HH24:MI:SS') AS time, message 
FROM test_execution_log 
ORDER BY log_id DESC;

Отримати результати

SELECT 
    query_type,
    architecture,
    data_volume,
    ROUND(AVG(elapsed_ms), 2) AS avg_elapsed_ms_warm
FROM experiment_results
WHERE notes LIKE 'Warm Cache%'
GROUP BY query_type, architecture, data_volume
ORDER BY query_type, data_volume, architecture;