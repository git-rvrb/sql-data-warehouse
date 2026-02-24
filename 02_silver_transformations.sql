DROP TABLE IF EXISTS silver.crm_cust_info;

CREATE TABLE silver.crm_cust_info (
	cst_id INT,
    cst_key VARCHAR(50),
    cst_firstname VARCHAR(50),
    cst_lastname VARCHAR(50),
    cst_marital_status VARCHAR(50),
    cst_gndr VARCHAR(50),
    cst_create_date DATE,
    dwh_create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- new column added to show exactly when data was cleaned
);

-- Transformations
INSERT INTO silver.crm_cust_info (
    cst_id, cst_key, cst_firstname, cst_lastname, cst_marital_status, cst_gndr, cst_create_date
)
SELECT 
    cst_id,
    cst_key,
    TRIM(cst_firstname) AS cst_firstname,
    TRIM(cst_lastname) AS cst_lastname,
    CASE 
        WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
        WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
        ELSE 'n/a'
    END AS cst_marital_status,
    CASE 
        WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
        WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
        ELSE 'n/a' 
    END AS cst_gndr,
    cst_create_date
FROM (
    -- This subquery assigns a rank to duplicates, prioritizing the newest date
    SELECT *,
           ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) as row_num
    FROM bronze.crm_cust_info
) deduplicated_data --(you must give the subquery an Alias!)
WHERE row_num = 1;


--product info

DROP TABLE IF EXISTS silver.crm_prd_info;

CREATE TABLE silver.crm_prd_info (
	prd_id INT,
    category_id VARCHAR(50),
	product_number VARCHAR(50),
    prd_nm VARCHAR(50),
    prd_cost INT,
    prd_line VARCHAR(50),
    prd_start_dt DATE,
    prd_end_dt DATE,
    dwh_create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO silver.crm_prd_info (
    prd_id, category_id, product_number, prd_nm, prd_cost, prd_line, prd_start_dt, prd_end_dt
)
SELECT 
    prd_id,
    SPLIT_PART(prd_key, '-', 1) AS category_id,
    SPLIT_PART(prd_key, '-', 2) AS product_number,
    TRIM(prd_nm) AS prd_nm,
    COALESCE(prd_cost, '0')::INT AS prd_cost,
    CASE 
        WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
        WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Sport'
        WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
        WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
        ELSE 'Other'
    END AS prd_line,
    prd_start_dt,
    prd_end_dt
FROM (
    -- The subquery generates the ranking first
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY prd_id ORDER BY prd_start_dt DESC) AS row_num
    FROM bronze.crm_prd_info
) deduplicated_data
WHERE row_num = 1; 
	

-- Sales Details 

DROP TABLE IF EXISTS silver.crm_sales_details;

-- 1. Create the Silver table with proper DATE and INT types
CREATE TABLE silver.crm_sales_details (
    sls_ord_num VARCHAR(50),
    sls_prd_key VARCHAR(50),
    sls_cust_id INT,
    sls_order_dt DATE,          -- Transformed to DATE
    sls_ship_dt DATE,           -- Transformed to DATE
    sls_due_dt DATE,            -- Transformed to DATE
    sls_sales INT,
    sls_quantity INT,
    sls_price INT,
    dwh_create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Transform and Insert
INSERT INTO silver.crm_sales_details (
    sls_ord_num, sls_prd_key, sls_cust_id, sls_order_dt, sls_ship_dt, sls_due_dt, sls_sales, sls_quantity, sls_price
)
SELECT 
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    
    -- Parse Order Date
    CASE 
        WHEN sls_order_dt = '0' OR LENGTH(sls_order_dt::TEXT) != 8 THEN NULL
        ELSE TO_DATE(sls_order_dt::TEXT, 'YYYYMMDD')
    END AS sls_order_dt,
    
    -- Parse Shipping Date
    CASE 
        WHEN sls_ship_dt = '0' OR LENGTH(sls_ship_dt::TEXT) != 8 THEN NULL
        ELSE TO_DATE(sls_ship_dt::TEXT, 'YYYYMMDD')
    END AS sls_ship_dt,
    
    -- Parse Due Date
    CASE 
        WHEN sls_due_dt = '0' OR LENGTH(sls_due_dt::TEXT) != 8 THEN NULL
        ELSE TO_DATE(sls_due_dt::TEXT, 'YYYYMMDD')
    END AS sls_due_dt,
    
    -- Recalculate Sales if missing, negative, or math is wrong
    CASE 
        WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != (sls_quantity * ABS(sls_price)) -- ABS = absolute value, turns neg into pos
            THEN sls_quantity * ABS(sls_price)
        ELSE sls_sales -- if there are no issues, leave the column data as is
    END AS sls_sales,
    
    sls_quantity,
    
    -- Recalculate Price if missing or negative
    CASE 
        WHEN sls_price IS NULL OR sls_price <= 0 
            THEN sls_sales / NULLIF(sls_quantity, 0)
        ELSE sls_price 
    END AS sls_price

FROM bronze.crm_sales_details;


--erp customers

DROP TABLE IF EXISTS silver.erp_CUST_AZ12;

CREATE TABLE silver.erp_CUST_AZ12 (
	cid VARCHAR(50),
	bdate DATE,
	gen VARCHAR(50),
	dwh_create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO silver.erp_CUST_AZ12 (
	CID, BDATE, GEN
)

SELECT 
	SUBSTRING(cid, 4) AS cid,
	CASE WHEN (bdate > CURRENT_DATE) THEN NULL ELSE bdate
	END AS bdate,
	CASE 
		WHEN UPPER(TRIM(gen)) LIKE 'M%' THEN 'Male'
		WHEN UPPER(TRIM(gen)) LIKE 'F%' THEN 'Female' --always remember to (upper trim) when cleaning 
		ELSE 'n/a'
	END AS gen
FROM bronze.erp_CUST_AZ12;


--erp locations

DROP TABLE IF EXISTS silver.erp_LOC_A101;

CREATE TABLE silver.erp_LOC_A101 (
	cid VARCHAR(50),
	cntry VARCHAR(50),
	dwh_create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO silver.erp_LOC_A101 (
	cid, cntry
)

SELECT
	REPLACE(cid, '-', '') AS cid,
	CASE 
		WHEN UPPER(TRIM(cntry)) LIKE 'US%' THEN 'United States'
		WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'Germany'
		WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
		ELSE cntry
	END AS cntry
FROM bronze.erp_LOC_A101;


--erp categories

DROP TABLE IF EXISTS silver.erp_PX_CAT_G1V2;

CREATE TABLE silver.erp_PX_CAT_G1V2 (
	ID VARCHAR(50),
	CAT VARCHAR(50),
	SUBCAT VARCHAR(50),
	MAINTENANCE VARCHAR(50),
	dwh_create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO silver.erp_PX_CAT_G1V2 (
	ID, CAT, SUBCAT, MAINTENANCE
)

SELECT 
    ID, 
    CAT, 
    SUBCAT, 
    MAINTENANCE
FROM bronze.erp_PX_CAT_G1V2; -- when the data is flawless you drop it in silver as is, but you must select the columns
















