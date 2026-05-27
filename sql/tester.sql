/*
Скрипт проверки что все затраты распределены корректно

Порядок работы:
    1. Из таблицы costs_output собираются все строки у которых нет подчиненных распределений:  co.id NOT IN (SELECT parent_row_id FROM costs_output co2 WHERE co2.parent_row_id IS NOT null)
    2. По этим строкам суммируются затраты и группируются по ID строк входных затрат
    3. На случай если по входным строкам будет найдена ошибка округления выбираются первые строки из порядка распределения row_number() OVER (PARTITION BY co.cost_input_id ORDER BY co.id) и for_fix."row_number" = 1
    4. Фильтруются строки у которых найдены ошибки округления WHERE (base.cost_output_sum - ci2.cost_sum) != 0

Что бы увидеть ошибки округления нужно закоментировать блок исправления ошибок округления в скрипте sql_solution.sql
*/
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
SELECT base.*, 
    (base.cost_output_sum - ci2.cost_sum) as diff
FROM base 
INNER JOIN costs_input ci2 ON ci2.id = base.cost_input_id 
WHERE (base.cost_output_sum - ci2.cost_sum) != 0;
