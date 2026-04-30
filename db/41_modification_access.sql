-- ================================================================
-- HCM360 — 41: TRANSACTIONAL MODIFICATION ACCESS
-- Configurable per-role / per-user edit rights on transactional data
-- + audit tables for attendance overrides and payroll adjustments
-- ================================================================
SET search_path TO core, public;

-- ────────────────────────────────────────────────────────────────
-- 1. Modification Permissions
--    Grants roles or individual users the right to edit/override
--    records in a specific module.
-- ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS core.mod_permissions (
    id              BIGSERIAL    PRIMARY KEY,
    module_code     VARCHAR(30)  NOT NULL,           -- e.g. ATTENDANCE, PAYROLL, LEAVE
    grantee_type    VARCHAR(10)  NOT NULL CHECK (grantee_type IN ('ROLE','USER')),
    grantee_role    VARCHAR(30),                     -- used when grantee_type = 'ROLE'
    grantee_user_id BIGINT       REFERENCES core.users(id) ON DELETE CASCADE,
    can_modify      BOOLEAN      NOT NULL DEFAULT TRUE,
    granted_by      BIGINT       REFERENCES core.users(id),
    granted_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT mp_role_unique  UNIQUE (module_code, grantee_type, grantee_role),
    CONSTRAINT mp_user_unique  UNIQUE (module_code, grantee_type, grantee_user_id),
    CONSTRAINT mp_grantee_check CHECK (
        (grantee_type = 'ROLE' AND grantee_role IS NOT NULL AND grantee_user_id IS NULL)
        OR
        (grantee_type = 'USER' AND grantee_user_id IS NOT NULL AND grantee_role IS NULL)
    )
);

COMMENT ON TABLE core.mod_permissions IS
    'Configures which roles/users may modify (override/adjust) transactional records per module.';

-- ────────────────────────────────────────────────────────────────
-- 2. Attendance Admin Overrides
--    Direct admin edits of att_daily rows, with full audit trail.
-- ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS attendance.att_admin_overrides (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    work_date       DATE         NOT NULL,
    -- snapshot of original values before override
    orig_time_in    TIMESTAMP,
    orig_time_out   TIMESTAMP,
    orig_hours      NUMERIC(5,2),
    orig_status     VARCHAR(20),
    -- new corrected values
    new_time_in     TIMESTAMP,
    new_time_out    TIMESTAMP,
    new_hours       NUMERIC(5,2),
    new_status      VARCHAR(20),
    reason          TEXT         NOT NULL,
    overridden_by   BIGINT       NOT NULL REFERENCES core.users(id),
    overridden_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE attendance.att_admin_overrides IS
    'Immutable audit log of every admin direct-edit on att_daily.';

-- ────────────────────────────────────────────────────────────────
-- 3. Payroll Adjustments
--    Earning/deduction adjustments applied on top of a pay run.
--    Does not alter the original pay_employee_payroll row.
-- ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payroll.pay_adjustments (
    id              BIGSERIAL    PRIMARY KEY,
    run_id          BIGINT       NOT NULL REFERENCES payroll.pay_runs(id),
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    adjustment_type VARCHAR(30)  NOT NULL CHECK (adjustment_type IN
                        ('EARNINGS','DEDUCTION','ALLOWANCE','CORRECTION')),
    description     VARCHAR(200) NOT NULL,
    amount          NUMERIC(14,2) NOT NULL,          -- positive = add, negative = subtract
    applied_by      BIGINT       NOT NULL REFERENCES core.users(id),
    applied_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    remarks         TEXT
);

COMMENT ON TABLE payroll.pay_adjustments IS
    'Non-destructive payroll adjustments (earnings/deductions) appended to a run.';

-- ────────────────────────────────────────────────────────────────
-- 4. Leave Balance Manual Adjustments
-- ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS leave_mgmt.lv_balance_adjustments (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    leave_type_id   BIGINT       NOT NULL REFERENCES leave_mgmt.lv_types(id),
    year            SMALLINT     NOT NULL,
    adjustment_days NUMERIC(5,2) NOT NULL,           -- positive = credit, negative = debit
    reason          VARCHAR(300) NOT NULL,
    adjusted_by     BIGINT       NOT NULL REFERENCES core.users(id),
    adjusted_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE leave_mgmt.lv_balance_adjustments IS
    'Manual credit/debit adjustments to leave balances with full audit trail.';

-- ────────────────────────────────────────────────────────────────
-- 5. Seed default permissions
--    SUPER_ADMIN and HR_ADMIN can modify all modules by default.
-- ────────────────────────────────────────────────────────────────
INSERT INTO core.mod_permissions (module_code, grantee_type, grantee_role)
VALUES
    ('ATTENDANCE', 'ROLE', 'SUPER_ADMIN'),
    ('ATTENDANCE', 'ROLE', 'HR_ADMIN'),
    ('PAYROLL',    'ROLE', 'SUPER_ADMIN'),
    ('PAYROLL',    'ROLE', 'HR_ADMIN'),
    ('LEAVE',      'ROLE', 'SUPER_ADMIN'),
    ('LEAVE',      'ROLE', 'HR_ADMIN'),
    ('RECRUITMENT','ROLE', 'SUPER_ADMIN'),
    ('RECRUITMENT','ROLE', 'HR_ADMIN'),
    ('PERFORMANCE','ROLE', 'SUPER_ADMIN'),
    ('PERFORMANCE','ROLE', 'HR_ADMIN'),
    ('LEARNING',   'ROLE', 'SUPER_ADMIN'),
    ('LEARNING',   'ROLE', 'HR_ADMIN'),
    ('DISCIPLINE', 'ROLE', 'SUPER_ADMIN'),
    ('HEALTH',     'ROLE', 'SUPER_ADMIN'),
    ('DMS',        'ROLE', 'SUPER_ADMIN'),
    ('DMS',        'ROLE', 'HR_ADMIN')
ON CONFLICT DO NOTHING;
