-- ================================================================
-- HCM360 — 53: STEP INCREMENT + RETIREMENT MONITORING
--
-- Adds two LGU-critical workflows:
--   * core.step_increment_history    — 3-yearly salary step increments
--   * core.retirement_tracking       — age 60 early / 65 mandatory
--   * core.retirement_rules          — per-company configuration
--
-- Also adds:
--   * date_of_original_appointment column on core.employees (nullable;
--     falls back to date_hired when not set)
--
-- Registers pages + features + role access for Access Matrix.
-- ================================================================
SET search_path TO core, public;

-- ── Schema adjustments ─────────────────────────────────────────────
ALTER TABLE core.employees
    ADD COLUMN IF NOT EXISTS date_of_original_appointment DATE;

-- Backfill: use date_hired when the new column is NULL
UPDATE core.employees
SET date_of_original_appointment = date_hired
WHERE date_of_original_appointment IS NULL;


-- ── Step Increment History ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS core.step_increment_history (
    id                BIGSERIAL   PRIMARY KEY,
    employee_id       BIGINT      NOT NULL REFERENCES core.employees(id) ON DELETE CASCADE,
    increment_no      INT         NOT NULL,               -- 1st increment, 2nd, etc.
    due_date          DATE        NOT NULL,               -- when it falls due
    effective_date    DATE,                               -- when it actually takes effect
    from_salary_grade VARCHAR(10),
    to_salary_grade   VARCHAR(10),
    from_step         INT,
    to_step           INT,
    status            VARCHAR(20) NOT NULL DEFAULT 'DUE'
                       CHECK (status IN ('DUE', 'NOTICE_SENT', 'APPROVED', 'RECORDED', 'DECLINED')),
    notice_sent_at    TIMESTAMPTZ,
    notice_sent_by    BIGINT      REFERENCES core.users(id),
    notice_path       TEXT,
    acknowledged_at   TIMESTAMPTZ,
    approved_at       TIMESTAMPTZ,
    approved_by       BIGINT      REFERENCES core.users(id),
    notes             TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (employee_id, increment_no)
);
CREATE INDEX IF NOT EXISTS idx_si_history_due   ON core.step_increment_history (due_date);
CREATE INDEX IF NOT EXISTS idx_si_history_emp   ON core.step_increment_history (employee_id);
CREATE INDEX IF NOT EXISTS idx_si_history_status ON core.step_increment_history (status);


-- ── Retirement Tracking ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS core.retirement_rules (
    company_id           BIGINT   PRIMARY KEY REFERENCES core.companies(id) ON DELETE CASCADE,
    early_retire_age     INT      NOT NULL DEFAULT 60,
    mandatory_retire_age INT      NOT NULL DEFAULT 65,
    notice_lead_months   INT      NOT NULL DEFAULT 6,   -- generate notice N months before
    early_retire_benefit_years INT DEFAULT 15,          -- min years of service for early
    updated_by           BIGINT   REFERENCES core.users(id),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed for demo company
INSERT INTO core.retirement_rules (company_id)
SELECT id FROM core.companies WHERE code = 'DEMO'
ON CONFLICT (company_id) DO NOTHING;


CREATE TABLE IF NOT EXISTS core.retirement_tracking (
    id                BIGSERIAL   PRIMARY KEY,
    employee_id       BIGINT      NOT NULL REFERENCES core.employees(id) ON DELETE CASCADE,
    eligibility_type  VARCHAR(20) NOT NULL
                       CHECK (eligibility_type IN ('EARLY', 'MANDATORY')),
    eligible_date     DATE        NOT NULL,                -- date they become eligible
    retirement_date   DATE,                                -- actual date
    status            VARCHAR(20) NOT NULL DEFAULT 'UPCOMING'
                       CHECK (status IN ('UPCOMING','NOTICE_SENT','ACKNOWLEDGED',
                                         'SCHEDULED','RETIRED','CANCELLED')),
    notice_sent_at        TIMESTAMPTZ,
    notice_sent_by        BIGINT REFERENCES core.users(id),
    notice_hr_path        TEXT,
    notice_employee_path  TEXT,
    notice_finance_path   TEXT,
    acknowledged_at       TIMESTAMPTZ,
    notes                 TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (employee_id, eligibility_type)
);
CREATE INDEX IF NOT EXISTS idx_ret_tracking_date   ON core.retirement_tracking (eligible_date);
CREATE INDEX IF NOT EXISTS idx_ret_tracking_emp    ON core.retirement_tracking (employee_id);
CREATE INDEX IF NOT EXISTS idx_ret_tracking_status ON core.retirement_tracking (status);


-- ── Page Registry Entries ──────────────────────────────────────────
INSERT INTO core.page_registry
    (path, title, module, nav_group, nav_label, nav_icon, nav_order, is_visible)
VALUES
    ('/step-increments/',
        'Step Increment Monitoring',
        'core', 'Workforce', 'Step Increments', 'trending-up', 70, TRUE),
    ('/retirement/',
        'Retirement Monitoring',
        'core', 'Workforce', 'Retirement', 'sunrise', 71, TRUE),
    ('/admin/retirement-rules',
        'Retirement Rules',
        'admin', 'Administration', 'Retirement Rules', 'settings', 97, TRUE)
ON CONFLICT (path) DO NOTHING;


-- ── Feature Registry ───────────────────────────────────────────────
INSERT INTO core.feature_registry
    (code, name, description, module, is_enabled, feature_type, action_type, page_path)
VALUES
    ('SI_SCAN',
        'Scan for Step Increments',
        'Run the 3-year anniversary scan and create DUE rows',
        'core', TRUE, 'ACTION', 'CREATE', '/step-increments/'),
    ('SI_NOTICE_SEND',
        'Send Step Increment Notice',
        'Generate and send step increment notice',
        'core', TRUE, 'ACTION', 'EDIT', '/step-increments/'),
    ('SI_RECORD',
        'Record Step Increment',
        'Mark a step increment as effective / recorded',
        'core', TRUE, 'ACTION', 'EDIT', '/step-increments/'),
    ('RET_SCAN',
        'Scan for Upcoming Retirement',
        'Run the age-based retirement eligibility scan',
        'core', TRUE, 'ACTION', 'CREATE', '/retirement/'),
    ('RET_NOTICE_SEND',
        'Send Retirement Notice',
        'Generate multi-recipient retirement notice (HR, Employee, Finance)',
        'core', TRUE, 'ACTION', 'EDIT', '/retirement/'),
    ('RET_RULES_EDIT',
        'Edit Retirement Rules',
        'Adjust early/mandatory retirement ages and lead time',
        'admin', TRUE, 'ACTION', 'EDIT', '/admin/retirement-rules')
ON CONFLICT (code) DO NOTHING;


-- ── Role Page Access ───────────────────────────────────────────────
-- SUPER_ADMIN, HR_ADMIN, EXECUTIVE can view all three pages
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
FROM core.page_registry p
CROSS JOIN (VALUES
    ('SUPER_ADMIN'), ('HR_ADMIN'), ('EXECUTIVE')
) AS r(role_code)
WHERE p.path IN ('/step-increments/', '/retirement/')
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

-- Admin rules page: SUPER_ADMIN + HR_ADMIN only
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
FROM core.page_registry p
CROSS JOIN (VALUES ('SUPER_ADMIN'), ('HR_ADMIN')) AS r(role_code)
WHERE p.path = '/admin/retirement-rules'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

-- Explicit denial for MANAGER + EMPLOYEE
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, FALSE
FROM core.page_registry p
CROSS JOIN (VALUES ('MANAGER'), ('EMPLOYEE')) AS r(role_code)
WHERE p.path IN ('/step-increments/', '/retirement/', '/admin/retirement-rules')
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = FALSE;


-- ── Role Feature Access ────────────────────────────────────────────
-- HR_ADMIN + SUPER_ADMIN can invoke write actions
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.role_code, f.id, TRUE
FROM core.feature_registry f
CROSS JOIN (VALUES ('SUPER_ADMIN'), ('HR_ADMIN')) AS r(role_code)
WHERE f.code IN ('SI_SCAN','SI_NOTICE_SEND','SI_RECORD',
                 'RET_SCAN','RET_NOTICE_SEND','RET_RULES_EDIT')
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = TRUE;
