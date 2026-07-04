# 🛍️ Superstore Customer Sales Analysis
### Celebal Summer Internship 2026 — Week 3 SQL Task

![SQL](https://img.shields.io/badge/SQL-Subqueries%20%7C%20CTEs%20%7C%20Window%20Functions-blue?style=flat-square&logo=mysql)
![Dataset](https://img.shields.io/badge/Dataset-Superstore%209%2C994%20rows-orange?style=flat-square)
![Status](https://img.shields.io/badge/Status-Completed-brightgreen?style=flat-square)
![Internship](https://img.shields.io/badge/Celebal%20Technologies-Summer%202026-red?style=flat-square)

---

## 📌 Overview

This repository contains the complete SQL solution for **Week 3** of the Celebal Summer Internship 2026 program.

The task uses the **Sample Superstore dataset** — a retail sales dataset with 9,994 records covering customers, orders, and products across the United States. The goal is to extract customer sales insights using advanced SQL techniques: **Subqueries**, **CTEs**, and **Window Functions**.

---

## 📊 Dataset Summary

| Metric | Value |
|---|---|
| Total rows | 9,994 |
| Unique customers | 793 |
| Unique orders | 5,009 |
| Unique products | 1,862 |
| Date range | 2014 – 2017 |
| Categories | Furniture, Office Supplies, Technology |
| Regions | East, West, Central, South |

---

## 🗂️ Database Schema

```
superstore_raw (raw import)
        │
        ├──▶ customers  (customer_id, customer_name, segment, city, state, region, country)
        ├──▶ products   (product_id, product_name, category, sub_category)
        └──▶ orders     (order_id, order_date, ship_date, ship_mode, customer_id, product_id,
                          sales, quantity, discount, profit)
```

All three tables are built from `superstore_raw` using `SELECT DISTINCT` to eliminate duplicate entries.

---

## 📁 File Structure

```
📦 celebal-sql-week3/
├── 📄 superstore_week3_solution.sql   # Complete SQL script (all queries)
├── 📊 Sample - Superstore.csv         # Source dataset (place in root folder)
└── 📄 README.md                       # This file
```

---

## ▶️ How to Run

### Option 1 — SQLite (Recommended for quick setup)

```bash
# Load the CSV using Python (handles latin-1 encoding)
python3 - << 'EOF'
import pandas as pd, sqlite3
df = pd.read_csv("Sample - Superstore.csv", encoding="latin-1")
df.columns = [c.strip().lower().replace(" ","_").replace("-","_") for c in df.columns]
conn = sqlite3.connect("superstore.db")
df.to_sql("superstore_raw", conn, if_exists="replace", index=False)
print("Loaded", len(df), "rows")
EOF

# Run the SQL solution
sqlite3 superstore.db < superstore_week3_solution.sql
```

### Option 2 — MySQL

```sql
CREATE DATABASE superstore;
USE superstore;
-- Import CSV via LOAD DATA or MySQL Workbench Table Import Wizard
SOURCE superstore_week3_solution.sql;
```

### Option 3 — PostgreSQL

```bash
psql -U your_user -d your_db -f superstore_week3_solution.sql
```

> ⚠️ **Date functions differ by RDBMS:**
> - SQLite: `strftime('%Y', order_date)`
> - MySQL: `YEAR(order_date)` or `DATE_FORMAT(order_date, '%Y')`
> - PostgreSQL: `EXTRACT(YEAR FROM order_date::date)`

---

## 📋 Queries Covered

### Step 2 — Required Queries

| # | Query | Technique |
|---|---|---|
| Q1 | Orders where sales > average sales | Subquery |
| Q2 | Highest sales order per customer | Correlated Subquery |
| Q3 | Total sales per customer | CTE |
| Q4 | Customers with above-average total sales | CTE + Subquery |
| Q5 | Rank all customers by total sales | `RANK()` Window Function |
| Q6 | Row numbers per order within each customer | `ROW_NUMBER()` + `PARTITION BY` |
| Q7 | Top 3 customers by total sales | Window Function + Filter |

### Step 3 — Final Combined Query
One query combining `JOIN` + `CTE` + multiple Window Functions (`RANK`, `NTILE`) to show Customer Name, Total Sales, and Rank.

### Mini Project — Customer Sales Insights

| # | Question | Technique |
|---|---|---|
| MP1 | Who are the top 5 customers? | CTE + RANK() |
| MP2 | Who are the bottom 5 customers? | CTE + RANK() ASC |
| MP3 | Which customers made only one order? | GROUP BY + HAVING |
| MP4 | Which customers have above-average sales? | CTE + Subquery |
| MP5 | What is the highest order value per customer? | CTE + RANK() + PARTITION BY |

---

## 💡 Key Business Insights

| Insight | Finding |
|---|---|
| 🏆 Top customer | Ken Lonsdale — $141,752 lifetime sales |
| 📉 Bottom customer | Lela Donovan — $5.30 lifetime sales |
| 📦 Average customer lifetime value | $19,582.95 |
| 🎯 Above-average customers | ~25% of 793 customers drive the majority of revenue |
| 🔁 Single-order customers | 12 customers — prime targets for re-engagement |
| 💰 Highest single order | Sean Miller — $23,661 (CA-2014-145317) |
| 📊 Revenue skew | Technology category drives the highest-value individual orders |
| 🌍 Top region | West region leads in total sales |

---

## 🧠 SQL Concepts Demonstrated

```sql
-- Subquery (scalar)
WHERE sales > (SELECT AVG(sales) FROM orders)

-- Correlated Subquery
WHERE sales = (SELECT MAX(sales) FROM orders o2 WHERE o2.customer_id = o.customer_id)

-- CTE (Common Table Expression)
WITH customer_sales AS (
    SELECT customer_id, SUM(sales) AS total_sales FROM orders GROUP BY customer_id
)
SELECT * FROM customer_sales WHERE total_sales > (SELECT AVG(total_sales) FROM customer_sales);

-- Window Functions
RANK()       OVER (ORDER BY total_sales DESC)
DENSE_RANK() OVER (ORDER BY total_sales DESC)
ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date)
NTILE(4)     OVER (ORDER BY total_sales DESC)
SUM(sales)   OVER (PARTITION BY customer_id ORDER BY order_date ROWS UNBOUNDED PRECEDING)
```

---

## 🛠️ Tools Used

- **Database:** SQLite (local), compatible with MySQL / PostgreSQL
- **Language:** Standard SQL
- **Dataset:** Tableau Sample Superstore (9,994 rows)
- **Concepts:** Subqueries, CTEs, Window Functions, JOINs, Aggregation, HAVING

---

## 👤 Author

**[Your Name]**  
Celebal Summer Internship 2026 — SQL Track  
Celebal Technologies

---

## 📜 License

This project is created for educational purposes as part of the Celebal Technologies internship program.
