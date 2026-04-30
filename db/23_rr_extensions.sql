-- ================================================================
-- HCM360 HRIS — 23: REWARDS & RECOGNITION PHASE 2 EXTENSIONS
-- Schema    : rewards
-- Standards : EO 201 / SSL (Salary Standardization Law),
--             CSC MC 12-2020 (PRAISE Program),
--             Step Increment (3-year cycle)
-- ================================================================
SET search_path TO rewards, performance, core, workflow, public;

-- ----------------------------------------------------------------
-- Extend rwd_nominations with PRAISE fields
-- ----------------------------------------------------------------
ALTER TABLE rewards.rwd_nominations
    ADD COLUMN IF NOT EXISTS praise_category_id BIGINT,
    ADD COLUMN IF NOT EXISTS period_year        INTEGER,
    ADD COLUMN IF NOT EXISTS period_quarter     INTEGER;

-- ----------------------------------------------------------------
-- Extend rwd_retirement_plans with alert tracking
-- ----------------------------------------------------------------
ALTER TABLE rewards.rwd_retirement_plans
    ADD COLUMN IF NOT EXISTS alert_sent_60d  BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS alert_sent_30d  BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS alert_sent_age60 BOOLEAN NOT NULL DEFAULT FALSE;

-- ----------------------------------------------------------------
-- SSL SALARY GRADE x STEP TABLE (DBM-authorized rates)
-- Referenced by both rewards (step increments) and payroll
-- ----------------------------------------------------------------
CREATE TABLE rewards.rwd_ssl_table (
    id              BIGSERIAL    PRIMARY KEY,
    salary_grade    INTEGER      NOT NULL CHECK (salary_grade BETWEEN 1 AND 33),
    step_no         INTEGER      NOT NULL CHECK (step_no BETWEEN 1 AND 8),
    monthly_rate    NUMERIC(12,2) NOT NULL,
    effective_date  DATE         NOT NULL DEFAULT '2024-01-01',
    ssl_version     VARCHAR(30)  NOT NULL DEFAULT 'SSL V',
    UNIQUE (salary_grade, step_no, effective_date)
);

CREATE INDEX idx_ssl_sg_step ON rewards.rwd_ssl_table(salary_grade, step_no);

-- ----------------------------------------------------------------
-- STEP INCREMENT SCHEDULE (every 3 years of satisfactory service)
-- ----------------------------------------------------------------
CREATE TABLE rewards.rwd_step_increments (
    id                      BIGSERIAL    PRIMARY KEY,
    employee_id             BIGINT       NOT NULL REFERENCES core.employees(id),
    current_sg              INTEGER      NOT NULL,
    current_step            INTEGER      NOT NULL,
    next_step               INTEGER      NOT NULL,
    last_increment_date     DATE         NOT NULL,
    next_increment_due      DATE         GENERATED ALWAYS AS (last_increment_date + INTERVAL '3 years') STORED,
    eligibility_status      VARCHAR(20)  NOT NULL DEFAULT 'PENDING_RATING'
                                CHECK (eligibility_status IN ('ELIGIBLE', 'PENDING_RATING', 'PROCESSED', 'SKIPPED')),
    ipcr_summary_id         BIGINT       REFERENCES performance.perf_ipcr_summary(id),
    processed_at            TIMESTAMPTZ,
    processed_by            BIGINT       REFERENCES core.users(id),
    payroll_effective_date   DATE,
    remarks                 TEXT,
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_step_inc_employee ON rewards.rwd_step_increments(employee_id);
CREATE INDEX idx_step_inc_due      ON rewards.rwd_step_increments(next_increment_due)
    WHERE eligibility_status IN ('ELIGIBLE', 'PENDING_RATING');

-- ----------------------------------------------------------------
-- LOYALTY AWARD MILESTONES (10, 15, 20, 25, 30 years)
-- ----------------------------------------------------------------
CREATE TABLE rewards.rwd_loyalty_milestones (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id),
    service_years       INTEGER      NOT NULL,
    award_type          VARCHAR(20)  NOT NULL DEFAULT 'COMBINATION'
                            CHECK (award_type IN ('PLAQUE', 'CASH_GIFT', 'LEAVE_CREDITS', 'COMBINATION')),
    award_value         NUMERIC(12,2),
    eligibility_date    DATE         NOT NULL,
    status              VARCHAR(20)  NOT NULL DEFAULT 'UPCOMING'
                            CHECK (status IN ('UPCOMING', 'ELIGIBLE', 'AWARDED', 'WAIVED')),
    awarded_at          TIMESTAMPTZ,
    awarded_by          BIGINT       REFERENCES core.users(id),
    certificate_path    VARCHAR(500),
    notified_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (employee_id, service_years)
);

CREATE INDEX idx_loyalty_status ON rewards.rwd_loyalty_milestones(status, eligibility_date);

-- ----------------------------------------------------------------
-- PRAISE PROGRAM CONFIGURATION (CSC MC 12-2020)
-- ----------------------------------------------------------------
CREATE TABLE rewards.rwd_praise_config (
    id                      BIGSERIAL    PRIMARY KEY,
    company_id              BIGINT       NOT NULL REFERENCES core.companies(id),
    award_type              VARCHAR(30)  NOT NULL
                                CHECK (award_type IN (
                                    'EMPLOYEE_OF_MONTH', 'EMPLOYEE_OF_YEAR', 'BEST_TEAM',
                                    'INNOVATION', 'LOYALTY', 'PERFECT_ATTENDANCE',
                                    'OUTSTANDING_PERFORMANCE')),
    criteria_description    TEXT,
    monetary_equivalent     NUMERIC(12,2),
    non_monetary_description TEXT,
    is_active               BOOLEAN      NOT NULL DEFAULT TRUE,
    created_by              BIGINT       REFERENCES core.users(id),
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------
-- PERFORMANCE-BASED BONUS (PBB) DETERMINATION
-- ----------------------------------------------------------------
CREATE TABLE rewards.rwd_pbb_records (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id),
    year                INTEGER      NOT NULL,
    ipcr_summary_id     BIGINT       REFERENCES performance.perf_ipcr_summary(id),
    ipcr_adjectival     VARCHAR(30),
    opcr_adjectival     VARCHAR(30),
    pbb_tier            VARCHAR(20)  NOT NULL DEFAULT 'NOT_ELIGIBLE'
                            CHECK (pbb_tier IN ('TIER_1', 'TIER_2', 'TIER_3', 'TIER_4', 'NOT_ELIGIBLE')),
    pbb_amount          NUMERIC(12,2),
    conditions_met      TEXT,
    status              VARCHAR(20)  NOT NULL DEFAULT 'PENDING'
                            CHECK (status IN ('PENDING', 'APPROVED', 'RELEASED')),
    released_at         TIMESTAMPTZ,
    released_by         BIGINT       REFERENCES core.users(id),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (employee_id, year)
);

CREATE INDEX idx_pbb_year ON rewards.rwd_pbb_records(year, pbb_tier);

-- ----------------------------------------------------------------
-- RETIREMENT ALERTS
-- ----------------------------------------------------------------
CREATE TABLE rewards.rwd_retirement_alerts (
    id                      BIGSERIAL    PRIMARY KEY,
    employee_id             BIGINT       NOT NULL REFERENCES core.employees(id),
    retirement_age          INTEGER      NOT NULL,
    projected_retirement_date DATE       NOT NULL,
    alert_type              VARCHAR(20)  NOT NULL
                                CHECK (alert_type IN (
                                    'AGE_60_NOTICE', 'AGE_63_NOTICE', 'AGE_65_NOTICE',
                                    '6MO_NOTICE', '3MO_NOTICE', '1MO_NOTICE')),
    scheduled_send_date     DATE         NOT NULL,
    sent_at                 TIMESTAMPTZ,
    recipient_ids           JSONB        NOT NULL DEFAULT '[]',
    notification_ref        VARCHAR(100),
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ret_alert_schedule ON rewards.rwd_retirement_alerts(scheduled_send_date)
    WHERE sent_at IS NULL;

-- ================================================================
-- SEED: R&R PAGE REGISTRY
-- ================================================================
INSERT INTO core.page_registry
    (path, title, nav_group, nav_label, module, nav_icon, nav_order, requires_feature)
VALUES
    ('/rr/nominations',      'PRAISE Nominations',  'Awards', 'Nominations', 'rr', '🏆', 10, 'REWARDS'),
    ('/rr/step-increments',  'Step Increments',     'Awards', 'Step Inc.',   'rr', '📈', 20, 'REWARDS'),
    ('/rr/loyalty',          'Loyalty Awards',      'Awards', 'Loyalty',     'rr', '🎖️', 30, 'REWARDS'),
    ('/rr/pbb',              'PBB Records',         'Awards', 'PBB',         'rr', '💰', 40, 'REWARDS'),
    ('/rr/retirement-notices','Retirement Notices', 'Awards', 'Retirement',  'rr', '🏡', 50, 'REWARDS'),
    ('/rr/ssl-table',        'SSL Salary Table',    'Awards', 'SSL Table',   'rr', '📋', 60, 'REWARDS')
ON CONFLICT (path) DO NOTHING;

-- ================================================================
-- SEED: FEATURE FLAG
-- ================================================================
INSERT INTO core.feature_registry (code, name, description, module, is_enabled) VALUES
    ('REWARDS', 'Rewards & Recognition', 'PRAISE, step increments, PBB, loyalty, retirement', 'rr', TRUE)
ON CONFLICT (code) DO NOTHING;
