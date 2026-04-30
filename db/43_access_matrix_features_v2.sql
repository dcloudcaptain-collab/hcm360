-- ================================================================
-- HCM360 — 43: ACCESS MATRIX FEATURES EXPANSION
-- Fills missing action features for all modules/pages
-- ================================================================
SET search_path TO core, public;

-- ────────────────────────────────────────────────────────────────
-- CORE / EMPLOYEES
-- ────────────────────────────────────────────────────────────────
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('CORE_EMP_EXPORT',      'Employees — Export List CSV/XLSX',       'core', 'ACTION', 'EXPORT', '/employees',  TRUE),
  ('CORE_EMP_PRINT',       'Employees — Print Employee Record',       'core', 'ACTION', 'PRINT',  '/employees',  TRUE),
  ('CORE_EMP_CREATE',      'Employees — Add New Employee',            'core', 'ACTION', 'CREATE', '/employees',  TRUE),
  ('CORE_EMP_EDIT',        'Employees — Edit Employee Record',        'core', 'ACTION', 'EDIT',   '/employees',  TRUE)
ON CONFLICT (code) DO NOTHING;

-- ────────────────────────────────────────────────────────────────
-- ESS / MSS  (Self-Service)
-- ────────────────────────────────────────────────────────────────
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('ESS_PROFILE_EDIT',     'My Profile — Edit Personal Info',         'ess_mss', 'ACTION', 'EDIT',    '/me',             TRUE),
  ('ESS_ATT_EXPORT',       'My Attendance — Export DTR',              'ess_mss', 'ACTION', 'EXPORT',  '/me/attendance',  TRUE),
  ('ESS_LV_REQUEST',       'My Leaves — File Leave Request',          'ess_mss', 'ACTION', 'CREATE',  '/me/leaves',      TRUE),
  ('ESS_LV_CANCEL',        'My Leaves — Cancel Leave Request',        'ess_mss', 'ACTION', 'DELETE',  '/me/leaves',      TRUE),
  ('ESS_PAY_PRINT',        'My Payslips — Download / Print Payslip',  'ess_mss', 'ACTION', 'PRINT',   '/me/payslips',    TRUE),
  ('ESS_CERT_REQUEST',     'My Certificates — Request Certificate',   'ess_mss', 'ACTION', 'CREATE',  '/me/certificates', TRUE),
  ('MSS_TEAM_LV_APPROVE',  'My Team — Approve / Reject Leave',        'ess_mss', 'ACTION', 'APPROVE', '/my-team',        TRUE),
  ('MSS_TEAM_ATT_VIEW',    'My Team — View Team Attendance',          'ess_mss', 'ACTION', 'VIEW',    '/my-team',        TRUE),
  ('MSS_TEAM_EXPORT',      'My Team — Export Team Report',            'ess_mss', 'ACTION', 'EXPORT',  '/my-team',        TRUE)
ON CONFLICT (code) DO NOTHING;

-- ────────────────────────────────────────────────────────────────
-- AI / ARIA
-- ────────────────────────────────────────────────────────────────
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('AI_CHAT',              'ARIA — Send Chat Message',                'ai', 'ACTION', 'CREATE', '/ai/assistant',  TRUE),
  ('AI_EXEC_REFRESH',      'Executive Briefing — Refresh Briefing',   'ai', 'ACTION', 'TOGGLE', '/ai/executive',  TRUE),
  ('AI_EXEC_EXPORT',       'Executive Briefing — Export Briefing',    'ai', 'ACTION', 'EXPORT', '/ai/executive',  TRUE)
ON CONFLICT (code) DO NOTHING;

-- ────────────────────────────────────────────────────────────────
-- ANALYTICS — missing pages
-- ────────────────────────────────────────────────────────────────
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('ANALYTICS_HC_EXPORT',    'Headcount — Export Report',            'analytics', 'ACTION', 'EXPORT', '/reports/headcount',    TRUE),
  ('ANALYTICS_HC_PRINT',     'Headcount — Print Report',             'analytics', 'ACTION', 'PRINT',  '/reports/headcount',    TRUE),
  ('ANALYTICS_DEMO_EXPORT',  'Demographics — Export Report',         'analytics', 'ACTION', 'EXPORT', '/reports/demographics', TRUE),
  ('ANALYTICS_DEMO_PRINT',   'Demographics — Print Report',          'analytics', 'ACTION', 'PRINT',  '/reports/demographics', TRUE),
  ('ANALYTICS_SAVED_DELETE', 'Saved Reports — Delete Report',        'analytics', 'ACTION', 'DELETE', '/reports/saved',        TRUE),
  ('ANALYTICS_SAVED_SHARE',  'Saved Reports — Share / Publish',      'analytics', 'ACTION', 'TOGGLE', '/reports/saved',        TRUE),
  ('ANALYTICS_SCHED_CREATE', 'Scheduled Reports — Create Schedule',  'analytics', 'ACTION', 'CREATE', '/reports/scheduled',    TRUE),
  ('ANALYTICS_SCHED_DELETE', 'Scheduled Reports — Delete Schedule',  'analytics', 'ACTION', 'DELETE', '/reports/scheduled',    TRUE)
ON CONFLICT (code) DO NOTHING;

-- ────────────────────────────────────────────────────────────────
-- DISCIPLINE — additional workflow actions
-- ────────────────────────────────────────────────────────────────
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('DISC_CASE_INVESTIGATE',  'Discipline — Start Investigation',     'discipline', 'ACTION', 'EDIT',   '/discipline/',         TRUE),
  ('DISC_CASE_HEAR',         'Discipline — Schedule Hearing',        'discipline', 'ACTION', 'CREATE', '/discipline/',         TRUE),
  ('DISC_CASE_CHARGE',       'Discipline — Issue Formal Charge',     'discipline', 'ACTION', 'APPROVE','/discipline/cases/new',TRUE),
  ('DISC_EXPORT',            'Discipline — Export Case Report',      'discipline', 'ACTION', 'EXPORT', '/discipline/',         TRUE)
ON CONFLICT (code) DO NOTHING;

-- ────────────────────────────────────────────────────────────────
-- HEALTH & SAFETY — missing pages
-- ────────────────────────────────────────────────────────────────
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('HEALTH_DASHBOARD_EXPORT','Health — Export Health Summary',       'health', 'ACTION', 'EXPORT', '/health/',              TRUE),
  ('HEALTH_CERT_UPLOAD',     'Health Certs — Upload Certificate',    'health', 'ACTION', 'CREATE', '/health/certificates',  TRUE),
  ('HEALTH_CERT_APPROVE',    'Health Certs — Approve / Reject Cert', 'health', 'ACTION', 'APPROVE','/health/certificates',  TRUE),
  ('HEALTH_PE_SCHEDULE',     'Annual PE — Schedule Medical Exam',    'health', 'ACTION', 'CREATE', '/health/pe',            TRUE),
  ('HEALTH_PE_EXPORT',       'Annual PE — Export PE Records',        'health', 'ACTION', 'EXPORT', '/health/pe',            TRUE)
ON CONFLICT (code) DO NOTHING;

-- ────────────────────────────────────────────────────────────────
-- LEARNING & DEVELOPMENT — missing pages
-- ────────────────────────────────────────────────────────────────
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('LD_SESSION_CREATE',      'Sessions — Create Training Session',   'ld', 'ACTION', 'CREATE', '/ld/sessions',        TRUE),
  ('LD_SESSION_EDIT',        'Sessions — Edit Session Details',      'ld', 'ACTION', 'EDIT',   '/ld/sessions',        TRUE),
  ('LD_SESSION_EXPORT',      'Sessions — Export Attendance Sheet',   'ld', 'ACTION', 'EXPORT', '/ld/sessions',        TRUE),
  ('LD_SCHOLAR_APPLY',       'Scholarships — Submit Application',    'ld', 'ACTION', 'CREATE', '/ld/scholarships',    TRUE),
  ('LD_SCHOLAR_APPROVE',     'Scholarships — Approve Application',   'ld', 'ACTION', 'APPROVE','/ld/scholarships',    TRUE),
  ('LD_TNA_CREATE',          'TNA — Add Training Need Entry',        'ld', 'ACTION', 'CREATE', '/ld/tna',             TRUE),
  ('LD_TNA_EXPORT',          'TNA — Export TNA Summary',             'ld', 'ACTION', 'EXPORT', '/ld/tna',             TRUE),
  ('LD_PROGRAMS_CREATE',     'Catalog — Add Training Program',       'ld', 'ACTION', 'CREATE', '/ld/programs',        TRUE),
  ('LD_PROGRAMS_EDIT',       'Catalog — Edit Training Program',      'ld', 'ACTION', 'EDIT',   '/ld/programs',        TRUE)
ON CONFLICT (code) DO NOTHING;

-- ────────────────────────────────────────────────────────────────
-- PERFORMANCE MANAGEMENT — missing pages
-- ────────────────────────────────────────────────────────────────
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('PM_CYCLE_CREATE',        'PM — Create Performance Cycle',        'pm', 'ACTION', 'CREATE', '/pm/cycles',      TRUE),
  ('PM_CYCLE_EDIT',          'PM — Edit Cycle Parameters',           'pm', 'ACTION', 'EDIT',   '/pm/cycles',      TRUE),
  ('PM_OPCR_FINALIZE',       'PM — Finalize OPCR',                   'pm', 'ACTION', 'APPROVE','/pm/opcr',        TRUE),
  ('PM_OPCR_EXPORT',         'PM — Export OPCR Report',              'pm', 'ACTION', 'EXPORT', '/pm/opcr',        TRUE),
  ('PM_RATINGS_EXPORT',      'PM — Export Rating Distribution',      'pm', 'ACTION', 'EXPORT', '/pm/ratings',     TRUE),
  ('PM_SUCCESSION_EDIT',     'PM — Edit Succession Plan',            'pm', 'ACTION', 'EDIT',   '/pm/succession',  TRUE),
  ('PM_SUCCESSION_EXPORT',   'PM — Export Succession Plan',          'pm', 'ACTION', 'EXPORT', '/pm/succession',  TRUE)
ON CONFLICT (code) DO NOTHING;

-- ────────────────────────────────────────────────────────────────
-- REWARDS & RECOGNITION — missing pages
-- ────────────────────────────────────────────────────────────────
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('RR_PBB_APPROVE',         'PBB — Approve PBB Record',             'rr', 'ACTION', 'APPROVE', '/rr/pbb',              TRUE),
  ('RR_PBB_EXPORT',          'PBB — Export PBB Report',              'rr', 'ACTION', 'EXPORT',  '/rr/pbb',              TRUE),
  ('RR_SSL_EDIT',            'SSL Table — Edit Salary Schedule',      'rr', 'ACTION', 'EDIT',    '/rr/ssl-table',        TRUE),
  ('RR_SSL_EXPORT',          'SSL Table — Export SSL Table',          'rr', 'ACTION', 'EXPORT',  '/rr/ssl-table',        TRUE),
  ('RR_NOM_CREATE',          'Nominations — Submit Nomination',       'rr', 'ACTION', 'CREATE',  '/rr/nominations',      TRUE),
  ('RR_NOM_APPROVE',         'Nominations — Approve Nomination',      'rr', 'ACTION', 'APPROVE', '/rr/nominations',      TRUE),
  ('RR_LOYALTY_EXPORT',      'Loyalty Awards — Export Report',        'rr', 'ACTION', 'EXPORT',  '/rr/loyalty',          TRUE),
  ('RR_RETIRE_EXPORT',       'Retirement Notices — Export Notices',   'rr', 'ACTION', 'EXPORT',  '/rr/retirement-notices', TRUE)
ON CONFLICT (code) DO NOTHING;

-- ────────────────────────────────────────────────────────────────
-- RSP / RECRUITMENT — missing pages
-- ────────────────────────────────────────────────────────────────
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('RSP_PLANTILLA_EDIT',     'Plantilla — Edit Plantilla Item',      'rsp', 'ACTION', 'EDIT',   '/rsp/plantilla',     TRUE),
  ('RSP_PLANTILLA_EXPORT',   'Plantilla — Export Plantilla',         'rsp', 'ACTION', 'EXPORT', '/rsp/plantilla',     TRUE),
  ('RSP_PLANTILLA_PRINT',    'Plantilla — Print Plantilla',          'rsp', 'ACTION', 'PRINT',  '/rsp/plantilla',     TRUE),
  ('RSP_VACANCY_CREATE',     'Vacancies — Create Vacancy Posting',   'rsp', 'ACTION', 'CREATE', '/rsp/vacancies',     TRUE),
  ('RSP_APPLICANT_EXPORT',   'Applicants — Export Pipeline',         'rsp', 'ACTION', 'EXPORT', '/rsp/applicants',    TRUE),
  ('RSP_ONBOARD_CREATE',     'Onboarding — Create Checklist',        'rsp', 'ACTION', 'CREATE', '/rsp/onboarding',    TRUE),
  ('RSP_ONBOARD_COMPLETE',   'Onboarding — Complete Checklist Item', 'rsp', 'ACTION', 'TOGGLE', '/rsp/onboarding',    TRUE),
  ('RSP_ONBOARD_EXPORT',     'Onboarding — Export Status Report',    'rsp', 'ACTION', 'EXPORT', '/rsp/onboarding',    TRUE),
  ('RSP_APPOINT_PRINT',      'Appointments — Print Appointment',     'rsp', 'ACTION', 'PRINT',  '/rsp/appointments',  TRUE),
  ('RSP_PSB_APPROVE',        'PSB — Approve Deliberation',           'rsp', 'ACTION', 'APPROVE','/rsp/psb',           TRUE)
ON CONFLICT (code) DO NOTHING;

-- ────────────────────────────────────────────────────────────────
-- DOCUMENT MANAGEMENT — missing pages
-- ────────────────────────────────────────────────────────────────
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('DMS_CHECKLIST_EDIT',     'Checklist — Edit Document Checklist',  'dms', 'ACTION', 'EDIT',   '/dms/checklist',  TRUE),
  ('DMS_CHECKLIST_EXPORT',   'Checklist — Export Checklist Status',  'dms', 'ACTION', 'EXPORT', '/dms/checklist',  TRUE),
  ('DMS_RETENTION_EDIT',     'Retention — Edit Retention Policy',    'dms', 'ACTION', 'EDIT',   '/dms/retention',  TRUE),
  ('DMS_CERT_REJECT',        'Certificates — Reject Certificate',    'dms', 'ACTION', 'DELETE', '/dms/certificate-requests', TRUE),
  ('DMS_REQUEST_EXPORT',     'Requests — Export Document Queue',     'dms', 'ACTION', 'EXPORT', '/dms/requests',   TRUE)
ON CONFLICT (code) DO NOTHING;

-- ────────────────────────────────────────────────────────────────
-- LEAVE MANAGEMENT — missing pages
-- ────────────────────────────────────────────────────────────────
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('LV_DASHBOARD_EXPORT',    'Leave Dashboard — Export Summary',     'leave_mgmt', 'ACTION', 'EXPORT', '/leave',          TRUE),
  ('LV_LOCATOR_EXPORT',      'Team Locator — Export Locator',        'leave_mgmt', 'ACTION', 'EXPORT', '/leave/locator',  TRUE)
ON CONFLICT (code) DO NOTHING;

-- ────────────────────────────────────────────────────────────────
-- ORGANIZATION CHART
-- ────────────────────────────────────────────────────────────────
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('ORG_EXPORT',             'Org Chart — Export Chart',             'orgchart', 'ACTION', 'EXPORT', '/orgchart/', TRUE),
  ('ORG_PRINT',              'Org Chart — Print Chart',              'orgchart', 'ACTION', 'PRINT',  '/orgchart/', TRUE)
ON CONFLICT (code) DO NOTHING;

-- ────────────────────────────────────────────────────────────────
-- WORKFLOW
-- ────────────────────────────────────────────────────────────────
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('WF_APPROVE',             'Workflow — Approve / Reject Item',     'workflow', 'ACTION', 'APPROVE', '/workflow', TRUE),
  ('WF_CREATE',              'Workflow — Create Workflow',            'workflow', 'ACTION', 'CREATE',  '/workflow', TRUE),
  ('WF_EXPORT',              'Workflow — Export Workflow Log',        'workflow', 'ACTION', 'EXPORT',  '/workflow', TRUE)
ON CONFLICT (code) DO NOTHING;

-- ────────────────────────────────────────────────────────────────
-- ADMIN — missing page
-- ────────────────────────────────────────────────────────────────
INSERT INTO core.feature_registry (code, name, module, feature_type, action_type, page_path, is_enabled)
VALUES
  ('ADMIN_THEME_EDIT',       'Admin — Change Theme',                 'admin', 'ACTION', 'EDIT',   '/admin/themes',  TRUE),
  ('ADMIN_MOD_ACCESS_EDIT',  'Admin — Edit Modification Access',     'admin', 'ACTION', 'EDIT',   '/admin/access-matrix', TRUE)
ON CONFLICT (code) DO NOTHING;

-- ────────────────────────────────────────────────────────────────
-- DEFAULT GRANTS for all new features
-- ────────────────────────────────────────────────────────────────

-- SUPER_ADMIN + HR_ADMIN: all new action features
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.code, f.id, TRUE
FROM core.feature_registry f,
     (VALUES ('SUPER_ADMIN'), ('HR_ADMIN')) AS r(code)
WHERE f.feature_type = 'ACTION'
  AND f.code IN (
    'CORE_EMP_EXPORT','CORE_EMP_PRINT','CORE_EMP_CREATE','CORE_EMP_EDIT',
    'ESS_PROFILE_EDIT','ESS_ATT_EXPORT','ESS_LV_REQUEST','ESS_LV_CANCEL',
    'ESS_PAY_PRINT','ESS_CERT_REQUEST',
    'MSS_TEAM_LV_APPROVE','MSS_TEAM_ATT_VIEW','MSS_TEAM_EXPORT',
    'AI_CHAT','AI_EXEC_REFRESH','AI_EXEC_EXPORT',
    'ANALYTICS_HC_EXPORT','ANALYTICS_HC_PRINT','ANALYTICS_DEMO_EXPORT','ANALYTICS_DEMO_PRINT',
    'ANALYTICS_SAVED_DELETE','ANALYTICS_SAVED_SHARE','ANALYTICS_SCHED_CREATE','ANALYTICS_SCHED_DELETE',
    'DISC_CASE_INVESTIGATE','DISC_CASE_HEAR','DISC_CASE_CHARGE','DISC_EXPORT',
    'HEALTH_DASHBOARD_EXPORT','HEALTH_CERT_UPLOAD','HEALTH_CERT_APPROVE','HEALTH_PE_SCHEDULE','HEALTH_PE_EXPORT',
    'LD_SESSION_CREATE','LD_SESSION_EDIT','LD_SESSION_EXPORT',
    'LD_SCHOLAR_APPLY','LD_SCHOLAR_APPROVE',
    'LD_TNA_CREATE','LD_TNA_EXPORT','LD_PROGRAMS_CREATE','LD_PROGRAMS_EDIT',
    'PM_CYCLE_CREATE','PM_CYCLE_EDIT','PM_OPCR_FINALIZE','PM_OPCR_EXPORT',
    'PM_RATINGS_EXPORT','PM_SUCCESSION_EDIT','PM_SUCCESSION_EXPORT',
    'RR_PBB_APPROVE','RR_PBB_EXPORT','RR_SSL_EDIT','RR_SSL_EXPORT',
    'RR_NOM_CREATE','RR_NOM_APPROVE','RR_LOYALTY_EXPORT','RR_RETIRE_EXPORT',
    'RSP_PLANTILLA_EDIT','RSP_PLANTILLA_EXPORT','RSP_PLANTILLA_PRINT',
    'RSP_VACANCY_CREATE','RSP_APPLICANT_EXPORT',
    'RSP_ONBOARD_CREATE','RSP_ONBOARD_COMPLETE','RSP_ONBOARD_EXPORT',
    'RSP_APPOINT_PRINT','RSP_PSB_APPROVE',
    'DMS_CHECKLIST_EDIT','DMS_CHECKLIST_EXPORT','DMS_RETENTION_EDIT',
    'DMS_CERT_REJECT','DMS_REQUEST_EXPORT',
    'LV_DASHBOARD_EXPORT','LV_LOCATOR_EXPORT',
    'ORG_EXPORT','ORG_PRINT',
    'WF_APPROVE','WF_CREATE','WF_EXPORT',
    'ADMIN_THEME_EDIT','ADMIN_MOD_ACCESS_EDIT'
  )
ON CONFLICT (role_code, feature_id) DO NOTHING;

-- MANAGER: view/approve/export/create — exclude admin/payroll-sensitive
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT 'MANAGER', f.id, TRUE
FROM core.feature_registry f
WHERE f.feature_type = 'ACTION'
  AND f.action_type IN ('VIEW','APPROVE','PRINT','EXPORT','CREATE','TOGGLE')
  AND f.code IN (
    'CORE_EMP_EXPORT','CORE_EMP_PRINT',
    'ESS_ATT_EXPORT','ESS_LV_REQUEST','ESS_LV_CANCEL','ESS_PAY_PRINT','ESS_CERT_REQUEST',
    'MSS_TEAM_LV_APPROVE','MSS_TEAM_ATT_VIEW','MSS_TEAM_EXPORT',
    'AI_CHAT','AI_EXEC_EXPORT',
    'ANALYTICS_HC_EXPORT','ANALYTICS_HC_PRINT','ANALYTICS_DEMO_EXPORT',
    'ANALYTICS_SAVED_DELETE','ANALYTICS_SAVED_SHARE','ANALYTICS_SCHED_CREATE',
    'DISC_CASE_HEAR','DISC_EXPORT',
    'HEALTH_DASHBOARD_EXPORT','HEALTH_CERT_UPLOAD','HEALTH_PE_EXPORT',
    'LD_SESSION_EXPORT','LD_SCHOLAR_APPLY','LD_TNA_EXPORT',
    'PM_OPCR_EXPORT','PM_RATINGS_EXPORT','PM_SUCCESSION_EXPORT',
    'RR_PBB_EXPORT','RR_SSL_EXPORT','RR_NOM_CREATE','RR_LOYALTY_EXPORT','RR_RETIRE_EXPORT',
    'RSP_PLANTILLA_EXPORT','RSP_PLANTILLA_PRINT','RSP_APPLICANT_EXPORT',
    'RSP_ONBOARD_COMPLETE','RSP_ONBOARD_EXPORT','RSP_APPOINT_PRINT',
    'DMS_CHECKLIST_EXPORT','DMS_REQUEST_EXPORT',
    'LV_DASHBOARD_EXPORT','LV_LOCATOR_EXPORT',
    'ORG_EXPORT','ORG_PRINT',
    'WF_APPROVE','WF_EXPORT'
  )
ON CONFLICT (role_code, feature_id) DO NOTHING;

-- EMPLOYEE: own self-service actions only
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT 'EMPLOYEE', f.id, TRUE
FROM core.feature_registry f
WHERE f.code IN (
    'ESS_PROFILE_EDIT','ESS_ATT_EXPORT','ESS_LV_REQUEST','ESS_LV_CANCEL',
    'ESS_PAY_PRINT','ESS_CERT_REQUEST',
    'AI_CHAT',
    'LD_SCHOLAR_APPLY','LD_CHECKIN','LD_NARRATIVE_SUBMIT',
    'ORG_PRINT','ORG_EXPORT',
    'HEALTH_ENROLL','HEALTH_INCIDENT',
    'WF_APPROVE'
  )
ON CONFLICT (role_code, feature_id) DO NOTHING;
