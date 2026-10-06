# DataGrokr PLP Week 6: Enterprise Data Engineering SQL Pipeline

## Executive Summary
This repository contains the end-to-end relational database solution for the **DataGrokr Pre-Learning Program (PLP) Week 6 Mini Project**. Designed specifically for high-throughput Data Engineering workflows, this project demonstrates advanced MySQL implementation including Dimensional Modeling (Star Schema), Range Table Partitioning, Dynamic MERGE/UPSERT pattern execution, Stored Procedures, ACID-compliant transactions, Triggers, Semi-Structured JSON Data processing, and Query Performance Optimization using `EXPLAIN ANALYZE`.

---

## Business Problem & Technical Architecture

### Business Scenario
Modern enterprise data warehouses require robust data pipelines capable of handling historical data retention, incremental data ingestion, schema evolution, and millisecond analytical query execution. Standard database setups fail under heavy read/write contention and massive data volume growth.

### Technical Solution
To solve these challenges, this pipeline establishes a modern **Star Schema architecture** consisting of fact and dimension tables engineered with the following technical enhancements:
* **Table Partitioning:** Implemented `RANGE` partitioning on transaction dates across multi-year operational boundaries, isolating cold historical data from active transactional queries.
* **Incremental Ingestion (MERGE / UPSERT):** Utilized MySQL native `ON DUPLICATE KEY UPDATE` logic within atomic transactions to perform idempotent batch updates without producing duplicate rows.
* **Semi-Structured Storage:** Stored variable product parameters within native `JSON` attributes to allow flexible schema iteration without expensive `ALTER TABLE` locks.
* **Query Acceleration:** Deployed targeted single-column and composite secondary indexes to optimize join predicates and filter conditions.

---

## Detailed Component Breakdown

### 1. Schema Design & Dimensional Modeling
* **`dim_customer`**: Dimension table engineered to track customer profile metadata, segmentation, and Slowly Changing Dimension (SCD Type 2) flags like `effective_date`, `end_date`, and `is_current`.
* **`dim_product`**: Dimension table using native MySQL `JSON` column types to query nested product attributes (`tier`, `support`) directly using JSON path operators (`->>`).
* **`fact_sales`**: Primary fact table containing core transactional metrics (`quantity`, `amount`) linked to dimension surrogate keys.

### 2. High-Performance Partitioning Strategy
The `fact_sales` table is partitioned by range on `YEAR(sale_date)`:
* **`p2023`**: Contains all sales records prior to 2024.
* **`p2024`**: Dedicated partition for 2024 transactions.
* **`p2025`**: Dedicated partition for 2025 transactions.
* **`p_future`**: Catch-all partition using `LESS THAN MAXVALUE` to prevent insertion errors during future pipeline runs.

### 3. Automated Ingestion & ACID Controls
* **Stored Procedure (`ProcessSalesUpsert`)**: Encapsulates data load operations. Wrapped in explicit `START TRANSACTION` and `COMMIT` blocks with an `EXIT HANDLER FOR SQLEXCEPTION` that executes `ROLLBACK` to prevent partial batch writes.
* **Audit Logging (`trg_after_sales_insert`)**: An automated row-level `AFTER INSERT` trigger that writes transaction metadata into `sales_audit_log` for compliance and ETL observability.

### 4. Query Optimization & Analysis
To ensure scalability, query execution plans were evaluated using MySQL `EXPLAIN ANALYZE`:
* **Index Mechanics**: Evaluated single-column (`idx_sales_customer`) and multi-column composite (`idx_sales_cust_date`) indexes.
* **Partition Pruning Verification**: Confirmed that queries scoped to specific date ranges scan only relevant partition pages rather than executing full table scans, drastically reducing I/O footprint.

---
