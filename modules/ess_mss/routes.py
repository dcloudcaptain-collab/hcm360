"""ESS/MSS Blueprint — /me (employee) and /my-team (manager)."""
from flask import Blueprint, render_template, request, redirect, url_for, \
    flash, session
from modules.ess_mss import ess_service as svc
from services.privacy_service import apply_privacy, SECTION_MAP

ess_bp = Blueprint('ess', __name__,
                   template_folder='../../templates/ess_mss')


def _login_required(f):
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated


def _require_employee(f):
    """Ensure the logged-in user has an employee record."""
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('auth.login'))
        if not session.get('employee_id'):
            flash('No employee record linked to your account.', 'warning')
            return redirect(url_for('dashboard.index'))
        return f(*args, **kwargs)
    return decorated


# ---------------------------------------------------------------------------
# ESS — Employee Portal  (/me)
# ---------------------------------------------------------------------------

@ess_bp.route('/me')
@_require_employee
def me():
    emp_id = session['employee_id']
    uid = session.get('user_id')
    profile = svc.get_my_profile(emp_id)
    balances, leave_history = svc.get_my_leaves(emp_id)
    logs, ot_summary = svc.get_my_attendance(emp_id, months=1)
    comp = svc.get_my_compensation(emp_id)
    att_summary = svc.get_attendance_summary(emp_id)
    # Task inbox
    from services import task_inbox_service as tis
    tis.refresh_inbox(emp_id, uid)
    inbox_counts = tis.get_inbox_count(emp_id, uid)
    inbox_items = tis.get_inbox(emp_id, uid)[:5]
    # Benefits
    try:
        from modules.benefits import benefits_service as bsvc
        my_enrollments = bsvc.get_employee_enrollments(emp_id)
    except Exception:
        my_enrollments = []
    # Onboarding status
    try:
        from modules.onboarding import onboarding_service as obs
        onboarding = obs.get_employee_onboarding(emp_id)
    except Exception:
        onboarding = None
    return render_template('ess_mss/me.html',
                           profile=profile,
                           balances=balances,
                           leave_history=leave_history[:5],
                           logs=logs[:7],
                           ot_summary=ot_summary,
                           comp=comp,
                           att_summary=att_summary,
                           inbox_counts=inbox_counts,
                           inbox_items=inbox_items,
                           onboarding=onboarding,
                           my_enrollments=my_enrollments)


@ess_bp.route('/me/profile')
@_require_employee
def my_profile():
    profile = svc.get_my_profile(session['employee_id'])
    role_code = session.get('role_code', 'EMPLOYEE')
    # Self-service: employee views own record — MASKED fields visible, HIDDEN stay hidden
    profile['employee']   = apply_privacy(profile['employee'],             role_code, 'employee',         is_own_record=True)
    profile['gov_ids']    = apply_privacy(profile.get('gov_ids', []),      role_code, 'government_id',    is_own_record=True)
    profile['banks']      = apply_privacy(profile.get('banks', []),        role_code, 'bank_account',     is_own_record=True)
    profile['dependents'] = apply_privacy(profile.get('dependents', []),   role_code, 'dependent',        is_own_record=True)
    # Addresses and emergency contacts: always fully visible to self
    return render_template('ess_mss/my_profile.html', profile=profile)


# ═══════════════════════════════════════════════════════════════════
# Self-Service: Personal Information Sub-tables
# Employees can add/edit/delete their own addresses, contacts, etc.
# ═══════════════════════════════════════════════════════════════════
from services import employee_service as emp_svc

# Sub-table config for self-service (mirrors employees module config)
_ESS_SUB_TABLES = {
    'addresses': {
        'label': 'Address',
        'get_all': emp_svc.get_addresses,
        'get_one': emp_svc.get_address,
        'save':    emp_svc.save_address,
        'delete':  emp_svc.delete_address,
        'fields': [
            {'name': 'address_type', 'label': 'Type', 'required': True,
             'type': 'select', 'options': ['PERMANENT','RESIDENTIAL','MAILING']},
            {'name': 'line1', 'label': 'Address Line 1', 'required': True},
            {'name': 'line2', 'label': 'Address Line 2'},
            {'name': 'barangay', 'label': 'Barangay'},
            {'name': 'city', 'label': 'City/Municipality'},
            {'name': 'province', 'label': 'Province'},
            {'name': 'region', 'label': 'Region'},
            {'name': 'zip_code', 'label': 'ZIP Code'},
            {'name': 'country', 'label': 'Country'},
            {'name': 'is_primary', 'label': 'Primary Address', 'type': 'checkbox'},
        ],
        'list_cols': ['address_type', 'line1', 'city', 'province', 'is_primary'],
    },
    'emergency-contacts': {
        'label': 'Emergency Contact',
        'get_all': emp_svc.get_emergency_contacts,
        'get_one': emp_svc.get_emergency_contact,
        'save':    emp_svc.save_emergency_contact,
        'delete':  emp_svc.delete_emergency_contact,
        'fields': [
            {'name': 'full_name', 'label': 'Full Name', 'required': True},
            {'name': 'relationship', 'label': 'Relationship', 'required': True,
             'type': 'select', 'options': ['SPOUSE','PARENT','SIBLING','CHILD','RELATIVE','FRIEND','OTHER']},
            {'name': 'mobile_no', 'label': 'Mobile No.'},
            {'name': 'phone_no', 'label': 'Phone No.'},
            {'name': 'address', 'label': 'Address', 'type': 'textarea'},
            {'name': 'is_primary', 'label': 'Primary Contact', 'type': 'checkbox'},
        ],
        'list_cols': ['full_name', 'relationship', 'mobile_no', 'is_primary'],
    },
    'government-ids': {
        'label': 'Government ID',
        'get_all': emp_svc.get_government_ids,
        'get_one': emp_svc.get_government_id,
        'save':    emp_svc.save_government_id,
        'delete':  emp_svc.delete_government_id,
        'fields': [
            {'name': 'id_type', 'label': 'ID Type', 'required': True,
             'type': 'select', 'options': ['GSIS','SSS','PAGIBIG','PHILHEALTH','TIN','PRC','PASSPORT','DRIVERS_LICENSE','VOTERS_ID','POSTAL_ID']},
            {'name': 'id_number', 'label': 'ID Number', 'required': True},
            {'name': 'issue_date', 'label': 'Issue Date', 'type': 'date'},
            {'name': 'expiry_date', 'label': 'Expiry Date', 'type': 'date'},
        ],
        'list_cols': ['id_type', 'id_number', 'expiry_date', 'is_verified'],
    },
    'bank-accounts': {
        'label': 'Bank Account',
        'get_all': emp_svc.get_bank_accounts,
        'get_one': emp_svc.get_bank_account,
        'save':    emp_svc.save_bank_account,
        'delete':  emp_svc.delete_bank_account,
        'fields': [
            {'name': 'bank_name', 'label': 'Bank Name', 'required': True},
            {'name': 'bank_code', 'label': 'Bank Code'},
            {'name': 'account_name', 'label': 'Account Name', 'required': True},
            {'name': 'account_number', 'label': 'Account Number', 'required': True},
            {'name': 'account_type', 'label': 'Account Type',
             'type': 'select', 'options': ['SAVINGS','CHECKING','PAYROLL']},
            {'name': 'is_primary', 'label': 'Primary Account', 'type': 'checkbox'},
        ],
        'list_cols': ['bank_name', 'account_name', 'account_number', 'account_type', 'is_primary'],
    },
    'dependents': {
        'label': 'Dependent',
        'get_all': emp_svc.get_dependents,
        'get_one': emp_svc.get_dependent,
        'save':    emp_svc.save_dependent,
        'delete':  emp_svc.delete_dependent,
        'fields': [
            {'name': 'full_name', 'label': 'Full Name', 'required': True},
            {'name': 'relationship', 'label': 'Relationship', 'required': True,
             'type': 'select', 'options': ['SPOUSE','CHILD','PARENT','SIBLING','OTHER']},
            {'name': 'date_of_birth', 'label': 'Date of Birth', 'type': 'date'},
            {'name': 'is_beneficiary', 'label': 'Beneficiary', 'type': 'checkbox'},
        ],
        'list_cols': ['full_name', 'relationship', 'date_of_birth', 'is_beneficiary'],
    },
}

_ESS_ALLOWED = set(_ESS_SUB_TABLES.keys())


@ess_bp.route('/me/profile/<sub_key>')
@_require_employee
def my_sub_list(sub_key):
    if sub_key not in _ESS_ALLOWED:
        abort(404)
    cfg = _ESS_SUB_TABLES[sub_key]
    emp_id = session['employee_id']
    items = cfg['get_all'](emp_id)
    emp = emp_svc.get_employee(emp_id)
    # Apply privacy masking for self-service view
    role_code = session.get('role_code', 'EMPLOYEE')
    section = SECTION_MAP.get(sub_key)
    if section:
        items = apply_privacy(items, role_code, section, is_own_record=True)
    return render_template('ess_mss/my_sub_list.html',
                           emp=emp, items=items, cfg=cfg, sub_key=sub_key)


@ess_bp.route('/me/profile/<sub_key>/new', methods=['GET', 'POST'])
@_require_employee
def my_sub_new(sub_key):
    if sub_key not in _ESS_ALLOWED:
        abort(404)
    cfg = _ESS_SUB_TABLES[sub_key]
    emp_id = session['employee_id']
    if request.method == 'POST':
        try:
            cfg['save'](request.form, emp_id)
            flash(f'{cfg["label"]} added.', 'success')
            return redirect(url_for('ess.my_sub_list', sub_key=sub_key))
        except Exception as e:
            flash(f'Error: {e}', 'error')
    emp = emp_svc.get_employee(emp_id)
    return render_template('ess_mss/my_sub_form.html',
                           emp=emp, item=None, cfg=cfg, sub_key=sub_key)


@ess_bp.route('/me/profile/<sub_key>/<int:item_id>/edit', methods=['GET', 'POST'])
@_require_employee
def my_sub_edit(sub_key, item_id):
    if sub_key not in _ESS_ALLOWED:
        abort(404)
    cfg = _ESS_SUB_TABLES[sub_key]
    emp_id = session['employee_id']
    item = cfg['get_one'](item_id)
    # Verify the item belongs to this employee
    if not item or item.get('employee_id') != emp_id:
        abort(403)
    if request.method == 'POST':
        try:
            cfg['save'](request.form, emp_id, item_id)
            flash(f'{cfg["label"]} updated.', 'success')
            return redirect(url_for('ess.my_sub_list', sub_key=sub_key))
        except Exception as e:
            flash(f'Error: {e}', 'error')
    emp = emp_svc.get_employee(emp_id)
    return render_template('ess_mss/my_sub_form.html',
                           emp=emp, item=item, cfg=cfg, sub_key=sub_key)


@ess_bp.route('/me/profile/<sub_key>/<int:item_id>/delete', methods=['POST'])
@_require_employee
def my_sub_delete(sub_key, item_id):
    if sub_key not in _ESS_ALLOWED:
        abort(404)
    cfg = _ESS_SUB_TABLES[sub_key]
    emp_id = session['employee_id']
    item = cfg['get_one'](item_id)
    if not item or item.get('employee_id') != emp_id:
        abort(403)
    try:
        cfg['delete'](item_id)
        flash(f'{cfg["label"]} deleted.', 'success')
    except Exception as e:
        flash(f'Error: {e}', 'error')
    return redirect(url_for('ess.my_sub_list', sub_key=sub_key))


@ess_bp.route('/me/attendance')
@_require_employee
def my_attendance():
    months = request.args.get('months', 1, type=int)
    logs, ot_summary = svc.get_my_attendance(session['employee_id'], months=months)
    return render_template('ess_mss/my_attendance.html',
                           logs=logs, ot_summary=ot_summary, months=months)


@ess_bp.route('/me/leaves')
@_require_employee
def my_leaves():
    balances, history = svc.get_my_leaves(session['employee_id'])
    return render_template('ess_mss/my_leaves.html',
                           balances=balances, history=history)


@ess_bp.route('/me/payslips')
@_require_employee
def my_payslips():
    page = request.args.get('page', 1, type=int)
    rows, total = svc.get_my_payslips(session['employee_id'], page=page)
    return render_template('ess_mss/my_payslips.html',
                           rows=rows, total=total, page=page)


# ---------------------------------------------------------------------------
# MSS — Manager Portal  (/my-team)
# ---------------------------------------------------------------------------

@ess_bp.route('/my-team')
@_require_employee
def my_team():
    emp_id   = session['employee_id']
    team     = svc.get_team(emp_id)
    today    = svc.get_team_attendance_today(emp_id)
    on_leave = svc.get_team_leave_today(emp_id)
    pending  = svc.get_pending_approvals(session['user_id'])
    return render_template('ess_mss/my_team.html',
                           team=team, today=today,
                           on_leave=on_leave,
                           pending=pending)


@ess_bp.route('/my-team/attendance')
@_require_employee
def team_attendance():
    emp_id = session['employee_id']
    today  = svc.get_team_attendance_today(emp_id)
    return render_template('ess_mss/team_attendance.html', today=today)


@ess_bp.route('/my-team/approvals')
@_require_employee
def team_approvals():
    pending = svc.get_pending_approvals(session['user_id'])
    return render_template('ess_mss/team_approvals.html', pending=pending)


# ---------------------------------------------------------------------------
# Certificate Requests (ESS)
# ---------------------------------------------------------------------------

@ess_bp.route('/me/certificates')
@_require_employee
def my_certificates():
    from modules.dms import dms_service
    emp_id = session['employee_id']
    cert_types = dms_service.get_certificate_types()
    my_requests = dms_service.get_certificate_requests(employee_id=emp_id)
    return render_template('ess_mss/my_certificates.html',
                           cert_types=cert_types, requests=my_requests)


@ess_bp.route('/me/certificates/request', methods=['POST'])
@_require_employee
def request_certificate():
    from modules.dms import dms_service
    emp_id = session['employee_id']
    cert_type_id = request.form.get('cert_type_id', type=int)
    purpose = request.form.get('purpose', '')
    copies = request.form.get('copies', 1, type=int)
    dms_service.create_certificate_request(emp_id, cert_type_id, purpose, copies)
    flash('Certificate request submitted. HR will process your request.', 'success')
    return redirect(url_for('ess.my_certificates'))


# ---------------------------------------------------------------------------
# ESS — Compensation
# ---------------------------------------------------------------------------

@ess_bp.route('/me/compensation')
@_require_employee
def my_compensation():
    comp = svc.get_my_compensation(session['employee_id'])
    return render_template('ess_mss/my_compensation.html', comp=comp)


# ---------------------------------------------------------------------------
# ESS — Task Inbox
# ---------------------------------------------------------------------------

@ess_bp.route('/me/inbox')
@_require_employee
def my_inbox():
    from services import task_inbox_service as tis
    from services import task_service as ts
    emp_id = session['employee_id']
    uid = session.get('user_id')
    role = session.get('role_code')
    tis.refresh_inbox(emp_id, uid)
    # Pull query-string filters + route through the filterable lister when
    # any filter/search/sort is active; otherwise keep the legacy simple view.
    filters = {k: request.args.get(k) for k in
               ('status', 'priority', 'category', 'due', 'q', 'sort')
               if request.args.get(k)}
    if filters:
        items = ts.list_tasks(uid, role, mode='inbox', filters=filters)
    else:
        items = tis.get_inbox(emp_id, uid)
    counts = tis.get_inbox_count(emp_id, uid)
    return render_template('ess_mss/my_inbox.html',
                           items=items, counts=counts, filters=filters)


@ess_bp.route('/me/inbox/<int:task_id>/complete', methods=['POST'])
@_require_employee
def inbox_complete(task_id):
    from services import task_inbox_service as tis
    tis.complete_task(task_id)
    return redirect(url_for('ess.my_inbox'))


@ess_bp.route('/me/inbox/<int:task_id>/dismiss', methods=['POST'])
@_require_employee
def inbox_dismiss(task_id):
    from services import task_inbox_service as tis
    tis.dismiss_task(task_id)
    return redirect(url_for('ess.my_inbox'))


@ess_bp.route('/me/inbox/mark-all-read', methods=['POST'])
@_require_employee
def inbox_mark_all_read():
    from services import task_inbox_service as tis
    tis.mark_all_read(session['employee_id'], session.get('user_id'))
    return redirect(url_for('ess.my_inbox'))


# ---------------------------------------------------------------------------
# ESS — Onboarding Self-Service View
# ---------------------------------------------------------------------------

@ess_bp.route('/me/benefits')
@_require_employee
def my_benefits():
    from modules.benefits import benefits_service as bsvc
    emp_id = session['employee_id']
    enrollments = bsvc.get_employee_enrollments(emp_id)
    life_events = bsvc.get_life_events(employee_id=emp_id)
    return render_template('ess_mss/my_benefits.html',
                           enrollments=enrollments, life_events=life_events)


@ess_bp.route('/me/benefits/enroll', methods=['GET', 'POST'])
@_require_employee
def my_benefits_enroll():
    from modules.benefits import benefits_service as bsvc
    emp_id = session['employee_id']
    window = bsvc.get_active_window()
    if not window:
        flash('No open enrollment window at this time.', 'info')
        return redirect(url_for('ess.my_benefits'))
    if request.method == 'POST':
        plan_id = request.form.get('plan_id', type=int)
        coverage = request.form.get('coverage_level', 'INDIVIDUAL')
        bsvc.enroll(emp_id, plan_id, coverage, window_id=window['id'])
        flash('You have been enrolled successfully.', 'success')
        return redirect(url_for('ess.my_benefits'), code=303)
    plans = bsvc.get_plans()
    enrollments = bsvc.get_employee_enrollments(emp_id)
    enrolled_plan_ids = [e['plan_id'] for e in enrollments] if enrollments else []
    return render_template('ess_mss/my_benefits_enroll.html',
                           window=window, plans=plans, enrolled_plan_ids=enrolled_plan_ids)


@ess_bp.route('/me/certifications')
@_require_employee
def my_certifications_list():
    from modules.certifications import cert_service as csvc
    certs = csvc.get_employee_certs(session['employee_id'])
    return render_template('ess_mss/my_certifications_list.html', certs=certs)


@ess_bp.route('/me/theme', methods=['GET', 'POST'])
def my_theme():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    from services.theme_service import list_themes, set_user_theme
    from services.db import get_cursor
    if request.method == 'POST':
        theme_id = request.form.get('theme_id', type=int)
        if theme_id == 0:
            set_user_theme(session['user_id'], None)
            flash('Theme reset to system default.', 'success')
        else:
            set_user_theme(session['user_id'], theme_id)
            flash('Theme preference saved.', 'success')
        return redirect(url_for('ess.my_theme'), code=303)

    # Query the user's OWN explicit preference (not the resolved fallback).
    # This is what the template needs to correctly highlight the chosen card,
    # because get_user_theme() falls back to the global active theme and the
    # template can't tell the two cases apart.
    with get_cursor() as cur:
        cur.execute('SELECT theme_id FROM core.users WHERE id = %s', (session['user_id'],))
        row = cur.fetchone()
    user_theme_id = row['theme_id'] if row else None

    return render_template('ess_mss/my_theme.html',
                           themes=list_themes(),
                           user_theme_id=user_theme_id)


@ess_bp.route('/me/onboarding')
@_require_employee
def my_onboarding():
    from modules.onboarding import onboarding_service as obs
    data = obs.get_employee_onboarding(session['employee_id'])
    if not data:
        flash('No active onboarding found.', 'info')
        return redirect(url_for('ess.me'))
    return render_template('ess_mss/my_onboarding.html', **data)
