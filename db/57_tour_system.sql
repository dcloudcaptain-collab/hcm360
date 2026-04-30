-- ================================================================
-- HCM360 — 57: GUIDED TOUR + TOOLTIP SYSTEM
--
-- Tables:
--   core.tours             — tour definitions (module/role/version/steps)
--   core.tour_completions  — per-user per-tour completion tracking
--
-- Seed: 8 role-appropriate tours (dashboard, employees, payroll,
--       leave-manager, ESS-profile, checkin, attrition, access-matrix)
--
-- Integration: base.html loads /static/js/hris-tour.js + css on every page.
-- The page declares data-tour-key="<key>" on <body>; the engine fetches
-- the tour config and optionally auto-starts for first-time users.
-- ================================================================
SET search_path TO core, public;


CREATE TABLE IF NOT EXISTS core.tours (
    id              BIGSERIAL   PRIMARY KEY,
    tour_key        VARCHAR(80) UNIQUE NOT NULL,
    title           VARCHAR(200) NOT NULL,
    description     TEXT,
    module          VARCHAR(50),                      -- for grouping in admin UI
    version         INT         NOT NULL DEFAULT 1,
    allowed_roles   VARCHAR(30)[] NOT NULL DEFAULT '{SUPER_ADMIN,HR_ADMIN,MANAGER,EMPLOYEE,EXECUTIVE}',
    url_pattern     VARCHAR(200),                     -- where tour applies (LIKE match)
    auto_start      BOOLEAN     NOT NULL DEFAULT TRUE,
    steps           JSONB       NOT NULL DEFAULT '[]'::jsonb,
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    updated_by      BIGINT REFERENCES core.users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_tours_module ON core.tours (module);
CREATE INDEX IF NOT EXISTS idx_tours_url    ON core.tours (url_pattern);


CREATE TABLE IF NOT EXISTS core.tour_completions (
    user_id         BIGINT      NOT NULL REFERENCES core.users(id) ON DELETE CASCADE,
    tour_key        VARCHAR(80) NOT NULL,
    version         INT         NOT NULL DEFAULT 1,
    completed_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    skipped         BOOLEAN     NOT NULL DEFAULT FALSE,
    step_reached    INT         NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, tour_key, version)
);
CREATE INDEX IF NOT EXISTS idx_tour_comp_user ON core.tour_completions (user_id);


-- Page + feature registry for admin UI
INSERT INTO core.page_registry
    (path, title, module, nav_group, nav_label, nav_icon, nav_order, is_visible)
VALUES
    ('/admin/tours', 'Guided Tours', 'admin',
     'Administration', 'Guided Tours', 'compass', 95, TRUE)
ON CONFLICT (path) DO NOTHING;

INSERT INTO core.feature_registry
    (code, name, description, module, is_enabled, feature_type, action_type, page_path)
VALUES
    ('TOUR_MANAGE', 'Manage Tours', 'Create/edit/reset guided tours',
     'admin', TRUE, 'ACTION', 'EDIT', '/admin/tours')
ON CONFLICT (code) DO NOTHING;


-- Role access: SUPER_ADMIN + HR_ADMIN only for admin page
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
FROM core.page_registry p
CROSS JOIN (VALUES ('SUPER_ADMIN'), ('HR_ADMIN')) AS r(role_code)
WHERE p.path = '/admin/tours'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, FALSE
FROM core.page_registry p
CROSS JOIN (VALUES ('MANAGER'), ('EMPLOYEE'), ('EXECUTIVE')) AS r(role_code)
WHERE p.path = '/admin/tours'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = FALSE;

INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.role_code, f.id, TRUE
FROM core.feature_registry f
CROSS JOIN (VALUES ('SUPER_ADMIN'), ('HR_ADMIN')) AS r(role_code)
WHERE f.code = 'TOUR_MANAGE'
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = TRUE;


-- ══════════════════════════════════════════════════════════════════
-- Seed tours (8 role-appropriate)
-- ══════════════════════════════════════════════════════════════════
INSERT INTO core.tours (tour_key, title, description, module, allowed_roles, url_pattern, steps)
VALUES
    -- Welcome tour for ALL roles on dashboard
    ('dashboard-welcome-v1',
     'Welcome to HCM360',
     'Quick orientation to your personal dashboard',
     'dashboard',
     ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE'],
     '/',
     '[
        {"title":"Welcome to HCM360","body":"This is your home dashboard. We''ll show you around in 6 quick steps.","position":"center"},
        {"selector":".nav-primary, nav.sidebar, aside.sidebar","title":"Navigation","body":"Use the left sidebar to jump between modules. Items are filtered to match your role.","position":"right"},
        {"selector":".kpi, .kpi-card, [data-kpi]","title":"KPI Cards","body":"At-a-glance metrics — headcount, present today, leaves pending, and more. Click any card to drill in.","position":"bottom"},
        {"selector":".inbox, [data-inbox], a[href*=\"inbox\"]","title":"Inbox","body":"Approval tasks and notifications live in your inbox. The red dot means unread items.","position":"bottom"},
        {"selector":"a[href*=\"/me/profile\"], a[href=\"/me\"]","title":"My Profile","body":"Update your personal info, addresses, and documents from your profile page.","position":"bottom"},
        {"title":"All set!","body":"Click the ? launcher in the bottom-right any time to replay this tour or explore other tours.","position":"center"}
     ]'::jsonb),

    -- HR employee directory
    ('employees-directory-v1',
     'Employee Directory Tour',
     'Navigate the employee list, search, and drill into profiles',
     'employees',
     ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE'],
     '/employees',
     '[
        {"title":"Employee Directory","body":"Manage your entire workforce from this page.","position":"center"},
        {"selector":"input[type=search], .search-box, input[name*=q]","title":"Search & Filter","body":"Type a name, employee number, or email. Results update live.","position":"bottom"},
        {"selector":"a[href*=\"new\"], button:contains(\"New\"), .btn-primary","title":"Add Employee","body":"Click here to onboard a new hire. Fields map to the 201 file.","position":"bottom"},
        {"selector":"table, .dt, .employee-row","title":"Roster","body":"Click any row to open the employee''s 201 file — personal info, documents, payroll, leave history.","position":"top"}
     ]'::jsonb),

    -- Payroll tour
    ('payroll-runs-v1',
     'Payroll Runs',
     'Create, compute, and post a pay run',
     'payroll',
     ARRAY['SUPER_ADMIN','HR_ADMIN'],
     '/payroll',
     '[
        {"title":"Payroll Runs","body":"Create and post pay runs here. Each run moves through DRAFT → COMPUTING → COMPUTED → APPROVED → POSTED.","position":"center"},
        {"selector":".btn-primary, a[href*=\"new\"]","title":"New Run","body":"Start a new run. You''ll pick the period type (Regular / 13th Month / Final Pay).","position":"bottom"},
        {"selector":"table.dt, .runs-list","title":"Run List","body":"Click any run to view computations per employee. Adjustments post-payout use a separate audit-safe path.","position":"top"},
        {"selector":"a[href*=\"payslip\"]","title":"Payslips","body":"Once a run is POSTED, employees see their payslips via /me/payslips and can download PDFs.","position":"top"}
     ]'::jsonb),

    -- Manager leave approvals
    ('leave-mgr-approve-v1',
     'Approving Leave Requests',
     'Review and approve your team''s leave requests',
     'leave_mgmt',
     ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER'],
     '/team',
     '[
        {"title":"Team Management","body":"Approve leaves, overtime, and other requests from your team here.","position":"center"},
        {"selector":"a[href*=\"inbox\"], .inbox-link","title":"Your Inbox","body":"Pending approvals land in your inbox. Red badge = urgent; yellow = high priority.","position":"bottom"},
        {"selector":"table, .dt","title":"Decision Impact","body":"Each request shows the applicant''s current leave balance so you can see the impact of approval.","position":"top"}
     ]'::jsonb),

    -- Employee self-service profile
    ('ess-profile-v1',
     'Your Profile',
     'Keep your personal info up to date',
     'ess_mss',
     ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE'],
     '/me/profile',
     '[
        {"title":"My Profile","body":"Keep your info current — HR and Payroll depend on it.","position":"center"},
        {"selector":".sec-card, .section-card, details","title":"Collapsible Sections","body":"Click any section header to expand. You can add missing records via the ''+ Add one'' links.","position":"right"},
        {"selector":"a[href*=\"new\"]","title":"Add Records","body":"Addresses, emergency contacts, government IDs, and bank accounts all use these quick-add links.","position":"top"}
     ]'::jsonb),

    -- Face check-in (any role with employee link)
    ('checkin-v1',
     'Face Check-In',
     'Clock in/out using your camera and location',
     'attendance',
     ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE'],
     '/checkin',
     '[
        {"title":"Face Check-In","body":"Verify your identity and location in one tap.","position":"center"},
        {"selector":"#video, .video-card","title":"Camera","body":"The system uses on-device face matching — no photo is uploaded. A 128-d signature of your face is compared to your enrollment.","position":"right"},
        {"selector":"#cameraSelect, select[name*=camera]","title":"Choose Camera","body":"Switch between laptop webcam and mobile front/back camera here.","position":"left"},
        {"selector":"#btnIn, .btn-in","title":"Check In","body":"Green button records IN. The orange one records OUT. Both require an active face + GPS lock.","position":"top"}
     ]'::jsonb),

    -- Attrition risk dashboard
    ('attrition-risk-v1',
     'Attrition Risk Dashboard',
     'Identify retention risks and take action',
     'analytics',
     ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE'],
     '/reports/attrition-risk',
     '[
        {"title":"Attrition Risk","body":"AI-assisted scoring of every active employee based on tenure, engagement, attendance, and leave patterns.","position":"center"},
        {"selector":"#btnScan","title":"Run Risk Scan","body":"Re-score all employees. Runs are fast (< 5 sec for 500 employees). Latest scan timestamp is shown below.","position":"bottom"},
        {"selector":".kpi.red, .kpi.amber","title":"Risk Tiers","body":"Red = HIGH (≥ 0.6), amber = MEDIUM (0.3–0.6). Gender split helps identify cohort patterns.","position":"bottom"},
        {"selector":".factor-chip","title":"Factor Chips","body":"Hover each chip to see why the system flagged this employee. Use these insights to tailor retention conversations.","position":"top"}
     ]'::jsonb),

    -- Access matrix (SUPER_ADMIN only)
    ('access-matrix-v1',
     'Access Matrix',
     'Manage role-based access to pages and features',
     'admin',
     ARRAY['SUPER_ADMIN'],
     '/admin/access-matrix',
     '[
        {"title":"Access Matrix","body":"The single place to control who can see what. Changes take effect on the next request.","position":"center"},
        {"selector":"select[name*=module]","title":"Pick a Module","body":"Each module shows its pages and action features. Start with the module you want to adjust.","position":"bottom"},
        {"selector":"input[type=checkbox]","title":"Toggle Access","body":"Each checkbox is a role × page grant. User-level overrides take precedence over role grants.","position":"right"}
     ]'::jsonb)
ON CONFLICT (tour_key) DO UPDATE SET
    title         = EXCLUDED.title,
    description   = EXCLUDED.description,
    module        = EXCLUDED.module,
    allowed_roles = EXCLUDED.allowed_roles,
    url_pattern   = EXCLUDED.url_pattern,
    steps         = EXCLUDED.steps,
    updated_at    = NOW();
