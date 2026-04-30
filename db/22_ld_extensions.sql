-- ================================================================
-- HCM360 HRIS — 22: LEARNING & DEVELOPMENT PHASE 2 EXTENSIONS
-- Schema    : learning
-- Features  : LSP registry, TNA, IDP actions, scholarships,
--             geo-tagged mobile attendance, Narrative Report Form
-- ================================================================
SET search_path TO learning, performance, core, workflow, public;

-- ----------------------------------------------------------------
-- Extend lrn_programs with CSC accreditation + LSP link
-- ----------------------------------------------------------------
ALTER TABLE learning.lrn_programs
    ADD COLUMN IF NOT EXISTS lsp_id           BIGINT,
    ADD COLUMN IF NOT EXISTS tna_basis        VARCHAR(100),
    ADD COLUMN IF NOT EXISTS csc_accredited   BOOLEAN NOT NULL DEFAULT FALSE;

-- ----------------------------------------------------------------
-- Extend lrn_enrollments with attendance % and NRF link
-- ----------------------------------------------------------------
ALTER TABLE learning.lrn_enrollments
    ADD COLUMN IF NOT EXISTS attendance_pct       NUMERIC(5,2),
    ADD COLUMN IF NOT EXISTS narrative_report_id  BIGINT;

-- ----------------------------------------------------------------
-- LEARNING SERVICE PROVIDER REGISTRY
-- ----------------------------------------------------------------
CREATE TABLE learning.lrn_lsp_registry (
    id                  BIGSERIAL    PRIMARY KEY,
    company_id          BIGINT       NOT NULL REFERENCES core.companies(id),
    name                VARCHAR(200) NOT NULL,
    accreditation_no    VARCHAR(60),
    contact_person      VARCHAR(200),
    email               VARCHAR(200),
    phone               VARCHAR(30),
    is_csc_accredited   BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Add FK from lrn_programs to lsp
ALTER TABLE learning.lrn_programs
    ADD CONSTRAINT fk_program_lsp
    FOREIGN KEY (lsp_id) REFERENCES learning.lrn_lsp_registry(id);

-- ----------------------------------------------------------------
-- TRAINING NEEDS ANALYSIS (TNA)
-- ----------------------------------------------------------------
CREATE TABLE learning.lrn_tna_entries (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id),
    cycle_id            BIGINT       REFERENCES performance.perf_cycles(id),
    competency_gap      TEXT         NOT NULL,
    recommended_training TEXT,
    priority            VARCHAR(10)  NOT NULL DEFAULT 'MEDIUM'
                            CHECK (priority IN ('HIGH', 'MEDIUM', 'LOW')),
    source              VARCHAR(20)  NOT NULL DEFAULT 'IPCR'
                            CHECK (source IN ('IPCR', 'SUPERVISOR', 'SELF', 'HR_AUDIT')),
    status              VARCHAR(20)  NOT NULL DEFAULT 'PENDING'
                            CHECK (status IN ('PENDING', 'ENROLLED', 'COMPLETED', 'DEFERRED')),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tna_employee ON learning.lrn_tna_entries(employee_id);
CREATE INDEX idx_tna_cycle    ON learning.lrn_tna_entries(cycle_id);

-- ----------------------------------------------------------------
-- IDP ACTIONS (extends perf_idp_plans with L&D linkage)
-- ----------------------------------------------------------------
CREATE TABLE learning.lrn_idp_actions (
    id                  BIGSERIAL    PRIMARY KEY,
    idp_plan_id         BIGINT       REFERENCES performance.perf_idp_plans(id),
    tna_entry_id        BIGINT       REFERENCES learning.lrn_tna_entries(id),
    action_type         VARCHAR(20)  NOT NULL DEFAULT 'TRAINING'
                            CHECK (action_type IN ('TRAINING', 'COACHING', 'ASSIGNMENT', 'STUDY_LEAVE', 'SCHOLARSHIP')),
    target_completion_date DATE,
    actual_completion_date DATE,
    session_id          BIGINT       REFERENCES learning.lrn_sessions(id),
    outcome             TEXT,
    status              VARCHAR(20)  NOT NULL DEFAULT 'PLANNED'
                            CHECK (status IN ('PLANNED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------
-- SCHOLARSHIPS & STUDY GRANTS
-- ----------------------------------------------------------------
CREATE TABLE learning.lrn_scholarships (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id),
    program_name        VARCHAR(200) NOT NULL,
    grant_type          VARCHAR(20)  NOT NULL DEFAULT 'LOCAL'
                            CHECK (grant_type IN ('LOCAL', 'FOREIGN', 'PRIVATE', 'CSC_SPONSORED')),
    institution         VARCHAR(200),
    course              VARCHAR(200),
    start_date          DATE,
    end_date            DATE,
    coverage_details    TEXT,
    bond_required_months INTEGER,
    return_of_service_date DATE,
    status              VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE'
                            CHECK (status IN ('ACTIVE', 'COMPLETED', 'CANCELLED', 'ON_BOND')),
    approved_by         BIGINT       REFERENCES core.users(id),
    document_path       VARCHAR(500),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_scholarship_employee ON learning.lrn_scholarships(employee_id);

-- ----------------------------------------------------------------
-- GEO-TAGGED MOBILE ATTENDANCE (for training sessions)
-- ----------------------------------------------------------------
CREATE TABLE learning.lrn_attendance_logs (
    id                  BIGSERIAL    PRIMARY KEY,
    enrollment_id       BIGINT       NOT NULL REFERENCES learning.lrn_enrollments(id),
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id),
    session_id          BIGINT       NOT NULL REFERENCES learning.lrn_sessions(id),
    checked_in_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    checkin_lat         NUMERIC(10,7),
    checkin_lng         NUMERIC(10,7),
    checkin_accuracy_m  NUMERIC(6,2),
    device_id           VARCHAR(100),
    ip_address          INET,
    photo_path          VARCHAR(500),
    is_valid            BOOLEAN      NOT NULL DEFAULT TRUE,
    invalidated_reason  TEXT,
    verified_by         BIGINT       REFERENCES core.users(id),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_lrn_att_enrollment ON learning.lrn_attendance_logs(enrollment_id);
CREATE INDEX idx_lrn_att_session    ON learning.lrn_attendance_logs(session_id);

-- ----------------------------------------------------------------
-- NARRATIVE REPORT FORM (NRF) — online submission
-- ----------------------------------------------------------------
CREATE TABLE learning.lrn_narrative_reports (
    id                  BIGSERIAL    PRIMARY KEY,
    enrollment_id       BIGINT       NOT NULL REFERENCES learning.lrn_enrollments(id),
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id),
    training_title      VARCHAR(200),
    training_dates      TEXT,
    venue               VARCHAR(200),
    facilitator         VARCHAR(200),
    learning_objectives TEXT,
    key_learnings       TEXT,
    application_plans   TEXT,
    challenges          TEXT,
    recommendations     TEXT,
    evaluation_rating   NUMERIC(3,1),
    submitted_at        TIMESTAMPTZ,
    approved_by         BIGINT       REFERENCES core.users(id),
    approved_at         TIMESTAMPTZ,
    status              VARCHAR(20)  NOT NULL DEFAULT 'DRAFT'
                            CHECK (status IN ('DRAFT', 'SUBMITTED', 'APPROVED', 'RETURNED')),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Link enrollments to NRF
ALTER TABLE learning.lrn_enrollments
    ADD CONSTRAINT fk_enrollment_nrf
    FOREIGN KEY (narrative_report_id) REFERENCES learning.lrn_narrative_reports(id);

-- ================================================================
-- SEED: WORKFLOW DEFINITION FOR NRF
-- ================================================================
INSERT INTO workflow.workflow_definitions (code, name, module, description) VALUES
    ('LD_NRF_APPROVAL',
     'Narrative Report Form Approval',
     'ld',
     'NRF submitted by employee after training → Supervisor reviews → HR files')
ON CONFLICT (code) DO NOTHING;

WITH wf AS (SELECT id FROM workflow.workflow_definitions WHERE code = 'LD_NRF_APPROVAL')
INSERT INTO workflow.workflow_steps (workflow_id, step_order, code, name, role_required, sla_hours, is_final)
SELECT wf.id, s.step_order, s.code, s.name, s.role, s.sla_hours, s.is_final
FROM wf, (VALUES
    (1, 'LD_NRF_SUBMIT',  'Employee Submission',  'EMPLOYEE',  0,   FALSE),
    (2, 'LD_NRF_REVIEW',  'Supervisor Review',    'DEPT_HEAD', 72,  FALSE),
    (3, 'LD_NRF_FILE',    'HR Filing',            'HR_ADMIN',  48,  TRUE)
) AS s(step_order, code, name, role, sla_hours, is_final)
ON CONFLICT DO NOTHING;

-- ================================================================
-- SEED: L&D PAGE REGISTRY
-- ================================================================
INSERT INTO core.page_registry
    (path, title, nav_group, nav_label, module, nav_icon, nav_order, requires_feature)
VALUES
    ('/ld/programs',          'Training Catalog',     'Learning', 'Programs',     'ld', '📚', 10, 'LEARNING'),
    ('/ld/sessions',          'Sessions',             'Learning', 'Sessions',     'ld', '📅', 20, 'LEARNING'),
    ('/ld/tna',               'Training Needs',       'Learning', 'TNA',          'ld', '🎯', 30, 'LEARNING'),
    ('/ld/scholarships',      'Scholarships',         'Learning', 'Scholarships', 'ld', '🎓', 40, 'LEARNING'),
    ('/ld/narrative-reports', 'Narrative Reports',    'Learning', 'NRF',          'ld', '📝', 50, 'LEARNING'),
    ('/ld/attendance',        'Training Attendance',  'Learning', 'Attendance',   'ld', '📍', 60, 'LEARNING')
ON CONFLICT (path) DO NOTHING;

-- ================================================================
-- SEED: FEATURE FLAG
-- ================================================================
INSERT INTO core.feature_registry (code, name, description, module, is_enabled) VALUES
    ('LEARNING', 'Learning & Development', 'Training catalog, TNA, scholarships, NRF', 'ld', TRUE)
ON CONFLICT (code) DO NOTHING;
