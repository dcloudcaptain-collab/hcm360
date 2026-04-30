-- ================================================================
-- HCM360 HRIS — 13: ANALYTICS SCHEMA
-- Schema    : analytics
-- Contains  : dimension tables, fact tables (derived from
--             transactional schemas), KPI snapshots
-- NOTE: Analytics tables are read-only from modules.
--       They are refreshed by scheduled ETL queries.
-- ================================================================

SET search_path TO analytics, core, public;

-- ── Dimension: Date ───────────────────────────────────────────────

CREATE TABLE analytics.dim_date (
    date_key        INTEGER      PRIMARY KEY,  -- YYYYMMDD
    full_date       DATE         NOT NULL UNIQUE,
    day_of_week     SMALLINT     NOT NULL,
    day_name        VARCHAR(10)  NOT NULL,
    day_of_month    SMALLINT     NOT NULL,
    day_of_year     SMALLINT     NOT NULL,
    week_of_year    SMALLINT     NOT NULL,
    month_number    SMALLINT     NOT NULL,
    month_name      VARCHAR(15)  NOT NULL,
    month_short     VARCHAR(5)   NOT NULL,
    quarter         SMALLINT     NOT NULL,
    year            SMALLINT     NOT NULL,
    is_weekend      BOOLEAN      NOT NULL DEFAULT FALSE,
    is_holiday      BOOLEAN      NOT NULL DEFAULT FALSE,
    holiday_name    VARCHAR(100),
    fiscal_year     SMALLINT,
    fiscal_quarter  SMALLINT
);

-- Populate dim_date for 2024-2028
INSERT INTO analytics.dim_date
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INTEGER                     AS date_key,
    d                                                    AS full_date,
    EXTRACT(DOW FROM d)::SMALLINT                        AS day_of_week,
    TO_CHAR(d, 'Day')                                    AS day_name,
    EXTRACT(DAY FROM d)::SMALLINT                        AS day_of_month,
    EXTRACT(DOY FROM d)::SMALLINT                        AS day_of_year,
    EXTRACT(WEEK FROM d)::SMALLINT                       AS week_of_year,
    EXTRACT(MONTH FROM d)::SMALLINT                      AS month_number,
    TO_CHAR(d, 'Month')                                  AS month_name,
    TO_CHAR(d, 'Mon')                                    AS month_short,
    EXTRACT(QUARTER FROM d)::SMALLINT                    AS quarter,
    EXTRACT(YEAR FROM d)::SMALLINT                       AS year,
    EXTRACT(DOW FROM d) IN (0, 6)                        AS is_weekend,
    FALSE                                                AS is_holiday,
    NULL                                                 AS holiday_name,
    EXTRACT(YEAR FROM d)::SMALLINT                       AS fiscal_year,
    EXTRACT(QUARTER FROM d)::SMALLINT                    AS fiscal_quarter
FROM generate_series('2024-01-01'::DATE, '2028-12-31'::DATE, '1 day'::INTERVAL) AS d;

-- ── Dimension: Employee ───────────────────────────────────────────

CREATE TABLE analytics.dim_employee (
    surrogate_key       BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id),
    employee_no         VARCHAR(30)  NOT NULL,
    full_name           VARCHAR(250) NOT NULL,
    gender              VARCHAR(20),
    department_id       BIGINT,
    department_name     VARCHAR(200),
    position_id         BIGINT,
    position_title      VARCHAR(200),
    job_grade           VARCHAR(30),
    employment_type     VARCHAR(30),
    work_arrangement    VARCHAR(30),
    date_hired          DATE,
    status              VARCHAR(30),
    tenure_months       INTEGER,
    effective_from      DATE         NOT NULL,
    effective_to        DATE,
    is_current          BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_dim_emp_current ON analytics.dim_employee(employee_id) WHERE is_current;
CREATE INDEX idx_dim_emp_dept ON analytics.dim_employee(department_id, is_current);

-- ── Dimension: Department ─────────────────────────────────────────

CREATE TABLE analytics.dim_department (
    surrogate_key   BIGSERIAL    PRIMARY KEY,
    department_id   BIGINT       NOT NULL REFERENCES core.departments(id),
    code            VARCHAR(20)  NOT NULL,
    name            VARCHAR(200) NOT NULL,
    company_id      BIGINT,
    is_current      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── Dimension: Position ───────────────────────────────────────────

CREATE TABLE analytics.dim_position (
    surrogate_key   BIGSERIAL    PRIMARY KEY,
    position_id     BIGINT       NOT NULL REFERENCES core.positions(id),
    code            VARCHAR(20)  NOT NULL,
    title           VARCHAR(200) NOT NULL,
    is_managerial   BOOLEAN,
    is_current      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── Fact: Attendance ──────────────────────────────────────────────

CREATE TABLE analytics.fact_attendance (
    id                  BIGSERIAL    PRIMARY KEY,
    date_key            INTEGER      NOT NULL REFERENCES analytics.dim_date(date_key),
    employee_key        BIGINT       NOT NULL REFERENCES analytics.dim_employee(surrogate_key),
    department_key      BIGINT       REFERENCES analytics.dim_department(surrogate_key),
    hours_worked        NUMERIC(5,2) NOT NULL DEFAULT 0,
    hours_late          NUMERIC(5,2) NOT NULL DEFAULT 0,
    hours_overtime      NUMERIC(5,2) NOT NULL DEFAULT 0,
    hours_night_diff    NUMERIC(5,2) NOT NULL DEFAULT 0,
    is_present          BOOLEAN      NOT NULL DEFAULT FALSE,
    is_absent           BOOLEAN      NOT NULL DEFAULT FALSE,
    is_on_leave         BOOLEAN      NOT NULL DEFAULT FALSE,
    is_holiday          BOOLEAN      NOT NULL DEFAULT FALSE,
    attendance_status   VARCHAR(20),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (date_key, employee_key)
);

CREATE INDEX idx_fa_date   ON analytics.fact_attendance(date_key, is_present);
CREATE INDEX idx_fa_emp    ON analytics.fact_attendance(employee_key, date_key);
CREATE INDEX idx_fa_dept   ON analytics.fact_attendance(department_key, date_key);

-- ── Fact: Leave ───────────────────────────────────────────────────

CREATE TABLE analytics.fact_leave (
    id                    BIGSERIAL    PRIMARY KEY,
    date_key              INTEGER      REFERENCES analytics.dim_date(date_key),
    employee_key          BIGINT       REFERENCES analytics.dim_employee(surrogate_key),
    leave_request_id      BIGINT,
    leave_type_code       VARCHAR(30),
    leave_type_name       VARCHAR(100),
    days_approved         NUMERIC(4,1),
    days_pending          NUMERIC(4,1),
    approval_cycle_hours  NUMERIC(8,2),
    status                VARCHAR(30),
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (leave_request_id)
);

-- ── Fact: Payroll ─────────────────────────────────────────────────

CREATE TABLE analytics.fact_payroll (
    id                  BIGSERIAL    PRIMARY KEY,
    date_key            INTEGER      REFERENCES analytics.dim_date(date_key),
    employee_key        BIGINT       REFERENCES analytics.dim_employee(surrogate_key),
    department_key      BIGINT       REFERENCES analytics.dim_department(surrogate_key),
    run_id              BIGINT,
    period_code         VARCHAR(20),
    gross_pay           NUMERIC(14,2) NOT NULL DEFAULT 0,
    net_pay             NUMERIC(14,2) NOT NULL DEFAULT 0,
    total_deductions    NUMERIC(14,2) NOT NULL DEFAULT 0,
    tax_withheld        NUMERIC(12,2) NOT NULL DEFAULT 0,
    loan_deductions     NUMERIC(12,2) NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (run_id, employee_key)
);

-- ── Fact: Training ────────────────────────────────────────────────

CREATE TABLE analytics.fact_training (
    id                  BIGSERIAL    PRIMARY KEY,
    date_key            INTEGER      REFERENCES analytics.dim_date(date_key),
    employee_key        BIGINT       REFERENCES analytics.dim_employee(surrogate_key),
    program_id          BIGINT,
    program_title       VARCHAR(200),
    hours_completed     NUMERIC(6,2),
    passed              BOOLEAN,
    score               NUMERIC(5,2),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── KPI Snapshots ─────────────────────────────────────────────────
-- One row per KPI per module per day. Dashboard reads from here.

CREATE TABLE analytics.kpi_snapshots (
    id              BIGSERIAL    PRIMARY KEY,
    snapshot_date   DATE         NOT NULL DEFAULT CURRENT_DATE,
    module          VARCHAR(50)  NOT NULL,
    kpi_code        VARCHAR(60)  NOT NULL,
    kpi_value       NUMERIC(14,4),
    kpi_label       VARCHAR(120),
    dimension_key   VARCHAR(100),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_kpi_snap_date   ON analytics.kpi_snapshots(snapshot_date, module);
CREATE INDEX idx_kpi_snap_code   ON analytics.kpi_snapshots(kpi_code, snapshot_date);
