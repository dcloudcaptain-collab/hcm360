-- ================================================================
-- HCM360 HRIS — 09: PERFORMANCE SCHEMA (Phase 2)
-- Schema    : performance
-- ================================================================
SET search_path TO performance, core, public;

CREATE TABLE performance.perf_cycles (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES core.companies(id),
    name            VARCHAR(200) NOT NULL,
    cycle_type      VARCHAR(20)  NOT NULL DEFAULT 'ANNUAL',
    period_from     DATE         NOT NULL,
    period_to       DATE         NOT NULL,
    status          VARCHAR(20)  NOT NULL DEFAULT 'PLANNING',
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE performance.perf_competencies (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES core.companies(id),
    code            VARCHAR(30)  NOT NULL,
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    weight          NUMERIC(4,2) NOT NULL DEFAULT 1.0,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE performance.perf_employee_kpis (
    id              BIGSERIAL    PRIMARY KEY,
    cycle_id        BIGINT       NOT NULL REFERENCES performance.perf_cycles(id),
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    kpi_name        VARCHAR(200) NOT NULL,
    description     TEXT,
    target_value    NUMERIC(10,2),
    actual_value    NUMERIC(10,2),
    weight          NUMERIC(4,2) NOT NULL DEFAULT 1.0,
    score           NUMERIC(4,2),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE performance.perf_reviews (
    id              BIGSERIAL    PRIMARY KEY,
    cycle_id        BIGINT       NOT NULL REFERENCES performance.perf_cycles(id),
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    reviewer_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    status          VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    self_score      NUMERIC(4,2),
    manager_score   NUMERIC(4,2),
    final_score     NUMERIC(4,2),
    self_comments   TEXT,
    manager_comments TEXT,
    workflow_instance_id BIGINT,
    submitted_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (cycle_id, employee_id, reviewer_id)
);

CREATE TABLE performance.perf_idp_plans (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    cycle_id        BIGINT       REFERENCES performance.perf_cycles(id),
    development_goal TEXT        NOT NULL,
    action_steps    TEXT,
    target_date     DATE,
    status          VARCHAR(20)  NOT NULL DEFAULT 'IN_PROGRESS',
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
