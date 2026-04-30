-- ══════════════════════════════════════════════════════════════════════
-- 63 · Retirement Rule Profiles (multi-profile config)
-- ══════════════════════════════════════════════════════════════════════
-- Today core.retirement_rules holds a SINGLE row per company. That works
-- for simple orgs but doesn't fit LGUs that have different rules for
-- different employment types (regular vs casual, uniformed vs civilian).
--
-- This migration adds a companion profile table. The legacy single-row
-- table still works (used as fallback); when profiles exist, the system
-- picks the default one (or the one matching the employee's scope).
-- ══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS core.retirement_rule_profiles (
    id                          BIGSERIAL PRIMARY KEY,
    company_id                  BIGINT NOT NULL REFERENCES core.companies(id) ON DELETE CASCADE,
    name                        VARCHAR(100) NOT NULL,
    description                 TEXT,
    employment_type_id          BIGINT REFERENCES core.employment_types(id),
    department_id               BIGINT REFERENCES core.departments(id),
    early_retire_age            INTEGER NOT NULL DEFAULT 60,
    mandatory_retire_age        INTEGER NOT NULL DEFAULT 65,
    notice_lead_months          INTEGER NOT NULL DEFAULT 6,
    early_retire_benefit_years  INTEGER NOT NULL DEFAULT 15,
    is_default                  BOOLEAN NOT NULL DEFAULT FALSE,
    is_active                   BOOLEAN NOT NULL DEFAULT TRUE,
    created_by                  BIGINT REFERENCES core.users(id),
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, name)
);
CREATE INDEX IF NOT EXISTS idx_retire_profiles_company ON core.retirement_rule_profiles(company_id);
CREATE INDEX IF NOT EXISTS idx_retire_profiles_default ON core.retirement_rule_profiles(company_id, is_default);

-- Seed a Default profile from the legacy single-row config (one-time).
INSERT INTO core.retirement_rule_profiles
    (company_id, name, description,
     early_retire_age, mandatory_retire_age, notice_lead_months,
     early_retire_benefit_years, is_default, is_active, updated_at)
SELECT rr.company_id,
       'Default',
       'Baseline company-wide retirement rules (auto-migrated from legacy table)',
       rr.early_retire_age, rr.mandatory_retire_age, rr.notice_lead_months,
       COALESCE(rr.early_retire_benefit_years, 15),
       TRUE, TRUE, NOW()
  FROM core.retirement_rules rr
 WHERE NOT EXISTS (
        SELECT 1 FROM core.retirement_rule_profiles p
         WHERE p.company_id = rr.company_id AND p.name = 'Default'
 );

-- Feature + page access
INSERT INTO core.feature_registry (code, name, description, module, is_enabled, feature_type, action_type, page_path)
VALUES
    ('RET_RULE_CREATE', 'Create Retirement Rule', 'Create a new retirement rule profile',
        'core', TRUE, 'ACTION', 'CREATE', '/admin/retirement-rules'),
    ('RET_RULE_EDIT',   'Edit Retirement Rule', 'Modify an existing retirement rule profile',
        'core', TRUE, 'ACTION', 'EDIT',   '/admin/retirement-rules'),
    ('RET_RULE_DELETE', 'Delete Retirement Rule', 'Remove (deactivate) a retirement rule profile',
        'core', TRUE, 'ACTION', 'DELETE', '/admin/retirement-rules')
ON CONFLICT (code) DO UPDATE SET
    name=EXCLUDED.name, description=EXCLUDED.description, is_enabled=TRUE;

-- Grant to SUPER_ADMIN + HR_ADMIN
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.role_code, f.id, TRUE
FROM core.feature_registry f
CROSS JOIN (VALUES ('SUPER_ADMIN'),('HR_ADMIN')) AS r(role_code)
WHERE f.code IN ('RET_RULE_CREATE','RET_RULE_EDIT','RET_RULE_DELETE')
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = TRUE;
