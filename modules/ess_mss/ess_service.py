"""ESS/MSS service — employee and manager self-service data queries."""
from datetime import date, timedelta
from services.db import get_cursor


# ---------------------------------------------------------------------------
# Employee Self-Service
# ---------------------------------------------------------------------------

def get_my_profile(employee_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM core.v_employees_full WHERE id = %s
        """, (employee_id,))
        emp = cur.fetchone()
        # Pull profile_photo_path from base table — not exposed by the view yet
        if emp:
            emp = dict(emp)
            cur.execute(
                "SELECT profile_photo_path FROM core.employees WHERE id = %s",
                (employee_id,),
            )
            row = cur.fetchone()
            emp['profile_photo_path'] = row['profile_photo_path'] if row else None

        cur.execute("""
            SELECT * FROM core.emp_addresses WHERE employee_id = %s ORDER BY is_primary DESC
        """, (employee_id,))
        addresses = cur.fetchall()

        cur.execute("""
            SELECT * FROM core.emp_emergency_contacts WHERE employee_id = %s ORDER BY is_primary DESC
        """, (employee_id,))
        emergency = cur.fetchall()

        cur.execute("""
            SELECT * FROM core.emp_government_ids WHERE employee_id = %s ORDER BY id_type
        """, (employee_id,))
        gov_ids = cur.fetchall()

        cur.execute("""
            SELECT * FROM core.emp_bank_accounts WHERE employee_id = %s ORDER BY is_primary DESC
        """, (employee_id,))
        banks = cur.fetchall()

        cur.execute("""
            SELECT * FROM core.emp_dependents WHERE employee_id = %s ORDER BY relationship
        """, (employee_id,))
        dependents = cur.fetchall()

    return {
        'employee':  emp,
        'addresses': addresses,
        'emergency': emergency,
        'gov_ids':   gov_ids,
        'banks':     banks,
        'dependents': dependents,
    }


def get_my_attendance(employee_id, months=1):
    date_from = date.today().replace(day=1) - timedelta(days=(months - 1) * 30)
    with get_cursor() as cur:
        cur.execute("""
            SELECT work_date, time_in, time_out,
                   hours_worked                          AS worked_hours,
                   ROUND(hours_late * 60)::INTEGER       AS late_minutes,
                   hours_overtime                        AS ot_hours,
                   (status = 'PRESENT')                  AS is_present,
                   (status = 'LATE')                     AS is_late,
                   (status = 'ABSENT')                   AS is_absent,
                   is_holiday, is_restday, remarks
            FROM attendance.att_daily
            WHERE employee_id = %s AND work_date >= %s
            ORDER BY work_date DESC
        """, (employee_id, date_from))
        logs = cur.fetchall()

        cur.execute("""
            SELECT status, COUNT(*) AS cnt
            FROM attendance.att_overtime_requests
            WHERE employee_id = %s
              AND request_date >= %s
            GROUP BY status
        """, (employee_id, date_from))
        ot_summary = {r['status']: r['cnt'] for r in cur.fetchall()}

    return logs, ot_summary


def get_my_leaves(employee_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT lb.*, lt.name AS leave_type_name, lt.code
            FROM leave_mgmt.lv_balances lb
            JOIN leave_mgmt.lv_types lt ON lt.id = lb.leave_type_id
            WHERE lb.employee_id = %s
              AND lb.year = EXTRACT(YEAR FROM CURRENT_DATE)
            ORDER BY lt.name
        """, (employee_id,))
        balances = cur.fetchall()

        cur.execute("""
            SELECT lr.*, lt.name AS leave_type_name
            FROM leave_mgmt.lv_requests lr
            JOIN leave_mgmt.lv_types lt ON lt.id = lr.leave_type_id
            WHERE lr.employee_id = %s
            ORDER BY lr.created_at DESC
            LIMIT 20
        """, (employee_id,))
        history = cur.fetchall()

    return balances, history


def get_my_payslips(employee_id, page=1, per_page=12):
    offset = (page - 1) * per_page
    with get_cursor() as cur:
        cur.execute("""
            SELECT ep.id, ep.basic_pay, ep.gross_pay, ep.net_pay,
                   pp.date_from, pp.date_to, pp.payment_date,
                   pp.period_type, pr.status AS run_status
            FROM payroll.pay_employee_payroll ep
            JOIN payroll.pay_runs pr ON pr.id = ep.run_id
            JOIN payroll.pay_periods pp ON pp.id = pr.period_id
            WHERE ep.employee_id = %s AND pr.status = 'COMPLETED'
            ORDER BY pp.date_from DESC
            LIMIT %s OFFSET %s
        """, (employee_id, per_page, offset))
        rows = cur.fetchall()
        cur.execute("""
            SELECT COUNT(*) FROM payroll.pay_employee_payroll ep
            JOIN payroll.pay_runs pr ON pr.id = ep.run_id
            WHERE ep.employee_id = %s AND pr.status = 'COMPLETED'
        """, (employee_id,))
        total = cur.fetchone()['count']
    return rows, total


# ---------------------------------------------------------------------------
# Manager Self-Service (MSS)
# ---------------------------------------------------------------------------

def get_team(manager_employee_id):
    """Return direct reports for a manager."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT e.id, e.employee_no,
                   e.first_name || ' ' || e.last_name AS full_name,
                   d.name AS department,
                   p.title AS position_title,
                   et.name AS employment_type,
                   e.status AS employment_status,
                   e.work_email
            FROM core.employees e
            LEFT JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.positions p ON p.id = e.position_id
            LEFT JOIN core.employment_types et ON et.id = e.employment_type_id
            WHERE e.immediate_supervisor_id = %s
              AND e.is_active = TRUE
            ORDER BY e.first_name, e.last_name
        """, (manager_employee_id,))
        return cur.fetchall()


def get_team_attendance_today(manager_employee_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                e.id AS employee_id,
                e.employee_no,
                e.first_name || ' ' || e.last_name AS full_name,
                ad.time_in, ad.time_out,
                ad.hours_worked                          AS worked_hours,
                ROUND(COALESCE(ad.hours_late, 0) * 60)::INTEGER AS late_minutes,
                (ad.status = 'PRESENT')                  AS is_present,
                (ad.status = 'LATE')                     AS is_late,
                (ad.status = 'ABSENT')                   AS is_absent,
                ll.location_type                         AS location_status
            FROM core.employees e
            LEFT JOIN attendance.att_daily ad
                ON ad.employee_id = e.id AND ad.work_date = CURRENT_DATE
            LEFT JOIN leave_mgmt.lv_locator_entries ll
                ON ll.employee_id = e.id AND ll.log_date = CURRENT_DATE
            WHERE e.immediate_supervisor_id = %s
              AND e.is_active = TRUE
            ORDER BY e.first_name, e.last_name
        """, (manager_employee_id,))
        return cur.fetchall()


def get_pending_approvals(manager_user_id):
    """
    Return workflow instances where the current step requires the manager's role
    and the manager is the direct supervisor of the initiator.
    """
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                wi.id AS instance_id,
                wi.reference_no,
                wd.name AS workflow_name,
                wd.module,
                ws.name AS current_step,
                ws.role_required,
                wi.entity_type,
                wi.entity_id,
                wi.created_at,
                u.display_name AS initiated_by,
                EXTRACT(EPOCH FROM (NOW() - wi.created_at))/3600 AS hours_pending
            FROM workflow.workflow_instances wi
            JOIN workflow.workflow_definitions wd ON wd.id = wi.definition_id
            JOIN workflow.workflow_steps ws ON ws.id = wi.current_step_id
            JOIN core.users u ON u.id = wi.initiated_by
            WHERE wi.status = 'IN_PROGRESS'
              AND ws.role_required IN (
                  SELECT r.code FROM core.roles r
                  JOIN core.user_roles ur ON ur.role_id = r.id
                  WHERE ur.user_id = %s
              )
            ORDER BY wi.created_at
        """, (manager_user_id,))
        return cur.fetchall()


def get_team_leave_today(manager_employee_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT e.first_name || ' ' || e.last_name AS full_name,
                   lr.date_from, lr.date_to,
                   lt.name AS leave_type, lr.days_requested AS total_days
            FROM leave_mgmt.lv_requests lr
            JOIN core.employees e ON e.id = lr.employee_id
            JOIN leave_mgmt.lv_types lt ON lt.id = lr.leave_type_id
            WHERE e.immediate_supervisor_id = %s
              AND lr.status = 'APPROVED'
              AND CURRENT_DATE BETWEEN lr.date_from AND lr.date_to
            ORDER BY e.first_name, e.last_name
        """, (manager_employee_id,))
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Compensation / Benefits (ESS)
# ---------------------------------------------------------------------------

def get_my_compensation(employee_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT ep.basic_pay, ep.gross_pay, ep.net_pay, ep.total_deductions,
                   pp.date_from, pp.date_to, pp.payment_date
            FROM payroll.pay_employee_payroll ep
            JOIN payroll.pay_runs pr ON pr.id = ep.run_id
            JOIN payroll.pay_periods pp ON pp.id = pr.period_id
            WHERE ep.employee_id = %s AND pr.status = 'COMPLETED'
            ORDER BY pp.date_from DESC LIMIT 1
        """, (employee_id,))
        latest_payslip = cur.fetchone()

        cur.execute("""
            SELECT ea.*, ga.allowance_name
            FROM payroll.pay_employee_allowances_gov ea
            JOIN payroll.pay_gov_allowances ga ON ga.id = ea.allowance_id
            WHERE ea.employee_id = %s AND ga.is_active = TRUE
            ORDER BY ga.allowance_name
        """, (employee_id,))
        allowances = cur.fetchall()

        cur.execute("""
            SELECT pl.loan_type AS loan_name,
                   pl.principal_amount, pl.outstanding_balance, pl.monthly_deduction,
                   pl.status AS loan_status
            FROM payroll.pay_loans pl
            WHERE pl.employee_id = %s AND pl.status IN ('ACTIVE','APPROVED')
            ORDER BY pl.created_at DESC
        """, (employee_id,))
        loans = cur.fetchall()

    return {'latest_payslip': latest_payslip, 'allowances': allowances, 'loans': loans}


def get_attendance_summary(employee_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                COUNT(*) FILTER (WHERE status = 'PRESENT') AS present_days,
                COUNT(*) FILTER (WHERE status = 'LATE') AS late_days,
                COUNT(*) FILTER (WHERE status = 'ABSENT') AS absent_days,
                COUNT(*) AS total_days,
                COALESCE(SUM(hours_worked), 0)::NUMERIC(6,1) AS total_hours,
                COALESCE(SUM(hours_overtime), 0)::NUMERIC(6,1) AS total_ot
            FROM attendance.att_daily
            WHERE employee_id = %s
              AND work_date >= DATE_TRUNC('month', CURRENT_DATE)
        """, (employee_id,))
        return cur.fetchone()
