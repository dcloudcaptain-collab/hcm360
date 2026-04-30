"""Benefits Administration Service — plans, enrollments, life events, open enrollment."""
from datetime import date
from services.db import get_cursor


# ---------------------------------------------------------------------------
# Plan Types & Plans
# ---------------------------------------------------------------------------

def get_plan_types():
    with get_cursor() as cur:
        cur.execute("SELECT * FROM benefits.plan_types ORDER BY sort_order, name")
        return cur.fetchall()


def get_plans(company_id=None, plan_type_id=None, active_only=True):
    conditions = []
    params = []
    if company_id:
        conditions.append('p.company_id = %s')
        params.append(company_id)
    if plan_type_id:
        conditions.append('p.plan_type_id = %s')
        params.append(plan_type_id)
    if active_only:
        conditions.append('p.is_active = TRUE')
    where = 'WHERE ' + ' AND '.join(conditions) if conditions else ''
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT p.*, pt.name AS type_name, pt.category, pt.code AS type_code,
                   (SELECT COUNT(*) FROM benefits.enrollments e
                    WHERE e.plan_id = p.id AND e.status = 'ACTIVE') AS enrolled_count
            FROM benefits.plans p
            JOIN benefits.plan_types pt ON pt.id = p.plan_type_id
            {where}
            ORDER BY pt.sort_order, p.name
        """, params)
        return cur.fetchall()


def get_plan(plan_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT p.*, pt.name AS type_name, pt.category, pt.code AS type_code
            FROM benefits.plans p
            JOIN benefits.plan_types pt ON pt.id = p.plan_type_id
            WHERE p.id = %s
        """, (plan_id,))
        return cur.fetchone()


def create_plan(company_id, plan_type_id, code, name, description, provider,
                coverage_level, employer_cost, employee_cost, plan_details=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO benefits.plans
                (company_id, plan_type_id, code, name, description, provider,
                 coverage_level, employer_cost, employee_cost, plan_details)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            RETURNING id
        """, (company_id, plan_type_id, code, name, description, provider,
              coverage_level, employer_cost, employee_cost, plan_details))
        return cur.fetchone()['id']


# ---------------------------------------------------------------------------
# Enrollment Windows
# ---------------------------------------------------------------------------

def get_enrollment_windows(company_id=None):
    with get_cursor() as cur:
        cur.execute("""
            SELECT ew.*,
                   (SELECT COUNT(*) FROM benefits.enrollments e
                    WHERE e.window_id = ew.id) AS enrollment_count
            FROM benefits.enrollment_windows ew
            ORDER BY ew.year DESC, ew.open_date DESC
        """)
        return cur.fetchall()


def get_active_window(company_id=None):
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM benefits.enrollment_windows
            WHERE status = 'OPEN' AND CURRENT_DATE BETWEEN open_date AND close_date
            ORDER BY close_date LIMIT 1
        """)
        return cur.fetchone()


def create_enrollment_window(company_id, name, year, open_date, close_date, effective_date):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO benefits.enrollment_windows
                (company_id, name, year, open_date, close_date, effective_date, status)
            VALUES (%s,%s,%s,%s,%s,%s,'DRAFT') RETURNING id
        """, (company_id, name, year, open_date, close_date, effective_date))
        return cur.fetchone()['id']


def update_window_status(window_id, status):
    with get_cursor(commit=True) as cur:
        cur.execute("UPDATE benefits.enrollment_windows SET status = %s WHERE id = %s",
                    (status, window_id))


# ---------------------------------------------------------------------------
# Enrollments
# ---------------------------------------------------------------------------

def get_employee_enrollments(employee_id, status='ACTIVE'):
    with get_cursor() as cur:
        cur.execute("""
            SELECT e.*, p.name AS plan_name, p.code AS plan_code, p.provider,
                   pt.name AS type_name, pt.category, pt.code AS type_code,
                   p.plan_details
            FROM benefits.enrollments e
            JOIN benefits.plans p ON p.id = e.plan_id
            JOIN benefits.plan_types pt ON pt.id = p.plan_type_id
            WHERE e.employee_id = %s AND e.status = %s
            ORDER BY pt.sort_order, p.name
        """, (employee_id, status))
        return cur.fetchall()


def get_enrollment_detail(enrollment_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT e.*, p.name AS plan_name, p.code AS plan_code, p.provider,
                   pt.name AS type_name, pt.category,
                   p.plan_details, p.description AS plan_description
            FROM benefits.enrollments e
            JOIN benefits.plans p ON p.id = e.plan_id
            JOIN benefits.plan_types pt ON pt.id = p.plan_type_id
            WHERE e.id = %s
        """, (enrollment_id,))
        enrollment = cur.fetchone()

        cur.execute("""
            SELECT * FROM benefits.enrollment_dependents
            WHERE enrollment_id = %s AND is_active = TRUE
            ORDER BY relationship, dependent_name
        """, (enrollment_id,))
        dependents = cur.fetchall()

    return {'enrollment': enrollment, 'dependents': dependents}


def enroll(employee_id, plan_id, coverage_level='INDIVIDUAL', window_id=None,
           dependents=None, effective_from=None):
    if not effective_from:
        effective_from = date.today()
    plan = get_plan(plan_id)
    emp_cost = plan['employee_cost'] if plan else 0
    er_cost = plan['employer_cost'] if plan else 0

    if coverage_level == 'FAMILY':
        emp_cost = emp_cost * 2.5
        er_cost = er_cost * 2.5
    elif coverage_level == 'INDIVIDUAL_PLUS_ONE':
        emp_cost = emp_cost * 1.5
        er_cost = er_cost * 1.5

    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO benefits.enrollments
                (employee_id, plan_id, window_id, coverage_level,
                 employee_cost, employer_cost, status, effective_from)
            VALUES (%s,%s,%s,%s,%s,%s,'ACTIVE',%s)
            ON CONFLICT (employee_id, plan_id, effective_from)
            DO UPDATE SET coverage_level = EXCLUDED.coverage_level,
                          employee_cost = EXCLUDED.employee_cost,
                          employer_cost = EXCLUDED.employer_cost,
                          status = 'ACTIVE'
            RETURNING id
        """, (employee_id, plan_id, window_id, coverage_level,
              emp_cost, er_cost, effective_from))
        enrollment_id = cur.fetchone()['id']

        if dependents:
            for dep in dependents:
                cur.execute("""
                    INSERT INTO benefits.enrollment_dependents
                        (enrollment_id, dependent_name, relationship, date_of_birth)
                    VALUES (%s,%s,%s,%s)
                """, (enrollment_id, dep['name'], dep['relationship'], dep.get('dob')))

        cur.execute("""
            INSERT INTO benefits.change_log
                (enrollment_id, employee_id, change_type, new_plan_id, changed_by)
            VALUES (%s,%s,'ENROLL',%s,%s)
        """, (enrollment_id, employee_id, plan_id, employee_id))

    return enrollment_id


def waive_plan(employee_id, plan_id, reason=None, changed_by=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE benefits.enrollments SET status = 'WAIVED', waived_reason = %s
            WHERE employee_id = %s AND plan_id = %s AND status = 'ACTIVE'
            RETURNING id
        """, (reason, employee_id, plan_id))
        row = cur.fetchone()
        if row:
            cur.execute("""
                INSERT INTO benefits.change_log
                    (enrollment_id, employee_id, change_type, old_plan_id, reason, changed_by)
                VALUES (%s,%s,'WAIVE',%s,%s,%s)
            """, (row['id'], employee_id, plan_id, reason, changed_by))


# ---------------------------------------------------------------------------
# Life Events
# ---------------------------------------------------------------------------

def get_life_events(employee_id=None, status=None):
    conditions = []
    params = []
    if employee_id:
        conditions.append('le.employee_id = %s')
        params.append(employee_id)
    if status:
        conditions.append('le.status = %s')
        params.append(status)
    where = 'WHERE ' + ' AND '.join(conditions) if conditions else ''
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT le.*, emp.first_name || ' ' || emp.last_name AS employee_name
            FROM benefits.life_events le
            JOIN core.employees emp ON emp.id = le.employee_id
            {where}
            ORDER BY le.created_at DESC
        """, params)
        return cur.fetchall()


def create_life_event(employee_id, event_type, event_date, description=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO benefits.life_events
                (employee_id, event_type, event_date, description)
            VALUES (%s,%s,%s,%s) RETURNING id
        """, (employee_id, event_type, event_date, description))
        return cur.fetchone()['id']


def close_life_event(event_id, processed_by):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE benefits.life_events
            SET status = 'CLOSED', processed_by = %s, processed_at = NOW()
            WHERE id = %s
        """, (processed_by, event_id))


# ---------------------------------------------------------------------------
# Dashboard Stats
# ---------------------------------------------------------------------------

def get_benefits_stats(company_id=None):
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                (SELECT COUNT(*) FROM benefits.plans WHERE is_active) AS active_plans,
                (SELECT COUNT(*) FROM benefits.enrollments WHERE status = 'ACTIVE') AS active_enrollments,
                (SELECT COUNT(DISTINCT employee_id) FROM benefits.enrollments WHERE status = 'ACTIVE') AS enrolled_employees,
                (SELECT COALESCE(SUM(employer_cost), 0) FROM benefits.enrollments WHERE status = 'ACTIVE') AS total_employer_cost,
                (SELECT COALESCE(SUM(employee_cost), 0) FROM benefits.enrollments WHERE status = 'ACTIVE') AS total_employee_cost,
                (SELECT COUNT(*) FROM benefits.life_events WHERE status = 'OPEN') AS open_life_events,
                (SELECT COUNT(*) FROM benefits.enrollment_windows WHERE status = 'OPEN') AS open_windows
        """)
        return cur.fetchone()


def get_enrollment_summary_by_type():
    with get_cursor() as cur:
        cur.execute("""
            SELECT pt.name AS type_name, pt.category,
                   COUNT(DISTINCT e.employee_id) AS employees,
                   SUM(e.employer_cost) AS employer_total,
                   SUM(e.employee_cost) AS employee_total
            FROM benefits.enrollments e
            JOIN benefits.plans p ON p.id = e.plan_id
            JOIN benefits.plan_types pt ON pt.id = p.plan_type_id
            WHERE e.status = 'ACTIVE'
            GROUP BY pt.name, pt.category, pt.sort_order
            ORDER BY pt.sort_order
        """)
        return cur.fetchall()
