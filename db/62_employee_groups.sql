-- ══════════════════════════════════════════════════════════════════════
-- 62 · Employee Groups (custom cohorts for the global employee picker)
-- ══════════════════════════════════════════════════════════════════════
-- Backs the reusable picker used by Task Templates spawning, bulk task
-- assignment, bulk messaging, training cohort selection, etc.
--
-- Groups can be:
--   · PUBLIC   — visible to every user
--   · DEPT     — visible only to members of the same department
--   · PRIVATE  — visible only to the creator and SUPER_ADMIN
-- ══════════════════════════════════════════════════════════════════════

-- Group header
CREATE TABLE IF NOT EXISTS core.employee_groups (
    id            BIGSERIAL PRIMARY KEY,
    code          VARCHAR(60) UNIQUE,          -- optional short code (e.g. 'PROBATIONARY_2026')
    name          VARCHAR(150) NOT NULL,
    description   TEXT,
    visibility    VARCHAR(20) NOT NULL DEFAULT 'PUBLIC'
                    CHECK (visibility IN ('PUBLIC','DEPT','PRIVATE')),
    created_by    BIGINT REFERENCES core.users(id),
    department_id BIGINT REFERENCES core.departments(id),  -- auto-scoped for DEPT visibility
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_emp_groups_creator ON core.employee_groups(created_by);
CREATE INDEX IF NOT EXISTS idx_emp_groups_dept    ON core.employee_groups(department_id);

-- Group members
CREATE TABLE IF NOT EXISTS core.employee_group_members (
    group_id      BIGINT NOT NULL REFERENCES core.employee_groups(id) ON DELETE CASCADE,
    employee_id   BIGINT NOT NULL REFERENCES core.employees(id)        ON DELETE CASCADE,
    added_by      BIGINT REFERENCES core.users(id),
    added_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (group_id, employee_id)
);
CREATE INDEX IF NOT EXISTS idx_emp_group_members_emp ON core.employee_group_members(employee_id);

-- ── Seed a few example groups so the picker has content on first render
DO $$
DECLARE admin_uid BIGINT;
BEGIN
    SELECT id INTO admin_uid FROM core.users WHERE role_code='SUPER_ADMIN' ORDER BY id LIMIT 1;

    -- Probationary employees (hired in the last 6 months)
    INSERT INTO core.employee_groups (code, name, description, visibility, created_by)
    VALUES ('PROBATIONARY', 'Probationary Employees',
            'Employees hired in the last 6 months — probationary period tracking',
            'PUBLIC', admin_uid)
    ON CONFLICT (code) DO NOTHING;

    -- Department heads
    INSERT INTO core.employee_groups (code, name, description, visibility, created_by)
    VALUES ('DEPT_HEADS', 'Department Heads',
            'All employees currently flagged as department head / manager',
            'PUBLIC', admin_uid)
    ON CONFLICT (code) DO NOTHING;

    -- Backfill PROBATIONARY members from hire_date
    INSERT INTO core.employee_group_members (group_id, employee_id, added_by)
    SELECT g.id, e.id, admin_uid
      FROM core.employee_groups g, core.employees e
     WHERE g.code = 'PROBATIONARY'
       AND e.is_active
       AND e.date_hired >= CURRENT_DATE - INTERVAL '6 months'
    ON CONFLICT DO NOTHING;

    -- Backfill DEPT_HEADS — use department head_employee_id
    INSERT INTO core.employee_group_members (group_id, employee_id, added_by)
    SELECT g.id, d.head_employee_id, admin_uid
      FROM core.employee_groups g
      JOIN core.departments d ON d.head_employee_id IS NOT NULL
     WHERE g.code = 'DEPT_HEADS'
    ON CONFLICT DO NOTHING;
END $$;

-- Page + feature registry for the groups admin page
INSERT INTO core.page_registry (path, title, module, nav_group, nav_label, nav_icon, nav_order, is_visible)
VALUES ('/admin/employee-groups', 'Employee Groups', 'core', 'Admin', 'Employee Groups', 'users-2', 52, TRUE)
ON CONFLICT (path) DO UPDATE SET
    title     = EXCLUDED.title,
    nav_label = EXCLUDED.nav_label,
    nav_icon  = EXCLUDED.nav_icon;

INSERT INTO core.feature_registry (code, name, description, module, is_enabled, feature_type, action_type, page_path)
VALUES
    ('EMP_GROUP_CREATE', 'Create Employee Group', 'Create a custom cohort of employees',
        'core', TRUE, 'ACTION', 'CREATE', '/admin/employee-groups'),
    ('EMP_GROUP_MANAGE', 'Manage Group Members', 'Add or remove members from a group',
        'core', TRUE, 'ACTION', 'EDIT', '/admin/employee-groups')
ON CONFLICT (code) DO UPDATE SET
    name       = EXCLUDED.name,
    is_enabled = TRUE;

-- Role grants
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
FROM core.page_registry p
CROSS JOIN (VALUES ('SUPER_ADMIN'),('HR_ADMIN')) AS r(role_code)
WHERE p.path = '/admin/employee-groups'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.role_code, f.id, TRUE
FROM core.feature_registry f
CROSS JOIN (VALUES ('SUPER_ADMIN'),('HR_ADMIN')) AS r(role_code)
WHERE f.code IN ('EMP_GROUP_CREATE','EMP_GROUP_MANAGE')
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = TRUE;

-- Also allow MANAGER to create PRIVATE groups (for their own team cohorts)
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT 'MANAGER', f.id, TRUE
FROM core.feature_registry f
WHERE f.code = 'EMP_GROUP_CREATE'
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = TRUE;
