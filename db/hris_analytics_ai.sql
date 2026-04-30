-- ================================================================
-- HCM360 ANALYTICS & AI LAYER
-- Loaded after: 01_hris_schema.sql, 02_hris_change_tracking.sql
-- ================================================================
--
-- ARCHITECTURE OVERVIEW
-- ─────────────────────────────────────────────────────────────────
-- PART 1  │ Dimensional Model      │ Star-schema facts + SCD Type 2
-- PART 2  │ Materialized Views     │ Pre-aggregated, concurrently refreshable
-- PART 3  │ Domain Event Log       │ Immutable business events, ML training source
-- PART 4  │ ML Feature Store       │ Point-in-time feature snapshots per employee
-- PART 5  │ Model Registry         │ Version-controlled ML model catalog
-- PART 6  │ AI Predictions         │ Inference log + actual outcome feedback loop
-- PART 7  │ AI Insight Scores      │ Attrition risk, anomalies, recommendations
-- PART 8  │ Vector Embeddings      │ Semantic search via pgvector (opt-in)
-- PART 9  │ Data Quality Layer     │ Completeness, freshness, drift signals
-- PART 10 │ Analytics Config       │ Metric definitions + report templates
--
-- AI USE CASES ENABLED
-- ─────────────────────────────────────────────────────────────────
--   • Attrition / turnover prediction per employee (risk score)
--   • Payroll anomaly detection (outliers in gross/net pay)
--   • Attendance pattern analysis (chronic lateness, leave abuse)
--   • Performance trajectory prediction
--   • Recruitment fit scoring (semantic similarity to top performers)
--   • Workforce demand forecasting (headcount planning)
--   • Skill gap identification & training recommendations
--   • Smart scheduling (shift optimization)
--   • NLP on performance feedback, documents, exit interviews
-- ================================================================

-- ── Extensions ──────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "tablefunc";   -- crosstab / pivot support

-- pgvector: install separately (docker image: pgvector/pgvector:pg15)
-- CREATE EXTENSION IF NOT EXISTS vector;    -- uncomment when available

-- ================================================================
-- PART 1: DIMENSIONAL MODEL (Star Schema)
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- 1A. Date Dimension (pre-populated 2020-01-01 → 2035-12-31)
-- ────────────────────────────────────────────────────────────────
CREATE TABLE dim_date (
    date_key        INTEGER      PRIMARY KEY,   -- YYYYMMDD integer key
    full_date       DATE         NOT NULL UNIQUE,
    day_of_week     SMALLINT     NOT NULL,       -- 0=Sunday … 6=Saturday
    day_name        VARCHAR(10)  NOT NULL,
    day_of_month    SMALLINT     NOT NULL,
    day_of_year     SMALLINT     NOT NULL,
    week_of_year    SMALLINT     NOT NULL,
    month_number    SMALLINT     NOT NULL,
    month_name      VARCHAR(10)  NOT NULL,
    quarter         SMALLINT     NOT NULL,
    year            SMALLINT     NOT NULL,
    is_weekday      BOOLEAN      NOT NULL,
    is_weekend      BOOLEAN      NOT NULL,
    is_holiday      BOOLEAN      NOT NULL DEFAULT FALSE,
    holiday_name    VARCHAR(200),
    fiscal_month    SMALLINT,                   -- populated by sp_refresh_fiscal_calendar
    fiscal_quarter  SMALLINT,
    fiscal_year     SMALLINT
);

-- Populate 2020-01-01 → 2035-12-31
INSERT INTO dim_date (
    date_key, full_date, day_of_week, day_name, day_of_month, day_of_year,
    week_of_year, month_number, month_name, quarter, year, is_weekday, is_weekend
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INTEGER,
    d::DATE,
    EXTRACT(DOW  FROM d)::SMALLINT,
    TRIM(TO_CHAR(d, 'Day')),
    EXTRACT(DAY  FROM d)::SMALLINT,
    EXTRACT(DOY  FROM d)::SMALLINT,
    EXTRACT(WEEK FROM d)::SMALLINT,
    EXTRACT(MON  FROM d)::SMALLINT,
    TRIM(TO_CHAR(d, 'Month')),
    EXTRACT(QUARTER FROM d)::SMALLINT,
    EXTRACT(YEAR FROM d)::SMALLINT,
    EXTRACT(DOW FROM d) NOT IN (0,6),
    EXTRACT(DOW FROM d) IN (0,6)
FROM generate_series('2020-01-01'::DATE, '2035-12-31'::DATE, '1 day'::INTERVAL) AS g(d);

CREATE INDEX idx_dim_date_year_month ON dim_date (year, month_number);

-- ────────────────────────────────────────────────────────────────
-- 1B. Employee Dimension — SCD Type 2
-- Tracks every attribute change as a new row for historical slicing.
-- Refresh via sp_refresh_dim_employee().
-- ────────────────────────────────────────────────────────────────
CREATE TABLE dim_employee (
    surrogate_key       BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL,   -- natural key → employees.id
    employee_no         VARCHAR(30),
    uuid                UUID,
    full_name           VARCHAR(300),
    last_name           VARCHAR(100),
    first_name          VARCHAR(100),
    gender              VARCHAR(20),
    civil_status        VARCHAR(20),
    date_of_birth       DATE,
    nationality         VARCHAR(50),
    department_id       BIGINT,
    department_name     VARCHAR(200),
    business_unit_name  VARCHAR(200),
    position_id         BIGINT,
    position_title      VARCHAR(200),
    job_grade_code      VARCHAR(20),
    job_grade_name      VARCHAR(100),
    employment_type     VARCHAR(100),
    is_managerial       BOOLEAN,
    supervisor_id       BIGINT,
    supervisor_name     VARCHAR(300),
    work_arrangement    VARCHAR(20),
    work_location       VARCHAR(200),
    cost_center_code    VARCHAR(20),
    status              VARCHAR(30),
    date_hired          DATE,
    date_regularized    DATE,
    basic_salary        NUMERIC(14,2),
    -- SCD Type 2 control
    effective_from      DATE         NOT NULL,
    effective_to        DATE,                    -- NULL = current record
    is_current          BOOLEAN      NOT NULL DEFAULT TRUE,
    -- Snapshot metadata
    snapshot_source     VARCHAR(30)  NOT NULL DEFAULT 'TRIGGER', -- TRIGGER | BATCH
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_dim_emp_natural     ON dim_employee (employee_id, is_current);
CREATE INDEX idx_dim_emp_current     ON dim_employee (employee_id) WHERE is_current = TRUE;
CREATE INDEX idx_dim_emp_effective   ON dim_employee (effective_from, effective_to);
CREATE INDEX idx_dim_emp_dept        ON dim_employee (department_id);

-- ────────────────────────────────────────────────────────────────
-- 1C. Fact Tables (denormalized, optimized for aggregation)
-- ────────────────────────────────────────────────────────────────

-- Fact: Attendance (one row per employee per work day)
CREATE TABLE fact_attendance (
    id                  BIGSERIAL    PRIMARY KEY,
    date_key            INTEGER      NOT NULL REFERENCES dim_date(date_key),
    employee_surrogate  BIGINT       REFERENCES dim_employee(surrogate_key),
    employee_id         BIGINT       NOT NULL,
    company_id          BIGINT       NOT NULL,
    department_id       BIGINT,
    position_id         BIGINT,
    shift_id            BIGINT,
    -- Degenerate dimensions
    status              VARCHAR(20),
    work_arrangement    VARCHAR(20),
    is_holiday          BOOLEAN      NOT NULL DEFAULT FALSE,
    is_restday          BOOLEAN      NOT NULL DEFAULT FALSE,
    -- Measures
    hours_worked        NUMERIC(5,2) NOT NULL DEFAULT 0,
    hours_late          NUMERIC(5,2) NOT NULL DEFAULT 0,
    hours_undertime     NUMERIC(5,2) NOT NULL DEFAULT 0,
    hours_overtime      NUMERIC(5,2) NOT NULL DEFAULT 0,
    hours_night_diff    NUMERIC(5,2) NOT NULL DEFAULT 0,
    -- Indicator flags (1/0 for easy SUM aggregation)
    is_present          SMALLINT     NOT NULL DEFAULT 0,
    is_absent           SMALLINT     NOT NULL DEFAULT 0,
    is_late             SMALLINT     NOT NULL DEFAULT 0,
    is_half_day         SMALLINT     NOT NULL DEFAULT 0,
    is_on_leave         SMALLINT     NOT NULL DEFAULT 0,
    is_ob               SMALLINT     NOT NULL DEFAULT 0,
    loaded_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (employee_id, date_key)
);

CREATE INDEX idx_fact_att_emp        ON fact_attendance (employee_id, date_key);
CREATE INDEX idx_fact_att_dept_date  ON fact_attendance (department_id, date_key);
CREATE INDEX idx_fact_att_company    ON fact_attendance (company_id, date_key);

-- Fact: Payroll (one row per employee per payroll run)
CREATE TABLE fact_payroll (
    id                  BIGSERIAL    PRIMARY KEY,
    period_date_key     INTEGER      NOT NULL REFERENCES dim_date(date_key),
    employee_surrogate  BIGINT       REFERENCES dim_employee(surrogate_key),
    employee_id         BIGINT       NOT NULL,
    run_id              BIGINT       NOT NULL,
    period_id           BIGINT       NOT NULL,
    company_id          BIGINT       NOT NULL,
    department_id       BIGINT,
    position_id         BIGINT,
    job_grade_id        BIGINT,
    employment_type     VARCHAR(100),
    period_type         VARCHAR(20),
    -- Measures
    worked_days         NUMERIC(5,2) NOT NULL DEFAULT 0,
    absent_days         NUMERIC(5,2) NOT NULL DEFAULT 0,
    ot_hours            NUMERIC(5,2) NOT NULL DEFAULT 0,
    basic_pay           NUMERIC(14,2) NOT NULL DEFAULT 0,
    ot_pay              NUMERIC(14,2) NOT NULL DEFAULT 0,
    allowances_total    NUMERIC(14,2) NOT NULL DEFAULT 0,
    gross_pay           NUMERIC(14,2) NOT NULL DEFAULT 0,
    sss_ee              NUMERIC(10,2) NOT NULL DEFAULT 0,
    philhealth_ee       NUMERIC(10,2) NOT NULL DEFAULT 0,
    pagibig_ee          NUMERIC(10,2) NOT NULL DEFAULT 0,
    withholding_tax     NUMERIC(10,2) NOT NULL DEFAULT 0,
    total_deductions    NUMERIC(14,2) NOT NULL DEFAULT 0,
    net_pay             NUMERIC(14,2) NOT NULL DEFAULT 0,
    -- Employer cost
    total_employer_cost NUMERIC(14,2) NOT NULL DEFAULT 0,
    loaded_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (run_id, employee_id)
);

CREATE INDEX idx_fact_pay_emp        ON fact_payroll (employee_id, period_date_key);
CREATE INDEX idx_fact_pay_company    ON fact_payroll (company_id, period_date_key);
CREATE INDEX idx_fact_pay_dept       ON fact_payroll (department_id, period_date_key);

-- Fact: Leave (one row per leave request)
CREATE TABLE fact_leave (
    id                  BIGSERIAL    PRIMARY KEY,
    filed_date_key      INTEGER      NOT NULL REFERENCES dim_date(date_key),
    from_date_key       INTEGER      REFERENCES dim_date(date_key),
    employee_surrogate  BIGINT       REFERENCES dim_employee(surrogate_key),
    employee_id         BIGINT       NOT NULL,
    leave_request_id    BIGINT       NOT NULL,
    company_id          BIGINT       NOT NULL,
    department_id       BIGINT,
    leave_type_id       BIGINT,
    leave_type_code     VARCHAR(30),
    is_paid             BOOLEAN,
    status              VARCHAR(20),
    -- Measures
    days_requested      NUMERIC(4,1) NOT NULL DEFAULT 0,
    days_approved       NUMERIC(4,1) NOT NULL DEFAULT 0,
    approval_hours      NUMERIC(8,2),           -- time from filed to final decision
    approval_levels     SMALLINT,               -- number of approvals required
    loaded_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (leave_request_id)
);

CREATE INDEX idx_fact_lv_emp         ON fact_leave (employee_id, filed_date_key);
CREATE INDEX idx_fact_lv_type        ON fact_leave (leave_type_id, filed_date_key);
CREATE INDEX idx_fact_lv_status      ON fact_leave (status);

-- Fact: Performance Review (one row per completed review)
CREATE TABLE fact_performance (
    id                  BIGSERIAL    PRIMARY KEY,
    review_date_key     INTEGER      REFERENCES dim_date(date_key),
    employee_surrogate  BIGINT       REFERENCES dim_employee(surrogate_key),
    employee_id         BIGINT       NOT NULL,
    reviewer_id         BIGINT       NOT NULL,
    review_id           BIGINT       NOT NULL,
    cycle_id            BIGINT       NOT NULL,
    company_id          BIGINT       NOT NULL,
    department_id       BIGINT,
    position_id         BIGINT,
    cycle_type          VARCHAR(20),
    review_type         VARCHAR(20),
    -- Measures
    overall_rating      NUMERIC(4,2),
    calibrated_rating   NUMERIC(4,2),
    kpi_count           INTEGER,
    kpis_met            INTEGER,
    kpis_exceeded       INTEGER,
    kpis_missed         INTEGER,
    loaded_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (review_id)
);

CREATE INDEX idx_fact_perf_emp       ON fact_performance (employee_id, review_date_key);
CREATE INDEX idx_fact_perf_cycle     ON fact_performance (cycle_id);

-- Fact: Recruitment Funnel (one row per applicant)
CREATE TABLE fact_recruitment (
    id                  BIGSERIAL    PRIMARY KEY,
    applied_date_key    INTEGER      REFERENCES dim_date(date_key),
    applicant_id        BIGINT       NOT NULL,
    posting_id          BIGINT       NOT NULL,
    company_id          BIGINT       NOT NULL,
    department_id       BIGINT,
    position_id         BIGINT,
    employment_type     VARCHAR(100),
    source              VARCHAR(50),
    final_stage         VARCHAR(30),
    was_hired           BOOLEAN      NOT NULL DEFAULT FALSE,
    -- Time-to-hire measures (days)
    days_applied_to_screening   INTEGER,
    days_applied_to_offer       INTEGER,
    days_applied_to_hired       INTEGER,
    expected_salary             NUMERIC(14,2),
    offered_salary              NUMERIC(14,2),
    loaded_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (applicant_id)
);

-- ================================================================
-- PART 2: MATERIALIZED VIEWS (Pre-aggregated, concurrently refreshable)
-- Schedule refresh via pg_cron: SELECT cron.schedule('0 1 * * *', 'CALL sp_refresh_analytics()');
-- ================================================================

-- Monthly headcount snapshot
CREATE MATERIALIZED VIEW mv_headcount_monthly AS
SELECT
    e.company_id,
    d.name                                  AS department,
    et.name                                 AS employment_type,
    e.status,
    e.work_arrangement,
    DATE_TRUNC('month', CURRENT_DATE)       AS snapshot_month,
    COUNT(*)                                AS headcount,
    COUNT(*) FILTER (WHERE e.gender = 'MALE')   AS male_count,
    COUNT(*) FILTER (WHERE e.gender = 'FEMALE') AS female_count,
    AVG(EXTRACT(EPOCH FROM (CURRENT_DATE - e.date_hired)) / 86400 / 365.25)
                                            AS avg_tenure_years,
    AVG(e.basic_salary)                     AS avg_salary,
    MIN(e.basic_salary)                     AS min_salary,
    MAX(e.basic_salary)                     AS max_salary
FROM employees e
JOIN departments     d  ON e.department_id     = d.id
JOIN employment_types et ON e.employment_type_id = et.id
WHERE e.is_active = TRUE
GROUP BY e.company_id, d.name, et.name, e.status, e.work_arrangement
WITH DATA;

CREATE UNIQUE INDEX uidx_mv_headcount ON mv_headcount_monthly
    (company_id, department, employment_type, status, work_arrangement);

-- Monthly payroll cost analysis
CREATE MATERIALIZED VIEW mv_payroll_cost_monthly AS
SELECT
    fp.company_id,
    fp.department_id,
    de.department_name,
    fp.employment_type,
    fp.period_type,
    dd.year,
    dd.month_number,
    dd.month_name,
    COUNT(DISTINCT fp.employee_id)  AS employee_count,
    SUM(fp.basic_pay)               AS total_basic,
    SUM(fp.allowances_total)        AS total_allowances,
    SUM(fp.ot_pay)                  AS total_ot_pay,
    SUM(fp.gross_pay)               AS total_gross,
    SUM(fp.total_deductions)        AS total_deductions,
    SUM(fp.net_pay)                 AS total_net,
    SUM(fp.total_employer_cost)     AS total_employer_cost,
    AVG(fp.gross_pay)               AS avg_gross_per_employee,
    AVG(fp.net_pay)                 AS avg_net_per_employee
FROM fact_payroll fp
JOIN dim_date     dd ON fp.period_date_key  = dd.date_key
JOIN dim_employee de ON fp.employee_surrogate = de.surrogate_key
GROUP BY
    fp.company_id, fp.department_id, de.department_name,
    fp.employment_type, fp.period_type,
    dd.year, dd.month_number, dd.month_name
WITH DATA;

CREATE UNIQUE INDEX uidx_mv_payroll ON mv_payroll_cost_monthly
    (company_id, department_id, employment_type, year, month_number);

-- Monthly attrition and headcount movement
CREATE MATERIALIZED VIEW mv_attrition_monthly AS
WITH
    separations AS (
        SELECT
            company_id,
            department_id,
            DATE_TRUNC('month', date_separated)         AS month,
            COUNT(*)                                     AS separated_count,
            COUNT(*) FILTER (WHERE separation_reason ILIKE '%resign%') AS resignations,
            COUNT(*) FILTER (WHERE status = 'TERMINATED')               AS terminations
        FROM employees
        WHERE date_separated IS NOT NULL
        GROUP BY company_id, department_id, DATE_TRUNC('month', date_separated)
    ),
    hires AS (
        SELECT
            company_id,
            department_id,
            DATE_TRUNC('month', date_hired)             AS month,
            COUNT(*)                                     AS new_hires
        FROM employees
        WHERE date_hired IS NOT NULL
        GROUP BY company_id, department_id, DATE_TRUNC('month', date_hired)
    )
SELECT
    COALESCE(s.company_id, h.company_id)    AS company_id,
    COALESCE(s.department_id, h.department_id) AS department_id,
    COALESCE(s.month, h.month)              AS month,
    COALESCE(h.new_hires, 0)                AS new_hires,
    COALESCE(s.separated_count, 0)          AS separations,
    COALESCE(s.resignations, 0)             AS resignations,
    COALESCE(s.terminations, 0)             AS terminations
FROM separations s
FULL OUTER JOIN hires h
    ON  s.company_id    = h.company_id
    AND s.department_id = h.department_id
    AND s.month         = h.month
WITH DATA;

CREATE UNIQUE INDEX uidx_mv_attrition ON mv_attrition_monthly (company_id, department_id, month);

-- Attendance heat-map (department × day-of-week × hour)
CREATE MATERIALIZED VIEW mv_attendance_heatmap AS
SELECT
    e.company_id,
    e.department_id,
    d.name              AS department_name,
    dd.day_of_week,
    dd.day_name,
    dd.year,
    dd.month_number,
    AVG(fa.hours_worked)        AS avg_hours_worked,
    SUM(fa.is_absent)           AS total_absences,
    SUM(fa.is_late)             AS total_lates,
    SUM(fa.is_on_leave)         AS total_on_leave,
    SUM(fa.hours_overtime)      AS total_ot_hours,
    COUNT(fa.id)                AS records
FROM fact_attendance fa
JOIN employees    e  ON fa.employee_id = e.id
JOIN departments  d  ON e.department_id = d.id
JOIN dim_date     dd ON fa.date_key    = dd.date_key
GROUP BY
    e.company_id, e.department_id, d.name,
    dd.day_of_week, dd.day_name, dd.year, dd.month_number
WITH DATA;

CREATE UNIQUE INDEX uidx_mv_att_heatmap ON mv_attendance_heatmap
    (company_id, department_id, day_of_week, year, month_number);

-- Leave utilization analytics
CREATE MATERIALIZED VIEW mv_leave_utilization AS
SELECT
    lb.employee_id,
    e.company_id,
    e.department_id,
    d.name          AS department_name,
    et.name         AS employment_type,
    lt.code         AS leave_type_code,
    lt.name         AS leave_type_name,
    lb.year,
    lb.entitled_days,
    lb.accrued_days,
    lb.used_days,
    lb.balance,
    CASE WHEN lb.accrued_days > 0
         THEN ROUND(lb.used_days / lb.accrued_days * 100, 2)
         ELSE 0 END AS utilization_pct
FROM lv_balances lb
JOIN employees      e  ON lb.employee_id   = e.id
JOIN lv_types       lt ON lb.leave_type_id = lt.id
JOIN departments    d  ON e.department_id  = d.id
JOIN employment_types et ON e.employment_type_id = et.id
WITH DATA;

CREATE UNIQUE INDEX uidx_mv_leave ON mv_leave_utilization (employee_id, leave_type_code, year);

-- ================================================================
-- PART 3: DOMAIN EVENT LOG (Immutable event stream)
-- Used for ML training, event sourcing, real-time analytics, webhooks.
-- Never UPDATE or DELETE rows — append-only.
-- ================================================================
CREATE TABLE hris_domain_events (
    id              BIGSERIAL        NOT NULL,
    event_id        UUID             NOT NULL DEFAULT uuid_generate_v4() UNIQUE,
    event_type      VARCHAR(100)     NOT NULL,
    -- Examples:
    -- EMPLOYEE_HIRED | EMPLOYEE_REGULARIZED | EMPLOYEE_RESIGNED | EMPLOYEE_TERMINATED
    -- LEAVE_FILED | LEAVE_APPROVED | LEAVE_REJECTED | LEAVE_CANCELLED
    -- PAYROLL_COMPUTED | PAYROLL_POSTED | PAYSLIP_RELEASED
    -- ATTENDANCE_LATE | ATTENDANCE_ABSENT | OVERTIME_APPROVED
    -- PERFORMANCE_REVIEW_SUBMITTED | KPI_ACHIEVED | KPI_MISSED | RATING_FINALIZED
    -- DOCUMENT_UPLOADED | DOCUMENT_EXPIRED | CONTRACT_RENEWED
    -- TRAINING_COMPLETED | TRAINING_FAILED
    -- USER_LOGIN | USER_LOGOUT | PERMISSION_CHANGED
    event_version   VARCHAR(10)      NOT NULL DEFAULT '1.0', -- for schema evolution
    company_id      BIGINT,
    employee_id     BIGINT,
    actor_user_id   BIGINT,          -- who triggered the event
    -- Core payload
    aggregate_type  VARCHAR(50)      NOT NULL,  -- EMPLOYEE | LEAVE | PAYROLL | etc.
    aggregate_id    BIGINT           NOT NULL,
    payload         JSONB            NOT NULL DEFAULT '{}',
    -- Correlation / causation for event chains
    correlation_id  UUID,            -- tie related events together
    causation_id    UUID,            -- event that caused this one
    -- Processing metadata
    is_processed    BOOLEAN          NOT NULL DEFAULT FALSE,
    processed_at    TIMESTAMPTZ,
    processor_id    VARCHAR(50),     -- which consumer processed it
    created_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE hris_domain_events_2025 PARTITION OF hris_domain_events FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE hris_domain_events_2026 PARTITION OF hris_domain_events FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE hris_domain_events_2027 PARTITION OF hris_domain_events FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
CREATE TABLE hris_domain_events_2028 PARTITION OF hris_domain_events FOR VALUES FROM ('2028-01-01') TO ('2029-01-01');

CREATE INDEX idx_evt_type            ON hris_domain_events (event_type, created_at);
CREATE INDEX idx_evt_employee        ON hris_domain_events (employee_id, created_at);
CREATE INDEX idx_evt_company         ON hris_domain_events (company_id, created_at);
CREATE INDEX idx_evt_aggregate       ON hris_domain_events (aggregate_type, aggregate_id);
CREATE INDEX idx_evt_unprocessed     ON hris_domain_events (is_processed, created_at) WHERE is_processed = FALSE;
CREATE INDEX idx_evt_payload_gin     ON hris_domain_events USING GIN (payload);

-- Convenience function to emit a domain event
CREATE OR REPLACE FUNCTION fn_emit_event(
    p_event_type    VARCHAR,
    p_aggregate_type VARCHAR,
    p_aggregate_id  BIGINT,
    p_payload       JSONB       DEFAULT '{}',
    p_employee_id   BIGINT      DEFAULT NULL,
    p_company_id    BIGINT      DEFAULT NULL,
    p_correlation_id UUID       DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql AS $$
DECLARE
    v_event_id  UUID := uuid_generate_v4();
    v_user_id   BIGINT;
BEGIN
    BEGIN
        v_user_id := current_setting('app.current_user_id', TRUE)::BIGINT;
    EXCEPTION WHEN OTHERS THEN v_user_id := NULL; END;

    INSERT INTO hris_domain_events (
        event_id, event_type, company_id, employee_id, actor_user_id,
        aggregate_type, aggregate_id, payload, correlation_id
    ) VALUES (
        v_event_id, p_event_type, p_company_id, p_employee_id, v_user_id,
        p_aggregate_type, p_aggregate_id, p_payload, p_correlation_id
    );
    RETURN v_event_id;
END;
$$;

-- ================================================================
-- PART 4: ML FEATURE STORE
-- Pre-computed, point-in-time safe feature snapshots.
-- The application / ML pipeline populates these on a schedule.
-- ================================================================

-- Feature catalog: defines each feature, its source, and type
CREATE TABLE ml_feature_catalog (
    id              BIGSERIAL    PRIMARY KEY,
    feature_code    VARCHAR(100) NOT NULL UNIQUE,
    feature_name    VARCHAR(200) NOT NULL,
    description     TEXT,
    entity_type     VARCHAR(50)  NOT NULL DEFAULT 'EMPLOYEE', -- EMPLOYEE | DEPARTMENT | COMPANY
    data_type       VARCHAR(30)  NOT NULL, -- NUMERIC | BOOLEAN | CATEGORICAL | EMBEDDING
    source_module   VARCHAR(50)  NOT NULL, -- ATTENDANCE | LEAVE | PAYROLL | PERFORMANCE | etc.
    sql_expression  TEXT,                  -- how to compute it (for documentation / lineage)
    default_value   VARCHAR(100),
    is_nullable     BOOLEAN      NOT NULL DEFAULT TRUE,
    importance_score NUMERIC(5,4),         -- updated by model training pipelines
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Point-in-time employee feature snapshots (for training + inference)
CREATE TABLE ml_employee_features (
    id              BIGSERIAL    NOT NULL,
    employee_id     BIGINT       NOT NULL REFERENCES employees(id),
    company_id      BIGINT       NOT NULL,
    snapshot_date   DATE         NOT NULL,
    feature_set_version VARCHAR(20) NOT NULL DEFAULT 'v1',
    -- Attendance features
    tenure_days                 INTEGER,
    attendance_rate_30d         NUMERIC(5,4),  -- 0.0–1.0
    late_count_30d              INTEGER,
    late_count_90d              INTEGER,
    absent_count_30d            INTEGER,
    absent_count_90d            INTEGER,
    ot_hours_30d                NUMERIC(7,2),
    ot_hours_90d                NUMERIC(7,2),
    avg_daily_hours_30d         NUMERIC(5,2),
    -- Leave features
    leave_balance_pct           NUMERIC(5,4),  -- used / entitled
    leave_requests_12m          INTEGER,
    leave_days_used_12m         NUMERIC(5,1),
    leave_rejection_rate_12m    NUMERIC(5,4),
    sick_leave_count_12m        INTEGER,
    -- Payroll features
    current_basic_salary        NUMERIC(14,2),
    salary_pct_of_grade_max     NUMERIC(5,4),
    salary_growth_pct_12m       NUMERIC(7,4),
    total_loans_outstanding     NUMERIC(14,2),
    -- Performance features
    last_overall_rating         NUMERIC(4,2),
    avg_rating_2_cycles         NUMERIC(4,2),
    rating_trend                NUMERIC(5,4),  -- positive = improving
    kpi_achievement_rate        NUMERIC(5,4),
    -- Organizational features
    manager_change_count_12m    INTEGER,
    dept_change_count_24m       INTEGER,
    team_attrition_rate_12m     NUMERIC(5,4),  -- attrition in same dept
    position_tenure_days        INTEGER,
    -- Training features
    trainings_completed_12m     INTEGER,
    training_pass_rate          NUMERIC(5,4),
    -- Composite / derived
    engagement_score            NUMERIC(5,4),  -- computed by ML pipeline
    flight_risk_raw             NUMERIC(5,4),  -- preliminary before model override
    -- Flexible overflow for new features
    extra_features              JSONB          NOT NULL DEFAULT '{}',
    created_at                  TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, snapshot_date)
) PARTITION BY RANGE (snapshot_date);

CREATE TABLE ml_employee_features_2025 PARTITION OF ml_employee_features FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE ml_employee_features_2026 PARTITION OF ml_employee_features FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE ml_employee_features_2027 PARTITION OF ml_employee_features FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
CREATE TABLE ml_employee_features_2028 PARTITION OF ml_employee_features FOR VALUES FROM ('2028-01-01') TO ('2029-01-01');

CREATE INDEX idx_mlf_emp_date ON ml_employee_features (employee_id, snapshot_date DESC);
CREATE INDEX idx_mlf_company  ON ml_employee_features (company_id, snapshot_date DESC);

-- Training dataset registry (snapshot references used per model version)
CREATE TABLE ml_training_datasets (
    id              BIGSERIAL    PRIMARY KEY,
    dataset_code    VARCHAR(100) NOT NULL UNIQUE,
    model_target    VARCHAR(100) NOT NULL,  -- ATTRITION | PERFORMANCE | ANOMALY | etc.
    feature_set_version VARCHAR(20) NOT NULL,
    snapshot_from   DATE         NOT NULL,
    snapshot_to     DATE         NOT NULL,
    total_samples   INTEGER,
    positive_samples INTEGER,               -- label = 1 count
    negative_samples INTEGER,               -- label = 0 count
    class_balance   NUMERIC(5,4),           -- pos / total
    split_config    JSONB        NOT NULL DEFAULT '{}',
    -- {"train": 0.7, "val": 0.15, "test": 0.15, "stratify": "department_id"}
    storage_path    TEXT,                   -- S3/local path to exported dataset
    created_by      VARCHAR(100),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ================================================================
-- PART 5: MODEL REGISTRY
-- Version-controlled ML model catalog with deployment tracking.
-- ================================================================
CREATE TABLE ml_models (
    id              BIGSERIAL    PRIMARY KEY,
    model_code      VARCHAR(100) NOT NULL UNIQUE,
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    model_type      VARCHAR(50)  NOT NULL,
    -- CLASSIFICATION | REGRESSION | CLUSTERING | ANOMALY_DETECTION | NLP | EMBEDDING
    use_case        VARCHAR(100) NOT NULL,
    -- ATTRITION_PREDICTION | PERFORMANCE_PREDICTION | PAYROLL_ANOMALY
    -- ATTENDANCE_ANOMALY | RECRUITMENT_FIT | WORKFORCE_FORECAST | SEMANTIC_SEARCH
    target_entity   VARCHAR(50)  NOT NULL DEFAULT 'EMPLOYEE',
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE ml_model_versions (
    id              BIGSERIAL    PRIMARY KEY,
    model_id        BIGINT       NOT NULL REFERENCES ml_models(id),
    version_tag     VARCHAR(30)  NOT NULL,  -- e.g. v1.2.0
    dataset_id      BIGINT       REFERENCES ml_training_datasets(id),
    algorithm       VARCHAR(100),           -- XGBoost | RandomForest | LogReg | BERT | etc.
    framework       VARCHAR(50),            -- sklearn | pytorch | tensorflow | xgboost
    hyperparameters JSONB        NOT NULL DEFAULT '{}',
    -- Training metrics
    train_accuracy  NUMERIC(7,4),
    val_accuracy    NUMERIC(7,4),
    test_accuracy   NUMERIC(7,4),
    auc_roc         NUMERIC(7,4),
    f1_score        NUMERIC(7,4),
    precision_score NUMERIC(7,4),
    recall_score    NUMERIC(7,4),
    rmse            NUMERIC(12,4),          -- for regression models
    feature_importance JSONB     NOT NULL DEFAULT '{}',
    -- Deployment
    status          VARCHAR(20)  NOT NULL DEFAULT 'CANDIDATE',
    -- CANDIDATE | STAGING | PRODUCTION | RETIRED | FAILED
    model_path      TEXT,                   -- serialized model file path
    deployed_at     TIMESTAMPTZ,
    deployed_by     VARCHAR(100),
    retired_at      TIMESTAMPTZ,
    notes           TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (model_id, version_tag)
);

CREATE INDEX idx_mlv_model_status  ON ml_model_versions (model_id, status);

-- Model drift / monitoring (track performance degradation over time)
CREATE TABLE ml_model_monitoring (
    id              BIGSERIAL    PRIMARY KEY,
    model_version_id BIGINT      NOT NULL REFERENCES ml_model_versions(id),
    evaluation_date DATE         NOT NULL,
    sample_count    INTEGER,
    accuracy        NUMERIC(7,4),
    auc_roc         NUMERIC(7,4),
    f1_score        NUMERIC(7,4),
    -- PSI = Population Stability Index (>0.2 = significant drift)
    psi_score       NUMERIC(7,4),
    drift_detected  BOOLEAN      NOT NULL DEFAULT FALSE,
    alert_sent      BOOLEAN      NOT NULL DEFAULT FALSE,
    notes           TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ================================================================
-- PART 6: AI PREDICTIONS & FEEDBACK LOOP
-- Inference log + actual outcome tracking for model improvement.
-- ================================================================

-- Inference log (partitioned — high volume)
CREATE TABLE ai_predictions (
    id              BIGSERIAL        NOT NULL,
    prediction_id   UUID             NOT NULL DEFAULT uuid_generate_v4() UNIQUE,
    model_version_id BIGINT          NOT NULL REFERENCES ml_model_versions(id),
    use_case        VARCHAR(100)     NOT NULL,
    -- Target entity
    employee_id     BIGINT           REFERENCES employees(id),
    company_id      BIGINT           REFERENCES companies(id),
    entity_type     VARCHAR(50)      NOT NULL DEFAULT 'EMPLOYEE',
    entity_id       BIGINT           NOT NULL,
    -- Prediction
    prediction_date DATE             NOT NULL,
    predicted_label VARCHAR(100),             -- for classification: predicted class
    predicted_score NUMERIC(8,6),             -- probability / regression value
    confidence      NUMERIC(6,4),             -- model confidence score
    features_snapshot JSONB          NOT NULL DEFAULT '{}',  -- inputs used
    explanation     JSONB            NOT NULL DEFAULT '{}',  -- SHAP values / reasoning
    -- Outcome tracking (filled when ground truth is known)
    actual_label    VARCHAR(100),
    actual_outcome_date DATE,
    is_correct      BOOLEAN,
    -- Operational
    created_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE ai_predictions_2025 PARTITION OF ai_predictions FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE ai_predictions_2026 PARTITION OF ai_predictions FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE ai_predictions_2027 PARTITION OF ai_predictions FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
CREATE TABLE ai_predictions_2028 PARTITION OF ai_predictions FOR VALUES FROM ('2028-01-01') TO ('2029-01-01');

CREATE INDEX idx_aip_employee   ON ai_predictions (employee_id, prediction_date);
CREATE INDEX idx_aip_use_case   ON ai_predictions (use_case, prediction_date);
CREATE INDEX idx_aip_model      ON ai_predictions (model_version_id, prediction_date);

-- ================================================================
-- PART 7: AI INSIGHT SCORES
-- Current per-employee AI-derived scores, refreshed on schedule.
-- ================================================================

-- Attrition risk per employee (latest score)
CREATE TABLE ai_attrition_scores (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES employees(id) UNIQUE,
    company_id      BIGINT       NOT NULL,
    model_version_id BIGINT      REFERENCES ml_model_versions(id),
    score_date      DATE         NOT NULL DEFAULT CURRENT_DATE,
    -- Score and risk tier
    risk_score      NUMERIC(6,4) NOT NULL,    -- 0.0 = no risk, 1.0 = certain departure
    risk_tier       VARCHAR(20)  NOT NULL,    -- LOW | MEDIUM | HIGH | CRITICAL
    -- Top contributing factors (from SHAP)
    top_factors     JSONB        NOT NULL DEFAULT '[]',
    -- [{"feature": "late_count_90d", "impact": 0.23, "value": 12}, ...]
    recommended_actions JSONB    NOT NULL DEFAULT '[]',
    -- [{"action": "Manager check-in", "priority": "HIGH"}, ...]
    -- Tracking
    previous_score  NUMERIC(6,4),
    score_change    NUMERIC(6,4) GENERATED ALWAYS AS (risk_score - COALESCE(previous_score, risk_score)) STORED,
    is_flagged_for_hr BOOLEAN    NOT NULL DEFAULT FALSE,
    hr_reviewed_at  TIMESTAMPTZ,
    hr_reviewer_id  BIGINT       REFERENCES users(id),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_attrition_company   ON ai_attrition_scores (company_id, risk_tier);
CREATE INDEX idx_attrition_flagged   ON ai_attrition_scores (is_flagged_for_hr) WHERE is_flagged_for_hr = TRUE;

-- Anomaly flags (payroll, attendance, behavior outliers)
CREATE TABLE ai_anomaly_flags (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL,
    employee_id     BIGINT       REFERENCES employees(id),
    module          VARCHAR(50)  NOT NULL,  -- PAYROLL | ATTENDANCE | LEAVE | PERFORMANCE
    anomaly_type    VARCHAR(100) NOT NULL,
    -- PAYROLL: GROSS_OUTLIER | SUDDEN_RAISE | DEDUCTION_MISSING | DUPLICATE_PAYRUN
    -- ATTENDANCE: CONSECUTIVE_ABSENCES | ALWAYS_EXACT_CLOCKIN | UNUSUAL_OT_PATTERN
    -- LEAVE: BACKDATED_LEAVE | MONDAY_FRIDAY_PATTERN | BALANCE_DISCREPANCY
    entity_id       BIGINT,                -- affected record id
    entity_date     DATE,
    anomaly_score   NUMERIC(6,4) NOT NULL, -- 0=normal, 1=extreme
    description     TEXT         NOT NULL,
    raw_value       NUMERIC(14,4),
    expected_range  JSONB,                 -- {"min": 100, "max": 500, "mean": 250}
    status          VARCHAR(20)  NOT NULL DEFAULT 'OPEN',
    -- OPEN | REVIEWED | RESOLVED | FALSE_POSITIVE
    reviewed_by     BIGINT       REFERENCES users(id),
    reviewed_at     TIMESTAMPTZ,
    resolution_notes TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_anomaly_company     ON ai_anomaly_flags (company_id, status, created_at);
CREATE INDEX idx_anomaly_employee    ON ai_anomaly_flags (employee_id, module, created_at);
CREATE INDEX idx_anomaly_open        ON ai_anomaly_flags (status, anomaly_score DESC) WHERE status = 'OPEN';

-- Workforce demand forecast (department-level headcount projections)
CREATE TABLE ai_workforce_forecasts (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL,
    department_id   BIGINT       REFERENCES departments(id),
    forecast_date   DATE         NOT NULL,
    forecast_horizon_months INTEGER NOT NULL,
    -- Projections
    current_headcount   INTEGER,
    projected_headcount INTEGER,
    attrition_forecast  INTEGER,    -- expected departures
    hiring_need         INTEGER,    -- recommended new hires
    confidence_interval_low  INTEGER,
    confidence_interval_high INTEGER,
    model_version_id    BIGINT      REFERENCES ml_model_versions(id),
    assumptions         JSONB       NOT NULL DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, department_id, forecast_date, forecast_horizon_months)
);

-- AI-generated HR recommendations
CREATE TABLE ai_recommendations (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL,
    employee_id     BIGINT       REFERENCES employees(id),
    category        VARCHAR(50)  NOT NULL,
    -- RETENTION | TRAINING | PROMOTION | PERFORMANCE_SUPPORT
    -- SHIFT_OPTIMIZATION | LEAVE_PLANNING | COMPLIANCE
    title           VARCHAR(300) NOT NULL,
    description     TEXT         NOT NULL,
    priority        VARCHAR(20)  NOT NULL DEFAULT 'MEDIUM',  -- LOW | MEDIUM | HIGH | URGENT
    supporting_data JSONB        NOT NULL DEFAULT '{}',
    expires_at      TIMESTAMPTZ,
    status          VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    -- PENDING | ACTIONED | DISMISSED | EXPIRED
    actioned_by     BIGINT       REFERENCES users(id),
    actioned_at     TIMESTAMPTZ,
    feedback        TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_rec_company_status  ON ai_recommendations (company_id, status, priority);
CREATE INDEX idx_rec_employee        ON ai_recommendations (employee_id, status);

-- ================================================================
-- PART 8: VECTOR EMBEDDINGS (requires pgvector extension)
-- Enables semantic search, similarity matching, and RAG pipelines.
-- Uncomment after: CREATE EXTENSION vector;
-- ================================================================

-- Employee profile embeddings (generated from profile text)
-- CREATE TABLE emb_employee_profiles (
--     id              BIGSERIAL    PRIMARY KEY,
--     employee_id     BIGINT       NOT NULL REFERENCES employees(id),
--     model_name      VARCHAR(100) NOT NULL DEFAULT 'text-embedding-3-small',
--     embedding       vector(1536),          -- 1536 dims for OpenAI; 768 for BGE
--     source_text     TEXT,                  -- the text that was embedded
--     snapshot_date   DATE         NOT NULL DEFAULT CURRENT_DATE,
--     created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
--     UNIQUE (employee_id, model_name)
-- );
-- CREATE INDEX idx_emb_emp_hnsw ON emb_employee_profiles USING hnsw (embedding vector_cosine_ops);

-- Job description embeddings (for recruitment similarity matching)
-- CREATE TABLE emb_job_descriptions (
--     id              BIGSERIAL    PRIMARY KEY,
--     posting_id      BIGINT       NOT NULL REFERENCES rec_job_postings(id),
--     model_name      VARCHAR(100) NOT NULL DEFAULT 'text-embedding-3-small',
--     embedding       vector(1536),
--     source_text     TEXT,
--     created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
-- );
-- CREATE INDEX idx_emb_job_hnsw ON emb_job_descriptions USING hnsw (embedding vector_cosine_ops);

-- Performance feedback embeddings (qualitative NLP)
-- CREATE TABLE emb_performance_feedback (
--     id              BIGSERIAL    PRIMARY KEY,
--     review_id       BIGINT       NOT NULL REFERENCES perf_reviews(id),
--     feedback_type   VARCHAR(50),
--     model_name      VARCHAR(100) NOT NULL DEFAULT 'text-embedding-3-small',
--     embedding       vector(1536),
--     source_text     TEXT,
--     sentiment_score NUMERIC(5,4),          -- -1.0 to 1.0
--     key_themes      TEXT[],
--     created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
-- );

-- ================================================================
-- PART 9: DATA QUALITY LAYER
-- Profile completeness and staleness signals for ML reliability.
-- ================================================================

-- Employee profile completeness score (recomputed nightly)
CREATE TABLE dq_profile_completeness (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES employees(id) UNIQUE,
    company_id      BIGINT       NOT NULL,
    computed_date   DATE         NOT NULL DEFAULT CURRENT_DATE,
    -- Completeness by domain (0.0 – 1.0)
    personal_score      NUMERIC(5,4) NOT NULL DEFAULT 0,
    contact_score       NUMERIC(5,4) NOT NULL DEFAULT 0,
    government_id_score NUMERIC(5,4) NOT NULL DEFAULT 0,
    banking_score       NUMERIC(5,4) NOT NULL DEFAULT 0,
    education_score     NUMERIC(5,4) NOT NULL DEFAULT 0,
    documents_score     NUMERIC(5,4) NOT NULL DEFAULT 0,
    overall_score       NUMERIC(5,4) NOT NULL DEFAULT 0,
    -- Missing critical fields
    missing_fields      TEXT[]       NOT NULL DEFAULT '{}',
    ml_readiness        BOOLEAN      NOT NULL DEFAULT FALSE,  -- overall_score >= 0.80
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_dq_company_score    ON dq_profile_completeness (company_id, overall_score);
CREATE INDEX idx_dq_ml_readiness     ON dq_profile_completeness (ml_readiness) WHERE ml_readiness = FALSE;

-- Data issue tracker (feed from automated quality checks)
CREATE TABLE dq_data_issues (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL,
    table_name      VARCHAR(100) NOT NULL,
    column_name     VARCHAR(100),
    row_id          BIGINT,
    issue_type      VARCHAR(50)  NOT NULL,
    -- NULL_REQUIRED | DUPLICATE | INVALID_FORMAT | OUT_OF_RANGE
    -- ORPHAN_RECORD | FUTURE_DATE | REFERENTIAL_MISMATCH
    description     TEXT         NOT NULL,
    severity        VARCHAR(20)  NOT NULL DEFAULT 'WARNING',  -- INFO | WARNING | ERROR | CRITICAL
    status          VARCHAR(20)  NOT NULL DEFAULT 'OPEN',
    auto_fixable    BOOLEAN      NOT NULL DEFAULT FALSE,
    fix_applied     BOOLEAN      NOT NULL DEFAULT FALSE,
    resolved_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_dq_issues_open      ON dq_data_issues (company_id, status, severity) WHERE status = 'OPEN';

-- Column-level statistics (for feature drift detection)
CREATE TABLE dq_column_stats (
    id              BIGSERIAL    PRIMARY KEY,
    table_name      VARCHAR(100) NOT NULL,
    column_name     VARCHAR(100) NOT NULL,
    company_id      BIGINT,
    stats_date      DATE         NOT NULL DEFAULT CURRENT_DATE,
    row_count       BIGINT,
    null_count      BIGINT,
    null_pct        NUMERIC(7,4),
    distinct_count  BIGINT,
    min_value       TEXT,
    max_value       TEXT,
    mean_value      NUMERIC(20,6),
    std_dev         NUMERIC(20,6),
    p25             NUMERIC(20,6),
    p50             NUMERIC(20,6),
    p75             NUMERIC(20,6),
    top_values      JSONB,                 -- [{"value": "ACTIVE", "count": 850}, ...]
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ================================================================
-- PART 10: ANALYTICS CONFIGURATION
-- Metric definitions and report templates for the dashboard layer.
-- ================================================================

-- Metric definitions (single source of truth for KPI formulas)
CREATE TABLE analytics_metric_definitions (
    id              BIGSERIAL    PRIMARY KEY,
    metric_code     VARCHAR(100) NOT NULL UNIQUE,
    category        VARCHAR(50)  NOT NULL,
    -- HEADCOUNT | ATTRITION | ATTENDANCE | PAYROLL | PERFORMANCE | RECRUITMENT | TRAINING
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    formula_sql     TEXT,                  -- SQL expression or MV reference
    unit            VARCHAR(30),           -- COUNT | PERCENTAGE | CURRENCY | HOURS | DAYS
    direction       VARCHAR(10) NOT NULL DEFAULT 'NEUTRAL',  -- UP_IS_GOOD | DOWN_IS_GOOD | NEUTRAL
    target_value    NUMERIC(20,4),
    warning_threshold NUMERIC(20,4),
    critical_threshold NUMERIC(20,4),
    refresh_frequency VARCHAR(20) NOT NULL DEFAULT 'DAILY',  -- REALTIME | HOURLY | DAILY | WEEKLY
    is_ai_derived   BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Metric value history (time-series store for dashboards)
CREATE TABLE analytics_metric_values (
    id              BIGSERIAL    NOT NULL,
    metric_id       BIGINT       NOT NULL REFERENCES analytics_metric_definitions(id),
    company_id      BIGINT       NOT NULL REFERENCES companies(id),
    dimension_key   VARCHAR(200),          -- e.g. "department_id:3" for drilldown
    period_date     DATE         NOT NULL,
    value           NUMERIC(20,4),
    previous_value  NUMERIC(20,4),
    pct_change      NUMERIC(8,4) GENERATED ALWAYS AS
        (CASE WHEN previous_value != 0 THEN (value - previous_value) / ABS(previous_value) * 100 ELSE NULL END) STORED,
    is_estimate     BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, period_date)
) PARTITION BY RANGE (period_date);

CREATE TABLE analytics_metric_values_2025 PARTITION OF analytics_metric_values FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE analytics_metric_values_2026 PARTITION OF analytics_metric_values FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE analytics_metric_values_2027 PARTITION OF analytics_metric_values FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
CREATE TABLE analytics_metric_values_2028 PARTITION OF analytics_metric_values FOR VALUES FROM ('2028-01-01') TO ('2029-01-01');

CREATE INDEX idx_amv_metric_date     ON analytics_metric_values (metric_id, company_id, period_date);

-- ================================================================
-- STORED PROCEDURES: Refresh Pipeline
-- ================================================================

-- Refresh all materialized views (schedule nightly via pg_cron)
CREATE OR REPLACE PROCEDURE sp_refresh_analytics()
LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_headcount_monthly;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_payroll_cost_monthly;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_attrition_monthly;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_attendance_heatmap;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_leave_utilization;
    RAISE NOTICE 'Analytics materialized views refreshed at %', NOW();
END;
$$;

-- Refresh dim_employee SCD Type 2 from live employees table
CREATE OR REPLACE PROCEDURE sp_refresh_dim_employee()
LANGUAGE plpgsql AS $$
BEGIN
    -- Close current records where key attributes have changed
    UPDATE dim_employee de
    SET
        effective_to = CURRENT_DATE - 1,
        is_current   = FALSE
    FROM employees e
    JOIN departments     d  ON e.department_id     = d.id
    JOIN positions       p  ON e.position_id       = p.id
    LEFT JOIN job_grades jg ON e.job_grade_id      = jg.id
    LEFT JOIN employment_types et ON e.employment_type_id = et.id
    LEFT JOIN employees  s  ON e.immediate_supervisor_id = s.id
    WHERE de.employee_id  = e.id
      AND de.is_current   = TRUE
      AND (
            de.status             IS DISTINCT FROM e.status
         OR de.department_id      IS DISTINCT FROM e.department_id
         OR de.position_id        IS DISTINCT FROM e.position_id
         OR de.basic_salary       IS DISTINCT FROM e.basic_salary
         OR de.job_grade_code     IS DISTINCT FROM jg.code
         OR de.employment_type    IS DISTINCT FROM et.name
         OR de.work_arrangement   IS DISTINCT FROM e.work_arrangement
      );

    -- Insert new current records for changed / new employees
    INSERT INTO dim_employee (
        employee_id, employee_no, uuid, full_name, last_name, first_name,
        gender, civil_status, date_of_birth, nationality,
        department_id, department_name, position_id, position_title,
        job_grade_code, job_grade_name, employment_type, is_managerial,
        supervisor_id, supervisor_name,
        status, date_hired, date_regularized, basic_salary,
        work_arrangement, work_location, cost_center_code,
        effective_from, effective_to, is_current, snapshot_source
    )
    SELECT
        e.id, e.employee_no, e.uuid,
        e.last_name || ', ' || e.first_name, e.last_name, e.first_name,
        e.gender, e.civil_status, e.date_of_birth, e.nationality,
        e.department_id, d.name, e.position_id, p.title,
        jg.code, jg.name, et.name, p.is_managerial,
        e.immediate_supervisor_id,
        COALESCE(s.last_name || ', ' || s.first_name, ''),
        e.status, e.date_hired, e.date_regularized, e.basic_salary,
        e.work_arrangement, e.work_location, e.cost_center_code,
        CURRENT_DATE, NULL, TRUE, 'BATCH'
    FROM employees e
    JOIN departments     d  ON e.department_id     = d.id
    JOIN positions       p  ON e.position_id       = p.id
    LEFT JOIN job_grades jg ON e.job_grade_id      = jg.id
    LEFT JOIN employment_types et ON e.employment_type_id = et.id
    LEFT JOIN employees  s  ON e.immediate_supervisor_id = s.id
    WHERE e.is_active = TRUE
      AND NOT EXISTS (
          SELECT 1 FROM dim_employee de2
          WHERE de2.employee_id = e.id AND de2.is_current = TRUE
      );

    RAISE NOTICE 'dim_employee refreshed at %', NOW();
END;
$$;

-- Load fact_attendance from att_daily (incremental — last 7 days by default)
CREATE OR REPLACE PROCEDURE sp_load_fact_attendance(p_days_back INTEGER DEFAULT 7)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO fact_attendance (
        date_key, employee_surrogate, employee_id, company_id,
        department_id, position_id, shift_id,
        status, work_arrangement, is_holiday, is_restday,
        hours_worked, hours_late, hours_undertime, hours_overtime, hours_night_diff,
        is_present, is_absent, is_late, is_half_day, is_on_leave, is_ob
    )
    SELECT
        TO_CHAR(ad.work_date, 'YYYYMMDD')::INTEGER,
        de.surrogate_key,
        ad.employee_id,
        e.company_id,
        e.department_id,
        e.position_id,
        ad.shift_id,
        ad.status,
        e.work_arrangement,
        ad.is_holiday,
        ad.is_restday,
        ad.hours_worked,
        ad.hours_late,
        ad.hours_undertime,
        ad.hours_overtime,
        ad.hours_night_diff,
        (ad.status = 'PRESENT')::SMALLINT,
        (ad.status = 'ABSENT')::SMALLINT,
        (ad.status = 'LATE')::SMALLINT,
        (ad.status = 'HALF_DAY')::SMALLINT,
        (ad.status = 'ON_LEAVE')::SMALLINT,
        (ad.status = 'OB')::SMALLINT
    FROM att_daily ad
    JOIN employees e  ON ad.employee_id  = e.id
    LEFT JOIN dim_employee de ON de.employee_id = e.id AND de.is_current = TRUE
    WHERE ad.work_date >= CURRENT_DATE - p_days_back
    ON CONFLICT (employee_id, date_key)
    DO UPDATE SET
        hours_worked      = EXCLUDED.hours_worked,
        hours_late        = EXCLUDED.hours_late,
        hours_undertime   = EXCLUDED.hours_undertime,
        hours_overtime    = EXCLUDED.hours_overtime,
        is_present        = EXCLUDED.is_present,
        is_absent         = EXCLUDED.is_absent,
        is_late           = EXCLUDED.is_late,
        is_on_leave       = EXCLUDED.is_on_leave,
        status            = EXCLUDED.status,
        loaded_at         = NOW();

    RAISE NOTICE 'fact_attendance loaded (% days back) at %', p_days_back, NOW();
END;
$$;

-- ================================================================
-- ANALYTICS VIEWS (on top of dimensional model)
-- ================================================================

-- High-risk attrition dashboard
CREATE VIEW v_attrition_risk_dashboard AS
SELECT
    e.employee_no,
    e.last_name || ', ' || e.first_name AS full_name,
    d.name          AS department,
    p.title         AS position,
    et.name         AS employment_type,
    e.date_hired,
    ROUND(EXTRACT(EPOCH FROM (CURRENT_DATE - e.date_hired)) / 86400 / 365.25, 1) AS tenure_years,
    e.basic_salary,
    a.risk_score,
    a.risk_tier,
    a.top_factors,
    a.recommended_actions,
    a.score_change,
    a.is_flagged_for_hr,
    a.updated_at    AS score_updated_at
FROM ai_attrition_scores a
JOIN employees       e  ON a.employee_id      = e.id
JOIN departments     d  ON e.department_id    = d.id
JOIN positions       p  ON e.position_id      = p.id
JOIN employment_types et ON e.employment_type_id = et.id
WHERE e.is_active = TRUE
  AND e.status NOT IN ('RESIGNED','TERMINATED','RETIRED')
ORDER BY a.risk_score DESC;

-- Workforce overview snapshot for executive dashboard
CREATE VIEW v_workforce_snapshot AS
SELECT
    c.name                          AS company,
    COUNT(DISTINCT e.id)            AS total_headcount,
    COUNT(*) FILTER (WHERE e.status = 'ACTIVE')       AS active,
    COUNT(*) FILTER (WHERE e.status = 'PROBATIONARY') AS on_probation,
    COUNT(*) FILTER (WHERE e.status = 'ON_LEAVE')     AS on_leave,
    COUNT(*) FILTER (WHERE e.work_arrangement = 'REMOTE') AS remote,
    COUNT(*) FILTER (WHERE e.work_arrangement = 'HYBRID') AS hybrid,
    COUNT(*) FILTER (WHERE e.work_arrangement = 'ONSITE') AS onsite,
    COUNT(*) FILTER (WHERE e.date_hired >= CURRENT_DATE - INTERVAL '30 days') AS new_hires_30d,
    COUNT(*) FILTER (WHERE e.date_separated >= CURRENT_DATE - INTERVAL '30 days') AS separations_30d,
    ROUND(AVG(EXTRACT(EPOCH FROM (CURRENT_DATE - e.date_hired)) / 86400 / 365.25)::NUMERIC, 2) AS avg_tenure_years,
    ROUND(AVG(e.basic_salary)::NUMERIC, 2)           AS avg_salary,
    COUNT(*) FILTER (WHERE a.risk_tier IN ('HIGH','CRITICAL')) AS high_risk_attrition_count
FROM companies c
JOIN employees e ON c.id = e.company_id AND e.is_active = TRUE
LEFT JOIN ai_attrition_scores a ON e.id = a.employee_id
GROUP BY c.name;

-- Open anomaly flags for HR review
CREATE VIEW v_open_anomalies AS
SELECT
    af.id,
    af.module,
    af.anomaly_type,
    e.employee_no,
    e.last_name || ', ' || e.first_name AS full_name,
    d.name          AS department,
    af.entity_date,
    af.anomaly_score,
    af.description,
    af.raw_value,
    af.expected_range,
    af.created_at
FROM ai_anomaly_flags af
LEFT JOIN employees  e  ON af.employee_id  = e.id
LEFT JOIN departments d ON e.department_id = d.id
WHERE af.status = 'OPEN'
ORDER BY af.anomaly_score DESC, af.created_at DESC;

-- ML feature store completeness
CREATE VIEW v_ml_readiness AS
SELECT
    c.name          AS company,
    COUNT(*)        AS total_employees,
    COUNT(*) FILTER (WHERE dq.ml_readiness = TRUE)  AS ml_ready,
    COUNT(*) FILTER (WHERE dq.ml_readiness = FALSE) AS ml_not_ready,
    ROUND(AVG(dq.overall_score) * 100, 1)           AS avg_profile_completeness_pct,
    ROUND(AVG(dq.government_id_score) * 100, 1)     AS avg_govt_id_completeness_pct,
    COUNT(*) FILTER (WHERE mf.employee_id IS NULL)  AS missing_feature_snapshots
FROM companies c
JOIN employees e  ON c.id = e.company_id AND e.is_active = TRUE
LEFT JOIN dq_profile_completeness dq ON e.id = dq.employee_id
LEFT JOIN ml_employee_features    mf ON e.id = mf.employee_id
    AND mf.snapshot_date = CURRENT_DATE
GROUP BY c.name;

-- ================================================================
-- DEFAULT METRIC DEFINITIONS
-- ================================================================
INSERT INTO analytics_metric_definitions
    (metric_code, category, name, description, unit, direction, refresh_frequency, is_ai_derived) VALUES

-- Headcount
('TOTAL_HEADCOUNT',      'HEADCOUNT',    'Total Active Headcount',     'Current active employees',                           'COUNT',      'NEUTRAL',      'DAILY',   FALSE),
('NEW_HIRES_MTD',        'HEADCOUNT',    'New Hires Month-to-Date',    'Employees hired in current month',                   'COUNT',      'NEUTRAL',      'DAILY',   FALSE),
('SEPARATIONS_MTD',      'HEADCOUNT',    'Separations Month-to-Date',  'Employees separated in current month',               'COUNT',      'DOWN_IS_GOOD', 'DAILY',   FALSE),
-- Attrition
('MONTHLY_ATTRITION',    'ATTRITION',    'Monthly Attrition Rate',     'Separations / avg headcount × 100',                  'PERCENTAGE', 'DOWN_IS_GOOD', 'MONTHLY', FALSE),
('HIGH_RISK_ATTRITION',  'ATTRITION',    'High Attrition Risk Count',  'Employees with risk_tier HIGH or CRITICAL (AI)',      'COUNT',      'DOWN_IS_GOOD', 'DAILY',   TRUE),
-- Attendance
('ATTENDANCE_RATE',      'ATTENDANCE',   'Attendance Rate',            'Present days / scheduled days × 100',                'PERCENTAGE', 'UP_IS_GOOD',   'DAILY',   FALSE),
('AVG_DAILY_OT_HOURS',   'ATTENDANCE',   'Avg Daily OT Hours',         'Average overtime hours per employee per day',         'HOURS',      'NEUTRAL',      'DAILY',   FALSE),
-- Leave
('LEAVE_UTILIZATION',    'LEAVE',        'Leave Utilization Rate',     'Used leave days / entitled days × 100',               'PERCENTAGE', 'NEUTRAL',      'MONTHLY', FALSE),
('PENDING_LEAVE_COUNT',  'LEAVE',        'Pending Leave Approvals',    'Leave requests awaiting approval',                    'COUNT',      'DOWN_IS_GOOD', 'DAILY',   FALSE),
-- Payroll
('TOTAL_PAYROLL_COST',   'PAYROLL',      'Total Payroll Cost',         'Total employer payroll cost per period',              'CURRENCY',   'NEUTRAL',      'MONTHLY', FALSE),
('AVG_GROSS_PAY',        'PAYROLL',      'Average Gross Pay',          'Average gross pay per employee per period',           'CURRENCY',   'NEUTRAL',      'MONTHLY', FALSE),
('PAYROLL_ANOMALIES',    'PAYROLL',      'Open Payroll Anomalies',     'Unresolved AI-detected payroll anomalies',            'COUNT',      'DOWN_IS_GOOD', 'DAILY',   TRUE),
-- Performance
('AVG_PERFORMANCE_RATING','PERFORMANCE', 'Avg Performance Rating',     'Average final rating across completed reviews',       'NUMERIC',    'UP_IS_GOOD',   'QUARTERLY',FALSE),
-- Recruitment
('TIME_TO_HIRE',         'RECRUITMENT',  'Average Time to Hire',       'Avg days from application to hire',                  'DAYS',       'DOWN_IS_GOOD', 'MONTHLY', FALSE),
('OFFER_ACCEPTANCE_RATE','RECRUITMENT',  'Offer Acceptance Rate',      'Offers accepted / offers extended × 100',            'PERCENTAGE', 'UP_IS_GOOD',   'MONTHLY', FALSE),
-- Training
('TRAINING_COMPLETION',  'TRAINING',     'Training Completion Rate',   'Completed / enrolled trainings × 100',               'PERCENTAGE', 'UP_IS_GOOD',   'MONTHLY', FALSE);
