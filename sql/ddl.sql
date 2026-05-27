-- Скрипт создания БД для примера распределения затрат

CREATE TABLE costs_input (
    id bigserial NOT NULL,
    department_name varchar NOT NULL, -- Имя отдела для распределения
    calc_name varchar NOT NULL, -- Наименование/Код расчета
    cost_sum numeric(16, 2) NULL, -- Сумма затрат отдела к распределению
    CONSTRAINT costs_input_pk PRIMARY KEY (id)
);
COMMENT ON TABLE public.costs_input IS 'Таблица входных распределений.';
COMMENT ON COLUMN public.costs_input.department_name IS 'Имя отдела для распределения';
COMMENT ON COLUMN public.costs_input.calc_name IS 'Наименование/Код расчета';
COMMENT ON COLUMN public.costs_input.cost_sum IS 'Сумма затрат отдела к распределению';


CREATE TABLE rules_headers (
    department_name varchar NULL, -- Наименование отдела
    id bigserial NOT NULL,
    "limit" numeric(18, 2) NULL, -- Минимальный лимит с которого начинается распределение расходов на другие отделы
    CONSTRAINT rules_pk PRIMARY KEY (id)
);
COMMENT ON TABLE public.rules_headers IS 'Таблица заголовков распределений';
COMMENT ON COLUMN public.rules_headers.department_name IS 'Наименование отдела';
COMMENT ON COLUMN public.rules_headers."limit" IS 'Минимальный лимит с которого начинается распределение расходов на другие отделы';


CREATE TABLE rules_rows (
    id bigserial NOT NULL, -- PK
    formula varchar NOT NULL, -- Формула расчета суммы распределения
    disable_child_creation bool NULL, -- Если true, дочерние элементы не будут создаваться
    rule_header_id int8 NOT NULL,
    dest_rule_id int8 NULL,
    CONSTRAINT rules_rows_pk PRIMARY KEY (id),
    CONSTRAINT rules_rows_rules_headers_dest_fk FOREIGN KEY (dest_rule_id) REFERENCES rules_headers(id),
    CONSTRAINT rules_rows_rules_headers_fk FOREIGN KEY (rule_header_id) REFERENCES rules_headers(id) ON DELETE CASCADE
);
COMMENT ON TABLE public.rules_rows IS 'Таблица строк распределений. То есть конечных элементов распределения затрат.';
COMMENT ON COLUMN public.rules_rows.id IS 'PK';
COMMENT ON COLUMN public.rules_rows.formula IS 'Формула расчета суммы распределения';
COMMENT ON COLUMN public.rules_rows.disable_child_creation IS 'Если true, дочерние элементы не будут создаваться';
COMMENT ON COLUMN public.rules_rows.rule_header_id IS 'Владелец распределения';
COMMENT ON COLUMN public.rules_rows.dest_rule_id IS 'Загловок распределения на которое передаеются расходы';


CREATE TABLE costs_output (
    id bigserial NOT NULL,
    cost_input_id int8 NULL,
    rules_rows_id int8 NOT NULL,
    parent_row_id int8 NULL,
    summ numeric(16, 2) NOT NULL,
    CONSTRAINT costs_output_pk PRIMARY KEY (id),
    CONSTRAINT costs_output_costs_input_fk FOREIGN KEY (cost_input_id) REFERENCES costs_input(id),
    CONSTRAINT costs_output_costs_output_fk FOREIGN KEY (parent_row_id) REFERENCES costs_output(id),
    CONSTRAINT costs_output_rules_rows_fk FOREIGN KEY (rules_rows_id) REFERENCES rules_rows(id)
);
COMMENT ON TABLE public.costs_output IS 'Таблица результатов распределений. Содержит связи самой на себя.';
COMMENT ON COLUMN public.costs_output.id IS 'PK';
COMMENT ON COLUMN public.costs_output.cost_input_id IS 'Ссылка на входные суммы расходов для распределения';
COMMENT ON COLUMN public.costs_output.rules_rows_id IS 'Ссылка на строку правил распределения, по формуле которой рассчитана сумма расходов';
COMMENT ON COLUMN public.costs_output.parent_row_id IS 'Если это второе и далее распределение в этой строке находится ссылка на строку из которой пришла сумма для распределения по формуле';


-- Индексы
CREATE INDEX idx_costs_input_department_name ON costs_input(department_name);
CREATE INDEX idx_rules_headers_department_name ON rules_headers(department_name);
CREATE INDEX idx_rules_rows_rule_header_id ON rules_rows(rule_header_id);

CREATE INDEX idx_costs_output_rules_rows_id ON costs_output(rules_rows_id);
CREATE INDEX idx_costs_output_parent_row_id ON costs_output(parent_row_id);
CREATE INDEX idx_costs_output_cost_input_id ON costs_output(cost_input_id);

CREATE INDEX idx_costs_output_parent_exists ON costs_output(parent_row_id) 
    WHERE parent_row_id IS NOT NULL;

CREATE INDEX idx_rules_rows_dest_rule_id ON rules_rows(dest_rule_id);
CREATE INDEX idx_rules_rows_disable_child_creation ON rules_rows(disable_child_creation) 
    WHERE disable_child_creation IS FALSE OR disable_child_creation IS NULL;

CREATE INDEX idx_rules_headers_limit ON rules_headers("limit");