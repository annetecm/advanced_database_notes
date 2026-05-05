Today's Challenge
-- Lesson 05: Schema Backup & Restore
-- File 08: Class Exercises (self-contained)

-- ============================================
-- EXERCISE 1: Explore your schema
-- ============================================
-- List all the objects in your schema using user_objects
-- Group by object_type and count them
-- Which object types do you have?

-- Sample solution:
SELECT object_type, COUNT(*) AS cnt
FROM user_objects
GROUP BY object_type
ORDER BY object_type;

-- Also get details:
SELECT object_name, object_type, created, last_ddl_time
FROM user_objects
ORDER BY object_type, object_name;

-- ============================================
-- EXERCISE 2: Basic GET_DDL
-- ============================================
-- First, set transform params for clean output:
BEGIN
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'PRETTY', true);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SQLTERMINATOR', true);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SEGMENT_ATTRIBUTES', false);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE', false);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'TABLESPACE', false);
END;
/

SET LONG 100000
SET PAGESIZE 0

-- Get DDL for one of your tables (replace MY_TABLE with actual name)
SELECT DBMS_METADATA.GET_DDL('TABLE', 'MY_TABLE') FROM DUAL;

-- Or get all tables at once:
SELECT DBMS_METADATA.GET_DDL('TABLE', table_name)
FROM user_tables
ORDER BY table_name;

-- Identify the key parts in the output:
--   - Column definitions (NAME, TYPE, NULL/NOT NULL)
--   - Constraints (PRIMARY KEY, FK, CHECK)
--   - Storage parameters (if included)

-- ============================================
-- EXERCISE 3: Clean DDL for portability
-- ============================================
-- Remove schema names from DDL so it works in any schema

BEGIN
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'EMIT_SCHEMA', false);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'PRETTY', true);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SQLTERMINATOR', true);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SEGMENT_ATTRIBUTES', false);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE', false);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'TABLESPACE', false);
END;
/

-- Compare the output with and without EMIT_SCHEMA:
-- With EMIT_SCHEMA (default):   CREATE TABLE "SALES"."ORDERS" ...
-- Without EMIT_SCHEMA:          CREATE TABLE "ORDERS" ...

-- Try it yourself:
SELECT DBMS_METADATA.GET_DDL('TABLE', table_name)
FROM user_tables
WHERE ROWNUM = 1;

-- ============================================
-- EXERCISE 4: Plan a migration
-- ============================================
-- You're moving to a new schema with a different name.
-- What changes would you need to make to your exported DDL?

-- Scenario: Migrating from SCHEMA_OLD to SCHEMA_NEW

-- 1. First, identify schema names embedded in your DDL:
SELECT DBMS_METADATA.GET_DDL('TABLE', table_name)
FROM user_tables
WHERE table_name = 'ANY_TABLE_WITH_FK';

-- 2. Check for schema-qualified references:
SELECT constraint_name, table_name, r_constraint_name
FROM user_constraints
WHERE constraint_type = 'R';

-- 3. If you find FK constraints pointing to other schemas, you need to:
--    - Update the REFERENCES clause to point to new schema name
--    - Or make sure target table exists in same schema

-- 4. Write a migration checklist:
--    □ Export all DDL with EMIT_SCHEMA = false
--    □ Review FK constraints for schema references
--    □ Update constraint references if needed
--    □ Reload in order: tables → constraints → indexes → views → code

-- ============================================
-- EXERCISE 5: Dependency order
-- ============================================
-- Look at user_dependencies to understand object relationships

-- See all dependencies in your schema:
SELECT referenced_name, referencing_name, referencing_type
FROM user_dependencies
ORDER BY referenced_name;

-- Find objects that depend on TABLES (to know what needs tables first):
SELECT referencing_name, referencing_type
FROM user_dependencies
WHERE referenced_name IN (
  SELECT table_name FROM user_tables
)
ORDER BY referencing_type, referencing_name;

-- Find direct dependencies for a specific object (replace PROC_NAME):
SELECT referenced_name, referenced_type
FROM user_dependencies
WHERE referencing_name = 'PROC_NAME';

-- Build a dependency tree for PL/SQL objects:
SELECT referencing_name, referencing_type,
       LISTAGG(referenced_name, ', ') WITHIN GROUP (ORDER BY referenced_name) AS dependencies
FROM user_dependencies
WHERE referencing_type IN ('PACKAGE', 'PROCEDURE', 'FUNCTION')
GROUP BY referencing_name, referencing_type
ORDER BY referencing_type, referencing_name;

-- ============================================
-- EXERCISE 6: Design your own backup strategy
-- ============================================
-- Given:
--   - No expdp access (no directory privileges)
--   - Need to move your schema to another database
--   - Only have SQL access
--
-- Design the steps you would take:

-- STEP 1: Document your current schema structure
SELECT object_type, COUNT(*) FROM user_objects GROUP BY object_type;
SELECT table_name, num_rows FROM user_tables ORDER BY num_rows DESC;

-- STEP 2: Extract all DDL (run all these)
BEGIN
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'PRETTY', true);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SQLTERMINATOR', true);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SEGMENT_ATTRIBUTES', false);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE', false);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'TABLESPACE', false);
END;
/

-- Extract tables (spool to file or copy output):
SELECT DBMS_METADATA.GET_DDL('TABLE', table_name) FROM user_tables;

-- Extract indexes:
SELECT DBMS_METADATA.GET_DDL('INDEX', index_name) FROM user_indexes;

-- Extract views:
SELECT DBMS_METADATA.GET_DDL('VIEW', view_name) FROM user_views;

-- Extract sequences:
SELECT DBMS_METADATA.GET_DDL('SEQUENCE', sequence_name) FROM user_sequences;

-- Extract constraints:
SELECT DBMS_METADATA.GET_DDL('CONSTRAINT', constraint_name) FROM user_constraints;

-- Extract code:
SELECT DBMS_METADATA.GET_DDL('PROCEDURE', object_name) FROM user_objects WHERE object_type = 'PROCEDURE';
SELECT DBMS_METADATA.GET_DDL('FUNCTION', object_name) FROM user_objects WHERE object_type = 'FUNCTION';
SELECT DBMS_METADATA.GET_DDL('PACKAGE', object_name) FROM user_objects WHERE object_type = 'PACKAGE';

-- STEP 3: Reload in new schema (use proper order)
-- 1. Create tables (no constraints yet)
-- 2. Create sequences
-- 3. Create indexes
-- 4. Add constraints (enable FKs)
-- 5. Create views
-- 6. Create procedures/functions/packages
-- 7. Create triggers

-- STEP 4: Verify everything transferred
SELECT object_type, COUNT(*) FROM user_objects GROUP BY object_type;
SELECT table_name, num_rows FROM user_tables ORDER BY table_name;
SELECT index_name, table_name FROM user_indexes ORDER BY index_name;

-- ============================================
-- DISCUSSION QUESTIONS
-- ============================================

-- Q1: What are the limitations of DBMS_METADATA vs expdp?
-- A:  DBMS_METADATA only exports DDL (no data), requires manual spool/cursor,
--     and can't handle very large schemas easily.
--     expdp is faster, can export data, handles large schemas, but needs directory access.
--     Choose DBMS_METADATA when you have no DBA access or need educational visibility.
--     Choose expdp when you have proper access and need speed/completeness.

-- Q2: If you have circular dependencies (A depends on B, B depends on A),
--     how would you handle the reload?
-- A:  Oracle handles most circular dependencies automatically if you create
--     objects first and enable constraints later.
--     For PL/SQL circular dependencies, create the package/spec first,
--     then the package/body second.
--     DBMS_METADATA returns objects in a valid order - trust the dependency analysis.

-- Q3: Your company is migrating from one Oracle database to another.
--     They give you read-only access to the old database and want you
--     to recreate the schema on the new database.
--     What's your plan?
-- A:  1. Document source schema structure (user_objects, user_tables, etc.)
--     2. Set EMIT_SCHEMA=false and extract clean DDL
--     3. Check for dependencies and schema-qualified references
--     4. Review and clean up the DDL (remove storage, fix schema names)
--     5. Create new schema user on target
--     6. Run DDL in proper order (tables → constraints → indexes → views → code)
--     7. Verify with object counts and sample queries
--     8. If possible, export sample data via INSERT statements or CSV

-- ============================================
-- FURTHER INVESTIGATION
-- ============================================
-- The techniques in this lesson work on freesql.com with basic SQL access.
-- When you have full Oracle access (DBA, directory privileges, etc.),
-- consider these more advanced approaches:

-- 1. expdp / impdp (Data Pump)
--    The standard Oracle export/import tool.
--    Requires: CREATE ANY DIRECTORY privilege + directory object.
--    Can export schemas, tablespaces, full databases.
--    Handles data + DDL (unlike DBMS_METADATA which is DDL only).
--    Example:
--    expdp system/password@db SCHEMAS=MY_SCHEMA DIRECTORY=MY_DIR DUMPFILE=backup.dmp

-- 2. SQLcl "script" command
--    SQL Developer Command Line can export entire schema to JSON or ZIP.
--    Has a "rollling migration" feature for schema comparisons.

-- 3. Oracle SQL Developer (GUI)
--    Has "Database Export" wizard for schema backup.
--    Point-and-click, no CLI needed.

-- 4. Partitioned tables & transportable tablespaces
--    For very large schemas, Oracle's transportable tablespace
--    feature can move entire tablespaces between databases.

-- 5. Cloud-native tools (if using Oracle Cloud)
--    Oracle Cloud Infrastructure Database Migration service
--    handles full schema migration with automatic conversion.

-- Research these on your own when you have access to a full Oracle environment.
-- The DBMS_METADATA approach you learned here works everywhere — good baseline skill.v