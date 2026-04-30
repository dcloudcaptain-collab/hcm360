-- ================================================================
-- HCM360 HRIS — 20: RSP PHASE 2 EXTENSIONS
-- Schemas   : recruitment, onboarding
-- Standards : CSC (Civil Service Commission), DBM Plantilla,
--             CSC MC 12-2020, RA 7041 (Publication Law)
-- ================================================================
SET search_path TO recruitment, onboarding, core, workflow, public;

-- ----------------------------------------------------------------
-- PLANTILLA OF PERSONNEL (DBM-authorized positions)
-- ----------------------------------------------------------------
CREATE TABLE recruitment.rec_plantilla_items (
    id                  BIGSERIAL    PRIMARY KEY,
    company_id          BIGINT       NOT NULL REFERENCES core.companies(id),
    department_id       BIGINT       REFERENCES core.departments(id),
    position_id         BIGINT       REFERENCES core.positions(id),
    item_number         VARCHAR(30)  UNIQUE NOT NULL,   -- e.g. "Item No. 123-2024"
    salary_grade        INTEGER      NOT NULL CHECK (salary_grade BETWEEN 1 AND 33),
    step_no             INTEGER      NOT NULL DEFAULT 1 CHECK (step_no BETWEEN 1 AND 8),
    authorized_year     INTEGER,
    filled_by           BIGINT       REFERENCES core.employees(id),
    status              VARCHAR(20)  NOT NULL DEFAULT 'VACANT'
                            CHECK (status IN ('FILLED','VACANT','PROPOSED','ABOLISHED')),
    remarks             TEXT,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_plantilla_company   ON recruitment.rec_plantilla_items(company_id, status);
CREATE INDEX idx_plantilla_dept      ON recruitment.rec_plantilla_items(department_id);
CREATE INDEX idx_plantilla_position  ON recruitment.rec_plantilla_items(position_id);

-- ----------------------------------------------------------------
-- CSC QUALIFICATION STANDARDS PER POSITION
-- ----------------------------------------------------------------
CREATE TABLE recruitment.rec_qualification_standards (
    id                  BIGSERIAL    PRIMARY KEY,
    position_id         BIGINT       NOT NULL REFERENCES core.positions(id),
    education           TEXT,          -- "Bachelor's degree relevant to the job"
    experience          TEXT,          -- "2 years of relevant experience"
    training            TEXT,          -- "8 hours of relevant training"
    eligibility         TEXT,          -- "Career Service (Professional)"
    competencies        JSONB          NOT NULL DEFAULT '[]',  -- array of {name, level}
    effective_date      DATE           NOT NULL DEFAULT CURRENT_DATE,
    created_by          BIGINT         REFERENCES core.users(id),
    is_active           BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_qs_position_active
    ON recruitment.rec_qualification_standards(position_id)
    WHERE is_active = TRUE;

-- ----------------------------------------------------------------
-- CSC ELIGIBILITY LOOKUP TABLE
-- ----------------------------------------------------------------
CREATE TABLE recruitment.rec_csc_eligibilities (
    id                  BIGSERIAL    PRIMARY KEY,
    code                VARCHAR(40)  NOT NULL UNIQUE,
    name                VARCHAR(200) NOT NULL,
    category            VARCHAR(60),   -- CAREER_SERVICE, BOARD_EXAM, HONOR_GRAD, SPECIAL_LAW
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------
-- EMPLOYEE ELIGIBILITIES (links employee to CSC eligibility)
-- ----------------------------------------------------------------
CREATE TABLE recruitment.rec_employee_eligibilities (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id),
    eligibility_id      BIGINT       NOT NULL REFERENCES recruitment.rec_csc_eligibilities(id),
    rating              NUMERIC(5,2),
    exam_date           DATE,
    exam_place          VARCHAR(200),
    license_no          VARCHAR(60),
    license_expiry      DATE,
    is_verified         BOOLEAN      NOT NULL DEFAULT FALSE,
    verified_by         BIGINT       REFERENCES core.users(id),
    verified_at         TIMESTAMPTZ,
    document_path       VARCHAR(500),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_emp_elig_employee ON recruitment.rec_employee_eligibilities(employee_id);
CREATE UNIQUE INDEX idx_emp_elig_unique
    ON recruitment.rec_employee_eligibilities(employee_id, eligibility_id);

-- ----------------------------------------------------------------
-- VACANCY PUBLICATION (CSC RA 7041 posting requirements)
-- ----------------------------------------------------------------
CREATE TABLE recruitment.rec_publications (
    id                  BIGSERIAL    PRIMARY KEY,
    requisition_id      BIGINT       NOT NULL REFERENCES recruitment.rec_requisitions(id),
    posting_id          BIGINT       REFERENCES recruitment.rec_job_postings(id),
    published_at        TIMESTAMPTZ,
    closes_at           TIMESTAMPTZ,
    published_by        BIGINT       REFERENCES core.users(id),
    csc_reference_no    VARCHAR(60),
    channel             VARCHAR(30)  NOT NULL DEFAULT 'AGENCY_BULLETIN'
                            CHECK (channel IN ('CSC_BOARD','AGENCY_BULLETIN','WEBSITE','JOBSTREET','PHILJOBNET')),
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_pub_requisition ON recruitment.rec_publications(requisition_id);

-- ----------------------------------------------------------------
-- PERSONNEL SELECTION BOARD (PSB) MEMBERS
-- ----------------------------------------------------------------
CREATE TABLE recruitment.rec_psb_members (
    id                  BIGSERIAL    PRIMARY KEY,
    company_id          BIGINT       NOT NULL REFERENCES core.companies(id),
    member_employee_id  BIGINT       NOT NULL REFERENCES core.employees(id),
    role                VARCHAR(20)  NOT NULL DEFAULT 'MEMBER'
                            CHECK (role IN ('CHAIR','MEMBER','OBSERVER','HR_REP')),
    effective_from      DATE         NOT NULL DEFAULT CURRENT_DATE,
    effective_to        DATE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_psb_company ON recruitment.rec_psb_members(company_id);

-- ----------------------------------------------------------------
-- PSB DELIBERATION RECORDS
-- ----------------------------------------------------------------
CREATE TABLE recruitment.rec_psb_deliberations (
    id                  BIGSERIAL    PRIMARY KEY,
    requisition_id      BIGINT       NOT NULL REFERENCES recruitment.rec_requisitions(id),
    deliberation_date   DATE         NOT NULL,
    chairperson_id      BIGINT       REFERENCES core.employees(id),
    minutes_path        VARCHAR(500),
    status              VARCHAR(20)  NOT NULL DEFAULT 'PENDING'
                            CHECK (status IN ('PENDING','COMPLETED','DEFERRED')),
    resolution          TEXT,
    created_by          BIGINT       REFERENCES core.users(id),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_psb_delib_req ON recruitment.rec_psb_deliberations(requisition_id);

-- ----------------------------------------------------------------
-- PSB SCREENING SCORES PER APPLICANT
-- total_score is auto-computed from weighted sub-scores
-- ----------------------------------------------------------------
CREATE TABLE recruitment.rec_psb_scores (
    id                  BIGSERIAL    PRIMARY KEY,
    deliberation_id     BIGINT       NOT NULL REFERENCES recruitment.rec_psb_deliberations(id),
    applicant_id        BIGINT       NOT NULL REFERENCES recruitment.rec_applicants(id),
    education_score     NUMERIC(5,2) NOT NULL DEFAULT 0,
    experience_score    NUMERIC(5,2) NOT NULL DEFAULT 0,
    training_score      NUMERIC(5,2) NOT NULL DEFAULT 0,
    performance_score   NUMERIC(5,2) NOT NULL DEFAULT 0,
    interview_score     NUMERIC(5,2) NOT NULL DEFAULT 0,
    total_score         NUMERIC(6,2) GENERATED ALWAYS AS (
                            education_score + experience_score + training_score
                            + performance_score + interview_score
                        ) STORED,
    rank                INTEGER,
    is_next_in_rank     BOOLEAN      NOT NULL DEFAULT FALSE,
    remarks             TEXT,
    scored_by           BIGINT       REFERENCES core.users(id),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (deliberation_id, applicant_id)
);

CREATE INDEX idx_psb_scores_delib  ON recruitment.rec_psb_scores(deliberation_id);
CREATE INDEX idx_psb_scores_applic ON recruitment.rec_psb_scores(applicant_id);

-- ----------------------------------------------------------------
-- NEXT-IN-RANK LIST (auto-maintained; triggers notification)
-- ----------------------------------------------------------------
CREATE TABLE recruitment.rec_next_in_rank_list (
    id                  BIGSERIAL    PRIMARY KEY,
    position_id         BIGINT       NOT NULL REFERENCES core.positions(id),
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id),
    qualification_met   BOOLEAN      NOT NULL DEFAULT FALSE,
    rank                INTEGER      NOT NULL,
    assessed_on         DATE         NOT NULL DEFAULT CURRENT_DATE,
    assessed_by         BIGINT       REFERENCES core.users(id),
    notified_at         TIMESTAMPTZ,
    notification_ref    VARCHAR(100),
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (position_id, employee_id)
);

CREATE INDEX idx_nir_position ON recruitment.rec_next_in_rank_list(position_id, qualification_met);
CREATE INDEX idx_nir_employee ON recruitment.rec_next_in_rank_list(employee_id);

-- ----------------------------------------------------------------
-- APPOINTMENT PAPERS
-- ----------------------------------------------------------------
CREATE TABLE recruitment.rec_appointments (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id),
    position_id         BIGINT       NOT NULL REFERENCES core.positions(id),
    plantilla_item_id   BIGINT       REFERENCES recruitment.rec_plantilla_items(id),
    appointment_type    VARCHAR(20)  NOT NULL DEFAULT 'PERMANENT'
                            CHECK (appointment_type IN
                                ('PERMANENT','TEMPORARY','CASUAL','COTERMINOUS','CONTRACTUAL')),
    appointment_no      VARCHAR(60)  UNIQUE NOT NULL,
    effective_date      DATE         NOT NULL,
    end_date            DATE,
    salary_grade        INTEGER      NOT NULL CHECK (salary_grade BETWEEN 1 AND 33),
    step_no             INTEGER      NOT NULL DEFAULT 1 CHECK (step_no BETWEEN 1 AND 8),
    monthly_salary      NUMERIC(14,2) NOT NULL,
    issued_by           BIGINT       REFERENCES core.users(id),
    approved_by         BIGINT       REFERENCES core.users(id),
    csc_attested_at     TIMESTAMPTZ,
    document_path       VARCHAR(500),
    workflow_instance_id BIGINT,
    status              VARCHAR(20)  NOT NULL DEFAULT 'DRAFT'
                            CHECK (status IN ('DRAFT','FOR_SIGNATURE','ATTESTED','CANCELLED')),
    remarks             TEXT,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_appt_employee ON recruitment.rec_appointments(employee_id);
CREATE INDEX idx_appt_position ON recruitment.rec_appointments(position_id, status);

-- ----------------------------------------------------------------
-- ONBOARDING: PRE-EMPLOYMENT REQUIREMENTS
-- ----------------------------------------------------------------
CREATE TABLE onboarding.onb_pre_employment_reqs (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id),
    requirement_type    VARCHAR(40)  NOT NULL
                            CHECK (requirement_type IN (
                                'MEDICAL_CERT','NBI_CLEARANCE','BIRTH_CERT',
                                'TOR','PDS_CS9','OATHS','PMS_IPCR',
                                'SERVICE_RECORD','CLEARANCE_PREV_EMPLOYER')),
    submitted_at        TIMESTAMPTZ,
    expires_at          DATE,
    document_path       VARCHAR(500),
    verified_by         BIGINT       REFERENCES core.users(id),
    verified_at         TIMESTAMPTZ,
    remarks             TEXT,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_pre_emp_employee ON onboarding.onb_pre_employment_reqs(employee_id);

-- ----------------------------------------------------------------
-- OFFBOARDING: CLEARANCE TRACKER
-- ----------------------------------------------------------------
CREATE TABLE onboarding.offb_clearance_items (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id),
    clearance_type      VARCHAR(30)  NOT NULL
                            CHECK (clearance_type IN (
                                'PROPERTY','CASH_ADVANCE','LIBRARY',
                                'IT_EQUIPMENT','HR_201','FINANCE',
                                'GSIS','PAGIBIG','MEDICAL')),
    cleared_by          BIGINT       REFERENCES core.users(id),
    cleared_at          TIMESTAMPTZ,
    remarks             TEXT,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (employee_id, clearance_type)
);

CREATE INDEX idx_clearance_employee ON onboarding.offb_clearance_items(employee_id);

-- ================================================================
-- SEED: CSC ELIGIBILITY TYPES
-- ================================================================
INSERT INTO recruitment.rec_csc_eligibilities (code, name, category) VALUES
    ('CS-PROF',     'Career Service Professional',                  'CAREER_SERVICE'),
    ('CS-SUBPRO',   'Career Service Sub-Professional',              'CAREER_SERVICE'),
    ('PD907',       'PD 907 (Veteran Preference)',                  'SPECIAL_LAW'),
    ('RA1080',      'RA 1080 (Registered Professionals)',           'BOARD_EXAM'),
    ('RA1080-CPA',  'RA 1080 – Certified Public Accountant',        'BOARD_EXAM'),
    ('RA1080-RN',   'RA 1080 – Registered Nurse',                   'BOARD_EXAM'),
    ('RA1080-CIVIL','RA 1080 – Civil Engineer',                     'BOARD_EXAM'),
    ('RA1080-MECH', 'RA 1080 – Mechanical Engineer',                'BOARD_EXAM'),
    ('RA1080-ELEC', 'RA 1080 – Electronics Engineer',               'BOARD_EXAM'),
    ('RA1080-ELEC2','RA 1080 – Electrical Engineer',                'BOARD_EXAM'),
    ('RA1080-ARCH', 'RA 1080 – Architect',                          'BOARD_EXAM'),
    ('RA1080-BAR',  'RA 1080 – Bar (Attorney)',                     'BOARD_EXAM'),
    ('HONOR',       'Honor Graduate (RA 1256)',                     'HONOR_GRAD'),
    ('BOARD',       'Passed Board/Bar Examinations',                'BOARD_EXAM'),
    ('MC11-S97',    'MC 11, s. 1996 – Barangay Official',           'SPECIAL_LAW'),
    ('RA7883',      'RA 7883 – Barangay Health Worker',             'SPECIAL_LAW'),
    ('NONE',        'No eligibility required (SG 1-8)',             'CAREER_SERVICE')
ON CONFLICT (code) DO NOTHING;

-- ================================================================
-- SEED: WORKFLOW DEFINITIONS FOR RSP
-- ================================================================
INSERT INTO workflow.workflow_definitions (code, name, module, description) VALUES
    ('RSP_APPOINTMENT_APPROVAL',
     'Appointment Paper Approval',
     'rsp',
     'Multi-step approval for employee appointment papers: HR → Department Head → HRMO → Appointing Authority'),
    ('RSP_ONBOARDING_COMPLETION',
     'Onboarding Completion Workflow',
     'rsp',
     'Gate-checked workflow: all pre-employment documents must be submitted before employee is activated'),
    ('RSP_OFFBOARDING_CLEARANCE',
     'Offboarding Clearance Workflow',
     'rsp',
     'Sequenced clearance: Property → Finance → HR; triggers final pay computation on completion')
ON CONFLICT (code) DO NOTHING;

-- Appointment Approval steps
WITH wf AS (SELECT id FROM workflow.workflow_definitions WHERE code = 'RSP_APPOINTMENT_APPROVAL')
INSERT INTO workflow.workflow_steps (workflow_id, step_order, code, name, role_required, sla_hours, is_final)
SELECT wf.id, s.step_order, s.code, s.name, s.role, s.sla_hours, s.is_final
FROM wf, (VALUES
    (1, 'RSP_APPT_HR',      'HR Review',              'HR_ADMIN',    48,  FALSE),
    (2, 'RSP_APPT_DEPT',    'Department Head Review', 'DEPT_HEAD',   48,  FALSE),
    (3, 'RSP_APPT_HRMO',    'HRMO Endorsement',       'HRMO',        24,  FALSE),
    (4, 'RSP_APPT_AA',      'Appointing Authority',   'SUPER_ADMIN', 72,  TRUE)
) AS s(step_order, code, name, role, sla_hours, is_final)
ON CONFLICT DO NOTHING;

-- Onboarding Completion steps
WITH wf AS (SELECT id FROM workflow.workflow_definitions WHERE code = 'RSP_ONBOARDING_COMPLETION')
INSERT INTO workflow.workflow_steps (workflow_id, step_order, code, name, role_required, sla_hours, is_final)
SELECT wf.id, s.step_order, s.code, s.name, s.role, s.sla_hours, s.is_final
FROM wf, (VALUES
    (1, 'ONB_DOCS_SUBMIT', 'Submit Pre-Employment Documents', 'EMPLOYEE',  168, FALSE),
    (2, 'ONB_HR_VERIFY',   'HR Documents Verification',      'HR_ADMIN',   48, FALSE),
    (3, 'ONB_ACTIVATE',    'Employee Activation',            'HR_ADMIN',   24, TRUE)
) AS s(step_order, code, name, role, sla_hours, is_final)
ON CONFLICT DO NOTHING;

-- Offboarding Clearance steps
WITH wf AS (SELECT id FROM workflow.workflow_definitions WHERE code = 'RSP_OFFBOARDING_CLEARANCE')
INSERT INTO workflow.workflow_steps (workflow_id, step_order, code, name, role_required, sla_hours, is_final)
SELECT wf.id, s.step_order, s.code, s.name, s.role, s.sla_hours, s.is_final
FROM wf, (VALUES
    (1, 'OFFB_PROPERTY',  'Property Clearance',    'HR_ADMIN',    48, FALSE),
    (2, 'OFFB_FINANCE',   'Finance Clearance',     'HR_ADMIN',    48, FALSE),
    (3, 'OFFB_HR',        'HR Clearance (201)',    'HR_ADMIN',    24, FALSE),
    (4, 'OFFB_COMPLETE',  'Clearance Completed',   'HR_ADMIN',    24, TRUE)
) AS s(step_order, code, name, role, sla_hours, is_final)
ON CONFLICT DO NOTHING;

-- ================================================================
-- SEED: RSP PAGE REGISTRY (RBAC feature flags)
-- ================================================================
INSERT INTO core.page_registry
    (path, title, nav_group, nav_label, module, nav_icon, nav_order, requires_feature)
VALUES
    ('/rsp/plantilla',    'Plantilla of Personnel', 'Recruitment', 'Plantilla',    'rsp', '📋', 10, 'RSP'),
    ('/rsp/vacancies',    'Vacancy Postings',        'Recruitment', 'Vacancies',    'rsp', '📢', 20, 'RSP'),
    ('/rsp/applicants',   'Applicant Pipeline',      'Recruitment', 'Applicants',   'rsp', '👤', 30, 'RSP'),
    ('/rsp/psb',          'PSB Deliberations',       'Recruitment', 'PSB',          'rsp', '⚖️', 40, 'RSP'),
    ('/rsp/appointments', 'Appointments',             'Recruitment', 'Appointments', 'rsp', '📄', 50, 'RSP'),
    ('/rsp/next-in-rank', 'Next-in-Rank List',        'Recruitment', 'Next-in-Rank', 'rsp', '🏆', 60, 'RSP'),
    ('/rsp/onboarding',   'Onboarding Tracker',       'Recruitment', 'Onboarding',   'rsp', '✅', 70, 'RSP'),
    ('/rsp/offboarding',  'Offboarding Clearance',    'Recruitment', 'Offboarding',  'rsp', '🚪', 80, 'RSP')
ON CONFLICT (path) DO NOTHING;

-- ================================================================
-- SEED: NEW RBAC ROLES FOR PHASE 2
-- ================================================================
INSERT INTO core.roles (code, name, description, is_active)
SELECT code, name, description, is_active FROM (VALUES
    ('HRMO',                  'HR Management Officer',     'Full RSP, PM read, Payroll read',          TRUE),
    ('RECRUITMENT_OFFICER',   'Recruitment Officer',       'RSP module only',                          TRUE),
    ('LEARNING_OFFICER',      'Learning Officer',          'L&D module only',                          TRUE),
    ('PAYROLL_OFFICER_GOV',   'Government Payroll Officer','Government payroll, GSIS/Pag-IBIG reports', TRUE),
    ('PRAISE_COMMITTEE',      'PRAISE Committee Member',   'R&R nominations and awards',               TRUE)
) AS v(code, name, description, is_active)
WHERE NOT EXISTS (SELECT 1 FROM core.roles r WHERE r.code = v.code);

-- ================================================================
-- FEATURE FLAG
-- ================================================================
INSERT INTO core.feature_registry (code, name, description, module, is_enabled) VALUES
    ('RECRUITMENT', 'Recruitment Module', 'RSP – Recruitment, Selection & Placement', 'rsp', TRUE)
ON CONFLICT (code) DO NOTHING;
