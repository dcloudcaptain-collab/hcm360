-- ══════════════════════════════════════════════════════════════════════
-- 61 · Task Management Feature
-- ══════════════════════════════════════════════════════════════════════
-- Closes Sheet #9 of the LGU Gap Analysis — 10 High-priority gaps:
--   · Assigner/created_by column
--   · Task comments + @mentions
--   · Task templates (onboarding/offboarding/etc.)
--   · Notification templates + reminder rules
--   · Page + feature registry + role grants
--   · Report Builder TASKS source
--   · Dashboard metrics
--   · Guided tour
--
-- Idempotent: safe to re-run. Uses ADD COLUMN IF NOT EXISTS, ON CONFLICT,
-- and conditional DO blocks where needed.
-- ══════════════════════════════════════════════════════════════════════

SET search_path = public;

-- ── 1 · Extend core.task_inbox ────────────────────────────────────────
ALTER TABLE core.task_inbox
    ADD COLUMN IF NOT EXISTS created_by    BIGINT REFERENCES core.users(id),
    ADD COLUMN IF NOT EXISTS task_category VARCHAR(30),
    ADD COLUMN IF NOT EXISTS updated_at    TIMESTAMPTZ DEFAULT NOW();

-- Category check (drop-then-add for idempotency)
DO $$
BEGIN
    BEGIN
        ALTER TABLE core.task_inbox DROP CONSTRAINT IF EXISTS task_inbox_category_check;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    ALTER TABLE core.task_inbox
        ADD CONSTRAINT task_inbox_category_check CHECK (
            task_category IS NULL OR task_category IN
              ('WORK','FOLLOWUP','MEETING','DOC_REVIEW',
               'ONBOARDING','OFFBOARDING','PERSONAL','SYSTEM')
        );
END $$;

-- Default new rows; backfill legacy
ALTER TABLE core.task_inbox ALTER COLUMN task_category SET DEFAULT 'WORK';
UPDATE core.task_inbox
   SET task_category = CASE
       WHEN task_type LIKE '%APPROVAL%' THEN 'SYSTEM'
       WHEN task_type LIKE '%REMINDER%' THEN 'SYSTEM'
       ELSE 'WORK' END
 WHERE task_category IS NULL;

-- created_by backfill — best guess: same as user_id for workflow-generated rows
UPDATE core.task_inbox SET created_by = user_id
 WHERE created_by IS NULL AND user_id IS NOT NULL;

-- ── 2 · core.task_comments ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS core.task_comments (
    id                  BIGSERIAL PRIMARY KEY,
    task_id             BIGINT NOT NULL REFERENCES core.task_inbox(id) ON DELETE CASCADE,
    user_id             BIGINT NOT NULL REFERENCES core.users(id),
    body                TEXT NOT NULL,
    mentioned_user_ids  BIGINT[] NOT NULL DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    edited_at           TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_task_comments_task ON core.task_comments(task_id, created_at);
CREATE INDEX IF NOT EXISTS idx_task_comments_mentions ON core.task_comments USING GIN(mentioned_user_ids);

-- ── 3 · core.task_templates ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS core.task_templates (
    id                BIGSERIAL PRIMARY KEY,
    code              VARCHAR(50) UNIQUE NOT NULL,
    title             VARCHAR(200) NOT NULL,
    description       TEXT,
    category          VARCHAR(30),
    default_priority  VARCHAR(10) DEFAULT 'NORMAL',
    icon              VARCHAR(40),
    checklist         JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_active         BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order        INT DEFAULT 100,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed templates (idempotent via ON CONFLICT on code)
INSERT INTO core.task_templates (code, title, description, category, default_priority, icon, checklist, sort_order)
VALUES
    ('ONBOARD_NEW_HIRE',
     'New Hire Onboarding',
     'Standard 30-day onboarding checklist for new employees — covers Day 0 setup, Day 1 orientation, Week 1 paperwork, and Month 1 check-in.',
     'ONBOARDING', 'HIGH', 'user-plus',
     '[
        {"title":"Send welcome email","offset_days":-1,"priority":"NORMAL","description":"Send welcome email with Day 1 instructions, dress code, office address, and reporting contact"},
        {"title":"Prepare workstation","offset_days":-1,"priority":"NORMAL","description":"Allocate desk, chair, laptop, and access badge before first day"},
        {"title":"Provision email account","offset_days":0,"priority":"HIGH","description":"Create company email, add to shared distribution lists, and test login"},
        {"title":"Orientation meeting","offset_days":0,"priority":"HIGH","description":"Welcome session with HR — policies, benefits, culture, org chart"},
        {"title":"Sign HR policies","offset_days":0,"priority":"HIGH","description":"Confidentiality, Code of Conduct, Data Privacy (RA 10173), Anti-Sexual Harassment"},
        {"title":"Submit IDs to HR","offset_days":2,"priority":"NORMAL","description":"TIN, SSS, PhilHealth, Pag-IBIG, NBI, police clearance, medical cert"},
        {"title":"Complete PDS (CSC 212)","offset_days":5,"priority":"HIGH","description":"Fill out Personal Data Sheet at /me/pds"},
        {"title":"201 file compilation","offset_days":7,"priority":"NORMAL","description":"Confirm HR has all records filed: contract, IDs, medical, PDS"},
        {"title":"SALN filing (if applicable)","offset_days":14,"priority":"NORMAL","description":"For permanent positions — file Statement of Assets, Liabilities and Net Worth at /me/saln"},
        {"title":"30-day check-in","offset_days":30,"priority":"HIGH","description":"One-on-one with direct supervisor — early wins, concerns, feedback"},
        {"title":"Training plan review","offset_days":30,"priority":"NORMAL","description":"Identify required trainings for the role and schedule them"},
        {"title":"First IPCR setup","offset_days":30,"priority":"HIGH","description":"Set initial performance objectives for the next review cycle"}
     ]'::jsonb,
     10),

    ('OFFBOARD_SEPARATION',
     'Separation / Offboarding',
     'Standard offboarding checklist — triggered when an employee resigns, retires, or is separated. Covers exit interview, CS Form 7 clearance, and knowledge handover.',
     'OFFBOARDING', 'HIGH', 'user-minus',
     '[
        {"title":"Submit exit interview","offset_days":-7,"priority":"HIGH","description":"Fill out exit interview form at /offboarding/exit-interview"},
        {"title":"Start CS Form 7 Clearance","offset_days":-7,"priority":"HIGH","description":"Initiate clearance at /offboarding/clearance — multi-signatory workflow"},
        {"title":"Return laptop / equipment","offset_days":-2,"priority":"HIGH","description":"Return assigned laptop, badge, office keys, company phone"},
        {"title":"Knowledge transfer document","offset_days":-5,"priority":"HIGH","description":"Document active projects, open tickets, key contacts for successor"},
        {"title":"Revoke system access","offset_days":0,"priority":"URGENT","description":"IT disables email, VPN, production access on last day"},
        {"title":"Final payslip review","offset_days":0,"priority":"NORMAL","description":"Confirm last pay, unused leave conversion, tax clearance"},
        {"title":"Issue Certificate of Employment","offset_days":3,"priority":"NORMAL","description":"COE prepared and signed by HR Admin"},
        {"title":"Government contributions final","offset_days":15,"priority":"NORMAL","description":"Confirm last SSS/PhilHealth/Pag-IBIG/BIR remittance includes employee"},
        {"title":"Archive 201 file","offset_days":15,"priority":"LOW","description":"Move to inactive archive with retention tag per records schedule"}
     ]'::jsonb,
     20),

    ('MONTHLY_KPI_REPORT',
     'Monthly KPI Report',
     'Recurring monthly cadence to prepare and submit departmental KPI report.',
     'WORK', 'NORMAL', 'bar-chart-2',
     '[
        {"title":"Gather metrics from team","offset_days":0,"priority":"NORMAL","description":"Request updates from each direct report"},
        {"title":"Compile report","offset_days":2,"priority":"NORMAL","description":"Consolidate metrics with commentary on variance"},
        {"title":"Review with supervisor","offset_days":3,"priority":"HIGH","description":"Walk through before submission"},
        {"title":"Submit to HR / Exec","offset_days":5,"priority":"HIGH","description":"File final report"}
     ]'::jsonb,
     30),

    ('QUARTERLY_IPCR',
     'Quarterly IPCR Cycle',
     'Individual Performance Commitment and Review — quarterly review cycle.',
     'WORK', 'HIGH', 'check-square',
     '[
        {"title":"Self-assessment draft","offset_days":0,"priority":"NORMAL","description":"Draft self-rating against quarterly objectives"},
        {"title":"Peer feedback collection","offset_days":3,"priority":"NORMAL","description":"Gather feedback from 2-3 peers"},
        {"title":"Supervisor rating session","offset_days":7,"priority":"HIGH","description":"Formal one-on-one rating discussion"},
        {"title":"Sign & finalize IPCR","offset_days":10,"priority":"HIGH","description":"Both parties sign final rating"},
        {"title":"File with HR","offset_days":12,"priority":"NORMAL","description":"Submit signed IPCR to 201 file"},
        {"title":"Set next-quarter objectives","offset_days":14,"priority":"HIGH","description":"Agree on next-cycle commitments"}
     ]'::jsonb,
     40),

    ('ANNUAL_SALN_FILING',
     'Annual SALN Filing',
     'Statement of Assets, Liabilities and Net Worth — filed annually by all government employees.',
     'DOC_REVIEW', 'HIGH', 'file-text',
     '[
        {"title":"Gather supporting documents","offset_days":0,"priority":"NORMAL","description":"Bank statements, land titles, vehicle registrations, business interests"},
        {"title":"Complete SALN form","offset_days":7,"priority":"HIGH","description":"Fill out CSC Form 210 at /me/saln"},
        {"title":"Submit by April 30","offset_days":14,"priority":"URGENT","description":"Notarized and filed with HR before statutory deadline"}
     ]'::jsonb,
     50)
ON CONFLICT (code) DO UPDATE SET
    title            = EXCLUDED.title,
    description      = EXCLUDED.description,
    category         = EXCLUDED.category,
    default_priority = EXCLUDED.default_priority,
    icon             = EXCLUDED.icon,
    checklist        = EXCLUDED.checklist,
    sort_order       = EXCLUDED.sort_order,
    updated_at       = NOW();

-- ── 4 · Notification templates ────────────────────────────────────────
INSERT INTO notifications.ntf_templates (template_code, module, event_type, channel_id, subject_template, body_template, is_active)
VALUES
    ('task_assigned',  'tasks', 'TASK_ASSIGNED',  1,
     'New task assigned',
     '{{assigner_name}} assigned you: {{title}}. Due {{due_date}}. Priority: {{priority}}.',
     TRUE),
    ('task_due_24h',   'tasks', 'TASK_DUE_24H',   1,
     'Task due tomorrow',
     'Task "{{title}}" is due tomorrow ({{due_date}}). Priority: {{priority}}.',
     TRUE),
    ('task_overdue',   'tasks', 'TASK_OVERDUE',   1,
     'Task overdue',
     'Task "{{title}}" was due {{due_date}} and is now {{days_overdue}} day(s) overdue.',
     TRUE),
    ('task_commented', 'tasks', 'TASK_COMMENTED', 1,
     'New comment on your task',
     '{{commenter_name}} commented on "{{title}}": {{excerpt}}',
     TRUE),
    ('task_mentioned', 'tasks', 'TASK_MENTIONED', 1,
     'You were mentioned',
     '{{commenter_name}} mentioned you on task "{{title}}". Click to view.',
     TRUE)
ON CONFLICT (template_code) DO UPDATE SET
    module           = EXCLUDED.module,
    event_type       = EXCLUDED.event_type,
    channel_id       = EXCLUDED.channel_id,
    subject_template = EXCLUDED.subject_template,
    body_template    = EXCLUDED.body_template,
    is_active        = TRUE;

-- ── 5 · Reminder rules ────────────────────────────────────────────────
INSERT INTO notifications.reminder_rules
    (code, title, description, rule_type, source_query, task_type, priority, action_url_template, is_active)
VALUES
    ('TASK_DUE_24H',
     'Task due in 24 hours',
     'Notifies task assignees the day before the due date.',
     'OPERATIONAL', 'INLINE_SQL', 'TASK_REMINDER', 'NORMAL',
     '/me/inbox', TRUE),
    ('TASK_OVERDUE',
     'Task overdue',
     'Escalates tasks past their due date to the assignee (and assigner after 48h).',
     'OPERATIONAL', 'INLINE_SQL', 'TASK_REMINDER', 'HIGH',
     '/me/inbox', TRUE)
ON CONFLICT (code) DO UPDATE SET
    title               = EXCLUDED.title,
    description         = EXCLUDED.description,
    priority            = EXCLUDED.priority,
    action_url_template = EXCLUDED.action_url_template,
    is_active           = TRUE;

-- ── 6 · Page registry ─────────────────────────────────────────────────
INSERT INTO core.page_registry (path, title, module, nav_group, nav_label, nav_icon, nav_order, is_visible)
VALUES
    ('/me/inbox',             'My Inbox',       'ess_mss', 'Self-Service', 'My Inbox',       'inbox',        45, TRUE),
    ('/tasks/new',            'New Task',       'ess_mss', 'Self-Service', 'New Task',       'plus-square',  46, FALSE),
    ('/tasks/',               'My Tasks',       'ess_mss', 'Self-Service', 'My Tasks',       'check-square', 47, TRUE),
    ('/tasks/team',           'Team Tasks',     'ess_mss', 'Management',   'Team Tasks',     'users',        48, TRUE),
    ('/admin/tasks',          'All Tasks',      'core',    'Admin',        'All Tasks',      'list',         49, TRUE),
    ('/admin/task-templates', 'Task Templates', 'core',    'Admin',        'Task Templates', 'layers',       50, TRUE)
ON CONFLICT (path) DO UPDATE SET
    title      = EXCLUDED.title,
    module     = EXCLUDED.module,
    nav_group  = EXCLUDED.nav_group,
    nav_label  = EXCLUDED.nav_label,
    nav_icon   = EXCLUDED.nav_icon,
    nav_order  = EXCLUDED.nav_order,
    is_visible = EXCLUDED.is_visible;

-- ── 7 · Feature registry (action-level features) ──────────────────────
INSERT INTO core.feature_registry (code, name, description, module, is_enabled, feature_type, action_type, page_path)
VALUES
    ('TASK_CREATE',          'Create Task',           'Create a new task for self or others',
        'ess_mss', TRUE, 'ACTION', 'CREATE', '/tasks/new'),
    ('TASK_ASSIGN',          'Assign Task to Others', 'Assign a task to a different employee (vs. self-task)',
        'ess_mss', TRUE, 'ACTION', 'CREATE', '/tasks/new'),
    ('TASK_EDIT',            'Edit Task',             'Modify title/description/priority/due date of a task',
        'ess_mss', TRUE, 'ACTION', 'EDIT',   '/tasks/'),
    ('TASK_COMPLETE',        'Complete Task',         'Mark a task as completed',
        'ess_mss', TRUE, 'ACTION', 'EDIT',   '/me/inbox'),
    ('TASK_REASSIGN',        'Reassign Task',         'Transfer task ownership to another user',
        'ess_mss', TRUE, 'ACTION', 'EDIT',   '/tasks/'),
    ('TASK_COMMENT',         'Comment on Task',       'Post a comment or @mention on a task',
        'ess_mss', TRUE, 'ACTION', 'CREATE', '/tasks/'),
    ('TASK_DELETE',          'Delete Task',           'Permanently delete a task (admin only)',
        'core',    TRUE, 'ACTION', 'DELETE', '/admin/tasks'),
    ('TASK_TEMPLATE_SPAWN',  'Spawn from Template',   'Bulk-create tasks from a template (HR only)',
        'core',    TRUE, 'ACTION', 'CREATE', '/admin/task-templates')
ON CONFLICT (code) DO UPDATE SET
    name        = EXCLUDED.name,
    description = EXCLUDED.description,
    module      = EXCLUDED.module,
    is_enabled  = TRUE,
    page_path   = EXCLUDED.page_path;

-- ── 8 · Role → Page access grants ─────────────────────────────────────
-- All roles can access personal inbox + create self-tasks + view a task detail.
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
FROM core.page_registry p
CROSS JOIN (VALUES ('SUPER_ADMIN'),('HR_ADMIN'),('EXECUTIVE'),('MANAGER'),('EMPLOYEE')) AS r(role_code)
WHERE p.path IN ('/me/inbox','/tasks/new','/tasks/')
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

-- MANAGER+ get team view
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
FROM core.page_registry p
CROSS JOIN (VALUES ('SUPER_ADMIN'),('HR_ADMIN'),('EXECUTIVE'),('MANAGER')) AS r(role_code)
WHERE p.path = '/tasks/team'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

-- HR_ADMIN+ get admin pages
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
FROM core.page_registry p
CROSS JOIN (VALUES ('SUPER_ADMIN'),('HR_ADMIN')) AS r(role_code)
WHERE p.path IN ('/admin/tasks','/admin/task-templates')
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

-- ── 9 · Role → Feature access grants ──────────────────────────────────
-- All roles get create/complete/comment
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.role_code, f.id, TRUE
FROM core.feature_registry f
CROSS JOIN (VALUES ('SUPER_ADMIN'),('HR_ADMIN'),('EXECUTIVE'),('MANAGER'),('EMPLOYEE')) AS r(role_code)
WHERE f.code IN ('TASK_CREATE','TASK_COMPLETE','TASK_COMMENT')
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = TRUE;

-- MANAGER+ get assign/edit/reassign
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.role_code, f.id, TRUE
FROM core.feature_registry f
CROSS JOIN (VALUES ('SUPER_ADMIN'),('HR_ADMIN'),('EXECUTIVE'),('MANAGER')) AS r(role_code)
WHERE f.code IN ('TASK_ASSIGN','TASK_EDIT','TASK_REASSIGN')
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = TRUE;

-- HR_ADMIN+ get delete + template spawn
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.role_code, f.id, TRUE
FROM core.feature_registry f
CROSS JOIN (VALUES ('SUPER_ADMIN'),('HR_ADMIN')) AS r(role_code)
WHERE f.code IN ('TASK_DELETE','TASK_TEMPLATE_SPAWN')
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = TRUE;

-- ── 10 · Report Builder data source ───────────────────────────────────
INSERT INTO analytics.report_data_sources
    (source_code, source_label, module, description, base_sql, is_active, sort_order)
VALUES
    ('TASKS',
     'Task Inbox',
     'ess_mss',
     'Tasks assigned to employees — open, overdue, completed. Covers personal tasks, system-generated approval tasks, and template-spawned onboarding/offboarding checklists.',
     'SELECT
        t.id,
        t.title,
        t.description,
        t.task_type,
        COALESCE(t.task_category, ''WORK'') AS task_category,
        t.priority,
        t.status,
        t.is_read,
        t.due_date,
        t.created_at,
        t.completed_at,
        (t.due_date - CURRENT_DATE)::int AS days_to_due,
        EXTRACT(DAY FROM NOW() - t.created_at)::int AS age_days,
        CASE WHEN t.due_date IS NOT NULL
                  AND t.due_date < CURRENT_DATE
                  AND t.status NOT IN (''COMPLETED'',''DISMISSED'')
             THEN TRUE ELSE FALSE END AS is_overdue,
        COALESCE(ae.first_name || '' '' || ae.last_name, au.display_name, '''') AS assignee_name,
        d.name AS assignee_department,
        COALESCE(cu.display_name, '''') AS assigner_name,
        t.source_table,
        t.action_url
      FROM core.task_inbox t
      LEFT JOIN core.employees ae ON ae.id = t.employee_id
      LEFT JOIN core.users au     ON au.id = t.user_id
      LEFT JOIN core.users cu     ON cu.id = t.created_by
      LEFT JOIN core.departments d ON d.id = ae.department_id',
     TRUE, 110)
ON CONFLICT (source_code) DO UPDATE SET
    source_label = EXCLUDED.source_label,
    module       = EXCLUDED.module,
    description  = EXCLUDED.description,
    base_sql     = EXCLUDED.base_sql,
    is_active    = TRUE,
    sort_order   = EXCLUDED.sort_order;

-- Field registry for the TASKS source
DO $$
DECLARE src_id BIGINT;
BEGIN
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code = 'TASKS';
    DELETE FROM analytics.report_field_registry WHERE source_id = src_id;
    INSERT INTO analytics.report_field_registry
        (source_id, field_code, field_label, field_type, sql_expression,
         is_groupable, is_filterable, is_sortable, is_aggregatable, sort_order)
    VALUES
        (src_id, 'id',                  'Task ID',              'NUMBER',  'id',                TRUE,  TRUE,  TRUE,  FALSE, 10),
        (src_id, 'title',               'Title',                'TEXT',    'title',             FALSE, TRUE,  TRUE,  FALSE, 20),
        (src_id, 'description',         'Description',          'TEXT',    'description',       FALSE, TRUE,  FALSE, FALSE, 25),
        (src_id, 'task_type',           'Task Type',            'TEXT',    'task_type',         TRUE,  TRUE,  TRUE,  FALSE, 30),
        (src_id, 'task_category',       'Category',             'TEXT',    'task_category',     TRUE,  TRUE,  TRUE,  FALSE, 35),
        (src_id, 'priority',            'Priority',             'TEXT',    'priority',          TRUE,  TRUE,  TRUE,  FALSE, 40),
        (src_id, 'status',              'Status',               'TEXT',    'status',            TRUE,  TRUE,  TRUE,  FALSE, 50),
        (src_id, 'is_read',             'Read?',                'BOOLEAN', 'is_read',           TRUE,  TRUE,  TRUE,  FALSE, 55),
        (src_id, 'is_overdue',          'Overdue?',             'BOOLEAN', 'is_overdue',        TRUE,  TRUE,  TRUE,  FALSE, 60),
        (src_id, 'due_date',            'Due Date',             'DATE',    'due_date',          TRUE,  TRUE,  TRUE,  FALSE, 70),
        (src_id, 'days_to_due',         'Days to Due',          'NUMBER',  'days_to_due',       FALSE, TRUE,  TRUE,  TRUE,  75),
        (src_id, 'created_at',          'Created',              'DATE',    'created_at',        TRUE,  TRUE,  TRUE,  FALSE, 80),
        (src_id, 'completed_at',        'Completed',            'DATE',    'completed_at',      TRUE,  TRUE,  TRUE,  FALSE, 85),
        (src_id, 'age_days',            'Age (days)',           'NUMBER',  'age_days',          FALSE, TRUE,  TRUE,  TRUE,  90),
        (src_id, 'assignee_name',       'Assignee',             'TEXT',    'assignee_name',     TRUE,  TRUE,  TRUE,  FALSE, 100),
        (src_id, 'assignee_department', 'Assignee Department',  'TEXT',    'assignee_department', TRUE, TRUE, TRUE,  FALSE, 110),
        (src_id, 'assigner_name',       'Assigned By',          'TEXT',    'assigner_name',     TRUE,  TRUE,  TRUE,  FALSE, 120),
        (src_id, 'source_table',        'Source System',        'TEXT',    'source_table',      TRUE,  TRUE,  FALSE, FALSE, 130),
        (src_id, 'action_url',          'Action URL',           'TEXT',    'action_url',        FALSE, FALSE, FALSE, FALSE, 140);
END $$;

-- Report source role access — all roles can query their own scope
DO $$
DECLARE src_id BIGINT;
BEGIN
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code = 'TASKS';
    -- Attempt to register role access if the table exists (naming varies by build)
    BEGIN
        INSERT INTO analytics.report_source_role_access (source_id, role_code, can_access)
        SELECT src_id, r.role_code, TRUE
        FROM (VALUES ('SUPER_ADMIN'),('HR_ADMIN'),('EXECUTIVE'),('MANAGER'),('EMPLOYEE')) AS r(role_code)
        ON CONFLICT DO NOTHING;
    EXCEPTION WHEN undefined_table THEN NULL;
    END;
END $$;

-- ── 11 · Dashboard metrics (4 new KPI cards) ──────────────────────────
INSERT INTO core.dashboard_metrics (code, label, icon, module, sql_query, filter_url, roles, sort_order, is_active)
VALUES
    ('tasks_open',
     'Open Tasks',
     'inbox',
     'ess_mss',
     'SELECT COUNT(*) FROM core.task_inbox t JOIN core.users u ON u.employee_id = t.employee_id WHERE t.status IN (''PENDING'',''IN_PROGRESS'') AND (u.id = {{user_id}} OR ''{{role_code}}'' IN (''SUPER_ADMIN'',''HR_ADMIN''))',
     '/me/inbox?status=PENDING',
     ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE','MANAGER','EMPLOYEE'],
     50, TRUE),
    ('tasks_overdue',
     'Overdue Tasks',
     'alert-triangle',
     'ess_mss',
     'SELECT COUNT(*) FROM core.task_inbox t JOIN core.users u ON u.employee_id = t.employee_id WHERE t.status NOT IN (''COMPLETED'',''DISMISSED'') AND t.due_date < CURRENT_DATE AND (u.id = {{user_id}} OR ''{{role_code}}'' IN (''SUPER_ADMIN'',''HR_ADMIN''))',
     '/me/inbox?due=overdue',
     ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE','MANAGER','EMPLOYEE'],
     51, TRUE),
    ('tasks_completed_ytd',
     'Tasks Completed YTD',
     'check-circle',
     'ess_mss',
     'SELECT COUNT(*) FROM core.task_inbox t JOIN core.users u ON u.employee_id = t.employee_id WHERE t.status = ''COMPLETED'' AND t.completed_at >= date_trunc(''year'', CURRENT_DATE) AND (u.id = {{user_id}} OR ''{{role_code}}'' IN (''SUPER_ADMIN'',''HR_ADMIN''))',
     '/me/inbox?status=COMPLETED',
     ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE','MANAGER','EMPLOYEE'],
     52, TRUE),
    ('tasks_avg_completion_days',
     'Avg Days to Complete',
     'clock',
     'ess_mss',
     'SELECT ROUND(AVG(EXTRACT(EPOCH FROM (completed_at - created_at))/86400)::numeric, 1)::text FROM core.task_inbox WHERE status = ''COMPLETED'' AND completed_at >= date_trunc(''year'', CURRENT_DATE)',
     '/reports/builder?source=TASKS',
     ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE'],
     53, TRUE)
ON CONFLICT (code) DO UPDATE SET
    label      = EXCLUDED.label,
    icon       = EXCLUDED.icon,
    module     = EXCLUDED.module,
    sql_query  = EXCLUDED.sql_query,
    filter_url = EXCLUDED.filter_url,
    roles      = EXCLUDED.roles,
    sort_order = EXCLUDED.sort_order,
    is_active  = TRUE,
    updated_at = NOW();

-- ── 12 · Guided tour ──────────────────────────────────────────────────
INSERT INTO core.tours (tour_key, title, description, module, allowed_roles, url_pattern, auto_start, steps, is_active)
VALUES
    ('task-management-v1',
     'Task Management Tour',
     '6-step walkthrough of the task inbox, filters, creating tasks, detail page, team view, and templates.',
     'ess_mss',
     ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE'],
     '/me/inbox',
     TRUE,
     '[
        {"title":"Your Task Inbox","body":"This is where tasks assigned to you live — personal to-dos, approval requests, and reminders. Click any task to open it.","position":"center"},
        {"selector":".filters, [data-filters]","title":"Filter & Search","body":"Filter by status, priority, or due date; search by keyword; sort however you like. The URL updates so you can bookmark a view.","position":"bottom"},
        {"selector":"a[href*=\"/tasks/new\"], .btn-primary","title":"Create a Task","body":"Click + New Task to create a personal to-do or assign one to a teammate. Pick priority, due date, and category.","position":"bottom"},
        {"title":"Task Detail","body":"Click any task title to open its detail page. You can complete, reassign, comment with @mentions, and see the full history.","position":"center"},
        {"selector":"a[href*=\"/tasks/team\"]","title":"Team View","body":"Managers see an aggregated view of all tasks assigned to their team at /tasks/team.","position":"bottom"},
        {"title":"All set!","body":"Need a ready-made checklist? Visit /admin/task-templates for onboarding, offboarding, and IPCR templates. Click the ? launcher anytime to replay this tour.","position":"center"}
     ]'::jsonb,
     TRUE)
ON CONFLICT (tour_key) DO UPDATE SET
    title         = EXCLUDED.title,
    description   = EXCLUDED.description,
    module        = EXCLUDED.module,
    allowed_roles = EXCLUDED.allowed_roles,
    url_pattern   = EXCLUDED.url_pattern,
    auto_start    = EXCLUDED.auto_start,
    steps         = EXCLUDED.steps,
    is_active     = TRUE,
    updated_at    = NOW();

-- ── Done ──────────────────────────────────────────────────────────────
-- Run `docker exec -i hris_db psql -U hris_admin -d hris_db < db/61_task_management.sql`
-- Then restart hris_web and exercise the verification checklist in the plan.
