-- Скрипт создания тестовых данных для распределения затрат в большом количестве

DO $$
DECLARE
    departments_count BIGINT = 5000; -- Количество отделов, в данном примере количество записей в таблице rules_headers
    deparments BIGINT[];
    current_department_name VARCHAR;
    calc_name VARCHAR = 'Пример распределения большого количества затрат';
    i BIGINT;
    cost_sum FLOAT;
    percent_for_division int;
    current_persent_for_division INT;
    percent_summed INT;
    rule_header_id BIGINT;
    dest_rule_id BIGINT;
BEGIN
    RAISE NOTICE 'Очистка таблиц перед заполнением';
    TRUNCATE TABLE costs_output RESTART IDENTITY CASCADE;
    TRUNCATE TABLE costs_input RESTART IDENTITY CASCADE;
    TRUNCATE TABLE rules_rows RESTART IDENTITY CASCADE;
    TRUNCATE TABLE rules_headers RESTART IDENTITY CASCADE;
    
    FOR i IN 1..departments_count LOOP
        current_department_name := 'Отдел ' || i;
        IF i % 50 = 0 THEN
            RAISE NOTICE 'Начата работа с %', current_department_name; 
        END IF;
        cost_sum := random() * (1500-500) + 500;
        INSERT INTO costs_input(        department_name, calc_name, cost_sum) VALUES
                               (current_department_name, calc_name, cost_sum);
             
        INSERT INTO rules_headers (        department_name, "limit") VALUES
                                  (current_department_name,  100.00)
        RETURNING id INTO rule_header_id;

        INSERT INTO rules_rows (   formula, disable_child_creation, rule_header_id,   dest_rule_id) VALUES
                               ('{X}*0.25',                   true, rule_header_id, rule_header_id);

        percent_for_division := 75; -- Сколько процентов затрат нужно распределить. 25% уходит на сам отдел без дальнейшего распределения. Описано выше
        percent_summed := 25; -- Сколько процентов затрат уже распределено. 25% уходит на сам отдел без дальнейшего распределения. Описано выше
        WHILE percent_for_division > 0 LOOP
            IF percent_for_division < 10 THEN
                current_persent_for_division := 100 - percent_summed;
            ELSE
                current_persent_for_division := round(random() * (percent_for_division - 10) + 1);
            END IF;

            SELECT id INTO dest_rule_id FROM rules_headers ORDER BY RANDOM() LIMIT 1; -- На какой другой отдел уйдут затраты определяется случайно

            INSERT INTO rules_rows (                                                                 formula, disable_child_creation, rule_header_id, dest_rule_id) VALUES
                                   ('{X}*' || TO_CHAR(current_persent_for_division::numeric / 100, 'FM0.00'),                  false, rule_header_id, dest_rule_id);
            percent_summed := percent_summed + current_persent_for_division;
            percent_for_division := percent_for_division - current_persent_for_division;
        END LOOP;
        
        
    END LOOP;
    
    raise notice 'Скрипт закончил работу';
END $$;

