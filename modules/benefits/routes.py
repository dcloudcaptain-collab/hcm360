"""Benefits Administration Blueprint — plan management, enrollment, life events."""
from flask import Blueprint, render_template, request, redirect, url_for, \
    flash, session, g, jsonify
from functools import wraps
from modules.benefits import benefits_service as svc
from services.db import get_cursor

benefits_bp = Blueprint('benefits', __name__,
                        url_prefix='/benefits',
                        template_folder='../../templates/benefits')


def _login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated


def _hr_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if session.get('role_code') not in ('SUPER_ADMIN', 'HR_ADMIN'):
            flash('Access denied.', 'error')
            return redirect(url_for('dashboard.index'))
        return f(*args, **kwargs)
    return decorated


def _get_company_id():
    with get_cursor() as cur:
        cur.execute("SELECT id FROM core.companies LIMIT 1")
        row = cur.fetchone()
        return row['id'] if row else None


# ---------------------------------------------------------------------------
# HR Dashboard
# ---------------------------------------------------------------------------

@benefits_bp.route('/')
@_login_required
def index():
    stats = svc.get_benefits_stats()
    plans = svc.get_plans()
    by_type = svc.get_enrollment_summary_by_type()
    windows = svc.get_enrollment_windows()
    life_events = svc.get_life_events(status='OPEN')
    return render_template('benefits/index.html',
                           stats=stats, plans=plans, by_type=by_type,
                           windows=windows, life_events=life_events)


# ---------------------------------------------------------------------------
# Plan Management
# ---------------------------------------------------------------------------

@benefits_bp.route('/plans')
@_login_required
def plans():
    plan_types = svc.get_plan_types()
    all_plans = svc.get_plans(active_only=False)
    return render_template('benefits/plans.html',
                           plan_types=plan_types, plans=all_plans)


@benefits_bp.route('/plans/new', methods=['GET', 'POST'])
@_login_required
@_hr_required
def plan_new():
    if request.method == 'POST':
        svc.create_plan(
            company_id=_get_company_id(),
            plan_type_id=request.form.get('plan_type_id', type=int),
            code=request.form.get('code', '').upper().strip(),
            name=request.form.get('name', '').strip(),
            description=request.form.get('description', '').strip(),
            provider=request.form.get('provider', '').strip(),
            coverage_level=request.form.get('coverage_level', 'INDIVIDUAL'),
            employer_cost=request.form.get('employer_cost', 0, type=float),
            employee_cost=request.form.get('employee_cost', 0, type=float),
        )
        flash('Plan created.', 'success')
        return redirect(url_for('benefits.plans'), code=303)
    plan_types = svc.get_plan_types()
    return render_template('benefits/plan_form.html', plan_types=plan_types, plan=None)


@benefits_bp.route('/plans/<int:plan_id>')
@_login_required
def plan_detail(plan_id):
    plan = svc.get_plan(plan_id)
    if not plan:
        flash('Plan not found.', 'error')
        return redirect(url_for('benefits.plans'))
    with get_cursor() as cur:
        cur.execute("""
            SELECT e.*, emp.first_name || ' ' || emp.last_name AS employee_name,
                   emp.employee_no
            FROM benefits.enrollments e
            JOIN core.employees emp ON emp.id = e.employee_id
            WHERE e.plan_id = %s ORDER BY emp.last_name
        """, (plan_id,))
        enrollees = cur.fetchall()
    return render_template('benefits/plan_detail.html', plan=plan, enrollees=enrollees)


# ---------------------------------------------------------------------------
# Enrollment (HR side — enroll an employee)
# ---------------------------------------------------------------------------

@benefits_bp.route('/enroll', methods=['GET', 'POST'])
@_login_required
@_hr_required
def enroll_employee():
    if request.method == 'POST':
        emp_id = request.form.get('employee_id', type=int)
        plan_id = request.form.get('plan_id', type=int)
        coverage = request.form.get('coverage_level', 'INDIVIDUAL')
        window = svc.get_active_window()
        svc.enroll(emp_id, plan_id, coverage, window_id=window['id'] if window else None)
        flash('Employee enrolled.', 'success')
        return redirect(url_for('benefits.index'), code=303)
    plans = svc.get_plans()
    with get_cursor() as cur:
        cur.execute("""
            SELECT id, first_name || ' ' || last_name AS name, employee_no
            FROM core.employees WHERE is_active = TRUE ORDER BY last_name
        """)
        employees = cur.fetchall()
    return render_template('benefits/enroll.html', plans=plans, employees=employees)


# ---------------------------------------------------------------------------
# Enrollment Windows
# ---------------------------------------------------------------------------

@benefits_bp.route('/windows')
@_login_required
def windows():
    windows = svc.get_enrollment_windows()
    return render_template('benefits/windows.html', windows=windows)


@benefits_bp.route('/windows/new', methods=['POST'])
@_login_required
@_hr_required
def window_new():
    svc.create_enrollment_window(
        _get_company_id(),
        request.form.get('name', '').strip(),
        request.form.get('year', type=int),
        request.form.get('open_date'),
        request.form.get('close_date'),
        request.form.get('effective_date'),
    )
    flash('Enrollment window created.', 'success')
    return redirect(url_for('benefits.windows'), code=303)


@benefits_bp.route('/windows/<int:window_id>/status', methods=['POST'])
@_login_required
@_hr_required
def window_status(window_id):
    svc.update_window_status(window_id, request.form.get('status', 'OPEN'))
    flash('Window status updated.', 'success')
    return redirect(url_for('benefits.windows'), code=303)


# ---------------------------------------------------------------------------
# Life Events
# ---------------------------------------------------------------------------

@benefits_bp.route('/life-events')
@_login_required
def life_events():
    events = svc.get_life_events()
    return render_template('benefits/life_events.html', events=events)


@benefits_bp.route('/life-events/new', methods=['POST'])
@_login_required
def life_event_new():
    svc.create_life_event(
        request.form.get('employee_id', type=int),
        request.form.get('event_type'),
        request.form.get('event_date'),
        request.form.get('description', '').strip(),
    )
    flash('Life event created. Benefit changes can be made within the window.', 'success')
    return redirect(url_for('benefits.life_events'), code=303)


@benefits_bp.route('/life-events/<int:event_id>/close', methods=['POST'])
@_login_required
@_hr_required
def life_event_close(event_id):
    svc.close_life_event(event_id, session['user_id'])
    flash('Life event closed.', 'success')
    return redirect(url_for('benefits.life_events'), code=303)
