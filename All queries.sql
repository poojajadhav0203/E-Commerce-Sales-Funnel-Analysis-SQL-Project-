
use `sql`;
show tables;
describe `sql`.customers;
describe `sql`.order_items;
describe `sql`.orders;
describe `sql`.payments;
describe `sql`.products;

-- Checking for null
SELECT * FROM customers WHERE customer_id  IS NULL;
SELECT * FROM customers WHERE customer_unique_id  IS NULL;
SELECT * FROM customers WHERE customer_zip_code_prefix  IS NULL;
SELECT * FROM customers WHERE customer_city  IS NULL;
SELECT * FROM customers WHERE customer_state IS NULL;

SELECT *
FROM order_items
WHERE order_id IS NULL
   OR order_item_id IS NULL
   OR product_id IS NULL
   OR seller_id IS NULL
   OR shipping_limit_date IS NULL
   OR price IS NULL
   OR freight_value IS NULL;
   
   SELECT *
FROM orders
WHERE order_id IS NULL
   OR customer_id IS NULL
   OR order_status IS NULL
   OR order_purchase_timestamp IS NULL
   OR order_approved_at IS NULL
   OR order_delivered_carrier_date IS NULL
   OR order_delivered_customer_date IS NULL
   OR order_estimated_delivery_date IS NULL;
   
     SELECT *
FROM payments
WHERE order_id IS NULL
   OR payment_sequential IS NULL
   OR payment_type IS NULL
   OR payment_installments IS NULL
   OR payment_value IS NULL;
   
   SELECT *
FROM products
WHERE product_id IS NULL
   OR `product category` IS NULL
   OR product_name_length IS NULL
   OR product_description_length IS NULL
   OR product_photos_qty IS NULL
   OR product_weight_g IS NULL
   OR product_length_cm IS NULL
   OR product_height_cm IS NULL
   OR product_width_cm IS NULL;
   
  -- remove duplicate
  SELECT DISTINCT * FROM customers;
  SELECT DISTINCT * FROM order_items;
  SELECT DISTINCT * FROM orders;
  SELECT DISTINCT * FROM payments;
  SELECT DISTINCT * FROM products;
  
  

  
  --- join customer + order
  WITH customer_orders AS (
  SELECT
    o.order_id,
    o.customer_id,
    o.order_purchase_timestamp,
    o.order_status,
    c.customer_city,
    c.customer_state
  FROM `orders` o
  JOIN `customers` c
    ON o.customer_id = c.customer_id
)
SELECT *
FROM customer_orders
LIMIT 10;

  

   




-- first order of customer(Customer Acquisition vs Repeat Purchase)
WITH first_orders AS (
  SELECT
    customer_id,
    MIN(order_purchase_timestamp) AS first_order_date
  FROM `orders`
  GROUP BY customer_id
),
labeled_orders AS (
  SELECT
    o.order_id,
    o.customer_id,
    o.order_purchase_timestamp,
    CASE 
      WHEN o.order_purchase_timestamp = f.first_order_date THEN 'New'
      ELSE 'Repeat'
    END AS customer_type
  FROM `orders` o
  JOIN first_orders f
    ON o.customer_id = f.customer_id
)
SELECT
  customer_type,
  COUNT(DISTINCT customer_id) AS customers,
  COUNT(order_id) AS total_orders
FROM labeled_orders
GROUP BY customer_type;



-- confirmation of order count
SELECT customer_id, COUNT(order_id) AS order_count
FROM orders
GROUP BY customer_id
ORDER BY order_count DESC
LIMIT 10;



-- Average Order Value (AOV) by Region
SELECT 
    c.customer_state AS region,
    ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN customers c 
  ON o.customer_id = c.customer_id
JOIN order_items oi 
  ON o.order_id = oi.order_id
GROUP BY c.customer_state
ORDER BY avg_order_value DESC;


---- Customer Lifetime Metrics
SELECT 
    o.customer_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(AVG(oi.price), 2) AS avg_order_value
FROM orders o
JOIN order_items oi 
  ON o.order_id = oi.order_id
GROUP BY o.customer_id
ORDER BY total_revenue DESC
LIMIT 10;


-- Cohort / Retention Analysis (Window Functions)
-- Query (Monthly Cohort Analysis)
WITH customer_first_order AS (
    SELECT 
        customer_id,
        DATE_FORMAT(MIN(order_purchase_timestamp), '%Y-%m') AS cohort_month
    FROM orders
    GROUP BY customer_id
),

customer_orders AS (
    SELECT 
        o.customer_id,
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month
    FROM orders o
)

SELECT 
    cfo.cohort_month,
    co.order_month,
    COUNT(DISTINCT co.customer_id) AS retained_customers
FROM customer_first_order cfo
JOIN customer_orders co 
  ON cfo.customer_id = co.customer_id
GROUP BY cfo.cohort_month, co.order_month
ORDER BY cfo.cohort_month, co.order_month;

SELECT COUNT(*) AS null_dates
FROM orders
WHERE order_purchase_timestamp IS NULL;

SELECT 
    DATE_FORMAT(MIN(order_purchase_timestamp), '%Y-%m') AS cohort_month,
    COUNT(DISTINCT customer_id) AS new_customers
FROM orders
GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
ORDER BY cohort_month;

-- Monthly Cohort Analysis (fixed)
WITH customer_first_order AS (
    SELECT 
        customer_id,
        DATE_FORMAT(STR_TO_DATE(MIN(order_purchase_timestamp), '%d-%m-%Y %H:%i'), '%Y-%m') AS cohort_month
    FROM orders
    GROUP BY customer_id
),

customer_orders AS (
    SELECT 
        customer_id,
        DATE_FORMAT(STR_TO_DATE(order_purchase_timestamp, '%d-%m-%Y %H:%i'), '%Y-%m') AS order_month
    FROM orders
)

SELECT 
    cfo.cohort_month,
    co.order_month,
    COUNT(DISTINCT co.customer_id) AS retained_customers
FROM customer_first_order cfo
JOIN customer_orders co ON cfo.customer_id = co.customer_id
GROUP BY cfo.cohort_month, co.order_month
ORDER BY cfo.cohort_month, co.order_month;

-- Top Products by Revenue
-- assuming each row is one item (no quantity column), just sum the price:
SELECT 
    p.product_id,
    p.`product category`,
    SUM(oi.price) AS total_revenue,
    COUNT(DISTINCT oi.order_id) AS total_orders
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_id, p.`product category`
ORDER BY total_revenue DESC
LIMIT 10;

-- payemnt type distibution
SELECT 
    payment_type,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(payment_value), 2) AS total_revenue
FROM payments
GROUP BY payment_type
ORDER BY total_revenue DESC;


-- monthly revenue trend
SELECT
    DATE_FORMAT(STR_TO_DATE(order_purchase_timestamp, '%d-%m-%Y %H:%i'), '%Y-%m') AS order_month,
    ROUND(SUM(oi.price), 2) AS monthly_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY order_month
ORDER BY order_month
LIMIT 10000;


-- High value customers by trend
SELECT
    c.customer_state AS region,
    o.customer_id,
    SUM(oi.price) AS total_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.customer_state, o.customer_id
ORDER BY total_revenue DESC
LIMIT 20;


-- find any orders without customer?
SELECT o.*
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;









 






























