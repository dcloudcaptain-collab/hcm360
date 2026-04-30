"""
Reminder & Trigger Engine — evaluates rules, fires reminders, escalates overdue items.

Called by:
  - refresh_inbox() on every /me page load (lightweight per-employee scan)
  - /admin/reminders/run-all (HR manual trigger for all employees)
  - Could be wired to a cron endpoint in production
"""
from datetime import date, timedelta
from services.db import get_cursor
from services import notification_service as notif
from services import task_inbox_service as inbox


# -------------------------------------------------------------------------
# Built-in trigger queries (keyed by reminder rule code)
# These return rows with: employee_id, user_id, title, description,
#                          action_url, due_date, priority, source_key
# -------------------------------------------------------------------------

TRIGGER_QUERIES = {

    # ── COMPLIANCE ────────────────────────────────────────────────────
    'COMP_ONBOARDING_REQS': """
        SELECT pr.employee_id, u.id AS user_id,
               'Submit: ' || REPLACE(pr.requirement_type, '_', ' ') AS title,
               'Your pre-employment requirement (' || LOWER(REPLACE(pr.requirement_type, '_', ' '))
                   || ') is still pending. Please submit before your onboarding deadline.' AS description,
               '/me/onboarding' AS action_url,
               oc.target_date AS due_date,
               CASE WHEN oc.target_date <= CURRENT_DATE + INTERVAL '3 days' THEN 'URGENT'
                    WHEN oc.target_date <= CURRENT_DATE + INTERVAL '7 days' THEN 'HIGH' ELSE 'NORMAL' END AS priority,
               'onboarding.onb_pre_employment_reqs:' || pr.id AS source_key
        FROM onboarding.onb_pre_employment_reqs pr
        JOIN onboarding.onb_checklists oc ON oc.employee_id = pr.employee_id AND oc.type = 'ONBOARDING'
        LEFT JOIN core.users u ON u.employee_id = pr.employee_id
        WHERE pr.status IN ('PENDING', 'REJECTED')
    """,

    'COMP_BENEFITS_ENROLLMENT': """
        SELECT e.id AS employee_id, u.id AS user_id,
               'Open Enrollment: Review your benefits' AS title,
               'The open enrollment window closes on ' || ew.close_date || '. Review and update your benefit selections.' AS description,
               '/me/benefits' AS action_url,
               ew.close_date AS due_date,
               CASE WHEN ew.close_date <= CURRENT_DATE + INTERVAL '3 days' THEN 'URGENT' ELSE 'HIGH' END AS priority,
               'benefits.enrollment_windows:' || ew.id || ':' || e.id AS source_key
        FROM benefits.enrollment_windows ew
        CROSS JOIN core.employees e
        LEFT JOIN core.users u ON u.employee_id = e.id
        WHERE ew.status = 'OPEN' AND e.is_active = TRUE
          AND NOT EXISTS (SELECT 1 FROM benefits.enrollments en
                          WHERE en.employee_id = e.id AND en.window_id = ew.id)
    """,

    'COMP_LIFE_EVENT_EXPIRING': """
        SELECT le.employee_id, u.id AS user_id,
               'Life Event: Update benefits within ' || le.change_window_days || ' days' AS title,
               'Your life event (' || le.event_type || ') requires benefit changes before '
                   || (le.event_date + le.change_window_days * INTERVAL '1 day')::DATE || '.' AS description,
               '/me/benefits' AS action_url,
               (le.event_date + le.change_window_days * INTERVAL '1 day')::DATE AS due_date,
               'HIGH' AS priority,
               'benefits.life_events:' || le.id AS source_key
        FROM benefits.life_events le
        LEFT JOIN core.users u ON u.employee_id = le.employee_id
        WHERE le.status = 'OPEN'
    """,

    # ── MILESTONES ────────────────────────────────────────────────────
    'MILE_BIRTHDAY': """
        SELECT e.id AS employee_id, u.id AS user_id,
               'Happy Birthday, ' || e.first_name || '!' AS title,
               'Wishing you a wonderful birthday! Your agency celebrates you today.' AS description,
               '/me' AS action_url,
               (DATE_TRUNC('year', CURRENT_DATE) + (e.date_of_birth - DATE_TRUNC('year', e.date_of_birth)))::DATE AS due_date,
               'LOW' AS priority,
               'milestone:birthday:' || e.id || ':' || EXTRACT(YEAR FROM CURRENT_DATE) AS source_key
        FROM core.employees e
        LEFT JOIN core.users u ON u.employee_id = e.id
        WHERE e.is_active AND e.date_of_birth IS NOT NULL
          AND EXTRACT(MONTH FROM e.date_of_birth) = EXTRACT(MONTH FROM CURRENT_DATE)
          AND EXTRACT(DAY FROM e.date_of_birth) = EXTRACT(DAY FROM CURRENT_DATE)
    """,

    'MILE_ANNIVERSARY': """
        SELECT e.id AS employee_id, u.id AS user_id,
               'Service Anniversary: ' || EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.date_hired))::INT || ' year(s)' AS title,
               'Congratulations on your ' || EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.date_hired))::INT
                   || '-year service milestone! Thank you for your dedication.' AS description,
               '/me' AS action_url,
               CURRENT_DATE AS due_date,
               'NORMAL' AS priority,
               'milestone:anniversary:' || e.id || ':' || EXTRACT(YEAR FROM CURRENT_DATE) AS source_key
        FROM core.employees e
        LEFT JOIN core.users u ON u.employee_id = e.id
        WHERE e.is_active AND e.date_hired IS NOT NULL
          AND EXTRACT(MONTH FROM e.date_hired) = EXTRACT(MONTH FROM CURRENT_DATE)
          AND EXTRACT(DAY FROM e.date_hired) = EXTRACT(DAY FROM CURRENT_DATE)
          AND e.date_hired < CURRENT_DATE
    """,

    'MILE_STEP_INCREMENT': """
        SELECT si.employee_id, u.id AS user_id,
               'Step Increment Due' AS title,
               'You are eligible for a step increment (Year ' || si.increment_year
                   || '). HR will process this automatically.' AS description,
               '/rr/step-increments' AS action_url,
               si.effective_date AS due_date,
               'NORMAL' AS priority,
               'rewards.rwd_step_increments:' || si.id AS source_key
        FROM rewards.rwd_step_increments si
        LEFT JOIN core.users u ON u.employee_id = si.employee_id
        WHERE si.status = 'ELIGIBLE'
          AND si.effective_date <= CURRENT_DATE + INTERVAL '30 days'
    """,

    # ── PERFORMANCE ───────────────────────────────────────────────────
    'PERF_IPCR_PENDING': """
        SELECT i.employee_id, u.id AS user_id,
               'IPCR Due: ' || pc.name AS title,
               'Your Individual Performance Commitment & Review for cycle "' || pc.name
                   || '" is pending submission. Deadline: ' || pc.review_end || '.' AS description,
               '/pm/ipcr' AS action_url,
               pc.review_end AS due_date,
               CASE WHEN pc.review_end <= CURRENT_DATE + INTERVAL '7 days' THEN 'HIGH' ELSE 'NORMAL' END AS priority,
               'performance.perf_ipcr:' || i.id AS source_key
        FROM performance.perf_ipcr i
        JOIN performance.perf_cycles pc ON pc.id = i.cycle_id
        LEFT JOIN core.users u ON u.employee_id = i.employee_id
        WHERE i.status IN ('DRAFT', 'IN_PROGRESS')
          AND pc.status = 'ACTIVE'
    """,

    # ── OPERATIONAL ───────────────────────────────────────────────────
    'OPS_PENDING_APPROVALS': """
        SELECT e.id AS employee_id, u.id AS user_id,
               'Pending Approval: ' || wd.name AS title,
               'A workflow (' || wd.name || ') is awaiting your action. Reference: '
                   || COALESCE(wi.reference_no, 'N/A') || '.' AS description,
               '/workflow/instance/' || wi.id AS action_url,
               NULL AS due_date,
               CASE WHEN wi.created_at < NOW() - INTERVAL '48 hours' THEN 'URGENT'
                    WHEN wi.created_at < NOW() - INTERVAL '24 hours' THEN 'HIGH' ELSE 'NORMAL' END AS priority,
               'workflow.workflow_instances:' || wi.id AS source_key
        FROM workflow.workflow_instances wi
        JOIN workflow.workflow_definitions wd ON wd.id = wi.definition_id
        JOIN workflow.workflow_steps ws ON ws.id = wi.current_step_id
        JOIN core.user_roles ur ON ur.role_id = (SELECT id FROM core.roles WHERE code = ws.role_required LIMIT 1)
        JOIN core.users u ON u.id = ur.user_id AND u.is_active
        LEFT JOIN core.employees e ON e.id = u.employee_id
        WHERE wi.status = 'IN_PROGRESS'
    """,

    'OPS_MISSING_TIMEOUT': """
        SELECT ad.employee_id, u.id AS user_id,
               'Missing Time-Out: ' || ad.work_date AS title,
               'Your DTR for ' || ad.work_date || ' has no time-out recorded. Please file a correction or contact HR.' AS description,
               '/me/attendance' AS action_url,
               ad.work_date + INTERVAL '3 days' AS due_date,
               'HIGH' AS priority,
               'attendance.att_daily:' || ad.id AS source_key
        FROM attendance.att_daily ad
        LEFT JOIN core.users u ON u.employee_id = ad.employee_id
        WHERE ad.time_in IS NOT NULL AND ad.time_out IS NULL
          AND ad.work_date >= CURRENT_DATE - INTERVAL '7 days'
    """,

    'OPS_LEAVE_BALANCE_LOW': """
        SELECT lb.employee_id, u.id AS user_id,
               'Low Leave Balance: ' || lt.name AS title,
               'Your ' || lt.name || ' balance is ' || lb.accrued_days - lb.used_days - lb.pending_days
                   || ' day(s). Plan accordingly.' AS description,
               '/me/leaves' AS action_url,
               NULL AS due_date,
               'NORMAL' AS priority,
               'leave_mgmt.lv_balances:' || lb.id AS source_key
        FROM leave_mgmt.lv_balances lb
        JOIN leave_mgmt.lv_types lt ON lt.id = lb.leave_type_id
        LEFT JOIN core.users u ON u.employee_id = lb.employee_id
        WHERE lb.year = EXTRACT(YEAR FROM CURRENT_DATE)
          AND (lb.accrued_days - lb.used_days - lb.pending_days) <= 3
          AND (lb.accrued_days - lb.used_days - lb.pending_days) >= 0
          AND lt.code IN ('VL', 'SL')
    """,

    # ── HR / MANAGER TARGETED ─────────────────────────────────────────
    'HR_RETIREMENT_UPCOMING': """
        SELECT ra.employee_id, u.id AS user_id,
               'Upcoming Retirement: ' || e.first_name || ' ' || e.last_name AS title,
               e.first_name || ' ' || e.last_name || ' reaches mandatory retirement on '
                   || ra.retirement_date || '. Prepare succession and clearance.' AS description,
               '/rr/retirement-notices' AS action_url,
               ra.retirement_date AS due_date,
               CASE WHEN ra.retirement_date <= CURRENT_DATE + INTERVAL '90 days' THEN 'HIGH' ELSE 'NORMAL' END AS priority,
               'rewards.rwd_retirement_alerts:' || ra.id AS source_key
        FROM rewards.rwd_retirement_alerts ra
        JOIN core.employees e ON e.id = ra.employee_id
        LEFT JOIN core.users u ON u.employee_id = ra.employee_id
        WHERE ra.status = 'PENDING'
          AND ra.retirement_date <= CURRENT_DATE + INTERVAL '180 days'
    """,

    # ── TASK MANAGEMENT ───────────────────────────────────────────────
    'TASK_DUE_24H': """
        SELECT COALESCE(t.employee_id, 0) AS employee_id,
               COALESCE(t.user_id, u.id)  AS user_id,
               'Due tomorrow: ' || t.title AS title,
               'Task "' || t.title || '" is due ' || to_char(t.due_date, 'FMMonth FMDD')
                   || '. Priority: ' || t.priority || '.' AS description,
               COALESCE(t.action_url, '/tasks/' || t.id) AS action_url,
               t.due_date AS due_date,
               CASE WHEN t.priority = 'URGENT' THEN 'URGENT'
                    WHEN t.priority = 'HIGH'   THEN 'HIGH'
                    ELSE 'NORMAL' END AS priority,
               'core.task_inbox:' || t.id AS source_key
          FROM core.task_inbox t
          LEFT JOIN core.users u ON u.employee_id = t.employee_id
         WHERE t.status IN ('PENDING','IN_PROGRESS')
           AND t.due_date = CURRENT_DATE + INTERVAL '1 day'
           AND t.task_type NOT LIKE 'TASK_REMINDER%'
    """,

    'TASK_OVERDUE': """
        SELECT COALESCE(t.employee_id, 0) AS employee_id,
               COALESCE(t.user_id, u.id)  AS user_id,
               'Overdue: ' || t.title AS title,
               'Task "' || t.title || '" was due ' || to_char(t.due_date, 'FMMonth FMDD')
                   || ' and is ' || (CURRENT_DATE - t.due_date) || ' day(s) overdue.' AS description,
               COALESCE(t.action_url, '/tasks/' || t.id) AS action_url,
               t.due_date AS due_date,
               'HIGH' AS priority,
               'core.task_inbox:' || t.id AS source_key
          FROM core.task_inbox t
          LEFT JOIN core.users u ON u.employee_id = t.employee_id
         WHERE t.status NOT IN ('COMPLETED','DISMISSED')
           AND t.due_date < CURRENT_DATE
           AND t.task_type NOT LIKE 'TASK_REMINDER%'
    """,

    # ── RECRUITMENT / REQUISITIONS ────────────────────────────────────
    'REQ_PENDING_24H': """
        SELECT COALESCE(e.id, 0) AS employee_id, u.id AS user_id,
               'Approve requisition: ' || r.reference_no AS title,
               'Requisition for ' || COALESCE(p.title, 'position')
                   || ' (' || r.headcount || ' head) has been pending over 24h. Review and approve.' AS description,
               '/rsp/requisitions/' || r.id AS action_url,
               (COALESCE(r.submitted_at, r.created_at) + INTERVAL '48 hours')::DATE AS due_date,
               CASE WHEN r.priority IN ('URGENT', 'HIGH') THEN 'HIGH' ELSE 'NORMAL' END AS priority,
               'recruitment.rec_requisitions:' || r.id AS source_key
        FROM recruitment.rec_requisitions r
        LEFT JOIN core.positions p ON p.id = r.position_id
        LEFT JOIN workflow.workflow_instances wi ON wi.id = r.workflow_instance_id
        LEFT JOIN workflow.workflow_steps ws ON ws.id = wi.current_step_id
        LEFT JOIN core.users u ON u.role_code = ws.role_required AND u.is_active = TRUE
        LEFT JOIN core.employees e ON e.id = u.employee_id
        WHERE r.status = 'PENDING_APPROVAL'
          AND COALESCE(r.submitted_at, r.created_at) <= NOW() - INTERVAL '24 hours'
    """,
}


# -------------------------------------------------------------------------
# Core engine
# -------------------------------------------------------------------------

def get_rules(category=None, active_only=True):
    conditions = []
    params = []
    if category:
        conditions.append('category = %s')
        params.append(category)
    if active_only:
        conditions.append('is_active = TRUE')
    where = 'WHERE ' + ' AND '.join(conditions) if conditions else ''
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT r.*,
                   (SELECT COUNT(*) FROM notifications.reminder_log rl
                    WHERE rl.rule_id = r.id AND rl.fired_at >= CURRENT_DATE) AS fired_today,
                   (SELECT COUNT(*) FROM notifications.reminder_log rl
                    WHERE rl.rule_id = r.id AND rl.status = 'SENT') AS pending_count
            FROM notifications.reminder_rules r {where}
            ORDER BY r.category, r.name
        """, params)
        return cur.fetchall()


def evaluate_rule(rule_code, employee_id=None):
    """Evaluate a single rule, returning matching rows. Optionally filter by employee."""
    query = TRIGGER_QUERIES.get(rule_code)
    if not query:
        return []
    if employee_id:
        query = f"SELECT * FROM ({query}) sub WHERE sub.employee_id = %s"
    with get_cursor() as cur:
        if employee_id:
            cur.execute(query, (employee_id,))
        else:
            cur.execute(query)
        return cur.fetchall()


def fire_reminders_for_employee(employee_id, user_id=None):
    """Evaluate all active rules for a single employee. Called on /me page load."""
    with get_cursor() as cur:
        cur.execute("SELECT code FROM notifications.reminder_rules WHERE is_active = TRUE")
        rules = [r['code'] for r in cur.fetchall()]

    fired = 0
    for code in rules:
        try:
            rows = evaluate_rule(code, employee_id=employee_id)
            for row in rows:
                fired += _fire_single(code, row)
        except Exception:
            pass  # Skip rules that fail (missing tables, etc.)
    return fired


def fire_all_reminders():
    """Evaluate all active rules for all employees. Called by HR admin action."""
    with get_cursor() as cur:
        cur.execute("SELECT code FROM notifications.reminder_rules WHERE is_active = TRUE")
        rules = [r['code'] for r in cur.fetchall()]

    fired = 0
    for code in rules:
        try:
            rows = evaluate_rule(code)
            for row in rows:
                fired += _fire_single(code, row)
        except Exception:
            pass
    return fired


def _fire_single(rule_code, row):
    """Create inbox task + bell notification for one reminder match, deduplicating by source_key."""
    source_key = row.get('source_key', '')
    emp_id = row.get('employee_id')
    uid = row.get('user_id')
    title = row.get('title', 'Reminder')
    desc = row.get('description', '')
    action_url = row.get('action_url', '/me/inbox')
    due = row.get('due_date')
    priority = row.get('priority', 'NORMAL')

    # Deduplicate: check if this exact source_key already has a pending task
    with get_cursor() as cur:
        cur.execute("""
            SELECT 1 FROM core.task_inbox
            WHERE source_table = %s AND status = 'PENDING'
            LIMIT 1
        """, (source_key,))
        if cur.fetchone():
            return 0

    # Create inbox task
    task_id = inbox.create_task(
        employee_id=emp_id, user_id=uid, task_type='REMINDER',
        title=title, description=desc, action_url=action_url,
        priority=priority, due_date=due, source_table=source_key,
    )

    # Fire bell notification
    notif_id = None
    if uid:
        notif_id = notif.push_in_app(
            user_id=uid, title=title, body=desc,
            action_url=action_url, module='reminder',
        )

    # Log the reminder
    with get_cursor(commit=True) as cur:
        cur.execute("SELECT id FROM notifications.reminder_rules WHERE code = %s", (rule_code,))
        rule = cur.fetchone()
        if rule:
            cur.execute("""
                INSERT INTO notifications.reminder_log
                    (rule_id, employee_id, user_id, task_inbox_id, notification_id, title, due_date, priority)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """, (rule['id'], emp_id, uid, task_id, notif_id, title, due, priority))

    return 1


def run_escalations():
    """Escalate overdue reminders to managers/HR."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            SELECT rl.id, rl.employee_id, rl.title, rl.due_date, rr.escalation_to, rr.escalation_days,
                   e.immediate_supervisor_id
            FROM notifications.reminder_log rl
            JOIN notifications.reminder_rules rr ON rr.id = rl.rule_id
            JOIN core.employees e ON e.id = rl.employee_id
            WHERE rl.status = 'SENT'
              AND rr.escalation_days IS NOT NULL
              AND rl.due_date IS NOT NULL
              AND rl.due_date + rr.escalation_days * INTERVAL '1 day' < CURRENT_DATE
              AND rl.escalated_at IS NULL
        """)
        overdue = cur.fetchall()

    for item in overdue:
        escalate_to = item['escalation_to'] or 'MANAGER'
        target_emp_id = None
        target_user_id = None

        if escalate_to == 'MANAGER' and item['immediate_supervisor_id']:
            target_emp_id = item['immediate_supervisor_id']
            with get_cursor() as cur:
                cur.execute("SELECT id FROM core.users WHERE employee_id = %s", (target_emp_id,))
                r = cur.fetchone()
                target_user_id = r['id'] if r else None
        elif escalate_to in ('HR', 'HR_ADMIN'):
            with get_cursor() as cur:
                cur.execute("SELECT id, employee_id FROM core.users WHERE role_code = 'HR_ADMIN' LIMIT 1")
                r = cur.fetchone()
                if r:
                    target_user_id = r['id']
                    target_emp_id = r['employee_id']

        if target_user_id and target_emp_id:
            esc_title = f"ESCALATION: {item['title']} (overdue)"
            esc_desc = f"This reminder for employee ID {item['employee_id']} is overdue (due {item['due_date']}). Please follow up."
            inbox.create_task(
                employee_id=target_emp_id, user_id=target_user_id,
                task_type='ESCALATION', title=esc_title, description=esc_desc,
                action_url='/admin/reminders', priority='URGENT',
            )
            notif.push_in_app(
                user_id=target_user_id, title=esc_title, body=esc_desc,
                action_url='/admin/reminders', module='escalation',
            )

        with get_cursor(commit=True) as cur:
            cur.execute("""
                UPDATE notifications.reminder_log SET status = 'ESCALATED', escalated_at = NOW()
                WHERE id = %s
            """, (item['id'],))


# -------------------------------------------------------------------------
# Stats for admin dashboard
# -------------------------------------------------------------------------

def get_reminder_stats():
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                (SELECT COUNT(*) FROM notifications.reminder_rules WHERE is_active) AS active_rules,
                (SELECT COUNT(*) FROM notifications.reminder_log WHERE fired_at >= CURRENT_DATE) AS fired_today,
                (SELECT COUNT(*) FROM notifications.reminder_log WHERE status = 'SENT') AS pending,
                (SELECT COUNT(*) FROM notifications.reminder_log WHERE status = 'ESCALATED') AS escalated,
                (SELECT COUNT(*) FROM notifications.reminder_log WHERE status = 'RESOLVED') AS resolved,
                (SELECT COUNT(*) FROM notifications.reminder_log) AS total_fired
        """)
        return cur.fetchone()


def get_recent_reminders(limit=20):
    with get_cursor() as cur:
        cur.execute("""
            SELECT rl.*, rr.code AS rule_code, rr.name AS rule_name, rr.category,
                   e.first_name || ' ' || e.last_name AS employee_name
            FROM notifications.reminder_log rl
            JOIN notifications.reminder_rules rr ON rr.id = rl.rule_id
            LEFT JOIN core.employees e ON e.id = rl.employee_id
            ORDER BY rl.fired_at DESC
            LIMIT %s
        """, (limit,))
        return cur.fetchall()
