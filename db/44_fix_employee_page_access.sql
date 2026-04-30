-- ================================================================
-- HCM360 — 44: FIX EMPLOYEE & HR_ADMIN PAGE ACCESS
-- Corrects pages blocked for EMPLOYEE that they legitimately need.
-- Also seeds missing rows for new pages added in migration 43.
-- ================================================================
SET search_path TO core, public;

-- ────────────────────────────────────────────────────────────────
-- Helper: upsert a page grant by path + role
-- ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION core._upsert_page_access(
    p_path      VARCHAR,
    p_role      VARCHAR,
    p_access    BOOLEAN
) RETURNS VOID AS $$
DECLARE v_page_id BIGINT;
BEGIN
    SELECT id INTO v_page_id FROM core.page_registry WHERE path = p_path;
    IF v_page_id IS NULL THEN RETURN; END IF;

    INSERT INTO core.role_page_access (role_code, page_id, can_access)
    VALUES (p_role, v_page_id, p_access)
    ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = EXCLUDED.can_access;
END;
$$ LANGUAGE plpgsql;

-- ────────────────────────────────────────────────────────────────
-- EMPLOYEE — pages they SHOULD access
-- ────────────────────────────────────────────────────────────────
DO $$ BEGIN

  -- Core
  PERFORM core._upsert_page_access('/',                        'EMPLOYEE', TRUE);
  PERFORM core._upsert_page_access('/employees',               'EMPLOYEE', TRUE);

  -- ESS / MSS (own profile & self-service)
  PERFORM core._upsert_page_access('/me',                      'EMPLOYEE', TRUE);
  PERFORM core._upsert_page_access('/me/attendance',           'EMPLOYEE', TRUE);
  PERFORM core._upsert_page_access('/me/leaves',               'EMPLOYEE', TRUE);
  PERFORM core._upsert_page_access('/me/payslips',             'EMPLOYEE', TRUE);
  PERFORM core._upsert_page_access('/me/certificates',         'EMPLOYEE', TRUE);

  -- Attendance (own OT requests only — NOT admin DTR view)
  PERFORM core._upsert_page_access('/attendance/overtime',     'EMPLOYEE', TRUE);

  -- Leave (own requests)
  PERFORM core._upsert_page_access('/leave',                   'EMPLOYEE', TRUE);
  PERFORM core._upsert_page_access('/leave/requests',          'EMPLOYEE', TRUE);
  PERFORM core._upsert_page_access('/leave/balances',          'EMPLOYEE', TRUE);
  PERFORM core._upsert_page_access('/leave/travel-orders',     'EMPLOYEE', TRUE);

  -- DMS (own document requests & certificates)
  PERFORM core._upsert_page_access('/dms/',                    'EMPLOYEE', TRUE);
  PERFORM core._upsert_page_access('/dms/requests',            'EMPLOYEE', TRUE);

  -- Health (report incidents, enroll in wellness)
  PERFORM core._upsert_page_access('/health/',                 'EMPLOYEE', TRUE);
  PERFORM core._upsert_page_access('/health/wellness',         'EMPLOYEE', TRUE);
  PERFORM core._upsert_page_access('/health/incidents',        'EMPLOYEE', TRUE);

  -- L&D (view catalog, check in, submit narrative, apply scholarship)
  PERFORM core._upsert_page_access('/ld/programs',             'EMPLOYEE', TRUE);
  PERFORM core._upsert_page_access('/ld/sessions',             'EMPLOYEE', TRUE);
  PERFORM core._upsert_page_access('/ld/attendance',           'EMPLOYEE', TRUE);
  PERFORM core._upsert_page_access('/ld/narrative-reports',    'EMPLOYEE', TRUE);
  PERFORM core._upsert_page_access('/ld/scholarships',         'EMPLOYEE', TRUE);
  PERFORM core._upsert_page_access('/ld/tna',                  'EMPLOYEE', TRUE);

  -- Performance (own IPCR)
  PERFORM core._upsert_page_access('/pm/ipcr',                 'EMPLOYEE', TRUE);
  PERFORM core._upsert_page_access('/pm/cycles',               'EMPLOYEE', TRUE);

  -- Payroll (own payslips via ESS, own loan records)
  PERFORM core._upsert_page_access('/payroll/loans',           'EMPLOYEE', TRUE);

  -- RSP (view vacancies, access own onboarding checklist)
  PERFORM core._upsert_page_access('/rsp/vacancies',           'EMPLOYEE', TRUE);
  PERFORM core._upsert_page_access('/rsp/onboarding',          'EMPLOYEE', TRUE);

  -- R&R (view/submit nominations, view own loyalty status)
  PERFORM core._upsert_page_access('/rr/nominations',          'EMPLOYEE', TRUE);
  PERFORM core._upsert_page_access('/rr/loyalty',              'EMPLOYEE', TRUE);

  -- Org Chart
  PERFORM core._upsert_page_access('/orgchart/',               'EMPLOYEE', TRUE);

  -- Workflow (approve own pending items)
  PERFORM core._upsert_page_access('/workflow',                'EMPLOYEE', TRUE);

  -- AI Assistant
  PERFORM core._upsert_page_access('/ai/assistant',            'EMPLOYEE', TRUE);

END $$;

-- ────────────────────────────────────────────────────────────────
-- EMPLOYEE — pages they should NOT access (explicit deny)
-- ────────────────────────────────────────────────────────────────
DO $$ BEGIN
  -- Admin
  PERFORM core._upsert_page_access('/admin/access-matrix',     'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/admin/demo-data',         'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/admin/reference',         'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/admin/themes',            'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/admin/users',             'EMPLOYEE', FALSE);

  -- Attendance admin views
  PERFORM core._upsert_page_access('/attendance/dtr',          'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/attendance/shifts',       'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/attendance/shift-assignments','EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/attendance/alerts',       'EMPLOYEE', FALSE);

  -- Analytics (management view)
  PERFORM core._upsert_page_access('/reports',                 'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/reports/builder',         'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/reports/demographics',    'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/reports/headcount',       'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/reports/saved',           'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/reports/scheduled',       'EMPLOYEE', FALSE);

  -- Discipline (HR/admin only)
  PERFORM core._upsert_page_access('/discipline/',             'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/discipline/cases/new',    'EMPLOYEE', FALSE);

  -- DMS admin views
  PERFORM core._upsert_page_access('/dms/certificate-requests','EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/dms/checklist',           'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/dms/retention',           'EMPLOYEE', FALSE);

  -- Health admin
  PERFORM core._upsert_page_access('/health/pe',               'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/health/certificates',     'EMPLOYEE', FALSE);

  -- Leave admin
  PERFORM core._upsert_page_access('/leave/cto',               'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/leave/locator',           'EMPLOYEE', FALSE);

  -- Payroll admin
  PERFORM core._upsert_page_access('/payroll',                 'EMPLOYEE', FALSE);

  -- PM management views
  PERFORM core._upsert_page_access('/pm/opcr',                 'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/pm/ratings',              'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/pm/succession',           'EMPLOYEE', FALSE);

  -- R&R admin
  PERFORM core._upsert_page_access('/rr/pbb',                  'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/rr/ssl-table',            'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/rr/step-increments',      'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/rr/retirement-notices',   'EMPLOYEE', FALSE);

  -- RSP admin
  PERFORM core._upsert_page_access('/rsp/applicants',          'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/rsp/appointments',        'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/rsp/next-in-rank',        'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/rsp/offboarding',         'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/rsp/plantilla',           'EMPLOYEE', FALSE);
  PERFORM core._upsert_page_access('/rsp/psb',                 'EMPLOYEE', FALSE);

  -- MSS (manager-only)
  PERFORM core._upsert_page_access('/my-team',                 'EMPLOYEE', FALSE);

  -- AI Executive (management only)
  PERFORM core._upsert_page_access('/ai/executive',            'EMPLOYEE', FALSE);

END $$;

-- ────────────────────────────────────────────────────────────────
-- HR_ADMIN — seed any missing new pages (all TRUE)
-- ────────────────────────────────────────────────────────────────
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT 'HR_ADMIN', p.id, TRUE
FROM core.page_registry p
WHERE NOT EXISTS (
    SELECT 1 FROM core.role_page_access rpa
    WHERE rpa.page_id = p.id AND rpa.role_code = 'HR_ADMIN'
)
ON CONFLICT (role_code, page_id) DO NOTHING;

-- MANAGER — seed any missing new pages (all TRUE)
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT 'MANAGER', p.id, TRUE
FROM core.page_registry p
WHERE NOT EXISTS (
    SELECT 1 FROM core.role_page_access rpa
    WHERE rpa.page_id = p.id AND rpa.role_code = 'MANAGER'
)
ON CONFLICT (role_code, page_id) DO NOTHING;

-- Clean up helper function
DROP FUNCTION IF EXISTS core._upsert_page_access(VARCHAR, VARCHAR, BOOLEAN);
