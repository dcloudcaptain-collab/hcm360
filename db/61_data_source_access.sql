-- ================================================================
-- HCM360 — 61: Data Source Access Grants
--
-- Adds role/user-level grants on Report Builder data sources so HR
-- admins can choose which sources a role or individual user can see
-- on the /reports/builder page. Grants also flow through to ARIA
-- (aria_extensions reads the same tables).
--
-- Surfaces in /admin/access-matrix under a new synthetic module
-- "data_sources" so the existing toggle UI works without changes.
-- ================================================================

-- Role-level access (inherits via role)
CREATE TABLE IF NOT EXISTS analytics.report_source_role_access (
    id         BIGSERIAL    PRIMARY KEY,
    role_code  VARCHAR(50)  NOT NULL,
    source_id  BIGINT       NOT NULL REFERENCES analytics.report_data_sources(id) ON DELETE CASCADE,
    can_access BOOLEAN      NOT NULL DEFAULT TRUE,
    granted_by BIGINT       REFERENCES core.users(id),
    granted_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (role_code, source_id)
);
CREATE INDEX IF NOT EXISTS idx_ds_role_access_role ON analytics.report_source_role_access (role_code);

-- User-level override
CREATE TABLE IF NOT EXISTS analytics.report_source_user_access (
    id         BIGSERIAL    PRIMARY KEY,
    user_id    BIGINT       NOT NULL REFERENCES core.users(id) ON DELETE CASCADE,
    source_id  BIGINT       NOT NULL REFERENCES analytics.report_data_sources(id) ON DELETE CASCADE,
    can_access BOOLEAN      NOT NULL DEFAULT TRUE,
    granted_by BIGINT       REFERENCES core.users(id),
    granted_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, source_id)
);
CREATE INDEX IF NOT EXISTS idx_ds_user_access_user ON analytics.report_source_user_access (user_id);


-- Seed default grants: SUPER_ADMIN + HR_ADMIN + EXECUTIVE see everything
INSERT INTO analytics.report_source_role_access (role_code, source_id, can_access)
SELECT r.role_code, s.id, TRUE
FROM (VALUES ('SUPER_ADMIN'), ('HR_ADMIN'), ('EXECUTIVE')) AS r(role_code)
CROSS JOIN analytics.report_data_sources s
WHERE s.is_active = TRUE
ON CONFLICT (role_code, source_id) DO UPDATE SET can_access = TRUE;

-- MANAGER sees a sensible subset — not payroll/comp, not full PDS
INSERT INTO analytics.report_source_role_access (role_code, source_id, can_access)
SELECT 'MANAGER', s.id, TRUE
FROM analytics.report_data_sources s
WHERE s.is_active = TRUE
  AND s.source_code IN ('EMPLOYEES','ATTENDANCE','LEAVE','GOALS','SKILLS','REQUISITIONS','TRAINING')
ON CONFLICT (role_code, source_id) DO UPDATE SET can_access = TRUE;

-- EMPLOYEE: no grants by default (matrix switches default off)
