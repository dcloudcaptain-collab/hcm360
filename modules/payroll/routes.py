"""Payroll Blueprint — pay runs, payslips, loans, register."""
from flask import Blueprint, render_template, request, redirect, url_for, \
    flash, session, send_file
import io
from modules.payroll import payroll_service as svc
from services import reporting_service

payroll_bp = Blueprint('payroll', __name__,
                       url_prefix='/payroll',
                       template_folder='../../templates/payroll')


def _login_required(f):
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated


# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------

@payroll_bp.route('/')
@_login_required
def index():
    period = svc.get_current_period()
    runs, _ = svc.get_pay_runs(per_page=5)
    return render_template('payroll/index.html', period=period, runs=runs)


# ---------------------------------------------------------------------------
# Pay Runs
# ---------------------------------------------------------------------------

@payroll_bp.route('/runs')
@_login_required
def runs():
    status = request.args.get('status')
    page   = request.args.get('page', 1, type=int)
    rows, total = svc.get_pay_runs(status=status, page=page)
    return render_template('payroll/runs.html',
                           rows=rows, total=total, page=page, status=status)


@payroll_bp.route('/runs/new', methods=['GET', 'POST'])
@_login_required
def run_new():
    if request.method == 'POST':
        period_id = request.form.get('pay_period_id', type=int)
        notes     = request.form.get('notes', '').strip()
        if not period_id:
            flash('Pay period is required.', 'danger')
        else:
            run_id = svc.create_pay_run(period_id, session['user_id'], notes or None)
            flash(f'Pay run #{run_id} created.', 'success')
            return redirect(url_for('payroll.run_detail', run_id=run_id))
    periods = svc.get_pay_periods(status='OPEN')
    return render_template('payroll/run_new.html', periods=periods)


@payroll_bp.route('/runs/<int:run_id>')
@_login_required
def run_detail(run_id):
    from services.access_service import can_modify
    run, employees = svc.get_run_detail(run_id)
    if not run:
        flash('Pay run not found.', 'warning')
        return redirect(url_for('payroll.runs'))
    remittances  = svc.get_government_remittances(run_id)
    adjustments  = svc.get_adjustments(run_id)
    can_adjust   = can_modify(session.get('role_code', ''), 'PAYROLL', session.get('user_id'))
    return render_template('payroll/run_detail.html',
                           run=run, employees=employees,
                           remittances=remittances,
                           adjustments=adjustments, can_adjust=can_adjust)


@payroll_bp.route('/runs/<int:run_id>/adjustment', methods=['POST'])
@_login_required
def run_adjustment(run_id):
    """Add an earnings/deduction adjustment to a pay run."""
    from services.access_service import can_modify
    if not can_modify(session.get('role_code', ''), 'PAYROLL', session.get('user_id')):
        flash('You do not have permission to adjust payroll records.', 'danger')
        return redirect(url_for('payroll.run_detail', run_id=run_id))

    employee_id     = request.form.get('employee_id', type=int)
    adjustment_type = request.form.get('adjustment_type', 'EARNINGS').upper()
    description     = request.form.get('description', '').strip()
    amount          = request.form.get('amount', type=float)
    remarks         = request.form.get('remarks', '').strip()

    if not employee_id or not description or amount is None:
        flash('Employee, description, and amount are required.', 'danger')
        return redirect(url_for('payroll.run_detail', run_id=run_id))

    result = svc.create_adjustment(
        run_id=run_id,
        employee_id=employee_id,
        adjustment_type=adjustment_type,
        description=description,
        amount=amount,
        applied_by=session['user_id'],
        remarks=remarks or None,
    )
    if result['ok']:
        flash(result['message'], 'success')
    else:
        flash(result['message'], 'danger')
    return redirect(url_for('payroll.run_detail', run_id=run_id))


@payroll_bp.route('/runs/<int:run_id>/action', methods=['POST'])
@_login_required
def run_action(run_id):
    action   = request.form.get('action_code', '').upper()
    comments = request.form.get('comments', '').strip()
    result   = svc.action_pay_run(run_id, action,
                                  session['user_id'], comments or None)
    if result['ok']:
        flash(result['message'], 'success')
    else:
        flash(result['message'], 'danger')
    return redirect(url_for('payroll.run_detail', run_id=run_id))


# ---------------------------------------------------------------------------
# Register (export)
# ---------------------------------------------------------------------------

@payroll_bp.route('/register')
@_login_required
def register():
    run_id = request.args.get('run_id', type=int)
    runs, _ = svc.get_pay_runs(per_page=100)
    rows = svc.get_payroll_register(run_id) if run_id else []
    return render_template('payroll/register.html',
                           rows=rows, run_id=run_id, runs=runs)


@payroll_bp.route('/register/export')
@_login_required
def register_export():
    from services.audit_service import log_export
    run_id = request.args.get('run_id', type=int)
    fmt    = request.args.get('fmt', 'xlsx')
    if not run_id:
        flash('Select a pay run first.', 'warning')
        return redirect(url_for('payroll.register'))

    rows = svc.get_payroll_register(run_id)
    columns = [
        ('employee_no', 'Employee No'), ('full_name', 'Full Name'),
        ('department', 'Department'), ('basic_pay', 'Basic Pay'),
        ('ot_pay', 'OT Pay'), ('holiday_pay', 'Holiday Pay'),
        ('gross_pay', 'Gross Pay'), ('sss_ee', 'SSS'),
        ('philhealth_ee', 'PhilHealth'), ('hdmf_ee', 'HDMF'),
        ('withholding_tax', 'Tax'), ('total_loan_deductions', 'Loans'),
        ('total_deductions', 'Total Deductions'), ('net_pay', 'Net Pay'),
    ]
    log_export(session['user_id'], 'PAYROLL_REGISTER',
               record_count=len(rows), file_format=fmt.upper())

    if fmt == 'xlsx':
        data = reporting_service.to_xlsx(rows, sheet_name='Register',
                                         columns=columns,
                                         title=f'Payroll Register — Run {run_id}')
        return send_file(io.BytesIO(data),
                         mimetype='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                         as_attachment=True,
                         download_name=f'payroll_register_run{run_id}.xlsx')
    else:
        data = reporting_service.to_csv(rows, columns=columns)
        return send_file(io.BytesIO(data), mimetype='text/csv',
                         as_attachment=True,
                         download_name=f'payroll_register_run{run_id}.csv')


# ---------------------------------------------------------------------------
# Payslips
# ---------------------------------------------------------------------------

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
    # Employees can only see their own; HR/Admin can see all
    emp_id = None
    role   = session.get('role_code', '')
    if role not in ('HR_ADMIN', 'SUPER_ADMIN', 'SUPERADMIN', 'PAYROLL_OFFICER'):
        emp_id = session.get('employee_id')
    detail = svc.get_payslip_detail(payslip_id, employee_id=emp_id)
    if not detail:
        flash('Payslip not found.', 'warning')
        return redirect(url_for('ess.my_payslips'))
    return render_template('payroll/payslip.html', detail=detail)


@payroll_bp.route('/payslips/<int:payslip_id>/pdf')
@_login_required
def payslip_pdf(payslip_id):
    detail = svc.get_payslip_detail(payslip_id)
    if not detail:
        flash('Payslip not found.', 'warning')
        return redirect(url_for('payroll.runs'))
    pdf = reporting_service.render_payslip_pdf(
        detail['employee_id'], detail['run_id']
    )
    return send_file(io.BytesIO(pdf), mimetype='application/pdf',
                     as_attachment=True,
                     download_name=f'payslip_{payslip_id}.pdf')


# ---------------------------------------------------------------------------
# Loans
# ---------------------------------------------------------------------------

@payroll_bp.route('/loans')
@_login_required
def loans():
    status = request.args.get('status')
    page   = request.args.get('page', 1, type=int)
    rows, total = svc.get_loans(status=status, page=page)
    return render_template('payroll/loans.html',
                           rows=rows, total=total, page=page, status=status)


@payroll_bp.route('/loans/new', methods=['GET', 'POST'])
@_login_required
def loan_new():
    if request.method == 'POST':
        emp_id    = request.form.get('employee_id', type=int) or session.get('employee_id')
        loan_type = request.form.get('loan_type', 'COMPANY')
        principal = request.form.get('principal', type=float)
        monthly   = request.form.get('monthly_deduction', type=float)
        period_id = request.form.get('start_cutoff_id', type=int)
        purpose   = request.form.get('purpose', '').strip()
        if not principal:
            flash('Principal amount is required.', 'danger')
        else:
            loan_id = svc.apply_loan(emp_id, loan_type, principal,
                                     monthly, period_id, purpose,
                                     session['user_id'])
            flash(f'Loan application #{loan_id} submitted.', 'success')
            return redirect(url_for('payroll.loans'))
    periods = svc.get_pay_periods(status='OPEN')
    return render_template('payroll/loan_new.html', periods=periods)


@payroll_bp.route('/loans/<int:loan_id>')
@_login_required
def loan_detail(loan_id):
    loan, payments = svc.get_loan_detail(loan_id)
    if not loan:
        flash('Loan not found.', 'warning')
        return redirect(url_for('payroll.loans'))
    return render_template('payroll/loan_detail.html',
                           loan=loan, payments=payments)
