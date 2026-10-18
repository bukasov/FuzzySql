
-- Clear previous experiment results
   TRUNCATE TABLE experiment_results;
   TRUNCATE TABLE test_execution_log;

SET SERVEROUTPUT ON SIZE UNLIMITED;

DECLARE
    -- Define collection types to hold workload scale tiers
    TYPE t_volume_array IS TABLE OF NUMBER;
    v_main_volumes t_volume_array := t_volume_array(10000, 50000, 100000, 500000, 1000000);
    v_pareto_volumes t_volume_array := t_volume_array(5000, 10000, 20000, 30000, 50000);
    
    v_current_volume NUMBER;
    v_run_note VARCHAR2(50);
    
BEGIN
    log_msg('=== BENCHMARK STARTED ===');
    
    ----------------------------------------------------------------------------
    -- PART 1: Linear query benchmarking (COUNT, AVG, COMBINED SEARCH)
    ----------------------------------------------------------------------------
    log_msg('--- BLOCK 1: Main Scale (COUNT, AVG, Combined Search) ---');
    
    FOR i IN 1 .. v_main_volumes.COUNT LOOP
        v_current_volume := v_main_volumes(i);
        log_msg('>> Preparing database: generating ' || v_current_volume || ' records...');
        
        -- Call data generation procedure
        prepare_test_environment(v_current_volume);
        log_msg('   Data generation completed. Starting test suite...');

        -- 3 runs for each data point (first is warm-up, followed by two benchmark runs)
        FOR run_num IN 1 .. 3 LOOP
            IF run_num = 1 THEN
                v_run_note := 'Cold Cache - Run 1';
            ELSE
                v_run_note := 'Warm Cache - Run ' || run_num;
            END IF;
            
            log_msg('   -> Executing ' || v_run_note);
            
            -- Execute test suites
            test_fuzzy_count_perf(v_current_volume, v_run_note);
            test_fuzzy_avg_perf(v_current_volume, v_run_note);
            test_combined_search_perf(v_current_volume, v_run_note);
        END LOOP;
        
        log_msg('<< Benchmarking for ' || v_current_volume || ' records completed.');
        DBMS_OUTPUT.PUT_LINE('----------------------------------------------------');
    END LOOP;


    ----------------------------------------------------------------------------
    -- PART 2: Pareto set algorithm benchmarking O(n^2)
    ----------------------------------------------------------------------------
    log_msg('--- BLOCK 2: Dedicated Scale for Pareto Frontier O(n^2) ---');
    
    FOR i IN 1 .. v_pareto_volumes.COUNT LOOP
        v_current_volume := v_pareto_volumes(i);
        log_msg('>> Preparing database: generating ' || v_current_volume || ' records (Pareto)...');
        
        prepare_test_environment(v_current_volume);
        log_msg('   Data generation completed. Starting Pareto tests...');

        -- 3 runs for each data point
        FOR run_num IN 1 .. 3 LOOP
            IF run_num = 1 THEN
                v_run_note := 'Cold Cache - Run 1';
            ELSE
                v_run_note := 'Warm Cache - Run ' || run_num;
            END IF;
            
            log_msg('   -> Executing ' || v_run_note);
            
            -- Execute heavy computation test
            test_pareto_search_perf(v_current_volume, v_run_note);
        END LOOP;
        
        log_msg('<< Pareto benchmarking for ' || v_current_volume || ' records completed.');
        DBMS_OUTPUT.PUT_LINE('----------------------------------------------------');
    END LOOP;

    log_msg('=== ALL TESTS COMPLETED SUCCESSFULLY ===');
    log_msg('Results saved to EXPERIMENT_RESULTS table. Ready for reporting.');
    
EXCEPTION
    WHEN OTHERS THEN
        log_msg('!!! EXECUTION ERROR !!!');
        log_msg(SQLERRM);
        -- Гарантоване відновлення працездатності індексів у разі падіння
        BEGIN
            EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_prod_year_idx REBUILD';
            EXECUTE IMMEDIATE 'ALTER INDEX tbl_cars_engine_cap_idx REBUILD';
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        ROLLBACK;
END;
/