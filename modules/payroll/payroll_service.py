"""Payroll module service — pay runs, payslips, loans, government remittances."""
from datetime import date
from services.db import get_cursor
from services import workflow_service, notification_service


# ---------------------------------------------------------------------------
# Pay Periods
# ---------------------------------------------------------------------------

def get_pay_periods(status=None):
    with get_cursor() as cur:
        if status:
            cur.execute("""
                SELECT * FROM payroll.pay_periods
                WHERE status = %s ORDER BY date_from DESC
            """, (status,))
        else:
            cur.execute("""
                SELECT * FROM payroll.pay_periods ORDER BY date_from DESC
            """)
        return cur.fetchall()


def get_current_period():
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM payroll.pay_periods
            WHERE status IN ('OPEN', 'PROCESSING')
            ORDER BY date_from DESC LIMIT 1
        """)
        return cur.fetchone()


# ---------------------------------------------------------------------------
# Pay Runs
# ---------------------------------------------------------------------------

def get_pay_runs(status=None, page=1, per_page=20):
    conditions = ['1=1']
    params     = []
    if status:
        conditions.append('pr.status = %s')
        params.append(status)
    offset = (page - 1) * per_page
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT pr.*, pp.date_from, pp.date_to, pp.payment_date,
                   u.display_name AS computed_by_name,
                   COUNT(ep.id) AS employee_count,
                   SUM(ep.gross_pay) AS total_gross,
                   SUM(ep.net_pay) AS total_net
            FROM payroll.pay_runs pr
            JOIN payroll.pay_periods pp ON pp.id = pr.period_id
            LEFT JOIN core.users u ON u.id = pr.computed_by
            LEFT JOIN payroll.pay_employee_payroll ep ON ep.run_id = pr.id
            WHERE {' AND '.join(conditions)}
            GROUP BY pr.id, pp.date_from, pp.date_to, pp.payment_date, u.display_name
            ORDER BY pr.created_at DESC
            LIMIT %s OFFSET %s
        """, params + [per_page, offset])
        rows = cur.fetchall()
        cur.execute(f"""
            SELECT COUNT(*) FROM payroll.pay_runs pr
            WHERE {' AND '.join(conditions)}
        """, params)
        total = cur.fetchone()['count']
    return rows, total


def get_run_detail(run_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT pr.*, pp.date_from, pp.date_to, pp.payment_date,
                   pp.period_type
            FROM payroll.pay_runs pr
            JOIN payroll.pay_periods pp ON pp.id = pr.period_id
            WHERE pr.id = %s
        """, (run_id,))
        run = cur.fetchone()
        cur.execute("""
            SELECT ep.*, e.employee_no, e.full_name, d.name AS department,
                   p.title AS position_title
            FROM payroll.pay_employee_payroll ep
            JOIN core.v_employees_full e   ON e.id = ep.employee_id
            JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.positions p ON p.id = e.position_id
            WHERE ep.run_id = %s
            ORDER BY d.name, e.full_name
        """, (run_id,))
        employees = cur.fetchall()
    return run, employees


def create_pay_run(pay_period_id, created_by, notes=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO payroll.pay_runs
                (period_id, status, computed_by, remarks)
            VALUES (%s, 'DRAFT', %s, %s)
            RETURNING id
        """, (pay_period_id, created_by, notes))
        run_id = cur.fetchone()['id']

    instance_id = workflow_service.create_instance(
        definition_code='PAYROLL_APPROVAL',
        module='payroll',
        entity_type='pay_runs',
        entity_id=run_id,
        initiated_by=created_by,
        reference_no=f'PAY-{run_id:05d}',
    )
    if instance_id:
        with get_cursor(commit=True) as cur:
            cur.execute("""
                UPDATE payroll.pay_runs
                SET workflow_instance_id = %s WHERE id = %s
            """, (instance_id, run_id))

    return run_id


def action_pay_run(run_id, action_code, performed_by, comments=None):
    with get_cursor() as cur:
        cur.execute("""
            SELECT workflow_instance_id, status FROM payroll.pay_runs WHERE id = %s
        """, (run_id,))
        run = cur.fetchone()

    if not run:
        return {'ok': False, 'message': 'Pay run not found.'}

    result = workflow_service.execute_action(
        run['workflow_instance_id'], action_code, performed_by, comments
    )
    if not result['ok']:
        return result

    status_map = {
        'SUBMIT':  'SUBMITTED',
        'APPROVE': 'APPROVED',
        'PROCESS': 'PROCESSING',
        'COMPLETE': 'COMPLETED',
        'REJECT':  'REJECTED',
    }
    new_status = status_map.get(action_code.upper(), run['status'])

    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE payroll.pay_runs SET status = %s WHERE id = %s
        """, (new_status, run_id))

        if new_status == 'COMPLETED':
            notification_service.notify(
                user_id=performed_by,
                event_type='PAYROLL_COMPLETED',
                payload={'run_id': run_id},
            )

    return result


# ---------------------------------------------------------------------------
# Payroll Adjustments
# ---------------------------------------------------------------------------

def get_adjustments(run_id):
    """Return all adjustments for a pay run, grouped with employee info."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT pa.*, e.employee_no, e.full_name, d.name AS department,
                   u.display_name AS applied_by_name
            FROM payroll.pay_adjustments pa
            JOIN core.v_employees_full e ON e.id = pa.employee_id
            JOIN core.departments d      ON d.id = e.department_id
            JOIN core.users u            ON u.id = pa.applied_by
            WHERE pa.run_id = %s
            ORDER BY pa.applied_at DESC
        """, (run_id,))
        return cur.fetchall()


def create_adjustment(run_id, employee_id, adjustment_type, description,
                      amount, applied_by, remarks=None):
    """Append a non-destructive adjustment record to a pay run."""
    with get_cursor() as cur:
        cur.execute("SELECT id, status FROM payroll.pay_runs WHERE id = %s", (run_id,))
        run = cur.fetchone()
    if not run:
        return {'ok': False, 'message': 'Pay run not found.'}
    if run['status'] == 'COMPLETED':
        return {'ok': False, 'message': 'Cannot adjust a completed pay run.'}

    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO payroll.pay_adjustments
                (run_id, employee_id, adjustment_type, description, amount, applied_by, remarks)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (run_id, employee_id, adjustment_type, description,
              amount, applied_by, remarks or None))
        adj_id = cur.fetchone()['id']
    return {'ok': True, 'id': adj_id,
            'message': f'Adjustment #{adj_id} recorded successfully.'}


# ---------------------------------------------------------------------------
# Payslips
# ---------------------------------------------------------------------------

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
            SELECT COUNT(*) FROM payroll.pay_employee_payroll
            WHERE employee_id = %s
        """, (employee_id,))
        total = cur.fetchone()['count']
    return rows, total


def get_payslip_detail(payslip_id, employee_id=None):
    with get_cursor() as cur:
        if employee_id:
            cur.execute("""
                SELECT * FROM payroll.v_payslip
                WHERE payslip_id = %s AND employee_id = %s
            """, (payslip_id, employee_id))
        else:
            cur.execute("SELECT * FROM payroll.v_payslip WHERE payslip_id = %s",
                        (payslip_id,))
        return cur.fetchone()


# ---------------------------------------------------------------------------
# Loans
# ---------------------------------------------------------------------------

def get_loans(employee_id=None, status=None, page=1, per_page=30):
    conditions = ['1=1']
    params     = []
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
            JOIN core.v_employees_full e   ON e.id = pl.employee_id
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
            SELECT pl.*, e.employee_no, e.full_name
            FROM payroll.pay_loans pl
            JOIN core.v_employees_full e ON e.id = pl.employee_id
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
               start_cutoff_id, purpose, submitted_by):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO payroll.pay_loans
                (employee_id, loan_type, principal_amount, outstanding_balance,
                 monthly_deduction, start_cutoff_id, purpose, status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, 'PENDING')
            RETURNING id
        """, (employee_id, loan_type.upper(), principal, principal,
              monthly_deduction, start_cutoff_id, purpose))
        loan_id = cur.fetchone()['id']

    workflow_service.create_instance(
        definition_code='LOAN_APPROVAL',
        module='payroll',
        entity_type='pay_loans',
        entity_id=loan_id,
        initiated_by=submitted_by,
        reference_no=f'LN-{loan_id:05d}',
    )
    return loan_id


# ---------------------------------------------------------------------------
# Payroll Register (HR admin view)
# ---------------------------------------------------------------------------

def get_payroll_register(run_id):
    """Full register for a pay run, suitable for export."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                e.employee_no, e.full_name, d.name AS department,
                ep.basic_pay, ep.ot_pay, ep.holiday_pay, ep.night_diff_pay,
                ep.allowances_total, ep.gross_pay,
                ep.sss_ee, ep.philhealth_ee, ep.pagibig_ee, ep.tax_withheld,
                ep.loan_deductions, ep.other_deductions,
                ep.total_deductions, ep.net_pay
            FROM payroll.pay_employee_payroll ep
            JOIN core.v_employees_full e   ON e.id = ep.employee_id
            JOIN core.departments d ON d.id = e.department_id
            WHERE ep.run_id = %s
            ORDER BY d.name, e.full_name
        """, (run_id,))
        return cur.fetchall()


def get_government_remittances(run_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM payroll.pay_government_remittances
            WHERE run_id = %s ORDER BY agency
        """, (run_id,))
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Government Payroll Computation Engine
# ---------------------------------------------------------------------------

def _lookup_ssl_rate(cur, sg, step):
    """Get monthly rate from SSL table for given SG and step."""
    cur.execute("""
        SELECT monthly_rate FROM rewards.rwd_ssl_table
        WHERE salary_grade = %s AND step_no = %s
        ORDER BY effective_date DESC LIMIT 1
    """, (sg, step))
    row = cur.fetchone()
    return float(row['monthly_rate']) if row else 0


def _lookup_gsis(cur, basic_pay):
    """Get GSIS EE and ER shares for given basic pay."""
    cur.execute("""
        SELECT ee_personal_share_pct, er_government_share_pct, life_insurance_pct
        FROM payroll.pay_gsis_schedule
        WHERE is_current = TRUE
          AND salary_bracket_from <= %s AND salary_bracket_to >= %s
        LIMIT 1
    """, (basic_pay, basic_pay))
    row = cur.fetchone()
    if not row:
        return 0, 0
    ee = round(basic_pay * float(row['ee_personal_share_pct']), 2)
    er = round(basic_pay * float(row['er_government_share_pct']), 2)
    return ee, er


def _lookup_pagibig(cur, basic_pay):
    """Get Pag-IBIG EE and ER contributions."""
    cur.execute("""
        SELECT ee_contribution_pct, er_contribution_pct
        FROM payroll.pay_pagibig_schedule
        WHERE is_current = TRUE
          AND salary_bracket_from <= %s AND salary_bracket_to >= %s
        LIMIT 1
    """, (basic_pay, basic_pay))
    row = cur.fetchone()
    if not row:
        return 100, 100  # default ₱100 each
    ee = round(basic_pay * float(row['ee_contribution_pct']), 2)
    er = round(basic_pay * float(row['er_contribution_pct']), 2)
    return min(ee, 5000), min(er, 5000)  # cap at ₱5,000


def _lookup_bir_tax(cur, taxable_income, frequency='MONTHLY'):
    """Compute BIR withholding tax using the tax table."""
    cur.execute("""
        SELECT bracket_from, base_tax, excess_pct
        FROM payroll.pay_bir_tax_table
        WHERE is_current = TRUE AND frequency = %s
          AND bracket_from <= %s
        ORDER BY bracket_from DESC LIMIT 1
    """, (frequency, taxable_income))
    row = cur.fetchone()
    if not row:
        return 0
    excess = taxable_income - float(row['bracket_from'])
    return round(float(row['base_tax']) + excess * float(row['excess_pct']), 2)


def _get_employee_allowances_gov(cur, employee_id):
    """Get total PERA, RATA, ACA, hazard for an employee."""
    result = {'pera': 0, 'rata': 0, 'aca': 0, 'hazard': 0}
    cur.execute("""
        SELECT ga.allowance_code, eag.monthly_amount
        FROM payroll.pay_employee_allowances_gov eag
        JOIN payroll.pay_gov_allowances ga ON ga.id = eag.allowance_id
        WHERE eag.employee_id = %s
          AND eag.effective_from <= CURRENT_DATE
          AND (eag.effective_to IS NULL OR eag.effective_to >= CURRENT_DATE)
    """, (employee_id,))
    for row in cur.fetchall():
        code = row['allowance_code']
        amt = float(row['monthly_amount'])
        if code == 'PERA':
            result['pera'] = amt
        elif code == 'ACA':
            result['aca'] = amt
        elif code == 'HAZARD':
            result['hazard'] = amt
    # RATA from schedule
    cur.execute("""
        SELECT representation_allowance + transportation_allowance AS rata
        FROM payroll.pay_rata_schedule
        WHERE is_current = TRUE AND position_id IN (
            SELECT position_id FROM core.employees WHERE id = %s
        )
        LIMIT 1
    """, (employee_id,))
    rata_row = cur.fetchone()
    if rata_row:
        result['rata'] = float(rata_row['rata'])
    return result


def _get_loan_deductions(cur, employee_id):
    """Sum of all active loan monthly deductions."""
    cur.execute("""
        SELECT COALESCE(SUM(monthly_deduction), 0) AS total
        FROM payroll.pay_loans
        WHERE employee_id = %s AND status = 'ACTIVE'
    """, (employee_id,))
    return float(cur.fetchone()['total'])


def _get_coop_deduction(cur, employee_id):
    """Monthly coop savings deduction."""
    cur.execute("""
        SELECT COALESCE(SUM(monthly_savings), 0) AS total
        FROM payroll.pay_coop_members
        WHERE employee_id = %s AND is_active = TRUE
    """, (employee_id,))
    return float(cur.fetchone()['total'])


def compute_employee_payroll(employee_id, pay_run_id):
    """
    Full government payroll computation:
    1. Basic pay from SSL table (SG x Step)
    2. Add: PERA (₱2,000), ACA, RATA (if applicable), Hazard Pay
    3. Add: OT pay (from approved OT requests)
    4. Gross pay = basic + allowances + OT
    5. GSIS: ee_share (from pay_gsis_schedule)
    6. Pag-IBIG: ee_contribution (from pay_pagibig_schedule)
    7. PhilHealth: standard rate
    8. Tax: from pay_bir_tax_table (on basic + taxable allowances)
    9. Loan deductions: all ACTIVE loans
    10. Net pay = gross - all deductions
    """
    with get_cursor(commit=True) as cur:
        # Get employee details
        cur.execute("""
            SELECT e.id, jg.grade_level AS salary_grade, e.first_name, e.last_name,
                   COALESCE(a.step_no, 1) AS step_no
            FROM core.employees e
            LEFT JOIN core.job_grades jg ON jg.id = e.job_grade_id
            LEFT JOIN recruitment.rec_appointments a
                ON a.employee_id = e.id AND a.status = 'ATTESTED'
            WHERE e.id = %s
            ORDER BY a.effective_date DESC NULLS LAST
            LIMIT 1
        """, (employee_id,))
        emp = cur.fetchone()
        if not emp or not emp['salary_grade']:
            return None

        sg = emp['salary_grade']
        step = emp['step_no']

        # 1. Basic pay from SSL
        basic_pay = _lookup_ssl_rate(cur, sg, step)

        # 2. Allowances
        allowances = _get_employee_allowances_gov(cur, employee_id)
        pera = allowances['pera'] or 2000  # default PERA
        rata = allowances['rata']
        aca = allowances['aca']
        hazard = allowances['hazard']
        total_allowances = pera + rata + aca + hazard

        # 3. OT pay (simplified: from existing ot columns if computed)
        ot_pay = 0  # to be linked from attendance module

        # 4. Gross pay
        gross_pay = basic_pay + total_allowances + ot_pay

        # 5. GSIS
        gsis_ee, gsis_er = _lookup_gsis(cur, basic_pay)

        # 6. Pag-IBIG
        pagibig_ee, pagibig_er = _lookup_pagibig(cur, basic_pay)

        # 7. PhilHealth (simplified 5% shared equally)
        philhealth_ee = round(basic_pay * 0.025, 2)  # 2.5% employee share

        # 8. BIR Tax (on basic + taxable allowances - mandatory contributions)
        taxable_income = basic_pay - gsis_ee - pagibig_ee - philhealth_ee
        tax = _lookup_bir_tax(cur, max(taxable_income, 0))

        # 9. Loans + coop
        loan_ded = _get_loan_deductions(cur, employee_id)
        coop_ded = _get_coop_deduction(cur, employee_id)

        # 10. Total deductions & net
        total_deductions = gsis_ee + pagibig_ee + philhealth_ee + tax + loan_ded + coop_ded
        net_pay = gross_pay - total_deductions

        # Upsert into pay_employee_payroll
        cur.execute("""
            INSERT INTO payroll.pay_employee_payroll
                (run_id, employee_id, basic_pay, allowances_total, ot_pay,
                 gross_pay, pera, rata, aca, hazard_pay,
                 gsis_ps, gsis_gs, pagibig_ps, pagibig_gs,
                 philhealth_ee, tax_withheld,
                 loan_deductions, coop_deduction,
                 total_deductions, net_pay)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (run_id, employee_id) DO UPDATE SET
                basic_pay = EXCLUDED.basic_pay,
                allowances_total = EXCLUDED.allowances_total,
                ot_pay = EXCLUDED.ot_pay,
                gross_pay = EXCLUDED.gross_pay,
                pera = EXCLUDED.pera, rata = EXCLUDED.rata,
                aca = EXCLUDED.aca, hazard_pay = EXCLUDED.hazard_pay,
                gsis_ps = EXCLUDED.gsis_ps, gsis_gs = EXCLUDED.gsis_gs,
                pagibig_ps = EXCLUDED.pagibig_ps, pagibig_gs = EXCLUDED.pagibig_gs,
                philhealth_ee = EXCLUDED.philhealth_ee,
                tax_withheld = EXCLUDED.tax_withheld,
                loan_deductions = EXCLUDED.loan_deductions,
                coop_deduction = EXCLUDED.coop_deduction,
                total_deductions = EXCLUDED.total_deductions,
                net_pay = EXCLUDED.net_pay,
                updated_at = NOW()
            RETURNING id
        """, (pay_run_id, employee_id, basic_pay, total_allowances, ot_pay,
              gross_pay, pera, rata, aca, hazard,
              gsis_ee, gsis_er, pagibig_ee, pagibig_er,
              philhealth_ee, tax,
              loan_ded, coop_ded,
              total_deductions, net_pay))

        return {
            'basic_pay': basic_pay, 'gross_pay': gross_pay,
            'net_pay': net_pay, 'gsis_ee': gsis_ee,
            'pagibig_ee': pagibig_ee, 'tax': tax,
        }
