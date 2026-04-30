-- ================================================================
-- HCM360 — 69: DASHBOARD LIBRARY (KPI TILES + USER PINS)
--
-- Goal:
--   Turn the dashboard into a personalizable tile library, mirroring
--   the Insights Library flow for /analytics. Any role-appropriate KPI
--   tile can be pinned/unpinned by each user from /dashboard/manage.
--
-- Changes:
--   • ALTER  core.dashboard_metrics — add `category` + `description`
--            columns so the library UI can bucket + explain each tile.
--   • CREATE core.user_dashboard_pins — per-user selections.
--   • SEED   15 more industry-standard HR-leader KPIs (new_hires_ytd,
--            turnover_rate_12m, avg_time_to_hire, etc.) so the library
--            is meaningful out of the box.
--   • REGISTER /dashboard/manage page + role grants.
-- ================================================================
SET search_path TO core, public;


-- ── Table changes ──────────────────────────────────────────────
ALTER TABLE core.dashboard_metrics
    ADD COLUMN IF NOT EXISTS category    VARCHAR(40) NOT NULL DEFAULT 'General',
    ADD COLUMN IF NOT EXISTS description TEXT;

-- Back-fill categories for existing rows
UPDATE core.dashboard_metrics SET category = 'Workforce',   description = COALESCE(description, label) WHERE module = 'core';
UPDATE core.dashboard_metrics SET category = 'Attendance',  description = COALESCE(description, label) WHERE module = 'attendance';
UPDATE core.dashboard_metrics SET category = 'Leave',       description = COALESCE(description, label) WHERE module = 'leave_mgmt';
UPDATE core.dashboard_metrics SET category = 'Operations',  description = COALESCE(description, label) WHERE module = 'workflow';
UPDATE core.dashboard_metrics SET category = 'Talent',      description = COALESCE(description, label) WHERE module IN ('analytics','recruitment','performance');
UPDATE core.dashboard_metrics SET category = 'Rewards',     description = COALESCE(description, label) WHERE module = 'rewards';
UPDATE core.dashboard_metrics SET category = 'Tasks',       description = COALESCE(description, label) WHERE module = 'ess_mss';


-- ── User pins ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS core.user_dashboard_pins (
    user_id      BIGINT       NOT NULL REFERENCES core.users(id) ON DELETE CASCADE,
    metric_code  VARCHAR(60)  NOT NULL REFERENCES core.dashboard_metrics(code) ON DELETE CASCADE,
    sort_order   INT          NOT NULL DEFAULT 100,
    pinned_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, metric_code)
);
CREATE INDEX IF NOT EXISTS idx_udp_user ON core.user_dashboard_pins (user_id, sort_order);


-- ── 15 industry-standard HR-leader KPIs ────────────────────────
INSERT INTO core.dashboard_metrics
    (code, label, icon, module, category, description, sql_query, filter_url, roles, sort_order, is_active)
VALUES

-- Workforce dynamics
('new_hires_ytd',
 'New Hires YTD', 'user-plus', 'core', 'Workforce',
 'Employees hired since Jan 1 — hiring velocity.',
 $sql$ SELECT COUNT(*) FROM core.employees
        WHERE date_hired >= DATE_TRUNC('year', CURRENT_DATE) $sql$,
 '/employees?status=ACTIVE',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE','MANAGER']::text[], 60, TRUE),

('separations_ytd',
 'Separations YTD', 'user-minus', 'core', 'Workforce',
 'Employees who left since Jan 1 — early warning for retention.',
 $sql$ SELECT COUNT(*) FROM core.employees
        WHERE date_separated >= DATE_TRUNC('year', CURRENT_DATE) $sql$,
 '/employees?status=RESIGNED',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE']::text[], 61, TRUE),

('turnover_rate_12m',
 'Turnover Rate (12 mo)', 'trending-down', 'analytics', 'Workforce',
 'Separations over avg headcount — industry benchmark < 10% annually.',
 $sql$ WITH sep AS (
           SELECT COUNT(*)::numeric AS n FROM core.employees
            WHERE date_separated BETWEEN CURRENT_DATE - INTERVAL '12 months' AND CURRENT_DATE
         ),
         hc  AS (
           SELECT COUNT(*)::numeric AS n FROM core.employees WHERE is_active = TRUE
         )
         SELECT ROUND(100 * sep.n / NULLIF(hc.n, 0), 1) AS val FROM sep, hc $sql$,
 '/reports/demographics',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE']::text[], 62, TRUE),

('avg_tenure_years',
 'Avg Tenure (yrs)', 'calendar', 'analytics', 'Workforce',
 'Average years of service across active employees — loyalty metric.',
 $sql$ SELECT ROUND(
            AVG(EXTRACT(YEAR FROM AGE(CURRENT_DATE, date_hired)))::numeric, 1
         ) FROM core.employees
        WHERE is_active = TRUE AND date_hired IS NOT NULL $sql$,
 '/reports/demographics',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE']::text[], 63, TRUE),

('female_workforce_pct',
 'Female Workforce %', 'users', 'analytics', 'Workforce',
 'Share of workforce that identifies as female — diversity KPI.',
 $sql$ SELECT ROUND(
            100.0 * COUNT(*) FILTER (WHERE LOWER(gender) = 'female')
          / NULLIF(COUNT(*) FILTER (WHERE gender IS NOT NULL), 0), 1
         ) FROM core.employees WHERE is_active = TRUE $sql$,
 '/reports/demographics',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE']::text[], 64, TRUE),

('manager_span_of_control',
 'Avg Manager Span', 'git-branch', 'analytics', 'Workforce',
 'Direct reports per manager — org-health gauge (ideal 5-8).',
 $sql$ WITH spans AS (
         SELECT immediate_supervisor_id, COUNT(*) AS n
           FROM core.employees
          WHERE is_active = TRUE AND immediate_supervisor_id IS NOT NULL
          GROUP BY immediate_supervisor_id
       )
       SELECT ROUND(AVG(n)::numeric, 1) FROM spans $sql$,
 '/orgchart',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE']::text[], 65, TRUE),

-- Talent / Recruitment velocity
('avg_time_to_hire',
 'Avg Time-to-Hire (d)', 'clock', 'recruitment', 'Talent',
 'Days from requisition approval to candidate appointment — speed metric.',
 $sql$ SELECT ROUND(
         AVG( EXTRACT(EPOCH FROM (a.created_at - r.approved_at))/86400 )::numeric, 1
       )
         FROM recruitment.rec_appointments a
         JOIN recruitment.rec_requisitions r ON r.id = a.requisition_id
        WHERE r.approved_at IS NOT NULL $sql$,
 '/rsp/requisitions',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE']::text[], 66, TRUE),

-- Learning & compliance
('training_compliance_pct',
 'Training Compliance %', 'book-open', 'learning', 'Talent',
 'Percentage of employees who completed at least one training this year.',
 $sql$ SELECT ROUND(
         100.0 * COUNT(DISTINCT le.employee_id)
              / NULLIF((SELECT COUNT(*) FROM core.employees WHERE is_active = TRUE), 0), 1
       )
         FROM learning.lrn_enrollments le
        WHERE le.status = 'COMPLETED'
          AND le.completion_date >= DATE_TRUNC('year', CURRENT_DATE) $sql$,
 '/learning',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE']::text[], 67, TRUE),

-- Payroll
('payroll_cost_mtd',
 'Payroll Cost MTD (₱)', 'banknote', 'payroll', 'Payroll',
 'Total gross payroll posted this month so far.',
 $sql$ SELECT COALESCE(SUM(ep.gross_pay), 0)::bigint
         FROM payroll.pay_employee_payroll ep
         JOIN payroll.pay_runs pr ON pr.id = ep.run_id
         JOIN payroll.pay_periods pp ON pp.id = pr.period_id
        WHERE pp.date_from >= DATE_TRUNC('month', CURRENT_DATE)
          AND pr.status = 'POSTED' $sql$,
 '/payroll',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE']::text[], 68, TRUE),

('active_loans_count',
 'Active Loans', 'credit-card', 'payroll', 'Payroll',
 'Active loan deductions on payroll (SSS / HDMF / GSIS / Coop / CA).',
 $sql$ SELECT COUNT(*) FROM payroll.pay_loans WHERE status = 'ACTIVE' $sql$,
 '/payroll/loans',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE']::text[], 69, TRUE),

-- Performance
('ipcr_completed_cycle',
 'IPCR Completed', 'star', 'performance', 'Talent',
 'Employees with a finalized IPCR for the most recent cycle.',
 $sql$ SELECT COUNT(*) FROM performance.perf_ipcr_summary
        WHERE approved_at IS NOT NULL
          AND cycle_id = (SELECT id FROM performance.perf_cycles ORDER BY id DESC LIMIT 1) $sql$,
 '/performance',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE','MANAGER']::text[], 70, TRUE),

-- Health & compliance
('health_cert_expiring_30d',
 'Certs Expiring (30d)', 'alert-triangle', 'health', 'Compliance',
 'Health certificates expiring within the next 30 days — renewal risk.',
 $sql$ SELECT COUNT(*) FROM health.health_certificates
        WHERE status = 'ACTIVE'
          AND expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days' $sql$,
 '/health/certificates',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER']::text[], 71, TRUE),

('wellness_enrollment_pct',
 'Wellness Participation %', 'heart', 'health', 'Wellness',
 'Share of employees enrolled in at least one active wellness program.',
 $sql$ SELECT ROUND(
         100.0 * COUNT(DISTINCT we.employee_id)
              / NULLIF((SELECT COUNT(*) FROM core.employees WHERE is_active = TRUE), 0), 1
       )
         FROM health.wellness_enrollments we
         JOIN health.wellness_programs wp ON wp.id = we.program_id
        WHERE wp.status IN ('ACTIVE','PLANNED') $sql$,
 '/health/wellness',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE']::text[], 72, TRUE),

-- Retirement runway
('retirement_next_12m',
 'Retirements (12 mo)', 'award', 'core', 'Workforce',
 'Employees reaching age 65 in the next 12 months — plan knowledge transfer.',
 $sql$ SELECT COUNT(*) FROM core.employees
        WHERE is_active = TRUE
          AND date_of_birth IS NOT NULL
          AND (date_of_birth + INTERVAL '65 years')
              BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '12 months' $sql$,
 '/retirement',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE']::text[], 73, TRUE),

-- Attrition risk headline
('attrition_scored_employees',
 'Employees Risk-Scored', 'shield', 'analytics', 'Talent',
 'How many active employees have a recent attrition risk score.',
 $sql$ SELECT COUNT(DISTINCT employee_id) FROM ai.ai_risk_scores
        WHERE risk_type = 'ATTRITION'
          AND score_date >= CURRENT_DATE - INTERVAL '30 days' $sql$,
 '/reports/attrition-risk',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE']::text[], 74, TRUE)

ON CONFLICT (code) DO UPDATE SET
    label       = EXCLUDED.label,
    icon        = EXCLUDED.icon,
    module      = EXCLUDED.module,
    category    = EXCLUDED.category,
    description = EXCLUDED.description,
    sql_query   = EXCLUDED.sql_query,
    filter_url  = EXCLUDED.filter_url,
    roles       = EXCLUDED.roles,
    sort_order  = EXCLUDED.sort_order,
    is_active   = EXCLUDED.is_active,
    updated_at  = NOW();


-- ── Page registry ──────────────────────────────────────────────
INSERT INTO core.page_registry
    (path, title, module, nav_group, nav_label, nav_icon, nav_order, is_visible)
VALUES
    ('/dashboard/manage', 'Manage Dashboard', 'core',
     'Self-Service', 'Manage Dashboard', 'layout-dashboard', 12, FALSE)
ON CONFLICT (path) DO UPDATE SET title = EXCLUDED.title;

-- Every role may access their own dashboard library
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
  FROM core.page_registry p
  CROSS JOIN (VALUES ('SUPER_ADMIN'),('HR_ADMIN'),('MANAGER'),('EMPLOYEE'),('EXECUTIVE')) AS r(role_code)
 WHERE p.path = '/dashboard/manage'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;
