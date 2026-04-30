-- ================================================================
-- HCM360 HRIS — 06: LEAVE MANAGEMENT SCHEMA
-- Schema    : leave_mgmt
-- Contains  : leave types (PH statutory + company), policies,
--             balances, requests, approvals, ledger,
--             travel orders, daily locator, CTO credits
-- ================================================================

SET search_path TO leave_mgmt, core, public;

CREATE TABLE leave_mgmt.lv_types (
    id                    BIGSERIAL    PRIMARY KEY,
    company_id            BIGINT       NOT NULL REFERENCES core.companies(id),
    code                  VARCHAR(30)  NOT NULL,
    name                  VARCHAR(100) NOT NULL,
    category              VARCHAR(30)  NOT NULL DEFAULT 'COMPANY',
    legal_basis           VARCHAR(100),
    color                 VARCHAR(20)  NOT NULL DEFAULT '#3b82f6',
    icon                  VARCHAR(20)  NOT NULL DEFAULT '📅',
    description           TEXT,
    is_paid               BOOLEAN      NOT NULL DEFAULT TRUE,
    requires_document     BOOLEAN      NOT NULL DEFAULT FALSE,
    min_days              NUMERIC(4,1) NOT NULL DEFAULT 1,
    max_days_per_filing   NUMERIC(4,1),
    notice_days_required  INTEGER      NOT NULL DEFAULT 0,
    gender_restriction    VARCHAR(10),
    is_active             BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, code)
);

CREATE TABLE leave_mgmt.lv_policies (
    id                     BIGSERIAL    PRIMARY KEY,
    company_id             BIGINT       NOT NULL REFERENCES core.companies(id),
    leave_type_id          BIGINT       NOT NULL REFERENCES leave_mgmt.lv_types(id),
    employment_type_id     BIGINT       REFERENCES core.employment_types(id),
    annual_days            NUMERIC(5,1) NOT NULL,
    accrual_type           VARCHAR(20)  NOT NULL DEFAULT 'ANNUAL',
    carry_over_allowed     BOOLEAN      NOT NULL DEFAULT FALSE,
    carry_over_max_days    NUMERIC(5,1) NOT NULL DEFAULT 0,
    monetization_allowed   BOOLEAN      NOT NULL DEFAULT FALSE,
    months_before_entitled INTEGER      NOT NULL DEFAULT 0,
    effective_from         DATE,
    effective_to           DATE,
    created_at             TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE leave_mgmt.lv_balances (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    leave_type_id   BIGINT       NOT NULL REFERENCES leave_mgmt.lv_types(id),
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

CREATE INDEX idx_lv_bal_emp  ON leave_mgmt.lv_balances(employee_id, year);

CREATE TABLE leave_mgmt.lv_requests (
    id                BIGSERIAL    PRIMARY KEY,
    reference_no      VARCHAR(40)  UNIQUE NOT NULL,
    employee_id       BIGINT       NOT NULL REFERENCES core.employees(id),
    leave_type_id     BIGINT       NOT NULL REFERENCES leave_mgmt.lv_types(id),
    date_from         DATE         NOT NULL,
    date_to           DATE         NOT NULL,
    days_requested    NUMERIC(4,1) NOT NULL,
    reason            TEXT,
    status            VARCHAR(30)  NOT NULL DEFAULT 'PENDING',
    is_half_day       BOOLEAN      NOT NULL DEFAULT FALSE,
    half_day_type     VARCHAR(5),
    document_path     TEXT,
    workflow_instance_id BIGINT,
    filed_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    return_date       DATE,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_lv_req_emp    ON leave_mgmt.lv_requests(employee_id, status);
CREATE INDEX idx_lv_req_status ON leave_mgmt.lv_requests(status, date_from);
CREATE INDEX idx_lv_req_dates  ON leave_mgmt.lv_requests(date_from, date_to);

CREATE TABLE leave_mgmt.lv_approvals (
    id              BIGSERIAL    PRIMARY KEY,
    request_id      BIGINT       NOT NULL REFERENCES leave_mgmt.lv_requests(id) ON DELETE CASCADE,
    approval_level  INTEGER      NOT NULL DEFAULT 1,
    approver_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    status          VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    remarks         TEXT,
    acted_at        TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE leave_mgmt.lv_ledger (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id),
    leave_type_id       BIGINT       NOT NULL REFERENCES leave_mgmt.lv_types(id),
    year                INTEGER      NOT NULL,
    transaction_type    VARCHAR(30)  NOT NULL,
    days                NUMERIC(5,1) NOT NULL,
    reference_id        BIGINT,
    reference_type      VARCHAR(30),
    remarks             TEXT,
    created_by          BIGINT       REFERENCES core.users(id),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── Philippine Public Holidays ────────────────────────────────────

CREATE TABLE leave_mgmt.lv_holidays (
    id          BIGSERIAL    PRIMARY KEY,
    company_id  BIGINT       REFERENCES core.companies(id),
    hdate       DATE         NOT NULL,
    name        VARCHAR(100) NOT NULL,
    htype       VARCHAR(30)  NOT NULL DEFAULT 'REGULAR',
    is_recurring BOOLEAN     NOT NULL DEFAULT FALSE,
    month_day   VARCHAR(6),
    UNIQUE (company_id, hdate, name)
);

-- ── Travel Orders ─────────────────────────────────────────────────

CREATE TABLE leave_mgmt.lv_travel_orders (
    id                    BIGSERIAL    PRIMARY KEY,
    reference_no          VARCHAR(40)  UNIQUE NOT NULL,
    employee_id           BIGINT       NOT NULL REFERENCES core.employees(id),
    destination           VARCHAR(300) NOT NULL,
    purpose               TEXT         NOT NULL,
    date_from             DATE         NOT NULL,
    date_to               DATE         NOT NULL,
    transport_mode        VARCHAR(50),
    estimated_expense     NUMERIC(12,2),
    workflow_instance_id  BIGINT,
    status                VARCHAR(30)  NOT NULL DEFAULT 'DRAFT',
    approved_by           BIGINT       REFERENCES core.users(id),
    approved_at           TIMESTAMPTZ,
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_to_emp    ON leave_mgmt.lv_travel_orders(employee_id, status);
CREATE INDEX idx_to_dates  ON leave_mgmt.lv_travel_orders(date_from, date_to);

-- ── Daily Locator Board ───────────────────────────────────────────

CREATE TABLE leave_mgmt.lv_locator_entries (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    log_date        DATE         NOT NULL DEFAULT CURRENT_DATE,
    location_type   VARCHAR(30)  NOT NULL DEFAULT 'IN_OFFICE',
    departure_time  TIME,
    return_time     TIME,
    destination     VARCHAR(300),
    purpose         TEXT,
    contact_no      VARCHAR(30),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (employee_id, log_date)
);

CREATE INDEX idx_locator_date ON leave_mgmt.lv_locator_entries(log_date, location_type);

-- ── Compensatory Time Off (CTO) Credits ──────────────────────────

CREATE TABLE leave_mgmt.lv_cto_credits (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    credit_type     VARCHAR(30)  NOT NULL DEFAULT 'EARNED',
    reference_date  DATE         NOT NULL,
    hours_credit    NUMERIC(5,2) NOT NULL DEFAULT 0,
    reason          TEXT,
    approved_by     BIGINT       REFERENCES core.users(id),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_cto_emp ON leave_mgmt.lv_cto_credits(employee_id, reference_date);
