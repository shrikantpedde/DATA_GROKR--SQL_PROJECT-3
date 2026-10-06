DROP DATABASE IF EXISTS datagrokr_de_pipeline;
CREATE DATABASE datagrokr_de_pipeline;
USE datagrokr_de_pipeline;

CREATE TABLE dim_customer (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    email VARCHAR(100),
    segment VARCHAR(50),
    effective_date DATE,
    end_date DATE,
    is_current BOOLEAN DEFAULT TRUE
);

CREATE TABLE dim_product (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50),
    price DECIMAL(10,2),
    attributes JSON
);

CREATE TABLE fact_sales (
    sales_id INT,
    customer_id INT,
    product_id INT,
    sale_date DATE,
    quantity INT,
    amount DECIMAL(10,2),
    PRIMARY KEY (sales_id, sale_date)
)
PARTITION BY RANGE (YEAR(sale_date)) (
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

INSERT INTO dim_customer (customer_id, customer_name, email, segment, effective_date, end_date, is_current) VALUES
(101, 'Ananya Rao', 'ananya@company.com', 'Enterprise', '2023-01-01', NULL, TRUE),
(102, 'Rahul Sharma', 'rahul@company.com', 'Retail', '2023-01-01', NULL, TRUE),
(103, 'Priya Nair', 'priya@company.com', 'SMB', '2023-01-01', NULL, TRUE);

INSERT INTO dim_product (product_id, product_name, category, price, attributes) VALUES
(201, 'Cloud Data Platform', 'Software', 1500.00, '{"tier": "Gold", "support": "24/7"}'),
(202, 'Analytics Engine', 'Software', 800.00, '{"tier": "Silver", "support": "Business"}'),
(203, 'ETL Pipeline Builder', 'Tools', 450.00, '{"tier": "Bronze", "support": "Standard"}');

INSERT INTO fact_sales (sales_id, customer_id, product_id, sale_date, quantity, amount) VALUES
(1, 101, 201, '2023-05-15', 2, 3000.00),
(2, 102, 202, '2023-11-20', 1, 800.00),
(3, 103, 203, '2024-02-10', 4, 1800.00),
(4, 101, 202, '2024-06-18', 3, 2400.00),
(5, 102, 201, '2025-01-12', 1, 1500.00);

INSERT INTO dim_customer (customer_id, customer_name, email, segment, effective_date, end_date, is_current)
VALUES (102, 'Rahul Sharma', 'rahul_new@company.com', 'Enterprise', '2024-01-01', NULL, TRUE)
ON DUPLICATE KEY UPDATE 
    email = VALUES(email),
    segment = VALUES(segment);

CREATE INDEX idx_sales_customer ON fact_sales(customer_id);
CREATE INDEX idx_sales_cust_date ON fact_sales(customer_id, sale_date);

DELIMITER //
CREATE PROCEDURE ProcessSalesUpsert(
    IN p_sales_id INT,
    IN p_customer_id INT,
    IN p_product_id INT,
    IN p_sale_date DATE,
    IN p_quantity INT,
    IN p_amount DECIMAL(10,2)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    START TRANSACTION;
    
    INSERT INTO fact_sales (sales_id, customer_id, product_id, sale_date, quantity, amount)
    VALUES (p_sales_id, p_customer_id, p_product_id, p_sale_date, p_quantity, p_amount)
    ON DUPLICATE KEY UPDATE
        quantity = VALUES(quantity),
        amount = VALUES(amount);

    COMMIT;
END //
DELIMITER ;

CREATE TABLE sales_audit_log (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    sales_id INT,
    action_type VARCHAR(50),
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DELIMITER //
CREATE TRIGGER trg_after_sales_insert
AFTER INSERT ON fact_sales
FOR EACH ROW
BEGIN
    INSERT INTO sales_audit_log (sales_id, action_type)
    VALUES (NEW.sales_id, 'INSERT');
END //
DELIMITER ;

CALL ProcessSalesUpsert(6, 103, 201, '2025-03-01', 2, 3000.00);

SELECT product_name, attributes->>'$.tier' AS tier, attributes->>'$.support' AS support
FROM dim_product
WHERE attributes->>'$.tier' = 'Gold';

EXPLAIN ANALYZE
SELECT f.sales_id, c.customer_name, p.product_name, f.amount
FROM fact_sales f
JOIN dim_customer c ON f.customer_id = c.customer_id
JOIN dim_product p ON f.product_id = p.product_id
WHERE f.customer_id = 101 AND f.sale_date >= '2023-01-01';

SELECT * FROM fact_sales PARTITION (p2024);