-- ============================================================
-- SNOWFLAKE ICEBERG + DUCKDB FEDERATION SETUP
-- ============================================================
-- Run this entire script in Snowsight or SnowSQL.
-- It creates everything needed for DuckDB federation.
-- ============================================================

-- ============================================================
-- STEP 1: Create Database
-- ============================================================
CREATE OR REPLACE DATABASE ICEBERG_DUCKDB_DEMO;
USE DATABASE ICEBERG_DUCKDB_DEMO;
USE SCHEMA PUBLIC;

-- ============================================================
-- STEP 2: Create Iceberg Tables
-- ============================================================
CREATE OR REPLACE ICEBERG TABLE customers (
    customer_id INT,
    name STRING,
    email STRING,
    city STRING,
    signup_date DATE
)
  CATALOG = 'SNOWFLAKE'
  EXTERNAL_VOLUME = 'SF_MANAGED_ICEBERG_VOL'
  BASE_LOCATION = 'iceberg_duckdb_demo/customers';

CREATE OR REPLACE ICEBERG TABLE products (
    product_id INT,
    product_name STRING,
    category STRING,
    price DECIMAL(10,2)
)
  CATALOG = 'SNOWFLAKE'
  EXTERNAL_VOLUME = 'SF_MANAGED_ICEBERG_VOL'
  BASE_LOCATION = 'iceberg_duckdb_demo/products';

CREATE OR REPLACE ICEBERG TABLE orders (
    order_id INT,
    customer_id INT,
    product_id INT,
    quantity INT,
    order_date DATE,
    total_amount DECIMAL(10,2)
)
  CATALOG = 'SNOWFLAKE'
  EXTERNAL_VOLUME = 'SF_MANAGED_ICEBERG_VOL'
  BASE_LOCATION = 'iceberg_duckdb_demo/orders';

-- ============================================================
-- STEP 3: Insert Sample Data
-- ============================================================
INSERT INTO customers VALUES
  (1, 'Alice Johnson', 'alice@example.com', 'New York', '2024-01-15'),
  (2, 'Bob Smith', 'bob@example.com', 'San Francisco', '2024-02-20'),
  (3, 'Charlie Lee', 'charlie@example.com', 'Chicago', '2024-03-10'),
  (4, 'Diana Patel', 'diana@example.com', 'Austin', '2024-04-05'),
  (5, 'Eve Martinez', 'eve@example.com', 'Seattle', '2024-05-12');

INSERT INTO products VALUES
  (101, 'Wireless Mouse', 'Electronics', 29.99),
  (102, 'Mechanical Keyboard', 'Electronics', 89.99),
  (103, 'USB-C Hub', 'Accessories', 49.99),
  (104, 'Monitor Stand', 'Furniture', 39.99),
  (105, 'Desk Lamp', 'Furniture', 24.99);

INSERT INTO orders VALUES
  (1001, 1, 101, 2, '2024-06-01', 59.98),
  (1002, 2, 102, 1, '2024-06-03', 89.99),
  (1003, 3, 103, 3, '2024-06-05', 149.97),
  (1004, 1, 104, 1, '2024-06-07', 39.99),
  (1005, 4, 105, 2, '2024-06-10', 49.98),
  (1006, 5, 101, 1, '2024-06-12', 29.99),
  (1007, 2, 103, 2, '2024-06-15', 99.98),
  (1008, 3, 102, 1, '2024-06-18', 89.99);

-- ============================================================
-- STEP 4: Verify Data
-- ============================================================
SELECT o.order_id, c.name, p.product_name, o.quantity, o.total_amount
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN products p ON o.product_id = p.product_id
ORDER BY o.order_date;

-- ============================================================
-- STEP 5: Create Role and Service User for Horizon Access
-- ============================================================
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE ROLE iceberg_duckdb_role;
GRANT USAGE ON DATABASE ICEBERG_DUCKDB_DEMO TO ROLE iceberg_duckdb_role;
GRANT USAGE ON SCHEMA ICEBERG_DUCKDB_DEMO.PUBLIC TO ROLE iceberg_duckdb_role;
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA ICEBERG_DUCKDB_DEMO.PUBLIC TO ROLE iceberg_duckdb_role;
GRANT USAGE ON EXTERNAL VOLUME SF_MANAGED_ICEBERG_VOL TO ROLE iceberg_duckdb_role;

CREATE OR REPLACE USER horizon_duckdb_user
  TYPE = SERVICE
  DEFAULT_ROLE = iceberg_duckdb_role
  DEFAULT_WAREHOUSE = 'DEMO_WH';
GRANT ROLE iceberg_duckdb_role TO USER horizon_duckdb_user;
GRANT ROLE ACCOUNTADMIN TO USER horizon_duckdb_user;

-- ============================================================
-- STEP 6: Generate Programmatic Access Token (PAT)
-- ============================================================
-- *** SAVE THE token_secret FROM THE OUTPUT! ***
-- You will paste it into duckdb_iceberg_demo.py
ALTER USER horizon_duckdb_user ADD PROGRAMMATIC ACCESS TOKEN horizon_duckdb_pat
  DAYS_TO_EXPIRY = 30
  ROLE_RESTRICTION = 'ACCOUNTADMIN'
  COMMENT = 'PAT for DuckDB + MCP server access';

-- ============================================================
-- VERIFICATION QUERIES (run after DuckDB script completes)
-- ============================================================
-- These confirm DuckDB-written data is visible in Snowflake:
--
-- SELECT * FROM ICEBERG_DUCKDB_DEMO.PUBLIC.CUSTOMERS WHERE customer_id = 200;
-- SELECT * FROM ICEBERG_DUCKDB_DEMO.PUBLIC.PRODUCTS WHERE product_id = 300;
-- SELECT * FROM ICEBERG_DUCKDB_DEMO.PUBLIC.ORDERS WHERE order_id = 3001;

-- ============================================================
-- CLEANUP (optional — run when you're done with the demo)
-- ============================================================
-- DROP DATABASE ICEBERG_DUCKDB_DEMO;
-- DROP USER horizon_duckdb_user;
-- DROP ROLE iceberg_duckdb_role;
