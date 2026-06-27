BMI Sales Performance Dashboard
Project-Based Virtual Internship — Business Intelligence Analyst
Bank Muamalat x Rakamin Academy | April–May 2025


Project Overview
PT Sejahtera Bersama (Bank Muamalat) needed a data-driven approach to evaluate sales performance across products, customer segments, and cities. This project involved building a relational data model, integrating multiple datasets using SQL, and delivering a business intelligence dashboard with strategic recommendations.


Objectives
- Identify primary keys and map entity relationships across 4 datasets
- Integrate datasets into a unified master table using SQL
- Build an interactive sales performance dashboard
- Deliver data-driven business recommendations

Dataset Structure
| Table | Primary Key | Description |
|-------|-------------|-------------|
| bmi_customers | CustomerID | Customer profile and location data |
| bmi_orders | OrderID | Transaction records with product and quantity |
| bmi_products | ProdNumber | Product name, category reference, and price |
| bmi_productcategory | CategoryID | Product category names and abbreviations |

Entity Relationships:
- One Customer → Many Orders (One-to-Many)
- Many Orders → One Product (Many-to-One)
- Many Products → One Category (Many-to-One)

Tools Used
- Google BigQuery — SQL query execution and master table creation
- Google Looker Studio — Dashboard and data visualization
- SQL — Data integration via multi-table JOINs

SQL Query
The following query creates the master table by joining all 4 datasets:
```sql
CREATE OR REPLACE TABLE `rakamin-bmi.dataset.bmi_master` AS
SELECT
  c.CustomerEmail AS cust_email,
  c.CustomerCity AS cust_city,
  o.Date AS order_date,
  o.Quantity AS order_qty,
  p.ProdName AS product_name,
  p.Price AS product_price,
  pc.CategoryName AS category_name,
  (o.Quantity * p.Price) AS total_sales
FROM
  `rakamin-bmi.dataset.bmi_orders` AS o
JOIN
  `rakamin-bmi.dataset.bmi_customers` AS c
  ON o.CustomerID = c.CustomerID
JOIN
  `rakamin-bmi.dataset.bmi_products` AS p
  ON o.ProdNumber = p.ProdNumber
JOIN
  `rakamin-bmi.dataset.bmi_productcategory` AS pc
  ON p.Category = pc.CategoryID
ORDER BY
  order_date ASC;
```

Dashboard Summary
Key Metrics (All-time):
- Total Sales: Rp1.75 Billion
- Total Orders: 11,654
- Total Customers: 1,671

Top Product Categories by Revenue:
1. Robots
2. Drones
3. Robot Kits
4. Drone Kits
5. Training Videos

Top Product Categories by Order Volume:
1. eBooks
2. Training Videos
3. Blueprints
4. Drone Kits
5. Drones

Top Cities by Sales:
1. Washington — 55,382
2. Houston — 33,761
3. Sacramento — 33,380
4. San Diego — 29,229
5. Albany — 25,406

Key Insights
- Revenue remained stable throughout the analyzed period with strong repeat purchase behavior (11,654 orders from only 1,671 customers)
- Robots and Drones dominate revenue despite moderate order volume, indicating high unit price contribution
- eBooks lead in order quantity but generate lower revenue, reflecting a low average selling price
- Strong geographic concentration in Washington, Houston, and Sacramento suggests untapped potential in smaller cities

Recommendations
1. Product Portfolio Optimization
Implement premium positioning for high-value categories (Robots & Drones). Create bundling packages and subscription models for digital products (eBooks & Training Videos).

2. Geographic Marketing Strategy
Allocate greater resources to top-performing cities. Launch market penetration campaigns in underperforming cities (Albany, Springfield).

3. Customer Retention
Build a data-driven CRM system leveraging repeat purchase behavior. Develop tiered loyalty programs with reward points.

4. Seasonal Promotion Planning
Prepare targeted campaigns for peak periods. Implement dynamic pricing strategies based on demand patterns.

Author
**Refa Defanda Witanto**
International Relations, Universitas Brawijaya
[LinkedIn](https://www.linkedin.com/in/refa-defanda/) | refadfnda@gmail.com

---

Setelah kamu paste README-nya, kalau ada screenshot dari PDF presentasi (slide dashboard-nya), upload juga ke repo sebagai gambar — itu akan langsung muncul di README dan bikin profilnya jauh lebih visual. Mau aku tunjukkan cara menambahkan gambar ke README-nya juga?
