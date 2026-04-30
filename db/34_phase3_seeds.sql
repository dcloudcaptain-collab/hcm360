-- ================================================================
-- HCM360 HRIS — 34: PHASE 3 SEED DATA
-- ================================================================
SET search_path TO dms, discipline, health, core, workflow, public;

-- ================================================================
-- DMS: 201 File Document Categories
-- ================================================================
INSERT INTO dms.document_categories (company_id, code, name, sort_order)
SELECT c.id, v.code, v.name, v.sort_order
FROM core.companies c,
(VALUES
    ('PERSONAL_INFO',       'Personal Information',          10),
    ('EMPLOYMENT_RECORDS',  'Employment Records',            20),
    ('SERVICE_RECORD',      'Service Record',                30),
    ('TRAINING_DEV',        'Training & Development',        40),
    ('PERFORMANCE',         'Performance Records',           50),
    ('DISCIPLINARY',        'Disciplinary Records',          60),
    ('MEDICAL',             'Medical Records',               70),
    ('CLEARANCES',          'Clearances & Certifications',   80),
    ('FINANCIAL',           'Financial Records',             90),
    ('OTHERS',              'Other Documents',               99)
) AS v(code, name, sort_order)
WHERE c.id = (SELECT id FROM core.companies LIMIT 1)
ON CONFLICT (company_id, code) DO NOTHING;

-- ================================================================
-- DMS: Default 201 Checklist for all employees
-- ================================================================
INSERT INTO dms.checklist_templates (company_id, name, is_active)
SELECT id, 'Standard 201 File Requirements', TRUE
FROM core.companies LIMIT 1;

WITH tpl AS (SELECT id FROM dms.checklist_templates WHERE name = 'Standard 201 File Requirements' LIMIT 1)
INSERT INTO dms.checklist_items (template_id, document_type, label, is_mandatory, sort_order)
SELECT tpl.id, v.doc_type, v.label, v.mandatory, v.sort_order
FROM tpl, (VALUES
    ('PDS_CS212',           'Personal Data Sheet (CS Form 212)',         TRUE,  1),
    ('OATH_OF_OFFICE',      'Oath of Office',                           TRUE,  2),
    ('APPOINTMENT_PAPER',   'Appointment Paper',                        TRUE,  3),
    ('CSC_ELIGIBILITY',     'Certificate of Eligibility',               TRUE,  4),
    ('BIRTH_CERTIFICATE',   'Birth Certificate (PSA)',                  TRUE,  5),
    ('MARRIAGE_CERT',       'Marriage Certificate (if applicable)',      FALSE, 6),
    ('DIPLOMA_TOR',         'Diploma / Transcript of Records',          TRUE,  7),
    ('NBI_CLEARANCE',       'NBI Clearance',                            TRUE,  8),
    ('MEDICAL_CERT',        'Medical Certificate (Pre-Employment)',     TRUE,  9),
    ('SALN',                'SALN (Statement of Assets & Liabilities)', TRUE, 10),
    ('BIR_TIN',             'BIR TIN Certificate',                      TRUE, 11),
    ('GSIS_ID',             'GSIS Membership ID',                       TRUE, 12),
    ('PAGIBIG_ID',          'Pag-IBIG MID Number',                      TRUE, 13),
    ('PHILHEALTH_ID',       'PhilHealth ID / MDR',                      TRUE, 14),
    ('SSS_ID',              'SSS Number (if applicable)',                FALSE, 15),
    ('PHOTO_2X2',           '2x2 ID Photo',                             TRUE, 16)
) AS v(doc_type, label, mandatory, sort_order)
ON CONFLICT DO NOTHING;

-- ================================================================
-- DISCIPLINE: CSC RRACA Offense Types
-- ================================================================
INSERT INTO discipline.case_types (code, name, gravity, legal_basis, default_penalty) VALUES
    -- GRAVE offenses
    ('DISHONESTY',          'Dishonesty',                    'GRAVE',      'RRACA Sec. 46(A)(1)',  'DISMISSAL'),
    ('GRAVE_MISCONDUCT',    'Grave Misconduct',              'GRAVE',      'RRACA Sec. 46(A)(3)',  'DISMISSAL'),
    ('GROSS_NEGLECT',       'Gross Neglect of Duty',         'GRAVE',      'RRACA Sec. 46(A)(2)',  'DISMISSAL'),
    ('NOTORIOUS_UNDESIRABLE','Being Notoriously Undesirable','GRAVE',      'RRACA Sec. 46(A)(8)',  'DISMISSAL'),
    ('CONVICTION_FELONY',   'Conviction of a Crime/Felony',  'GRAVE',      'RRACA Sec. 46(A)(13)', 'DISMISSAL'),
    ('FALSIFICATION',       'Falsification of Official Docs','GRAVE',      'RRACA Sec. 46(A)(6)',  'DISMISSAL'),
    ('OPPRESSION',          'Oppression',                    'GRAVE',      'RRACA Sec. 46(A)(4)',  'DISMISSAL'),
    -- LESS GRAVE offenses
    ('SIMPLE_MISCONDUCT',   'Simple Misconduct',             'LESS_GRAVE', 'RRACA Sec. 46(B)(1)',  'SUSPENSION_1_6MO'),
    ('FREQ_UNAUTH_ABSENCE', 'Frequent Unauthorized Absences','LESS_GRAVE', 'RRACA Sec. 46(B)(5)',  'SUSPENSION_1_6MO'),
    ('GROSS_DISCOURTESY',   'Gross Discourtesy',             'LESS_GRAVE', 'RRACA Sec. 46(B)(6)',  'SUSPENSION_1_6MO'),
    ('INSUBORDINATION',     'Insubordination',               'LESS_GRAVE', 'RRACA Sec. 46(B)(4)',  'SUSPENSION_1_6MO'),
    -- LIGHT offenses
    ('DISCOURTESY',         'Discourtesy in Course of Duty', 'LIGHT',      'RRACA Sec. 46(C)(2)',  'REPRIMAND'),
    ('SIMPLE_NEGLECT',      'Simple Neglect of Duty',        'LIGHT',      'RRACA Sec. 46(C)(1)',  'REPRIMAND'),
    ('VIOLATION_OFFICE_HRS','Violation of Office Hours',     'LIGHT',      'RRACA Sec. 46(C)(4)',  'REPRIMAND'),
    ('GAMBLING',            'Gambling Prohibited by Law',    'LIGHT',      'RRACA Sec. 46(C)(7)',  'REPRIMAND')
ON CONFLICT (code) DO NOTHING;

-- ================================================================
-- WORKFLOW DEFINITIONS
-- ================================================================
INSERT INTO workflow.workflow_definitions (code, name, module, description, is_active) VALUES
    ('DISC_ADMIN_CASE',
     'Administrative Case Workflow',
     'discipline',
     'Complaint → Prelim Investigation → Formal Charge → Hearing → Decision → Appeal',
     TRUE),
    ('DMS_DOCUMENT_REQUEST',
     'Document Request Workflow',
     'dms',
     'Request → HR Review → Fulfilled',
     TRUE),
    ('HEALTH_INCIDENT_REPORT',
     'Incident Report Workflow',
     'health',
     'Reported → Investigation → Corrective Action → Closed',
     TRUE)
ON CONFLICT (code) DO NOTHING;

-- ================================================================
-- RBAC: Grant all roles access to Phase 3 pages
-- ================================================================
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.code, p.id, TRUE
FROM core.page_registry p
CROSS JOIN (VALUES ('SUPER_ADMIN'), ('HR_ADMIN'), ('MANAGER'), ('EMPLOYEE'), ('EXECUTIVE')) AS r(code)
WHERE p.module IN ('dms', 'discipline', 'health')
ON CONFLICT DO NOTHING;
