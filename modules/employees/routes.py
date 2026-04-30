import json
import os
from datetime import date, datetime
from decimal import Decimal

from flask import Blueprint, render_template, request, abort, redirect, send_from_directory, url_for, flash, session
from services.db import get_cursor
from modules.ess_mss import ess_service
from services import employee_service as emp_svc
from services import photo_service
from services.access_service import get_employee_scope_filter
from services.privacy_service import apply_privacy, SECTION_MAP

bp = Blueprint('employees', __name__, url_prefix='/employees')


def _can_edit_photo(target_emp_id):
    role = session.get('role_code', '')
    if role in ('SUPER_ADMIN', 'HR_ADMIN'):
        return True
    return session.get('employee_id') == target_emp_id


def _js(obj):
    if isinstance(obj, (date, datetime)):
        return obj.isoformat()
    if isinstance(obj, Decimal):
        return float(obj)
    return str(obj)


@bp.route('')
def list_employees():
    # Row-level scope: SUPER_ADMIN/HR-Ops see all; EMPLOYEE/EXECUTIVE see own dept;
    # MANAGER sees direct + indirect reports. See doc/role_authority_matrix.md.
    scope_filter = get_employee_scope_filter(
        role_code=session.get('role_code'),
        user_id=session.get('user_id'),
    )
    scope_clause = ""
    scope_params = ()
    if scope_filter is not None:
        kind, ids = scope_filter
        if kind == 'IDS' and ids:
            scope_clause = " WHERE e.id = ANY(%s)"
            scope_params = (ids,)
        else:
            # No employee linkage and restricted scope → empty list
            scope_clause = " WHERE FALSE"

    with get_cursor() as cur:

        # Q1: Status breakdown (unfiltered — drives KPI strip)
        cur.execute("SELECT status, COUNT(*) AS cnt FROM core.employees GROUP BY status")
        by_status = {r['status']: r['cnt'] for r in cur.fetchall()}

        # Q2: Employment type breakdown
        cur.execute("""
            SELECT COALESCE(et.name, 'Unknown') AS emp_type, COUNT(*) AS cnt
            FROM core.employees e
            LEFT JOIN core.employment_types et ON et.id = e.employment_type_id
            GROUP BY et.name ORDER BY cnt DESC
        """)
        by_emp_type = [dict(r) for r in cur.fetchall()]

        # Q3: Global flag KPIs (single pass)
        cur.execute("""
            SELECT
              COUNT(*)                                                                          AS total,
              COUNT(*) FILTER (WHERE e.status = 'ACTIVE')                                     AS active,
              COUNT(*) FILTER (WHERE e.status != 'ACTIVE')                                    AS inactive,
              COUNT(*) FILTER (WHERE e.immediate_supervisor_id IS NULL AND e.is_active)        AS no_manager,
              COUNT(*) FILTER (WHERE e.position_id IS NULL AND e.is_active)                   AS no_position,
              (SELECT COUNT(DISTINCT employee_id) FROM core.documents WHERE is_missing = TRUE) AS missing_docs,
              (SELECT COUNT(DISTINCT employee_id) FROM core.documents
               WHERE expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 30)                  AS expiring_30,
              COUNT(*) FILTER (WHERE e.date_hired >= CURRENT_DATE - 7)                        AS added_7d,
              COUNT(*) FILTER (WHERE e.date_hired >= CURRENT_DATE - 30)                       AS added_30d
            FROM core.employees e
        """)
        flag = cur.fetchone()

        stats = {
            'total':       flag['total'],
            'active':      flag['active'],
            'inactive':    flag['inactive'],
            'by_status':   by_status,
            'by_emp_type': by_emp_type,
            'no_manager':  flag['no_manager'],
            'no_position': flag['no_position'],
            'missing_docs': flag['missing_docs'],
            'expiring_30':  flag['expiring_30'],
            'added_7d':    flag['added_7d'],
            'added_30d':   flag['added_30d'],
        }

        # Filter-panel option lists
        cur.execute("""
            SELECT DISTINCT d.code, d.name
            FROM core.departments d JOIN core.employees e ON e.department_id = d.id
            ORDER BY d.name
        """)
        dept_options = [dict(r) for r in cur.fetchall()]

        cur.execute("""
            SELECT DISTINCT et.name
            FROM core.employment_types et JOIN core.employees e ON e.employment_type_id = et.id
            WHERE et.name IS NOT NULL ORDER BY et.name
        """)
        emp_type_options = [r['name'] for r in cur.fetchall()]

        cur.execute("""
            SELECT DISTINCT p.title
            FROM core.positions p JOIN core.employees e ON e.position_id = p.id
            WHERE p.title IS NOT NULL ORDER BY p.title
        """)
        position_options = [r['title'] for r in cur.fetchall()]

        cur.execute("""
            SELECT DISTINCT jg.code
            FROM core.job_grades jg JOIN core.employees e ON e.job_grade_id = jg.id
            WHERE jg.code IS NOT NULL ORDER BY jg.code
        """)
        grade_options = [r['code'] for r in cur.fetchall()]

        cur.execute("""
            SELECT m.id, CONCAT(m.first_name, ' ', m.last_name) AS name
            FROM core.employees m
            WHERE m.id IN (
                SELECT DISTINCT immediate_supervisor_id FROM core.employees
                WHERE immediate_supervisor_id IS NOT NULL
            )
            ORDER BY name
        """)
        manager_options = [dict(r) for r in cur.fetchall()]

        # All employees — enriched, always unfiltered (JS handles client-side filtering)
        cur.execute("""
            SELECT
                e.id, e.employee_no, e.first_name, e.last_name,
                e.gender, e.date_hired, e.is_active, e.work_email, e.status,
                e.immediate_supervisor_id, e.position_id,
                e.profile_photo_path AS photo_path,
                d.name   AS department_name,
                d.code   AS department_code,
                p.title  AS position_title,
                et.name  AS employment_type,
                jg.code  AS job_grade,
                CASE WHEN m.id IS NOT NULL
                     THEN CONCAT(m.first_name, ' ', m.last_name)
                     ELSE NULL END                              AS manager_name,
                EXISTS(
                    SELECT 1 FROM core.documents dc
                    WHERE dc.employee_id = e.id AND dc.is_missing = TRUE
                )                                               AS has_missing_docs,
                EXISTS(
                    SELECT 1 FROM core.documents dc
                    WHERE dc.employee_id = e.id
                      AND dc.expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 30
                )                                               AS has_expiring_docs
            FROM core.employees e
            LEFT JOIN core.departments      d  ON d.id  = e.department_id
            LEFT JOIN core.positions        p  ON p.id  = e.position_id
            LEFT JOIN core.employment_types et ON et.id = e.employment_type_id
            LEFT JOIN core.job_grades       jg ON jg.id = e.job_grade_id
            LEFT JOIN core.employees        m  ON m.id  = e.immediate_supervisor_id
            """ + scope_clause + """
            ORDER BY e.last_name, e.first_name
        """, scope_params)
        rows = cur.fetchall()

    # Serialize for JS embedding
    employees_json = json.dumps([dict(r) for r in rows], default=_js)
    stats_json     = json.dumps(stats, default=_js)
    filter_meta    = json.dumps({
        'dept_options':     dept_options,
        'emp_type_options': emp_type_options,
        'position_options': position_options,
        'grade_options':    grade_options,
        'manager_options':  manager_options,
    }, default=_js)

    # Initial filter state from URL params (for KPI-tile deep links)
    initial_filters = {
        'dept':        request.args.getlist('dept'),
        'status':      request.args.getlist('status') or (
                           [request.args.get('status')] if request.args.get('status') else []),
        'emp_type':    request.args.getlist('emp_type'),
        'no_manager':  '1' if request.args.get('no_manager') == '1' else '',
        'no_position': '1' if request.args.get('no_position') == '1' else '',
        'missing_docs': request.args.get('missing_docs', ''),
        'expiring':    request.args.get('expiring', ''),
        'recent':      request.args.get('recent', ''),
    }

    return render_template('employees/list.html',
                           stats=stats,
                           employees_json=employees_json,
                           stats_json=stats_json,
                           filter_meta=filter_meta,
                           initial_filters=initial_filters,
                           dept_options=dept_options,
                           position_options=position_options,
                           emp_type_options=emp_type_options,
                           grade_options=grade_options,
                           manager_options=manager_options)


@bp.route('/new', methods=['GET', 'POST'])
def employee_new():
    if request.method == 'POST':
        try:
            emp_id = emp_svc.create_employee(request.form, user_id=session.get('user_id'))
            flash('Employee created successfully.', 'success')
            return redirect(url_for('employees.employee_detail', employee_id=emp_id))
        except Exception as e:
            flash(f'Error creating employee: {e}', 'error')
    options = emp_svc.get_form_options()
    return render_template('employees/form.html', employee=None, options=options)


@bp.route('/<int:employee_id>')
def employee_detail(employee_id):
    profile = ess_service.get_my_profile(employee_id)
    if not profile['employee']:
        abort(404)
    extended = emp_svc.get_employee_extended(employee_id)
    # Apply field-level privacy masking based on viewer's role
    role_code = session.get('role_code', '')
    is_own = (session.get('employee_id') == employee_id)
    profile['employee'] = apply_privacy(profile['employee'], role_code, 'employee', is_own_record=is_own)
    profile['gov_ids']  = apply_privacy(profile.get('gov_ids', []),  role_code, 'government_id', is_own_record=is_own)
    profile['banks']    = apply_privacy(profile.get('banks', []),     role_code, 'bank_account',  is_own_record=is_own)
    profile['dependents'] = apply_privacy(profile.get('dependents', []), role_code, 'dependent', is_own_record=is_own)
    return render_template('employees/detail.html',
                           profile=profile, extended=extended)


@bp.route('/<int:employee_id>/edit', methods=['GET', 'POST'])
def employee_edit(employee_id):
    if request.method == 'POST':
        try:
            emp_svc.update_employee(employee_id, request.form, user_id=session.get('user_id'))
            flash('Employee updated successfully.', 'success')
            return redirect(url_for('employees.employee_detail', employee_id=employee_id))
        except Exception as e:
            flash(f'Error updating employee: {e}', 'error')
    employee = emp_svc.get_employee(employee_id)
    if not employee:
        abort(404)
    options = emp_svc.get_form_options()
    return render_template('employees/form.html', employee=employee, options=options)


@bp.route('/<int:employee_id>/delete', methods=['POST'])
def employee_delete(employee_id):
    try:
        emp_svc.delete_employee(employee_id)
        flash('Employee deactivated successfully.', 'success')
    except Exception as e:
        flash(f'Error: {e}', 'error')
    return redirect(url_for('employees.list_employees'))


# ═══════════════════════════════════════════════════════════════════
# Sub-table CRUD: generic pattern for all 5 sub-tables
# ═══════════════════════════════════════════════════════════════════
_SUB_TABLES = {
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


@bp.route('/<int:employee_id>/<sub_key>')
def sub_list(employee_id, sub_key):
    cfg = _SUB_TABLES.get(sub_key)
    if not cfg:
        abort(404)
    items = cfg['get_all'](employee_id)
    emp = emp_svc.get_employee(employee_id)
    # Apply field-level privacy masking on sub-table list
    role_code = session.get('role_code', '')
    is_own = (session.get('employee_id') == employee_id)
    section = SECTION_MAP.get(sub_key)
    if section:
        items = apply_privacy(items, role_code, section, is_own_record=is_own)
    return render_template('employees/sub_list.html',
                           emp=emp, items=items, cfg=cfg, sub_key=sub_key)


@bp.route('/<int:employee_id>/<sub_key>/new', methods=['GET', 'POST'])
def sub_new(employee_id, sub_key):
    cfg = _SUB_TABLES.get(sub_key)
    if not cfg:
        abort(404)
    if request.method == 'POST':
        try:
            cfg['save'](request.form, employee_id)
            flash(f'{cfg["label"]} added.', 'success')
            return redirect(url_for('employees.sub_list', employee_id=employee_id, sub_key=sub_key))
        except Exception as e:
            flash(f'Error: {e}', 'error')
    emp = emp_svc.get_employee(employee_id)
    return render_template('employees/sub_form.html',
                           emp=emp, item=None, cfg=cfg, sub_key=sub_key)


@bp.route('/<int:employee_id>/<sub_key>/<int:item_id>/edit', methods=['GET', 'POST'])
def sub_edit(employee_id, sub_key, item_id):
    cfg = _SUB_TABLES.get(sub_key)
    if not cfg:
        abort(404)
    if request.method == 'POST':
        try:
            cfg['save'](request.form, employee_id, item_id)
            flash(f'{cfg["label"]} updated.', 'success')
            return redirect(url_for('employees.sub_list', employee_id=employee_id, sub_key=sub_key))
        except Exception as e:
            flash(f'Error: {e}', 'error')
    item = cfg['get_one'](item_id)
    if not item:
        abort(404)
    emp = emp_svc.get_employee(employee_id)
    return render_template('employees/sub_form.html',
                           emp=emp, item=item, cfg=cfg, sub_key=sub_key)


@bp.route('/<int:employee_id>/<sub_key>/<int:item_id>/delete', methods=['POST'])
def sub_delete(employee_id, sub_key, item_id):
    cfg = _SUB_TABLES.get(sub_key)
    if not cfg:
        abort(404)
    try:
        cfg['delete'](item_id)
        flash(f'{cfg["label"]} deleted.', 'success')
    except Exception as e:
        flash(f'Error: {e}', 'error')
    return redirect(url_for('employees.sub_list', employee_id=employee_id, sub_key=sub_key))


# ══════════════════════════════════════════════════════════════════
# Profile Photo upload / delete / serve
# ══════════════════════════════════════════════════════════════════
@bp.route('/<int:employee_id>/photo/upload', methods=['POST'])
def photo_upload(employee_id):
    if not session.get('user_id'):
        abort(401)
    if not _can_edit_photo(employee_id):
        flash('You do not have permission to change this photo.', 'error')
        return redirect(url_for('employees.employee_detail', employee_id=employee_id))

    f = request.files.get('photo')
    rel, err = photo_service.save_photo(employee_id, f)
    if err:
        flash(err, 'error')
    else:
        flash('Profile photo updated.', 'success')

    # Honor optional `next` redirect (e.g., back to /me/profile)
    nxt = request.form.get('next') or request.referrer
    if nxt:
        return redirect(nxt)
    return redirect(url_for('employees.employee_detail', employee_id=employee_id))


@bp.route('/<int:employee_id>/photo/delete', methods=['POST'])
def photo_delete(employee_id):
    if not session.get('user_id'):
        abort(401)
    if not _can_edit_photo(employee_id):
        flash('You do not have permission to delete this photo.', 'error')
        return redirect(url_for('employees.employee_detail', employee_id=employee_id))
    photo_service.delete_photo(employee_id)
    flash('Profile photo removed.', 'success')
    nxt = request.form.get('next') or request.referrer
    if nxt:
        return redirect(nxt)
    return redirect(url_for('employees.employee_detail', employee_id=employee_id))
