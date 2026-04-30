-- ================================================================
-- HCM360 — 74: CSC IPCR / OPCR TEMPLATE LIBRARY
--
-- Goal:
--   Provide CSC-prescribed IPCR/OPCR starter templates so HR can spawn
--   a complete, ready-to-evaluate IPCR for any employee in 1 click —
--   instead of typing every MFO from blank.
--
-- Schema additions:
--   • performance.perf_ipcr_templates — reusable MFO bundles
--   • performance.perf_ipcr_summary  — adds CSC-required signatory
--                                       columns (discussed_at, ratee/rater
--                                       signed_at, period_start, period_end,
--                                       reviewed_by, recommendations)
--
-- Seeds: 5 starter templates spanning common LGU positions.
-- ================================================================
SET search_path TO performance, core, public;


-- ── Template library ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS performance.perf_ipcr_templates (
    id              BIGSERIAL    PRIMARY KEY,
    code            VARCHAR(50)  UNIQUE NOT NULL,
    title           VARCHAR(200) NOT NULL,
    description     TEXT,
    target_position VARCHAR(150),       -- "Admin Officer V", "HR Specialist", etc.
    department_hint VARCHAR(100),       -- optional dept lock
    items           JSONB        NOT NULL DEFAULT '[]'::jsonb,
                    -- Each item:
                    -- { "function_type": "CORE"|"STRATEGIC"|"SUPPORT",
                    --   "performance_indicator": "...",
                    --   "target": "...",
                    --   "target_value": 95,
                    --   "weight": 0.20,
                    --   "means_of_verification": "..." }
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    sort_order      INT          NOT NULL DEFAULT 100,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ipcr_tpl_active ON performance.perf_ipcr_templates (is_active, sort_order);


-- ── CSC signatory columns on the summary ───────────────────────
ALTER TABLE performance.perf_ipcr_summary
    ADD COLUMN IF NOT EXISTS period_start    DATE,
    ADD COLUMN IF NOT EXISTS period_end      DATE,
    ADD COLUMN IF NOT EXISTS discussed_at    DATE,
    ADD COLUMN IF NOT EXISTS ratee_signed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS rater_signed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS rater_id        BIGINT REFERENCES core.users(id),
    ADD COLUMN IF NOT EXISTS approver_id     BIGINT REFERENCES core.users(id),
    ADD COLUMN IF NOT EXISTS recommendations TEXT;


-- ── 5 CSC-aligned starter templates ────────────────────────────
INSERT INTO performance.perf_ipcr_templates
    (code, title, description, target_position, items, sort_order)
VALUES

('ADMIN_OFFICER_V',
 'Administrative Officer V — IPCR Starter',
 'Standard IPCR for Administrative Officer V positions. Covers core admin support, '
 'customer service, file management, and report submission per CSC OPES guidelines.',
 'Administrative Officer V',
 $items$[
   {"function_type":"CORE","weight":0.25,
    "performance_indicator":"Process incoming and outgoing communications within prescribed turnaround time",
    "target":"100% of communications processed within 24 working hours",
    "target_value":100,
    "means_of_verification":"Communications log; receiving copies"},
   {"function_type":"CORE","weight":0.20,
    "performance_indicator":"Maintain accurate and up-to-date 201/personnel files",
    "target":"Zero misfiled documents per quarter",
    "target_value":0,
    "means_of_verification":"Quarterly random spot-check audit by HR"},
   {"function_type":"CORE","weight":0.20,
    "performance_indicator":"Submit accomplishment reports on time",
    "target":"All monthly reports submitted by the 5th working day of next month",
    "target_value":12,
    "means_of_verification":"Submitted reports with timestamp"},
   {"function_type":"CORE","weight":0.15,
    "performance_indicator":"Provide responsive frontline service to internal/external clients",
    "target":"≥ 95% client satisfaction rating from feedback survey",
    "target_value":95,
    "means_of_verification":"Client satisfaction survey results"},
   {"function_type":"SUPPORT","weight":0.10,
    "performance_indicator":"Attend mandatory CSC-prescribed trainings and seminars",
    "target":"Complete at least 2 trainings per year",
    "target_value":2,
    "means_of_verification":"Certificates of attendance"},
   {"function_type":"SUPPORT","weight":0.10,
    "performance_indicator":"Comply with prescribed civil service code of conduct",
    "target":"Zero substantiated complaints",
    "target_value":0,
    "means_of_verification":"Discipline office records"}
 ]$items$::jsonb,
 10),

('HR_OFFICER',
 'HR Officer / HR Specialist — IPCR Starter',
 'Standard IPCR for HR officers covering recruitment, employee relations, training, '
 'records, and compliance per CSC PRIME-HRM Level 2 standards.',
 'HR Officer',
 $items$[
   {"function_type":"CORE","weight":0.25,
    "performance_indicator":"Process recruitment requisitions to job offer",
    "target":"≤ 30 days average time-to-hire",
    "target_value":30,
    "means_of_verification":"Recruitment tracker; rec_requisitions records"},
   {"function_type":"CORE","weight":0.20,
    "performance_indicator":"Conduct employee onboarding within prescribed period",
    "target":"100% of new hires onboarded within their first 5 working days",
    "target_value":100,
    "means_of_verification":"Onboarding checklist completion records"},
   {"function_type":"CORE","weight":0.15,
    "performance_indicator":"Process employee leave applications",
    "target":"100% of CSC Form 6 leave applications processed within 3 working days",
    "target_value":100,
    "means_of_verification":"Leave management system logs"},
   {"function_type":"STRATEGIC","weight":0.20,
    "performance_indicator":"Plan and execute training & development programs",
    "target":"Deliver at least 4 training programs covering 80% of target attendees",
    "target_value":4,
    "means_of_verification":"Training program reports; attendance sheets"},
   {"function_type":"CORE","weight":0.10,
    "performance_indicator":"Maintain CSC eligibility and qualification records",
    "target":"100% of new hires verified against CSC eligibility before appointment",
    "target_value":100,
    "means_of_verification":"Eligibility verification logs"},
   {"function_type":"SUPPORT","weight":0.10,
    "performance_indicator":"Support HR audit readiness (CSC PRIME-HRM)",
    "target":"Pass all internal HR audit checkpoints",
    "target_value":100,
    "means_of_verification":"Internal audit reports"}
 ]$items$::jsonb,
 20),

('IT_OFFICER',
 'IT / MIS Officer — IPCR Starter',
 'Standard IPCR for Information Technology / MIS officers covering systems uptime, '
 'service desk, security, and digital transformation projects.',
 'IT Officer',
 $items$[
   {"function_type":"CORE","weight":0.25,
    "performance_indicator":"Resolve service desk tickets within SLA",
    "target":"≥ 90% of tickets resolved within agreed SLA",
    "target_value":90,
    "means_of_verification":"Ticketing system reports"},
   {"function_type":"CORE","weight":0.25,
    "performance_indicator":"Maintain critical system uptime",
    "target":"≥ 99.5% uptime for critical systems",
    "target_value":99.5,
    "means_of_verification":"Monitoring system logs"},
   {"function_type":"STRATEGIC","weight":0.25,
    "performance_indicator":"Deliver assigned digital transformation projects",
    "target":"All assigned projects delivered on time and within scope",
    "target_value":100,
    "means_of_verification":"Project sign-off documents"},
   {"function_type":"CORE","weight":0.15,
    "performance_indicator":"Implement information security controls",
    "target":"Zero high-severity security incidents per quarter",
    "target_value":0,
    "means_of_verification":"Security incident reports"},
   {"function_type":"SUPPORT","weight":0.10,
    "performance_indicator":"Train end-users on systems and tools",
    "target":"Conduct at least 2 training sessions per quarter",
    "target_value":2,
    "means_of_verification":"Training attendance and feedback forms"}
 ]$items$::jsonb,
 30),

('DEPARTMENT_HEAD',
 'Department Head / Division Chief — IPCR Starter',
 'Strategic IPCR for department heads. Cascades from OPCR with focus on operations, '
 'people leadership, fiscal stewardship, and CSC compliance.',
 'Department Head',
 $items$[
   {"function_type":"STRATEGIC","weight":0.30,
    "performance_indicator":"Achieve department OPCR targets",
    "target":"≥ 4.0 weighted-average OPCR rating",
    "target_value":4.0,
    "means_of_verification":"OPCR validated rating from approving authority"},
   {"function_type":"CORE","weight":0.20,
    "performance_indicator":"Manage department budget within approved appropriations",
    "target":"Zero budget overrun; ≥ 95% utilization rate",
    "target_value":95,
    "means_of_verification":"Budget utilization reports"},
   {"function_type":"STRATEGIC","weight":0.20,
    "performance_indicator":"Develop and mentor staff",
    "target":"All direct reports complete annual IPCR with at least Satisfactory rating",
    "target_value":100,
    "means_of_verification":"Department IPCR roll-up"},
   {"function_type":"CORE","weight":0.15,
    "performance_indicator":"Ensure timely submission of all department reports",
    "target":"100% of mandated reports submitted on or before deadline",
    "target_value":100,
    "means_of_verification":"Submission logs"},
   {"function_type":"SUPPORT","weight":0.15,
    "performance_indicator":"Maintain CSC PRIME-HRM compliance for the department",
    "target":"Zero adverse audit findings",
    "target_value":0,
    "means_of_verification":"Internal HR audit"}
 ]$items$::jsonb,
 40),

('FRONTLINE_STAFF',
 'Frontline / Service Window Staff — IPCR Starter',
 'IPCR for frontline service personnel (registry clerks, cashiers, service-desk).',
 'Frontline Staff',
 $items$[
   {"function_type":"CORE","weight":0.30,
    "performance_indicator":"Serve clients within Anti-Red Tape Act prescribed turnaround",
    "target":"100% of transactions completed within posted Citizen's Charter timeline",
    "target_value":100,
    "means_of_verification":"Transaction logbook; CSC client feedback survey"},
   {"function_type":"CORE","weight":0.25,
    "performance_indicator":"Maintain accurate transaction records",
    "target":"Zero verified record discrepancies per quarter",
    "target_value":0,
    "means_of_verification":"Reconciliation reports"},
   {"function_type":"CORE","weight":0.20,
    "performance_indicator":"Achieve high client satisfaction",
    "target":"≥ 4.5 / 5.0 average rating in client satisfaction survey",
    "target_value":4.5,
    "means_of_verification":"Client satisfaction survey"},
   {"function_type":"SUPPORT","weight":0.15,
    "performance_indicator":"Maintain proper grooming and decorum",
    "target":"Zero substantiated complaints regarding conduct",
    "target_value":0,
    "means_of_verification":"Discipline office records"},
   {"function_type":"SUPPORT","weight":0.10,
    "performance_indicator":"Attend ARTA and customer-service refresher trainings",
    "target":"Complete at least 1 refresher training per year",
    "target_value":1,
    "means_of_verification":"Certificates of completion"}
 ]$items$::jsonb,
 50)

ON CONFLICT (code) DO UPDATE SET
    title           = EXCLUDED.title,
    description     = EXCLUDED.description,
    target_position = EXCLUDED.target_position,
    items           = EXCLUDED.items,
    sort_order      = EXCLUDED.sort_order,
    updated_at      = NOW();


-- ── Page registry — IPCR Templates Library page ────────────────
INSERT INTO core.page_registry
    (path, title, module, nav_group, nav_label, nav_icon, nav_order, is_visible)
VALUES
    ('/pm/ipcr/templates', 'IPCR Templates', 'performance',
     'Performance', 'IPCR Templates', 'clipboard-list', 60, TRUE)
ON CONFLICT (path) DO UPDATE SET title = EXCLUDED.title;

INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
  FROM core.page_registry p
  CROSS JOIN (VALUES ('SUPER_ADMIN'),('HR_ADMIN'),('MANAGER'),('EXECUTIVE')) AS r(role_code)
 WHERE p.path = '/pm/ipcr/templates'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, FALSE
  FROM core.page_registry p
  CROSS JOIN (VALUES ('EMPLOYEE')) AS r(role_code)
 WHERE p.path = '/pm/ipcr/templates'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = FALSE;
