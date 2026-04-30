"""Payroll Blueprint — dashboard, periods, runs, payslips, loans, register, 13th month, remittances."""
from flask import Blueprint, render_template, request, redirect, url_for, \
    flash, session, g, send_file
import io
from datetime import date
from services import payroll_service as svc
from services import attendance_service as att_svc

payroll_bp = Blueprint('payroll', __name__,
                       url_prefix='/payroll',
                       template_folder='../templates/payroll')


def _login_required(f):
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect('/login')
        return f(*args, **kwargs)
    return decorated


# ── Dashboard ───────────────────────────────────────────────────

@payroll_bp.route('/')
@_login_required
def index():
    period = svc.get_current_period(g.company_id)
    runs, _ = svc.get_pay_runs(company_id=g.company_id, per_page=5)
    return render_template('payroll/index.html', period=period, runs=runs)


# ── Pay Periods ─────────────────────────────────────────────────

@payroll_bp.route('/periods')
@_login_required
def periods():
    page = request.args.get('page', 1, type=int)
    rows, total = svc.get_pay_periods(company_id=g.company_id, page=page)
    return render_template('payroll/periods.html',
                           rows=rows, total=total, page=page, per_page=30)


@payroll_bp.route('/periods/new', methods=['POST'])
@_login_required
def period_new():
    pid = svc.create_pay_period(
        company_id=g.company_id,
        period_code=request.form['period_code'],
        period_type=request.form.get('period_type', 'SEMI_MONTHLY'),
        date_from=request.form['date_from'],
        date_to=request.form['date_to'],
        payment_date=request.form.get('payment_date') or None,
    )
    flash(f'Pay period #{pid} created.', 'success')
    return redirect(url_for('payroll.periods'))


@payroll_bp.route('/periods/<int:period_id>/close', methods=['POST'])
@_login_required
def period_close(period_id):
    result = svc.close_pay_period(period_id)
    flash(result['message'], 'success' if result['ok'] else 'danger')
    return redirect(url_for('payroll.periods'))


# ── Pay Runs ────────────────────────────────────────────────────

@payroll_bp.route('/runs')
@_login_required
def runs():
    status = request.args.get('status')
    page = request.args.get('page', 1, type=int)
    rows, total = svc.get_pay_runs(company_id=g.company_id, status=status, page=page)
    return render_template('payroll/runs.html',
                           rows=rows, total=total, page=page, status=status)


@payroll_bp.route('/runs/new', methods=['GET', 'POST'])
@_login_required
def run_new():
    if request.method == 'POST':
        period_id = request.form.get('pay_period_id', type=int)
        notes = request.form.get('notes', '').strip()
        if not period_id:
            flash('Pay period is required.', 'danger')
        else:
            run_id = svc.create_pay_run(period_id, session['user_id'], notes or None)
            flash(f'Pay run #{run_id} created.', 'success')
            return redirect(url_for('payroll.run_detail', run_id=run_id))
    periods, _ = svc.get_pay_periods(company_id=g.company_id, status='OPEN')
    return render_template('payroll/run_new.html', periods=periods)


@payroll_bp.route('/runs/<int:run_id>')
@_login_required
def run_detail(run_id):
    run, employees = svc.get_run_detail(run_id)
    if not run:
        flash('Pay run not found.', 'warning')
        return redirect(url_for('payroll.runs'))
    remittances = svc.get_remittances(run_id=run_id)
    return render_template('payroll/run_detail.html',
                           run=run, employees=employees, remittances=remittances)


@payroll_bp.route('/runs/<int:run_id>/compute', methods=['POST'])
@_login_required
def run_compute(run_id):
    run, _ = svc.get_run_detail(run_id)
    if not run:
        flash('Pay run not found.', 'warning')
        return redirect(url_for('payroll.runs'))
    result = svc.compute_pay_run(run_id, run['company_id'], session['user_id'])
    flash(result['message'], 'success' if result['ok'] else 'danger')
    return redirect(url_for('payroll.run_detail', run_id=run_id))


@payroll_bp.route('/runs/<int:run_id>/action', methods=['POST'])
@_login_required
def run_action(run_id):
    action = request.form.get('action_code', '').upper()
    comments = request.form.get('comments', '').strip()
    result = svc.action_pay_run(run_id, action, session['user_id'], comments or None)
    flash(result['message'], 'success' if result['ok'] else 'danger')
    return redirect(url_for('payroll.run_detail', run_id=run_id))


# ── Payslips ────────────────────────────────────────────────────

@payroll_bp.route('/payslips/<int:employee_id>')
@_login_required
def payslips(employee_id):
    page = request.args.get('page', 1, type=int)
    rows, total = svc.get_payslips(employee_id, page=page)
    return render_template('payroll/payslips.html',
                           rows=rows, total=total, page=page,
                           employee_id=employee_id)


@payroll_bp.route('/payslips/<int:payslip_id>/view')
@_login_required
def payslip_view(payslip_id):
    emp_id = None
    role = session.get('role_code', '')
    if role not in ('HR_ADMIN', 'SUPERADMIN', 'SUPER_ADMIN', 'PAYROLL_OFFICER'):
        emp_id = session.get('employee_id')
    detail = svc.get_payslip_detail(payslip_id, employee_id=emp_id)
    if not detail:
        flash('Payslip not found.', 'warning')
        return redirect(url_for('payroll.index'))
    return render_template('payroll/payslip.html', detail=detail)


# ── Loans ───────────────────────────────────────────────────────

@payroll_bp.route('/loans')
@_login_required
def loans():
    status = request.args.get('status')
    page = request.args.get('page', 1, type=int)
    rows, total = svc.get_loans(company_id=g.company_id, status=status, page=page)
    return render_template('payroll/loans.html',
                           rows=rows, total=total, page=page, status=status)


@payroll_bp.route('/loans/new', methods=['GET', 'POST'])
@_login_required
def loan_new():
    if request.method == 'POST':
        emp_id = request.form.get('employee_id', type=int)
        loan_type = request.form.get('loan_type', 'COMPANY')
        principal = request.form.get('principal', type=float)
        monthly = request.form.get('monthly_deduction', type=float)
        total_months = request.form.get('total_months', type=int)
        start_date = request.form.get('start_date')
        purpose = request.form.get('purpose', '').strip()
        if not principal or not emp_id:
            flash('Employee and principal amount are required.', 'danger')
        else:
            loan_id = svc.apply_loan(emp_id, loan_type, principal, monthly,
                                      total_months, start_date, purpose,
                                      session['user_id'])
            flash(f'Loan #{loan_id} submitted.', 'success')
            return redirect(url_for('payroll.loans'))
    employees = att_svc.get_employees(g.company_id)
    return render_template('payroll/loan_new.html', employees=employees)


@payroll_bp.route('/loans/<int:loan_id>')
@_login_required
def loan_detail(loan_id):
    loan, payments = svc.get_loan_detail(loan_id)
    if not loan:
        flash('Loan not found.', 'warning')
        return redirect(url_for('payroll.loans'))
    return render_template('payroll/loan_detail.html', loan=loan, payments=payments)


@payroll_bp.route('/loans/<int:loan_id>/approve', methods=['POST'])
@_login_required
def loan_approve(loan_id):
    result = svc.approve_loan(loan_id, session['user_id'])
    flash(result['message'], 'success' if result['ok'] else 'danger')
    return redirect(url_for('payroll.loan_detail', loan_id=loan_id))


# ── Register ────────────────────────────────────────────────────

@payroll_bp.route('/register')
@_login_required
def register():
    run_id = request.args.get('run_id', type=int)
    runs, _ = svc.get_pay_runs(company_id=g.company_id, per_page=100)
    rows = svc.get_payroll_register(run_id) if run_id else []
    return render_template('payroll/register.html',
                           rows=rows, run_id=run_id, runs=runs)


@payroll_bp.route('/register/export')
@_login_required
def register_export():
    run_id = request.args.get('run_id', type=int)
    fmt = request.args.get('fmt', 'xlsx')
    if not run_id:
        flash('Select a pay run first.', 'warning')
        return redirect(url_for('payroll.register'))

    rows = svc.get_payroll_register(run_id)
    columns = [
        ('employee_no', 'Employee No'), ('full_name', 'Full Name'),
        ('department', 'Department'), ('basic_pay', 'Basic Pay'),
        ('ot_pay', 'OT Pay'), ('holiday_pay', 'Holiday Pay'),
        ('gross_pay', 'Gross Pay'), ('sss_ee', 'SSS'),
        ('philhealth_ee', 'PhilHealth'), ('pagibig_ee', 'Pag-IBIG'),
        ('tax_withheld', 'Tax'), ('loan_deductions', 'Loans'),
        ('total_deductions', 'Total Deductions'), ('net_pay', 'Net Pay'),
    ]

    from services.reporting_service import to_xlsx, to_csv
    if fmt == 'xlsx':
        data = to_xlsx(rows, sheet_name='Register', columns=columns,
                       title=f'Payroll Register — Run {run_id}')
        return send_file(io.BytesIO(data),
                         mimetype='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                         as_attachment=True,
                         download_name=f'payroll_register_run{run_id}.xlsx')
    else:
        data = to_csv(rows, columns=columns)
        return send_file(io.BytesIO(data), mimetype='text/csv',
                         as_attachment=True,
                         download_name=f'payroll_register_run{run_id}.csv')


# ── 13th Month ──────────────────────────────────────────────────

@payroll_bp.route('/13th-month')
@_login_required
def thirteenth_month():
    year = request.args.get('year', date.today().year, type=int)
    rows = svc.get_13th_month(g.company_id, year)
    return render_template('payroll/13th_month.html', rows=rows, year=year)


@payroll_bp.route('/13th-month/compute', methods=['POST'])
@_login_required
def thirteenth_month_compute():
    year = request.form.get('year', date.today().year, type=int)
    result = svc.compute_13th_month(g.company_id, year)
    flash(result['message'], 'success' if result['ok'] else 'danger')
    return redirect(url_for('payroll.thirteenth_month', year=year))


# ── Remittances ─────────────────────────────────────────────────

@payroll_bp.route('/remittances')
@_login_required
def remittances():
    run_id = request.args.get('run_id', type=int)
    rows = svc.get_remittances(run_id=run_id, company_id=g.company_id)
    runs, _ = svc.get_pay_runs(company_id=g.company_id, per_page=50)
    return render_template('payroll/remittances.html',
                           rows=rows, run_id=run_id, runs=runs)
