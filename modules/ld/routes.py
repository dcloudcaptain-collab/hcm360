"""LD Blueprint — Learning & Development."""
from flask import Blueprint, render_template, request, redirect, url_for, flash, session, jsonify
from functools import wraps
from modules.ld import ld_service as svc
from services.db import get_cursor

ld_bp = Blueprint('ld', __name__,
                  url_prefix='/ld',
                  template_folder='../../templates/ld')


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


@ld_bp.route('/programs')
@_login_required
def programs():
    company_id = _get_company_id()
    csc_only = request.args.get('csc_only') == '1'
    category = request.args.get('category')
    progs = svc.get_programs(company_id, csc_only=csc_only, category=category) if company_id else []
    return render_template('ld/programs.html', programs=progs,
                           csc_only=csc_only, category_filter=category)


@ld_bp.route('/programs/new', methods=['GET', 'POST'])
@_login_required
def program_new():
    if request.method == 'POST':
        try:
            pid = svc.create_program(request.form)
            flash('Training program created.', 'success')
            return redirect(url_for('ld.programs'))
        except Exception as e:
            flash(f'Error: {e}', 'error')
    return render_template('ld/program_form.html', program=None)


@ld_bp.route('/programs/<int:program_id>/edit', methods=['GET', 'POST'])
@_login_required
def program_edit(program_id):
    if request.method == 'POST':
        try:
            svc.update_program(program_id, request.form)
            flash('Training program updated.', 'success')
            return redirect(url_for('ld.programs'))
        except Exception as e:
            flash(f'Error: {e}', 'error')
    program = svc.get_program(program_id)
    if not program:
        flash('Program not found.', 'error')
        return redirect(url_for('ld.programs'))
    return render_template('ld/program_form.html', program=program)


@ld_bp.route('/sessions')
@_login_required
def sessions():
    program_id = request.args.get('program_id', type=int)
    status = request.args.get('status')
    sess = svc.get_sessions(program_id=program_id, status=status)
    return render_template('ld/sessions.html', sessions=sess,
                           program_id=program_id, status_filter=status)


@ld_bp.route('/tna')
@_login_required
def tna():
    cycle_id = request.args.get('cycle_id', type=int)
    dept_id = request.args.get('department_id', type=int)
    entries = svc.get_tna_entries(cycle_id=cycle_id, department_id=dept_id)
    with get_cursor() as cur:
        cur.execute("SELECT id, name FROM performance.perf_cycles ORDER BY period_from DESC")
        cycles = cur.fetchall()
        cur.execute("SELECT id, name FROM core.departments ORDER BY name")
        departments = cur.fetchall()
    return render_template('ld/tna.html', entries=entries, cycles=cycles,
                           departments=departments, cycle_id=cycle_id, dept_id=dept_id)


@ld_bp.route('/scholarships')
@_login_required
def scholarships():
    status = request.args.get('status')
    schols = svc.get_scholarships(status=status)
    return render_template('ld/scholarships.html', scholarships=schols, status_filter=status)


@ld_bp.route('/narrative-reports')
@_login_required
def narrative_reports():
    status = request.args.get('status')
    reports = svc.get_narrative_reports(status=status)
    return render_template('ld/narrative_report.html', reports=reports, status_filter=status)


@ld_bp.route('/narrative-reports/submit', methods=['POST'])
@_login_required
def submit_nrf():
    enrollment_id = request.form.get('enrollment_id', type=int)
    employee_id = session.get('employee_id')
    if not employee_id:
        flash('No employee record linked.', 'error')
        return redirect(url_for('ld.narrative_reports'))
    form_data = {
        'training_title': request.form.get('training_title'),
        'training_dates': request.form.get('training_dates'),
        'venue': request.form.get('venue'),
        'facilitator': request.form.get('facilitator'),
        'learning_objectives': request.form.get('learning_objectives'),
        'key_learnings': request.form.get('key_learnings'),
        'application_plans': request.form.get('application_plans'),
        'challenges': request.form.get('challenges'),
        'recommendations': request.form.get('recommendations'),
        'evaluation_rating': request.form.get('evaluation_rating', type=float),
    }
    svc.submit_narrative_report(enrollment_id, employee_id, form_data)
    flash('Narrative Report submitted for approval.', 'success')
    return redirect(url_for('ld.narrative_reports'))


@ld_bp.route('/attendance')
@_login_required
def attendance():
    session_id = request.args.get('session_id', type=int)
    logs = svc.get_attendance_logs(session_id) if session_id else []
    sess = svc.get_sessions(status='SCHEDULED')
    return render_template('ld/attendance.html', logs=logs, sessions=sess, session_id=session_id)


@ld_bp.route('/attendance/<int:session_id>/checkin', methods=['POST'])
@_login_required
def checkin(session_id):
    """Mobile geo-tagged check-in endpoint."""
    data = request.get_json(silent=True) or request.form
    enrollment_id = data.get('enrollment_id', type=int) if hasattr(data, 'get') else int(data.get('enrollment_id', 0))
    lat = float(data.get('lat', 0))
    lng = float(data.get('lng', 0))
    accuracy = float(data.get('accuracy', 0))
    device_id = data.get('device_id')
    ip_address = request.remote_addr

    result = svc.validate_geo_attendance(enrollment_id, lat, lng, accuracy, device_id, ip_address)
    if result:
        if request.is_json:
            return jsonify({'status': 'ok', 'id': result['id']})
        flash('Check-in recorded.', 'success')
    else:
        if request.is_json:
            return jsonify({'status': 'error', 'message': 'Enrollment not found'}), 404
        flash('Check-in failed — enrollment not found.', 'error')
    return redirect(url_for('ld.attendance', session_id=session_id))
