-- ================================================================
-- HCM360 — 46: FINAL ACCESS MATRIX CORRECTION
--
-- Principles:
--   SUPER_ADMIN  → bypassed in code (can_access_page always True)
--   HR_ADMIN     → full HR ops; restricted admin (themes, reference,
--                  users, reminders only — NOT access-matrix/demo-data)
--   MANAGER      → team management; NO admin access
--   EXECUTIVE    → read-only dashboards & analytics; NO admin access
--   EMPLOYEE     → self-service only; NO admin access
--
-- capsanchez (user_id=6) is SUPER_ADMIN — already has unrestricted access.
-- ================================================================
SET search_path TO core, public;

-- ────────────────────────────────────────────────────────────────
-- Helper
-- ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION core._set_access(
    p_path   VARCHAR,
    p_role   VARCHAR,
    p_access BOOLEAN
) RETURNS VOID AS $$
DECLARE v_id BIGINT;
BEGIN
    SELECT id INTO v_id FROM core.page_registry WHERE path = p_path;
    IF v_id IS NULL THEN RETURN; END IF;
    INSERT INTO core.role_page_access (role_code, page_id, can_access)
    VALUES (p_role, v_id, p_access)
    ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = EXCLUDED.can_access;
END;
$$ LANGUAGE plpgsql;


-- ════════════════════════════════════════════════════════════════
-- 1. ADMIN PAGES — SUPER_ADMIN only
--    Remove MANAGER / HR_ADMIN / EXECUTIVE / EMPLOYEE access
-- ════════════════════════════════════════════════════════════════
DO $$ BEGIN
  PERFORM core._set_access('/admin/access-matrix',   'MANAGER',   FALSE);
  PERFORM core._set_access('/admin/access-matrix',   'HR_ADMIN',  FALSE);
  PERFORM core._set_access('/admin/access-matrix',   'EXECUTIVE', FALSE);
  PERFORM core._set_access('/admin/access-matrix',   'EMPLOYEE',  FALSE);

  PERFORM core._set_access('/admin/demo-data',       'MANAGER',   FALSE);
  PERFORM core._set_access('/admin/demo-data',       'HR_ADMIN',  FALSE);
  PERFORM core._set_access('/admin/demo-data',       'EXECUTIVE', FALSE);
  PERFORM core._set_access('/admin/demo-data',       'EMPLOYEE',  FALSE);

  PERFORM core._set_access('/admin/themes',          'MANAGER',   FALSE);
  PERFORM core._set_access('/admin/themes',          'EXECUTIVE', FALSE);
  PERFORM core._set_access('/admin/themes',          'EMPLOYEE',  FALSE);

  PERFORM core._set_access('/admin/users',           'MANAGER',   FALSE);
  PERFORM core._set_access('/admin/users',           'EXECUTIVE', FALSE);
  PERFORM core._set_access('/admin/users',           'EMPLOYEE',  FALSE);

  PERFORM core._set_access('/admin/reference',       'MANAGER',   FALSE);
  PERFORM core._set_access('/admin/reference',       'EXECUTIVE', FALSE);
  PERFORM core._set_access('/admin/reference',       'EMPLOYEE',  FALSE);
END $$;

-- HR_ADMIN keeps themes + reference + users (operational, not system config)
DO $$ BEGIN
  PERFORM core._set_access('/admin/themes',    'HR_ADMIN', TRUE);
  PERFORM core._set_access('/admin/reference', 'HR_ADMIN', TRUE);
  PERFORM core._set_access('/admin/users',     'HR_ADMIN', TRUE);
END $$;


-- ════════════════════════════════════════════════════════════════
-- 2. EXECUTIVE — read-only access to dashboards & analytics
-- ════════════════════════════════════════════════════════════════
DO $$ BEGIN
  -- Core
  PERFORM core._set_access('/',                          'EXECUTIVE', TRUE);
  PERFORM core._set_access('/employees',                 'EXECUTIVE', TRUE);
  PERFORM core._set_access('/search',                    'EXECUTIVE', TRUE);

  -- Self-service (own profile)
  PERFORM core._set_access('/me',                        'EXECUTIVE', TRUE);
  PERFORM core._set_access('/me/attendance',             'EXECUTIVE', TRUE);
  PERFORM core._set_access('/me/leaves',                 'EXECUTIVE', TRUE);
  PERFORM core._set_access('/me/payslips',               'EXECUTIVE', TRUE);
  PERFORM core._set_access('/me/certificates',           'EXECUTIVE', TRUE);

  -- Workforce (read-only view)
  PERFORM core._set_access('/leave',                     'EXECUTIVE', TRUE);
  PERFORM core._set_access('/leave/requests',            'EXECUTIVE', TRUE);
  PERFORM core._set_access('/leave/balances',            'EXECUTIVE', TRUE);
  PERFORM core._set_access('/leave/locator',             'EXECUTIVE', TRUE);
  PERFORM core._set_access('/leave/travel-orders',       'EXECUTIVE', TRUE);
  PERFORM core._set_access('/leave/cto',                 'EXECUTIVE', FALSE);
  PERFORM core._set_access('/attendance/dtr',            'EXECUTIVE', TRUE);
  PERFORM core._set_access('/attendance/overtime',       'EXECUTIVE', TRUE);
  PERFORM core._set_access('/attendance/alerts',         'EXECUTIVE', TRUE);
  PERFORM core._set_access('/attendance/shifts',         'EXECUTIVE', FALSE);
  PERFORM core._set_access('/attendance/shift-assignments','EXECUTIVE',FALSE);

  -- Payroll (view only — no admin)
  PERFORM core._set_access('/payroll',                   'EXECUTIVE', FALSE);
  PERFORM core._set_access('/payroll/loans',             'EXECUTIVE', FALSE);

  -- Workflow
  PERFORM core._set_access('/workflow',                  'EXECUTIVE', TRUE);

  -- AI
  PERFORM core._set_access('/ai/executive',              'EXECUTIVE', TRUE);
  PERFORM core._set_access('/ai/assistant',              'EXECUTIVE', TRUE);

  -- Admin — none
  PERFORM core._set_access('/admin/themes',              'EXECUTIVE', FALSE);
  PERFORM core._set_access('/admin/users',               'EXECUTIVE', FALSE);
  PERFORM core._set_access('/admin/access-matrix',       'EXECUTIVE', FALSE);
  PERFORM core._set_access('/admin/reference',           'EXECUTIVE', FALSE);
  PERFORM core._set_access('/admin/demo-data',           'EXECUTIVE', FALSE);
END $$;


-- ════════════════════════════════════════════════════════════════
-- 3. MANAGER — team management; NO admin
-- ════════════════════════════════════════════════════════════════
DO $$ BEGIN
  -- Explicitly deny all admin pages
  PERFORM core._set_access('/admin/themes',              'MANAGER', FALSE);
  PERFORM core._set_access('/admin/users',               'MANAGER', FALSE);
  PERFORM core._set_access('/admin/access-matrix',       'MANAGER', FALSE);
  PERFORM core._set_access('/admin/reference',           'MANAGER', FALSE);
  PERFORM core._set_access('/admin/demo-data',           'MANAGER', FALSE);

  -- Payroll: managers view runs but not full admin
  PERFORM core._set_access('/payroll',                   'MANAGER', FALSE);
  PERFORM core._set_access('/payroll/loans',             'MANAGER', TRUE);

  -- MSS
  PERFORM core._set_access('/my-team',                   'MANAGER', TRUE);
END $$;


-- ════════════════════════════════════════════════════════════════
-- 4. EMPLOYEE — self-service only; explicit denies
-- ════════════════════════════════════════════════════════════════
DO $$ BEGIN
  -- Admin — all denied (belt-and-suspenders)
  PERFORM core._set_access('/admin/themes',              'EMPLOYEE', FALSE);
  PERFORM core._set_access('/admin/users',               'EMPLOYEE', FALSE);
  PERFORM core._set_access('/admin/access-matrix',       'EMPLOYEE', FALSE);
  PERFORM core._set_access('/admin/reference',           'EMPLOYEE', FALSE);
  PERFORM core._set_access('/admin/demo-data',           'EMPLOYEE', FALSE);

  -- Team/management views
  PERFORM core._set_access('/my-team',                   'EMPLOYEE', FALSE);
  PERFORM core._set_access('/leave/cto',                 'EMPLOYEE', FALSE);
  PERFORM core._set_access('/attendance/dtr',            'EMPLOYEE', FALSE);
  PERFORM core._set_access('/attendance/shifts',         'EMPLOYEE', FALSE);
  PERFORM core._set_access('/attendance/shift-assignments','EMPLOYEE',FALSE);
  PERFORM core._set_access('/attendance/alerts',         'EMPLOYEE', FALSE);
  PERFORM core._set_access('/payroll',                   'EMPLOYEE', FALSE);
  PERFORM core._set_access('/ai/executive',              'EMPLOYEE', FALSE);

  -- Allowed self-service
  PERFORM core._set_access('/leave/locator',             'EMPLOYEE', TRUE);
  PERFORM core._set_access('/attendance/overtime',       'EMPLOYEE', TRUE);
  PERFORM core._set_access('/payroll/loans',             'EMPLOYEE', TRUE);
  PERFORM core._set_access('/workflow',                  'EMPLOYEE', TRUE);
END $$;


-- ════════════════════════════════════════════════════════════════
-- 5. HR_ADMIN — full HR ops (already seeded TRUE for most pages)
--    Explicit denies for system-level pages
-- ════════════════════════════════════════════════════════════════
DO $$ BEGIN
  PERFORM core._set_access('/admin/access-matrix',       'HR_ADMIN', FALSE);
  PERFORM core._set_access('/admin/demo-data',           'HR_ADMIN', FALSE);
  PERFORM core._set_access('/my-team',                   'HR_ADMIN', TRUE);
  PERFORM core._set_access('/payroll/loans',             'HR_ADMIN', TRUE);
  PERFORM core._set_access('/workflow',                  'HR_ADMIN', TRUE);
END $$;


-- ════════════════════════════════════════════════════════════════
-- 6. EMPLOYEE 201 FILE — /employees/ (prefix pattern for detail pages)
--    HR_ADMIN + MANAGER can view; EXECUTIVE + EMPLOYEE cannot
-- ════════════════════════════════════════════════════════════════
INSERT INTO core.page_registry (path, title, module, is_visible)
VALUES ('/employees/', 'Employee 201 File', 'dms', FALSE)
ON CONFLICT (path) DO UPDATE SET title = EXCLUDED.title, module = EXCLUDED.module;

DO $$ BEGIN
  PERFORM core._set_access('/employees/', 'SUPER_ADMIN', TRUE);
  PERFORM core._set_access('/employees/', 'HR_ADMIN',    TRUE);
  PERFORM core._set_access('/employees/', 'MANAGER',     TRUE);
  PERFORM core._set_access('/employees/', 'EXECUTIVE',   FALSE);
  PERFORM core._set_access('/employees/', 'EMPLOYEE',    FALSE);
END $$;


-- ────────────────────────────────────────────────────────────────
-- Clean up helper
-- ────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS core._set_access(VARCHAR, VARCHAR, BOOLEAN);
