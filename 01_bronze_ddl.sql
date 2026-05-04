-- create the DB

CREATE DATABASE data_warehouse;

-- create the layers

CREATE SCHEMA bronze;
CREATE SCHEMA silver;
CREATE SCHEMA gold;

-- (Bronze Layer) create the tables
-- NOTE: the naming convention is as follows: [SourceSystem]_[FileName] 

---- Customer Info
DROP TABLE IF EXISTS bronze.crm_cust_info;
CREATE TABLE bronze.crm_cust_info (
    cst_id INT,
    cst_key VARCHAR(50),
    cst_firstname VARCHAR(50),
    cst_lastname VARCHAR(50),
    cst_marital_status VARCHAR(50),
    cst_gndr VARCHAR(50),
    cst_create_date DATE
);

-- load the CSV data
-- use this if you cannot import the data from inside PG

COPY bronze.crm_cust_info(cst_id, cst_key, cst_firstname, cst_lastname, cst_marital_status, cst_gndr, cst_create_date)FROM 'C:/Users/Aran/Desktop/Aran/Data Warehouse Project/dbc9660c89a3480fa5eb9bae464d6c07/sql-data-warehouse-project/datasets/source_crm/cust_info.csv'
DELIMITER ','
CSV HEADER; 

---- Product Info
DROP TABLE IF EXISTS bronze.crm_prd_info;
CREATE TABLE bronze.crm_prd_info (
	prd_id INT,
	prd_key VARCHAR(50),
	prd_nm VARCHAR(50),
	prd_cost VARCHAR(50),
	prd_line VARCHAR(50),
	prd_start_dt DATE,
	prd_end_dt DATE
);

---- Sales Details
DROP TABLE IF EXISTS bronze.crm_sales_details;
CREATE TABLE bronze.crm_sales_details (
	sls_ord_num VARCHAR(50),
	sls_prd_key VARCHAR(50),
	sls_cust_id INT,
	sls_order_dt VARCHAR(50),
	sls_ship_dt VARCHAR(50),
	sls_due_dt VARCHAR(50),
	sls_sales INT,
	sls_quantity INT,
	sls_price INT
);

---- ERP Customers
DROP TABLE IF EXISTS bronze.erp_CUST_AZ12;
CREATE TABLE bronze.erp_CUST_AZ12 (
	CID VARCHAR(50),
	BDATE DATE,
	GEN VARCHAR(50)
);

---- ERP Locations
DROP TABLE IF EXISTS bronze.erp_LOC_A101;
CREATE TABLE bronze.erp_LOC_A101(
	CID VARCHAR(50),
	CNTRY VARCHAR(50)
);

---- ERP Categories
DROP TABLE IF EXISTS bronze.erp_PX_CAT_G1V2;
CREATE TABLE bronze.erp_PX_CAT_G1V2 (
	ID VARCHAR(50),
	CAT VARCHAR(50),
	SUBCAT VARCHAR(50),
	MAINTENANCE VARCHAR(50)
);










