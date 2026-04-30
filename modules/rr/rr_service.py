"""Rewards & Recognition service — step increments, loyalty, PBB, retirement alerts."""
from datetime import date, timedelta
from services.db import get_cursor
from services import notification_service


# ---------------------------------------------------------------------------
# Step Increment Engine
# ---------------------------------------------------------------------------

def compute_step_increment_eligibility():
    """
    Scan all active employees for 3-year step increment eligibility.
    Must have >= Satisfactory IPCR (step_increment_eligible = TRUE).
    """
    with get_cursor(commit=True) as cur:
        cur.execute("""
            SELECT e.id AS employee_id, jg.grade_level AS salary_grade, e.date_hired,
                   e.first_name || ' ' || e.last_name AS full_name
            FROM core.employees e
            LEFT JOIN core.job_grades jg ON jg.id = e.job_grade_id
            WHERE e.is_active = TRUE
              AND jg.grade_level IS NOT NULL
        """)
        employees = cur.fetchall()

        processed = 0
        for emp in employees:
            # Check if already has an active step increment record
            cur.execute("""
                SELECT id, current_step, next_increment_due, eligibility_status
                FROM rewards.rwd_step_increments
                WHERE employee_id = %s
                ORDER BY created_at DESC LIMIT 1
            """, (emp['employee_id'],))
            existing = cur.fetchone()

            if existing and existing['eligibility_status'] in ('ELIGIBLE', 'PENDING_RATING'):
                continue  # already tracked

            # Determine current step and last increment date
            cur.execute("""
                SELECT step_no, effective_date
                FROM recruitment.rec_appointments
                WHERE employee_id = %s AND status = 'ATTESTED'
                ORDER BY effective_date DESC LIMIT 1
            """, (emp['employee_id'],))
            appt = cur.fetchone()

            current_step = appt['step_no'] if appt else 1
            last_inc = appt['effective_date'] if appt else emp['date_hired']
            if not last_inc:
                continue

            next_step = min(current_step + 1, 8)
            if current_step >= 8:
                continue  # already at max step

            # Check IPCR eligibility
            cur.execute("""
                SELECT id, step_increment_eligible
                FROM performance.perf_ipcr_summary
                WHERE employee_id = %s
                ORDER BY approved_at DESC NULLS LAST LIMIT 1
            """, (emp['employee_id'],))
            ipcr = cur.fetchone()

            status = 'ELIGIBLE' if (ipcr and ipcr['step_increment_eligible']) else 'PENDING_RATING'

            cur.execute("""
                INSERT INTO rewards.rwd_step_increments
                    (employee_id, current_sg, current_step, next_step,
                     last_increment_date, eligibility_status, ipcr_summary_id)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """, (emp['employee_id'], emp['salary_grade'], current_step,
                  next_step, last_inc, status,
                  ipcr['id'] if ipcr else None))
            processed += 1

        return processed


def get_step_increments(status=None):
    conditions = ['1=1']
    params = []
    if status:
        conditions.append('si.eligibility_status = %s')
        params.append(status)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT si.*,
                   e.first_name || ' ' || e.last_name AS employee_name,
                   d.name AS department_name,
                   ssl.monthly_rate AS current_rate,
                   ssl_next.monthly_rate AS next_rate
            FROM rewards.rwd_step_increments si
            JOIN core.employees e ON e.id = si.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN rewards.rwd_ssl_table ssl
                ON ssl.salary_grade = si.current_sg AND ssl.step_no = si.current_step
            LEFT JOIN rewards.rwd_ssl_table ssl_next
                ON ssl_next.salary_grade = si.current_sg AND ssl_next.step_no = si.next_step
            WHERE {' AND '.join(conditions)}
            ORDER BY si.next_increment_due NULLS LAST
        """, params)
        return cur.fetchall()


def process_step_increment(increment_id, processed_by, effective_date=None):
    """Process a step increment — update employee record and mark as PROCESSED."""
    with get_cursor(commit=True) as cur:
        cur.execute("SELECT * FROM rewards.rwd_step_increments WHERE id = %s", (increment_id,))
        si = cur.fetchone()
        if not si:
            return None

        eff_date = effective_date or date.today()

        # Update employee salary grade step (if column exists)
        cur.execute("""
            UPDATE rewards.rwd_step_increments
            SET eligibility_status = 'PROCESSED',
                processed_at = NOW(),
                processed_by = %s,
                payroll_effective_date = %s
            WHERE id = %s
        """, (processed_by, eff_date, increment_id))

        return si


# ---------------------------------------------------------------------------
# Loyalty Milestone Scanner
# ---------------------------------------------------------------------------

def scan_loyalty_milestones():
    """Daily cron: check service years for 10/15/20/25/30 anniversaries."""
    milestones = [10, 15, 20, 25, 30]
    today = date.today()

    with get_cursor(commit=True) as cur:
        cur.execute("""
            SELECT id, date_hired,
                   first_name || ' ' || last_name AS full_name
            FROM core.employees
            WHERE status = 'ACTIVE' AND date_hired IS NOT NULL
        """)
        employees = cur.fetchall()

        created = 0
        for emp in employees:
            years = (today - emp['date_hired']).days / 365.25
            for m in milestones:
                anniversary = emp['date_hired'] + timedelta(days=int(m * 365.25))
                if anniversary <= today + timedelta(days=90):  # within 90 days
                    cur.execute("""
                        INSERT INTO rewards.rwd_loyalty_milestones
                            (employee_id, service_years, eligibility_date, status)
                        VALUES (%s, %s, %s, %s)
                        ON CONFLICT (employee_id, service_years) DO NOTHING
                    """, (emp['id'], m, anniversary,
                          'ELIGIBLE' if anniversary <= today else 'UPCOMING'))
                    created += 1
        return created


def get_loyalty_milestones(status=None):
    conditions = ['1=1']
    params = []
    if status:
        conditions.append('lm.status = %s')
        params.append(status)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT lm.*,
                   e.first_name || ' ' || e.last_name AS employee_name,
                   d.name AS department_name,
                   e.date_hired
            FROM rewards.rwd_loyalty_milestones lm
            JOIN core.employees e ON e.id = lm.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            WHERE {' AND '.join(conditions)}
            ORDER BY lm.eligibility_date
        """, params)
        return cur.fetchall()


# ---------------------------------------------------------------------------
# PBB Computation
# ---------------------------------------------------------------------------

def compute_pbb(employee_id, year):
    """Cross-reference IPCR + OPCR ratings for PBB tier assignment."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            SELECT s.id, s.adjectival_rating, s.final_numerical_rating, s.pbb_eligible
            FROM performance.perf_ipcr_summary s
            JOIN performance.perf_cycles c ON c.id = s.cycle_id
            WHERE s.employee_id = %s AND EXTRACT(YEAR FROM c.period_to) = %s
            ORDER BY s.approved_at DESC LIMIT 1
        """, (employee_id, year))
        ipcr = cur.fetchone()

        if not ipcr or not ipcr['pbb_eligible']:
            tier = 'NOT_ELIGIBLE'
            amount = 0
        else:
            rating = float(ipcr['final_numerical_rating'])
            if rating >= 4.500:
                tier = 'TIER_1'
                amount = 65000
            elif rating >= 3.500:
                tier = 'TIER_2'
                amount = 57500
            elif rating >= 2.500:
                tier = 'TIER_3'
                amount = 50000
            else:
                tier = 'NOT_ELIGIBLE'
                amount = 0

        cur.execute("""
            INSERT INTO rewards.rwd_pbb_records
                (employee_id, year, ipcr_summary_id, ipcr_adjectival, pbb_tier, pbb_amount)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (employee_id, year) DO UPDATE SET
                ipcr_summary_id = EXCLUDED.ipcr_summary_id,
                ipcr_adjectival = EXCLUDED.ipcr_adjectival,
                pbb_tier        = EXCLUDED.pbb_tier,
                pbb_amount      = EXCLUDED.pbb_amount
            RETURNING id
        """, (employee_id, year, ipcr['id'] if ipcr else None,
              ipcr['adjectival_rating'] if ipcr else None, tier, amount))
        return cur.fetchone()


def get_pbb_records(year=None, tier=None):
    conditions = ['1=1']
    params = []
    if year:
        conditions.append('p.year = %s')
        params.append(year)
    if tier:
        conditions.append('p.pbb_tier = %s')
        params.append(tier)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT p.*,
                   e.first_name || ' ' || e.last_name AS employee_name,
                   d.name AS department_name
            FROM rewards.rwd_pbb_records p
            JOIN core.employees e ON e.id = p.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            WHERE {' AND '.join(conditions)}
            ORDER BY p.pbb_tier, p.pbb_amount DESC
        """, params)
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Retirement Alert Scheduler
# ---------------------------------------------------------------------------

def schedule_retirement_alerts():
    """Daily cron: compute age and schedule notices 6mo/3mo/1mo before 60/65."""
    today = date.today()
    with get_cursor(commit=True) as cur:
        cur.execute("""
            SELECT e.id, e.date_of_birth,
                   e.first_name || ' ' || e.last_name AS full_name
            FROM core.employees e
            WHERE e.is_active = TRUE AND e.date_of_birth IS NOT NULL
        """)
        employees = cur.fetchall()

        scheduled = 0
        for emp in employees:
            bd = emp['birth_date']
            for ret_age, alert_type in [(60, 'AGE_60_NOTICE'), (65, 'AGE_65_NOTICE')]:
                ret_date = bd.replace(year=bd.year + ret_age)
                if ret_date < today:
                    continue
                for months_before, notice_type in [(6, '6MO_NOTICE'), (3, '3MO_NOTICE'), (1, '1MO_NOTICE')]:
                    send_date = ret_date - timedelta(days=months_before * 30)
                    if send_date <= today + timedelta(days=7):  # within next week
                        cur.execute("""
                            INSERT INTO rewards.rwd_retirement_alerts
                                (employee_id, retirement_age, projected_retirement_date,
                                 alert_type, scheduled_send_date, recipient_ids)
                            VALUES (%s, %s, %s, %s, %s, '[]')
                            ON CONFLICT DO NOTHING
                        """, (emp['id'], ret_age, ret_date, notice_type, send_date))
                        scheduled += 1
        return scheduled


def get_retirement_notices():
    with get_cursor() as cur:
        cur.execute("""
            SELECT ra.*,
                   e.first_name || ' ' || e.last_name AS employee_name,
                   e.date_of_birth,
                   d.name AS department_name
            FROM rewards.rwd_retirement_alerts ra
            JOIN core.employees e ON e.id = ra.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            ORDER BY ra.projected_retirement_date
        """)
        return cur.fetchall()


# ---------------------------------------------------------------------------
# SSL Table Lookup
# ---------------------------------------------------------------------------

def get_ssl_table(salary_grade=None):
    conditions = ['1=1']
    params = []
    if salary_grade:
        conditions.append('s.salary_grade = %s')
        params.append(salary_grade)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT * FROM rewards.rwd_ssl_table s
            WHERE {' AND '.join(conditions)}
            ORDER BY s.salary_grade, s.step_no
        """, params)
        return cur.fetchall()
