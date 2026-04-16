-- ============================================================
-- Exercise 1 — Find the slow query
--
-- Run this query. Look at the execution plan.
-- Is Oracle using an index? Should it?
-- ============================================================

EXPLAIN PLAN FOR
SELECT * FROM patient_visits WHERE site_id = 3;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Questions:
-- a) What scan type do you see? Why?

-- The execution plan shows a TABLE ACCESS FULL, meaning Oracle performs a full table scan. 
-- This happens because either there is no index on site_id, or the optimizer estimates that a large percentage of rows match the condition (site_id = 3), 
-- making a full scan more efficient than using an index. Additionally, since the query uses SELECT *, 
-- Oracle may prefer a full scan to avoid extra table lookups.

-- b) site_id has values 1–5. Is this high or low cardinality?

-- Low cardinality

-- c) Would adding an index on site_id help? Why or why not?
-- Adding an index on site_id would likely not help much, because the column has low cardinality, 
-- meaning each value matches many rows. As a result, Oracle may still prefer a full table scan instead of using the index.

-- ============================================================
-- Exercise 2 — Create an index and see if it helps
--
-- Create an index on visit_date.
-- Then run the range query below and check the plan.
-- ============================================================

-- Step 1: Create it
CREATE INDEX excer2
ON patient_visits (visit_date);

-- Step 2
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'PATIENT_VISITS', cascade => TRUE);
END;

-- Step 3: Run the range query and check the plan
EXPLAIN PLAN FOR
SELECT * FROM patient_visits
WHERE visit_date BETWEEN SYSDATE - 30 AND SYSDATE;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Questions:
-- a) Does Oracle use the index for this range?
-- Yes

-- b) Change the range to the last 7 days. Does the plan change?
-- No

-- c) Change to the last 700 days. What happens?
-- Nothing

-- d) Why does the range size affect whether Oracle uses the index?
-- Because the amount of rows we have is a lot so it is not noticeable for Oracle

-- ============================================================
-- Exercise 3 — Composite index
--
-- You often query by both patient_id AND visit_date together:
--   WHERE patient_id = 1234 AND visit_date > SYSDATE - 90
--
-- Two options:
--   Option A: Two separate indexes (one per column)
--   Option B: One composite index (patient_id, visit_date)
--
-- Create the composite index and test the query.
-- ============================================================

CREATE INDEX idx_pv_patient_date ON patient_visits(patient_id, visit_date);

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'PATIENT_VISITS', cascade => TRUE);
END;

EXPLAIN PLAN FOR
SELECT * FROM patient_visits
WHERE patient_id = 1234
  AND visit_date > SYSDATE - 90;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Questions:
-- a) Does the plan use the composite index?
-- Yes, the execution plan should use the composite index idx_pv_patient_date

-- b) Now try querying ONLY on visit_date (no patient_id).
--    Does the composite index get used? Why not?
-- No, the composite index is typically not used when querying only by visit_date

-- c) What's the rule about column order in composite indexes?
-- In a composite index, the order of columns matters,
-- and Oracle can only efficiently use the index starting from the leftmost (leading) column.

-- ============================================================
-- Exercise 4 — Function that breaks an index
--
-- There IS an index on patient_id (from lesson 03).
-- Predict what happens when you wrap the column in a function.
-- ============================================================

-- This query CAN use the index:
EXPLAIN PLAN FOR
SELECT * FROM patient_visits WHERE patient_id = 5432;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- This one cannot — why?
EXPLAIN PLAN FOR
SELECT * FROM patient_visits WHERE TO_CHAR(patient_id) = '5432';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Questions:
-- a) What scan type did the second query use?
-- The second query uses a TABLE ACCESS FULL.

-- b) Why does wrapping a column in a function break index use?
-- Wrapping a column in a function breaks index usage because the index is built on the original column values, 
-- not on the result of the function. When a function is applied, Oracle must compute the function for every row, 
-- which prevents it from using the index efficiently.

-- c) How would you rewrite the second query to allow index use?
-- Remove the function from the column so Oracle can use the index.

-- ============================================================
-- Exercise 5 — Discussion: real-world scenarios
--
-- For each scenario below, decide:
--   a) Would you add an index?
--   b) On which column(s)?
--   c) Any concerns?
-- ============================================================
--Scenario A

-- a) Would you add an index?
--  Yes

-- b) On which column(s)?
--  visit_date (or whatever the date column is)

-- c) Any concerns?

-- Slight overhead during nightly load (but acceptable)
-- Index size on a large table

-- Scenario B

-- a) Would you add an index?
-- Yes, but carefully

-- b) On which column(s)?

-- Index on customer_id
-- Avoid (or reconsider) index on order_status

-- c) Any concerns?

-- High insert rate → indexes slow down writes
-- Too many indexes = performance degradation

-- Scenario C

-- a) Would you add an index?
-- Yes

-- b) On which column(s)?
-- email

-- c) What kind of index?
-- Unique index