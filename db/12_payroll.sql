-- ================================================================
-- HCM360 HRIS — 12: PAYROLL SCHEMA
-- Schema    : payroll
-- Contains  : periods, runs, employee payroll, allowances,
--             loans, 13th month, government remittances, tax tables
-- ================================================================

SET search_path TO payroll, core, public;

CREATE TABLE payroll.pay_periods (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES core.companies(id),
    period_code     VARCHAR(30)  NOT NULL,
    period_type     VARCHAR(20)  NOT NULL DEFAULT 'SEMI_MONTHLY',
    date_from       DATE         NOT NULL,
    date_to         DATE         NOT NULL,
    payment_date    DATE,
    status          VARCHAR(20)  NOT NULL DEFAULT 'OPEN',
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, period_code)
);

CREATE TABLE payroll.pay_runs (
    id                BIGSERIAL    PRIMARY KEY,
    period_id         BIGINT       NOT NULL REFERENCES payroll.pay_periods(id),
    run_number        INTEGER      NOT NULL DEFAULT 1,
    status            VARCHAR(20)  NOT NULL DEFAULT 'DRAFT',
    total_employees   INTEGER      NOT NULL DEFAULT 0,
    total_gross       NUMERIC(16,2) NOT NULL DEFAULT 0,
    total_deductions  NUMERIC(16,2) NOT NULL DEFAULT 0,
    total_net         NUMERIC(16,2) NOT NULL DEFAULT 0,
    workflow_instance_id BIGINT,
    computed_at       TIMESTAMPTZ,
    computed_by       BIGINT       REFERENCES core.users(id),
    approved_at       TIMESTAMPTZ,
    approved_by       BIGINT       REFERENCES core.users(id),
    posted_at         TIMESTAMPTZ,
    posted_by         BIGINT       REFERENCES core.users(id),
    remarks           TEXT,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (period_id, run_number)
);

CREATE INDEX idx_pay_runs_status ON payroll.pay_runs(status);

CREATE TABLE payroll.pay_employee_payroll (
    id                  BIGSERIAL    PRIMARY KEY,
    run_id              BIGINT       NOT NULL REFERENCES payroll.pay_runs(id),
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id),
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
    basic_pay           NUMERIC(14,2) NOT NULL DEFAULT 0,
    ot_pay              NUMERIC(14,2) NOT NULL DEFAULT 0,
    holiday_pay         NUMERIC(14,2) NOT NULL DEFAULT 0,
    night_diff_pay      NUMERIC(14,2) NOT NULL DEFAULT 0,
    allowances_total    NUMERIC(14,2) NOT NULL DEFAULT 0,
    other_earnings      NUMERIC(14,2) NOT NULL DEFAULT 0,
    gross_pay           NUMERIC(14,2) NOT NULL DEFAULT 0,
    sss_ee              NUMERIC(10,2) NOT NULL DEFAULT 0,
    philhealth_ee       NUMERIC(10,2) NOT NULL DEFAULT 0,
    pagibig_ee          NUMERIC(10,2) NOT NULL DEFAULT 0,
    tax_withheld        NUMERIC(12,2) NOT NULL DEFAULT 0,
    loan_deductions     NUMERIC(12,2) NOT NULL DEFAULT 0,
    other_deductions    NUMERIC(12,2) NOT NULL DEFAULT 0,
    total_deductions    NUMERIC(14,2) NOT NULL DEFAULT 0,
    net_pay             NUMERIC(14,2) NOT NULL DEFAULT 0,
    payslip_generated   BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (run_id, employee_id)
);

CREATE INDEX idx_payslip_emp ON payroll.pay_employee_payroll(employee_id, run_id);

CREATE TABLE payroll.pay_employee_allowances (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    allowance_type  VARCHAR(60)  NOT NULL,
    amount          NUMERIC(12,2) NOT NULL,
    is_taxable      BOOLEAN      NOT NULL DEFAULT FALSE,
    effective_from  DATE         NOT NULL,
    effective_to    DATE,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── Loans ─────────────────────────────────────────────────────────

CREATE TABLE payroll.pay_loans (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id),
    loan_type           VARCHAR(50)  NOT NULL,
    reference_no        VARCHAR(40)  UNIQUE NOT NULL,
    principal_amount    NUMERIC(14,2) NOT NULL,
    outstanding_balance NUMERIC(14,2) NOT NULL,
    monthly_deduction   NUMERIC(12,2) NOT NULL,
    interest_rate       NUMERIC(5,4)  NOT NULL DEFAULT 0,
    total_months        INTEGER      NOT NULL,
    months_paid         INTEGER      NOT NULL DEFAULT 0,
    start_date          DATE         NOT NULL,
    end_date            DATE,
    status              VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',
    workflow_instance_id BIGINT,
    approved_by         BIGINT       REFERENCES core.users(id),
    approved_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_loans_emp    ON payroll.pay_loans(employee_id, status);

CREATE TABLE payroll.pay_loan_payments (
    id              BIGSERIAL    PRIMARY KEY,
    loan_id         BIGINT       NOT NULL REFERENCES payroll.pay_loans(id),
    run_id          BIGINT       REFERENCES payroll.pay_runs(id),
    payment_date    DATE         NOT NULL,
    amount          NUMERIC(12,2) NOT NULL,
    principal_paid  NUMERIC(12,2) NOT NULL DEFAULT 0,
    interest_paid   NUMERIC(12,2) NOT NULL DEFAULT 0,
    balance_after   NUMERIC(14,2) NOT NULL,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── 13th Month ────────────────────────────────────────────────────

CREATE TABLE payroll.pay_13th_month (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    year            INTEGER      NOT NULL,
    total_basic_pay NUMERIC(14,2) NOT NULL DEFAULT 0,
    months_worked   NUMERIC(4,2) NOT NULL DEFAULT 12,
    gross_13th      NUMERIC(14,2) NOT NULL DEFAULT 0,
    tax_exempt_amt  NUMERIC(14,2) NOT NULL DEFAULT 90000,
    taxable_amt     NUMERIC(14,2) NOT NULL DEFAULT 0,
    net_13th        NUMERIC(14,2) NOT NULL DEFAULT 0,
    paid_at         TIMESTAMPTZ,
    run_id          BIGINT       REFERENCES payroll.pay_runs(id),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (employee_id, year)
);

-- ── Government Remittances ────────────────────────────────────────

CREATE TABLE payroll.pay_government_remittances (
    id              BIGSERIAL    PRIMARY KEY,
    run_id          BIGINT       NOT NULL REFERENCES payroll.pay_runs(id),
    agency          VARCHAR(20)  NOT NULL,
    remittance_date DATE,
    total_ee        NUMERIC(14,2) NOT NULL DEFAULT 0,
    total_er        NUMERIC(14,2) NOT NULL DEFAULT 0,
    total_amount    NUMERIC(14,2) NOT NULL DEFAULT 0,
    file_path       TEXT,
    status          VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    submitted_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (run_id, agency)
);

-- ── Withholding Tax Tables ────────────────────────────────────────

CREATE TABLE payroll.pay_tax_tables (
    id              BIGSERIAL    PRIMARY KEY,
    effective_year  INTEGER      NOT NULL,
    frequency       VARCHAR(20)  NOT NULL DEFAULT 'SEMI_MONTHLY',
    bracket_from    NUMERIC(14,2) NOT NULL,
    bracket_to      NUMERIC(14,2),
    base_tax        NUMERIC(12,2) NOT NULL DEFAULT 0,
    tax_rate        NUMERIC(5,4)  NOT NULL DEFAULT 0,
    excess_over     NUMERIC(14,2) NOT NULL DEFAULT 0
);
