
-- TRUNCATE TABLE experiment_results

SET SERVEROUTPUT ON SIZE UNLIMITED;

DECLARE
    -- Визначаємо типи колекцій для зберігання градацій навантаження
    TYPE t_volume_array IS TABLE OF NUMBER;
    v_main_volumes t_volume_array := t_volume_array(10000, 50000, 100000, 500000, 1000000);
    v_pareto_volumes t_volume_array := t_volume_array(5000, 10000, 20000, 30000, 50000);
    
    v_current_volume NUMBER;
    v_run_note VARCHAR2(50);
    
    -- Допоміжна процедура для логування в консоль з часом
    PROCEDURE log_msg(p_msg VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('[' || TO_CHAR(SYSDATE, 'HH24:MI:SS') || '] ' || p_msg);
    END;
BEGIN
    log_msg('=== ПОЧАТОК ТЕСТУВАННЯ ===');
    
    ----------------------------------------------------------------------------
    -- ЧАСТИНА 1: Тестування лінійних запитів (COUNT, AVG, COMBINED SEARCH)
    ----------------------------------------------------------------------------
    log_msg('--- БЛОК 1: Основна шкала (COUNT, AVG, Combined Search) ---');
    
    FOR i IN 1 .. v_main_volumes.COUNT LOOP
        v_current_volume := v_main_volumes(i);
        log_msg('>> Підготовка бази даних: генерація ' || v_current_volume || ' записів...');
        
        -- Виклик процедури генерації даних
        prepare_test_environment(v_current_volume);
        log_msg('   Генерація завершена. Запуск серії тестів...');

        -- 3 прогони для кожної точки (перший прогрів і два робочих)
        FOR run_num IN 1 .. 3 LOOP
            IF run_num = 1 THEN
                v_run_note := 'Cold Cache - Run 1';
            ELSE
                v_run_note := 'Warm Cache - Run ' || run_num;
            END IF;
            
            log_msg('   -> Виконання ' || v_run_note);
            
            -- Запуск тестів
            test_fuzzy_count_perf(v_current_volume, v_run_note);
            test_fuzzy_avg_perf(v_current_volume, v_run_note);
            test_combined_search_perf(v_current_volume, v_run_note);
        END LOOP;
        
        log_msg('<< Тестування для ' || v_current_volume || ' записів завершено.');
        DBMS_OUTPUT.PUT_LINE('----------------------------------------------------');
    END LOOP;


    ----------------------------------------------------------------------------
    -- ЧАСТИНА 2: Тестування алгоритму Парето O(n^2)
    ----------------------------------------------------------------------------
    log_msg('--- БЛОК 2: Спеціальна шкала для множини Парето O(n^2) ---');
    
    FOR i IN 1 .. v_pareto_volumes.COUNT LOOP
        v_current_volume := v_pareto_volumes(i);
        log_msg('>> Підготовка бази даних: генерація ' || v_current_volume || ' записів (Pareto)...');
        
        prepare_test_environment(v_current_volume);
        log_msg('   Генерація завершена. Запуск тестів Парето...');

        -- 3 прогони для кожної точки
        FOR run_num IN 1 .. 3 LOOP
            IF run_num = 1 THEN
                v_run_note := 'Cold Cache - Run 1';
            ELSE
                v_run_note := 'Warm Cache - Run ' || run_num;
            END IF;
            
            log_msg('   -> Виконання ' || v_run_note);
            
            -- Запуск важкого тесту
            test_pareto_search_perf(v_current_volume, v_run_note);
        END LOOP;
        
        log_msg('<< Тестування Парето для ' || v_current_volume || ' записів завершено.');
        DBMS_OUTPUT.PUT_LINE('----------------------------------------------------');
    END LOOP;

    log_msg('=== ВСІ ТЕСТИ УСПІШНО ЗАВЕРШЕНІ ===');
    log_msg('Результати збережено в таблицю EXPERIMENT_RESULTS. Можна формувати звіти.');
    
EXCEPTION
    WHEN OTHERS THEN
        log_msg('!!! ПОМИЛКА ВИКОНАННЯ !!!');
        log_msg(SQLERRM);
        ROLLBACK;
END;
/