"""Task Inbox Service — unified pending actions across all modules."""
from services.db import get_cursor


def get_inbox(employee_id, user_id=None, status='PENDING'):
    """Get all pending inbox items for an employee."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM core.task_inbox
            WHERE (employee_id = %s OR user_id = %s)
              AND status = %s
            ORDER BY
                CASE priority WHEN 'URGENT' THEN 0 WHEN 'HIGH' THEN 1 WHEN 'NORMAL' THEN 2 ELSE 3 END,
                due_date NULLS LAST,
                created_at DESC
        """, (employee_id, user_id, status))
        return cur.fetchall()


def get_inbox_count(employee_id, user_id=None):
    with get_cursor() as cur:
        cur.execute("""
            SELECT COUNT(*) AS total,
                   COUNT(*) FILTER (WHERE NOT is_read) AS unread,
                   COUNT(*) FILTER (WHERE priority IN ('HIGH','URGENT')) AS urgent
            FROM core.task_inbox
            WHERE (employee_id = %s OR user_id = %s) AND status = 'PENDING'
        """, (employee_id, user_id))
        return cur.fetchone()


def create_task(employee_id, task_type, title, description=None, action_url=None,
                priority='NORMAL', due_date=None, user_id=None, source_table=None, source_id=None,
                created_by=None, task_category=None):
    """Insert a task into core.task_inbox.

    `created_by` and `task_category` are populated when known; they enable
    the Task Management feature (assigner audit, category-based filters).
    When `created_by` differs from the assignee's `user_id`, a TASK_ASSIGNED
    notification is fired automatically.
    """
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO core.task_inbox
                (employee_id, user_id, task_type, title, description, action_url,
                 priority, due_date, source_table, source_id,
                 created_by, task_category, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                    %s, COALESCE(%s, 'SYSTEM'), NOW(), NOW())
            RETURNING id
        """, (employee_id, user_id, task_type, title, description, action_url,
              priority, due_date, source_table, source_id,
              created_by, task_category))
        task_id = cur.fetchone()['id']

    # Fire TASK_ASSIGNED notification when a human assigner delegated to someone else
    if created_by and user_id and created_by != user_id:
        try:
            from services import notification_service
            with get_cursor() as cur:
                cur.execute("SELECT display_name FROM core.users WHERE id = %s",
                            (created_by,))
                assigner = (cur.fetchone() or {}).get('display_name') or 'A colleague'
            notification_service.notify(
                user_id=user_id,
                event_type='TASK_ASSIGNED',
                payload={
                    'title': title,
                    'assigner_name': assigner,
                    'due_date': str(due_date) if due_date else 'no date',
                    'priority': priority,
                },
            )
            notification_service.push_in_app(
                user_id=user_id,
                title=f'New task: {title}',
                body=f'{assigner} assigned you a task. Priority: {priority}.',
                action_url=action_url or f'/tasks/{task_id}',
            )
        except Exception:
            pass  # Don't fail the insert on notification errors

    return task_id


def complete_task(task_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.task_inbox SET status = 'COMPLETED', completed_at = NOW() WHERE id = %s
        """, (task_id,))


def dismiss_task(task_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.task_inbox SET status = 'DISMISSED', completed_at = NOW() WHERE id = %s
        """, (task_id,))


def mark_read(task_id):
    with get_cursor(commit=True) as cur:
        cur.execute("UPDATE core.task_inbox SET is_read = TRUE WHERE id = %s", (task_id,))


def mark_all_read(employee_id, user_id=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.task_inbox SET is_read = TRUE
            WHERE (employee_id = %s OR user_id = %s) AND status = 'PENDING' AND NOT is_read
        """, (employee_id, user_id))


def refresh_inbox(employee_id, user_id=None):
    """Scan all modules + reminder engine for pending actions for this employee."""
    # Fire the reminder engine (evaluates all active rules for this employee)
    try:
        from services.reminder_engine import fire_reminders_for_employee
        fire_reminders_for_employee(employee_id, user_id)
    except Exception:
        pass  # Graceful fallback if reminder engine has issues

    # Legacy direct scans (kept as fallback for items not covered by rules)
    try:
      with get_cursor(commit=True) as cur:
        # Onboarding requirements not submitted (submitted_at IS NULL = pending)
        cur.execute("""
            INSERT INTO core.task_inbox (employee_id, task_type, title, description, action_url, priority, source_table, source_id)
            SELECT pr.employee_id, 'ONBOARDING',
                   'Submit: ' || REPLACE(pr.requirement_type, '_', ' '),
                   'Upload your ' || LOWER(REPLACE(pr.requirement_type, '_', ' ')) || ' document.',
                   '/me/onboarding',
                   CASE WHEN pr.requirement_type IN ('MEDICAL_CERT','NBI_CLEARANCE') THEN 'HIGH' ELSE 'NORMAL' END,
                   'onboarding.onb_pre_employment_reqs', pr.id
            FROM onboarding.onb_pre_employment_reqs pr
            WHERE pr.employee_id = %s AND pr.submitted_at IS NULL
              AND NOT EXISTS (
                  SELECT 1 FROM core.task_inbox ti
                  WHERE ti.source_table = 'onboarding.onb_pre_employment_reqs'
                    AND ti.source_id = pr.id AND ti.status = 'PENDING'
              )
        """, (employee_id,))

        # Onboarding welcome items not completed
        cur.execute("""
            INSERT INTO core.task_inbox (employee_id, task_type, title, description, action_url, priority, source_table, source_id)
            SELECT oc.employee_id, 'POLICY_ACK',
                   wi.title,
                   wi.description,
                   '/me/onboarding',
                   'NORMAL',
                   'onboarding.onb_welcome_items', wi.id
            FROM onboarding.onb_welcome_items wi
            JOIN onboarding.onb_checklists oc ON oc.id = wi.checklist_id
            WHERE oc.employee_id = %s AND NOT wi.is_completed
              AND wi.item_type IN ('POLICY_ACK', 'ORIENTATION')
              AND NOT EXISTS (
                  SELECT 1 FROM core.task_inbox ti
                  WHERE ti.source_table = 'onboarding.onb_welcome_items'
                    AND ti.source_id = wi.id AND ti.status = 'PENDING'
              )
        """, (employee_id,))

        # Attendance discrepancies (missing time-out)
        cur.execute("""
            INSERT INTO core.task_inbox (employee_id, task_type, title, description, action_url, priority, source_table, source_id)
            SELECT ad.employee_id, 'ATTENDANCE',
                   'Missing Time-Out: ' || ad.work_date::TEXT,
                   'Your DTR for ' || ad.work_date::TEXT || ' has no time-out recorded.',
                   '/me/attendance',
                   'HIGH',
                   'attendance.att_daily', ad.id
            FROM attendance.att_daily ad
            WHERE ad.employee_id = %s AND ad.time_in IS NOT NULL AND ad.time_out IS NULL
              AND ad.work_date >= CURRENT_DATE - INTERVAL '7 days'
              AND NOT EXISTS (
                  SELECT 1 FROM core.task_inbox ti
                  WHERE ti.source_table = 'attendance.att_daily'
                    AND ti.source_id = ad.id AND ti.status = 'PENDING'
              )
        """, (employee_id,))
    except Exception:
        pass  # Graceful fallback — don't crash /me if inbox scan fails
