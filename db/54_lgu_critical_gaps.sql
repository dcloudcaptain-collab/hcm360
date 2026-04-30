-- ================================================================
-- HCM360 — 54: LGU CRITICAL GAPS (G01–G04, G07, G14)
--
-- Adds tables + page registry + access for six LGU-critical features:
--   G01  CS Form No. 6 strict leave compliance  (extends lv_requests)
--   G02  CS Form No. 7 Exit Interview + Clearance
--   G03  Travel Order (online with DTR integration)
--   G04  Locator Slip (brief out-of-office)
--   G07  LGU Contracts (JO / LSB / BHW / Nutritionist Scholar)
--   G14  Personal Data Sheet (CSC Form 212)
-- ================================================================
SET search_path TO core, leave_mgmt, public;


-- ────────────────────────────────────────────────────────────────
-- G01 · Extend lv_requests with Civil Service Form No. 6 fields
-- ────────────────────────────────────────────────────────────────
ALTER TABLE leave_mgmt.lv_requests
    ADD COLUMN IF NOT EXISTS cs_form6_mode         BOOLEAN       NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS salary_at_time        NUMERIC(14,2),
    ADD COLUMN IF NOT EXISTS whereabouts           VARCHAR(30),  -- WITHIN_PH, ABROAD, HOSPITAL, OUT_PATIENT
    ADD COLUMN IF NOT EXISTS whereabouts_detail    VARCHAR(300),
    ADD COLUMN IF NOT EXISTS illness_specification TEXT,
    ADD COLUMN IF NOT EXISTS commutation           VARCHAR(20)   DEFAULT 'NOT_REQUESTED',
    ADD COLUMN IF NOT EXISTS date_of_filing        DATE,
    ADD COLUMN IF NOT EXISTS recommend_action      VARCHAR(30),  -- APPROVED, DISAPPROVED, APPROVED_WITH_MOD
    ADD COLUMN IF NOT EXISTS recommend_by          BIGINT        REFERENCES core.users(id),
    ADD COLUMN IF NOT EXISTS recommend_at          TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS head_action           VARCHAR(30),
    ADD COLUMN IF NOT EXISTS head_action_by        BIGINT        REFERENCES core.users(id),
    ADD COLUMN IF NOT EXISTS head_action_at        TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS head_remarks          TEXT;

-- Constraint on commutation values
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'lv_req_commutation_chk') THEN
        ALTER TABLE leave_mgmt.lv_requests
            ADD CONSTRAINT lv_req_commutation_chk
            CHECK (commutation IN ('REQUESTED', 'NOT_REQUESTED'));
    END IF;
END $$;


-- ────────────────────────────────────────────────────────────────
-- G02 · Exit Interview + CS Form No. 7 Clearance
-- ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS core.exit_interviews (
    id                  BIGSERIAL   PRIMARY KEY,
    employee_id         BIGINT      NOT NULL REFERENCES core.employees(id) ON DELETE CASCADE,
    resignation_date    DATE,
    last_working_day    DATE        NOT NULL,
    reason_for_leaving  VARCHAR(60),     -- better_opportunity, career_change, relocation, personal, retirement, health, etc.
    future_plans        TEXT,
    would_recommend     BOOLEAN,          -- would they recommend the company?
    would_rejoin        BOOLEAN,
    overall_rating      INT CHECK (overall_rating BETWEEN 1 AND 5),
    manager_rating      INT CHECK (manager_rating  BETWEEN 1 AND 5),
    compensation_rating INT CHECK (compensation_rating BETWEEN 1 AND 5),
    culture_rating      INT CHECK (culture_rating  BETWEEN 1 AND 5),
    best_aspects        TEXT,
    improvement_areas   TEXT,
    additional_comments TEXT,
    status              VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
                         CHECK (status IN ('DRAFT','SUBMITTED','REVIEWED','ARCHIVED')),
    submitted_at        TIMESTAMPTZ,
    reviewed_by         BIGINT REFERENCES core.users(id),
    reviewed_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_exit_emp ON core.exit_interviews (employee_id);


CREATE TABLE IF NOT EXISTS core.clearance_forms (
    id                  BIGSERIAL   PRIMARY KEY,
    employee_id         BIGINT      NOT NULL REFERENCES core.employees(id) ON DELETE CASCADE,
    exit_interview_id   BIGINT      REFERENCES core.exit_interviews(id),
    last_working_day    DATE        NOT NULL,
    status              VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
                         CHECK (status IN ('DRAFT','IN_PROGRESS','CLEARED','ARCHIVED')),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (employee_id, last_working_day)
);


CREATE TABLE IF NOT EXISTS core.clearance_items (
    id                  BIGSERIAL   PRIMARY KEY,
    clearance_id        BIGINT      NOT NULL REFERENCES core.clearance_forms(id) ON DELETE CASCADE,
    signatory_role      VARCHAR(60) NOT NULL,     -- 'Immediate Supervisor','Property Custodian','Accounting',...
    signatory_user_id   BIGINT      REFERENCES core.users(id),
    description         TEXT,
    is_cleared          BOOLEAN     NOT NULL DEFAULT FALSE,
    cleared_at          TIMESTAMPTZ,
    remarks             TEXT,
    sort_order          INT         NOT NULL DEFAULT 0
);


-- ────────────────────────────────────────────────────────────────
-- G03 · Travel Order
-- ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS core.travel_orders (
    id                    BIGSERIAL   PRIMARY KEY,
    control_no            VARCHAR(30) UNIQUE,
    employee_id           BIGINT      NOT NULL REFERENCES core.employees(id) ON DELETE CASCADE,
    purpose               TEXT        NOT NULL,
    destination           VARCHAR(200) NOT NULL,
    date_from             DATE        NOT NULL,
    date_to               DATE        NOT NULL,
    time_from             TIME,
    time_to               TIME,
    mode_of_transport     VARCHAR(80),         -- vehicle, airplane, bus, etc.
    funds_source          VARCHAR(200),        -- chargeable to [budget code]
    estimated_cost        NUMERIC(12,2),
    companions            TEXT,
    remarks               TEXT,
    status                VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
                           CHECK (status IN ('DRAFT','PENDING_SUPERVISOR','PENDING_HEAD',
                                             'APPROVED','REJECTED','CANCELLED','COMPLETED')),
    submitted_at          TIMESTAMPTZ,
    supervisor_user_id    BIGINT REFERENCES core.users(id),
    supervisor_action_at  TIMESTAMPTZ,
    supervisor_remarks    TEXT,
    head_user_id          BIGINT REFERENCES core.users(id),
    head_action_at        TIMESTAMPTZ,
    head_remarks          TEXT,
    dtr_updated           BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (date_to >= date_from)
);
CREATE INDEX IF NOT EXISTS idx_travel_emp ON core.travel_orders (employee_id, date_from);
CREATE INDEX IF NOT EXISTS idx_travel_status ON core.travel_orders (status);


-- ────────────────────────────────────────────────────────────────
-- G04 · Locator Slip
-- ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS core.locator_slips (
    id                  BIGSERIAL   PRIMARY KEY,
    employee_id         BIGINT      NOT NULL REFERENCES core.employees(id) ON DELETE CASCADE,
    slip_date           DATE        NOT NULL DEFAULT CURRENT_DATE,
    purpose             VARCHAR(300) NOT NULL,
    destination         VARCHAR(200) NOT NULL,
    time_out            TIME        NOT NULL,
    expected_return     TIME,
    actual_return       TIME,
    status              VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
                         CHECK (status IN ('DRAFT','PENDING','APPROVED','REJECTED','COMPLETED')),
    approver_user_id    BIGINT REFERENCES core.users(id),
    approved_at         TIMESTAMPTZ,
    remarks             TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_loc_slip_emp ON core.locator_slips (employee_id, slip_date);


-- ────────────────────────────────────────────────────────────────
-- G07 · LGU Contracts (JO / LSB / BHW / Nutritionist Scholar)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS core.lgu_contract_types (
    id            SERIAL PRIMARY KEY,
    code          VARCHAR(20) UNIQUE NOT NULL,
    name          VARCHAR(100) NOT NULL,
    description   TEXT,
    legal_basis   VARCHAR(200),
    default_rate  NUMERIC(12,2),          -- daily/monthly default
    rate_type     VARCHAR(20)             -- 'DAILY', 'MONTHLY', 'HOURLY'
                   CHECK (rate_type IN ('DAILY','MONTHLY','HOURLY','NONE')),
    requires_moa  BOOLEAN NOT NULL DEFAULT FALSE,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order    INT NOT NULL DEFAULT 0
);

INSERT INTO core.lgu_contract_types (code, name, description, legal_basis, rate_type, sort_order)
VALUES
    ('JO',  'Job Order',
     'Short-term engagement for specific non-personal services under COA Circular 2012-001.',
     'COA Circular 2012-001', 'DAILY', 10),
    ('LSB', 'Local School Board Contract',
     'Teachers and SPED personnel engaged by the Local School Board.',
     'RA 5447 / DepEd Order', 'MONTHLY', 20),
    ('BHW', 'Barangay Health Worker',
     'Community-based health worker engaged under the Barangay Health Worker law.',
     'RA 7883', 'MONTHLY', 30),
    ('NS',  'Nutritionist Scholar',
     'Nutritionist-dietitian scholar/intern assigned at LGU level.',
     'RA 2674 / DOH Guidelines', 'MONTHLY', 40)
ON CONFLICT (code) DO NOTHING;


CREATE TABLE IF NOT EXISTS core.lgu_contracts (
    id                BIGSERIAL PRIMARY KEY,
    contract_no       VARCHAR(40) UNIQUE,
    contract_type_id  INT         NOT NULL REFERENCES core.lgu_contract_types(id),
    employee_id       BIGINT      REFERENCES core.employees(id),   -- may be NULL if not yet an employee
    full_name         VARCHAR(200) NOT NULL,
    address           TEXT,
    contact_no        VARCHAR(30),
    email             VARCHAR(200),
    position_title    VARCHAR(200),
    department_id     BIGINT REFERENCES core.departments(id),
    barangay          VARCHAR(100),                 -- for BHW
    school            VARCHAR(200),                 -- for LSB
    date_from         DATE NOT NULL,
    date_to           DATE NOT NULL,
    rate              NUMERIC(12,2),
    rate_type         VARCHAR(20)
                       CHECK (rate_type IN ('DAILY','MONTHLY','HOURLY')),
    funds_source      VARCHAR(200),
    terms             TEXT,
    status            VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
                       CHECK (status IN ('DRAFT','PENDING','APPROVED','ACTIVE',
                                         'EXPIRED','TERMINATED','RENEWED')),
    approver_user_id  BIGINT REFERENCES core.users(id),
    approved_at       TIMESTAMPTZ,
    created_by        BIGINT REFERENCES core.users(id),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (date_to >= date_from)
);
CREATE INDEX IF NOT EXISTS idx_lgu_contract_type ON core.lgu_contracts (contract_type_id);
CREATE INDEX IF NOT EXISTS idx_lgu_contract_status ON core.lgu_contracts (status);
CREATE INDEX IF NOT EXISTS idx_lgu_contract_dates ON core.lgu_contracts (date_from, date_to);


-- ────────────────────────────────────────────────────────────────
-- G14 · Personal Data Sheet (CSC Form 212)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS core.personal_data_sheets (
    id              BIGSERIAL PRIMARY KEY,
    employee_id     BIGINT      NOT NULL REFERENCES core.employees(id) ON DELETE CASCADE,
    version         INT         NOT NULL DEFAULT 1,
    as_of_date      DATE        NOT NULL DEFAULT CURRENT_DATE,
    is_current      BOOLEAN     NOT NULL DEFAULT TRUE,
    data            JSONB       NOT NULL,                  -- full CSC Form 212 content
    status          VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
                     CHECK (status IN ('DRAFT','SUBMITTED','VERIFIED','ARCHIVED')),
    submitted_at    TIMESTAMPTZ,
    verified_at     TIMESTAMPTZ,
    verified_by     BIGINT REFERENCES core.users(id),
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_pds_emp ON core.personal_data_sheets (employee_id, is_current);


-- ────────────────────────────────────────────────────────────────
-- Page Registry
-- ────────────────────────────────────────────────────────────────
INSERT INTO core.page_registry
    (path, title, module, nav_group, nav_label, nav_icon, nav_order, is_visible)
VALUES
    ('/leave/cs-form-6',         'CS Form No. 6 Leave',  'leave_mgmt',
         'Self-Service', 'CS Form No. 6', 'file-text', 40, TRUE),

    ('/offboarding/exit-interview','Exit Interview',     'ess_mss',
         'Self-Service', 'Exit Interview', 'log-out', 50, TRUE),
    ('/offboarding/clearance',   'CS Form No. 7 Clearance','ess_mss',
         'Self-Service', 'Clearance (CS 7)', 'check-square', 51, TRUE),

    ('/travel-orders/',          'Travel Orders',        'core',
         'Self-Service', 'Travel Orders', 'plane', 36, TRUE),
    ('/locator-slips/',          'Locator Slips',        'core',
         'Self-Service', 'Locator Slips', 'map-pin', 37, TRUE),

    ('/lgu-contracts/',          'LGU Contracts',        'core',
         'HR Admin', 'LGU Contracts', 'file-signature', 65, TRUE),

    ('/pds/',                    'Personal Data Sheets', 'core',
         'HR Admin', 'PDS (CSC 212)', 'id-card', 66, TRUE),
    ('/me/pds',                  'My PDS',               'core',
         'Self-Service', 'My PDS', 'id-card', 38, TRUE)
ON CONFLICT (path) DO NOTHING;


-- ────────────────────────────────────────────────────────────────
-- Feature Registry
-- ────────────────────────────────────────────────────────────────
INSERT INTO core.feature_registry
    (code, name, description, module, is_enabled, feature_type, action_type, page_path)
VALUES
    ('CSF6_SUBMIT',       'Submit CS Form No. 6',     'File a CSC-compliant leave application',
        'leave_mgmt', TRUE, 'ACTION', 'CREATE', '/leave/cs-form-6'),
    ('CSF6_PRINT',        'Print CS Form No. 6',      'Download printable CSC leave form',
        'leave_mgmt', TRUE, 'ACTION', 'PRINT',  '/leave/cs-form-6'),

    ('EXIT_SUBMIT',       'Submit Exit Interview',    'Fill and submit exit interview form',
        'ess_mss', TRUE, 'ACTION', 'CREATE', '/offboarding/exit-interview'),
    ('CSF7_CREATE',       'Create Clearance',         'Initiate CS Form No. 7 clearance',
        'ess_mss', TRUE, 'ACTION', 'CREATE', '/offboarding/clearance'),
    ('CSF7_SIGN',         'Sign Clearance Item',      'Clear an item on a clearance form',
        'ess_mss', TRUE, 'ACTION', 'EDIT',   '/offboarding/clearance'),

    ('TO_SUBMIT',         'Submit Travel Order',      'File travel order request',
        'core', TRUE, 'ACTION', 'CREATE', '/travel-orders/'),
    ('TO_APPROVE',        'Approve Travel Order',     'Approve/reject travel order',
        'core', TRUE, 'ACTION', 'APPROVE','/travel-orders/'),

    ('LS_SUBMIT',         'Submit Locator Slip',      'File locator slip request',
        'core', TRUE, 'ACTION', 'CREATE', '/locator-slips/'),
    ('LS_APPROVE',        'Approve Locator Slip',     'Approve/reject locator slip',
        'core', TRUE, 'ACTION', 'APPROVE','/locator-slips/'),

    ('LGU_CONTRACT_CREATE','Create LGU Contract',     'Create JO/LSB/BHW/NS contract',
        'core', TRUE, 'ACTION', 'CREATE', '/lgu-contracts/'),
    ('LGU_CONTRACT_APPROVE','Approve LGU Contract',   'Approve LGU contract',
        'core', TRUE, 'ACTION', 'APPROVE','/lgu-contracts/'),

    ('PDS_EDIT',          'Edit Own PDS',             'Edit own Personal Data Sheet',
        'core', TRUE, 'ACTION', 'EDIT',   '/me/pds'),
    ('PDS_VERIFY',        'Verify PDS',               'HR verifies a submitted PDS',
        'core', TRUE, 'ACTION', 'APPROVE','/pds/')
ON CONFLICT (code) DO NOTHING;


-- ────────────────────────────────────────────────────────────────
-- Role Page Access
-- ────────────────────────────────────────────────────────────────
-- Self-service pages: everyone
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
FROM core.page_registry p
CROSS JOIN (VALUES
    ('SUPER_ADMIN'), ('HR_ADMIN'), ('MANAGER'),
    ('EMPLOYEE'),    ('EXECUTIVE')
) AS r(role_code)
WHERE p.path IN ('/leave/cs-form-6', '/offboarding/exit-interview',
                 '/offboarding/clearance', '/travel-orders/',
                 '/locator-slips/', '/me/pds')
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

-- Admin pages: SUPER_ADMIN + HR_ADMIN only
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
FROM core.page_registry p
CROSS JOIN (VALUES ('SUPER_ADMIN'), ('HR_ADMIN')) AS r(role_code)
WHERE p.path IN ('/lgu-contracts/', '/pds/')
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

-- Explicit denial for admin pages to others
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, FALSE
FROM core.page_registry p
CROSS JOIN (VALUES ('MANAGER'), ('EMPLOYEE'), ('EXECUTIVE')) AS r(role_code)
WHERE p.path IN ('/lgu-contracts/', '/pds/')
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = FALSE;


-- Role Feature Access — everyone can do self-service actions
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.role_code, f.id, TRUE
FROM core.feature_registry f
CROSS JOIN (VALUES
    ('SUPER_ADMIN'), ('HR_ADMIN'), ('MANAGER'),
    ('EMPLOYEE'),    ('EXECUTIVE')
) AS r(role_code)
WHERE f.code IN ('CSF6_SUBMIT','CSF6_PRINT','EXIT_SUBMIT','TO_SUBMIT',
                 'LS_SUBMIT','PDS_EDIT')
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = TRUE;

-- Approval features: HR_ADMIN + SUPER_ADMIN (+ MANAGER for locator slips & travel)
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.role_code, f.id, TRUE
FROM core.feature_registry f
CROSS JOIN (VALUES ('SUPER_ADMIN'), ('HR_ADMIN')) AS r(role_code)
WHERE f.code IN ('CSF7_CREATE','CSF7_SIGN','TO_APPROVE','LS_APPROVE',
                 'LGU_CONTRACT_CREATE','LGU_CONTRACT_APPROVE','PDS_VERIFY')
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = TRUE;

INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.role_code, f.id, TRUE
FROM core.feature_registry f
CROSS JOIN (VALUES ('MANAGER')) AS r(role_code)
WHERE f.code IN ('TO_APPROVE','LS_APPROVE','CSF7_SIGN')
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = TRUE;
