"""Performance Management service — IPCR/OPCR, adjectival ratings, PBB flagging."""
from services.db import get_cursor
from services import workflow_service, notification_service


# ---------------------------------------------------------------------------
# Adjectival Rating Mapping (CSC SPMS)
# ---------------------------------------------------------------------------

def adjectival_rating(numerical):
    """Map numerical IPCR/OPCR rating to adjectival rating per CSC scale."""
    if numerical is None:
        return None
    n = float(numerical)
    if n >= 4.500:
        return 'Outstanding'
    elif n >= 3.500:
        return 'Very Satisfactory'
    elif n >= 2.500:
        return 'Satisfactory'
    elif n >= 1.500:
        return 'Unsatisfactory'
    else:
        return 'Poor'


# ---------------------------------------------------------------------------
# Performance Cycles
# ---------------------------------------------------------------------------

def get_cycles(company_id, status=None):
    conditions = ['c.company_id = %s']
    params = [company_id]
    if status:
        conditions.append('c.status = %s')
        params.append(status)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT c.*,
                   COUNT(DISTINCT i.employee_id) AS ipcr_count,
                   COUNT(DISTINCT o.id)          AS opcr_count
            FROM performance.perf_cycles c
            LEFT JOIN performance.perf_ipcr i ON i.cycle_id = c.id
            LEFT JOIN performance.perf_opcr o ON o.cycle_id = c.id
            WHERE {' AND '.join(conditions)}
            GROUP BY c.id
            ORDER BY c.period_from DESC
        """, params)
        return cur.fetchall()


def get_cycle(cycle_id):
    with get_cursor() as cur:
        cur.execute("SELECT * FROM performance.perf_cycles WHERE id = %s", (cycle_id,))
        return cur.fetchone()


def create_cycle(data):
    with get_cursor(commit=True) as cur:
        cur.execute("SELECT id FROM core.companies LIMIT 1")
        co_id = cur.fetchone()['id']
        cur.execute("""
            INSERT INTO performance.perf_cycles (company_id, name, cycle_type, period_from, period_to, status)
            VALUES (%s, %s, %s, %s, %s, %s) RETURNING id
        """, (co_id, data['name'], data['cycle_type'], data['period_from'], data['period_to'], data.get('status', 'PLANNING')))
        return cur.fetchone()['id']


def update_cycle(cycle_id, data):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE performance.perf_cycles
            SET name=%s, cycle_type=%s, period_from=%s, period_to=%s, status=%s
            WHERE id=%s
        """, (data['name'], data['cycle_type'], data['period_from'], data['period_to'], data.get('status', 'PLANNING'), cycle_id))


# ---------------------------------------------------------------------------
# OPCR
# ---------------------------------------------------------------------------

def get_opcr_dashboard(cycle_id, department_id=None):
    conditions = ['o.cycle_id = %s']
    params = [cycle_id]
    if department_id:
        conditions.append('o.department_id = %s')
        params.append(department_id)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT o.*, d.name AS department_name
            FROM performance.perf_opcr o
            JOIN core.departments d ON d.id = o.department_id
            WHERE {' AND '.join(conditions)}
            ORDER BY o.mfo_code, o.id
        """, params)
        return cur.fetchall()


def save_opcr(data, user_id):
    with get_cursor(commit=True) as cur:
        if data.get('id'):
            cur.execute("""
                UPDATE performance.perf_opcr SET
                    mfo_code = %s, performance_indicator = %s, target = %s,
                    target_value = %s, actual_value = %s, self_rating = %s,
                    weight = %s, means_of_verification = %s, responsible_office = %s,
                    updated_at = NOW()
                WHERE id = %s RETURNING id
            """, (data['mfo_code'], data['performance_indicator'], data['target'],
                  data.get('target_value'), data.get('actual_value'), data.get('self_rating'),
                  data.get('weight', 1.0), data.get('means_of_verification'),
                  data.get('responsible_office'), data['id']))
        else:
            cur.execute("""
                INSERT INTO performance.perf_opcr
                    (company_id, department_id, cycle_id, mfo_code, performance_indicator,
                     target, target_value, weight, means_of_verification, responsible_office)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING id
            """, (data['company_id'], data['department_id'], data['cycle_id'],
                  data['mfo_code'], data['performance_indicator'], data['target'],
                  data.get('target_value'), data.get('weight', 1.0),
                  data.get('means_of_verification'), data.get('responsible_office')))
        return cur.fetchone()


# ---------------------------------------------------------------------------
# IPCR
# ---------------------------------------------------------------------------

def get_ipcr_entries(employee_id=None, cycle_id=None, evaluator_id=None):
    conditions = ['1=1']
    params = []
    if employee_id:
        conditions.append('i.employee_id = %s')
        params.append(employee_id)
    if cycle_id:
        conditions.append('i.cycle_id = %s')
        params.append(cycle_id)
    if evaluator_id:
        conditions.append('i.evaluator_id = %s')
        params.append(evaluator_id)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT i.*,
                   e.first_name || ' ' || e.last_name AS employee_name,
                   ev.first_name || ' ' || ev.last_name AS evaluator_name,
                   d.name AS department_name
            FROM performance.perf_ipcr i
            JOIN core.employees e ON e.id = i.employee_id
            LEFT JOIN core.employees ev ON ev.id = i.evaluator_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            WHERE {' AND '.join(conditions)}
            ORDER BY i.function_type, i.id
        """, params)
        return cur.fetchall()


def save_ipcr(data, user_id):
    with get_cursor(commit=True) as cur:
        if data.get('id'):
            cur.execute("""
                UPDATE performance.perf_ipcr SET
                    function_type = %s, performance_indicator = %s, target = %s,
                    target_value = %s, actual_value = %s,
                    quality_rating = %s, efficiency_rating = %s, timeliness_rating = %s,
                    weight = %s, means_of_verification = %s, status = %s,
                    updated_at = NOW()
                WHERE id = %s RETURNING id
            """, (data['function_type'], data['performance_indicator'], data['target'],
                  data.get('target_value'), data.get('actual_value'),
                  data.get('quality_rating'), data.get('efficiency_rating'),
                  data.get('timeliness_rating'), data.get('weight', 1.0),
                  data.get('means_of_verification'), data.get('status', 'DRAFT'),
                  data['id']))
        else:
            cur.execute("""
                INSERT INTO performance.perf_ipcr
                    (employee_id, cycle_id, opcr_id, function_type, performance_indicator,
                     target, target_value, weight, means_of_verification, evaluator_id)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING id
            """, (data['employee_id'], data['cycle_id'], data.get('opcr_id'),
                  data['function_type'], data['performance_indicator'],
                  data['target'], data.get('target_value'),
                  data.get('weight', 1.0), data.get('means_of_verification'),
                  data.get('evaluator_id')))
        return cur.fetchone()


# ---------------------------------------------------------------------------
# IPCR Rating Computation
# ---------------------------------------------------------------------------

def compute_ipcr_rating(employee_id, cycle_id):
    """
    Compute weighted average of all IPCR entries for an employee in a cycle.
    Returns: {final_numerical_rating, adjectival_rating, core_avg, support_avg, strategic_avg}
    """
    with get_cursor() as cur:
        cur.execute("""
            SELECT function_type, weight, average_rating
            FROM performance.perf_ipcr
            WHERE employee_id = %s AND cycle_id = %s
              AND average_rating IS NOT NULL
        """, (employee_id, cycle_id))
        entries = cur.fetchall()

    if not entries:
        return None

    total_weight = sum(float(e['weight'] or 1) for e in entries)
    if total_weight == 0:
        return None

    weighted_sum = sum(float(e['average_rating']) * float(e['weight'] or 1) for e in entries)
    final_rating = round(weighted_sum / total_weight, 2)

    # Per-function averages
    def fn_avg(fn_type):
        subset = [e for e in entries if e['function_type'] == fn_type]
        if not subset:
            return None
        w = sum(float(e['weight'] or 1) for e in subset)
        return round(sum(float(e['average_rating']) * float(e['weight'] or 1) for e in subset) / w, 2) if w else None

    return {
        'final_numerical_rating': final_rating,
        'adjectival_rating': adjectival_rating(final_rating),
        'core_avg': fn_avg('CORE'),
        'support_avg': fn_avg('SUPPORT'),
        'strategic_avg': fn_avg('STRATEGIC'),
    }


def finalize_ipcr(employee_id, cycle_id, approver_id):
    """Finalize IPCR summary: compute rating, set PBB/step-increment flags."""
    result = compute_ipcr_rating(employee_id, cycle_id)
    if not result:
        return None

    pbb_eligible = result['final_numerical_rating'] >= 3.500  # Very Satisfactory+
    step_eligible = result['final_numerical_rating'] >= 2.500  # Satisfactory+

    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO performance.perf_ipcr_summary
                (employee_id, cycle_id, final_numerical_rating, adjectival_rating,
                 pbb_eligible, step_increment_eligible, approved_by, approved_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, NOW())
            ON CONFLICT (employee_id, cycle_id) DO UPDATE SET
                final_numerical_rating  = EXCLUDED.final_numerical_rating,
                adjectival_rating       = EXCLUDED.adjectival_rating,
                pbb_eligible            = EXCLUDED.pbb_eligible,
                step_increment_eligible = EXCLUDED.step_increment_eligible,
                approved_by             = EXCLUDED.approved_by,
                approved_at             = NOW(),
                updated_at              = NOW()
            RETURNING id
        """, (employee_id, cycle_id, result['final_numerical_rating'],
              result['adjectival_rating'], pbb_eligible, step_eligible, approver_id))
        summary = cur.fetchone()

        # Update all IPCR entries to APPROVED
        cur.execute("""
            UPDATE performance.perf_ipcr
            SET status = 'APPROVED', updated_at = NOW()
            WHERE employee_id = %s AND cycle_id = %s
        """, (employee_id, cycle_id))

    return summary


def get_ipcr_summary(employee_id=None, cycle_id=None):
    conditions = ['1=1']
    params = []
    if employee_id:
        conditions.append('s.employee_id = %s')
        params.append(employee_id)
    if cycle_id:
        conditions.append('s.cycle_id = %s')
        params.append(cycle_id)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT s.*,
                   e.first_name || ' ' || e.last_name AS employee_name,
                   d.name AS department_name,
                   c.name AS cycle_name
            FROM performance.perf_ipcr_summary s
            JOIN core.employees e ON e.id = s.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            JOIN performance.perf_cycles c ON c.id = s.cycle_id
            WHERE {' AND '.join(conditions)}
            ORDER BY s.final_numerical_rating DESC NULLS LAST
        """, params)
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Rating Distribution (org-wide)
# ---------------------------------------------------------------------------

def get_rating_distribution(cycle_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT adjectival_rating, COUNT(*) AS cnt
            FROM performance.perf_ipcr_summary
            WHERE cycle_id = %s AND adjectival_rating IS NOT NULL
            GROUP BY adjectival_rating
            ORDER BY MIN(final_numerical_rating) DESC
        """, (cycle_id,))
        return cur.fetchall()


def get_pbb_eligible(cycle_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT s.*, e.first_name || ' ' || e.last_name AS employee_name,
                   d.name AS department_name
            FROM performance.perf_ipcr_summary s
            JOIN core.employees e ON e.id = s.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            WHERE s.cycle_id = %s AND s.pbb_eligible = TRUE
            ORDER BY s.final_numerical_rating DESC
        """, (cycle_id,))
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Succession Planning
# ---------------------------------------------------------------------------

def get_succession_matrix(cycle_id=None):
    with get_cursor() as cur:
        cur.execute("""
            SELECT sm.*, p.title AS position_title,
                   e.first_name || ' ' || e.last_name AS successor_name,
                   jg.grade_level AS salary_grade,
                   d.name AS department_name
            FROM performance.perf_succession_matrix sm
            JOIN core.positions p ON p.id = sm.key_position_id
            JOIN core.employees e ON e.id = sm.successor_employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.job_grades jg ON jg.id = e.job_grade_id
            WHERE (%s IS NULL OR sm.cycle_id = %s)
            ORDER BY p.title, sm.readiness
        """, (cycle_id, cycle_id))
        return cur.fetchall()
