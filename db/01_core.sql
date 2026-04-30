-- ================================================================
-- HCM360 HRIS — 01: CORE SCHEMA
-- Schema    : core
-- Contains  : organization, users, RBAC, employee master, documents,
--             UI configuration, page registry, feature flags
-- ================================================================

SET search_path TO core, public;

-- ── Organization ─────────────────────────────────────────────────

CREATE TABLE core.companies (
    id                  BIGSERIAL    PRIMARY KEY,
    code                VARCHAR(20)  NOT NULL UNIQUE,
    name                VARCHAR(200) NOT NULL,
    legal_name          VARCHAR(200),
    industry            VARCHAR(100),
    size_bracket        VARCHAR(20)  NOT NULL DEFAULT 'MSME',
    address_line1       TEXT,
    address_line2       TEXT,
    barangay            VARCHAR(100),
    city                VARCHAR(100),
    province            VARCHAR(100),
    region              VARCHAR(100),
    zip_code            VARCHAR(10),
    country             VARCHAR(100) NOT NULL DEFAULT 'Philippines',
    phone               VARCHAR(30),
    email               VARCHAR(200),
    website             VARCHAR(200),
    tin                 VARCHAR(20),
    sss_employer_id     VARCHAR(30),
    phic_employer_id    VARCHAR(30),
    hdmf_employer_id    VARCHAR(30),
    logo_path           TEXT,
    fiscal_year_start   INTEGER      NOT NULL DEFAULT 1,
    payroll_cycle       VARCHAR(20)  NOT NULL DEFAULT 'SEMI_MONTHLY',
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    metadata            JSONB        NOT NULL DEFAULT '{}',
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE core.business_units (
    id                  BIGSERIAL    PRIMARY KEY,
    company_id          BIGINT       NOT NULL REFERENCES core.companies(id),
    code                VARCHAR(20)  NOT NULL,
    name                VARCHAR(200) NOT NULL,
    parent_id           BIGINT       REFERENCES core.business_units(id),
    head_employee_id    BIGINT,
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, code)
);

CREATE TABLE core.departments (
    id                  BIGSERIAL    PRIMARY KEY,
    company_id          BIGINT       NOT NULL REFERENCES core.companies(id),
    business_unit_id    BIGINT       REFERENCES core.business_units(id),
    code                VARCHAR(20)  NOT NULL,
    name                VARCHAR(200) NOT NULL,
    parent_id           BIGINT       REFERENCES core.departments(id),
    head_employee_id    BIGINT,
    cost_center_code    VARCHAR(20),
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, code)
);

CREATE TABLE core.job_grades (
    id                  BIGSERIAL    PRIMARY KEY,
    company_id          BIGINT       NOT NULL REFERENCES core.companies(id),
    code                VARCHAR(20)  NOT NULL,
    name                VARCHAR(100) NOT NULL,
    grade_level         INTEGER      NOT NULL,
    salary_min          NUMERIC(14,2),
    salary_max          NUMERIC(14,2),
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, code)
);

CREATE TABLE core.positions (
    id                  BIGSERIAL    PRIMARY KEY,
    company_id          BIGINT       NOT NULL REFERENCES core.companies(id),
    department_id       BIGINT       REFERENCES core.departments(id),
    job_grade_id        BIGINT       REFERENCES core.job_grades(id),
    code                VARCHAR(20)  NOT NULL,
    title               VARCHAR(200) NOT NULL,
    description         TEXT,
    is_managerial       BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, code)
);

CREATE TABLE core.employment_types (
    id                   BIGSERIAL    PRIMARY KEY,
    code                 VARCHAR(30)  NOT NULL UNIQUE,
    name                 VARCHAR(100) NOT NULL,
    description          TEXT,
    is_entitled_benefits BOOLEAN      NOT NULL DEFAULT TRUE,
    probation_days       INTEGER      NOT NULL DEFAULT 0,
    is_active            BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── Users & RBAC ─────────────────────────────────────────────────

CREATE TABLE core.users (
    id                  BIGSERIAL    PRIMARY KEY,
    company_id          BIGINT       REFERENCES core.companies(id),
    username            VARCHAR(100) NOT NULL UNIQUE,
    email               VARCHAR(200) UNIQUE,
    password_hash       VARCHAR(255) NOT NULL DEFAULT '',
    display_name        VARCHAR(150),
    role_code           VARCHAR(50)  NOT NULL DEFAULT 'EMPLOYEE',
    employee_id         BIGINT,
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    last_login_at       TIMESTAMPTZ,
    failed_attempts     INTEGER      NOT NULL DEFAULT 0,
    locked_until        TIMESTAMPTZ,
    password_changed_at TIMESTAMPTZ,
    mfa_enabled         BOOLEAN      NOT NULL DEFAULT FALSE,
    mfa_secret          VARCHAR(100),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE core.roles (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       REFERENCES core.companies(id),
    code            VARCHAR(50)  NOT NULL,
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    is_system_role  BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, code)
);

CREATE TABLE core.permissions (
    id          BIGSERIAL    PRIMARY KEY,
    module      VARCHAR(50)  NOT NULL,
    resource    VARCHAR(100) NOT NULL,
    action      VARCHAR(50)  NOT NULL,
    description TEXT,
    UNIQUE (module, resource, action)
);

CREATE TABLE core.role_permissions (
    id            BIGSERIAL    PRIMARY KEY,
    role_id       BIGINT       NOT NULL REFERENCES core.roles(id) ON DELETE CASCADE,
    permission_id BIGINT       NOT NULL REFERENCES core.permissions(id) ON DELETE CASCADE,
    granted       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (role_id, permission_id)
);

CREATE TABLE core.user_roles (
    id          BIGSERIAL    PRIMARY KEY,
    user_id     BIGINT       NOT NULL REFERENCES core.users(id) ON DELETE CASCADE,
    role_id     BIGINT       NOT NULL REFERENCES core.roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    assigned_by BIGINT       REFERENCES core.users(id),
    expires_at  TIMESTAMPTZ,
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    UNIQUE (user_id, role_id)
);

-- ── Page / Feature Registry (existing RBAC tables) ───────────────

CREATE TABLE core.page_registry (
    id          BIGSERIAL    PRIMARY KEY,
    path        VARCHAR(200) NOT NULL UNIQUE,
    title       VARCHAR(100) NOT NULL,
    module      VARCHAR(50),
    nav_group   VARCHAR(50),
    nav_label   VARCHAR(100),
    nav_icon    VARCHAR(50),
    nav_order   INTEGER      NOT NULL DEFAULT 99,
    is_visible  BOOLEAN      NOT NULL DEFAULT TRUE,
    requires_feature VARCHAR(60),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE core.role_page_access (
    id          BIGSERIAL    PRIMARY KEY,
    role_code   VARCHAR(50)  NOT NULL,
    page_id     BIGINT       NOT NULL REFERENCES core.page_registry(id) ON DELETE CASCADE,
    can_access  BOOLEAN      NOT NULL DEFAULT TRUE,
    UNIQUE (role_code, page_id)
);

CREATE TABLE core.feature_registry (
    id              BIGSERIAL    PRIMARY KEY,
    code            VARCHAR(60)  NOT NULL UNIQUE,
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    module          VARCHAR(50),
    is_enabled      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE core.role_feature_access (
    id          BIGSERIAL    PRIMARY KEY,
    role_code   VARCHAR(50)  NOT NULL,
    feature_id  BIGINT       NOT NULL REFERENCES core.feature_registry(id) ON DELETE CASCADE,
    can_access  BOOLEAN      NOT NULL DEFAULT TRUE,
    UNIQUE (role_code, feature_id)
);

-- ── Status Definitions ───────────────────────────────────────────

CREATE TABLE core.status_definitions (
    id          BIGSERIAL    PRIMARY KEY,
    module      VARCHAR(50)  NOT NULL,
    code        VARCHAR(50)  NOT NULL,
    label       VARCHAR(100) NOT NULL,
    color       VARCHAR(20)  NOT NULL DEFAULT '#94a3b8',
    badge_class VARCHAR(50),
    sort_order  INTEGER      NOT NULL DEFAULT 99,
    UNIQUE (module, code)
);

-- ── UI / Branding ─────────────────────────────────────────────────

CREATE TABLE core.ui_themes (
    id          BIGSERIAL    PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    is_active   BOOLEAN      NOT NULL DEFAULT FALSE,
    primary_color   VARCHAR(20),
    secondary_color VARCHAR(20),
    accent_color    VARCHAR(20),
    bg_color        VARCHAR(20),
    card_color      VARCHAR(20),
    sidebar_color   VARCHAR(20),
    sidebar_text    VARCHAR(20),
    border_radius   VARCHAR(10),
    font_family     VARCHAR(100),
    text_color      VARCHAR(20),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE core.company_branding (
    id          BIGSERIAL    PRIMARY KEY,
    company_id  BIGINT       REFERENCES core.companies(id),
    key         VARCHAR(60)  NOT NULL UNIQUE,
    value       TEXT,
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── Dashboard / Search Infrastructure ────────────────────────────

CREATE TABLE core.dashboard_metrics (
    id          BIGSERIAL    PRIMARY KEY,
    code        VARCHAR(60)  NOT NULL UNIQUE,
    label       VARCHAR(100) NOT NULL,
    icon        VARCHAR(50),
    module      VARCHAR(50),
    sql_query   TEXT         NOT NULL,
    filter_url  VARCHAR(300),
    roles       TEXT[]       NOT NULL DEFAULT '{}',
    sort_order  INTEGER      NOT NULL DEFAULT 99,
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE core.search_index (
    id          BIGSERIAL    PRIMARY KEY,
    entity_type VARCHAR(50)  NOT NULL,
    entity_id   BIGINT       NOT NULL,
    title       VARCHAR(200) NOT NULL,
    subtitle    VARCHAR(200),
    keywords    TEXT,
    url         VARCHAR(300),
    module      VARCHAR(50),
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_search_fts ON core.search_index
    USING GIN (to_tsvector('english', coalesce(title,'') || ' ' || coalesce(subtitle,'') || ' ' || coalesce(keywords,'')));

-- ── Dynamic Forms / Orchestration ────────────────────────────────

CREATE TABLE core.dynamic_forms (
    id          BIGSERIAL    PRIMARY KEY,
    form_code   VARCHAR(60)  NOT NULL UNIQUE,
    title       VARCHAR(100) NOT NULL,
    module      VARCHAR(50),
    description TEXT,
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE core.form_fields (
    id          BIGSERIAL    PRIMARY KEY,
    form_id     BIGINT       NOT NULL REFERENCES core.dynamic_forms(id) ON DELETE CASCADE,
    field_name  VARCHAR(60)  NOT NULL,
    label       VARCHAR(100) NOT NULL,
    field_type  VARCHAR(30)  NOT NULL DEFAULT 'TEXT',
    is_required BOOLEAN      NOT NULL DEFAULT FALSE,
    options     JSONB,
    sort_order  INTEGER      NOT NULL DEFAULT 99
);

CREATE TABLE core.transaction_registry (
    id              BIGSERIAL    PRIMARY KEY,
    module          VARCHAR(50)  NOT NULL,
    type_code       VARCHAR(60)  NOT NULL UNIQUE,
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    workflow_def_code VARCHAR(60),
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE core.transaction_qr_tokens (
    id              BIGSERIAL    PRIMARY KEY,
    token           VARCHAR(100) NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(16), 'hex'),
    module          VARCHAR(50)  NOT NULL,
    entity_type     VARCHAR(60)  NOT NULL,
    entity_id       BIGINT       NOT NULL,
    expires_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE core.orchestration_flows (
    id          BIGSERIAL    PRIMARY KEY,
    flow_code   VARCHAR(60)  NOT NULL UNIQUE,
    name        VARCHAR(100) NOT NULL,
    description TEXT,
    trigger_event VARCHAR(100),
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE core.orchestration_steps (
    id          BIGSERIAL    PRIMARY KEY,
    flow_id     BIGINT       NOT NULL REFERENCES core.orchestration_flows(id) ON DELETE CASCADE,
    step_order  INTEGER      NOT NULL,
    action_type VARCHAR(50)  NOT NULL,
    action_config JSONB      NOT NULL DEFAULT '{}',
    condition   TEXT
);

-- ── Employee Master Data ──────────────────────────────────────────

CREATE TABLE core.employees (
    id                      BIGSERIAL    PRIMARY KEY,
    uuid                    UUID         NOT NULL DEFAULT uuid_generate_v4() UNIQUE,
    company_id              BIGINT       NOT NULL REFERENCES core.companies(id),
    employee_no             VARCHAR(30)  NOT NULL,
    last_name               VARCHAR(100) NOT NULL,
    first_name              VARCHAR(100) NOT NULL,
    middle_name             VARCHAR(100),
    suffix                  VARCHAR(10),
    preferred_name          VARCHAR(100),
    gender                  VARCHAR(20),
    civil_status            VARCHAR(20),
    nationality             VARCHAR(50)  NOT NULL DEFAULT 'Filipino',
    religion                VARCHAR(50),
    date_of_birth           DATE,
    place_of_birth          VARCHAR(200),
    blood_type              VARCHAR(5),
    personal_email          VARCHAR(200),
    work_email              VARCHAR(200),
    mobile_no               VARCHAR(20),
    phone_no                VARCHAR(20),
    department_id           BIGINT       REFERENCES core.departments(id),
    position_id             BIGINT       REFERENCES core.positions(id),
    job_grade_id            BIGINT       REFERENCES core.job_grades(id),
    employment_type_id      BIGINT       REFERENCES core.employment_types(id),
    immediate_supervisor_id BIGINT       REFERENCES core.employees(id),
    date_hired              DATE,
    date_regularized        DATE,
    probation_end_date      DATE,
    date_separated          DATE,
    status                  VARCHAR(30)  NOT NULL DEFAULT 'PROBATIONARY',
    separation_reason       TEXT,
    basic_salary            NUMERIC(14,2),
    daily_rate              NUMERIC(10,4),
    hourly_rate             NUMERIC(10,4),
    cost_center_code        VARCHAR(20),
    work_location           VARCHAR(200),
    work_arrangement        VARCHAR(20)  NOT NULL DEFAULT 'ONSITE',
    height_cm               NUMERIC(5,1),
    weight_kg               NUMERIC(5,1),
    profile_photo_path      TEXT,
    is_active               BOOLEAN      NOT NULL DEFAULT TRUE,
    metadata                JSONB        NOT NULL DEFAULT '{}',
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_by              BIGINT       REFERENCES core.users(id),
    updated_by              BIGINT       REFERENCES core.users(id),
    UNIQUE (company_id, employee_no)
);

-- Link users.employee_id → employees after both tables exist
ALTER TABLE core.users ADD CONSTRAINT fk_users_employee
    FOREIGN KEY (employee_id) REFERENCES core.employees(id);
ALTER TABLE core.business_units ADD CONSTRAINT fk_bu_head
    FOREIGN KEY (head_employee_id) REFERENCES core.employees(id);
ALTER TABLE core.departments ADD CONSTRAINT fk_dept_head
    FOREIGN KEY (head_employee_id) REFERENCES core.employees(id);

CREATE INDEX idx_emp_company     ON core.employees(company_id, is_active);
CREATE INDEX idx_emp_dept        ON core.employees(department_id);
CREATE INDEX idx_emp_status      ON core.employees(status);
CREATE INDEX idx_emp_supervisor  ON core.employees(immediate_supervisor_id);
CREATE INDEX idx_emp_name_trgm   ON core.employees USING GIN (
    (lower(last_name || ' ' || first_name)) gin_trgm_ops
);

CREATE TABLE core.emp_addresses (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id) ON DELETE CASCADE,
    address_type    VARCHAR(30)  NOT NULL,
    line1           TEXT         NOT NULL,
    line2           TEXT,
    barangay        VARCHAR(100),
    city            VARCHAR(100),
    province        VARCHAR(100),
    region          VARCHAR(100),
    zip_code        VARCHAR(10),
    country         VARCHAR(100) NOT NULL DEFAULT 'Philippines',
    is_primary      BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE core.emp_emergency_contacts (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id) ON DELETE CASCADE,
    full_name       VARCHAR(200) NOT NULL,
    relationship    VARCHAR(50)  NOT NULL,
    mobile_no       VARCHAR(20),
    phone_no        VARCHAR(20),
    address         TEXT,
    is_primary      BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE core.emp_government_ids (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id) ON DELETE CASCADE,
    id_type         VARCHAR(30)  NOT NULL,
    id_number       VARCHAR(50)  NOT NULL,
    issue_date      DATE,
    expiry_date     DATE,
    file_path       TEXT,
    is_verified     BOOLEAN      NOT NULL DEFAULT FALSE,
    verified_by     BIGINT       REFERENCES core.users(id),
    verified_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (employee_id, id_type)
);

CREATE TABLE core.emp_bank_accounts (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id) ON DELETE CASCADE,
    bank_name       VARCHAR(100) NOT NULL,
    bank_code       VARCHAR(20),
    account_name    VARCHAR(200) NOT NULL,
    account_number  VARCHAR(50)  NOT NULL,
    account_type    VARCHAR(30)  NOT NULL DEFAULT 'SAVINGS',
    is_primary      BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE core.emp_dependents (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id) ON DELETE CASCADE,
    full_name       VARCHAR(200) NOT NULL,
    relationship    VARCHAR(50)  NOT NULL,
    date_of_birth   DATE,
    is_beneficiary  BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE core.emp_education (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id) ON DELETE CASCADE,
    level           VARCHAR(50)  NOT NULL,
    institution     VARCHAR(200) NOT NULL,
    degree          VARCHAR(200),
    field_of_study  VARCHAR(200),
    year_from       INTEGER,
    year_to         INTEGER,
    honors          VARCHAR(100),
    is_highest      BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE core.emp_work_history (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id) ON DELETE CASCADE,
    company_name        VARCHAR(200) NOT NULL,
    position_held       VARCHAR(200),
    date_from           DATE,
    date_to             DATE,
    reason_for_leaving  TEXT,
    immediate_supervisor VARCHAR(200),
    contact_no          VARCHAR(30),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE core.emp_status_history (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id) ON DELETE CASCADE,
    from_status     VARCHAR(30),
    to_status       VARCHAR(30)  NOT NULL,
    effective_date  DATE         NOT NULL,
    reason          TEXT,
    remarks         TEXT,
    changed_by      BIGINT       REFERENCES core.users(id),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── Documents (201 file / HR documents) ──────────────────────────

CREATE TABLE core.documents (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       REFERENCES core.companies(id),
    employee_id     BIGINT       REFERENCES core.employees(id),
    document_type   VARCHAR(60)  NOT NULL,
    document_name   VARCHAR(200) NOT NULL,
    file_path       TEXT,
    file_size_kb    INTEGER,
    mime_type       VARCHAR(100),
    is_missing      BOOLEAN      NOT NULL DEFAULT FALSE,
    is_expired      BOOLEAN      NOT NULL DEFAULT FALSE,
    expiry_date     DATE,
    uploaded_by     BIGINT       REFERENCES core.users(id),
    verified_by     BIGINT       REFERENCES core.users(id),
    verified_at     TIMESTAMPTZ,
    status          VARCHAR(30)  NOT NULL DEFAULT 'PENDING',
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_docs_employee    ON core.documents(employee_id, status);
CREATE INDEX idx_docs_missing     ON core.documents(company_id, is_missing) WHERE is_missing;
CREATE INDEX idx_docs_expiry      ON core.documents(expiry_date) WHERE expiry_date IS NOT NULL;

-- ── Org Chart ─────────────────────────────────────────────────────

CREATE TABLE core.org_chart_nodes (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES core.companies(id),
    employee_id     BIGINT       REFERENCES core.employees(id),
    position_id     BIGINT       REFERENCES core.positions(id),
    parent_node_id  BIGINT       REFERENCES core.org_chart_nodes(id),
    node_type       VARCHAR(30)  NOT NULL DEFAULT 'POSITION',
    effective_from  DATE         NOT NULL,
    effective_to    DATE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
