-- ================================================================
-- HCM360 — 67: INSIGHTS LIBRARY + PERSONAL ANALYTICS DASHBOARD
--
-- Tables:
--   analytics.insight_library  — catalog of best-practice canned insights
--                                (each row = title, chart_type, base_sql,
--                                 required_roles, default_pinned)
--   analytics.user_insights    — per-user pinned list (many-to-many)
--
-- Pages registered:
--   /analytics                  → user's personalized Chart.js dashboard
--   /admin/insights-library     → admin page to tick/untick insights
--
-- Seeds: 17 best-practice insights across 5 categories
--        5 default-pinned so the dashboard is never empty on first visit
-- ================================================================
SET search_path TO analytics, core, public;


-- ── Library ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS analytics.insight_library (
    id              BIGSERIAL    PRIMARY KEY,
    code            VARCHAR(60)  UNIQUE NOT NULL,
    title           VARCHAR(160) NOT NULL,
    description     TEXT,
    category        VARCHAR(40)  NOT NULL,
    icon            VARCHAR(8)   NOT NULL DEFAULT '📊',
    chart_type      VARCHAR(20)  NOT NULL DEFAULT 'bar'
                    CHECK (chart_type IN ('bar','horizontalBar','line','doughnut','pie')),
    base_sql        TEXT         NOT NULL,
    color_scheme    VARCHAR(20)  NOT NULL DEFAULT 'indigo',
    required_roles  VARCHAR(20)[] NOT NULL
                    DEFAULT ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE']::VARCHAR(20)[],
    default_pinned  BOOLEAN      NOT NULL DEFAULT FALSE,
    sort_order      INT          NOT NULL DEFAULT 100,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_insight_lib_cat     ON analytics.insight_library (category, sort_order);
CREATE INDEX IF NOT EXISTS idx_insight_lib_active  ON analytics.insight_library (is_active);


-- ── Per-user pinned selections ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS analytics.user_insights (
    user_id         BIGINT      NOT NULL REFERENCES core.users(id) ON DELETE CASCADE,
    insight_code    VARCHAR(60) NOT NULL REFERENCES analytics.insight_library(code) ON DELETE CASCADE,
    sort_order      INT         NOT NULL DEFAULT 100,
    added_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, insight_code)
);
CREATE INDEX IF NOT EXISTS idx_user_insights_user ON analytics.user_insights (user_id, sort_order);


-- ── 17 best-practice seeds ──────────────────────────────────────────
INSERT INTO analytics.insight_library
    (code, title, description, category, icon, chart_type, color_scheme,
     required_roles, default_pinned, sort_order, base_sql)
VALUES

-- ═══ Workforce ═════════════════════════════════════════════════════
('HEADCOUNT_BY_DEPT',
 'Headcount by Department',
 'Active employee count per department — the most common HR snapshot.',
 'Workforce', '👥', 'bar', 'indigo',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE']::VARCHAR(20)[], TRUE, 10,
 $sql$
   SELECT COALESCE(d.name, 'Unassigned') AS label,
          COUNT(e.id)::BIGINT             AS value
     FROM core.employees e
     LEFT JOIN core.departments d ON d.id = e.department_id
    WHERE e.is_active = TRUE
      AND (e.date_separated IS NULL OR e.date_separated > CURRENT_DATE)
    GROUP BY d.name
    ORDER BY value DESC
    LIMIT 15
 $sql$),

('GENDER_DIVERSITY',
 'Gender Diversity',
 'Male / Female / other — overall workforce composition for EEO reports.',
 'Workforce', '⚤', 'doughnut', 'rose',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE']::VARCHAR(20)[], TRUE, 20,
 $sql$
   SELECT COALESCE(NULLIF(TRIM(gender), ''), 'Unspecified') AS label,
          COUNT(*)::BIGINT                                  AS value
     FROM core.employees
    WHERE is_active = TRUE
    GROUP BY 1
    ORDER BY value DESC
 $sql$),

('AGE_DISTRIBUTION',
 'Age Distribution (5-year buckets)',
 'Workforce age pyramid — spots aging cohorts and succession pressure.',
 'Workforce', '📊', 'bar', 'sky',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE']::VARCHAR(20)[], TRUE, 30,
 $sql$
   WITH ages AS (
     SELECT EXTRACT(YEAR FROM AGE(date_of_birth))::INT AS age
       FROM core.employees
      WHERE is_active = TRUE AND date_of_birth IS NOT NULL
   ),
   buckets AS (
     SELECT CASE
              WHEN age < 25 THEN '<25'
              WHEN age BETWEEN 25 AND 29 THEN '25-29'
              WHEN age BETWEEN 30 AND 34 THEN '30-34'
              WHEN age BETWEEN 35 AND 39 THEN '35-39'
              WHEN age BETWEEN 40 AND 44 THEN '40-44'
              WHEN age BETWEEN 45 AND 49 THEN '45-49'
              WHEN age BETWEEN 50 AND 54 THEN '50-54'
              WHEN age BETWEEN 55 AND 59 THEN '55-59'
              ELSE '60+'
            END AS label
       FROM ages
   )
   SELECT label, COUNT(*)::BIGINT AS value
     FROM buckets
    GROUP BY label
    ORDER BY label
 $sql$),

('TENURE_BY_DEPT',
 'Average Tenure by Department (years)',
 'How long people stay by department — a proxy for engagement.',
 'Workforce', '📅', 'horizontalBar', 'emerald',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE']::VARCHAR(20)[], FALSE, 40,
 $sql$
   SELECT COALESCE(d.name, 'Unassigned') AS label,
          ROUND(AVG(EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.date_hired)))::numeric, 1) AS value
     FROM core.employees e
     LEFT JOIN core.departments d ON d.id = e.department_id
    WHERE e.is_active = TRUE AND e.date_hired IS NOT NULL
    GROUP BY d.name
    ORDER BY value DESC NULLS LAST
    LIMIT 12
 $sql$),

('EMPLOYMENT_TYPE_MIX',
 'Employment Type Mix',
 'Permanent / Casual / Contractual / JO split (important for LGU plantilla).',
 'Workforce', '🏷️', 'doughnut', 'mixed',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE']::VARCHAR(20)[], FALSE, 50,
 $sql$
   SELECT COALESCE(et.name, 'Unspecified') AS label,
          COUNT(*)::BIGINT                  AS value
     FROM core.employees e
     LEFT JOIN core.employment_types et ON et.id = e.employment_type_id
    WHERE e.is_active = TRUE
    GROUP BY et.name
    ORDER BY value DESC
 $sql$),

('RETIREMENT_RUNWAY',
 'Retirement Runway (next 24 months)',
 'Employees approaching mandatory retirement age 65 — plan knowledge transfer.',
 'Workforce', '🎓', 'bar', 'amber',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE']::VARCHAR(20)[], FALSE, 60,
 $sql$
   WITH monthly AS (
     SELECT TO_CHAR(
              date_of_birth + INTERVAL '65 year',
              'YYYY-MM'
            ) AS label,
            e.id
       FROM core.employees e
      WHERE e.is_active = TRUE
        AND e.date_of_birth IS NOT NULL
        AND (e.date_of_birth + INTERVAL '65 year') BETWEEN CURRENT_DATE
                                                      AND CURRENT_DATE + INTERVAL '24 months'
   )
   SELECT label, COUNT(*)::BIGINT AS value
     FROM monthly
    GROUP BY label
    ORDER BY label
 $sql$),

-- ═══ Attendance & Leave ═══════════════════════════════════════════
('ATTENDANCE_RATE_30D',
 'Attendance Rate — Last 30 Days',
 'Present vs expected, computed daily over the last 30 days.',
 'Attendance', '📆', 'line', 'indigo',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE']::VARCHAR(20)[], TRUE, 70,
 $sql$
   SELECT TO_CHAR(work_date, 'MM-DD') AS label,
          ROUND(
            100.0 * COUNT(*) FILTER (WHERE status IN ('PRESENT','LATE','UNDERTIME')) /
            NULLIF(COUNT(*) FILTER (WHERE NOT is_restday), 0),
            1
          ) AS value
     FROM attendance.att_daily
    WHERE work_date BETWEEN CURRENT_DATE - INTERVAL '30 days' AND CURRENT_DATE
    GROUP BY work_date
    ORDER BY work_date
 $sql$),

('OT_HOURS_BY_DEPT_30D',
 'Overtime Hours by Department (last 30 days)',
 'Which departments are accruing the most OT — budget & burnout signal.',
 'Attendance', '⏱️', 'bar', 'amber',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE']::VARCHAR(20)[], FALSE, 80,
 $sql$
   SELECT COALESCE(d.name, 'Unassigned') AS label,
          ROUND(SUM(ad.hours_overtime)::numeric, 1) AS value
     FROM attendance.att_daily ad
     JOIN core.employees e   ON e.id = ad.employee_id
     LEFT JOIN core.departments d ON d.id = e.department_id
    WHERE ad.work_date BETWEEN CURRENT_DATE - INTERVAL '30 days' AND CURRENT_DATE
      AND ad.hours_overtime > 0
    GROUP BY d.name
    ORDER BY value DESC
    LIMIT 12
 $sql$),

('LEAVE_UTIL_YTD',
 'Leave Utilization YTD (by type)',
 'Leave days taken by type year-to-date — spotlights under/over use.',
 'Attendance', '☂️', 'bar', 'sky',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE']::VARCHAR(20)[], TRUE, 90,
 $sql$
   SELECT lt.name AS label,
          ROUND(SUM(lr.total_days)::numeric, 1) AS value
     FROM leave_mgmt.lv_requests lr
     JOIN leave_mgmt.lv_types lt ON lt.id = lr.leave_type_id
    WHERE lr.status = 'APPROVED'
      AND lr.date_from >= DATE_TRUNC('year', CURRENT_DATE)
    GROUP BY lt.name
    ORDER BY value DESC
    LIMIT 10
 $sql$),

-- ═══ Talent ════════════════════════════════════════════════════════
('TRAINING_COMPLETION',
 'Training Completion Rate by Program (90d)',
 'Completion percentage per training program — effectiveness gauge.',
 'Talent', '🎓', 'bar', 'emerald',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE']::VARCHAR(20)[], FALSE, 100,
 $sql$
   SELECT p.title AS label,
          ROUND(
            100.0 * COUNT(*) FILTER (WHERE le.status = 'COMPLETED') /
            NULLIF(COUNT(*), 0),
            0
          ) AS value
     FROM learning.lrn_enrollments le
     JOIN learning.lrn_sessions    s ON s.id = le.session_id
     JOIN learning.lrn_programs    p ON p.id = s.program_id
    WHERE le.created_at >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY p.title
   HAVING COUNT(*) > 0
    ORDER BY value DESC NULLS LAST
    LIMIT 10
 $sql$),

('IPCR_RATING_DIST',
 'IPCR Rating Distribution',
 'Distribution of IPCR adjectival ratings in the most recent cycle.',
 'Talent', '⭐', 'bar', 'indigo',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE']::VARCHAR(20)[], FALSE, 110,
 $sql$
   SELECT COALESCE(adjectival_rating, 'Unrated') AS label,
          COUNT(*)::BIGINT                        AS value
     FROM performance.perf_ipcr_summary
    GROUP BY adjectival_rating
    ORDER BY value DESC
 $sql$),

('ATTRITION_RISK_DIST',
 'Attrition Risk Distribution',
 'AI-scored retention risk tiers — HIGH / MEDIUM / LOW.',
 'Talent', '⚠️', 'doughnut', 'rose',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE']::VARCHAR(20)[], TRUE, 120,
 $sql$
   SELECT risk_level AS label,
          COUNT(*)::BIGINT AS value
     FROM (
       SELECT DISTINCT ON (employee_id) employee_id, risk_level
         FROM ai.ai_risk_scores
        WHERE risk_type = 'ATTRITION'
        ORDER BY employee_id, score_date DESC
     ) latest
    GROUP BY risk_level
    ORDER BY CASE risk_level WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END
 $sql$),

('OPEN_REQS_BY_STATUS',
 'Open Requisitions by Status',
 'Pipeline visibility for hiring managers and HR.',
 'Talent', '📋', 'doughnut', 'sky',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE']::VARCHAR(20)[], FALSE, 130,
 $sql$
   SELECT status AS label,
          COUNT(*)::BIGINT AS value
     FROM recruitment.rec_requisitions
    WHERE status NOT IN ('CANCELLED','FILLED','CLOSED')
    GROUP BY status
    ORDER BY value DESC
 $sql$),

-- ═══ Payroll ═══════════════════════════════════════════════════════
('PAYROLL_COST_BY_DEPT',
 'Payroll Cost by Department (YTD)',
 'Gross payroll cost per department YTD — budget governance.',
 'Payroll', '💰', 'bar', 'emerald',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE']::VARCHAR(20)[], FALSE, 140,
 $sql$
   SELECT COALESCE(d.name, 'Unassigned') AS label,
          ROUND(SUM(ep.gross_pay)::numeric, 0) AS value
     FROM payroll.pay_employee_payroll ep
     JOIN core.employees e   ON e.id = ep.employee_id
     JOIN payroll.pay_runs pr ON pr.id = ep.run_id
     JOIN payroll.pay_periods pp ON pp.id = pr.period_id
     LEFT JOIN core.departments d ON d.id = e.department_id
    WHERE pp.date_from >= DATE_TRUNC('year', CURRENT_DATE)
      AND pr.status = 'POSTED'
    GROUP BY d.name
    ORDER BY value DESC NULLS LAST
    LIMIT 12
 $sql$),

('LOAN_PORTFOLIO',
 'Loan Portfolio by Type',
 'Outstanding loan balance by source (SSS · Pag-IBIG · GSIS · Coop · Cash Advance).',
 'Payroll', '💳', 'doughnut', 'amber',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE']::VARCHAR(20)[], FALSE, 150,
 $sql$
   SELECT loan_type AS label,
          ROUND(SUM(outstanding_balance)::numeric, 0) AS value
     FROM payroll.pay_loans
    WHERE status = 'ACTIVE'
    GROUP BY loan_type
    ORDER BY value DESC
 $sql$),

-- ═══ Operations ════════════════════════════════════════════════════
('PENDING_TASKS_BY_TYPE',
 'Pending Tasks by Type',
 'What kinds of work are outstanding across the platform.',
 'Operations', '📥', 'doughnut', 'indigo',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE']::VARCHAR(20)[], FALSE, 160,
 $sql$
   SELECT COALESCE(NULLIF(task_type,''), 'UNCATEGORIZED') AS label,
          COUNT(*)::BIGINT AS value
     FROM core.task_inbox
    WHERE status = 'PENDING'
    GROUP BY task_type
    ORDER BY value DESC
    LIMIT 10
 $sql$),

('CERT_EXPIRY_RUNWAY',
 'Certificate Expiry Runway (next 90 days)',
 'Health certificates expiring soon — schedule renewals before they lapse.',
 'Operations', '🔔', 'bar', 'rose',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE']::VARCHAR(20)[], FALSE, 170,
 $sql$
   SELECT TO_CHAR(
            DATE_TRUNC('week', expiry_date),
            'MM-DD'
          ) AS label,
          COUNT(*)::BIGINT AS value
     FROM health.health_certificates
    WHERE status = 'ACTIVE'
      AND expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '90 days'
    GROUP BY DATE_TRUNC('week', expiry_date)
    ORDER BY DATE_TRUNC('week', expiry_date)
 $sql$)

ON CONFLICT (code) DO UPDATE SET
    title          = EXCLUDED.title,
    description    = EXCLUDED.description,
    category       = EXCLUDED.category,
    icon           = EXCLUDED.icon,
    chart_type     = EXCLUDED.chart_type,
    color_scheme   = EXCLUDED.color_scheme,
    required_roles = EXCLUDED.required_roles,
    default_pinned = EXCLUDED.default_pinned,
    sort_order     = EXCLUDED.sort_order,
    base_sql       = EXCLUDED.base_sql,
    updated_at     = NOW();


-- ── Page + feature registry ─────────────────────────────────────────
INSERT INTO core.page_registry
    (path, title, module, nav_group, nav_label, nav_icon, nav_order, is_visible)
VALUES
    ('/analytics',              'My Analytics',     'analytics', 'Analytics',      'My Analytics',     'bar-chart-3', 45, TRUE),
    ('/admin/insights-library', 'Insights Library', 'admin',     'Administration', 'Insights Library', 'sparkles',     97, TRUE)
ON CONFLICT (path) DO NOTHING;


-- Role grants — /analytics is visible to every role
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
  FROM core.page_registry p
  CROSS JOIN (VALUES ('SUPER_ADMIN'), ('HR_ADMIN'), ('MANAGER'), ('EMPLOYEE'), ('EXECUTIVE')) AS r(role_code)
 WHERE p.path = '/analytics'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;


-- /admin/insights-library only for admins
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
  FROM core.page_registry p
  CROSS JOIN (VALUES ('SUPER_ADMIN'), ('HR_ADMIN')) AS r(role_code)
 WHERE p.path = '/admin/insights-library'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, FALSE
  FROM core.page_registry p
  CROSS JOIN (VALUES ('MANAGER'), ('EMPLOYEE'), ('EXECUTIVE')) AS r(role_code)
 WHERE p.path = '/admin/insights-library'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = FALSE;


-- Feature flag
INSERT INTO core.feature_registry
    (code, name, description, module, is_enabled, feature_type, action_type, page_path)
VALUES
    ('INSIGHTS_TOGGLE', 'Toggle Insights',
     'Pin/unpin insights on the personal Analytics page',
     'analytics', TRUE, 'ACTION', 'EDIT', '/admin/insights-library')
ON CONFLICT (code) DO NOTHING;

INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.role_code, f.id, TRUE
  FROM core.feature_registry f
  CROSS JOIN (VALUES ('SUPER_ADMIN'),('HR_ADMIN'),('MANAGER'),('EMPLOYEE'),('EXECUTIVE')) AS r(role_code)
 WHERE f.code = 'INSIGHTS_TOGGLE'
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = TRUE;
