# Lesson 08: Exercise — Assignment History

A support ticketing system. Tickets get reassigned between agents. You need
to track who was assigned when the ticket was created vs when it was resolved.

---

## Step 1 — Source Tables (OLTP)

Create two tables:

**`tickets`** — current state of each ticket. Needs:
- ticket_id, title, status, priority, created_at, resolved_at, assigned_to

**`ticket_assignments`** — history of who was assigned when. Needs:
- assignment_id, ticket_id, assigned_to, assigned_by, valid_from, valid_to

```sql
CREATE TABLE tickets (
    ticket_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title         VARCHAR2(200) NOT NULL,
    status        VARCHAR2(20)  DEFAULT 'open' NOT NULL,
    priority      VARCHAR2(10)  DEFAULT 'medium' NOT NULL,
    created_at    TIMESTAMP     DEFAULT SYSTIMESTAMP,
    resolved_at   TIMESTAMP,
    assigned_to   NUMBER        NOT NULL,

    CONSTRAINT chk_ticket_status CHECK (
        status IN ('open', 'in_progress', 'resolved', 'closed')
    ),

    CONSTRAINT chk_ticket_priority CHECK (
        priority IN ('low', 'medium', 'high', 'critical')
    )
);

CREATE TABLE ticket_assignments (
    assignment_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_id     NUMBER      NOT NULL REFERENCES tickets(ticket_id),
    assigned_to   NUMBER      NOT NULL,
    assigned_by   NUMBER,
    valid_from    TIMESTAMP   NOT NULL,
    valid_to      TIMESTAMP
);

```

---

## Step 2 — Sample Data

Insert at least 5 tickets. Make sure at least one gets reassigned (different
person in `ticket_assignments` than the current `assigned_to` in `tickets`).

```sql
INSERT INTO ticket_assignments (
    ticket_id, assigned_to, assigned_by, valid_from, valid_to
) VALUES (
    1,
    1,
    10,
    TIMESTAMP '2026-05-01 09:00:00',
    TIMESTAMP '2026-05-01 15:00:00'
);

INSERT INTO ticket_assignments (
    ticket_id, assigned_to, assigned_by, valid_from, valid_to
) VALUES (
    1,
    2,
    10,
    TIMESTAMP '2026-05-01 15:00:00',
    NULL
);

-- Ticket 2
INSERT INTO ticket_assignments (
    ticket_id, assigned_to, assigned_by, valid_from, valid_to
) VALUES (
    2,
    3,
    10,
    TIMESTAMP '2026-05-03 10:00:00',
    NULL
);

-- Ticket 3
INSERT INTO ticket_assignments (
    ticket_id, assigned_to, assigned_by, valid_from, valid_to
) VALUES (
    3,
    4,
    10,
    TIMESTAMP '2026-05-04 11:00:00',
    NULL
);

-- Ticket 4
INSERT INTO ticket_assignments (
    ticket_id, assigned_to, assigned_by, valid_from, valid_to
) VALUES (
    4,
    1,
    10,
    TIMESTAMP '2026-05-06 08:30:00',
    NULL
);

-- Ticket 5
INSERT INTO ticket_assignments (
    ticket_id, assigned_to, assigned_by, valid_from, valid_to
) VALUES (
    5,
    5,
    10,
    TIMESTAMP '2026-05-07 13:00:00',
    NULL
);

COMMIT;
```

## Step 3 — Trigger

Write a trigger on `tickets` that:
- On INSERT or UPDATE of `assigned_to`, logs the change to `ticket_assignments`
- Closes the previous active assignment (sets its `valid_to`)
- Inserts a new row with `valid_from = now()` and `valid_to = NULL`

```sql
CREATE OR REPLACE TRIGGER trg_ticket_assignment_log
    AFTER INSERT OR UPDATE OF assigned_to ON tickets
    FOR EACH ROW
BEGIN

   IF INSERTING THEN

        INSERT INTO ticket_assignments (
            ticket_id,
            assigned_to,
            assigned_by,
            valid_from,
            valid_to
        )
        VALUES (
            :NEW.ticket_id,
            :NEW.assigned_to,
            NULL,
            SYSTIMESTAMP,
            NULL
        );

    ELSIF UPDATING THEN

        -- Close previous active assignment
        UPDATE ticket_assignments
           SET valid_to = SYSTIMESTAMP
         WHERE ticket_id = :OLD.ticket_id
           AND valid_to IS NULL;

        -- Insert new active assignment
        INSERT INTO ticket_assignments (
            ticket_id,
            assigned_to,
            assigned_by,
            valid_from,
            valid_to
        )
        VALUES (
            :NEW.ticket_id,
            :NEW.assigned_to,
            NULL,
            SYSTIMESTAMP,
            NULL
        );

    END IF;

END;
/
```

## Step 4 — Data Warehouse Tables (Star Schema)

Create two tables:

**`dim_agent`** — agent details. Needs: agent_key, agent_name, team

**`fact_ticket_daily`** — daily counts per agent/status/priority. Needs:
date_key, agent_key, status, priority, tickets_created, tickets_resolved

```sql
CREATE TABLE dim_agent (
    agent_key   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    agent_name  VARCHAR2(100) NOT NULL,
    team        VARCHAR2(50) NOT NULL
);

CREATE TABLE fact_ticket_daily (
    fact_key          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date_key          NUMBER NOT NULL,
    agent_key         NUMBER NOT NULL REFERENCES dim_agent(agent_key),
    status            VARCHAR2(20) NOT NULL,
    priority          VARCHAR2(10) NOT NULL,
    tickets_created   NUMBER DEFAULT 0,
    tickets_resolved  NUMBER DEFAULT 0
);
```

---

## Step 5 — Populate dim_agent

Insert 3-4 agents with their teams.

```sql
INSERT INTO dim_agent (agent_name, team)
VALUES ('Alice Johnson', 'Support');

INSERT INTO dim_agent (agent_name, team)
VALUES ('Bob Smith', 'Technical Support');

INSERT INTO dim_agent (agent_name, team)
VALUES ('Carol Davis', 'Billing');

INSERT INTO dim_agent (agent_name, team)
VALUES ('David Wilson', 'Customer Success');

COMMIT;
```

---

## Step 6 — ETL Logic (Colab)

In your Colab notebook, write pandas code that:
1. Extracts `tickets` and `ticket_assignments` from FreeSQL
2. For each ticket, finds who was assigned at `created_at` using:
   `valid_from <= created_at AND (valid_to IS NULL OR valid_to > created_at)`
3. Same for `resolved_at`
4. Groups by date, agent, status, priority and counts
5. Inserts into `fact_ticket_daily`

import pandas as pd
import oracledb

conn = oracledb.connect(
    user="YOUR_USERNAME",
    password="YOUR_PASSWORD",
    dsn="YOUR_CONNECTION_STRING"
)

tickets = pd.read_sql("""
    SELECT *
    FROM tickets
""", conn)

ticket_assignments = pd.read_sql("""
    SELECT *
    FROM ticket_assignments
""", conn)

dim_agent = pd.read_sql("""
    SELECT *
    FROM dim_agent
""", conn)

tickets["CREATED_AT"] = pd.to_datetime(tickets["CREATED_AT"])
tickets["RESOLVED_AT"] = pd.to_datetime(tickets["RESOLVED_AT"])

ticket_assignments["VALID_FROM"] = pd.to_datetime(
    ticket_assignments["VALID_FROM"]
)

ticket_assignments["VALID_TO"] = pd.to_datetime(
    ticket_assignments["VALID_TO"]
)


created_records = []

for _, ticket in tickets.iterrows():

    matches = ticket_assignments[
        (ticket_assignments["TICKET_ID"] == ticket["TICKET_ID"]) &
        (ticket_assignments["VALID_FROM"] <= ticket["CREATED_AT"]) &
        (
            ticket_assignments["VALID_TO"].isna() |
            (ticket_assignments["VALID_TO"] > ticket["CREATED_AT"])
        )
    ]

    if not matches.empty:

        assignment = matches.iloc[0]

        created_records.append({
            "date_key": int(ticket["CREATED_AT"].strftime("%Y%m%d")),
            "agent_key": assignment["ASSIGNED_TO"],
            "status": ticket["STATUS"],
            "priority": ticket["PRIORITY"],
            "tickets_created": 1,
            "tickets_resolved": 0
        })

resolved_records = []

resolved_tickets = tickets[tickets["RESOLVED_AT"].notna()]

for _, ticket in resolved_tickets.iterrows():

    matches = ticket_assignments[
        (ticket_assignments["TICKET_ID"] == ticket["TICKET_ID"]) &
        (ticket_assignments["VALID_FROM"] <= ticket["RESOLVED_AT"]) &
        (
            ticket_assignments["VALID_TO"].isna() |
            (ticket_assignments["VALID_TO"] > ticket["RESOLVED_AT"])
        )
    ]

    if not matches.empty:

        assignment = matches.iloc[0]

        resolved_records.append({
            "date_key": int(ticket["RESOLVED_AT"].strftime("%Y%m%d")),
            "agent_key": assignment["ASSIGNED_TO"],
            "status": ticket["STATUS"],
            "priority": ticket["PRIORITY"],
            "tickets_created": 0,
            "tickets_resolved": 1
        })

fact_df = pd.DataFrame(created_records + resolved_records)

fact_df = fact_df.groupby(
    ["date_key", "agent_key", "status", "priority"],
    as_index=False
).sum()

cursor = conn.cursor()

for _, row in fact_df.iterrows():

    cursor.execute("""
        INSERT INTO fact_ticket_daily (
            date_key,
            agent_key,
            status,
            priority,
            tickets_created,
            tickets_resolved
        )
        VALUES (
            :1, :2, :3, :4, :5, :6
        )
    """, (
        int(row["date_key"]),
        int(row["agent_key"]),
        row["status"],
        row["priority"],
        int(row["tickets_created"]),
        int(row["tickets_resolved"])
    ))

conn.commit()
ed and resolved per agent per day. The reassigned ticket should show
the original agent for creation and the new agent for resolution.

```sql
SELECT
    f.date_key,
    a.agent_name,
    a.team,
    f.status,
    f.priority,
    SUM(f.tickets_created)  AS tickets_created,
    SUM(f.tickets_resolved) AS tickets_resolved
FROM fact_ticket_daily f
JOIN dim_agent a
    ON f.agent_key = a.agent_key
GROUP BY
    f.date_key,
    a.agent_name,
    a.team,
    f.status,
    f.priority
ORDER BY
    f.date_key,
    a.agent_name;
print("ETL completed successfully!")

cursor.close()
conn.close()

---

## Step 7 — Verify

Write a query joining `fact_ticket_daily` and `dim_agent` to show tickets
created and resolved per agent per day. The reassigned ticket should show
the original agent for creation and the new agent for resolution.

SELECT
    f.date_key,
    a.agent_name,
    a.team,
    f.status,
    f.priority,
    SUM(f.tickets_created)  AS tickets_created,
    SUM(f.tickets_resolved) AS tickets_resolved
FROM fact_ticket_daily f
JOIN dim_agent a
    ON f.agent_key = a.agent_key
GROUP BY
    f.date_key,
    a.agent_name,
    a.team,
    f.status,
    f.priority
ORDER BY
    f.date_key,
    a.agent_name;