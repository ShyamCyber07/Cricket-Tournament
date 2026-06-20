# Team Uniqueness Migration

## Problem

The original team creation behavior had a **global uniqueness constraint** on team names. This meant that if one user created a team named "CSK", no other user could create a team with the same name.

**Before:**
- User A creates "CSK" -> SUCCESS
- User B creates "CSK" -> FAILS (duplicate name globally)

This is unsuitable for a multi-user platform where users may want to create teams with common names (like IPL team names).

## Solution

Changed from **global uniqueness** to **per-user uniqueness**:

- User A can create "CSK" -> SUCCESS
- User B can create "CSK" -> SUCCESS
- User A cannot create a second "CSK" -> FAILS (duplicate for this user)

## Implementation

### 1. Database Migration

Created `backend/alembic/versions/team_uniqueness_migration.py`:

```python
def upgrade() -> None:
    # Step 1: Drop the existing global unique index on name
    op.drop_index('ix_teams_name', table_name='teams')

    # Step 2: Create composite unique index on (created_by, name)
    op.create_index(
        'ix_teams_created_by_name',
        table_name='teams',
        columns=['created_by', 'name'],
        unique=True
    )
```

**Executed on production database:**

```sql
DROP INDEX IF EXISTS ix_teams_name;

CREATE UNIQUE INDEX ix_teams_created_by_name
ON teams (created_by, name);
```

### 2. Model Update

Updated `backend/app/models/cricket.py`:

```python
# Before:
name = Column(String, unique=True, index=True, nullable=False)

# After:
name = Column(String, index=True, nullable=False)  # Unique per user, not globally
```

### 3. API Validation Update

Updated `backend/app/routers/teams.py`:

**Create Team:**
```python
# Before - check all teams:
existing = db.query(Team).filter(Team.name == team_in.name).first()

# After - check only teams by same user:
existing = db.query(Team).filter(
    Team.name == team_in.name,
    Team.created_by == current_user.id
).first()
```

**Update Team:**
```python
# Before:
existing = db.query(Team).filter(
    Team.name == team_in.name,
    Team.id != id
).first()

# After:
existing = db.query(Team).filter(
    Team.name == team_in.name,
    Team.created_by == team.created_by,  # Same user
    Team.id != id
).first()
```

## Verification Evidence

### Database Index After Migration

```
ix_teams_created_by_name: CREATE UNIQUE INDEX ix_teams_created_by_name ON public.teams USING btree (created_by, name)
```

### Behavior Tests

| Test | User | Team Name | Result | Explanation |
|------|------|-----------|--------|-------------|
| 1 | User A (cricupservice@gmail.com) | CSK | Already exists | Pre-existing team |
| 2 | User B (shyam@example.com) | CSK | **SUCCESS** | Created new team - per-user uniqueness works |
| 3 | User A | CSK (second) | **FAILED** | UniqueViolation - correctly rejects duplicate for same user |

### Final State - Teams Named "CSK"

```
Team: CSK, Created by: 31f9289e-fb0c-4d86-baa2-3704d82796cb (User A)
Team: CSK, Created by: 1600e0f2-b73b-46de-91db-6e6b74ff833b (User B)
```

Both users now have their own "CSK" team.

## Files Modified

1. **Created:** `backend/alembic/versions/team_uniqueness_migration.py`
2. **Modified:** `backend/app/models/cricket.py` (line 73)
3. **Modified:** `backend/app/routers/teams.py` (lines 24-30, 212-219)

## Rollback

To revert to global uniqueness:

```python
def downgrade() -> None:
    op.drop_index('ix_teams_created_by_name', table_name='teams')
    op.create_index('ix_teams_name', table_name='teams', columns=['name'], unique=True)
```

And restore `unique=True` in the model.