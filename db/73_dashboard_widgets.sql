-- ================================================================
-- HCM360 — 73: DASHBOARD WIDGET LIBRARY
--
-- Goal:
--   Turn the dashboard contextual panels into a personalizable,
--   extensible widget library — same pattern as /dashboard/manage
--   (KPI tiles) and /admin/insights-library (charts).
--
-- Tables:
--   core.widget_library    — catalog of 20 canned widgets
--   core.user_widget_pins  — per-user pin list
--
-- Rendering model:
--   Every widget's `base_sql` returns ≤ `max_rows` rows. The template
--   iterates via `columns_meta` (JSONB array of {label, field, type}).
--   Types: 'text' · 'muted' · 'mono' · 'date' · 'time' · 'currency'
--          · 'int' · 'badge' (uses `badge_map` on the column)
--
-- Seeds: 20 top-priority HRIS widgets across 5 categories.
--        5 default-pinned so the dashboard is never empty.
-- ================================================================
SET search_path TO core, public;

CREATE TABLE IF NOT EXISTS core.widget_library (
    id              BIGSERIAL   PRIMARY KEY,
    code            VARCHAR(60) UNIQUE NOT NULL,
    title           VARCHAR(160) NOT NULL,
    description     TEXT,
    category        VARCHAR(40)  NOT NULL DEFAULT 'General',
    icon            VARCHAR(8)   NOT NULL DEFAULT '📊',
    render_mode     VARCHAR(20)  NOT NULL DEFAULT 'list'
                    CHECK (render_mode IN ('list','table','kv','stat')),
    base_sql        TEXT         NOT NULL,
    columns_meta    JSONB        NOT NULL DEFAULT '[]'::jsonb,
    link_url        VARCHAR(300),
    link_label      VARCHAR(60)  DEFAULT 'View all →',
    required_roles  VARCHAR(20)[] NOT NULL
                    DEFAULT ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE']::VARCHAR(20)[],
    default_pinned  BOOLEAN      NOT NULL DEFAULT FALSE,
    sort_order      INT          NOT NULL DEFAULT 100,
    max_rows        INT          NOT NULL DEFAULT 10,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_widget_lib_cat    ON core.widget_library (category, sort_order);
CREATE INDEX IF NOT EXISTS idx_widget_lib_active ON core.widget_library (is_active);


CREATE TABLE IF NOT EXISTS core.user_widget_pins (
    user_id      BIGINT      NOT NULL REFERENCES core.users(id) ON DELETE CASCADE,
    widget_code  VARCHAR(60) NOT NULL REFERENCES core.widget_library(code) ON DELETE CASCADE,
    sort_order   INT         NOT NULL DEFAULT 100,
    pinned_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, widget_code)
);
CREATE INDEX IF NOT EXISTS idx_uwp_user ON core.user_widget_pins (user_id, sort_order);


-- ═══════════════════════════════════════════════════════════════
-- 20 canned widgets
-- ═══════════════════════════════════════════════════════════════
INSERT INTO core.widget_library
    (code, title, description, category, icon, render_mode,
     base_sql, columns_meta, link_url, link_label,
     required_roles, default_pinned, sort_order, max_rows)
VALUES

-- ══ Workforce ════════════════════════════════════════════════
('TODAY_ATTENDANCE_BOARD',
 'Today''s Attendance Board',
 'Live check-in status for active employees today.',
 'Workforce', '🟢', 'list',
 $sql$
   SELECT e.first_name || ' ' || e.last_name AS employee,
          COALESCE(d.name, '—')              AS department,
          TO_CHAR(ad.time_in, 'HH24:MI')     AS time_in,
          ad.status                           AS status
     FROM core.employees e
     LEFT JOIN attendance.att_daily ad
            ON ad.employee_id = e.id AND ad.work_date = CURRENT_DATE
     LEFT JOIN core.departments d ON d.id = e.department_id
    WHERE e.is_active = TRUE
    ORDER BY e.last_name, e.first_name
    LIMIT 12
 $sql$,
 '[{"label":"Employee","field":"employee","type":"text"},
   {"label":"Dept","field":"department","type":"muted"},
   {"label":"In","field":"time_in","type":"mono"},
   {"label":"Status","field":"status","type":"badge","badge_map":{"PRESENT":"green","LATE":"amber","ABSENT":"red","ON_LEAVE":"blue"}}]'::jsonb,
 '/attendance/dtr', 'View full board →',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE']::VARCHAR(20)[], TRUE, 10, 12),

('BIRTHDAYS_THIS_MONTH',
 'Birthdays This Month',
 'Celebrate your teammates — employees with birthdays this calendar month.',
 'Workforce', '🎂', 'list',
 $sql$
   SELECT e.first_name || ' ' || e.last_name            AS employee,
          TO_CHAR(e.date_of_birth, 'Mon DD')            AS birthday,
          COALESCE(d.name, '—')                          AS department
     FROM core.employees e
     LEFT JOIN core.departments d ON d.id = e.department_id
    WHERE e.is_active = TRUE
      AND e.date_of_birth IS NOT NULL
      AND EXTRACT(MONTH FROM e.date_of_birth) = EXTRACT(MONTH FROM CURRENT_DATE)
    ORDER BY EXTRACT(DAY FROM e.date_of_birth)
    LIMIT 10
 $sql$,
 '[{"label":"Employee","field":"employee","type":"text"},
   {"label":"Birthday","field":"birthday","type":"mono"},
   {"label":"Dept","field":"department","type":"muted"}]'::jsonb,
 '/employees', 'Directory →',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE']::VARCHAR(20)[], FALSE, 20, 10),

('NEW_HIRES_30D',
 'New Hires (30 days)',
 'Employees who started in the last 30 days — onboarding watch list.',
 'Workforce', '🆕', 'list',
 $sql$
   SELECT e.first_name || ' ' || e.last_name AS employee,
          COALESCE(p.title, '—')             AS position,
          TO_CHAR(e.date_hired, 'Mon DD')    AS hired
     FROM core.employees e
     LEFT JOIN core.positions p ON p.id = e.position_id
    WHERE e.is_active = TRUE
      AND e.date_hired >= CURRENT_DATE - INTERVAL '30 days'
    ORDER BY e.date_hired DESC
    LIMIT 10
 $sql$,
 '[{"label":"Employee","field":"employee","type":"text"},
   {"label":"Position","field":"position","type":"muted"},
   {"label":"Hired","field":"hired","type":"mono"}]'::jsonb,
 '/employees?status=ACTIVE', 'See all →',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE']::VARCHAR(20)[], FALSE, 30, 10),

('SEPARATIONS_30D',
 'Separations (30 days)',
 'Employees who left in the last 30 days — retention red flag.',
 'Workforce', '🚪', 'list',
 $sql$
   SELECT e.first_name || ' ' || e.last_name AS employee,
          COALESCE(d.name, '—')              AS department,
          TO_CHAR(e.date_separated, 'Mon DD') AS separated
     FROM core.employees e
     LEFT JOIN core.departments d ON d.id = e.department_id
    WHERE e.date_separated >= CURRENT_DATE - INTERVAL '30 days'
    ORDER BY e.date_separated DESC
    LIMIT 10
 $sql$,
 '[{"label":"Employee","field":"employee","type":"text"},
   {"label":"Dept","field":"department","type":"muted"},
   {"label":"Sep","field":"separated","type":"mono"}]'::jsonb,
 '/employees', 'Directory →',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE']::VARCHAR(20)[], FALSE, 40, 10),

('UPCOMING_RETIREMENTS',
 'Upcoming Retirements (12 mo)',
 'Employees turning 65 in the next 12 months — plan knowledge transfer.',
 'Workforce', '🎓', 'list',
 $sql$
   SELECT e.first_name || ' ' || e.last_name                     AS employee,
          COALESCE(d.name, '—')                                   AS department,
          TO_CHAR(e.date_of_birth + INTERVAL '65 years', 'Mon DD, YYYY') AS retires_on
     FROM core.employees e
     LEFT JOIN core.departments d ON d.id = e.department_id
    WHERE e.is_active = TRUE
      AND e.date_of_birth IS NOT NULL
      AND (e.date_of_birth + INTERVAL '65 years')
          BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '12 months'
    ORDER BY e.date_of_birth + INTERVAL '65 years'
    LIMIT 10
 $sql$,
 '[{"label":"Employee","field":"employee","type":"text"},
   {"label":"Dept","field":"department","type":"muted"},
   {"label":"Retires","field":"retires_on","type":"mono"}]'::jsonb,
 '/retirement', 'Open tracker →',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE']::VARCHAR(20)[], FALSE, 50, 10),

-- ══ Attendance / Leave ═══════════════════════════════════════
('RECENT_LEAVE_REQUESTS',
 'Recent Leave Requests',
 'Latest leave filings across the org.',
 'Leave', '☂️', 'list',
 $sql$
   SELECT e.first_name || ' ' || e.last_name AS employee,
          lt.name                             AS leave_type,
          TO_CHAR(lr.date_from, 'Mon DD') || ' – ' || TO_CHAR(lr.date_to, 'Mon DD') AS dates,
          lr.status                           AS status
     FROM leave_mgmt.lv_requests lr
     JOIN leave_mgmt.lv_types lt ON lt.id = lr.leave_type_id
     JOIN core.employees e       ON e.id = lr.employee_id
    ORDER BY lr.created_at DESC
    LIMIT 8
 $sql$,
 '[{"label":"Employee","field":"employee","type":"text"},
   {"label":"Type","field":"leave_type","type":"muted"},
   {"label":"Dates","field":"dates","type":"mono"},
   {"label":"Status","field":"status","type":"badge","badge_map":{"PENDING":"amber","APPROVED":"green","REJECTED":"red","CANCELLED":"gray"}}]'::jsonb,
 '/leave/requests', 'All requests →',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE']::VARCHAR(20)[], TRUE, 60, 8),

('PENDING_APPROVALS',
 'Pending Approvals',
 'Workflow items awaiting your action or team action.',
 'Operations', '⏳', 'list',
 $sql$
   SELECT wd.name                                 AS workflow,
          wi.reference_no                         AS ref,
          COALESCE(u.display_name, '—')           AS initiated_by,
          ROUND(EXTRACT(EPOCH FROM (NOW() - wi.created_at)) / 3600)::int AS hours_pending
     FROM workflow.workflow_instances wi
     JOIN workflow.workflow_definitions wd ON wd.id = wi.definition_id
     LEFT JOIN core.users u ON u.id = wi.initiated_by
    WHERE wi.status = 'IN_PROGRESS'
    ORDER BY wi.created_at
    LIMIT 10
 $sql$,
 '[{"label":"Workflow","field":"workflow","type":"text"},
   {"label":"Ref","field":"ref","type":"mono"},
   {"label":"Initiator","field":"initiated_by","type":"muted"},
   {"label":"Hrs","field":"hours_pending","type":"int"}]'::jsonb,
 '/workflow/', 'All approvals →',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE']::VARCHAR(20)[], TRUE, 70, 10),

('LATE_TODAY',
 'Late Today',
 'Employees who checked in after their shift start time.',
 'Attendance', '⏰', 'list',
 $sql$
   SELECT e.first_name || ' ' || e.last_name   AS employee,
          TO_CHAR(ad.time_in, 'HH24:MI')       AS time_in,
          ROUND(ad.hours_late::numeric, 2)     AS hrs_late
     FROM attendance.att_daily ad
     JOIN core.employees e ON e.id = ad.employee_id
    WHERE ad.work_date = CURRENT_DATE
      AND ad.status = 'LATE'
    ORDER BY ad.hours_late DESC
    LIMIT 10
 $sql$,
 '[{"label":"Employee","field":"employee","type":"text"},
   {"label":"In","field":"time_in","type":"mono"},
   {"label":"Late","field":"hrs_late","type":"text"}]'::jsonb,
 '/attendance/dtr', 'View DTR →',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE']::VARCHAR(20)[], FALSE, 80, 10),

('ON_LEAVE_TODAY',
 'On Leave Today',
 'Employees out on approved leave today — know who''s unavailable.',
 'Leave', '🏖️', 'list',
 $sql$
   SELECT e.first_name || ' ' || e.last_name AS employee,
          lt.name                             AS leave_type,
          TO_CHAR(lr.date_to, 'Mon DD')       AS back_on
     FROM leave_mgmt.lv_requests lr
     JOIN leave_mgmt.lv_types lt ON lt.id = lr.leave_type_id
     JOIN core.employees e       ON e.id = lr.employee_id
    WHERE lr.status = 'APPROVED'
      AND CURRENT_DATE BETWEEN lr.date_from AND lr.date_to
    ORDER BY e.last_name
    LIMIT 10
 $sql$,
 '[{"label":"Employee","field":"employee","type":"text"},
   {"label":"Type","field":"leave_type","type":"muted"},
   {"label":"Back","field":"back_on","type":"mono"}]'::jsonb,
 '/leave/requests?status=APPROVED', 'Leave register →',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE']::VARCHAR(20)[], FALSE, 90, 10),

('OT_FILINGS_PENDING',
 'Overtime Filings Pending',
 'OT requests awaiting approval.',
 'Attendance', '⏱️', 'list',
 $sql$
   SELECT e.first_name || ' ' || e.last_name AS employee,
          TO_CHAR(ot.request_date, 'Mon DD') AS for_date,
          ROUND(ot.expected_ot_hours::numeric, 1) AS hrs
     FROM attendance.att_overtime_requests ot
     JOIN core.employees e ON e.id = ot.employee_id
    WHERE ot.status = 'PENDING'
    ORDER BY ot.created_at DESC
    LIMIT 10
 $sql$,
 '[{"label":"Employee","field":"employee","type":"text"},
   {"label":"Date","field":"for_date","type":"mono"},
   {"label":"Hrs","field":"hrs","type":"text"}]'::jsonb,
 '/attendance/overtime', 'All OT →',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE']::VARCHAR(20)[], FALSE, 100, 10),

-- ══ Payroll ═══════════════════════════════════════════════════
('PAYROLL_SNAPSHOT',
 'Payroll Snapshot',
 'Most recent active pay run — totals + status.',
 'Payroll', '💰', 'kv',
 $sql$
   SELECT COALESCE(pp.period_code, '—')                           AS "Period",
          COALESCE(TO_CHAR(pp.date_from, 'Mon DD') || ' – ' || TO_CHAR(pp.date_to, 'Mon DD'), '—') AS "Cutoff",
          COALESCE(pr.status, '—')                                AS "Status",
          COALESCE(pr.total_employees, 0)::text                   AS "Employees",
          '₱ ' || COALESCE(TO_CHAR(pr.total_net, 'FM999,999,999'), '0') AS "Net Pay"
     FROM payroll.pay_runs pr
     JOIN payroll.pay_periods pp ON pp.id = pr.period_id
    ORDER BY pp.date_from DESC
    LIMIT 1
 $sql$,
 '[]'::jsonb,
 '/payroll/runs', 'View pay runs →',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE']::VARCHAR(20)[], TRUE, 110, 1),

('ACTIVE_LOANS_TOP',
 'Top Active Loans',
 'Employees with the highest outstanding loan balances.',
 'Payroll', '💳', 'list',
 $sql$
   SELECT e.first_name || ' ' || e.last_name AS employee,
          pl.loan_type                        AS type,
          '₱ ' || TO_CHAR(pl.outstanding_balance, 'FM999,999,999') AS balance
     FROM payroll.pay_loans pl
     JOIN core.employees e ON e.id = pl.employee_id
    WHERE pl.status = 'ACTIVE'
    ORDER BY pl.outstanding_balance DESC
    LIMIT 10
 $sql$,
 '[{"label":"Employee","field":"employee","type":"text"},
   {"label":"Type","field":"type","type":"muted"},
   {"label":"Balance","field":"balance","type":"mono"}]'::jsonb,
 '/payroll/loans', 'All loans →',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE']::VARCHAR(20)[], FALSE, 120, 10),

('UPCOMING_PAY_PERIODS',
 'Upcoming Pay Periods',
 'Pay periods scheduled within the next 60 days.',
 'Payroll', '📅', 'list',
 $sql$
   SELECT pp.period_code                           AS code,
          TO_CHAR(pp.date_from, 'Mon DD') || ' – ' || TO_CHAR(pp.date_to, 'Mon DD') AS dates,
          COALESCE(TO_CHAR(pp.payment_date, 'Mon DD'), '—') AS pay_date,
          pp.status                                AS status
     FROM payroll.pay_periods pp
    WHERE pp.date_from BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '60 days'
    ORDER BY pp.date_from
    LIMIT 10
 $sql$,
 '[{"label":"Code","field":"code","type":"mono"},
   {"label":"Period","field":"dates","type":"muted"},
   {"label":"Pay","field":"pay_date","type":"mono"},
   {"label":"Status","field":"status","type":"badge","badge_map":{"OPEN":"green","CLOSED":"gray","FUTURE":"blue"}}]'::jsonb,
 '/admin/reference-data/pay_periods', 'Manage →',
 ARRAY['SUPER_ADMIN','HR_ADMIN']::VARCHAR(20)[], FALSE, 130, 10),

-- ══ Talent / Recruitment ══════════════════════════════════════
('OPEN_REQUISITIONS',
 'Open Requisitions',
 'Hiring requisitions currently open across the org.',
 'Talent', '📋', 'list',
 $sql$
   SELECT r.reference_no                     AS ref,
          COALESCE(p.title, '—')              AS position,
          COALESCE(d.name, '—')               AS department,
          r.headcount                          AS need,
          r.status                             AS status
     FROM recruitment.rec_requisitions r
     LEFT JOIN core.positions  p ON p.id = r.position_id
     LEFT JOIN core.departments d ON d.id = r.department_id
    WHERE r.status NOT IN ('CANCELLED','FILLED','CLOSED')
    ORDER BY r.created_at DESC
    LIMIT 10
 $sql$,
 '[{"label":"Ref","field":"ref","type":"mono"},
   {"label":"Position","field":"position","type":"text"},
   {"label":"Dept","field":"department","type":"muted"},
   {"label":"HC","field":"need","type":"int"},
   {"label":"Status","field":"status","type":"badge","badge_map":{"DRAFT":"gray","PENDING_APPROVAL":"amber","APPROVED":"green","PUBLISHED":"blue"}}]'::jsonb,
 '/rsp/requisitions', 'All requisitions →',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE']::VARCHAR(20)[], TRUE, 140, 10),

('RECENT_IPCR_SUBMISSIONS',
 'Recent IPCR Submissions',
 'Finalized performance reviews from the current cycle.',
 'Talent', '⭐', 'list',
 $sql$
   SELECT e.first_name || ' ' || e.last_name AS employee,
          ips.adjectival_rating               AS rating,
          ROUND(ips.final_numerical_rating::numeric, 2) AS score,
          TO_CHAR(ips.approved_at, 'Mon DD')  AS approved
     FROM performance.perf_ipcr_summary ips
     JOIN core.employees e ON e.id = ips.employee_id
    WHERE ips.approved_at IS NOT NULL
    ORDER BY ips.approved_at DESC
    LIMIT 10
 $sql$,
 '[{"label":"Employee","field":"employee","type":"text"},
   {"label":"Rating","field":"rating","type":"muted"},
   {"label":"Score","field":"score","type":"mono"},
   {"label":"Approved","field":"approved","type":"mono"}]'::jsonb,
 '/performance', 'All IPCR →',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE']::VARCHAR(20)[], FALSE, 150, 10),

('HIGH_RISK_EMPLOYEES',
 'High Attrition Risk',
 'Employees flagged HIGH by the AI risk scorer — retention priority.',
 'Talent', '⚠️', 'list',
 $sql$
   WITH latest AS (
     SELECT DISTINCT ON (employee_id) employee_id, risk_score, risk_level, score_date
       FROM ai.ai_risk_scores
      WHERE risk_type = 'ATTRITION'
      ORDER BY employee_id, score_date DESC
   )
   SELECT e.first_name || ' ' || e.last_name AS employee,
          COALESCE(d.name, '—')              AS department,
          ROUND(l.risk_score::numeric, 2)    AS score,
          l.risk_level                        AS tier
     FROM latest l
     JOIN core.employees e       ON e.id = l.employee_id
     LEFT JOIN core.departments d ON d.id = e.department_id
    WHERE l.risk_level = 'HIGH' AND e.is_active = TRUE
    ORDER BY l.risk_score DESC
    LIMIT 10
 $sql$,
 '[{"label":"Employee","field":"employee","type":"text"},
   {"label":"Dept","field":"department","type":"muted"},
   {"label":"Score","field":"score","type":"mono"},
   {"label":"Tier","field":"tier","type":"badge","badge_map":{"HIGH":"red","MEDIUM":"amber","LOW":"green"}}]'::jsonb,
 '/reports/attrition-risk', 'Risk dashboard →',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE']::VARCHAR(20)[], FALSE, 160, 10),

('UPCOMING_TRAININGS',
 'Upcoming Training Sessions',
 'Training sessions scheduled in the next 30 days.',
 'Talent', '🎓', 'list',
 $sql$
   SELECT p.title                             AS program,
          TO_CHAR(s.session_date, 'Mon DD')   AS on_date,
          COALESCE(s.venue, '—')              AS venue,
          COALESCE(s.max_participants, 0)     AS capacity
     FROM learning.lrn_sessions s
     JOIN learning.lrn_programs p ON p.id = s.program_id
    WHERE s.session_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
    ORDER BY s.session_date
    LIMIT 10
 $sql$,
 '[{"label":"Program","field":"program","type":"text"},
   {"label":"Date","field":"on_date","type":"mono"},
   {"label":"Venue","field":"venue","type":"muted"},
   {"label":"Cap","field":"capacity","type":"int"}]'::jsonb,
 '/learning/sessions', 'All sessions →',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE']::VARCHAR(20)[], FALSE, 170, 10),

-- ══ Health & Operations ═══════════════════════════════════════
('EXPIRING_HEALTH_CERTS',
 'Expiring Health Certificates',
 'Health certs expiring within 90 days — schedule renewals.',
 'Health', '🔔', 'list',
 $sql$
   SELECT e.first_name || ' ' || e.last_name AS employee,
          hc.certificate_type                 AS type,
          TO_CHAR(hc.expiry_date, 'Mon DD, YYYY') AS expires
     FROM health.health_certificates hc
     JOIN core.employees e ON e.id = hc.employee_id
    WHERE hc.status = 'ACTIVE'
      AND hc.expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '90 days'
    ORDER BY hc.expiry_date
    LIMIT 10
 $sql$,
 '[{"label":"Employee","field":"employee","type":"text"},
   {"label":"Type","field":"type","type":"muted"},
   {"label":"Expires","field":"expires","type":"mono"}]'::jsonb,
 '/health/certificates?status=ACTIVE', 'All certs →',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE']::VARCHAR(20)[], FALSE, 180, 10),

('ACTIVE_WELLNESS_PROGRAMS',
 'Active Wellness Programs',
 'Ongoing wellness programs with enrollment counts.',
 'Health', '🏃', 'list',
 $sql$
   SELECT wp.name                              AS program,
          COALESCE(wp.program_type, '—')       AS type,
          COUNT(we.id)::int                     AS enrolled
     FROM health.wellness_programs wp
     LEFT JOIN health.wellness_enrollments we ON we.program_id = wp.id
    WHERE wp.status IN ('ACTIVE','PLANNED')
    GROUP BY wp.id
    ORDER BY enrolled DESC
    LIMIT 10
 $sql$,
 '[{"label":"Program","field":"program","type":"text"},
   {"label":"Type","field":"type","type":"muted"},
   {"label":"Enrolled","field":"enrolled","type":"int"}]'::jsonb,
 '/health/wellness', 'All programs →',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE']::VARCHAR(20)[], FALSE, 190, 10),

('OVERDUE_TASKS',
 'Overdue Tasks',
 'Tasks past their due date — cleanup priority.',
 'Operations', '🚨', 'list',
 $sql$
   SELECT COALESCE(NULLIF(ti.title, ''), ti.task_type) AS task,
          ti.task_type                                 AS task_type,
          ti.priority                                  AS priority,
          TO_CHAR(ti.due_date, 'Mon DD')               AS due
     FROM core.task_inbox ti
    WHERE ti.status = 'PENDING'
      AND ti.due_date IS NOT NULL
      AND ti.due_date < CURRENT_DATE
    ORDER BY ti.due_date
    LIMIT 10
 $sql$,
 '[{"label":"Task","field":"task","type":"text"},
   {"label":"Type","field":"task_type","type":"muted"},
   {"label":"Due","field":"due","type":"mono"},
   {"label":"Pri","field":"priority","type":"badge","badge_map":{"URGENT":"red","HIGH":"amber","NORMAL":"blue","LOW":"gray"}}]'::jsonb,
 '/me/inbox', 'Inbox →',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE']::VARCHAR(20)[], FALSE, 200, 10)

ON CONFLICT (code) DO UPDATE SET
    title          = EXCLUDED.title,
    description    = EXCLUDED.description,
    category       = EXCLUDED.category,
    icon           = EXCLUDED.icon,
    render_mode    = EXCLUDED.render_mode,
    base_sql       = EXCLUDED.base_sql,
    columns_meta   = EXCLUDED.columns_meta,
    link_url       = EXCLUDED.link_url,
    link_label     = EXCLUDED.link_label,
    required_roles = EXCLUDED.required_roles,
    default_pinned = EXCLUDED.default_pinned,
    sort_order     = EXCLUDED.sort_order,
    max_rows       = EXCLUDED.max_rows,
    is_active      = EXCLUDED.is_active,
    updated_at     = NOW();


-- ── Register the management page ───────────────────────────────
INSERT INTO core.page_registry
    (path, title, module, nav_group, nav_label, nav_icon, nav_order, is_visible)
VALUES
    ('/dashboard/widgets', 'Manage Widgets', 'core',
     'Self-Service', 'Manage Widgets', 'layout-grid', 13, FALSE)
ON CONFLICT (path) DO UPDATE SET title = EXCLUDED.title;

INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
  FROM core.page_registry p
  CROSS JOIN (VALUES ('SUPER_ADMIN'),('HR_ADMIN'),('MANAGER'),('EMPLOYEE'),('EXECUTIVE')) AS r(role_code)
 WHERE p.path = '/dashboard/widgets'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;
