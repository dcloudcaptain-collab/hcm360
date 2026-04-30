"""
LGU Forms blueprint — consolidates G01/G02/G03/G04/G07/G14.

Route prefixes:
    /leave/cs-form-6*         CS Form No. 6 (G01)
    /offboarding/*            Exit Interview + Clearance (G02)
    /travel-orders/*          Travel Orders (G03)
    /locator-slips/*          Locator Slips (G04)
    /lgu-contracts/*          JO / LSB / BHW / NS (G07)
    /pds/*  and  /me/pds      Personal Data Sheet (G14)
"""
from functools import wraps
from datetime import date as Date

from flask import (Blueprint, flash, jsonify, redirect, render_template,
                   request, session, url_for)

from services import lgu_forms_service as svc
from services.db import get_cursor


lgu_forms_bp = Blueprint('lgu_forms', __name__,
                         template_folder='../../templates/lgu_forms')


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
        cur.execute('SELECT id FROM core.companies ORDER BY id LIMIT 1')
        row = cur.fetchone()
    return row['id'] if row else 1


def _leave_types():
    with get_cursor() as cur:
        cur.execute("""
            SELECT id, code, name, legal_basis, color, icon, is_paid,
                   gender_restriction, requires_document
            FROM leave_mgmt.lv_types
            WHERE is_active = TRUE
            ORDER BY name
        """)
        return cur.fetchall()


# ══════════════════════════════════════════════════════════════════════
# G01 · CS Form No. 6
# ══════════════════════════════════════════════════════════════════════
@lgu_forms_bp.route('/leave/cs-form-6')
@_login_required
def cs6_index():
    emp_id = session.get('employee_id')
    cid = _company_id()
    if session.get('role_code') in ('SUPER_ADMIN', 'HR_ADMIN'):
        rows = svc.cs6_list(company_id=cid)
    else:
        rows = svc.cs6_list(employee_id=emp_id)
    return render_template('lgu_forms/cs6_index.html',
                           rows=rows, is_admin=session.get('role_code') in
                                                 ('SUPER_ADMIN','HR_ADMIN'))


@lgu_forms_bp.route('/leave/cs-form-6/new', methods=['GET', 'POST'])
@_login_required
def cs6_new():
    emp_id = session.get('employee_id')
    if not emp_id:
        flash('No employee record linked to your account.', 'error')
        return redirect(url_for('dashboard.index'))
    if request.method == 'POST':
        form = request.form.to_dict()
        form['leave_type_id'] = int(form['leave_type_id'])
        rid = svc.cs6_create(emp_id, form, session.get('user_id'))
        flash('CS Form No. 6 submitted.', 'success')
        return redirect(url_for('lgu_forms.cs6_view', rid=rid))
    return render_template('lgu_forms/cs6_new.html',
                           leave_types=_leave_types(),
                           today=Date.today())


@lgu_forms_bp.route('/leave/cs-form-6/<int:rid>')
@_login_required
def cs6_view(rid):
    r = svc.cs6_get(rid)
    if not r:
        flash('Form not found.', 'error')
        return redirect(url_for('lgu_forms.cs6_index'))
    return render_template('lgu_forms/cs6_view.html', r=r)


@lgu_forms_bp.route('/leave/cs-form-6/<int:rid>/action', methods=['POST'])
@_login_required
@_admin_required
def cs6_action(rid):
    data = request.get_json(silent=True) or request.form.to_dict()
    role = data.get('role', 'head')  # 'recommend' or 'head'
    action = data.get('action')
    remarks = data.get('remarks', '')
    if role == 'recommend':
        svc.cs6_recommend(rid, session.get('user_id'), action, remarks)
    else:
        svc.cs6_head_action(rid, session.get('user_id'), action, remarks)
    return jsonify({'ok': True})


# ══════════════════════════════════════════════════════════════════════
# G02 · Exit Interview + CS Form No. 7
# ══════════════════════════════════════════════════════════════════════
@lgu_forms_bp.route('/offboarding/exit-interview', methods=['GET', 'POST'])
@_login_required
def exit_index():
    emp_id = session.get('employee_id')
    if request.method == 'POST' and emp_id:
        form = request.form.to_dict()
        for k in ('overall_rating', 'manager_rating',
                  'compensation_rating', 'culture_rating'):
            form[k] = int(form[k]) if form.get(k) else None
        form['would_recommend'] = form.get('would_recommend') == 'true'
        form['would_rejoin']    = form.get('would_rejoin') == 'true'
        eid = svc.exit_create(emp_id, form)
        if form.get('submit') == 'true':
            svc.exit_submit(eid)
        flash('Exit interview saved.', 'success')
        return redirect(url_for('lgu_forms.exit_view', eid=eid))
    cid = _company_id()
    rows = svc.exit_list(cid) if session.get('role_code') in \
        ('SUPER_ADMIN', 'HR_ADMIN') else []
    return render_template('lgu_forms/exit_index.html',
                           rows=rows, reasons=svc.EXIT_REASONS,
                           is_admin=session.get('role_code') in
                                     ('SUPER_ADMIN','HR_ADMIN'))


@lgu_forms_bp.route('/offboarding/exit-interview/<int:eid>')
@_login_required
def exit_view(eid):
    r = svc.exit_get(eid)
    if not r:
        flash('Interview not found.', 'error')
        return redirect(url_for('lgu_forms.exit_index'))
    return render_template('lgu_forms/exit_view.html', r=r)


# ── CS Form No. 7 Clearance ──
@lgu_forms_bp.route('/offboarding/clearance')
@_login_required
def clearance_index():
    cid = _company_id()
    rows = svc.clearance_list(cid)
    return render_template('lgu_forms/clearance_index.html', rows=rows,
                           is_admin=session.get('role_code') in
                                     ('SUPER_ADMIN','HR_ADMIN'))


@lgu_forms_bp.route('/offboarding/clearance/new', methods=['POST'])
@_login_required
@_admin_required
def clearance_new():
    data = request.form.to_dict() or request.get_json() or {}
    emp_id = int(data.get('employee_id'))
    lwd = data.get('last_working_day')
    cid = svc.clearance_create(emp_id, lwd)
    return redirect(url_for('lgu_forms.clearance_view', cid=cid))


@lgu_forms_bp.route('/offboarding/clearance/<int:cid>')
@_login_required
def clearance_view(cid):
    data = svc.clearance_get(cid)
    if not data:
        flash('Clearance not found.', 'error')
        return redirect(url_for('lgu_forms.clearance_index'))
    return render_template('lgu_forms/clearance_view.html',
                           clearance=data['form'], items=data['items'])


@lgu_forms_bp.route('/offboarding/clearance/item/<int:item_id>/sign',
                    methods=['POST'])
@_login_required
def clearance_sign(item_id):
    data = request.get_json(silent=True) or request.form.to_dict()
    svc.clearance_sign(item_id, session.get('user_id'),
                       cleared=str(data.get('cleared', 'true')).lower() == 'true',
                       remarks=data.get('remarks', ''))
    return jsonify({'ok': True})


# ══════════════════════════════════════════════════════════════════════
# G03 · Travel Orders
# ══════════════════════════════════════════════════════════════════════
@lgu_forms_bp.route('/travel-orders/')
@_login_required
def travel_index():
    cid = _company_id()
    emp = session.get('employee_id')
    is_admin = session.get('role_code') in ('SUPER_ADMIN','HR_ADMIN','MANAGER')
    rows = svc.travel_list(cid, employee_id=None if is_admin else emp,
                           status=request.args.get('status'))
    return render_template('lgu_forms/travel_index.html',
                           rows=rows, is_admin=is_admin,
                           status_filter=request.args.get('status'))


@lgu_forms_bp.route('/travel-orders/new', methods=['GET', 'POST'])
@_login_required
def travel_new():
    emp_id = session.get('employee_id')
    if not emp_id:
        flash('No employee record linked.', 'error')
        return redirect(url_for('dashboard.index'))
    if request.method == 'POST':
        form = request.form.to_dict()
        row = svc.travel_create(emp_id, form, session.get('user_id'))
        flash(f'Travel Order {row["control_no"]} submitted.', 'success')
        return redirect(url_for('lgu_forms.travel_view', tid=row['id']))
    return render_template('lgu_forms/travel_new.html', today=Date.today())


@lgu_forms_bp.route('/travel-orders/<int:tid>')
@_login_required
def travel_view(tid):
    r = svc.travel_get(tid)
    if not r:
        flash('Travel order not found.', 'error')
        return redirect(url_for('lgu_forms.travel_index'))
    return render_template('lgu_forms/travel_view.html', r=r)


@lgu_forms_bp.route('/travel-orders/<int:tid>/action', methods=['POST'])
@_login_required
def travel_action(tid):
    data = request.get_json(silent=True) or request.form.to_dict()
    if session.get('role_code') not in ('SUPER_ADMIN','HR_ADMIN','MANAGER'):
        return jsonify({'ok': False, 'message': 'Forbidden'}), 403
    svc.travel_action(tid, session.get('user_id'),
                      action=data.get('action'),
                      level=data.get('level', 'supervisor'),
                      remarks=data.get('remarks', ''))
    return jsonify({'ok': True})


# ══════════════════════════════════════════════════════════════════════
# G04 · Locator Slips
# ══════════════════════════════════════════════════════════════════════
@lgu_forms_bp.route('/locator-slips/')
@_login_required
def locator_index():
    cid = _company_id()
    emp = session.get('employee_id')
    is_admin = session.get('role_code') in ('SUPER_ADMIN','HR_ADMIN','MANAGER')
    rows = svc.locator_list(cid, employee_id=None if is_admin else emp,
                            status=request.args.get('status'))
    return render_template('lgu_forms/locator_index.html',
                           rows=rows, is_admin=is_admin,
                           status_filter=request.args.get('status'))


@lgu_forms_bp.route('/locator-slips/new', methods=['GET', 'POST'])
@_login_required
def locator_new():
    emp_id = session.get('employee_id')
    if not emp_id:
        flash('No employee record linked.', 'error')
        return redirect(url_for('dashboard.index'))
    if request.method == 'POST':
        form = request.form.to_dict()
        svc.locator_create(emp_id, form)
        flash('Locator slip submitted.', 'success')
        return redirect(url_for('lgu_forms.locator_index'))
    return render_template('lgu_forms/locator_new.html', today=Date.today())


@lgu_forms_bp.route('/locator-slips/<int:sid>/action', methods=['POST'])
@_login_required
def locator_action(sid):
    data = request.get_json(silent=True) or request.form.to_dict()
    if session.get('role_code') not in ('SUPER_ADMIN','HR_ADMIN','MANAGER'):
        return jsonify({'ok': False, 'message': 'Forbidden'}), 403
    svc.locator_action(sid, session.get('user_id'),
                       action=data.get('action'),
                       remarks=data.get('remarks', ''))
    return jsonify({'ok': True})


# ══════════════════════════════════════════════════════════════════════
# G07 · LGU Contracts
# ══════════════════════════════════════════════════════════════════════
@lgu_forms_bp.route('/lgu-contracts/')
@_login_required
@_admin_required
def contract_index():
    status = request.args.get('status')
    type_code = request.args.get('type')
    rows = svc.contract_list(status=status, contract_type_code=type_code)
    summary = svc.contract_summary()
    types = svc.contract_types()
    return render_template('lgu_forms/contract_index.html',
                           rows=rows, summary=summary, types=types,
                           status_filter=status, type_filter=type_code)


@lgu_forms_bp.route('/lgu-contracts/new', methods=['GET', 'POST'])
@_login_required
@_admin_required
def contract_new():
    types = svc.contract_types()
    if request.method == 'POST':
        form = request.form.to_dict()
        form['contract_type_id'] = int(form['contract_type_id'])
        if form.get('employee_id'):
            form['employee_id'] = int(form['employee_id'])
        if form.get('department_id'):
            form['department_id'] = int(form['department_id'])
        row = svc.contract_create(form, session.get('user_id'))
        flash(f'Contract {row["contract_no"]} created.', 'success')
        return redirect(url_for('lgu_forms.contract_view', cid=row['id']))
    with get_cursor() as cur:
        cur.execute("SELECT id, name FROM core.departments ORDER BY name")
        depts = cur.fetchall()
    return render_template('lgu_forms/contract_new.html',
                           types=types, depts=depts, today=Date.today())


@lgu_forms_bp.route('/lgu-contracts/<int:cid>')
@_login_required
@_admin_required
def contract_view(cid):
    r = svc.contract_get(cid)
    if not r:
        flash('Contract not found.', 'error')
        return redirect(url_for('lgu_forms.contract_index'))
    return render_template('lgu_forms/contract_view.html', r=r)


@lgu_forms_bp.route('/lgu-contracts/<int:cid>/action', methods=['POST'])
@_login_required
@_admin_required
def contract_action(cid):
    data = request.get_json(silent=True) or request.form.to_dict()
    svc.contract_action(cid, session.get('user_id'), data.get('action'))
    return jsonify({'ok': True})


# ══════════════════════════════════════════════════════════════════════
# G14 · Personal Data Sheet (CSC Form 212)
# ══════════════════════════════════════════════════════════════════════
@lgu_forms_bp.route('/pds/')
@_login_required
@_admin_required
def pds_index():
    cid = _company_id()
    rows = svc.pds_list(cid, status=request.args.get('status'))
    return render_template('lgu_forms/pds_index.html',
                           rows=rows, status_filter=request.args.get('status'))


@lgu_forms_bp.route('/me/pds', methods=['GET', 'POST'])
@_login_required
def pds_me():
    emp_id = session.get('employee_id')
    if not emp_id:
        flash('No employee record linked.', 'error')
        return redirect(url_for('dashboard.index'))
    if request.method == 'POST':
        import json as _json
        payload = request.get_json(silent=True) or {}
        data = payload.get('data') or {}
        submit = bool(payload.get('submit', False))
        row = svc.pds_save(emp_id, data, session.get('user_id'), submit=submit)
        return jsonify({'ok': True, 'id': row['id'], 'version': row['version']})
    # GET
    current = svc.pds_get_current(emp_id)
    prefill = svc.pds_prefill_from_master(emp_id)
    if current:
        # psycopg2 may return JSONB as dict already, or as str
        d = current['data']
        if isinstance(d, str):
            import json as _json
            d = _json.loads(d)
        # Merge prefill defaults so every PDS section has a key to bind to
        # (older drafts may only contain personal_info; without this merge the
        # Family / Education / Work tabs render with no hooks and the page
        # appears broken to the user).
        if not isinstance(d, dict):
            d = {}
        data_obj = {**prefill, **d}
        # Deep-merge personal_info so existing values win over master defaults
        if 'personal_info' in prefill:
            pi = {**prefill.get('personal_info', {}), **d.get('personal_info', {})}
            data_obj['personal_info'] = pi
    else:
        data_obj = prefill
    return render_template('lgu_forms/pds_me.html',
                           data=data_obj, current=current,
                           sections=svc.PDS_SECTIONS)


@lgu_forms_bp.route('/pds/<int:pid>/verify', methods=['POST'])
@_login_required
@_admin_required
def pds_verify(pid):
    svc.pds_verify(pid, session.get('user_id'))
    return jsonify({'ok': True})
