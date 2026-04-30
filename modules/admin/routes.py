from flask import Blueprint, current_app, flash, g, jsonify, redirect, render_template, request, url_for
from services.access_service import (
    get_access_matrix, get_mod_permissions,
    get_module_access_detail, save_page_access, save_feature_access,
    get_all_roles, get_all_users_for_access, create_role, MODULES,
    get_data_source_access_detail, save_data_source_access,
)
from services.db import get_cursor
from services.demo_data import DEMO_USERS, PRESETS, get_current_counts, load_preset, truncate_demo_data
from services.privacy_service import SENSITIVE_FIELDS, get_privacy_rules, save_privacy_rule
from services.reference_service import (
    REFERENCE_TABLES, UnknownReferenceKey,
    create_row, delete_row, get_row, list_rows, update_row,
)
from services.service_monitor import SERVICES, check_all_services, start_service
from services.settings_service import (
    EDITABLE_BRANDING_KEYS, get_branding, save_branding_bulk,
)
from services.theme_service import activate_theme, list_themes
from services import validation_service

bp = Blueprint('admin', __name__, url_prefix='/admin')


# ── Validation rules admin (SUPER_ADMIN + IT_ADMIN only) ──────────────
def _can_manage_validations():
    return g.current_user and g.current_user['role_code'] in ('SUPER_ADMIN', 'IT_ADMIN')


@bp.route('/validations')
def validations():
    if not _can_manage_validations():
        # HR_MANAGER and other admin-tab roles get a read-only view
        if not (g.current_user and g.current_user['role_code'] in ('HR_MANAGER', 'HR_ADMIN')):
            flash('Access denied — administrators only.', 'error')
            return redirect(url_for('dashboard.index'))

    rules = validation_service.get_rules()
    by_category = {}
    for r in rules:
        by_category.setdefault(r['category'], []).append(r)
    return render_template(
        'admin/validations.html',
        rules_by_category=by_category,
        master_enforced=validation_service.is_master_enforced(),
        can_edit=_can_manage_validations(),
        category_labels={
            'EMPLOYEE':     '👤 Employee Records',
            'LEAVE':        '📅 Leave & Absence',
            'DTR':          '🕐 Time & Attendance',
            'COMPENSATION': '💰 Compensation',
        },
    )


@bp.route('/validations/master', methods=['POST'])
def validations_set_master():
    if not _can_manage_validations():
        return jsonify({'ok': False, 'message': 'Access denied'}), 403
    body = request.get_json(silent=True) or {}
    enforce = bool(body.get('enforce', True))
    validation_service.set_master_enforce(enforce, g.current_user['id'] if g.current_user else None)
    return jsonify({'ok': True, 'master_enforce': enforce})


@bp.route('/validations/<rule_code>/toggle', methods=['POST'])
def validations_toggle_rule(rule_code):
    if not _can_manage_validations():
        return jsonify({'ok': False, 'message': 'Access denied'}), 403
    body = request.get_json(silent=True) or {}
    enforce = bool(body.get('enforce', True))
    validation_service.set_rule_enforce(rule_code, enforce, g.current_user['id'] if g.current_user else None)
    return jsonify({'ok': True, 'rule_code': rule_code, 'is_enforced': enforce})


@bp.route('/themes', methods=['GET', 'POST'])
def themes():
    if request.method == 'POST':
        activate_theme(int(request.form['theme_id']))
    return render_template('admin/themes.html', themes=list_themes())


@bp.route('/branding', methods=['GET', 'POST'])
def branding():
    """Configure every branding key: company name, tagline, login
    wallpaper, powered-by footer. SUPER_ADMIN + HR_ADMIN only."""
    if not g.current_user or g.current_user['role_code'] not in ('SUPER_ADMIN', 'HR_ADMIN'):
        return redirect(url_for('dashboard.index'))
    if request.method == 'POST':
        save_branding_bulk(request.form)
        flash('Branding updated. Changes are live immediately.', 'success')
        return redirect(url_for('admin.branding'))
    return render_template('admin/branding.html',
                           branding=get_branding(),
                           editable_keys=EDITABLE_BRANDING_KEYS)


@bp.route('/statuses')
def statuses():
    with get_cursor() as cur:
        cur.execute('SELECT * FROM core.status_definitions ORDER BY module, sort_order, status_label')
        statuses = cur.fetchall()
    return render_template('admin/statuses.html', statuses=statuses)


_BUILTIN_ROLES = [
    ('SUPER_ADMIN', 'Super Administrator'),
    ('HR_ADMIN',    'HR Administrator'),
    ('EXECUTIVE',   'Executive'),
    ('MANAGER',     'People Manager'),
    ('EMPLOYEE',    'Employee'),
]


def _all_roles_for_dropdown():
    """Union of built-in role codes (+ labels) with any custom core.roles
    rows and any role_code actually used by existing users.  Returns a
    deduplicated, ordered list of dicts: {code, name}."""
    seen = {}
    # 1. Built-ins first (deterministic order)
    for code, name in _BUILTIN_ROLES:
        seen[code] = name
    # 2. Custom roles from core.roles
    with get_cursor() as cur:
        cur.execute("""
            SELECT code, name FROM core.roles WHERE is_active = TRUE
        """)
        for r in cur.fetchall():
            if r['code'] not in seen:
                seen[r['code']] = r['name']
        # 3. Whatever role_codes actually exist on users (catches drift)
        cur.execute("SELECT DISTINCT role_code FROM core.users WHERE role_code IS NOT NULL")
        for r in cur.fetchall():
            seen.setdefault(r['role_code'], r['role_code'])
    # Preserve insertion order: built-ins → customs → drifted
    return [{'code': k, 'name': v} for k, v in seen.items()]


@bp.route('/users')
def users():
    with get_cursor() as cur:
        cur.execute("""
            SELECT u.id, u.username, u.display_name, u.email, u.role_code,
                   u.is_active, u.last_login_at, u.employee_id,
                   e.employee_no,
                   CONCAT_WS(' ', e.first_name, e.last_name) AS linked_employee_name
            FROM core.users u
            LEFT JOIN core.employees e ON e.id = u.employee_id
            ORDER BY u.id
        """)
        users = cur.fetchall()
    roles = _all_roles_for_dropdown()
    can_edit = g.current_user and g.current_user.get('role_code') == 'SUPER_ADMIN'
    return render_template('admin/users.html',
                           users=users, roles=roles, can_edit=can_edit)


@bp.route('/users/<int:user_id>/save', methods=['POST'])
def users_save(user_id):
    if not g.current_user or g.current_user.get('role_code') != 'SUPER_ADMIN':
        return jsonify({'ok': False, 'message': 'SUPER_ADMIN only'}), 403

    data = request.get_json(silent=True) or request.form.to_dict()
    # Validate role
    with get_cursor() as cur:
        cur.execute('SELECT code FROM core.roles WHERE is_active = TRUE')
        valid_roles = {r['code'] for r in cur.fetchall()}

    role_code = (data.get('role_code') or '').strip()
    if role_code and role_code not in valid_roles:
        return jsonify({'ok': False,
                        'message': f'Invalid role: {role_code}'}), 400

    # Safety: refuse to demote the last remaining SUPER_ADMIN
    if role_code and role_code != 'SUPER_ADMIN':
        with get_cursor() as cur:
            cur.execute("""
                SELECT COUNT(*) AS n FROM core.users
                WHERE role_code = 'SUPER_ADMIN' AND is_active = TRUE AND id <> %s
            """, (user_id,))
            if cur.fetchone()['n'] == 0:
                cur.execute('SELECT role_code FROM core.users WHERE id = %s', (user_id,))
                current = cur.fetchone()
                if current and current['role_code'] == 'SUPER_ADMIN':
                    return jsonify({
                        'ok': False,
                        'message': 'Cannot demote the last active SUPER_ADMIN.'
                    }), 400

    # Build SET clauses for allowed fields
    updates, params = [], []
    for field in ('display_name', 'email', 'role_code'):
        if field in data and data[field] is not None:
            updates.append(f'{field} = %s')
            params.append((data[field] or '').strip() or None)
    if 'is_active' in data:
        val = data['is_active']
        if isinstance(val, bool):
            pass
        elif isinstance(val, str):
            val = val.lower() in ('true', '1', 'yes', 'on')
        else:
            val = bool(val)
        updates.append('is_active = %s')
        params.append(val)

    if not updates:
        return jsonify({'ok': False, 'message': 'Nothing to update.'}), 400

    params.append(user_id)
    with get_cursor(commit=True) as cur:
        try:
            cur.execute(f"""
                UPDATE core.users
                SET {', '.join(updates)}, updated_at = NOW()
                WHERE id = %s
                RETURNING id, display_name, email, role_code, is_active
            """, tuple(params))
            row = cur.fetchone()
        except Exception as ex:
            return jsonify({'ok': False, 'message': str(ex)}), 500

    if not row:
        return jsonify({'ok': False, 'message': 'User not found'}), 404
    return jsonify({'ok': True, 'user': dict(row)})


@bp.route('/access-matrix')
def access_matrix():
    """Module-level access matrix with role/user tabs and per-action granularity."""
    if not g.current_user or g.current_user['role_code'] != 'SUPER_ADMIN':
        flash('Access denied — SUPER_ADMIN only.', 'error')
        return redirect(url_for('dashboard.index'))

    # Grantee selection from query params
    grantee_type = request.args.get('grantee_type', 'ROLE')
    grantee_role = request.args.get('role', get_all_roles()[0] if get_all_roles() else 'HR_ADMIN')
    grantee_uid  = request.args.get('user_id', type=int)
    module_code  = request.args.get('module', 'attendance')

    roles = get_all_roles()
    users = get_all_users_for_access()

    if module_code == 'data_sources':
        detail = get_data_source_access_detail(
            grantee_type=grantee_type,
            grantee_role=grantee_role if grantee_type == 'ROLE' else None,
            grantee_user_id=grantee_uid if grantee_type == 'USER' else None,
        )
    else:
        detail = get_module_access_detail(
            module_code=module_code,
            grantee_type=grantee_type,
            grantee_role=grantee_role if grantee_type == 'ROLE' else None,
            grantee_user_id=grantee_uid if grantee_type == 'USER' else None,
        )

    selected_user = next((u for u in users if u['id'] == grantee_uid), None) if grantee_uid else None

    return render_template('admin/access_matrix.html',
                           modules=MODULES, module_code=module_code,
                           grantee_type=grantee_type,
                           grantee_role=grantee_role,
                           grantee_uid=grantee_uid,
                           selected_user=selected_user,
                           roles=roles, users=users,
                           detail=detail,
                           is_data_source_view=(module_code == 'data_sources'))


@bp.route('/access-matrix/toggle', methods=['POST'])
def access_matrix_toggle():
    """AJAX endpoint — toggle a page or feature access grant. Expects JSON body."""
    if not g.current_user or g.current_user['role_code'] != 'SUPER_ADMIN':
        return jsonify({'ok': False, 'message': 'Access denied'}), 403

    from flask import session
    body         = request.get_json(silent=True) or {}
    granted_by   = session.get('user_id')
    toggle_type  = body.get('type')          # 'page' or 'feature'
    item_id      = int(body['id']) if body.get('id') else None
    can_access   = bool(body.get('can_access', True))
    grantee_type = body.get('grantee_type', 'ROLE')
    grantee_role = body.get('role') or None
    grantee_uid  = int(body['user_id']) if body.get('user_id') else None

    if not item_id:
        return jsonify({'ok': False, 'message': 'Missing id'}), 400

    try:
        if toggle_type == 'page':
            # save_page_access cascades to features and returns their IDs
            cascaded_ids = save_page_access(
                item_id, can_access, granted_by,
                role_code=grantee_role if grantee_type == 'ROLE' else None,
                user_id=grantee_uid   if grantee_type == 'USER' else None,
            )
            return jsonify({'ok': True, 'cascaded_feature_ids': cascaded_ids or []})
        elif toggle_type == 'feature':
            save_feature_access(item_id, can_access, granted_by,
                                role_code=grantee_role if grantee_type == 'ROLE' else None,
                                user_id=grantee_uid   if grantee_type == 'USER' else None)
            return jsonify({'ok': True, 'cascaded_feature_ids': []})
        elif toggle_type == 'data_source':
            save_data_source_access(
                item_id, can_access, granted_by,
                role_code=grantee_role if grantee_type == 'ROLE' else None,
                user_id=grantee_uid   if grantee_type == 'USER' else None,
            )
            return jsonify({'ok': True, 'cascaded_feature_ids': []})
        else:
            return jsonify({'ok': False, 'message': 'Unknown toggle type'}), 400
    except Exception as e:
        return jsonify({'ok': False, 'message': str(e)}), 500


@bp.route('/access-matrix/search')
def access_matrix_search():
    """Global search across pages, features, and data sources.

    Returns each hit annotated with the current grant state for the
    specified grantee so the client can render toggle switches inline.
    """
    if not g.current_user or g.current_user['role_code'] != 'SUPER_ADMIN':
        return jsonify({'ok': False, 'message': 'Access denied'}), 403

    q = (request.args.get('q') or '').strip()
    if len(q) < 2:
        return jsonify({'ok': True, 'pages': [], 'features': [], 'data_sources': []})

    grantee_type = request.args.get('grantee_type', 'ROLE')
    grantee_role = request.args.get('role') or None
    grantee_uid  = request.args.get('user_id', type=int)

    like = f'%{q}%'
    module_lookup = {m['code']: m['label'] for m in MODULES}

    with get_cursor() as cur:
        # ── Pages ──
        cur.execute("""
            SELECT p.id, p.path, p.title, p.nav_label, p.module
            FROM core.page_registry p
            WHERE p.title ILIKE %s OR p.path ILIKE %s OR p.nav_label ILIKE %s
               OR p.module ILIKE %s
            ORDER BY p.module, p.nav_order
            LIMIT 50
        """, (like, like, like, like))
        pages = [dict(r) for r in cur.fetchall()]

        if pages:
            page_ids = [p['id'] for p in pages]
            if grantee_type == 'ROLE' and grantee_role:
                cur.execute("""
                    SELECT page_id, can_access FROM core.role_page_access
                    WHERE role_code = %s AND page_id = ANY(%s)
                """, (grantee_role, page_ids))
            elif grantee_type == 'USER' and grantee_uid:
                cur.execute("""
                    SELECT page_id, can_access FROM core.user_page_access
                    WHERE user_id = %s AND page_id = ANY(%s)
                """, (grantee_uid, page_ids))
            else:
                cur.execute("SELECT NULL AS page_id, NULL AS can_access WHERE FALSE")
            grants = {r['page_id']: r['can_access'] for r in cur.fetchall()}
            for p in pages:
                p['granted'] = bool(grants.get(p['id'], grantee_role == 'SUPER_ADMIN'))
                p['module_label'] = module_lookup.get(p['module'], p['module'])

        # ── Features ──
        cur.execute("""
            SELECT fr.id, fr.code, fr.name, fr.action_type, fr.page_path,
                   fr.module, fr.is_enabled
            FROM core.feature_registry fr
            WHERE fr.feature_type = 'ACTION'
              AND (fr.name ILIKE %s OR fr.code ILIKE %s OR fr.description ILIKE %s
                   OR fr.action_type ILIKE %s OR fr.page_path ILIKE %s
                   OR fr.module ILIKE %s)
            ORDER BY fr.module, fr.page_path, fr.action_type
            LIMIT 60
        """, (like, like, like, like, like, like))
        features = [dict(r) for r in cur.fetchall()]

        if features:
            feat_ids = [f['id'] for f in features]
            if grantee_type == 'ROLE' and grantee_role:
                cur.execute("""
                    SELECT feature_id, can_access FROM core.role_feature_access
                    WHERE role_code = %s AND feature_id = ANY(%s)
                """, (grantee_role, feat_ids))
            elif grantee_type == 'USER' and grantee_uid:
                cur.execute("""
                    SELECT feature_id, can_access FROM core.user_feature_access
                    WHERE user_id = %s AND feature_id = ANY(%s)
                """, (grantee_uid, feat_ids))
            else:
                cur.execute("SELECT NULL AS feature_id, NULL AS can_access WHERE FALSE")
            fgrants = {r['feature_id']: r['can_access'] for r in cur.fetchall()}
            for f in features:
                f['granted'] = bool(fgrants.get(f['id'], f.get('is_enabled') if grantee_role == 'SUPER_ADMIN' else False))
                f['module_label'] = module_lookup.get(f['module'], f['module'])

        # ── Data sources ──
        cur.execute("""
            SELECT id, source_code, source_label, module, description
            FROM analytics.report_data_sources
            WHERE is_active = TRUE
              AND (source_code ILIKE %s OR source_label ILIKE %s
                   OR description ILIKE %s OR module ILIKE %s)
            ORDER BY module, source_label
            LIMIT 30
        """, (like, like, like, like))
        sources = [dict(r) for r in cur.fetchall()]

        if sources:
            src_ids = [s['id'] for s in sources]
            if grantee_type == 'ROLE' and grantee_role:
                cur.execute("""
                    SELECT source_id, can_access FROM analytics.report_source_role_access
                    WHERE role_code = %s AND source_id = ANY(%s)
                """, (grantee_role, src_ids))
            elif grantee_type == 'USER' and grantee_uid:
                cur.execute("""
                    SELECT source_id, can_access FROM analytics.report_source_user_access
                    WHERE user_id = %s AND source_id = ANY(%s)
                """, (grantee_uid, src_ids))
            else:
                cur.execute("SELECT NULL AS source_id, NULL AS can_access WHERE FALSE")
            sgrants = {r['source_id']: r['can_access'] for r in cur.fetchall()}
            for s in sources:
                s['granted'] = bool(sgrants.get(s['id'], grantee_role == 'SUPER_ADMIN'))

    return jsonify({
        'ok': True,
        'query': q,
        'pages': pages,
        'features': features,
        'data_sources': sources,
    })


@bp.route('/access-matrix/create-role', methods=['POST'])
def access_matrix_create_role():
    """Create a new role from the Access Matrix UI."""
    if not g.current_user or g.current_user['role_code'] != 'SUPER_ADMIN':
        flash('Access denied — SUPER_ADMIN only.', 'error')
        return redirect(url_for('admin.access_matrix'))

    code = (request.form.get('role_code') or '').upper().strip().replace(' ', '_')
    name = (request.form.get('role_name') or '').strip()
    desc = (request.form.get('role_description') or '').strip()

    if not code or not name:
        flash('Role code and name are required.', 'error')
        return redirect(url_for('admin.access_matrix'), code=303)

    try:
        create_role(code, name, desc)
        flash(f'Role "{code}" created successfully.', 'success')
        return redirect(url_for('admin.access_matrix', grantee_type='ROLE', role=code), code=303)
    except Exception as e:
        if 'duplicate' in str(e).lower() or 'unique' in str(e).lower():
            flash(f'Role code "{code}" already exists.', 'error')
        else:
            flash(f'Error creating role: {e}', 'error')
        return redirect(url_for('admin.access_matrix'), code=303)


@bp.route('/simulated-scenarios')
def simulated_scenarios():
    scenarios = [
        {'label': 'Super Admin full config', 'user_id': 1, 'route': '/admin/access-matrix'},
        {'label': 'HR Admin workflow review', 'user_id': 2, 'route': '/workflow/instance/1'},
        {'label': 'Manager approval scenario', 'user_id': 3, 'route': '/workflow/instance/2'},
        {'label': 'Employee restricted view', 'user_id': 4, 'route': '/'},
    ]
    return render_template('admin/simulated_scenarios.html', scenarios=scenarios)


@bp.route('/visual-builder')
def visual_builder():
    with get_cursor() as cur:
        cur.execute('SELECT id, workflow_name, module_code FROM workflow_definitions ORDER BY workflow_name')
        workflows = cur.fetchall()
        cur.execute('SELECT * FROM workflow_steps ORDER BY workflow_definition_id, step_order')
        steps = cur.fetchall()
    return render_template('admin/visual_builder.html', workflows=workflows, steps=steps)


@bp.route('/form-builder')
def form_builder():
    with get_cursor() as cur:
        cur.execute('SELECT * FROM dynamic_forms ORDER BY form_name')
        forms = cur.fetchall()
        cur.execute('SELECT * FROM form_fields ORDER BY dynamic_form_id, field_order')
        fields = cur.fetchall()
    return render_template('admin/form_builder.html', forms=forms, fields=fields)


@bp.route('/kpi-builder')
def kpi_builder():
    with get_cursor() as cur:
        cur.execute('SELECT * FROM kpi_query_registry ORDER BY id')
        kpis = cur.fetchall()
    return render_template('admin/kpi_builder.html', kpis=kpis)


@bp.route('/orchestration')
def orchestration():
    with get_cursor() as cur:
        cur.execute('SELECT * FROM orchestration_flows ORDER BY id')
        flows = cur.fetchall()
        cur.execute('SELECT * FROM orchestration_steps ORDER BY orchestration_flow_id, step_order')
        steps = cur.fetchall()
    return render_template('admin/orchestration.html', flows=flows, steps=steps)


@bp.route('/reference')
@bp.route('/reference-data')
def reference_data():
    return render_template('admin/reference_data.html', references=REFERENCE_TABLES)


def _guard_key(key):
    """Return cfg or None. Flashes + redirects if key is unregistered."""
    if key not in REFERENCE_TABLES:
        flash(f'Reference table "{key}" is not registered yet. '
              f'Ask an admin to add it to REFERENCE_TABLES.', 'error')
        return None
    return REFERENCE_TABLES[key]


@bp.route('/reference-data/<key>')
def reference_list(key):
    if _guard_key(key) is None:
        return redirect(url_for('admin.reference_data'))
    try:
        rows, cfg = list_rows(key)
    except UnknownReferenceKey:
        flash(f'Unknown reference-data key: {key}', 'error')
        return redirect(url_for('admin.reference_data'))
    return render_template('admin/reference_list.html', ref_key=key, rows=rows, cfg=cfg)


@bp.route('/reference-data/<key>/new', methods=['GET', 'POST'])
def reference_new(key):
    cfg = _guard_key(key)
    if cfg is None:
        return redirect(url_for('admin.reference_data'))
    if request.method == 'POST':
        try:
            create_row(key, request.form)
            flash('Row created.', 'success')
        except Exception as e:
            flash(f'Could not create row: {e}', 'error')
            return render_template('admin/reference_form.html',
                                   ref_key=key, cfg=cfg, row=dict(request.form))
        return redirect(url_for('admin.reference_list', key=key))
    return render_template('admin/reference_form.html', ref_key=key, cfg=cfg, row={})


@bp.route('/reference-data/<key>/<int:row_id>/edit', methods=['GET', 'POST'])
def reference_edit(key, row_id):
    if _guard_key(key) is None:
        return redirect(url_for('admin.reference_data'))
    try:
        row, cfg = get_row(key, row_id)
    except UnknownReferenceKey:
        flash(f'Unknown reference-data key: {key}', 'error')
        return redirect(url_for('admin.reference_data'))
    if not row:
        flash('Row not found.', 'error')
        return redirect(url_for('admin.reference_list', key=key))
    if request.method == 'POST':
        try:
            update_row(key, row_id, request.form)
            flash('Row updated.', 'success')
        except Exception as e:
            flash(f'Could not save row: {e}', 'error')
            return render_template('admin/reference_form.html',
                                   ref_key=key, cfg=cfg, row=dict(request.form))
        return redirect(url_for('admin.reference_list', key=key))
    return render_template('admin/reference_form.html', ref_key=key, cfg=cfg, row=row)


@bp.route('/reference-data/<key>/<int:row_id>/delete', methods=['POST'])
def reference_delete(key, row_id):
    if _guard_key(key) is None:
        return redirect(url_for('admin.reference_data'))
    try:
        delete_row(key, row_id)
        flash('Row deleted.', 'success')
    except Exception as e:
        flash(f'Could not delete: {e}', 'error')
    return redirect(url_for('admin.reference_list', key=key))


@bp.route('/services')
def services():
    if not g.current_user or g.current_user['role_code'] != 'SUPER_ADMIN':
        return redirect(url_for('dashboard.index'))
    statuses = check_all_services()
    return render_template('admin/services.html', services=statuses)


@bp.route('/services/<name>/start', methods=['POST'])
def service_start(name):
    if not g.current_user or g.current_user['role_code'] != 'SUPER_ADMIN':
        return jsonify({'success': False, 'message': 'Access denied'}), 403
    result = start_service(name)
    if request.headers.get('X-Requested-With') == 'XMLHttpRequest':
        return jsonify(result)
    if result['success']:
        flash(result['message'], 'success')
    else:
        flash(result['message'], 'error')
    return redirect(url_for('admin.services'))


@bp.route('/services/status')
def services_status():
    if not g.current_user or g.current_user['role_code'] != 'SUPER_ADMIN':
        return jsonify([])
    return jsonify(check_all_services())


@bp.route('/modification-access', methods=['GET'])
def modification_access():
    """Admin UI — configure which roles/users can modify transactional records."""
    if not g.current_user or g.current_user['role_code'] != 'SUPER_ADMIN':
        flash('Access denied — SUPER_ADMIN only.', 'error')
        return redirect(url_for('dashboard.index'))
    permissions = get_mod_permissions()
    with get_cursor() as cur:
        cur.execute("SELECT DISTINCT role_code FROM core.users WHERE role_code IS NOT NULL ORDER BY role_code")
        roles = [r['role_code'] for r in cur.fetchall()]
        cur.execute("SELECT id, display_name, email, role_code FROM core.users WHERE is_active = TRUE ORDER BY display_name")
        users = cur.fetchall()
    modules = ['ATTENDANCE', 'PAYROLL', 'LEAVE', 'RECRUITMENT', 'PERFORMANCE',
               'LEARNING', 'DISCIPLINE', 'HEALTH', 'DMS']
    return render_template('admin/modification_access.html',
                           permissions=permissions, roles=roles,
                           users=users, modules=modules)


@bp.route('/modification-access/grant', methods=['POST'])
def modification_access_grant():
    """Grant or revoke modification access for a role or user."""
    if not g.current_user or g.current_user['role_code'] != 'SUPER_ADMIN':
        flash('Access denied.', 'error')
        return redirect(url_for('admin.modification_access'))

    module_code  = request.form.get('module_code', '').upper().strip()
    grantee_type = request.form.get('grantee_type', 'ROLE').upper()
    grantee_role = request.form.get('grantee_role', '').strip() or None
    grantee_uid  = request.form.get('grantee_user_id', type=int)
    can_modify   = request.form.get('can_modify', 'true').lower() == 'true'

    if not module_code:
        flash('Module is required.', 'error')
        return redirect(url_for('admin.modification_access'))
    if grantee_type == 'ROLE' and not grantee_role:
        flash('Role is required for role-based grants.', 'error')
        return redirect(url_for('admin.modification_access'))
    if grantee_type == 'USER' and not grantee_uid:
        flash('User is required for user-based grants.', 'error')
        return redirect(url_for('admin.modification_access'))

    from flask import session
    with get_cursor(commit=True) as cur:
        if grantee_type == 'ROLE':
            cur.execute("""
                INSERT INTO core.mod_permissions
                    (module_code, grantee_type, grantee_role, can_modify, granted_by)
                VALUES (%s, 'ROLE', %s, %s, %s)
                ON CONFLICT (module_code, grantee_type, grantee_role)
                DO UPDATE SET can_modify = EXCLUDED.can_modify, granted_by = EXCLUDED.granted_by, granted_at = NOW()
            """, (module_code, grantee_role, can_modify, session.get('user_id')))
        else:
            cur.execute("""
                INSERT INTO core.mod_permissions
                    (module_code, grantee_type, grantee_user_id, can_modify, granted_by)
                VALUES (%s, 'USER', %s, %s, %s)
                ON CONFLICT (module_code, grantee_type, grantee_user_id)
                DO UPDATE SET can_modify = EXCLUDED.can_modify, granted_by = EXCLUDED.granted_by, granted_at = NOW()
            """, (module_code, grantee_uid, can_modify, session.get('user_id')))

    action = 'granted' if can_modify else 'revoked'
    flash(f'Modification access {action} for {module_code}.', 'success')
    return redirect(url_for('admin.modification_access'))


@bp.route('/modification-access/<int:perm_id>/delete', methods=['POST'])
def modification_access_delete(perm_id):
    """Remove a modification permission grant."""
    if not g.current_user or g.current_user['role_code'] != 'SUPER_ADMIN':
        flash('Access denied.', 'error')
        return redirect(url_for('admin.modification_access'))
    with get_cursor(commit=True) as cur:
        cur.execute("DELETE FROM core.mod_permissions WHERE id = %s", (perm_id,))
    flash('Permission removed.', 'success')
    return redirect(url_for('admin.modification_access'))


@bp.route('/privacy', methods=['GET'])
def privacy_rules():
    """Field-level privacy configuration grid."""
    if not g.current_user or g.current_user['role_code'] != 'SUPER_ADMIN':
        flash('Access denied.', 'error')
        return redirect(url_for('admin.access_matrix'))
    roles = get_all_roles()          # list of role_code strings
    rules = get_privacy_rules()      # {(section, field, role): {visibility, mask_char}}
    # Build role_codes list in consistent display order
    role_order = ['EMPLOYEE', 'MANAGER', 'HR_STAFF', 'HR_ADMIN', 'SUPER_ADMIN']
    display_roles = [r for r in role_order if r in roles] + \
                    [r for r in roles if r not in role_order]
    return render_template(
        'admin/privacy_rules.html',
        sensitive_fields=SENSITIVE_FIELDS,
        display_roles=display_roles,
        rules=rules,
    )


@bp.route('/privacy/save', methods=['POST'])
def privacy_rules_save():
    """AJAX endpoint: save a single field-visibility rule."""
    if not g.current_user or g.current_user['role_code'] != 'SUPER_ADMIN':
        return jsonify({'ok': False, 'error': 'Access denied'}), 403
    data = request.get_json(force=True)
    section    = data.get('section', '').strip()
    field_name = data.get('field_name', '').strip()
    role_code  = data.get('role_code', '').strip()
    visibility = data.get('visibility', 'VISIBLE').strip().upper()
    if visibility not in ('VISIBLE', 'MASKED', 'HIDDEN'):
        return jsonify({'ok': False, 'error': 'Invalid visibility'}), 400
    save_privacy_rule(section, field_name, role_code, visibility, g.current_user['id'])
    return jsonify({'ok': True})


@bp.route('/demo-data', methods=['GET'])
def demo_data():
    from services import demo_seed_service as dss
    allowed = g.current_user and (
        g.current_user.get('role_code') == 'SUPER_ADMIN'
        or g.current_user.get('email') in DEMO_USERS
    )
    profiles = dss.get_profiles() if allowed else []
    counts = dss.get_record_counts() if allowed else {}
    active = dss.get_active_profile() if allowed else None
    return render_template('admin/demo_data.html',
                           allowed=allowed, profiles=profiles,
                           counts=counts, active_profile=active,
                           presets=PRESETS)


@bp.route('/demo-data/activate/<code>', methods=['POST'])
def demo_data_activate(code):
    from services import demo_seed_service as dss
    if not g.current_user or g.current_user.get('role_code') != 'SUPER_ADMIN':
        flash('Access denied — SUPER_ADMIN only.', 'error')
        return redirect(url_for('admin.demo_data'))
    try:
        from flask import session
        dss.activate_profile(code, session.get('user_id'))
        flash(f'Demo profile "{code}" activated successfully.', 'success')
    except Exception as e:
        flash(f'Error activating profile: {e}', 'error')
    return redirect(url_for('admin.demo_data'))


@bp.route('/demo-data/reset', methods=['POST'])
def demo_data_reset():
    from services import demo_seed_service as dss
    if not g.current_user or g.current_user.get('role_code') != 'SUPER_ADMIN':
        flash('Access denied.', 'error')
        return redirect(url_for('admin.demo_data'))
    try:
        dss.clear_all_demo_data()
        flash('Demo data cleared. Base 20 employees restored.', 'success')
    except Exception as e:
        flash(f'Error resetting: {e}', 'error')
    return redirect(url_for('admin.demo_data'))


@bp.route('/demo-data/truncate', methods=['POST'])
def demo_data_truncate():
    from services import demo_seed_service as dss
    if not g.current_user or g.current_user.get('role_code') != 'SUPER_ADMIN':
        flash('Access denied.', 'error')
        return redirect(url_for('admin.demo_data'))
    confirm = request.form.get('confirm')
    if confirm != 'yes':
        flash('Truncate requires confirmation. Check the confirm box.', 'warning')
        return redirect(url_for('admin.demo_data'))
    try:
        dss.truncate_all_transactional()
        flash('All transactional data truncated. Only app config and admin users preserved.', 'success')
    except Exception as e:
        flash(f'Error truncating: {e}', 'error')
    return redirect(url_for('admin.demo_data'))


@bp.route('/demo-data/load', methods=['POST'])
def demo_data_load():
    if not g.current_user or g.current_user['email'] not in DEMO_USERS:
        flash('Access denied.', 'error')
        return redirect(url_for('admin.demo_data'))
    period = request.form.get('period', 'week')
    do_truncate = request.form.get('truncate') == '1'
    try:
        load_preset(period, do_truncate=do_truncate)
        label = PRESETS[period]['label']
        action = 'replaced with' if do_truncate else 'extended with'
        flash(f'Demo data {action} the {label} preset successfully.', 'success')
    except Exception as e:
        flash(f'Error loading preset: {e}', 'error')
    return redirect(url_for('admin.demo_data'))


# =========================================================================
# Reminder Engine Admin
# =========================================================================

@bp.route('/reminders')
def reminders():
    if not g.current_user or g.current_user['role_code'] not in ('SUPER_ADMIN', 'HR_ADMIN'):
        flash('Access denied.', 'error')
        return redirect(url_for('dashboard.index'))
    from services import reminder_engine as eng
    stats = eng.get_reminder_stats()
    rules = eng.get_rules()
    recent = eng.get_recent_reminders(limit=30)
    return render_template('admin/reminders.html', stats=stats, rules=rules, recent=recent)


@bp.route('/reminders/run-all', methods=['POST'])
def reminders_run_all():
    if not g.current_user or g.current_user['role_code'] not in ('SUPER_ADMIN', 'HR_ADMIN'):
        flash('Access denied.', 'error')
        return redirect(url_for('admin.reminders'))
    from services import reminder_engine as eng
    fired = eng.fire_all_reminders()
    flash(f'Reminder engine executed. {fired} new reminder(s) fired.', 'success')
    return redirect(url_for('admin.reminders'), code=303)


@bp.route('/users/backfill-orphans', methods=['POST'])
def users_backfill_orphans():
    """Create core.users rows for employees missing one so they show in the login dropdown."""
    if not g.current_user or g.current_user['role_code'] not in ('SUPER_ADMIN', 'HR_ADMIN'):
        flash('Access denied.', 'error')
        return redirect(url_for('admin.users_list') if 'admin.users_list' in [r.endpoint for r in current_app.url_map.iter_rules()] else '/')
    from services.employee_service import backfill_user_accounts
    n = backfill_user_accounts()
    flash(f'Created {n} user account(s) for orphan employees.' if n else
          'No orphan employees found — all employees already have user accounts.',
          'success')
    return redirect(request.referrer or '/admin/users', code=303)


@bp.route('/reminders/escalate', methods=['POST'])
def reminders_escalate():
    if not g.current_user or g.current_user['role_code'] not in ('SUPER_ADMIN', 'HR_ADMIN'):
        flash('Access denied.', 'error')
        return redirect(url_for('admin.reminders'))
    from services import reminder_engine as eng
    eng.run_escalations()
    flash('Escalation check completed.', 'success')
    return redirect(url_for('admin.reminders'), code=303)


@bp.route('/reminders/toggle/<int:rule_id>', methods=['POST'])
def reminder_toggle(rule_id):
    if not g.current_user or g.current_user['role_code'] != 'SUPER_ADMIN':
        return jsonify({'ok': False}), 403
    with get_cursor(commit=True) as cur:
        cur.execute("UPDATE notifications.reminder_rules SET is_active = NOT is_active WHERE id = %s", (rule_id,))
    flash('Rule toggled.', 'success')
    return redirect(url_for('admin.reminders'), code=303)
