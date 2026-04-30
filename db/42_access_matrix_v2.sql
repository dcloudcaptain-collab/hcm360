-- ================================================================
-- HCM360 — 42: ACCESS MATRIX V2
-- Granular per-page / per-action access, user-level overrides
-- ================================================================
SET search_path TO core, public;

-- ────────────────────────────────────────────────────────────────
-- 1. Extend feature_registry with type + action metadata
-- ────────────────────────────────────────────────────────────────
ALTER TABLE core.feature_registry
    ADD COLUMN IF NOT EXISTS feature_type VARCHAR(20) NOT NULL DEFAULT 'MODULE'
        CHECK (feature_type IN ('MODULE','ACTION')),
    ADD COLUMN IF NOT EXISTS action_type  VARCHAR(20)
        CHECK (action_type IN ('VIEW','PRINT','EXPORT','EDIT','OVERRIDE',
                               'ADJUST','APPROVE','CREATE','DELETE','TOGGLE',NULL)),
    ADD COLUMN IF NOT EXISTS page_path    VARCHAR(200)  -- ties action to a specific page
        REFERENCES core.page_registry(path) ON DELETE SET NULL DEFERRABLE;

-- Back-fill existing rows as MODULE type
UPDATE core.feature_registry SET feature_type = 'MODULE' WHERE feature_type IS NULL;

-- ────────────────────────────────────────────────────────────────
-- 2. User-level page access (overrides role-level)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS core.user_page_access (
    id          BIGSERIAL   PRIMARY KEY,
    user_id     BIGINT      NOT NULL REFERENCES core.users(id) ON DELETE CASCADE,
    page_id     BIGINT      NOT NULL REFERENCES core.page_registry(id) ON DELETE CASCADE,
    can_access  BOOLEAN     NOT NULL DEFAULT TRUE,
    granted_by  BIGINT      REFERENCES core.users(id),
    granted_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, page_id)
);

-- ────────────────────────────────────────────────────────────────
-- 3. User-level feature access (overrides role-level)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS core.user_feature_access (
    id          BIGSERIAL   PRIMARY KEY,
    user_id     BIGINT      NOT NULL REFERENCES core.users(id) ON DELETE CASCADE,
    feature_id  BIGINT      NOT NULL REFERENCES core.feature_registry(id) ON DELETE CASCADE,
    can_access  BOOLEAN     NOT NULL DEFAULT TRUE,
    granted_by  BIGINT      REFERENCES core.users(id),
    granted_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, feature_id)
);

-- ────────────────────────────────────────────────────────────────
-- 4. Granular action features per module / page
--    page_path values must match core.page_registry.path exactly
-- ────────────────────────────────────────────────────────────────

-- ATTENDANCE
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('ATT_DTR_EXPORT',     'DTR — Export CSV/XLSX',          'attendance', 'ACTION', 'EXPORT',   '/attendance/dtr',            TRUE),
  ('ATT_DTR_PRINT',      'DTR — Print CS Form 6',          'attendance', 'ACTION', 'PRINT',    '/attendance/dtr',            TRUE),
  ('ATT_DTR_OVERRIDE',   'DTR — Admin Override',           'attendance', 'ACTION', 'OVERRIDE', '/attendance/dtr',            TRUE),
  ('ATT_DTR_CORRECT',    'DTR — Request Correction',       'attendance', 'ACTION', 'EDIT',     '/attendance/dtr',            TRUE),
  ('ATT_OT_APPROVE',     'Overtime — Approve/Reject',      'attendance', 'ACTION', 'APPROVE',  '/attendance/overtime',       TRUE),
  ('ATT_OT_CREATE',      'Overtime — Submit Request',      'attendance', 'ACTION', 'CREATE',   '/attendance/overtime',       TRUE),
  ('ATT_SHIFT_EDIT',     'Shifts — Create/Edit Shift',     'attendance', 'ACTION', 'EDIT',     '/attendance/shifts',         TRUE),
  ('ATT_SHIFT_ASSIGN',   'Shifts — Assign to Employee',    'attendance', 'ACTION', 'TOGGLE',   '/attendance/shift-assignments', TRUE),
  ('ATT_ALERTS_VIEW',    'Alerts — View Tardiness/AWOL',   'attendance', 'ACTION', 'VIEW',     '/attendance/alerts',         TRUE)
ON CONFLICT (code) DO NOTHING;

-- LEAVE
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('LV_REQUEST_CREATE',  'Leave — File Request',           'leave_mgmt', 'ACTION', 'CREATE',   '/leave/requests',            TRUE),
  ('LV_REQUEST_APPROVE', 'Leave — Approve/Reject',         'leave_mgmt', 'ACTION', 'APPROVE',  '/leave/requests',            TRUE),
  ('LV_REQUEST_CANCEL',  'Leave — Cancel Request',         'leave_mgmt', 'ACTION', 'DELETE',   '/leave/requests',            TRUE),
  ('LV_BALANCE_ADJUST',  'Leave Balances — Manual Adjust', 'leave_mgmt', 'ACTION', 'ADJUST',   '/leave/balances',            TRUE),
  ('LV_BALANCE_EXPORT',  'Leave Balances — Export',        'leave_mgmt', 'ACTION', 'EXPORT',   '/leave/balances',            TRUE),
  ('LV_CTO_ADJUST',      'CTO — Adjust Credits',           'leave_mgmt', 'ACTION', 'ADJUST',   '/leave/cto',                 TRUE),
  ('LV_TO_APPROVE',      'Travel Orders — Approve/Reject', 'leave_mgmt', 'ACTION', 'APPROVE',  '/leave/travel-orders',       TRUE),
  ('LV_TO_CREATE',       'Travel Orders — Submit',         'leave_mgmt', 'ACTION', 'CREATE',   '/leave/travel-orders',       TRUE)
ON CONFLICT (code) DO NOTHING;

-- PAYROLL
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('PAY_RUN_CREATE',     'Payroll — Create Pay Run',       'payroll', 'ACTION', 'CREATE',   '/payroll',                   TRUE),
  ('PAY_RUN_APPROVE',    'Payroll — Approve/Process Run',  'payroll', 'ACTION', 'APPROVE',  '/payroll',                   TRUE),
  ('PAY_RUN_ADJUST',     'Payroll — Add Adjustment',       'payroll', 'ACTION', 'ADJUST',   '/payroll',                   TRUE),
  ('PAY_SLIP_PRINT',     'Payslip — Print/PDF',            'payroll', 'ACTION', 'PRINT',    '/payroll',                   TRUE),
  ('PAY_LOAN_CREATE',    'Loans — Apply New Loan',         'payroll', 'ACTION', 'CREATE',   '/payroll/loans',             TRUE),
  ('PAY_LOAN_VIEW_ALL',  'Loans — View All Employees',     'payroll', 'ACTION', 'VIEW',     '/payroll/loans',             TRUE)
ON CONFLICT (code) DO NOTHING;

-- RSP / RECRUITMENT  (module code in page_registry is 'rsp')
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('RSP_VACANCY_PUBLISH','RSP — Publish Vacancy',          'rsp', 'ACTION', 'TOGGLE', '/rsp/vacancies',                 TRUE),
  ('RSP_APPLICANT_ADV',  'RSP — Advance Applicant Stage',  'rsp', 'ACTION', 'EDIT',   '/rsp/applicants',                TRUE),
  ('RSP_PSB_SCORE',      'RSP — PSB Scoring',              'rsp', 'ACTION', 'EDIT',   '/rsp/psb',                       TRUE),
  ('RSP_APPOINT',        'RSP — Issue Appointment',        'rsp', 'ACTION', 'CREATE', '/rsp/appointments',              TRUE),
  ('RSP_NEXT_COMPUTE',   'RSP — Compute Next-in-Rank',     'rsp', 'ACTION', 'TOGGLE', '/rsp/next-in-rank',              TRUE),
  ('RSP_OFFBOARD_CLEAR', 'RSP — Offboarding Clearance',    'rsp', 'ACTION', 'EDIT',   '/rsp/offboarding',               TRUE)
ON CONFLICT (code) DO NOTHING;

-- PERFORMANCE MANAGEMENT  (module = 'pm')
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('PM_IPCR_EDIT',       'PM — Edit IPCR',                 'pm', 'ACTION', 'EDIT',    '/pm/ipcr',                       TRUE),
  ('PM_IPCR_FINALIZE',   'PM — Finalize IPCR',             'pm', 'ACTION', 'APPROVE', '/pm/ipcr',                       TRUE),
  ('PM_OPCR_EDIT',       'PM — Edit OPCR',                 'pm', 'ACTION', 'EDIT',    '/pm/opcr',                       TRUE),
  ('PM_PRINT',           'PM — Print Evaluation Form',     'pm', 'ACTION', 'PRINT',   '/pm/ipcr',                       TRUE)
ON CONFLICT (code) DO NOTHING;

-- LEARNING & DEVELOPMENT  (module = 'ld')
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('LD_CHECKIN',         'L&D — Mobile Check-in',          'ld', 'ACTION', 'CREATE',  '/ld/attendance',                 TRUE),
  ('LD_NARRATIVE_SUBMIT','L&D — Submit Narrative Report',  'ld', 'ACTION', 'CREATE',  '/ld/narrative-reports',          TRUE),
  ('LD_TNA_VIEW',        'L&D — View TNA Entries',         'ld', 'ACTION', 'VIEW',    '/ld/tna',                        TRUE),
  ('LD_PRINT',           'L&D — Print Training Report',    'ld', 'ACTION', 'PRINT',   '/ld/programs',                   TRUE)
ON CONFLICT (code) DO NOTHING;

-- REWARDS & RECOGNITION  (module = 'rr')
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('RR_STEP_COMPUTE',    'R&R — Compute Step Increment',   'rr', 'ACTION', 'TOGGLE',  '/rr/step-increments',            TRUE),
  ('RR_STEP_PROCESS',    'R&R — Process Step Increment',   'rr', 'ACTION', 'APPROVE', '/rr/step-increments',            TRUE),
  ('RR_LOYALTY_SCAN',    'R&R — Scan Loyalty Milestones',  'rr', 'ACTION', 'TOGGLE',  '/rr/loyalty',                    TRUE),
  ('RR_RETIRE_SCHEDULE', 'R&R — Schedule Retirement Alert','rr', 'ACTION', 'CREATE',  '/rr/retirement-notices',         TRUE),
  ('RR_PRINT',           'R&R — Print Award Notice/Memo',  'rr', 'ACTION', 'PRINT',   '/rr/nominations',                TRUE)
ON CONFLICT (code) DO NOTHING;

-- DMS / DOCUMENT MANAGEMENT  (module = 'dms')
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('DMS_REQUEST_CREATE', 'DMS — Create Document Request',  'dms', 'ACTION', 'CREATE',  '/dms/requests',                 TRUE),
  ('DMS_CERT_PROCESS',   'DMS — Process Certificate',      'dms', 'ACTION', 'APPROVE', '/dms/certificate-requests',     TRUE),
  ('DMS_CERT_RELEASE',   'DMS — Release Certificate',      'dms', 'ACTION', 'TOGGLE',  '/dms/certificate-requests',     TRUE),
  ('DMS_SR_GENERATE',    'DMS — Generate Service Record',  'dms', 'ACTION', 'PRINT',   '/dms/',                         TRUE),
  ('DMS_EXPORT',         'DMS — Export Document List',     'dms', 'ACTION', 'EXPORT',  '/dms/',                         TRUE)
ON CONFLICT (code) DO NOTHING;

-- DISCIPLINE
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('DISC_CASE_CREATE',   'Discipline — File New Case',     'discipline', 'ACTION', 'CREATE',  '/discipline/',            TRUE),
  ('DISC_CASE_DECIDE',   'Discipline — Record Decision',   'discipline', 'ACTION', 'APPROVE', '/discipline/',            TRUE),
  ('DISC_PRINT',         'Discipline — Print Case Report', 'discipline', 'ACTION', 'PRINT',   '/discipline/',            TRUE)
ON CONFLICT (code) DO NOTHING;

-- HEALTH & SAFETY
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('HEALTH_INCIDENT',    'Health — Report Incident',       'health', 'ACTION', 'CREATE',  '/health/incidents',           TRUE),
  ('HEALTH_ENROLL',      'Health — Enroll in Wellness',    'health', 'ACTION', 'TOGGLE',  '/health/wellness',            TRUE),
  ('HEALTH_EXPORT',      'Health — Export Health Report',  'health', 'ACTION', 'EXPORT',  '/health/',                    TRUE)
ON CONFLICT (code) DO NOTHING;

-- ANALYTICS / REPORTS
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('ANALYTICS_EXPORT',   'Analytics — Export Reports',     'analytics', 'ACTION', 'EXPORT',  '/reports',                TRUE),
  ('ANALYTICS_BUILD',    'Analytics — Use Report Builder', 'analytics', 'ACTION', 'CREATE',  '/reports/builder',        TRUE)
ON CONFLICT (code) DO NOTHING;

-- ADMIN
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('ADMIN_USERS_EDIT',   'Admin — Manage Users',           'admin', 'ACTION', 'EDIT',    '/admin/users',                TRUE),
  ('ADMIN_ACCESS_EDIT',  'Admin — Edit Access Matrix',     'admin', 'ACTION', 'EDIT',    '/admin/access-matrix',        TRUE),
  ('ADMIN_REF_EDIT',     'Admin — Edit Reference Data',    'admin', 'ACTION', 'EDIT',    '/admin/reference',            TRUE),
  ('ADMIN_DEMO_ACTIVATE','Admin — Activate Demo Profile',  'admin', 'ACTION', 'TOGGLE',  '/admin/demo-data',            TRUE)
ON CONFLICT (code) DO NOTHING;

-- ────────────────────────────────────────────────────────────────
-- 5. Default action grants
-- ────────────────────────────────────────────────────────────────

-- SUPER_ADMIN + HR_ADMIN: all action features
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.code, f.id, TRUE
FROM core.feature_registry f,
     (VALUES ('SUPER_ADMIN'), ('HR_ADMIN')) AS r(code)
WHERE f.feature_type = 'ACTION'
ON CONFLICT (role_code, feature_id) DO NOTHING;

-- MANAGER: view/approve/export/create — not override/adjust/admin
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT 'MANAGER', f.id, TRUE
FROM core.feature_registry f
WHERE f.feature_type = 'ACTION'
  AND f.action_type IN ('VIEW','APPROVE','PRINT','EXPORT','CREATE')
  AND f.module NOT IN ('admin','payroll')
  AND f.code NOT IN ('LV_BALANCE_ADJUST','LV_CTO_ADJUST','ATT_DTR_OVERRIDE',
                     'RSP_APPOINT','DISC_CASE_DECIDE')
ON CONFLICT (role_code, feature_id) DO NOTHING;

-- EMPLOYEE: own-actions only
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT 'EMPLOYEE', f.id, TRUE
FROM core.feature_registry f
WHERE f.code IN ('LV_REQUEST_CREATE','LV_TO_CREATE','ATT_OT_CREATE',
                 'ATT_DTR_CORRECT','LD_CHECKIN','LD_NARRATIVE_SUBMIT',
                 'HEALTH_ENROLL','PAY_SLIP_PRINT')
ON CONFLICT (role_code, feature_id) DO NOTHING;
