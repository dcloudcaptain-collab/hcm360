"""Discipline Blueprint — Grievance & Administrative Cases."""
from flask import Blueprint, render_template, request, redirect, url_for, flash, session
from functools import wraps
from modules.discipline import discipline_service as svc
from services.db import get_cursor

discipline_bp = Blueprint('discipline', __name__,
                          url_prefix='/discipline',
                          template_folder='../../templates/discipline')


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


@discipline_bp.route('/')
@_login_required
def dashboard():
    company_id = _get_company_id()
    status = request.args.get('status')
    cases = svc.get_cases(company_id, status=status,
                          user_id=session.get('user_id'),
                          user_role=session.get('role_code')) if company_id else []
    return render_template('discipline/dashboard.html', cases=cases, status_filter=status)


@discipline_bp.route('/case/<int:case_id>')
@_login_required
def case_detail(case_id):
    data = svc.get_case(case_id)
    if not data:
        flash('Case not found.', 'error')
        return redirect(url_for('discipline.dashboard'))
    return render_template('discipline/case_detail.html', **data)


@discipline_bp.route('/cases/new', methods=['GET', 'POST'])
@_login_required
def new_case():
    if request.method == 'POST':
        company_id = _get_company_id()
        result = svc.create_case(
            company_id,
            request.form.get('respondent_id', type=int),
            request.form.get('complainant_id', type=int),
            request.form.get('case_type_id', type=int),
            request.form.get('offense_description'),
            request.form.get('date_of_offense') or None,
            session['user_id']
        )
        flash(f'Case {result["case_no"]} created.', 'success')
        return redirect(url_for('discipline.case_detail', case_id=result['id']))

    case_types = svc.get_case_types()
    with get_cursor() as cur:
        cur.execute("SELECT id, first_name || ' ' || last_name AS name FROM core.employees WHERE is_active = TRUE ORDER BY last_name")
        employees = cur.fetchall()
    return render_template('discipline/new_case.html', case_types=case_types, employees=employees)


@discipline_bp.route('/case/<int:case_id>/complaint', methods=['POST'])
@_login_required
def complaint(case_id):
    svc.file_complaint(case_id, request.form.get('complaint_text'),
                       request.form.get('evidence_summary'), session['user_id'])
    flash('Complaint filed.', 'success')
    return redirect(url_for('discipline.case_detail', case_id=case_id))


@discipline_bp.route('/case/<int:case_id>/investigate', methods=['POST'])
@_login_required
def investigate(case_id):
    svc.start_investigation(case_id, session['user_id'])
    flash('Investigation started.', 'success')
    return redirect(url_for('discipline.case_detail', case_id=case_id))


@discipline_bp.route('/case/<int:case_id>/formal-charge', methods=['POST'])
@_login_required
def formal_charge(case_id):
    svc.issue_formal_charge(case_id, request.form.get('charge_text'),
                            request.form.get('offense_classification'), session['user_id'])
    flash('Formal charge issued. Answer deadline: 5 calendar days.', 'success')
    return redirect(url_for('discipline.case_detail', case_id=case_id))


@discipline_bp.route('/case/<int:case_id>/hearing', methods=['POST'])
@_login_required
def hearing(case_id):
    svc.schedule_hearing(case_id, request.form.get('hearing_type', 'FORMAL'),
                         request.form.get('scheduled_date'),
                         request.form.get('venue'),
                         request.form.get('presiding_officer_id', type=int))
    flash('Hearing scheduled.', 'success')
    return redirect(url_for('discipline.case_detail', case_id=case_id))


@discipline_bp.route('/case/<int:case_id>/decision', methods=['POST'])
@_login_required
def decision(case_id):
    svc.record_decision(case_id, request.form.get('verdict'),
                        request.form.get('penalty'), request.form.get('penalty_details'),
                        request.form.get('decision_text'), session['user_id'],
                        request.form.get('effectivity_date') or None)
    flash('Decision recorded.', 'success')
    return redirect(url_for('discipline.case_detail', case_id=case_id))
