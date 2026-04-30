-- ================================================================
-- HCM360 HRIS — 11: REWARDS & RECOGNITION SCHEMA (Phase 2)
-- Schema    : rewards
-- ================================================================
SET search_path TO rewards, core, public;

CREATE TABLE rewards.rwd_categories (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES core.companies(id),
    code            VARCHAR(30)  NOT NULL,
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    award_type      VARCHAR(30)  NOT NULL DEFAULT 'NON_MONETARY',
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE rewards.rwd_nominations (
    id                    BIGSERIAL    PRIMARY KEY,
    category_id           BIGINT       NOT NULL REFERENCES rewards.rwd_categories(id),
    nominee_employee_id   BIGINT       NOT NULL REFERENCES core.employees(id),
    nominated_by          BIGINT       NOT NULL REFERENCES core.users(id),
    period                VARCHAR(30)  NOT NULL,
    justification         TEXT         NOT NULL,
    status                VARCHAR(30)  NOT NULL DEFAULT 'PENDING',
    workflow_instance_id  BIGINT,
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE rewards.rwd_awards (
    id              BIGSERIAL    PRIMARY KEY,
    nomination_id   BIGINT       REFERENCES rewards.rwd_nominations(id),
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    category_id     BIGINT       NOT NULL REFERENCES rewards.rwd_categories(id),
    awarded_on      DATE         NOT NULL DEFAULT CURRENT_DATE,
    award_value     NUMERIC(12,2),
    certificate_path TEXT,
    announced_via   VARCHAR(50),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE rewards.rwd_retirement_plans (
    id                        BIGSERIAL    PRIMARY KEY,
    employee_id               BIGINT       NOT NULL REFERENCES core.employees(id) UNIQUE,
    projected_retirement_date DATE,
    retirement_status         VARCHAR(30)  NOT NULL DEFAULT 'ACTIVE',
    remarks                   TEXT,
    updated_by                BIGINT       REFERENCES core.users(id),
    updated_at                TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
