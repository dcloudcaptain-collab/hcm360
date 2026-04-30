-- ============================================================
-- Migration 50: Field-Level Privacy Rules (RA 10173 Compliance)
-- Controls which roles can see sensitive employee data fields
-- ============================================================

-- A. Privacy rules table
CREATE TABLE IF NOT EXISTS core.field_privacy_rules (
    id          BIGSERIAL PRIMARY KEY,
    section     VARCHAR(60)  NOT NULL,
    field_name  VARCHAR(100) NOT NULL,
    role_code   VARCHAR(50)  NOT NULL,
    visibility  VARCHAR(10)  NOT NULL DEFAULT 'VISIBLE'
                CHECK (visibility IN ('VISIBLE','MASKED','HIDDEN')),
    mask_char   VARCHAR(20)  DEFAULT '***',
    updated_by  BIGINT REFERENCES core.users(id) ON DELETE SET NULL,
    updated_at  TIMESTAMPTZ  DEFAULT NOW(),
    UNIQUE (section, field_name, role_code)
);

COMMENT ON TABLE core.field_privacy_rules IS
  'Field-level visibility controls per role. Absent = VISIBLE (default). '
  'MASKED = value shown as mask_char. HIDDEN = field excluded entirely.';

-- B. Default seed rules — restrict sensitive fields for lower-privilege roles
-- EMPLOYEE role: can see own data (is_own_record=True in code), but salary hidden
-- MANAGER role: can see staff PII but bank account numbers masked
INSERT INTO core.field_privacy_rules (section, field_name, role_code, visibility, mask_char) VALUES
  -- Employee core fields
  ('employee', 'date_of_birth',   'EMPLOYEE', 'MASKED',  '****-**-**'),
  ('employee', 'basic_salary',    'EMPLOYEE', 'HIDDEN',  '***'),
  ('employee', 'daily_rate',      'EMPLOYEE', 'HIDDEN',  '***'),
  ('employee', 'hourly_rate',     'EMPLOYEE', 'HIDDEN',  '***'),
  ('employee', 'salary_grade',    'EMPLOYEE', 'HIDDEN',  '***'),
  ('employee', 'basic_salary',    'MANAGER',  'HIDDEN',  '***'),
  ('employee', 'daily_rate',      'MANAGER',  'HIDDEN',  '***'),
  ('employee', 'hourly_rate',     'MANAGER',  'HIDDEN',  '***'),
  ('employee', 'date_of_birth',   'MANAGER',  'MASKED',  '****-**-**'),
  -- Government IDs
  ('government_id', 'id_number',  'EMPLOYEE', 'MASKED',  '***-****-***'),
  ('government_id', 'id_number',  'MANAGER',  'MASKED',  '***-****-***'),
  -- Bank accounts
  ('bank_account', 'account_number', 'EMPLOYEE', 'MASKED', '****-****-****'),
  ('bank_account', 'account_number', 'MANAGER',  'MASKED', '****-****-****'),
  -- Dependent birth dates
  ('dependent', 'date_of_birth',  'EMPLOYEE', 'MASKED',  '****-**-**'),
  ('dependent', 'date_of_birth',  'MANAGER',  'MASKED',  '****-**-**')
ON CONFLICT (section, field_name, role_code) DO NOTHING;

-- C. Register the privacy admin page
INSERT INTO core.page_registry (path, title, module, nav_group, nav_label, nav_icon, nav_order, is_visible)
VALUES ('/admin/privacy', 'Field Privacy Rules', 'admin', 'Administration', 'Data Privacy', 'shield', 95, TRUE)
ON CONFLICT (path) DO NOTHING;

-- Grant SUPER_ADMIN access to the privacy page
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT 'SUPER_ADMIN', id, TRUE
FROM   core.page_registry
WHERE  path = '/admin/privacy'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

-- D. Feature registry entry for the privacy edit action
INSERT INTO core.feature_registry (code, name, description, module, is_enabled, feature_type, action_type, page_path)
VALUES (
  'EMP_PRIVACY_ADMIN',
  'Manage Field Privacy Rules',
  'Configure field-level visibility per role for RA 10173 compliance',
  'admin', TRUE, 'ACTION', 'EDIT', '/admin/privacy'
)
ON CONFLICT (code) DO NOTHING;

-- Grant that feature to SUPER_ADMIN
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT 'SUPER_ADMIN', id, TRUE
FROM   core.feature_registry
WHERE  code = 'EMP_PRIVACY_ADMIN'
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = TRUE;
