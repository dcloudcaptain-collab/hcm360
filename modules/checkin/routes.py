"""
Check-in blueprint — face recognition + geotag attendance.

Routes:
    GET  /checkin/                      — the employee check-in page
    GET  /checkin/enroll                — enrol your face (first time)
    POST /checkin/api/enroll            — save face descriptor (AJAX)
    POST /checkin/api/submit            — submit a check-in (AJAX)
    GET  /checkin/history               — personal check-in history
    GET  /admin/checkin-settings        — admin configuration page
    POST /admin/checkin-settings/save   — save settings (AJAX)
"""
from functools import wraps

from flask import (Blueprint, jsonify, redirect, render_template, request,
                   session, url_for, flash)

from services import checkin_service as svc
from services.db import get_cursor


checkin_bp = Blueprint('checkin', __name__,
                       template_folder='../../templates/checkin')


def _login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated


def _admin_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if session.get('role_code') not in ('SUPER_ADMIN', 'HR_ADMIN'):
            flash('Admin access required.', 'error')
            return redirect(url_for('dashboard.index'))
        return f(*args, **kwargs)
    return decorated


def _company_id():
    uid = session.get('user_id')
    if not uid:
        return None
    with get_cursor() as cur:
        cur.execute(
            'SELECT company_id FROM core.users WHERE id = %s', (uid,))
        row = cur.fetchone()
    return row['company_id'] if row else None


# ══════════════════════════════════════════════════════════════════════
# Employee-facing pages
# ══════════════════════════════════════════════════════════════════════
@checkin_bp.route('/checkin/')
@_login_required
def index():
    emp_id = session.get('employee_id')
    if not emp_id:
        flash('Your user account is not linked to an employee record. '
              'Contact HR to enable check-in.', 'error')
        return redirect(url_for('dashboard.index'))

    enrolled = svc.is_face_enrolled(emp_id)
    settings = svc.get_settings(_company_id())
    return render_template('checkin/index.html',
                           enrolled=enrolled,
                           settings=settings)


@checkin_bp.route('/checkin/enroll')
@_login_required
def enroll_page():
    emp_id = session.get('employee_id')
    if not emp_id:
        flash('No employee record linked to your account.', 'error')
        return redirect(url_for('dashboard.index'))

    existing = svc.get_face_enrollment(emp_id)
    settings = svc.get_settings(_company_id())
    return render_template('checkin/enroll.html',
                           existing=existing,
                           settings=settings)


@checkin_bp.route('/checkin/api/enroll', methods=['POST'])
@_login_required
def api_enroll():
    data = request.get_json(silent=True) or {}
    descriptor = data.get('descriptor')
    target_emp_id = data.get('employee_id') or session.get('employee_id')
    if not target_emp_id:
        return jsonify({'ok': False, 'message': 'No employee context.'}), 400

    # Only HR/Admin can enrol on behalf of others
    if (target_emp_id != session.get('employee_id')
            and session.get('role_code') not in ('SUPER_ADMIN', 'HR_ADMIN')):
        return jsonify({'ok': False,
                        'message': 'Permission denied to enrol for others.'}), 403

    if not isinstance(descriptor, list) or len(descriptor) != 128:
        return jsonify({'ok': False,
                        'message': 'Face descriptor must be 128 floats.'}), 400

    try:
        enrol_id = svc.save_face_enrollment(
            target_emp_id, descriptor,
            enrolled_by=session.get('user_id'),
            note=data.get('note', ''))
    except Exception as ex:
        return jsonify({'ok': False, 'message': str(ex)}), 500

    return jsonify({'ok': True, 'id': enrol_id,
                    'message': 'Face enrolled successfully.'})


@checkin_bp.route('/checkin/api/submit', methods=['POST'])
@_login_required
def api_submit():
    emp_id = session.get('employee_id')
    if not emp_id:
        return jsonify({'ok': False, 'message': 'No employee record.'}), 400

    data = request.get_json(silent=True) or {}
    result = svc.submit_checkin(
        emp_id, data, ip_address=request.headers.get(
            'X-Forwarded-For', request.remote_addr))
    status = 200 if result.get('ok') else 400
    return jsonify(result), status


@checkin_bp.route('/checkin/history')
@_login_required
def history():
    emp_id = session.get('employee_id')
    if not emp_id:
        flash('No employee record linked.', 'error')
        return redirect(url_for('dashboard.index'))
    rows = svc.get_history(emp_id, limit=100)
    return render_template('checkin/history.html', rows=rows)


# ══════════════════════════════════════════════════════════════════════
# Admin settings
# ══════════════════════════════════════════════════════════════════════
@checkin_bp.route('/admin/checkin-settings')
@_login_required
@_admin_required
def settings_page():
    settings = svc.get_settings(_company_id())
    summary = svc.get_enrollments_summary(_company_id())
    return render_template('checkin/settings.html',
                           settings=settings, summary=summary)


@checkin_bp.route('/admin/checkin-settings/save', methods=['POST'])
@_login_required
@_admin_required
def settings_save():
    data = request.get_json(silent=True) or request.form.to_dict()
    # Cast checkbox strings
    for k in ('require_face', 'require_geotag', 'capture_photo'):
        v = data.get(k)
        data[k] = v in (True, 'true', 'on', '1', 1)
    try:
        svc.save_settings(_company_id(), data,
                          updated_by=session.get('user_id'))
    except Exception as ex:
        return jsonify({'ok': False, 'message': str(ex)}), 500
    return jsonify({'ok': True, 'message': 'Settings saved.'})
