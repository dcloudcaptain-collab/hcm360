"""Calibration service — talent calibration sessions and 9-box grid."""
from services.db import get_cursor


# ---------------------------------------------------------------------------
# Box label computation
# ---------------------------------------------------------------------------

_PERF_LABELS = {1: 'Low', 2: 'Med', 3: 'High'}
_POT_LABELS = {1: 'A', 2: 'B', 3: 'C'}


def compute_box_label(performance_score, potential_score):
    """
    Compute 9-box label from performance (1-3) and potential (1-3).
    Format: "{perf}{potential}" e.g. "3A" = High Performance, Low Potential.
    """
    perf = max(1, min(3, int(performance_score or 1)))
    pot = max(1, min(3, int(potential_score or 1)))
    return f"{perf}{_POT_LABELS[pot]}"


def box_display_name(performance_score, potential_score):
    """Human-readable box name."""
    perf = _PERF_LABELS.get(int(performance_score or 1), 'Low')
    pot = _PERF_LABELS.get(int(potential_score or 1), 'Low')
    return f"{perf} Perf / {pot} Potential"


# ---------------------------------------------------------------------------
# Sessions
# ---------------------------------------------------------------------------

def get_sessions(status=None):
    """List calibration sessions with participant counts."""
    conditions = []
    params = []
    if status:
        conditions.append('cs.status = %s')
        params.append(status)

    where = ('WHERE ' + ' AND '.join(conditions)) if conditions else ''

    with get_cursor() as cur:
        cur.execute(f"""
            SELECT cs.*,
                   d.name AS department_name,
                   pc.name AS cycle_name,
                   ef.full_name AS facilitator_name,
                   COUNT(ta.id) AS assessed_count
            FROM performance.calibration_sessions cs
            LEFT JOIN core.departments d ON d.id = cs.department_id
            LEFT JOIN performance.perf_cycles pc ON pc.id = cs.cycle_id
            LEFT JOIN core.v_employees_full ef ON ef.id = cs.facilitator_id
            LEFT JOIN performance.talent_assessments ta ON ta.session_id = cs.id
            {where}
            GROUP BY cs.id, d.name, pc.name, ef.full_name
            ORDER BY cs.created_at DESC
        """, params)
        return cur.fetchall()


def get_session_detail(session_id):
    """Session + all talent_assessments with employee info."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT cs.*,
                   d.name AS department_name,
                   pc.name AS cycle_name,
                   ef.full_name AS facilitator_name
            FROM performance.calibration_sessions cs
            LEFT JOIN core.departments d ON d.id = cs.department_id
            LEFT JOIN performance.perf_cycles pc ON pc.id = cs.cycle_id
            LEFT JOIN core.v_employees_full ef ON ef.id = cs.facilitator_id
            WHERE cs.id = %s
        """, (session_id,))
        session_row = cur.fetchone()

        cur.execute("""
            SELECT ta.*,
                   e.full_name AS employee_name,
                   e.department_name,
                   e.position_title,
                   ab.full_name AS assessed_by_name
            FROM performance.talent_assessments ta
            LEFT JOIN core.v_employees_full e ON e.id = ta.employee_id
            LEFT JOIN core.v_employees_full ab ON ab.id = ta.assessed_by
            WHERE ta.session_id = %s
            ORDER BY ta.performance_score DESC, ta.potential_score DESC
        """, (session_id,))
        assessments = cur.fetchall()

        return session_row, assessments


# ---------------------------------------------------------------------------
# Create Session
# ---------------------------------------------------------------------------

def create_session(name, cycle_id, department_id, facilitator_id):
    """Insert a new calibration session."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO performance.calibration_sessions
                (name, cycle_id, department_id, facilitator_id, status)
            VALUES (%s, %s, %s, %s, 'DRAFT')
            RETURNING id
        """, (name, cycle_id, department_id, facilitator_id))
        return cur.fetchone()['id']


# ---------------------------------------------------------------------------
# Assess Employee
# ---------------------------------------------------------------------------

def assess_employee(session_id, employee_id, performance_score, potential_score,
                    risk_of_loss, impact_of_loss, development_action, notes, assessed_by):
    """Upsert talent_assessments, auto-compute box_label."""
    box_label = compute_box_label(performance_score, potential_score)

    with get_cursor(commit=True) as cur:
        # Check existing
        cur.execute("""
            SELECT id FROM performance.talent_assessments
            WHERE session_id = %s AND employee_id = %s
        """, (session_id, employee_id))
        existing = cur.fetchone()

        if existing:
            cur.execute("""
                UPDATE performance.talent_assessments
                SET performance_score = %s, potential_score = %s,
                    box_label = %s, risk_of_loss = %s, impact_of_loss = %s,
                    development_action = %s, notes = %s, assessed_by = %s,
                    updated_at = NOW()
                WHERE id = %s
            """, (performance_score, potential_score, box_label,
                  risk_of_loss, impact_of_loss, development_action, notes,
                  assessed_by, existing['id']))
            return existing['id']
        else:
            cur.execute("""
                INSERT INTO performance.talent_assessments
                    (session_id, employee_id, performance_score, potential_score,
                     box_label, risk_of_loss, impact_of_loss, development_action,
                     notes, assessed_by)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING id
            """, (session_id, employee_id, performance_score, potential_score,
                  box_label, risk_of_loss, impact_of_loss, development_action,
                  notes, assessed_by))
            return cur.fetchone()['id']


# ---------------------------------------------------------------------------
# Finalize Session
# ---------------------------------------------------------------------------

def finalize_session(session_id):
    """Set status to FINALIZED."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE performance.calibration_sessions
            SET status = 'FINALIZED', finalized_at = NOW()
            WHERE id = %s
        """, (session_id,))


# ---------------------------------------------------------------------------
# 9-Box Matrix
# ---------------------------------------------------------------------------

def get_9box_matrix(session_id):
    """Return assessments grouped by box position for grid rendering.

    Returns a dict keyed by (perf, pot) tuples where perf and pot are 1-3.
    """
    with get_cursor() as cur:
        cur.execute("""
            SELECT ta.*,
                   e.full_name AS employee_name,
                   e.position_title
            FROM performance.talent_assessments ta
            LEFT JOIN core.v_employees_full e ON e.id = ta.employee_id
            WHERE ta.session_id = %s
        """, (session_id,))
        assessments = cur.fetchall()

    matrix = {}
    for perf in range(1, 4):
        for pot in range(1, 4):
            matrix[(perf, pot)] = []

    for a in assessments:
        perf = max(1, min(3, int(a['performance_score'] or 1)))
        pot = max(1, min(3, int(a['potential_score'] or 1)))
        matrix[(perf, pot)].append(a)

    return matrix


# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------

def get_calibration_stats():
    """Total sessions, finalized, employees assessed."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                COUNT(*) AS total_sessions,
                COUNT(*) FILTER (WHERE status = 'FINALIZED') AS finalized,
                (SELECT COUNT(DISTINCT employee_id) FROM performance.talent_assessments) AS employees_assessed
            FROM performance.calibration_sessions
        """)
        return cur.fetchone()
