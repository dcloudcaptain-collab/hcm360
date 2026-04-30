-- ================================================================
-- HCM360 HRIS — 30: GRIEVANCE & DISCIPLINE
-- Schema    : discipline
-- Standards : CSC RRACA (Revised Rules on Administrative Cases),
--             CSC Resolution No. 1701077
-- ================================================================

CREATE SCHEMA IF NOT EXISTS discipline;
SET search_path TO discipline, core, workflow, public;

-- ----------------------------------------------------------------
-- CASE TYPES (CSC offense classification)
-- ----------------------------------------------------------------
CREATE TABLE discipline.case_types (
    id              BIGSERIAL    PRIMARY KEY,
    code            VARCHAR(40)  NOT NULL UNIQUE,
    name            VARCHAR(200) NOT NULL,
    gravity         VARCHAR(20)  NOT NULL
                        CHECK (gravity IN ('LIGHT', 'LESS_GRAVE', 'GRAVE')),
    description     TEXT,
    legal_basis     VARCHAR(200),
    default_penalty VARCHAR(40),
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------
-- ADMINISTRATIVE CASES
-- ----------------------------------------------------------------
CREATE TABLE discipline.cases (
    id                      BIGSERIAL    PRIMARY KEY,
    company_id              BIGINT       NOT NULL REFERENCES core.companies(id),
    case_no                 VARCHAR(40)  NOT NULL UNIQUE,
    respondent_id           BIGINT       NOT NULL REFERENCES core.employees(id),
    complainant_id          BIGINT       REFERENCES core.employees(id),
    case_type_id            BIGINT       NOT NULL REFERENCES discipline.case_types(id),
    offense_description     TEXT         NOT NULL,
    date_of_offense         DATE,
    date_filed              DATE         NOT NULL DEFAULT CURRENT_DATE,
    status                  VARCHAR(30)  NOT NULL DEFAULT 'COMPLAINT_FILED'
                                CHECK (status IN (
                                    'COMPLAINT_FILED', 'PRELIMINARY_INVESTIGATION',
                                    'FORMAL_CHARGE', 'PREVENTIVE_SUSPENSION',
                                    'HEARING', 'DECISION', 'APPEAL', 'CLOSED', 'DISMISSED')),
    gravity                 VARCHAR(20),
    is_confidential         BOOLEAN      NOT NULL DEFAULT TRUE,
    assigned_to             BIGINT       REFERENCES core.users(id),
    workflow_instance_id    BIGINT,
    created_by              BIGINT       NOT NULL REFERENCES core.users(id),
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_disc_cases_respondent ON discipline.cases(respondent_id, status);
CREATE INDEX idx_disc_cases_company    ON discipline.cases(company_id, status);

-- ----------------------------------------------------------------
-- COMPLAINTS
-- ----------------------------------------------------------------
CREATE TABLE discipline.complaints (
    id                  BIGSERIAL    PRIMARY KEY,
    case_id             BIGINT       NOT NULL REFERENCES discipline.cases(id) ON DELETE CASCADE,
    complaint_text      TEXT         NOT NULL,
    evidence_summary    TEXT,
    supporting_docs     JSONB        NOT NULL DEFAULT '[]',
    sworn_statement_path TEXT,
    filed_by            BIGINT       NOT NULL REFERENCES core.users(id),
    filed_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------
-- INVESTIGATIONS
-- ----------------------------------------------------------------
CREATE TABLE discipline.investigations (
    id                  BIGSERIAL    PRIMARY KEY,
    case_id             BIGINT       NOT NULL REFERENCES discipline.cases(id) ON DELETE CASCADE,
    investigator_id     BIGINT       NOT NULL REFERENCES core.users(id),
    started_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    completed_at        TIMESTAMPTZ,
    findings            TEXT,
    recommendation      VARCHAR(30)
                            CHECK (recommendation IN ('PROCEED_FORMAL_CHARGE', 'DISMISS', 'MEDIATE')),
    report_path         TEXT,
    status              VARCHAR(20)  NOT NULL DEFAULT 'IN_PROGRESS'
                            CHECK (status IN ('IN_PROGRESS', 'COMPLETED', 'DEFERRED'))
);

-- ----------------------------------------------------------------
-- FORMAL CHARGES
-- ----------------------------------------------------------------
CREATE TABLE discipline.formal_charges (
    id                      BIGSERIAL    PRIMARY KEY,
    case_id                 BIGINT       NOT NULL REFERENCES discipline.cases(id) ON DELETE CASCADE,
    charge_text             TEXT         NOT NULL,
    offense_classification  VARCHAR(60),
    charge_date             DATE         NOT NULL DEFAULT CURRENT_DATE,
    answer_deadline         DATE         NOT NULL,
    answer_received_at      TIMESTAMPTZ,
    answer_text             TEXT,
    issued_by               BIGINT       NOT NULL REFERENCES core.users(id),
    document_path           TEXT
);

-- ----------------------------------------------------------------
-- PREVENTIVE SUSPENSIONS (max 90 days per RRACA Sec. 24)
-- ----------------------------------------------------------------
CREATE TABLE discipline.preventive_suspensions (
    id              BIGSERIAL    PRIMARY KEY,
    case_id         BIGINT       NOT NULL REFERENCES discipline.cases(id) ON DELETE CASCADE,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    start_date      DATE         NOT NULL,
    end_date        DATE         NOT NULL,
    reason          TEXT         NOT NULL,
    order_path      TEXT,
    approved_by     BIGINT       REFERENCES core.users(id),
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_max_90_days CHECK (end_date - start_date <= 90)
);

CREATE INDEX idx_disc_prev_susp ON discipline.preventive_suspensions(employee_id, is_active);

-- ----------------------------------------------------------------
-- HEARINGS
-- ----------------------------------------------------------------
CREATE TABLE discipline.hearings (
    id                      BIGSERIAL    PRIMARY KEY,
    case_id                 BIGINT       NOT NULL REFERENCES discipline.cases(id) ON DELETE CASCADE,
    hearing_type            VARCHAR(30)  NOT NULL DEFAULT 'FORMAL'
                                CHECK (hearing_type IN ('FORMAL', 'CLARIFICATORY', 'PRE_HEARING')),
    scheduled_date          TIMESTAMPTZ  NOT NULL,
    actual_date             TIMESTAMPTZ,
    venue                   VARCHAR(200),
    presiding_officer_id    BIGINT       REFERENCES core.users(id),
    minutes_text            TEXT,
    minutes_path            TEXT,
    attendees               JSONB        NOT NULL DEFAULT '[]',
    status                  VARCHAR(20)  NOT NULL DEFAULT 'SCHEDULED'
                                CHECK (status IN ('SCHEDULED', 'COMPLETED', 'POSTPONED', 'CANCELLED')),
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_disc_hearings_date ON discipline.hearings(scheduled_date, status);

-- ----------------------------------------------------------------
-- DECISIONS
-- ----------------------------------------------------------------
CREATE TABLE discipline.decisions (
    id                  BIGSERIAL    PRIMARY KEY,
    case_id             BIGINT       NOT NULL REFERENCES discipline.cases(id) ON DELETE CASCADE,
    decision_date       DATE         NOT NULL,
    verdict             VARCHAR(30)  NOT NULL
                            CHECK (verdict IN ('GUILTY', 'NOT_GUILTY', 'DISMISSED', 'WITHDRAWN')),
    penalty             VARCHAR(40),
    penalty_details     TEXT,
    suspension_days     INTEGER,
    decision_text       TEXT         NOT NULL,
    decision_path       TEXT,
    decided_by          BIGINT       NOT NULL REFERENCES core.users(id),
    effectivity_date    DATE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------
-- APPEALS
-- ----------------------------------------------------------------
CREATE TABLE discipline.appeals (
    id              BIGSERIAL    PRIMARY KEY,
    case_id         BIGINT       NOT NULL REFERENCES discipline.cases(id) ON DELETE CASCADE,
    decision_id     BIGINT       NOT NULL REFERENCES discipline.decisions(id),
    appeal_date     DATE         NOT NULL,
    appeal_body     VARCHAR(60)  NOT NULL DEFAULT 'CSC_REGIONAL'
                        CHECK (appeal_body IN ('CSC_REGIONAL', 'CSC_CENTRAL', 'COURT_OF_APPEALS', 'SUPREME_COURT')),
    grounds         TEXT         NOT NULL,
    status          VARCHAR(20)  NOT NULL DEFAULT 'FILED'
                        CHECK (status IN ('FILED', 'UNDER_REVIEW', 'RESOLVED', 'DISMISSED')),
    resolution      TEXT,
    resolution_date DATE,
    document_path   TEXT,
    filed_by        BIGINT       NOT NULL REFERENCES core.users(id),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ================================================================
-- SEED: PAGE REGISTRY
-- ================================================================
INSERT INTO core.page_registry
    (path, title, nav_group, nav_label, module, nav_icon, nav_order, requires_feature)
VALUES
    ('/discipline/',           'Admin Cases Dashboard', 'Discipline', 'Dashboard', 'discipline', '⚖️', 10, 'DISCIPLINE'),
    ('/discipline/cases/new',  'File New Case',         'Discipline', 'New Case',  'discipline', '📝', 20, 'DISCIPLINE')
ON CONFLICT (path) DO NOTHING;

-- ================================================================
-- SEED: FEATURE FLAG
-- ================================================================
INSERT INTO core.feature_registry (code, name, description, module, is_enabled) VALUES
    ('DISCIPLINE', 'Grievance & Discipline', 'Administrative cases per CSC RRACA', 'discipline', TRUE)
ON CONFLICT (code) DO NOTHING;
