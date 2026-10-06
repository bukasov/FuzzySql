-- Для об'єктивного тестування добавляю індекси до таблиці tbl_cars

CREATE INDEX tbl_cars_prod_year_idx ON tbl_cars(prod_year);
CREATE INDEX tbl_cars_engine_cap_idx ON tbl_cars(engine_capacity);

