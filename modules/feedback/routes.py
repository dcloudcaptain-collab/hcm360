"""Feedback Blueprint — continuous feedback and 360 reviews."""
from flask import Blueprint, render_template, request, redirect, url_for, flash, session
from functools import wraps
from modules.feedback import feedback_service as svc
from services.db import get_cursor

feedback_bp = Blueprint('feedback', __name__,
                        url_prefix='/feedback',
                        template_folder='../../templates/feedback')


def _login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated


# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------

@feedback_bp.route('/')
@_login_required
def index():
    emp_id = session.get('employee_id')
    role = session.get('role_code', '')

    if role in ('HR_ADMIN', 'SUPER_ADMIN'):
        stats = svc.get_feedback_dashboard()
    else:
        stats = svc.get_feedback_dashboard(emp_id)

    pending = svc.get_pending_requests(emp_id) if emp_id else []

    # Recent feedback received (last 5)
    received = []
    if emp_id:
        all_received = svc.get_feedback_received(emp_id)
        received = all_received[:5]

    return render_template('feedback/index.html',
                           stats=stats, pending=pending, received=received)


# ---------------------------------------------------------------------------
# Request Feedback
# ---------------------------------------------------------------------------

@feedback_bp.route('/request', methods=['GET'])
@_login_required
def request_form():
    with get_cursor() as cur:
        cur.execute("""
            SELECT id, full_name, department_name
            FROM core.v_employees_full
            WHERE is_active = true
            ORDER BY full_name
        """)
        employees = cur.fetchall()
    return render_template('feedback/request_form.html', employees=employees)


@feedback_bp.route('/request', methods=['POST'])
@_login_required
def request_submit():
    emp_id = session.get('employee_id')
    subject_id = request.form.get('subject_id', type=int)
    respondent_id = request.form.get('respondent_id', type=int)
    feedback_type = request.form.get('feedback_type', 'PEER')
    message = request.form.get('message', '')
    due_date = request.form.get('due_date') or None

    if not subject_id or not respondent_id:
        flash('Please select both the person to review and the respondent.', 'error')
        return redirect(url_for('feedback.request_form'))

    svc.request_feedback(emp_id, subject_id, respondent_id, feedback_type, message, due_date)
    flash('Feedback request sent.', 'success')
    return redirect(url_for('feedback.index'))


# ---------------------------------------------------------------------------
# Respond to Feedback Request
# ---------------------------------------------------------------------------

@feedback_bp.route('/respond/<int:request_id>', methods=['GET'])
@_login_required
def respond_form(request_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT fr.*,
                   es.full_name AS subject_name,
                   er.full_name AS requester_name
            FROM performance.feedback_requests fr
            LEFT JOIN core.v_employees_full es ON es.id = fr.subject_id
            LEFT JOIN core.v_employees_full er ON er.id = fr.requester_id
            WHERE fr.id = %s
        """, (request_id,))
        freq = cur.fetchone()

    if not freq:
        flash('Request not found.', 'error')
        return redirect(url_for('feedback.index'))

    return render_template('feedback/respond_form.html', freq=freq)


@feedback_bp.route('/respond/<int:request_id>', methods=['POST'])
@_login_required
def respond_submit(request_id):
    emp_id = session.get('employee_id')

    with get_cursor() as cur:
        cur.execute("SELECT * FROM performance.feedback_requests WHERE id = %s", (request_id,))
        freq = cur.fetchone()

    if not freq:
        flash('Request not found.', 'error')
        return redirect(url_for('feedback.index'))

    rating = request.form.get('rating', type=int)
    strengths = request.form.get('strengths', '')
    improvements = request.form.get('improvements', '')
    comments = request.form.get('comments', '')
    is_anonymous = request.form.get('is_anonymous') == 'on'
    visibility = request.form.get('visibility', 'MANAGER')

    svc.submit_feedback(
        request_id=request_id,
        author_id=emp_id,
        subject_id=freq['subject_id'],
        feedback_type=freq['feedback_type'],
        rating=rating,
        strengths=strengths,
        improvements=improvements,
        comments=comments,
        is_anonymous=is_anonymous,
        visibility=visibility
    )
    flash('Feedback submitted.', 'success')
    return redirect(url_for('feedback.index'))


# ---------------------------------------------------------------------------
# Feedback Lists
# ---------------------------------------------------------------------------

@feedback_bp.route('/received')
@_login_required
def received():
    emp_id = session.get('employee_id')
    items = svc.get_feedback_received(emp_id) if emp_id else []
    return render_template('feedback/received.html', items=items)


@feedback_bp.route('/given')
@_login_required
def given():
    emp_id = session.get('employee_id')
    items = svc.get_feedback_given(emp_id) if emp_id else []
    return render_template('feedback/given.html', items=items)


# ---------------------------------------------------------------------------
# 360 Review (HR / Manager only)
# ---------------------------------------------------------------------------

@feedback_bp.route('/360/<int:employee_id>')
@_login_required
def review_360(employee_id):
    role = session.get('role_code', '')
    if role not in ('HR_ADMIN', 'SUPER_ADMIN', 'MANAGER'):
        flash('Access denied.', 'error')
        return redirect(url_for('feedback.index'))

    summary = svc.get_360_summary(employee_id)

    with get_cursor() as cur:
        cur.execute("SELECT full_name FROM core.v_employees_full WHERE id = %s", (employee_id,))
        emp = cur.fetchone()

    responses = svc.get_feedback_received(employee_id)
    return render_template('feedback/received.html',
                           items=responses,
                           employee_name=emp['full_name'] if emp else 'Employee',
                           summary=summary,
                           is_360=True)
