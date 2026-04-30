"""PM Blueprint — Performance Management (IPCR/OPCR)."""
from flask import (Blueprint, render_template, request, redirect, url_for,
                   flash, session, send_file, abort)
from functools import wraps
from modules.pm import pm_service as svc
from services import ipcr_csc_service as csc
from services.db import get_cursor

pm_bp = Blueprint('pm', __name__,
                  url_prefix='/pm',
                  template_folder='../../templates/pm')


def _login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated


def _get_company_id():
    with get_cursor() as cur:
        cur.execute("SELECT id FROM core.companies LIMIT 1")
        row = cur.fetchone()
        return row['id'] if row else None


# ---------------------------------------------------------------------------
# Performance Cycles
# ---------------------------------------------------------------------------

@pm_bp.route('/cycles')
@_login_required
def cycles():
    company_id = _get_company_id()
    if not company_id:
        flash('No company configured.', 'error')
        return redirect('/')
    all_cycles = svc.get_cycles(company_id)
    return render_template('pm/cycles.html', cycles=all_cycles)


@pm_bp.route('/cycles/new', methods=['GET', 'POST'])
@_login_required
def cycle_new():
    if request.method == 'POST':
        try:
            cid = svc.create_cycle(request.form)
            flash('Performance cycle created.', 'success')
            return redirect(url_for('pm.cycles'))
        except Exception as e:
            flash(f'Error: {e}', 'error')
    return render_template('pm/cycle_form.html', cycle=None)


@pm_bp.route('/cycles/<int:cycle_id>/edit', methods=['GET', 'POST'])
@_login_required
def cycle_edit(cycle_id):
    if request.method == 'POST':
        try:
            svc.update_cycle(cycle_id, request.form)
            flash('Performance cycle updated.', 'success')
            return redirect(url_for('pm.cycles'))
        except Exception as e:
            flash(f'Error: {e}', 'error')
    cycle = svc.get_cycle(cycle_id)
    if not cycle:
        flash('Cycle not found.', 'error')
        return redirect(url_for('pm.cycles'))
    return render_template('pm/cycle_form.html', cycle=cycle)


# ---------------------------------------------------------------------------
# OPCR
# ---------------------------------------------------------------------------

@pm_bp.route('/opcr')
@_login_required
def opcr():
    cycle_id = request.args.get('cycle_id', type=int)
    dept_id = request.args.get('department_id', type=int)
    if not cycle_id:
        flash('Select a performance cycle first.', 'info')
        return redirect(url_for('pm.cycles'))
    entries = svc.get_opcr_dashboard(cycle_id, department_id=dept_id)
    cycle = svc.get_cycle(cycle_id)
    with get_cursor() as cur:
        cur.execute("SELECT id, name FROM core.departments ORDER BY name")
        departments = cur.fetchall()
    return render_template('pm/opcr_form.html',
                           entries=entries, cycle=cycle,
                           departments=departments, dept_filter=dept_id)


@pm_bp.route('/opcr/save', methods=['POST'])
@_login_required
def save_opcr():
    data = {
        'id': request.form.get('id', type=int),
        'company_id': _get_company_id(),
        'department_id': request.form.get('department_id', type=int),
        'cycle_id': request.form.get('cycle_id', type=int),
        'mfo_code': request.form.get('mfo_code', ''),
        'performance_indicator': request.form.get('performance_indicator', ''),
        'target': request.form.get('target', ''),
        'target_value': request.form.get('target_value', type=float),
        'actual_value': request.form.get('actual_value', type=float),
        'self_rating': request.form.get('self_rating', type=float),
        'weight': request.form.get('weight', 1.0, type=float),
        'means_of_verification': request.form.get('means_of_verification', ''),
        'responsible_office': request.form.get('responsible_office', ''),
    }
    svc.save_opcr(data, session['user_id'])
    flash('OPCR entry saved.', 'success')
    return redirect(url_for('pm.opcr', cycle_id=data['cycle_id']))


# ---------------------------------------------------------------------------
# IPCR
# ---------------------------------------------------------------------------

@pm_bp.route('/ipcr')
@_login_required
def ipcr():
    cycle_id = request.args.get('cycle_id', type=int)
    employee_id = request.args.get('employee_id', type=int)
    # Non-admin users can only see their own IPCR — auto-scope to session employee
    role = session.get('role_code')
    if role not in ('SUPER_ADMIN', 'HR_ADMIN', 'EXECUTIVE', 'MANAGER'):
        employee_id = session.get('employee_id')
    entries = svc.get_ipcr_entries(employee_id=employee_id, cycle_id=cycle_id)
    with get_cursor() as cur:
        cur.execute("SELECT * FROM performance.perf_cycles ORDER BY period_from DESC")
        all_cycles = cur.fetchall()
    return render_template('pm/ipcr_form.html',
                           entries=entries, cycles=all_cycles,
                           cycle_id=cycle_id, employee_id=employee_id)


@pm_bp.route('/ipcr/<int:employee_id>/<int:cycle_id>')
@_login_required
def ipcr_detail(employee_id, cycle_id):
    entries = svc.get_ipcr_entries(employee_id=employee_id, cycle_id=cycle_id)
    summary = svc.get_ipcr_summary(employee_id=employee_id, cycle_id=cycle_id)
    computed = svc.compute_ipcr_rating(employee_id, cycle_id)
    cycle = svc.get_cycle(cycle_id)
    return render_template('pm/ipcr_summary.html',
                           entries=entries,
                           summary=summary[0] if summary else None,
                           computed=computed,
                           cycle=cycle,
                           employee_id=employee_id)


@pm_bp.route('/ipcr/save', methods=['POST'])
@_login_required
def save_ipcr():
    data = {
        'id': request.form.get('id', type=int),
        'employee_id': request.form.get('employee_id', type=int),
        'cycle_id': request.form.get('cycle_id', type=int),
        'opcr_id': request.form.get('opcr_id', type=int),
        'function_type': request.form.get('function_type', 'CORE'),
        'performance_indicator': request.form.get('performance_indicator', ''),
        'target': request.form.get('target', ''),
        'target_value': request.form.get('target_value', type=float),
        'actual_value': request.form.get('actual_value', type=float),
        'quality_rating': request.form.get('quality_rating', type=float),
        'efficiency_rating': request.form.get('efficiency_rating', type=float),
        'timeliness_rating': request.form.get('timeliness_rating', type=float),
        'weight': request.form.get('weight', 1.0, type=float),
        'means_of_verification': request.form.get('means_of_verification', ''),
        'evaluator_id': request.form.get('evaluator_id', type=int),
        'status': request.form.get('status', 'DRAFT'),
    }
    svc.save_ipcr(data, session['user_id'])
    flash('IPCR entry saved.', 'success')
    return redirect(url_for('pm.ipcr', cycle_id=data['cycle_id'], employee_id=data['employee_id']))


@pm_bp.route('/ipcr/<int:employee_id>/<int:cycle_id>/finalize', methods=['POST'])
@_login_required
def finalize_ipcr(employee_id, cycle_id):
    result = svc.finalize_ipcr(employee_id, cycle_id, session['user_id'])
    if result:
        flash('IPCR finalized and summary created.', 'success')
    else:
        flash('Cannot finalize — no rated entries found.', 'error')
    return redirect(url_for('pm.ipcr_detail', employee_id=employee_id, cycle_id=cycle_id))


# ---------------------------------------------------------------------------
# Ratings Distribution
# ---------------------------------------------------------------------------

@pm_bp.route('/ratings')
@_login_required
def ratings():
    cycle_id = request.args.get('cycle_id', type=int)
    distribution = svc.get_rating_distribution(cycle_id) if cycle_id else []
    pbb_list = svc.get_pbb_eligible(cycle_id) if cycle_id else []
    summaries = svc.get_ipcr_summary(cycle_id=cycle_id) if cycle_id else []
    with get_cursor() as cur:
        cur.execute("SELECT * FROM performance.perf_cycles ORDER BY period_from DESC")
        all_cycles = cur.fetchall()
    return render_template('pm/ratings.html',
                           distribution=distribution, pbb_list=pbb_list,
                           summaries=summaries, cycles=all_cycles, cycle_id=cycle_id)


# ---------------------------------------------------------------------------
# Succession Planning
# ---------------------------------------------------------------------------

@pm_bp.route('/succession')
@_login_required
def succession():
    cycle_id = request.args.get('cycle_id', type=int)
    matrix = svc.get_succession_matrix(cycle_id)
    return render_template('pm/succession.html', matrix=matrix, cycle_id=cycle_id)


# ---------------------------------------------------------------------------
# CSC IPCR Templates Library + PDF generators
# ---------------------------------------------------------------------------

def _admin_only():
    """HR/Manager-or-above gate for spawn/edit operations."""
    return session.get('role_code') in ('SUPER_ADMIN', 'HR_ADMIN', 'MANAGER', 'EXECUTIVE')


@pm_bp.route('/ipcr/templates')
@_login_required
def ipcr_templates():
    """Catalog of CSC-aligned starter IPCR templates (HR/admin only)."""
    if not _admin_only():
        abort(403)
    templates = csc.list_templates()
    with get_cursor() as cur:
        cur.execute("""
            SELECT id, name, period_from, period_to, status
              FROM performance.perf_cycles
             ORDER BY period_from DESC LIMIT 12
        """)
        cycles = cur.fetchall()
        cur.execute("""
            SELECT id,
                   COALESCE(first_name,'') || ' ' || COALESCE(last_name,'') AS name,
                   employee_no
              FROM core.employees
             WHERE is_active = TRUE
             ORDER BY last_name, first_name
        """)
        employees = cur.fetchall()
    return render_template('pm/ipcr_templates.html',
                           templates=templates, cycles=cycles,
                           employees=employees)


@pm_bp.route('/ipcr/spawn-from-template', methods=['POST'])
@_login_required
def ipcr_spawn():
    if not _admin_only():
        abort(403)
    code = (request.form.get('template_code') or '').strip()
    employee_id = request.form.get('employee_id', type=int)
    cycle_id = request.form.get('cycle_id', type=int)
    replace = request.form.get('replace') == '1'
    if not (code and employee_id and cycle_id):
        flash('Template, employee and cycle are all required.', 'error')
        return redirect(url_for('pm.ipcr_templates'))
    # evaluator_id FK points to core.employees, not core.users — translate
    evaluator_emp_id = session.get('employee_id')
    n = csc.spawn_from_template(code, employee_id, cycle_id,
                                evaluator_id=evaluator_emp_id,
                                replace_existing=replace)
    flash(f'Spawned {n} MFO line items for the selected employee.', 'success')
    return redirect(url_for('pm.ipcr_detail', employee_id=employee_id, cycle_id=cycle_id))


@pm_bp.route('/ipcr/<int:employee_id>/<int:cycle_id>/csc-form.pdf')
@_login_required
def ipcr_csc_pdf(employee_id, cycle_id):
    """Download the CSC-format IPCR PDF for one employee + cycle."""
    fname, buf = csc.render_ipcr_pdf(employee_id, cycle_id)
    return send_file(buf, as_attachment=False,
                     download_name=fname,
                     mimetype='application/pdf')


@pm_bp.route('/opcr/<int:department_id>/<int:cycle_id>/csc-form.pdf')
@_login_required
def opcr_csc_pdf(department_id, cycle_id):
    """Download the CSC-format OPCR PDF for one department + cycle."""
    fname, buf = csc.render_opcr_pdf(department_id, cycle_id)
    return send_file(buf, as_attachment=False,
                     download_name=fname,
                     mimetype='application/pdf')
