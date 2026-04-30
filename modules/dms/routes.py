"""DMS Blueprint — Document Management / 201 File."""
from flask import Blueprint, render_template, request, redirect, url_for, flash, session
from functools import wraps
from modules.dms import dms_service as svc
from services.db import get_cursor

dms_bp = Blueprint('dms', __name__,
                   url_prefix='/dms',
                   template_folder='../../templates/dms')


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


@dms_bp.route('/')
@_login_required
def dashboard():
    company_id = _get_company_id()
    dept_id = request.args.get('department_id', type=int)
    completeness = svc.get_completeness_dashboard(company_id, department_id=dept_id) if company_id else []
    with get_cursor() as cur:
        cur.execute("SELECT id, name FROM core.departments ORDER BY name")
        departments = cur.fetchall()
    return render_template('dms/dashboard.html',
                           completeness=completeness, departments=departments, dept_id=dept_id)


@dms_bp.route('/employee/<int:employee_id>')
@_login_required
def employee_201(employee_id):
    checklist = svc.get_checklist_for_employee(employee_id)
    with get_cursor() as cur:
        cur.execute("SELECT first_name || ' ' || last_name AS name FROM core.employees WHERE id = %s", (employee_id,))
        emp = cur.fetchone()
    return render_template('dms/employee_201.html',
                           checklist=checklist, employee_id=employee_id,
                           employee_name=emp['name'] if emp else '—')


@dms_bp.route('/checklist')
@_login_required
def checklist():
    company_id = _get_company_id()
    categories = svc.get_categories(company_id) if company_id else []
    return render_template('dms/checklist.html', categories=categories)


@dms_bp.route('/requests')
@_login_required
def requests_list():
    company_id = _get_company_id()
    status = request.args.get('status')
    reqs = svc.get_document_requests(company_id, status=status) if company_id else []
    return render_template('dms/requests.html', requests=reqs, status_filter=status)


@dms_bp.route('/requests/new', methods=['POST'])
@_login_required
def create_request():
    company_id = _get_company_id()
    svc.create_document_request(
        company_id,
        request.form.get('employee_id', type=int),
        request.form.get('document_type'),
        request.form.get('purpose'),
        session['user_id'],
        request.form.get('due_date') or None
    )
    flash('Document request created.', 'success')
    return redirect(url_for('dms.requests_list'))


@dms_bp.route('/service-record/<int:employee_id>')
@_login_required
def service_record(employee_id):
    record = svc.get_service_record(employee_id)
    with get_cursor() as cur:
        cur.execute("SELECT first_name || ' ' || last_name AS name FROM core.employees WHERE id = %s", (employee_id,))
        emp = cur.fetchone()
    return render_template('dms/service_record.html',
                           record=record, employee_id=employee_id,
                           employee_name=emp['name'] if emp else '—')


@dms_bp.route('/service-record/<int:employee_id>/generate', methods=['POST'])
@_login_required
def generate_service_record(employee_id):
    result = svc.generate_service_record(employee_id, session['user_id'])
    if result:
        flash('Service record (CSC Form 212) generated.', 'success')
    else:
        flash('Employee not found.', 'error')
    return redirect(url_for('dms.service_record', employee_id=employee_id))


@dms_bp.route('/leave-card/<int:employee_id>')
@_login_required
def leave_card(employee_id):
    year = request.args.get('year', type=int)
    data = svc.get_leave_card_summary(employee_id, year=year)
    with get_cursor() as cur:
        cur.execute("SELECT first_name || ' ' || last_name AS name FROM core.employees WHERE id = %s", (employee_id,))
        emp = cur.fetchone()
    return render_template('dms/leave_card.html',
                           data=data, employee_id=employee_id,
                           employee_name=emp['name'] if emp else '—')


@dms_bp.route('/retention')
@_login_required
def retention():
    company_id = _get_company_id()
    alerts = svc.get_retention_alerts(company_id) if company_id else []
    return render_template('dms/retention.html', alerts=alerts)


# ---------------------------------------------------------------------------
# Certificate Request Queue (HR Admin)
# ---------------------------------------------------------------------------

@dms_bp.route('/certificate-requests')
@_login_required
def certificate_queue():
    status = request.args.get('status')
    reqs = svc.get_certificate_requests(status=status)
    return render_template('dms/certificate_queue.html', requests=reqs, status_filter=status)


@dms_bp.route('/certificate-requests/<int:req_id>/process', methods=['POST'])
@_login_required
def process_cert(req_id):
    svc.process_certificate_request(req_id, session['user_id'])
    flash('Certificate request is now processing.', 'success')
    return redirect(url_for('dms.certificate_queue'))


@dms_bp.route('/certificate-requests/<int:req_id>/ready', methods=['POST'])
@_login_required
def ready_cert(req_id):
    svc.mark_certificate_ready(req_id, session['user_id'])
    flash('Certificate marked as ready for release.', 'success')
    return redirect(url_for('dms.certificate_queue'))


@dms_bp.route('/certificate-requests/<int:req_id>/release', methods=['POST'])
@_login_required
def release_cert(req_id):
    svc.release_certificate(req_id, session['user_id'])
    flash('Certificate released to employee.', 'success')
    return redirect(url_for('dms.certificate_queue'))


@dms_bp.route('/certificate-requests/<int:req_id>/reject', methods=['POST'])
@_login_required
def reject_cert(req_id):
    reason = request.form.get('reason', '')
    svc.reject_certificate_request(req_id, session['user_id'], reason)
    flash('Certificate request rejected.', 'info')
    return redirect(url_for('dms.certificate_queue'))
