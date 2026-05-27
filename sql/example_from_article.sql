-- Скрипт создания тестовых данных для примера из статьи https://habr.com/ru/articles/1036190/

DO $$
DECLARE
    department_1_id BIGINT;
    department_2_id BIGINT;
    department_3_id BIGINT;
    calc_name VARCHAR;
BEGIN
    RAISE NOTICE 'Очистка таблиц перед заполнением';
    TRUNCATE TABLE costs_output RESTART IDENTITY CASCADE;
    TRUNCATE TABLE costs_input RESTART IDENTITY CASCADE;
    TRUNCATE TABLE rules_rows RESTART IDENTITY CASCADE;
    TRUNCATE TABLE rules_headers RESTART IDENTITY CASCADE;

    INSERT INTO rules_headers (department_name,"limit") VALUES
                              ('Отдел 1',      100.00)
    RETURNING id INTO department_1_id;

    INSERT INTO rules_headers (department_name,"limit") VALUES
                              ('Отдел 2',      100.00)
    RETURNING id INTO department_2_id;

    INSERT INTO rules_headers (department_name,"limit") VALUES
                              ('Отдел 3',      NULL)
    RETURNING id INTO department_3_id;

    INSERT INTO rules_rows (formula,disable_child_creation,rule_header_id,dest_rule_id) VALUES
         ('{X}*0.25',true,department_1_id,department_1_id),
         ('{X}*0.25',NULL,department_1_id,department_2_id),
         ('{X}*0.50',NULL,department_1_id,department_3_id),
         ('{X}*0.30',true,department_2_id,department_2_id),
         ('{X}*0.60',NULL,department_2_id,department_1_id),
         ('{X}*0.10',NULL,department_2_id,department_3_id),
         ('{X}'     ,true,department_3_id,department_3_id);

    calc_name := 'Пример из статьи';
    
    INSERT INTO costs_input (department_name, calc_name, cost_sum) VALUES ('Отдел 1', calc_name, 1000);
    
END $$;