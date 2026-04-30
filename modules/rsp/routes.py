"""RSP Blueprint — Recruitment, Selection & Placement."""
from flask import Blueprint, render_template, request, redirect, url_for, flash, session
from functools import wraps
from modules.rsp import rsp_service as svc
from services.db import get_cursor

rsp_bp = Blueprint('rsp', __name__,
                   url_prefix='/rsp',
                   template_folder='../../templates/rsp')


def _login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated


def _get_companies():
    with get_cursor() as cur:
        cur.execute("SELECT id, name FROM core.companies ORDER BY name LIMIT 1")
        return cur.fetchone()


def _get_positions():
    with get_cursor() as cur:
        cur.execute("""
            SELECT p.id, p.title, jg.grade_level AS salary_grade
            FROM core.positions p
            LEFT JOIN core.job_grades jg ON jg.id = p.job_grade_id
            ORDER BY jg.grade_level DESC NULLS LAST, p.title
        """)
        return cur.fetchall()


def _get_departments():
    with get_cursor() as cur:
        cur.execute("SELECT id, name FROM core.departments ORDER BY name")
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Plantilla
# ---------------------------------------------------------------------------

@rsp_bp.route('/plantilla')
@_login_required
def plantilla():
    company = _get_companies()
    if not company:
        flash('No company configured.', 'error')
        return redirect('/')
    status = request.args.get('status')
    dept_id = request.args.get('dept_id', type=int)
    items = svc.get_plantilla(company['id'], status=status, department_id=dept_id)
    departments = _get_departments()
    return render_template('rsp/plantilla.html',
                           items=items, departments=departments,
                           status_filter=status, dept_filter=dept_id)


# ---------------------------------------------------------------------------
# Vacancies / Postings
# ---------------------------------------------------------------------------

@rsp_bp.route('/vacancies')
@_login_required
def vacancies():
    company = _get_companies()
    if not company:
        return redirect('/')
    status = request.args.get('status')
    vacancies = svc.get_vacancies(company['id'], status=status)
    return render_template('rsp/vacancies.html', vacancies=vacancies, status_filter=status)


@rsp_bp.route('/vacancies/<int:vacancy_id>/publish', methods=['POST'])
@_login_required
def publish_vacancy(vacancy_id):
    channel   = request.form.get('channel', 'AGENCY_BULLETIN')
    csc_ref   = request.form.get('csc_reference_no', '')
    closes_at = request.form.get('closes_at')
    posting_id = request.form.get('posting_id', type=int)
    svc.publish_vacancy(vacancy_id, posting_id, channel, csc_ref, closes_at, session['user_id'])
    flash('Vacancy published successfully.', 'success')
    return redirect(url_for('rsp.vacancies'))


# ---------------------------------------------------------------------------
# Applicant Pipeline
# ---------------------------------------------------------------------------

@rsp_bp.route('/applicants')
@_login_required
def applicants():
    posting_id = request.args.get('posting_id', type=int)
    stage      = request.args.get('stage')
    apps = svc.get_applicants(posting_id=posting_id, stage=stage)
    # Group by stage for Kanban view
    stages = ['APPLIED', 'SCREENING', 'INTERVIEW', 'PSB', 'OFFER', 'HIRED', 'REJECTED']
    by_stage = {s: [] for s in stages}
    for a in apps:
        if a['stage'] in by_stage:
            by_stage[a['stage']].append(a)
    return render_template('rsp/applicants.html',
                           by_stage=by_stage, stages=stages,
                           posting_id=posting_id, stage_filter=stage)


@rsp_bp.route('/applicants/<int:applicant_id>/advance', methods=['POST'])
@_login_required
def advance_stage(applicant_id):
    new_stage = request.form.get('new_stage')
    svc.advance_applicant_stage(applicant_id, new_stage, session['user_id'])
    flash(f'Applicant moved to {new_stage}.', 'success')
    return redirect(request.referrer or url_for('rsp.applicants'))


# ---------------------------------------------------------------------------
# PSB Deliberations
# ---------------------------------------------------------------------------

@rsp_bp.route('/psb')
@_login_required
def psb():
    req_id = request.args.get('requisition_id', type=int)
    deliberations = svc.get_psb_deliberations(req_id)
    return render_template('rsp/psb_deliberation.html',
                           deliberations=deliberations, requisition_id=req_id)


@rsp_bp.route('/psb/<int:delib_id>/scores')
@_login_required
def psb_scores(delib_id):
    scores = svc.get_psb_scores(delib_id)
    return render_template('rsp/psb_scores.html', scores=scores, delib_id=delib_id)


@rsp_bp.route('/psb/<int:delib_id>/score', methods=['POST'])
@_login_required
def save_score(delib_id):
    applicant_id = request.form.get('applicant_id', type=int)
    scores = {
        'education':   float(request.form.get('education_score', 0)),
        'experience':  float(request.form.get('experience_score', 0)),
        'training':    float(request.form.get('training_score', 0)),
        'performance': float(request.form.get('performance_score', 0)),
        'interview':   float(request.form.get('interview_score', 0)),
    }
    svc.save_psb_score(delib_id, applicant_id, scores, session['user_id'])
    flash('Score saved.', 'success')
    return redirect(url_for('rsp.psb_scores', delib_id=delib_id))


# ---------------------------------------------------------------------------
# Appointments
# ---------------------------------------------------------------------------

@rsp_bp.route('/appointments')
@_login_required
def appointments():
    status    = request.args.get('status')
    emp_id    = request.args.get('employee_id', type=int)
    appts     = svc.get_appointments(employee_id=emp_id, status=status)
    return render_template('rsp/appointment_form.html',
                           appointments=appts, status_filter=status)


@rsp_bp.route('/appointments/new', methods=['GET', 'POST'])
@_login_required
def new_appointment():
    if request.method == 'POST':
        appt_id = svc.issue_appointment(
            employee_id      = request.form.get('employee_id', type=int),
            position_id      = request.form.get('position_id', type=int),
            plantilla_item_id= request.form.get('plantilla_item_id', type=int),
            appt_type        = request.form.get('appointment_type', 'PERMANENT'),
            appt_no          = request.form.get('appointment_no'),
            effective_date   = request.form.get('effective_date'),
            salary_grade     = request.form.get('salary_grade', type=int),
            step_no          = request.form.get('step_no', 1, type=int),
            monthly_salary   = request.form.get('monthly_salary', type=float),
            issued_by        = session['user_id'],
            end_date         = request.form.get('end_date') or None
        )
        flash('Appointment paper created and sent for approval.', 'success')
        return redirect(url_for('rsp.appointments'))
    positions  = _get_positions()
    company    = _get_companies()
    plantilla  = svc.get_plantilla(company['id'], status='VACANT') if company else []
    return render_template('rsp/new_appointment.html',
                           positions=positions, plantilla=plantilla)


# ---------------------------------------------------------------------------
# Next-in-Rank
# ---------------------------------------------------------------------------

@rsp_bp.route('/next-in-rank')
@_login_required
def next_in_rank():
    position_id = request.args.get('position_id', type=int)
    positions   = _get_positions()
    candidates  = svc.get_next_in_rank(position_id) if position_id else []
    return render_template('rsp/next_in_rank.html',
                           candidates=candidates, positions=positions,
                           position_id=position_id)


@rsp_bp.route('/next-in-rank/compute', methods=['POST'])
@_login_required
def compute_nir():
    position_id = request.form.get('position_id', type=int)
    count = svc.compute_next_in_rank(position_id, session['user_id'])
    notified = svc.notify_next_in_rank(position_id, session['user_id'])
    flash(f'Next-in-rank computed: {count} employees ranked, {notified} notified.', 'success')
    return redirect(url_for('rsp.next_in_rank', position_id=position_id))


# ---------------------------------------------------------------------------
# Onboarding
# ---------------------------------------------------------------------------

@rsp_bp.route('/onboarding')
@_login_required
def onboarding():
    emp_id = request.args.get('employee_id', type=int)
    with get_cursor() as cur:
        cur.execute("""
            SELECT oc.*, e.first_name || ' ' || e.last_name AS employee_name,
                   COUNT(oci.id) AS total_items,
                   COUNT(oci.id) FILTER (WHERE oci.is_completed) AS completed_items
            FROM onboarding.onb_checklists oc
            JOIN core.employees e ON e.id = oc.employee_id
            LEFT JOIN onboarding.onb_checklist_items oci ON oci.checklist_id = oc.id
            WHERE oc.type = 'ONBOARDING'
              AND (%s IS NULL OR oc.employee_id = %s)
            GROUP BY oc.id, e.first_name, e.last_name
            ORDER BY oc.created_at DESC
        """, (emp_id, emp_id))
        checklists = cur.fetchall()
    return render_template('rsp/onboarding.html', checklists=checklists, emp_filter=emp_id)


@rsp_bp.route('/onboarding/<int:checklist_id>/item/<int:item_id>/complete', methods=['POST'])
@_login_required
def complete_item(checklist_id, item_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE onboarding.onb_checklist_items
            SET is_completed = TRUE, completed_by = %s, completed_at = NOW()
            WHERE id = %s AND checklist_id = %s
        """, (session['user_id'], item_id, checklist_id))
    flash('Item marked complete.', 'success')
    return redirect(request.referrer or url_for('rsp.onboarding'))


# ---------------------------------------------------------------------------
# Offboarding
# ---------------------------------------------------------------------------

@rsp_bp.route('/offboarding')
@_login_required
def offboarding():
    emp_id = request.args.get('employee_id', type=int)
    clearance_items = svc.get_clearance_items(emp_id) if emp_id else []
    with get_cursor() as cur:
        cur.execute("""
            SELECT oe.*, e.first_name || ' ' || e.last_name AS employee_name,
                   e.id AS emp_id
            FROM onboarding.offb_exit_interviews oe
            JOIN core.employees e ON e.id = oe.employee_id
            ORDER BY oe.last_working_day DESC NULLS LAST
            LIMIT 50
        """)
        exits = cur.fetchall()
    return render_template('rsp/offboarding.html',
                           clearance_items=clearance_items,
                           exits=exits, emp_filter=emp_id)


@rsp_bp.route('/offboarding/clear', methods=['POST'])
@_login_required
def clear_item():
    employee_id    = request.form.get('employee_id', type=int)
    clearance_type = request.form.get('clearance_type')
    remarks        = request.form.get('remarks', '')
    svc.mark_clearance(employee_id, clearance_type, session['user_id'], remarks)
    flash(f'{clearance_type.replace("_"," ").title()} clearance recorded.', 'success')
    return redirect(url_for('rsp.offboarding', employee_id=employee_id))
