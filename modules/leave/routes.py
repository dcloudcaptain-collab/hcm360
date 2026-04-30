"""Leave Blueprint — requests, balances, travel orders, locator, CTO."""
from flask import Blueprint, render_template, request, redirect, url_for, \
    flash, session, jsonify
from modules.leave import leave_service as svc

leave_bp = Blueprint('leave', __name__,
                     url_prefix='/leave',
                     template_folder='../../templates/leave')


def _login_required(f):
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated


# ---------------------------------------------------------------------------
# Leave Dashboard
# ---------------------------------------------------------------------------

@leave_bp.route('/')
@_login_required
def index():
    emp_id   = session.get('employee_id')
    balances = svc.get_balances(emp_id) if emp_id else []
    rows, _  = svc.get_requests(employee_id=emp_id, status='PENDING')
    return render_template('leave/index.html',
                           balances=balances, pending=rows)


# ---------------------------------------------------------------------------
# Leave Requests
# ---------------------------------------------------------------------------

@leave_bp.route('/requests')
@_login_required
def requests():
    status  = request.args.get('status')
    dept_id = request.args.get('dept_id', type=int)
    page    = request.args.get('page', 1, type=int)
    leave_type_id = request.args.get('leave_type_id', type=int)
    date_from = request.args.get('date_from')
    date_to   = request.args.get('date_to')

    # If not SUPER_ADMIN, show only logged-in employee's leaves
    emp_id = None
    if session.get('role_code') not in ('SUPER_ADMIN', 'HR_ADMIN', 'MANAGER'):
        emp_id = session.get('employee_id')

    rows, total = svc.get_requests(status=status, department_id=dept_id, page=page,
                                   date_from=date_from, date_to=date_to,
                                   employee_id=emp_id)
    leave_types = svc.get_leave_types()
    filters = {'status': status, 'dept_id': dept_id, 'leave_type_id': leave_type_id,
               'date_from': date_from, 'date_to': date_to}
    return render_template('leave/requests.html',
                           rows=rows, total=total, page=page, per_page=30,
                           filters=filters, leave_types=leave_types)


@leave_bp.route('/requests/new', methods=['GET', 'POST'])
@_login_required
def request_new():
    if request.method == 'POST':
        leave_type_id = request.form.get('leave_type_id', type=int)
        date_from     = request.form.get('date_from')
        date_to       = request.form.get('date_to')
        reason        = request.form.get('reason', '').strip()
        result = svc.submit_request(
            employee_id=session['employee_id'],
            leave_type_id=leave_type_id,
            date_from=date_from,
            date_to=date_to,
            reason=reason,
            submitted_by=session['user_id'],
        )
        if result['ok']:
            flash(f"Leave request #{result['id']} submitted.", 'success')
            return redirect(url_for('leave.requests'))
        flash(result['message'], 'danger')

    leave_types = svc.get_leave_types()
    balances    = svc.get_balances(session.get('employee_id'))
    return render_template('leave/request_new.html',
                           leave_types=leave_types, balances=balances)


@leave_bp.route('/requests/<int:request_id>')
@_login_required
def request_detail(request_id):
    detail = svc.get_request_detail(request_id)
    if not detail:
        flash('Request not found.', 'warning')
        return redirect(url_for('leave.requests'))
    return render_template('leave/request_detail.html', detail=detail)


@leave_bp.route('/requests/<int:request_id>/action', methods=['POST'])
@_login_required
def request_action(request_id):
    action   = request.form.get('action_code', '').upper()
    comments = request.form.get('comments', '').strip()
    result   = svc.action_request(request_id, action,
                                  session['user_id'], comments or None)
    if result['ok']:
        flash(result['message'], 'success')
    else:
        flash(result['message'], 'danger')
    return redirect(url_for('leave.request_detail', request_id=request_id))


@leave_bp.route('/requests/<int:request_id>/cancel', methods=['POST'])
@_login_required
def request_cancel(request_id):
    svc.cancel_request(request_id, cancelled_by=session['user_id'])
    flash('Leave request cancelled.', 'info')
    return redirect(url_for('leave.requests'))


# ---------------------------------------------------------------------------
# Balances
# ---------------------------------------------------------------------------

@leave_bp.route('/balances')
@_login_required
def balances():
    dept_id = request.args.get('dept_id', type=int)
    q       = request.args.get('q', '').strip()
    matrix  = svc.get_balance_matrix(department_id=dept_id)
    departments = svc.get_departments()
    filters = {'department_id': dept_id, 'q': q}
    return render_template('leave/balances.html', matrix=matrix,
                           departments=departments, filters=filters)


@leave_bp.route('/balances/<int:employee_id>')
@_login_required
def balance_detail(employee_id):
    from services.access_service import can_modify
    from datetime import date as _date
    data        = svc.get_balances(employee_id)
    adjustments = svc.get_balance_adjustments(employee_id)
    leave_types = svc.get_leave_types()
    can_adjust  = can_modify(session.get('role_code', ''), 'LEAVE', session.get('user_id'))
    year        = _date.today().year
    return render_template('leave/balance_detail.html', data=data,
                           employee_id=employee_id, adjustments=adjustments,
                           leave_types=leave_types, can_adjust=can_adjust, year=year)


@leave_bp.route('/balances/<int:employee_id>/adjust', methods=['POST'])
@_login_required
def balance_adjust(employee_id):
    """Manual credit/debit on a leave balance — requires LEAVE modify permission."""
    from services.access_service import can_modify
    if not can_modify(session.get('role_code', ''), 'LEAVE', session.get('user_id')):
        flash('You do not have permission to adjust leave balances.', 'danger')
        return redirect(url_for('leave.balance_detail', employee_id=employee_id))

    leave_type_id   = request.form.get('leave_type_id', type=int)
    year            = request.form.get('year', type=int)
    adjustment_days = request.form.get('adjustment_days', type=float)
    reason          = request.form.get('reason', '').strip()

    if not leave_type_id or adjustment_days is None or not reason:
        flash('Leave type, adjustment days, and reason are all required.', 'danger')
        return redirect(url_for('leave.balance_detail', employee_id=employee_id))

    result = svc.adjust_balance(
        employee_id=employee_id,
        leave_type_id=leave_type_id,
        year=year,
        adjustment_days=adjustment_days,
        reason=reason,
        adjusted_by=session['user_id'],
    )
    if result['ok']:
        flash(result['message'], 'success')
    else:
        flash(result['message'], 'danger')
    return redirect(url_for('leave.balance_detail', employee_id=employee_id))


# ---------------------------------------------------------------------------
# Travel Orders
# ---------------------------------------------------------------------------

@leave_bp.route('/travel-orders')
@_login_required
def travel_orders():
    status = request.args.get('status')
    page   = request.args.get('page', 1, type=int)
    rows, total = svc.get_travel_orders(status=status, page=page)
    filters = {'status': status}
    return render_template('leave/travel_orders.html',
                           rows=rows, total=total, page=page, per_page=30,
                           filters=filters, status=status)


@leave_bp.route('/travel-orders/new', methods=['GET', 'POST'])
@_login_required
def travel_order_new():
    if request.method == 'POST':
        to_id = svc.submit_travel_order(
            employee_id=session['employee_id'],
            destination=request.form.get('destination', '').strip(),
            date_from=request.form.get('date_from'),
            date_to=request.form.get('date_to'),
            purpose=request.form.get('purpose', '').strip(),
            transport_mode=request.form.get('transport_mode', 'OTHER'),
            submitted_by=session['user_id'],
        )
        flash(f'Travel order #{to_id} submitted.', 'success')
        return redirect(url_for('leave.travel_orders'))
    return render_template('leave/travel_order_new.html')


# ---------------------------------------------------------------------------
# Locator
# ---------------------------------------------------------------------------

@leave_bp.route('/locator')
@_login_required
def locator():
    from datetime import date as _date
    dept_id = request.args.get('dept_id', type=int)
    board   = svc.get_locator_today(department_id=dept_id)
    filter_status = request.args.get('filter')
    if filter_status:
        board = [r for r in board if r.get('location_type') == filter_status]
    summary   = {}
    by_status = {}
    for r in board:
        s = r.get('location_type', 'UNKNOWN')
        summary[s] = summary.get(s, 0) + 1
        by_status.setdefault(s, []).append(r)
    return render_template('leave/locator.html', board=board,
                           filter_status=filter_status,
                           summary=summary, by_status=by_status,
                           today=_date.today().strftime('%B %d, %Y'))


@leave_bp.route('/locator/log', methods=['POST'])
@_login_required
def locator_log():
    # Admin-on-behalf support: if an employee_id is posted, honor it (admin
    # logs for a subordinate); otherwise default to the caller's session.
    posted_emp_id = request.form.get('employee_id', type=int)
    emp_id = posted_emp_id or session.get('employee_id')
    if not emp_id:
        flash('Your account is not linked to an employee record, so locator entries cannot be attributed. Link an employee to your login first, or choose one to log on behalf of.', 'error')
        return redirect(url_for('leave.locator'))
    status = request.form.get('location_status', 'IN_OFFICE')
    notes  = request.form.get('notes', '').strip()
    svc.log_locator(
        employee_id=emp_id,
        location_status=status,
        notes=notes or None,
        logged_by=session['user_id'],
    )
    flash('Location updated.', 'success')
    return redirect(url_for('leave.locator'))


# ---------------------------------------------------------------------------
# CTO Credits
# ---------------------------------------------------------------------------

@leave_bp.route('/cto')
@_login_required
def cto():
    emp_id = request.args.get('employee_id',
                              session.get('employee_id'), type=int)
    ledger, balance = svc.get_cto_ledger(emp_id)
    totals = {
        'earned':    sum(r['hours'] for r in ledger if r.get('transaction_type') == 'EARNED'),
        'used':      sum(r['hours'] for r in ledger if r.get('transaction_type') == 'USED'),
        'forfeited': sum(r['hours'] for r in ledger if r.get('transaction_type') in ('FORFEITED','EXPIRED')),
        'balance':   float(balance or 0),
    }
    return render_template('leave/cto.html',
                           ledger=ledger, balance=balance, totals=totals,
                           employee_id=emp_id)


@leave_bp.route('/cto/adjust', methods=['POST'])
@_login_required
def cto_adjust():
    emp_id   = request.form.get('employee_id', type=int)
    tx_type  = request.form.get('transaction_type', 'EARNED').upper()
    hours    = request.form.get('hours', type=float)
    remarks  = request.form.get('remarks', '').strip()
    if not emp_id or not hours:
        flash('Employee and hours are required.', 'danger')
    else:
        svc.adjust_cto(emp_id, tx_type, hours, remarks,
                       adjusted_by=session['user_id'])
        flash('CTO credits adjusted.', 'success')
    return redirect(url_for('leave.cto', employee_id=emp_id))
