-- Для об'єктивного тестування добавляю індекси до таблиці tbl_cars

CREATE INDEX tbl_cars_prod_year_idx ON tbl_cars(prod_year);
CREATE INDEX tbl_cars_engine_cap_idx ON tbl_cars(engine_capacity);

-- Створюємо додаткові індекси для EAV-моделі
CREATE INDEX value_attr_num_idx ON value (attribute_id, number_value);
ALTER TABLE lvv ADD CONSTRAINT lvv_attr_val_uq UNIQUE (attribute_id, lvv);

-- додаємо колонки для кешування меж (Bounding Box) для лінгвістичних термів
DECLARE
    v_col_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_col_exists 
    FROM user_tab_columns 
    WHERE table_name = 'LVV' AND column_name = 'BND_MIN';
    
    IF v_col_exists = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE lvv ADD (bnd_min NUMBER)';
        EXECUTE IMMEDIATE 'ALTER TABLE lvv ADD (bnd_max NUMBER)';
    END IF;
END;
/