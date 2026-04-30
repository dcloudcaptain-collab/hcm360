-- ================================================================
-- HCM360 HRIS — 31: HEALTH & SAFETY
-- Schema    : health
-- Standards : DOLE DO 198-18 (OSH Standards), RA 11058 (OSH Act)
-- ================================================================

CREATE SCHEMA IF NOT EXISTS health;
SET search_path TO health, core, workflow, public;

-- ----------------------------------------------------------------
-- MEDICAL RECORDS (master per employee)
-- ----------------------------------------------------------------
CREATE TABLE health.medical_records (
    id                      BIGSERIAL    PRIMARY KEY,
    employee_id             BIGINT       NOT NULL REFERENCES core.employees(id) UNIQUE,
    blood_type              VARCHAR(5),
    allergies               TEXT,
    chronic_conditions      TEXT,
    medications             TEXT,
    emergency_medical_notes TEXT,
    last_updated_by         BIGINT       REFERENCES core.users(id),
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------
-- ANNUAL PE SCHEDULES
-- ----------------------------------------------------------------
CREATE TABLE health.pe_schedules (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES core.companies(id),
    year            INTEGER      NOT NULL,
    title           VARCHAR(200) NOT NULL,
    provider_name   VARCHAR(200),
    scheduled_from  DATE         NOT NULL,
    scheduled_to    DATE         NOT NULL,
    venue           VARCHAR(200),
    status          VARCHAR(20)  NOT NULL DEFAULT 'SCHEDULED'
                        CHECK (status IN ('SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
    created_by      BIGINT       REFERENCES core.users(id),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, year)
);

-- ----------------------------------------------------------------
-- PE RESULTS (individual)
-- ----------------------------------------------------------------
CREATE TABLE health.pe_results (
    id                      BIGSERIAL    PRIMARY KEY,
    schedule_id             BIGINT       NOT NULL REFERENCES health.pe_schedules(id),
    employee_id             BIGINT       NOT NULL REFERENCES core.employees(id),
    exam_date               DATE,
    overall_result          VARCHAR(30)  NOT NULL DEFAULT 'PENDING'
                                CHECK (overall_result IN ('PENDING', 'FIT', 'UNFIT', 'CONDITIONAL', 'NO_SHOW')),
    findings                TEXT,
    recommendations         TEXT,
    follow_up_required      BOOLEAN      NOT NULL DEFAULT FALSE,
    follow_up_date          DATE,
    examining_physician     VARCHAR(200),
    result_document_id      BIGINT       REFERENCES core.documents(id),
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (schedule_id, employee_id)
);

CREATE INDEX idx_pe_results_emp ON health.pe_results(employee_id);

-- ----------------------------------------------------------------
-- HEALTH CERTIFICATES (expiry tracking)
-- ----------------------------------------------------------------
CREATE TABLE health.health_certificates (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id),
    certificate_type    VARCHAR(60)  NOT NULL,
    issued_date         DATE         NOT NULL,
    expiry_date         DATE,
    issuing_authority   VARCHAR(200),
    document_id         BIGINT       REFERENCES core.documents(id),
    status              VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE'
                            CHECK (status IN ('ACTIVE', 'EXPIRED', 'REVOKED')),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_health_certs_emp    ON health.health_certificates(employee_id, status);
CREATE INDEX idx_health_certs_expiry ON health.health_certificates(expiry_date)
    WHERE status = 'ACTIVE';

-- ----------------------------------------------------------------
-- WORKPLACE INCIDENTS (DOLE compliance)
-- ----------------------------------------------------------------
CREATE TABLE health.incidents (
    id                  BIGSERIAL    PRIMARY KEY,
    company_id          BIGINT       NOT NULL REFERENCES core.companies(id),
    incident_no         VARCHAR(40)  NOT NULL UNIQUE,
    incident_date       TIMESTAMPTZ  NOT NULL,
    location            VARCHAR(200) NOT NULL,
    incident_type       VARCHAR(40)  NOT NULL
                            CHECK (incident_type IN ('INJURY', 'ILLNESS', 'NEAR_MISS', 'PROPERTY_DAMAGE', 'ENVIRONMENTAL', 'OTHER')),
    severity            VARCHAR(20)  NOT NULL DEFAULT 'MINOR'
                            CHECK (severity IN ('MINOR', 'MODERATE', 'MAJOR', 'FATAL')),
    description         TEXT         NOT NULL,
    immediate_action_taken TEXT,
    reported_by         BIGINT       NOT NULL REFERENCES core.users(id),
    reported_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    status              VARCHAR(20)  NOT NULL DEFAULT 'REPORTED'
                            CHECK (status IN ('REPORTED', 'INVESTIGATING', 'RESOLVED', 'CLOSED')),
    dole_reportable     BOOLEAN      NOT NULL DEFAULT FALSE,
    dole_reported_at    TIMESTAMPTZ,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_incidents_company ON health.incidents(company_id, status);
CREATE INDEX idx_incidents_date    ON health.incidents(incident_date);

-- ----------------------------------------------------------------
-- INCIDENT PERSONS
-- ----------------------------------------------------------------
CREATE TABLE health.incident_persons (
    id                  BIGSERIAL    PRIMARY KEY,
    incident_id         BIGINT       NOT NULL REFERENCES health.incidents(id) ON DELETE CASCADE,
    employee_id         BIGINT       REFERENCES core.employees(id),
    person_name         VARCHAR(200),
    role                VARCHAR(30)  NOT NULL DEFAULT 'INJURED'
                            CHECK (role IN ('INJURED', 'WITNESS', 'FIRST_RESPONDER', 'SUPERVISOR')),
    injury_type         VARCHAR(100),
    body_part_affected  VARCHAR(100),
    treatment_given     TEXT,
    days_lost           INTEGER      NOT NULL DEFAULT 0,
    hospitalized        BOOLEAN      NOT NULL DEFAULT FALSE
);

-- ----------------------------------------------------------------
-- INCIDENT INVESTIGATIONS
-- ----------------------------------------------------------------
CREATE TABLE health.incident_investigations (
    id                      BIGSERIAL    PRIMARY KEY,
    incident_id             BIGINT       NOT NULL REFERENCES health.incidents(id) ON DELETE CASCADE,
    investigator_id         BIGINT       NOT NULL REFERENCES core.users(id),
    investigation_date      DATE         NOT NULL,
    root_cause              TEXT,
    contributing_factors    TEXT,
    corrective_actions      TEXT,
    preventive_actions      TEXT,
    target_completion_date  DATE,
    status                  VARCHAR(20)  NOT NULL DEFAULT 'IN_PROGRESS'
                                CHECK (status IN ('IN_PROGRESS', 'COMPLETED', 'VERIFIED')),
    completed_at            TIMESTAMPTZ,
    report_path             TEXT
);

-- ----------------------------------------------------------------
-- WELLNESS PROGRAMS
-- ----------------------------------------------------------------
CREATE TABLE health.wellness_programs (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES core.companies(id),
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    program_type    VARCHAR(40)  NOT NULL
                        CHECK (program_type IN ('MENTAL_HEALTH', 'FITNESS', 'NUTRITION', 'VACCINATION', 'SCREENING', 'SEMINAR')),
    start_date      DATE,
    end_date        DATE,
    provider        VARCHAR(200),
    max_participants INTEGER,
    status          VARCHAR(20)  NOT NULL DEFAULT 'PLANNED'
                        CHECK (status IN ('PLANNED', 'ACTIVE', 'COMPLETED', 'CANCELLED')),
    created_by      BIGINT       REFERENCES core.users(id),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE health.wellness_enrollments (
    id              BIGSERIAL    PRIMARY KEY,
    program_id      BIGINT       NOT NULL REFERENCES health.wellness_programs(id) ON DELETE CASCADE,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    enrolled_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    status          VARCHAR(20)  NOT NULL DEFAULT 'ENROLLED'
                        CHECK (status IN ('ENROLLED', 'COMPLETED', 'WITHDRAWN', 'NO_SHOW')),
    completed_at    TIMESTAMPTZ,
    feedback        TEXT,
    UNIQUE (program_id, employee_id)
);

CREATE INDEX idx_wellness_enroll ON health.wellness_enrollments(employee_id);

-- ================================================================
-- SEED: PAGE REGISTRY
-- ================================================================
INSERT INTO core.page_registry
    (path, title, nav_group, nav_label, module, nav_icon, nav_order, requires_feature)
VALUES
    ('/health/',             'Health Dashboard',     'Health', 'Dashboard',     'health', '🏥', 10, 'HEALTH'),
    ('/health/pe',           'Annual PE',            'Health', 'Physical Exam', 'health', '🩺', 20, 'HEALTH'),
    ('/health/certificates', 'Health Certificates',  'Health', 'Certificates',  'health', '📋', 30, 'HEALTH'),
    ('/health/incidents',    'Incident Reports',     'Health', 'Incidents',     'health', '⚠️', 40, 'HEALTH'),
    ('/health/wellness',     'Wellness Programs',    'Health', 'Wellness',      'health', '💪', 50, 'HEALTH')
ON CONFLICT (path) DO NOTHING;

-- ================================================================
-- SEED: FEATURE FLAG
-- ================================================================
INSERT INTO core.feature_registry (code, name, description, module, is_enabled) VALUES
    ('HEALTH', 'Health & Safety', 'Occupational health, PE, incidents, wellness', 'health', TRUE)
ON CONFLICT (code) DO NOTHING;
