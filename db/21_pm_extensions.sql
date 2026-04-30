-- ================================================================
-- HCM360 HRIS — 21: PERFORMANCE MANAGEMENT PHASE 2 EXTENSIONS
-- Schema    : performance
-- Standards : CSC SPMS (Strategic Performance Management System)
--             IPCR / OPCR rating framework
-- ================================================================
SET search_path TO performance, core, workflow, public;

-- ----------------------------------------------------------------
-- Extend perf_cycles with government-specific subtype
-- ----------------------------------------------------------------
ALTER TABLE performance.perf_cycles
    ADD COLUMN IF NOT EXISTS cycle_subtype VARCHAR(20) DEFAULT 'YEAR_END'
        CHECK (cycle_subtype IN ('MID_YEAR', 'YEAR_END'));

-- ----------------------------------------------------------------
-- Extend perf_reviews with government-specific rating fields
-- ----------------------------------------------------------------
ALTER TABLE performance.perf_reviews
    ADD COLUMN IF NOT EXISTS adjectival_rating VARCHAR(30),
    ADD COLUMN IF NOT EXISTS numerical_rating  NUMERIC(3,2),
    ADD COLUMN IF NOT EXISTS approved_at       TIMESTAMPTZ;

-- ----------------------------------------------------------------
-- STRATEGIC PLAN / MFO ALIGNMENT
-- ----------------------------------------------------------------
CREATE TABLE performance.perf_strategic_plans (
    id                      BIGSERIAL    PRIMARY KEY,
    company_id              BIGINT       NOT NULL REFERENCES core.companies(id),
    year                    INTEGER      NOT NULL,
    vision                  TEXT,
    mission                 TEXT,
    strategic_priorities    JSONB        NOT NULL DEFAULT '[]',
    created_by              BIGINT       REFERENCES core.users(id),
    approved_by             BIGINT       REFERENCES core.users(id),
    status                  VARCHAR(20)  NOT NULL DEFAULT 'DRAFT'
                                CHECK (status IN ('DRAFT', 'APPROVED')),
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, year)
);

-- ----------------------------------------------------------------
-- OPCR — Organizational Performance Commitment and Review
-- ----------------------------------------------------------------
CREATE TABLE performance.perf_opcr (
    id                      BIGSERIAL    PRIMARY KEY,
    company_id              BIGINT       NOT NULL REFERENCES core.companies(id),
    department_id           BIGINT       NOT NULL REFERENCES core.departments(id),
    cycle_id                BIGINT       NOT NULL REFERENCES performance.perf_cycles(id),
    mfo_code                VARCHAR(20),
    performance_indicator   TEXT         NOT NULL,
    target                  TEXT,
    target_value            NUMERIC(10,2),
    actual_value            NUMERIC(10,2),
    self_rating             NUMERIC(3,2),
    validated_rating        NUMERIC(3,2),
    adjectival_rating       VARCHAR(30),
    weight                  NUMERIC(5,2) NOT NULL DEFAULT 1.0,
    means_of_verification   TEXT,
    responsible_office      TEXT,
    status                  VARCHAR(20)  NOT NULL DEFAULT 'DRAFT'
                                CHECK (status IN ('DRAFT', 'SUBMITTED', 'RATED', 'APPROVED')),
    workflow_instance_id    BIGINT,
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_opcr_cycle_dept ON performance.perf_opcr(cycle_id, department_id);

-- ----------------------------------------------------------------
-- IPCR — Individual Performance Commitment and Review
-- ----------------------------------------------------------------
CREATE TABLE performance.perf_ipcr (
    id                      BIGSERIAL    PRIMARY KEY,
    employee_id             BIGINT       NOT NULL REFERENCES core.employees(id),
    cycle_id                BIGINT       NOT NULL REFERENCES performance.perf_cycles(id),
    opcr_id                 BIGINT       REFERENCES performance.perf_opcr(id),
    function_type           VARCHAR(20)  NOT NULL DEFAULT 'CORE'
                                CHECK (function_type IN ('CORE', 'SUPPORT', 'STRATEGIC')),
    performance_indicator   TEXT         NOT NULL,
    target                  TEXT,
    target_value            NUMERIC(10,2),
    actual_value            NUMERIC(10,2),
    quality_rating          NUMERIC(3,2),    -- Q
    efficiency_rating       NUMERIC(3,2),    -- E
    timeliness_rating       NUMERIC(3,2),    -- T
    average_rating          NUMERIC(3,2) GENERATED ALWAYS AS (
                                ROUND((COALESCE(quality_rating,0)
                                     + COALESCE(efficiency_rating,0)
                                     + COALESCE(timeliness_rating,0)) / 3.0, 2)
                            ) STORED,
    weight                  NUMERIC(5,2) NOT NULL DEFAULT 1.0,
    means_of_verification   TEXT,
    supporting_docs_path    VARCHAR(500),
    evaluator_id            BIGINT       REFERENCES core.employees(id),
    status                  VARCHAR(20)  NOT NULL DEFAULT 'DRAFT'
                                CHECK (status IN ('DRAFT', 'SUBMITTED', 'EVALUATED', 'APPROVED')),
    workflow_instance_id    BIGINT,
    period_start            DATE,
    period_end              DATE,
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ipcr_employee_cycle ON performance.perf_ipcr(employee_id, cycle_id);
CREATE INDEX idx_ipcr_evaluator      ON performance.perf_ipcr(evaluator_id);

-- ----------------------------------------------------------------
-- IPCR SUMMARY (final computed rating per employee per cycle)
-- ----------------------------------------------------------------
CREATE TABLE performance.perf_ipcr_summary (
    id                          BIGSERIAL    PRIMARY KEY,
    employee_id                 BIGINT       NOT NULL REFERENCES core.employees(id),
    cycle_id                    BIGINT       NOT NULL REFERENCES performance.perf_cycles(id),
    final_numerical_rating      NUMERIC(3,2),
    adjectival_rating           VARCHAR(30),
    evaluator_comments          TEXT,
    employee_comments           TEXT,
    approved_by                 BIGINT       REFERENCES core.users(id),
    approved_at                 TIMESTAMPTZ,
    pbb_eligible                BOOLEAN      NOT NULL DEFAULT FALSE,
    step_increment_eligible     BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at                  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (employee_id, cycle_id)
);

CREATE INDEX idx_ipcr_summary_pbb ON performance.perf_ipcr_summary(pbb_eligible)
    WHERE pbb_eligible = TRUE;

-- ----------------------------------------------------------------
-- SUCCESSION PLANNING MATRIX
-- ----------------------------------------------------------------
CREATE TABLE performance.perf_succession_matrix (
    id                      BIGSERIAL    PRIMARY KEY,
    key_position_id         BIGINT       NOT NULL REFERENCES core.positions(id),
    successor_employee_id   BIGINT       NOT NULL REFERENCES core.employees(id),
    readiness               VARCHAR(20)  NOT NULL DEFAULT 'LONG_TERM'
                                CHECK (readiness IN ('READY_NOW', 'READY_1_2YR', 'READY_3_5YR', 'LONG_TERM')),
    development_needs       TEXT,
    assessed_on             DATE         NOT NULL DEFAULT CURRENT_DATE,
    assessed_by             BIGINT       REFERENCES core.users(id),
    cycle_id                BIGINT       REFERENCES performance.perf_cycles(id),
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (key_position_id, successor_employee_id)
);

-- ================================================================
-- SEED: WORKFLOW DEFINITIONS FOR PM
-- ================================================================
INSERT INTO workflow.workflow_definitions (code, name, module, description) VALUES
    ('PM_IPCR_APPROVAL',
     'IPCR Rating Approval',
     'pm',
     'IPCR submitted by employee → Supervisor evaluates (Q/E/T) → HR validates → Head of Office approves'),
    ('PM_OPCR_APPROVAL',
     'OPCR Rating Approval',
     'pm',
     'OPCR submitted by office → PMT validates → Head of Office approves')
ON CONFLICT (code) DO NOTHING;

-- IPCR Approval steps
WITH wf AS (SELECT id FROM workflow.workflow_definitions WHERE code = 'PM_IPCR_APPROVAL')
INSERT INTO workflow.workflow_steps (workflow_id, step_order, code, name, role_required, sla_hours, is_final)
SELECT wf.id, s.step_order, s.code, s.name, s.role, s.sla_hours, s.is_final
FROM wf, (VALUES
    (1, 'PM_IPCR_SUBMIT',    'Employee Submission',   'EMPLOYEE',    0,   FALSE),
    (2, 'PM_IPCR_EVALUATE',  'Supervisor Evaluation', 'DEPT_HEAD',   72,  FALSE),
    (3, 'PM_IPCR_HR_VALID',  'HR Validation',         'HR_ADMIN',    48,  FALSE),
    (4, 'PM_IPCR_APPROVE',   'Head of Office Approval','SUPER_ADMIN', 72,  TRUE)
) AS s(step_order, code, name, role, sla_hours, is_final)
ON CONFLICT DO NOTHING;

-- ================================================================
-- SEED: PM PAGE REGISTRY
-- ================================================================
INSERT INTO core.page_registry
    (path, title, nav_group, nav_label, module, nav_icon, nav_order, requires_feature)
VALUES
    ('/pm/cycles',     'Performance Cycles',   'Performance', 'Cycles',     'pm', '🔄', 10, 'PERFORMANCE'),
    ('/pm/opcr',       'OPCR Dashboard',       'Performance', 'OPCR',       'pm', '🏢', 20, 'PERFORMANCE'),
    ('/pm/ipcr',       'IPCR Management',      'Performance', 'IPCR',       'pm', '📝', 30, 'PERFORMANCE'),
    ('/pm/ratings',    'Rating Distribution',  'Performance', 'Ratings',    'pm', '📊', 40, 'PERFORMANCE'),
    ('/pm/succession', 'Succession Planning',  'Performance', 'Succession', 'pm', '🎯', 50, 'PERFORMANCE')
ON CONFLICT (path) DO NOTHING;

-- ================================================================
-- SEED: FEATURE FLAG
-- ================================================================
INSERT INTO core.feature_registry (code, name, description, module, is_enabled) VALUES
    ('PERFORMANCE', 'Performance Management', 'IPCR/OPCR – Individual & Office Performance', 'pm', TRUE)
ON CONFLICT (code) DO NOTHING;
