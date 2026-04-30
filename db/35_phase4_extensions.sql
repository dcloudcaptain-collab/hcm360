-- ================================================================
-- HCM360 HRIS — 35: PHASE 4 EXTENSIONS
-- Certificate Request System + Org Chart config
-- ================================================================
SET search_path TO dms, core, workflow, public;

-- ----------------------------------------------------------------
-- CERTIFICATE TYPES (COE, Service Record, SALN Copy, etc.)
-- ----------------------------------------------------------------
CREATE TABLE dms.certificate_types (
    id              BIGSERIAL    PRIMARY KEY,
    code            VARCHAR(30)  NOT NULL UNIQUE,
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    processing_days INTEGER      NOT NULL DEFAULT 3,
    requires_approval BOOLEAN    NOT NULL DEFAULT TRUE,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE
);

INSERT INTO dms.certificate_types (code, name, description, processing_days) VALUES
    ('COE',              'Certificate of Employment',          'Certifies current/former employment',  2),
    ('SERVICE_RECORD',   'Service Record (CS Form 212)',       'Official government service record',   3),
    ('SALN_COPY',        'Copy of SALN',                      'Statement of Assets, Liabilities & Net Worth', 3),
    ('APPOINTMENT_COPY', 'Copy of Appointment',               'Copy of appointment paper',            2),
    ('EMPLOYMENT_CERT',  'Certificate of No Pending Case',    'Certifies no pending admin case',      3),
    ('LEAVE_CERT',       'Certificate of Leave Credits',      'Certifies remaining leave balance',    1),
    ('COMPENSATION_CERT','Certificate of Compensation/Tax',   'BIR Form 2316 / Compensation cert',   5)
ON CONFLICT (code) DO NOTHING;

-- ----------------------------------------------------------------
-- CERTIFICATE REQUESTS
-- ----------------------------------------------------------------
CREATE TABLE dms.certificate_requests (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id),
    cert_type_id        BIGINT       NOT NULL REFERENCES dms.certificate_types(id),
    purpose             TEXT,
    copies_requested    INTEGER      NOT NULL DEFAULT 1,
    status              VARCHAR(20)  NOT NULL DEFAULT 'PENDING'
                            CHECK (status IN ('PENDING', 'PROCESSING', 'READY', 'RELEASED', 'REJECTED')),
    requested_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    processed_by        BIGINT       REFERENCES core.users(id),
    processed_at        TIMESTAMPTZ,
    released_at         TIMESTAMPTZ,
    released_by         BIGINT       REFERENCES core.users(id),
    document_id         BIGINT       REFERENCES core.documents(id),
    rejection_reason    TEXT,
    workflow_instance_id BIGINT,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_cert_req_emp ON dms.certificate_requests(employee_id, status);
CREATE INDEX idx_cert_req_status ON dms.certificate_requests(status) WHERE status IN ('PENDING', 'PROCESSING');

-- ================================================================
-- WORKFLOW: Certificate Request
-- ================================================================
INSERT INTO workflow.workflow_definitions (code, name, module, description, is_active) VALUES
    ('CERT_REQUEST_APPROVAL', 'Certificate Request Approval', 'dms',
     'Employee Request → HR Processing → Release', TRUE)
ON CONFLICT (code) DO NOTHING;

-- ================================================================
-- PAGE REGISTRY — Phase 4 additions
-- ================================================================
INSERT INTO core.page_registry
    (path, title, nav_group, nav_label, module, nav_icon, nav_order, requires_feature)
VALUES
    ('/reports/demographics',       'HR Demographics',       'Analytics', 'Demographics', 'analytics', '📊', 25, NULL),
    ('/attendance/alerts',          'Attendance Alerts',     'Workforce', 'Alerts',       'attendance', '⚠️', 35, NULL),
    ('/attendance/shifts',          'Shift Schedules',       'Workforce', 'Shifts',       'attendance', '🕐', 36, NULL),
    ('/attendance/shift-assignments','Shift Assignments',    'Workforce', 'Assign Shifts','attendance', '📋', 37, NULL),
    ('/me/certificates',            'My Certificates',       'Self-Service', 'Certificates', 'dms', '📜', 35, 'DMS'),
    ('/dms/certificate-requests',   'Certificate Queue',     '201 File', 'Cert Queue',   'dms', '📜', 50, 'DMS'),
    ('/orgchart/',                  'Organization Chart',    'Org Chart', 'Org Chart',    'orgchart', '🏛️', 10, 'ORGCHART')
ON CONFLICT (path) DO NOTHING;

-- ================================================================
-- FEATURE FLAG — Org Chart
-- ================================================================
INSERT INTO core.feature_registry (code, name, description, module, is_enabled) VALUES
    ('ORGCHART', 'Organization Chart', 'Interactive org chart visualization', 'orgchart', TRUE)
ON CONFLICT (code) DO NOTHING;

-- ================================================================
-- RBAC — Grant access to Phase 4 pages
-- ================================================================
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.code, p.id, TRUE
FROM core.page_registry p
CROSS JOIN (VALUES ('SUPER_ADMIN'), ('HR_ADMIN'), ('MANAGER'), ('EMPLOYEE'), ('EXECUTIVE')) AS r(code)
WHERE p.path IN (
    '/reports/demographics', '/attendance/alerts', '/attendance/shifts',
    '/attendance/shift-assignments', '/me/certificates', '/dms/certificate-requests',
    '/orgchart/'
)
ON CONFLICT DO NOTHING;
