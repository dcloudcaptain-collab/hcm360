"""Global employee picker — reusable across the HRIS.

Supports three selection modes:
  1. Individual — type-ahead search across active employees
  2. By Department — expand a department to all its active employees
  3. Custom Group — expand a user-defined cohort (core.employee_groups)

Also hosts the admin UI for managing employee groups.
"""
from functools import wraps

from flask import (Blueprint, render_template, request, redirect, url_for,
                   flash, session, jsonify, abort)

from services.db import get_cursor


picker_bp = Blueprint('employee_picker', __name__)


def _login_required(f):
    @wraps(f)
    def wrapper(*a, **kw):
        if not session.get('user_id'):
            return redirect(url_for('login'))
        return f(*a, **kw)
    return wrapper


def _require_role(roles):
    def decorator(f):
        @wraps(f)
        def wrapper(*a, **kw):
            if session.get('role_code') not in roles:
                if request.is_json:
                    return jsonify({'ok': False, 'message': 'Access denied'}), 403
                flash('Access denied — insufficient role.', 'error')
                return redirect(url_for('ess.me'))
            return f(*a, **kw)
        return wrapper
    return decorator


# ══════════════════════════════════════════════════════════════════════
# JSON APIs (used by the picker widget)
# ══════════════════════════════════════════════════════════════════════
@picker_bp.route('/api/departments')
@_login_required
def api_departments():
    """List active departments with live employee counts."""
    q = (request.args.get('q') or '').strip()
    like = f'%{q}%'
    sql = """
        SELECT d.id, d.name, d.code,
               (SELECT COUNT(*) FROM core.employees e
                  WHERE e.department_id = d.id
                    AND e.is_active = TRUE) AS headcount
          FROM core.departments d
         WHERE d.is_active = TRUE
    """
    params = []
    if q:
        sql += ' AND (d.name ILIKE %s OR d.code ILIKE %s)'
        params.extend([like, like])
    sql += ' ORDER BY d.name LIMIT 100'
    with get_cursor() as cur:
        cur.execute(sql, params)
        rows = cur.fetchall()
    return jsonify({'ok': True, 'departments': [dict(r) for r in rows]})


@picker_bp.route('/api/departments/<int:dept_id>/employees')
@_login_required
def api_department_employees(dept_id):
    """Return all active employees in a department."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT e.id, e.employee_no,
                   TRIM(e.first_name || ' ' || COALESCE(e.middle_name || ' ', '') || e.last_name) AS name,
                   e.work_email,
                   d.name AS department
              FROM core.employees e
              LEFT JOIN core.departments d ON d.id = e.department_id
             WHERE e.department_id = %s AND e.is_active = TRUE
             ORDER BY e.last_name, e.first_name
        """, (dept_id,))
        rows = cur.fetchall()
    return jsonify({'ok': True, 'employees': [dict(r) for r in rows]})


@picker_bp.route('/api/employee-groups')
@_login_required
def api_groups():
    """List groups visible to the current user.

    · PUBLIC   → everyone
    · DEPT     → same department as creator (or current user's dept)
    · PRIVATE  → creator only (+ SUPER_ADMIN)
    """
    uid = session.get('user_id')
    role = session.get('role_code')
    q = (request.args.get('q') or '').strip()
    like = f'%{q}%'

    sql = """
        SELECT g.id, g.code, g.name, g.description, g.visibility,
               g.department_id, d.name AS department,
               g.created_by, cu.display_name AS created_by_name,
               (SELECT COUNT(*) FROM core.employee_group_members m
                  WHERE m.group_id = g.id) AS member_count
          FROM core.employee_groups g
          LEFT JOIN core.departments d ON d.id = g.department_id
          LEFT JOIN core.users cu       ON cu.id = g.created_by
         WHERE g.is_active = TRUE
    """
    params = []
    if q:
        sql += ' AND (g.name ILIKE %s OR g.code ILIKE %s OR g.description ILIKE %s)'
        params.extend([like, like, like])

    # Visibility filter
    if role not in ('SUPER_ADMIN',):
        sql += """ AND (
            g.visibility = 'PUBLIC'
            OR g.created_by = %s
            OR (g.visibility = 'DEPT' AND g.department_id = (
                SELECT e.department_id FROM core.users u
                  JOIN core.employees e ON e.id = u.employee_id
                 WHERE u.id = %s))
        )"""
        params.extend([uid, uid])

    sql += ' ORDER BY g.name LIMIT 200'

    with get_cursor() as cur:
        cur.execute(sql, params)
        rows = cur.fetchall()
    return jsonify({'ok': True, 'groups': [dict(r) for r in rows]})


@picker_bp.route('/api/employee-groups/<int:group_id>/members')
@_login_required
def api_group_members(group_id):
    """Return all employees in the given group."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT e.id, e.employee_no,
                   TRIM(e.first_name || ' ' || COALESCE(e.middle_name || ' ', '') || e.last_name) AS name,
                   e.work_email,
                   d.name AS department
              FROM core.employee_group_members m
              JOIN core.employees e ON e.id = m.employee_id
              LEFT JOIN core.departments d ON d.id = e.department_id
             WHERE m.group_id = %s AND e.is_active = TRUE
             ORDER BY e.last_name, e.first_name
        """, (group_id,))
        rows = cur.fetchall()
    return jsonify({'ok': True, 'employees': [dict(r) for r in rows]})


# ══════════════════════════════════════════════════════════════════════
# Admin page + CRUD
# ══════════════════════════════════════════════════════════════════════
@picker_bp.route('/admin/employee-groups')
@_login_required
@_require_role(('SUPER_ADMIN', 'HR_ADMIN', 'MANAGER'))
def groups_list():
    uid = session.get('user_id')
    role = session.get('role_code')
    with get_cursor() as cur:
        sql = """
            SELECT g.id, g.code, g.name, g.description, g.visibility,
                   g.is_active, g.created_at,
                   COALESCE(cu.display_name, '') AS created_by_name,
                   d.name AS department,
                   (SELECT COUNT(*) FROM core.employee_group_members m
                     WHERE m.group_id = g.id) AS member_count
              FROM core.employee_groups g
              LEFT JOIN core.users cu ON cu.id = g.created_by
              LEFT JOIN core.departments d ON d.id = g.department_id
             WHERE 1=1
        """
        params = []
        if role not in ('SUPER_ADMIN',):
            sql += """ AND (
                g.visibility = 'PUBLIC'
                OR g.created_by = %s
                OR (g.visibility = 'DEPT' AND g.department_id = (
                    SELECT e.department_id FROM core.users u
                      JOIN core.employees e ON e.id = u.employee_id
                     WHERE u.id = %s))
            )"""
            params.extend([uid, uid])
        sql += ' ORDER BY g.is_active DESC, g.name'
        cur.execute(sql, params)
        groups = cur.fetchall()
    return render_template('employee_picker/groups_list.html', groups=groups)


@picker_bp.route('/admin/employee-groups/new', methods=['GET', 'POST'])
@_login_required
@_require_role(('SUPER_ADMIN', 'HR_ADMIN', 'MANAGER'))
def group_new():
    if request.method == 'POST':
        name = (request.form.get('name') or '').strip()
        if not name:
            flash('Group name is required.', 'error')
            return redirect(url_for('employee_picker.group_new'))

        code = (request.form.get('code') or '').strip().upper().replace(' ', '_') or None
        visibility = request.form.get('visibility', 'PUBLIC')
        if visibility not in ('PUBLIC', 'DEPT', 'PRIVATE'):
            visibility = 'PUBLIC'

        dept_id = request.form.get('department_id') or None
        try:
            dept_id = int(dept_id) if dept_id else None
        except ValueError:
            dept_id = None

        with get_cursor(commit=True) as cur:
            try:
                cur.execute("""
                    INSERT INTO core.employee_groups
                        (code, name, description, visibility, created_by, department_id)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING id
                """, (code, name, request.form.get('description') or None,
                      visibility, session.get('user_id'), dept_id))
                gid = cur.fetchone()['id']
            except Exception as e:
                flash(f'Could not create group: {e}', 'error')
                return redirect(url_for('employee_picker.group_new'))
        flash(f'Group "{name}" created.', 'success')
        return redirect(url_for('employee_picker.group_detail', group_id=gid))

    # GET
    with get_cursor() as cur:
        cur.execute("SELECT id, name FROM core.departments WHERE is_active ORDER BY name")
        departments = cur.fetchall()
    return render_template('employee_picker/group_new.html', departments=departments)


@picker_bp.route('/admin/employee-groups/<int:group_id>')
@_login_required
@_require_role(('SUPER_ADMIN', 'HR_ADMIN', 'MANAGER'))
def group_detail(group_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT g.*, d.name AS department,
                   COALESCE(cu.display_name, '') AS created_by_name
              FROM core.employee_groups g
              LEFT JOIN core.departments d ON d.id = g.department_id
              LEFT JOIN core.users cu ON cu.id = g.created_by
             WHERE g.id = %s
        """, (group_id,))
        group = cur.fetchone()
        if not group:
            abort(404)
        cur.execute("""
            SELECT e.id, e.employee_no,
                   TRIM(e.first_name || ' ' || COALESCE(e.middle_name || ' ', '') || e.last_name) AS name,
                   d.name AS department,
                   m.added_at,
                   COALESCE(au.display_name, '') AS added_by_name
              FROM core.employee_group_members m
              JOIN core.employees e ON e.id = m.employee_id
              LEFT JOIN core.departments d ON d.id = e.department_id
              LEFT JOIN core.users au ON au.id = m.added_by
             WHERE m.group_id = %s
             ORDER BY e.last_name, e.first_name
        """, (group_id,))
        members = cur.fetchall()
    return render_template('employee_picker/group_detail.html',
                           group=group, members=members)


@picker_bp.route('/admin/employee-groups/<int:group_id>/members/add', methods=['POST'])
@_login_required
@_require_role(('SUPER_ADMIN', 'HR_ADMIN', 'MANAGER'))
def group_add_members(group_id):
    """Accepts employee_ids[] via form or JSON; returns JSON."""
    uid = session.get('user_id')
    data = request.get_json(silent=True) or {}
    ids = data.get('employee_ids') or request.form.getlist('employee_ids[]') or request.form.getlist('employee_ids')
    try:
        ids = [int(x) for x in ids if x]
    except ValueError:
        return jsonify({'ok': False, 'message': 'Invalid employee IDs'}), 400
    if not ids:
        return jsonify({'ok': False, 'message': 'No employees selected'}), 400

    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO core.employee_group_members (group_id, employee_id, added_by)
            SELECT %s, unnest(%s::bigint[]), %s
            ON CONFLICT DO NOTHING
        """, (group_id, ids, uid))
        cur.execute("""
            SELECT COUNT(*) AS total FROM core.employee_group_members WHERE group_id = %s
        """, (group_id,))
        total = cur.fetchone()['total']
    return jsonify({'ok': True, 'added': len(ids), 'total': total})


@picker_bp.route('/admin/employee-groups/<int:group_id>/members/<int:employee_id>/remove',
                  methods=['POST'])
@_login_required
@_require_role(('SUPER_ADMIN', 'HR_ADMIN', 'MANAGER'))
def group_remove_member(group_id, employee_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            DELETE FROM core.employee_group_members
             WHERE group_id = %s AND employee_id = %s
        """, (group_id, employee_id))
    return jsonify({'ok': True})
