-- ================================================================
-- HCM360 — 55: REMAINING LGU GAPS (G08–G18)
--
-- Adds schema for:
--   G15  CSC Eligibility 1st/2nd Level (add column + backfill)
--   G16  SALN (3-mode configurable: UPLOAD_ONLY / SIMPLE_FORM / FULL_CSC_210)
--   G09  Training attendance shift (AM/PM column)
--   G08  Electronic signature (canvas + DocuSign)
--   G11  Loyalty award memo tracking columns
--   G18  Extend ai.ml_predictions if needed (already exists per 14_ai.sql)
--
-- Page + feature registry + role grants all included.
-- ================================================================
SET search_path TO core, public;


-- ══════════════════════════════════════════════════════════════════
-- G15 · CSC Eligibility Level
-- ══════════════════════════════════════════════════════════════════
ALTER TABLE recruitment.rec_csc_eligibilities
    ADD COLUMN IF NOT EXISTS level VARCHAR(20);

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'rec_csc_elig_level_chk') THEN
        ALTER TABLE recruitment.rec_csc_eligibilities
            ADD CONSTRAINT rec_csc_elig_level_chk
            CHECK (level IS NULL OR level IN ('1ST_LEVEL','2ND_LEVEL','HONOR_GRAD','OTHER'));
    END IF;
END $$;

-- Backfill level from known CSC eligibility codes
UPDATE recruitment.rec_csc_eligibilities
SET level = CASE
    WHEN code IN ('CS-PROF', 'RA1080', 'BOARD', 'PROF', 'PROFESSIONAL') THEN '2ND_LEVEL'
    WHEN code IN ('CS-SUBPRO', 'PD907', 'SUBPRO', 'SUB-PROFESSIONAL')   THEN '1ST_LEVEL'
    WHEN code = 'HONOR'                                                  THEN 'HONOR_GRAD'
    ELSE 'OTHER'
END
WHERE level IS NULL;


-- ══════════════════════════════════════════════════════════════════
-- G16 · SALN (configurable 3-mode)
-- ══════════════════════════════════════════════════════════════════
CREATE SCHEMA IF NOT EXISTS dms;

CREATE TABLE IF NOT EXISTS dms.saln_settings (
    company_id    BIGINT      PRIMARY KEY REFERENCES core.companies(id) ON DELETE CASCADE,
    mode          VARCHAR(20) NOT NULL DEFAULT 'SIMPLE_FORM'
                   CHECK (mode IN ('UPLOAD_ONLY','SIMPLE_FORM','FULL_CSC_210')),
    filing_month  INT         DEFAULT 4,      -- April = SALN season in PH
    reminder_days INT         DEFAULT 30,
    updated_by    BIGINT      REFERENCES core.users(id),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO dms.saln_settings (company_id)
SELECT id FROM core.companies WHERE code = 'DEMO'
ON CONFLICT (company_id) DO NOTHING;


CREATE TABLE IF NOT EXISTS dms.saln_filings (
    id              BIGSERIAL   PRIMARY KEY,
    employee_id     BIGINT      NOT NULL REFERENCES core.employees(id) ON DELETE CASCADE,
    filing_year     INT         NOT NULL,
    mode            VARCHAR(20) NOT NULL
                     CHECK (mode IN ('UPLOAD_ONLY','SIMPLE_FORM','FULL_CSC_210')),
    data            JSONB       NOT NULL DEFAULT '{}'::jsonb,
    uploaded_doc_id BIGINT      REFERENCES core.documents(id),
    status          VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
                     CHECK (status IN ('DRAFT','SUBMITTED','VERIFIED','ARCHIVED')),
    filed_at        TIMESTAMPTZ,
    verified_by     BIGINT REFERENCES core.users(id),
    verified_at     TIMESTAMPTZ,
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (employee_id, filing_year)
);
CREATE INDEX IF NOT EXISTS idx_saln_emp_year ON dms.saln_filings (employee_id, filing_year);
CREATE INDEX IF NOT EXISTS idx_saln_status   ON dms.saln_filings (status);


-- ══════════════════════════════════════════════════════════════════
-- G09 · Training Attendance Shift (AM/PM)
-- ══════════════════════════════════════════════════════════════════
ALTER TABLE learning.lrn_attendance_logs
    ADD COLUMN IF NOT EXISTS shift_period VARCHAR(2),
    ADD COLUMN IF NOT EXISTS session_date DATE;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'lrn_att_shift_chk') THEN
        ALTER TABLE learning.lrn_attendance_logs
            ADD CONSTRAINT lrn_att_shift_chk
            CHECK (shift_period IS NULL OR shift_period IN ('AM','PM'));
    END IF;
END $$;


-- ══════════════════════════════════════════════════════════════════
-- G08 · Electronic Signature (Canvas + DocuSign)
-- ══════════════════════════════════════════════════════════════════
ALTER TABLE core.documents
    ADD COLUMN IF NOT EXISTS requires_signature        BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS current_signatures_count  INT     NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS required_signatures_count INT     NOT NULL DEFAULT 0;


CREATE TABLE IF NOT EXISTS core.esignature_settings (
    company_id               BIGINT      PRIMARY KEY REFERENCES core.companies(id) ON DELETE CASCADE,
    default_mode             VARCHAR(20) NOT NULL DEFAULT 'CANVAS'
                              CHECK (default_mode IN ('CANVAS','DOCUSIGN')),
    docusign_integration_key VARCHAR(100),
    docusign_account_id      VARCHAR(60),
    docusign_base_url        VARCHAR(200) DEFAULT 'https://demo.docusign.net/restapi',
    docusign_enabled         BOOLEAN      NOT NULL DEFAULT FALSE,
    updated_by               BIGINT       REFERENCES core.users(id),
    updated_at               TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

INSERT INTO core.esignature_settings (company_id)
SELECT id FROM core.companies WHERE code = 'DEMO'
ON CONFLICT (company_id) DO NOTHING;


CREATE TABLE IF NOT EXISTS core.document_signatures (
    id                   BIGSERIAL   PRIMARY KEY,
    document_id          BIGINT      REFERENCES core.documents(id) ON DELETE CASCADE,
    entity_kind          VARCHAR(30) NOT NULL DEFAULT 'document',  -- 'document'|'cs_form_6'|'contract'|'appointment'|'clearance'
    entity_id            BIGINT,                                    -- id in the relevant table
    signer_user_id       BIGINT      REFERENCES core.users(id),
    signer_employee_id   BIGINT      REFERENCES core.employees(id),
    signer_role          VARCHAR(60) NOT NULL,
    signer_name          VARCHAR(200),
    signature_mode       VARCHAR(20) NOT NULL
                          CHECK (signature_mode IN ('CANVAS','DOCUSIGN')),
    signature_image      TEXT,                            -- base64 PNG for canvas
    docusign_envelope_id VARCHAR(100),
    status               VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                          CHECK (status IN ('PENDING','SIGNED','DECLINED','CANCELLED','EXPIRED')),
    signed_at            TIMESTAMPTZ,
    ip_address           VARCHAR(45),
    user_agent           TEXT,
    notes                TEXT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_docsig_doc    ON core.document_signatures (document_id);
CREATE INDEX IF NOT EXISTS idx_docsig_entity ON core.document_signatures (entity_kind, entity_id);
CREATE INDEX IF NOT EXISTS idx_docsig_status ON core.document_signatures (status);


-- ══════════════════════════════════════════════════════════════════
-- G11 · Loyalty Award Memo tracking
-- ══════════════════════════════════════════════════════════════════
-- rewards.rwd_loyalty_milestones already exists; add a few optional columns
ALTER TABLE rewards.rwd_loyalty_milestones
    ADD COLUMN IF NOT EXISTS memo_no          VARCHAR(40),
    ADD COLUMN IF NOT EXISTS memo_generated_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS memo_by           BIGINT REFERENCES core.users(id);


-- ══════════════════════════════════════════════════════════════════
-- G18 · Attrition Risk view + ai.ml_predictions extension
-- ══════════════════════════════════════════════════════════════════
-- ai.ml_predictions may not yet have unique index for ON CONFLICT — ensure it:
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'ai' AND indexname = 'uq_ml_pred_emp_type'
    ) THEN
        -- Best-effort; ignore if table doesn't exist
        BEGIN
            CREATE UNIQUE INDEX uq_ml_pred_emp_type
              ON ai.ml_predictions (employee_id, prediction_type);
        EXCEPTION WHEN OTHERS THEN
            -- table may not exist; ignore
            NULL;
        END;
    END IF;
END $$;


-- ══════════════════════════════════════════════════════════════════
-- Page Registry
-- ══════════════════════════════════════════════════════════════════
INSERT INTO core.page_registry
    (path, title, module, nav_group, nav_label, nav_icon, nav_order, is_visible)
VALUES
    ('/reports/eligibility',    'CSC Eligibility Report',  'analytics',
        'Reports', 'CSC Eligibility', 'award', 30, TRUE),
    ('/reports/attrition-risk', 'Attrition Risk',          'analytics',
        'Reports', 'Attrition Risk',  'alert-triangle', 31, TRUE),

    ('/rewards/loyalty',        'Loyalty Award Dashboard', 'rewards',
        'HR Admin', 'Loyalty Awards', 'award', 68, TRUE),

    ('/admin/saln-settings',    'SALN Settings',           'admin',
        'Administration', 'SALN Settings', 'settings', 98, TRUE),
    ('/me/saln',                'My SALN',                 'core',
        'Self-Service', 'My SALN', 'file-text', 39, TRUE),
    ('/dms/saln',               'SALN Filings',            'dms',
        'HR Admin', 'SALN Filings', 'folder', 69, TRUE),

    ('/admin/esignature-settings','E-Signature Settings',  'admin',
        'Administration', 'E-Signature', 'edit-3', 99, TRUE),

    ('/learning/sessions/checkin','Training Check-In',     'learning',
        'Self-Service', 'Training Check-In', 'map-pin', 41, FALSE),
    ('/learning/nrf',            'Narrative Reports',      'learning',
        'Self-Service', 'Narrative Report', 'file-text', 42, TRUE)
ON CONFLICT (path) DO NOTHING;


-- ══════════════════════════════════════════════════════════════════
-- Feature Registry
-- ══════════════════════════════════════════════════════════════════
INSERT INTO core.feature_registry
    (code, name, description, module, is_enabled, feature_type, action_type, page_path)
VALUES
    ('G15_ELIG_REPORT',  'View Eligibility Report',  '1st/2nd Level × Gender report',
        'analytics', TRUE, 'ACTION', 'VIEW',   '/reports/eligibility'),
    ('G18_ATTR_SCAN',    'Run Attrition Scan',       'Score all employees for attrition risk',
        'analytics', TRUE, 'ACTION', 'CREATE', '/reports/attrition-risk'),

    ('G11_LOYALTY_SCAN',  'Scan Loyalty Milestones','Detect 10/15/20/25/30-year anniversaries',
        'rewards', TRUE, 'ACTION', 'CREATE', '/rewards/loyalty'),
    ('G11_LOYALTY_MEMO',  'Generate Loyalty Memo',  'Produce loyalty award memo PDF',
        'rewards', TRUE, 'ACTION', 'PRINT',  '/rewards/loyalty'),
    ('G11_LOYALTY_AWARD', 'Mark Awarded',            'Flip to AWARDED after ceremony',
        'rewards', TRUE, 'ACTION', 'EDIT',   '/rewards/loyalty'),

    ('G16_SALN_FILE',     'File SALN',               'Submit SALN filing',
        'core',    TRUE, 'ACTION', 'CREATE', '/me/saln'),
    ('G16_SALN_VERIFY',   'Verify SALN',             'HR verify submitted SALN',
        'core',    TRUE, 'ACTION', 'APPROVE','/dms/saln'),
    ('G16_SALN_SETTINGS', 'Manage SALN Settings',    'Configure SALN mode',
        'admin',   TRUE, 'ACTION', 'EDIT',   '/admin/saln-settings'),

    ('G17_APPT_PDF',      'Download Appointment PDF','Generate CSC Form 33',
        'core',    TRUE, 'ACTION', 'PRINT',  '/rsp/appointments'),

    ('G08_ESIG_SIGN',     'Sign Document',           'Capture canvas signature on a document',
        'core',    TRUE, 'ACTION', 'CREATE', '/admin/esignature-settings'),
    ('G08_ESIG_DOCUSIGN', 'Send DocuSign',           'Send envelope via DocuSign',
        'core',    TRUE, 'ACTION', 'CREATE', '/admin/esignature-settings'),
    ('G08_ESIG_SETTINGS', 'Manage E-Sig Settings',   'Configure DocuSign integration',
        'admin',   TRUE, 'ACTION', 'EDIT',   '/admin/esignature-settings'),

    ('G09_TRAIN_CHECKIN', 'Training Check-In',       'Mobile attendance at training session',
        'learning', TRUE, 'ACTION', 'CREATE', '/learning/sessions/checkin'),
    ('G10_NRF_SUBMIT',    'Submit NRF',              'Submit narrative report for training',
        'learning', TRUE, 'ACTION', 'CREATE', '/learning/nrf'),
    ('G10_NRF_APPROVE',   'Approve NRF',             'Supervisor/HR approve narrative report',
        'learning', TRUE, 'ACTION', 'APPROVE','/learning/nrf')
ON CONFLICT (code) DO NOTHING;


-- ══════════════════════════════════════════════════════════════════
-- Role Page Access
-- ══════════════════════════════════════════════════════════════════
-- Self-service pages: every role
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
FROM core.page_registry p
CROSS JOIN (VALUES
    ('SUPER_ADMIN'), ('HR_ADMIN'), ('MANAGER'),
    ('EMPLOYEE'),    ('EXECUTIVE')
) AS r(role_code)
WHERE p.path IN ('/me/saln', '/learning/sessions/checkin', '/learning/nrf')
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

-- Report + HR dashboards: SUPER_ADMIN + HR_ADMIN + EXECUTIVE
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
FROM core.page_registry p
CROSS JOIN (VALUES ('SUPER_ADMIN'), ('HR_ADMIN'), ('EXECUTIVE')) AS r(role_code)
WHERE p.path IN ('/reports/eligibility', '/reports/attrition-risk',
                 '/rewards/loyalty', '/dms/saln')
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

-- Admin settings: SUPER_ADMIN + HR_ADMIN only
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
FROM core.page_registry p
CROSS JOIN (VALUES ('SUPER_ADMIN'), ('HR_ADMIN')) AS r(role_code)
WHERE p.path IN ('/admin/saln-settings', '/admin/esignature-settings')
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

-- Explicit denial for manager/employee/executive on admin settings
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, FALSE
FROM core.page_registry p
CROSS JOIN (VALUES ('MANAGER'), ('EMPLOYEE'), ('EXECUTIVE')) AS r(role_code)
WHERE p.path IN ('/admin/saln-settings', '/admin/esignature-settings')
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = FALSE;


-- Role Feature Access: everyone can perform self-service actions
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.role_code, f.id, TRUE
FROM core.feature_registry f
CROSS JOIN (VALUES
    ('SUPER_ADMIN'), ('HR_ADMIN'), ('MANAGER'),
    ('EMPLOYEE'),    ('EXECUTIVE')
) AS r(role_code)
WHERE f.code IN ('G16_SALN_FILE','G09_TRAIN_CHECKIN','G10_NRF_SUBMIT',
                 'G08_ESIG_SIGN','G17_APPT_PDF')
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = TRUE;

-- HR/Admin approvals + scans
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.role_code, f.id, TRUE
FROM core.feature_registry f
CROSS JOIN (VALUES ('SUPER_ADMIN'), ('HR_ADMIN')) AS r(role_code)
WHERE f.code IN ('G15_ELIG_REPORT','G18_ATTR_SCAN','G11_LOYALTY_SCAN',
                 'G11_LOYALTY_MEMO','G11_LOYALTY_AWARD','G16_SALN_VERIFY',
                 'G16_SALN_SETTINGS','G08_ESIG_DOCUSIGN','G08_ESIG_SETTINGS',
                 'G10_NRF_APPROVE')
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = TRUE;


-- ══════════════════════════════════════════════════════════════════
-- Dashboard Metrics (G15 + G18)
-- ══════════════════════════════════════════════════════════════════
INSERT INTO core.dashboard_metrics (code, label, icon, module, sql_query, filter_url, roles, sort_order, is_active)
VALUES
    ('csc_2nd_level_total',   '2nd Level Eligible',   'award',    'analytics',
     'SELECT COUNT(DISTINCT e.id) FROM core.employees e JOIN recruitment.rec_employee_eligibilities ee ON ee.employee_id=e.id JOIN recruitment.rec_csc_eligibilities ce ON ce.id=ee.eligibility_id WHERE ce.level=''2ND_LEVEL'' AND e.is_active=TRUE',
     '/reports/eligibility', ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE'], 30, TRUE),

    ('csc_1st_level_total',   '1st Level Eligible',   'award',    'analytics',
     'SELECT COUNT(DISTINCT e.id) FROM core.employees e JOIN recruitment.rec_employee_eligibilities ee ON ee.employee_id=e.id JOIN recruitment.rec_csc_eligibilities ce ON ce.id=ee.eligibility_id WHERE ce.level=''1ST_LEVEL'' AND e.is_active=TRUE',
     '/reports/eligibility', ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE'], 31, TRUE),

    ('attrition_high_risk',   'High Attrition Risk',  'alert-triangle', 'analytics',
     'SELECT COUNT(*) FROM ai.ml_predictions WHERE prediction_type=''ATTRITION'' AND risk_level=''HIGH''',
     '/reports/attrition-risk', ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE'], 32, TRUE),

    ('attrition_medium_risk', 'Medium Attrition Risk','alert-circle',   'analytics',
     'SELECT COUNT(*) FROM ai.ml_predictions WHERE prediction_type=''ATTRITION'' AND risk_level=''MEDIUM''',
     '/reports/attrition-risk', ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE'], 33, TRUE),

    ('loyalty_eligible',      'Loyalty Eligible',     'gift',    'rewards',
     'SELECT COUNT(*) FROM rewards.rwd_loyalty_milestones WHERE status=''ELIGIBLE''',
     '/rewards/loyalty', ARRAY['SUPER_ADMIN','HR_ADMIN'], 35, TRUE)
ON CONFLICT (code) DO NOTHING;
