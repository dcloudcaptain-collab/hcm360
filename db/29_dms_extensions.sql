-- ================================================================
-- HCM360 HRIS — 29: DOCUMENT MANAGEMENT / 201 FILE
-- Schema    : dms
-- Standards : CSC MC 8-2020, RA 9470 (National Archives Act)
-- ================================================================

CREATE SCHEMA IF NOT EXISTS dms;
SET search_path TO dms, core, workflow, public;

-- ----------------------------------------------------------------
-- Extend core.documents with DMS classification
-- ----------------------------------------------------------------
ALTER TABLE core.documents ADD COLUMN IF NOT EXISTS category_id      BIGINT;
ALTER TABLE core.documents ADD COLUMN IF NOT EXISTS retention_until   DATE;
ALTER TABLE core.documents ADD COLUMN IF NOT EXISTS is_archived       BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_docs_category  ON core.documents(category_id);
CREATE INDEX IF NOT EXISTS idx_docs_archived  ON core.documents(is_archived) WHERE is_archived;

-- ----------------------------------------------------------------
-- DOCUMENT CATEGORIES (hierarchical 201 classification)
-- ----------------------------------------------------------------
CREATE TABLE dms.document_categories (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES core.companies(id),
    code            VARCHAR(40)  NOT NULL,
    name            VARCHAR(200) NOT NULL,
    parent_id       BIGINT       REFERENCES dms.document_categories(id),
    description     TEXT,
    sort_order      INTEGER      NOT NULL DEFAULT 99,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, code)
);

-- FK from core.documents to dms.document_categories
ALTER TABLE core.documents
    ADD CONSTRAINT fk_docs_category
    FOREIGN KEY (category_id) REFERENCES dms.document_categories(id);

-- ----------------------------------------------------------------
-- RETENTION POLICIES
-- ----------------------------------------------------------------
CREATE TABLE dms.retention_policies (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES core.companies(id),
    category_id     BIGINT       NOT NULL REFERENCES dms.document_categories(id),
    retention_years INTEGER      NOT NULL DEFAULT 10,
    retention_basis VARCHAR(60)  NOT NULL DEFAULT 'FROM_UPLOAD'
                        CHECK (retention_basis IN ('FROM_UPLOAD', 'FROM_SEPARATION', 'FROM_EXPIRY')),
    disposal_method VARCHAR(30)  NOT NULL DEFAULT 'ARCHIVE'
                        CHECK (disposal_method IN ('ARCHIVE', 'SHRED', 'DELETE')),
    legal_basis     VARCHAR(200),
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, category_id)
);

-- ----------------------------------------------------------------
-- 201 FILE CHECKLIST TEMPLATES
-- ----------------------------------------------------------------
CREATE TABLE dms.checklist_templates (
    id                  BIGSERIAL    PRIMARY KEY,
    company_id          BIGINT       NOT NULL REFERENCES core.companies(id),
    employment_type_id  BIGINT       REFERENCES core.employment_types(id),
    name                VARCHAR(200) NOT NULL,
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE dms.checklist_items (
    id              BIGSERIAL    PRIMARY KEY,
    template_id     BIGINT       NOT NULL REFERENCES dms.checklist_templates(id) ON DELETE CASCADE,
    category_id     BIGINT       REFERENCES dms.document_categories(id),
    document_type   VARCHAR(60)  NOT NULL,
    label           VARCHAR(200) NOT NULL,
    is_mandatory    BOOLEAN      NOT NULL DEFAULT TRUE,
    sort_order      INTEGER      NOT NULL DEFAULT 99
);

-- ----------------------------------------------------------------
-- DOCUMENT REQUESTS
-- ----------------------------------------------------------------
CREATE TABLE dms.document_requests (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES core.companies(id),
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    document_type   VARCHAR(60)  NOT NULL,
    purpose         TEXT,
    requested_by    BIGINT       NOT NULL REFERENCES core.users(id),
    due_date        DATE,
    status          VARCHAR(20)  NOT NULL DEFAULT 'PENDING'
                        CHECK (status IN ('PENDING', 'SUBMITTED', 'OVERDUE', 'CANCELLED')),
    fulfilled_doc_id BIGINT      REFERENCES core.documents(id),
    remarks         TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_dms_requests_emp ON dms.document_requests(employee_id, status);

-- ----------------------------------------------------------------
-- CSC FORM 212 (SERVICE RECORD) SNAPSHOTS
-- ----------------------------------------------------------------
CREATE TABLE dms.service_record_snapshots (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    generated_by    BIGINT       REFERENCES core.users(id),
    generated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    snapshot_data   JSONB        NOT NULL,
    file_path       TEXT,
    is_latest       BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_svc_record_emp ON dms.service_record_snapshots(employee_id, is_latest)
    WHERE is_latest = TRUE;

-- ================================================================
-- SEED: PAGE REGISTRY
-- ================================================================
INSERT INTO core.page_registry
    (path, title, nav_group, nav_label, module, nav_icon, nav_order, requires_feature)
VALUES
    ('/dms/',             '201 File Dashboard',  '201 File', 'Dashboard',  'dms', '📁', 10, 'DMS'),
    ('/dms/checklist',    'Document Checklist',  '201 File', 'Checklist',  'dms', '✅', 20, 'DMS'),
    ('/dms/requests',     'Document Requests',   '201 File', 'Requests',   'dms', '📨', 30, 'DMS'),
    ('/dms/retention',    'Retention Policies',  '201 File', 'Retention',  'dms', '🗄️', 40, 'DMS')
ON CONFLICT (path) DO NOTHING;

-- ================================================================
-- SEED: FEATURE FLAG
-- ================================================================
INSERT INTO core.feature_registry (code, name, description, module, is_enabled) VALUES
    ('DMS', 'Document Management', '201 File / DMS — digital employee file', 'dms', TRUE)
ON CONFLICT (code) DO NOTHING;
