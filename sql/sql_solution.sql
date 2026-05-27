DO $$
DECLARE
    cost_row RECORD;
    cost_row2 RECORD;
    formula VARCHAR;
    cost_sum NUMERIC(16, 2);
    sum_of_costs NUMERIC(16, 2);
    has_rows_for_divide boolean = TRUE;
    iteration_count INT = 0;
    step_starter_at TIMESTAMP;
BEGIN
    RAISE NOTICE '%', '-------------------------------------------------------------';
    RAISE NOTICE '% %', 'Начато распределение затрат', TIMEOFDAY();
    step_starter_at := CLOCK_TIMESTAMP();
    -- Копирование входных данных на первый уровень распределения в таблицу costs_output
    FOR cost_row IN
        SELECT ci.id "cost_input_id", rr.id "rules_row_id", ci.cost_sum, rr.formula
        FROM costs_input ci
        JOIN rules_headers rh ON rh.department_name = ci.department_name
        JOIN rules_rows rr ON rh.id = rr.rule_header_id
    LOOP
        formula := REPLACE(cost_row.formula::text, '{X}'::text, cost_row.cost_sum::text);
        EXECUTE 'SELECT ' || formula INTO cost_sum;
        
        INSERT INTO costs_output (         cost_input_id,         rules_rows_id,     summ)
                          VALUES (cost_row.cost_input_id, cost_row.rules_row_id, cost_sum);
    END LOOP;

    /*
    Поиск и распределение затрат у которых:
        1. Нет подчиненных распределений затрат, то есть они еще не распределены NOT EXISTS (SELECT 1 FROM costs_output ...
        2. Сумма затрат больше уровня затрат на распределение co.summ >= ...
        3. Распределение затрат НЕ отключено в правилах (rr_from_co.disable_child_creation IS NULL OR rr_from_co.disable_child_creation = FALSE)
    */
    WHILE has_rows_for_divide LOOP
        FOR cost_row2 IN
            SELECT rr_from_rr.id "rules_row_id", co.summ "cost_sum", rr_from_rr.formula , co.id "parent_row_id", co.cost_input_id
            FROM costs_output co 
            INNER JOIN rules_rows rr_from_co ON co.rules_rows_id = rr_from_co.id
            INNER JOIN rules_headers rh_from_rr ON rh_from_rr.id = rr_from_co.dest_rule_id
            INNER JOIN rules_rows rr_from_rr ON rr_from_rr.rule_header_id = rh_from_rr.id 
            WHERE (rr_from_co.disable_child_creation IS NULL OR rr_from_co.disable_child_creation = FALSE) AND
                 co.summ >= COALESCE(rh_from_rr."limit", 'Infinity'::numeric) AND
                 NOT EXISTS (SELECT 1 FROM costs_output co_exists_test WHERE co_exists_test.parent_row_id = co.id)
        LOOP
            formula := REPLACE(cost_row2.formula::text, '{X}'::text, cost_row2.cost_sum::text);
            EXECUTE 'SELECT ' || formula INTO cost_sum;
            INSERT INTO costs_output (          parent_row_id,          rules_rows_id,     summ,           cost_input_id)
                              VALUES (cost_row2.parent_row_id, cost_row2.rules_row_id, cost_sum, cost_row2.cost_input_id);

        END LOOP;
        iteration_count := iteration_count + 1;
        IF iteration_count % 10 = 0 THEN
            RAISE NOTICE 'Отработан уровень %', iteration_count;
        END IF;

        SELECT EXISTS (
            SELECT 1
            FROM costs_output co 
            INNER JOIN rules_rows rr_from_co ON co.rules_rows_id = rr_from_co.id
            INNER JOIN rules_headers rh_from_rr ON rh_from_rr.id = rr_from_co.dest_rule_id
            INNER JOIN rules_rows rr_from_rr ON rr_from_rr.rule_header_id = rh_from_rr.id 
            WHERE (rr_from_co.disable_child_creation IS NULL OR rr_from_co.disable_child_creation = FALSE) AND
                 co.summ >= COALESCE(rh_from_rr."limit", 'Infinity'::numeric) AND
                 NOT EXISTS (SELECT 1 FROM costs_output co_exists_test WHERE co_exists_test.parent_row_id = co.id)
        ) INTO has_rows_for_divide;
        
        IF iteration_count > 1000 THEN
            RAISE NOTICE 'Превышено количетво разрешенных итераций';
        END IF;
    END LOOP;
    RAISE NOTICE '% %', 'Затраты распределены за: ', CLOCK_TIMESTAMP() - step_starter_at;

    -- при каскадном распределении неизбежно появление ошибок округления
    -- скрипт ниже убирает ошибки округления распределения, перенося их на первую строку распределения
    -- Объяснение работы этого SQL для исправления смотреть в скрипте tester.sql
    RAISE NOTICE '% %', 'Начато исправление ошибок округления', TIMEOFDAY();
    step_starter_at := CLOCK_TIMESTAMP();
    WITH base AS (
        SELECT co.cost_input_id, 
            for_fix.id "for_fix_id",
            sum(co.summ) "cost_output_sum", 
            (SELECT sum(ci.cost_sum) FROM costs_input ci where ci.id = co.cost_input_id) "cost_input_sum"
        FROM costs_output co 
        INNER JOIN (
            SELECT co.cost_input_id, 
                co.id, 
                row_number() OVER (PARTITION BY co.cost_input_id ORDER BY co.id)
            FROM costs_output co 
            GROUP BY 1, 2
            ORDER BY 1, 2
        ) for_fix ON for_fix.cost_input_id = co.cost_input_id AND for_fix."row_number" = 1
        WHERE co.id NOT IN (SELECT parent_row_id FROM costs_output co2 WHERE co2.parent_row_id IS NOT null)
        GROUP BY 1, 2
        ORDER BY 1, 2
    )
    UPDATE costs_output
    SET summ = summ - sub_query.diff
    FROM (
        SELECT base.*, 
            (base.cost_output_sum - ci2.cost_sum) as diff
        FROM base 
        INNER JOIN costs_input ci2 ON ci2.id = base.cost_input_id 
        WHERE (base.cost_output_sum - ci2.cost_sum) != 0
    ) sub_query
    WHERE sub_query.for_fix_id = id;
    RAISE NOTICE '% %', 'Ошибки округления исправлены за: ', CLOCK_TIMESTAMP() - step_starter_at;

END $$;

SELECT statement_timestamp()