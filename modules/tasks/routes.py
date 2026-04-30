"""Task Management blueprint — user-initiated tasks, team view, admin view,
comments, @mentions, and template-based bulk creation."""
from flask import (Blueprint, render_template, request, redirect, url_for,
                   flash, session, jsonify, g, abort)
from functools import wraps

from services import task_service as ts
from services.db import get_cursor


tasks_bp = Blueprint('tasks', __name__)


# ── Helpers ──────────────────────────────────────────────────────────
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
            role = session.get('role_code')
            if role not in roles:
                flash('Access denied — insufficient role.', 'error')
                return redirect(url_for('ess_mss.me_inbox'))
            return f(*a, **kw)
        return wrapper
    return decorator


def _current_role():
    return session.get('role_code')


def _current_user_id():
    return session.get('user_id')


# ══════════════════════════════════════════════════════════════════════
# List views (personal / team / admin)
# ══════════════════════════════════════════════════════════════════════
@tasks_bp.route('/tasks/')
@_login_required
def my_tasks():
    uid = _current_user_id()
    role = _current_role()
    filters = {k: request.args.get(k) for k in
               ('status', 'priority', 'category', 'task_type', 'due', 'q', 'sort')
               if request.args.get(k)}
    tasks = ts.list_tasks(uid, role, mode='inbox', filters=filters)
    stats = ts.get_summary_stats(uid, role, mode='inbox')
    return render_template('tasks/list.html',
                           tasks=tasks, filters=filters, stats=stats,
                           view='my', title='My Tasks')


@tasks_bp.route('/tasks/team')
@_login_required
@_require_role(('SUPER_ADMIN', 'HR_ADMIN', 'EXECUTIVE', 'MANAGER'))
def team_tasks():
    uid = _current_user_id()
    role = _current_role()
    filters = {k: request.args.get(k) for k in
               ('status', 'priority', 'category', 'task_type', 'due', 'q', 'sort')
               if request.args.get(k)}
    tasks = ts.list_tasks(uid, role, mode='team', filters=filters)
    stats = ts.get_summary_stats(uid, role, mode='team')
    return render_template('tasks/list.html',
                           tasks=tasks, filters=filters, stats=stats,
                           view='team', title='Team Tasks')


@tasks_bp.route('/admin/tasks')
@_login_required
@_require_role(('SUPER_ADMIN', 'HR_ADMIN'))
def admin_tasks():
    uid = _current_user_id()
    role = _current_role()
    filters = {k: request.args.get(k) for k in
               ('status', 'priority', 'category', 'task_type', 'due', 'q', 'sort',
                'assigner_id', 'assignee_employee_id')
               if request.args.get(k)}
    tasks = ts.list_tasks(uid, role, mode='admin', filters=filters)
    stats = ts.get_summary_stats(uid, role, mode='admin')
    return render_template('tasks/list.html',
                           tasks=tasks, filters=filters, stats=stats,
                           view='admin', title='All Tasks')


# ══════════════════════════════════════════════════════════════════════
# Create
# ══════════════════════════════════════════════════════════════════════
@tasks_bp.route('/tasks/new', methods=['GET', 'POST'])
@_login_required
def new_task():
    uid = _current_user_id()
    role = _current_role()

    if request.method == 'POST':
        try:
            row = ts.create_task({
                'title':         request.form.get('title'),
                'description':   request.form.get('description'),
                'employee_id':   request.form.get('assignee_employee_id') or None,
                'priority':      request.form.get('priority'),
                'task_category': request.form.get('task_category'),
                'due_date':      request.form.get('due_date') or None,
                'task_type':     request.form.get('task_type') or 'PERSONAL',
            }, uid, role)
            flash(f'Task "{row["title"]}" created.', 'success')
            return redirect(url_for('tasks.task_detail', task_id=row['id']))
        except (ValueError, PermissionError) as e:
            flash(str(e), 'error')

    # GET or failed POST — show form
    template_code = request.args.get('template')
    preset = {}
    if template_code:
        tpl = ts.get_template(template_code)
        if tpl:
            preset = {
                'title': tpl['title'],
                'description': tpl['description'],
                'priority': tpl.get('default_priority') or 'NORMAL',
                'task_category': tpl.get('category') or 'WORK',
            }
    # Default assignee: self
    with get_cursor() as cur:
        cur.execute("""
            SELECT e.id, e.first_name || ' ' || e.last_name AS name,
                   e.employee_no, d.name AS department
              FROM core.users u
              LEFT JOIN core.employees e ON e.id = u.employee_id
              LEFT JOIN core.departments d ON d.id = e.department_id
             WHERE u.id = %s
        """, (uid,))
        me = cur.fetchone()
    return render_template('tasks/new.html', preset=preset, me=me)


# ══════════════════════════════════════════════════════════════════════
# Detail + state transitions + comments
# ══════════════════════════════════════════════════════════════════════
@tasks_bp.route('/tasks/<int:task_id>')
@_login_required
def task_detail(task_id):
    uid = _current_user_id()
    role = _current_role()
    task = ts.get_task(task_id, uid, role)
    if not task:
        abort(404)
    # Render comments with mention highlighting
    for c in task.get('comments', []):
        c['body_html'] = ts.render_mentions_html(c['body'], c.get('mentioned_user_ids'))
    return render_template('tasks/view.html', task=task)


@tasks_bp.route('/tasks/<int:task_id>/edit', methods=['POST'])
@_login_required
def task_edit(task_id):
    uid = _current_user_id()
    role = _current_role()
    try:
        data = request.get_json(silent=True) or request.form.to_dict()
        row = ts.update_task(task_id, data, uid, role)
        if not row:
            return jsonify({'ok': False, 'message': 'Task not found'}), 404
        return jsonify({'ok': True, 'task': dict(row)})
    except PermissionError as e:
        return jsonify({'ok': False, 'message': str(e)}), 403
    except ValueError as e:
        return jsonify({'ok': False, 'message': str(e)}), 400


@tasks_bp.route('/tasks/<int:task_id>/complete', methods=['POST'])
@_login_required
def task_complete(task_id):
    ts.complete_task(task_id, _current_user_id())
    if request.is_json or request.headers.get('Accept', '').startswith('application/json'):
        return jsonify({'ok': True})
    flash('Task completed.', 'success')
    return redirect(request.referrer or url_for('tasks.my_tasks'))


@tasks_bp.route('/tasks/<int:task_id>/dismiss', methods=['POST'])
@_login_required
def task_dismiss(task_id):
    ts.dismiss_task(task_id, _current_user_id())
    if request.is_json or request.headers.get('Accept', '').startswith('application/json'):
        return jsonify({'ok': True})
    flash('Task dismissed.', 'success')
    return redirect(request.referrer or url_for('tasks.my_tasks'))


@tasks_bp.route('/tasks/<int:task_id>/reopen', methods=['POST'])
@_login_required
def task_reopen(task_id):
    ts.reopen_task(task_id, _current_user_id())
    if request.is_json or request.headers.get('Accept', '').startswith('application/json'):
        return jsonify({'ok': True})
    flash('Task reopened.', 'success')
    return redirect(request.referrer or url_for('tasks.task_detail', task_id=task_id))


@tasks_bp.route('/tasks/<int:task_id>/comments', methods=['POST'])
@_login_required
def task_add_comment(task_id):
    uid = _current_user_id()
    try:
        payload = request.get_json(silent=True) or {}
        body = payload.get('body') or request.form.get('body')
        c = ts.add_comment(task_id, uid, body)
        c['body_html'] = ts.render_mentions_html(c['body'], c.get('mentioned_user_ids'))
        # psycopg2 datetimes → str
        if c.get('created_at'):
            c['created_at'] = c['created_at'].isoformat()
        return jsonify({'ok': True, 'comment': c})
    except ValueError as e:
        return jsonify({'ok': False, 'message': str(e)}), 400


# ══════════════════════════════════════════════════════════════════════
# Templates (HR_ADMIN+)
# ══════════════════════════════════════════════════════════════════════
@tasks_bp.route('/admin/task-templates')
@_login_required
@_require_role(('SUPER_ADMIN', 'HR_ADMIN'))
def task_templates_list():
    templates = ts.list_templates()
    # Enrich with checklist length for the card
    out = []
    for t in templates:
        t = dict(t)
        checklist = t.get('checklist') or []
        import json
        if isinstance(checklist, str):
            checklist = json.loads(checklist)
        t['checklist_count'] = len(checklist)
        out.append(t)
    return render_template('tasks/templates_list.html', templates=out)


@tasks_bp.route('/admin/task-templates/<code>/spawn', methods=['POST'])
@_login_required
@_require_role(('SUPER_ADMIN', 'HR_ADMIN'))
def task_template_spawn(code):
    uid = _current_user_id()
    emp_ids_raw = request.form.getlist('target_employee_ids[]') or request.form.getlist('target_employee_ids')
    if not emp_ids_raw:
        single = request.form.get('target_employee_id')
        emp_ids_raw = [single] if single else []
    try:
        emp_ids = [int(x) for x in emp_ids_raw if x]
    except ValueError:
        flash('Invalid employee IDs.', 'error')
        return redirect(url_for('tasks.task_templates_list'))

    if not emp_ids:
        flash('Select at least one employee to spawn the template for.', 'error')
        return redirect(url_for('tasks.task_templates_list'))

    start_date = request.form.get('start_date') or None
    try:
        created = ts.spawn_from_template(code, emp_ids, uid, start_date=start_date)
        flash(f'Spawned {len(created)} task(s) from template "{code}" '
              f'for {len(emp_ids)} employee(s).', 'success')
    except ValueError as e:
        flash(str(e), 'error')
    return redirect(url_for('tasks.admin_tasks'))


# ══════════════════════════════════════════════════════════════════════
# Employee autocomplete API (shared with other modules)
# ══════════════════════════════════════════════════════════════════════
@tasks_bp.route('/api/employees/search')
@_login_required
def api_employees_search():
    q = request.args.get('q') or ''
    if len(q) < 1:
        return jsonify({'ok': True, 'employees': []})
    rows = ts.search_employees(q, _current_user_id(), _current_role(), limit=20)
    return jsonify({'ok': True, 'employees': [dict(r) for r in rows]})


@tasks_bp.route('/api/tasks/summary')
@_login_required
def api_tasks_summary():
    mode = request.args.get('mode', 'inbox')
    if mode not in ('inbox', 'team', 'admin'):
        mode = 'inbox'
    if mode == 'team' and _current_role() not in ('SUPER_ADMIN', 'HR_ADMIN', 'EXECUTIVE', 'MANAGER'):
        mode = 'inbox'
    if mode == 'admin' and _current_role() not in ('SUPER_ADMIN', 'HR_ADMIN'):
        mode = 'inbox'
    stats = ts.get_summary_stats(_current_user_id(), _current_role(), mode=mode)
    return jsonify({'ok': True, 'stats': stats})
