"""Calibration Blueprint — talent calibration sessions and 9-box grid."""
from flask import Blueprint, render_template, request, redirect, url_for, flash, session
from functools import wraps
from modules.calibration import calibration_service as svc
from services.db import get_cursor

calibration_bp = Blueprint('calibration', __name__,
                           url_prefix='/calibration',
                           template_folder='../../templates/calibration')


def _login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated


def _hr_or_manager_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        role = session.get('role_code', '')
        if role not in ('HR_ADMIN', 'SUPER_ADMIN', 'MANAGER'):
            flash('Access denied. HR or Manager role required.', 'error')
            return redirect('/')
        return f(*args, **kwargs)
    return decorated


# ---------------------------------------------------------------------------
# Sessions List
# ---------------------------------------------------------------------------

@calibration_bp.route('/')
@_login_required
@_hr_or_manager_required
def index():
    sessions = svc.get_sessions()
    stats = svc.get_calibration_stats()

    with get_cursor() as cur:
        cur.execute("SELECT id, name FROM performance.perf_cycles ORDER BY period_from DESC")
        cycles = cur.fetchall()
        cur.execute("SELECT id, name FROM core.departments ORDER BY name")
        departments = cur.fetchall()
        cur.execute("""
            SELECT e.id, e.full_name
            FROM core.v_employees_full e
            WHERE e.is_active = true
            ORDER BY e.full_name
        """)
        employees = cur.fetchall()

    return render_template('calibration/index.html',
                           sessions=sessions, stats=stats,
                           cycles=cycles, departments=departments,
                           employees=employees)


# ---------------------------------------------------------------------------
# Create Session
# ---------------------------------------------------------------------------

@calibration_bp.route('/create', methods=['POST'])
@_login_required
@_hr_or_manager_required
def create():
    name = request.form.get('name', '').strip()
    cycle_id = request.form.get('cycle_id', type=int)
    department_id = request.form.get('department_id', type=int)
    facilitator_id = request.form.get('facilitator_id', type=int)

    if not name:
        flash('Session name is required.', 'error')
        return redirect(url_for('calibration.index'))

    session_id = svc.create_session(name, cycle_id, department_id, facilitator_id)
    flash('Calibration session created.', 'success')
    return redirect(url_for('calibration.detail', session_id=session_id))


# ---------------------------------------------------------------------------
# Session Detail + 9-Box Grid
# ---------------------------------------------------------------------------

@calibration_bp.route('/<int:session_id>')
@_login_required
@_hr_or_manager_required
def detail(session_id):
    session_row, assessments = svc.get_session_detail(session_id)
    if not session_row:
        flash('Session not found.', 'error')
        return redirect(url_for('calibration.index'))

    matrix = svc.get_9box_matrix(session_id)

    with get_cursor() as cur:
        cur.execute("""
            SELECT e.id, e.full_name, e.position_title, e.department_name
            FROM core.v_employees_full e
            WHERE e.is_active = true
            ORDER BY e.full_name
        """)
        employees = cur.fetchall()

    return render_template('calibration/detail.html',
                           s=session_row, assessments=assessments,
                           matrix=matrix, employees=employees)


# ---------------------------------------------------------------------------
# Assess Employee
# ---------------------------------------------------------------------------

@calibration_bp.route('/<int:session_id>/assess', methods=['POST'])
@_login_required
@_hr_or_manager_required
def assess(session_id):
    emp_id = request.form.get('employee_id', type=int)
    perf = request.form.get('performance_score', type=int)
    pot = request.form.get('potential_score', type=int)
    risk = request.form.get('risk_of_loss', '')
    impact = request.form.get('impact_of_loss', '')
    dev_action = request.form.get('development_action', '')
    notes = request.form.get('notes', '')

    if not emp_id or not perf or not pot:
        flash('Employee, performance score, and potential score are required.', 'error')
        return redirect(url_for('calibration.detail', session_id=session_id))

    svc.assess_employee(
        session_id=session_id,
        employee_id=emp_id,
        performance_score=perf,
        potential_score=pot,
        risk_of_loss=risk,
        impact_of_loss=impact,
        development_action=dev_action,
        notes=notes,
        assessed_by=session.get('employee_id')
    )
    flash('Assessment saved.', 'success')
    return redirect(url_for('calibration.detail', session_id=session_id))


# ---------------------------------------------------------------------------
# Finalize Session
# ---------------------------------------------------------------------------

@calibration_bp.route('/<int:session_id>/finalize', methods=['POST'])
@_login_required
@_hr_or_manager_required
def finalize(session_id):
    svc.finalize_session(session_id)
    flash('Session finalized.', 'success')
    return redirect(url_for('calibration.detail', session_id=session_id))
