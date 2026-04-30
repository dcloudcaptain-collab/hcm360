"""
Step Increment Monitoring — 3-year anniversary step increments from the
employee's Date of Original Appointment (falls back to date_hired).

Workflow:
    DUE  ->  NOTICE_SENT  ->  APPROVED  ->  RECORDED
                                        \->  DECLINED
"""
from datetime import date, timedelta

from services.db import get_cursor


# ══════════════════════════════════════════════════════════════════════
# Scanner
# ══════════════════════════════════════════════════════════════════════
def scan_due(company_id: int, look_ahead_days: int = 90) -> dict:
    """
    Find employees whose next 3-year increment is due within look_ahead_days.
    Inserts rows with status='DUE' if not already present.
    Returns summary counts.
    """
    today = date.today()
    horizon = today + timedelta(days=look_ahead_days)

    with get_cursor(commit=True) as cur:
        # Find all active employees whose next 3-year increment
        # lands within the horizon, if not already tracked.
        cur.execute("""
            WITH anchor AS (
                SELECT e.id AS employee_id,
                       COALESCE(e.date_of_original_appointment,
                                e.date_hired)      AS anchor_date,
                       jg.code AS salary_grade
                FROM core.employees e
                LEFT JOIN core.job_grades jg ON jg.id = e.job_grade_id
                WHERE e.company_id = %s
                  AND e.status = 'ACTIVE'
                  AND COALESCE(e.date_of_original_appointment,
                               e.date_hired) IS NOT NULL
            ),
            projected AS (
                SELECT a.employee_id, a.salary_grade, a.anchor_date,
                       -- Number of full 3-year cycles already elapsed
                       FLOOR(EXTRACT(EPOCH FROM age(%s::date, a.anchor_date))
                             / (365.25 * 86400) / 3)::int AS cycles_elapsed
                FROM anchor a
            ),
            upcoming AS (
                SELECT p.employee_id, p.salary_grade, p.anchor_date,
                       p.cycles_elapsed + 1                       AS next_increment_no,
                       (p.anchor_date + ((p.cycles_elapsed + 1) * INTERVAL '3 years'))::date
                                                                   AS next_due_date
                FROM projected p
            )
            INSERT INTO core.step_increment_history
                (employee_id, increment_no, due_date, from_salary_grade, status)
            SELECT u.employee_id, u.next_increment_no, u.next_due_date,
                   u.salary_grade, 'DUE'
            FROM upcoming u
            WHERE u.next_due_date <= %s
              AND u.next_due_date >= %s - INTERVAL '1 year'
            ON CONFLICT (employee_id, increment_no) DO NOTHING
            RETURNING id;
        """, (company_id, today, horizon, today))
        new_rows = cur.rowcount

    return {'inserted': new_rows, 'scanned_through': horizon.isoformat()}


# ══════════════════════════════════════════════════════════════════════
# Queries
# ══════════════════════════════════════════════════════════════════════
def list_items(company_id: int, status_filter: str = None,
               limit: int = 200) -> list:
    with get_cursor() as cur:
        sql = """
            SELECT h.id, h.employee_id, h.increment_no, h.due_date,
                   h.effective_date, h.status, h.from_salary_grade,
                   h.to_salary_grade, h.notice_sent_at, h.acknowledged_at,
                   emp.employee_no,
                   CONCAT_WS(' ', emp.first_name, emp.middle_name, emp.last_name) AS full_name,
                   jg.code AS salary_grade,
                   d.name AS department_name, p.title AS position_title,
                   COALESCE(emp.date_of_original_appointment, emp.date_hired)
                       AS anchor_date
            FROM core.step_increment_history h
            JOIN core.employees emp       ON emp.id = h.employee_id
            LEFT JOIN core.departments d  ON d.id = emp.department_id
            LEFT JOIN core.positions p    ON p.id = emp.position_id
            LEFT JOIN core.job_grades jg  ON jg.id = emp.job_grade_id
            WHERE emp.company_id = %s
        """
        params = [company_id]
        if status_filter:
            sql += ' AND h.status = %s'
            params.append(status_filter)
        sql += """
            ORDER BY h.due_date ASC, h.status ASC
            LIMIT %s
        """
        params.append(limit)
        cur.execute(sql, tuple(params))
        return cur.fetchall()


def summary(company_id: int) -> dict:
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                COUNT(*) FILTER (WHERE h.status = 'DUE'
                                 AND h.due_date <= CURRENT_DATE + INTERVAL '90 days')
                    AS due_soon,
                COUNT(*) FILTER (WHERE h.status = 'DUE'
                                 AND h.due_date <= CURRENT_DATE) AS overdue,
                COUNT(*) FILTER (WHERE h.status = 'NOTICE_SENT') AS notice_sent,
                COUNT(*) FILTER (WHERE h.status = 'APPROVED')    AS approved,
                COUNT(*) FILTER (WHERE h.status = 'RECORDED'
                                 AND h.effective_date >=
                                     CURRENT_DATE - INTERVAL '365 days') AS recorded_ytd
            FROM core.step_increment_history h
            JOIN core.employees e ON e.id = h.employee_id
            WHERE e.company_id = %s
        """, (company_id,))
        return dict(cur.fetchone())


# ══════════════════════════════════════════════════════════════════════
# Transitions
# ══════════════════════════════════════════════════════════════════════
def send_notice(increment_id: int, user_id: int, notice_path: str = None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.step_increment_history
            SET status          = 'NOTICE_SENT',
                notice_sent_at  = NOW(),
                notice_sent_by  = %s,
                notice_path     = %s,
                updated_at      = NOW()
            WHERE id = %s AND status IN ('DUE','NOTICE_SENT')
            RETURNING id, employee_id, increment_no
        """, (user_id, notice_path, increment_id))
        return cur.fetchone()


def approve(increment_id: int, user_id: int):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.step_increment_history
            SET status = 'APPROVED',
                approved_at = NOW(),
                approved_by = %s,
                updated_at = NOW()
            WHERE id = %s AND status = 'NOTICE_SENT'
            RETURNING id
        """, (user_id, increment_id))
        return cur.fetchone()


def record_effective(increment_id: int, effective_date, to_step: int = None,
                     to_salary_grade: str = None, user_id: int = None,
                     notes: str = ''):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.step_increment_history
            SET status          = 'RECORDED',
                effective_date  = %s,
                to_step         = %s,
                to_salary_grade = %s,
                notes           = %s,
                updated_at      = NOW()
            WHERE id = %s
            RETURNING id, employee_id
        """, (effective_date, to_step, to_salary_grade, notes, increment_id))
        return cur.fetchone()


def decline(increment_id: int, user_id: int, reason: str):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.step_increment_history
            SET status = 'DECLINED',
                notes = %s,
                updated_at = NOW()
            WHERE id = %s
            RETURNING id
        """, (reason, increment_id))
        return cur.fetchone()
