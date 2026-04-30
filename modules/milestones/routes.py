"""
Milestones blueprint — Step Increment & Retirement monitoring.

Routes:
    GET  /step-increments/                — dashboard + list
    POST /step-increments/scan            — scan for new DUE rows
    POST /step-increments/<id>/notice     — mark notice sent
    POST /step-increments/<id>/approve    — approve
    POST /step-increments/<id>/record     — record as effective
    POST /step-increments/<id>/decline    — decline

    GET  /retirement/                     — dashboard + list
    POST /retirement/scan                 — scan for new UPCOMING rows
    POST /retirement/<id>/notice          — mark notice sent
    POST /retirement/<id>/acknowledge     — mark acknowledged
    POST /retirement/<id>/schedule        — set retirement date
    POST /retirement/<id>/retire          — mark as retired (& update employee)

    GET  /admin/retirement-rules          — admin config
    POST /admin/retirement-rules/save     — save rules
"""
from functools import wraps
from datetime import date as Date

from flask import (Blueprint, jsonify, redirect, render_template, request,
                   session, url_for, flash)

from services import step_increment_service as si
from services import retirement_service as ret
from services.db import get_cursor


milestones_bp = Blueprint('milestones', __name__,
                          template_folder='../../templates/milestones')


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
    with get_cursor() as cur:
        cur.execute(
            'SELECT id FROM core.companies ORDER BY id LIMIT 1')
        row = cur.fetchone()
    return row['id'] if row else 1


# ══════════════════════════════════════════════════════════════════════
# Step Increment
# ══════════════════════════════════════════════════════════════════════
@milestones_bp.route('/step-increments/')
@_login_required
def si_index():
    cid = _company_id()
    status = request.args.get('status')
    rows = si.list_items(cid, status_filter=status)
    stats = si.summary(cid)
    return render_template('milestones/step_increments.html',
                           rows=rows, stats=stats, status_filter=status,
                           today=Date.today())


@milestones_bp.route('/step-increments/scan', methods=['POST'])
@_login_required
@_admin_required
def si_scan():
    cid = _company_id()
    result = si.scan_due(cid, look_ahead_days=120)
    return jsonify({'ok': True, **result})


@milestones_bp.route('/step-increments/<int:sid>/notice', methods=['POST'])
@_login_required
@_admin_required
def si_notice(sid):
    row = si.send_notice(sid, session.get('user_id'),
                         notice_path=f'/tmp/si_notice_{sid}.pdf')
    return jsonify({'ok': True, 'row': dict(row) if row else None})


@milestones_bp.route('/step-increments/<int:sid>/approve', methods=['POST'])
@_login_required
@_admin_required
def si_approve(sid):
    row = si.approve(sid, session.get('user_id'))
    return jsonify({'ok': bool(row), 'row': dict(row) if row else None})


@milestones_bp.route('/step-increments/<int:sid>/record', methods=['POST'])
@_login_required
@_admin_required
def si_record(sid):
    data = request.get_json(silent=True) or request.form.to_dict()
    eff = data.get('effective_date') or Date.today().isoformat()
    row = si.record_effective(
        sid, effective_date=eff,
        to_step=data.get('to_step'),
        to_salary_grade=data.get('to_salary_grade'),
        user_id=session.get('user_id'),
        notes=data.get('notes', ''))
    return jsonify({'ok': bool(row), 'row': dict(row) if row else None})


@milestones_bp.route('/step-increments/<int:sid>/decline', methods=['POST'])
@_login_required
@_admin_required
def si_decline(sid):
    data = request.get_json(silent=True) or request.form.to_dict()
    row = si.decline(sid, session.get('user_id'),
                     reason=data.get('reason', 'Declined.'))
    return jsonify({'ok': bool(row)})


# ══════════════════════════════════════════════════════════════════════
# Retirement
# ══════════════════════════════════════════════════════════════════════
@milestones_bp.route('/retirement/')
@_login_required
def ret_index():
    cid = _company_id()
    status = request.args.get('status')
    etype = request.args.get('eligibility')
    rows = ret.list_items(cid, status_filter=status, eligibility_filter=etype)
    stats = ret.summary(cid)
    rules = ret.get_rules(cid)
    return render_template('milestones/retirement.html',
                           rows=rows, stats=stats, rules=rules,
                           status_filter=status, eligibility_filter=etype)


@milestones_bp.route('/retirement/scan', methods=['POST'])
@_login_required
@_admin_required
def ret_scan():
    cid = _company_id()
    result = ret.scan(cid)
    return jsonify({'ok': True, **result})


@milestones_bp.route('/retirement/<int:tid>/notice', methods=['POST'])
@_login_required
@_admin_required
def ret_notice(tid):
    # In real deployment, these paths would point to generated PDFs.
    hr = f'/tmp/retire_{tid}_hr.pdf'
    emp = f'/tmp/retire_{tid}_emp.pdf'
    fin = f'/tmp/retire_{tid}_finance.pdf'
    row = ret.send_notice(tid, session.get('user_id'),
                          hr_path=hr, emp_path=emp, finance_path=fin)
    return jsonify({
        'ok': bool(row),
        'notices': {'hr': hr, 'employee': emp, 'finance': fin}
    })


@milestones_bp.route('/retirement/<int:tid>/acknowledge', methods=['POST'])
@_login_required
@_admin_required
def ret_ack(tid):
    row = ret.acknowledge(tid, session.get('user_id'))
    return jsonify({'ok': bool(row)})


@milestones_bp.route('/retirement/<int:tid>/schedule', methods=['POST'])
@_login_required
@_admin_required
def ret_schedule(tid):
    data = request.get_json(silent=True) or request.form.to_dict()
    if not data.get('retirement_date'):
        return jsonify({'ok': False, 'message': 'retirement_date required.'}), 400
    row = ret.set_retirement_date(tid, data['retirement_date'],
                                  session.get('user_id'))
    return jsonify({'ok': bool(row)})


@milestones_bp.route('/retirement/<int:tid>/retire', methods=['POST'])
@_login_required
@_admin_required
def ret_retire(tid):
    row = ret.mark_retired(tid, session.get('user_id'))
    return jsonify({'ok': bool(row)})


# ══════════════════════════════════════════════════════════════════════
# Retirement Rules (Admin)
# ══════════════════════════════════════════════════════════════════════
@milestones_bp.route('/admin/retirement-rules')
@_login_required
@_admin_required
def ret_rules_page():
    cid = _company_id()
    rules = ret.get_rules(cid)
    profiles = ret.list_profiles(cid)
    return render_template('milestones/retirement_rules.html',
                           rules=rules, profiles=profiles)


@milestones_bp.route('/admin/retirement-rules/save', methods=['POST'])
@_login_required
@_admin_required
def ret_rules_save():
    """Legacy single-row save (backward compat with the original JS)."""
    data = request.get_json(silent=True) or request.form.to_dict()
    try:
        ret.save_rules(_company_id(), data, session.get('user_id'))
    except Exception as ex:
        return jsonify({'ok': False, 'message': str(ex)}), 500
    return jsonify({'ok': True, 'message': 'Retirement rules saved.'})


# ── Profiles CRUD ─────────────────────────────────────────────────────
@milestones_bp.route('/admin/retirement-rules/new', methods=['GET', 'POST'])
@_login_required
@_admin_required
def ret_profile_new():
    from services.db import get_cursor
    cid = _company_id()
    if request.method == 'POST':
        try:
            pid = ret.save_profile(cid, request.form.to_dict(), session.get('user_id'))
            flash(f'Rule profile created.', 'success')
            return redirect(url_for('milestones.ret_rules_page'))
        except Exception as ex:
            flash(f'Could not create profile: {ex}', 'error')
    with get_cursor() as cur:
        cur.execute("SELECT id, name FROM core.employment_types ORDER BY name")
        emp_types = cur.fetchall()
        cur.execute("SELECT id, name FROM core.departments WHERE is_active ORDER BY name")
        departments = cur.fetchall()
    return render_template('milestones/retirement_rule_form.html',
                           profile=None, emp_types=emp_types, departments=departments)


@milestones_bp.route('/admin/retirement-rules/<int:pid>/edit', methods=['GET', 'POST'])
@_login_required
@_admin_required
def ret_profile_edit(pid):
    from services.db import get_cursor
    cid = _company_id()
    profile = ret.get_profile(pid)
    if not profile or profile['company_id'] != cid:
        flash('Profile not found.', 'error')
        return redirect(url_for('milestones.ret_rules_page'))
    if request.method == 'POST':
        try:
            data = request.form.to_dict()
            data['id'] = pid
            ret.save_profile(cid, data, session.get('user_id'))
            flash('Rule profile updated.', 'success')
            return redirect(url_for('milestones.ret_rules_page'))
        except Exception as ex:
            flash(f'Could not save profile: {ex}', 'error')
    with get_cursor() as cur:
        cur.execute("SELECT id, name FROM core.employment_types ORDER BY name")
        emp_types = cur.fetchall()
        cur.execute("SELECT id, name FROM core.departments WHERE is_active ORDER BY name")
        departments = cur.fetchall()
    return render_template('milestones/retirement_rule_form.html',
                           profile=profile, emp_types=emp_types, departments=departments)


@milestones_bp.route('/admin/retirement-rules/<int:pid>/delete', methods=['POST'])
@_login_required
@_admin_required
def ret_profile_delete(pid):
    ret.delete_profile(pid, _company_id())
    flash('Profile deactivated. The default profile cannot be deleted.', 'success')
    return redirect(url_for('milestones.ret_rules_page'))
