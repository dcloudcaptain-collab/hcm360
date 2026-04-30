"""Goals service — cascading goals and OKR management."""
from services.db import get_cursor


# ---------------------------------------------------------------------------
# Goal Tree
# ---------------------------------------------------------------------------

def get_goal_tree(cycle_id=None):
    """Hierarchical goal tree (org -> dept -> team -> individual) using parent_goal_id.

    Returns a list of top-level goals, each with a 'children' key populated recursively.
    """
    conditions = ['1=1']
    params = []
    if cycle_id:
        conditions.append('g.cycle_id = %s')
        params.append(cycle_id)

    with get_cursor() as cur:
        cur.execute(f"""
            SELECT g.*,
                   pc.name AS cycle_name,
                   CASE g.owner_type
                       WHEN 'EMPLOYEE' THEN (SELECT full_name FROM core.v_employees_full WHERE id = g.owner_id)
                       WHEN 'DEPARTMENT' THEN (SELECT name FROM core.departments WHERE id = g.owner_id)
                       ELSE NULL
                   END AS owner_name
            FROM performance.goals g
            LEFT JOIN performance.perf_cycles pc ON pc.id = g.cycle_id
            WHERE {' AND '.join(conditions)}
            ORDER BY g.owner_type, g.created_at
        """, params)
        all_goals = cur.fetchall()

    # Build tree
    goal_map = {}
    for g in all_goals:
        g['children'] = []
        goal_map[g['id']] = g

    roots = []
    for g in all_goals:
        parent_id = g.get('parent_goal_id')
        if parent_id and parent_id in goal_map:
            goal_map[parent_id]['children'].append(g)
        else:
            roots.append(g)

    return roots


# ---------------------------------------------------------------------------
# Goals for Employee
# ---------------------------------------------------------------------------

def get_goals_for_employee(employee_id, cycle_id=None):
    """Employee's goals with parent info."""
    conditions = ["g.owner_type = 'EMPLOYEE'", 'g.owner_id = %s']
    params = [employee_id]
    if cycle_id:
        conditions.append('g.cycle_id = %s')
        params.append(cycle_id)

    with get_cursor() as cur:
        cur.execute(f"""
            SELECT g.*,
                   pc.name AS cycle_name,
                   pg.title AS parent_title,
                   pg.owner_type AS parent_owner_type
            FROM performance.goals g
            LEFT JOIN performance.perf_cycles pc ON pc.id = g.cycle_id
            LEFT JOIN performance.goals pg ON pg.id = g.parent_goal_id
            WHERE {' AND '.join(conditions)}
            ORDER BY g.due_date ASC NULLS LAST, g.created_at DESC
        """, params)
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Goals for Department
# ---------------------------------------------------------------------------

def get_goals_for_department(department_id, cycle_id=None):
    """Department goals."""
    conditions = ["g.owner_type = 'DEPARTMENT'", 'g.owner_id = %s']
    params = [department_id]
    if cycle_id:
        conditions.append('g.cycle_id = %s')
        params.append(cycle_id)

    with get_cursor() as cur:
        cur.execute(f"""
            SELECT g.*,
                   pc.name AS cycle_name,
                   d.name AS department_name,
                   pg.title AS parent_title
            FROM performance.goals g
            LEFT JOIN performance.perf_cycles pc ON pc.id = g.cycle_id
            LEFT JOIN core.departments d ON d.id = g.owner_id
            LEFT JOIN performance.goals pg ON pg.id = g.parent_goal_id
            WHERE {' AND '.join(conditions)}
            ORDER BY g.due_date ASC NULLS LAST, g.created_at DESC
        """, params)
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Create Goal
# ---------------------------------------------------------------------------

def create_goal(cycle_id, parent_goal_id, owner_type, owner_id,
                title, description, metric, target_value, weight, due_date):
    """Insert a new goal."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO performance.goals
                (cycle_id, parent_goal_id, owner_type, owner_id,
                 title, description, metric, target_value,
                 weight, due_date, status, progress_pct, current_value)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'ACTIVE', 0, 0)
            RETURNING id
        """, (cycle_id, parent_goal_id, owner_type, owner_id,
              title, description, metric, target_value, weight, due_date))
        return cur.fetchone()['id']


# ---------------------------------------------------------------------------
# Update Progress
# ---------------------------------------------------------------------------

def update_progress(goal_id, current_value, progress_pct):
    """Update goal progress."""
    with get_cursor(commit=True) as cur:
        status = 'COMPLETED' if progress_pct and float(progress_pct) >= 100 else 'ACTIVE'
        cur.execute("""
            UPDATE performance.goals
            SET current_value = %s, progress_pct = %s, status = %s, updated_at = NOW()
            WHERE id = %s
        """, (current_value, progress_pct, status, goal_id))


# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------

def get_goal_stats(cycle_id=None):
    """Total, by status, avg progress."""
    conditions = ['1=1']
    params = []
    if cycle_id:
        conditions.append('g.cycle_id = %s')
        params.append(cycle_id)

    with get_cursor() as cur:
        cur.execute(f"""
            SELECT
                COUNT(*) AS total,
                COUNT(*) FILTER (WHERE g.status = 'ACTIVE') AS active,
                COUNT(*) FILTER (WHERE g.status = 'COMPLETED') AS completed,
                COUNT(*) FILTER (WHERE g.status = 'CANCELLED') AS cancelled,
                ROUND(AVG(g.progress_pct)::numeric, 1) AS avg_progress
            FROM performance.goals g
            WHERE {' AND '.join(conditions)}
        """, params)
        return cur.fetchone()


# ---------------------------------------------------------------------------
# Cascading View
# ---------------------------------------------------------------------------

def get_cascading_view(goal_id):
    """Goal + all children recursively."""
    with get_cursor() as cur:
        cur.execute("""
            WITH RECURSIVE goal_tree AS (
                SELECT g.*,
                       0 AS depth,
                       CASE g.owner_type
                           WHEN 'EMPLOYEE' THEN (SELECT full_name FROM core.v_employees_full WHERE id = g.owner_id)
                           WHEN 'DEPARTMENT' THEN (SELECT name FROM core.departments WHERE id = g.owner_id)
                           ELSE NULL
                       END AS owner_name
                FROM performance.goals g
                WHERE g.id = %s

                UNION ALL

                SELECT c.*,
                       gt.depth + 1,
                       CASE c.owner_type
                           WHEN 'EMPLOYEE' THEN (SELECT full_name FROM core.v_employees_full WHERE id = c.owner_id)
                           WHEN 'DEPARTMENT' THEN (SELECT name FROM core.departments WHERE id = c.owner_id)
                           ELSE NULL
                       END AS owner_name
                FROM performance.goals c
                JOIN goal_tree gt ON c.parent_goal_id = gt.id
            )
            SELECT * FROM goal_tree ORDER BY depth, created_at
        """, (goal_id,))
        rows = cur.fetchall()

    if not rows:
        return None, []

    root = rows[0]
    children = rows[1:]
    return root, children


# ---------------------------------------------------------------------------
# Goal Detail
# ---------------------------------------------------------------------------

def get_goal(goal_id):
    """Get a single goal with parent info."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT g.*,
                   pc.name AS cycle_name,
                   pg.title AS parent_title,
                   pg.id AS parent_id,
                   CASE g.owner_type
                       WHEN 'EMPLOYEE' THEN (SELECT full_name FROM core.v_employees_full WHERE id = g.owner_id)
                       WHEN 'DEPARTMENT' THEN (SELECT name FROM core.departments WHERE id = g.owner_id)
                       ELSE NULL
                   END AS owner_name
            FROM performance.goals g
            LEFT JOIN performance.perf_cycles pc ON pc.id = g.cycle_id
            LEFT JOIN performance.goals pg ON pg.id = g.parent_goal_id
            WHERE g.id = %s
        """, (goal_id,))
        return cur.fetchone()
