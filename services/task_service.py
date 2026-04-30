"""Task Management service — user-initiated task CRUD + comments + templates.

Layered on top of the existing `task_inbox_service` (low-level CRUD) and
`notification_service` (rendering + dispatch). Adds:

  · User-initiated creation with assignee picker + assigner audit (`created_by`)
  · Rich list filters: status, priority, category, due, keyword, sort, scope
  · Dept-scoped visibility guard for non-admin roles
  · Comments with @mention parsing + in-app notifications
  · Template library → bulk task spawning (onboarding / offboarding / IPCR / SALN)
  · Summary stats feeding dashboard KPI cards

Closes the 10 High-priority Task Management gaps from Sheet #9 of the
LGU Gap Analysis.
"""
from __future__ import annotations

import re
from datetime import date as Date, timedelta
from services.db import get_cursor


ADMIN_ROLES = ('SUPER_ADMIN', 'HR_ADMIN')
MANAGER_ROLES = ADMIN_ROLES + ('EXECUTIVE', 'MANAGER')

VALID_CATEGORIES = ('WORK', 'FOLLOWUP', 'MEETING', 'DOC_REVIEW',
                     'ONBOARDING', 'OFFBOARDING', 'PERSONAL', 'SYSTEM')
VALID_PRIORITIES = ('URGENT', 'HIGH', 'NORMAL', 'LOW')
MENTION_REGEX = re.compile(r'@([a-zA-Z][a-zA-Z0-9._-]{1,60})')


# ══════════════════════════════════════════════════════════════════════
# Small helpers
# ══════════════════════════════════════════════════════════════════════
def _current_user_employee_id(cur, user_id):
    cur.execute("SELECT employee_id FROM core.users WHERE id = %s", (user_id,))
    row = cur.fetchone()
    return (row or {}).get('employee_id')


def _current_user_department(cur, user_id):
    cur.execute("""
        SELECT e.department_id
          FROM core.users u
          JOIN core.employees e ON e.id = u.employee_id
         WHERE u.id = %s
    """, (user_id,))
    row = cur.fetchone()
    return (row or {}).get('department_id')


def _apply_scope_filter(sql, params, viewer_user_id, viewer_role, mode='inbox'):
    """Append scope conditions for non-admin roles.

    Modes:
      · inbox  — only tasks assigned to viewer or created by viewer
      · team   — tasks assigned to users in viewer's department (MANAGER+)
      · admin  — unrestricted (HR_ADMIN / SUPER_ADMIN)
    """
    if mode == 'admin' and viewer_role in ADMIN_ROLES:
        return sql, params

    if mode == 'team' and viewer_role in MANAGER_ROLES:
        # Tasks assigned to employees in the same department as the viewer
        sql += """ AND EXISTS (
                     SELECT 1 FROM core.employees e2
                       JOIN core.users u2 ON u2.employee_id = e2.id
                      WHERE e2.id = t.employee_id
                        AND e2.department_id = (
                            SELECT e3.department_id FROM core.employees e3
                              JOIN core.users u3 ON u3.employee_id = e3.id
                             WHERE u3.id = %s))"""
        params.append(viewer_user_id)
        return sql, params

    # Default 'inbox' or any non-admin → own tasks only (assignee OR creator)
    sql += """ AND (t.created_by = %s
                OR t.user_id = %s
                OR t.employee_id = (SELECT employee_id FROM core.users WHERE id = %s))"""
    params.extend([viewer_user_id, viewer_user_id, viewer_user_id])
    return sql, params


# ══════════════════════════════════════════════════════════════════════
# Create
# ══════════════════════════════════════════════════════════════════════
def create_task(data, user_id, role_code=None):
    """User-initiated task creation. Returns dict with new row.

    Rules:
      · `employee_id` defaults to the creator's employee record if not given
      · Non-admin roles can only assign to themselves or a teammate in the
        same department (checked against core.employees.department_id)
      · `created_by` is always set to `user_id`
      · If `assignee` ≠ `creator`, fires `TASK_ASSIGNED` notification
    """
    from services import notification_service, task_inbox_service

    title = (data.get('title') or '').strip()
    if not title:
        raise ValueError('Task title is required')

    category = data.get('task_category') or 'WORK'
    if category not in VALID_CATEGORIES:
        category = 'WORK'
    priority = data.get('priority') or 'NORMAL'
    if priority not in VALID_PRIORITIES:
        priority = 'NORMAL'

    task_type = data.get('task_type') or 'PERSONAL'

    with get_cursor(commit=True) as cur:
        creator_emp_id = _current_user_employee_id(cur, user_id)

        # Resolve assignee — either employee_id directly or default to self
        assignee_emp_id = data.get('employee_id')
        if assignee_emp_id:
            assignee_emp_id = int(assignee_emp_id)
        else:
            assignee_emp_id = creator_emp_id

        # Scope check — non-admin must be assigning to self or same-dept teammate
        if assignee_emp_id != creator_emp_id and role_code not in ADMIN_ROLES:
            cur.execute("""
                SELECT department_id FROM core.employees WHERE id = %s
            """, (assignee_emp_id,))
            a_row = cur.fetchone()
            creator_dept = _current_user_department(cur, user_id)
            if not a_row or a_row['department_id'] != creator_dept:
                raise PermissionError(
                    'Cannot assign tasks to employees outside your department')

        # Resolve assignee's user_id (for notifications)
        cur.execute("SELECT id FROM core.users WHERE employee_id = %s LIMIT 1",
                    (assignee_emp_id,))
        a_user = cur.fetchone()
        assignee_user_id = (a_user or {}).get('id')

        due_date = data.get('due_date') or None
        description = data.get('description') or None
        action_url = data.get('action_url') or None

        cur.execute("""
            INSERT INTO core.task_inbox
                (employee_id, user_id, task_type, title, description, action_url,
                 priority, due_date, status, is_read,
                 created_by, task_category, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'PENDING', FALSE,
                    %s, %s, NOW(), NOW())
            RETURNING id, employee_id, user_id, title, priority, due_date, status
        """, (assignee_emp_id, assignee_user_id, task_type, title, description, action_url,
              priority, due_date, user_id, category))
        row = cur.fetchone()
        task_id = row['id']

    # Fire assignment notification if assigning to someone else
    if assignee_user_id and assignee_user_id != user_id:
        try:
            cur_uid = user_id
            with get_cursor() as cur:
                cur.execute("SELECT display_name FROM core.users WHERE id = %s",
                            (user_id,))
                a_name = (cur.fetchone() or {}).get('display_name') or 'A colleague'
            notification_service.notify(
                user_id=assignee_user_id,
                event_type='TASK_ASSIGNED',
                payload={
                    'title': title,
                    'assigner_name': a_name,
                    'due_date': str(due_date) if due_date else 'no date',
                    'priority': priority,
                },
            )
            notification_service.push_in_app(
                user_id=assignee_user_id,
                title=f'New task: {title}',
                body=f'{a_name} assigned you a task. Priority: {priority}.',
                action_url=f'/tasks/{task_id}',
            )
        except Exception:
            pass  # don't fail the whole create on notification errors

    return dict(row)


# ══════════════════════════════════════════════════════════════════════
# List / filter / search / sort
# ══════════════════════════════════════════════════════════════════════
def list_tasks(viewer_user_id, viewer_role=None, mode='inbox', filters=None):
    """Unified lister with filters.

    filters keys:
      status, priority, category, task_type, due (overdue|today|this_week|no_date),
      q (keyword in title/description), assigner_id, assignee_employee_id,
      sort (due_asc|due_desc|priority|created_desc|created_asc)
    """
    filters = filters or {}

    sql = """
        SELECT t.*,
               COALESCE(ae.first_name || ' ' || ae.last_name,
                        au.display_name, '') AS assignee_name,
               d.name  AS assignee_department,
               COALESCE(cu.display_name, '') AS assigner_name,
               CASE WHEN t.due_date IS NOT NULL
                         AND t.due_date < CURRENT_DATE
                         AND t.status NOT IN ('COMPLETED','DISMISSED')
                    THEN TRUE ELSE FALSE END AS is_overdue
          FROM core.task_inbox t
          LEFT JOIN core.employees ae    ON ae.id = t.employee_id
          LEFT JOIN core.users au        ON au.id = t.user_id
          LEFT JOIN core.users cu        ON cu.id = t.created_by
          LEFT JOIN core.departments d   ON d.id = ae.department_id
         WHERE 1=1
    """
    params = []

    if filters.get('status'):
        sql += ' AND t.status = %s'; params.append(filters['status'])
    if filters.get('priority'):
        sql += ' AND t.priority = %s'; params.append(filters['priority'])
    if filters.get('category'):
        sql += ' AND COALESCE(t.task_category, \'WORK\') = %s'
        params.append(filters['category'])
    if filters.get('task_type'):
        sql += ' AND t.task_type = %s'; params.append(filters['task_type'])

    due = filters.get('due')
    if due == 'overdue':
        sql += " AND t.due_date < CURRENT_DATE AND t.status NOT IN ('COMPLETED','DISMISSED')"
    elif due == 'today':
        sql += ' AND t.due_date = CURRENT_DATE'
    elif due == 'this_week':
        sql += " AND t.due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'"
    elif due == 'no_date':
        sql += ' AND t.due_date IS NULL'

    if filters.get('q'):
        sql += ' AND (t.title ILIKE %s OR t.description ILIKE %s)'
        like = f"%{filters['q']}%"
        params.extend([like, like])

    if filters.get('assigner_id'):
        sql += ' AND t.created_by = %s'; params.append(int(filters['assigner_id']))
    if filters.get('assignee_employee_id'):
        sql += ' AND t.employee_id = %s'
        params.append(int(filters['assignee_employee_id']))

    sql, params = _apply_scope_filter(sql, params, viewer_user_id, viewer_role, mode=mode)

    sort = filters.get('sort') or 'created_desc'
    sort_map = {
        'due_asc':       ' ORDER BY t.due_date ASC NULLS LAST, t.created_at DESC',
        'due_desc':      ' ORDER BY t.due_date DESC NULLS LAST, t.created_at DESC',
        'priority':      " ORDER BY CASE t.priority WHEN 'URGENT' THEN 0 WHEN 'HIGH' THEN 1 WHEN 'NORMAL' THEN 2 ELSE 3 END, t.created_at DESC",
        'created_asc':   ' ORDER BY t.created_at ASC',
        'created_desc':  ' ORDER BY t.created_at DESC',
    }
    sql += sort_map.get(sort, sort_map['created_desc'])
    sql += ' LIMIT 500'

    with get_cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchall()


# ══════════════════════════════════════════════════════════════════════
# Detail / permission guard
# ══════════════════════════════════════════════════════════════════════
def get_task(task_id, viewer_user_id, viewer_role=None):
    """Fetch task + author/assignee meta + comments. Returns None if not allowed."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT t.*,
                   COALESCE(ae.first_name || ' ' || ae.last_name,
                            au.display_name, '') AS assignee_name,
                   ae.department_id AS assignee_department_id,
                   d.name  AS assignee_department,
                   COALESCE(cu.display_name, '') AS assigner_name,
                   t.created_by AS assigner_user_id,
                   au.id AS assignee_user_id,
                   CASE WHEN t.due_date IS NOT NULL
                             AND t.due_date < CURRENT_DATE
                             AND t.status NOT IN ('COMPLETED','DISMISSED')
                        THEN TRUE ELSE FALSE END AS is_overdue
              FROM core.task_inbox t
              LEFT JOIN core.employees ae   ON ae.id = t.employee_id
              LEFT JOIN core.users au       ON au.id = t.user_id
              LEFT JOIN core.users cu       ON cu.id = t.created_by
              LEFT JOIN core.departments d  ON d.id = ae.department_id
             WHERE t.id = %s
        """, (task_id,))
        task = cur.fetchone()
        if not task:
            return None

        # Permission gate
        if viewer_role not in ADMIN_ROLES:
            cur.execute("SELECT employee_id, department_id FROM core.users u "
                        "LEFT JOIN core.employees e ON e.id = u.employee_id "
                        "WHERE u.id = %s", (viewer_user_id,))
            me = cur.fetchone() or {}
            is_assignee  = me.get('employee_id') == task['employee_id']
            is_assigner  = task['created_by'] == viewer_user_id
            is_team_mgr  = (viewer_role in ('MANAGER', 'EXECUTIVE')
                            and me.get('department_id') == task.get('assignee_department_id'))
            if not (is_assignee or is_assigner or is_team_mgr):
                return None  # 403 in the route

        # Comments
        cur.execute("""
            SELECT c.id, c.body, c.created_at, c.edited_at, c.mentioned_user_ids,
                   u.id AS user_id, u.display_name AS author_name
              FROM core.task_comments c
              JOIN core.users u ON u.id = c.user_id
             WHERE c.task_id = %s
             ORDER BY c.created_at ASC
        """, (task_id,))
        comments = cur.fetchall()

    task = dict(task)
    task['comments'] = comments
    return task


# ══════════════════════════════════════════════════════════════════════
# Edit
# ══════════════════════════════════════════════════════════════════════
def update_task(task_id, data, user_id, role_code=None):
    """In-place edit of title/description/priority/due_date/category.
    Assignee can self-edit; assigner can edit; admins can edit anything."""
    with get_cursor(commit=True) as cur:
        cur.execute("SELECT * FROM core.task_inbox WHERE id = %s", (task_id,))
        t = cur.fetchone()
        if not t:
            return None
        cur.execute("SELECT employee_id FROM core.users WHERE id = %s", (user_id,))
        me = cur.fetchone() or {}
        allowed = (role_code in ADMIN_ROLES
                    or t['created_by'] == user_id
                    or t['employee_id'] == me.get('employee_id'))
        if not allowed:
            raise PermissionError('Not allowed to edit this task')

        fields = {}
        for k in ('title', 'description', 'action_url'):
            if k in data:
                fields[k] = data[k]
        if data.get('priority') in VALID_PRIORITIES:
            fields['priority'] = data['priority']
        if data.get('task_category') in VALID_CATEGORIES:
            fields['task_category'] = data['task_category']
        if 'due_date' in data:
            fields['due_date'] = data['due_date'] or None
        if not fields:
            return t

        set_clause = ', '.join(f'{k} = %s' for k in fields) + ', updated_at = NOW()'
        cur.execute(
            f"UPDATE core.task_inbox SET {set_clause} WHERE id = %s RETURNING *",
            list(fields.values()) + [task_id],
        )
        return cur.fetchone()


# ══════════════════════════════════════════════════════════════════════
# Transitions
# ══════════════════════════════════════════════════════════════════════
def complete_task(task_id, user_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.task_inbox
               SET status = 'COMPLETED', completed_at = NOW(), updated_at = NOW()
             WHERE id = %s
        """, (task_id,))


def dismiss_task(task_id, user_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.task_inbox
               SET status = 'DISMISSED', completed_at = NOW(), updated_at = NOW()
             WHERE id = %s
        """, (task_id,))


def reopen_task(task_id, user_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.task_inbox
               SET status = 'PENDING', completed_at = NULL, updated_at = NOW()
             WHERE id = %s
        """, (task_id,))


# ══════════════════════════════════════════════════════════════════════
# Comments + @mentions
# ══════════════════════════════════════════════════════════════════════
def add_comment(task_id, user_id, body):
    """Insert a comment with parsed @mentions. Fires notifications.
    Returns {id, body, mentioned_user_ids, created_at, author_name}."""
    from services import notification_service

    body = (body or '').strip()
    if not body:
        raise ValueError('Comment body cannot be empty')

    # Parse @mentions against core.users.username
    tokens = set(m.group(1).lower() for m in MENTION_REGEX.finditer(body))
    mentioned_ids = []
    if tokens:
        with get_cursor() as cur:
            cur.execute("""
                SELECT id, username FROM core.users
                 WHERE LOWER(username) = ANY(%s) AND is_active = TRUE
            """, (list(tokens),))
            mentioned_ids = [r['id'] for r in cur.fetchall()]

    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO core.task_comments (task_id, user_id, body, mentioned_user_ids)
            VALUES (%s, %s, %s, %s)
            RETURNING id, body, created_at, mentioned_user_ids
        """, (task_id, user_id, body, mentioned_ids))
        comment = cur.fetchone()
        cur.execute("SELECT display_name FROM core.users WHERE id = %s", (user_id,))
        commenter = (cur.fetchone() or {}).get('display_name') or 'Someone'

        # Grab task + all recipients (assignee, assigner) minus commenter
        cur.execute("""
            SELECT t.title, t.user_id AS assignee_user_id, t.created_by AS assigner_user_id
              FROM core.task_inbox t
             WHERE t.id = %s
        """, (task_id,))
        t = cur.fetchone() or {}

    recipients = set()
    for uid in (t.get('assignee_user_id'), t.get('assigner_user_id')):
        if uid and uid != user_id:
            recipients.add(uid)

    payload = {
        'title': t.get('title') or 'Task',
        'commenter_name': commenter,
        'excerpt': body[:120] + ('…' if len(body) > 120 else ''),
    }
    # Comment notification to assignee + assigner
    for uid in recipients:
        try:
            notification_service.notify(uid, 'TASK_COMMENTED', payload)
            notification_service.push_in_app(
                user_id=uid,
                title=f'New comment on: {payload["title"]}',
                body=f'{commenter}: {payload["excerpt"]}',
                action_url=f'/tasks/{task_id}',
            )
        except Exception:
            pass
    # Mention notification to each tagged user (skip if already in recipients)
    for uid in mentioned_ids:
        if uid == user_id:
            continue
        try:
            notification_service.notify(uid, 'TASK_MENTIONED', payload)
            if uid not in recipients:
                notification_service.push_in_app(
                    user_id=uid,
                    title=f'You were mentioned: {payload["title"]}',
                    body=f'{commenter}: {payload["excerpt"]}',
                    action_url=f'/tasks/{task_id}',
                )
        except Exception:
            pass

    comment = dict(comment)
    comment['author_name'] = commenter
    return comment


# ══════════════════════════════════════════════════════════════════════
# Templates
# ══════════════════════════════════════════════════════════════════════
def list_templates(active_only=True):
    sql = 'SELECT * FROM core.task_templates'
    if active_only:
        sql += ' WHERE is_active = TRUE'
    sql += ' ORDER BY sort_order, title'
    with get_cursor() as cur:
        cur.execute(sql)
        return cur.fetchall()


def get_template(code):
    with get_cursor() as cur:
        cur.execute("SELECT * FROM core.task_templates WHERE code = %s", (code,))
        return cur.fetchone()


def spawn_from_template(template_code, target_employee_ids, user_id, start_date=None):
    """Create one task per checklist item, per target employee.
    `start_date` anchors offset_days (defaults to today)."""
    template = get_template(template_code)
    if not template:
        raise ValueError(f'Unknown template: {template_code}')

    start = start_date or Date.today()
    if isinstance(start, str):
        from datetime import datetime
        start = datetime.strptime(start, '%Y-%m-%d').date()

    checklist = template.get('checklist') or []
    import json
    if isinstance(checklist, str):
        checklist = json.loads(checklist)

    category = template.get('category') or 'WORK'
    task_type = f'TEMPLATE:{template_code}'
    created = []

    if not isinstance(target_employee_ids, (list, tuple)):
        target_employee_ids = [target_employee_ids]

    with get_cursor(commit=True) as cur:
        for emp_id in target_employee_ids:
            cur.execute("SELECT id FROM core.users WHERE employee_id = %s LIMIT 1",
                        (emp_id,))
            u = cur.fetchone()
            assignee_user_id = (u or {}).get('id')

            for item in checklist:
                offset = int(item.get('offset_days') or 0)
                due = start + timedelta(days=offset)
                priority = item.get('priority') or template.get('default_priority') or 'NORMAL'
                cur.execute("""
                    INSERT INTO core.task_inbox
                        (employee_id, user_id, task_type, title, description,
                         priority, due_date, status, is_read,
                         created_by, task_category, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, 'PENDING', FALSE,
                            %s, %s, NOW(), NOW())
                    RETURNING id
                """, (emp_id, assignee_user_id, task_type,
                      item.get('title'), item.get('description'),
                      priority, due, user_id, category))
                created.append(cur.fetchone()['id'])

    return created


# ══════════════════════════════════════════════════════════════════════
# Employee picker (autocomplete)
# ══════════════════════════════════════════════════════════════════════
def search_employees(query, current_user_id, role_code=None, limit=20):
    """Autocomplete for the assignee picker.
    Non-admin roles restricted to same department."""
    query = (query or '').strip()
    if len(query) < 1:
        return []

    like = f'%{query}%'
    sql = """
        SELECT e.id, e.employee_no,
               TRIM(e.first_name || ' ' || COALESCE(e.middle_name || ' ', '') || e.last_name) AS name,
               d.name AS department, e.work_email
          FROM core.employees e
          LEFT JOIN core.departments d ON d.id = e.department_id
         WHERE e.is_active = TRUE
           AND (e.first_name ILIKE %s
                OR e.last_name ILIKE %s
                OR e.first_name || ' ' || e.last_name ILIKE %s
                OR e.employee_no ILIKE %s
                OR e.work_email ILIKE %s)
    """
    params = [like, like, like, like, like]
    if role_code not in ADMIN_ROLES:
        sql += """ AND e.department_id = (
                     SELECT e2.department_id FROM core.employees e2
                       JOIN core.users u ON u.employee_id = e2.id
                      WHERE u.id = %s)"""
        params.append(current_user_id)
    sql += ' ORDER BY e.last_name, e.first_name LIMIT %s'
    params.append(limit)

    with get_cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchall()


# ══════════════════════════════════════════════════════════════════════
# Summary stats
# ══════════════════════════════════════════════════════════════════════
def get_summary_stats(viewer_user_id, viewer_role=None, mode='inbox'):
    """Returns { open, overdue, completed_ytd, avg_completion_days } scoped."""
    base = """
        SELECT
          COUNT(*) FILTER (WHERE t.status IN ('PENDING','IN_PROGRESS')) AS open_count,
          COUNT(*) FILTER (WHERE t.status NOT IN ('COMPLETED','DISMISSED')
                             AND t.due_date < CURRENT_DATE) AS overdue,
          COUNT(*) FILTER (WHERE t.status = 'COMPLETED'
                             AND t.completed_at >= date_trunc('year', CURRENT_DATE)) AS completed_ytd,
          ROUND(AVG(EXTRACT(EPOCH FROM (t.completed_at - t.created_at))/86400)
                 FILTER (WHERE t.status = 'COMPLETED'
                           AND t.completed_at >= date_trunc('year', CURRENT_DATE)))::int
                 AS avg_days
          FROM core.task_inbox t
         WHERE 1=1
    """
    params = []
    base, params = _apply_scope_filter(base, params, viewer_user_id, viewer_role, mode=mode)
    with get_cursor() as cur:
        cur.execute(base, params)
        r = cur.fetchone() or {}
    return {
        'open':             r.get('open_count') or 0,
        'overdue':          r.get('overdue') or 0,
        'completed_ytd':    r.get('completed_ytd') or 0,
        'avg_completion_days': r.get('avg_days'),
    }


def render_mentions_html(body, mentioned_user_ids):
    """Render @mention tokens as highlighted spans for display."""
    if not body:
        return ''
    usernames = {}
    if mentioned_user_ids:
        with get_cursor() as cur:
            cur.execute("SELECT id, username, display_name FROM core.users WHERE id = ANY(%s)",
                        (list(mentioned_user_ids),))
            for r in cur.fetchall():
                usernames[r['username'].lower()] = r['display_name'] or r['username']

    def repl(m):
        u = m.group(1).lower()
        if u in usernames:
            return f'<span class="mention" title="{usernames[u]}">@{m.group(1)}</span>'
        return m.group(0)
    import html as _html
    safe = _html.escape(body)
    return MENTION_REGEX.sub(repl, safe)
