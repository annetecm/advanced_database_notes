- OLTP

Characteristics:

Many small queries (INSERT, UPDATE, DELETE)
Fast response time
Used in applications like banking, e-commerce, and reservations
Focuses on real-time data

Example:

INSERT INTO orders (customer_id, amount)
VALUES (101, 250);

- OLAP

Characteristics:

Complex queries with aggregations
Used for reporting, dashboards, and business intelligence
Focuses on historical and summarized data
Optimized for reading and analysis

Example:

SELECT region, SUM(sales) AS total_sales
FROM sales_data
GROUP BY region;