/*
 * Step: Initialize Schema Metadata and Reference Dictionaries
 * -------------------------------------------------------------
 * Clears existing test data and populates base lookup tables:
 * - Entity classes and attributes (EAV schema metadata)
 * - Linguistic Variable Values (LVV)
 * - Membership Functions (MF) for fuzzy logic evaluations
 */

TRUNCATE TABLE tbl_possibility;

INSERT INTO tbl_possibility (username, table_name, column_name, linguistic_variable_value, a, b, c, d, type)
VALUES ('user', 'tbl_cars', 'prod_year', 'NEW', 2010, 2015, 2050, 2050, 'trapezoid');

INSERT INTO tbl_possibility (username, table_name, column_name, linguistic_variable_value, a, b, c, d, type)
VALUES ('user', 'tbl_cars', 'prod_year', 'AVERAGE', 1995, 2000, 2010, 2015, 'trapezoid');

INSERT INTO tbl_possibility (username, table_name, column_name, linguistic_variable_value, a, b, c, d, type)
VALUES ('user', 'tbl_cars', 'prod_year', 'OLD', 0, 0, 1995, 2000, 'trapezoid');

INSERT INTO tbl_possibility (username, table_name, column_name, linguistic_variable_value, a, b, c, d, type)
VALUES ('user', 'tbl_cars', 'engine_capacity', 'SMALL', 0, 0.33, 0.66, 1, 'trapezoid');

INSERT INTO tbl_possibility (username, table_name, column_name, linguistic_variable_value, a, b, c, d, type)
VALUES ('user', 'tbl_cars', 'engine_capacity', 'MIDDLE', 0, 1, 1.6, 2.5, 'trapezoid');

INSERT INTO tbl_possibility (username, table_name, column_name, linguistic_variable_value, a, b, c, d, type)
VALUES ('user', 'tbl_cars', 'engine_capacity', 'HIGH', 1.6, 2.5, 5, 8, 'trapezoid');

COMMIT;


-- Disable constraints before TRUNCATE
ALTER TABLE value DISABLE CONSTRAINT value_entity_fk;
ALTER TABLE value DISABLE CONSTRAINT value_attribute_fk;
ALTER TABLE value DISABLE CONSTRAINT value_entity_attribute_uq;
ALTER TABLE lvv DISABLE CONSTRAINT lvv_attribute_fk;
ALTER TABLE mf DISABLE CONSTRAINT mf_lvv_fk;
ALTER TABLE entity DISABLE CONSTRAINT entity_class_fk;
ALTER TABLE attribute DISABLE CONSTRAINT attribute_class_fk;

-- Clear
TRUNCATE TABLE mf;
TRUNCATE TABLE lvv;
TRUNCATE TABLE value;
TRUNCATE TABLE entity;
TRUNCATE TABLE attribute;
TRUNCATE TABLE class;

-- Base class and attributes
INSERT INTO class (class_id, class_name) VALUES (1, 'CAR');

-- Основні атрибути (1-4)
INSERT INTO attribute (attribute_id, class_id, attribute_name, attribute_type) VALUES (1, 1, 'TYPE', 'TEXT');
INSERT INTO attribute (attribute_id, class_id, attribute_name, attribute_type) VALUES (2, 1, 'PROD_YEAR', 'NUMBER');
INSERT INTO attribute (attribute_id, class_id, attribute_name, attribute_type) VALUES (3, 1, 'ENGINE_CAPACITY', 'NUMBER');
INSERT INTO attribute (attribute_id, class_id, attribute_name, attribute_type) VALUES (4, 1, 'PRICE', 'NUMBER');

-- Додаткові атрибути для навантаження EAV-схеми (5-8)
INSERT INTO attribute (attribute_id, class_id, attribute_name, attribute_type) VALUES (5, 1, 'MILEAGE', 'NUMBER');
INSERT INTO attribute (attribute_id, class_id, attribute_name, attribute_type) VALUES (6, 1, 'POWER', 'NUMBER');
INSERT INTO attribute (attribute_id, class_id, attribute_name, attribute_type) VALUES (7, 1, 'DOORS', 'NUMBER');
INSERT INTO attribute (attribute_id, class_id, attribute_name, attribute_type) VALUES (8, 1, 'FUEL_CONSUMPTION', 'NUMBER');

-- LVV & MF (custom fuzzy set definitions)
INSERT INTO lvv(lvv_id, attribute_id, lvv) VALUES (1, 2, 'NEW');
INSERT INTO lvv(lvv_id, attribute_id, lvv) VALUES (2, 2, 'AVERAGE');
INSERT INTO lvv(lvv_id, attribute_id, lvv) VALUES (3, 2, 'OLD');
INSERT INTO lvv(lvv_id, attribute_id, lvv) VALUES (4, 3, 'SMALL');
INSERT INTO lvv(lvv_id, attribute_id, lvv) VALUES (5, 3, 'MIDDLE');
INSERT INTO lvv(lvv_id, attribute_id, lvv) VALUES (6, 3, 'HIGH');

INSERT INTO mf(mf_id, lvv_id, x1, y1, x2, y2) VALUES (1, 1, 2010, 0, 2015, 1);
INSERT INTO mf(mf_id, lvv_id, x1, y1, x2, y2) VALUES (2, 1, 2015, 1, 2050, 1);
INSERT INTO mf(mf_id, lvv_id, x1, y1, x2, y2) VALUES (3, 2, 1995, 0, 2000, 1);
INSERT INTO mf(mf_id, lvv_id, x1, y1, x2, y2) VALUES (4, 2, 2000, 1, 2010, 1);
INSERT INTO mf(mf_id, lvv_id, x1, y1, x2, y2) VALUES (5, 2, 2010, 1, 2015, 0);
INSERT INTO mf(mf_id, lvv_id, x1, y1, x2, y2) VALUES (6, 3, 0000, 1, 1995, 1);
INSERT INTO mf(mf_id, lvv_id, x1, y1, x2, y2) VALUES (7, 3, 1995, 1, 2000, 0);
INSERT INTO mf(mf_id, lvv_id, x1, y1, x2, y2) VALUES (8, 4, 0, 0, 0.33, 1);
INSERT INTO mf(mf_id, lvv_id, x1, y1, x2, y2) VALUES (9, 4, 0.33, 1, 0.66, 1);
INSERT INTO mf(mf_id, lvv_id, x1, y1, x2, y2) VALUES (10, 4, 0.66, 1, 1, 0);
INSERT INTO mf(mf_id, lvv_id, x1, y1, x2, y2) VALUES (11, 5, 0, 0, 1, 1);
INSERT INTO mf(mf_id, lvv_id, x1, y1, x2, y2) VALUES (12, 5, 1, 1, 1.6, 1);
INSERT INTO mf(mf_id, lvv_id, x1, y1, x2, y2) VALUES (13, 5, 1.6, 1, 2.5, 0);
INSERT INTO mf(mf_id, lvv_id, x1, y1, x2, y2) VALUES (14, 6, 1.6, 0, 2.5, 1);
INSERT INTO mf(mf_id, lvv_id, x1, y1, x2, y2) VALUES (15, 6, 2.5, 1, 5, 1);
INSERT INTO mf(mf_id, lvv_id, x1, y1, x2, y2) VALUES (16, 6, 5, 1, 8, 0);
COMMIT;

-- Indexes rebuild
ALTER INDEX attribute_class_id_idx REBUILD;
ALTER INDEX lvv_attribute_id_idx REBUILD;
ALTER INDEX lvv_lvv_idx REBUILD;
ALTER INDEX mf_lvv_id_idx REBUILD;
ALTER INDEX value_entity_id_idx REBUILD;
ALTER INDEX value_attribute_id_idx REBUILD;
ALTER INDEX value_number_value_idx REBUILD;

-- Enable constraints
ALTER TABLE attribute ENABLE CONSTRAINT attribute_class_fk;
ALTER TABLE entity ENABLE CONSTRAINT entity_class_fk;
ALTER TABLE lvv ENABLE CONSTRAINT lvv_attribute_fk;
ALTER TABLE mf ENABLE CONSTRAINT mf_lvv_fk;
ALTER TABLE value ENABLE CONSTRAINT value_entity_attribute_uq;
ALTER TABLE value ENABLE CONSTRAINT value_entity_fk;
ALTER TABLE value ENABLE CONSTRAINT value_attribute_fk;