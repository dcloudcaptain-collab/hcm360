-- ================================================================
-- HCM360 — 60: JOB REQUISITION FEATURE (full implementation)
--
-- Closes all 31 GAP + 5 PARTIAL items from Sheet #8 of the LGU
-- Mariveles Gap Analysis (doc/lgu/generate.py:JOB_REQUISITION_GAP).
--
-- Categories addressed:
--   1. Data Model      — ALTER rec_requisitions + new attachments table
--   3. Approval Workflow — seed REQUISITION_APPROVAL definition
--   5. Notifications    — seed REQ_SUBMITTED/APPROVED/REJECTED templates
--   6. Access Control   — register pages + features + role grants
--   7. Reporting        — Report Builder source + 4 dashboard metrics
--   8. Integration      — guided tour seed
-- ================================================================
SET search_path TO recruitment, core, workflow, public;


-- ══════════════════════════════════════════════════════════════════════
-- CATEGORY 1 · Data Model — extend rec_requisitions + attachments
-- ══════════════════════════════════════════════════════════════════════
ALTER TABLE recruitment.rec_requisitions
    ADD COLUMN IF NOT EXISTS plantilla_item_id        BIGINT REFERENCES recruitment.rec_plantilla_items(id),
    ADD COLUMN IF NOT EXISTS budget_source            VARCHAR(200),
    ADD COLUMN IF NOT EXISTS funds_available          NUMERIC(14,2),
    ADD COLUMN IF NOT EXISTS priority                 VARCHAR(10) DEFAULT 'NORMAL',
    ADD COLUMN IF NOT EXISTS qualification_standard_id BIGINT REFERENCES recruitment.rec_qualification_standards(id),
    ADD COLUMN IF NOT EXISTS required_eligibility_id   BIGINT REFERENCES recruitment.rec_csc_eligibilities(id),
    ADD COLUMN IF NOT EXISTS salary_min_override      NUMERIC(14,2),
    ADD COLUMN IF NOT EXISTS salary_max_override      NUMERIC(14,2),
    ADD COLUMN IF NOT EXISTS rejection_reason         TEXT,
    ADD COLUMN IF NOT EXISTS approved_headcount       INTEGER,
    ADD COLUMN IF NOT EXISTS submitted_at             TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS approved_at              TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Priority CHECK
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'rec_req_priority_chk') THEN
        ALTER TABLE recruitment.rec_requisitions
            ADD CONSTRAINT rec_req_priority_chk
            CHECK (priority IN ('URGENT','HIGH','NORMAL','LOW'));
    END IF;
END $$;

-- Widen status CHECK (drop existing if present, then add comprehensive)
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_constraint
               WHERE conname = 'rec_requisitions_status_check') THEN
        ALTER TABLE recruitment.rec_requisitions
            DROP CONSTRAINT rec_requisitions_status_check;
    END IF;
    ALTER TABLE recruitment.rec_requisitions
        ADD CONSTRAINT rec_req_status_chk
        CHECK (status IN ('DRAFT','PENDING_APPROVAL','APPROVED',
                          'PUBLISHED','FILLED','REJECTED','CANCELLED'));
EXCEPTION WHEN OTHERS THEN NULL;
END $$;


-- Attachments table
CREATE TABLE IF NOT EXISTS recruitment.rec_requisition_attachments (
    id               BIGSERIAL    PRIMARY KEY,
    requisition_id   BIGINT       NOT NULL REFERENCES recruitment.rec_requisitions(id) ON DELETE CASCADE,
    attachment_type  VARCHAR(60),         -- 'JOB_DESCRIPTION','ORG_CHART','APPROVED_BUDGET','OTHER'
    file_name        VARCHAR(200) NOT NULL,
    file_path        TEXT         NOT NULL,
    file_size_kb     INTEGER,
    mime_type        VARCHAR(100),
    uploaded_by      BIGINT       REFERENCES core.users(id),
    uploaded_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_req_att_req ON recruitment.rec_requisition_attachments (requisition_id);


-- Rejection reason history (optional audit aid)
CREATE TABLE IF NOT EXISTS recruitment.rec_requisition_history (
    id              BIGSERIAL    PRIMARY KEY,
    requisition_id  BIGINT       NOT NULL REFERENCES recruitment.rec_requisitions(id) ON DELETE CASCADE,
    from_status     VARCHAR(30),
    to_status       VARCHAR(30),
    action          VARCHAR(30),              -- SUBMIT / APPROVE / REJECT / CANCEL / ATTACH / CLONE / PUBLISH
    remarks         TEXT,
    approved_headcount_snapshot INTEGER,
    metadata        JSONB        DEFAULT '{}'::jsonb,
    performed_by    BIGINT       REFERENCES core.users(id),
    performed_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
ALTER TABLE recruitment.rec_requisition_history
    ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb,
    ALTER COLUMN to_status DROP NOT NULL;
CREATE INDEX IF NOT EXISTS idx_req_hist_req ON recruitment.rec_requisition_history (requisition_id);


-- ══════════════════════════════════════════════════════════════════════
-- CATEGORY 3 · Approval Workflow — seed REQUISITION_APPROVAL
-- ══════════════════════════════════════════════════════════════════════
DO $$
DECLARE
    v_wd_id BIGINT;
    v_s1 BIGINT; v_s2 BIGINT; v_s3 BIGINT;
BEGIN
    INSERT INTO workflow.workflow_definitions
        (code, name, module, description, is_active)
    VALUES ('REQUISITION_APPROVAL', 'Job Requisition Approval',
            'recruitment',
            'Dept Head → HR Review → Executive Sign-off',
            TRUE)
    ON CONFLICT (code) DO UPDATE SET
        name = EXCLUDED.name,
        description = EXCLUDED.description,
        is_active = TRUE;

    SELECT id INTO v_wd_id FROM workflow.workflow_definitions
     WHERE code='REQUISITION_APPROVAL';

    -- Clear any previous steps/routes to make this migration idempotent
    DELETE FROM workflow.workflow_routes
     WHERE step_id IN (SELECT id FROM workflow.workflow_steps WHERE workflow_id = v_wd_id);
    DELETE FROM workflow.workflow_steps WHERE workflow_id = v_wd_id;

    INSERT INTO workflow.workflow_steps
        (workflow_id, step_order, code, name, role_required, is_final, sla_hours)
    VALUES
        (v_wd_id, 1, 'REQ_DEPT_HEAD',     'Department Head Review', 'MANAGER',    FALSE, 48),
        (v_wd_id, 2, 'REQ_HR_REVIEW',     'HR Review',              'HR_ADMIN',   FALSE, 48),
        (v_wd_id, 3, 'REQ_EXEC_APPROVE',  'Executive Sign-off',     'EXECUTIVE',  TRUE,  24);

    SELECT id INTO v_s1 FROM workflow.workflow_steps
     WHERE workflow_id=v_wd_id AND step_order=1;
    SELECT id INTO v_s2 FROM workflow.workflow_steps
     WHERE workflow_id=v_wd_id AND step_order=2;
    SELECT id INTO v_s3 FROM workflow.workflow_steps
     WHERE workflow_id=v_wd_id AND step_order=3;

    INSERT INTO workflow.workflow_routes (step_id, action_code, next_step_id, label)
    VALUES
        (v_s1, 'APPROVE', v_s2, 'Endorse → HR'),
        (v_s1, 'REJECT',  NULL, 'Reject'),
        (v_s2, 'APPROVE', v_s3, 'Approve → Executive'),
        (v_s2, 'REJECT',  NULL, 'Reject'),
        (v_s3, 'APPROVE', NULL, 'Final Approve'),
        (v_s3, 'REJECT',  NULL, 'Reject');
END $$;


-- ══════════════════════════════════════════════════════════════════════
-- CATEGORY 5 · Notifications — seed templates
-- ══════════════════════════════════════════════════════════════════════
INSERT INTO notifications.ntf_templates
    (template_code, module, event_type, channel_id, subject_template, body_template, is_active)
VALUES
    ('req_submitted_inapp',
     'recruitment', 'REQ_SUBMITTED', 1,
     'Requisition awaiting your approval',
     'A new requisition {{reference_no}} for {{position_title}} ({{headcount}} heads) has been submitted by {{requester_name}} and awaits your approval.',
     TRUE),
    ('req_approved_inapp',
     'recruitment', 'REQ_APPROVED', 1,
     'Requisition approved',
     'Your requisition {{reference_no}} has been approved. {{approved_headcount}} head(s) will be published as a vacancy shortly.',
     TRUE),
    ('req_rejected_inapp',
     'recruitment', 'REQ_REJECTED', 1,
     'Requisition rejected',
     'Your requisition {{reference_no}} was rejected. Reason: {{rejection_reason}}',
     TRUE)
ON CONFLICT (template_code) DO UPDATE SET
    subject_template = EXCLUDED.subject_template,
    body_template    = EXCLUDED.body_template,
    is_active        = TRUE;


-- ══════════════════════════════════════════════════════════════════════
-- CATEGORY 6 · Access Control — pages + features + role grants
-- ══════════════════════════════════════════════════════════════════════
INSERT INTO core.page_registry
    (path, title, module, nav_group, nav_label, nav_icon, nav_order, is_visible)
VALUES
    ('/rsp/requisitions',
        'Job Requisitions', 'rsp',
        'Recruitment', 'Requisitions', 'briefcase', 45, TRUE),
    ('/rsp/requisitions/new',
        'New Requisition', 'rsp',
        'Recruitment', 'New Requisition', 'plus-circle', 46, FALSE),
    ('/rsp/requisitions/',
        'Requisition Detail', 'rsp',
        'Recruitment', 'Requisition Detail', 'file-text', 47, FALSE)
ON CONFLICT (path) DO NOTHING;

INSERT INTO core.feature_registry
    (code, name, description, module, is_enabled, feature_type, action_type, page_path)
VALUES
    ('REQ_CREATE',  'Create Requisition',
     'Submit a new job requisition',
     'rsp', TRUE, 'ACTION', 'CREATE',  '/rsp/requisitions'),
    ('REQ_APPROVE', 'Approve Requisition',
     'Approve a pending requisition (workflow step actor)',
     'rsp', TRUE, 'ACTION', 'APPROVE', '/rsp/requisitions'),
    ('REQ_REJECT',  'Reject Requisition',
     'Reject a pending requisition with reason',
     'rsp', TRUE, 'ACTION', 'APPROVE', '/rsp/requisitions'),
    ('REQ_CANCEL',  'Cancel Requisition',
     'Cancel a requisition before completion',
     'rsp', TRUE, 'ACTION', 'EDIT',    '/rsp/requisitions'),
    ('REQ_PUBLISH', 'Publish Requisition',
     'Auto-publish approved requisition as vacancy',
     'rsp', TRUE, 'ACTION', 'CREATE',  '/rsp/requisitions')
ON CONFLICT (code) DO NOTHING;

-- Role-page access
-- SUPER_ADMIN + HR_ADMIN + MANAGER + EXECUTIVE can view all
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
FROM core.page_registry p
CROSS JOIN (VALUES ('SUPER_ADMIN'), ('HR_ADMIN'), ('MANAGER'),
                   ('EXECUTIVE')) AS r(role_code)
WHERE p.path IN ('/rsp/requisitions', '/rsp/requisitions/new', '/rsp/requisitions/')
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

-- EMPLOYEE can only view list (read-only), not create
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT 'EMPLOYEE', p.id, TRUE
FROM core.page_registry p
WHERE p.path IN ('/rsp/requisitions', '/rsp/requisitions/')
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT 'EMPLOYEE', p.id, FALSE
FROM core.page_registry p
WHERE p.path = '/rsp/requisitions/new'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = FALSE;

-- Role-feature access
-- CREATE: SUPER_ADMIN, HR_ADMIN, MANAGER
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.role_code, f.id, TRUE
FROM core.feature_registry f
CROSS JOIN (VALUES ('SUPER_ADMIN'), ('HR_ADMIN'), ('MANAGER')) AS r(role_code)
WHERE f.code IN ('REQ_CREATE', 'REQ_CANCEL')
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = TRUE;

-- APPROVE/REJECT: SUPER_ADMIN, HR_ADMIN, MANAGER, EXECUTIVE
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.role_code, f.id, TRUE
FROM core.feature_registry f
CROSS JOIN (VALUES ('SUPER_ADMIN'), ('HR_ADMIN'), ('MANAGER'),
                   ('EXECUTIVE')) AS r(role_code)
WHERE f.code IN ('REQ_APPROVE', 'REQ_REJECT', 'REQ_PUBLISH')
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = TRUE;


-- ══════════════════════════════════════════════════════════════════════
-- CATEGORY 7 · Reporting — Report Builder data source + dashboard KPIs
-- ══════════════════════════════════════════════════════════════════════
INSERT INTO analytics.report_data_sources
    (source_code, source_label, module, description, base_sql, is_active, sort_order)
VALUES
    ('REQUISITIONS', 'Job Requisitions', 'recruitment',
     'Open and historical job requisitions with status, priority, headcount, and approval timing',
     'SELECT rq.id, rq.reference_no, rq.headcount, rq.approved_headcount,
             rq.status, rq.priority, rq.target_hire_date,
             rq.submitted_at, rq.approved_at, rq.created_at,
             rq.budget_source, rq.funds_available,
             p.title AS position_title,
             d.name  AS department,
             jg.code AS salary_grade,
             CONCAT_WS('' '', u.display_name) AS requester_name,
             CASE WHEN rq.submitted_at IS NOT NULL
                  THEN EXTRACT(DAY FROM COALESCE(rq.approved_at, NOW()) - rq.submitted_at)::int
                  ELSE NULL END AS days_pending,
             pi.item_no AS plantilla_item_no,
             qs.title   AS qualification_standard,
             ce.code    AS required_eligibility
      FROM recruitment.rec_requisitions rq
      LEFT JOIN core.positions p                      ON p.id = rq.position_id
      LEFT JOIN core.departments d                    ON d.id = rq.department_id
      LEFT JOIN core.job_grades jg                    ON jg.id = p.job_grade_id
      LEFT JOIN core.users u                          ON u.id = rq.requested_by
      LEFT JOIN recruitment.rec_plantilla_items pi    ON pi.id = rq.plantilla_item_id
      LEFT JOIN recruitment.rec_qualification_standards qs ON qs.id = rq.qualification_standard_id
      LEFT JOIN recruitment.rec_csc_eligibilities ce  ON ce.id = rq.required_eligibility_id',
     TRUE, 55)
ON CONFLICT (source_code) DO UPDATE SET
    source_label = EXCLUDED.source_label,
    description  = EXCLUDED.description,
    base_sql     = EXCLUDED.base_sql,
    is_active    = TRUE,
    sort_order   = EXCLUDED.sort_order;

-- Field registry (~17 fields; sql_expression = output alias, per pattern fix in db/58)
DO $$
DECLARE src_id BIGINT;
    field_def RECORD;
BEGIN
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='REQUISITIONS';

    FOR field_def IN SELECT * FROM (VALUES
        ('reference_no',           'Reference No',       'TEXT',    'reference_no',       TRUE, TRUE, TRUE, FALSE, NULL),
        ('status',                 'Status',             'TEXT',    'status',             TRUE, TRUE, TRUE, FALSE, NULL),
        ('priority',               'Priority',           'TEXT',    'priority',           TRUE, TRUE, TRUE, FALSE, NULL),
        ('position_title',         'Position',           'TEXT',    'position_title',     TRUE, TRUE, TRUE, FALSE, NULL),
        ('department',             'Department',         'TEXT',    'department',         TRUE, TRUE, TRUE, FALSE, NULL),
        ('salary_grade',           'Salary Grade',       'TEXT',    'salary_grade',       TRUE, TRUE, TRUE, FALSE, NULL),
        ('headcount',              'Headcount',          'NUMBER',  'headcount',          FALSE, TRUE, TRUE, TRUE, 'SUM'),
        ('approved_headcount',     'Approved HC',        'NUMBER',  'approved_headcount', FALSE, TRUE, TRUE, TRUE, 'SUM'),
        ('target_hire_date',       'Target Hire Date',   'DATE',    'target_hire_date',   TRUE, TRUE, TRUE, FALSE, NULL),
        ('submitted_at',           'Submitted',          'DATE',    'submitted_at',       TRUE, TRUE, TRUE, FALSE, NULL),
        ('approved_at',            'Approved',           'DATE',    'approved_at',        TRUE, TRUE, TRUE, FALSE, NULL),
        ('created_at',             'Created',            'DATE',    'created_at',         TRUE, TRUE, TRUE, FALSE, NULL),
        ('days_pending',           'Days Pending',       'NUMBER',  'days_pending',       FALSE, TRUE, TRUE, TRUE, 'AVG'),
        ('budget_source',          'Budget Source',      'TEXT',    'budget_source',      TRUE, TRUE, TRUE, FALSE, NULL),
        ('funds_available',        'Funds Available',    'CURRENCY','funds_available',    FALSE, TRUE, TRUE, TRUE, 'SUM'),
        ('requester_name',         'Requester',          'TEXT',    'requester_name',     TRUE, TRUE, TRUE, FALSE, NULL),
        ('plantilla_item_no',      'Plantilla Item',     'TEXT',    'plantilla_item_no',  TRUE, TRUE, TRUE, FALSE, NULL),
        ('qualification_standard', 'Qualification Std.', 'TEXT',    'qualification_standard', TRUE, TRUE, TRUE, FALSE, NULL),
        ('required_eligibility',   'Required Eligibility','TEXT',   'required_eligibility', TRUE, TRUE, TRUE, FALSE, NULL)
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;
END $$;


-- Dashboard KPIs (4 metrics)
INSERT INTO core.dashboard_metrics
    (code, label, icon, module, sql_query, filter_url, roles, sort_order, is_active)
VALUES
    ('req_pending_count', 'Pending Requisitions', 'briefcase', 'recruitment',
     'SELECT COUNT(*) FROM recruitment.rec_requisitions WHERE status = ''PENDING_APPROVAL''',
     '/rsp/requisitions?status=PENDING_APPROVAL',
     ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE'], 52, TRUE),

    ('req_approved_ytd', 'Requisitions Approved YTD', 'check-circle', 'recruitment',
     'SELECT COUNT(*) FROM recruitment.rec_requisitions WHERE status IN (''APPROVED'',''PUBLISHED'',''FILLED'') AND EXTRACT(YEAR FROM COALESCE(approved_at, created_at)) = EXTRACT(YEAR FROM CURRENT_DATE)',
     '/rsp/requisitions?status=APPROVED',
     ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE'], 53, TRUE),

    ('req_avg_days_approve', 'Avg Days to Approve', 'clock', 'recruitment',
     'SELECT COALESCE(ROUND(AVG(EXTRACT(DAY FROM approved_at - submitted_at))), 0) FROM recruitment.rec_requisitions WHERE approved_at IS NOT NULL AND submitted_at IS NOT NULL',
     '/rsp/requisitions',
     ARRAY['SUPER_ADMIN','HR_ADMIN'], 54, TRUE),

    ('req_open_vacancies', 'Open Vacancies', 'map-pin', 'recruitment',
     'SELECT COUNT(*) FROM recruitment.rec_requisitions WHERE status IN (''APPROVED'',''PUBLISHED'')',
     '/rsp/requisitions?status=APPROVED',
     ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER'], 55, TRUE)
ON CONFLICT (code) DO UPDATE SET
    label      = EXCLUDED.label,
    sql_query  = EXCLUDED.sql_query,
    filter_url = EXCLUDED.filter_url,
    roles      = EXCLUDED.roles,
    is_active  = TRUE;


-- ══════════════════════════════════════════════════════════════════════
-- CATEGORY 8 · Guided tour
-- ══════════════════════════════════════════════════════════════════════
INSERT INTO core.tours
    (tour_key, title, description, module, allowed_roles, url_pattern, steps)
VALUES
    ('requisition-create-v1',
     'Creating a Job Requisition',
     'Walk-through of the end-to-end requisition form and approval flow',
     'recruitment',
     ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER'],
     '/rsp/requisitions',
     '[
        {"title":"Job Requisitions","body":"Request new or replacement positions here. Each requisition goes through a 3-step approval chain: Department Head → HR → Executive.","position":"center"},
        {"selector":"a[href*=\"new\"], .btn-primary","title":"Start a new requisition","body":"Click here to fill out the form. You can save as a draft any time.","position":"bottom"},
        {"selector":"select[name=position_id], [name=position]","title":"Pick the position","body":"Select the position you''re requesting. Pulling from the Plantilla (for LGUs) auto-locks the salary grade.","position":"right"},
        {"selector":"input[name=headcount]","title":"Headcount","body":"Number of heads you''re asking for. Approvers can reduce this later (partial approval).","position":"right"},
        {"selector":"textarea[name=justification]","title":"Justify the request","body":"Spell out the business need. This drives the approval conversation.","position":"right"},
        {"title":"After you submit","body":"A task lands in the Department Head''s inbox. Each approval moves the requisition one step forward. Once fully approved, a vacancy is auto-published.","position":"center"}
     ]'::jsonb)
ON CONFLICT (tour_key) DO UPDATE SET
    title         = EXCLUDED.title,
    description   = EXCLUDED.description,
    allowed_roles = EXCLUDED.allowed_roles,
    url_pattern   = EXCLUDED.url_pattern,
    steps         = EXCLUDED.steps,
    updated_at    = NOW();


-- ══════════════════════════════════════════════════════════════════════
-- CATEGORY 5 · Reminder rule — pending-approval > 24h
-- (The actual SQL lives in services/reminder_engine.py:TRIGGER_QUERIES.
--  This row activates the rule so fire_reminders_for_employee() picks it up.)
-- ══════════════════════════════════════════════════════════════════════
INSERT INTO notifications.reminder_rules
    (code, title, description, rule_type, source_query,
     task_type, priority, action_url_template, is_active)
VALUES
    ('REQ_PENDING_24H',
     'Requisition Pending >24h',
     'Approval task sent to current-step approver if a requisition has been pending more than 24 hours.',
     'SCHEDULED',
     'SEE services/reminder_engine.py:TRIGGER_QUERIES',
     'REQUISITION_APPROVAL',
     'HIGH',
     '/rsp/requisitions/{entity_id}',
     TRUE)
ON CONFLICT (code) DO UPDATE SET
    title                = EXCLUDED.title,
    description          = EXCLUDED.description,
    priority             = EXCLUDED.priority,
    action_url_template  = EXCLUDED.action_url_template,
    is_active            = TRUE;
