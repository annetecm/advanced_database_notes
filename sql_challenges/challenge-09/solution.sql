-- Today's Challenge
-- Lesson 04: Setup
-- Create a simple accounts table for the transfer demo

DROP TABLE accounts PURGE;

CREATE TABLE accounts (
    account_id   NUMBER PRIMARY KEY,
    owner_name   VARCHAR2(50) NOT NULL,
    balance      NUMBER(10,2) NOT NULL CHECK (balance >= 0)
);

INSERT INTO accounts VALUES (1, 'Alice',  1000.00);
INSERT INTO accounts VALUES (2, 'Bob',     500.00);
INSERT INTO accounts VALUES (3, 'Charlie', 250.00);
COMMIT;

-- Verify starting state
SELECT account_id, owner_name, balance FROM accounts ORDER BY account_id;
-- Expected: Alice=1000, Bob=500, Charlie=250
 

-- Lesson 04: Class Exercises
-- Students: work through these in order. Don't skip the verify steps.

-- ============================================================
-- EXERCISE 1: Manual transaction (warm-up)
-- ============================================================
-- Transfer $50 from Charlie (3) to Alice (1) using BEGIN / COMMIT manually.
-- Before: verify balances. After COMMIT: verify again.

-- Your SQL here:
-- Subtract $50 from Charlie (account 3)
UPDATE accounts
SET balance = balance - 50
WHERE account_id = 3;

-- Add $50 to Alice (account 1)
UPDATE accounts
SET balance = balance + 50
WHERE account_id = 1;

COMMIT;

SELECT account_id, owner_name, balance 
FROM accounts 
ORDER BY account_id;

-- Alice: 1050
-- Bob: 500
-- Charlie: 200

ROLLBACK;

-- ============================================================
-- EXERCISE 2: Catch yourself with ROLLBACK
-- ============================================================
-- Start a transfer of $10,000 from Bob (2) to Charlie (3).
-- Before committing, check the balances. Does Bob have enough?
-- Use ROLLBACK to undo. Verify balances restored.

-- Your SQL here:
-- Subtract from Bob (account 2)
UPDATE accounts
SET balance = balance - 10000
WHERE account_id = 2;

-- Add to Charlie (account 3)
UPDATE accounts
SET balance = balance + 10000
WHERE account_id = 3;

SELECT account_id, owner_name, balance 
FROM accounts 
ORDER BY account_id;

-- Alice: 1050
-- Bob: 500
-- Charlie: 10200

ROLLBACK;

SELECT account_id, owner_name, balance 
FROM accounts 
ORDER BY account_id;

-- Alice: 1050
-- Bob: 500
-- Charlie: 200
 

-- ============================================================
-- EXERCISE 3: SAVEPOINT checkpoint
-- ============================================================
-- You need to:
-- 1. Add $25 to Alice's balance
-- 2. Set a savepoint
-- 3. Deduct $25 from Charlie's balance (wrong account — you meant Bob)
-- 4. Rollback to savepoint
-- 5. Deduct $25 from Bob's balance instead
-- 6. Commit

-- Your SQL here:
UPDATE accounts
SET balance = balance + 25
WHERE account_id = 1;

SAVEPOINT after_alice_update;

UPDATE accounts
SET balance = balance - 25
WHERE account_id = 3;

ROLLBACK TO after_alice_update;

UPDATE accounts
SET balance = balance - 25
WHERE account_id = 2;

COMMIT;

SELECT account_id, owner_name, balance 
FROM accounts 
ORDER BY account_id;

-- Alice: 1075
-- Bob: 475
-- Charlie: 200
 

-- ============================================================
-- EXERCISE 4: Write your own stored procedure
-- ============================================================
-- Create a procedure called deposit_funds(p_account_id, p_amount)
-- It should:
-- 1. Validate that p_amount > 0 (raise error if not)
-- 2. Add p_amount to the account balance
-- 3. COMMIT on success
-- 4. ROLLBACK + re-raise on any error
-- Test it with: EXEC deposit_funds(3, 75);

-- Your SQL here:

CREATE OR REPLACE PROCEDURE deposit_funds (
    p_account_id IN NUMBER,
    p_amount     IN NUMBER
)
IS
BEGIN
    -- 1. Validate amount
    IF p_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Amount must be greater than 0');
    END IF;

    -- 2. Update balance
    UPDATE accounts
    SET balance = balance + p_amount
    WHERE account_id = p_account_id;

    -- Optional: check if account exists
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Account not found');
    END IF;

    -- 3. Commit on success
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        -- 4. Rollback and re-raise error
        ROLLBACK;
        RAISE;
END;
/

EXEC deposit_funds(3, 75);

-- Charlie: 200 → 275

 

-- ============================================================
-- EXERCISE 5: Discussion
-- ============================================================
-- Answer these in words (no SQL needed):

-- Q1: You're building a patient appointment booking system.
-- A booking requires:
--   a) Reserve the time slot
--   b) Create the appointment record
--   c) Send a confirmation notification
-- Which of these should be inside the transaction? Which should be outside? Why?

-- Inside the transaction (atomic, must succeed together):

-- a) Reserve the time slot
-- b) Create the appointment record

-- These two are core data integrity operations. If one succeeds and 
-- the other fails, your system becomes inconsistent (e.g., a reserved slot with no appointment, or vice versa). 
-- They must be committed or rolled back as a unit.

-- Outside the transaction:

-- c) Send a confirmation notification

-- Notifications are side effects, not core data. If sending fails, you don’t want 
-- to undo the appointment itself. Otherwise, a temporary email/SMS outage would break your booking system.

-- Q2: Your stored procedure calls COMMIT at the end.
-- A developer calls your procedure from inside their own larger transaction.
-- What problem does this create?

-- It breaks transaction control for the caller.

-- If your procedure does a COMMIT, and someone calls it inside a larger transaction:

-- Their partial work is forced to commit early
-- They can no longer ROLLBACK everything as one unit
-- You lose atomicity across the full workflow

-- Q3: You have a function called calculate_copay() and a procedure called post_payment().
-- A colleague wants to use calculate_copay() inside a SELECT statement.
-- Can they? Can they do the same with post_payment()? Why or why not?

-- A function like calculate_copay() can be used inside a SELECT statement because it returns a value
-- and is designed to behave like an expression, meaning it can be evaluated for each row in a query. 
-- In contrast, a procedure like post_payment() cannot be used in a SELECT because it does not return a 
-- value in the same way and is intended to perform actions such as inserting or updating data. SQL 
-- queries expect expressions that produce values, not operations with side effects, which is why functions 
-- are allowed in queries but procedures must be executed separately using statements like EXEC or within a BEGIN...END block.