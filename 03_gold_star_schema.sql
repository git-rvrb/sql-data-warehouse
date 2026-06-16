-- =============================================================================
-- GOLD LAYER — Star Schema
-- =============================================================================
-- Builds the analytical star schema by joining Silver CRM + ERP tables into
-- denormalized dimension and fact tables optimized for reporting.
--
-- Schema: gold
-- Tables: gold.dim_customer, gold.dim_product, gold.dim_date, gold.fact_sales
-- =============================================================================


-- ─────────────────────────────────────────────
-- DIMENSION: Customers
-- ─────────────────────────────────────────────
-- Joins CRM customer info with ERP demographics and locations
-- to create a single customer dimension with all attributes.

DROP TABLE IF EXISTS gold.dim_customer;

CREATE TABLE gold.dim_customer (
    customer_key    INT PRIMARY KEY,      -- Surrogate key (from CRM cst_id)
    customer_id     VARCHAR(50),          -- Natural key (CRM cst_key)
    first_name      VARCHAR(50),
    last_name       VARCHAR(50),
    full_name       VARCHAR(100),
    gender          VARCHAR(10),
    marital_status  VARCHAR(20),
    birth_date      DATE,
    country         VARCHAR(50),
    create_date     DATE,
    dwh_create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO gold.dim_customer (
    customer_key, customer_id, first_name, last_name, full_name,
    gender, marital_status, birth_date, country, create_date
)
SELECT
    c.cst_id        AS customer_key,
    c.cst_key       AS customer_id,
    c.cst_firstname AS first_name,
    c.cst_lastname  AS last_name,
    CONCAT(c.cst_firstname, ' ', c.cst_lastname) AS full_name,

    -- Prefer ERP gender (more complete), fall back to CRM
    COALESCE(NULLIF(e.gen, 'n/a'), c.cst_gndr) AS gender,

    c.cst_marital_status AS marital_status,
    e.bdate              AS birth_date,
    COALESCE(l.cntry, 'n/a') AS country,
    c.cst_create_date    AS create_date

FROM silver.crm_cust_info c
LEFT JOIN silver.erp_cust_az12 e
    ON c.cst_key = e.cid
LEFT JOIN silver.erp_loc_a101 l
    ON c.cst_key = l.cid;


-- ─────────────────────────────────────────────
-- DIMENSION: Products
-- ─────────────────────────────────────────────
-- Joins CRM product info with ERP category hierarchy.

DROP TABLE IF EXISTS gold.dim_product;

CREATE TABLE gold.dim_product (
    product_key     INT PRIMARY KEY,      -- Surrogate key (from CRM prd_id)
    product_number  VARCHAR(50),          -- Natural key
    product_name    VARCHAR(50),
    product_cost    INT,
    product_line    VARCHAR(50),
    category        VARCHAR(50),
    subcategory     VARCHAR(50),
    maintenance     VARCHAR(50),
    start_date      DATE,
    end_date        DATE,
    dwh_create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO gold.dim_product (
    product_key, product_number, product_name, product_cost, product_line,
    category, subcategory, maintenance, start_date, end_date, is_current
)
SELECT
    p.prd_id              AS product_key,
    p.product_number      AS product_number,
    p.prd_nm              AS product_name,
    p.prd_cost            AS product_cost,
    p.prd_line            AS product_line,
    COALESCE(cat.cat, 'n/a')    AS category,
    COALESCE(cat.subcat, 'n/a') AS subcategory,
    COALESCE(cat.maintenance, 'n/a') AS maintenance,
    p.prd_start_dt        AS start_date,
    p.prd_end_dt          AS end_date,
    CASE
        WHEN p.prd_end_dt IS NULL THEN TRUE
        ELSE FALSE
    END AS is_current

FROM silver.crm_prd_info p
LEFT JOIN silver.erp_px_cat_g1v2 cat
    ON p.category_id = cat.id;


-- ─────────────────────────────────────────────
-- DIMENSION: Date
-- ─────────────────────────────────────────────
-- Generated calendar dimension from the earliest to latest order date.
-- Enables time-based slicing by year, quarter, month, day of week.

DROP TABLE IF EXISTS gold.dim_date;

CREATE TABLE gold.dim_date (
    date_key        INT PRIMARY KEY,     
    full_date       DATE NOT NULL,
    year            INT,
    quarter         INT,
    month           INT,
    month_name      VARCHAR(20),
    day             INT,
    day_of_week     INT,             
    day_name        VARCHAR(20),
    is_weekend      BOOLEAN
);

INSERT INTO gold.dim_date (
    date_key, full_date, year, quarter, month, month_name,
    day, day_of_week, day_name, is_weekend
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT  AS date_key,
    d                             AS full_date,
    EXTRACT(YEAR FROM d)::INT     AS year,
    EXTRACT(QUARTER FROM d)::INT  AS quarter,
    EXTRACT(MONTH FROM d)::INT    AS month,
    TO_CHAR(d, 'Month')          AS month_name,
    EXTRACT(DAY FROM d)::INT      AS day,
    EXTRACT(DOW FROM d)::INT      AS day_of_week,
    TO_CHAR(d, 'Day')            AS day_name,
    EXTRACT(DOW FROM d) IN (0, 6) AS is_weekend
FROM (
    SELECT GENERATE_SERIES(
        (SELECT MIN(sls_order_dt) FROM silver.crm_sales_details),
        (SELECT MAX(sls_order_dt) FROM silver.crm_sales_details),
        INTERVAL '1 day'
    )::DATE AS d
) dates;


-- ─────────────────────────────────────────────
-- FACT: Sales
-- ─────────────────────────────────────────────
-- Grain: one row per order line item.
-- Foreign keys reference dimension surrogate keys.

DROP TABLE IF EXISTS gold.fact_sales;

CREATE TABLE gold.fact_sales (
    order_number    VARCHAR(50),
    customer_key    INT REFERENCES gold.dim_customer(customer_key),
    product_key     INT REFERENCES gold.dim_product(product_key),
    order_date_key  INT REFERENCES gold.dim_date(date_key),
    ship_date_key   INT,
    due_date_key    INT,
    sales_amount    INT,
    quantity        INT,
    unit_price      INT,
    dwh_create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO gold.fact_sales (
    order_number, customer_key, product_key,
    order_date_key, ship_date_key, due_date_key,
    sales_amount, quantity, unit_price
)
SELECT
    s.sls_ord_num   AS order_number,
    c.customer_key  AS customer_key,
    p.product_key   AS product_key,
    TO_CHAR(s.sls_order_dt, 'YYYYMMDD')::INT AS order_date_key,
    CASE WHEN s.sls_ship_dt IS NOT NULL
         THEN TO_CHAR(s.sls_ship_dt, 'YYYYMMDD')::INT
         ELSE NULL
    END AS ship_date_key,
    CASE WHEN s.sls_due_dt IS NOT NULL
         THEN TO_CHAR(s.sls_due_dt, 'YYYYMMDD')::INT
         ELSE NULL
    END AS due_date_key,

    s.sls_sales     AS sales_amount,
    s.sls_quantity  AS quantity,
    s.sls_price     AS unit_price

FROM silver.crm_sales_details s
LEFT JOIN gold.dim_customer c
    ON s.sls_cust_id = c.customer_key
LEFT JOIN gold.dim_product p
    ON s.sls_prd_key = p.product_number;
