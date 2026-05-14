# Lesson Exercises

---

# Exercise 1 — Model Design (10 min)

## Scenario

Your task system needs a `comments` table.

Each comment belongs to:
- one task
- one user

CREATE TABLE comments (
    id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    task_id     NUMBER NOT NULL,
    user_id     NUMBER NOT NULL,
    content     VARCHAR2(1000) NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_comments_task
        FOREIGN KEY (task_id) REFERENCES tasks(id),

    CONSTRAINT fk_comments_user
        FOREIGN KEY (user_id) REFERENCES users(id)
);

---

## Task

Create a new Colab cell and write the `Comment` model.

### Required Fields

- `id`
- `task_id`
- `user_id`
- `content`
- `created_at`

class Comment:
    def __init__(self, id, task_id, user_id, content, created_at):
        self.id = id
        self.task_id = task_id
        self.user_id = user_id
        self.content = content
        self.created_at = created_at

    def __repr__(self):
        return (
            f"Comment(id={self.id}, task_id={self.task_id}, "
            f"user_id={self.user_id}, content='{self.content}', "
            f"created_at='{self.created_at}')"
        )

---

## Questions

1. What relationships should `Comment` have?
- A relationship to Task because each comment belongs to one task.
- A relationship to User because each comment is written by one user.
2. Should `Task` have a `comments` relationship?
- Yes
3. What should happen to comments when a task is deleted?
- its comments should also be deleted

---

# Exercise 2 — Migration Creation (10 min)

## Scenario

You added the `Comment` model.

Now generate a migration programmatically.

---

## Task

Run:

```python
command.revision(
    alembic_cfg,
    autogenerate=True,
    message="add comments table"
)
```

---

## Then Inspect the Migration

```python
import glob

migration_files = sorted(
    glob.glob('/content/project/alembic/versions/*.py')
)

for f in migration_files:
    print(f)
```

---

## Open the Generated Migration

```python
latest = migration_files[-1]

with open(latest) as f:
    print(f.read())
```

---

## Questions

1. What does `upgrade()` do?

- upgrade() applies the migration changes to the database.

- In this case, it will:

- Create the comments table
- Add all columns (id, task_id, user_id, content, created_at)
- Add foreign key constraints to tasks and users

2. What does `downgrade()` do?

- downgrade() reverses the migration changes

3. What happens if you downgrade this migration?

- The comments table will be deleted
- All comment records stored in that table will be lost
- The database schema returns to the state before the migration was applied
---

# Exercise 3 — CRUD Challenge (10 min)

## Scenario

Write a script that:

1. Creates a team called `"DevOps"`
2. Creates a user `"diana_ops"`
3. Creates 3 tasks with different priorities
4. Prints task count
5. Closes one task
6. Deletes the lowest priority task

---

## Requirements

- Use ORM only
- Use relationships
- Print output clearly

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Assume Team, User, and Task models already exist

# ============================================================
# Database Setup
# ============================================================

DATABASE_URL = "sqlite:///project.db"  # change if needed

engine = create_engine(DATABASE_URL)
Session = sessionmaker(bind=engine)
session = Session()

# ============================================================
# 1. Create Team
# ============================================================

devops_team = Team(
    name="DevOps",
    description="Infrastructure and deployment team"
)

session.add(devops_team)
session.commit()

print("=== TEAM CREATED ===")
print(f"Team: {devops_team.name}")
print()

# ============================================================
# 2. Create User
# ============================================================

diana = User(
    username="diana_ops",
    email="diana@example.com",
    full_name="Diana Ops",
    team=devops_team   # relationship usage
)

session.add(diana)
session.commit()

print("=== USER CREATED ===")
print(f"Username: {diana.username}")
print(f"Team: {diana.team.name}")
print()

# ============================================================
# 3. Create 3 Tasks with Different Priorities
# ============================================================

task1 = Task(
    title="Configure CI/CD",
    description="Set up GitHub Actions pipeline",
    priority="high",
    status="open",
    assigned_user=diana
)

task2 = Task(
    title="Monitor Servers",
    description="Install Prometheus monitoring",
    priority="medium",
    status="open",
    assigned_user=diana
)

task3 = Task(
    title="Clean Old Logs",
    description="Remove unused log files",
    priority="low",
    status="open",
    assigned_user=diana
)

session.add_all([task1, task2, task3])
session.commit()

print("=== TASKS CREATED ===")
for task in diana.tasks:
    print(f"- {task.title} | Priority: {task.priority} | Status: {task.status}")

print()

# ============================================================
# 4. Print Task Count
# ============================================================

task_count = len(diana.tasks)

print("=== TASK COUNT ===")
print(f"{diana.username} has {task_count} tasks")
print()

# ============================================================
# 5. Close One Task
# ============================================================

task1.status = "closed"

session.commit()

print("=== TASK CLOSED ===")
print(f"Task '{task1.title}' status changed to: {task1.status}")
print()

# ============================================================
# 6. Delete Lowest Priority Task
# ============================================================

lowest_priority_task = task3

session.delete(lowest_priority_task)
session.commit()

print("=== TASK DELETED ===")
print(f"Deleted task: {lowest_priority_task.title}")
print()

# ============================================================
# Final Task List
# ============================================================

print("=== REMAINING TASKS ===")

remaining_tasks = session.query(Task).filter(
    Task.assigned_to == diana.id
).all()

for task in remaining_tasks:
    print(f"- {task.title} | Priority: {task.priority} | Status: {task.status}")

---

# Exercise 4 — Migration Rollback (5 min)

## Scenario

You added a bad column:
`estimated_hours`

The migration has already been applied.

---

## Task

Rollback the migration programmatically.

### Example

```python
command.downgrade(alembic_cfg, "-1")
```

---

## Questions

1. What happens to the column?

- the column disappears from the database schema.

2. What happens to the data?
- All data stored in estimated_hours is lost
---

# Exercise 5 — Concept Check (5 min)

Answer briefly:

1. Why use ORM instead of raw SQL?

ORM lets you work with Python objects instead of writing SQL manually.
It makes code cleaner, easier to maintain, and more portable across databases.

2. Why use migrations?

Migrations track and manage database schema changes safely over time.
They help keep all environments (development, testing, production) synchronized.

3. When would you rollback?

- a migration has bugs
- a schema change breaks the application
- incorrect columns/tables were added
- you need to revert to a previous stable state

4. Difference between `add()` and `commit()`?

- add() places an object into the SQLAlchemy session.
- commit() permanently saves all pending changes to the database.

5. Why are relationships useful?
- Relationships make it easy to connect and navigate related data.
