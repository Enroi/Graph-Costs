SELECT rh.department_name "Отдел владелец правила", 
    rh."limit" "Минимум распределения",
    rr.formula "Формула",
    rr.disable_child_creation "Окончить распределение",
    rh2.department_name "Отдел получатель затрат"
FROM rules_headers rh 
JOIN rules_rows rr ON rh.id = rr.rule_header_id
JOIN rules_headers rh2 ON rh2.id = rr.dest_rule_id
ORDER BY 1, 5