# SQL Data Warehouse

End-to-end data warehouse built with PostgreSQL following the **Medallion Architecture** (Bronze → Silver → Gold).

Integrates data from two source systems (CRM + ERP), cleans and standardises it through transformation layers, and outputs a **star schema** optimised for analytical queries.

## Architecture

```text
  Source Systems                 Medallion Layers                    Star Schema
  ──────────────                 ────────────────                    ───────────

  CRM                           BRONZE                              GOLD
  ├─ cust_info      ──→         ├─ crm_cust_info                   ┌──────────────┐
  ├─ prd_info        ──→        ├─ crm_prd_info       ──→          │  dim_customer │
  └─ sales_details    ──→       └─ crm_sales_details               │  dim_product  │
                                                        SILVER     │  dim_date     │
  ERP                                                    ──→       │  fact_sales   │
  ├─ CUST_AZ12       ──→       ├─ erp_cust_az12                   └──────────────┘
  ├─ LOC_A101         ──→      ├─ erp_loc_a101
  └─ PX_CAT_G1V2      ──→     └─ erp_px_cat_g1v2
```

## Tech Stack

- **Database:** PostgreSQL
- **Language:** SQL (DDL + DML only — no external tools)
- **Pattern:** Medallion Architecture (Bronze → Silver → Gold)
- **Schema Design:** Star Schema (Kimball methodology)

## Project Structure

```
sql-data-warehouse/
├── 01_bronze_ddl.sql              # Raw table creation + CSV data loading
├── 02_silver_transformations.sql  # Cleaning, deduplication, type casting
├── 03_gold_star_schema.sql        # Star schema (dimensions + fact table)
└── README.md
```

## Layer Breakdown

### Bronze — Raw Ingestion
Creates raw tables mirroring source system schemas and loads CSV data via `COPY`. No transformations — data lands as-is.

**Tables:** `bronze.crm_cust_info`, `bronze.crm_prd_info`, `bronze.crm_sales_details`, `bronze.erp_cust_az12`, `bronze.erp_loc_a101`, `bronze.erp_px_cat_g1v2`

### Silver — Clean & Standardise
Applies data quality rules:
- **Deduplication** via `ROW_NUMBER()` window functions (latest record wins)
- **Type casting** — raw date strings (`YYYYMMDD`) parsed to `DATE`
- **Code expansion** — abbreviations mapped to readable values (`M` → `Male`, `S` → `Single`, `R` → `Road`)
- **Derived fields** — composite keys split into `category_id` + `product_number`
- **Data repair** — missing/negative sales recalculated from `quantity × price`
- **Key normalisation** — ERP customer IDs stripped of prefixes/hyphens to align with CRM keys
- **Audit column** — `dwh_create_date` added to every silver table

### Gold — Star Schema
Joins CRM + ERP silver tables into a denormalized star schema:

| Table | Type | Description |
|-------|------|-------------|
| `dim_customer` | Dimension | CRM customer info + ERP demographics + ERP location |
| `dim_product` | Dimension | CRM product info + ERP category hierarchy, SCD2 flag |
| `dim_date` | Dimension | Generated calendar (year, quarter, month, day, weekend) |
| `fact_sales` | Fact | Order line items with FK references to all dimensions |

**Key design decisions:**
- Customer dimension resolves gender conflicts between CRM and ERP (ERP preferred via `COALESCE`)
- Date dimension auto-generated from `GENERATE_SERIES` spanning the full order date range
- Product dimension includes an `is_current` flag for SCD Type 2 tracking
- Fact table grain is one row per order line item

## How to Run

```sql
-- Execute in order:
\i 01_bronze_ddl.sql
\i 02_silver_transformations.sql
\i 03_gold_star_schema.sql
```

Requires PostgreSQL 12+ and the source CSV files loaded into bronze tables.
