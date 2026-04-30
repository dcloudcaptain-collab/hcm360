-- ================================================================
-- HCM360 HRIS — 11: BENEFITS ADMINISTRATION SCHEMA
-- Schema    : benefits
-- Contains  : plans, enrollments, life events, enrollment windows
-- ================================================================

SET search_path TO benefits, core, public;

CREATE SCHEMA IF NOT EXISTS benefits;

-- ── Plan Types ────────────────────────────────────────────────

CREATE TABLE benefits.plan_types (
    id              BIGSERIAL    PRIMARY KEY,
    name            VARCHAR(100) NOT NULL UNIQUE,
    category        VARCHAR(50)  NOT NULL,
    code            VARCHAR(30)  NOT NULL UNIQUE,
    description     TEXT,
    sort_order      INTEGER      NOT NULL DEFAULT 999,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── Plans ─────────────────────────────────────────────────────

CREATE TABLE benefits.plans (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES core.companies(id),
    plan_type_id    BIGINT       NOT NULL REFERENCES benefits.plan_types(id),
    code            VARCHAR(50)  NOT NULL,
    name            VARCHAR(150) NOT NULL,
    description     TEXT,
    provider        VARCHAR(100),
    coverage_level  VARCHAR(30)  NOT NULL DEFAULT 'INDIVIDUAL',
    employer_cost   NUMERIC(12,2) NOT NULL DEFAULT 0,
    employee_cost   NUMERIC(12,2) NOT NULL DEFAULT 0,
    plan_details    JSONB,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, code)
);

-- ── Enrollment Windows ────────────────────────────────────────

CREATE TABLE benefits.enrollment_windows (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES core.companies(id),
    name            VARCHAR(150) NOT NULL,
    year            INTEGER      NOT NULL,
    open_date       DATE         NOT NULL,
    close_date      DATE         NOT NULL,
    effective_date  DATE         NOT NULL,
    status          VARCHAR(20)  NOT NULL DEFAULT 'DRAFT',
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, year)
);

-- ── Enrollments ───────────────────────────────────────────────

CREATE TABLE benefits.enrollments (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id),
    plan_id             BIGINT       NOT NULL REFERENCES benefits.plans(id),
    window_id           BIGINT       REFERENCES benefits.enrollment_windows(id),
    coverage_level      VARCHAR(30)  NOT NULL DEFAULT 'INDIVIDUAL',
    employee_cost       NUMERIC(12,2) NOT NULL DEFAULT 0,
    employer_cost       NUMERIC(12,2) NOT NULL DEFAULT 0,
    status              VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',
    waived_reason       TEXT,
    effective_from      DATE         NOT NULL,
    effective_to        DATE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (employee_id, plan_id, effective_from)
);

CREATE INDEX idx_enrollments_emp ON benefits.enrollments(employee_id, status);
CREATE INDEX idx_enrollments_plan ON benefits.enrollments(plan_id, status);

-- ── Enrollment Dependents ─────────────────────────────────────

CREATE TABLE benefits.enrollment_dependents (
    id              BIGSERIAL    PRIMARY KEY,
    enrollment_id   BIGINT       NOT NULL REFERENCES benefits.enrollments(id) ON DELETE CASCADE,
    dependent_name  VARCHAR(150) NOT NULL,
    relationship    VARCHAR(30)  NOT NULL,
    date_of_birth   DATE,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── Life Events ───────────────────────────────────────────────

CREATE TABLE benefits.life_events (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    event_type      VARCHAR(50)  NOT NULL,
    event_date      DATE         NOT NULL,
    description     TEXT,
    status          VARCHAR(20)  NOT NULL DEFAULT 'OPEN',
    processed_by    BIGINT       REFERENCES core.users(id),
    processed_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (employee_id, event_type, event_date)
);

CREATE INDEX idx_life_events_emp ON benefits.life_events(employee_id, status);

-- ── Change Log ────────────────────────────────────────────────

CREATE TABLE benefits.change_log (
    id              BIGSERIAL    PRIMARY KEY,
    enrollment_id   BIGINT       REFERENCES benefits.enrollments(id),
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    change_type     VARCHAR(30)  NOT NULL,
    old_plan_id     BIGINT       REFERENCES benefits.plans(id),
    new_plan_id     BIGINT       REFERENCES benefits.plans(id),
    reason          TEXT,
    changed_by      BIGINT       REFERENCES core.users(id),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_changelog_emp ON benefits.change_log(employee_id);
