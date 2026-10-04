-- =====================================================================
-- SQLQuery.sql
-- PT Sejahtera Bersama - BI Analyst Final Task (Bank Muamalat x Rakamin)
-- Dialect: BigQuery Standard SQL | Project: rakamin-bmi | Dataset: sejahtera
--
-- Contents:
--   Load notes  : how the 4 source tables are loaded into BigQuery
--   A. Primary key validation
--   B. Relationship validation (orphan key check)
--   Master table: CREATE TABLE + validation
--   C. Dashboard check queries
--   D. Business analysis queries
--   E. Supporting queries for product- and city-specific recommendations
-- =====================================================================

-- =====================================================================
-- LOAD NOTES (done in the BigQuery console: Create table > Upload)
-- Common settings: format CSV, Field delimiter = Custom ';', Header rows to skip = 1
-- Source files: customers.csv, orders.csv, products.csv, product_category.csv
--
-- customers        (manual schema, 9 columns)
--   CustomerID:INTEGER,FirstName:STRING,LastName:STRING,CustomerEmail:STRING,
--   CustomerPhone:STRING,CustomerAddress:STRING,CustomerCity:STRING,
--   CustomerState:STRING,CustomerZip:STRING
-- orders           (manual schema, 5 columns)
--   OrderID:INTEGER,Date:DATE,CustomerID:INTEGER,ProdNumber:STRING,Quantity:INTEGER
-- products         (manual schema, 4 columns, ALL columns STRING)
--   ProdNumber:STRING,ProdName:STRING,Category:STRING,Price:STRING
--   Price uses a decimal comma (e.g. 9,99). Auto-detect reads it as 999 and
--   inflates sales by 100x, so Price and Category are converted in SQL with
--   CAST(REPLACE(Price, ',', '.') AS FLOAT64) and CAST(Category AS INT64).
-- product_category (Auto detect, 3 columns)
--
-- Expected row counts: customers 2123, orders 3339, products 70, product_category 7
-- =====================================================================


-- =====================================================================
-- A. Primary key validation
-- Expected: total_rows = distinct_keys and null_keys = 0
-- =====================================================================

SELECT 'customers' AS table_name, 'CustomerID' AS pk,
       COUNT(*) AS total_rows,
       COUNT(DISTINCT CustomerID) AS distinct_keys,
       COUNTIF(CustomerID IS NULL) AS null_keys
FROM `rakamin-bmi.sejahtera.customers`
UNION ALL
SELECT 'products', 'ProdNumber',
       COUNT(*), COUNT(DISTINCT ProdNumber), COUNTIF(ProdNumber IS NULL)
FROM `rakamin-bmi.sejahtera.products`
UNION ALL
SELECT 'orders', 'OrderID',
       COUNT(*), COUNT(DISTINCT OrderID), COUNTIF(OrderID IS NULL)
FROM `rakamin-bmi.sejahtera.orders`
UNION ALL
SELECT 'product_category', 'CategoryID',
       COUNT(*), COUNT(DISTINCT CategoryID), COUNTIF(CategoryID IS NULL)
FROM `rakamin-bmi.sejahtera.product_category`;


-- =====================================================================
-- B. Relationship validation (orphan key check)
-- Expected: all counts = 0
-- =====================================================================

SELECT
  (SELECT COUNT(*) FROM `rakamin-bmi.sejahtera.orders` o
    LEFT JOIN `rakamin-bmi.sejahtera.customers` c ON o.CustomerID = c.CustomerID
    WHERE c.CustomerID IS NULL) AS orders_without_customer,
  (SELECT COUNT(*) FROM `rakamin-bmi.sejahtera.orders` o
    LEFT JOIN `rakamin-bmi.sejahtera.products` p ON o.ProdNumber = p.ProdNumber
    WHERE p.ProdNumber IS NULL) AS orders_without_product,
  (SELECT COUNT(*) FROM `rakamin-bmi.sejahtera.products` p
    LEFT JOIN `rakamin-bmi.sejahtera.product_category` pc ON CAST(p.Category AS INT64) = pc.CategoryID
    WHERE pc.CategoryID IS NULL) AS products_without_category;

-- Relationships:
--   product_category (1) --> (N) products   [products.Category   = product_category.CategoryID]
--   products         (1) --> (N) orders     [orders.ProdNumber   = products.ProdNumber]
--   customers        (1) --> (N) orders     [orders.CustomerID   = customers.CustomerID]



-- =====================================================================
-- MASTER TABLE
-- Notes:
--  * CustomerEmail in the raw data looks like 'abc@x.com#mailto:abc@x.com#',
--    so it is cleaned with SPLIT(CustomerEmail, '#')[OFFSET(0)].
--  * products was loaded with all columns as STRING (decimal comma in the source
--    CSV), so Price is converted with CAST(REPLACE(Price, ',', '.') AS FLOAT64)
--    and Category with CAST(Category AS INT64).
-- =====================================================================

CREATE OR REPLACE TABLE `rakamin-bmi.sejahtera.master_table` AS
SELECT
  CAST(o.Date AS DATE)                        AS order_date,
  pc.CategoryName                             AS category_name,
  p.ProdName                                  AS product_name,
  CAST(REPLACE(p.Price, ',', '.') AS FLOAT64)  AS product_price,
  o.Quantity                                  AS order_qty,
  ROUND(o.Quantity * CAST(REPLACE(p.Price, ',', '.') AS FLOAT64), 2)  AS total_sales,
  SPLIT(c.CustomerEmail, '#')[OFFSET(0)]      AS cust_email,
  c.CustomerCity                              AS cust_city
FROM `rakamin-bmi.sejahtera.orders` o
JOIN `rakamin-bmi.sejahtera.products` p
  ON o.ProdNumber = p.ProdNumber
JOIN `rakamin-bmi.sejahtera.product_category` pc
  ON CAST(p.Category AS INT64) = pc.CategoryID
JOIN `rakamin-bmi.sejahtera.customers` c
  ON o.CustomerID = c.CustomerID
ORDER BY order_date, o.OrderID;

-- Preview
SELECT * FROM `rakamin-bmi.sejahtera.master_table` ORDER BY order_date LIMIT 10;

-- Validation (expected: 3,339 rows, total_sales ~ 1,754,750.57, total_qty 11,654)
SELECT COUNT(*)         AS row_count,
       SUM(total_sales) AS total_sales,
       SUM(order_qty)   AS total_qty,
       MIN(order_date)  AS start_date,
       MAX(order_date)  AS end_date
FROM `rakamin-bmi.sejahtera.master_table`;


-- =====================================================================
-- C. Dashboard check queries (Looker Studio figures should match these)
-- To export the master table: run SELECT * FROM master_table, then Save results > CSV (local file)
-- =====================================================================

-- Total sales
SELECT SUM(total_sales) AS total_sales FROM `rakamin-bmi.sejahtera.master_table`;

-- Sales and quantity by product category
SELECT category_name,
       SUM(total_sales) AS total_sales,
       SUM(order_qty)   AS total_qty
FROM `rakamin-bmi.sejahtera.master_table`
GROUP BY category_name
ORDER BY total_sales DESC;

-- Sales and quantity by city
SELECT cust_city,
       SUM(total_sales) AS total_sales,
       SUM(order_qty)   AS total_qty
FROM `rakamin-bmi.sejahtera.master_table`
GROUP BY cust_city
ORDER BY total_sales DESC;

-- Top 5 categories by sales
SELECT category_name, SUM(total_sales) AS total_sales
FROM `rakamin-bmi.sejahtera.master_table`
GROUP BY category_name
ORDER BY total_sales DESC
LIMIT 5;

-- Top 5 categories by quantity
SELECT category_name, SUM(order_qty) AS total_qty
FROM `rakamin-bmi.sejahtera.master_table`
GROUP BY category_name
ORDER BY total_qty DESC
LIMIT 5;


-- =====================================================================
-- D. Business analysis queries (support the recommendations)
-- =====================================================================

-- D1. Yearly sales and YoY growth
WITH yearly AS (
  SELECT EXTRACT(YEAR FROM order_date) AS order_year, SUM(total_sales) AS total_sales
  FROM `rakamin-bmi.sejahtera.master_table`
  GROUP BY order_year
)
SELECT order_year, total_sales,
       ROUND(SAFE_DIVIDE(total_sales - LAG(total_sales) OVER (ORDER BY order_year),
                         LAG(total_sales) OVER (ORDER BY order_year)) * 100, 2) AS yoy_pct
FROM yearly
ORDER BY order_year;

-- D2. Monthly sales (weakest and peak months)
SELECT FORMAT_DATE('%Y-%m', order_date) AS month_label,
       SUM(total_sales) AS total_sales,
       SUM(order_qty)   AS total_qty
FROM `rakamin-bmi.sejahtera.master_table`
GROUP BY month_label
ORDER BY month_label;

-- D3. Category contribution to total sales and quantity
SELECT category_name,
       SUM(total_sales) AS total_sales,
       ROUND(SUM(total_sales) / SUM(SUM(total_sales)) OVER () * 100, 2) AS pct_sales,
       SUM(order_qty)   AS total_qty,
       ROUND(SUM(order_qty) / SUM(SUM(order_qty)) OVER () * 100, 2)     AS pct_qty
FROM `rakamin-bmi.sejahtera.master_table`
GROUP BY category_name
ORDER BY total_sales DESC;

-- D4. Top 10 products by sales
SELECT product_name, category_name,
       SUM(total_sales) AS total_sales,
       SUM(order_qty)   AS total_qty
FROM `rakamin-bmi.sejahtera.master_table`
GROUP BY product_name, category_name
ORDER BY total_sales DESC
LIMIT 10;

-- D5. Customers who never ordered (activation campaign target)
-- Expected: 452 of 2,123 customers
SELECT COUNT(*) AS customers_never_ordered
FROM `rakamin-bmi.sejahtera.customers` c
LEFT JOIN `rakamin-bmi.sejahtera.orders` o ON c.CustomerID = o.CustomerID
WHERE o.OrderID IS NULL;

-- D6. Order frequency distribution per customer (repeat orders)
WITH freq AS (
  SELECT CustomerID, COUNT(*) AS order_count
  FROM `rakamin-bmi.sejahtera.orders`
  GROUP BY CustomerID
)
SELECT order_count, COUNT(*) AS customer_count
FROM freq
GROUP BY order_count
ORDER BY order_count;

-- D7. Sales by category and year
SELECT EXTRACT(YEAR FROM order_date) AS order_year,
       category_name,
       SUM(total_sales) AS total_sales
FROM `rakamin-bmi.sejahtera.master_table`
GROUP BY order_year, category_name
ORDER BY category_name, order_year;

-- D8. Top 10 cities by sales
SELECT cust_city,
       SUM(total_sales) AS total_sales,
       SUM(order_qty)   AS total_qty
FROM `rakamin-bmi.sejahtera.master_table`
GROUP BY cust_city
ORDER BY total_sales DESC
LIMIT 10;


-- =====================================================================
-- E. Supporting queries for product- and city-specific recommendations
-- =====================================================================

-- E1. Sales and quantity growth by category, 2020 vs 2021
SELECT category_name,
       SUM(IF(EXTRACT(YEAR FROM order_date) = 2020, total_sales, 0)) AS sales_2020,
       SUM(IF(EXTRACT(YEAR FROM order_date) = 2021, total_sales, 0)) AS sales_2021,
       ROUND(SAFE_DIVIDE(SUM(IF(EXTRACT(YEAR FROM order_date) = 2021, total_sales, 0)),
                         SUM(IF(EXTRACT(YEAR FROM order_date) = 2020, total_sales, 0))) * 100 - 100, 1) AS growth_sales_pct,
       SUM(IF(EXTRACT(YEAR FROM order_date) = 2020, order_qty, 0)) AS qty_2020,
       SUM(IF(EXTRACT(YEAR FROM order_date) = 2021, order_qty, 0)) AS qty_2021
FROM `rakamin-bmi.sejahtera.master_table`
GROUP BY category_name
ORDER BY sales_2020 DESC;

-- E2. Average price per unit and average order value by category
SELECT category_name,
       ROUND(SUM(total_sales) / SUM(order_qty), 2) AS avg_price_per_unit,
       ROUND(SUM(total_sales) / COUNT(*), 2)       AS avg_order_value
FROM `rakamin-bmi.sejahtera.master_table`
GROUP BY category_name
ORDER BY avg_order_value DESC;

-- E3. Top 3 products per category by sales
SELECT * EXCEPT(rn)
FROM (
  SELECT category_name, product_name,
         SUM(total_sales) AS total_sales,
         SUM(order_qty)   AS total_qty,
         ROW_NUMBER() OVER (PARTITION BY category_name ORDER BY SUM(total_sales) DESC) AS rn
  FROM `rakamin-bmi.sejahtera.master_table`
  GROUP BY category_name, product_name
)
WHERE rn <= 3
ORDER BY category_name, rn;

-- E4. Monthly sales by category (Robots vs Drones volatility)
SELECT FORMAT_DATE('%Y-%m', order_date) AS month_label,
       category_name,
       SUM(total_sales) AS total_sales,
       SUM(order_qty)   AS total_qty
FROM `rakamin-bmi.sejahtera.master_table`
GROUP BY month_label, category_name
ORDER BY month_label, category_name;

-- E5. City sales 2020 vs 2021 (sharpest declines)
SELECT cust_city,
       SUM(IF(EXTRACT(YEAR FROM order_date) = 2020, total_sales, 0)) AS sales_2020,
       SUM(IF(EXTRACT(YEAR FROM order_date) = 2021, total_sales, 0)) AS sales_2021,
       SUM(IF(EXTRACT(YEAR FROM order_date) = 2021, total_sales, 0))
         - SUM(IF(EXTRACT(YEAR FROM order_date) = 2020, total_sales, 0)) AS diff
FROM `rakamin-bmi.sejahtera.master_table`
GROUP BY cust_city
ORDER BY diff ASC
LIMIT 10;

-- E6. Customers who only bought low-value products (upsell target)
-- Uses source tables because master_table has no CustomerID
WITH cust_cat AS (
  SELECT o.CustomerID,
         LOGICAL_OR(pc.CategoryName IN ('Robots', 'Drones')) AS bought_robots_drones,
         LOGICAL_AND(pc.CategoryName IN ('eBooks', 'Training Videos', 'Blueprints')) AS only_low_value
  FROM `rakamin-bmi.sejahtera.orders` o
  JOIN `rakamin-bmi.sejahtera.products` p ON o.ProdNumber = p.ProdNumber
  JOIN `rakamin-bmi.sejahtera.product_category` pc ON CAST(p.Category AS INT64) = pc.CategoryID
  GROUP BY o.CustomerID
)
SELECT COUNT(*) AS active_customers,
       COUNTIF(only_low_value) AS only_low_value,
       ROUND(COUNTIF(only_low_value) / COUNT(*) * 100, 1) AS pct_only_low_value,
       ROUND(COUNTIF(bought_robots_drones) / COUNT(*) * 100, 1) AS pct_bought_robots_drones
FROM cust_cat;

-- E7. Sales concentration by customer decile (top 10% of customers)
WITH spend AS (
  SELECT o.CustomerID, SUM(o.Quantity * CAST(REPLACE(p.Price, ',', '.') AS FLOAT64)) AS total_spend
  FROM `rakamin-bmi.sejahtera.orders` o
  JOIN `rakamin-bmi.sejahtera.products` p ON o.ProdNumber = p.ProdNumber
  GROUP BY o.CustomerID
),
ranked AS (
  SELECT *, NTILE(10) OVER (ORDER BY total_spend DESC) AS decile FROM spend
)
SELECT decile, COUNT(*) AS customer_count,
       ROUND(SUM(total_spend), 2) AS total_spend,
       ROUND(SUM(total_spend) / SUM(SUM(total_spend)) OVER () * 100, 1) AS pct_sales
FROM ranked
GROUP BY decile
ORDER BY decile;

-- E8. Sales by state (master table has no state, so join to customers)
SELECT c.CustomerState,
       ROUND(SUM(o.Quantity * CAST(REPLACE(p.Price, ',', '.') AS FLOAT64)), 2) AS total_sales
FROM `rakamin-bmi.sejahtera.orders` o
JOIN `rakamin-bmi.sejahtera.products` p ON o.ProdNumber = p.ProdNumber
JOIN `rakamin-bmi.sejahtera.customers` c ON o.CustomerID = c.CustomerID
GROUP BY c.CustomerState
ORDER BY total_sales DESC
LIMIT 10;
