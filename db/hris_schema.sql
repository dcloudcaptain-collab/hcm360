-- ================================================================
-- HCM360 CENTRALIZED HRIS DATABASE SCHEMA
-- Version  : 1.0
-- Target   : MSME → Corporate Grade | 1,000+ Employees
-- Engine   : PostgreSQL 15
-- Port     : 5440 (host) → 5432 (container)
-- Database : hris_central
-- ================================================================
-- Module prefix conventions
--   (no prefix) → core / system tables
--   emp_*       → employee master data
--   att_*       → attendance & timekeeping
--   lv_*        → leave management
--   pay_*       → payroll engine
--   perf_*      → performance management
--   doc_*       → document management (201 file)
--   rec_*       → recruitment pipeline
--   trn_*       → training & development
--   ntf_*       → notifications & alerts
--   sys_*       → system integration & audit
-- ================================================================

-- ── Extensions ──────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "unaccent";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- ================================================================
-- CORE: ORGANIZATION
-- ================================================================

CREATE TABLE companies (
    id                  BIGSERIAL    PRIMARY KEY,
    code                VARCHAR(20)  NOT NULL UNIQUE,
    name                VARCHAR(200) NOT NULL,
    legal_name          VARCHAR(200),
    industry            VARCHAR(100),
    size_bracket        VARCHAR(20)  NOT NULL DEFAULT 'MSME', -- MSME | SME | CORPORATE | ENTERPRISE
    address_line1       TEXT,
    address_line2       TEXT,
    barangay            VARCHAR(100),
    city                VARCHAR(100),
    province            VARCHAR(100),
    region              VARCHAR(100),
    zip_code            VARCHAR(10),
    country             VARCHAR(100) NOT NULL DEFAULT 'Philippines',
    phone               VARCHAR(30),
    email               VARCHAR(200),
    website             VARCHAR(200),
    tin                 VARCHAR(20),
    sss_employer_id     VARCHAR(30),
    phic_employer_id    VARCHAR(30),
    hdmf_employer_id    VARCHAR(30),
    logo_path           TEXT,
    fiscal_year_start   INTEGER      NOT NULL DEFAULT 1,  -- month number 1-12
    payroll_cycle       VARCHAR(20)  NOT NULL DEFAULT 'SEMI_MONTHLY', -- WEEKLY | SEMI_MONTHLY | MONTHLY
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    metadata            JSONB        NOT NULL DEFAULT '{}',
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE business_units (
    id                  BIGSERIAL    PRIMARY KEY,
    company_id          BIGINT       NOT NULL REFERENCES companies(id),
    code                VARCHAR(20)  NOT NULL,
    name                VARCHAR(200) NOT NULL,
    parent_id           BIGINT       REFERENCES business_units(id),
    head_employee_id    BIGINT,      -- FK added after employees
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, code)
);

CREATE TABLE departments (
    id                  BIGSERIAL    PRIMARY KEY,
    company_id          BIGINT       NOT NULL REFERENCES companies(id),
    business_unit_id    BIGINT       REFERENCES business_units(id),
    code                VARCHAR(20)  NOT NULL,
    name                VARCHAR(200) NOT NULL,
    parent_id           BIGINT       REFERENCES departments(id),
    head_employee_id    BIGINT,      -- FK added after employees
    cost_center_code    VARCHAR(20),
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, code)
);

CREATE TABLE job_grades (
    id                  BIGSERIAL    PRIMARY KEY,
    company_id          BIGINT       NOT NULL REFERENCES companies(id),
    code                VARCHAR(20)  NOT NULL,
    name                VARCHAR(100) NOT NULL,
    grade_level         INTEGER      NOT NULL,  -- 1 = entry, higher = senior
    salary_min          NUMERIC(14,2),
    salary_max          NUMERIC(14,2),
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, code)
);

CREATE TABLE positions (
    id                  BIGSERIAL    PRIMARY KEY,
    company_id          BIGINT       NOT NULL REFERENCES companies(id),
    department_id       BIGINT       REFERENCES departments(id),
    job_grade_id        BIGINT       REFERENCES job_grades(id),
    code                VARCHAR(20)  NOT NULL,
    title               VARCHAR(200) NOT NULL,
    description         TEXT,
    is_managerial       BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, code)
);

CREATE TABLE employment_types (
    id                  BIGSERIAL    PRIMARY KEY,
    code                VARCHAR(30)  NOT NULL UNIQUE,
    name                VARCHAR(100) NOT NULL,
    description         TEXT,
    is_entitled_benefits BOOLEAN     NOT NULL DEFAULT TRUE,
    probation_days      INTEGER      NOT NULL DEFAULT 0,
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ================================================================
-- CORE: USERS & ACCESS CONTROL
-- ================================================================

CREATE TABLE users (
    id                  BIGSERIAL    PRIMARY KEY,
    company_id          BIGINT       REFERENCES companies(id),
    username            VARCHAR(100) NOT NULL UNIQUE,
    email               VARCHAR(200) UNIQUE,
    password_hash       VARCHAR(255) NOT NULL DEFAULT '',
    display_name        VARCHAR(150),
    role_code           VARCHAR(50)  NOT NULL DEFAULT 'EMPLOYEE',  -- SUPER_ADMIN | HR_ADMIN | MANAGER | EMPLOYEE
    employee_id         BIGINT,      -- FK added after employees
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    last_login_at       TIMESTAMPTZ,
    failed_attempts     INTEGER      NOT NULL DEFAULT 0,
    locked_until        TIMESTAMPTZ,
    password_changed_at TIMESTAMPTZ,
    mfa_enabled         BOOLEAN      NOT NULL DEFAULT FALSE,
    mfa_secret          VARCHAR(100),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE roles (
    id                  BIGSERIAL    PRIMARY KEY,
    company_id          BIGINT       REFERENCES companies(id),  -- NULL = system-wide
    code                VARCHAR(50)  NOT NULL,
    name                VARCHAR(100) NOT NULL,
    description         TEXT,
    is_system_role      BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, code)
);

CREATE TABLE permissions (
    id                  BIGSERIAL    PRIMARY KEY,
    module              VARCHAR(50)  NOT NULL,
    resource            VARCHAR(100) NOT NULL,
    action              VARCHAR(50)  NOT NULL,  -- VIEW | CREATE | EDIT | DELETE | APPROVE | EXPORT
    description         TEXT,
    UNIQUE (module, resource, action)
);

CREATE TABLE role_permissions (
    id                  BIGSERIAL    PRIMARY KEY,
    role_id             BIGINT       NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id       BIGINT       NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    granted             BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (role_id, permission_id)
);

CREATE TABLE user_roles (
    id                  BIGSERIAL    PRIMARY KEY,
    user_id             BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id             BIGINT       NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    assigned_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    assigned_by         BIGINT       REFERENCES users(id),
    expires_at          TIMESTAMPTZ,
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    UNIQUE (user_id, role_id)
);

-- ================================================================
-- MODULE 1: EMPLOYEE MASTER DATA
-- ================================================================

CREATE TABLE employees (
    id                      BIGSERIAL    PRIMARY KEY,
    uuid                    UUID         NOT NULL DEFAULT uuid_generate_v4() UNIQUE,
    company_id              BIGINT       NOT NULL REFERENCES companies(id),
    employee_no             VARCHAR(30)  NOT NULL,
    -- Personal identity
    last_name               VARCHAR(100) NOT NULL,
    first_name              VARCHAR(100) NOT NULL,
    middle_name             VARCHAR(100),
    suffix                  VARCHAR(10),
    preferred_name          VARCHAR(100),
    gender                  VARCHAR(20),
    civil_status            VARCHAR(20),
    nationality             VARCHAR(50)  NOT NULL DEFAULT 'Filipino',
    religion                VARCHAR(50),
    date_of_birth           DATE,
    place_of_birth          VARCHAR(200),
    blood_type              VARCHAR(5),
    -- Contact
    personal_email          VARCHAR(200),
    work_email              VARCHAR(200),
    mobile_no               VARCHAR(20),
    phone_no                VARCHAR(20),
    -- Organizational placement
    department_id           BIGINT       REFERENCES departments(id),
    position_id             BIGINT       REFERENCES positions(id),
    job_grade_id            BIGINT       REFERENCES job_grades(id),
    employment_type_id      BIGINT       REFERENCES employment_types(id),
    immediate_supervisor_id BIGINT       REFERENCES employees(id),
    -- Employment timeline
    date_hired              DATE,
    date_regularized        DATE,
    probation_end_date      DATE,
    date_separated          DATE,
    -- Status
    status                  VARCHAR(30)  NOT NULL DEFAULT 'PROBATIONARY',
    -- ACTIVE | PROBATIONARY | ON_LEAVE | RESIGNED | TERMINATED | RETIRED | DECEASED
    separation_reason       TEXT,
    -- Compensation basis
    basic_salary            NUMERIC(14,2),
    daily_rate              NUMERIC(10,4),
    hourly_rate             NUMERIC(10,4),
    cost_center_code        VARCHAR(20),
    work_location           VARCHAR(200),
    work_arrangement        VARCHAR(20)  NOT NULL DEFAULT 'ONSITE',  -- ONSITE | REMOTE | HYBRID
    -- Physical
    height_cm               NUMERIC(5,1),
    weight_kg               NUMERIC(5,1),
    -- Files
    profile_photo_path      TEXT,
    -- Metadata
    is_active               BOOLEAN      NOT NULL DEFAULT TRUE,
    metadata                JSONB        NOT NULL DEFAULT '{}',
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_by              BIGINT       REFERENCES users(id),
    updated_by              BIGINT       REFERENCES users(id),
    UNIQUE (company_id, employee_no)
);

CREATE TABLE emp_addresses (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    address_type    VARCHAR(30)  NOT NULL,  -- PRESENT | PERMANENT | PROVINCIAL
    line1           TEXT         NOT NULL,
    line2           TEXT,
    barangay        VARCHAR(100),
    city            VARCHAR(100),
    province        VARCHAR(100),
    region          VARCHAR(100),
    zip_code        VARCHAR(10),
    country         VARCHAR(100) NOT NULL DEFAULT 'Philippines',
    is_primary      BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE emp_emergency_contacts (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    full_name       VARCHAR(200) NOT NULL,
    relationship    VARCHAR(50)  NOT NULL,
    mobile_no       VARCHAR(20),
    phone_no        VARCHAR(20),
    address         TEXT,
    is_primary      BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE emp_government_ids (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    id_type         VARCHAR(30)  NOT NULL,
    -- SSS | TIN | PHILHEALTH | PAGIBIG | UMID | PASSPORT | VOTER_ID | DRIVERS_LICENSE | NATIONAL_ID
    id_number       VARCHAR(50)  NOT NULL,
    issue_date      DATE,
    expiry_date     DATE,
    file_path       TEXT,
    is_verified     BOOLEAN      NOT NULL DEFAULT FALSE,
    verified_by     BIGINT       REFERENCES users(id),
    verified_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (employee_id, id_type)
);

CREATE TABLE emp_bank_accounts (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    bank_name       VARCHAR(100) NOT NULL,
    bank_code       VARCHAR(20),
    account_name    VARCHAR(200) NOT NULL,
    account_number  VARCHAR(50)  NOT NULL,
    account_type    VARCHAR(30)  NOT NULL DEFAULT 'SAVINGS',  -- SAVINGS | CHECKING
    is_primary      BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE emp_dependents (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    full_name       VARCHAR(200) NOT NULL,
    relationship    VARCHAR(50)  NOT NULL,
    date_of_birth   DATE,
    is_beneficiary  BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE emp_education (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    level           VARCHAR(50)  NOT NULL,
    -- ELEMENTARY | HIGH_SCHOOL | SENIOR_HIGH | VOCATIONAL | COLLEGE | POST_GRADUATE
    institution     VARCHAR(200) NOT NULL,
    degree          VARCHAR(200),
    field_of_study  VARCHAR(200),
    year_from       INTEGER,
    year_to         INTEGER,
    honors          VARCHAR(100),
    is_highest      BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE emp_work_history (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    company_name        VARCHAR(200) NOT NULL,
    position_held       VARCHAR(200),
    date_from           DATE,
    date_to             DATE,
    reason_for_leaving  TEXT,
    immediate_supervisor VARCHAR(200),
    contact_no          VARCHAR(30),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE emp_status_history (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    from_status     VARCHAR(30),
    to_status       VARCHAR(30)  NOT NULL,
    effective_date  DATE         NOT NULL,
    reason          TEXT,
    remarks         TEXT,
    changed_by      BIGINT       REFERENCES users(id),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ================================================================
-- MODULE 2: ATTENDANCE & TIMEKEEPING
-- ================================================================

CREATE TABLE att_shifts (
    id                      BIGSERIAL    PRIMARY KEY,
    company_id              BIGINT       NOT NULL REFERENCES companies(id),
    code                    VARCHAR(20)  NOT NULL,
    name                    VARCHAR(100) NOT NULL,
    shift_type              VARCHAR(20)  NOT NULL DEFAULT 'FIXED',  -- FIXED | FLEXI | ROTATING
    time_in                 TIME,
    time_out                TIME,
    break_minutes           INTEGER      NOT NULL DEFAULT 60,
    total_work_hours        NUMERIC(4,2),
    grace_period_minutes    INTEGER      NOT NULL DEFAULT 0,
    is_night_shift          BOOLEAN      NOT NULL DEFAULT FALSE,
    crosses_midnight        BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active               BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, code)
);

CREATE TABLE att_shift_assignments (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES employees(id),
    shift_id        BIGINT       NOT NULL REFERENCES att_shifts(id),
    effective_from  DATE         NOT NULL,
    effective_to    DATE,
    created_by      BIGINT       REFERENCES users(id),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE att_holiday_types (
    id              BIGSERIAL    PRIMARY KEY,
    code            VARCHAR(20)  NOT NULL UNIQUE,
    name            VARCHAR(100) NOT NULL,
    pay_multiplier  NUMERIC(4,2) NOT NULL DEFAULT 1.0,
    description     TEXT
);

CREATE TABLE att_holidays (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES companies(id),
    holiday_type_id BIGINT       NOT NULL REFERENCES att_holiday_types(id),
    holiday_date    DATE         NOT NULL,
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    is_recurring    BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, holiday_date, name)
);

-- Partitioned raw log table (biometric / QR / manual)
CREATE TABLE att_logs (
    id              BIGSERIAL    NOT NULL,
    employee_id     BIGINT       NOT NULL REFERENCES employees(id),
    log_datetime    TIMESTAMPTZ  NOT NULL,
    log_type        VARCHAR(10)  NOT NULL,  -- IN | OUT | BREAK_OUT | BREAK_IN
    source          VARCHAR(20)  NOT NULL DEFAULT 'MANUAL',  -- BIOMETRIC | QR | MANUAL | MOBILE
    device_id       VARCHAR(50),
    location        VARCHAR(200),
    photo_path      TEXT,
    is_valid        BOOLEAN      NOT NULL DEFAULT TRUE,
    invalidated_by  BIGINT       REFERENCES users(id),
    invalidation_reason TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, log_datetime)
) PARTITION BY RANGE (log_datetime);

CREATE TABLE att_logs_2025 PARTITION OF att_logs FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE att_logs_2026 PARTITION OF att_logs FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE att_logs_2027 PARTITION OF att_logs FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
CREATE TABLE att_logs_2028 PARTITION OF att_logs FOR VALUES FROM ('2028-01-01') TO ('2029-01-01');

-- Computed daily attendance summary (one row per employee per day)
CREATE TABLE att_daily (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES employees(id),
    work_date           DATE         NOT NULL,
    shift_id            BIGINT       REFERENCES att_shifts(id),
    time_in             TIMESTAMPTZ,
    time_out            TIMESTAMPTZ,
    hours_worked        NUMERIC(5,2) NOT NULL DEFAULT 0,
    hours_late          NUMERIC(5,2) NOT NULL DEFAULT 0,
    hours_undertime     NUMERIC(5,2) NOT NULL DEFAULT 0,
    hours_overtime      NUMERIC(5,2) NOT NULL DEFAULT 0,
    hours_night_diff    NUMERIC(5,2) NOT NULL DEFAULT 0,
    status              VARCHAR(20)  NOT NULL DEFAULT 'ABSENT',
    -- PRESENT | ABSENT | LATE | HALF_DAY | ON_LEAVE | HOLIDAY | RESTDAY | OB
    is_holiday          BOOLEAN      NOT NULL DEFAULT FALSE,
    holiday_id          BIGINT       REFERENCES att_holidays(id),
    is_restday          BOOLEAN      NOT NULL DEFAULT FALSE,
    leave_request_id    BIGINT,      -- FK added after lv_requests
    remarks             TEXT,
    is_locked           BOOLEAN      NOT NULL DEFAULT FALSE,
    locked_by           BIGINT       REFERENCES users(id),
    locked_at           TIMESTAMPTZ,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (employee_id, work_date)
);

CREATE TABLE att_overtime_requests (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES employees(id),
    request_date        DATE         NOT NULL,
    expected_ot_hours   NUMERIC(4,2) NOT NULL,
    reason              TEXT         NOT NULL,
    status              VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    approved_by         BIGINT       REFERENCES employees(id),
    approved_at         TIMESTAMPTZ,
    rejection_reason    TEXT,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ================================================================
-- MODULE 3: LEAVE MANAGEMENT
-- ================================================================

CREATE TABLE lv_types (
    id                      BIGSERIAL    PRIMARY KEY,
    company_id              BIGINT       NOT NULL REFERENCES companies(id),
    code                    VARCHAR(30)  NOT NULL,
    name                    VARCHAR(100) NOT NULL,
    description             TEXT,
    is_paid                 BOOLEAN      NOT NULL DEFAULT TRUE,
    requires_document       BOOLEAN      NOT NULL DEFAULT FALSE,
    min_days                NUMERIC(4,1) NOT NULL DEFAULT 1,
    max_days_per_filing     NUMERIC(4,1),
    notice_days_required    INTEGER      NOT NULL DEFAULT 0,
    gender_restriction      VARCHAR(10),  -- M | F | NULL = all
    is_active               BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, code)
);

CREATE TABLE lv_policies (
    id                      BIGSERIAL    PRIMARY KEY,
    company_id              BIGINT       NOT NULL REFERENCES companies(id),
    leave_type_id           BIGINT       NOT NULL REFERENCES lv_types(id),
    employment_type_id      BIGINT       REFERENCES employment_types(id),
    annual_days             NUMERIC(5,1) NOT NULL,
    accrual_type            VARCHAR(20)  NOT NULL DEFAULT 'ANNUAL',  -- ANNUAL | MONTHLY | AFTER_REGULARIZATION
    carry_over_allowed      BOOLEAN      NOT NULL DEFAULT FALSE,
    carry_over_max_days     NUMERIC(5,1) NOT NULL DEFAULT 0,
    monetization_allowed    BOOLEAN      NOT NULL DEFAULT FALSE,
    months_before_entitled  INTEGER      NOT NULL DEFAULT 0,
    effective_from          DATE,
    effective_to            DATE,
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE lv_balances (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES employees(id),
    leave_type_id   BIGINT       NOT NULL REFERENCES lv_types(id),
    year            INTEGER      NOT NULL,
    entitled_days   NUMERIC(5,1) NOT NULL DEFAULT 0,
    accrued_days    NUMERIC(5,1) NOT NULL DEFAULT 0,
    used_days       NUMERIC(5,1) NOT NULL DEFAULT 0,
    pending_days    NUMERIC(5,1) NOT NULL DEFAULT 0,
    carried_over    NUMERIC(5,1) NOT NULL DEFAULT 0,
    forfeited_days  NUMERIC(5,1) NOT NULL DEFAULT 0,
    balance         NUMERIC(5,1) GENERATED ALWAYS AS
                    (accrued_days + carried_over - used_days - pending_days) STORED,
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (employee_id, leave_type_id, year)
);

CREATE TABLE lv_requests (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES employees(id),
    leave_type_id   BIGINT       NOT NULL REFERENCES lv_types(id),
    date_from       DATE         NOT NULL,
    date_to         DATE         NOT NULL,
    days_requested  NUMERIC(4,1) NOT NULL,
    reason          TEXT,
    status          VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    -- PENDING | APPROVED | REJECTED | CANCELLED | WITHDRAWN
    is_half_day     BOOLEAN      NOT NULL DEFAULT FALSE,
    half_day_type   VARCHAR(5),   -- AM | PM
    document_path   TEXT,
    filed_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    return_date     DATE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE lv_approvals (
    id              BIGSERIAL    PRIMARY KEY,
    request_id      BIGINT       NOT NULL REFERENCES lv_requests(id) ON DELETE CASCADE,
    approval_level  INTEGER      NOT NULL DEFAULT 1,
    approver_id     BIGINT       NOT NULL REFERENCES employees(id),
    status          VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    remarks         TEXT,
    acted_at        TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE lv_ledger (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES employees(id),
    leave_type_id       BIGINT       NOT NULL REFERENCES lv_types(id),
    year                INTEGER      NOT NULL,
    transaction_type    VARCHAR(30)  NOT NULL,
    -- ACCRUAL | USAGE | CARRY_OVER | ADJUSTMENT | MONETIZATION | FORFEITURE
    days                NUMERIC(5,1) NOT NULL,
    reference_id        BIGINT,
    reference_type      VARCHAR(30),
    remarks             TEXT,
    created_by          BIGINT       REFERENCES users(id),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ================================================================
-- MODULE 4: PAYROLL ENGINE
-- ================================================================

CREATE TABLE pay_periods (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES companies(id),
    period_code     VARCHAR(30)  NOT NULL,
    period_type     VARCHAR(20)  NOT NULL,  -- WEEKLY | SEMI_MONTHLY | MONTHLY
    date_from       DATE         NOT NULL,
    date_to         DATE         NOT NULL,
    payment_date    DATE,
    status          VARCHAR(20)  NOT NULL DEFAULT 'OPEN',  -- OPEN | PROCESSING | CLOSED | POSTED
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, period_code)
);

CREATE TABLE pay_runs (
    id              BIGSERIAL    PRIMARY KEY,
    period_id       BIGINT       NOT NULL REFERENCES pay_periods(id),
    run_number      INTEGER      NOT NULL DEFAULT 1,
    status          VARCHAR(20)  NOT NULL DEFAULT 'DRAFT',
    -- DRAFT | COMPUTING | COMPUTED | APPROVED | POSTED | REVERSED
    total_employees INTEGER      NOT NULL DEFAULT 0,
    total_gross     NUMERIC(16,2) NOT NULL DEFAULT 0,
    total_deductions NUMERIC(16,2) NOT NULL DEFAULT 0,
    total_net       NUMERIC(16,2) NOT NULL DEFAULT 0,
    computed_at     TIMESTAMPTZ,
    computed_by     BIGINT       REFERENCES users(id),
    approved_at     TIMESTAMPTZ,
    approved_by     BIGINT       REFERENCES users(id),
    posted_at       TIMESTAMPTZ,
    posted_by       BIGINT       REFERENCES users(id),
    remarks         TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (period_id, run_number)
);

CREATE TABLE pay_employee_payroll (
    id                  BIGSERIAL    PRIMARY KEY,
    run_id              BIGINT       NOT NULL REFERENCES pay_runs(id),
    employee_id         BIGINT       NOT NULL REFERENCES employees(id),
    -- Attendance basis
    scheduled_days      NUMERIC(5,2) NOT NULL DEFAULT 0,
    worked_days         NUMERIC(5,2) NOT NULL DEFAULT 0,
    absent_days         NUMERIC(5,2) NOT NULL DEFAULT 0,
    leave_days          NUMERIC(5,2) NOT NULL DEFAULT 0,
    late_hours          NUMERIC(5,2) NOT NULL DEFAULT 0,
    undertime_hours     NUMERIC(5,2) NOT NULL DEFAULT 0,
    ot_regular_hours    NUMERIC(5,2) NOT NULL DEFAULT 0,
    ot_restday_hours    NUMERIC(5,2) NOT NULL DEFAULT 0,
    ot_holiday_hours    NUMERIC(5,2) NOT NULL DEFAULT 0,
    night_diff_hours    NUMERIC(5,2) NOT NULL DEFAULT 0,
    -- Earnings
    basic_pay           NUMERIC(14,2) NOT NULL DEFAULT 0,
    ot_pay              NUMERIC(14,2) NOT NULL DEFAULT 0,
    holiday_pay         NUMERIC(14,2) NOT NULL DEFAULT 0,
    night_diff_pay      NUMERIC(14,2) NOT NULL DEFAULT 0,
    allowances_total    NUMERIC(14,2) NOT NULL DEFAULT 0,
    other_earnings      NUMERIC(14,2) NOT NULL DEFAULT 0,
    gross_pay           NUMERIC(14,2) NOT NULL DEFAULT 0,
    -- Mandatory deductions (employee share)
    sss_ee              NUMERIC(10,2) NOT NULL DEFAULT 0,
    philhealth_ee       NUMERIC(10,2) NOT NULL DEFAULT 0,
    pagibig_ee          NUMERIC(10,2) NOT NULL DEFAULT 0,
    withholding_tax     NUMERIC(10,2) NOT NULL DEFAULT 0,
    -- Other deductions
    late_deduction      NUMERIC(10,2) NOT NULL DEFAULT 0,
    absent_deduction    NUMERIC(10,2) NOT NULL DEFAULT 0,
    loan_deduction      NUMERIC(10,2) NOT NULL DEFAULT 0,
    other_deductions    NUMERIC(10,2) NOT NULL DEFAULT 0,
    total_deductions    NUMERIC(14,2) NOT NULL DEFAULT 0,
    -- Employer contributions (cost tracking)
    sss_er              NUMERIC(10,2) NOT NULL DEFAULT 0,
    sss_ec              NUMERIC(10,2) NOT NULL DEFAULT 0,
    philhealth_er       NUMERIC(10,2) NOT NULL DEFAULT 0,
    pagibig_er          NUMERIC(10,2) NOT NULL DEFAULT 0,
    -- Result
    net_pay             NUMERIC(14,2) NOT NULL DEFAULT 0,
    status              VARCHAR(20)  NOT NULL DEFAULT 'COMPUTED',
    -- COMPUTED | APPROVED | POSTED | DISPUTED | REVERSED
    payslip_path        TEXT,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (run_id, employee_id)
);

CREATE TABLE pay_earnings_detail (
    id              BIGSERIAL    PRIMARY KEY,
    payroll_id      BIGINT       NOT NULL REFERENCES pay_employee_payroll(id) ON DELETE CASCADE,
    earning_type    VARCHAR(50)  NOT NULL,
    description     VARCHAR(200),
    hours           NUMERIC(6,2),
    rate            NUMERIC(12,4),
    amount          NUMERIC(14,2) NOT NULL
);

CREATE TABLE pay_deductions_detail (
    id              BIGSERIAL    PRIMARY KEY,
    payroll_id      BIGINT       NOT NULL REFERENCES pay_employee_payroll(id) ON DELETE CASCADE,
    deduction_type  VARCHAR(50)  NOT NULL,
    description     VARCHAR(200),
    amount          NUMERIC(14,2) NOT NULL,
    reference_no    VARCHAR(100)
);

CREATE TABLE pay_employee_allowances (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES employees(id),
    allowance_type  VARCHAR(50)  NOT NULL,
    -- TRANSPORT | MEAL | COMMUNICATION | HOUSING | RICE | CLOTHING | LAUNDRY
    amount          NUMERIC(12,2) NOT NULL,
    frequency       VARCHAR(20)  NOT NULL DEFAULT 'MONTHLY',
    taxable         BOOLEAN      NOT NULL DEFAULT FALSE,
    effective_from  DATE,
    effective_to    DATE,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE pay_employee_loans (
    id                      BIGSERIAL    PRIMARY KEY,
    employee_id             BIGINT       NOT NULL REFERENCES employees(id),
    loan_type               VARCHAR(50)  NOT NULL,
    -- SSS_CALAMITY | SSS_SALARY | PAGIBIG_MULTI | PAGIBIG_HOUSING | COMPANY_LOAN
    reference_no            VARCHAR(100),
    total_amount            NUMERIC(14,2) NOT NULL,
    outstanding_balance     NUMERIC(14,2) NOT NULL,
    monthly_amortization    NUMERIC(12,2) NOT NULL,
    start_date              DATE         NOT NULL,
    end_date                DATE,
    status                  VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',
    -- ACTIVE | FULLY_PAID | DEFAULTED | RESTRUCTURED
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- PH Statutory Contribution Tables

CREATE TABLE pay_sss_table (
    id                  BIGSERIAL    PRIMARY KEY,
    effective_date      DATE         NOT NULL,
    salary_from         NUMERIC(12,2) NOT NULL,
    salary_to           NUMERIC(12,2),
    ee_contribution     NUMERIC(10,2) NOT NULL,
    er_contribution     NUMERIC(10,2) NOT NULL,
    ec_contribution     NUMERIC(10,2) NOT NULL DEFAULT 0,
    total_contribution  NUMERIC(10,2) NOT NULL
);

CREATE TABLE pay_philhealth_table (
    id              BIGSERIAL    PRIMARY KEY,
    effective_date  DATE         NOT NULL,
    salary_from     NUMERIC(12,2) NOT NULL,
    salary_to       NUMERIC(12,2),
    premium_rate    NUMERIC(6,4) NOT NULL,
    ee_share        NUMERIC(6,4) NOT NULL DEFAULT 0.50,
    er_share        NUMERIC(6,4) NOT NULL DEFAULT 0.50,
    min_premium     NUMERIC(10,2),
    max_premium     NUMERIC(10,2)
);

CREATE TABLE pay_pagibig_table (
    id                          BIGSERIAL    PRIMARY KEY,
    effective_date              DATE         NOT NULL,
    salary_from                 NUMERIC(12,2) NOT NULL,
    salary_to                   NUMERIC(12,2),
    ee_rate                     NUMERIC(6,4) NOT NULL,
    er_rate                     NUMERIC(6,4) NOT NULL,
    max_monthly_compensation    NUMERIC(12,2)
);

-- BIR withholding tax table (annualized, all frequencies)
CREATE TABLE pay_bir_tax_table (
    id              BIGSERIAL    PRIMARY KEY,
    effective_date  DATE         NOT NULL,
    frequency       VARCHAR(20)  NOT NULL,  -- ANNUAL | MONTHLY | SEMI_MONTHLY | WEEKLY | DAILY
    income_from     NUMERIC(14,2) NOT NULL,
    income_to       NUMERIC(14,2),
    base_tax        NUMERIC(14,2) NOT NULL DEFAULT 0,
    excess_rate     NUMERIC(8,4) NOT NULL DEFAULT 0,
    excess_over     NUMERIC(14,2) NOT NULL DEFAULT 0
);

CREATE TABLE pay_13th_month (
    id                      BIGSERIAL    PRIMARY KEY,
    company_id              BIGINT       NOT NULL REFERENCES companies(id),
    employee_id             BIGINT       NOT NULL REFERENCES employees(id),
    year                    INTEGER      NOT NULL,
    jan_basic               NUMERIC(14,2) NOT NULL DEFAULT 0,
    feb_basic               NUMERIC(14,2) NOT NULL DEFAULT 0,
    mar_basic               NUMERIC(14,2) NOT NULL DEFAULT 0,
    apr_basic               NUMERIC(14,2) NOT NULL DEFAULT 0,
    may_basic               NUMERIC(14,2) NOT NULL DEFAULT 0,
    jun_basic               NUMERIC(14,2) NOT NULL DEFAULT 0,
    jul_basic               NUMERIC(14,2) NOT NULL DEFAULT 0,
    aug_basic               NUMERIC(14,2) NOT NULL DEFAULT 0,
    sep_basic               NUMERIC(14,2) NOT NULL DEFAULT 0,
    oct_basic               NUMERIC(14,2) NOT NULL DEFAULT 0,
    nov_basic               NUMERIC(14,2) NOT NULL DEFAULT 0,
    total_basic             NUMERIC(14,2) NOT NULL DEFAULT 0,
    months_worked           NUMERIC(4,1) NOT NULL DEFAULT 0,
    thirteenth_month_pay    NUMERIC(14,2) NOT NULL DEFAULT 0,
    status                  VARCHAR(20)  NOT NULL DEFAULT 'DRAFT',
    -- DRAFT | COMPUTED | RELEASED
    released_on             DATE,
    released_via_run_id     BIGINT       REFERENCES pay_runs(id),
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, employee_id, year)
);

-- ================================================================
-- MODULE 5: PERFORMANCE MANAGEMENT
-- ================================================================

CREATE TABLE perf_cycles (
    id                  BIGSERIAL    PRIMARY KEY,
    company_id          BIGINT       NOT NULL REFERENCES companies(id),
    name                VARCHAR(200) NOT NULL,
    cycle_type          VARCHAR(20)  NOT NULL DEFAULT 'ANNUAL',
    -- ANNUAL | SEMI_ANNUAL | QUARTERLY | PROBATIONARY
    year                INTEGER      NOT NULL,
    period              INTEGER,     -- 1 = first half / Q1, etc.
    goal_setting_start  DATE,
    goal_setting_end    DATE,
    mid_review_start    DATE,
    mid_review_end      DATE,
    final_review_start  DATE,
    final_review_end    DATE,
    status              VARCHAR(20)  NOT NULL DEFAULT 'PLANNING',
    -- PLANNING | GOAL_SETTING | MID_REVIEW | FINAL_REVIEW | CLOSED
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE perf_kpi_categories (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES companies(id),
    code            VARCHAR(30)  NOT NULL,
    name            VARCHAR(100) NOT NULL,
    weight          NUMERIC(5,2) NOT NULL DEFAULT 0,
    UNIQUE (company_id, code)
);

CREATE TABLE perf_kpis (
    id                  BIGSERIAL    PRIMARY KEY,
    company_id          BIGINT       NOT NULL REFERENCES companies(id),
    category_id         BIGINT       REFERENCES perf_kpi_categories(id),
    code                VARCHAR(30)  NOT NULL,
    name                VARCHAR(200) NOT NULL,
    description         TEXT,
    measurement_unit    VARCHAR(50),
    kpi_type            VARCHAR(20)  NOT NULL DEFAULT 'QUANTITATIVE',
    -- QUANTITATIVE | QUALITATIVE | BEHAVIORAL
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    UNIQUE (company_id, code)
);

CREATE TABLE perf_employee_kpis (
    id                  BIGSERIAL    PRIMARY KEY,
    cycle_id            BIGINT       NOT NULL REFERENCES perf_cycles(id),
    employee_id         BIGINT       NOT NULL REFERENCES employees(id),
    kpi_id              BIGINT       NOT NULL REFERENCES perf_kpis(id),
    target_value        NUMERIC(14,4),
    target_description  TEXT,
    weight              NUMERIC(5,2) NOT NULL DEFAULT 0,
    actual_value        NUMERIC(14,4),
    score               NUMERIC(5,2),
    status              VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (cycle_id, employee_id, kpi_id)
);

CREATE TABLE perf_reviews (
    id                          BIGSERIAL    PRIMARY KEY,
    cycle_id                    BIGINT       NOT NULL REFERENCES perf_cycles(id),
    employee_id                 BIGINT       NOT NULL REFERENCES employees(id),
    reviewer_id                 BIGINT       NOT NULL REFERENCES employees(id),
    review_type                 VARCHAR(20)  NOT NULL DEFAULT 'ANNUAL',
    overall_rating              NUMERIC(4,2),
    rating_label                VARCHAR(50),
    status                      VARCHAR(20)  NOT NULL DEFAULT 'DRAFT',
    -- DRAFT | SELF_EVAL | MANAGER_EVAL | ACKNOWLEDGED | FINALIZED
    self_eval_submitted_at      TIMESTAMPTZ,
    reviewer_submitted_at       TIMESTAMPTZ,
    acknowledged_at             TIMESTAMPTZ,
    calibrated_rating           NUMERIC(4,2),
    calibration_remarks         TEXT,
    created_at                  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (cycle_id, employee_id, reviewer_id)
);

CREATE TABLE perf_review_ratings (
    id                  BIGSERIAL    PRIMARY KEY,
    review_id           BIGINT       NOT NULL REFERENCES perf_reviews(id) ON DELETE CASCADE,
    kpi_id              BIGINT       NOT NULL REFERENCES perf_kpis(id),
    self_rating         NUMERIC(4,2),
    manager_rating      NUMERIC(4,2),
    final_rating        NUMERIC(4,2),
    self_comments       TEXT,
    manager_comments    TEXT
);

CREATE TABLE perf_review_feedback (
    id              BIGSERIAL    PRIMARY KEY,
    review_id       BIGINT       NOT NULL REFERENCES perf_reviews(id) ON DELETE CASCADE,
    feedback_type   VARCHAR(50)  NOT NULL,
    -- STRENGTHS | IMPROVEMENTS | DEVELOPMENT_GOALS | GENERAL
    authored_by     VARCHAR(20)  NOT NULL,  -- SELF | MANAGER
    content         TEXT         NOT NULL,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ================================================================
-- MODULE 6: DOCUMENT MANAGEMENT (201 FILE)
-- ================================================================

CREATE TABLE doc_categories (
    id              BIGSERIAL    PRIMARY KEY,
    code            VARCHAR(30)  NOT NULL UNIQUE,
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    requires_expiry BOOLEAN      NOT NULL DEFAULT FALSE,
    is_confidential BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE doc_employee_files (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES employees(id),
    category_id         BIGINT       NOT NULL REFERENCES doc_categories(id),
    document_name       VARCHAR(200) NOT NULL,
    document_no         VARCHAR(100),
    file_path           TEXT         NOT NULL,
    file_size_kb        INTEGER,
    file_mime_type      VARCHAR(50),
    issued_date         DATE,
    expiry_date         DATE,
    issuing_authority   VARCHAR(200),
    version             INTEGER      NOT NULL DEFAULT 1,
    is_current          BOOLEAN      NOT NULL DEFAULT TRUE,
    is_confidential     BOOLEAN      NOT NULL DEFAULT FALSE,
    uploaded_by         BIGINT       REFERENCES users(id),
    uploaded_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    remarks             TEXT
);

CREATE TABLE doc_versions (
    id              BIGSERIAL    PRIMARY KEY,
    document_id     BIGINT       NOT NULL REFERENCES doc_employee_files(id),
    version         INTEGER      NOT NULL,
    file_path       TEXT         NOT NULL,
    uploaded_by     BIGINT       REFERENCES users(id),
    uploaded_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    change_notes    TEXT
);

-- ================================================================
-- MODULE 7: RECRUITMENT PIPELINE
-- ================================================================

CREATE TABLE rec_job_postings (
    id                  BIGSERIAL    PRIMARY KEY,
    company_id          BIGINT       NOT NULL REFERENCES companies(id),
    position_id         BIGINT       REFERENCES positions(id),
    department_id       BIGINT       REFERENCES departments(id),
    title               VARCHAR(200) NOT NULL,
    description         TEXT,
    requirements        TEXT,
    headcount           INTEGER      NOT NULL DEFAULT 1,
    employment_type_id  BIGINT       REFERENCES employment_types(id),
    salary_min          NUMERIC(14,2),
    salary_max          NUMERIC(14,2),
    posted_date         DATE,
    closing_date        DATE,
    status              VARCHAR(20)  NOT NULL DEFAULT 'DRAFT',
    -- DRAFT | OPEN | ON_HOLD | CLOSED | CANCELLED
    posted_by           BIGINT       REFERENCES users(id),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE rec_applicants (
    id                  BIGSERIAL    PRIMARY KEY,
    posting_id          BIGINT       NOT NULL REFERENCES rec_job_postings(id),
    first_name          VARCHAR(100) NOT NULL,
    last_name           VARCHAR(100) NOT NULL,
    email               VARCHAR(200),
    mobile_no           VARCHAR(20),
    current_position    VARCHAR(200),
    current_company     VARCHAR(200),
    expected_salary     NUMERIC(14,2),
    resume_path         TEXT,
    source              VARCHAR(50),
    -- REFERRAL | JOBSTREET | LINKEDIN | JOBSDB | WALK_IN | AGENCY
    stage               VARCHAR(30)  NOT NULL DEFAULT 'APPLIED',
    -- APPLIED | SCREENING | INITIAL_INTERVIEW | FINAL_INTERVIEW | EXAM | OFFER | HIRED | REJECTED | WITHDRAWN
    hired_as_employee_id BIGINT      REFERENCES employees(id),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE rec_application_history (
    id              BIGSERIAL    PRIMARY KEY,
    applicant_id    BIGINT       NOT NULL REFERENCES rec_applicants(id),
    from_stage      VARCHAR(30),
    to_stage        VARCHAR(30)  NOT NULL,
    remarks         TEXT,
    changed_by      BIGINT       REFERENCES users(id),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ================================================================
-- MODULE 8: TRAINING & DEVELOPMENT
-- ================================================================

CREATE TABLE trn_programs (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES companies(id),
    code            VARCHAR(30)  NOT NULL,
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    category        VARCHAR(50),
    -- TECHNICAL | SOFT_SKILLS | COMPLIANCE | LEADERSHIP | SAFETY | PRODUCT
    provider        VARCHAR(200),
    duration_hours  NUMERIC(5,1),
    is_mandatory    BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, code)
);

CREATE TABLE trn_sessions (
    id              BIGSERIAL    PRIMARY KEY,
    program_id      BIGINT       NOT NULL REFERENCES trn_programs(id),
    session_code    VARCHAR(30)  NOT NULL,
    facilitator     VARCHAR(200),
    venue           VARCHAR(200),
    mode            VARCHAR(20)  NOT NULL DEFAULT 'IN_PERSON',
    -- IN_PERSON | ONLINE | BLENDED
    date_from       DATE         NOT NULL,
    date_to         DATE         NOT NULL,
    max_participants INTEGER,
    status          VARCHAR(20)  NOT NULL DEFAULT 'SCHEDULED',
    -- SCHEDULED | ONGOING | COMPLETED | CANCELLED
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (program_id, session_code)
);

CREATE TABLE trn_enrollments (
    id                  BIGSERIAL    PRIMARY KEY,
    session_id          BIGINT       NOT NULL REFERENCES trn_sessions(id),
    employee_id         BIGINT       NOT NULL REFERENCES employees(id),
    status              VARCHAR(20)  NOT NULL DEFAULT 'ENROLLED',
    -- ENROLLED | ATTENDED | COMPLETED | DROPPED | NO_SHOW
    pre_eval_score      NUMERIC(5,2),
    post_eval_score     NUMERIC(5,2),
    passed              BOOLEAN,
    certificate_path    TEXT,
    completed_at        DATE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (session_id, employee_id)
);

CREATE TABLE trn_employee_history (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES employees(id),
    program_name    VARCHAR(200) NOT NULL,
    provider        VARCHAR(200),
    date_completed  DATE,
    hours           NUMERIC(5,1),
    certificate_path TEXT,
    is_external     BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ================================================================
-- MODULE 9: NOTIFICATIONS & ALERTS
-- ================================================================

CREATE TABLE ntf_templates (
    id              BIGSERIAL    PRIMARY KEY,
    code            VARCHAR(50)  NOT NULL UNIQUE,
    name            VARCHAR(200) NOT NULL,
    channel         VARCHAR(20)  NOT NULL,  -- EMAIL | SMS | IN_APP | PUSH
    subject         VARCHAR(300),
    body_template   TEXT         NOT NULL,  -- {{variable}} placeholders
    trigger_event   VARCHAR(100),
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Partitioned notifications table
CREATE TABLE ntf_notifications (
    id                      BIGSERIAL    NOT NULL,
    template_id             BIGINT       REFERENCES ntf_templates(id),
    recipient_user_id       BIGINT       REFERENCES users(id),
    recipient_employee_id   BIGINT       REFERENCES employees(id),
    channel                 VARCHAR(20)  NOT NULL,
    subject                 VARCHAR(300),
    body                    TEXT         NOT NULL,
    reference_type          VARCHAR(50),
    reference_id            BIGINT,
    status                  VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    -- PENDING | SENT | FAILED | READ
    sent_at                 TIMESTAMPTZ,
    read_at                 TIMESTAMPTZ,
    error_message           TEXT,
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE ntf_notifications_2025 PARTITION OF ntf_notifications FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE ntf_notifications_2026 PARTITION OF ntf_notifications FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE ntf_notifications_2027 PARTITION OF ntf_notifications FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
CREATE TABLE ntf_notifications_2028 PARTITION OF ntf_notifications FOR VALUES FROM ('2028-01-01') TO ('2029-01-01');

-- ================================================================
-- MODULE 10: COMPLIANCE & REGULATORY
-- ================================================================

CREATE TABLE sys_compliance_reports (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES companies(id),
    report_type     VARCHAR(50)  NOT NULL,
    -- SSS_R3 | PHILHEALTH_RF1 | PAGIBIG_MCF | BIR_2316 | BIR_ALPHALIST | DOLE
    period_from     DATE,
    period_to       DATE,
    file_path       TEXT,
    status          VARCHAR(20)  NOT NULL DEFAULT 'GENERATED',
    generated_by    BIGINT       REFERENCES users(id),
    generated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE sys_regulatory_deadlines (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES companies(id),
    agency          VARCHAR(50)  NOT NULL,  -- SSS | PHILHEALTH | PAGIBIG | BIR | DOLE
    requirement     VARCHAR(200) NOT NULL,
    deadline_date   DATE         NOT NULL,
    frequency       VARCHAR(20)  NOT NULL DEFAULT 'MONTHLY',
    status          VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    -- PENDING | FILED | LATE | WAIVED
    filed_at        TIMESTAMPTZ,
    filed_by        BIGINT       REFERENCES users(id),
    notes           TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ================================================================
-- MODULE 11: SYSTEM INTEGRATION & SYNC
-- ================================================================

CREATE TABLE sys_integrations (
    id                  BIGSERIAL    PRIMARY KEY,
    code                VARCHAR(50)  NOT NULL UNIQUE,
    name                VARCHAR(200) NOT NULL,
    integration_type    VARCHAR(50)  NOT NULL,
    -- BIOMETRIC | PAYROLL_BANK | ERP | GOVT_PORTAL | LMS | ATS
    endpoint_url        VARCHAR(500),
    auth_type           VARCHAR(30),  -- API_KEY | OAUTH2 | BASIC | CERT
    config              JSONB        NOT NULL DEFAULT '{}',
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    last_sync_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE sys_sync_logs (
    id                  BIGSERIAL    PRIMARY KEY,
    integration_id      BIGINT       NOT NULL REFERENCES sys_integrations(id),
    sync_type           VARCHAR(50)  NOT NULL,
    status              VARCHAR(20)  NOT NULL,  -- SUCCESS | FAILED | PARTIAL
    records_processed   INTEGER      NOT NULL DEFAULT 0,
    records_success     INTEGER      NOT NULL DEFAULT 0,
    records_failed      INTEGER      NOT NULL DEFAULT 0,
    error_summary       TEXT,
    started_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    completed_at        TIMESTAMPTZ
);

-- Partitioned system-wide audit log
CREATE TABLE sys_audit_logs (
    id              BIGSERIAL    NOT NULL,
    company_id      BIGINT       REFERENCES companies(id),
    user_id         BIGINT       REFERENCES users(id),
    employee_id     BIGINT       REFERENCES employees(id),
    module          VARCHAR(50)  NOT NULL,
    action          VARCHAR(50)  NOT NULL,
    -- CREATE | UPDATE | DELETE | LOGIN | LOGOUT | EXPORT | APPROVE | REJECT
    resource_type   VARCHAR(100),
    resource_id     BIGINT,
    old_values      JSONB,
    new_values      JSONB,
    ip_address      INET,
    user_agent      TEXT,
    session_id      VARCHAR(100),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE sys_audit_logs_2025 PARTITION OF sys_audit_logs FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE sys_audit_logs_2026 PARTITION OF sys_audit_logs FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE sys_audit_logs_2027 PARTITION OF sys_audit_logs FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
CREATE TABLE sys_audit_logs_2028 PARTITION OF sys_audit_logs FOR VALUES FROM ('2028-01-01') TO ('2029-01-01');

-- ================================================================
-- DEFERRED FOREIGN KEYS (circular references resolved)
-- ================================================================

ALTER TABLE business_units
    ADD CONSTRAINT fk_bu_head
    FOREIGN KEY (head_employee_id) REFERENCES employees(id) DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE departments
    ADD CONSTRAINT fk_dept_head
    FOREIGN KEY (head_employee_id) REFERENCES employees(id) DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE users
    ADD CONSTRAINT fk_user_employee
    FOREIGN KEY (employee_id) REFERENCES employees(id) DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE att_daily
    ADD CONSTRAINT fk_att_daily_leave
    FOREIGN KEY (leave_request_id) REFERENCES lv_requests(id) DEFERRABLE INITIALLY DEFERRED;

-- ================================================================
-- INDEXES
-- ================================================================

-- Companies
CREATE INDEX idx_companies_code ON companies(code);

-- Employees (most queried table)
CREATE INDEX idx_emp_company        ON employees(company_id);
CREATE INDEX idx_emp_department     ON employees(department_id);
CREATE INDEX idx_emp_position       ON employees(position_id);
CREATE INDEX idx_emp_supervisor     ON employees(immediate_supervisor_id);
CREATE INDEX idx_emp_status         ON employees(status) WHERE is_active = TRUE;
CREATE INDEX idx_emp_date_hired     ON employees(date_hired);
CREATE INDEX idx_emp_uuid           ON employees(uuid);
CREATE INDEX idx_emp_fulltext       ON employees USING GIN
    (to_tsvector('simple', unaccent(last_name || ' ' || first_name)));

-- Government IDs (lookups by ID number)
CREATE INDEX idx_govt_id_number     ON emp_government_ids(id_number);

-- Attendance
CREATE INDEX idx_att_daily_emp      ON att_daily(employee_id);
CREATE INDEX idx_att_daily_date     ON att_daily(work_date);
CREATE INDEX idx_att_daily_emp_date ON att_daily(employee_id, work_date);
CREATE INDEX idx_att_daily_status   ON att_daily(status, work_date);

-- Leave
CREATE INDEX idx_lv_req_employee    ON lv_requests(employee_id);
CREATE INDEX idx_lv_req_status      ON lv_requests(status);
CREATE INDEX idx_lv_req_dates       ON lv_requests(date_from, date_to);
CREATE INDEX idx_lv_bal_emp_year    ON lv_balances(employee_id, year);

-- Payroll
CREATE INDEX idx_pay_payroll_run    ON pay_employee_payroll(run_id);
CREATE INDEX idx_pay_payroll_emp    ON pay_employee_payroll(employee_id);
CREATE INDEX idx_pay_period_company ON pay_periods(company_id, date_from, date_to);

-- Performance
CREATE INDEX idx_perf_review_emp    ON perf_reviews(employee_id);
CREATE INDEX idx_perf_review_cycle  ON perf_reviews(cycle_id);

-- Documents
CREATE INDEX idx_doc_files_emp      ON doc_employee_files(employee_id);
CREATE INDEX idx_doc_files_expiry   ON doc_employee_files(expiry_date)
    WHERE expiry_date IS NOT NULL;

-- Notifications
CREATE INDEX idx_ntf_recipient_status ON ntf_notifications(recipient_user_id, status);

-- Audit
CREATE INDEX idx_audit_company      ON sys_audit_logs(company_id, created_at);
CREATE INDEX idx_audit_user         ON sys_audit_logs(user_id, created_at);
CREATE INDEX idx_audit_resource     ON sys_audit_logs(resource_type, resource_id);

-- ================================================================
-- REFERENCE DATA SEEDS
-- ================================================================

INSERT INTO employment_types (code, name, description, is_entitled_benefits, probation_days) VALUES
    ('REGULAR',       'Regular',           'Permanent employee — full benefits',    TRUE,  0),
    ('PROBATIONARY',  'Probationary',      '6-month probationary period',           TRUE,  180),
    ('CONTRACTUAL',   'Contractual',       'Fixed-term contract, project-based',    FALSE, 0),
    ('PART_TIME',     'Part-time',         'Works less than standard weekly hours', FALSE, 0),
    ('SEASONAL',      'Seasonal',          'Peak-season hire',                      FALSE, 0),
    ('OJT',           'OJT / Intern',      'Student trainee — on-the-job training', FALSE, 0),
    ('CONSULTANT',    'Consultant',        'Independent contractor / consultant',   FALSE, 0);

INSERT INTO att_holiday_types (code, name, pay_multiplier) VALUES
    ('REGULAR',            'Regular Holiday',            2.00),
    ('SPECIAL_NON_WORKING','Special Non-Working Holiday',1.30),
    ('SPECIAL_WORKING',    'Special Working Holiday',    1.00);

INSERT INTO doc_categories (code, name, requires_expiry, is_confidential) VALUES
    ('CONTRACT',     'Employment Contract',      TRUE,  FALSE),
    ('GOVT_ID',      'Government ID',            TRUE,  FALSE),
    ('SSS',          'SSS Documents',            FALSE, FALSE),
    ('TIN',          'TIN / BIR Documents',      FALSE, FALSE),
    ('PHILHEALTH',   'PhilHealth Documents',     FALSE, FALSE),
    ('PAGIBIG',      'Pag-IBIG Documents',       FALSE, FALSE),
    ('CERTIFICATE',  'Certifications & Awards',  TRUE,  FALSE),
    ('DIPLOMA',      'Educational Documents',    FALSE, FALSE),
    ('MEDICAL',      'Medical Records',          TRUE,  TRUE),
    ('NBI',          'NBI Clearance',            TRUE,  FALSE),
    ('POLICE',       'Police Clearance',         TRUE,  FALSE),
    ('BARANGAY',     'Barangay Clearance',       TRUE,  FALSE),
    ('MEMO',         'Memorandums & Notices',    FALSE, FALSE),
    ('PAYSLIP',      'Payslips',                 FALSE, TRUE),
    ('OTHERS',       'Other Documents',          FALSE, FALSE);

INSERT INTO ntf_templates (code, name, channel, subject, body_template, trigger_event) VALUES
    ('LEAVE_APPROVED',    'Leave Approved',        'IN_APP',
     'Your Leave Request has been Approved',
     'Your {{leave_type}} leave from {{date_from}} to {{date_to}} has been approved by {{approver_name}}.',
     'LEAVE_APPROVED'),
    ('LEAVE_REJECTED',    'Leave Rejected',        'IN_APP',
     'Your Leave Request has been Rejected',
     'Your {{leave_type}} leave from {{date_from}} to {{date_to}} was rejected. Reason: {{reason}}',
     'LEAVE_REJECTED'),
    ('PAYSLIP_RELEASED',  'Payslip Available',     'IN_APP',
     'Payslip for {{period}} is now available',
     'Your payslip for {{period}} has been released. Net pay: {{net_pay}}.',
     'PAYSLIP_RELEASED'),
    ('CONTRACT_EXPIRY',   'Contract Expiry Notice','IN_APP',
     'Your contract is expiring soon',
     'Your employment contract expires on {{expiry_date}}. Coordinate with HR for renewal.',
     'CONTRACT_EXPIRY'),
    ('DOC_EXPIRY',        'Document Expiry Alert', 'IN_APP',
     'Document Expiry: {{document_name}}',
     '{{document_name}} expires on {{expiry_date}}. Please upload the renewed document.',
     'DOC_EXPIRY'),
    ('BIRTHDAY',          'Birthday Greeting',     'IN_APP',
     'Happy Birthday, {{first_name}}!',
     'Wishing you a wonderful birthday! From everyone at {{company_name}}.',
     'BIRTHDAY'),
    ('OT_APPROVED',       'OT Request Approved',   'IN_APP',
     'Overtime Request Approved',
     'Your overtime request on {{request_date}} for {{hours}} hours has been approved.',
     'OT_APPROVED'),
    ('REGULARIZATION_DUE','Regularization Due',    'IN_APP',
     'Regularization Date Approaching',
     '{{employee_name}} probation ends on {{probation_end_date}}. Please initiate the regularization process.',
     'REGULARIZATION_DUE');

-- PH National Holidays 2026
-- (extend each year; is_recurring=TRUE for fixed-date holidays)
INSERT INTO att_holidays (company_id, holiday_type_id, holiday_date, name, is_recurring)
SELECT
    c.id,
    (SELECT id FROM att_holiday_types WHERE code = 'REGULAR'),
    dates.d,
    dates.n,
    TRUE
FROM companies c,
(VALUES
    ('2026-01-01'::date, 'New Year''s Day'),
    ('2026-04-02'::date, 'Maundy Thursday'),
    ('2026-04-03'::date, 'Good Friday'),
    ('2026-04-09'::date, 'Araw ng Kagitingan'),
    ('2026-05-01'::date, 'Labor Day'),
    ('2026-06-12'::date, 'Independence Day'),
    ('2026-08-31'::date, 'National Heroes Day'),
    ('2026-11-30'::date, 'Bonifacio Day'),
    ('2026-12-25'::date, 'Christmas Day'),
    ('2026-12-30'::date, 'Rizal Day')
) AS dates(d, n)
ON CONFLICT DO NOTHING;

-- ================================================================
-- REPORTING VIEWS
-- ================================================================

CREATE VIEW v_active_employees AS
SELECT
    e.id,
    e.uuid,
    e.employee_no,
    e.last_name || ', ' || e.first_name
        || COALESCE(' ' || e.middle_name, '') AS full_name,
    e.first_name,
    e.last_name,
    e.work_email,
    e.mobile_no,
    e.status,
    e.work_arrangement,
    e.date_hired,
    e.date_regularized,
    e.basic_salary,
    d.name  AS department,
    p.title AS position,
    jg.name AS job_grade,
    et.name AS employment_type,
    c.name  AS company_name,
    COALESCE(s.last_name || ', ' || s.first_name, '') AS supervisor_name
FROM employees e
LEFT JOIN departments    d  ON e.department_id     = d.id
LEFT JOIN positions      p  ON e.position_id       = p.id
LEFT JOIN job_grades     jg ON e.job_grade_id      = jg.id
LEFT JOIN employment_types et ON e.employment_type_id = et.id
LEFT JOIN companies      c  ON e.company_id        = c.id
LEFT JOIN employees      s  ON e.immediate_supervisor_id = s.id
WHERE e.is_active = TRUE AND e.status NOT IN ('RESIGNED','TERMINATED','RETIRED','DECEASED');

CREATE VIEW v_leave_balances AS
SELECT
    lb.employee_id,
    e.employee_no,
    e.last_name || ', ' || e.first_name AS full_name,
    lt.code  AS leave_code,
    lt.name  AS leave_type,
    lb.year,
    lb.entitled_days,
    lb.accrued_days,
    lb.used_days,
    lb.pending_days,
    lb.carried_over,
    lb.balance
FROM lv_balances lb
JOIN employees e ON lb.employee_id   = e.id
JOIN lv_types lt ON lb.leave_type_id = lt.id;

CREATE VIEW v_monthly_attendance AS
SELECT
    ad.employee_id,
    e.employee_no,
    e.last_name || ', ' || e.first_name AS full_name,
    DATE_TRUNC('month', ad.work_date)   AS month,
    COUNT(*)  FILTER (WHERE ad.status = 'PRESENT')  AS days_present,
    COUNT(*)  FILTER (WHERE ad.status = 'ABSENT')   AS days_absent,
    COUNT(*)  FILTER (WHERE ad.status = 'LATE')     AS days_late,
    COUNT(*)  FILTER (WHERE ad.status = 'HALF_DAY') AS days_half,
    COUNT(*)  FILTER (WHERE ad.status = 'ON_LEAVE') AS days_on_leave,
    SUM(ad.hours_worked)   AS total_hours_worked,
    SUM(ad.hours_overtime) AS total_ot_hours,
    SUM(ad.hours_late)     AS total_late_hours
FROM att_daily ad
JOIN employees e ON ad.employee_id = e.id
GROUP BY ad.employee_id, e.employee_no, e.last_name, e.first_name,
         DATE_TRUNC('month', ad.work_date);

CREATE VIEW v_payroll_summary AS
SELECT
    pr.id           AS run_id,
    pp.period_code,
    pp.date_from,
    pp.date_to,
    pp.payment_date,
    pr.status,
    pr.total_employees,
    pr.total_gross,
    pr.total_deductions,
    pr.total_net,
    c.name          AS company_name
FROM pay_runs pr
JOIN pay_periods pp ON pr.period_id    = pp.id
JOIN companies   c  ON pp.company_id   = c.id;

CREATE VIEW v_document_expiry_alerts AS
SELECT
    df.id           AS document_id,
    e.employee_no,
    e.last_name || ', ' || e.first_name AS full_name,
    d.name          AS department,
    dc.name         AS document_category,
    df.document_name,
    df.expiry_date,
    (df.expiry_date - CURRENT_DATE) AS days_until_expiry
FROM doc_employee_files df
JOIN employees   e  ON df.employee_id  = e.id
JOIN departments d  ON e.department_id = d.id
JOIN doc_categories dc ON df.category_id = dc.id
WHERE df.expiry_date IS NOT NULL
  AND df.is_current  = TRUE
  AND df.expiry_date >= CURRENT_DATE
ORDER BY df.expiry_date;

CREATE VIEW v_headcount_by_department AS
SELECT
    d.name          AS department,
    et.name         AS employment_type,
    e.status,
    COUNT(*)        AS headcount
FROM employees e
JOIN departments     d  ON e.department_id     = d.id
JOIN employment_types et ON e.employment_type_id = et.id
WHERE e.is_active = TRUE
GROUP BY d.name, et.name, e.status
ORDER BY d.name, et.name;
