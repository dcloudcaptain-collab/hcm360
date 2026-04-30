-- ================================================================
-- HCM360 — 78: ROLE TAXONOMY (industry-standard, no overlap)
--
-- Adds 9 specialised HR roles + a data_scope column on core.roles
-- so row-level visibility (self / department / reports / all) is
-- declared per role and read by services.access_service.
--
-- See doc/role_authority_matrix.md for the authoritative matrix.
-- Idempotent: safe to re-run.
-- ================================================================
BEGIN;

-- ── Schema: data_scope on roles ───────────────────────────────────
ALTER TABLE core.roles
  ADD COLUMN IF NOT EXISTS data_scope VARCHAR(20) NOT NULL DEFAULT 'ALL'
    CHECK (data_scope IN ('SELF','DEPARTMENT','REPORTS','ALL'));

-- ── Roles: upsert the canonical taxonomy via CTE (composite unique on (company_id, code)) ──
WITH wanted (code, name, description, data_scope) AS (
  VALUES
  ('EMPLOYEE',                'Employee',                          'Self-service only; sees own profile and own-department directory.', 'DEPARTMENT'),
  ('MANAGER',                 'Line Manager',                      'Approves team; sees direct + indirect reports.',                   'REPORTS'),
  ('EXECUTIVE',               'Department / Division Head',        'Department-wide read; approves dept-level requests.',               'DEPARTMENT'),
  ('HR_RECRUITER',            'HR — Recruitment Officer',          'Owns RSP module: plantilla, vacancies, applicants, onboarding.',    'ALL'),
  ('HR_TIME_OFFICER',         'HR — Time & Attendance Officer',    'Owns Time & Attendance + Leave & Absence.',                         'ALL'),
  ('HR_COMP_OFFICER',         'HR — Compensation Officer',         'Owns Compensation & Rewards (SSL, step-inc, loyalty, PBB, retirement).', 'ALL'),
  ('HR_LEARNING_OFFICER',     'HR — Learning Officer',             'Owns Learning & Development.',                                      'ALL'),
  ('HR_PERFORMANCE_OFFICER',  'HR — Performance Officer',          'Owns Performance Management cycles, IPCR/OPCR, succession.',        'ALL'),
  ('HR_RELATIONS_OFFICER',    'HR — Employee Relations Officer',   'Owns Discipline + Health & Safety.',                                'ALL'),
  ('HR_RECORDS_OFFICER',      'HR — Records Officer',              'Owns Employee Records / 201 File / DMS.',                           'ALL'),
  ('HR_MANAGER',              'HR Manager',                        'HR leadership; supervises all HR-Ops officers; analytics admin.',   'ALL'),
  ('PAYROLL_OFFICER',         'Payroll Officer',                   'Payroll runs, loans; reads Time & Attendance and Compensation.',    'ALL'),
  ('IT_ADMIN',                'IT / System Administrator',         'System config, branding, themes, workflow engine. No employee data write.', 'ALL'),
  ('HR_ADMIN',                'HR Manager (legacy alias)',         'Backwards-compat alias for HR_MANAGER.',                            'ALL'),
  ('SUPER_ADMIN',             'Super Admin',                       'Unrestricted.',                                                     'ALL')
),
upd AS (
  UPDATE core.roles r
  SET name = w.name, description = w.description, data_scope = w.data_scope
  FROM wanted w
  WHERE r.code = w.code AND r.company_id IS NULL
  RETURNING r.code
)
INSERT INTO core.roles (company_id, code, name, description, data_scope)
SELECT NULL, w.code, w.name, w.description, w.data_scope
FROM wanted w
WHERE w.code NOT IN (SELECT code FROM upd)
  AND NOT EXISTS (SELECT 1 FROM core.roles r WHERE r.code = w.code AND r.company_id IS NULL);

-- ── Re-seed role_page_access from scratch for the new roles ───────
-- For each new role we re-derive grants from the role × module matrix.
-- Existing legacy roles (EMPLOYEE/MANAGER/EXECUTIVE/HR_ADMIN/SUPER_ADMIN)
-- keep their current grants — we only TIGHTEN where the matrix says ✗.

-- Helper: a temp lookup of (role, module, granted) following the matrix.
DROP TABLE IF EXISTS tmp_grants;
CREATE TEMP TABLE tmp_grants (role_code VARCHAR(50), module VARCHAR(50), granted BOOLEAN);

-- Universal-access modules (every role): core, ess_mss, ai
INSERT INTO tmp_grants
SELECT r, m, TRUE
FROM unnest(ARRAY['EMPLOYEE','MANAGER','EXECUTIVE',
                  'HR_RECRUITER','HR_TIME_OFFICER','HR_COMP_OFFICER',
                  'HR_LEARNING_OFFICER','HR_PERFORMANCE_OFFICER',
                  'HR_RELATIONS_OFFICER','HR_RECORDS_OFFICER',
                  'HR_MANAGER','HR_ADMIN','PAYROLL_OFFICER','IT_ADMIN','SUPER_ADMIN']) AS r,
     unnest(ARRAY['core','ess_mss','ai']) AS m;

-- Vertical owners (full ✓)
INSERT INTO tmp_grants VALUES
  ('HR_RECRUITER',           'rsp',                TRUE),
  ('HR_TIME_OFFICER',        'attendance',         TRUE),
  ('HR_TIME_OFFICER',        'leave_mgmt',         TRUE),
  ('HR_COMP_OFFICER',        'rr',                 TRUE),
  ('HR_LEARNING_OFFICER',    'ld',                 TRUE),
  ('HR_PERFORMANCE_OFFICER', 'pm',                 TRUE),
  ('HR_RELATIONS_OFFICER',   'discipline',         TRUE),
  ('HR_RELATIONS_OFFICER',   'health',             TRUE),
  ('HR_RECORDS_OFFICER',     'dms',                TRUE),
  ('PAYROLL_OFFICER',        'payroll',            TRUE),
  ('IT_ADMIN',               'admin',              TRUE),
  ('IT_ADMIN',               'workflow',           TRUE);

-- HR_MANAGER (and legacy HR_ADMIN): all HR modules + analytics + workforce_planning + orgchart
INSERT INTO tmp_grants
SELECT r, m, TRUE
FROM unnest(ARRAY['HR_MANAGER','HR_ADMIN']) AS r,
     unnest(ARRAY['rsp','attendance','leave_mgmt','rr','ld','pm','discipline','health','dms',
                  'analytics','data_sources','workforce_planning','orgchart']) AS m;

-- SUPER_ADMIN: everything
INSERT INTO tmp_grants
SELECT 'SUPER_ADMIN', module, TRUE FROM core.page_registry WHERE module IS NOT NULL
UNION
SELECT 'SUPER_ADMIN', m, TRUE FROM unnest(ARRAY['admin','workflow']) m;

-- Read-only modules (◐): every HR-Ops role gets read on analytics; PAYROLL_OFFICER reads attendance/leave/rr/dms; MANAGER reads everything ESS-relevant
INSERT INTO tmp_grants
SELECT r, 'analytics', TRUE
FROM unnest(ARRAY['EMPLOYEE','MANAGER','EXECUTIVE',
                  'HR_RECRUITER','HR_TIME_OFFICER','HR_COMP_OFFICER',
                  'HR_LEARNING_OFFICER','HR_PERFORMANCE_OFFICER',
                  'HR_RELATIONS_OFFICER','HR_RECORDS_OFFICER',
                  'PAYROLL_OFFICER']) AS r;

INSERT INTO tmp_grants VALUES
  ('PAYROLL_OFFICER','attendance', TRUE),
  ('PAYROLL_OFFICER','leave_mgmt', TRUE),
  ('PAYROLL_OFFICER','rr',         TRUE),
  ('PAYROLL_OFFICER','dms',        TRUE),
  ('EMPLOYEE',       'dms',        TRUE),  -- ESS view of own docs
  ('EMPLOYEE',       'attendance', TRUE),
  ('EMPLOYEE',       'leave_mgmt', TRUE),
  ('EMPLOYEE',       'health',     TRUE),
  ('EMPLOYEE',       'pm',         TRUE),  -- own IPCR
  ('EMPLOYEE',       'ld',         TRUE),  -- own learning
  ('MANAGER',        'attendance', TRUE),
  ('MANAGER',        'leave_mgmt', TRUE),
  ('MANAGER',        'rr',         TRUE),
  ('MANAGER',        'pm',         TRUE),
  ('MANAGER',        'ld',         TRUE),
  ('MANAGER',        'discipline', TRUE),
  ('MANAGER',        'health',     TRUE),
  ('MANAGER',        'dms',        TRUE),
  ('MANAGER',        'workforce_planning', TRUE),
  ('MANAGER',        'orgchart',   TRUE),
  ('EXECUTIVE',      'rsp',        TRUE),
  ('EXECUTIVE',      'attendance', TRUE),
  ('EXECUTIVE',      'leave_mgmt', TRUE),
  ('EXECUTIVE',      'rr',         TRUE),
  ('EXECUTIVE',      'pm',         TRUE),
  ('EXECUTIVE',      'ld',         TRUE),
  ('EXECUTIVE',      'discipline', TRUE),
  ('EXECUTIVE',      'health',     TRUE),
  ('EXECUTIVE',      'dms',        TRUE),
  ('EXECUTIVE',      'workforce_planning', TRUE),
  ('EXECUTIVE',      'orgchart',   TRUE),
  ('EXECUTIVE',      'payroll',    TRUE),
  ('HR_MANAGER',     'admin',      TRUE),  -- ◐: read-only access matrix
  ('HR_ADMIN',       'admin',      TRUE);

-- ── Apply: insert role_page_access rows for the new HR-Ops roles ──
-- (legacy roles' grants are NOT touched — preserves prior state)

INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT g.role_code, p.id, g.granted
FROM tmp_grants g
JOIN core.page_registry p ON p.module = g.module
WHERE g.role_code IN (
  'HR_RECRUITER','HR_TIME_OFFICER','HR_COMP_OFFICER',
  'HR_LEARNING_OFFICER','HR_PERFORMANCE_OFFICER',
  'HR_RELATIONS_OFFICER','HR_RECORDS_OFFICER',
  'HR_MANAGER','PAYROLL_OFFICER','IT_ADMIN'
)
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = EXCLUDED.can_access;

-- Explicit denies: for the 10 new roles, anything NOT in tmp_grants is denied.
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.r, p.id, FALSE
FROM unnest(ARRAY['HR_RECRUITER','HR_TIME_OFFICER','HR_COMP_OFFICER',
                  'HR_LEARNING_OFFICER','HR_PERFORMANCE_OFFICER',
                  'HR_RELATIONS_OFFICER','HR_RECORDS_OFFICER',
                  'HR_MANAGER','PAYROLL_OFFICER','IT_ADMIN']) AS r(r)
CROSS JOIN core.page_registry p
WHERE p.module IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM tmp_grants g
    WHERE g.role_code = r.r AND g.module = p.module AND g.granted
  )
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = EXCLUDED.can_access;

DROP TABLE tmp_grants;

COMMIT;
