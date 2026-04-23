class files
-- Lesson 04: Transactions — COMMIT, ROLLBACK, SAVEPOINT

-- ============================================================
-- DEMO 1: Successful transfer with COMMIT
-- ============================================================

-- Start point
SELECT account_id, owner_name, balance FROM accounts ORDER BY account_id;

-- Transfer $200 from Alice to Bob
UPDATE accounts SET balance = balance - 200 WHERE account_id = 1;
UPDATE accounts SET balance = balance + 200 WHERE account_id = 2;

-- Verify before committing (only visible in this session)
SELECT account_id, owner_name, balance FROM accounts ORDER BY account_id;
-- Alice: 800, Bob: 700

-- Make it permanent
COMMIT;

-- Now everyone can see it
SELECT account_id, owner_name, balance FROM accounts ORDER BY account_id;


-- ============================================================
-- DEMO 2: ROLLBACK — undo everything
-- ============================================================

-- Try to transfer $300 from Alice to Bob, then change mind
UPDATE accounts SET balance = balance - 300 WHERE account_id = 1;
UPDATE accounts SET balance = balance + 300 WHERE account_id = 2;

-- Check state (not committed yet)
SELECT account_id, owner_name, balance FROM accounts ORDER BY account_id;
-- Alice: 500, Bob: 1000

-- Undo it — ROLLBACK takes us back to the last COMMIT
ROLLBACK;

SELECT account_id, owner_name, balance FROM accounts ORDER BY account_id;
-- Alice: 800, Bob: 700 — back to post-COMMIT state


-- ============================================================
-- DEMO 3: SAVEPOINT — partial rollback
-- ============================================================

-- Multi-step workflow: update Alice, set a savepoint, update Bob, decide to undo only Bob
UPDATE accounts SET balance = balance - 100 WHERE account_id = 1;

SAVEPOINT after_alice;

UPDATE accounts SET balance = balance + 100 WHERE account_id = 3;  -- Charlie, not Bob

-- Actually no — wrong account. Roll back to savepoint, not the beginning.
ROLLBACK TO SAVEPOINT after_alice;

-- Alice's change is still pending, Charlie's is undone
SELECT account_id, owner_name, balance FROM accounts ORDER BY account_id;
-- Alice: 700 (pending), Bob: 700, Charlie: 250 (restored)

-- Now do the right update
UPDATE accounts SET balance = balance + 100 WHERE account_id = 2;

SELECT account_id, owner_name, balance FROM accounts ORDER BY account_id;
-- Alice: 700, Bob: 800, Charlie: 250

COMMIT;

 

 

-- Lesson 04: Stored Procedures — Package the Logic in the Database

-- ============================================================
-- PART 1: Create the stored procedure
-- ============================================================

CREATE OR REPLACE PROCEDURE transfer_funds(
    p_from_account  IN  NUMBER,
    p_to_account    IN  NUMBER,
    p_amount        IN  NUMBER
) AS
    v_from_balance  NUMBER;
BEGIN
    -- Check sufficient funds before doing anything
    SELECT balance INTO v_from_balance
    FROM accounts
    WHERE account_id = p_from_account;

    IF v_from_balance < p_amount THEN
        RAISE_APPLICATION_ERROR(-20001, 'Insufficient funds in account ' || p_from_account);
    END IF;

    -- Perform the transfer
    UPDATE accounts SET balance = balance - p_amount WHERE account_id = p_from_account;
    UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_to_account;

    -- Commit only if both succeed
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Transfer complete: $' || p_amount ||
                         ' from account ' || p_from_account ||
                         ' to account ' || p_to_account);
EXCEPTION
    WHEN OTHERS THEN
        -- Something went wrong — undo everything
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Transfer failed. All changes rolled back.');
        RAISE;  -- re-raise the error so the caller knows it failed
END;
/


-- ============================================================
-- PART 2: Call the procedure
-- ============================================================

-- Check starting state
SELECT account_id, owner_name, balance FROM accounts ORDER BY account_id;

-- Transfer $100 from Alice (1) to Bob (2)
SET SERVEROUTPUT ON;
EXEC transfer_funds(1, 2, 100);

-- Verify
SELECT account_id, owner_name, balance FROM accounts ORDER BY account_id;


-- ============================================================
-- PART 3: What happens with insufficient funds?
-- ============================================================

-- Try to transfer more than Alice has
EXEC transfer_funds(1, 2, 99999);
-- Expected: error, ROLLBACK triggered, no change

SELECT account_id, owner_name, balance FROM accounts ORDER BY account_id;
-- Balances unchanged


-- ============================================================
-- PART 4: Stored procedure vs function — side by side
-- ============================================================

-- PROCEDURE: does something, can use COMMIT/ROLLBACK
-- Use when: inserting data, updating state, complex multi-step operations
-- Called with: EXEC or CALL — cannot use in SELECT

-- FUNCTION: returns a value, no COMMIT/ROLLBACK
-- Use when: calculations, data transformation
-- Can use in: SELECT, WHERE, HAVING

-- Example function (contrast)
CREATE OR REPLACE FUNCTION get_balance(p_account_id IN NUMBER) RETURN NUMBER AS
    v_balance NUMBER;
BEGIN
    SELECT balance INTO v_balance FROM accounts WHERE account_id = p_account_id;
    RETURN v_balance;
END;
/

-- Function used directly in SELECT
SELECT account_id, owner_name, get_balance(account_id) AS current_balance
FROM accounts;

-- Procedure: CANNOT do this:
-- SELECT transfer_funds(1, 2, 100) FROM dual;  -- ERROR