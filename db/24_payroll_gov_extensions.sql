-- ================================================================
-- HCM360 HRIS — 24: PAYROLL GOVERNMENT-SPECIFIC EXTENSIONS
-- Schema    : payroll
-- Standards : GSIS (RA 8291), Pag-IBIG (RA 9679), BIR (TRAIN Law),
--             EO 201 / SSL, RA 6758 (Compensation & Position Classification)
-- ================================================================
SET search_path TO payroll, rewards, core, public;

-- ----------------------------------------------------------------
-- Extend pay_employee_payroll with government-specific columns
-- ----------------------------------------------------------------
ALTER TABLE payroll.pay_employee_payroll
    ADD COLUMN IF NOT EXISTS pera             NUMERIC(10,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS rata             NUMERIC(10,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS aca              NUMERIC(10,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS hazard_pay       NUMERIC(10,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS gsis_ps          NUMERIC(10,2) NOT NULL DEFAULT 0,  -- personal share
    ADD COLUMN IF NOT EXISTS gsis_gs          NUMERIC(10,2) NOT NULL DEFAULT 0,  -- government share
    ADD COLUMN IF NOT EXISTS gsis_policy_loan NUMERIC(10,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS pagibig_ps       NUMERIC(10,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS pagibig_gs       NUMERIC(10,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS coop_deduction   NUMERIC(10,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS yeb_amount       NUMERIC(12,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS cash_gift        NUMERIC(12,2) NOT NULL DEFAULT 0;

-- ----------------------------------------------------------------
-- GSIS CONTRIBUTION SCHEDULE
-- ----------------------------------------------------------------
CREATE TABLE payroll.pay_gsis_schedule (
    id                      BIGSERIAL    PRIMARY KEY,
    effective_date          DATE         NOT NULL,
    salary_bracket_from     NUMERIC(12,2) NOT NULL,
    salary_bracket_to       NUMERIC(12,2) NOT NULL,
    ee_personal_share_pct   NUMERIC(5,4) NOT NULL,
    er_government_share_pct NUMERIC(5,4) NOT NULL,
    life_insurance_pct      NUMERIC(5,4) NOT NULL DEFAULT 0,
    is_current              BOOLEAN      NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_gsis_current ON payroll.pay_gsis_schedule(is_current)
    WHERE is_current = TRUE;

-- ----------------------------------------------------------------
-- PAG-IBIG (HDMF) GOVERNMENT SCHEDULE
-- ----------------------------------------------------------------
CREATE TABLE payroll.pay_pagibig_schedule (
    id                      BIGSERIAL    PRIMARY KEY,
    effective_date          DATE         NOT NULL,
    salary_bracket_from     NUMERIC(12,2) NOT NULL,
    salary_bracket_to       NUMERIC(12,2) NOT NULL,
    ee_contribution_pct     NUMERIC(5,4) NOT NULL,
    er_contribution_pct     NUMERIC(5,4) NOT NULL,
    is_current              BOOLEAN      NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_pagibig_current ON payroll.pay_pagibig_schedule(is_current)
    WHERE is_current = TRUE;

-- ----------------------------------------------------------------
-- RATA PER POSITION LEVEL
-- ----------------------------------------------------------------
CREATE TABLE payroll.pay_rata_schedule (
    id                          BIGSERIAL    PRIMARY KEY,
    position_id                 BIGINT       REFERENCES core.positions(id),
    salary_grade                INTEGER      NOT NULL,
    representation_allowance    NUMERIC(12,2) NOT NULL DEFAULT 0,
    transportation_allowance    NUMERIC(12,2) NOT NULL DEFAULT 0,
    effective_date              DATE         NOT NULL DEFAULT CURRENT_DATE,
    is_current                  BOOLEAN      NOT NULL DEFAULT FALSE
);

-- ----------------------------------------------------------------
-- GOVERNMENT ALLOWANCE TYPES MASTER
-- ----------------------------------------------------------------
CREATE TABLE payroll.pay_gov_allowances (
    id                  BIGSERIAL    PRIMARY KEY,
    company_id          BIGINT       NOT NULL REFERENCES core.companies(id),
    allowance_code      VARCHAR(20)  NOT NULL UNIQUE,
    allowance_name      VARCHAR(100) NOT NULL,
    default_amount      NUMERIC(12,2) NOT NULL DEFAULT 0,
    is_taxable          BOOLEAN      NOT NULL DEFAULT FALSE,
    applicable_to       JSONB        NOT NULL DEFAULT '{}',
    effective_date      DATE         NOT NULL DEFAULT CURRENT_DATE,
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------
-- EMPLOYEE GOVERNMENT ALLOWANCE ASSIGNMENTS
-- ----------------------------------------------------------------
CREATE TABLE payroll.pay_employee_allowances_gov (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id),
    allowance_id        BIGINT       NOT NULL REFERENCES payroll.pay_gov_allowances(id),
    monthly_amount      NUMERIC(12,2) NOT NULL,
    effective_from      DATE         NOT NULL,
    effective_to        DATE,
    approved_by         BIGINT       REFERENCES core.users(id),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_emp_gov_allow ON payroll.pay_employee_allowances_gov(employee_id);

-- ----------------------------------------------------------------
-- ANNUAL BONUSES & INCENTIVES (YEB, Cash Gift, PBB)
-- ----------------------------------------------------------------
CREATE TABLE payroll.pay_annual_bonuses (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id),
    bonus_type          VARCHAR(30)  NOT NULL
                            CHECK (bonus_type IN ('YEB', 'CASH_GIFT', 'PBB', 'PRODUCTIVITY_INCENTIVE')),
    year                INTEGER      NOT NULL,
    reference_period    VARCHAR(60),
    gross_amount        NUMERIC(12,2) NOT NULL DEFAULT 0,
    tax_withheld        NUMERIC(12,2) NOT NULL DEFAULT 0,
    net_amount          NUMERIC(12,2) NOT NULL DEFAULT 0,
    pay_run_id          BIGINT       REFERENCES payroll.pay_runs(id),
    pbb_record_id       BIGINT,
    released_at         TIMESTAMPTZ,
    released_by         BIGINT       REFERENCES core.users(id),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (employee_id, bonus_type, year)
);

-- ----------------------------------------------------------------
-- COOPERATIVE MEMBERSHIP & LOANS
-- ----------------------------------------------------------------
CREATE TABLE payroll.pay_coop_members (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id),
    cooperative_name    VARCHAR(200) NOT NULL,
    membership_no       VARCHAR(60),
    monthly_savings     NUMERIC(12,2) NOT NULL DEFAULT 0,
    effective_from      DATE         NOT NULL,
    effective_to        DATE,
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_coop_employee ON payroll.pay_coop_members(employee_id);

-- ----------------------------------------------------------------
-- BIR WITHHOLDING TAX TABLE (Revenue Regulations)
-- ----------------------------------------------------------------
CREATE TABLE payroll.pay_bir_tax_table (
    id                  BIGSERIAL    PRIMARY KEY,
    effective_date      DATE         NOT NULL,
    frequency           VARCHAR(15)  NOT NULL DEFAULT 'MONTHLY'
                            CHECK (frequency IN ('MONTHLY', 'SEMI_MONTHLY', 'WEEKLY')),
    bracket_from        NUMERIC(12,2) NOT NULL,
    bracket_to          NUMERIC(12,2) NOT NULL,
    base_tax            NUMERIC(12,2) NOT NULL DEFAULT 0,
    excess_pct          NUMERIC(5,4) NOT NULL DEFAULT 0,
    is_current          BOOLEAN      NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_bir_current ON payroll.pay_bir_tax_table(is_current, frequency)
    WHERE is_current = TRUE;

-- ================================================================
-- SEED: Government Allowance Types
-- ================================================================
INSERT INTO payroll.pay_gov_allowances (company_id, allowance_code, allowance_name, default_amount, is_taxable)
SELECT c.id, v.code, v.name, v.amount, v.taxable
FROM core.companies c,
(VALUES
    ('PERA',       'Personnel Economic Relief Allowance',  2000.00, FALSE),
    ('ACA',        'Additional Compensation Allowance',    0.00,    FALSE),
    ('HAZARD',     'Hazard Pay',                           0.00,    FALSE),
    ('RICE_SUB',   'Rice Subsidy',                         0.00,    FALSE),
    ('LAUNDRY',    'Laundry Allowance',                    0.00,    FALSE),
    ('CLOTHING',   'Clothing/Uniform Allowance',           6000.00, FALSE),
    ('MID_YEAR',   'Mid-Year Bonus',                       0.00,    FALSE)
) AS v(code, name, amount, taxable)
WHERE c.id = (SELECT id FROM core.companies LIMIT 1)
ON CONFLICT (allowance_code) DO NOTHING;
