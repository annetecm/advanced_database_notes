-- Lesson 07: KPI Dashboards — Class Exercises
-- File: 06_exercises.sql
-- Purpose: Practice defining KPIs, writing queries, and handling edge cases
--
-- Instructions: Open this file in your FreeSQL worksheet.
-- For each exercise, write your query below the prompt, then run it.
-- There is no "autograder" — correctness is determined by whether
-- the query matches the KPI contract YOU defined.
-- ============================================================

-- ============================================================
-- PART A: The KPI Contract (Conceptual)
-- ============================================================
-- Before writing any query, answer these for EACH exercise:
--
-- 1. What is the business question?
-- 2. What is the exact definition? (Include every filter, every join)
-- 3. What are the edge cases? (NULLs, cancelled tasks, unassigned tasks, etc.)
-- 4. What is the unit? (Count, percentage, hours, dollars?)
-- 5. What would make this metric misleading?
--
-- Write your answers as SQL comments above each query.
-- A query without a contract is just a number. A query WITH a contract
-- is a metric the business can trust.
--
-- Tom Kyte's rule: "If you cannot explain the metric to a non-technical
-- person in one sentence, your query is wrong."

-- ============================================================
-- EXERCISE 1: Define "Team Velocity"
-- ============================================================
--
-- Business context: Management wants to compare how fast each team
-- completes work. They ask for "team velocity."
--
-- YOUR TASK:
-- 1. Define the KPI contract in comments. What EXACTLY does "velocity" mean?
--    Is it tasks completed per day? Per person? Per story point?
--    (We do not have story points — how does that change the definition?)

-- Velocity is defined by average tasks completed per person, as we don't have story points we don't know the 
-- level of difficulty there is no way to proof the reason why that time was spent in each task.

-- Contract:
-- 1. What is the business question?
-- What is the team's velocity?
-- 2. What is the exact definition? (Include every filter, every join)
-- average number of completed tasks per team member
-- 3. What are the edge cases? (NULLs, cancelled tasks, unassigned tasks, etc.)
-- he Product team has fewer people than Engineering.
-- 4. What is the unit? (Count, percentage, hours, dollars?)
-- hours
-- 5. What would make this metric misleading?
-- in progress tasks

-- 2. Write a query that shows each team's velocity with your chosen definition.
SELECT
    assigned_to AS team_id,
    COUNT(*) AS completed_tasks
FROM tasks
WHERE status = 'completed'
  AND assigned_to IS NOT NULL
GROUP BY assigned_to
ORDER BY completed_tasks DESC;

-- 3. Add a column that flags teams with velocity below the overall average.
WITH velocity_stats AS (
    SELECT
        assigned_to AS team_id,
        COUNT(*) AS completed_tasks
    FROM tasks
    WHERE status = 'completed'
      AND assigned_to IS NOT NULL
    GROUP BY assigned_to
)

SELECT
    team_id,
    completed_tasks,
    CASE
        WHEN completed_tasks < AVG(completed_tasks) OVER ()
            THEN 'BELOW_AVERAGE'
        ELSE 'OK'
    END AS performance_flag
FROM velocity_stats
ORDER BY completed_tasks DESC;
-- Edge case to consider: The Product team has fewer people than Engineering.
-- Should velocity be normalized per team member? What are the pros and cons?
-- Yes, velocity should usually be normalized per team member when comparing teams of different sizes.
-- Pros:

-- Makes comparisons fair between small and large teams.
-- Shows individual productivity more accurately.
-- Prevents large teams from looking better simply because they have more people.
-- Helps identify highly efficient small teams.

-- Cons:

-- Assumes all team members contribute equally.
-- Ignores task complexity and effort.
-- Small teams can appear artificially strong with only a few completed tasks.
-- Does not account for different roles (designers, QA, backend, etc.).

-- ============================================================
-- EXERCISE 2: Define "On-Time Delivery Rate"
-- ============================================================
--
-- Business context: The product manager wants to know: "Do we meet
-- our deadlines?" They ask for an "on-time delivery rate."
--
-- ============================================================
-- EXERCISE 2: On-Time Delivery Rate
-- ============================================================

-- KPI CONTRACT:
--
-- 1. Business Question:
--    Are tasks being completed before their deadlines?
--
-- 2. Exact Definition:
--    On-time delivery rate is defined as:
--    "Percentage of completed tasks finished on or before the due date."
--
--    Rules:
--    - Only tasks with status = 'completed' are included.
--    - Tasks must have both due_date and completed_at.
--    - A task is considered on-time if:
--          completed_at <= due_date + 1 day
--      This means the team has until 23:59:59 of the due date.
--    - Results are grouped by priority.
--
-- 3. Edge Cases:
--    - Tasks with NULL due_date are excluded because no deadline exists.
--    - Tasks with NULL completed_at are excluded because they are unfinished.
--    - Cancelled tasks are excluded.
--    - A task completed at 23:59 on the due date is considered on-time.
--    - A task completed at 00:01 the next day is considered late.
--
-- 4. Unit:
--    - On-time delivery rate = percentage (%)
--    - Average lateness = hours
--
-- 5. What makes this misleading?
--    - Tasks do not have equal complexity.
--    - Teams may intentionally set unrealistic due dates.
--    - Small sample sizes per priority can distort percentages.
--    - Excluding tasks without due dates may hide planning issues.
SELECT
    priority,

    COUNT(*) AS total_completed_tasks,

    SUM(
        CASE
            WHEN completed_at < CAST(due_date + 1 AS TIMESTAMP)
            THEN 1
            ELSE 0
        END
    ) AS on_time_tasks,

    ROUND(
        (
            SUM(
                CASE
                    WHEN completed_at < CAST(due_date + 1 AS TIMESTAMP)
                    THEN 1
                    ELSE 0
                END
            ) / COUNT(*)
        ) * 100,
        2
    ) AS on_time_delivery_rate,

    ROUND(
        AVG(
            CASE
                WHEN completed_at >= CAST(due_date + 1 AS TIMESTAMP)
                THEN (
                    (CAST(completed_at AS DATE) - (due_date + 1)) * 24
                )
            END
        ),
        2
    ) AS avg_lateness_hours

FROM tasks
WHERE status = 'completed'
  AND due_date IS NOT NULL
  AND completed_at IS NOT NULL
GROUP BY priority
ORDER BY
    CASE priority
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        WHEN 'low' THEN 4
    END;

-- ============================================================
-- EXERCISE 3: Improve "Tasks per Team"
-- ============================================================

-- KPI CONTRACT:
--
-- 1. Business Question:
--    Which teams currently have the highest workload,
--    and how effectively are they completing tasks?
--
-- 2. Exact Definition:
--    - total_tasks:
--          Counts every task assigned to the team.
--
--    - active_tasks:
--          Counts only tasks with status:
--          ('open', 'in_progress', 'blocked')
--
--    - completion_rate:
--          completed tasks / total tasks
--          excluding cancelled tasks.
--
--    - health_score:
--          Overloaded     -> active_tasks > 10
--          Healthy        -> active_tasks BETWEEN 5 AND 10
--          Underutilized  -> active_tasks < 5
--
-- 3. Edge Cases:
--    - Teams with zero tasks should still appear.
--    - Cancelled tasks are excluded from completion_rate.
--    - Division by zero is prevented with NULLIF.
--    - NULL task assignments are ignored.
--
-- 4. Unit:
--    - total_tasks = count
--    - active_tasks = count
--    - completion_rate = percentage (%)
--
-- 5. What makes this misleading?
--    - Tasks vary in complexity.
--    - A team with many small tasks may appear overloaded.
--    - Completion rate does not measure task quality.

SELECT
    t.name AS team_name,

    COUNT(ts.id) AS total_tasks,

    SUM(
        CASE
            WHEN ts.status IN ('open', 'in_progress', 'blocked')
            THEN 1
            ELSE 0
        END
    ) AS active_tasks,

    ROUND(
        (
            SUM(
                CASE
                    WHEN ts.status = 'completed'
                    THEN 1
                    ELSE 0
                END
            ) * 100
        ) /
        NULLIF(
            SUM(
                CASE
                    WHEN ts.status <> 'cancelled'
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ),
        2
    ) AS completion_rate,

    CASE
        WHEN SUM(
            CASE
                WHEN ts.status IN ('open', 'in_progress', 'blocked')
                THEN 1
                ELSE 0
            END
        ) > 10
        THEN 'Overloaded'

        WHEN SUM(
            CASE
                WHEN ts.status IN ('open', 'in_progress', 'blocked')
                THEN 1
                ELSE 0
            END
        ) BETWEEN 5 AND 10
        THEN 'Healthy'

        ELSE 'Underutilized'
    END AS health_score

FROM teams t
LEFT JOIN users u
    ON u.team_id = t.id
LEFT JOIN tasks ts
    ON ts.assigned_to = u.id

GROUP BY t.id, t.name

ORDER BY active_tasks DESC;

-- ============================================================
-- EXERCISE 4: Improve "Average Resolution Time"
-- ============================================================

-- KPI CONTRACT:
--
-- 1. Business Question:
--    How quickly are tasks resolved for each priority level,
--    and are teams meeting SLA expectations?
--
-- 2. Exact Definition:
--    Resolution time =
--        completed_at - created_at
--
--    Measured in hours.
--
--    Only tasks where:
--        status = 'completed'
--        AND completed_at IS NOT NULL
--
--    Metrics are grouped by priority.
--
--    SLA Targets:
--        critical = 24 hours
--        high     = 72 hours
--        medium   = 168 hours
--        low      = 336 hours
--
-- 3. Edge Cases:
--    - Priorities with only 1 completed task may not produce
--      statistically meaningful averages.
--    - NULL completed_at tasks are excluded.
--    - Different task complexities affect fairness.
--
-- 4. Unit:
--    Hours
--
-- 5. What makes this misleading?
--    - Small sample sizes.
--    - Large outliers can distort averages.
--    - Some priorities naturally require more work.

WITH resolution_data AS (
    SELECT
        priority,

        (
            EXTRACT(DAY FROM (completed_at - created_at)) * 24 +
            EXTRACT(HOUR FROM (completed_at - created_at)) +
            EXTRACT(MINUTE FROM (completed_at - created_at)) / 60
        ) AS resolution_hours

    FROM tasks
    WHERE status = 'completed'
      AND completed_at IS NOT NULL
)

SELECT
    priority,

    COUNT(*) AS completed_task_count,

    ROUND(AVG(resolution_hours), 2) AS avg_resolution_hours,

    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY resolution_hours),
        2
    ) AS median_resolution_hours,

    ROUND(MIN(resolution_hours), 2) AS fastest_resolution_hours,

    ROUND(MAX(resolution_hours), 2) AS slowest_resolution_hours,

    CASE
        WHEN priority = 'critical'
             AND AVG(resolution_hours) <= 24
        THEN 'Target Met'

        WHEN priority = 'high'
             AND AVG(resolution_hours) <= 72
        THEN 'Target Met'

        WHEN priority = 'medium'
             AND AVG(resolution_hours) <= 168
        THEN 'Target Met'

        WHEN priority = 'low'
             AND AVG(resolution_hours) <= 336
        THEN 'Target Met'

        ELSE 'Target Missed'
    END AS target_met

FROM resolution_data

GROUP BY priority

ORDER BY
    CASE priority
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        WHEN 'low' THEN 4
    END;

-- ============================================================
-- EXERCISE 5: Improve "Overdue Tasks"
-- ============================================================

-- KPI CONTRACT:
--
-- 1. Business Question:
--    Which overdue tasks represent the highest operational risk,
--    who owns them, and how severe is the delay?
--
-- 2. Exact Definition:
--    A task is overdue when:
--        due_date < TRUNC(SYSDATE)
--
--    AND status NOT IN ('completed', 'cancelled')
--
--    days_overdue =
--        TRUNC(SYSDATE) - due_date
--
--    Severity Rules:
--        CRITICAL -> priority = 'critical' AND days_overdue > 0
--        HIGH     -> priority = 'high'     AND days_overdue > 2
--        MEDIUM   -> priority = 'medium'   AND days_overdue > 5
--        LOW      -> all other overdue tasks
--
-- 3. Edge Cases:
--    - Tasks with NULL due_date are excluded.
--    - Tasks due today are not overdue.
--    - Completed and cancelled tasks are excluded.
--    - Severity depends on both priority and lateness.
--
-- 4. Unit:
--    - days_overdue = days
--    - overdue_count = count
--
-- 5. What makes this misleading?
--    - Tasks vary in complexity and business impact.
--    - Some overdue tasks may already be deprioritized.
--    - Missing due dates hide planning problems.

WITH overdue_tasks AS (
    SELECT
        ts.title,
        u.username AS assignee,
        t.name AS team,
        ts.priority,
        ts.due_date,

        TRUNC(SYSDATE) - ts.due_date AS days_overdue,

        CASE
            WHEN ts.priority = 'critical'
                 AND (TRUNC(SYSDATE) - ts.due_date) > 0
            THEN 'CRITICAL'

            WHEN ts.priority = 'high'
                 AND (TRUNC(SYSDATE) - ts.due_date) > 2
            THEN 'HIGH'

            WHEN ts.priority = 'medium'
                 AND (TRUNC(SYSDATE) - ts.due_date) > 5
            THEN 'MEDIUM'

            ELSE 'LOW'
        END AS severity

    FROM tasks ts
    LEFT JOIN users u
        ON ts.assigned_to = u.id
    LEFT JOIN teams t
        ON u.team_id = t.id

    WHERE ts.due_date < TRUNC(SYSDATE)
      AND ts.status NOT IN ('completed', 'cancelled')
      AND ts.due_date IS NOT NULL
)

SELECT *
FROM (

    SELECT
        title,
        assignee,
        team,
        priority,
        due_date,
        days_overdue,
        severity,
        NULL AS overdue_count,
        NULL AS avg_days_overdue
    FROM overdue_tasks

    UNION ALL

    SELECT
        'SUMMARY' AS title,
        NULL AS assignee,
        NULL AS team,
        NULL AS priority,
        NULL AS due_date,
        NULL AS days_overdue,
        severity,
        COUNT(*) AS overdue_count,
        ROUND(AVG(days_overdue), 2) AS avg_days_overdue
    FROM overdue_tasks
    GROUP BY severity
)

ORDER BY
    CASE severity
        WHEN 'CRITICAL' THEN 1
        WHEN 'HIGH' THEN 2
        WHEN 'MEDIUM' THEN 3
        WHEN 'LOW' THEN 4
    END,
    days_overdue DESC NULLS LAST;
-- ============================================================
-- EXERCISE 6: Fix the "Productivity Score"
-- ============================================================

-- PROBLEM:
-- The original KPI is misleading because it counts all assigned tasks,
-- including unfinished work, and ignores task priority and complexity.
-- A user with many open tasks may appear more productive than someone
-- who completed fewer but higher-impact tasks.
--
-- BETTER KPI:
-- "Weighted completed tasks per active work day."

SELECT
    u.username,

    COUNT(ts.id) AS completed_tasks,

    SUM(
        CASE
            WHEN ts.priority = 'critical' THEN 4
            WHEN ts.priority = 'high' THEN 3
            WHEN ts.priority = 'medium' THEN 2
            WHEN ts.priority = 'low' THEN 1
            ELSE 0
        END
    ) AS weighted_score,

    COUNT(DISTINCT ts.completed_at) AS active_days,

    ROUND(
        SUM(
            CASE
                WHEN ts.priority = 'critical' THEN 4
                WHEN ts.priority = 'high' THEN 3
                WHEN ts.priority = 'medium' THEN 2
                WHEN ts.priority = 'low' THEN 1
                ELSE 0
            END
        ) * 1.0 /
        COUNT(DISTINCT ts.completed_at),
        2
    ) AS productivity_per_day

FROM users u
JOIN tasks ts
    ON ts.assigned_to = u.id

WHERE ts.status = 'completed'
  AND ts.completed_at IS NOT NULL

GROUP BY u.username

ORDER BY productivity_per_day DESC;

-- ============================================================
-- EXERCISE 7: Fix the "Team Efficiency"
-- ============================================================

-- PROBLEM:
-- The original KPI is mathematically meaningless because
-- averaging task IDs does not measure performance or efficiency.
--
-- Task IDs are arbitrary identifiers generated by the database.
-- A higher or lower average task ID says nothing about:
--    - productivity
--    - completion speed
--    - workload
--    - quality
--
-- BETTER KPI:
-- "Completed task ratio per team."
--
-- Efficiency =
--    completed tasks / total non-cancelled tasks
--
-- This measures how effectively teams finish assigned work.

SELECT
    t.name AS team_name,

    COUNT(ts.id) AS total_tasks,

    SUM(
        CASE
            WHEN ts.status = 'completed'
            THEN 1
            ELSE 0
        END
    ) AS completed_tasks,

    ROUND(
        (
            SUM(
                CASE
                    WHEN ts.status = 'completed'
                    THEN 1
                    ELSE 0
                END
            ) * 100
        ) /
        NULLIF(
            SUM(
                CASE
                    WHEN ts.status <> 'cancelled'
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ),
        2
    ) AS efficiency_rate

FROM teams t
JOIN users u
    ON u.team_id = t.id
JOIN tasks ts
    ON ts.assigned_to = u.id

GROUP BY t.id, t.name

ORDER BY efficiency_rate DESC;

-- ============================================================
-- EXERCISE 8: Fix the "Urgency Index"
-- ============================================================

-- PROBLEM:
-- The original query is invalid because:
--
-- 1. priority is a VARCHAR, not a numeric value.
--    You cannot multiply text by 10.
--
-- 2. due_date is a DATE datatype.
--    Adding numbers directly to dates without a clear business
--    definition creates meaningless results.
--
-- 3. The KPI has no real interpretation.
--    A valid urgency metric should combine:
--       - business importance (priority)
--       - time pressure (days until due)
--
-- BETTER KPI:
-- "Urgency Score"
--
-- Priority Weights:
--    critical = 4
--    high     = 3
--    medium   = 2
--    low      = 1
--
-- Formula:
--    urgency_score =
--        (priority_weight * 10) - days_until_due
--
-- Result:
--    Higher score = more urgent
--    Overdue tasks naturally receive higher urgency.

SELECT
    title,
    priority,
    due_date,

    TRUNC(due_date) - TRUNC(SYSDATE) AS days_until_due,

    CASE
        WHEN priority = 'critical' THEN 4
        WHEN priority = 'high' THEN 3
        WHEN priority = 'medium' THEN 2
        WHEN priority = 'low' THEN 1
        ELSE 0
    END AS priority_weight,

    (
        (
            CASE
                WHEN priority = 'critical' THEN 4
                WHEN priority = 'high' THEN 3
                WHEN priority = 'medium' THEN 2
                WHEN priority = 'low' THEN 1
                ELSE 0
            END
        ) * 10
    )
    -
    (TRUNC(due_date) - TRUNC(SYSDATE))
    AS urgency_score

FROM tasks

WHERE due_date IS NOT NULL
  AND status NOT IN ('completed', 'cancelled')

ORDER BY urgency_score DESC;

-- ============================================================
-- PART D: Bonus — Summary Dashboard Query
-- ============================================================

WITH base AS (

    SELECT
        ts.id,
        ts.title,
        ts.status,
        ts.priority,
        ts.created_at,
        ts.completed_at,
        ts.due_date,

        u.username,
        t.name AS team_name,

        CASE
            WHEN ts.status IN ('open', 'in_progress', 'blocked')
            THEN 1
            ELSE 0
        END AS is_active,

        CASE
            WHEN ts.status = 'completed'
            THEN 1
            ELSE 0
        END AS is_completed,

        CASE
            WHEN ts.due_date < TRUNC(SYSDATE)
                 AND ts.status NOT IN ('completed', 'cancelled')
            THEN 1
            ELSE 0
        END AS is_overdue,

        CASE
            WHEN ts.due_date < TRUNC(SYSDATE)
                 AND ts.status NOT IN ('completed', 'cancelled')
            THEN TRUNC(SYSDATE) - ts.due_date
        END AS days_overdue,

        CASE
            WHEN ts.status = 'completed'
                 AND ts.completed_at IS NOT NULL
            THEN
                (
                    EXTRACT(DAY FROM (ts.completed_at - ts.created_at)) * 24 +
                    EXTRACT(HOUR FROM (ts.completed_at - ts.created_at)) +
                    EXTRACT(MINUTE FROM (ts.completed_at - ts.created_at)) / 60
                )
        END AS resolution_hours

    FROM tasks ts
    LEFT JOIN users u
        ON ts.assigned_to = u.id
    LEFT JOIN teams t
        ON u.team_id = t.id
),

priority_rank AS (

    SELECT *
    FROM (
        SELECT
            priority,
            COUNT(*) AS active_count,
            ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS rn
        FROM base
        WHERE is_active = 1
        GROUP BY priority
    )
    WHERE rn = 1
),

team_rank AS (

    SELECT *
    FROM (
        SELECT
            team_name,
            COUNT(*) AS active_count,
            ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS rn
        FROM base
        WHERE is_active = 1
        GROUP BY team_name
    )
    WHERE rn = 1
)

SELECT
    COUNT(*) AS total_tasks,

    SUM(is_completed) AS completed_tasks,

    SUM(is_active) AS active_tasks,

    SUM(is_overdue) AS overdue_tasks,

    ROUND(
        (SUM(is_completed) * 100) / NULLIF(COUNT(*), 0),
        2
    ) AS completion_rate_pct,

    ROUND(AVG(resolution_hours), 2) AS avg_resolution_hours,

    ROUND(AVG(days_overdue), 2) AS avg_days_overdue,

    MAX((SELECT priority FROM priority_rank)) AS most_common_priority,

    MAX((SELECT team_name FROM team_rank)) AS busiest_team

FROM base;