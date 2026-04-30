-- ================================================================
-- HCM360 HRIS — 10: LEARNING & DEVELOPMENT SCHEMA (Phase 2)
-- Schema    : learning
-- ================================================================
SET search_path TO learning, core, public;

CREATE TABLE learning.lrn_programs (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES core.companies(id),
    code            VARCHAR(30)  NOT NULL,
    title           VARCHAR(200) NOT NULL,
    description     TEXT,
    category        VARCHAR(50),
    delivery_mode   VARCHAR(30)  NOT NULL DEFAULT 'IN_PERSON',
    duration_hours  NUMERIC(6,2),
    provider        VARCHAR(200),
    cost            NUMERIC(12,2),
    is_mandatory    BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, code)
);

CREATE TABLE learning.lrn_sessions (
    id              BIGSERIAL    PRIMARY KEY,
    program_id      BIGINT       NOT NULL REFERENCES learning.lrn_programs(id),
    session_date    DATE         NOT NULL,
    session_end     DATE,
    venue           VARCHAR(300),
    facilitator     VARCHAR(200),
    max_participants INTEGER,
    status          VARCHAR(20)  NOT NULL DEFAULT 'SCHEDULED',
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE learning.lrn_enrollments (
    id              BIGSERIAL    PRIMARY KEY,
    session_id      BIGINT       NOT NULL REFERENCES learning.lrn_sessions(id),
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    status          VARCHAR(20)  NOT NULL DEFAULT 'ENROLLED',
    completion_date DATE,
    score           NUMERIC(5,2),
    passed          BOOLEAN,
    certificate_path TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (session_id, employee_id)
);

CREATE TABLE learning.lrn_skills (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES core.companies(id),
    code            VARCHAR(30)  NOT NULL,
    name            VARCHAR(100) NOT NULL,
    category        VARCHAR(50),
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE learning.lrn_employee_skills (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    skill_id        BIGINT       NOT NULL REFERENCES learning.lrn_skills(id),
    proficiency     VARCHAR(20)  NOT NULL DEFAULT 'BEGINNER',
    assessed_on     DATE,
    assessed_by     BIGINT       REFERENCES core.users(id),
    UNIQUE (employee_id, skill_id)
);
