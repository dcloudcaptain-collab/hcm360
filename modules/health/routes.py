"""Health Blueprint — Occupational Health & Safety."""
from datetime import date
from flask import Blueprint, render_template, request, redirect, url_for, flash, session
from functools import wraps
from modules.health import health_service as svc
from services.db import get_cursor

health_bp = Blueprint('health', __name__,
                      url_prefix='/health',
                      template_folder='../../templates/health')


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


@health_bp.route('/')
@_login_required
def dashboard():
    company_id = _get_company_id()
    yr = date.today().year
    compliance = svc.get_pe_compliance(company_id, yr) if company_id else []
    expiring = svc.get_expiring_certificates(company_id) if company_id else []
    incidents = svc.get_incidents(company_id) if company_id else []
    return render_template('health/dashboard.html',
                           compliance=compliance, expiring_certs=expiring,
                           incidents=incidents[:10], year=yr)


@health_bp.route('/pe')
@_login_required
def pe_schedules():
    company_id = _get_company_id()
    year = request.args.get('year', type=int)
    schedules = svc.get_pe_schedules(company_id, year=year) if company_id else []
    return render_template('health/pe_schedule.html', schedules=schedules, year_filter=year)


@health_bp.route('/pe/new', methods=['GET', 'POST'])
@_login_required
def pe_new():
    if request.method == 'POST':
        try:
            svc.create_pe_schedule(request.form, created_by=session.get('user_id'))
            flash('PE schedule created.', 'success')
            return redirect(url_for('health.pe_schedules'))
        except Exception as e:
            flash(f'Error: {e}', 'error')
    return render_template('health/pe_form.html')


@health_bp.route('/pe/<int:schedule_id>')
@_login_required
def pe_results(schedule_id):
    dept_id = request.args.get('department_id', type=int)
    results = svc.get_pe_results(schedule_id, department_id=dept_id)
    with get_cursor() as cur:
        cur.execute("SELECT id, name FROM core.departments ORDER BY name")
        departments = cur.fetchall()
    return render_template('health/pe_results.html',
                           results=results, schedule_id=schedule_id,
                           departments=departments, dept_id=dept_id)


@health_bp.route('/certificates')
@_login_required
def certificates():
    status = request.args.get('status')
    certs = svc.get_health_certificates(status=status)
    return render_template('health/certificates.html', certificates=certs, status_filter=status)


@health_bp.route('/incidents')
@_login_required
def incidents_list():
    company_id = _get_company_id()
    status = request.args.get('status')
    inc_type = request.args.get('type')
    incidents = svc.get_incidents(company_id, status=status, incident_type=inc_type) if company_id else []
    return render_template('health/incidents.html', incidents=incidents,
                           status_filter=status, type_filter=inc_type)


@health_bp.route('/incidents/<int:incident_id>')
@_login_required
def incident_detail(incident_id):
    data = svc.get_incident(incident_id)
    if not data:
        flash('Incident not found.', 'error')
        return redirect(url_for('health.incidents_list'))
    return render_template('health/incident_detail.html', **data)


@health_bp.route('/incidents/new', methods=['POST'])
@_login_required
def report_incident():
    company_id = _get_company_id()
    result = svc.report_incident(
        company_id,
        request.form.get('incident_date'),
        request.form.get('location'),
        request.form.get('incident_type'),
        request.form.get('severity', 'MINOR'),
        request.form.get('description'),
        request.form.get('immediate_action_taken'),
        session['user_id'],
        request.form.get('dole_reportable') == '1'
    )
    flash(f'Incident {result["incident_no"]} reported.', 'success')
    return redirect(url_for('health.incident_detail', incident_id=result['id']))


@health_bp.route('/wellness')
@_login_required
def wellness():
    company_id = _get_company_id()
    status = request.args.get('status')
    programs = svc.get_wellness_programs(company_id, status=status) if company_id else []
    return render_template('health/wellness.html', programs=programs, status_filter=status)


@health_bp.route('/wellness/new', methods=['GET', 'POST'])
@_login_required
def wellness_new():
    if request.method == 'POST':
        try:
            svc.create_wellness_program(request.form, created_by=session.get('user_id'))
            flash('Wellness program created.', 'success')
            return redirect(url_for('health.wellness'))
        except Exception as e:
            flash(f'Error: {e}', 'error')
    return render_template('health/wellness_form.html')


@health_bp.route('/wellness/<int:program_id>/enroll', methods=['POST'])
@_login_required
def enroll(program_id):
    emp_id = session.get('employee_id')
    if emp_id:
        svc.enroll_employee(program_id, emp_id, enrolled_by=session.get('user_id'))
        flash('Enrolled successfully.', 'success')
    else:
        flash('No employee record linked.', 'error')
    return redirect(url_for('health.wellness_detail', program_id=program_id))


# ── Program detail + admin management ────────────────────────────────
@health_bp.route('/wellness/<int:program_id>')
@_login_required
def wellness_detail(program_id):
    data = svc.get_wellness_program(program_id)
    if not data:
        flash('Program not found.', 'error')
        return redirect(url_for('health.wellness'))
    # Has the current user enrolled?
    emp_id = session.get('employee_id')
    my_enrollment = None
    if emp_id:
        for e in data['enrollments']:
            if e['employee_id'] == emp_id:
                my_enrollment = e
                break
    # Summary stats for the detail header
    total = len(data['enrollments'])
    attended = sum(1 for e in data['enrollments'] if e.get('attended_at'))
    with_feedback = sum(1 for e in data['enrollments'] if e.get('feedback') or e.get('feedback_rating'))
    ratings = [e['feedback_rating'] for e in data['enrollments'] if e.get('feedback_rating')]
    avg_rating = round(sum(ratings) / len(ratings), 1) if ratings else None
    stats = {
        'total': total, 'attended': attended,
        'with_feedback': with_feedback, 'avg_rating': avg_rating,
        'no_show': sum(1 for e in data['enrollments'] if e.get('status') == 'NO_SHOW'),
    }
    return render_template('health/wellness_detail.html',
                           program=data['program'],
                           enrollments=data['enrollments'],
                           my_enrollment=my_enrollment,
                           stats=stats)


@health_bp.route('/wellness/<int:program_id>/assign', methods=['POST'])
@_login_required
def wellness_assign(program_id):
    """Admin bulk-enroll: accepts employee_ids[] via form or JSON."""
    role = session.get('role_code')
    if role not in ('SUPER_ADMIN', 'HR_ADMIN'):
        flash('Access denied.', 'error')
        return redirect(url_for('health.wellness_detail', program_id=program_id))
    data = request.get_json(silent=True) or {}
    ids = data.get('employee_ids') or request.form.getlist('target_employee_ids[]') \
          or request.form.getlist('target_employee_ids')
    try:
        ids = [int(x) for x in ids if x]
    except ValueError:
        return jsonify({'ok': False, 'message': 'Invalid employee IDs'}), 400
    if not ids:
        flash('Select at least one employee, department, or group.', 'error')
        return redirect(url_for('health.wellness_detail', program_id=program_id))
    n = svc.enroll_many(program_id, ids, enrolled_by=session.get('user_id'))
    flash(f'Enrolled {n} new employee(s); duplicates ignored.', 'success')
    return redirect(url_for('health.wellness_detail', program_id=program_id))


@health_bp.route('/wellness/enrollment/<int:enrollment_id>/attend', methods=['POST'])
@_login_required
def wellness_mark_attend(enrollment_id):
    role = session.get('role_code')
    if role not in ('SUPER_ADMIN', 'HR_ADMIN'):
        return jsonify({'ok': False, 'message': 'Access denied'}), 403
    attended = request.form.get('attended', 'true').lower() == 'true'
    svc.mark_attendance(enrollment_id, attended)
    if request.is_json or request.headers.get('X-Requested-With') == 'XMLHttpRequest':
        return jsonify({'ok': True, 'attended': attended})
    return redirect(request.referrer or url_for('health.wellness'))


@health_bp.route('/wellness/enrollment/<int:enrollment_id>/no-show', methods=['POST'])
@_login_required
def wellness_mark_noshow(enrollment_id):
    role = session.get('role_code')
    if role not in ('SUPER_ADMIN', 'HR_ADMIN'):
        return jsonify({'ok': False, 'message': 'Access denied'}), 403
    svc.mark_no_show(enrollment_id)
    return redirect(request.referrer or url_for('health.wellness'))


@health_bp.route('/wellness/<int:program_id>/feedback', methods=['POST'])
@_login_required
def wellness_submit_feedback(program_id):
    emp_id = session.get('employee_id')
    if not emp_id:
        flash('Your account is not linked to an employee record.', 'error')
        return redirect(url_for('health.wellness_detail', program_id=program_id))
    rating = request.form.get('rating', type=int)
    feedback = (request.form.get('feedback') or '').strip() or None
    n = svc.submit_feedback(program_id, emp_id, rating, feedback)
    if n:
        flash('Thanks — your feedback has been recorded.', 'success')
    else:
        flash('You need to be enrolled in this program before submitting feedback.', 'error')
    return redirect(url_for('health.wellness_detail', program_id=program_id))


@health_bp.route('/wellness/<int:program_id>/edit', methods=['GET', 'POST'])
@_login_required
def wellness_edit(program_id):
    role = session.get('role_code')
    if role not in ('SUPER_ADMIN', 'HR_ADMIN'):
        flash('Access denied.', 'error')
        return redirect(url_for('health.wellness_detail', program_id=program_id))
    data = svc.get_wellness_program(program_id)
    if not data:
        return redirect(url_for('health.wellness'))
    if request.method == 'POST':
        svc.update_wellness_program(program_id, request.form)
        flash('Program updated.', 'success')
        return redirect(url_for('health.wellness_detail', program_id=program_id))
    return render_template('health/wellness_form.html', program=data['program'])
