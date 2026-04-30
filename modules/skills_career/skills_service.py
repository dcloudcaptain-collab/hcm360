"""Skills & Career Development Service."""
from services.db import get_cursor


# ---------------------------------------------------------------------------
# Skill Categories
# ---------------------------------------------------------------------------

def get_skill_categories():
    """Return all skill categories."""
    with get_cursor() as cur:
        cur.execute("SELECT * FROM skills.skill_categories ORDER BY sort_order, name")
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Skill Definitions
# ---------------------------------------------------------------------------

def get_skill_definitions(category_id=None):
    """Return all skill definitions with category name, optionally filtered."""
    conditions = []
    params = []
    if category_id:
        conditions.append('sd.category_id = %s')
        params.append(category_id)
    where = 'WHERE ' + ' AND '.join(conditions) if conditions else ''
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT sd.*, sc.name AS category_name            FROM skills.skill_definitions sd
            JOIN skills.skill_categories sc ON sc.id = sd.category_id
            {where}
            ORDER BY sc.sort_order, sd.name
        """, params)
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Employee Skills
# ---------------------------------------------------------------------------

def get_employee_skills(employee_id):
    """Return employee's skills with self/manager ratings and gap info."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT es.*, sd.name AS skill_name, sd.description AS skill_description,
                   sd.is_technical, sc.name AS category_name,                    rsr.required_level,
                   CASE WHEN rsr.required_level IS NOT NULL
                        THEN rsr.required_level - COALESCE(es.self_rating, 0)
                        ELSE NULL END AS gap
            FROM skills.employee_skills es
            JOIN skills.skill_definitions sd ON sd.id = es.skill_id
            JOIN skills.skill_categories sc ON sc.id = sd.category_id
            LEFT JOIN core.employees emp ON emp.id = es.employee_id
            LEFT JOIN skills.role_skill_requirements rsr
                 ON rsr.skill_id = es.skill_id
                AND rsr.position_id = emp.position_id
            WHERE es.employee_id = %s
            ORDER BY sc.sort_order, sd.name
        """, (employee_id,))
        return cur.fetchall()


def rate_skill(employee_id, skill_id, self_rating=None, manager_rating=None):
    """Upsert an employee skill rating."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO skills.employee_skills (employee_id, skill_id, self_rating, manager_rating)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (employee_id, skill_id)
            DO UPDATE SET
                self_rating    = COALESCE(EXCLUDED.self_rating, skills.employee_skills.self_rating),
                manager_rating = COALESCE(EXCLUDED.manager_rating, skills.employee_skills.manager_rating),
                updated_at     = NOW()
            RETURNING id
        """, (employee_id, skill_id, self_rating, manager_rating))
        return cur.fetchone()


def validate_skill(employee_id, skill_id, validated_by):
    """Mark a skill as validated."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE skills.employee_skills
            SET validated = TRUE, validated_by = %s, validated_at = NOW()
            WHERE employee_id = %s AND skill_id = %s
        """, (validated_by, employee_id, skill_id))


# ---------------------------------------------------------------------------
# Role Requirements
# ---------------------------------------------------------------------------

def get_role_requirements(position_id=None):
    """Return skill requirements for a position (or all positions)."""
    conditions = []
    params = []
    if position_id:
        conditions.append('rsr.position_id = %s')
        params.append(position_id)
    where = 'WHERE ' + ' AND '.join(conditions) if conditions else ''
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT rsr.*, sd.name AS skill_name, sd.is_technical,
                   sc.name AS category_name,
                   p.title AS position_title
            FROM skills.role_skill_requirements rsr
            JOIN skills.skill_definitions sd ON sd.id = rsr.skill_id
            JOIN skills.skill_categories sc ON sc.id = sd.category_id
            LEFT JOIN core.positions p ON p.id = rsr.position_id
            {where}
            ORDER BY p.title, sc.sort_order, sd.name
        """, params)
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Skill Gap Analysis
# ---------------------------------------------------------------------------

def get_skill_gap_report(employee_id):
    """Compare employee skills vs role requirements, return gaps."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT emp.first_name || ' ' || emp.last_name AS employee_name,
                   sd.name AS skill_name, sc.name AS category_name,
                   COALESCE(es.self_rating, 0) AS current_level,
                   rsr.required_level,
                   rsr.required_level - COALESCE(es.self_rating, 0) AS gap,
                   rsr.is_mandatory,
                   p.title AS position_title
            FROM skills.role_skill_requirements rsr
            JOIN core.employees emp ON emp.position_id = rsr.position_id AND emp.id = %s
            JOIN skills.skill_definitions sd ON sd.id = rsr.skill_id
            JOIN skills.skill_categories sc ON sc.id = sd.category_id
            LEFT JOIN core.positions p ON p.id = rsr.position_id
            LEFT JOIN skills.employee_skills es
                 ON es.employee_id = emp.id AND es.skill_id = rsr.skill_id
            ORDER BY (rsr.required_level - COALESCE(es.self_rating, 0)) DESC
        """, (employee_id,))
        return cur.fetchall()


def generate_skill_gaps(employee_id):
    """Compute and store gaps in skill_gap_analysis for an employee."""
    gaps = get_skill_gap_report(employee_id)
    with get_cursor(commit=True) as cur:
        cur.execute(
            "DELETE FROM skills.skill_gap_analysis WHERE employee_id = %s",
            (employee_id,))
        for g in gaps:
            gap_val = g['gap'] or 0
            if gap_val <= 0:
                continue
            recommendation = 'TRAIN' if gap_val >= 2 else 'MENTOR'
            cur.execute("""
                INSERT INTO skills.skill_gap_analysis
                    (employee_id, skill_id, current_level, required_level, recommendation)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT DO NOTHING
            """, (employee_id, g['skill_id'], g['current_level'],
                  g['required_level'], recommendation))


# ---------------------------------------------------------------------------
# Career Paths
# ---------------------------------------------------------------------------

def get_career_paths(from_position_id=None):
    """Return available career paths, optionally from a specific position."""
    conditions = []
    params = []
    if from_position_id:
        conditions.append('cp.from_position_id = %s')
        params.append(from_position_id)
    where = 'WHERE ' + ' AND '.join(conditions) if conditions else ''
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT cp.*,
                   fp.title AS from_position_title,
                   tp.title AS to_position_title
            FROM skills.career_paths cp
            LEFT JOIN core.positions fp ON fp.id = cp.from_position_id
            LEFT JOIN core.positions tp ON tp.id = cp.to_position_id
            {where}
            ORDER BY cp.path_type, fp.title
        """, params)
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Org Heatmap & Stats
# ---------------------------------------------------------------------------

def get_org_skill_heatmap():
    """Aggregate skill levels by department for dashboard heatmap."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT d.name AS department_name,
                   sc.name AS category_name,
                                      ROUND(AVG(es.self_rating)::numeric, 1) AS avg_rating,
                   COUNT(DISTINCT es.employee_id) AS employee_count
            FROM skills.employee_skills es
            JOIN core.employees emp ON emp.id = es.employee_id
            JOIN core.departments d ON d.id = emp.department_id
            JOIN skills.skill_definitions sd ON sd.id = es.skill_id
            JOIN skills.skill_categories sc ON sc.id = sd.category_id
            WHERE es.self_rating IS NOT NULL
            GROUP BY d.name, sc.name            ORDER BY d.name, sc.name
        """)
        return cur.fetchall()


def get_skill_stats():
    """Return total skills, employees assessed, avg gap, top gaps."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                (SELECT COUNT(*) FROM skills.skill_definitions) AS total_skills,
                (SELECT COUNT(DISTINCT employee_id) FROM skills.employee_skills) AS employees_assessed,
                (SELECT ROUND(AVG(gap)::numeric, 1) FROM skills.skill_gap_analysis WHERE gap > 0) AS avg_gap,
                (SELECT COUNT(*) FROM skills.skill_gap_analysis WHERE gap >= 3) AS critical_gaps
        """)
        stats = cur.fetchone()

        cur.execute("""
            SELECT sd.name AS skill_name, ROUND(AVG(sga.gap)::numeric, 1) AS avg_gap,
                   COUNT(*) AS affected_employees, sga.recommendation
            FROM skills.skill_gap_analysis sga
            JOIN skills.skill_definitions sd ON sd.id = sga.skill_id
            WHERE sga.gap > 0
            GROUP BY sd.name, sga.recommendation
            ORDER BY AVG(sga.gap) DESC
            LIMIT 10
        """)
        top_gaps = cur.fetchall()

    return stats, top_gaps
