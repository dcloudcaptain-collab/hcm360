"""
Retirement Monitoring — age-based eligibility tracking.

Defaults (per Philippine government / LGU norms):
    * Early retirement eligible at age 60
    * Mandatory retirement at age 65
    * Notice generated N months in advance (default 6)

Generates three notice artifacts per retiring employee:
    1. HR notice
    2. Employee notice
    3. Finance (Accounting / Budget / Payroll) notice
"""
import calendar
from datetime import date, timedelta

from services.db import get_cursor


def _add_months(d: date, months: int) -> date:
    """Add N months to a date using stdlib only (handles month-end rollover)."""
    total = d.month - 1 + months
    year = d.year + total // 12
    month = total % 12 + 1
    day = min(d.day, calendar.monthrange(year, month)[1])
    return date(year, month, day)


# ══════════════════════════════════════════════════════════════════════
# Rules
# ══════════════════════════════════════════════════════════════════════
DEFAULT_RULES = {
    'early_retire_age': 60,
    'mandatory_retire_age': 65,
    'notice_lead_months': 6,
    'early_retire_benefit_years': 15,
}


def get_rules(company_id: int) -> dict:
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM core.retirement_rules WHERE company_id = %s
        """, (company_id,))
        row = cur.fetchone()
        if row:
            return dict(row)
    return {'company_id': company_id, **DEFAULT_RULES}


def save_rules(company_id: int, rules: dict, updated_by: int):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO core.retirement_rules
                (company_id, early_retire_age, mandatory_retire_age,
                 notice_lead_months, early_retire_benefit_years,
                 updated_by, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, NOW())
            ON CONFLICT (company_id) DO UPDATE SET
                early_retire_age          = EXCLUDED.early_retire_age,
                mandatory_retire_age      = EXCLUDED.mandatory_retire_age,
                notice_lead_months        = EXCLUDED.notice_lead_months,
                early_retire_benefit_years= EXCLUDED.early_retire_benefit_years,
                updated_by                = EXCLUDED.updated_by,
                updated_at                = NOW()
        """, (
            company_id,
            int(rules.get('early_retire_age', 60)),
            int(rules.get('mandatory_retire_age', 65)),
            int(rules.get('notice_lead_months', 6)),
            int(rules.get('early_retire_benefit_years', 15)),
            updated_by,
        ))


# ══════════════════════════════════════════════════════════════════════
# Rule Profiles (multi-profile config — Migration 63)
# ══════════════════════════════════════════════════════════════════════
def list_profiles(company_id: int) -> list:
    with get_cursor() as cur:
        cur.execute("""
            SELECT p.*,
                   et.name AS employment_type_name,
                   d.name  AS department_name
              FROM core.retirement_rule_profiles p
              LEFT JOIN core.employment_types et ON et.id = p.employment_type_id
              LEFT JOIN core.departments d       ON d.id = p.department_id
             WHERE p.company_id = %s
             ORDER BY p.is_default DESC, p.is_active DESC, p.name
        """, (company_id,))
        return cur.fetchall()


def get_profile(profile_id: int) -> dict:
    with get_cursor() as cur:
        cur.execute("SELECT * FROM core.retirement_rule_profiles WHERE id = %s",
                    (profile_id,))
        return cur.fetchone()


def save_profile(company_id: int, data: dict, user_id: int) -> int:
    """Create or update a named retirement rule profile.
    Pass `id` to update, omit to create new. Returns the profile_id."""
    pid = data.get('id')
    name = (data.get('name') or '').strip()
    if not name:
        raise ValueError('Profile name is required')

    vals = dict(
        company_id=company_id,
        name=name,
        description=data.get('description') or None,
        employment_type_id=int(data['employment_type_id']) if data.get('employment_type_id') else None,
        department_id=int(data['department_id']) if data.get('department_id') else None,
        early_retire_age=int(data.get('early_retire_age', 60)),
        mandatory_retire_age=int(data.get('mandatory_retire_age', 65)),
        notice_lead_months=int(data.get('notice_lead_months', 6)),
        early_retire_benefit_years=int(data.get('early_retire_benefit_years', 15)),
        is_default=bool(data.get('is_default')),
        is_active=bool(data.get('is_active', True)),
    )

    with get_cursor(commit=True) as cur:
        # Only one default per company
        if vals['is_default']:
            cur.execute("""
                UPDATE core.retirement_rule_profiles
                   SET is_default = FALSE, updated_at = NOW()
                 WHERE company_id = %s AND is_default = TRUE
            """, (company_id,))
        if pid:
            cur.execute("""
                UPDATE core.retirement_rule_profiles SET
                  name=%(name)s, description=%(description)s,
                  employment_type_id=%(employment_type_id)s,
                  department_id=%(department_id)s,
                  early_retire_age=%(early_retire_age)s,
                  mandatory_retire_age=%(mandatory_retire_age)s,
                  notice_lead_months=%(notice_lead_months)s,
                  early_retire_benefit_years=%(early_retire_benefit_years)s,
                  is_default=%(is_default)s, is_active=%(is_active)s,
                  updated_at=NOW()
                 WHERE id = %(id)s AND company_id = %(company_id)s
            """, {**vals, 'id': int(pid)})
            return int(pid)
        else:
            cur.execute("""
                INSERT INTO core.retirement_rule_profiles
                    (company_id, name, description, employment_type_id, department_id,
                     early_retire_age, mandatory_retire_age, notice_lead_months,
                     early_retire_benefit_years, is_default, is_active, created_by)
                VALUES (%(company_id)s, %(name)s, %(description)s,
                        %(employment_type_id)s, %(department_id)s,
                        %(early_retire_age)s, %(mandatory_retire_age)s,
                        %(notice_lead_months)s, %(early_retire_benefit_years)s,
                        %(is_default)s, %(is_active)s, %(user_id)s)
                RETURNING id
            """, {**vals, 'user_id': user_id})
            return cur.fetchone()['id']


def delete_profile(profile_id: int, company_id: int):
    """Soft-delete (deactivate) a rule profile. Never deletes the default."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.retirement_rule_profiles
               SET is_active = FALSE, updated_at = NOW()
             WHERE id = %s AND company_id = %s AND is_default = FALSE
        """, (profile_id, company_id))


# ══════════════════════════════════════════════════════════════════════
# Scanner
# ══════════════════════════════════════════════════════════════════════
def scan(company_id: int) -> dict:
    """
    Identify employees turning the early or mandatory retirement age within
    the notice lead window. Idempotent — uses ON CONFLICT.
    """
    rules = get_rules(company_id)
    early = rules['early_retire_age']
    mandatory = rules['mandatory_retire_age']
    lead_months = rules.get('notice_lead_months') or 6

    today = date.today()
    # Look ahead (lead_months months) plus one year back to catch recent
    # eligibility that hasn't been recorded.
    horizon = _add_months(today, lead_months)
    lookback = _add_months(today, -12)

    inserted = 0
    with get_cursor(commit=True) as cur:
        # Early retirement (age 60) — employees reaching 60 in the window
        cur.execute("""
            INSERT INTO core.retirement_tracking
                (employee_id, eligibility_type, eligible_date, status)
            SELECT e.id, 'EARLY',
                   (e.date_of_birth + (%s || ' years')::interval)::date,
                   'UPCOMING'
            FROM core.employees e
            WHERE e.company_id = %s
              AND e.status = 'ACTIVE'
              AND e.date_of_birth IS NOT NULL
              AND (e.date_of_birth + (%s || ' years')::interval)::date
                    BETWEEN %s AND %s
            ON CONFLICT (employee_id, eligibility_type) DO NOTHING
            RETURNING id
        """, (early, company_id, early, lookback, horizon))
        inserted += cur.rowcount

        # Mandatory retirement (age 65)
        cur.execute("""
            INSERT INTO core.retirement_tracking
                (employee_id, eligibility_type, eligible_date, status)
            SELECT e.id, 'MANDATORY',
                   (e.date_of_birth + (%s || ' years')::interval)::date,
                   'UPCOMING'
            FROM core.employees e
            WHERE e.company_id = %s
              AND e.status = 'ACTIVE'
              AND e.date_of_birth IS NOT NULL
              AND (e.date_of_birth + (%s || ' years')::interval)::date
                    BETWEEN %s AND %s
            ON CONFLICT (employee_id, eligibility_type) DO NOTHING
            RETURNING id
        """, (mandatory, company_id, mandatory, lookback, horizon))
        inserted += cur.rowcount

    return {
        'inserted': inserted,
        'early_age': early,
        'mandatory_age': mandatory,
        'horizon': horizon.isoformat(),
    }


# ══════════════════════════════════════════════════════════════════════
# Queries
# ══════════════════════════════════════════════════════════════════════
def list_items(company_id: int, status_filter: str = None,
               eligibility_filter: str = None, limit: int = 200) -> list:
    with get_cursor() as cur:
        sql = """
            SELECT t.id, t.employee_id, t.eligibility_type, t.eligible_date,
                   t.retirement_date, t.status, t.notice_sent_at,
                   t.acknowledged_at,
                   e.employee_no, e.full_name, e.gender, e.date_of_birth,
                   d.name AS department_name, p.title AS position_title,
                   EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.date_of_birth))::int AS age_now,
                   EXTRACT(YEAR FROM AGE(t.eligible_date, e.date_of_birth))::int AS eligibility_age
            FROM core.retirement_tracking t
            JOIN core.v_employees_full e ON e.id = t.employee_id
            LEFT JOIN core.departments d  ON d.id = e.department_id
            LEFT JOIN core.positions p    ON p.id = e.position_id
            WHERE e.company_id = %s
        """
        params = [company_id]
        if status_filter:
            sql += ' AND t.status = %s'
            params.append(status_filter)
        if eligibility_filter:
            sql += ' AND t.eligibility_type = %s'
            params.append(eligibility_filter)
        sql += """
            ORDER BY t.eligible_date ASC
            LIMIT %s
        """
        params.append(limit)
        cur.execute(sql, tuple(params))
        return cur.fetchall()


def summary(company_id: int) -> dict:
    with get_cursor() as cur:
        # Counts by status + gender breakdown
        cur.execute("""
            SELECT
                COUNT(*) FILTER (WHERE t.status = 'UPCOMING'
                                 AND t.eligibility_type = 'EARLY')      AS early_upcoming,
                COUNT(*) FILTER (WHERE t.status = 'UPCOMING'
                                 AND t.eligibility_type = 'MANDATORY')  AS mandatory_upcoming,
                COUNT(*) FILTER (WHERE t.status = 'NOTICE_SENT')        AS notices_sent,
                COUNT(*) FILTER (WHERE t.status = 'RETIRED'
                                 AND t.retirement_date >=
                                     CURRENT_DATE - INTERVAL '365 days') AS retired_ytd,
                COUNT(*) FILTER (WHERE e.gender = 'MALE'
                                 AND t.status IN ('UPCOMING','NOTICE_SENT'))   AS male_pending,
                COUNT(*) FILTER (WHERE e.gender = 'FEMALE'
                                 AND t.status IN ('UPCOMING','NOTICE_SENT'))   AS female_pending
            FROM core.retirement_tracking t
            JOIN core.employees e ON e.id = t.employee_id
            WHERE e.company_id = %s
        """, (company_id,))
        return dict(cur.fetchone())


# ══════════════════════════════════════════════════════════════════════
# Transitions
# ══════════════════════════════════════════════════════════════════════
def send_notice(tracking_id: int, user_id: int,
                hr_path: str = None, emp_path: str = None,
                finance_path: str = None):
    """
    Mark notice as sent with paths to the three recipient PDFs.
    In a real deployment these would also enqueue notifications for each
    recipient (HR user, Employee, Finance officer).
    """
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.retirement_tracking
            SET status               = 'NOTICE_SENT',
                notice_sent_at       = NOW(),
                notice_sent_by       = %s,
                notice_hr_path       = %s,
                notice_employee_path = %s,
                notice_finance_path  = %s,
                updated_at           = NOW()
            WHERE id = %s
            RETURNING id, employee_id, eligibility_type
        """, (user_id, hr_path, emp_path, finance_path, tracking_id))
        return cur.fetchone()


def acknowledge(tracking_id: int, user_id: int):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.retirement_tracking
            SET status = 'ACKNOWLEDGED',
                acknowledged_at = NOW(),
                updated_at = NOW()
            WHERE id = %s
            RETURNING id
        """, (tracking_id,))
        return cur.fetchone()


def set_retirement_date(tracking_id: int, retirement_date, user_id: int):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.retirement_tracking
            SET status = 'SCHEDULED',
                retirement_date = %s,
                updated_at = NOW()
            WHERE id = %s
            RETURNING id, employee_id
        """, (retirement_date, tracking_id))
        return cur.fetchone()


def mark_retired(tracking_id: int, user_id: int):
    """Also set the employee's status to RETIRED."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.retirement_tracking
            SET status = 'RETIRED',
                updated_at = NOW()
            WHERE id = %s
            RETURNING employee_id, retirement_date
        """, (tracking_id,))
        row = cur.fetchone()
        if row and row['employee_id']:
            cur.execute("""
                UPDATE core.employees
                SET status = 'RETIRED', updated_at = NOW()
                WHERE id = %s
            """, (row['employee_id'],))
        return row
