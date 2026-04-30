"""Payroll service — periods, runs, payslips, loans, remittances, 13th month."""
from datetime import date
from services.db import get_cursor


# ── Pay Periods ─────────────────────────────────────────────────

def get_pay_periods(company_id=None, status=None, page=1, per_page=30):
    conditions = ['1=1']
    params = []
    if company_id:
        conditions.append('pp.company_id = %s')
        params.append(company_id)
    if status:
        conditions.append('pp.status = %s')
        params.append(status)
    offset = (page - 1) * per_page
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT pp.*
            FROM payroll.pay_periods pp
            WHERE {' AND '.join(conditions)}
            ORDER BY pp.date_from DESC
            LIMIT %s OFFSET %s
        """, params + [per_page, offset])
        rows = cur.fetchall()
        cur.execute(f"""
            SELECT COUNT(*) FROM payroll.pay_periods pp
            WHERE {' AND '.join(conditions)}
        """, params)
        total = cur.fetchone()['count']
    return rows, total


def get_current_period(company_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM payroll.pay_periods
            WHERE company_id = %s AND status IN ('OPEN', 'PROCESSING')
            ORDER BY date_from DESC LIMIT 1
        """, (company_id,))
        return cur.fetchone()


def create_pay_period(company_id, period_code, period_type, date_from, date_to,
                      payment_date=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO payroll.pay_periods
                (company_id, period_code, period_type, date_from, date_to, payment_date)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (company_id, period_code, period_type, date_from, date_to, payment_date))
        return cur.fetchone()['id']


def close_pay_period(period_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE payroll.pay_periods SET status = 'CLOSED' WHERE id = %s
        """, (period_id,))
    return {'ok': True, 'message': 'Period closed.'}


# ── Pay Runs ────────────────────────────────────────────────────

def get_pay_runs(company_id=None, status=None, page=1, per_page=20):
    conditions = ['1=1']
    params = []
    if company_id:
        conditions.append('pp.company_id = %s')
        params.append(company_id)
    if status:
        conditions.append('pr.status = %s')
        params.append(status)
    offset = (page - 1) * per_page
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT pr.*, pp.date_from AS cutoff_start, pp.date_to AS cutoff_end,
                   pp.payment_date AS pay_date, pp.period_type AS cutoff_type,
                   u.display_name AS computed_by_name,
                   pr.total_employees AS employee_count
            FROM payroll.pay_runs pr
            JOIN payroll.pay_periods pp ON pp.id = pr.period_id
            LEFT JOIN core.users u ON u.id = pr.computed_by
            WHERE {' AND '.join(conditions)}
            ORDER BY pr.created_at DESC
            LIMIT %s OFFSET %s
        """, params + [per_page, offset])
        rows = cur.fetchall()
        cur.execute(f"""
            SELECT COUNT(*) FROM payroll.pay_runs pr
            JOIN payroll.pay_periods pp ON pp.id = pr.period_id
            WHERE {' AND '.join(conditions)}
        """, params)
        total = cur.fetchone()['count']
    return rows, total


def get_run_detail(run_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT pr.*, pp.date_from AS cutoff_start, pp.date_to AS cutoff_end,
                   pp.payment_date, pp.period_type, pp.company_id
            FROM payroll.pay_runs pr
            JOIN payroll.pay_periods pp ON pp.id = pr.period_id
            WHERE pr.id = %s
        """, (run_id,))
        run = cur.fetchone()
        cur.execute("""
            SELECT ep.*, e.employee_no, e.full_name,
                   d.name AS department, p.title AS position_title
            FROM payroll.pay_employee_payroll ep
            JOIN core.v_employees_full e ON e.id = ep.employee_id
            JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.positions p ON p.id = e.position_id
            WHERE ep.run_id = %s
            ORDER BY d.name, e.full_name
        """, (run_id,))
        employees = cur.fetchall()
    return run, employees


def create_pay_run(period_id, created_by, notes=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO payroll.pay_runs
                (period_id, status, computed_by, remarks)
            VALUES (%s, 'DRAFT', %s, %s)
            RETURNING id
        """, (period_id, created_by, notes))
        return cur.fetchone()['id']


def compute_pay_run(run_id, company_id, user_id):
    """Invoke computation engine for a pay run."""
    with get_cursor() as cur:
        cur.execute("SELECT period_id FROM payroll.pay_runs WHERE id = %s", (run_id,))
        run = cur.fetchone()
    if not run:
        return {'ok': False, 'message': 'Pay run not found.'}

    from services.computation_engine import PayrollEngine
    engine = PayrollEngine(company_id, run['period_id'])
    result = engine.compute_run(run_id)

    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE payroll.pay_runs SET computed_by = %s, computed_at = NOW()
            WHERE id = %s
        """, (user_id, run_id))

    return {
        'ok': True,
        'message': f"Computed {result['computed']} employees. {len(result['errors'])} errors.",
        'detail': result,
    }


def action_pay_run(run_id, action_code, performed_by, comments=None):
    status_map = {
        'SUBMIT': 'SUBMITTED',
        'APPROVE': 'APPROVED',
        'REJECT': 'REJECTED',
        'COMPLETE': 'COMPLETED',
        'REOPEN': 'DRAFT',
    }
    new_status = status_map.get(action_code.upper())
    if not new_status:
        return {'ok': False, 'message': f'Unknown action: {action_code}'}

    with get_cursor(commit=True) as cur:
        cur.execute("SELECT status FROM payroll.pay_runs WHERE id = %s", (run_id,))
        run = cur.fetchone()
        if not run:
            return {'ok': False, 'message': 'Pay run not found.'}

        updates = ['status = %s']
        params = [new_status]

        if new_status == 'APPROVED':
            updates.append('approved_by = %s')
            updates.append('approved_at = NOW()')
            params.append(performed_by)
        elif new_status == 'COMPLETED':
            updates.append('posted_by = %s')
            updates.append('posted_at = NOW()')
            params.append(performed_by)

        if comments:
            updates.append('remarks = %s')
            params.append(comments)

        params.append(run_id)
        cur.execute(f"""
            UPDATE payroll.pay_runs SET {', '.join(updates)} WHERE id = %s
        """, params)

    return {'ok': True, 'message': f'Pay run {new_status.lower()}.'}


# ── Payslips ────────────────────────────────────────────────────

def get_payslips(employee_id, page=1, per_page=20):
    offset = (page - 1) * per_page
    with get_cursor() as cur:
        cur.execute("""
            SELECT ep.id, ep.basic_pay, ep.gross_pay, ep.net_pay,
                   pp.date_from, pp.date_to, pp.payment_date,
                   pp.period_type, pr.status AS run_status
            FROM payroll.pay_employee_payroll ep
            JOIN payroll.pay_runs pr ON pr.id = ep.run_id
            JOIN payroll.pay_periods pp ON pp.id = pr.period_id
            WHERE ep.employee_id = %s
            ORDER BY pp.date_from DESC
            LIMIT %s OFFSET %s
        """, (employee_id, per_page, offset))
        rows = cur.fetchall()
        cur.execute("""
            SELECT COUNT(*) FROM payroll.pay_employee_payroll WHERE employee_id = %s
        """, (employee_id,))
        total = cur.fetchone()['count']
    return rows, total


def get_payslip_detail(payslip_id, employee_id=None):
    with get_cursor() as cur:
        if employee_id:
            cur.execute("""
                SELECT ep.*, e.employee_no, e.full_name,
                       d.name AS department, p.title AS position_title,
                       pp.date_from AS cutoff_start, pp.date_to AS cutoff_end,
                       pp.payment_date, pp.period_type
                FROM payroll.pay_employee_payroll ep
                JOIN core.v_employees_full e ON e.id = ep.employee_id
                JOIN core.departments d ON d.id = e.department_id
                LEFT JOIN core.positions p ON p.id = e.position_id
                JOIN payroll.pay_runs pr ON pr.id = ep.run_id
                JOIN payroll.pay_periods pp ON pp.id = pr.period_id
                WHERE ep.id = %s AND ep.employee_id = %s
            """, (payslip_id, employee_id))
        else:
            cur.execute("""
                SELECT ep.*, e.employee_no, e.full_name,
                       d.name AS department, p.title AS position_title,
                       pp.date_from AS cutoff_start, pp.date_to AS cutoff_end,
                       pp.payment_date, pp.period_type
                FROM payroll.pay_employee_payroll ep
                JOIN core.v_employees_full e ON e.id = ep.employee_id
                JOIN core.departments d ON d.id = e.department_id
                LEFT JOIN core.positions p ON p.id = e.position_id
                JOIN payroll.pay_runs pr ON pr.id = ep.run_id
                JOIN payroll.pay_periods pp ON pp.id = pr.period_id
                WHERE ep.id = %s
            """, (payslip_id,))
        return cur.fetchone()


# ── Loans ───────────────────────────────────────────────────────

def get_loans(company_id=None, employee_id=None, status=None, page=1, per_page=30):
    conditions = ['1=1']
    params = []
    if company_id:
        conditions.append('e.company_id = %s')
        params.append(company_id)
    if employee_id:
        conditions.append('pl.employee_id = %s')
        params.append(employee_id)
    if status:
        conditions.append('pl.status = %s')
        params.append(status)
    offset = (page - 1) * per_page
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT pl.*, e.employee_no, e.full_name, d.name AS department
            FROM payroll.pay_loans pl
            JOIN core.v_employees_full e ON e.id = pl.employee_id
            JOIN core.departments d ON d.id = e.department_id
            WHERE {' AND '.join(conditions)}
            ORDER BY pl.created_at DESC
            LIMIT %s OFFSET %s
        """, params + [per_page, offset])
        rows = cur.fetchall()
        cur.execute(f"""
            SELECT COUNT(*) FROM payroll.pay_loans pl
            JOIN core.v_employees_full e ON e.id = pl.employee_id
            WHERE {' AND '.join(conditions)}
        """, params)
        total = cur.fetchone()['count']
    return rows, total


def get_loan_detail(loan_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT pl.*, e.employee_no, e.full_name, d.name AS department
            FROM payroll.pay_loans pl
            JOIN core.v_employees_full e ON e.id = pl.employee_id
            JOIN core.departments d ON d.id = e.department_id
            WHERE pl.id = %s
        """, (loan_id,))
        loan = cur.fetchone()
        cur.execute("""
            SELECT * FROM payroll.pay_loan_payments
            WHERE loan_id = %s ORDER BY payment_date DESC
        """, (loan_id,))
        payments = cur.fetchall()
    return loan, payments


def apply_loan(employee_id, loan_type, principal, monthly_deduction,
               total_months, start_date, purpose, submitted_by):
    import random, string
    ref_no = 'LN-' + ''.join(random.choices(string.digits, k=6))
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO payroll.pay_loans
                (employee_id, loan_type, reference_no, principal_amount,
                 outstanding_balance, monthly_deduction, total_months,
                 start_date, status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'PENDING')
            RETURNING id
        """, (employee_id, loan_type.upper(), ref_no, principal, principal,
              monthly_deduction, total_months, start_date))
        return cur.fetchone()['id']


def approve_loan(loan_id, approved_by):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE payroll.pay_loans
            SET status = 'ACTIVE', approved_by = %s, approved_at = NOW()
            WHERE id = %s
        """, (approved_by, loan_id))
    return {'ok': True, 'message': 'Loan approved and activated.'}


# ── Payroll Register ────────────────────────────────────────────

def get_payroll_register(run_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT e.employee_no, e.full_name, d.name AS department,
                   ep.basic_pay, ep.ot_pay, ep.holiday_pay, ep.night_diff_pay,
                   ep.allowances_total, ep.gross_pay,
                   ep.sss_ee, ep.philhealth_ee, ep.pagibig_ee, ep.tax_withheld,
                   ep.loan_deductions, ep.other_deductions,
                   ep.total_deductions, ep.net_pay
            FROM payroll.pay_employee_payroll ep
            JOIN core.v_employees_full e ON e.id = ep.employee_id
            JOIN core.departments d ON d.id = e.department_id
            WHERE ep.run_id = %s
            ORDER BY d.name, e.full_name
        """, (run_id,))
        return cur.fetchall()


# ── Remittances ─────────────────────────────────────────────────

def get_remittances(run_id=None, company_id=None):
    conditions = ['1=1']
    params = []
    if run_id:
        conditions.append('gr.run_id = %s')
        params.append(run_id)
    if company_id:
        conditions.append('pp.company_id = %s')
        params.append(company_id)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT gr.*, pr.id AS run_number,
                   pp.date_from AS cutoff_start, pp.date_to AS cutoff_end
            FROM payroll.pay_government_remittances gr
            JOIN payroll.pay_runs pr ON pr.id = gr.run_id
            JOIN payroll.pay_periods pp ON pp.id = pr.period_id
            WHERE {' AND '.join(conditions)}
            ORDER BY gr.run_id DESC, gr.agency
        """, params)
        return cur.fetchall()


# ── 13th Month ──────────────────────────────────────────────────

def get_13th_month(company_id, year=None):
    year = year or date.today().year
    with get_cursor() as cur:
        cur.execute("""
            SELECT tm.*, e.employee_no, e.full_name, d.name AS department
            FROM payroll.pay_13th_month tm
            JOIN core.v_employees_full e ON e.id = tm.employee_id
            JOIN core.departments d ON d.id = e.department_id
            WHERE e.company_id = %s AND tm.year = %s
            ORDER BY d.name, e.full_name
        """, (company_id, year))
        return cur.fetchall()


def compute_13th_month(company_id, year):
    """Compute 13th month pay: total_basic / 12."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            SELECT e.id AS employee_id,
                   COALESCE(SUM(ep.basic_pay), 0) AS total_basic,
                   COUNT(DISTINCT pr.period_id) AS periods_count
            FROM core.v_employees_full e
            JOIN payroll.pay_employee_payroll ep ON ep.employee_id = e.id
            JOIN payroll.pay_runs pr ON pr.id = ep.run_id
            JOIN payroll.pay_periods pp ON pp.id = pr.period_id
            WHERE e.company_id = %s AND e.is_active = TRUE
              AND EXTRACT(YEAR FROM pp.date_from) = %s
              AND pr.status IN ('APPROVED', 'COMPLETED')
            GROUP BY e.id
        """, (company_id, year))
        rows = cur.fetchall()

        computed = 0
        for row in rows:
            total_basic = float(row['total_basic'])
            months_worked = min(float(row['periods_count']) / 2, 12)  # semi-monthly = /2
            gross_13th = round(total_basic / 12, 2) if total_basic > 0 else 0
            de_minimis = 90000
            taxable = max(gross_13th - de_minimis, 0)

            cur.execute("""
                INSERT INTO payroll.pay_13th_month
                    (employee_id, year, total_basic_pay, months_worked,
                     gross_13th, tax_exempt_amt, taxable_amt, net_13th)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (employee_id, year) DO UPDATE
                SET total_basic_pay = EXCLUDED.total_basic_pay,
                    months_worked = EXCLUDED.months_worked,
                    gross_13th = EXCLUDED.gross_13th,
                    taxable_amt = EXCLUDED.taxable_amt,
                    net_13th = EXCLUDED.net_13th
            """, (row['employee_id'], year, total_basic, months_worked,
                  gross_13th, de_minimis, taxable, gross_13th))
            computed += 1

    return {'ok': True, 'message': f'Computed 13th month for {computed} employees.'}
