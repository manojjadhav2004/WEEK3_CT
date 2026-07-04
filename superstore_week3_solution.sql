-- ============================================================
--  SUPERSTORE SALES ANALYSIS
--  Celebal Summer Internship 2026 — Week 3 SQL Task
--  Subqueries · CTEs · Window Functions
--  Compatible with: SQLite / MySQL / PostgreSQL (standard SQL)
-- ============================================================


-- ════════════════════════════════════════════════════════════
--  STEP 1 — SETUP: Import raw data & create normalised tables
-- ════════════════════════════════════════════════════════════

-- NOTE ─────────────────────────────────────────────────────
--  The Superstore CSV (Sample - Superstore.csv) must be loaded
--  into `superstore_raw` before running this script.
--
--  SQLite one-liner (run in terminal):
--    sqlite3 superstore.db
--    .mode csv
--    .headers on
--    .import "Sample - Superstore.csv" superstore_raw
--
--  Python loader (handles latin-1 encoding):
--    import pandas as pd, sqlite3
--    df = pd.read_csv("Sample - Superstore.csv", encoding="latin-1")
--    df.columns = [c.strip().lower().replace(" ","_").replace("-","_") for c in df.columns]
--    conn = sqlite3.connect("superstore.db")
--    df.to_sql("superstore_raw", conn, if_exists="replace", index=False)
-- ──────────────────────────────────────────────────────────

-- Expected columns in superstore_raw:
--   row_id, order_id, order_date, ship_date, ship_mode,
--   customer_id, customer_name, segment, country, city,
--   state, postal_code, region, product_id, category,
--   sub_category, product_name, sales, quantity, discount, profit


-- ── 1A. Create customers table ──────────────────────────────
CREATE TABLE IF NOT EXISTS customers AS
SELECT DISTINCT
    customer_id,
    customer_name,
    segment,
    city,
    state,
    region,
    country
FROM superstore_raw;

-- ── 1B. Create products table ───────────────────────────────
CREATE TABLE IF NOT EXISTS products AS
SELECT DISTINCT
    product_id,
    product_name,
    category,
    sub_category
FROM superstore_raw;

-- ── 1C. Create orders table ─────────────────────────────────
CREATE TABLE IF NOT EXISTS orders AS
SELECT DISTINCT
    order_id,
    order_date,
    ship_date,
    ship_mode,
    customer_id,
    product_id,
    ROUND(sales,    2) AS sales,
    quantity,
    ROUND(discount, 2) AS discount,
    ROUND(profit,   2) AS profit
FROM superstore_raw;

-- ── Verify row counts ───────────────────────────────────────
SELECT 'superstore_raw' AS tbl, COUNT(*) AS rows FROM superstore_raw UNION ALL
SELECT 'customers',                  COUNT(*)         FROM customers         UNION ALL
SELECT 'products',                   COUNT(*)         FROM products          UNION ALL
SELECT 'orders',                     COUNT(*)         FROM orders;
/*
 Expected (approximately):
   superstore_raw  9994
   customers       793 unique customer IDs
   products        1862 unique product IDs
   orders          9993 line-item rows
*/


-- ════════════════════════════════════════════════════════════
--  STEP 2 — REQUIRED QUERIES
-- ════════════════════════════════════════════════════════════

-- ── Q1. Orders where sales > average sales  [SUBQUERY] ──────
SELECT
    o.order_id,
    c.customer_name,
    p.product_name,
    o.sales,
    ROUND((SELECT AVG(sales) FROM orders), 2) AS avg_sales
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN products  p ON o.product_id  = p.product_id
WHERE o.sales > (SELECT AVG(sales) FROM orders)
ORDER BY o.sales DESC;

/*
 INSIGHT: Average order sales = ~$229.86.
 2,983 out of 9,993 rows (≈29.8%) exceed the average —
 a classic right-skewed distribution driven by a few very
 high-value technology orders.
*/


-- ── Q2. Highest sales order for each customer  [SUBQUERY] ───
SELECT
    c.customer_name,
    o.order_id,
    o.sales AS highest_order_sales
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.sales = (
    SELECT MAX(o2.sales)
    FROM orders o2
    WHERE o2.customer_id = o.customer_id
)
GROUP BY o.customer_id
ORDER BY o.sales DESC;

/*
 INSIGHT: Sean Miller's single order (CA-2014-145317) of $22,638
 is the highest single-line sale in the entire dataset — nearly
 double the next highest value.
*/


-- ── Q3. Total sales per customer  [CTE] ─────────────────────
WITH customer_sales AS (
    SELECT
        c.customer_id,
        c.customer_name,
        c.segment,
        ROUND(SUM(o.sales), 2)        AS total_sales,
        COUNT(DISTINCT o.order_id)    AS total_orders
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_id, c.customer_name, c.segment
)
SELECT *
FROM customer_sales
ORDER BY total_sales DESC;

/*
 INSIGHT: Top customer Ken Lonsdale has $141,752 in lifetime
 sales across 12 orders, versus the median customer who totals
 around $9,000. A handful of high-value customers drive
 disproportionate revenue.
*/


-- ── Q4. Customers with above-average total sales  [CTE + SUBQUERY] ──
WITH customer_sales AS (
    SELECT
        c.customer_id,
        c.customer_name,
        c.segment,
        ROUND(SUM(o.sales), 2) AS total_sales
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_id, c.customer_name, c.segment
)
SELECT
    customer_name,
    segment,
    total_sales,
    ROUND((SELECT AVG(total_sales) FROM customer_sales), 2) AS avg_total_sales
FROM customer_sales
WHERE total_sales > (SELECT AVG(total_sales) FROM customer_sales)
ORDER BY total_sales DESC;

/*
 INSIGHT: Average customer lifetime value = $19,582.95.
 Only ~25% of customers exceed this average, confirming the
 80/20 rule: a small segment generates the majority of revenue.
*/


-- ── Q5. Rank all customers by total sales  [WINDOW FUNCTION] ─
WITH customer_sales AS (
    SELECT
        c.customer_id,
        c.customer_name,
        c.segment,
        c.region,
        ROUND(SUM(o.sales), 2) AS total_sales
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_id, c.customer_name, c.segment, c.region
)
SELECT
    customer_name,
    segment,
    region,
    total_sales,
    RANK()       OVER (ORDER BY total_sales DESC) AS sales_rank,
    DENSE_RANK() OVER (ORDER BY total_sales DESC) AS dense_rank,
    NTILE(4)     OVER (ORDER BY total_sales DESC) AS quartile
FROM customer_sales
ORDER BY sales_rank;

/*
 Window functions used:
   RANK()       — gaps after ties (1,1,3,4…)
   DENSE_RANK() — no gaps after ties (1,1,2,3…)
   NTILE(4)     — divides customers into 4 equal bands (Q1–Q4)
*/


-- ── Q6. Row numbers per order within each customer  [WINDOW + PARTITION BY] ──
SELECT
    c.customer_name,
    o.order_id,
    o.order_date,
    ROUND(o.sales, 2) AS sales,
    ROW_NUMBER() OVER (
        PARTITION BY o.customer_id
        ORDER BY     o.order_date, o.order_id
    ) AS order_sequence,
    SUM(o.sales) OVER (
        PARTITION BY o.customer_id
        ORDER BY     o.order_date, o.order_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
ORDER BY c.customer_name, order_sequence;

/*
 ROW_NUMBER() + PARTITION BY resets the counter for each customer,
 producing a per-customer order sequence (1, 2, 3 …).
 The running_total window shows cumulative spend as orders progress.
*/


-- ── Q7. Top 3 customers by total sales  [WINDOW FUNCTION] ───
WITH customer_sales AS (
    SELECT
        c.customer_id,
        c.customer_name,
        c.segment,
        ROUND(SUM(o.sales), 2)     AS total_sales,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_id, c.customer_name, c.segment
),
ranked AS (
    SELECT *,
           RANK() OVER (ORDER BY total_sales DESC) AS rnk
    FROM customer_sales
)
SELECT customer_name, segment, total_orders, total_sales, rnk AS rank
FROM ranked
WHERE rnk <= 3;

/*
 RESULT:
   1. Ken Lonsdale   Consumer    12 orders  $141,752
   2. Sanjit Engle   Consumer    11 orders  $134,304
   3. Adrian Barton  Consumer    10 orders  $130,262
*/


-- ════════════════════════════════════════════════════════════
--  STEP 3 — FINAL COMBINED QUERY
--  Customer Name | Total Sales | Rank
--  (JOIN + CTE + Window Function)
-- ════════════════════════════════════════════════════════════

WITH customer_sales AS (
    -- Aggregate sales and order count per unique customer
    SELECT
        c.customer_id,
        c.customer_name,
        c.segment,
        c.region,
        ROUND(SUM(o.sales), 2)       AS total_sales,
        COUNT(DISTINCT o.order_id)   AS total_orders,
        ROUND(AVG(o.sales), 2)       AS avg_order_value,
        ROUND(SUM(o.profit), 2)      AS total_profit
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_id, c.customer_name, c.segment, c.region
)
SELECT
    customer_name,
    segment,
    region,
    total_orders,
    avg_order_value,
    total_sales,
    total_profit,
    RANK()       OVER (ORDER BY total_sales  DESC) AS sales_rank,
    RANK()       OVER (ORDER BY total_profit DESC) AS profit_rank,
    NTILE(4)     OVER (ORDER BY total_sales  DESC) AS sales_quartile
FROM customer_sales
ORDER BY sales_rank;

/*
 This single query combines:
   JOIN         — links orders → customers
   CTE          — pre-aggregates per-customer metrics
   RANK()       — ranks by total sales AND total profit
   NTILE(4)     — segments customers into performance quartiles
*/


-- ════════════════════════════════════════════════════════════
--  MINI PROJECT — CUSTOMER SALES INSIGHTS
-- ════════════════════════════════════════════════════════════

-- ── MP-Q1. Top 5 customers ───────────────────────────────────
WITH cs AS (
    SELECT
        c.customer_name,
        c.segment,
        c.region,
        ROUND(SUM(o.sales),   2) AS total_sales,
        ROUND(SUM(o.profit),  2) AS total_profit,
        COUNT(DISTINCT o.order_id) AS orders
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_id
)
SELECT
    customer_name, segment, region, orders,
    total_sales, total_profit,
    RANK() OVER (ORDER BY total_sales DESC) AS rank
FROM cs
ORDER BY total_sales DESC
LIMIT 5;

/*
 TOP 5 CUSTOMERS (by lifetime sales):
   1. Ken Lonsdale    Consumer     $141,752  (12 orders)
   2. Sanjit Engle    Consumer     $134,304  (11 orders)
   3. Adrian Barton   Consumer     $130,262  (10 orders)
   4. Sean Miller     Home Office  $125,215  (5 orders)  ← high value/low volume
   5. Clay Ludtke     Consumer     $119,686  (12 orders)
 All top 5 are Consumer or Home Office segment.
*/


-- ── MP-Q2. Bottom 5 customers ───────────────────────────────
WITH cs AS (
    SELECT
        c.customer_name,
        c.segment,
        ROUND(SUM(o.sales),  2) AS total_sales,
        COUNT(DISTINCT o.order_id) AS orders
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_id
)
SELECT
    customer_name, segment, orders, total_sales,
    RANK() OVER (ORDER BY total_sales ASC) AS rank_from_bottom
FROM cs
ORDER BY total_sales ASC
LIMIT 5;

/*
 BOTTOM 5 CUSTOMERS:
   1. Lela Donovan    Corporate  $5.30   (1 order)
   2. Thais Sissman   Consumer   $9.67   (2 orders)
   3. Carl Jackson    Corporate  $16.52  (1 order)
   4. Mitch Gastineau Corporate  $16.74  (1 order)
   5. Roy Skaria      Home Office $44.66 (2 orders)
 All bottom customers have very few orders and no high-value purchases.
*/


-- ── MP-Q3. Customers who made exactly one order ──────────────
SELECT
    c.customer_name,
    c.segment,
    c.region,
    COUNT(DISTINCT o.order_id)   AS order_count,
    ROUND(SUM(o.sales), 2)       AS total_sales
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.customer_id
HAVING COUNT(DISTINCT o.order_id) = 1
ORDER BY total_sales DESC;

/*
 INSIGHT: 12 customers placed only a single order.
 These are candidates for a "win-back" or second-purchase campaign.
 Highest single-order value: Jenna Caffey at $1,058.
*/


-- ── MP-Q4. Customers with above-average total sales ──────────
WITH cs AS (
    SELECT
        c.customer_name,
        c.segment,
        ROUND(SUM(o.sales), 2) AS total_sales
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_id
),
avg_sales AS (
    SELECT ROUND(AVG(total_sales), 2) AS avg_val FROM cs
)
SELECT
    cs.customer_name,
    cs.segment,
    cs.total_sales,
    avg_sales.avg_val        AS avg_customer_sales,
    ROUND(cs.total_sales - avg_sales.avg_val, 2) AS above_avg_by,
    RANK() OVER (ORDER BY cs.total_sales DESC)   AS rank
FROM cs, avg_sales
WHERE cs.total_sales > avg_sales.avg_val
ORDER BY cs.total_sales DESC;

/*
 INSIGHT: Average customer lifetime sales = $19,582.95.
 Approximately 196 customers (out of 793, ~25%) exceed this
 benchmark. The top customer (Ken Lonsdale) is 7x the average.
*/


-- ── MP-Q5. Highest order value per customer ──────────────────
WITH order_totals AS (
    -- Collapse multi-item orders into one total per order
    SELECT
        o.customer_id,
        o.order_id,
        ROUND(SUM(o.sales), 2) AS order_total
    FROM orders o
    GROUP BY o.customer_id, o.order_id
),
ranked_orders AS (
    SELECT
        customer_id,
        order_id,
        order_total,
        RANK() OVER (
            PARTITION BY customer_id
            ORDER BY order_total DESC
        ) AS rn
    FROM order_totals
)
SELECT
    c.customer_name,
    c.segment,
    ro.order_id             AS best_order_id,
    ro.order_total          AS highest_order_value
FROM ranked_orders ro
JOIN customers c ON ro.customer_id = c.customer_id
WHERE ro.rn = 1
GROUP BY c.customer_id          -- de-duplicate tied top orders
ORDER BY ro.order_total DESC;

/*
 TOP 5 HIGHEST SINGLE ORDER VALUES:
   1. Sean Miller   CA-2014-145317  $23,661
   2. Tamara Chand  CA-2016-118689  $18,337
   3. Raymond Buch  CA-2017-140151  $14,052
   4. Tom Ashbrook  CA-2017-127180  $13,716
   5. Becky Martin  CA-2014-139892  $10,540
 Technology products (Copiers, Machines) dominate these large orders.
*/


-- ════════════════════════════════════════════════════════════
--  BONUS ANALYSIS QUERIES
-- ════════════════════════════════════════════════════════════

-- ── B1. Sales & profit by category and sub-category ─────────
SELECT
    p.category,
    p.sub_category,
    COUNT(DISTINCT o.order_id)     AS orders,
    SUM(o.quantity)                AS units_sold,
    ROUND(SUM(o.sales),   2)       AS total_sales,
    ROUND(SUM(o.profit),  2)       AS total_profit,
    ROUND(SUM(o.profit) / NULLIF(SUM(o.sales),0) * 100, 1) AS profit_margin_pct
FROM orders o
JOIN products p ON o.product_id = p.product_id
GROUP BY p.category, p.sub_category
ORDER BY total_sales DESC;

-- ── B2. Year-over-year sales trend ──────────────────────────
-- SQLite: strftime | MySQL: YEAR(order_date) | PG: EXTRACT(YEAR FROM...)
SELECT
    strftime('%Y', order_date)           AS year,
    COUNT(DISTINCT order_id)             AS orders,
    ROUND(SUM(sales),  2)                AS total_sales,
    ROUND(AVG(sales),  2)                AS avg_order_sales,
    ROUND(SUM(profit), 2)                AS total_profit
FROM orders
GROUP BY strftime('%Y', order_date)
ORDER BY year;

-- ── B3. Regional performance with customer count ────────────
WITH region_stats AS (
    SELECT
        c.region,
        COUNT(DISTINCT c.customer_id)    AS customer_count,
        COUNT(DISTINCT o.order_id)       AS order_count,
        ROUND(SUM(o.sales),  2)          AS total_sales,
        ROUND(SUM(o.profit), 2)          AS total_profit
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.region
)
SELECT *,
       RANK() OVER (ORDER BY total_sales DESC) AS region_rank
FROM region_stats
ORDER BY region_rank;

-- ── B4. Data quality check ───────────────────────────────────
SELECT
    'superstore_raw'  AS tbl, COUNT(*) AS rows FROM superstore_raw  UNION ALL
SELECT 'customers',           COUNT(*)         FROM customers        UNION ALL
SELECT 'products',            COUNT(*)         FROM products         UNION ALL
SELECT 'orders',              COUNT(*)         FROM orders;
