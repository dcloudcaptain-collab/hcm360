-- ================================================================
-- HCM360 CHANGE TRACKING & AUDIT LAYER
-- Loaded after: hris_schema.sql
-- Captures every INSERT / UPDATE / DELETE across all modules,
-- normalizes field-level diffs, and exposes analytics views.
-- ================================================================
--
-- How it works
-- ─────────────────────────────────────────────────────────────────
-- 1. sys_change_log      – one row per DML operation (partitioned)
-- 2. sys_field_changes   – one row per changed field (UPDATE only)
-- 3. sys_login_logs      – dedicated auth event log
-- 4. sys_data_exports    – tracks every data export / download
-- 5. fn_capture_change() – generic AFTER trigger applied to all tables
-- 6. Triggers            – installed on every business-data table
-- 7. Analytics views     – ready for dashboard / reporting queries
--
-- App integration required
-- ─────────────────────────────────────────────────────────────────
-- At the start of each DB transaction the application must run:
--   SET LOCAL app.current_user_id    = '<user_id>';
--   SET LOCAL app.current_company_id = '<company_id>';
--   SET LOCAL app.client_ip          = '<ip_address>';
-- This lets the trigger capture who made the change.
-- ================================================================

-- ── Extensions (idempotent) ──────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ================================================================
-- TABLE: sys_change_log (partitioned by month)
-- One row per INSERT / UPDATE / DELETE on any tracked table
-- ================================================================
CREATE TABLE sys_change_log (
    id              BIGSERIAL        NOT NULL,
    -- What changed
    schema_name     VARCHAR(63)      NOT NULL DEFAULT 'public',
    table_name      VARCHAR(100)     NOT NULL,
    operation       VARCHAR(10)      NOT NULL,  -- INSERT | UPDATE | DELETE
    row_id          BIGINT,                     -- PK of the affected row
    row_uuid        UUID,                       -- UUID column if present
    -- Before / after snapshot
    old_data        JSONB,                      -- NULL for INSERT
    new_data        JSONB,                      -- NULL for DELETE
    changed_fields  TEXT[],                     -- list of field names that changed (UPDATE)
    -- Context
    user_id         BIGINT,
    company_id      BIGINT,
    client_ip       INET,
    session_id      VARCHAR(100),
    app_context     VARCHAR(100),               -- e.g. 'PAYROLL_RUN', 'LEAVE_APPROVAL'
    -- Metadata
    created_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE sys_change_log_2025 PARTITION OF sys_change_log FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE sys_change_log_2026 PARTITION OF sys_change_log FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE sys_change_log_2027 PARTITION OF sys_change_log FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
CREATE TABLE sys_change_log_2028 PARTITION OF sys_change_log FOR VALUES FROM ('2028-01-01') TO ('2029-01-01');

CREATE INDEX idx_chg_table_rowid   ON sys_change_log (table_name, row_id, created_at);
CREATE INDEX idx_chg_user          ON sys_change_log (user_id, created_at);
CREATE INDEX idx_chg_company       ON sys_change_log (company_id, created_at);
CREATE INDEX idx_chg_operation     ON sys_change_log (operation, table_name, created_at);

-- ================================================================
-- TABLE: sys_field_changes (partitioned by month)
-- One row per field that changed in an UPDATE operation.
-- Enables "show history of this field" queries.
-- ================================================================
CREATE TABLE sys_field_changes (
    id              BIGSERIAL        NOT NULL,
    change_log_id   BIGINT           NOT NULL,  -- → sys_change_log.id
    table_name      VARCHAR(100)     NOT NULL,
    row_id          BIGINT,
    field_name      VARCHAR(100)     NOT NULL,
    old_value       TEXT,
    new_value       TEXT,
    data_type       VARCHAR(50),                -- inferred from JSONB
    user_id         BIGINT,
    created_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE sys_field_changes_2025 PARTITION OF sys_field_changes FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE sys_field_changes_2026 PARTITION OF sys_field_changes FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE sys_field_changes_2027 PARTITION OF sys_field_changes FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
CREATE TABLE sys_field_changes_2028 PARTITION OF sys_field_changes FOR VALUES FROM ('2028-01-01') TO ('2029-01-01');

CREATE INDEX idx_fchg_table_field  ON sys_field_changes (table_name, field_name, created_at);
CREATE INDEX idx_fchg_row          ON sys_field_changes (table_name, row_id, created_at);
CREATE INDEX idx_fchg_user         ON sys_field_changes (user_id, created_at);

-- ================================================================
-- TABLE: sys_login_logs
-- Dedicated auth event log (login, logout, failed attempts, SSO)
-- ================================================================
CREATE TABLE sys_login_logs (
    id              BIGSERIAL        PRIMARY KEY,
    user_id         BIGINT           REFERENCES users(id),
    username        VARCHAR(100),
    company_id      BIGINT           REFERENCES companies(id),
    event_type      VARCHAR(30)      NOT NULL,
    -- LOGIN_SUCCESS | LOGIN_FAILED | LOGOUT | SSO_LOGIN
    -- PASSWORD_CHANGED | PASSWORD_RESET | ACCOUNT_LOCKED | MFA_SUCCESS | MFA_FAILED
    client_ip       INET,
    user_agent      TEXT,
    session_id      VARCHAR(100),
    sso_provider    VARCHAR(50),
    failure_reason  VARCHAR(200),
    created_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_login_user        ON sys_login_logs (user_id, created_at);
CREATE INDEX idx_login_event       ON sys_login_logs (event_type, created_at);
CREATE INDEX idx_login_ip          ON sys_login_logs (client_ip, created_at);

-- ================================================================
-- TABLE: sys_data_exports
-- Tracks every export / download / print for compliance
-- ================================================================
CREATE TABLE sys_data_exports (
    id              BIGSERIAL        PRIMARY KEY,
    user_id         BIGINT           REFERENCES users(id),
    company_id      BIGINT           REFERENCES companies(id),
    export_type     VARCHAR(50)      NOT NULL,
    -- EMPLOYEE_LIST | PAYSLIP | PAYROLL_REGISTER | ATTENDANCE_REPORT
    -- LEAVE_REPORT | SSS_R3 | PHILHEALTH_RF1 | PAGIBIG_MCF | BIR_2316
    -- ALPHALIST | CUSTOM_REPORT
    module          VARCHAR(50)      NOT NULL,
    format          VARCHAR(20)      NOT NULL DEFAULT 'CSV',  -- CSV | XLSX | PDF | JSON
    filter_params   JSONB            NOT NULL DEFAULT '{}',   -- what filters were applied
    row_count       INTEGER,
    file_path       TEXT,
    client_ip       INET,
    created_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_export_user       ON sys_data_exports (user_id, created_at);
CREATE INDEX idx_export_type       ON sys_data_exports (export_type, created_at);

-- ================================================================
-- TABLE: sys_status_transitions
-- Dedicated log for every status change across all modules.
-- Enables funnel analysis (e.g. leave approval cycle time).
-- ================================================================
CREATE TABLE sys_status_transitions (
    id              BIGSERIAL        PRIMARY KEY,
    module          VARCHAR(50)      NOT NULL,
    -- EMPLOYEE | LEAVE_REQUEST | PAYROLL_RUN | PERFORMANCE_REVIEW
    -- RECRUITMENT | TRAINING | WORKFLOW_INSTANCE
    entity_type     VARCHAR(100)     NOT NULL,
    entity_id       BIGINT           NOT NULL,
    from_status     VARCHAR(50),
    to_status       VARCHAR(50)      NOT NULL,
    transitioned_by BIGINT           REFERENCES users(id),
    reason          TEXT,
    duration_from_prev_ms BIGINT,    -- milliseconds since last transition (cycle time)
    metadata        JSONB            NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_st_module_entity  ON sys_status_transitions (module, entity_type, entity_id);
CREATE INDEX idx_st_created        ON sys_status_transitions (created_at);
CREATE INDEX idx_st_to_status      ON sys_status_transitions (module, to_status, created_at);

-- ================================================================
-- TABLE: sys_payroll_audit
-- Dedicated payroll change log — financial changes need extra detail
-- ================================================================
CREATE TABLE sys_payroll_audit (
    id              BIGSERIAL        PRIMARY KEY,
    run_id          BIGINT           REFERENCES pay_runs(id),
    employee_id     BIGINT           REFERENCES employees(id),
    field_name      VARCHAR(100)     NOT NULL,
    old_value       NUMERIC(14,2),
    new_value       NUMERIC(14,2),
    change_reason   TEXT,
    changed_by      BIGINT           REFERENCES users(id),
    created_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_pay_audit_run     ON sys_payroll_audit (run_id);
CREATE INDEX idx_pay_audit_emp     ON sys_payroll_audit (employee_id, created_at);

-- ================================================================
-- TABLE: sys_bulk_operation_logs
-- Tracks mass-actions: bulk upload, batch payroll compute, etc.
-- ================================================================
CREATE TABLE sys_bulk_operation_logs (
    id              BIGSERIAL        PRIMARY KEY,
    user_id         BIGINT           REFERENCES users(id),
    company_id      BIGINT           REFERENCES companies(id),
    operation_type  VARCHAR(100)     NOT NULL,
    -- BULK_EMPLOYEE_IMPORT | PAYROLL_COMPUTE | ATTENDANCE_IMPORT
    -- LEAVE_ACCRUAL_RUN | DOCUMENT_BULK_UPLOAD
    total_records   INTEGER          NOT NULL DEFAULT 0,
    success_count   INTEGER          NOT NULL DEFAULT 0,
    failure_count   INTEGER          NOT NULL DEFAULT 0,
    skipped_count   INTEGER          NOT NULL DEFAULT 0,
    error_log       JSONB            NOT NULL DEFAULT '[]',
    file_source     TEXT,
    started_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    completed_at    TIMESTAMPTZ,
    duration_ms     BIGINT GENERATED ALWAYS AS
        (EXTRACT(EPOCH FROM (completed_at - started_at)) * 1000)::BIGINT STORED
);

CREATE INDEX idx_bulk_user         ON sys_bulk_operation_logs (user_id, started_at);
CREATE INDEX idx_bulk_type         ON sys_bulk_operation_logs (operation_type, started_at);

-- ================================================================
-- TRIGGER FUNCTION: fn_capture_change()
-- Generic AFTER trigger — fires on INSERT / UPDATE / DELETE
-- on every tracked table.
-- ================================================================
CREATE OR REPLACE FUNCTION fn_capture_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id       BIGINT;
    v_company_id    BIGINT;
    v_client_ip     INET;
    v_session_id    VARCHAR(100);
    v_app_context   VARCHAR(100);
    v_old_data      JSONB;
    v_new_data      JSONB;
    v_changed_fields TEXT[];
    v_change_id     BIGINT;
    v_row_id        BIGINT;
    v_row_uuid      UUID;
    v_key           TEXT;
    v_old_val       TEXT;
    v_new_val       TEXT;
    -- fields excluded from field-level diff (noise, not meaningful)
    v_excluded_fields TEXT[] := ARRAY[
        'updated_at', 'updated_by', 'created_at', 'created_by'
    ];
BEGIN
    -- ── Read session context set by the application ──────────────
    BEGIN
        v_user_id    := current_setting('app.current_user_id',    TRUE)::BIGINT;
    EXCEPTION WHEN OTHERS THEN v_user_id    := NULL; END;

    BEGIN
        v_company_id := current_setting('app.current_company_id', TRUE)::BIGINT;
    EXCEPTION WHEN OTHERS THEN v_company_id := NULL; END;

    BEGIN
        v_client_ip  := current_setting('app.client_ip',          TRUE)::INET;
    EXCEPTION WHEN OTHERS THEN v_client_ip  := NULL; END;

    BEGIN
        v_session_id := current_setting('app.session_id',         TRUE);
    EXCEPTION WHEN OTHERS THEN v_session_id := NULL; END;

    BEGIN
        v_app_context := current_setting('app.context',           TRUE);
    EXCEPTION WHEN OTHERS THEN v_app_context := NULL; END;

    -- ── Build old / new JSONB snapshots ──────────────────────────
    IF TG_OP = 'INSERT' THEN
        v_old_data := NULL;
        v_new_data := to_jsonb(NEW);
    ELSIF TG_OP = 'UPDATE' THEN
        v_old_data := to_jsonb(OLD);
        v_new_data := to_jsonb(NEW);
    ELSE  -- DELETE
        v_old_data := to_jsonb(OLD);
        v_new_data := NULL;
    END IF;

    -- ── Resolve the row PK ───────────────────────────────────────
    IF TG_OP = 'DELETE' THEN
        v_row_id := (v_old_data->>'id')::BIGINT;
    ELSE
        v_row_id := (v_new_data->>'id')::BIGINT;
    END IF;

    -- UUID (optional — only if table has a uuid column)
    BEGIN
        IF TG_OP = 'DELETE' THEN
            v_row_uuid := (v_old_data->>'uuid')::UUID;
        ELSE
            v_row_uuid := (v_new_data->>'uuid')::UUID;
        END IF;
    EXCEPTION WHEN OTHERS THEN v_row_uuid := NULL; END;

    -- ── Build changed_fields array for UPDATE ────────────────────
    IF TG_OP = 'UPDATE' THEN
        SELECT ARRAY_AGG(k)
          INTO v_changed_fields
          FROM jsonb_object_keys(v_new_data) AS k
         WHERE (v_old_data->>k) IS DISTINCT FROM (v_new_data->>k)
           AND k != ALL(v_excluded_fields);
    END IF;

    -- ── Skip UPDATE if nothing meaningful changed ─────────────────
    IF TG_OP = 'UPDATE' AND (v_changed_fields IS NULL OR CARDINALITY(v_changed_fields) = 0) THEN
        RETURN NEW;
    END IF;

    -- ── Write to sys_change_log ───────────────────────────────────
    INSERT INTO sys_change_log (
        table_name, operation, row_id, row_uuid,
        old_data, new_data, changed_fields,
        user_id, company_id, client_ip, session_id, app_context
    ) VALUES (
        TG_TABLE_NAME, TG_OP, v_row_id, v_row_uuid,
        v_old_data, v_new_data, v_changed_fields,
        v_user_id, v_company_id, v_client_ip, v_session_id, v_app_context
    )
    RETURNING id INTO v_change_id;

    -- ── Write field-level diff rows for UPDATE ───────────────────
    IF TG_OP = 'UPDATE' AND v_changed_fields IS NOT NULL THEN
        FOREACH v_key IN ARRAY v_changed_fields
        LOOP
            v_old_val := v_old_data->>v_key;
            v_new_val := v_new_data->>v_key;

            INSERT INTO sys_field_changes (
                change_log_id, table_name, row_id,
                field_name, old_value, new_value,
                user_id
            ) VALUES (
                v_change_id, TG_TABLE_NAME, v_row_id,
                v_key, v_old_val, v_new_val,
                v_user_id
            );
        END LOOP;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

-- ================================================================
-- HELPER: fn_install_change_trigger(table_name)
-- Installs the trigger on a given table (idempotent).
-- ================================================================
CREATE OR REPLACE FUNCTION fn_install_change_trigger(p_table TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE format(
        'DROP TRIGGER IF EXISTS trg_capture_change ON %I;
         CREATE TRIGGER trg_capture_change
         AFTER INSERT OR UPDATE OR DELETE ON %I
         FOR EACH ROW EXECUTE FUNCTION fn_capture_change();',
        p_table, p_table
    );
END;
$$;

-- ================================================================
-- INSTALL TRIGGERS on all tracked tables
-- ================================================================

-- Core / org
SELECT fn_install_change_trigger('companies');
SELECT fn_install_change_trigger('business_units');
SELECT fn_install_change_trigger('departments');
SELECT fn_install_change_trigger('job_grades');
SELECT fn_install_change_trigger('positions');
SELECT fn_install_change_trigger('employment_types');
SELECT fn_install_change_trigger('users');
SELECT fn_install_change_trigger('roles');

-- Employee master
SELECT fn_install_change_trigger('employees');
SELECT fn_install_change_trigger('emp_addresses');
SELECT fn_install_change_trigger('emp_emergency_contacts');
SELECT fn_install_change_trigger('emp_government_ids');
SELECT fn_install_change_trigger('emp_bank_accounts');
SELECT fn_install_change_trigger('emp_dependents');
SELECT fn_install_change_trigger('emp_education');
SELECT fn_install_change_trigger('emp_work_history');
SELECT fn_install_change_trigger('emp_status_history');

-- Attendance
SELECT fn_install_change_trigger('att_shifts');
SELECT fn_install_change_trigger('att_shift_assignments');
SELECT fn_install_change_trigger('att_holidays');
SELECT fn_install_change_trigger('att_daily');
SELECT fn_install_change_trigger('att_overtime_requests');

-- Leave
SELECT fn_install_change_trigger('lv_types');
SELECT fn_install_change_trigger('lv_policies');
SELECT fn_install_change_trigger('lv_balances');
SELECT fn_install_change_trigger('lv_requests');
SELECT fn_install_change_trigger('lv_approvals');

-- Payroll
SELECT fn_install_change_trigger('pay_periods');
SELECT fn_install_change_trigger('pay_runs');
SELECT fn_install_change_trigger('pay_employee_payroll');
SELECT fn_install_change_trigger('pay_employee_allowances');
SELECT fn_install_change_trigger('pay_employee_loans');
SELECT fn_install_change_trigger('pay_13th_month');

-- Performance
SELECT fn_install_change_trigger('perf_cycles');
SELECT fn_install_change_trigger('perf_employee_kpis');
SELECT fn_install_change_trigger('perf_reviews');
SELECT fn_install_change_trigger('perf_review_ratings');

-- Documents
SELECT fn_install_change_trigger('doc_employee_files');

-- Recruitment
SELECT fn_install_change_trigger('rec_job_postings');
SELECT fn_install_change_trigger('rec_applicants');

-- Training
SELECT fn_install_change_trigger('trn_programs');
SELECT fn_install_change_trigger('trn_sessions');
SELECT fn_install_change_trigger('trn_enrollments');

-- ================================================================
-- TRIGGER: auto-populate sys_status_transitions
-- Fires whenever a status column changes on key tables.
-- ================================================================
CREATE OR REPLACE FUNCTION fn_capture_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER AS $$
DECLARE
    v_user_id   BIGINT;
    v_module    VARCHAR(50);
    v_prev_ts   TIMESTAMPTZ;
    v_duration_ms BIGINT;
BEGIN
    BEGIN
        v_user_id := current_setting('app.current_user_id', TRUE)::BIGINT;
    EXCEPTION WHEN OTHERS THEN v_user_id := NULL; END;

    -- Determine module from table name
    v_module := CASE TG_TABLE_NAME
        WHEN 'employees'           THEN 'EMPLOYEE'
        WHEN 'lv_requests'         THEN 'LEAVE_REQUEST'
        WHEN 'pay_runs'            THEN 'PAYROLL_RUN'
        WHEN 'perf_reviews'        THEN 'PERFORMANCE_REVIEW'
        WHEN 'rec_applicants'      THEN 'RECRUITMENT'
        WHEN 'trn_enrollments'     THEN 'TRAINING'
        WHEN 'att_overtime_requests' THEN 'OVERTIME'
        ELSE TG_TABLE_NAME
    END;

    -- Calculate time since last transition for cycle-time analytics
    SELECT created_at INTO v_prev_ts
      FROM sys_status_transitions
     WHERE module    = v_module
       AND entity_id = OLD.id
     ORDER BY created_at DESC
     LIMIT 1;

    IF v_prev_ts IS NOT NULL THEN
        v_duration_ms := EXTRACT(EPOCH FROM (NOW() - v_prev_ts)) * 1000;
    END IF;

    INSERT INTO sys_status_transitions (
        module, entity_type, entity_id,
        from_status, to_status,
        transitioned_by, duration_from_prev_ms
    ) VALUES (
        v_module, TG_TABLE_NAME, NEW.id,
        OLD.status, NEW.status,
        v_user_id, v_duration_ms
    );

    RETURN NEW;
END;
$$;

-- Install status-transition triggers
CREATE TRIGGER trg_status_transition
AFTER UPDATE OF status ON employees
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION fn_capture_status_change();

CREATE TRIGGER trg_status_transition
AFTER UPDATE OF status ON lv_requests
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION fn_capture_status_change();

CREATE TRIGGER trg_status_transition
AFTER UPDATE OF status ON pay_runs
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION fn_capture_status_change();

CREATE TRIGGER trg_status_transition
AFTER UPDATE OF status ON perf_reviews
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION fn_capture_status_change();

CREATE TRIGGER trg_status_transition
AFTER UPDATE OF status ON rec_applicants
FOR EACH ROW WHEN (OLD.stage IS DISTINCT FROM NEW.stage)
EXECUTE FUNCTION fn_capture_status_change();

CREATE TRIGGER trg_status_transition
AFTER UPDATE OF status ON att_overtime_requests
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION fn_capture_status_change();

-- ================================================================
-- ANALYTICS VIEWS
-- ================================================================

-- ── Recent activity feed (last 500 changes, any table) ──────────
CREATE VIEW v_recent_changes AS
SELECT
    cl.id,
    cl.table_name,
    cl.operation,
    cl.row_id,
    cl.changed_fields,
    cl.user_id,
    u.display_name      AS changed_by_name,
    u.username          AS changed_by_username,
    cl.app_context,
    cl.created_at
FROM sys_change_log cl
LEFT JOIN users u ON cl.user_id = u.id
ORDER BY cl.created_at DESC
LIMIT 500;

-- ── Employee 360 change history ──────────────────────────────────
CREATE VIEW v_employee_change_history AS
SELECT
    cl.id,
    cl.table_name,
    cl.operation,
    cl.row_id,
    cl.changed_fields,
    cl.old_data,
    cl.new_data,
    cl.user_id,
    u.display_name      AS changed_by_name,
    cl.created_at,
    -- resolve employee context from various tables
    CASE
        WHEN cl.table_name = 'employees'
            THEN (cl.new_data->>'id')::BIGINT
        WHEN cl.new_data ? 'employee_id'
            THEN (cl.new_data->>'employee_id')::BIGINT
        WHEN cl.old_data ? 'employee_id'
            THEN (cl.old_data->>'employee_id')::BIGINT
        ELSE NULL
    END AS employee_id
FROM sys_change_log cl
LEFT JOIN users u ON cl.user_id = u.id;

-- ── Field-level change history for a specific employee ───────────
CREATE VIEW v_field_change_history AS
SELECT
    fc.id,
    fc.table_name,
    fc.row_id,
    fc.field_name,
    fc.old_value,
    fc.new_value,
    fc.user_id,
    u.display_name      AS changed_by_name,
    fc.created_at
FROM sys_field_changes fc
LEFT JOIN users u ON fc.user_id = u.id
ORDER BY fc.created_at DESC;

-- ── Change volume by table per day (heat-map data) ───────────────
CREATE VIEW v_change_volume_daily AS
SELECT
    DATE_TRUNC('day', created_at)   AS day,
    table_name,
    operation,
    COUNT(*)                        AS change_count,
    COUNT(DISTINCT user_id)         AS distinct_users
FROM sys_change_log
GROUP BY DATE_TRUNC('day', created_at), table_name, operation
ORDER BY day DESC, change_count DESC;

-- ── Top changed fields (schema drift / data quality signal) ─────
CREATE VIEW v_top_changed_fields AS
SELECT
    table_name,
    field_name,
    COUNT(*)                        AS change_count,
    COUNT(DISTINCT user_id)         AS distinct_users,
    MAX(created_at)                 AS last_changed_at
FROM sys_field_changes
GROUP BY table_name, field_name
ORDER BY change_count DESC;

-- ── User activity summary ────────────────────────────────────────
CREATE VIEW v_user_activity_summary AS
SELECT
    u.id            AS user_id,
    u.username,
    u.display_name,
    u.role_code,
    COUNT(cl.id)    AS total_changes,
    COUNT(cl.id) FILTER (WHERE cl.operation = 'INSERT') AS inserts,
    COUNT(cl.id) FILTER (WHERE cl.operation = 'UPDATE') AS updates,
    COUNT(cl.id) FILTER (WHERE cl.operation = 'DELETE') AS deletes,
    MAX(cl.created_at)  AS last_activity_at,
    COUNT(ll.id)        AS total_logins,
    MAX(ll.created_at)  AS last_login_at
FROM users u
LEFT JOIN sys_change_log  cl ON u.id = cl.user_id
LEFT JOIN sys_login_logs  ll ON u.id = ll.user_id
    AND ll.event_type = 'LOGIN_SUCCESS'
GROUP BY u.id, u.username, u.display_name, u.role_code;

-- ── Status transition funnel (leave approvals) ───────────────────
CREATE VIEW v_leave_approval_funnel AS
SELECT
    to_status,
    COUNT(*)                                    AS count,
    AVG(duration_from_prev_ms) / 1000 / 60      AS avg_minutes_to_reach,
    MIN(duration_from_prev_ms) / 1000 / 60      AS min_minutes,
    MAX(duration_from_prev_ms) / 1000 / 60      AS max_minutes
FROM sys_status_transitions
WHERE module = 'LEAVE_REQUEST'
GROUP BY to_status
ORDER BY count DESC;

-- ── Employee status transition timeline ─────────────────────────
CREATE VIEW v_employee_status_timeline AS
SELECT
    st.entity_id            AS employee_id,
    e.employee_no,
    e.last_name || ', ' || e.first_name AS full_name,
    st.from_status,
    st.to_status,
    st.transitioned_by,
    u.display_name          AS transitioned_by_name,
    st.duration_from_prev_ms / 1000 / 86400 AS days_in_prev_status,
    st.created_at
FROM sys_status_transitions st
JOIN employees e ON st.entity_id = e.id
LEFT JOIN users u ON st.transitioned_by = u.id
WHERE st.module = 'EMPLOYEE'
ORDER BY st.entity_id, st.created_at;

-- ── Data export audit trail ──────────────────────────────────────
CREATE VIEW v_data_export_audit AS
SELECT
    de.id,
    u.username,
    u.display_name,
    u.role_code,
    de.export_type,
    de.module,
    de.format,
    de.row_count,
    de.filter_params,
    de.client_ip,
    de.created_at
FROM sys_data_exports de
JOIN users u ON de.user_id = u.id
ORDER BY de.created_at DESC;

-- ── Security: failed logins + lockouts ──────────────────────────
CREATE VIEW v_security_events AS
SELECT
    event_type,
    username,
    client_ip,
    failure_reason,
    created_at
FROM sys_login_logs
WHERE event_type IN (
    'LOGIN_FAILED', 'ACCOUNT_LOCKED', 'MFA_FAILED', 'PASSWORD_RESET'
)
ORDER BY created_at DESC;

-- ── Payroll change audit summary ─────────────────────────────────
CREATE VIEW v_payroll_change_audit AS
SELECT
    pa.id,
    pr.id           AS run_id,
    pp.period_code,
    e.employee_no,
    e.last_name || ', ' || e.first_name AS full_name,
    pa.field_name,
    pa.old_value,
    pa.new_value,
    pa.new_value - pa.old_value         AS variance,
    pa.change_reason,
    u.display_name  AS changed_by,
    pa.created_at
FROM sys_payroll_audit pa
JOIN pay_runs    pr ON pa.run_id      = pr.id
JOIN pay_periods pp ON pr.period_id  = pp.id
JOIN employees    e ON pa.employee_id = e.id
LEFT JOIN users   u ON pa.changed_by  = u.id
ORDER BY pa.created_at DESC;

-- ── Bulk operations summary ──────────────────────────────────────
CREATE VIEW v_bulk_operations_summary AS
SELECT
    bl.id,
    u.display_name  AS initiated_by,
    bl.operation_type,
    bl.total_records,
    bl.success_count,
    bl.failure_count,
    bl.skipped_count,
    ROUND(bl.success_count::NUMERIC / NULLIF(bl.total_records,0) * 100, 1) AS success_rate_pct,
    bl.duration_ms,
    bl.started_at,
    bl.completed_at
FROM sys_bulk_operation_logs bl
LEFT JOIN users u ON bl.user_id = u.id
ORDER BY bl.started_at DESC;

-- ================================================================
-- STORED PROCEDURE: purge old change logs (retention policy)
-- Run monthly via pg_cron or a scheduled job.
-- Default retention: 36 months for change logs, 24 for field changes
-- ================================================================
CREATE OR REPLACE PROCEDURE sp_purge_old_logs(
    p_change_log_months INTEGER DEFAULT 36,
    p_field_changes_months INTEGER DEFAULT 24,
    p_login_log_months INTEGER DEFAULT 12
)
LANGUAGE plpgsql AS $$
DECLARE
    v_deleted_cl  INTEGER;
    v_deleted_fc  INTEGER;
    v_deleted_ll  INTEGER;
BEGIN
    -- Purge change log
    DELETE FROM sys_change_log
    WHERE created_at < NOW() - (p_change_log_months || ' months')::INTERVAL;
    GET DIAGNOSTICS v_deleted_cl = ROW_COUNT;

    -- Purge field changes
    DELETE FROM sys_field_changes
    WHERE created_at < NOW() - (p_field_changes_months || ' months')::INTERVAL;
    GET DIAGNOSTICS v_deleted_fc = ROW_COUNT;

    -- Purge login logs
    DELETE FROM sys_login_logs
    WHERE created_at < NOW() - (p_login_log_months || ' months')::INTERVAL;
    GET DIAGNOSTICS v_deleted_ll = ROW_COUNT;

    RAISE NOTICE 'Purge complete — change_log: %, field_changes: %, login_logs: %',
        v_deleted_cl, v_deleted_fc, v_deleted_ll;
END;
$$;

-- ================================================================
-- APP INTEGRATION HELPER
-- Call this once per request in the application's DB middleware:
--
--   def set_audit_context(conn, user_id, company_id, ip, session_id, context=''):
--       with conn.cursor() as cur:
--           cur.execute("""
--               SET LOCAL app.current_user_id    = %s;
--               SET LOCAL app.current_company_id = %s;
--               SET LOCAL app.client_ip          = %s;
--               SET LOCAL app.session_id         = %s;
--               SET LOCAL app.context            = %s;
--           """, (user_id, company_id, ip, session_id, context))
--
-- All changes made within that transaction will be attributed
-- to the given user automatically by the triggers.
-- ================================================================
