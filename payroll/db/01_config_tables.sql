-- ================================================================
-- Standalone Payroll Module — Config Tables
-- Schema: payroll (additive to existing hris_db)
-- ================================================================
SET search_path TO payroll, core, public;

-- ── Company-level key-value payroll settings ────────────────────
CREATE TABLE IF NOT EXISTS payroll.pay_config (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES core.companies(id),
    config_key      VARCHAR(60)  NOT NULL,
    config_value    TEXT         NOT NULL,
    description     TEXT,
    updated_by      BIGINT       REFERENCES core.users(id),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, config_key)
);

CREATE INDEX IF NOT EXISTS idx_pay_config_company ON payroll.pay_config(company_id);

-- Seed default config for first company
INSERT INTO payroll.pay_config (company_id, config_key, config_value, description)
SELECT c.id, v.key, v.val, v.descr
FROM core.companies c,
(VALUES
    ('payroll_type',           'GOV',           'Payroll type: GOV (government/SSL/GSIS) or PRIVATE (SSS-based)'),
    ('cutoff_type',            'SEMI_MONTHLY',  'Payroll frequency: SEMI_MONTHLY, MONTHLY, or WEEKLY'),
    ('working_days_per_month', '22',            'Standard working days per month for daily rate computation'),
    ('ot_min_hours',           '0.5',           'Minimum OT hours to qualify for OT pay'),
    ('night_diff_start',       '22:00',         'Night differential start time (24h format)'),
    ('night_diff_end',         '06:00',         'Night differential end time (24h format)'),
    ('late_deduction_rule',    'PER_MINUTE',    'Late deduction rule: PER_MINUTE or PER_15MIN'),
    ('absent_deduction_rule',  'PROPORTIONAL',  'Absent deduction: PROPORTIONAL (daily rate) or FIXED'),
    ('de_minimis_limit',       '90000',         'Non-taxable 13th month / de minimis threshold (PHP)'),
    ('grace_period_minutes',   '15',            'Default grace period for tardiness (minutes)'),
    ('half_month_cutoff_day',  '15',            'Day of month for semi-monthly first cutoff'),
    ('pay_date_offset_days',   '5',             'Days after cutoff end for pay date')
) AS v(key, val, descr)
WHERE c.id = (SELECT id FROM core.companies ORDER BY id LIMIT 1)
ON CONFLICT (company_id, config_key) DO NOTHING;


-- ── OT / Holiday / Night Diff rate multipliers ─────────────────
CREATE TABLE IF NOT EXISTS payroll.pay_rate_tables (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES core.companies(id),
    rate_code       VARCHAR(40)  NOT NULL,
    rate_name       VARCHAR(100) NOT NULL,
    multiplier      NUMERIC(6,4) NOT NULL,
    description     TEXT,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    effective_from  DATE         NOT NULL DEFAULT CURRENT_DATE,
    effective_to    DATE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, rate_code)
);

-- Seed Philippine-standard rate multipliers
INSERT INTO payroll.pay_rate_tables (company_id, rate_code, rate_name, multiplier, description)
SELECT c.id, v.code, v.name, v.mult, v.descr
FROM core.companies c,
(VALUES
    ('OT_REGULAR',           'Regular OT',                    1.2500, 'Ordinary day OT (125% of hourly rate)'),
    ('OT_RESTDAY',           'Rest Day OT',                   1.6900, 'Rest day OT (130% x 130%)'),
    ('OT_REGULAR_HOLIDAY',   'Regular Holiday OT',            2.6000, 'Regular holiday OT (200% x 130%)'),
    ('OT_SPECIAL_HOLIDAY',   'Special Holiday OT',            1.6900, 'Special holiday OT (130% x 130%)'),
    ('OT_DOUBLE_HOLIDAY',    'Double Holiday OT',             3.9000, 'Double holiday OT (300% x 130%)'),
    ('NIGHT_DIFF',           'Night Differential',            0.1000, 'Night diff premium (10% of hourly rate)'),
    ('NIGHT_DIFF_OT',        'Night Diff + OT',               0.1375, 'Night diff during OT (10% x 137.5%)'),
    ('RESTDAY_PREMIUM',      'Rest Day Premium',              1.3000, 'Rest day rate (130% of daily rate)'),
    ('REGULAR_HOLIDAY',      'Regular Holiday',               2.0000, 'Regular holiday rate (200%)'),
    ('SPECIAL_HOLIDAY',      'Special Non-Working Holiday',   1.3000, 'Special holiday rate (130%)'),
    ('DOUBLE_HOLIDAY',       'Double Holiday',                3.0000, 'Double holiday rate (300%)'),
    ('ABSENT_DEDUCTION',     'Absent Deduction',              1.0000, 'Multiplier for absent-day deduction (1x daily rate)')
) AS v(code, name, mult, descr)
WHERE c.id = (SELECT id FROM core.companies ORDER BY id LIMIT 1)
ON CONFLICT (company_id, rate_code) DO NOTHING;


-- ── SSS Contribution Schedule (private sector) ─────────────────
CREATE TABLE IF NOT EXISTS payroll.pay_sss_schedule (
    id                  BIGSERIAL    PRIMARY KEY,
    effective_date      DATE         NOT NULL,
    salary_bracket_from NUMERIC(12,2) NOT NULL,
    salary_bracket_to   NUMERIC(12,2) NOT NULL,
    monthly_salary_credit NUMERIC(12,2) NOT NULL DEFAULT 0,
    ee_contribution     NUMERIC(10,2) NOT NULL,
    er_contribution     NUMERIC(10,2) NOT NULL,
    ec_contribution     NUMERIC(10,2) NOT NULL DEFAULT 10.00,
    is_current          BOOLEAN      NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_sss_current ON payroll.pay_sss_schedule(is_current)
    WHERE is_current = TRUE;

-- Seed 2025 SSS contribution table (simplified key brackets)
INSERT INTO payroll.pay_sss_schedule
    (effective_date, salary_bracket_from, salary_bracket_to, monthly_salary_credit, ee_contribution, er_contribution, ec_contribution, is_current)
VALUES
    ('2025-01-01',     0.00,  4249.99,   4000,   180.00,  380.00, 10.00, TRUE),
    ('2025-01-01',  4250.00,  4749.99,   4500,   202.50,  427.50, 10.00, TRUE),
    ('2025-01-01',  4750.00,  5249.99,   5000,   225.00,  475.00, 10.00, TRUE),
    ('2025-01-01',  5250.00,  5749.99,   5500,   247.50,  522.50, 10.00, TRUE),
    ('2025-01-01',  5750.00,  6249.99,   6000,   270.00,  570.00, 10.00, TRUE),
    ('2025-01-01',  6250.00,  6749.99,   6500,   292.50,  617.50, 10.00, TRUE),
    ('2025-01-01',  6750.00,  7249.99,   7000,   315.00,  665.00, 10.00, TRUE),
    ('2025-01-01',  7250.00,  7749.99,   7500,   337.50,  712.50, 10.00, TRUE),
    ('2025-01-01',  7750.00,  8249.99,   8000,   360.00,  760.00, 10.00, TRUE),
    ('2025-01-01',  8250.00,  8749.99,   8500,   382.50,  807.50, 10.00, TRUE),
    ('2025-01-01',  8750.00,  9249.99,   9000,   405.00,  855.00, 10.00, TRUE),
    ('2025-01-01',  9250.00,  9749.99,   9500,   427.50,  902.50, 10.00, TRUE),
    ('2025-01-01',  9750.00, 10249.99,  10000,   450.00,  950.00, 10.00, TRUE),
    ('2025-01-01', 10250.00, 10749.99,  10500,   472.50,  997.50, 10.00, TRUE),
    ('2025-01-01', 10750.00, 11249.99,  11000,   495.00, 1045.00, 10.00, TRUE),
    ('2025-01-01', 11250.00, 11749.99,  11500,   517.50, 1092.50, 10.00, TRUE),
    ('2025-01-01', 11750.00, 12249.99,  12000,   540.00, 1140.00, 10.00, TRUE),
    ('2025-01-01', 12250.00, 12749.99,  12500,   562.50, 1187.50, 10.00, TRUE),
    ('2025-01-01', 12750.00, 13249.99,  13000,   585.00, 1235.00, 10.00, TRUE),
    ('2025-01-01', 13250.00, 13749.99,  13500,   607.50, 1282.50, 10.00, TRUE),
    ('2025-01-01', 13750.00, 14249.99,  14000,   630.00, 1330.00, 10.00, TRUE),
    ('2025-01-01', 14250.00, 14749.99,  14500,   652.50, 1377.50, 10.00, TRUE),
    ('2025-01-01', 14750.00, 15249.99,  15000,   675.00, 1425.00, 10.00, TRUE),
    ('2025-01-01', 15250.00, 15749.99,  15500,   697.50, 1472.50, 10.00, TRUE),
    ('2025-01-01', 15750.00, 16249.99,  16000,   720.00, 1520.00, 10.00, TRUE),
    ('2025-01-01', 16250.00, 16749.99,  16500,   742.50, 1567.50, 10.00, TRUE),
    ('2025-01-01', 16750.00, 17249.99,  17000,   765.00, 1615.00, 10.00, TRUE),
    ('2025-01-01', 17250.00, 17749.99,  17500,   787.50, 1662.50, 10.00, TRUE),
    ('2025-01-01', 17750.00, 18249.99,  18000,   810.00, 1710.00, 10.00, TRUE),
    ('2025-01-01', 18250.00, 18749.99,  18500,   832.50, 1757.50, 10.00, TRUE),
    ('2025-01-01', 18750.00, 19249.99,  19000,   855.00, 1805.00, 10.00, TRUE),
    ('2025-01-01', 19250.00, 19749.99,  19500,   877.50, 1852.50, 10.00, TRUE),
    ('2025-01-01', 19750.00, 20249.99,  20000,   900.00, 1900.00, 10.00, TRUE),
    ('2025-01-01', 20250.00, 20749.99,  20500,   922.50, 1947.50, 10.00, TRUE),
    ('2025-01-01', 20750.00, 21249.99,  21000,   945.00, 1995.00, 10.00, TRUE),
    ('2025-01-01', 21250.00, 21749.99,  21500,   967.50, 2042.50, 10.00, TRUE),
    ('2025-01-01', 21750.00, 22249.99,  22000,   990.00, 2090.00, 10.00, TRUE),
    ('2025-01-01', 22250.00, 22749.99,  22500,  1012.50, 2137.50, 10.00, TRUE),
    ('2025-01-01', 22750.00, 23249.99,  23000,  1035.00, 2185.00, 10.00, TRUE),
    ('2025-01-01', 23250.00, 23749.99,  23500,  1057.50, 2232.50, 10.00, TRUE),
    ('2025-01-01', 23750.00, 24249.99,  24000,  1080.00, 2280.00, 10.00, TRUE),
    ('2025-01-01', 24250.00, 24749.99,  24500,  1102.50, 2327.50, 10.00, TRUE),
    ('2025-01-01', 24750.00, 29999.99,  25000,  1125.00, 2375.00, 10.00, TRUE),
    ('2025-01-01', 30000.00, 99999.99,  30000,  1350.00, 2850.00, 10.00, TRUE)
ON CONFLICT DO NOTHING;


-- ── PhilHealth Contribution Schedule ────────────────────────────
CREATE TABLE IF NOT EXISTS payroll.pay_philhealth_schedule (
    id                  BIGSERIAL    PRIMARY KEY,
    effective_date      DATE         NOT NULL,
    salary_bracket_from NUMERIC(12,2) NOT NULL,
    salary_bracket_to   NUMERIC(12,2) NOT NULL,
    premium_rate        NUMERIC(6,4) NOT NULL DEFAULT 0.0500,
    ee_share            NUMERIC(6,4) NOT NULL DEFAULT 0.5000,
    er_share            NUMERIC(6,4) NOT NULL DEFAULT 0.5000,
    min_premium         NUMERIC(10,2) NOT NULL DEFAULT 500.00,
    max_premium         NUMERIC(10,2) NOT NULL DEFAULT 5000.00,
    is_current          BOOLEAN      NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_philhealth_current ON payroll.pay_philhealth_schedule(is_current)
    WHERE is_current = TRUE;

-- 2025 PhilHealth: 5% premium rate, shared equally
INSERT INTO payroll.pay_philhealth_schedule
    (effective_date, salary_bracket_from, salary_bracket_to, premium_rate, ee_share, er_share, min_premium, max_premium, is_current)
VALUES
    ('2025-01-01',      0.00,  10000.00, 0.0500, 0.5000, 0.5000,  500.00, 5000.00, TRUE),
    ('2025-01-01',  10000.01, 100000.00, 0.0500, 0.5000, 0.5000,  500.00, 5000.00, TRUE)
ON CONFLICT DO NOTHING;
