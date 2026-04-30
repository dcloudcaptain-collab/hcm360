-- ================================================================
-- HCM360 HRIS — 04: AUDIT LOGS SCHEMA
-- Schema    : audit_logs
-- Contains  : change log (partitioned), field changes, login logs,
--             data exports, status transitions, payroll audit,
--             bulk operations, and trigger function
-- ================================================================

SET search_path TO audit_logs, core, public;

-- ── Change Log (partitioned by month) ────────────────────────────

CREATE TABLE audit_logs.sys_change_log (
    id              BIGSERIAL        NOT NULL,
    schema_name     VARCHAR(63)      NOT NULL DEFAULT 'core',
    table_name      VARCHAR(100)     NOT NULL,
    operation       VARCHAR(10)      NOT NULL,
    row_id          BIGINT,
    row_uuid        UUID,
    old_data        JSONB,
    new_data        JSONB,
    changed_fields  TEXT[],
    user_id         BIGINT,
    company_id      BIGINT,
    client_ip       INET,
    session_id      VARCHAR(100),
    app_context     VARCHAR(100),
    created_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE audit_logs.sys_change_log_2025 PARTITION OF audit_logs.sys_change_log
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE audit_logs.sys_change_log_2026 PARTITION OF audit_logs.sys_change_log
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE audit_logs.sys_change_log_2027 PARTITION OF audit_logs.sys_change_log
    FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
CREATE TABLE audit_logs.sys_change_log_2028 PARTITION OF audit_logs.sys_change_log
    FOR VALUES FROM ('2028-01-01') TO ('2029-01-01');

CREATE INDEX idx_chg_table_rowid ON audit_logs.sys_change_log(table_name, row_id, created_at);
CREATE INDEX idx_chg_user        ON audit_logs.sys_change_log(user_id, created_at);
CREATE INDEX idx_chg_company     ON audit_logs.sys_change_log(company_id, created_at);
CREATE INDEX idx_chg_operation   ON audit_logs.sys_change_log(operation, table_name, created_at);

-- ── Field Changes (partitioned) ───────────────────────────────────

CREATE TABLE audit_logs.sys_field_changes (
    id              BIGSERIAL        NOT NULL,
    change_log_id   BIGINT           NOT NULL,
    table_name      VARCHAR(100)     NOT NULL,
    row_id          BIGINT,
    field_name      VARCHAR(100)     NOT NULL,
    old_value       TEXT,
    new_value       TEXT,
    data_type       VARCHAR(50),
    user_id         BIGINT,
    created_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE audit_logs.sys_field_changes_2025 PARTITION OF audit_logs.sys_field_changes
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE audit_logs.sys_field_changes_2026 PARTITION OF audit_logs.sys_field_changes
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE audit_logs.sys_field_changes_2027 PARTITION OF audit_logs.sys_field_changes
    FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
CREATE TABLE audit_logs.sys_field_changes_2028 PARTITION OF audit_logs.sys_field_changes
    FOR VALUES FROM ('2028-01-01') TO ('2029-01-01');

CREATE INDEX idx_fchg_table_field ON audit_logs.sys_field_changes(table_name, field_name, created_at);
CREATE INDEX idx_fchg_row         ON audit_logs.sys_field_changes(table_name, row_id, created_at);
CREATE INDEX idx_fchg_user        ON audit_logs.sys_field_changes(user_id, created_at);

-- ── Login Logs ────────────────────────────────────────────────────

CREATE TABLE audit_logs.sys_login_logs (
    id              BIGSERIAL        PRIMARY KEY,
    user_id         BIGINT,
    username        VARCHAR(100),
    company_id      BIGINT,
    event_type      VARCHAR(30)      NOT NULL,
    client_ip       INET,
    user_agent      TEXT,
    session_id      VARCHAR(100),
    sso_provider    VARCHAR(50),
    failure_reason  VARCHAR(200),
    created_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_login_user  ON audit_logs.sys_login_logs(user_id, created_at);
CREATE INDEX idx_login_event ON audit_logs.sys_login_logs(event_type, created_at);
CREATE INDEX idx_login_ip    ON audit_logs.sys_login_logs(client_ip, created_at);

-- ── Data Exports ──────────────────────────────────────────────────

CREATE TABLE audit_logs.sys_data_exports (
    id              BIGSERIAL        PRIMARY KEY,
    user_id         BIGINT,
    company_id      BIGINT,
    export_type     VARCHAR(50)      NOT NULL,
    module          VARCHAR(50)      NOT NULL,
    format          VARCHAR(20)      NOT NULL DEFAULT 'CSV',
    filter_params   JSONB            NOT NULL DEFAULT '{}',
    row_count       INTEGER,
    file_path       TEXT,
    client_ip       INET,
    created_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_export_user ON audit_logs.sys_data_exports(user_id, created_at);
CREATE INDEX idx_export_type ON audit_logs.sys_data_exports(export_type, created_at);

-- ── Status Transitions ────────────────────────────────────────────

CREATE TABLE audit_logs.sys_status_transitions (
    id                    BIGSERIAL        PRIMARY KEY,
    module                VARCHAR(50)      NOT NULL,
    entity_type           VARCHAR(100)     NOT NULL,
    entity_id             BIGINT           NOT NULL,
    from_status           VARCHAR(50),
    to_status             VARCHAR(50)      NOT NULL,
    transitioned_by       BIGINT,
    reason                TEXT,
    duration_from_prev_ms BIGINT,
    metadata              JSONB            NOT NULL DEFAULT '{}',
    created_at            TIMESTAMPTZ      NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_st_module_entity ON audit_logs.sys_status_transitions(module, entity_type, entity_id);
CREATE INDEX idx_st_created       ON audit_logs.sys_status_transitions(created_at);
CREATE INDEX idx_st_to_status     ON audit_logs.sys_status_transitions(module, to_status, created_at);

-- ── Payroll Audit ─────────────────────────────────────────────────

CREATE TABLE audit_logs.sys_payroll_audit (
    id              BIGSERIAL        PRIMARY KEY,
    run_id          BIGINT,
    employee_id     BIGINT,
    field_name      VARCHAR(100)     NOT NULL,
    old_value       NUMERIC(14,2),
    new_value       NUMERIC(14,2),
    change_reason   TEXT,
    changed_by      BIGINT,
    created_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_pay_audit_run ON audit_logs.sys_payroll_audit(run_id);
CREATE INDEX idx_pay_audit_emp ON audit_logs.sys_payroll_audit(employee_id, created_at);

-- ── Bulk Operations ───────────────────────────────────────────────

CREATE TABLE audit_logs.sys_bulk_operation_logs (
    id              BIGSERIAL        PRIMARY KEY,
    user_id         BIGINT,
    company_id      BIGINT,
    operation_type  VARCHAR(100)     NOT NULL,
    total_records   INTEGER          NOT NULL DEFAULT 0,
    success_count   INTEGER          NOT NULL DEFAULT 0,
    failure_count   INTEGER          NOT NULL DEFAULT 0,
    skipped_count   INTEGER          NOT NULL DEFAULT 0,
    error_log       JSONB            NOT NULL DEFAULT '[]',
    file_source     TEXT,
    started_at      TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    completed_at    TIMESTAMPTZ,
    duration_ms     BIGINT GENERATED ALWAYS AS
        (CAST(EXTRACT(EPOCH FROM (completed_at - started_at)) * 1000 AS BIGINT)) STORED
);

-- ── Trigger Function: fn_capture_change() ────────────────────────
-- Generic AFTER trigger — fires on INSERT / UPDATE / DELETE
-- Reads session vars set by Python: app.current_user_id, etc.

CREATE OR REPLACE FUNCTION audit_logs.fn_capture_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = audit_logs, core, public
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
    v_excluded_fields TEXT[] := ARRAY['updated_at','updated_by','created_at','created_by'];
BEGIN
    BEGIN v_user_id    := current_setting('app.current_user_id',    TRUE)::BIGINT; EXCEPTION WHEN OTHERS THEN v_user_id    := NULL; END;
    BEGIN v_company_id := current_setting('app.current_company_id', TRUE)::BIGINT; EXCEPTION WHEN OTHERS THEN v_company_id := NULL; END;
    BEGIN v_client_ip  := current_setting('app.client_ip',          TRUE)::INET;   EXCEPTION WHEN OTHERS THEN v_client_ip  := NULL; END;
    BEGIN v_session_id := current_setting('app.session_id',         TRUE);          EXCEPTION WHEN OTHERS THEN v_session_id := NULL; END;
    BEGIN v_app_context:= current_setting('app.context',            TRUE);          EXCEPTION WHEN OTHERS THEN v_app_context:= NULL; END;

    IF TG_OP = 'INSERT' THEN
        v_old_data := NULL; v_new_data := to_jsonb(NEW);
    ELSIF TG_OP = 'UPDATE' THEN
        v_old_data := to_jsonb(OLD); v_new_data := to_jsonb(NEW);
    ELSE
        v_old_data := to_jsonb(OLD); v_new_data := NULL;
    END IF;

    IF TG_OP = 'DELETE' THEN
        v_row_id := (v_old_data->>'id')::BIGINT;
    ELSE
        v_row_id := (v_new_data->>'id')::BIGINT;
    END IF;

    BEGIN
        IF TG_OP = 'DELETE' THEN v_row_uuid := (v_old_data->>'uuid')::UUID;
        ELSE v_row_uuid := (v_new_data->>'uuid')::UUID; END IF;
    EXCEPTION WHEN OTHERS THEN v_row_uuid := NULL; END;

    IF TG_OP = 'UPDATE' THEN
        SELECT ARRAY_AGG(k) INTO v_changed_fields
          FROM jsonb_object_keys(v_new_data) AS k
         WHERE (v_old_data->>k) IS DISTINCT FROM (v_new_data->>k)
           AND k != ALL(v_excluded_fields);
    END IF;

    IF TG_OP = 'UPDATE' AND (v_changed_fields IS NULL OR CARDINALITY(v_changed_fields) = 0) THEN
        RETURN NEW;
    END IF;

    INSERT INTO audit_logs.sys_change_log (
        schema_name, table_name, operation, row_id, row_uuid,
        old_data, new_data, changed_fields,
        user_id, company_id, client_ip, session_id, app_context
    ) VALUES (
        TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP, v_row_id, v_row_uuid,
        v_old_data, v_new_data, v_changed_fields,
        v_user_id, v_company_id, v_client_ip, v_session_id, v_app_context
    )
    RETURNING id INTO v_change_id;

    IF TG_OP = 'UPDATE' AND v_changed_fields IS NOT NULL THEN
        FOREACH v_key IN ARRAY v_changed_fields
        LOOP
            INSERT INTO audit_logs.sys_field_changes (
                change_log_id, table_name, row_id,
                field_name, old_value, new_value, user_id
            ) VALUES (
                v_change_id, TG_TABLE_NAME, v_row_id,
                v_key, v_old_data->>v_key, v_new_data->>v_key, v_user_id
            );
        END LOOP;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

-- ── Helper: install trigger on any schema-qualified table ─────────

CREATE OR REPLACE FUNCTION audit_logs.fn_install_change_trigger(p_schema TEXT, p_table TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE format(
        'DROP TRIGGER IF EXISTS trg_capture_change ON %I.%I;
         CREATE TRIGGER trg_capture_change
         AFTER INSERT OR UPDATE OR DELETE ON %I.%I
         FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();',
        p_schema, p_table, p_schema, p_table
    );
END;
$$;

-- ── Status Transition Capture ─────────────────────────────────────

CREATE OR REPLACE FUNCTION audit_logs.fn_capture_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER AS $$
DECLARE
    v_user_id     BIGINT;
    v_module      VARCHAR(50);
    v_prev_ts     TIMESTAMPTZ;
    v_duration_ms BIGINT;
BEGIN
    BEGIN v_user_id := current_setting('app.current_user_id', TRUE)::BIGINT;
    EXCEPTION WHEN OTHERS THEN v_user_id := NULL; END;

    v_module := CASE TG_TABLE_NAME
        WHEN 'employees'              THEN 'EMPLOYEE'
        WHEN 'lv_requests'            THEN 'LEAVE_REQUEST'
        WHEN 'pay_runs'               THEN 'PAYROLL_RUN'
        WHEN 'perf_reviews'           THEN 'PERFORMANCE_REVIEW'
        WHEN 'rec_applicants'         THEN 'RECRUITMENT'
        WHEN 'lrn_enrollments'        THEN 'TRAINING'
        WHEN 'att_overtime_requests'  THEN 'OVERTIME'
        WHEN 'workflow_instances'     THEN 'WORKFLOW'
        ELSE upper(TG_TABLE_NAME)
    END;

    SELECT created_at INTO v_prev_ts
      FROM audit_logs.sys_status_transitions
     WHERE module = v_module AND entity_id = OLD.id
     ORDER BY created_at DESC LIMIT 1;

    IF v_prev_ts IS NOT NULL THEN
        v_duration_ms := EXTRACT(EPOCH FROM (NOW() - v_prev_ts)) * 1000;
    END IF;

    INSERT INTO audit_logs.sys_status_transitions (
        module, entity_type, entity_id,
        from_status, to_status, transitioned_by, duration_from_prev_ms
    ) VALUES (
        v_module, TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME, NEW.id,
        OLD.status, NEW.status, v_user_id, v_duration_ms
    );

    RETURN NEW;
END;
$$;

-- ── Purge procedure (retention policy) ───────────────────────────

CREATE OR REPLACE PROCEDURE audit_logs.sp_purge_old_logs(
    p_change_log_months INTEGER DEFAULT 36,
    p_field_changes_months INTEGER DEFAULT 24,
    p_login_log_months INTEGER DEFAULT 12
)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM audit_logs.sys_change_log
     WHERE created_at < NOW() - (p_change_log_months || ' months')::INTERVAL;
    DELETE FROM audit_logs.sys_field_changes
     WHERE created_at < NOW() - (p_field_changes_months || ' months')::INTERVAL;
    DELETE FROM audit_logs.sys_login_logs
     WHERE created_at < NOW() - (p_login_log_months || ' months')::INTERVAL;
    RAISE NOTICE 'Purge complete';
END;
$$;
