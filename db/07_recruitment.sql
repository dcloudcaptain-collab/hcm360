-- ================================================================
-- HCM360 HRIS — 07: RECRUITMENT SCHEMA (Phase 2)
-- Schema    : recruitment
-- ================================================================
SET search_path TO recruitment, core, public;

CREATE TABLE recruitment.rec_requisitions (
    id                  BIGSERIAL    PRIMARY KEY,
    company_id          BIGINT       NOT NULL REFERENCES core.companies(id),
    reference_no        VARCHAR(40)  UNIQUE NOT NULL,
    department_id       BIGINT       REFERENCES core.departments(id),
    position_id         BIGINT       REFERENCES core.positions(id),
    headcount           INTEGER      NOT NULL DEFAULT 1,
    justification       TEXT,
    status              VARCHAR(30)  NOT NULL DEFAULT 'DRAFT',
    workflow_instance_id BIGINT,
    requested_by        BIGINT       REFERENCES core.users(id),
    approved_by         BIGINT       REFERENCES core.users(id),
    target_hire_date    DATE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE recruitment.rec_job_postings (
    id              BIGSERIAL    PRIMARY KEY,
    requisition_id  BIGINT       REFERENCES recruitment.rec_requisitions(id),
    title           VARCHAR(200) NOT NULL,
    description     TEXT,
    requirements    TEXT,
    employment_type VARCHAR(30),
    salary_range    VARCHAR(100),
    location        VARCHAR(200),
    posted_on       DATE,
    closed_on       DATE,
    status          VARCHAR(20)  NOT NULL DEFAULT 'DRAFT',
    is_internal     BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE recruitment.rec_applicants (
    id              BIGSERIAL    PRIMARY KEY,
    posting_id      BIGINT       REFERENCES recruitment.rec_job_postings(id),
    first_name      VARCHAR(100) NOT NULL,
    last_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(200),
    mobile_no       VARCHAR(20),
    resume_path     TEXT,
    stage           VARCHAR(30)  NOT NULL DEFAULT 'APPLIED',
    source          VARCHAR(50),
    score           NUMERIC(4,2),
    remarks         TEXT,
    hired_as_employee_id BIGINT REFERENCES core.employees(id),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE recruitment.rec_interview_schedules (
    id              BIGSERIAL    PRIMARY KEY,
    applicant_id    BIGINT       NOT NULL REFERENCES recruitment.rec_applicants(id),
    interviewer_id  BIGINT       REFERENCES core.users(id),
    scheduled_at    TIMESTAMPTZ  NOT NULL,
    interview_type  VARCHAR(30)  NOT NULL DEFAULT 'INITIAL',
    location        VARCHAR(200),
    notes           TEXT,
    outcome         VARCHAR(30),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE recruitment.rec_offers (
    id              BIGSERIAL    PRIMARY KEY,
    applicant_id    BIGINT       NOT NULL REFERENCES recruitment.rec_applicants(id),
    offered_salary  NUMERIC(14,2),
    position_id     BIGINT       REFERENCES core.positions(id),
    start_date      DATE,
    offer_date      DATE,
    expiry_date     DATE,
    status          VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    accepted_at     TIMESTAMPTZ,
    declined_reason TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
