--
-- PostgreSQL database dump
--

\restrict ogVg8xMH7NleGJJVgXHKxYFR8Xc3e4h8ah4IsCd8z8ixZaGc4noUV7RvKLBaeqe

-- Dumped from database version 15.17 (Debian 15.17-1.pgdg13+1)
-- Dumped by pg_dump version 15.17 (Debian 15.17-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: ai; Type: SCHEMA; Schema: -; Owner: hris_admin
--

CREATE SCHEMA ai;


ALTER SCHEMA ai OWNER TO hris_admin;

--
-- Name: analytics; Type: SCHEMA; Schema: -; Owner: hris_admin
--

CREATE SCHEMA analytics;


ALTER SCHEMA analytics OWNER TO hris_admin;

--
-- Name: attendance; Type: SCHEMA; Schema: -; Owner: hris_admin
--

CREATE SCHEMA attendance;


ALTER SCHEMA attendance OWNER TO hris_admin;

--
-- Name: audit_logs; Type: SCHEMA; Schema: -; Owner: hris_admin
--

CREATE SCHEMA audit_logs;


ALTER SCHEMA audit_logs OWNER TO hris_admin;

--
-- Name: core; Type: SCHEMA; Schema: -; Owner: hris_admin
--

CREATE SCHEMA core;


ALTER SCHEMA core OWNER TO hris_admin;

--
-- Name: discipline; Type: SCHEMA; Schema: -; Owner: hris_admin
--

CREATE SCHEMA discipline;


ALTER SCHEMA discipline OWNER TO hris_admin;

--
-- Name: dms; Type: SCHEMA; Schema: -; Owner: hris_admin
--

CREATE SCHEMA dms;


ALTER SCHEMA dms OWNER TO hris_admin;

--
-- Name: health; Type: SCHEMA; Schema: -; Owner: hris_admin
--

CREATE SCHEMA health;


ALTER SCHEMA health OWNER TO hris_admin;

--
-- Name: learning; Type: SCHEMA; Schema: -; Owner: hris_admin
--

CREATE SCHEMA learning;


ALTER SCHEMA learning OWNER TO hris_admin;

--
-- Name: leave_mgmt; Type: SCHEMA; Schema: -; Owner: hris_admin
--

CREATE SCHEMA leave_mgmt;


ALTER SCHEMA leave_mgmt OWNER TO hris_admin;

--
-- Name: notifications; Type: SCHEMA; Schema: -; Owner: hris_admin
--

CREATE SCHEMA notifications;


ALTER SCHEMA notifications OWNER TO hris_admin;

--
-- Name: onboarding; Type: SCHEMA; Schema: -; Owner: hris_admin
--

CREATE SCHEMA onboarding;


ALTER SCHEMA onboarding OWNER TO hris_admin;

--
-- Name: payroll; Type: SCHEMA; Schema: -; Owner: hris_admin
--

CREATE SCHEMA payroll;


ALTER SCHEMA payroll OWNER TO hris_admin;

--
-- Name: performance; Type: SCHEMA; Schema: -; Owner: hris_admin
--

CREATE SCHEMA performance;


ALTER SCHEMA performance OWNER TO hris_admin;

--
-- Name: recruitment; Type: SCHEMA; Schema: -; Owner: hris_admin
--

CREATE SCHEMA recruitment;


ALTER SCHEMA recruitment OWNER TO hris_admin;

--
-- Name: rewards; Type: SCHEMA; Schema: -; Owner: hris_admin
--

CREATE SCHEMA rewards;


ALTER SCHEMA rewards OWNER TO hris_admin;

--
-- Name: workflow; Type: SCHEMA; Schema: -; Owner: hris_admin
--

CREATE SCHEMA workflow;


ALTER SCHEMA workflow OWNER TO hris_admin;

--
-- Name: btree_gin; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gin WITH SCHEMA public;


--
-- Name: EXTENSION btree_gin; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION btree_gin IS 'support for indexing common datatypes in GIN';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: tablefunc; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS tablefunc WITH SCHEMA public;


--
-- Name: EXTENSION tablefunc; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION tablefunc IS 'functions that manipulate whole tables, including crosstab';


--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: fn_capture_change(); Type: FUNCTION; Schema: audit_logs; Owner: hris_admin
--

CREATE FUNCTION audit_logs.fn_capture_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'audit_logs', 'core', 'public'
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


ALTER FUNCTION audit_logs.fn_capture_change() OWNER TO hris_admin;

--
-- Name: fn_capture_status_change(); Type: FUNCTION; Schema: audit_logs; Owner: hris_admin
--

CREATE FUNCTION audit_logs.fn_capture_status_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


ALTER FUNCTION audit_logs.fn_capture_status_change() OWNER TO hris_admin;

--
-- Name: fn_install_change_trigger(text, text); Type: FUNCTION; Schema: audit_logs; Owner: hris_admin
--

CREATE FUNCTION audit_logs.fn_install_change_trigger(p_schema text, p_table text) RETURNS void
    LANGUAGE plpgsql
    AS $$
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


ALTER FUNCTION audit_logs.fn_install_change_trigger(p_schema text, p_table text) OWNER TO hris_admin;

--
-- Name: install_trigger(text, text); Type: FUNCTION; Schema: audit_logs; Owner: hris_admin
--

CREATE FUNCTION audit_logs.install_trigger(p_schema text, p_table text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM audit_logs.fn_install_change_trigger(p_schema, p_table);
END;
$$;


ALTER FUNCTION audit_logs.install_trigger(p_schema text, p_table text) OWNER TO hris_admin;

--
-- Name: sp_purge_old_logs(integer, integer, integer); Type: PROCEDURE; Schema: audit_logs; Owner: hris_admin
--

CREATE PROCEDURE audit_logs.sp_purge_old_logs(IN p_change_log_months integer DEFAULT 36, IN p_field_changes_months integer DEFAULT 24, IN p_login_log_months integer DEFAULT 12)
    LANGUAGE plpgsql
    AS $$
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


ALTER PROCEDURE audit_logs.sp_purge_old_logs(IN p_change_log_months integer, IN p_field_changes_months integer, IN p_login_log_months integer) OWNER TO hris_admin;

--
-- Name: fn_capture_change(); Type: FUNCTION; Schema: public; Owner: hris_admin
--

CREATE FUNCTION public.fn_capture_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


ALTER FUNCTION public.fn_capture_change() OWNER TO hris_admin;

--
-- Name: fn_capture_status_change(); Type: FUNCTION; Schema: public; Owner: hris_admin
--

CREATE FUNCTION public.fn_capture_status_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


ALTER FUNCTION public.fn_capture_status_change() OWNER TO hris_admin;

--
-- Name: fn_emit_event(character varying, character varying, bigint, jsonb, bigint, bigint, uuid); Type: FUNCTION; Schema: public; Owner: hris_admin
--

CREATE FUNCTION public.fn_emit_event(p_event_type character varying, p_aggregate_type character varying, p_aggregate_id bigint, p_payload jsonb DEFAULT '{}'::jsonb, p_employee_id bigint DEFAULT NULL::bigint, p_company_id bigint DEFAULT NULL::bigint, p_correlation_id uuid DEFAULT NULL::uuid) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_event_id  UUID := uuid_generate_v4();
    v_user_id   BIGINT;
BEGIN
    BEGIN
        v_user_id := current_setting('app.current_user_id', TRUE)::BIGINT;
    EXCEPTION WHEN OTHERS THEN v_user_id := NULL; END;

    INSERT INTO hris_domain_events (
        event_id, event_type, company_id, employee_id, actor_user_id,
        aggregate_type, aggregate_id, payload, correlation_id
    ) VALUES (
        v_event_id, p_event_type, p_company_id, p_employee_id, v_user_id,
        p_aggregate_type, p_aggregate_id, p_payload, p_correlation_id
    );
    RETURN v_event_id;
END;
$$;


ALTER FUNCTION public.fn_emit_event(p_event_type character varying, p_aggregate_type character varying, p_aggregate_id bigint, p_payload jsonb, p_employee_id bigint, p_company_id bigint, p_correlation_id uuid) OWNER TO hris_admin;

--
-- Name: fn_install_change_trigger(text); Type: FUNCTION; Schema: public; Owner: hris_admin
--

CREATE FUNCTION public.fn_install_change_trigger(p_table text) RETURNS void
    LANGUAGE plpgsql
    AS $$
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


ALTER FUNCTION public.fn_install_change_trigger(p_table text) OWNER TO hris_admin;

--
-- Name: sp_load_fact_attendance(integer); Type: PROCEDURE; Schema: public; Owner: hris_admin
--

CREATE PROCEDURE public.sp_load_fact_attendance(IN p_days_back integer DEFAULT 7)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO fact_attendance (
        date_key, employee_surrogate, employee_id, company_id,
        department_id, position_id, shift_id,
        status, work_arrangement, is_holiday, is_restday,
        hours_worked, hours_late, hours_undertime, hours_overtime, hours_night_diff,
        is_present, is_absent, is_late, is_half_day, is_on_leave, is_ob
    )
    SELECT
        TO_CHAR(ad.work_date, 'YYYYMMDD')::INTEGER,
        de.surrogate_key,
        ad.employee_id,
        e.company_id,
        e.department_id,
        e.position_id,
        ad.shift_id,
        ad.status,
        e.work_arrangement,
        ad.is_holiday,
        ad.is_restday,
        ad.hours_worked,
        ad.hours_late,
        ad.hours_undertime,
        ad.hours_overtime,
        ad.hours_night_diff,
        (ad.status = 'PRESENT')::SMALLINT,
        (ad.status = 'ABSENT')::SMALLINT,
        (ad.status = 'LATE')::SMALLINT,
        (ad.status = 'HALF_DAY')::SMALLINT,
        (ad.status = 'ON_LEAVE')::SMALLINT,
        (ad.status = 'OB')::SMALLINT
    FROM att_daily ad
    JOIN employees e  ON ad.employee_id  = e.id
    LEFT JOIN dim_employee de ON de.employee_id = e.id AND de.is_current = TRUE
    WHERE ad.work_date >= CURRENT_DATE - p_days_back
    ON CONFLICT (employee_id, date_key)
    DO UPDATE SET
        hours_worked      = EXCLUDED.hours_worked,
        hours_late        = EXCLUDED.hours_late,
        hours_undertime   = EXCLUDED.hours_undertime,
        hours_overtime    = EXCLUDED.hours_overtime,
        is_present        = EXCLUDED.is_present,
        is_absent         = EXCLUDED.is_absent,
        is_late           = EXCLUDED.is_late,
        is_on_leave       = EXCLUDED.is_on_leave,
        status            = EXCLUDED.status,
        loaded_at         = NOW();

    RAISE NOTICE 'fact_attendance loaded (% days back) at %', p_days_back, NOW();
END;
$$;


ALTER PROCEDURE public.sp_load_fact_attendance(IN p_days_back integer) OWNER TO hris_admin;

--
-- Name: sp_purge_old_logs(integer, integer, integer); Type: PROCEDURE; Schema: public; Owner: hris_admin
--

CREATE PROCEDURE public.sp_purge_old_logs(IN p_change_log_months integer DEFAULT 36, IN p_field_changes_months integer DEFAULT 24, IN p_login_log_months integer DEFAULT 12)
    LANGUAGE plpgsql
    AS $$
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


ALTER PROCEDURE public.sp_purge_old_logs(IN p_change_log_months integer, IN p_field_changes_months integer, IN p_login_log_months integer) OWNER TO hris_admin;

--
-- Name: sp_refresh_analytics(); Type: PROCEDURE; Schema: public; Owner: hris_admin
--

CREATE PROCEDURE public.sp_refresh_analytics()
    LANGUAGE plpgsql
    AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_headcount_monthly;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_payroll_cost_monthly;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_attrition_monthly;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_attendance_heatmap;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_leave_utilization;
    RAISE NOTICE 'Analytics materialized views refreshed at %', NOW();
END;
$$;


ALTER PROCEDURE public.sp_refresh_analytics() OWNER TO hris_admin;

--
-- Name: sp_refresh_dim_employee(); Type: PROCEDURE; Schema: public; Owner: hris_admin
--

CREATE PROCEDURE public.sp_refresh_dim_employee()
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Close current records where key attributes have changed
    UPDATE dim_employee de
    SET
        effective_to = CURRENT_DATE - 1,
        is_current   = FALSE
    FROM employees e
    JOIN departments     d  ON e.department_id     = d.id
    JOIN positions       p  ON e.position_id       = p.id
    LEFT JOIN job_grades jg ON e.job_grade_id      = jg.id
    LEFT JOIN employment_types et ON e.employment_type_id = et.id
    LEFT JOIN employees  s  ON e.immediate_supervisor_id = s.id
    WHERE de.employee_id  = e.id
      AND de.is_current   = TRUE
      AND (
            de.status             IS DISTINCT FROM e.status
         OR de.department_id      IS DISTINCT FROM e.department_id
         OR de.position_id        IS DISTINCT FROM e.position_id
         OR de.basic_salary       IS DISTINCT FROM e.basic_salary
         OR de.job_grade_code     IS DISTINCT FROM jg.code
         OR de.employment_type    IS DISTINCT FROM et.name
         OR de.work_arrangement   IS DISTINCT FROM e.work_arrangement
      );

    -- Insert new current records for changed / new employees
    INSERT INTO dim_employee (
        employee_id, employee_no, uuid, full_name, last_name, first_name,
        gender, civil_status, date_of_birth, nationality,
        department_id, department_name, position_id, position_title,
        job_grade_code, job_grade_name, employment_type, is_managerial,
        supervisor_id, supervisor_name,
        status, date_hired, date_regularized, basic_salary,
        work_arrangement, work_location, cost_center_code,
        effective_from, effective_to, is_current, snapshot_source
    )
    SELECT
        e.id, e.employee_no, e.uuid,
        e.last_name || ', ' || e.first_name, e.last_name, e.first_name,
        e.gender, e.civil_status, e.date_of_birth, e.nationality,
        e.department_id, d.name, e.position_id, p.title,
        jg.code, jg.name, et.name, p.is_managerial,
        e.immediate_supervisor_id,
        COALESCE(s.last_name || ', ' || s.first_name, ''),
        e.status, e.date_hired, e.date_regularized, e.basic_salary,
        e.work_arrangement, e.work_location, e.cost_center_code,
        CURRENT_DATE, NULL, TRUE, 'BATCH'
    FROM employees e
    JOIN departments     d  ON e.department_id     = d.id
    JOIN positions       p  ON e.position_id       = p.id
    LEFT JOIN job_grades jg ON e.job_grade_id      = jg.id
    LEFT JOIN employment_types et ON e.employment_type_id = et.id
    LEFT JOIN employees  s  ON e.immediate_supervisor_id = s.id
    WHERE e.is_active = TRUE
      AND NOT EXISTS (
          SELECT 1 FROM dim_employee de2
          WHERE de2.employee_id = e.id AND de2.is_current = TRUE
      );

    RAISE NOTICE 'dim_employee refreshed at %', NOW();
END;
$$;


ALTER PROCEDURE public.sp_refresh_dim_employee() OWNER TO hris_admin;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ai_feature_store; Type: TABLE; Schema: ai; Owner: hris_admin
--

CREATE TABLE ai.ai_feature_store (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    snapshot_date date NOT NULL,
    avg_hours_worked_30d numeric(5,2) DEFAULT 0 NOT NULL,
    late_count_30d integer DEFAULT 0 NOT NULL,
    absent_count_30d integer DEFAULT 0 NOT NULL,
    ot_hours_30d numeric(5,2) DEFAULT 0 NOT NULL,
    leave_balance_vl numeric(5,2) DEFAULT 0 NOT NULL,
    leave_taken_ytd numeric(5,2) DEFAULT 0 NOT NULL,
    last_review_score numeric(4,2),
    training_hours_ytd numeric(6,2) DEFAULT 0 NOT NULL,
    tenure_months integer DEFAULT 0 NOT NULL,
    salary_grade_level integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE ai.ai_feature_store OWNER TO hris_admin;

--
-- Name: ai_feature_store_id_seq; Type: SEQUENCE; Schema: ai; Owner: hris_admin
--

CREATE SEQUENCE ai.ai_feature_store_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ai.ai_feature_store_id_seq OWNER TO hris_admin;

--
-- Name: ai_feature_store_id_seq; Type: SEQUENCE OWNED BY; Schema: ai; Owner: hris_admin
--

ALTER SEQUENCE ai.ai_feature_store_id_seq OWNED BY ai.ai_feature_store.id;


--
-- Name: ai_insight_results; Type: TABLE; Schema: ai; Owner: hris_admin
--

CREATE TABLE ai.ai_insight_results (
    id bigint NOT NULL,
    insight_type character varying(60) NOT NULL,
    module character varying(50) NOT NULL,
    scope character varying(50) DEFAULT 'COMPANY'::character varying NOT NULL,
    entity_id bigint,
    title character varying(200) NOT NULL,
    summary text NOT NULL,
    data_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    generated_at timestamp with time zone DEFAULT now() NOT NULL,
    valid_until timestamp with time zone
);


ALTER TABLE ai.ai_insight_results OWNER TO hris_admin;

--
-- Name: ai_insight_results_id_seq; Type: SEQUENCE; Schema: ai; Owner: hris_admin
--

CREATE SEQUENCE ai.ai_insight_results_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ai.ai_insight_results_id_seq OWNER TO hris_admin;

--
-- Name: ai_insight_results_id_seq; Type: SEQUENCE OWNED BY; Schema: ai; Owner: hris_admin
--

ALTER SEQUENCE ai.ai_insight_results_id_seq OWNED BY ai.ai_insight_results.id;


--
-- Name: ai_messages; Type: TABLE; Schema: ai; Owner: hris_admin
--

CREATE TABLE ai.ai_messages (
    id bigint NOT NULL,
    session_id bigint NOT NULL,
    role character varying(20) NOT NULL,
    content text NOT NULL,
    tool_calls jsonb,
    tokens_used integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE ai.ai_messages OWNER TO hris_admin;

--
-- Name: ai_messages_id_seq; Type: SEQUENCE; Schema: ai; Owner: hris_admin
--

CREATE SEQUENCE ai.ai_messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ai.ai_messages_id_seq OWNER TO hris_admin;

--
-- Name: ai_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: ai; Owner: hris_admin
--

ALTER SEQUENCE ai.ai_messages_id_seq OWNED BY ai.ai_messages.id;


--
-- Name: ai_persona_configs; Type: TABLE; Schema: ai; Owner: hris_admin
--

CREATE TABLE ai.ai_persona_configs (
    id bigint NOT NULL,
    persona_code character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
    system_prompt text NOT NULL,
    model character varying(60) DEFAULT 'claude-sonnet-4-6'::character varying NOT NULL,
    max_tokens integer DEFAULT 4096 NOT NULL,
    tools_enabled text[] DEFAULT '{}'::text[] NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE ai.ai_persona_configs OWNER TO hris_admin;

--
-- Name: ai_persona_configs_id_seq; Type: SEQUENCE; Schema: ai; Owner: hris_admin
--

CREATE SEQUENCE ai.ai_persona_configs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ai.ai_persona_configs_id_seq OWNER TO hris_admin;

--
-- Name: ai_persona_configs_id_seq; Type: SEQUENCE OWNED BY; Schema: ai; Owner: hris_admin
--

ALTER SEQUENCE ai.ai_persona_configs_id_seq OWNED BY ai.ai_persona_configs.id;


--
-- Name: ai_recommendations; Type: TABLE; Schema: ai; Owner: hris_admin
--

CREATE TABLE ai.ai_recommendations (
    id bigint NOT NULL,
    target_user_id bigint,
    target_employee_id bigint,
    module character varying(50) NOT NULL,
    recommendation_type character varying(60) NOT NULL,
    title character varying(200) NOT NULL,
    body text NOT NULL,
    action_url character varying(500),
    priority integer DEFAULT 5 NOT NULL,
    is_dismissed boolean DEFAULT false NOT NULL,
    expires_at date,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE ai.ai_recommendations OWNER TO hris_admin;

--
-- Name: ai_recommendations_id_seq; Type: SEQUENCE; Schema: ai; Owner: hris_admin
--

CREATE SEQUENCE ai.ai_recommendations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ai.ai_recommendations_id_seq OWNER TO hris_admin;

--
-- Name: ai_recommendations_id_seq; Type: SEQUENCE OWNED BY; Schema: ai; Owner: hris_admin
--

ALTER SEQUENCE ai.ai_recommendations_id_seq OWNED BY ai.ai_recommendations.id;


--
-- Name: ai_risk_scores; Type: TABLE; Schema: ai; Owner: hris_admin
--

CREATE TABLE ai.ai_risk_scores (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    score_date date DEFAULT CURRENT_DATE NOT NULL,
    risk_type character varying(50) NOT NULL,
    risk_score numeric(5,4) DEFAULT 0 NOT NULL,
    risk_level character varying(20) DEFAULT 'LOW'::character varying NOT NULL,
    confidence numeric(5,4) DEFAULT 0 NOT NULL,
    model_version character varying(30) DEFAULT 'v0-placeholder'::character varying NOT NULL,
    factors jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ai_risk_scores_risk_score_check CHECK (((risk_score >= (0)::numeric) AND (risk_score <= (1)::numeric)))
);


ALTER TABLE ai.ai_risk_scores OWNER TO hris_admin;

--
-- Name: ai_risk_scores_id_seq; Type: SEQUENCE; Schema: ai; Owner: hris_admin
--

CREATE SEQUENCE ai.ai_risk_scores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ai.ai_risk_scores_id_seq OWNER TO hris_admin;

--
-- Name: ai_risk_scores_id_seq; Type: SEQUENCE OWNED BY; Schema: ai; Owner: hris_admin
--

ALTER SEQUENCE ai.ai_risk_scores_id_seq OWNED BY ai.ai_risk_scores.id;


--
-- Name: ai_sessions; Type: TABLE; Schema: ai; Owner: hris_admin
--

CREATE TABLE ai.ai_sessions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    session_token character varying(100) NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    ended_at timestamp with time zone,
    message_count integer DEFAULT 0 NOT NULL
);


ALTER TABLE ai.ai_sessions OWNER TO hris_admin;

--
-- Name: ai_sessions_id_seq; Type: SEQUENCE; Schema: ai; Owner: hris_admin
--

CREATE SEQUENCE ai.ai_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ai.ai_sessions_id_seq OWNER TO hris_admin;

--
-- Name: ai_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: ai; Owner: hris_admin
--

ALTER SEQUENCE ai.ai_sessions_id_seq OWNED BY ai.ai_sessions.id;


--
-- Name: ai_tool_call_logs; Type: TABLE; Schema: ai; Owner: hris_admin
--

CREATE TABLE ai.ai_tool_call_logs (
    id bigint NOT NULL,
    message_id bigint,
    tool_name character varying(100) NOT NULL,
    input_params jsonb DEFAULT '{}'::jsonb NOT NULL,
    output_result jsonb DEFAULT '{}'::jsonb NOT NULL,
    execution_ms integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE ai.ai_tool_call_logs OWNER TO hris_admin;

--
-- Name: ai_tool_call_logs_id_seq; Type: SEQUENCE; Schema: ai; Owner: hris_admin
--

CREATE SEQUENCE ai.ai_tool_call_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ai.ai_tool_call_logs_id_seq OWNER TO hris_admin;

--
-- Name: ai_tool_call_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: ai; Owner: hris_admin
--

ALTER SEQUENCE ai.ai_tool_call_logs_id_seq OWNED BY ai.ai_tool_call_logs.id;


--
-- Name: dim_date; Type: TABLE; Schema: analytics; Owner: hris_admin
--

CREATE TABLE analytics.dim_date (
    date_key integer NOT NULL,
    full_date date NOT NULL,
    day_of_week smallint NOT NULL,
    day_name character varying(10) NOT NULL,
    day_of_month smallint NOT NULL,
    day_of_year smallint NOT NULL,
    week_of_year smallint NOT NULL,
    month_number smallint NOT NULL,
    month_name character varying(15) NOT NULL,
    month_short character varying(5) NOT NULL,
    quarter smallint NOT NULL,
    year smallint NOT NULL,
    is_weekend boolean DEFAULT false NOT NULL,
    is_holiday boolean DEFAULT false NOT NULL,
    holiday_name character varying(100),
    fiscal_year smallint,
    fiscal_quarter smallint
);


ALTER TABLE analytics.dim_date OWNER TO hris_admin;

--
-- Name: dim_department; Type: TABLE; Schema: analytics; Owner: hris_admin
--

CREATE TABLE analytics.dim_department (
    surrogate_key bigint NOT NULL,
    department_id bigint NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(200) NOT NULL,
    company_id bigint,
    is_current boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.dim_department OWNER TO hris_admin;

--
-- Name: dim_department_surrogate_key_seq; Type: SEQUENCE; Schema: analytics; Owner: hris_admin
--

CREATE SEQUENCE analytics.dim_department_surrogate_key_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE analytics.dim_department_surrogate_key_seq OWNER TO hris_admin;

--
-- Name: dim_department_surrogate_key_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: hris_admin
--

ALTER SEQUENCE analytics.dim_department_surrogate_key_seq OWNED BY analytics.dim_department.surrogate_key;


--
-- Name: dim_employee; Type: TABLE; Schema: analytics; Owner: hris_admin
--

CREATE TABLE analytics.dim_employee (
    surrogate_key bigint NOT NULL,
    employee_id bigint NOT NULL,
    employee_no character varying(30) NOT NULL,
    full_name character varying(250) NOT NULL,
    gender character varying(20),
    department_id bigint,
    department_name character varying(200),
    position_id bigint,
    position_title character varying(200),
    job_grade character varying(30),
    employment_type character varying(30),
    work_arrangement character varying(30),
    date_hired date,
    status character varying(30),
    tenure_months integer,
    effective_from date NOT NULL,
    effective_to date,
    is_current boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.dim_employee OWNER TO hris_admin;

--
-- Name: dim_employee_surrogate_key_seq; Type: SEQUENCE; Schema: analytics; Owner: hris_admin
--

CREATE SEQUENCE analytics.dim_employee_surrogate_key_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE analytics.dim_employee_surrogate_key_seq OWNER TO hris_admin;

--
-- Name: dim_employee_surrogate_key_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: hris_admin
--

ALTER SEQUENCE analytics.dim_employee_surrogate_key_seq OWNED BY analytics.dim_employee.surrogate_key;


--
-- Name: dim_position; Type: TABLE; Schema: analytics; Owner: hris_admin
--

CREATE TABLE analytics.dim_position (
    surrogate_key bigint NOT NULL,
    position_id bigint NOT NULL,
    code character varying(20) NOT NULL,
    title character varying(200) NOT NULL,
    is_managerial boolean,
    is_current boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.dim_position OWNER TO hris_admin;

--
-- Name: dim_position_surrogate_key_seq; Type: SEQUENCE; Schema: analytics; Owner: hris_admin
--

CREATE SEQUENCE analytics.dim_position_surrogate_key_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE analytics.dim_position_surrogate_key_seq OWNER TO hris_admin;

--
-- Name: dim_position_surrogate_key_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: hris_admin
--

ALTER SEQUENCE analytics.dim_position_surrogate_key_seq OWNED BY analytics.dim_position.surrogate_key;


--
-- Name: fact_attendance; Type: TABLE; Schema: analytics; Owner: hris_admin
--

CREATE TABLE analytics.fact_attendance (
    id bigint NOT NULL,
    date_key integer NOT NULL,
    employee_key bigint NOT NULL,
    department_key bigint,
    hours_worked numeric(5,2) DEFAULT 0 NOT NULL,
    hours_late numeric(5,2) DEFAULT 0 NOT NULL,
    hours_overtime numeric(5,2) DEFAULT 0 NOT NULL,
    hours_night_diff numeric(5,2) DEFAULT 0 NOT NULL,
    is_present boolean DEFAULT false NOT NULL,
    is_absent boolean DEFAULT false NOT NULL,
    is_on_leave boolean DEFAULT false NOT NULL,
    is_holiday boolean DEFAULT false NOT NULL,
    attendance_status character varying(20),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.fact_attendance OWNER TO hris_admin;

--
-- Name: fact_attendance_id_seq; Type: SEQUENCE; Schema: analytics; Owner: hris_admin
--

CREATE SEQUENCE analytics.fact_attendance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE analytics.fact_attendance_id_seq OWNER TO hris_admin;

--
-- Name: fact_attendance_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: hris_admin
--

ALTER SEQUENCE analytics.fact_attendance_id_seq OWNED BY analytics.fact_attendance.id;


--
-- Name: fact_leave; Type: TABLE; Schema: analytics; Owner: hris_admin
--

CREATE TABLE analytics.fact_leave (
    id bigint NOT NULL,
    date_key integer,
    employee_key bigint,
    leave_request_id bigint,
    leave_type_code character varying(30),
    leave_type_name character varying(100),
    days_approved numeric(4,1),
    days_pending numeric(4,1),
    approval_cycle_hours numeric(8,2),
    status character varying(30),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.fact_leave OWNER TO hris_admin;

--
-- Name: fact_leave_id_seq; Type: SEQUENCE; Schema: analytics; Owner: hris_admin
--

CREATE SEQUENCE analytics.fact_leave_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE analytics.fact_leave_id_seq OWNER TO hris_admin;

--
-- Name: fact_leave_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: hris_admin
--

ALTER SEQUENCE analytics.fact_leave_id_seq OWNED BY analytics.fact_leave.id;


--
-- Name: fact_payroll; Type: TABLE; Schema: analytics; Owner: hris_admin
--

CREATE TABLE analytics.fact_payroll (
    id bigint NOT NULL,
    date_key integer,
    employee_key bigint,
    department_key bigint,
    run_id bigint,
    period_code character varying(20),
    gross_pay numeric(14,2) DEFAULT 0 NOT NULL,
    net_pay numeric(14,2) DEFAULT 0 NOT NULL,
    total_deductions numeric(14,2) DEFAULT 0 NOT NULL,
    tax_withheld numeric(12,2) DEFAULT 0 NOT NULL,
    loan_deductions numeric(12,2) DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.fact_payroll OWNER TO hris_admin;

--
-- Name: fact_payroll_id_seq; Type: SEQUENCE; Schema: analytics; Owner: hris_admin
--

CREATE SEQUENCE analytics.fact_payroll_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE analytics.fact_payroll_id_seq OWNER TO hris_admin;

--
-- Name: fact_payroll_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: hris_admin
--

ALTER SEQUENCE analytics.fact_payroll_id_seq OWNED BY analytics.fact_payroll.id;


--
-- Name: fact_training; Type: TABLE; Schema: analytics; Owner: hris_admin
--

CREATE TABLE analytics.fact_training (
    id bigint NOT NULL,
    date_key integer,
    employee_key bigint,
    program_id bigint,
    program_title character varying(200),
    hours_completed numeric(6,2),
    passed boolean,
    score numeric(5,2),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.fact_training OWNER TO hris_admin;

--
-- Name: fact_training_id_seq; Type: SEQUENCE; Schema: analytics; Owner: hris_admin
--

CREATE SEQUENCE analytics.fact_training_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE analytics.fact_training_id_seq OWNER TO hris_admin;

--
-- Name: fact_training_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: hris_admin
--

ALTER SEQUENCE analytics.fact_training_id_seq OWNED BY analytics.fact_training.id;


--
-- Name: kpi_snapshots; Type: TABLE; Schema: analytics; Owner: hris_admin
--

CREATE TABLE analytics.kpi_snapshots (
    id bigint NOT NULL,
    snapshot_date date DEFAULT CURRENT_DATE NOT NULL,
    module character varying(50) NOT NULL,
    kpi_code character varying(60) NOT NULL,
    kpi_value numeric(14,4),
    kpi_label character varying(120),
    dimension_key character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.kpi_snapshots OWNER TO hris_admin;

--
-- Name: kpi_snapshots_id_seq; Type: SEQUENCE; Schema: analytics; Owner: hris_admin
--

CREATE SEQUENCE analytics.kpi_snapshots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE analytics.kpi_snapshots_id_seq OWNER TO hris_admin;

--
-- Name: kpi_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: hris_admin
--

ALTER SEQUENCE analytics.kpi_snapshots_id_seq OWNED BY analytics.kpi_snapshots.id;


--
-- Name: report_data_sources; Type: TABLE; Schema: analytics; Owner: hris_admin
--

CREATE TABLE analytics.report_data_sources (
    id bigint NOT NULL,
    source_code character varying(30) NOT NULL,
    source_label character varying(100) NOT NULL,
    base_sql text NOT NULL,
    module character varying(30) NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL
);


ALTER TABLE analytics.report_data_sources OWNER TO hris_admin;

--
-- Name: report_data_sources_id_seq; Type: SEQUENCE; Schema: analytics; Owner: hris_admin
--

CREATE SEQUENCE analytics.report_data_sources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE analytics.report_data_sources_id_seq OWNER TO hris_admin;

--
-- Name: report_data_sources_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: hris_admin
--

ALTER SEQUENCE analytics.report_data_sources_id_seq OWNED BY analytics.report_data_sources.id;


--
-- Name: report_field_registry; Type: TABLE; Schema: analytics; Owner: hris_admin
--

CREATE TABLE analytics.report_field_registry (
    id bigint NOT NULL,
    source_id bigint NOT NULL,
    field_code character varying(60) NOT NULL,
    field_label character varying(100) NOT NULL,
    field_type character varying(20) DEFAULT 'TEXT'::character varying NOT NULL,
    sql_expression character varying(300) NOT NULL,
    is_groupable boolean DEFAULT true NOT NULL,
    is_filterable boolean DEFAULT true NOT NULL,
    is_sortable boolean DEFAULT true NOT NULL,
    is_aggregatable boolean DEFAULT false NOT NULL,
    default_aggregate character varying(10),
    sort_order integer DEFAULT 0 NOT NULL,
    CONSTRAINT report_field_registry_default_aggregate_check CHECK (((default_aggregate)::text = ANY ((ARRAY['COUNT'::character varying, 'SUM'::character varying, 'AVG'::character varying, 'MIN'::character varying, 'MAX'::character varying])::text[]))),
    CONSTRAINT report_field_registry_field_type_check CHECK (((field_type)::text = ANY ((ARRAY['TEXT'::character varying, 'NUMBER'::character varying, 'DATE'::character varying, 'BOOLEAN'::character varying, 'CURRENCY'::character varying])::text[])))
);


ALTER TABLE analytics.report_field_registry OWNER TO hris_admin;

--
-- Name: report_field_registry_id_seq; Type: SEQUENCE; Schema: analytics; Owner: hris_admin
--

CREATE SEQUENCE analytics.report_field_registry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE analytics.report_field_registry_id_seq OWNER TO hris_admin;

--
-- Name: report_field_registry_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: hris_admin
--

ALTER SEQUENCE analytics.report_field_registry_id_seq OWNED BY analytics.report_field_registry.id;


--
-- Name: report_run_history; Type: TABLE; Schema: analytics; Owner: hris_admin
--

CREATE TABLE analytics.report_run_history (
    id bigint NOT NULL,
    report_id bigint,
    schedule_id bigint,
    triggered_by character varying(20) DEFAULT 'MANUAL'::character varying NOT NULL,
    output_format character varying(10) NOT NULL,
    row_count integer,
    file_path character varying(500),
    file_size_bytes bigint,
    status character varying(20) DEFAULT 'RUNNING'::character varying NOT NULL,
    error_message text,
    run_by bigint,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    distributed_to jsonb DEFAULT '[]'::jsonb,
    CONSTRAINT report_run_history_status_check CHECK (((status)::text = ANY ((ARRAY['RUNNING'::character varying, 'COMPLETED'::character varying, 'FAILED'::character varying])::text[]))),
    CONSTRAINT report_run_history_triggered_by_check CHECK (((triggered_by)::text = ANY ((ARRAY['MANUAL'::character varying, 'SCHEDULED'::character varying, 'API'::character varying])::text[])))
);


ALTER TABLE analytics.report_run_history OWNER TO hris_admin;

--
-- Name: report_run_history_id_seq; Type: SEQUENCE; Schema: analytics; Owner: hris_admin
--

CREATE SEQUENCE analytics.report_run_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE analytics.report_run_history_id_seq OWNER TO hris_admin;

--
-- Name: report_run_history_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: hris_admin
--

ALTER SEQUENCE analytics.report_run_history_id_seq OWNED BY analytics.report_run_history.id;


--
-- Name: report_schedules; Type: TABLE; Schema: analytics; Owner: hris_admin
--

CREATE TABLE analytics.report_schedules (
    id bigint NOT NULL,
    report_id bigint NOT NULL,
    schedule_type character varying(20) DEFAULT 'WEEKLY'::character varying NOT NULL,
    day_of_week integer,
    day_of_month integer,
    run_time time without time zone DEFAULT '07:00:00'::time without time zone NOT NULL,
    output_format character varying(10) DEFAULT 'XLSX'::character varying NOT NULL,
    recipients jsonb DEFAULT '[]'::jsonb NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    last_run_at timestamp with time zone,
    next_run_at timestamp with time zone,
    created_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT report_schedules_output_format_check CHECK (((output_format)::text = ANY ((ARRAY['XLSX'::character varying, 'CSV'::character varying, 'PDF'::character varying])::text[]))),
    CONSTRAINT report_schedules_schedule_type_check CHECK (((schedule_type)::text = ANY ((ARRAY['DAILY'::character varying, 'WEEKLY'::character varying, 'MONTHLY'::character varying, 'QUARTERLY'::character varying, 'YEARLY'::character varying])::text[])))
);


ALTER TABLE analytics.report_schedules OWNER TO hris_admin;

--
-- Name: report_schedules_id_seq; Type: SEQUENCE; Schema: analytics; Owner: hris_admin
--

CREATE SEQUENCE analytics.report_schedules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE analytics.report_schedules_id_seq OWNER TO hris_admin;

--
-- Name: report_schedules_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: hris_admin
--

ALTER SEQUENCE analytics.report_schedules_id_seq OWNED BY analytics.report_schedules.id;


--
-- Name: saved_reports; Type: TABLE; Schema: analytics; Owner: hris_admin
--

CREATE TABLE analytics.saved_reports (
    id bigint NOT NULL,
    name character varying(200) NOT NULL,
    description text,
    source_id bigint NOT NULL,
    config jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_by bigint,
    is_shared boolean DEFAULT false NOT NULL,
    is_system boolean DEFAULT false NOT NULL,
    last_run_at timestamp with time zone,
    run_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.saved_reports OWNER TO hris_admin;

--
-- Name: saved_reports_id_seq; Type: SEQUENCE; Schema: analytics; Owner: hris_admin
--

CREATE SEQUENCE analytics.saved_reports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE analytics.saved_reports_id_seq OWNER TO hris_admin;

--
-- Name: saved_reports_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: hris_admin
--

ALTER SEQUENCE analytics.saved_reports_id_seq OWNED BY analytics.saved_reports.id;


--
-- Name: att_daily; Type: TABLE; Schema: attendance; Owner: hris_admin
--

CREATE TABLE attendance.att_daily (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    work_date date NOT NULL,
    shift_id bigint,
    time_in timestamp with time zone,
    time_out timestamp with time zone,
    hours_worked numeric(5,2) DEFAULT 0 NOT NULL,
    hours_late numeric(5,2) DEFAULT 0 NOT NULL,
    hours_undertime numeric(5,2) DEFAULT 0 NOT NULL,
    hours_overtime numeric(5,2) DEFAULT 0 NOT NULL,
    hours_night_diff numeric(5,2) DEFAULT 0 NOT NULL,
    status character varying(20) DEFAULT 'ABSENT'::character varying NOT NULL,
    is_holiday boolean DEFAULT false NOT NULL,
    holiday_id bigint,
    is_restday boolean DEFAULT false NOT NULL,
    leave_request_id bigint,
    remarks text,
    is_locked boolean DEFAULT false NOT NULL,
    locked_by bigint,
    locked_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE attendance.att_daily OWNER TO hris_admin;

--
-- Name: departments; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.departments (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    business_unit_id bigint,
    code character varying(20) NOT NULL,
    name character varying(200) NOT NULL,
    parent_id bigint,
    head_employee_id bigint,
    cost_center_code character varying(20),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.departments OWNER TO hris_admin;

--
-- Name: employees; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.employees (
    id bigint NOT NULL,
    uuid uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    company_id bigint NOT NULL,
    employee_no character varying(30) NOT NULL,
    last_name character varying(100) NOT NULL,
    first_name character varying(100) NOT NULL,
    middle_name character varying(100),
    suffix character varying(10),
    preferred_name character varying(100),
    gender character varying(20),
    civil_status character varying(20),
    nationality character varying(50) DEFAULT 'Filipino'::character varying NOT NULL,
    religion character varying(50),
    date_of_birth date,
    place_of_birth character varying(200),
    blood_type character varying(5),
    personal_email character varying(200),
    work_email character varying(200),
    mobile_no character varying(20),
    phone_no character varying(20),
    department_id bigint,
    position_id bigint,
    job_grade_id bigint,
    employment_type_id bigint,
    immediate_supervisor_id bigint,
    date_hired date,
    date_regularized date,
    probation_end_date date,
    date_separated date,
    status character varying(30) DEFAULT 'PROBATIONARY'::character varying NOT NULL,
    separation_reason text,
    basic_salary numeric(14,2),
    daily_rate numeric(10,4),
    hourly_rate numeric(10,4),
    cost_center_code character varying(20),
    work_location character varying(200),
    work_arrangement character varying(20) DEFAULT 'ONSITE'::character varying NOT NULL,
    height_cm numeric(5,1),
    weight_kg numeric(5,1),
    profile_photo_path text,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by bigint,
    updated_by bigint
);


ALTER TABLE core.employees OWNER TO hris_admin;

--
-- Name: v_attendance_rate_30d; Type: VIEW; Schema: analytics; Owner: hris_admin
--

CREATE VIEW analytics.v_attendance_rate_30d AS
 SELECT d.name AS department,
    count(*) AS total_employee_days,
    count(*) FILTER (WHERE ((ad.status)::text = 'PRESENT'::text)) AS present_days,
    count(*) FILTER (WHERE ((ad.status)::text = 'ABSENT'::text)) AS absent_days,
    count(*) FILTER (WHERE ((ad.status)::text = 'LATE'::text)) AS late_days,
    round((((count(*) FILTER (WHERE ((ad.status)::text = ANY ((ARRAY['PRESENT'::character varying, 'LATE'::character varying])::text[]))))::numeric / (NULLIF(count(*), 0))::numeric) * (100)::numeric), 1) AS attendance_rate_pct
   FROM ((attendance.att_daily ad
     JOIN core.employees e ON ((e.id = ad.employee_id)))
     LEFT JOIN core.departments d ON ((d.id = e.department_id)))
  WHERE ((ad.work_date >= (CURRENT_DATE - 30)) AND (ad.is_holiday = false) AND (ad.is_restday = false))
  GROUP BY d.name
  ORDER BY (round((((count(*) FILTER (WHERE ((ad.status)::text = ANY ((ARRAY['PRESENT'::character varying, 'LATE'::character varying])::text[]))))::numeric / (NULLIF(count(*), 0))::numeric) * (100)::numeric), 1)) DESC;


ALTER TABLE analytics.v_attendance_rate_30d OWNER TO hris_admin;

--
-- Name: v_headcount_by_dept; Type: VIEW; Schema: analytics; Owner: hris_admin
--

CREATE VIEW analytics.v_headcount_by_dept AS
 SELECT d.name AS department,
    d.code,
    count(*) FILTER (WHERE ((e.status)::text = 'ACTIVE'::text)) AS active,
    count(*) FILTER (WHERE ((e.status)::text = 'PROBATIONARY'::text)) AS probationary,
    count(*) FILTER (WHERE ((e.status)::text = 'ON_LEAVE'::text)) AS on_leave,
    count(*) AS total
   FROM (core.employees e
     LEFT JOIN core.departments d ON ((d.id = e.department_id)))
  WHERE ((e.is_active = true) AND ((e.status)::text <> ALL ((ARRAY['RESIGNED'::character varying, 'TERMINATED'::character varying, 'RETIRED'::character varying, 'DECEASED'::character varying])::text[])))
  GROUP BY d.name, d.code
  ORDER BY (count(*)) DESC;


ALTER TABLE analytics.v_headcount_by_dept OWNER TO hris_admin;

--
-- Name: lv_requests; Type: TABLE; Schema: leave_mgmt; Owner: hris_admin
--

CREATE TABLE leave_mgmt.lv_requests (
    id bigint NOT NULL,
    reference_no character varying(40) NOT NULL,
    employee_id bigint NOT NULL,
    leave_type_id bigint NOT NULL,
    date_from date NOT NULL,
    date_to date NOT NULL,
    days_requested numeric(4,1) NOT NULL,
    reason text,
    status character varying(30) DEFAULT 'PENDING'::character varying NOT NULL,
    is_half_day boolean DEFAULT false NOT NULL,
    half_day_type character varying(5),
    document_path text,
    workflow_instance_id bigint,
    filed_at timestamp with time zone DEFAULT now() NOT NULL,
    return_date date,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE leave_mgmt.lv_requests OWNER TO hris_admin;

--
-- Name: lv_types; Type: TABLE; Schema: leave_mgmt; Owner: hris_admin
--

CREATE TABLE leave_mgmt.lv_types (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    code character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
    category character varying(30) DEFAULT 'COMPANY'::character varying NOT NULL,
    legal_basis character varying(100),
    color character varying(20) DEFAULT '#3b82f6'::character varying NOT NULL,
    icon character varying(20) DEFAULT '📅'::character varying NOT NULL,
    description text,
    is_paid boolean DEFAULT true NOT NULL,
    requires_document boolean DEFAULT false NOT NULL,
    min_days numeric(4,1) DEFAULT 1 NOT NULL,
    max_days_per_filing numeric(4,1),
    notice_days_required integer DEFAULT 0 NOT NULL,
    gender_restriction character varying(10),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE leave_mgmt.lv_types OWNER TO hris_admin;

--
-- Name: v_leave_utilization_ytd; Type: VIEW; Schema: analytics; Owner: hris_admin
--

CREATE VIEW analytics.v_leave_utilization_ytd AS
 SELECT lt.code AS leave_type_code,
    lt.name AS leave_type_name,
    count(lr.id) AS total_requests,
    count(lr.id) FILTER (WHERE ((lr.status)::text = 'APPROVED'::text)) AS approved,
    count(lr.id) FILTER (WHERE ((lr.status)::text = 'PENDING'::text)) AS pending,
    count(lr.id) FILTER (WHERE ((lr.status)::text = 'REJECTED'::text)) AS rejected,
    COALESCE(sum(lr.days_requested) FILTER (WHERE ((lr.status)::text = 'APPROVED'::text)), (0)::numeric) AS total_days_approved
   FROM (leave_mgmt.lv_types lt
     LEFT JOIN leave_mgmt.lv_requests lr ON (((lr.leave_type_id = lt.id) AND (lr.date_from >= date_trunc('year'::text, (CURRENT_DATE)::timestamp with time zone)))))
  GROUP BY lt.code, lt.name
  ORDER BY COALESCE(sum(lr.days_requested) FILTER (WHERE ((lr.status)::text = 'APPROVED'::text)), (0)::numeric) DESC;


ALTER TABLE analytics.v_leave_utilization_ytd OWNER TO hris_admin;

--
-- Name: pay_employee_payroll; Type: TABLE; Schema: payroll; Owner: hris_admin
--

CREATE TABLE payroll.pay_employee_payroll (
    id bigint NOT NULL,
    run_id bigint NOT NULL,
    employee_id bigint NOT NULL,
    scheduled_days numeric(5,2) DEFAULT 0 NOT NULL,
    worked_days numeric(5,2) DEFAULT 0 NOT NULL,
    absent_days numeric(5,2) DEFAULT 0 NOT NULL,
    leave_days numeric(5,2) DEFAULT 0 NOT NULL,
    late_hours numeric(5,2) DEFAULT 0 NOT NULL,
    undertime_hours numeric(5,2) DEFAULT 0 NOT NULL,
    ot_regular_hours numeric(5,2) DEFAULT 0 NOT NULL,
    ot_restday_hours numeric(5,2) DEFAULT 0 NOT NULL,
    ot_holiday_hours numeric(5,2) DEFAULT 0 NOT NULL,
    night_diff_hours numeric(5,2) DEFAULT 0 NOT NULL,
    basic_pay numeric(14,2) DEFAULT 0 NOT NULL,
    ot_pay numeric(14,2) DEFAULT 0 NOT NULL,
    holiday_pay numeric(14,2) DEFAULT 0 NOT NULL,
    night_diff_pay numeric(14,2) DEFAULT 0 NOT NULL,
    allowances_total numeric(14,2) DEFAULT 0 NOT NULL,
    other_earnings numeric(14,2) DEFAULT 0 NOT NULL,
    gross_pay numeric(14,2) DEFAULT 0 NOT NULL,
    sss_ee numeric(10,2) DEFAULT 0 NOT NULL,
    philhealth_ee numeric(10,2) DEFAULT 0 NOT NULL,
    pagibig_ee numeric(10,2) DEFAULT 0 NOT NULL,
    tax_withheld numeric(12,2) DEFAULT 0 NOT NULL,
    loan_deductions numeric(12,2) DEFAULT 0 NOT NULL,
    other_deductions numeric(12,2) DEFAULT 0 NOT NULL,
    total_deductions numeric(14,2) DEFAULT 0 NOT NULL,
    net_pay numeric(14,2) DEFAULT 0 NOT NULL,
    payslip_generated boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    pera numeric(10,2) DEFAULT 0 NOT NULL,
    rata numeric(10,2) DEFAULT 0 NOT NULL,
    aca numeric(10,2) DEFAULT 0 NOT NULL,
    hazard_pay numeric(10,2) DEFAULT 0 NOT NULL,
    gsis_ps numeric(10,2) DEFAULT 0 NOT NULL,
    gsis_gs numeric(10,2) DEFAULT 0 NOT NULL,
    gsis_policy_loan numeric(10,2) DEFAULT 0 NOT NULL,
    pagibig_ps numeric(10,2) DEFAULT 0 NOT NULL,
    pagibig_gs numeric(10,2) DEFAULT 0 NOT NULL,
    coop_deduction numeric(10,2) DEFAULT 0 NOT NULL,
    yeb_amount numeric(12,2) DEFAULT 0 NOT NULL,
    cash_gift numeric(12,2) DEFAULT 0 NOT NULL
);


ALTER TABLE payroll.pay_employee_payroll OWNER TO hris_admin;

--
-- Name: pay_periods; Type: TABLE; Schema: payroll; Owner: hris_admin
--

CREATE TABLE payroll.pay_periods (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    period_code character varying(30) NOT NULL,
    period_type character varying(20) DEFAULT 'SEMI_MONTHLY'::character varying NOT NULL,
    date_from date NOT NULL,
    date_to date NOT NULL,
    payment_date date,
    status character varying(20) DEFAULT 'OPEN'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE payroll.pay_periods OWNER TO hris_admin;

--
-- Name: pay_runs; Type: TABLE; Schema: payroll; Owner: hris_admin
--

CREATE TABLE payroll.pay_runs (
    id bigint NOT NULL,
    period_id bigint NOT NULL,
    run_number integer DEFAULT 1 NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    total_employees integer DEFAULT 0 NOT NULL,
    total_gross numeric(16,2) DEFAULT 0 NOT NULL,
    total_deductions numeric(16,2) DEFAULT 0 NOT NULL,
    total_net numeric(16,2) DEFAULT 0 NOT NULL,
    workflow_instance_id bigint,
    computed_at timestamp with time zone,
    computed_by bigint,
    approved_at timestamp with time zone,
    approved_by bigint,
    posted_at timestamp with time zone,
    posted_by bigint,
    remarks text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE payroll.pay_runs OWNER TO hris_admin;

--
-- Name: v_payroll_cost_mtd; Type: VIEW; Schema: analytics; Owner: hris_admin
--

CREATE VIEW analytics.v_payroll_cost_mtd AS
 SELECT d.name AS department,
    count(ep.id) AS employee_count,
    sum(ep.gross_pay) AS total_gross,
    sum(ep.net_pay) AS total_net,
    sum(ep.total_deductions) AS total_deductions,
    sum(ep.loan_deductions) AS total_loan_deductions
   FROM ((((payroll.pay_employee_payroll ep
     JOIN payroll.pay_runs pr ON ((pr.id = ep.run_id)))
     JOIN payroll.pay_periods pp ON ((pp.id = pr.period_id)))
     JOIN core.employees e ON ((e.id = ep.employee_id)))
     LEFT JOIN core.departments d ON ((d.id = e.department_id)))
  WHERE (((pr.status)::text = 'POSTED'::text) AND (pp.date_from >= date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone)))
  GROUP BY d.name
  ORDER BY (sum(ep.gross_pay)) DESC;


ALTER TABLE analytics.v_payroll_cost_mtd OWNER TO hris_admin;

--
-- Name: att_admin_overrides; Type: TABLE; Schema: attendance; Owner: hris_admin
--

CREATE TABLE attendance.att_admin_overrides (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    work_date date NOT NULL,
    orig_time_in timestamp without time zone,
    orig_time_out timestamp without time zone,
    orig_hours numeric(5,2),
    orig_status character varying(20),
    new_time_in timestamp without time zone,
    new_time_out timestamp without time zone,
    new_hours numeric(5,2),
    new_status character varying(20),
    reason text NOT NULL,
    overridden_by bigint NOT NULL,
    overridden_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE attendance.att_admin_overrides OWNER TO hris_admin;

--
-- Name: TABLE att_admin_overrides; Type: COMMENT; Schema: attendance; Owner: hris_admin
--

COMMENT ON TABLE attendance.att_admin_overrides IS 'Immutable audit log of every admin direct-edit on att_daily.';


--
-- Name: att_admin_overrides_id_seq; Type: SEQUENCE; Schema: attendance; Owner: hris_admin
--

CREATE SEQUENCE attendance.att_admin_overrides_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE attendance.att_admin_overrides_id_seq OWNER TO hris_admin;

--
-- Name: att_admin_overrides_id_seq; Type: SEQUENCE OWNED BY; Schema: attendance; Owner: hris_admin
--

ALTER SEQUENCE attendance.att_admin_overrides_id_seq OWNED BY attendance.att_admin_overrides.id;


--
-- Name: att_daily_id_seq; Type: SEQUENCE; Schema: attendance; Owner: hris_admin
--

CREATE SEQUENCE attendance.att_daily_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE attendance.att_daily_id_seq OWNER TO hris_admin;

--
-- Name: att_daily_id_seq; Type: SEQUENCE OWNED BY; Schema: attendance; Owner: hris_admin
--

ALTER SEQUENCE attendance.att_daily_id_seq OWNED BY attendance.att_daily.id;


--
-- Name: att_dtr_corrections; Type: TABLE; Schema: attendance; Owner: hris_admin
--

CREATE TABLE attendance.att_dtr_corrections (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    work_date date NOT NULL,
    field_to_correct character varying(30) NOT NULL,
    original_value timestamp with time zone,
    corrected_value timestamp with time zone NOT NULL,
    reason text NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    reviewed_by bigint,
    reviewed_at timestamp with time zone,
    review_remarks text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE attendance.att_dtr_corrections OWNER TO hris_admin;

--
-- Name: att_dtr_corrections_id_seq; Type: SEQUENCE; Schema: attendance; Owner: hris_admin
--

CREATE SEQUENCE attendance.att_dtr_corrections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE attendance.att_dtr_corrections_id_seq OWNER TO hris_admin;

--
-- Name: att_dtr_corrections_id_seq; Type: SEQUENCE OWNED BY; Schema: attendance; Owner: hris_admin
--

ALTER SEQUENCE attendance.att_dtr_corrections_id_seq OWNED BY attendance.att_dtr_corrections.id;


--
-- Name: att_holiday_types; Type: TABLE; Schema: attendance; Owner: hris_admin
--

CREATE TABLE attendance.att_holiday_types (
    id bigint NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
    pay_multiplier numeric(4,2) DEFAULT 1.0 NOT NULL,
    description text
);


ALTER TABLE attendance.att_holiday_types OWNER TO hris_admin;

--
-- Name: att_holiday_types_id_seq; Type: SEQUENCE; Schema: attendance; Owner: hris_admin
--

CREATE SEQUENCE attendance.att_holiday_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE attendance.att_holiday_types_id_seq OWNER TO hris_admin;

--
-- Name: att_holiday_types_id_seq; Type: SEQUENCE OWNED BY; Schema: attendance; Owner: hris_admin
--

ALTER SEQUENCE attendance.att_holiday_types_id_seq OWNED BY attendance.att_holiday_types.id;


--
-- Name: att_holidays; Type: TABLE; Schema: attendance; Owner: hris_admin
--

CREATE TABLE attendance.att_holidays (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    holiday_type_id bigint NOT NULL,
    holiday_date date NOT NULL,
    name character varying(200) NOT NULL,
    description text,
    is_recurring boolean DEFAULT false NOT NULL,
    month_day character varying(6),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE attendance.att_holidays OWNER TO hris_admin;

--
-- Name: att_holidays_id_seq; Type: SEQUENCE; Schema: attendance; Owner: hris_admin
--

CREATE SEQUENCE attendance.att_holidays_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE attendance.att_holidays_id_seq OWNER TO hris_admin;

--
-- Name: att_holidays_id_seq; Type: SEQUENCE OWNED BY; Schema: attendance; Owner: hris_admin
--

ALTER SEQUENCE attendance.att_holidays_id_seq OWNED BY attendance.att_holidays.id;


--
-- Name: att_logs; Type: TABLE; Schema: attendance; Owner: hris_admin
--

CREATE TABLE attendance.att_logs (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    log_datetime timestamp with time zone NOT NULL,
    log_type character varying(10) NOT NULL,
    source character varying(20) DEFAULT 'MANUAL'::character varying NOT NULL,
    device_id character varying(50),
    location character varying(200),
    photo_path text,
    is_valid boolean DEFAULT true NOT NULL,
    invalidated_by bigint,
    invalidation_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
)
PARTITION BY RANGE (log_datetime);


ALTER TABLE attendance.att_logs OWNER TO hris_admin;

--
-- Name: att_logs_id_seq; Type: SEQUENCE; Schema: attendance; Owner: hris_admin
--

CREATE SEQUENCE attendance.att_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE attendance.att_logs_id_seq OWNER TO hris_admin;

--
-- Name: att_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: attendance; Owner: hris_admin
--

ALTER SEQUENCE attendance.att_logs_id_seq OWNED BY attendance.att_logs.id;


--
-- Name: att_logs_2025; Type: TABLE; Schema: attendance; Owner: hris_admin
--

CREATE TABLE attendance.att_logs_2025 (
    id bigint DEFAULT nextval('attendance.att_logs_id_seq'::regclass) NOT NULL,
    employee_id bigint NOT NULL,
    log_datetime timestamp with time zone NOT NULL,
    log_type character varying(10) NOT NULL,
    source character varying(20) DEFAULT 'MANUAL'::character varying NOT NULL,
    device_id character varying(50),
    location character varying(200),
    photo_path text,
    is_valid boolean DEFAULT true NOT NULL,
    invalidated_by bigint,
    invalidation_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE attendance.att_logs_2025 OWNER TO hris_admin;

--
-- Name: att_logs_2026; Type: TABLE; Schema: attendance; Owner: hris_admin
--

CREATE TABLE attendance.att_logs_2026 (
    id bigint DEFAULT nextval('attendance.att_logs_id_seq'::regclass) NOT NULL,
    employee_id bigint NOT NULL,
    log_datetime timestamp with time zone NOT NULL,
    log_type character varying(10) NOT NULL,
    source character varying(20) DEFAULT 'MANUAL'::character varying NOT NULL,
    device_id character varying(50),
    location character varying(200),
    photo_path text,
    is_valid boolean DEFAULT true NOT NULL,
    invalidated_by bigint,
    invalidation_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE attendance.att_logs_2026 OWNER TO hris_admin;

--
-- Name: att_logs_2027; Type: TABLE; Schema: attendance; Owner: hris_admin
--

CREATE TABLE attendance.att_logs_2027 (
    id bigint DEFAULT nextval('attendance.att_logs_id_seq'::regclass) NOT NULL,
    employee_id bigint NOT NULL,
    log_datetime timestamp with time zone NOT NULL,
    log_type character varying(10) NOT NULL,
    source character varying(20) DEFAULT 'MANUAL'::character varying NOT NULL,
    device_id character varying(50),
    location character varying(200),
    photo_path text,
    is_valid boolean DEFAULT true NOT NULL,
    invalidated_by bigint,
    invalidation_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE attendance.att_logs_2027 OWNER TO hris_admin;

--
-- Name: att_logs_2028; Type: TABLE; Schema: attendance; Owner: hris_admin
--

CREATE TABLE attendance.att_logs_2028 (
    id bigint DEFAULT nextval('attendance.att_logs_id_seq'::regclass) NOT NULL,
    employee_id bigint NOT NULL,
    log_datetime timestamp with time zone NOT NULL,
    log_type character varying(10) NOT NULL,
    source character varying(20) DEFAULT 'MANUAL'::character varying NOT NULL,
    device_id character varying(50),
    location character varying(200),
    photo_path text,
    is_valid boolean DEFAULT true NOT NULL,
    invalidated_by bigint,
    invalidation_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE attendance.att_logs_2028 OWNER TO hris_admin;

--
-- Name: att_overtime_requests; Type: TABLE; Schema: attendance; Owner: hris_admin
--

CREATE TABLE attendance.att_overtime_requests (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    request_date date NOT NULL,
    expected_ot_hours numeric(4,2) NOT NULL,
    reason text NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    workflow_instance_id bigint,
    approved_by bigint,
    approved_at timestamp with time zone,
    rejection_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE attendance.att_overtime_requests OWNER TO hris_admin;

--
-- Name: att_overtime_requests_id_seq; Type: SEQUENCE; Schema: attendance; Owner: hris_admin
--

CREATE SEQUENCE attendance.att_overtime_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE attendance.att_overtime_requests_id_seq OWNER TO hris_admin;

--
-- Name: att_overtime_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: attendance; Owner: hris_admin
--

ALTER SEQUENCE attendance.att_overtime_requests_id_seq OWNED BY attendance.att_overtime_requests.id;


--
-- Name: att_shift_assignments; Type: TABLE; Schema: attendance; Owner: hris_admin
--

CREATE TABLE attendance.att_shift_assignments (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    shift_id bigint NOT NULL,
    effective_from date NOT NULL,
    effective_to date,
    created_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE attendance.att_shift_assignments OWNER TO hris_admin;

--
-- Name: att_shift_assignments_id_seq; Type: SEQUENCE; Schema: attendance; Owner: hris_admin
--

CREATE SEQUENCE attendance.att_shift_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE attendance.att_shift_assignments_id_seq OWNER TO hris_admin;

--
-- Name: att_shift_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: attendance; Owner: hris_admin
--

ALTER SEQUENCE attendance.att_shift_assignments_id_seq OWNED BY attendance.att_shift_assignments.id;


--
-- Name: att_shifts; Type: TABLE; Schema: attendance; Owner: hris_admin
--

CREATE TABLE attendance.att_shifts (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
    shift_type character varying(20) DEFAULT 'FIXED'::character varying NOT NULL,
    time_in time without time zone,
    time_out time without time zone,
    break_minutes integer DEFAULT 60 NOT NULL,
    total_work_hours numeric(4,2),
    grace_period_minutes integer DEFAULT 0 NOT NULL,
    is_night_shift boolean DEFAULT false NOT NULL,
    crosses_midnight boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE attendance.att_shifts OWNER TO hris_admin;

--
-- Name: att_shifts_id_seq; Type: SEQUENCE; Schema: attendance; Owner: hris_admin
--

CREATE SEQUENCE attendance.att_shifts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE attendance.att_shifts_id_seq OWNER TO hris_admin;

--
-- Name: att_shifts_id_seq; Type: SEQUENCE OWNED BY; Schema: attendance; Owner: hris_admin
--

ALTER SEQUENCE attendance.att_shifts_id_seq OWNED BY attendance.att_shifts.id;


--
-- Name: v_attendance_summary; Type: VIEW; Schema: attendance; Owner: hris_admin
--

CREATE VIEW attendance.v_attendance_summary AS
 SELECT ad.work_date,
    ad.employee_id,
    (((e.last_name)::text || ', '::text) || (e.first_name)::text) AS full_name,
    e.employee_no,
    d.name AS department,
    ad.status,
    ad.time_in,
    ad.time_out,
    ad.hours_worked,
    ad.hours_late,
    ad.hours_overtime,
    ad.is_holiday,
    ad.is_restday,
    ad.is_locked
   FROM ((attendance.att_daily ad
     JOIN core.employees e ON ((e.id = ad.employee_id)))
     LEFT JOIN core.departments d ON ((d.id = e.department_id)));


ALTER TABLE attendance.v_attendance_summary OWNER TO hris_admin;

--
-- Name: v_today_board; Type: VIEW; Schema: attendance; Owner: hris_admin
--

CREATE VIEW attendance.v_today_board AS
 SELECT e.id AS employee_id,
    e.employee_no,
    (((e.last_name)::text || ', '::text) || (e.first_name)::text) AS full_name,
    d.name AS department,
    COALESCE(ad.status, 'NOT_LOGGED'::character varying) AS status,
    ad.time_in,
    ad.time_out,
    ad.hours_worked,
    ad.hours_late
   FROM ((core.employees e
     LEFT JOIN core.departments d ON ((d.id = e.department_id)))
     LEFT JOIN attendance.att_daily ad ON (((ad.employee_id = e.id) AND (ad.work_date = CURRENT_DATE))))
  WHERE ((e.is_active = true) AND ((e.status)::text <> ALL ((ARRAY['RESIGNED'::character varying, 'TERMINATED'::character varying, 'RETIRED'::character varying, 'DECEASED'::character varying])::text[])));


ALTER TABLE attendance.v_today_board OWNER TO hris_admin;

--
-- Name: sys_bulk_operation_logs; Type: TABLE; Schema: audit_logs; Owner: hris_admin
--

CREATE TABLE audit_logs.sys_bulk_operation_logs (
    id bigint NOT NULL,
    user_id bigint,
    company_id bigint,
    operation_type character varying(100) NOT NULL,
    total_records integer DEFAULT 0 NOT NULL,
    success_count integer DEFAULT 0 NOT NULL,
    failure_count integer DEFAULT 0 NOT NULL,
    skipped_count integer DEFAULT 0 NOT NULL,
    error_log jsonb DEFAULT '[]'::jsonb NOT NULL,
    file_source text,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    duration_ms bigint GENERATED ALWAYS AS (((EXTRACT(epoch FROM (completed_at - started_at)) * (1000)::numeric))::bigint) STORED
);


ALTER TABLE audit_logs.sys_bulk_operation_logs OWNER TO hris_admin;

--
-- Name: sys_bulk_operation_logs_id_seq; Type: SEQUENCE; Schema: audit_logs; Owner: hris_admin
--

CREATE SEQUENCE audit_logs.sys_bulk_operation_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE audit_logs.sys_bulk_operation_logs_id_seq OWNER TO hris_admin;

--
-- Name: sys_bulk_operation_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: audit_logs; Owner: hris_admin
--

ALTER SEQUENCE audit_logs.sys_bulk_operation_logs_id_seq OWNED BY audit_logs.sys_bulk_operation_logs.id;


--
-- Name: sys_change_log; Type: TABLE; Schema: audit_logs; Owner: hris_admin
--

CREATE TABLE audit_logs.sys_change_log (
    id bigint NOT NULL,
    schema_name character varying(63) DEFAULT 'core'::character varying NOT NULL,
    table_name character varying(100) NOT NULL,
    operation character varying(10) NOT NULL,
    row_id bigint,
    row_uuid uuid,
    old_data jsonb,
    new_data jsonb,
    changed_fields text[],
    user_id bigint,
    company_id bigint,
    client_ip inet,
    session_id character varying(100),
    app_context character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
)
PARTITION BY RANGE (created_at);


ALTER TABLE audit_logs.sys_change_log OWNER TO hris_admin;

--
-- Name: sys_change_log_id_seq; Type: SEQUENCE; Schema: audit_logs; Owner: hris_admin
--

CREATE SEQUENCE audit_logs.sys_change_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE audit_logs.sys_change_log_id_seq OWNER TO hris_admin;

--
-- Name: sys_change_log_id_seq; Type: SEQUENCE OWNED BY; Schema: audit_logs; Owner: hris_admin
--

ALTER SEQUENCE audit_logs.sys_change_log_id_seq OWNED BY audit_logs.sys_change_log.id;


--
-- Name: sys_change_log_2025; Type: TABLE; Schema: audit_logs; Owner: hris_admin
--

CREATE TABLE audit_logs.sys_change_log_2025 (
    id bigint DEFAULT nextval('audit_logs.sys_change_log_id_seq'::regclass) NOT NULL,
    schema_name character varying(63) DEFAULT 'core'::character varying NOT NULL,
    table_name character varying(100) NOT NULL,
    operation character varying(10) NOT NULL,
    row_id bigint,
    row_uuid uuid,
    old_data jsonb,
    new_data jsonb,
    changed_fields text[],
    user_id bigint,
    company_id bigint,
    client_ip inet,
    session_id character varying(100),
    app_context character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE audit_logs.sys_change_log_2025 OWNER TO hris_admin;

--
-- Name: sys_change_log_2026; Type: TABLE; Schema: audit_logs; Owner: hris_admin
--

CREATE TABLE audit_logs.sys_change_log_2026 (
    id bigint DEFAULT nextval('audit_logs.sys_change_log_id_seq'::regclass) NOT NULL,
    schema_name character varying(63) DEFAULT 'core'::character varying NOT NULL,
    table_name character varying(100) NOT NULL,
    operation character varying(10) NOT NULL,
    row_id bigint,
    row_uuid uuid,
    old_data jsonb,
    new_data jsonb,
    changed_fields text[],
    user_id bigint,
    company_id bigint,
    client_ip inet,
    session_id character varying(100),
    app_context character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE audit_logs.sys_change_log_2026 OWNER TO hris_admin;

--
-- Name: sys_change_log_2027; Type: TABLE; Schema: audit_logs; Owner: hris_admin
--

CREATE TABLE audit_logs.sys_change_log_2027 (
    id bigint DEFAULT nextval('audit_logs.sys_change_log_id_seq'::regclass) NOT NULL,
    schema_name character varying(63) DEFAULT 'core'::character varying NOT NULL,
    table_name character varying(100) NOT NULL,
    operation character varying(10) NOT NULL,
    row_id bigint,
    row_uuid uuid,
    old_data jsonb,
    new_data jsonb,
    changed_fields text[],
    user_id bigint,
    company_id bigint,
    client_ip inet,
    session_id character varying(100),
    app_context character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE audit_logs.sys_change_log_2027 OWNER TO hris_admin;

--
-- Name: sys_change_log_2028; Type: TABLE; Schema: audit_logs; Owner: hris_admin
--

CREATE TABLE audit_logs.sys_change_log_2028 (
    id bigint DEFAULT nextval('audit_logs.sys_change_log_id_seq'::regclass) NOT NULL,
    schema_name character varying(63) DEFAULT 'core'::character varying NOT NULL,
    table_name character varying(100) NOT NULL,
    operation character varying(10) NOT NULL,
    row_id bigint,
    row_uuid uuid,
    old_data jsonb,
    new_data jsonb,
    changed_fields text[],
    user_id bigint,
    company_id bigint,
    client_ip inet,
    session_id character varying(100),
    app_context character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE audit_logs.sys_change_log_2028 OWNER TO hris_admin;

--
-- Name: sys_data_exports; Type: TABLE; Schema: audit_logs; Owner: hris_admin
--

CREATE TABLE audit_logs.sys_data_exports (
    id bigint NOT NULL,
    user_id bigint,
    company_id bigint,
    export_type character varying(50) NOT NULL,
    module character varying(50) NOT NULL,
    format character varying(20) DEFAULT 'CSV'::character varying NOT NULL,
    filter_params jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_count integer,
    file_path text,
    client_ip inet,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE audit_logs.sys_data_exports OWNER TO hris_admin;

--
-- Name: sys_data_exports_id_seq; Type: SEQUENCE; Schema: audit_logs; Owner: hris_admin
--

CREATE SEQUENCE audit_logs.sys_data_exports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE audit_logs.sys_data_exports_id_seq OWNER TO hris_admin;

--
-- Name: sys_data_exports_id_seq; Type: SEQUENCE OWNED BY; Schema: audit_logs; Owner: hris_admin
--

ALTER SEQUENCE audit_logs.sys_data_exports_id_seq OWNED BY audit_logs.sys_data_exports.id;


--
-- Name: sys_field_changes; Type: TABLE; Schema: audit_logs; Owner: hris_admin
--

CREATE TABLE audit_logs.sys_field_changes (
    id bigint NOT NULL,
    change_log_id bigint NOT NULL,
    table_name character varying(100) NOT NULL,
    row_id bigint,
    field_name character varying(100) NOT NULL,
    old_value text,
    new_value text,
    data_type character varying(50),
    user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
)
PARTITION BY RANGE (created_at);


ALTER TABLE audit_logs.sys_field_changes OWNER TO hris_admin;

--
-- Name: sys_field_changes_id_seq; Type: SEQUENCE; Schema: audit_logs; Owner: hris_admin
--

CREATE SEQUENCE audit_logs.sys_field_changes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE audit_logs.sys_field_changes_id_seq OWNER TO hris_admin;

--
-- Name: sys_field_changes_id_seq; Type: SEQUENCE OWNED BY; Schema: audit_logs; Owner: hris_admin
--

ALTER SEQUENCE audit_logs.sys_field_changes_id_seq OWNED BY audit_logs.sys_field_changes.id;


--
-- Name: sys_field_changes_2025; Type: TABLE; Schema: audit_logs; Owner: hris_admin
--

CREATE TABLE audit_logs.sys_field_changes_2025 (
    id bigint DEFAULT nextval('audit_logs.sys_field_changes_id_seq'::regclass) NOT NULL,
    change_log_id bigint NOT NULL,
    table_name character varying(100) NOT NULL,
    row_id bigint,
    field_name character varying(100) NOT NULL,
    old_value text,
    new_value text,
    data_type character varying(50),
    user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE audit_logs.sys_field_changes_2025 OWNER TO hris_admin;

--
-- Name: sys_field_changes_2026; Type: TABLE; Schema: audit_logs; Owner: hris_admin
--

CREATE TABLE audit_logs.sys_field_changes_2026 (
    id bigint DEFAULT nextval('audit_logs.sys_field_changes_id_seq'::regclass) NOT NULL,
    change_log_id bigint NOT NULL,
    table_name character varying(100) NOT NULL,
    row_id bigint,
    field_name character varying(100) NOT NULL,
    old_value text,
    new_value text,
    data_type character varying(50),
    user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE audit_logs.sys_field_changes_2026 OWNER TO hris_admin;

--
-- Name: sys_field_changes_2027; Type: TABLE; Schema: audit_logs; Owner: hris_admin
--

CREATE TABLE audit_logs.sys_field_changes_2027 (
    id bigint DEFAULT nextval('audit_logs.sys_field_changes_id_seq'::regclass) NOT NULL,
    change_log_id bigint NOT NULL,
    table_name character varying(100) NOT NULL,
    row_id bigint,
    field_name character varying(100) NOT NULL,
    old_value text,
    new_value text,
    data_type character varying(50),
    user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE audit_logs.sys_field_changes_2027 OWNER TO hris_admin;

--
-- Name: sys_field_changes_2028; Type: TABLE; Schema: audit_logs; Owner: hris_admin
--

CREATE TABLE audit_logs.sys_field_changes_2028 (
    id bigint DEFAULT nextval('audit_logs.sys_field_changes_id_seq'::regclass) NOT NULL,
    change_log_id bigint NOT NULL,
    table_name character varying(100) NOT NULL,
    row_id bigint,
    field_name character varying(100) NOT NULL,
    old_value text,
    new_value text,
    data_type character varying(50),
    user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE audit_logs.sys_field_changes_2028 OWNER TO hris_admin;

--
-- Name: sys_login_logs; Type: TABLE; Schema: audit_logs; Owner: hris_admin
--

CREATE TABLE audit_logs.sys_login_logs (
    id bigint NOT NULL,
    user_id bigint,
    username character varying(100),
    company_id bigint,
    event_type character varying(30) NOT NULL,
    client_ip inet,
    user_agent text,
    session_id character varying(100),
    sso_provider character varying(50),
    failure_reason character varying(200),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE audit_logs.sys_login_logs OWNER TO hris_admin;

--
-- Name: sys_login_logs_id_seq; Type: SEQUENCE; Schema: audit_logs; Owner: hris_admin
--

CREATE SEQUENCE audit_logs.sys_login_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE audit_logs.sys_login_logs_id_seq OWNER TO hris_admin;

--
-- Name: sys_login_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: audit_logs; Owner: hris_admin
--

ALTER SEQUENCE audit_logs.sys_login_logs_id_seq OWNED BY audit_logs.sys_login_logs.id;


--
-- Name: sys_payroll_audit; Type: TABLE; Schema: audit_logs; Owner: hris_admin
--

CREATE TABLE audit_logs.sys_payroll_audit (
    id bigint NOT NULL,
    run_id bigint,
    employee_id bigint,
    field_name character varying(100) NOT NULL,
    old_value numeric(14,2),
    new_value numeric(14,2),
    change_reason text,
    changed_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE audit_logs.sys_payroll_audit OWNER TO hris_admin;

--
-- Name: sys_payroll_audit_id_seq; Type: SEQUENCE; Schema: audit_logs; Owner: hris_admin
--

CREATE SEQUENCE audit_logs.sys_payroll_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE audit_logs.sys_payroll_audit_id_seq OWNER TO hris_admin;

--
-- Name: sys_payroll_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: audit_logs; Owner: hris_admin
--

ALTER SEQUENCE audit_logs.sys_payroll_audit_id_seq OWNED BY audit_logs.sys_payroll_audit.id;


--
-- Name: sys_status_transitions; Type: TABLE; Schema: audit_logs; Owner: hris_admin
--

CREATE TABLE audit_logs.sys_status_transitions (
    id bigint NOT NULL,
    module character varying(50) NOT NULL,
    entity_type character varying(100) NOT NULL,
    entity_id bigint NOT NULL,
    from_status character varying(50),
    to_status character varying(50) NOT NULL,
    transitioned_by bigint,
    reason text,
    duration_from_prev_ms bigint,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE audit_logs.sys_status_transitions OWNER TO hris_admin;

--
-- Name: sys_status_transitions_id_seq; Type: SEQUENCE; Schema: audit_logs; Owner: hris_admin
--

CREATE SEQUENCE audit_logs.sys_status_transitions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE audit_logs.sys_status_transitions_id_seq OWNER TO hris_admin;

--
-- Name: sys_status_transitions_id_seq; Type: SEQUENCE OWNED BY; Schema: audit_logs; Owner: hris_admin
--

ALTER SEQUENCE audit_logs.sys_status_transitions_id_seq OWNED BY audit_logs.sys_status_transitions.id;


--
-- Name: users; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.users (
    id bigint NOT NULL,
    company_id bigint,
    username character varying(100) NOT NULL,
    email character varying(200),
    password_hash character varying(255) DEFAULT ''::character varying NOT NULL,
    display_name character varying(150),
    role_code character varying(50) DEFAULT 'EMPLOYEE'::character varying NOT NULL,
    employee_id bigint,
    is_active boolean DEFAULT true NOT NULL,
    last_login_at timestamp with time zone,
    failed_attempts integer DEFAULT 0 NOT NULL,
    locked_until timestamp with time zone,
    password_changed_at timestamp with time zone,
    mfa_enabled boolean DEFAULT false NOT NULL,
    mfa_secret character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    theme_id bigint
);


ALTER TABLE core.users OWNER TO hris_admin;

--
-- Name: v_recent_changes; Type: VIEW; Schema: audit_logs; Owner: hris_admin
--

CREATE VIEW audit_logs.v_recent_changes AS
 SELECT cl.id,
    cl.schema_name,
    cl.table_name,
    cl.operation,
    cl.row_id,
    cl.changed_fields,
    cl.user_id,
    u.display_name AS changed_by_name,
    cl.app_context,
    cl.created_at
   FROM (audit_logs.sys_change_log cl
     LEFT JOIN core.users u ON ((cl.user_id = u.id)))
  ORDER BY cl.created_at DESC
 LIMIT 500;


ALTER TABLE audit_logs.v_recent_changes OWNER TO hris_admin;

--
-- Name: v_security_events; Type: VIEW; Schema: audit_logs; Owner: hris_admin
--

CREATE VIEW audit_logs.v_security_events AS
 SELECT sys_login_logs.event_type,
    sys_login_logs.username,
    sys_login_logs.client_ip,
    sys_login_logs.failure_reason,
    sys_login_logs.created_at
   FROM audit_logs.sys_login_logs
  WHERE ((sys_login_logs.event_type)::text = ANY ((ARRAY['LOGIN_FAILED'::character varying, 'ACCOUNT_LOCKED'::character varying, 'MFA_FAILED'::character varying, 'PASSWORD_RESET'::character varying])::text[]))
  ORDER BY sys_login_logs.created_at DESC;


ALTER TABLE audit_logs.v_security_events OWNER TO hris_admin;

--
-- Name: v_user_activity_summary; Type: VIEW; Schema: audit_logs; Owner: hris_admin
--

CREATE VIEW audit_logs.v_user_activity_summary AS
 SELECT u.id AS user_id,
    u.username,
    u.display_name,
    u.role_code,
    count(cl.id) AS total_changes,
    count(cl.id) FILTER (WHERE ((cl.operation)::text = 'INSERT'::text)) AS inserts,
    count(cl.id) FILTER (WHERE ((cl.operation)::text = 'UPDATE'::text)) AS updates,
    count(cl.id) FILTER (WHERE ((cl.operation)::text = 'DELETE'::text)) AS deletes,
    max(cl.created_at) AS last_activity_at,
    count(ll.id) AS total_logins,
    max(ll.created_at) AS last_login_at
   FROM ((core.users u
     LEFT JOIN audit_logs.sys_change_log cl ON ((u.id = cl.user_id)))
     LEFT JOIN audit_logs.sys_login_logs ll ON (((u.id = ll.user_id) AND ((ll.event_type)::text = 'LOGIN_SUCCESS'::text))))
  GROUP BY u.id, u.username, u.display_name, u.role_code;


ALTER TABLE audit_logs.v_user_activity_summary OWNER TO hris_admin;

--
-- Name: business_units; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.business_units (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(200) NOT NULL,
    parent_id bigint,
    head_employee_id bigint,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.business_units OWNER TO hris_admin;

--
-- Name: business_units_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.business_units_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.business_units_id_seq OWNER TO hris_admin;

--
-- Name: business_units_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.business_units_id_seq OWNED BY core.business_units.id;


--
-- Name: companies; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.companies (
    id bigint NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(200) NOT NULL,
    legal_name character varying(200),
    industry character varying(100),
    size_bracket character varying(20) DEFAULT 'MSME'::character varying NOT NULL,
    address_line1 text,
    address_line2 text,
    barangay character varying(100),
    city character varying(100),
    province character varying(100),
    region character varying(100),
    zip_code character varying(10),
    country character varying(100) DEFAULT 'Philippines'::character varying NOT NULL,
    phone character varying(30),
    email character varying(200),
    website character varying(200),
    tin character varying(20),
    sss_employer_id character varying(30),
    phic_employer_id character varying(30),
    hdmf_employer_id character varying(30),
    logo_path text,
    fiscal_year_start integer DEFAULT 1 NOT NULL,
    payroll_cycle character varying(20) DEFAULT 'SEMI_MONTHLY'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.companies OWNER TO hris_admin;

--
-- Name: companies_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.companies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.companies_id_seq OWNER TO hris_admin;

--
-- Name: companies_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.companies_id_seq OWNED BY core.companies.id;


--
-- Name: company_branding; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.company_branding (
    id bigint NOT NULL,
    company_id bigint,
    key character varying(60) NOT NULL,
    value text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.company_branding OWNER TO hris_admin;

--
-- Name: company_branding_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.company_branding_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.company_branding_id_seq OWNER TO hris_admin;

--
-- Name: company_branding_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.company_branding_id_seq OWNED BY core.company_branding.id;


--
-- Name: dashboard_metrics; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.dashboard_metrics (
    id bigint NOT NULL,
    code character varying(60) NOT NULL,
    label character varying(100) NOT NULL,
    icon character varying(50),
    module character varying(50),
    sql_query text NOT NULL,
    filter_url character varying(300),
    roles text[] DEFAULT '{}'::text[] NOT NULL,
    sort_order integer DEFAULT 99 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.dashboard_metrics OWNER TO hris_admin;

--
-- Name: dashboard_metrics_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.dashboard_metrics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.dashboard_metrics_id_seq OWNER TO hris_admin;

--
-- Name: dashboard_metrics_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.dashboard_metrics_id_seq OWNED BY core.dashboard_metrics.id;


--
-- Name: demo_profiles; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.demo_profiles (
    id bigint NOT NULL,
    code character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    employee_count integer DEFAULT 20 NOT NULL,
    color character varying(10) DEFAULT '#4f46e5'::character varying NOT NULL,
    icon character varying(10) DEFAULT '📋'::character varying NOT NULL,
    scenario_notes jsonb DEFAULT '[]'::jsonb NOT NULL,
    is_active boolean DEFAULT false NOT NULL,
    loaded_at timestamp with time zone,
    loaded_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.demo_profiles OWNER TO hris_admin;

--
-- Name: demo_profiles_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.demo_profiles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.demo_profiles_id_seq OWNER TO hris_admin;

--
-- Name: demo_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.demo_profiles_id_seq OWNED BY core.demo_profiles.id;


--
-- Name: departments_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.departments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.departments_id_seq OWNER TO hris_admin;

--
-- Name: departments_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.departments_id_seq OWNED BY core.departments.id;


--
-- Name: documents; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.documents (
    id bigint NOT NULL,
    company_id bigint,
    employee_id bigint,
    document_type character varying(60) NOT NULL,
    document_name character varying(200) NOT NULL,
    file_path text,
    file_size_kb integer,
    mime_type character varying(100),
    is_missing boolean DEFAULT false NOT NULL,
    is_expired boolean DEFAULT false NOT NULL,
    expiry_date date,
    uploaded_by bigint,
    verified_by bigint,
    verified_at timestamp with time zone,
    status character varying(30) DEFAULT 'PENDING'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    category_id bigint,
    retention_until date,
    is_archived boolean DEFAULT false NOT NULL
);


ALTER TABLE core.documents OWNER TO hris_admin;

--
-- Name: documents_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.documents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.documents_id_seq OWNER TO hris_admin;

--
-- Name: documents_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.documents_id_seq OWNED BY core.documents.id;


--
-- Name: dynamic_forms; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.dynamic_forms (
    id bigint NOT NULL,
    form_code character varying(60) NOT NULL,
    title character varying(100) NOT NULL,
    module character varying(50),
    description text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.dynamic_forms OWNER TO hris_admin;

--
-- Name: dynamic_forms_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.dynamic_forms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.dynamic_forms_id_seq OWNER TO hris_admin;

--
-- Name: dynamic_forms_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.dynamic_forms_id_seq OWNED BY core.dynamic_forms.id;


--
-- Name: emp_addresses; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.emp_addresses (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    address_type character varying(30) NOT NULL,
    line1 text NOT NULL,
    line2 text,
    barangay character varying(100),
    city character varying(100),
    province character varying(100),
    region character varying(100),
    zip_code character varying(10),
    country character varying(100) DEFAULT 'Philippines'::character varying NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.emp_addresses OWNER TO hris_admin;

--
-- Name: emp_addresses_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.emp_addresses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.emp_addresses_id_seq OWNER TO hris_admin;

--
-- Name: emp_addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.emp_addresses_id_seq OWNED BY core.emp_addresses.id;


--
-- Name: emp_bank_accounts; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.emp_bank_accounts (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    bank_name character varying(100) NOT NULL,
    bank_code character varying(20),
    account_name character varying(200) NOT NULL,
    account_number character varying(50) NOT NULL,
    account_type character varying(30) DEFAULT 'SAVINGS'::character varying NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.emp_bank_accounts OWNER TO hris_admin;

--
-- Name: emp_bank_accounts_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.emp_bank_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.emp_bank_accounts_id_seq OWNER TO hris_admin;

--
-- Name: emp_bank_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.emp_bank_accounts_id_seq OWNED BY core.emp_bank_accounts.id;


--
-- Name: emp_dependents; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.emp_dependents (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    full_name character varying(200) NOT NULL,
    relationship character varying(50) NOT NULL,
    date_of_birth date,
    is_beneficiary boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.emp_dependents OWNER TO hris_admin;

--
-- Name: emp_dependents_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.emp_dependents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.emp_dependents_id_seq OWNER TO hris_admin;

--
-- Name: emp_dependents_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.emp_dependents_id_seq OWNED BY core.emp_dependents.id;


--
-- Name: emp_education; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.emp_education (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    level character varying(50) NOT NULL,
    institution character varying(200) NOT NULL,
    degree character varying(200),
    field_of_study character varying(200),
    year_from integer,
    year_to integer,
    honors character varying(100),
    is_highest boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.emp_education OWNER TO hris_admin;

--
-- Name: emp_education_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.emp_education_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.emp_education_id_seq OWNER TO hris_admin;

--
-- Name: emp_education_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.emp_education_id_seq OWNED BY core.emp_education.id;


--
-- Name: emp_emergency_contacts; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.emp_emergency_contacts (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    full_name character varying(200) NOT NULL,
    relationship character varying(50) NOT NULL,
    mobile_no character varying(20),
    phone_no character varying(20),
    address text,
    is_primary boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.emp_emergency_contacts OWNER TO hris_admin;

--
-- Name: emp_emergency_contacts_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.emp_emergency_contacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.emp_emergency_contacts_id_seq OWNER TO hris_admin;

--
-- Name: emp_emergency_contacts_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.emp_emergency_contacts_id_seq OWNED BY core.emp_emergency_contacts.id;


--
-- Name: emp_government_ids; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.emp_government_ids (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    id_type character varying(30) NOT NULL,
    id_number character varying(50) NOT NULL,
    issue_date date,
    expiry_date date,
    file_path text,
    is_verified boolean DEFAULT false NOT NULL,
    verified_by bigint,
    verified_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.emp_government_ids OWNER TO hris_admin;

--
-- Name: emp_government_ids_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.emp_government_ids_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.emp_government_ids_id_seq OWNER TO hris_admin;

--
-- Name: emp_government_ids_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.emp_government_ids_id_seq OWNED BY core.emp_government_ids.id;


--
-- Name: emp_status_history; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.emp_status_history (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    from_status character varying(30),
    to_status character varying(30) NOT NULL,
    effective_date date NOT NULL,
    reason text,
    remarks text,
    changed_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.emp_status_history OWNER TO hris_admin;

--
-- Name: emp_status_history_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.emp_status_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.emp_status_history_id_seq OWNER TO hris_admin;

--
-- Name: emp_status_history_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.emp_status_history_id_seq OWNED BY core.emp_status_history.id;


--
-- Name: emp_work_history; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.emp_work_history (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    company_name character varying(200) NOT NULL,
    position_held character varying(200),
    date_from date,
    date_to date,
    reason_for_leaving text,
    immediate_supervisor character varying(200),
    contact_no character varying(30),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.emp_work_history OWNER TO hris_admin;

--
-- Name: emp_work_history_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.emp_work_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.emp_work_history_id_seq OWNER TO hris_admin;

--
-- Name: emp_work_history_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.emp_work_history_id_seq OWNED BY core.emp_work_history.id;


--
-- Name: employees_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.employees_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.employees_id_seq OWNER TO hris_admin;

--
-- Name: employees_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.employees_id_seq OWNED BY core.employees.id;


--
-- Name: employment_types; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.employment_types (
    id bigint NOT NULL,
    code character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    is_entitled_benefits boolean DEFAULT true NOT NULL,
    probation_days integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.employment_types OWNER TO hris_admin;

--
-- Name: employment_types_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.employment_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.employment_types_id_seq OWNER TO hris_admin;

--
-- Name: employment_types_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.employment_types_id_seq OWNED BY core.employment_types.id;


--
-- Name: feature_registry; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.feature_registry (
    id bigint NOT NULL,
    code character varying(60) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    module character varying(50),
    is_enabled boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    feature_type character varying(20) DEFAULT 'MODULE'::character varying NOT NULL,
    action_type character varying(20),
    page_path character varying(200),
    CONSTRAINT feature_registry_action_type_check CHECK (((action_type)::text = ANY ((ARRAY['VIEW'::character varying, 'PRINT'::character varying, 'EXPORT'::character varying, 'EDIT'::character varying, 'OVERRIDE'::character varying, 'ADJUST'::character varying, 'APPROVE'::character varying, 'CREATE'::character varying, 'DELETE'::character varying, 'TOGGLE'::character varying, NULL::character varying])::text[]))),
    CONSTRAINT feature_registry_feature_type_check CHECK (((feature_type)::text = ANY ((ARRAY['MODULE'::character varying, 'ACTION'::character varying])::text[])))
);


ALTER TABLE core.feature_registry OWNER TO hris_admin;

--
-- Name: feature_registry_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.feature_registry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.feature_registry_id_seq OWNER TO hris_admin;

--
-- Name: feature_registry_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.feature_registry_id_seq OWNED BY core.feature_registry.id;


--
-- Name: field_privacy_rules; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.field_privacy_rules (
    id bigint NOT NULL,
    section character varying(60) NOT NULL,
    field_name character varying(100) NOT NULL,
    role_code character varying(50) NOT NULL,
    visibility character varying(10) DEFAULT 'VISIBLE'::character varying NOT NULL,
    mask_char character varying(20) DEFAULT '***'::character varying,
    updated_by bigint,
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT field_privacy_rules_visibility_check CHECK (((visibility)::text = ANY ((ARRAY['VISIBLE'::character varying, 'MASKED'::character varying, 'HIDDEN'::character varying])::text[])))
);


ALTER TABLE core.field_privacy_rules OWNER TO hris_admin;

--
-- Name: TABLE field_privacy_rules; Type: COMMENT; Schema: core; Owner: hris_admin
--

COMMENT ON TABLE core.field_privacy_rules IS 'Field-level visibility controls per role. Absent = VISIBLE (default). MASKED = value shown as mask_char. HIDDEN = field excluded entirely.';


--
-- Name: field_privacy_rules_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.field_privacy_rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.field_privacy_rules_id_seq OWNER TO hris_admin;

--
-- Name: field_privacy_rules_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.field_privacy_rules_id_seq OWNED BY core.field_privacy_rules.id;


--
-- Name: form_fields; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.form_fields (
    id bigint NOT NULL,
    form_id bigint NOT NULL,
    field_name character varying(60) NOT NULL,
    label character varying(100) NOT NULL,
    field_type character varying(30) DEFAULT 'TEXT'::character varying NOT NULL,
    is_required boolean DEFAULT false NOT NULL,
    options jsonb,
    sort_order integer DEFAULT 99 NOT NULL
);


ALTER TABLE core.form_fields OWNER TO hris_admin;

--
-- Name: form_fields_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.form_fields_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.form_fields_id_seq OWNER TO hris_admin;

--
-- Name: form_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.form_fields_id_seq OWNED BY core.form_fields.id;


--
-- Name: job_grades; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.job_grades (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
    grade_level integer NOT NULL,
    salary_min numeric(14,2),
    salary_max numeric(14,2),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.job_grades OWNER TO hris_admin;

--
-- Name: job_grades_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.job_grades_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.job_grades_id_seq OWNER TO hris_admin;

--
-- Name: job_grades_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.job_grades_id_seq OWNED BY core.job_grades.id;


--
-- Name: mod_permissions; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.mod_permissions (
    id bigint NOT NULL,
    module_code character varying(30) NOT NULL,
    grantee_type character varying(10) NOT NULL,
    grantee_role character varying(30),
    grantee_user_id bigint,
    can_modify boolean DEFAULT true NOT NULL,
    granted_by bigint,
    granted_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT mod_permissions_grantee_type_check CHECK (((grantee_type)::text = ANY ((ARRAY['ROLE'::character varying, 'USER'::character varying])::text[]))),
    CONSTRAINT mp_grantee_check CHECK (((((grantee_type)::text = 'ROLE'::text) AND (grantee_role IS NOT NULL) AND (grantee_user_id IS NULL)) OR (((grantee_type)::text = 'USER'::text) AND (grantee_user_id IS NOT NULL) AND (grantee_role IS NULL))))
);


ALTER TABLE core.mod_permissions OWNER TO hris_admin;

--
-- Name: TABLE mod_permissions; Type: COMMENT; Schema: core; Owner: hris_admin
--

COMMENT ON TABLE core.mod_permissions IS 'Configures which roles/users may modify (override/adjust) transactional records per module.';


--
-- Name: mod_permissions_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.mod_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.mod_permissions_id_seq OWNER TO hris_admin;

--
-- Name: mod_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.mod_permissions_id_seq OWNED BY core.mod_permissions.id;


--
-- Name: orchestration_flows; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.orchestration_flows (
    id bigint NOT NULL,
    flow_code character varying(60) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    trigger_event character varying(100),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.orchestration_flows OWNER TO hris_admin;

--
-- Name: orchestration_flows_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.orchestration_flows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.orchestration_flows_id_seq OWNER TO hris_admin;

--
-- Name: orchestration_flows_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.orchestration_flows_id_seq OWNED BY core.orchestration_flows.id;


--
-- Name: orchestration_steps; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.orchestration_steps (
    id bigint NOT NULL,
    flow_id bigint NOT NULL,
    step_order integer NOT NULL,
    action_type character varying(50) NOT NULL,
    action_config jsonb DEFAULT '{}'::jsonb NOT NULL,
    condition text
);


ALTER TABLE core.orchestration_steps OWNER TO hris_admin;

--
-- Name: orchestration_steps_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.orchestration_steps_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.orchestration_steps_id_seq OWNER TO hris_admin;

--
-- Name: orchestration_steps_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.orchestration_steps_id_seq OWNED BY core.orchestration_steps.id;


--
-- Name: org_chart_nodes; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.org_chart_nodes (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    employee_id bigint,
    position_id bigint,
    parent_node_id bigint,
    node_type character varying(30) DEFAULT 'POSITION'::character varying NOT NULL,
    effective_from date NOT NULL,
    effective_to date,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.org_chart_nodes OWNER TO hris_admin;

--
-- Name: org_chart_nodes_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.org_chart_nodes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.org_chart_nodes_id_seq OWNER TO hris_admin;

--
-- Name: org_chart_nodes_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.org_chart_nodes_id_seq OWNED BY core.org_chart_nodes.id;


--
-- Name: page_registry; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.page_registry (
    id bigint NOT NULL,
    path character varying(200) NOT NULL,
    title character varying(100) NOT NULL,
    module character varying(50),
    nav_group character varying(50),
    nav_label character varying(100),
    nav_icon character varying(50),
    nav_order integer DEFAULT 99 NOT NULL,
    is_visible boolean DEFAULT true NOT NULL,
    requires_feature character varying(60),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.page_registry OWNER TO hris_admin;

--
-- Name: page_registry_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.page_registry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.page_registry_id_seq OWNER TO hris_admin;

--
-- Name: page_registry_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.page_registry_id_seq OWNED BY core.page_registry.id;


--
-- Name: permissions; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.permissions (
    id bigint NOT NULL,
    module character varying(50) NOT NULL,
    resource character varying(100) NOT NULL,
    action character varying(50) NOT NULL,
    description text
);


ALTER TABLE core.permissions OWNER TO hris_admin;

--
-- Name: permissions_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.permissions_id_seq OWNER TO hris_admin;

--
-- Name: permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.permissions_id_seq OWNED BY core.permissions.id;


--
-- Name: positions; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.positions (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    department_id bigint,
    job_grade_id bigint,
    code character varying(20) NOT NULL,
    title character varying(200) NOT NULL,
    description text,
    is_managerial boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.positions OWNER TO hris_admin;

--
-- Name: positions_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.positions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.positions_id_seq OWNER TO hris_admin;

--
-- Name: positions_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.positions_id_seq OWNED BY core.positions.id;


--
-- Name: role_feature_access; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.role_feature_access (
    id bigint NOT NULL,
    role_code character varying(50) NOT NULL,
    feature_id bigint NOT NULL,
    can_access boolean DEFAULT true NOT NULL
);


ALTER TABLE core.role_feature_access OWNER TO hris_admin;

--
-- Name: role_feature_access_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.role_feature_access_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.role_feature_access_id_seq OWNER TO hris_admin;

--
-- Name: role_feature_access_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.role_feature_access_id_seq OWNED BY core.role_feature_access.id;


--
-- Name: role_page_access; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.role_page_access (
    id bigint NOT NULL,
    role_code character varying(50) NOT NULL,
    page_id bigint NOT NULL,
    can_access boolean DEFAULT true NOT NULL
);


ALTER TABLE core.role_page_access OWNER TO hris_admin;

--
-- Name: role_page_access_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.role_page_access_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.role_page_access_id_seq OWNER TO hris_admin;

--
-- Name: role_page_access_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.role_page_access_id_seq OWNED BY core.role_page_access.id;


--
-- Name: role_permissions; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.role_permissions (
    id bigint NOT NULL,
    role_id bigint NOT NULL,
    permission_id bigint NOT NULL,
    granted boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.role_permissions OWNER TO hris_admin;

--
-- Name: role_permissions_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.role_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.role_permissions_id_seq OWNER TO hris_admin;

--
-- Name: role_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.role_permissions_id_seq OWNED BY core.role_permissions.id;


--
-- Name: roles; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.roles (
    id bigint NOT NULL,
    company_id bigint,
    code character varying(50) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    is_system_role boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.roles OWNER TO hris_admin;

--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.roles_id_seq OWNER TO hris_admin;

--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.roles_id_seq OWNED BY core.roles.id;


--
-- Name: search_index; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.search_index (
    id bigint NOT NULL,
    entity_type character varying(50) NOT NULL,
    entity_id bigint NOT NULL,
    title character varying(200) NOT NULL,
    subtitle character varying(200),
    keywords text,
    url character varying(300),
    module character varying(50),
    is_active boolean DEFAULT true NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.search_index OWNER TO hris_admin;

--
-- Name: search_index_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.search_index_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.search_index_id_seq OWNER TO hris_admin;

--
-- Name: search_index_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.search_index_id_seq OWNED BY core.search_index.id;


--
-- Name: status_definitions; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.status_definitions (
    id bigint NOT NULL,
    module character varying(50) NOT NULL,
    code character varying(50) NOT NULL,
    label character varying(100) NOT NULL,
    color character varying(20) DEFAULT '#94a3b8'::character varying NOT NULL,
    badge_class character varying(50),
    sort_order integer DEFAULT 99 NOT NULL
);


ALTER TABLE core.status_definitions OWNER TO hris_admin;

--
-- Name: status_definitions_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.status_definitions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.status_definitions_id_seq OWNER TO hris_admin;

--
-- Name: status_definitions_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.status_definitions_id_seq OWNED BY core.status_definitions.id;


--
-- Name: task_inbox; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.task_inbox (
    id bigint NOT NULL,
    employee_id bigint,
    user_id bigint,
    task_type character varying(50) NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    action_url character varying(255),
    priority character varying(20) DEFAULT 'NORMAL'::character varying NOT NULL,
    due_date date,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    is_read boolean DEFAULT false NOT NULL,
    source_table character varying(100),
    source_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone
);


ALTER TABLE core.task_inbox OWNER TO hris_admin;

--
-- Name: task_inbox_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.task_inbox_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.task_inbox_id_seq OWNER TO hris_admin;

--
-- Name: task_inbox_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.task_inbox_id_seq OWNED BY core.task_inbox.id;


--
-- Name: transaction_qr_tokens; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.transaction_qr_tokens (
    id bigint NOT NULL,
    token character varying(100) DEFAULT encode(public.gen_random_bytes(16), 'hex'::text) NOT NULL,
    module character varying(50) NOT NULL,
    entity_type character varying(60) NOT NULL,
    entity_id bigint NOT NULL,
    expires_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.transaction_qr_tokens OWNER TO hris_admin;

--
-- Name: transaction_qr_tokens_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.transaction_qr_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.transaction_qr_tokens_id_seq OWNER TO hris_admin;

--
-- Name: transaction_qr_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.transaction_qr_tokens_id_seq OWNED BY core.transaction_qr_tokens.id;


--
-- Name: transaction_registry; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.transaction_registry (
    id bigint NOT NULL,
    module character varying(50) NOT NULL,
    type_code character varying(60) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    workflow_def_code character varying(60),
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE core.transaction_registry OWNER TO hris_admin;

--
-- Name: transaction_registry_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.transaction_registry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.transaction_registry_id_seq OWNER TO hris_admin;

--
-- Name: transaction_registry_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.transaction_registry_id_seq OWNED BY core.transaction_registry.id;


--
-- Name: ui_themes; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.ui_themes (
    id bigint NOT NULL,
    name character varying(100) NOT NULL,
    is_active boolean DEFAULT false NOT NULL,
    primary_color character varying(20),
    secondary_color character varying(20),
    accent_color character varying(20),
    bg_color character varying(20),
    card_color character varying(20),
    sidebar_color character varying(20),
    sidebar_text character varying(20),
    border_radius character varying(10),
    font_family character varying(100),
    text_color character varying(20),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.ui_themes OWNER TO hris_admin;

--
-- Name: ui_themes_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.ui_themes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.ui_themes_id_seq OWNER TO hris_admin;

--
-- Name: ui_themes_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.ui_themes_id_seq OWNED BY core.ui_themes.id;


--
-- Name: user_feature_access; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.user_feature_access (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    feature_id bigint NOT NULL,
    can_access boolean DEFAULT true NOT NULL,
    granted_by bigint,
    granted_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.user_feature_access OWNER TO hris_admin;

--
-- Name: user_feature_access_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.user_feature_access_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.user_feature_access_id_seq OWNER TO hris_admin;

--
-- Name: user_feature_access_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.user_feature_access_id_seq OWNED BY core.user_feature_access.id;


--
-- Name: user_page_access; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.user_page_access (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    page_id bigint NOT NULL,
    can_access boolean DEFAULT true NOT NULL,
    granted_by bigint,
    granted_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE core.user_page_access OWNER TO hris_admin;

--
-- Name: user_page_access_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.user_page_access_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.user_page_access_id_seq OWNER TO hris_admin;

--
-- Name: user_page_access_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.user_page_access_id_seq OWNED BY core.user_page_access.id;


--
-- Name: user_roles; Type: TABLE; Schema: core; Owner: hris_admin
--

CREATE TABLE core.user_roles (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    role_id bigint NOT NULL,
    assigned_at timestamp with time zone DEFAULT now() NOT NULL,
    assigned_by bigint,
    expires_at timestamp with time zone,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE core.user_roles OWNER TO hris_admin;

--
-- Name: user_roles_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.user_roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.user_roles_id_seq OWNER TO hris_admin;

--
-- Name: user_roles_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.user_roles_id_seq OWNED BY core.user_roles.id;


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: core; Owner: hris_admin
--

CREATE SEQUENCE core.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE core.users_id_seq OWNER TO hris_admin;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: hris_admin
--

ALTER SEQUENCE core.users_id_seq OWNED BY core.users.id;


--
-- Name: v_employees_full; Type: VIEW; Schema: core; Owner: hris_admin
--

CREATE VIEW core.v_employees_full AS
 SELECT e.id,
    e.uuid,
    e.employee_no,
    ((((e.last_name)::text || ', '::text) || (e.first_name)::text) || COALESCE((' '::text || (e.middle_name)::text), ''::text)) AS full_name,
    e.first_name,
    e.last_name,
    e.middle_name,
    e.suffix,
    e.gender,
    e.civil_status,
    e.date_of_birth,
    e.work_email,
    e.mobile_no,
    e.status,
    e.work_arrangement,
    e.date_hired,
    e.date_regularized,
    e.date_separated,
    e.basic_salary,
    e.daily_rate,
    e.hourly_rate,
    e.department_id,
    d.name AS department_name,
    d.code AS department_code,
    e.position_id,
    p.title AS position_title,
    p.code AS position_code,
    p.is_managerial,
    e.job_grade_id,
    jg.code AS grade_code,
    jg.name AS grade_name,
    e.employment_type_id,
    et.name AS employment_type,
    concat(s.first_name, ' ', s.last_name) AS supervisor_name,
    e.is_active,
    (EXTRACT(year FROM age((CURRENT_DATE)::timestamp with time zone, (e.date_hired)::timestamp with time zone)))::integer AS years_of_service,
    ((EXTRACT(month FROM age((CURRENT_DATE)::timestamp with time zone, (e.date_hired)::timestamp with time zone)))::integer + ((EXTRACT(year FROM age((CURRENT_DATE)::timestamp with time zone, (e.date_hired)::timestamp with time zone)))::integer * 12)) AS tenure_months,
    e.profile_photo_path,
    e.company_id,
    e.created_at,
    e.updated_at
   FROM (((((core.employees e
     LEFT JOIN core.departments d ON ((e.department_id = d.id)))
     LEFT JOIN core.positions p ON ((e.position_id = p.id)))
     LEFT JOIN core.job_grades jg ON ((e.job_grade_id = jg.id)))
     LEFT JOIN core.employment_types et ON ((e.employment_type_id = et.id)))
     LEFT JOIN core.employees s ON ((e.immediate_supervisor_id = s.id)));


ALTER TABLE core.v_employees_full OWNER TO hris_admin;

--
-- Name: appeals; Type: TABLE; Schema: discipline; Owner: hris_admin
--

CREATE TABLE discipline.appeals (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    decision_id bigint NOT NULL,
    appeal_date date NOT NULL,
    appeal_body character varying(60) DEFAULT 'CSC_REGIONAL'::character varying NOT NULL,
    grounds text NOT NULL,
    status character varying(20) DEFAULT 'FILED'::character varying NOT NULL,
    resolution text,
    resolution_date date,
    document_path text,
    filed_by bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT appeals_appeal_body_check CHECK (((appeal_body)::text = ANY ((ARRAY['CSC_REGIONAL'::character varying, 'CSC_CENTRAL'::character varying, 'COURT_OF_APPEALS'::character varying, 'SUPREME_COURT'::character varying])::text[]))),
    CONSTRAINT appeals_status_check CHECK (((status)::text = ANY ((ARRAY['FILED'::character varying, 'UNDER_REVIEW'::character varying, 'RESOLVED'::character varying, 'DISMISSED'::character varying])::text[])))
);


ALTER TABLE discipline.appeals OWNER TO hris_admin;

--
-- Name: appeals_id_seq; Type: SEQUENCE; Schema: discipline; Owner: hris_admin
--

CREATE SEQUENCE discipline.appeals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE discipline.appeals_id_seq OWNER TO hris_admin;

--
-- Name: appeals_id_seq; Type: SEQUENCE OWNED BY; Schema: discipline; Owner: hris_admin
--

ALTER SEQUENCE discipline.appeals_id_seq OWNED BY discipline.appeals.id;


--
-- Name: case_types; Type: TABLE; Schema: discipline; Owner: hris_admin
--

CREATE TABLE discipline.case_types (
    id bigint NOT NULL,
    code character varying(40) NOT NULL,
    name character varying(200) NOT NULL,
    gravity character varying(20) NOT NULL,
    description text,
    legal_basis character varying(200),
    default_penalty character varying(40),
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT case_types_gravity_check CHECK (((gravity)::text = ANY ((ARRAY['LIGHT'::character varying, 'LESS_GRAVE'::character varying, 'GRAVE'::character varying])::text[])))
);


ALTER TABLE discipline.case_types OWNER TO hris_admin;

--
-- Name: case_types_id_seq; Type: SEQUENCE; Schema: discipline; Owner: hris_admin
--

CREATE SEQUENCE discipline.case_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE discipline.case_types_id_seq OWNER TO hris_admin;

--
-- Name: case_types_id_seq; Type: SEQUENCE OWNED BY; Schema: discipline; Owner: hris_admin
--

ALTER SEQUENCE discipline.case_types_id_seq OWNED BY discipline.case_types.id;


--
-- Name: cases; Type: TABLE; Schema: discipline; Owner: hris_admin
--

CREATE TABLE discipline.cases (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    case_no character varying(40) NOT NULL,
    respondent_id bigint NOT NULL,
    complainant_id bigint,
    case_type_id bigint NOT NULL,
    offense_description text NOT NULL,
    date_of_offense date,
    date_filed date DEFAULT CURRENT_DATE NOT NULL,
    status character varying(30) DEFAULT 'COMPLAINT_FILED'::character varying NOT NULL,
    gravity character varying(20),
    is_confidential boolean DEFAULT true NOT NULL,
    assigned_to bigint,
    workflow_instance_id bigint,
    created_by bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT cases_status_check CHECK (((status)::text = ANY ((ARRAY['COMPLAINT_FILED'::character varying, 'PRELIMINARY_INVESTIGATION'::character varying, 'FORMAL_CHARGE'::character varying, 'PREVENTIVE_SUSPENSION'::character varying, 'HEARING'::character varying, 'DECISION'::character varying, 'APPEAL'::character varying, 'CLOSED'::character varying, 'DISMISSED'::character varying])::text[])))
);


ALTER TABLE discipline.cases OWNER TO hris_admin;

--
-- Name: cases_id_seq; Type: SEQUENCE; Schema: discipline; Owner: hris_admin
--

CREATE SEQUENCE discipline.cases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE discipline.cases_id_seq OWNER TO hris_admin;

--
-- Name: cases_id_seq; Type: SEQUENCE OWNED BY; Schema: discipline; Owner: hris_admin
--

ALTER SEQUENCE discipline.cases_id_seq OWNED BY discipline.cases.id;


--
-- Name: complaints; Type: TABLE; Schema: discipline; Owner: hris_admin
--

CREATE TABLE discipline.complaints (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    complaint_text text NOT NULL,
    evidence_summary text,
    supporting_docs jsonb DEFAULT '[]'::jsonb NOT NULL,
    sworn_statement_path text,
    filed_by bigint NOT NULL,
    filed_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE discipline.complaints OWNER TO hris_admin;

--
-- Name: complaints_id_seq; Type: SEQUENCE; Schema: discipline; Owner: hris_admin
--

CREATE SEQUENCE discipline.complaints_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE discipline.complaints_id_seq OWNER TO hris_admin;

--
-- Name: complaints_id_seq; Type: SEQUENCE OWNED BY; Schema: discipline; Owner: hris_admin
--

ALTER SEQUENCE discipline.complaints_id_seq OWNED BY discipline.complaints.id;


--
-- Name: decisions; Type: TABLE; Schema: discipline; Owner: hris_admin
--

CREATE TABLE discipline.decisions (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    decision_date date NOT NULL,
    verdict character varying(30) NOT NULL,
    penalty character varying(40),
    penalty_details text,
    suspension_days integer,
    decision_text text NOT NULL,
    decision_path text,
    decided_by bigint NOT NULL,
    effectivity_date date,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT decisions_verdict_check CHECK (((verdict)::text = ANY ((ARRAY['GUILTY'::character varying, 'NOT_GUILTY'::character varying, 'DISMISSED'::character varying, 'WITHDRAWN'::character varying])::text[])))
);


ALTER TABLE discipline.decisions OWNER TO hris_admin;

--
-- Name: decisions_id_seq; Type: SEQUENCE; Schema: discipline; Owner: hris_admin
--

CREATE SEQUENCE discipline.decisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE discipline.decisions_id_seq OWNER TO hris_admin;

--
-- Name: decisions_id_seq; Type: SEQUENCE OWNED BY; Schema: discipline; Owner: hris_admin
--

ALTER SEQUENCE discipline.decisions_id_seq OWNED BY discipline.decisions.id;


--
-- Name: formal_charges; Type: TABLE; Schema: discipline; Owner: hris_admin
--

CREATE TABLE discipline.formal_charges (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    charge_text text NOT NULL,
    offense_classification character varying(60),
    charge_date date DEFAULT CURRENT_DATE NOT NULL,
    answer_deadline date NOT NULL,
    answer_received_at timestamp with time zone,
    answer_text text,
    issued_by bigint NOT NULL,
    document_path text
);


ALTER TABLE discipline.formal_charges OWNER TO hris_admin;

--
-- Name: formal_charges_id_seq; Type: SEQUENCE; Schema: discipline; Owner: hris_admin
--

CREATE SEQUENCE discipline.formal_charges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE discipline.formal_charges_id_seq OWNER TO hris_admin;

--
-- Name: formal_charges_id_seq; Type: SEQUENCE OWNED BY; Schema: discipline; Owner: hris_admin
--

ALTER SEQUENCE discipline.formal_charges_id_seq OWNED BY discipline.formal_charges.id;


--
-- Name: hearings; Type: TABLE; Schema: discipline; Owner: hris_admin
--

CREATE TABLE discipline.hearings (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    hearing_type character varying(30) DEFAULT 'FORMAL'::character varying NOT NULL,
    scheduled_date timestamp with time zone NOT NULL,
    actual_date timestamp with time zone,
    venue character varying(200),
    presiding_officer_id bigint,
    minutes_text text,
    minutes_path text,
    attendees jsonb DEFAULT '[]'::jsonb NOT NULL,
    status character varying(20) DEFAULT 'SCHEDULED'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hearings_hearing_type_check CHECK (((hearing_type)::text = ANY ((ARRAY['FORMAL'::character varying, 'CLARIFICATORY'::character varying, 'PRE_HEARING'::character varying])::text[]))),
    CONSTRAINT hearings_status_check CHECK (((status)::text = ANY ((ARRAY['SCHEDULED'::character varying, 'COMPLETED'::character varying, 'POSTPONED'::character varying, 'CANCELLED'::character varying])::text[])))
);


ALTER TABLE discipline.hearings OWNER TO hris_admin;

--
-- Name: hearings_id_seq; Type: SEQUENCE; Schema: discipline; Owner: hris_admin
--

CREATE SEQUENCE discipline.hearings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE discipline.hearings_id_seq OWNER TO hris_admin;

--
-- Name: hearings_id_seq; Type: SEQUENCE OWNED BY; Schema: discipline; Owner: hris_admin
--

ALTER SEQUENCE discipline.hearings_id_seq OWNED BY discipline.hearings.id;


--
-- Name: investigations; Type: TABLE; Schema: discipline; Owner: hris_admin
--

CREATE TABLE discipline.investigations (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    investigator_id bigint NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    findings text,
    recommendation character varying(30),
    report_path text,
    status character varying(20) DEFAULT 'IN_PROGRESS'::character varying NOT NULL,
    CONSTRAINT investigations_recommendation_check CHECK (((recommendation)::text = ANY ((ARRAY['PROCEED_FORMAL_CHARGE'::character varying, 'DISMISS'::character varying, 'MEDIATE'::character varying])::text[]))),
    CONSTRAINT investigations_status_check CHECK (((status)::text = ANY ((ARRAY['IN_PROGRESS'::character varying, 'COMPLETED'::character varying, 'DEFERRED'::character varying])::text[])))
);


ALTER TABLE discipline.investigations OWNER TO hris_admin;

--
-- Name: investigations_id_seq; Type: SEQUENCE; Schema: discipline; Owner: hris_admin
--

CREATE SEQUENCE discipline.investigations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE discipline.investigations_id_seq OWNER TO hris_admin;

--
-- Name: investigations_id_seq; Type: SEQUENCE OWNED BY; Schema: discipline; Owner: hris_admin
--

ALTER SEQUENCE discipline.investigations_id_seq OWNED BY discipline.investigations.id;


--
-- Name: preventive_suspensions; Type: TABLE; Schema: discipline; Owner: hris_admin
--

CREATE TABLE discipline.preventive_suspensions (
    id bigint NOT NULL,
    case_id bigint NOT NULL,
    employee_id bigint NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    reason text NOT NULL,
    order_path text,
    approved_by bigint,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_max_90_days CHECK (((end_date - start_date) <= 90))
);


ALTER TABLE discipline.preventive_suspensions OWNER TO hris_admin;

--
-- Name: preventive_suspensions_id_seq; Type: SEQUENCE; Schema: discipline; Owner: hris_admin
--

CREATE SEQUENCE discipline.preventive_suspensions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE discipline.preventive_suspensions_id_seq OWNER TO hris_admin;

--
-- Name: preventive_suspensions_id_seq; Type: SEQUENCE OWNED BY; Schema: discipline; Owner: hris_admin
--

ALTER SEQUENCE discipline.preventive_suspensions_id_seq OWNED BY discipline.preventive_suspensions.id;


--
-- Name: v_active_suspensions; Type: VIEW; Schema: discipline; Owner: hris_admin
--

CREATE VIEW discipline.v_active_suspensions AS
 SELECT ps.id,
    ps.case_id,
    ps.employee_id,
    ps.start_date,
    ps.end_date,
    ps.reason,
    ps.order_path,
    ps.approved_by,
    ps.is_active,
    ps.created_at,
    (((e.first_name)::text || ' '::text) || (e.last_name)::text) AS employee_name,
    c.case_no,
    (ps.end_date - CURRENT_DATE) AS days_remaining
   FROM ((discipline.preventive_suspensions ps
     JOIN core.employees e ON ((e.id = ps.employee_id)))
     JOIN discipline.cases c ON ((c.id = ps.case_id)))
  WHERE ((ps.is_active = true) AND (ps.end_date >= CURRENT_DATE));


ALTER TABLE discipline.v_active_suspensions OWNER TO hris_admin;

--
-- Name: v_case_summary; Type: VIEW; Schema: discipline; Owner: hris_admin
--

CREATE VIEW discipline.v_case_summary AS
 SELECT c.id,
    c.case_no,
    c.status,
    c.date_filed,
    c.is_confidential,
    c.offense_description,
    ct.name AS offense_type,
    ct.gravity,
    (((e.first_name)::text || ' '::text) || (e.last_name)::text) AS respondent_name,
    d.name AS department_name,
    (CURRENT_DATE - c.date_filed) AS days_since_filed,
    c.assigned_to,
    u_assigned.display_name AS assigned_to_name
   FROM ((((discipline.cases c
     JOIN discipline.case_types ct ON ((ct.id = c.case_type_id)))
     JOIN core.employees e ON ((e.id = c.respondent_id)))
     LEFT JOIN core.departments d ON ((d.id = e.department_id)))
     LEFT JOIN core.users u_assigned ON ((u_assigned.id = c.assigned_to)));


ALTER TABLE discipline.v_case_summary OWNER TO hris_admin;

--
-- Name: certificate_requests; Type: TABLE; Schema: dms; Owner: hris_admin
--

CREATE TABLE dms.certificate_requests (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    cert_type_id bigint NOT NULL,
    purpose text,
    copies_requested integer DEFAULT 1 NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    processed_by bigint,
    processed_at timestamp with time zone,
    released_at timestamp with time zone,
    released_by bigint,
    document_id bigint,
    rejection_reason text,
    workflow_instance_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT certificate_requests_status_check CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'PROCESSING'::character varying, 'READY'::character varying, 'RELEASED'::character varying, 'REJECTED'::character varying])::text[])))
);


ALTER TABLE dms.certificate_requests OWNER TO hris_admin;

--
-- Name: certificate_requests_id_seq; Type: SEQUENCE; Schema: dms; Owner: hris_admin
--

CREATE SEQUENCE dms.certificate_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE dms.certificate_requests_id_seq OWNER TO hris_admin;

--
-- Name: certificate_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: dms; Owner: hris_admin
--

ALTER SEQUENCE dms.certificate_requests_id_seq OWNED BY dms.certificate_requests.id;


--
-- Name: certificate_types; Type: TABLE; Schema: dms; Owner: hris_admin
--

CREATE TABLE dms.certificate_types (
    id bigint NOT NULL,
    code character varying(30) NOT NULL,
    name character varying(200) NOT NULL,
    description text,
    processing_days integer DEFAULT 3 NOT NULL,
    requires_approval boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE dms.certificate_types OWNER TO hris_admin;

--
-- Name: certificate_types_id_seq; Type: SEQUENCE; Schema: dms; Owner: hris_admin
--

CREATE SEQUENCE dms.certificate_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE dms.certificate_types_id_seq OWNER TO hris_admin;

--
-- Name: certificate_types_id_seq; Type: SEQUENCE OWNED BY; Schema: dms; Owner: hris_admin
--

ALTER SEQUENCE dms.certificate_types_id_seq OWNED BY dms.certificate_types.id;


--
-- Name: checklist_items; Type: TABLE; Schema: dms; Owner: hris_admin
--

CREATE TABLE dms.checklist_items (
    id bigint NOT NULL,
    template_id bigint NOT NULL,
    category_id bigint,
    document_type character varying(60) NOT NULL,
    label character varying(200) NOT NULL,
    is_mandatory boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 99 NOT NULL
);


ALTER TABLE dms.checklist_items OWNER TO hris_admin;

--
-- Name: checklist_items_id_seq; Type: SEQUENCE; Schema: dms; Owner: hris_admin
--

CREATE SEQUENCE dms.checklist_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE dms.checklist_items_id_seq OWNER TO hris_admin;

--
-- Name: checklist_items_id_seq; Type: SEQUENCE OWNED BY; Schema: dms; Owner: hris_admin
--

ALTER SEQUENCE dms.checklist_items_id_seq OWNED BY dms.checklist_items.id;


--
-- Name: checklist_templates; Type: TABLE; Schema: dms; Owner: hris_admin
--

CREATE TABLE dms.checklist_templates (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    employment_type_id bigint,
    name character varying(200) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE dms.checklist_templates OWNER TO hris_admin;

--
-- Name: checklist_templates_id_seq; Type: SEQUENCE; Schema: dms; Owner: hris_admin
--

CREATE SEQUENCE dms.checklist_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE dms.checklist_templates_id_seq OWNER TO hris_admin;

--
-- Name: checklist_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: dms; Owner: hris_admin
--

ALTER SEQUENCE dms.checklist_templates_id_seq OWNED BY dms.checklist_templates.id;


--
-- Name: document_categories; Type: TABLE; Schema: dms; Owner: hris_admin
--

CREATE TABLE dms.document_categories (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    code character varying(40) NOT NULL,
    name character varying(200) NOT NULL,
    parent_id bigint,
    description text,
    sort_order integer DEFAULT 99 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE dms.document_categories OWNER TO hris_admin;

--
-- Name: document_categories_id_seq; Type: SEQUENCE; Schema: dms; Owner: hris_admin
--

CREATE SEQUENCE dms.document_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE dms.document_categories_id_seq OWNER TO hris_admin;

--
-- Name: document_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: dms; Owner: hris_admin
--

ALTER SEQUENCE dms.document_categories_id_seq OWNED BY dms.document_categories.id;


--
-- Name: document_requests; Type: TABLE; Schema: dms; Owner: hris_admin
--

CREATE TABLE dms.document_requests (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    employee_id bigint NOT NULL,
    document_type character varying(60) NOT NULL,
    purpose text,
    requested_by bigint NOT NULL,
    due_date date,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    fulfilled_doc_id bigint,
    remarks text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT document_requests_status_check CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'SUBMITTED'::character varying, 'OVERDUE'::character varying, 'CANCELLED'::character varying])::text[])))
);


ALTER TABLE dms.document_requests OWNER TO hris_admin;

--
-- Name: document_requests_id_seq; Type: SEQUENCE; Schema: dms; Owner: hris_admin
--

CREATE SEQUENCE dms.document_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE dms.document_requests_id_seq OWNER TO hris_admin;

--
-- Name: document_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: dms; Owner: hris_admin
--

ALTER SEQUENCE dms.document_requests_id_seq OWNED BY dms.document_requests.id;


--
-- Name: retention_policies; Type: TABLE; Schema: dms; Owner: hris_admin
--

CREATE TABLE dms.retention_policies (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    category_id bigint NOT NULL,
    retention_years integer DEFAULT 10 NOT NULL,
    retention_basis character varying(60) DEFAULT 'FROM_UPLOAD'::character varying NOT NULL,
    disposal_method character varying(30) DEFAULT 'ARCHIVE'::character varying NOT NULL,
    legal_basis character varying(200),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT retention_policies_disposal_method_check CHECK (((disposal_method)::text = ANY ((ARRAY['ARCHIVE'::character varying, 'SHRED'::character varying, 'DELETE'::character varying])::text[]))),
    CONSTRAINT retention_policies_retention_basis_check CHECK (((retention_basis)::text = ANY ((ARRAY['FROM_UPLOAD'::character varying, 'FROM_SEPARATION'::character varying, 'FROM_EXPIRY'::character varying])::text[])))
);


ALTER TABLE dms.retention_policies OWNER TO hris_admin;

--
-- Name: retention_policies_id_seq; Type: SEQUENCE; Schema: dms; Owner: hris_admin
--

CREATE SEQUENCE dms.retention_policies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE dms.retention_policies_id_seq OWNER TO hris_admin;

--
-- Name: retention_policies_id_seq; Type: SEQUENCE OWNED BY; Schema: dms; Owner: hris_admin
--

ALTER SEQUENCE dms.retention_policies_id_seq OWNED BY dms.retention_policies.id;


--
-- Name: service_record_snapshots; Type: TABLE; Schema: dms; Owner: hris_admin
--

CREATE TABLE dms.service_record_snapshots (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    generated_by bigint,
    generated_at timestamp with time zone DEFAULT now() NOT NULL,
    snapshot_data jsonb NOT NULL,
    file_path text,
    is_latest boolean DEFAULT true NOT NULL
);


ALTER TABLE dms.service_record_snapshots OWNER TO hris_admin;

--
-- Name: service_record_snapshots_id_seq; Type: SEQUENCE; Schema: dms; Owner: hris_admin
--

CREATE SEQUENCE dms.service_record_snapshots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE dms.service_record_snapshots_id_seq OWNER TO hris_admin;

--
-- Name: service_record_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: dms; Owner: hris_admin
--

ALTER SEQUENCE dms.service_record_snapshots_id_seq OWNED BY dms.service_record_snapshots.id;


--
-- Name: v_document_completeness; Type: VIEW; Schema: dms; Owner: hris_admin
--

CREATE VIEW dms.v_document_completeness AS
 SELECT e.id AS employee_id,
    (((e.first_name)::text || ' '::text) || (e.last_name)::text) AS employee_name,
    d.name AS department_name,
    count(DISTINCT ci.id) AS required_count,
    count(DISTINCT doc.id) AS submitted_count,
        CASE
            WHEN (count(DISTINCT ci.id) > 0) THEN round((((count(DISTINCT doc.id))::numeric / (count(DISTINCT ci.id))::numeric) * (100)::numeric), 0)
            ELSE (0)::numeric
        END AS pct_complete
   FROM ((((core.employees e
     LEFT JOIN core.departments d ON ((d.id = e.department_id)))
     LEFT JOIN dms.checklist_templates ct ON (((ct.company_id = e.company_id) AND ((ct.employment_type_id IS NULL) OR (ct.employment_type_id = e.employment_type_id)) AND (ct.is_active = true))))
     LEFT JOIN dms.checklist_items ci ON ((ci.template_id = ct.id)))
     LEFT JOIN core.documents doc ON (((doc.employee_id = e.id) AND ((doc.document_type)::text = (ci.document_type)::text) AND ((doc.status)::text <> 'REJECTED'::text))))
  WHERE (e.is_active = true)
  GROUP BY e.id, e.first_name, e.last_name, d.name;


ALTER TABLE dms.v_document_completeness OWNER TO hris_admin;

--
-- Name: v_retention_due; Type: VIEW; Schema: dms; Owner: hris_admin
--

CREATE VIEW dms.v_retention_due AS
 SELECT doc.id AS document_id,
    doc.employee_id,
    (((e.first_name)::text || ' '::text) || (e.last_name)::text) AS employee_name,
    doc.document_name,
    doc.document_type,
    doc.retention_until,
    (doc.retention_until - CURRENT_DATE) AS days_remaining,
    rp.disposal_method
   FROM (((core.documents doc
     JOIN core.employees e ON ((e.id = doc.employee_id)))
     LEFT JOIN dms.document_categories dc ON ((dc.id = doc.category_id)))
     LEFT JOIN dms.retention_policies rp ON ((rp.category_id = dc.id)))
  WHERE ((doc.retention_until IS NOT NULL) AND (doc.is_archived = false) AND (doc.retention_until <= (CURRENT_DATE + '90 days'::interval)));


ALTER TABLE dms.v_retention_due OWNER TO hris_admin;

--
-- Name: health_certificates; Type: TABLE; Schema: health; Owner: hris_admin
--

CREATE TABLE health.health_certificates (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    certificate_type character varying(60) NOT NULL,
    issued_date date NOT NULL,
    expiry_date date,
    issuing_authority character varying(200),
    document_id bigint,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT health_certificates_status_check CHECK (((status)::text = ANY ((ARRAY['ACTIVE'::character varying, 'EXPIRED'::character varying, 'REVOKED'::character varying])::text[])))
);


ALTER TABLE health.health_certificates OWNER TO hris_admin;

--
-- Name: health_certificates_id_seq; Type: SEQUENCE; Schema: health; Owner: hris_admin
--

CREATE SEQUENCE health.health_certificates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE health.health_certificates_id_seq OWNER TO hris_admin;

--
-- Name: health_certificates_id_seq; Type: SEQUENCE OWNED BY; Schema: health; Owner: hris_admin
--

ALTER SEQUENCE health.health_certificates_id_seq OWNED BY health.health_certificates.id;


--
-- Name: incident_investigations; Type: TABLE; Schema: health; Owner: hris_admin
--

CREATE TABLE health.incident_investigations (
    id bigint NOT NULL,
    incident_id bigint NOT NULL,
    investigator_id bigint NOT NULL,
    investigation_date date NOT NULL,
    root_cause text,
    contributing_factors text,
    corrective_actions text,
    preventive_actions text,
    target_completion_date date,
    status character varying(20) DEFAULT 'IN_PROGRESS'::character varying NOT NULL,
    completed_at timestamp with time zone,
    report_path text,
    CONSTRAINT incident_investigations_status_check CHECK (((status)::text = ANY ((ARRAY['IN_PROGRESS'::character varying, 'COMPLETED'::character varying, 'VERIFIED'::character varying])::text[])))
);


ALTER TABLE health.incident_investigations OWNER TO hris_admin;

--
-- Name: incident_investigations_id_seq; Type: SEQUENCE; Schema: health; Owner: hris_admin
--

CREATE SEQUENCE health.incident_investigations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE health.incident_investigations_id_seq OWNER TO hris_admin;

--
-- Name: incident_investigations_id_seq; Type: SEQUENCE OWNED BY; Schema: health; Owner: hris_admin
--

ALTER SEQUENCE health.incident_investigations_id_seq OWNED BY health.incident_investigations.id;


--
-- Name: incident_persons; Type: TABLE; Schema: health; Owner: hris_admin
--

CREATE TABLE health.incident_persons (
    id bigint NOT NULL,
    incident_id bigint NOT NULL,
    employee_id bigint,
    person_name character varying(200),
    role character varying(30) DEFAULT 'INJURED'::character varying NOT NULL,
    injury_type character varying(100),
    body_part_affected character varying(100),
    treatment_given text,
    days_lost integer DEFAULT 0 NOT NULL,
    hospitalized boolean DEFAULT false NOT NULL,
    CONSTRAINT incident_persons_role_check CHECK (((role)::text = ANY ((ARRAY['INJURED'::character varying, 'WITNESS'::character varying, 'FIRST_RESPONDER'::character varying, 'SUPERVISOR'::character varying])::text[])))
);


ALTER TABLE health.incident_persons OWNER TO hris_admin;

--
-- Name: incident_persons_id_seq; Type: SEQUENCE; Schema: health; Owner: hris_admin
--

CREATE SEQUENCE health.incident_persons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE health.incident_persons_id_seq OWNER TO hris_admin;

--
-- Name: incident_persons_id_seq; Type: SEQUENCE OWNED BY; Schema: health; Owner: hris_admin
--

ALTER SEQUENCE health.incident_persons_id_seq OWNED BY health.incident_persons.id;


--
-- Name: incidents; Type: TABLE; Schema: health; Owner: hris_admin
--

CREATE TABLE health.incidents (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    incident_no character varying(40) NOT NULL,
    incident_date timestamp with time zone NOT NULL,
    location character varying(200) NOT NULL,
    incident_type character varying(40) NOT NULL,
    severity character varying(20) DEFAULT 'MINOR'::character varying NOT NULL,
    description text NOT NULL,
    immediate_action_taken text,
    reported_by bigint NOT NULL,
    reported_at timestamp with time zone DEFAULT now() NOT NULL,
    status character varying(20) DEFAULT 'REPORTED'::character varying NOT NULL,
    dole_reportable boolean DEFAULT false NOT NULL,
    dole_reported_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT incidents_incident_type_check CHECK (((incident_type)::text = ANY ((ARRAY['INJURY'::character varying, 'ILLNESS'::character varying, 'NEAR_MISS'::character varying, 'PROPERTY_DAMAGE'::character varying, 'ENVIRONMENTAL'::character varying, 'OTHER'::character varying])::text[]))),
    CONSTRAINT incidents_severity_check CHECK (((severity)::text = ANY ((ARRAY['MINOR'::character varying, 'MODERATE'::character varying, 'MAJOR'::character varying, 'FATAL'::character varying])::text[]))),
    CONSTRAINT incidents_status_check CHECK (((status)::text = ANY ((ARRAY['REPORTED'::character varying, 'INVESTIGATING'::character varying, 'RESOLVED'::character varying, 'CLOSED'::character varying])::text[])))
);


ALTER TABLE health.incidents OWNER TO hris_admin;

--
-- Name: incidents_id_seq; Type: SEQUENCE; Schema: health; Owner: hris_admin
--

CREATE SEQUENCE health.incidents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE health.incidents_id_seq OWNER TO hris_admin;

--
-- Name: incidents_id_seq; Type: SEQUENCE OWNED BY; Schema: health; Owner: hris_admin
--

ALTER SEQUENCE health.incidents_id_seq OWNED BY health.incidents.id;


--
-- Name: medical_records; Type: TABLE; Schema: health; Owner: hris_admin
--

CREATE TABLE health.medical_records (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    blood_type character varying(5),
    allergies text,
    chronic_conditions text,
    medications text,
    emergency_medical_notes text,
    last_updated_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE health.medical_records OWNER TO hris_admin;

--
-- Name: medical_records_id_seq; Type: SEQUENCE; Schema: health; Owner: hris_admin
--

CREATE SEQUENCE health.medical_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE health.medical_records_id_seq OWNER TO hris_admin;

--
-- Name: medical_records_id_seq; Type: SEQUENCE OWNED BY; Schema: health; Owner: hris_admin
--

ALTER SEQUENCE health.medical_records_id_seq OWNED BY health.medical_records.id;


--
-- Name: pe_results; Type: TABLE; Schema: health; Owner: hris_admin
--

CREATE TABLE health.pe_results (
    id bigint NOT NULL,
    schedule_id bigint NOT NULL,
    employee_id bigint NOT NULL,
    exam_date date,
    overall_result character varying(30) DEFAULT 'PENDING'::character varying NOT NULL,
    findings text,
    recommendations text,
    follow_up_required boolean DEFAULT false NOT NULL,
    follow_up_date date,
    examining_physician character varying(200),
    result_document_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT pe_results_overall_result_check CHECK (((overall_result)::text = ANY ((ARRAY['PENDING'::character varying, 'FIT'::character varying, 'UNFIT'::character varying, 'CONDITIONAL'::character varying, 'NO_SHOW'::character varying])::text[])))
);


ALTER TABLE health.pe_results OWNER TO hris_admin;

--
-- Name: pe_results_id_seq; Type: SEQUENCE; Schema: health; Owner: hris_admin
--

CREATE SEQUENCE health.pe_results_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE health.pe_results_id_seq OWNER TO hris_admin;

--
-- Name: pe_results_id_seq; Type: SEQUENCE OWNED BY; Schema: health; Owner: hris_admin
--

ALTER SEQUENCE health.pe_results_id_seq OWNED BY health.pe_results.id;


--
-- Name: pe_schedules; Type: TABLE; Schema: health; Owner: hris_admin
--

CREATE TABLE health.pe_schedules (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    year integer NOT NULL,
    title character varying(200) NOT NULL,
    provider_name character varying(200),
    scheduled_from date NOT NULL,
    scheduled_to date NOT NULL,
    venue character varying(200),
    status character varying(20) DEFAULT 'SCHEDULED'::character varying NOT NULL,
    created_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT pe_schedules_status_check CHECK (((status)::text = ANY ((ARRAY['SCHEDULED'::character varying, 'IN_PROGRESS'::character varying, 'COMPLETED'::character varying, 'CANCELLED'::character varying])::text[])))
);


ALTER TABLE health.pe_schedules OWNER TO hris_admin;

--
-- Name: pe_schedules_id_seq; Type: SEQUENCE; Schema: health; Owner: hris_admin
--

CREATE SEQUENCE health.pe_schedules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE health.pe_schedules_id_seq OWNER TO hris_admin;

--
-- Name: pe_schedules_id_seq; Type: SEQUENCE OWNED BY; Schema: health; Owner: hris_admin
--

ALTER SEQUENCE health.pe_schedules_id_seq OWNED BY health.pe_schedules.id;


--
-- Name: v_expiring_certificates; Type: VIEW; Schema: health; Owner: hris_admin
--

CREATE VIEW health.v_expiring_certificates AS
 SELECT hc.id,
    hc.employee_id,
    (((e.first_name)::text || ' '::text) || (e.last_name)::text) AS employee_name,
    d.name AS department_name,
    hc.certificate_type,
    hc.expiry_date,
    (hc.expiry_date - CURRENT_DATE) AS days_until_expiry
   FROM ((health.health_certificates hc
     JOIN core.employees e ON ((e.id = hc.employee_id)))
     LEFT JOIN core.departments d ON ((d.id = e.department_id)))
  WHERE (((hc.status)::text = 'ACTIVE'::text) AND ((hc.expiry_date >= CURRENT_DATE) AND (hc.expiry_date <= (CURRENT_DATE + 60))));


ALTER TABLE health.v_expiring_certificates OWNER TO hris_admin;

--
-- Name: v_incident_summary; Type: VIEW; Schema: health; Owner: hris_admin
--

CREATE VIEW health.v_incident_summary AS
 SELECT i.company_id,
    EXTRACT(year FROM i.incident_date) AS year,
    EXTRACT(month FROM i.incident_date) AS month,
    i.incident_type,
    i.severity,
    count(*) AS incident_count,
    sum(ip.days_lost) AS total_days_lost
   FROM (health.incidents i
     LEFT JOIN health.incident_persons ip ON ((ip.incident_id = i.id)))
  GROUP BY i.company_id, (EXTRACT(year FROM i.incident_date)), (EXTRACT(month FROM i.incident_date)), i.incident_type, i.severity;


ALTER TABLE health.v_incident_summary OWNER TO hris_admin;

--
-- Name: v_pe_compliance; Type: VIEW; Schema: health; Owner: hris_admin
--

CREATE VIEW health.v_pe_compliance AS
 SELECT ps.id AS schedule_id,
    ps.year,
    ps.title,
    d.id AS department_id,
    d.name AS department_name,
    count(e.id) AS total_employees,
    count(pr.id) FILTER (WHERE (((pr.overall_result)::text <> 'PENDING'::text) AND ((pr.overall_result)::text <> 'NO_SHOW'::text))) AS examined_count,
    count(pr.id) FILTER (WHERE ((pr.overall_result)::text = 'NO_SHOW'::text)) AS no_show_count,
        CASE
            WHEN (count(e.id) > 0) THEN round((((count(pr.id) FILTER (WHERE ((pr.overall_result)::text <> ALL ((ARRAY['PENDING'::character varying, 'NO_SHOW'::character varying])::text[]))))::numeric / (count(e.id))::numeric) * (100)::numeric), 0)
            ELSE (0)::numeric
        END AS compliance_pct
   FROM (((health.pe_schedules ps
     CROSS JOIN core.departments d)
     JOIN core.employees e ON (((e.department_id = d.id) AND (e.is_active = true) AND (e.company_id = ps.company_id))))
     LEFT JOIN health.pe_results pr ON (((pr.schedule_id = ps.id) AND (pr.employee_id = e.id))))
  GROUP BY ps.id, ps.year, ps.title, d.id, d.name;


ALTER TABLE health.v_pe_compliance OWNER TO hris_admin;

--
-- Name: wellness_enrollments; Type: TABLE; Schema: health; Owner: hris_admin
--

CREATE TABLE health.wellness_enrollments (
    id bigint NOT NULL,
    program_id bigint NOT NULL,
    employee_id bigint NOT NULL,
    enrolled_at timestamp with time zone DEFAULT now() NOT NULL,
    status character varying(20) DEFAULT 'ENROLLED'::character varying NOT NULL,
    completed_at timestamp with time zone,
    feedback text,
    CONSTRAINT wellness_enrollments_status_check CHECK (((status)::text = ANY ((ARRAY['ENROLLED'::character varying, 'COMPLETED'::character varying, 'WITHDRAWN'::character varying, 'NO_SHOW'::character varying])::text[])))
);


ALTER TABLE health.wellness_enrollments OWNER TO hris_admin;

--
-- Name: wellness_enrollments_id_seq; Type: SEQUENCE; Schema: health; Owner: hris_admin
--

CREATE SEQUENCE health.wellness_enrollments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE health.wellness_enrollments_id_seq OWNER TO hris_admin;

--
-- Name: wellness_enrollments_id_seq; Type: SEQUENCE OWNED BY; Schema: health; Owner: hris_admin
--

ALTER SEQUENCE health.wellness_enrollments_id_seq OWNED BY health.wellness_enrollments.id;


--
-- Name: wellness_programs; Type: TABLE; Schema: health; Owner: hris_admin
--

CREATE TABLE health.wellness_programs (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    name character varying(200) NOT NULL,
    description text,
    program_type character varying(40) NOT NULL,
    start_date date,
    end_date date,
    provider character varying(200),
    max_participants integer,
    status character varying(20) DEFAULT 'PLANNED'::character varying NOT NULL,
    created_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT wellness_programs_program_type_check CHECK (((program_type)::text = ANY ((ARRAY['MENTAL_HEALTH'::character varying, 'FITNESS'::character varying, 'NUTRITION'::character varying, 'VACCINATION'::character varying, 'SCREENING'::character varying, 'SEMINAR'::character varying])::text[]))),
    CONSTRAINT wellness_programs_status_check CHECK (((status)::text = ANY ((ARRAY['PLANNED'::character varying, 'ACTIVE'::character varying, 'COMPLETED'::character varying, 'CANCELLED'::character varying])::text[])))
);


ALTER TABLE health.wellness_programs OWNER TO hris_admin;

--
-- Name: wellness_programs_id_seq; Type: SEQUENCE; Schema: health; Owner: hris_admin
--

CREATE SEQUENCE health.wellness_programs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE health.wellness_programs_id_seq OWNER TO hris_admin;

--
-- Name: wellness_programs_id_seq; Type: SEQUENCE OWNED BY; Schema: health; Owner: hris_admin
--

ALTER SEQUENCE health.wellness_programs_id_seq OWNED BY health.wellness_programs.id;


--
-- Name: lrn_attendance_logs; Type: TABLE; Schema: learning; Owner: hris_admin
--

CREATE TABLE learning.lrn_attendance_logs (
    id bigint NOT NULL,
    enrollment_id bigint NOT NULL,
    employee_id bigint NOT NULL,
    session_id bigint NOT NULL,
    checked_in_at timestamp with time zone DEFAULT now() NOT NULL,
    checkin_lat numeric(10,7),
    checkin_lng numeric(10,7),
    checkin_accuracy_m numeric(6,2),
    device_id character varying(100),
    ip_address inet,
    photo_path character varying(500),
    is_valid boolean DEFAULT true NOT NULL,
    invalidated_reason text,
    verified_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE learning.lrn_attendance_logs OWNER TO hris_admin;

--
-- Name: lrn_attendance_logs_id_seq; Type: SEQUENCE; Schema: learning; Owner: hris_admin
--

CREATE SEQUENCE learning.lrn_attendance_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE learning.lrn_attendance_logs_id_seq OWNER TO hris_admin;

--
-- Name: lrn_attendance_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: learning; Owner: hris_admin
--

ALTER SEQUENCE learning.lrn_attendance_logs_id_seq OWNED BY learning.lrn_attendance_logs.id;


--
-- Name: lrn_employee_skills; Type: TABLE; Schema: learning; Owner: hris_admin
--

CREATE TABLE learning.lrn_employee_skills (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    skill_id bigint NOT NULL,
    proficiency character varying(20) DEFAULT 'BEGINNER'::character varying NOT NULL,
    assessed_on date,
    assessed_by bigint
);


ALTER TABLE learning.lrn_employee_skills OWNER TO hris_admin;

--
-- Name: lrn_employee_skills_id_seq; Type: SEQUENCE; Schema: learning; Owner: hris_admin
--

CREATE SEQUENCE learning.lrn_employee_skills_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE learning.lrn_employee_skills_id_seq OWNER TO hris_admin;

--
-- Name: lrn_employee_skills_id_seq; Type: SEQUENCE OWNED BY; Schema: learning; Owner: hris_admin
--

ALTER SEQUENCE learning.lrn_employee_skills_id_seq OWNED BY learning.lrn_employee_skills.id;


--
-- Name: lrn_enrollments; Type: TABLE; Schema: learning; Owner: hris_admin
--

CREATE TABLE learning.lrn_enrollments (
    id bigint NOT NULL,
    session_id bigint NOT NULL,
    employee_id bigint NOT NULL,
    status character varying(20) DEFAULT 'ENROLLED'::character varying NOT NULL,
    completion_date date,
    score numeric(5,2),
    passed boolean,
    certificate_path text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    attendance_pct numeric(5,2),
    narrative_report_id bigint
);


ALTER TABLE learning.lrn_enrollments OWNER TO hris_admin;

--
-- Name: lrn_enrollments_id_seq; Type: SEQUENCE; Schema: learning; Owner: hris_admin
--

CREATE SEQUENCE learning.lrn_enrollments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE learning.lrn_enrollments_id_seq OWNER TO hris_admin;

--
-- Name: lrn_enrollments_id_seq; Type: SEQUENCE OWNED BY; Schema: learning; Owner: hris_admin
--

ALTER SEQUENCE learning.lrn_enrollments_id_seq OWNED BY learning.lrn_enrollments.id;


--
-- Name: lrn_idp_actions; Type: TABLE; Schema: learning; Owner: hris_admin
--

CREATE TABLE learning.lrn_idp_actions (
    id bigint NOT NULL,
    idp_plan_id bigint,
    tna_entry_id bigint,
    action_type character varying(20) DEFAULT 'TRAINING'::character varying NOT NULL,
    target_completion_date date,
    actual_completion_date date,
    session_id bigint,
    outcome text,
    status character varying(20) DEFAULT 'PLANNED'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT lrn_idp_actions_action_type_check CHECK (((action_type)::text = ANY ((ARRAY['TRAINING'::character varying, 'COACHING'::character varying, 'ASSIGNMENT'::character varying, 'STUDY_LEAVE'::character varying, 'SCHOLARSHIP'::character varying])::text[]))),
    CONSTRAINT lrn_idp_actions_status_check CHECK (((status)::text = ANY ((ARRAY['PLANNED'::character varying, 'IN_PROGRESS'::character varying, 'COMPLETED'::character varying, 'CANCELLED'::character varying])::text[])))
);


ALTER TABLE learning.lrn_idp_actions OWNER TO hris_admin;

--
-- Name: lrn_idp_actions_id_seq; Type: SEQUENCE; Schema: learning; Owner: hris_admin
--

CREATE SEQUENCE learning.lrn_idp_actions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE learning.lrn_idp_actions_id_seq OWNER TO hris_admin;

--
-- Name: lrn_idp_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: learning; Owner: hris_admin
--

ALTER SEQUENCE learning.lrn_idp_actions_id_seq OWNED BY learning.lrn_idp_actions.id;


--
-- Name: lrn_lsp_registry; Type: TABLE; Schema: learning; Owner: hris_admin
--

CREATE TABLE learning.lrn_lsp_registry (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    name character varying(200) NOT NULL,
    accreditation_no character varying(60),
    contact_person character varying(200),
    email character varying(200),
    phone character varying(30),
    is_csc_accredited boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE learning.lrn_lsp_registry OWNER TO hris_admin;

--
-- Name: lrn_lsp_registry_id_seq; Type: SEQUENCE; Schema: learning; Owner: hris_admin
--

CREATE SEQUENCE learning.lrn_lsp_registry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE learning.lrn_lsp_registry_id_seq OWNER TO hris_admin;

--
-- Name: lrn_lsp_registry_id_seq; Type: SEQUENCE OWNED BY; Schema: learning; Owner: hris_admin
--

ALTER SEQUENCE learning.lrn_lsp_registry_id_seq OWNED BY learning.lrn_lsp_registry.id;


--
-- Name: lrn_narrative_reports; Type: TABLE; Schema: learning; Owner: hris_admin
--

CREATE TABLE learning.lrn_narrative_reports (
    id bigint NOT NULL,
    enrollment_id bigint NOT NULL,
    employee_id bigint NOT NULL,
    training_title character varying(200),
    training_dates text,
    venue character varying(200),
    facilitator character varying(200),
    learning_objectives text,
    key_learnings text,
    application_plans text,
    challenges text,
    recommendations text,
    evaluation_rating numeric(3,1),
    submitted_at timestamp with time zone,
    approved_by bigint,
    approved_at timestamp with time zone,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT lrn_narrative_reports_status_check CHECK (((status)::text = ANY ((ARRAY['DRAFT'::character varying, 'SUBMITTED'::character varying, 'APPROVED'::character varying, 'RETURNED'::character varying])::text[])))
);


ALTER TABLE learning.lrn_narrative_reports OWNER TO hris_admin;

--
-- Name: lrn_narrative_reports_id_seq; Type: SEQUENCE; Schema: learning; Owner: hris_admin
--

CREATE SEQUENCE learning.lrn_narrative_reports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE learning.lrn_narrative_reports_id_seq OWNER TO hris_admin;

--
-- Name: lrn_narrative_reports_id_seq; Type: SEQUENCE OWNED BY; Schema: learning; Owner: hris_admin
--

ALTER SEQUENCE learning.lrn_narrative_reports_id_seq OWNED BY learning.lrn_narrative_reports.id;


--
-- Name: lrn_programs; Type: TABLE; Schema: learning; Owner: hris_admin
--

CREATE TABLE learning.lrn_programs (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    code character varying(30) NOT NULL,
    title character varying(200) NOT NULL,
    description text,
    category character varying(50),
    delivery_mode character varying(30) DEFAULT 'IN_PERSON'::character varying NOT NULL,
    duration_hours numeric(6,2),
    provider character varying(200),
    cost numeric(12,2),
    is_mandatory boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    lsp_id bigint,
    tna_basis character varying(100),
    csc_accredited boolean DEFAULT false NOT NULL
);


ALTER TABLE learning.lrn_programs OWNER TO hris_admin;

--
-- Name: lrn_programs_id_seq; Type: SEQUENCE; Schema: learning; Owner: hris_admin
--

CREATE SEQUENCE learning.lrn_programs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE learning.lrn_programs_id_seq OWNER TO hris_admin;

--
-- Name: lrn_programs_id_seq; Type: SEQUENCE OWNED BY; Schema: learning; Owner: hris_admin
--

ALTER SEQUENCE learning.lrn_programs_id_seq OWNED BY learning.lrn_programs.id;


--
-- Name: lrn_scholarships; Type: TABLE; Schema: learning; Owner: hris_admin
--

CREATE TABLE learning.lrn_scholarships (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    program_name character varying(200) NOT NULL,
    grant_type character varying(20) DEFAULT 'LOCAL'::character varying NOT NULL,
    institution character varying(200),
    course character varying(200),
    start_date date,
    end_date date,
    coverage_details text,
    bond_required_months integer,
    return_of_service_date date,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    approved_by bigint,
    document_path character varying(500),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT lrn_scholarships_grant_type_check CHECK (((grant_type)::text = ANY ((ARRAY['LOCAL'::character varying, 'FOREIGN'::character varying, 'PRIVATE'::character varying, 'CSC_SPONSORED'::character varying])::text[]))),
    CONSTRAINT lrn_scholarships_status_check CHECK (((status)::text = ANY ((ARRAY['ACTIVE'::character varying, 'COMPLETED'::character varying, 'CANCELLED'::character varying, 'ON_BOND'::character varying])::text[])))
);


ALTER TABLE learning.lrn_scholarships OWNER TO hris_admin;

--
-- Name: lrn_scholarships_id_seq; Type: SEQUENCE; Schema: learning; Owner: hris_admin
--

CREATE SEQUENCE learning.lrn_scholarships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE learning.lrn_scholarships_id_seq OWNER TO hris_admin;

--
-- Name: lrn_scholarships_id_seq; Type: SEQUENCE OWNED BY; Schema: learning; Owner: hris_admin
--

ALTER SEQUENCE learning.lrn_scholarships_id_seq OWNED BY learning.lrn_scholarships.id;


--
-- Name: lrn_sessions; Type: TABLE; Schema: learning; Owner: hris_admin
--

CREATE TABLE learning.lrn_sessions (
    id bigint NOT NULL,
    program_id bigint NOT NULL,
    session_date date NOT NULL,
    session_end date,
    venue character varying(300),
    facilitator character varying(200),
    max_participants integer,
    status character varying(20) DEFAULT 'SCHEDULED'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE learning.lrn_sessions OWNER TO hris_admin;

--
-- Name: lrn_sessions_id_seq; Type: SEQUENCE; Schema: learning; Owner: hris_admin
--

CREATE SEQUENCE learning.lrn_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE learning.lrn_sessions_id_seq OWNER TO hris_admin;

--
-- Name: lrn_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: learning; Owner: hris_admin
--

ALTER SEQUENCE learning.lrn_sessions_id_seq OWNED BY learning.lrn_sessions.id;


--
-- Name: lrn_skills; Type: TABLE; Schema: learning; Owner: hris_admin
--

CREATE TABLE learning.lrn_skills (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    code character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
    category character varying(50),
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE learning.lrn_skills OWNER TO hris_admin;

--
-- Name: lrn_skills_id_seq; Type: SEQUENCE; Schema: learning; Owner: hris_admin
--

CREATE SEQUENCE learning.lrn_skills_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE learning.lrn_skills_id_seq OWNER TO hris_admin;

--
-- Name: lrn_skills_id_seq; Type: SEQUENCE OWNED BY; Schema: learning; Owner: hris_admin
--

ALTER SEQUENCE learning.lrn_skills_id_seq OWNED BY learning.lrn_skills.id;


--
-- Name: lrn_tna_entries; Type: TABLE; Schema: learning; Owner: hris_admin
--

CREATE TABLE learning.lrn_tna_entries (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    cycle_id bigint,
    competency_gap text NOT NULL,
    recommended_training text,
    priority character varying(10) DEFAULT 'MEDIUM'::character varying NOT NULL,
    source character varying(20) DEFAULT 'IPCR'::character varying NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT lrn_tna_entries_priority_check CHECK (((priority)::text = ANY ((ARRAY['HIGH'::character varying, 'MEDIUM'::character varying, 'LOW'::character varying])::text[]))),
    CONSTRAINT lrn_tna_entries_source_check CHECK (((source)::text = ANY ((ARRAY['IPCR'::character varying, 'SUPERVISOR'::character varying, 'SELF'::character varying, 'HR_AUDIT'::character varying])::text[]))),
    CONSTRAINT lrn_tna_entries_status_check CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'ENROLLED'::character varying, 'COMPLETED'::character varying, 'DEFERRED'::character varying])::text[])))
);


ALTER TABLE learning.lrn_tna_entries OWNER TO hris_admin;

--
-- Name: lrn_tna_entries_id_seq; Type: SEQUENCE; Schema: learning; Owner: hris_admin
--

CREATE SEQUENCE learning.lrn_tna_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE learning.lrn_tna_entries_id_seq OWNER TO hris_admin;

--
-- Name: lrn_tna_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: learning; Owner: hris_admin
--

ALTER SEQUENCE learning.lrn_tna_entries_id_seq OWNED BY learning.lrn_tna_entries.id;


--
-- Name: lv_approvals; Type: TABLE; Schema: leave_mgmt; Owner: hris_admin
--

CREATE TABLE leave_mgmt.lv_approvals (
    id bigint NOT NULL,
    request_id bigint NOT NULL,
    approval_level integer DEFAULT 1 NOT NULL,
    approver_id bigint NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    remarks text,
    acted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE leave_mgmt.lv_approvals OWNER TO hris_admin;

--
-- Name: lv_approvals_id_seq; Type: SEQUENCE; Schema: leave_mgmt; Owner: hris_admin
--

CREATE SEQUENCE leave_mgmt.lv_approvals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE leave_mgmt.lv_approvals_id_seq OWNER TO hris_admin;

--
-- Name: lv_approvals_id_seq; Type: SEQUENCE OWNED BY; Schema: leave_mgmt; Owner: hris_admin
--

ALTER SEQUENCE leave_mgmt.lv_approvals_id_seq OWNED BY leave_mgmt.lv_approvals.id;


--
-- Name: lv_balance_adjustments; Type: TABLE; Schema: leave_mgmt; Owner: hris_admin
--

CREATE TABLE leave_mgmt.lv_balance_adjustments (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    leave_type_id bigint NOT NULL,
    year smallint NOT NULL,
    adjustment_days numeric(5,2) NOT NULL,
    reason character varying(300) NOT NULL,
    adjusted_by bigint NOT NULL,
    adjusted_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE leave_mgmt.lv_balance_adjustments OWNER TO hris_admin;

--
-- Name: TABLE lv_balance_adjustments; Type: COMMENT; Schema: leave_mgmt; Owner: hris_admin
--

COMMENT ON TABLE leave_mgmt.lv_balance_adjustments IS 'Manual credit/debit adjustments to leave balances with full audit trail.';


--
-- Name: lv_balance_adjustments_id_seq; Type: SEQUENCE; Schema: leave_mgmt; Owner: hris_admin
--

CREATE SEQUENCE leave_mgmt.lv_balance_adjustments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE leave_mgmt.lv_balance_adjustments_id_seq OWNER TO hris_admin;

--
-- Name: lv_balance_adjustments_id_seq; Type: SEQUENCE OWNED BY; Schema: leave_mgmt; Owner: hris_admin
--

ALTER SEQUENCE leave_mgmt.lv_balance_adjustments_id_seq OWNED BY leave_mgmt.lv_balance_adjustments.id;


--
-- Name: lv_balances; Type: TABLE; Schema: leave_mgmt; Owner: hris_admin
--

CREATE TABLE leave_mgmt.lv_balances (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    leave_type_id bigint NOT NULL,
    year integer NOT NULL,
    entitled_days numeric(5,1) DEFAULT 0 NOT NULL,
    accrued_days numeric(5,1) DEFAULT 0 NOT NULL,
    used_days numeric(5,1) DEFAULT 0 NOT NULL,
    pending_days numeric(5,1) DEFAULT 0 NOT NULL,
    carried_over numeric(5,1) DEFAULT 0 NOT NULL,
    forfeited_days numeric(5,1) DEFAULT 0 NOT NULL,
    balance numeric(5,1) GENERATED ALWAYS AS ((((accrued_days + carried_over) - used_days) - pending_days)) STORED,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE leave_mgmt.lv_balances OWNER TO hris_admin;

--
-- Name: lv_balances_id_seq; Type: SEQUENCE; Schema: leave_mgmt; Owner: hris_admin
--

CREATE SEQUENCE leave_mgmt.lv_balances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE leave_mgmt.lv_balances_id_seq OWNER TO hris_admin;

--
-- Name: lv_balances_id_seq; Type: SEQUENCE OWNED BY; Schema: leave_mgmt; Owner: hris_admin
--

ALTER SEQUENCE leave_mgmt.lv_balances_id_seq OWNED BY leave_mgmt.lv_balances.id;


--
-- Name: lv_cto_credits; Type: TABLE; Schema: leave_mgmt; Owner: hris_admin
--

CREATE TABLE leave_mgmt.lv_cto_credits (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    credit_type character varying(30) DEFAULT 'EARNED'::character varying NOT NULL,
    reference_date date NOT NULL,
    hours_credit numeric(5,2) DEFAULT 0 NOT NULL,
    reason text,
    approved_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE leave_mgmt.lv_cto_credits OWNER TO hris_admin;

--
-- Name: lv_cto_credits_id_seq; Type: SEQUENCE; Schema: leave_mgmt; Owner: hris_admin
--

CREATE SEQUENCE leave_mgmt.lv_cto_credits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE leave_mgmt.lv_cto_credits_id_seq OWNER TO hris_admin;

--
-- Name: lv_cto_credits_id_seq; Type: SEQUENCE OWNED BY; Schema: leave_mgmt; Owner: hris_admin
--

ALTER SEQUENCE leave_mgmt.lv_cto_credits_id_seq OWNED BY leave_mgmt.lv_cto_credits.id;


--
-- Name: lv_holidays; Type: TABLE; Schema: leave_mgmt; Owner: hris_admin
--

CREATE TABLE leave_mgmt.lv_holidays (
    id bigint NOT NULL,
    company_id bigint,
    hdate date NOT NULL,
    name character varying(100) NOT NULL,
    htype character varying(30) DEFAULT 'REGULAR'::character varying NOT NULL,
    is_recurring boolean DEFAULT false NOT NULL,
    month_day character varying(6)
);


ALTER TABLE leave_mgmt.lv_holidays OWNER TO hris_admin;

--
-- Name: lv_holidays_id_seq; Type: SEQUENCE; Schema: leave_mgmt; Owner: hris_admin
--

CREATE SEQUENCE leave_mgmt.lv_holidays_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE leave_mgmt.lv_holidays_id_seq OWNER TO hris_admin;

--
-- Name: lv_holidays_id_seq; Type: SEQUENCE OWNED BY; Schema: leave_mgmt; Owner: hris_admin
--

ALTER SEQUENCE leave_mgmt.lv_holidays_id_seq OWNED BY leave_mgmt.lv_holidays.id;


--
-- Name: lv_ledger; Type: TABLE; Schema: leave_mgmt; Owner: hris_admin
--

CREATE TABLE leave_mgmt.lv_ledger (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    leave_type_id bigint NOT NULL,
    year integer NOT NULL,
    transaction_type character varying(30) NOT NULL,
    days numeric(5,1) NOT NULL,
    reference_id bigint,
    reference_type character varying(30),
    remarks text,
    created_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE leave_mgmt.lv_ledger OWNER TO hris_admin;

--
-- Name: lv_ledger_id_seq; Type: SEQUENCE; Schema: leave_mgmt; Owner: hris_admin
--

CREATE SEQUENCE leave_mgmt.lv_ledger_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE leave_mgmt.lv_ledger_id_seq OWNER TO hris_admin;

--
-- Name: lv_ledger_id_seq; Type: SEQUENCE OWNED BY; Schema: leave_mgmt; Owner: hris_admin
--

ALTER SEQUENCE leave_mgmt.lv_ledger_id_seq OWNED BY leave_mgmt.lv_ledger.id;


--
-- Name: lv_locator_entries; Type: TABLE; Schema: leave_mgmt; Owner: hris_admin
--

CREATE TABLE leave_mgmt.lv_locator_entries (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    log_date date DEFAULT CURRENT_DATE NOT NULL,
    location_type character varying(30) DEFAULT 'IN_OFFICE'::character varying NOT NULL,
    departure_time time without time zone,
    return_time time without time zone,
    destination character varying(300),
    purpose text,
    contact_no character varying(30),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE leave_mgmt.lv_locator_entries OWNER TO hris_admin;

--
-- Name: lv_locator_entries_id_seq; Type: SEQUENCE; Schema: leave_mgmt; Owner: hris_admin
--

CREATE SEQUENCE leave_mgmt.lv_locator_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE leave_mgmt.lv_locator_entries_id_seq OWNER TO hris_admin;

--
-- Name: lv_locator_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: leave_mgmt; Owner: hris_admin
--

ALTER SEQUENCE leave_mgmt.lv_locator_entries_id_seq OWNED BY leave_mgmt.lv_locator_entries.id;


--
-- Name: lv_policies; Type: TABLE; Schema: leave_mgmt; Owner: hris_admin
--

CREATE TABLE leave_mgmt.lv_policies (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    leave_type_id bigint NOT NULL,
    employment_type_id bigint,
    annual_days numeric(5,1) NOT NULL,
    accrual_type character varying(20) DEFAULT 'ANNUAL'::character varying NOT NULL,
    carry_over_allowed boolean DEFAULT false NOT NULL,
    carry_over_max_days numeric(5,1) DEFAULT 0 NOT NULL,
    monetization_allowed boolean DEFAULT false NOT NULL,
    months_before_entitled integer DEFAULT 0 NOT NULL,
    effective_from date,
    effective_to date,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE leave_mgmt.lv_policies OWNER TO hris_admin;

--
-- Name: lv_policies_id_seq; Type: SEQUENCE; Schema: leave_mgmt; Owner: hris_admin
--

CREATE SEQUENCE leave_mgmt.lv_policies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE leave_mgmt.lv_policies_id_seq OWNER TO hris_admin;

--
-- Name: lv_policies_id_seq; Type: SEQUENCE OWNED BY; Schema: leave_mgmt; Owner: hris_admin
--

ALTER SEQUENCE leave_mgmt.lv_policies_id_seq OWNED BY leave_mgmt.lv_policies.id;


--
-- Name: lv_requests_id_seq; Type: SEQUENCE; Schema: leave_mgmt; Owner: hris_admin
--

CREATE SEQUENCE leave_mgmt.lv_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE leave_mgmt.lv_requests_id_seq OWNER TO hris_admin;

--
-- Name: lv_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: leave_mgmt; Owner: hris_admin
--

ALTER SEQUENCE leave_mgmt.lv_requests_id_seq OWNED BY leave_mgmt.lv_requests.id;


--
-- Name: lv_travel_orders; Type: TABLE; Schema: leave_mgmt; Owner: hris_admin
--

CREATE TABLE leave_mgmt.lv_travel_orders (
    id bigint NOT NULL,
    reference_no character varying(40) NOT NULL,
    employee_id bigint NOT NULL,
    destination character varying(300) NOT NULL,
    purpose text NOT NULL,
    date_from date NOT NULL,
    date_to date NOT NULL,
    transport_mode character varying(50),
    estimated_expense numeric(12,2),
    workflow_instance_id bigint,
    status character varying(30) DEFAULT 'DRAFT'::character varying NOT NULL,
    approved_by bigint,
    approved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE leave_mgmt.lv_travel_orders OWNER TO hris_admin;

--
-- Name: lv_travel_orders_id_seq; Type: SEQUENCE; Schema: leave_mgmt; Owner: hris_admin
--

CREATE SEQUENCE leave_mgmt.lv_travel_orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE leave_mgmt.lv_travel_orders_id_seq OWNER TO hris_admin;

--
-- Name: lv_travel_orders_id_seq; Type: SEQUENCE OWNED BY; Schema: leave_mgmt; Owner: hris_admin
--

ALTER SEQUENCE leave_mgmt.lv_travel_orders_id_seq OWNED BY leave_mgmt.lv_travel_orders.id;


--
-- Name: lv_types_id_seq; Type: SEQUENCE; Schema: leave_mgmt; Owner: hris_admin
--

CREATE SEQUENCE leave_mgmt.lv_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE leave_mgmt.lv_types_id_seq OWNER TO hris_admin;

--
-- Name: lv_types_id_seq; Type: SEQUENCE OWNED BY; Schema: leave_mgmt; Owner: hris_admin
--

ALTER SEQUENCE leave_mgmt.lv_types_id_seq OWNED BY leave_mgmt.lv_types.id;


--
-- Name: v_leave_balance_matrix; Type: VIEW; Schema: leave_mgmt; Owner: hris_admin
--

CREATE VIEW leave_mgmt.v_leave_balance_matrix AS
 SELECT lb.employee_id,
    lb.year,
    (((e.last_name)::text || ', '::text) || (e.first_name)::text) AS full_name,
    e.employee_no,
    d.name AS department,
    lt.code AS leave_type_code,
    lt.name AS leave_type_name,
    lb.entitled_days,
    lb.accrued_days,
    lb.used_days,
    lb.pending_days,
    lb.carried_over,
    lb.balance
   FROM (((leave_mgmt.lv_balances lb
     JOIN core.employees e ON ((e.id = lb.employee_id)))
     LEFT JOIN core.departments d ON ((d.id = e.department_id)))
     JOIN leave_mgmt.lv_types lt ON ((lt.id = lb.leave_type_id)));


ALTER TABLE leave_mgmt.v_leave_balance_matrix OWNER TO hris_admin;

--
-- Name: v_leave_requests_full; Type: VIEW; Schema: leave_mgmt; Owner: hris_admin
--

CREATE VIEW leave_mgmt.v_leave_requests_full AS
 SELECT lr.id,
    lr.reference_no,
    (((e.last_name)::text || ', '::text) || (e.first_name)::text) AS employee_name,
    e.employee_no,
    d.name AS department,
    lt.name AS leave_type,
    lt.code AS leave_type_code,
    lt.color,
    lr.date_from,
    lr.date_to,
    lr.days_requested,
    lr.reason,
    lr.status,
    lr.is_half_day,
    lr.filed_at,
    lr.workflow_instance_id,
    lr.employee_id
   FROM (((leave_mgmt.lv_requests lr
     JOIN core.employees e ON ((e.id = lr.employee_id)))
     LEFT JOIN core.departments d ON ((d.id = e.department_id)))
     JOIN leave_mgmt.lv_types lt ON ((lt.id = lr.leave_type_id)));


ALTER TABLE leave_mgmt.v_leave_requests_full OWNER TO hris_admin;

--
-- Name: v_locator_today; Type: VIEW; Schema: leave_mgmt; Owner: hris_admin
--

CREATE VIEW leave_mgmt.v_locator_today AS
 SELECT e.id AS employee_id,
    e.employee_no,
    (((e.last_name)::text || ', '::text) || (e.first_name)::text) AS full_name,
    d.name AS department,
    COALESCE(loc.location_type, 'UNKNOWN'::character varying) AS location_type,
    loc.destination,
    loc.purpose,
    loc.contact_no,
    loc.departure_time,
    loc.return_time
   FROM ((core.employees e
     LEFT JOIN core.departments d ON ((d.id = e.department_id)))
     LEFT JOIN leave_mgmt.lv_locator_entries loc ON (((loc.employee_id = e.id) AND (loc.log_date = CURRENT_DATE))))
  WHERE ((e.is_active = true) AND ((e.status)::text <> ALL ((ARRAY['RESIGNED'::character varying, 'TERMINATED'::character varying, 'RETIRED'::character varying, 'DECEASED'::character varying])::text[])));


ALTER TABLE leave_mgmt.v_locator_today OWNER TO hris_admin;

--
-- Name: ntf_channels; Type: TABLE; Schema: notifications; Owner: hris_admin
--

CREATE TABLE notifications.ntf_channels (
    id bigint NOT NULL,
    code character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
    config jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE notifications.ntf_channels OWNER TO hris_admin;

--
-- Name: ntf_channels_id_seq; Type: SEQUENCE; Schema: notifications; Owner: hris_admin
--

CREATE SEQUENCE notifications.ntf_channels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE notifications.ntf_channels_id_seq OWNER TO hris_admin;

--
-- Name: ntf_channels_id_seq; Type: SEQUENCE OWNED BY; Schema: notifications; Owner: hris_admin
--

ALTER SEQUENCE notifications.ntf_channels_id_seq OWNED BY notifications.ntf_channels.id;


--
-- Name: ntf_in_app; Type: TABLE; Schema: notifications; Owner: hris_admin
--

CREATE TABLE notifications.ntf_in_app (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    title character varying(200) NOT NULL,
    body text NOT NULL,
    action_url character varying(500),
    is_read boolean DEFAULT false NOT NULL,
    read_at timestamp with time zone,
    module character varying(50),
    entity_type character varying(60),
    entity_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE notifications.ntf_in_app OWNER TO hris_admin;

--
-- Name: ntf_in_app_id_seq; Type: SEQUENCE; Schema: notifications; Owner: hris_admin
--

CREATE SEQUENCE notifications.ntf_in_app_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE notifications.ntf_in_app_id_seq OWNER TO hris_admin;

--
-- Name: ntf_in_app_id_seq; Type: SEQUENCE OWNED BY; Schema: notifications; Owner: hris_admin
--

ALTER SEQUENCE notifications.ntf_in_app_id_seq OWNED BY notifications.ntf_in_app.id;


--
-- Name: ntf_queue; Type: TABLE; Schema: notifications; Owner: hris_admin
--

CREATE TABLE notifications.ntf_queue (
    id bigint NOT NULL,
    template_id bigint,
    recipient_user_id bigint,
    recipient_email character varying(200),
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    priority integer DEFAULT 5 NOT NULL,
    scheduled_at timestamp with time zone DEFAULT now() NOT NULL,
    sent_at timestamp with time zone,
    error_msg text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE notifications.ntf_queue OWNER TO hris_admin;

--
-- Name: ntf_queue_id_seq; Type: SEQUENCE; Schema: notifications; Owner: hris_admin
--

CREATE SEQUENCE notifications.ntf_queue_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE notifications.ntf_queue_id_seq OWNER TO hris_admin;

--
-- Name: ntf_queue_id_seq; Type: SEQUENCE OWNED BY; Schema: notifications; Owner: hris_admin
--

ALTER SEQUENCE notifications.ntf_queue_id_seq OWNED BY notifications.ntf_queue.id;


--
-- Name: ntf_templates; Type: TABLE; Schema: notifications; Owner: hris_admin
--

CREATE TABLE notifications.ntf_templates (
    id bigint NOT NULL,
    template_code character varying(60) NOT NULL,
    module character varying(50) NOT NULL,
    event_type character varying(100) NOT NULL,
    channel_id bigint NOT NULL,
    subject_template text,
    body_template text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE notifications.ntf_templates OWNER TO hris_admin;

--
-- Name: ntf_templates_id_seq; Type: SEQUENCE; Schema: notifications; Owner: hris_admin
--

CREATE SEQUENCE notifications.ntf_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE notifications.ntf_templates_id_seq OWNER TO hris_admin;

--
-- Name: ntf_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: notifications; Owner: hris_admin
--

ALTER SEQUENCE notifications.ntf_templates_id_seq OWNED BY notifications.ntf_templates.id;


--
-- Name: reminder_rules; Type: TABLE; Schema: notifications; Owner: hris_admin
--

CREATE TABLE notifications.reminder_rules (
    id bigint NOT NULL,
    code character varying(50) NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    rule_type character varying(50) DEFAULT 'SCHEDULED'::character varying NOT NULL,
    source_query text,
    task_type character varying(50),
    priority character varying(20) DEFAULT 'NORMAL'::character varying,
    action_url_template character varying(255),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE notifications.reminder_rules OWNER TO hris_admin;

--
-- Name: reminder_rules_id_seq; Type: SEQUENCE; Schema: notifications; Owner: hris_admin
--

CREATE SEQUENCE notifications.reminder_rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE notifications.reminder_rules_id_seq OWNER TO hris_admin;

--
-- Name: reminder_rules_id_seq; Type: SEQUENCE OWNED BY; Schema: notifications; Owner: hris_admin
--

ALTER SEQUENCE notifications.reminder_rules_id_seq OWNED BY notifications.reminder_rules.id;


--
-- Name: offb_clearance_items; Type: TABLE; Schema: onboarding; Owner: hris_admin
--

CREATE TABLE onboarding.offb_clearance_items (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    clearance_type character varying(30) NOT NULL,
    cleared_by bigint,
    cleared_at timestamp with time zone,
    remarks text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT offb_clearance_items_clearance_type_check CHECK (((clearance_type)::text = ANY ((ARRAY['PROPERTY'::character varying, 'CASH_ADVANCE'::character varying, 'LIBRARY'::character varying, 'IT_EQUIPMENT'::character varying, 'HR_201'::character varying, 'FINANCE'::character varying, 'GSIS'::character varying, 'PAGIBIG'::character varying, 'MEDICAL'::character varying])::text[])))
);


ALTER TABLE onboarding.offb_clearance_items OWNER TO hris_admin;

--
-- Name: offb_clearance_items_id_seq; Type: SEQUENCE; Schema: onboarding; Owner: hris_admin
--

CREATE SEQUENCE onboarding.offb_clearance_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE onboarding.offb_clearance_items_id_seq OWNER TO hris_admin;

--
-- Name: offb_clearance_items_id_seq; Type: SEQUENCE OWNED BY; Schema: onboarding; Owner: hris_admin
--

ALTER SEQUENCE onboarding.offb_clearance_items_id_seq OWNED BY onboarding.offb_clearance_items.id;


--
-- Name: offb_exit_interviews; Type: TABLE; Schema: onboarding; Owner: hris_admin
--

CREATE TABLE onboarding.offb_exit_interviews (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    interview_date date,
    interviewer_id bigint,
    reason_for_leaving text,
    would_return boolean,
    satisfaction_score integer,
    feedback text,
    last_working_day date,
    clearance_completed boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE onboarding.offb_exit_interviews OWNER TO hris_admin;

--
-- Name: offb_exit_interviews_id_seq; Type: SEQUENCE; Schema: onboarding; Owner: hris_admin
--

CREATE SEQUENCE onboarding.offb_exit_interviews_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE onboarding.offb_exit_interviews_id_seq OWNER TO hris_admin;

--
-- Name: offb_exit_interviews_id_seq; Type: SEQUENCE OWNED BY; Schema: onboarding; Owner: hris_admin
--

ALTER SEQUENCE onboarding.offb_exit_interviews_id_seq OWNED BY onboarding.offb_exit_interviews.id;


--
-- Name: onb_buddy_assignments; Type: TABLE; Schema: onboarding; Owner: hris_admin
--

CREATE TABLE onboarding.onb_buddy_assignments (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    buddy_id bigint NOT NULL,
    assigned_from date NOT NULL,
    assigned_to date,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE onboarding.onb_buddy_assignments OWNER TO hris_admin;

--
-- Name: onb_buddy_assignments_id_seq; Type: SEQUENCE; Schema: onboarding; Owner: hris_admin
--

CREATE SEQUENCE onboarding.onb_buddy_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE onboarding.onb_buddy_assignments_id_seq OWNER TO hris_admin;

--
-- Name: onb_buddy_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: onboarding; Owner: hris_admin
--

ALTER SEQUENCE onboarding.onb_buddy_assignments_id_seq OWNED BY onboarding.onb_buddy_assignments.id;


--
-- Name: onb_checklist_items; Type: TABLE; Schema: onboarding; Owner: hris_admin
--

CREATE TABLE onboarding.onb_checklist_items (
    id bigint NOT NULL,
    checklist_id bigint NOT NULL,
    category character varying(50) NOT NULL,
    item_name character varying(200) NOT NULL,
    is_required boolean DEFAULT true NOT NULL,
    is_completed boolean DEFAULT false NOT NULL,
    completed_by bigint,
    completed_at timestamp with time zone,
    notes text,
    sort_order integer DEFAULT 99 NOT NULL
);


ALTER TABLE onboarding.onb_checklist_items OWNER TO hris_admin;

--
-- Name: onb_checklist_items_id_seq; Type: SEQUENCE; Schema: onboarding; Owner: hris_admin
--

CREATE SEQUENCE onboarding.onb_checklist_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE onboarding.onb_checklist_items_id_seq OWNER TO hris_admin;

--
-- Name: onb_checklist_items_id_seq; Type: SEQUENCE OWNED BY; Schema: onboarding; Owner: hris_admin
--

ALTER SEQUENCE onboarding.onb_checklist_items_id_seq OWNED BY onboarding.onb_checklist_items.id;


--
-- Name: onb_checklists; Type: TABLE; Schema: onboarding; Owner: hris_admin
--

CREATE TABLE onboarding.onb_checklists (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    workflow_instance_id bigint,
    type character varying(20) DEFAULT 'ONBOARDING'::character varying NOT NULL,
    status character varying(20) DEFAULT 'IN_PROGRESS'::character varying NOT NULL,
    target_date date,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE onboarding.onb_checklists OWNER TO hris_admin;

--
-- Name: onb_checklists_id_seq; Type: SEQUENCE; Schema: onboarding; Owner: hris_admin
--

CREATE SEQUENCE onboarding.onb_checklists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE onboarding.onb_checklists_id_seq OWNER TO hris_admin;

--
-- Name: onb_checklists_id_seq; Type: SEQUENCE OWNED BY; Schema: onboarding; Owner: hris_admin
--

ALTER SEQUENCE onboarding.onb_checklists_id_seq OWNED BY onboarding.onb_checklists.id;


--
-- Name: onb_pre_employment_reqs; Type: TABLE; Schema: onboarding; Owner: hris_admin
--

CREATE TABLE onboarding.onb_pre_employment_reqs (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    requirement_type character varying(40) NOT NULL,
    submitted_at timestamp with time zone,
    expires_at date,
    document_path character varying(500),
    verified_by bigint,
    verified_at timestamp with time zone,
    remarks text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT onb_pre_employment_reqs_requirement_type_check CHECK (((requirement_type)::text = ANY ((ARRAY['MEDICAL_CERT'::character varying, 'NBI_CLEARANCE'::character varying, 'BIRTH_CERT'::character varying, 'TOR'::character varying, 'PDS_CS9'::character varying, 'OATHS'::character varying, 'PMS_IPCR'::character varying, 'SERVICE_RECORD'::character varying, 'CLEARANCE_PREV_EMPLOYER'::character varying])::text[])))
);


ALTER TABLE onboarding.onb_pre_employment_reqs OWNER TO hris_admin;

--
-- Name: onb_pre_employment_reqs_id_seq; Type: SEQUENCE; Schema: onboarding; Owner: hris_admin
--

CREATE SEQUENCE onboarding.onb_pre_employment_reqs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE onboarding.onb_pre_employment_reqs_id_seq OWNER TO hris_admin;

--
-- Name: onb_pre_employment_reqs_id_seq; Type: SEQUENCE OWNED BY; Schema: onboarding; Owner: hris_admin
--

ALTER SEQUENCE onboarding.onb_pre_employment_reqs_id_seq OWNED BY onboarding.onb_pre_employment_reqs.id;


--
-- Name: pay_13th_month; Type: TABLE; Schema: payroll; Owner: hris_admin
--

CREATE TABLE payroll.pay_13th_month (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    year integer NOT NULL,
    total_basic_pay numeric(14,2) DEFAULT 0 NOT NULL,
    months_worked numeric(4,2) DEFAULT 12 NOT NULL,
    gross_13th numeric(14,2) DEFAULT 0 NOT NULL,
    tax_exempt_amt numeric(14,2) DEFAULT 90000 NOT NULL,
    taxable_amt numeric(14,2) DEFAULT 0 NOT NULL,
    net_13th numeric(14,2) DEFAULT 0 NOT NULL,
    paid_at timestamp with time zone,
    run_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE payroll.pay_13th_month OWNER TO hris_admin;

--
-- Name: pay_13th_month_id_seq; Type: SEQUENCE; Schema: payroll; Owner: hris_admin
--

CREATE SEQUENCE payroll.pay_13th_month_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE payroll.pay_13th_month_id_seq OWNER TO hris_admin;

--
-- Name: pay_13th_month_id_seq; Type: SEQUENCE OWNED BY; Schema: payroll; Owner: hris_admin
--

ALTER SEQUENCE payroll.pay_13th_month_id_seq OWNED BY payroll.pay_13th_month.id;


--
-- Name: pay_adjustments; Type: TABLE; Schema: payroll; Owner: hris_admin
--

CREATE TABLE payroll.pay_adjustments (
    id bigint NOT NULL,
    run_id bigint NOT NULL,
    employee_id bigint NOT NULL,
    adjustment_type character varying(30) NOT NULL,
    description character varying(200) NOT NULL,
    amount numeric(14,2) NOT NULL,
    applied_by bigint NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL,
    remarks text,
    CONSTRAINT pay_adjustments_adjustment_type_check CHECK (((adjustment_type)::text = ANY ((ARRAY['EARNINGS'::character varying, 'DEDUCTION'::character varying, 'ALLOWANCE'::character varying, 'CORRECTION'::character varying])::text[])))
);


ALTER TABLE payroll.pay_adjustments OWNER TO hris_admin;

--
-- Name: TABLE pay_adjustments; Type: COMMENT; Schema: payroll; Owner: hris_admin
--

COMMENT ON TABLE payroll.pay_adjustments IS 'Non-destructive payroll adjustments (earnings/deductions) appended to a run.';


--
-- Name: pay_adjustments_id_seq; Type: SEQUENCE; Schema: payroll; Owner: hris_admin
--

CREATE SEQUENCE payroll.pay_adjustments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE payroll.pay_adjustments_id_seq OWNER TO hris_admin;

--
-- Name: pay_adjustments_id_seq; Type: SEQUENCE OWNED BY; Schema: payroll; Owner: hris_admin
--

ALTER SEQUENCE payroll.pay_adjustments_id_seq OWNED BY payroll.pay_adjustments.id;


--
-- Name: pay_annual_bonuses; Type: TABLE; Schema: payroll; Owner: hris_admin
--

CREATE TABLE payroll.pay_annual_bonuses (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    bonus_type character varying(30) NOT NULL,
    year integer NOT NULL,
    reference_period character varying(60),
    gross_amount numeric(12,2) DEFAULT 0 NOT NULL,
    tax_withheld numeric(12,2) DEFAULT 0 NOT NULL,
    net_amount numeric(12,2) DEFAULT 0 NOT NULL,
    pay_run_id bigint,
    pbb_record_id bigint,
    released_at timestamp with time zone,
    released_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT pay_annual_bonuses_bonus_type_check CHECK (((bonus_type)::text = ANY ((ARRAY['YEB'::character varying, 'CASH_GIFT'::character varying, 'PBB'::character varying, 'PRODUCTIVITY_INCENTIVE'::character varying])::text[])))
);


ALTER TABLE payroll.pay_annual_bonuses OWNER TO hris_admin;

--
-- Name: pay_annual_bonuses_id_seq; Type: SEQUENCE; Schema: payroll; Owner: hris_admin
--

CREATE SEQUENCE payroll.pay_annual_bonuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE payroll.pay_annual_bonuses_id_seq OWNER TO hris_admin;

--
-- Name: pay_annual_bonuses_id_seq; Type: SEQUENCE OWNED BY; Schema: payroll; Owner: hris_admin
--

ALTER SEQUENCE payroll.pay_annual_bonuses_id_seq OWNED BY payroll.pay_annual_bonuses.id;


--
-- Name: pay_bir_tax_table; Type: TABLE; Schema: payroll; Owner: hris_admin
--

CREATE TABLE payroll.pay_bir_tax_table (
    id bigint NOT NULL,
    effective_date date NOT NULL,
    frequency character varying(15) DEFAULT 'MONTHLY'::character varying NOT NULL,
    bracket_from numeric(12,2) NOT NULL,
    bracket_to numeric(12,2) NOT NULL,
    base_tax numeric(12,2) DEFAULT 0 NOT NULL,
    excess_pct numeric(5,4) DEFAULT 0 NOT NULL,
    is_current boolean DEFAULT false NOT NULL,
    CONSTRAINT pay_bir_tax_table_frequency_check CHECK (((frequency)::text = ANY ((ARRAY['MONTHLY'::character varying, 'SEMI_MONTHLY'::character varying, 'WEEKLY'::character varying])::text[])))
);


ALTER TABLE payroll.pay_bir_tax_table OWNER TO hris_admin;

--
-- Name: pay_bir_tax_table_id_seq; Type: SEQUENCE; Schema: payroll; Owner: hris_admin
--

CREATE SEQUENCE payroll.pay_bir_tax_table_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE payroll.pay_bir_tax_table_id_seq OWNER TO hris_admin;

--
-- Name: pay_bir_tax_table_id_seq; Type: SEQUENCE OWNED BY; Schema: payroll; Owner: hris_admin
--

ALTER SEQUENCE payroll.pay_bir_tax_table_id_seq OWNED BY payroll.pay_bir_tax_table.id;


--
-- Name: pay_coop_members; Type: TABLE; Schema: payroll; Owner: hris_admin
--

CREATE TABLE payroll.pay_coop_members (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    cooperative_name character varying(200) NOT NULL,
    membership_no character varying(60),
    monthly_savings numeric(12,2) DEFAULT 0 NOT NULL,
    effective_from date NOT NULL,
    effective_to date,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE payroll.pay_coop_members OWNER TO hris_admin;

--
-- Name: pay_coop_members_id_seq; Type: SEQUENCE; Schema: payroll; Owner: hris_admin
--

CREATE SEQUENCE payroll.pay_coop_members_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE payroll.pay_coop_members_id_seq OWNER TO hris_admin;

--
-- Name: pay_coop_members_id_seq; Type: SEQUENCE OWNED BY; Schema: payroll; Owner: hris_admin
--

ALTER SEQUENCE payroll.pay_coop_members_id_seq OWNED BY payroll.pay_coop_members.id;


--
-- Name: pay_employee_allowances; Type: TABLE; Schema: payroll; Owner: hris_admin
--

CREATE TABLE payroll.pay_employee_allowances (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    allowance_type character varying(60) NOT NULL,
    amount numeric(12,2) NOT NULL,
    is_taxable boolean DEFAULT false NOT NULL,
    effective_from date NOT NULL,
    effective_to date,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE payroll.pay_employee_allowances OWNER TO hris_admin;

--
-- Name: pay_employee_allowances_gov; Type: TABLE; Schema: payroll; Owner: hris_admin
--

CREATE TABLE payroll.pay_employee_allowances_gov (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    allowance_id bigint NOT NULL,
    monthly_amount numeric(12,2) NOT NULL,
    effective_from date NOT NULL,
    effective_to date,
    approved_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE payroll.pay_employee_allowances_gov OWNER TO hris_admin;

--
-- Name: pay_employee_allowances_gov_id_seq; Type: SEQUENCE; Schema: payroll; Owner: hris_admin
--

CREATE SEQUENCE payroll.pay_employee_allowances_gov_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE payroll.pay_employee_allowances_gov_id_seq OWNER TO hris_admin;

--
-- Name: pay_employee_allowances_gov_id_seq; Type: SEQUENCE OWNED BY; Schema: payroll; Owner: hris_admin
--

ALTER SEQUENCE payroll.pay_employee_allowances_gov_id_seq OWNED BY payroll.pay_employee_allowances_gov.id;


--
-- Name: pay_employee_allowances_id_seq; Type: SEQUENCE; Schema: payroll; Owner: hris_admin
--

CREATE SEQUENCE payroll.pay_employee_allowances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE payroll.pay_employee_allowances_id_seq OWNER TO hris_admin;

--
-- Name: pay_employee_allowances_id_seq; Type: SEQUENCE OWNED BY; Schema: payroll; Owner: hris_admin
--

ALTER SEQUENCE payroll.pay_employee_allowances_id_seq OWNED BY payroll.pay_employee_allowances.id;


--
-- Name: pay_employee_payroll_id_seq; Type: SEQUENCE; Schema: payroll; Owner: hris_admin
--

CREATE SEQUENCE payroll.pay_employee_payroll_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE payroll.pay_employee_payroll_id_seq OWNER TO hris_admin;

--
-- Name: pay_employee_payroll_id_seq; Type: SEQUENCE OWNED BY; Schema: payroll; Owner: hris_admin
--

ALTER SEQUENCE payroll.pay_employee_payroll_id_seq OWNED BY payroll.pay_employee_payroll.id;


--
-- Name: pay_gov_allowances; Type: TABLE; Schema: payroll; Owner: hris_admin
--

CREATE TABLE payroll.pay_gov_allowances (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    allowance_code character varying(20) NOT NULL,
    allowance_name character varying(100) NOT NULL,
    default_amount numeric(12,2) DEFAULT 0 NOT NULL,
    is_taxable boolean DEFAULT false NOT NULL,
    applicable_to jsonb DEFAULT '{}'::jsonb NOT NULL,
    effective_date date DEFAULT CURRENT_DATE NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE payroll.pay_gov_allowances OWNER TO hris_admin;

--
-- Name: pay_gov_allowances_id_seq; Type: SEQUENCE; Schema: payroll; Owner: hris_admin
--

CREATE SEQUENCE payroll.pay_gov_allowances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE payroll.pay_gov_allowances_id_seq OWNER TO hris_admin;

--
-- Name: pay_gov_allowances_id_seq; Type: SEQUENCE OWNED BY; Schema: payroll; Owner: hris_admin
--

ALTER SEQUENCE payroll.pay_gov_allowances_id_seq OWNED BY payroll.pay_gov_allowances.id;


--
-- Name: pay_government_remittances; Type: TABLE; Schema: payroll; Owner: hris_admin
--

CREATE TABLE payroll.pay_government_remittances (
    id bigint NOT NULL,
    run_id bigint NOT NULL,
    agency character varying(20) NOT NULL,
    remittance_date date,
    total_ee numeric(14,2) DEFAULT 0 NOT NULL,
    total_er numeric(14,2) DEFAULT 0 NOT NULL,
    total_amount numeric(14,2) DEFAULT 0 NOT NULL,
    file_path text,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    submitted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE payroll.pay_government_remittances OWNER TO hris_admin;

--
-- Name: pay_government_remittances_id_seq; Type: SEQUENCE; Schema: payroll; Owner: hris_admin
--

CREATE SEQUENCE payroll.pay_government_remittances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE payroll.pay_government_remittances_id_seq OWNER TO hris_admin;

--
-- Name: pay_government_remittances_id_seq; Type: SEQUENCE OWNED BY; Schema: payroll; Owner: hris_admin
--

ALTER SEQUENCE payroll.pay_government_remittances_id_seq OWNED BY payroll.pay_government_remittances.id;


--
-- Name: pay_gsis_schedule; Type: TABLE; Schema: payroll; Owner: hris_admin
--

CREATE TABLE payroll.pay_gsis_schedule (
    id bigint NOT NULL,
    effective_date date NOT NULL,
    salary_bracket_from numeric(12,2) NOT NULL,
    salary_bracket_to numeric(12,2) NOT NULL,
    ee_personal_share_pct numeric(5,4) NOT NULL,
    er_government_share_pct numeric(5,4) NOT NULL,
    life_insurance_pct numeric(5,4) DEFAULT 0 NOT NULL,
    is_current boolean DEFAULT false NOT NULL
);


ALTER TABLE payroll.pay_gsis_schedule OWNER TO hris_admin;

--
-- Name: pay_gsis_schedule_id_seq; Type: SEQUENCE; Schema: payroll; Owner: hris_admin
--

CREATE SEQUENCE payroll.pay_gsis_schedule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE payroll.pay_gsis_schedule_id_seq OWNER TO hris_admin;

--
-- Name: pay_gsis_schedule_id_seq; Type: SEQUENCE OWNED BY; Schema: payroll; Owner: hris_admin
--

ALTER SEQUENCE payroll.pay_gsis_schedule_id_seq OWNED BY payroll.pay_gsis_schedule.id;


--
-- Name: pay_loan_payments; Type: TABLE; Schema: payroll; Owner: hris_admin
--

CREATE TABLE payroll.pay_loan_payments (
    id bigint NOT NULL,
    loan_id bigint NOT NULL,
    run_id bigint,
    payment_date date NOT NULL,
    amount numeric(12,2) NOT NULL,
    principal_paid numeric(12,2) DEFAULT 0 NOT NULL,
    interest_paid numeric(12,2) DEFAULT 0 NOT NULL,
    balance_after numeric(14,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE payroll.pay_loan_payments OWNER TO hris_admin;

--
-- Name: pay_loan_payments_id_seq; Type: SEQUENCE; Schema: payroll; Owner: hris_admin
--

CREATE SEQUENCE payroll.pay_loan_payments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE payroll.pay_loan_payments_id_seq OWNER TO hris_admin;

--
-- Name: pay_loan_payments_id_seq; Type: SEQUENCE OWNED BY; Schema: payroll; Owner: hris_admin
--

ALTER SEQUENCE payroll.pay_loan_payments_id_seq OWNED BY payroll.pay_loan_payments.id;


--
-- Name: pay_loans; Type: TABLE; Schema: payroll; Owner: hris_admin
--

CREATE TABLE payroll.pay_loans (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    loan_type character varying(50) NOT NULL,
    reference_no character varying(40) NOT NULL,
    principal_amount numeric(14,2) NOT NULL,
    outstanding_balance numeric(14,2) NOT NULL,
    monthly_deduction numeric(12,2) NOT NULL,
    interest_rate numeric(5,4) DEFAULT 0 NOT NULL,
    total_months integer NOT NULL,
    months_paid integer DEFAULT 0 NOT NULL,
    start_date date NOT NULL,
    end_date date,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    workflow_instance_id bigint,
    approved_by bigint,
    approved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE payroll.pay_loans OWNER TO hris_admin;

--
-- Name: pay_loans_id_seq; Type: SEQUENCE; Schema: payroll; Owner: hris_admin
--

CREATE SEQUENCE payroll.pay_loans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE payroll.pay_loans_id_seq OWNER TO hris_admin;

--
-- Name: pay_loans_id_seq; Type: SEQUENCE OWNED BY; Schema: payroll; Owner: hris_admin
--

ALTER SEQUENCE payroll.pay_loans_id_seq OWNED BY payroll.pay_loans.id;


--
-- Name: pay_pagibig_schedule; Type: TABLE; Schema: payroll; Owner: hris_admin
--

CREATE TABLE payroll.pay_pagibig_schedule (
    id bigint NOT NULL,
    effective_date date NOT NULL,
    salary_bracket_from numeric(12,2) NOT NULL,
    salary_bracket_to numeric(12,2) NOT NULL,
    ee_contribution_pct numeric(5,4) NOT NULL,
    er_contribution_pct numeric(5,4) NOT NULL,
    is_current boolean DEFAULT false NOT NULL
);


ALTER TABLE payroll.pay_pagibig_schedule OWNER TO hris_admin;

--
-- Name: pay_pagibig_schedule_id_seq; Type: SEQUENCE; Schema: payroll; Owner: hris_admin
--

CREATE SEQUENCE payroll.pay_pagibig_schedule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE payroll.pay_pagibig_schedule_id_seq OWNER TO hris_admin;

--
-- Name: pay_pagibig_schedule_id_seq; Type: SEQUENCE OWNED BY; Schema: payroll; Owner: hris_admin
--

ALTER SEQUENCE payroll.pay_pagibig_schedule_id_seq OWNED BY payroll.pay_pagibig_schedule.id;


--
-- Name: pay_periods_id_seq; Type: SEQUENCE; Schema: payroll; Owner: hris_admin
--

CREATE SEQUENCE payroll.pay_periods_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE payroll.pay_periods_id_seq OWNER TO hris_admin;

--
-- Name: pay_periods_id_seq; Type: SEQUENCE OWNED BY; Schema: payroll; Owner: hris_admin
--

ALTER SEQUENCE payroll.pay_periods_id_seq OWNED BY payroll.pay_periods.id;


--
-- Name: pay_rata_schedule; Type: TABLE; Schema: payroll; Owner: hris_admin
--

CREATE TABLE payroll.pay_rata_schedule (
    id bigint NOT NULL,
    position_id bigint,
    salary_grade integer NOT NULL,
    representation_allowance numeric(12,2) DEFAULT 0 NOT NULL,
    transportation_allowance numeric(12,2) DEFAULT 0 NOT NULL,
    effective_date date DEFAULT CURRENT_DATE NOT NULL,
    is_current boolean DEFAULT false NOT NULL
);


ALTER TABLE payroll.pay_rata_schedule OWNER TO hris_admin;

--
-- Name: pay_rata_schedule_id_seq; Type: SEQUENCE; Schema: payroll; Owner: hris_admin
--

CREATE SEQUENCE payroll.pay_rata_schedule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE payroll.pay_rata_schedule_id_seq OWNER TO hris_admin;

--
-- Name: pay_rata_schedule_id_seq; Type: SEQUENCE OWNED BY; Schema: payroll; Owner: hris_admin
--

ALTER SEQUENCE payroll.pay_rata_schedule_id_seq OWNED BY payroll.pay_rata_schedule.id;


--
-- Name: pay_runs_id_seq; Type: SEQUENCE; Schema: payroll; Owner: hris_admin
--

CREATE SEQUENCE payroll.pay_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE payroll.pay_runs_id_seq OWNER TO hris_admin;

--
-- Name: pay_runs_id_seq; Type: SEQUENCE OWNED BY; Schema: payroll; Owner: hris_admin
--

ALTER SEQUENCE payroll.pay_runs_id_seq OWNED BY payroll.pay_runs.id;


--
-- Name: pay_tax_tables; Type: TABLE; Schema: payroll; Owner: hris_admin
--

CREATE TABLE payroll.pay_tax_tables (
    id bigint NOT NULL,
    effective_year integer NOT NULL,
    frequency character varying(20) DEFAULT 'SEMI_MONTHLY'::character varying NOT NULL,
    bracket_from numeric(14,2) NOT NULL,
    bracket_to numeric(14,2),
    base_tax numeric(12,2) DEFAULT 0 NOT NULL,
    tax_rate numeric(5,4) DEFAULT 0 NOT NULL,
    excess_over numeric(14,2) DEFAULT 0 NOT NULL
);


ALTER TABLE payroll.pay_tax_tables OWNER TO hris_admin;

--
-- Name: pay_tax_tables_id_seq; Type: SEQUENCE; Schema: payroll; Owner: hris_admin
--

CREATE SEQUENCE payroll.pay_tax_tables_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE payroll.pay_tax_tables_id_seq OWNER TO hris_admin;

--
-- Name: pay_tax_tables_id_seq; Type: SEQUENCE OWNED BY; Schema: payroll; Owner: hris_admin
--

ALTER SEQUENCE payroll.pay_tax_tables_id_seq OWNED BY payroll.pay_tax_tables.id;


--
-- Name: v_current_cutoff; Type: VIEW; Schema: payroll; Owner: hris_admin
--

CREATE VIEW payroll.v_current_cutoff AS
 SELECT pp.period_code,
    pp.date_from,
    pp.date_to,
    pp.payment_date,
    pr.id AS run_id,
    pr.status AS run_status,
    pr.total_employees,
    pr.total_gross,
    pr.total_net,
    pr.total_deductions
   FROM (payroll.pay_periods pp
     LEFT JOIN payroll.pay_runs pr ON ((pr.period_id = pp.id)))
  WHERE ((pp.status)::text = ANY ((ARRAY['OPEN'::character varying, 'PROCESSING'::character varying])::text[]))
  ORDER BY pp.date_from DESC
 LIMIT 1;


ALTER TABLE payroll.v_current_cutoff OWNER TO hris_admin;

--
-- Name: v_gov_payroll_summary; Type: VIEW; Schema: payroll; Owner: hris_admin
--

CREATE VIEW payroll.v_gov_payroll_summary AS
 SELECT ep.run_id,
    count(ep.id) AS employee_count,
    sum(ep.basic_pay) AS total_basic,
    sum(ep.pera) AS total_pera,
    sum(ep.rata) AS total_rata,
    sum(ep.gross_pay) AS total_gross,
    sum(ep.gsis_ps) AS total_gsis_ee,
    sum(ep.gsis_gs) AS total_gsis_er,
    sum(ep.pagibig_ps) AS total_pagibig_ee,
    sum(ep.pagibig_gs) AS total_pagibig_er,
    sum(ep.philhealth_ee) AS total_philhealth,
    sum(ep.tax_withheld) AS total_tax,
    sum(ep.loan_deductions) AS total_loans,
    sum(ep.total_deductions) AS total_deductions,
    sum(ep.net_pay) AS total_net
   FROM payroll.pay_employee_payroll ep
  GROUP BY ep.run_id;


ALTER TABLE payroll.v_gov_payroll_summary OWNER TO hris_admin;

--
-- Name: v_payslip; Type: VIEW; Schema: payroll; Owner: hris_admin
--

CREATE VIEW payroll.v_payslip AS
 SELECT ep.id AS payslip_id,
    ep.run_id,
    pp.period_code,
    pp.date_from AS period_from,
    pp.date_to AS period_to,
    pp.payment_date,
    e.id AS employee_id,
    e.employee_no,
    (((e.last_name)::text || ', '::text) || (e.first_name)::text) AS full_name,
    d.name AS department,
    p.title AS "position",
    ep.worked_days,
    ep.absent_days,
    ep.leave_days,
    ep.ot_regular_hours,
    ep.ot_restday_hours,
    ep.ot_holiday_hours,
    ep.basic_pay,
    ep.ot_pay,
    ep.holiday_pay,
    ep.night_diff_pay,
    ep.allowances_total,
    ep.other_earnings,
    ep.gross_pay,
    ep.sss_ee,
    ep.philhealth_ee,
    ep.pagibig_ee,
    ep.tax_withheld,
    ep.loan_deductions,
    ep.other_deductions,
    ep.total_deductions,
    ep.net_pay
   FROM (((((payroll.pay_employee_payroll ep
     JOIN payroll.pay_runs pr ON ((pr.id = ep.run_id)))
     JOIN payroll.pay_periods pp ON ((pp.id = pr.period_id)))
     JOIN core.employees e ON ((e.id = ep.employee_id)))
     LEFT JOIN core.departments d ON ((d.id = e.department_id)))
     LEFT JOIN core.positions p ON ((p.id = e.position_id)));


ALTER TABLE payroll.v_payslip OWNER TO hris_admin;

--
-- Name: perf_competencies; Type: TABLE; Schema: performance; Owner: hris_admin
--

CREATE TABLE performance.perf_competencies (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    code character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    weight numeric(4,2) DEFAULT 1.0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE performance.perf_competencies OWNER TO hris_admin;

--
-- Name: perf_competencies_id_seq; Type: SEQUENCE; Schema: performance; Owner: hris_admin
--

CREATE SEQUENCE performance.perf_competencies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE performance.perf_competencies_id_seq OWNER TO hris_admin;

--
-- Name: perf_competencies_id_seq; Type: SEQUENCE OWNED BY; Schema: performance; Owner: hris_admin
--

ALTER SEQUENCE performance.perf_competencies_id_seq OWNED BY performance.perf_competencies.id;


--
-- Name: perf_cycles; Type: TABLE; Schema: performance; Owner: hris_admin
--

CREATE TABLE performance.perf_cycles (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    name character varying(200) NOT NULL,
    cycle_type character varying(20) DEFAULT 'ANNUAL'::character varying NOT NULL,
    period_from date NOT NULL,
    period_to date NOT NULL,
    status character varying(20) DEFAULT 'PLANNING'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    cycle_subtype character varying(20) DEFAULT 'YEAR_END'::character varying,
    CONSTRAINT perf_cycles_cycle_subtype_check CHECK (((cycle_subtype)::text = ANY ((ARRAY['MID_YEAR'::character varying, 'YEAR_END'::character varying])::text[])))
);


ALTER TABLE performance.perf_cycles OWNER TO hris_admin;

--
-- Name: perf_cycles_id_seq; Type: SEQUENCE; Schema: performance; Owner: hris_admin
--

CREATE SEQUENCE performance.perf_cycles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE performance.perf_cycles_id_seq OWNER TO hris_admin;

--
-- Name: perf_cycles_id_seq; Type: SEQUENCE OWNED BY; Schema: performance; Owner: hris_admin
--

ALTER SEQUENCE performance.perf_cycles_id_seq OWNED BY performance.perf_cycles.id;


--
-- Name: perf_employee_kpis; Type: TABLE; Schema: performance; Owner: hris_admin
--

CREATE TABLE performance.perf_employee_kpis (
    id bigint NOT NULL,
    cycle_id bigint NOT NULL,
    employee_id bigint NOT NULL,
    kpi_name character varying(200) NOT NULL,
    description text,
    target_value numeric(10,2),
    actual_value numeric(10,2),
    weight numeric(4,2) DEFAULT 1.0 NOT NULL,
    score numeric(4,2),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE performance.perf_employee_kpis OWNER TO hris_admin;

--
-- Name: perf_employee_kpis_id_seq; Type: SEQUENCE; Schema: performance; Owner: hris_admin
--

CREATE SEQUENCE performance.perf_employee_kpis_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE performance.perf_employee_kpis_id_seq OWNER TO hris_admin;

--
-- Name: perf_employee_kpis_id_seq; Type: SEQUENCE OWNED BY; Schema: performance; Owner: hris_admin
--

ALTER SEQUENCE performance.perf_employee_kpis_id_seq OWNED BY performance.perf_employee_kpis.id;


--
-- Name: perf_idp_plans; Type: TABLE; Schema: performance; Owner: hris_admin
--

CREATE TABLE performance.perf_idp_plans (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    cycle_id bigint,
    development_goal text NOT NULL,
    action_steps text,
    target_date date,
    status character varying(20) DEFAULT 'IN_PROGRESS'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE performance.perf_idp_plans OWNER TO hris_admin;

--
-- Name: perf_idp_plans_id_seq; Type: SEQUENCE; Schema: performance; Owner: hris_admin
--

CREATE SEQUENCE performance.perf_idp_plans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE performance.perf_idp_plans_id_seq OWNER TO hris_admin;

--
-- Name: perf_idp_plans_id_seq; Type: SEQUENCE OWNED BY; Schema: performance; Owner: hris_admin
--

ALTER SEQUENCE performance.perf_idp_plans_id_seq OWNED BY performance.perf_idp_plans.id;


--
-- Name: perf_ipcr; Type: TABLE; Schema: performance; Owner: hris_admin
--

CREATE TABLE performance.perf_ipcr (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    cycle_id bigint NOT NULL,
    opcr_id bigint,
    function_type character varying(20) DEFAULT 'CORE'::character varying NOT NULL,
    performance_indicator text NOT NULL,
    target text,
    target_value numeric(10,2),
    actual_value numeric(10,2),
    quality_rating numeric(3,2),
    efficiency_rating numeric(3,2),
    timeliness_rating numeric(3,2),
    average_rating numeric(3,2) GENERATED ALWAYS AS (round((((COALESCE(quality_rating, (0)::numeric) + COALESCE(efficiency_rating, (0)::numeric)) + COALESCE(timeliness_rating, (0)::numeric)) / 3.0), 2)) STORED,
    weight numeric(5,2) DEFAULT 1.0 NOT NULL,
    means_of_verification text,
    supporting_docs_path character varying(500),
    evaluator_id bigint,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    workflow_instance_id bigint,
    period_start date,
    period_end date,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT perf_ipcr_function_type_check CHECK (((function_type)::text = ANY ((ARRAY['CORE'::character varying, 'SUPPORT'::character varying, 'STRATEGIC'::character varying])::text[]))),
    CONSTRAINT perf_ipcr_status_check CHECK (((status)::text = ANY ((ARRAY['DRAFT'::character varying, 'SUBMITTED'::character varying, 'EVALUATED'::character varying, 'APPROVED'::character varying])::text[])))
);


ALTER TABLE performance.perf_ipcr OWNER TO hris_admin;

--
-- Name: perf_ipcr_id_seq; Type: SEQUENCE; Schema: performance; Owner: hris_admin
--

CREATE SEQUENCE performance.perf_ipcr_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE performance.perf_ipcr_id_seq OWNER TO hris_admin;

--
-- Name: perf_ipcr_id_seq; Type: SEQUENCE OWNED BY; Schema: performance; Owner: hris_admin
--

ALTER SEQUENCE performance.perf_ipcr_id_seq OWNED BY performance.perf_ipcr.id;


--
-- Name: perf_ipcr_summary; Type: TABLE; Schema: performance; Owner: hris_admin
--

CREATE TABLE performance.perf_ipcr_summary (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    cycle_id bigint NOT NULL,
    final_numerical_rating numeric(3,2),
    adjectival_rating character varying(30),
    evaluator_comments text,
    employee_comments text,
    approved_by bigint,
    approved_at timestamp with time zone,
    pbb_eligible boolean DEFAULT false NOT NULL,
    step_increment_eligible boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE performance.perf_ipcr_summary OWNER TO hris_admin;

--
-- Name: perf_ipcr_summary_id_seq; Type: SEQUENCE; Schema: performance; Owner: hris_admin
--

CREATE SEQUENCE performance.perf_ipcr_summary_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE performance.perf_ipcr_summary_id_seq OWNER TO hris_admin;

--
-- Name: perf_ipcr_summary_id_seq; Type: SEQUENCE OWNED BY; Schema: performance; Owner: hris_admin
--

ALTER SEQUENCE performance.perf_ipcr_summary_id_seq OWNED BY performance.perf_ipcr_summary.id;


--
-- Name: perf_opcr; Type: TABLE; Schema: performance; Owner: hris_admin
--

CREATE TABLE performance.perf_opcr (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    department_id bigint NOT NULL,
    cycle_id bigint NOT NULL,
    mfo_code character varying(20),
    performance_indicator text NOT NULL,
    target text,
    target_value numeric(10,2),
    actual_value numeric(10,2),
    self_rating numeric(3,2),
    validated_rating numeric(3,2),
    adjectival_rating character varying(30),
    weight numeric(5,2) DEFAULT 1.0 NOT NULL,
    means_of_verification text,
    responsible_office text,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    workflow_instance_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT perf_opcr_status_check CHECK (((status)::text = ANY ((ARRAY['DRAFT'::character varying, 'SUBMITTED'::character varying, 'RATED'::character varying, 'APPROVED'::character varying])::text[])))
);


ALTER TABLE performance.perf_opcr OWNER TO hris_admin;

--
-- Name: perf_opcr_id_seq; Type: SEQUENCE; Schema: performance; Owner: hris_admin
--

CREATE SEQUENCE performance.perf_opcr_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE performance.perf_opcr_id_seq OWNER TO hris_admin;

--
-- Name: perf_opcr_id_seq; Type: SEQUENCE OWNED BY; Schema: performance; Owner: hris_admin
--

ALTER SEQUENCE performance.perf_opcr_id_seq OWNED BY performance.perf_opcr.id;


--
-- Name: perf_reviews; Type: TABLE; Schema: performance; Owner: hris_admin
--

CREATE TABLE performance.perf_reviews (
    id bigint NOT NULL,
    cycle_id bigint NOT NULL,
    employee_id bigint NOT NULL,
    reviewer_id bigint NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    self_score numeric(4,2),
    manager_score numeric(4,2),
    final_score numeric(4,2),
    self_comments text,
    manager_comments text,
    workflow_instance_id bigint,
    submitted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    adjectival_rating character varying(30),
    numerical_rating numeric(3,2),
    approved_at timestamp with time zone
);


ALTER TABLE performance.perf_reviews OWNER TO hris_admin;

--
-- Name: perf_reviews_id_seq; Type: SEQUENCE; Schema: performance; Owner: hris_admin
--

CREATE SEQUENCE performance.perf_reviews_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE performance.perf_reviews_id_seq OWNER TO hris_admin;

--
-- Name: perf_reviews_id_seq; Type: SEQUENCE OWNED BY; Schema: performance; Owner: hris_admin
--

ALTER SEQUENCE performance.perf_reviews_id_seq OWNED BY performance.perf_reviews.id;


--
-- Name: perf_strategic_plans; Type: TABLE; Schema: performance; Owner: hris_admin
--

CREATE TABLE performance.perf_strategic_plans (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    year integer NOT NULL,
    vision text,
    mission text,
    strategic_priorities jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_by bigint,
    approved_by bigint,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT perf_strategic_plans_status_check CHECK (((status)::text = ANY ((ARRAY['DRAFT'::character varying, 'APPROVED'::character varying])::text[])))
);


ALTER TABLE performance.perf_strategic_plans OWNER TO hris_admin;

--
-- Name: perf_strategic_plans_id_seq; Type: SEQUENCE; Schema: performance; Owner: hris_admin
--

CREATE SEQUENCE performance.perf_strategic_plans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE performance.perf_strategic_plans_id_seq OWNER TO hris_admin;

--
-- Name: perf_strategic_plans_id_seq; Type: SEQUENCE OWNED BY; Schema: performance; Owner: hris_admin
--

ALTER SEQUENCE performance.perf_strategic_plans_id_seq OWNED BY performance.perf_strategic_plans.id;


--
-- Name: perf_succession_matrix; Type: TABLE; Schema: performance; Owner: hris_admin
--

CREATE TABLE performance.perf_succession_matrix (
    id bigint NOT NULL,
    key_position_id bigint NOT NULL,
    successor_employee_id bigint NOT NULL,
    readiness character varying(20) DEFAULT 'LONG_TERM'::character varying NOT NULL,
    development_needs text,
    assessed_on date DEFAULT CURRENT_DATE NOT NULL,
    assessed_by bigint,
    cycle_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT perf_succession_matrix_readiness_check CHECK (((readiness)::text = ANY ((ARRAY['READY_NOW'::character varying, 'READY_1_2YR'::character varying, 'READY_3_5YR'::character varying, 'LONG_TERM'::character varying])::text[])))
);


ALTER TABLE performance.perf_succession_matrix OWNER TO hris_admin;

--
-- Name: perf_succession_matrix_id_seq; Type: SEQUENCE; Schema: performance; Owner: hris_admin
--

CREATE SEQUENCE performance.perf_succession_matrix_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE performance.perf_succession_matrix_id_seq OWNER TO hris_admin;

--
-- Name: perf_succession_matrix_id_seq; Type: SEQUENCE OWNED BY; Schema: performance; Owner: hris_admin
--

ALTER SEQUENCE performance.perf_succession_matrix_id_seq OWNED BY performance.perf_succession_matrix.id;


--
-- Name: v_ipcr_summary; Type: VIEW; Schema: performance; Owner: hris_admin
--

CREATE VIEW performance.v_ipcr_summary AS
 SELECT s.id,
    s.employee_id,
    s.cycle_id,
    s.final_numerical_rating,
    s.adjectival_rating,
    s.pbb_eligible,
    s.step_increment_eligible,
    s.approved_at,
    (((e.first_name)::text || ' '::text) || (e.last_name)::text) AS employee_name,
    e.employee_no,
    d.name AS department_name,
    p.title AS position_title,
    c.name AS cycle_name,
    c.period_from,
    c.period_to
   FROM ((((performance.perf_ipcr_summary s
     JOIN core.employees e ON ((e.id = s.employee_id)))
     LEFT JOIN core.departments d ON ((d.id = e.department_id)))
     LEFT JOIN core.positions p ON ((p.id = e.position_id)))
     JOIN performance.perf_cycles c ON ((c.id = s.cycle_id)));


ALTER TABLE performance.v_ipcr_summary OWNER TO hris_admin;

--
-- Name: ai_persona_configs; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.ai_persona_configs (
    id bigint NOT NULL,
    role_code character varying(50) NOT NULL,
    persona_name character varying(100) NOT NULL,
    system_prompt_addendum text,
    available_tools text[] DEFAULT '{}'::text[] NOT NULL,
    max_turns integer DEFAULT 6 NOT NULL,
    max_tokens integer DEFAULT 2048 NOT NULL,
    greeting_template text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.ai_persona_configs OWNER TO hris_admin;

--
-- Name: ai_persona_configs_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.ai_persona_configs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ai_persona_configs_id_seq OWNER TO hris_admin;

--
-- Name: ai_persona_configs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.ai_persona_configs_id_seq OWNED BY public.ai_persona_configs.id;


--
-- Name: analytics_metric_definitions; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.analytics_metric_definitions (
    id bigint NOT NULL,
    metric_code character varying(100) NOT NULL,
    category character varying(50) NOT NULL,
    name character varying(200) NOT NULL,
    description text,
    formula_sql text,
    unit character varying(30),
    direction character varying(10) DEFAULT 'NEUTRAL'::character varying NOT NULL,
    target_value numeric(20,4),
    warning_threshold numeric(20,4),
    critical_threshold numeric(20,4),
    refresh_frequency character varying(20) DEFAULT 'DAILY'::character varying NOT NULL,
    is_ai_derived boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.analytics_metric_definitions OWNER TO hris_admin;

--
-- Name: analytics_metric_definitions_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.analytics_metric_definitions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.analytics_metric_definitions_id_seq OWNER TO hris_admin;

--
-- Name: analytics_metric_definitions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.analytics_metric_definitions_id_seq OWNED BY public.analytics_metric_definitions.id;


--
-- Name: att_daily; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.att_daily (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    work_date date NOT NULL,
    shift_id bigint,
    time_in timestamp with time zone,
    time_out timestamp with time zone,
    hours_worked numeric(5,2) DEFAULT 0 NOT NULL,
    hours_late numeric(5,2) DEFAULT 0 NOT NULL,
    hours_undertime numeric(5,2) DEFAULT 0 NOT NULL,
    hours_overtime numeric(5,2) DEFAULT 0 NOT NULL,
    hours_night_diff numeric(5,2) DEFAULT 0 NOT NULL,
    status character varying(20) DEFAULT 'ABSENT'::character varying NOT NULL,
    is_holiday boolean DEFAULT false NOT NULL,
    holiday_id bigint,
    is_restday boolean DEFAULT false NOT NULL,
    leave_request_id bigint,
    remarks text,
    is_locked boolean DEFAULT false NOT NULL,
    locked_by bigint,
    locked_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.att_daily OWNER TO hris_admin;

--
-- Name: att_daily_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.att_daily_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.att_daily_id_seq OWNER TO hris_admin;

--
-- Name: att_daily_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.att_daily_id_seq OWNED BY public.att_daily.id;


--
-- Name: att_holiday_types; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.att_holiday_types (
    id bigint NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
    pay_multiplier numeric(4,2) DEFAULT 1.0 NOT NULL,
    description text
);


ALTER TABLE public.att_holiday_types OWNER TO hris_admin;

--
-- Name: att_holiday_types_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.att_holiday_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.att_holiday_types_id_seq OWNER TO hris_admin;

--
-- Name: att_holiday_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.att_holiday_types_id_seq OWNED BY public.att_holiday_types.id;


--
-- Name: att_holidays; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.att_holidays (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    holiday_type_id bigint NOT NULL,
    holiday_date date NOT NULL,
    name character varying(200) NOT NULL,
    description text,
    is_recurring boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.att_holidays OWNER TO hris_admin;

--
-- Name: att_holidays_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.att_holidays_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.att_holidays_id_seq OWNER TO hris_admin;

--
-- Name: att_holidays_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.att_holidays_id_seq OWNED BY public.att_holidays.id;


--
-- Name: att_logs; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.att_logs (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    log_datetime timestamp with time zone NOT NULL,
    log_type character varying(10) NOT NULL,
    source character varying(20) DEFAULT 'MANUAL'::character varying NOT NULL,
    device_id character varying(50),
    location character varying(200),
    photo_path text,
    is_valid boolean DEFAULT true NOT NULL,
    invalidated_by bigint,
    invalidation_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
)
PARTITION BY RANGE (log_datetime);


ALTER TABLE public.att_logs OWNER TO hris_admin;

--
-- Name: att_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.att_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.att_logs_id_seq OWNER TO hris_admin;

--
-- Name: att_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.att_logs_id_seq OWNED BY public.att_logs.id;


--
-- Name: att_logs_2025; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.att_logs_2025 (
    id bigint DEFAULT nextval('public.att_logs_id_seq'::regclass) NOT NULL,
    employee_id bigint NOT NULL,
    log_datetime timestamp with time zone NOT NULL,
    log_type character varying(10) NOT NULL,
    source character varying(20) DEFAULT 'MANUAL'::character varying NOT NULL,
    device_id character varying(50),
    location character varying(200),
    photo_path text,
    is_valid boolean DEFAULT true NOT NULL,
    invalidated_by bigint,
    invalidation_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.att_logs_2025 OWNER TO hris_admin;

--
-- Name: att_logs_2026; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.att_logs_2026 (
    id bigint DEFAULT nextval('public.att_logs_id_seq'::regclass) NOT NULL,
    employee_id bigint NOT NULL,
    log_datetime timestamp with time zone NOT NULL,
    log_type character varying(10) NOT NULL,
    source character varying(20) DEFAULT 'MANUAL'::character varying NOT NULL,
    device_id character varying(50),
    location character varying(200),
    photo_path text,
    is_valid boolean DEFAULT true NOT NULL,
    invalidated_by bigint,
    invalidation_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.att_logs_2026 OWNER TO hris_admin;

--
-- Name: att_logs_2027; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.att_logs_2027 (
    id bigint DEFAULT nextval('public.att_logs_id_seq'::regclass) NOT NULL,
    employee_id bigint NOT NULL,
    log_datetime timestamp with time zone NOT NULL,
    log_type character varying(10) NOT NULL,
    source character varying(20) DEFAULT 'MANUAL'::character varying NOT NULL,
    device_id character varying(50),
    location character varying(200),
    photo_path text,
    is_valid boolean DEFAULT true NOT NULL,
    invalidated_by bigint,
    invalidation_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.att_logs_2027 OWNER TO hris_admin;

--
-- Name: att_logs_2028; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.att_logs_2028 (
    id bigint DEFAULT nextval('public.att_logs_id_seq'::regclass) NOT NULL,
    employee_id bigint NOT NULL,
    log_datetime timestamp with time zone NOT NULL,
    log_type character varying(10) NOT NULL,
    source character varying(20) DEFAULT 'MANUAL'::character varying NOT NULL,
    device_id character varying(50),
    location character varying(200),
    photo_path text,
    is_valid boolean DEFAULT true NOT NULL,
    invalidated_by bigint,
    invalidation_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.att_logs_2028 OWNER TO hris_admin;

--
-- Name: att_overtime_requests; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.att_overtime_requests (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    request_date date NOT NULL,
    expected_ot_hours numeric(4,2) NOT NULL,
    reason text NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    approved_by bigint,
    approved_at timestamp with time zone,
    rejection_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.att_overtime_requests OWNER TO hris_admin;

--
-- Name: att_overtime_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.att_overtime_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.att_overtime_requests_id_seq OWNER TO hris_admin;

--
-- Name: att_overtime_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.att_overtime_requests_id_seq OWNED BY public.att_overtime_requests.id;


--
-- Name: att_shift_assignments; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.att_shift_assignments (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    shift_id bigint NOT NULL,
    effective_from date NOT NULL,
    effective_to date,
    created_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.att_shift_assignments OWNER TO hris_admin;

--
-- Name: att_shift_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.att_shift_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.att_shift_assignments_id_seq OWNER TO hris_admin;

--
-- Name: att_shift_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.att_shift_assignments_id_seq OWNED BY public.att_shift_assignments.id;


--
-- Name: att_shifts; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.att_shifts (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
    shift_type character varying(20) DEFAULT 'FIXED'::character varying NOT NULL,
    time_in time without time zone,
    time_out time without time zone,
    break_minutes integer DEFAULT 60 NOT NULL,
    total_work_hours numeric(4,2),
    grace_period_minutes integer DEFAULT 0 NOT NULL,
    is_night_shift boolean DEFAULT false NOT NULL,
    crosses_midnight boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.att_shifts OWNER TO hris_admin;

--
-- Name: att_shifts_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.att_shifts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.att_shifts_id_seq OWNER TO hris_admin;

--
-- Name: att_shifts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.att_shifts_id_seq OWNED BY public.att_shifts.id;


--
-- Name: business_units; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.business_units (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(200) NOT NULL,
    parent_id bigint,
    head_employee_id bigint,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.business_units OWNER TO hris_admin;

--
-- Name: business_units_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.business_units_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.business_units_id_seq OWNER TO hris_admin;

--
-- Name: business_units_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.business_units_id_seq OWNED BY public.business_units.id;


--
-- Name: companies; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.companies (
    id bigint NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(200) NOT NULL,
    legal_name character varying(200),
    industry character varying(100),
    size_bracket character varying(20) DEFAULT 'MSME'::character varying NOT NULL,
    address_line1 text,
    address_line2 text,
    barangay character varying(100),
    city character varying(100),
    province character varying(100),
    region character varying(100),
    zip_code character varying(10),
    country character varying(100) DEFAULT 'Philippines'::character varying NOT NULL,
    phone character varying(30),
    email character varying(200),
    website character varying(200),
    tin character varying(20),
    sss_employer_id character varying(30),
    phic_employer_id character varying(30),
    hdmf_employer_id character varying(30),
    logo_path text,
    fiscal_year_start integer DEFAULT 1 NOT NULL,
    payroll_cycle character varying(20) DEFAULT 'SEMI_MONTHLY'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.companies OWNER TO hris_admin;

--
-- Name: companies_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.companies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.companies_id_seq OWNER TO hris_admin;

--
-- Name: companies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.companies_id_seq OWNED BY public.companies.id;


--
-- Name: company_branding; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.company_branding (
    id integer NOT NULL,
    company_name character varying(120) NOT NULL,
    logo_url text,
    favicon_url text
);


ALTER TABLE public.company_branding OWNER TO hris_admin;

--
-- Name: company_branding_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.company_branding_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.company_branding_id_seq OWNER TO hris_admin;

--
-- Name: company_branding_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.company_branding_id_seq OWNED BY public.company_branding.id;


--
-- Name: dashboard_metrics; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.dashboard_metrics (
    id integer NOT NULL,
    metric_code character varying(60) NOT NULL,
    metric_label character varying(120) NOT NULL,
    formula_text text NOT NULL,
    drilldown_url character varying(255) NOT NULL,
    sort_order integer DEFAULT 0,
    is_active boolean DEFAULT true
);


ALTER TABLE public.dashboard_metrics OWNER TO hris_admin;

--
-- Name: dashboard_metrics_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.dashboard_metrics_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dashboard_metrics_id_seq OWNER TO hris_admin;

--
-- Name: dashboard_metrics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.dashboard_metrics_id_seq OWNED BY public.dashboard_metrics.id;


--
-- Name: departments; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.departments (
    id integer NOT NULL,
    name character varying(120) NOT NULL
);


ALTER TABLE public.departments OWNER TO hris_admin;

--
-- Name: departments_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.departments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.departments_id_seq OWNER TO hris_admin;

--
-- Name: departments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.departments_id_seq OWNED BY public.departments.id;


--
-- Name: dim_date; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.dim_date (
    date_key integer NOT NULL,
    full_date date NOT NULL,
    day_of_week smallint NOT NULL,
    day_name character varying(10) NOT NULL,
    day_of_month smallint NOT NULL,
    day_of_year smallint NOT NULL,
    week_of_year smallint NOT NULL,
    month_number smallint NOT NULL,
    month_name character varying(10) NOT NULL,
    quarter smallint NOT NULL,
    year smallint NOT NULL,
    is_weekday boolean NOT NULL,
    is_weekend boolean NOT NULL,
    is_holiday boolean DEFAULT false NOT NULL,
    holiday_name character varying(200),
    fiscal_month smallint,
    fiscal_quarter smallint,
    fiscal_year smallint
);


ALTER TABLE public.dim_date OWNER TO hris_admin;

--
-- Name: dim_employee; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.dim_employee (
    surrogate_key bigint NOT NULL,
    employee_id bigint NOT NULL,
    employee_no character varying(30),
    uuid uuid,
    full_name character varying(300),
    last_name character varying(100),
    first_name character varying(100),
    gender character varying(20),
    civil_status character varying(20),
    date_of_birth date,
    nationality character varying(50),
    department_id bigint,
    department_name character varying(200),
    business_unit_name character varying(200),
    position_id bigint,
    position_title character varying(200),
    job_grade_code character varying(20),
    job_grade_name character varying(100),
    employment_type character varying(100),
    is_managerial boolean,
    supervisor_id bigint,
    supervisor_name character varying(300),
    work_arrangement character varying(20),
    work_location character varying(200),
    cost_center_code character varying(20),
    status character varying(30),
    date_hired date,
    date_regularized date,
    basic_salary numeric(14,2),
    effective_from date NOT NULL,
    effective_to date,
    is_current boolean DEFAULT true NOT NULL,
    snapshot_source character varying(30) DEFAULT 'TRIGGER'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.dim_employee OWNER TO hris_admin;

--
-- Name: dim_employee_surrogate_key_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.dim_employee_surrogate_key_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dim_employee_surrogate_key_seq OWNER TO hris_admin;

--
-- Name: dim_employee_surrogate_key_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.dim_employee_surrogate_key_seq OWNED BY public.dim_employee.surrogate_key;


--
-- Name: doc_categories; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.doc_categories (
    id bigint NOT NULL,
    code character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    requires_expiry boolean DEFAULT false NOT NULL,
    is_confidential boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.doc_categories OWNER TO hris_admin;

--
-- Name: doc_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.doc_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.doc_categories_id_seq OWNER TO hris_admin;

--
-- Name: doc_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.doc_categories_id_seq OWNED BY public.doc_categories.id;


--
-- Name: doc_employee_files; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.doc_employee_files (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    category_id bigint NOT NULL,
    document_name character varying(200) NOT NULL,
    document_no character varying(100),
    file_path text NOT NULL,
    file_size_kb integer,
    file_mime_type character varying(50),
    issued_date date,
    expiry_date date,
    issuing_authority character varying(200),
    version integer DEFAULT 1 NOT NULL,
    is_current boolean DEFAULT true NOT NULL,
    is_confidential boolean DEFAULT false NOT NULL,
    uploaded_by bigint,
    uploaded_at timestamp with time zone DEFAULT now() NOT NULL,
    remarks text
);


ALTER TABLE public.doc_employee_files OWNER TO hris_admin;

--
-- Name: doc_employee_files_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.doc_employee_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.doc_employee_files_id_seq OWNER TO hris_admin;

--
-- Name: doc_employee_files_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.doc_employee_files_id_seq OWNED BY public.doc_employee_files.id;


--
-- Name: doc_versions; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.doc_versions (
    id bigint NOT NULL,
    document_id bigint NOT NULL,
    version integer NOT NULL,
    file_path text NOT NULL,
    uploaded_by bigint,
    uploaded_at timestamp with time zone DEFAULT now() NOT NULL,
    change_notes text
);


ALTER TABLE public.doc_versions OWNER TO hris_admin;

--
-- Name: doc_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.doc_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.doc_versions_id_seq OWNER TO hris_admin;

--
-- Name: doc_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.doc_versions_id_seq OWNED BY public.doc_versions.id;


--
-- Name: dq_column_stats; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.dq_column_stats (
    id bigint NOT NULL,
    table_name character varying(100) NOT NULL,
    column_name character varying(100) NOT NULL,
    company_id bigint,
    stats_date date DEFAULT CURRENT_DATE NOT NULL,
    row_count bigint,
    null_count bigint,
    null_pct numeric(7,4),
    distinct_count bigint,
    min_value text,
    max_value text,
    mean_value numeric(20,6),
    std_dev numeric(20,6),
    p25 numeric(20,6),
    p50 numeric(20,6),
    p75 numeric(20,6),
    top_values jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.dq_column_stats OWNER TO hris_admin;

--
-- Name: dq_column_stats_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.dq_column_stats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dq_column_stats_id_seq OWNER TO hris_admin;

--
-- Name: dq_column_stats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.dq_column_stats_id_seq OWNED BY public.dq_column_stats.id;


--
-- Name: dq_data_issues; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.dq_data_issues (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    table_name character varying(100) NOT NULL,
    column_name character varying(100),
    row_id bigint,
    issue_type character varying(50) NOT NULL,
    description text NOT NULL,
    severity character varying(20) DEFAULT 'WARNING'::character varying NOT NULL,
    status character varying(20) DEFAULT 'OPEN'::character varying NOT NULL,
    auto_fixable boolean DEFAULT false NOT NULL,
    fix_applied boolean DEFAULT false NOT NULL,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.dq_data_issues OWNER TO hris_admin;

--
-- Name: dq_data_issues_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.dq_data_issues_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dq_data_issues_id_seq OWNER TO hris_admin;

--
-- Name: dq_data_issues_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.dq_data_issues_id_seq OWNED BY public.dq_data_issues.id;


--
-- Name: dynamic_forms; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.dynamic_forms (
    id integer NOT NULL,
    form_name character varying(120) NOT NULL,
    module_code character varying(60) NOT NULL,
    description text
);


ALTER TABLE public.dynamic_forms OWNER TO hris_admin;

--
-- Name: dynamic_forms_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.dynamic_forms_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.dynamic_forms_id_seq OWNER TO hris_admin;

--
-- Name: dynamic_forms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.dynamic_forms_id_seq OWNED BY public.dynamic_forms.id;


--
-- Name: emp_addresses; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.emp_addresses (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    address_type character varying(30) NOT NULL,
    line1 text NOT NULL,
    line2 text,
    barangay character varying(100),
    city character varying(100),
    province character varying(100),
    region character varying(100),
    zip_code character varying(10),
    country character varying(100) DEFAULT 'Philippines'::character varying NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.emp_addresses OWNER TO hris_admin;

--
-- Name: emp_addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.emp_addresses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.emp_addresses_id_seq OWNER TO hris_admin;

--
-- Name: emp_addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.emp_addresses_id_seq OWNED BY public.emp_addresses.id;


--
-- Name: emp_bank_accounts; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.emp_bank_accounts (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    bank_name character varying(100) NOT NULL,
    bank_code character varying(20),
    account_name character varying(200) NOT NULL,
    account_number character varying(50) NOT NULL,
    account_type character varying(30) DEFAULT 'SAVINGS'::character varying NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.emp_bank_accounts OWNER TO hris_admin;

--
-- Name: emp_bank_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.emp_bank_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.emp_bank_accounts_id_seq OWNER TO hris_admin;

--
-- Name: emp_bank_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.emp_bank_accounts_id_seq OWNED BY public.emp_bank_accounts.id;


--
-- Name: emp_dependents; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.emp_dependents (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    full_name character varying(200) NOT NULL,
    relationship character varying(50) NOT NULL,
    date_of_birth date,
    is_beneficiary boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.emp_dependents OWNER TO hris_admin;

--
-- Name: emp_dependents_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.emp_dependents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.emp_dependents_id_seq OWNER TO hris_admin;

--
-- Name: emp_dependents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.emp_dependents_id_seq OWNED BY public.emp_dependents.id;


--
-- Name: emp_education; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.emp_education (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    level character varying(50) NOT NULL,
    institution character varying(200) NOT NULL,
    degree character varying(200),
    field_of_study character varying(200),
    year_from integer,
    year_to integer,
    honors character varying(100),
    is_highest boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.emp_education OWNER TO hris_admin;

--
-- Name: emp_education_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.emp_education_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.emp_education_id_seq OWNER TO hris_admin;

--
-- Name: emp_education_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.emp_education_id_seq OWNED BY public.emp_education.id;


--
-- Name: emp_emergency_contacts; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.emp_emergency_contacts (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    full_name character varying(200) NOT NULL,
    relationship character varying(50) NOT NULL,
    mobile_no character varying(20),
    phone_no character varying(20),
    address text,
    is_primary boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.emp_emergency_contacts OWNER TO hris_admin;

--
-- Name: emp_emergency_contacts_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.emp_emergency_contacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.emp_emergency_contacts_id_seq OWNER TO hris_admin;

--
-- Name: emp_emergency_contacts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.emp_emergency_contacts_id_seq OWNED BY public.emp_emergency_contacts.id;


--
-- Name: emp_government_ids; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.emp_government_ids (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    id_type character varying(30) NOT NULL,
    id_number character varying(50) NOT NULL,
    issue_date date,
    expiry_date date,
    file_path text,
    is_verified boolean DEFAULT false NOT NULL,
    verified_by bigint,
    verified_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.emp_government_ids OWNER TO hris_admin;

--
-- Name: emp_government_ids_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.emp_government_ids_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.emp_government_ids_id_seq OWNER TO hris_admin;

--
-- Name: emp_government_ids_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.emp_government_ids_id_seq OWNED BY public.emp_government_ids.id;


--
-- Name: emp_status_history; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.emp_status_history (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    from_status character varying(30),
    to_status character varying(30) NOT NULL,
    effective_date date NOT NULL,
    reason text,
    remarks text,
    changed_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.emp_status_history OWNER TO hris_admin;

--
-- Name: emp_status_history_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.emp_status_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.emp_status_history_id_seq OWNER TO hris_admin;

--
-- Name: emp_status_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.emp_status_history_id_seq OWNED BY public.emp_status_history.id;


--
-- Name: emp_work_history; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.emp_work_history (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    company_name character varying(200) NOT NULL,
    position_held character varying(200),
    date_from date,
    date_to date,
    reason_for_leaving text,
    immediate_supervisor character varying(200),
    contact_no character varying(30),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.emp_work_history OWNER TO hris_admin;

--
-- Name: emp_work_history_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.emp_work_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.emp_work_history_id_seq OWNER TO hris_admin;

--
-- Name: emp_work_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.emp_work_history_id_seq OWNED BY public.emp_work_history.id;


--
-- Name: employee_documents; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.employee_documents (
    id integer NOT NULL,
    employee_id integer,
    document_name character varying(120) NOT NULL,
    is_missing boolean DEFAULT false
);


ALTER TABLE public.employee_documents OWNER TO hris_admin;

--
-- Name: employee_documents_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.employee_documents_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.employee_documents_id_seq OWNER TO hris_admin;

--
-- Name: employee_documents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.employee_documents_id_seq OWNED BY public.employee_documents.id;


--
-- Name: employees; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.employees (
    id integer NOT NULL,
    employee_no character varying(30) NOT NULL,
    first_name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    department_id integer,
    position_id integer,
    status_id integer
);


ALTER TABLE public.employees OWNER TO hris_admin;

--
-- Name: employees_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.employees_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.employees_id_seq OWNER TO hris_admin;

--
-- Name: employees_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.employees_id_seq OWNED BY public.employees.id;


--
-- Name: employment_types; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.employment_types (
    id bigint NOT NULL,
    code character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    is_entitled_benefits boolean DEFAULT true NOT NULL,
    probation_days integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.employment_types OWNER TO hris_admin;

--
-- Name: employment_types_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.employment_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.employment_types_id_seq OWNER TO hris_admin;

--
-- Name: employment_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.employment_types_id_seq OWNED BY public.employment_types.id;


--
-- Name: fact_attendance; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.fact_attendance (
    id bigint NOT NULL,
    date_key integer NOT NULL,
    employee_surrogate bigint,
    employee_id bigint NOT NULL,
    company_id bigint NOT NULL,
    department_id bigint,
    position_id bigint,
    shift_id bigint,
    status character varying(20),
    work_arrangement character varying(20),
    is_holiday boolean DEFAULT false NOT NULL,
    is_restday boolean DEFAULT false NOT NULL,
    hours_worked numeric(5,2) DEFAULT 0 NOT NULL,
    hours_late numeric(5,2) DEFAULT 0 NOT NULL,
    hours_undertime numeric(5,2) DEFAULT 0 NOT NULL,
    hours_overtime numeric(5,2) DEFAULT 0 NOT NULL,
    hours_night_diff numeric(5,2) DEFAULT 0 NOT NULL,
    is_present smallint DEFAULT 0 NOT NULL,
    is_absent smallint DEFAULT 0 NOT NULL,
    is_late smallint DEFAULT 0 NOT NULL,
    is_half_day smallint DEFAULT 0 NOT NULL,
    is_on_leave smallint DEFAULT 0 NOT NULL,
    is_ob smallint DEFAULT 0 NOT NULL,
    loaded_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.fact_attendance OWNER TO hris_admin;

--
-- Name: fact_attendance_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.fact_attendance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fact_attendance_id_seq OWNER TO hris_admin;

--
-- Name: fact_attendance_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.fact_attendance_id_seq OWNED BY public.fact_attendance.id;


--
-- Name: fact_leave; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.fact_leave (
    id bigint NOT NULL,
    filed_date_key integer NOT NULL,
    from_date_key integer,
    employee_surrogate bigint,
    employee_id bigint NOT NULL,
    leave_request_id bigint NOT NULL,
    company_id bigint NOT NULL,
    department_id bigint,
    leave_type_id bigint,
    leave_type_code character varying(30),
    is_paid boolean,
    status character varying(20),
    days_requested numeric(4,1) DEFAULT 0 NOT NULL,
    days_approved numeric(4,1) DEFAULT 0 NOT NULL,
    approval_hours numeric(8,2),
    approval_levels smallint,
    loaded_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.fact_leave OWNER TO hris_admin;

--
-- Name: fact_leave_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.fact_leave_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fact_leave_id_seq OWNER TO hris_admin;

--
-- Name: fact_leave_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.fact_leave_id_seq OWNED BY public.fact_leave.id;


--
-- Name: fact_payroll; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.fact_payroll (
    id bigint NOT NULL,
    period_date_key integer NOT NULL,
    employee_surrogate bigint,
    employee_id bigint NOT NULL,
    run_id bigint NOT NULL,
    period_id bigint NOT NULL,
    company_id bigint NOT NULL,
    department_id bigint,
    position_id bigint,
    job_grade_id bigint,
    employment_type character varying(100),
    period_type character varying(20),
    worked_days numeric(5,2) DEFAULT 0 NOT NULL,
    absent_days numeric(5,2) DEFAULT 0 NOT NULL,
    ot_hours numeric(5,2) DEFAULT 0 NOT NULL,
    basic_pay numeric(14,2) DEFAULT 0 NOT NULL,
    ot_pay numeric(14,2) DEFAULT 0 NOT NULL,
    allowances_total numeric(14,2) DEFAULT 0 NOT NULL,
    gross_pay numeric(14,2) DEFAULT 0 NOT NULL,
    sss_ee numeric(10,2) DEFAULT 0 NOT NULL,
    philhealth_ee numeric(10,2) DEFAULT 0 NOT NULL,
    pagibig_ee numeric(10,2) DEFAULT 0 NOT NULL,
    withholding_tax numeric(10,2) DEFAULT 0 NOT NULL,
    total_deductions numeric(14,2) DEFAULT 0 NOT NULL,
    net_pay numeric(14,2) DEFAULT 0 NOT NULL,
    total_employer_cost numeric(14,2) DEFAULT 0 NOT NULL,
    loaded_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.fact_payroll OWNER TO hris_admin;

--
-- Name: fact_payroll_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.fact_payroll_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fact_payroll_id_seq OWNER TO hris_admin;

--
-- Name: fact_payroll_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.fact_payroll_id_seq OWNED BY public.fact_payroll.id;


--
-- Name: fact_performance; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.fact_performance (
    id bigint NOT NULL,
    review_date_key integer,
    employee_surrogate bigint,
    employee_id bigint NOT NULL,
    reviewer_id bigint NOT NULL,
    review_id bigint NOT NULL,
    cycle_id bigint NOT NULL,
    company_id bigint NOT NULL,
    department_id bigint,
    position_id bigint,
    cycle_type character varying(20),
    review_type character varying(20),
    overall_rating numeric(4,2),
    calibrated_rating numeric(4,2),
    kpi_count integer,
    kpis_met integer,
    kpis_exceeded integer,
    kpis_missed integer,
    loaded_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.fact_performance OWNER TO hris_admin;

--
-- Name: fact_performance_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.fact_performance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fact_performance_id_seq OWNER TO hris_admin;

--
-- Name: fact_performance_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.fact_performance_id_seq OWNED BY public.fact_performance.id;


--
-- Name: fact_recruitment; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.fact_recruitment (
    id bigint NOT NULL,
    applied_date_key integer,
    applicant_id bigint NOT NULL,
    posting_id bigint NOT NULL,
    company_id bigint NOT NULL,
    department_id bigint,
    position_id bigint,
    employment_type character varying(100),
    source character varying(50),
    final_stage character varying(30),
    was_hired boolean DEFAULT false NOT NULL,
    days_applied_to_screening integer,
    days_applied_to_offer integer,
    days_applied_to_hired integer,
    expected_salary numeric(14,2),
    offered_salary numeric(14,2),
    loaded_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.fact_recruitment OWNER TO hris_admin;

--
-- Name: fact_recruitment_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.fact_recruitment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fact_recruitment_id_seq OWNER TO hris_admin;

--
-- Name: fact_recruitment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.fact_recruitment_id_seq OWNED BY public.fact_recruitment.id;


--
-- Name: feature_registry; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.feature_registry (
    id integer NOT NULL,
    feature_code character varying(60) NOT NULL,
    feature_label character varying(120) NOT NULL,
    feature_type character varying(40) NOT NULL,
    sort_order integer DEFAULT 0,
    is_active boolean DEFAULT true
);


ALTER TABLE public.feature_registry OWNER TO hris_admin;

--
-- Name: feature_registry_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.feature_registry_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.feature_registry_id_seq OWNER TO hris_admin;

--
-- Name: feature_registry_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.feature_registry_id_seq OWNED BY public.feature_registry.id;


--
-- Name: form_fields; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.form_fields (
    id integer NOT NULL,
    dynamic_form_id integer,
    field_label character varying(120) NOT NULL,
    field_name character varying(80) NOT NULL,
    field_type character varying(40) NOT NULL,
    field_order integer DEFAULT 0,
    is_required boolean DEFAULT false,
    data_source character varying(120)
);


ALTER TABLE public.form_fields OWNER TO hris_admin;

--
-- Name: form_fields_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.form_fields_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.form_fields_id_seq OWNER TO hris_admin;

--
-- Name: form_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.form_fields_id_seq OWNED BY public.form_fields.id;


--
-- Name: instance_checklist_items; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.instance_checklist_items (
    id integer NOT NULL,
    instance_id integer,
    workflow_checklist_item_id integer,
    is_completed boolean DEFAULT false
);


ALTER TABLE public.instance_checklist_items OWNER TO hris_admin;

--
-- Name: instance_checklist_items_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.instance_checklist_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.instance_checklist_items_id_seq OWNER TO hris_admin;

--
-- Name: instance_checklist_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.instance_checklist_items_id_seq OWNED BY public.instance_checklist_items.id;


--
-- Name: job_grades; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.job_grades (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
    grade_level integer NOT NULL,
    salary_min numeric(14,2),
    salary_max numeric(14,2),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.job_grades OWNER TO hris_admin;

--
-- Name: job_grades_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.job_grades_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.job_grades_id_seq OWNER TO hris_admin;

--
-- Name: job_grades_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.job_grades_id_seq OWNED BY public.job_grades.id;


--
-- Name: kpi_query_registry; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.kpi_query_registry (
    id integer NOT NULL,
    kpi_code character varying(60) NOT NULL,
    kpi_label character varying(120) NOT NULL,
    sql_key character varying(80) NOT NULL,
    description text
);


ALTER TABLE public.kpi_query_registry OWNER TO hris_admin;

--
-- Name: kpi_query_registry_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.kpi_query_registry_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.kpi_query_registry_id_seq OWNER TO hris_admin;

--
-- Name: kpi_query_registry_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.kpi_query_registry_id_seq OWNED BY public.kpi_query_registry.id;


--
-- Name: lv_approvals; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.lv_approvals (
    id bigint NOT NULL,
    request_id bigint NOT NULL,
    approval_level integer DEFAULT 1 NOT NULL,
    approver_id bigint NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    remarks text,
    acted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.lv_approvals OWNER TO hris_admin;

--
-- Name: lv_approvals_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.lv_approvals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lv_approvals_id_seq OWNER TO hris_admin;

--
-- Name: lv_approvals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.lv_approvals_id_seq OWNED BY public.lv_approvals.id;


--
-- Name: lv_balances; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.lv_balances (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    leave_type_id bigint NOT NULL,
    year integer NOT NULL,
    entitled_days numeric(5,1) DEFAULT 0 NOT NULL,
    accrued_days numeric(5,1) DEFAULT 0 NOT NULL,
    used_days numeric(5,1) DEFAULT 0 NOT NULL,
    pending_days numeric(5,1) DEFAULT 0 NOT NULL,
    carried_over numeric(5,1) DEFAULT 0 NOT NULL,
    forfeited_days numeric(5,1) DEFAULT 0 NOT NULL,
    balance numeric(5,1) GENERATED ALWAYS AS ((((accrued_days + carried_over) - used_days) - pending_days)) STORED,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.lv_balances OWNER TO hris_admin;

--
-- Name: lv_balances_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.lv_balances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lv_balances_id_seq OWNER TO hris_admin;

--
-- Name: lv_balances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.lv_balances_id_seq OWNED BY public.lv_balances.id;


--
-- Name: lv_ledger; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.lv_ledger (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    leave_type_id bigint NOT NULL,
    year integer NOT NULL,
    transaction_type character varying(30) NOT NULL,
    days numeric(5,1) NOT NULL,
    reference_id bigint,
    reference_type character varying(30),
    remarks text,
    created_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.lv_ledger OWNER TO hris_admin;

--
-- Name: lv_ledger_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.lv_ledger_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lv_ledger_id_seq OWNER TO hris_admin;

--
-- Name: lv_ledger_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.lv_ledger_id_seq OWNED BY public.lv_ledger.id;


--
-- Name: lv_policies; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.lv_policies (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    leave_type_id bigint NOT NULL,
    employment_type_id bigint,
    annual_days numeric(5,1) NOT NULL,
    accrual_type character varying(20) DEFAULT 'ANNUAL'::character varying NOT NULL,
    carry_over_allowed boolean DEFAULT false NOT NULL,
    carry_over_max_days numeric(5,1) DEFAULT 0 NOT NULL,
    monetization_allowed boolean DEFAULT false NOT NULL,
    months_before_entitled integer DEFAULT 0 NOT NULL,
    effective_from date,
    effective_to date,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.lv_policies OWNER TO hris_admin;

--
-- Name: lv_policies_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.lv_policies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lv_policies_id_seq OWNER TO hris_admin;

--
-- Name: lv_policies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.lv_policies_id_seq OWNED BY public.lv_policies.id;


--
-- Name: lv_requests; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.lv_requests (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    leave_type_id bigint NOT NULL,
    date_from date NOT NULL,
    date_to date NOT NULL,
    days_requested numeric(4,1) NOT NULL,
    reason text,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    is_half_day boolean DEFAULT false NOT NULL,
    half_day_type character varying(5),
    document_path text,
    filed_at timestamp with time zone DEFAULT now() NOT NULL,
    return_date date,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.lv_requests OWNER TO hris_admin;

--
-- Name: lv_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.lv_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lv_requests_id_seq OWNER TO hris_admin;

--
-- Name: lv_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.lv_requests_id_seq OWNED BY public.lv_requests.id;


--
-- Name: lv_types; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.lv_types (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    code character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    is_paid boolean DEFAULT true NOT NULL,
    requires_document boolean DEFAULT false NOT NULL,
    min_days numeric(4,1) DEFAULT 1 NOT NULL,
    max_days_per_filing numeric(4,1),
    notice_days_required integer DEFAULT 0 NOT NULL,
    gender_restriction character varying(10),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.lv_types OWNER TO hris_admin;

--
-- Name: lv_types_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.lv_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lv_types_id_seq OWNER TO hris_admin;

--
-- Name: lv_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.lv_types_id_seq OWNED BY public.lv_types.id;


--
-- Name: ml_feature_catalog; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.ml_feature_catalog (
    id bigint NOT NULL,
    feature_code character varying(100) NOT NULL,
    feature_name character varying(200) NOT NULL,
    description text,
    entity_type character varying(50) DEFAULT 'EMPLOYEE'::character varying NOT NULL,
    data_type character varying(30) NOT NULL,
    source_module character varying(50) NOT NULL,
    sql_expression text,
    default_value character varying(100),
    is_nullable boolean DEFAULT true NOT NULL,
    importance_score numeric(5,4),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.ml_feature_catalog OWNER TO hris_admin;

--
-- Name: ml_feature_catalog_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.ml_feature_catalog_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ml_feature_catalog_id_seq OWNER TO hris_admin;

--
-- Name: ml_feature_catalog_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.ml_feature_catalog_id_seq OWNED BY public.ml_feature_catalog.id;


--
-- Name: ml_model_monitoring; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.ml_model_monitoring (
    id bigint NOT NULL,
    model_version_id bigint NOT NULL,
    evaluation_date date NOT NULL,
    sample_count integer,
    accuracy numeric(7,4),
    auc_roc numeric(7,4),
    f1_score numeric(7,4),
    psi_score numeric(7,4),
    drift_detected boolean DEFAULT false NOT NULL,
    alert_sent boolean DEFAULT false NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.ml_model_monitoring OWNER TO hris_admin;

--
-- Name: ml_model_monitoring_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.ml_model_monitoring_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ml_model_monitoring_id_seq OWNER TO hris_admin;

--
-- Name: ml_model_monitoring_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.ml_model_monitoring_id_seq OWNED BY public.ml_model_monitoring.id;


--
-- Name: ml_model_versions; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.ml_model_versions (
    id bigint NOT NULL,
    model_id bigint NOT NULL,
    version_tag character varying(30) NOT NULL,
    dataset_id bigint,
    algorithm character varying(100),
    framework character varying(50),
    hyperparameters jsonb DEFAULT '{}'::jsonb NOT NULL,
    train_accuracy numeric(7,4),
    val_accuracy numeric(7,4),
    test_accuracy numeric(7,4),
    auc_roc numeric(7,4),
    f1_score numeric(7,4),
    precision_score numeric(7,4),
    recall_score numeric(7,4),
    rmse numeric(12,4),
    feature_importance jsonb DEFAULT '{}'::jsonb NOT NULL,
    status character varying(20) DEFAULT 'CANDIDATE'::character varying NOT NULL,
    model_path text,
    deployed_at timestamp with time zone,
    deployed_by character varying(100),
    retired_at timestamp with time zone,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.ml_model_versions OWNER TO hris_admin;

--
-- Name: ml_model_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.ml_model_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ml_model_versions_id_seq OWNER TO hris_admin;

--
-- Name: ml_model_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.ml_model_versions_id_seq OWNED BY public.ml_model_versions.id;


--
-- Name: ml_models; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.ml_models (
    id bigint NOT NULL,
    model_code character varying(100) NOT NULL,
    name character varying(200) NOT NULL,
    description text,
    model_type character varying(50) NOT NULL,
    use_case character varying(100) NOT NULL,
    target_entity character varying(50) DEFAULT 'EMPLOYEE'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.ml_models OWNER TO hris_admin;

--
-- Name: ml_models_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.ml_models_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ml_models_id_seq OWNER TO hris_admin;

--
-- Name: ml_models_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.ml_models_id_seq OWNED BY public.ml_models.id;


--
-- Name: ml_training_datasets; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.ml_training_datasets (
    id bigint NOT NULL,
    dataset_code character varying(100) NOT NULL,
    model_target character varying(100) NOT NULL,
    feature_set_version character varying(20) NOT NULL,
    snapshot_from date NOT NULL,
    snapshot_to date NOT NULL,
    total_samples integer,
    positive_samples integer,
    negative_samples integer,
    class_balance numeric(5,4),
    split_config jsonb DEFAULT '{}'::jsonb NOT NULL,
    storage_path text,
    created_by character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.ml_training_datasets OWNER TO hris_admin;

--
-- Name: ml_training_datasets_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.ml_training_datasets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ml_training_datasets_id_seq OWNER TO hris_admin;

--
-- Name: ml_training_datasets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.ml_training_datasets_id_seq OWNED BY public.ml_training_datasets.id;


--
-- Name: mv_payroll_cost_monthly; Type: MATERIALIZED VIEW; Schema: public; Owner: hris_admin
--

CREATE MATERIALIZED VIEW public.mv_payroll_cost_monthly AS
 SELECT fp.company_id,
    fp.department_id,
    de.department_name,
    fp.employment_type,
    fp.period_type,
    dd.year,
    dd.month_number,
    dd.month_name,
    count(DISTINCT fp.employee_id) AS employee_count,
    sum(fp.basic_pay) AS total_basic,
    sum(fp.allowances_total) AS total_allowances,
    sum(fp.ot_pay) AS total_ot_pay,
    sum(fp.gross_pay) AS total_gross,
    sum(fp.total_deductions) AS total_deductions,
    sum(fp.net_pay) AS total_net,
    sum(fp.total_employer_cost) AS total_employer_cost,
    avg(fp.gross_pay) AS avg_gross_per_employee,
    avg(fp.net_pay) AS avg_net_per_employee
   FROM ((public.fact_payroll fp
     JOIN public.dim_date dd ON ((fp.period_date_key = dd.date_key)))
     JOIN public.dim_employee de ON ((fp.employee_surrogate = de.surrogate_key)))
  GROUP BY fp.company_id, fp.department_id, de.department_name, fp.employment_type, fp.period_type, dd.year, dd.month_number, dd.month_name
  WITH NO DATA;


ALTER TABLE public.mv_payroll_cost_monthly OWNER TO hris_admin;

--
-- Name: ntf_notifications; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.ntf_notifications (
    id bigint NOT NULL,
    template_id bigint,
    recipient_user_id bigint,
    recipient_employee_id bigint,
    channel character varying(20) NOT NULL,
    subject character varying(300),
    body text NOT NULL,
    reference_type character varying(50),
    reference_id bigint,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    sent_at timestamp with time zone,
    read_at timestamp with time zone,
    error_message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
)
PARTITION BY RANGE (created_at);


ALTER TABLE public.ntf_notifications OWNER TO hris_admin;

--
-- Name: ntf_notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.ntf_notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ntf_notifications_id_seq OWNER TO hris_admin;

--
-- Name: ntf_notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.ntf_notifications_id_seq OWNED BY public.ntf_notifications.id;


--
-- Name: ntf_notifications_2025; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.ntf_notifications_2025 (
    id bigint DEFAULT nextval('public.ntf_notifications_id_seq'::regclass) NOT NULL,
    template_id bigint,
    recipient_user_id bigint,
    recipient_employee_id bigint,
    channel character varying(20) NOT NULL,
    subject character varying(300),
    body text NOT NULL,
    reference_type character varying(50),
    reference_id bigint,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    sent_at timestamp with time zone,
    read_at timestamp with time zone,
    error_message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.ntf_notifications_2025 OWNER TO hris_admin;

--
-- Name: ntf_notifications_2026; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.ntf_notifications_2026 (
    id bigint DEFAULT nextval('public.ntf_notifications_id_seq'::regclass) NOT NULL,
    template_id bigint,
    recipient_user_id bigint,
    recipient_employee_id bigint,
    channel character varying(20) NOT NULL,
    subject character varying(300),
    body text NOT NULL,
    reference_type character varying(50),
    reference_id bigint,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    sent_at timestamp with time zone,
    read_at timestamp with time zone,
    error_message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.ntf_notifications_2026 OWNER TO hris_admin;

--
-- Name: ntf_notifications_2027; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.ntf_notifications_2027 (
    id bigint DEFAULT nextval('public.ntf_notifications_id_seq'::regclass) NOT NULL,
    template_id bigint,
    recipient_user_id bigint,
    recipient_employee_id bigint,
    channel character varying(20) NOT NULL,
    subject character varying(300),
    body text NOT NULL,
    reference_type character varying(50),
    reference_id bigint,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    sent_at timestamp with time zone,
    read_at timestamp with time zone,
    error_message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.ntf_notifications_2027 OWNER TO hris_admin;

--
-- Name: ntf_notifications_2028; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.ntf_notifications_2028 (
    id bigint DEFAULT nextval('public.ntf_notifications_id_seq'::regclass) NOT NULL,
    template_id bigint,
    recipient_user_id bigint,
    recipient_employee_id bigint,
    channel character varying(20) NOT NULL,
    subject character varying(300),
    body text NOT NULL,
    reference_type character varying(50),
    reference_id bigint,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    sent_at timestamp with time zone,
    read_at timestamp with time zone,
    error_message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.ntf_notifications_2028 OWNER TO hris_admin;

--
-- Name: ntf_templates; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.ntf_templates (
    id bigint NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(200) NOT NULL,
    channel character varying(20) NOT NULL,
    subject character varying(300),
    body_template text NOT NULL,
    trigger_event character varying(100),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.ntf_templates OWNER TO hris_admin;

--
-- Name: ntf_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.ntf_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ntf_templates_id_seq OWNER TO hris_admin;

--
-- Name: ntf_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.ntf_templates_id_seq OWNED BY public.ntf_templates.id;


--
-- Name: orchestration_flows; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.orchestration_flows (
    id integer NOT NULL,
    flow_name character varying(120) NOT NULL,
    trigger_module character varying(60) NOT NULL,
    flow_status character varying(40) NOT NULL
);


ALTER TABLE public.orchestration_flows OWNER TO hris_admin;

--
-- Name: orchestration_flows_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.orchestration_flows_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.orchestration_flows_id_seq OWNER TO hris_admin;

--
-- Name: orchestration_flows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.orchestration_flows_id_seq OWNED BY public.orchestration_flows.id;


--
-- Name: orchestration_steps; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.orchestration_steps (
    id integer NOT NULL,
    orchestration_flow_id integer,
    step_order integer NOT NULL,
    target_module character varying(60) NOT NULL,
    action_type character varying(60) NOT NULL
);


ALTER TABLE public.orchestration_steps OWNER TO hris_admin;

--
-- Name: orchestration_steps_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.orchestration_steps_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.orchestration_steps_id_seq OWNER TO hris_admin;

--
-- Name: orchestration_steps_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.orchestration_steps_id_seq OWNED BY public.orchestration_steps.id;


--
-- Name: page_registry; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.page_registry (
    id integer NOT NULL,
    page_code character varying(60) NOT NULL,
    label character varying(120) NOT NULL,
    route_url character varying(255) NOT NULL,
    sort_order integer DEFAULT 0,
    is_active boolean DEFAULT true
);


ALTER TABLE public.page_registry OWNER TO hris_admin;

--
-- Name: page_registry_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.page_registry_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.page_registry_id_seq OWNER TO hris_admin;

--
-- Name: page_registry_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.page_registry_id_seq OWNED BY public.page_registry.id;


--
-- Name: pay_13th_month; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.pay_13th_month (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    employee_id bigint NOT NULL,
    year integer NOT NULL,
    jan_basic numeric(14,2) DEFAULT 0 NOT NULL,
    feb_basic numeric(14,2) DEFAULT 0 NOT NULL,
    mar_basic numeric(14,2) DEFAULT 0 NOT NULL,
    apr_basic numeric(14,2) DEFAULT 0 NOT NULL,
    may_basic numeric(14,2) DEFAULT 0 NOT NULL,
    jun_basic numeric(14,2) DEFAULT 0 NOT NULL,
    jul_basic numeric(14,2) DEFAULT 0 NOT NULL,
    aug_basic numeric(14,2) DEFAULT 0 NOT NULL,
    sep_basic numeric(14,2) DEFAULT 0 NOT NULL,
    oct_basic numeric(14,2) DEFAULT 0 NOT NULL,
    nov_basic numeric(14,2) DEFAULT 0 NOT NULL,
    total_basic numeric(14,2) DEFAULT 0 NOT NULL,
    months_worked numeric(4,1) DEFAULT 0 NOT NULL,
    thirteenth_month_pay numeric(14,2) DEFAULT 0 NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    released_on date,
    released_via_run_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.pay_13th_month OWNER TO hris_admin;

--
-- Name: pay_13th_month_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.pay_13th_month_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pay_13th_month_id_seq OWNER TO hris_admin;

--
-- Name: pay_13th_month_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.pay_13th_month_id_seq OWNED BY public.pay_13th_month.id;


--
-- Name: pay_bir_tax_table; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.pay_bir_tax_table (
    id bigint NOT NULL,
    effective_date date NOT NULL,
    frequency character varying(20) NOT NULL,
    income_from numeric(14,2) NOT NULL,
    income_to numeric(14,2),
    base_tax numeric(14,2) DEFAULT 0 NOT NULL,
    excess_rate numeric(8,4) DEFAULT 0 NOT NULL,
    excess_over numeric(14,2) DEFAULT 0 NOT NULL
);


ALTER TABLE public.pay_bir_tax_table OWNER TO hris_admin;

--
-- Name: pay_bir_tax_table_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.pay_bir_tax_table_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pay_bir_tax_table_id_seq OWNER TO hris_admin;

--
-- Name: pay_bir_tax_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.pay_bir_tax_table_id_seq OWNED BY public.pay_bir_tax_table.id;


--
-- Name: pay_deductions_detail; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.pay_deductions_detail (
    id bigint NOT NULL,
    payroll_id bigint NOT NULL,
    deduction_type character varying(50) NOT NULL,
    description character varying(200),
    amount numeric(14,2) NOT NULL,
    reference_no character varying(100)
);


ALTER TABLE public.pay_deductions_detail OWNER TO hris_admin;

--
-- Name: pay_deductions_detail_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.pay_deductions_detail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pay_deductions_detail_id_seq OWNER TO hris_admin;

--
-- Name: pay_deductions_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.pay_deductions_detail_id_seq OWNED BY public.pay_deductions_detail.id;


--
-- Name: pay_earnings_detail; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.pay_earnings_detail (
    id bigint NOT NULL,
    payroll_id bigint NOT NULL,
    earning_type character varying(50) NOT NULL,
    description character varying(200),
    hours numeric(6,2),
    rate numeric(12,4),
    amount numeric(14,2) NOT NULL
);


ALTER TABLE public.pay_earnings_detail OWNER TO hris_admin;

--
-- Name: pay_earnings_detail_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.pay_earnings_detail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pay_earnings_detail_id_seq OWNER TO hris_admin;

--
-- Name: pay_earnings_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.pay_earnings_detail_id_seq OWNED BY public.pay_earnings_detail.id;


--
-- Name: pay_employee_allowances; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.pay_employee_allowances (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    allowance_type character varying(50) NOT NULL,
    amount numeric(12,2) NOT NULL,
    frequency character varying(20) DEFAULT 'MONTHLY'::character varying NOT NULL,
    taxable boolean DEFAULT false NOT NULL,
    effective_from date,
    effective_to date,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.pay_employee_allowances OWNER TO hris_admin;

--
-- Name: pay_employee_allowances_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.pay_employee_allowances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pay_employee_allowances_id_seq OWNER TO hris_admin;

--
-- Name: pay_employee_allowances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.pay_employee_allowances_id_seq OWNED BY public.pay_employee_allowances.id;


--
-- Name: pay_employee_loans; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.pay_employee_loans (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    loan_type character varying(50) NOT NULL,
    reference_no character varying(100),
    total_amount numeric(14,2) NOT NULL,
    outstanding_balance numeric(14,2) NOT NULL,
    monthly_amortization numeric(12,2) NOT NULL,
    start_date date NOT NULL,
    end_date date,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.pay_employee_loans OWNER TO hris_admin;

--
-- Name: pay_employee_loans_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.pay_employee_loans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pay_employee_loans_id_seq OWNER TO hris_admin;

--
-- Name: pay_employee_loans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.pay_employee_loans_id_seq OWNED BY public.pay_employee_loans.id;


--
-- Name: pay_employee_payroll; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.pay_employee_payroll (
    id bigint NOT NULL,
    run_id bigint NOT NULL,
    employee_id bigint NOT NULL,
    scheduled_days numeric(5,2) DEFAULT 0 NOT NULL,
    worked_days numeric(5,2) DEFAULT 0 NOT NULL,
    absent_days numeric(5,2) DEFAULT 0 NOT NULL,
    leave_days numeric(5,2) DEFAULT 0 NOT NULL,
    late_hours numeric(5,2) DEFAULT 0 NOT NULL,
    undertime_hours numeric(5,2) DEFAULT 0 NOT NULL,
    ot_regular_hours numeric(5,2) DEFAULT 0 NOT NULL,
    ot_restday_hours numeric(5,2) DEFAULT 0 NOT NULL,
    ot_holiday_hours numeric(5,2) DEFAULT 0 NOT NULL,
    night_diff_hours numeric(5,2) DEFAULT 0 NOT NULL,
    basic_pay numeric(14,2) DEFAULT 0 NOT NULL,
    ot_pay numeric(14,2) DEFAULT 0 NOT NULL,
    holiday_pay numeric(14,2) DEFAULT 0 NOT NULL,
    night_diff_pay numeric(14,2) DEFAULT 0 NOT NULL,
    allowances_total numeric(14,2) DEFAULT 0 NOT NULL,
    other_earnings numeric(14,2) DEFAULT 0 NOT NULL,
    gross_pay numeric(14,2) DEFAULT 0 NOT NULL,
    sss_ee numeric(10,2) DEFAULT 0 NOT NULL,
    philhealth_ee numeric(10,2) DEFAULT 0 NOT NULL,
    pagibig_ee numeric(10,2) DEFAULT 0 NOT NULL,
    withholding_tax numeric(10,2) DEFAULT 0 NOT NULL,
    late_deduction numeric(10,2) DEFAULT 0 NOT NULL,
    absent_deduction numeric(10,2) DEFAULT 0 NOT NULL,
    loan_deduction numeric(10,2) DEFAULT 0 NOT NULL,
    other_deductions numeric(10,2) DEFAULT 0 NOT NULL,
    total_deductions numeric(14,2) DEFAULT 0 NOT NULL,
    sss_er numeric(10,2) DEFAULT 0 NOT NULL,
    sss_ec numeric(10,2) DEFAULT 0 NOT NULL,
    philhealth_er numeric(10,2) DEFAULT 0 NOT NULL,
    pagibig_er numeric(10,2) DEFAULT 0 NOT NULL,
    net_pay numeric(14,2) DEFAULT 0 NOT NULL,
    status character varying(20) DEFAULT 'COMPUTED'::character varying NOT NULL,
    payslip_path text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.pay_employee_payroll OWNER TO hris_admin;

--
-- Name: pay_employee_payroll_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.pay_employee_payroll_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pay_employee_payroll_id_seq OWNER TO hris_admin;

--
-- Name: pay_employee_payroll_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.pay_employee_payroll_id_seq OWNED BY public.pay_employee_payroll.id;


--
-- Name: pay_pagibig_table; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.pay_pagibig_table (
    id bigint NOT NULL,
    effective_date date NOT NULL,
    salary_from numeric(12,2) NOT NULL,
    salary_to numeric(12,2),
    ee_rate numeric(6,4) NOT NULL,
    er_rate numeric(6,4) NOT NULL,
    max_monthly_compensation numeric(12,2)
);


ALTER TABLE public.pay_pagibig_table OWNER TO hris_admin;

--
-- Name: pay_pagibig_table_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.pay_pagibig_table_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pay_pagibig_table_id_seq OWNER TO hris_admin;

--
-- Name: pay_pagibig_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.pay_pagibig_table_id_seq OWNED BY public.pay_pagibig_table.id;


--
-- Name: pay_periods; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.pay_periods (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    period_code character varying(30) NOT NULL,
    period_type character varying(20) NOT NULL,
    date_from date NOT NULL,
    date_to date NOT NULL,
    payment_date date,
    status character varying(20) DEFAULT 'OPEN'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.pay_periods OWNER TO hris_admin;

--
-- Name: pay_periods_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.pay_periods_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pay_periods_id_seq OWNER TO hris_admin;

--
-- Name: pay_periods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.pay_periods_id_seq OWNED BY public.pay_periods.id;


--
-- Name: pay_philhealth_table; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.pay_philhealth_table (
    id bigint NOT NULL,
    effective_date date NOT NULL,
    salary_from numeric(12,2) NOT NULL,
    salary_to numeric(12,2),
    premium_rate numeric(6,4) NOT NULL,
    ee_share numeric(6,4) DEFAULT 0.50 NOT NULL,
    er_share numeric(6,4) DEFAULT 0.50 NOT NULL,
    min_premium numeric(10,2),
    max_premium numeric(10,2)
);


ALTER TABLE public.pay_philhealth_table OWNER TO hris_admin;

--
-- Name: pay_philhealth_table_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.pay_philhealth_table_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pay_philhealth_table_id_seq OWNER TO hris_admin;

--
-- Name: pay_philhealth_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.pay_philhealth_table_id_seq OWNED BY public.pay_philhealth_table.id;


--
-- Name: pay_runs; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.pay_runs (
    id bigint NOT NULL,
    period_id bigint NOT NULL,
    run_number integer DEFAULT 1 NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    total_employees integer DEFAULT 0 NOT NULL,
    total_gross numeric(16,2) DEFAULT 0 NOT NULL,
    total_deductions numeric(16,2) DEFAULT 0 NOT NULL,
    total_net numeric(16,2) DEFAULT 0 NOT NULL,
    computed_at timestamp with time zone,
    computed_by bigint,
    approved_at timestamp with time zone,
    approved_by bigint,
    posted_at timestamp with time zone,
    posted_by bigint,
    remarks text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.pay_runs OWNER TO hris_admin;

--
-- Name: pay_runs_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.pay_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pay_runs_id_seq OWNER TO hris_admin;

--
-- Name: pay_runs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.pay_runs_id_seq OWNED BY public.pay_runs.id;


--
-- Name: pay_sss_table; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.pay_sss_table (
    id bigint NOT NULL,
    effective_date date NOT NULL,
    salary_from numeric(12,2) NOT NULL,
    salary_to numeric(12,2),
    ee_contribution numeric(10,2) NOT NULL,
    er_contribution numeric(10,2) NOT NULL,
    ec_contribution numeric(10,2) DEFAULT 0 NOT NULL,
    total_contribution numeric(10,2) NOT NULL
);


ALTER TABLE public.pay_sss_table OWNER TO hris_admin;

--
-- Name: pay_sss_table_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.pay_sss_table_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pay_sss_table_id_seq OWNER TO hris_admin;

--
-- Name: pay_sss_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.pay_sss_table_id_seq OWNED BY public.pay_sss_table.id;


--
-- Name: perf_cycles; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.perf_cycles (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    name character varying(200) NOT NULL,
    cycle_type character varying(20) DEFAULT 'ANNUAL'::character varying NOT NULL,
    year integer NOT NULL,
    period integer,
    goal_setting_start date,
    goal_setting_end date,
    mid_review_start date,
    mid_review_end date,
    final_review_start date,
    final_review_end date,
    status character varying(20) DEFAULT 'PLANNING'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.perf_cycles OWNER TO hris_admin;

--
-- Name: perf_cycles_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.perf_cycles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.perf_cycles_id_seq OWNER TO hris_admin;

--
-- Name: perf_cycles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.perf_cycles_id_seq OWNED BY public.perf_cycles.id;


--
-- Name: perf_employee_kpis; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.perf_employee_kpis (
    id bigint NOT NULL,
    cycle_id bigint NOT NULL,
    employee_id bigint NOT NULL,
    kpi_id bigint NOT NULL,
    target_value numeric(14,4),
    target_description text,
    weight numeric(5,2) DEFAULT 0 NOT NULL,
    actual_value numeric(14,4),
    score numeric(5,2),
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.perf_employee_kpis OWNER TO hris_admin;

--
-- Name: perf_employee_kpis_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.perf_employee_kpis_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.perf_employee_kpis_id_seq OWNER TO hris_admin;

--
-- Name: perf_employee_kpis_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.perf_employee_kpis_id_seq OWNED BY public.perf_employee_kpis.id;


--
-- Name: perf_kpi_categories; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.perf_kpi_categories (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    code character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
    weight numeric(5,2) DEFAULT 0 NOT NULL
);


ALTER TABLE public.perf_kpi_categories OWNER TO hris_admin;

--
-- Name: perf_kpi_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.perf_kpi_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.perf_kpi_categories_id_seq OWNER TO hris_admin;

--
-- Name: perf_kpi_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.perf_kpi_categories_id_seq OWNED BY public.perf_kpi_categories.id;


--
-- Name: perf_kpis; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.perf_kpis (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    category_id bigint,
    code character varying(30) NOT NULL,
    name character varying(200) NOT NULL,
    description text,
    measurement_unit character varying(50),
    kpi_type character varying(20) DEFAULT 'QUANTITATIVE'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.perf_kpis OWNER TO hris_admin;

--
-- Name: perf_kpis_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.perf_kpis_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.perf_kpis_id_seq OWNER TO hris_admin;

--
-- Name: perf_kpis_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.perf_kpis_id_seq OWNED BY public.perf_kpis.id;


--
-- Name: perf_review_feedback; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.perf_review_feedback (
    id bigint NOT NULL,
    review_id bigint NOT NULL,
    feedback_type character varying(50) NOT NULL,
    authored_by character varying(20) NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.perf_review_feedback OWNER TO hris_admin;

--
-- Name: perf_review_feedback_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.perf_review_feedback_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.perf_review_feedback_id_seq OWNER TO hris_admin;

--
-- Name: perf_review_feedback_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.perf_review_feedback_id_seq OWNED BY public.perf_review_feedback.id;


--
-- Name: perf_review_ratings; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.perf_review_ratings (
    id bigint NOT NULL,
    review_id bigint NOT NULL,
    kpi_id bigint NOT NULL,
    self_rating numeric(4,2),
    manager_rating numeric(4,2),
    final_rating numeric(4,2),
    self_comments text,
    manager_comments text
);


ALTER TABLE public.perf_review_ratings OWNER TO hris_admin;

--
-- Name: perf_review_ratings_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.perf_review_ratings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.perf_review_ratings_id_seq OWNER TO hris_admin;

--
-- Name: perf_review_ratings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.perf_review_ratings_id_seq OWNED BY public.perf_review_ratings.id;


--
-- Name: perf_reviews; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.perf_reviews (
    id bigint NOT NULL,
    cycle_id bigint NOT NULL,
    employee_id bigint NOT NULL,
    reviewer_id bigint NOT NULL,
    review_type character varying(20) DEFAULT 'ANNUAL'::character varying NOT NULL,
    overall_rating numeric(4,2),
    rating_label character varying(50),
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    self_eval_submitted_at timestamp with time zone,
    reviewer_submitted_at timestamp with time zone,
    acknowledged_at timestamp with time zone,
    calibrated_rating numeric(4,2),
    calibration_remarks text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.perf_reviews OWNER TO hris_admin;

--
-- Name: perf_reviews_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.perf_reviews_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.perf_reviews_id_seq OWNER TO hris_admin;

--
-- Name: perf_reviews_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.perf_reviews_id_seq OWNED BY public.perf_reviews.id;


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.permissions (
    id bigint NOT NULL,
    module character varying(50) NOT NULL,
    resource character varying(100) NOT NULL,
    action character varying(50) NOT NULL,
    description text
);


ALTER TABLE public.permissions OWNER TO hris_admin;

--
-- Name: permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.permissions_id_seq OWNER TO hris_admin;

--
-- Name: permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.permissions_id_seq OWNED BY public.permissions.id;


--
-- Name: positions; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.positions (
    id integer NOT NULL,
    title character varying(120) NOT NULL
);


ALTER TABLE public.positions OWNER TO hris_admin;

--
-- Name: positions_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.positions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.positions_id_seq OWNER TO hris_admin;

--
-- Name: positions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.positions_id_seq OWNED BY public.positions.id;


--
-- Name: rec_applicants; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.rec_applicants (
    id bigint NOT NULL,
    posting_id bigint NOT NULL,
    first_name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    email character varying(200),
    mobile_no character varying(20),
    current_position character varying(200),
    current_company character varying(200),
    expected_salary numeric(14,2),
    resume_path text,
    source character varying(50),
    stage character varying(30) DEFAULT 'APPLIED'::character varying NOT NULL,
    hired_as_employee_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.rec_applicants OWNER TO hris_admin;

--
-- Name: rec_applicants_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.rec_applicants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.rec_applicants_id_seq OWNER TO hris_admin;

--
-- Name: rec_applicants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.rec_applicants_id_seq OWNED BY public.rec_applicants.id;


--
-- Name: rec_application_history; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.rec_application_history (
    id bigint NOT NULL,
    applicant_id bigint NOT NULL,
    from_stage character varying(30),
    to_stage character varying(30) NOT NULL,
    remarks text,
    changed_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.rec_application_history OWNER TO hris_admin;

--
-- Name: rec_application_history_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.rec_application_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.rec_application_history_id_seq OWNER TO hris_admin;

--
-- Name: rec_application_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.rec_application_history_id_seq OWNED BY public.rec_application_history.id;


--
-- Name: rec_job_postings; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.rec_job_postings (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    position_id bigint,
    department_id bigint,
    title character varying(200) NOT NULL,
    description text,
    requirements text,
    headcount integer DEFAULT 1 NOT NULL,
    employment_type_id bigint,
    salary_min numeric(14,2),
    salary_max numeric(14,2),
    posted_date date,
    closing_date date,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    posted_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.rec_job_postings OWNER TO hris_admin;

--
-- Name: rec_job_postings_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.rec_job_postings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.rec_job_postings_id_seq OWNER TO hris_admin;

--
-- Name: rec_job_postings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.rec_job_postings_id_seq OWNED BY public.rec_job_postings.id;


--
-- Name: role_feature_access; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.role_feature_access (
    id integer NOT NULL,
    role_code character varying(50) NOT NULL,
    feature_code character varying(60) NOT NULL,
    is_allowed boolean DEFAULT false
);


ALTER TABLE public.role_feature_access OWNER TO hris_admin;

--
-- Name: role_feature_access_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.role_feature_access_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.role_feature_access_id_seq OWNER TO hris_admin;

--
-- Name: role_feature_access_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.role_feature_access_id_seq OWNED BY public.role_feature_access.id;


--
-- Name: role_page_access; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.role_page_access (
    id integer NOT NULL,
    role_code character varying(50) NOT NULL,
    page_code character varying(60) NOT NULL,
    can_view boolean DEFAULT true
);


ALTER TABLE public.role_page_access OWNER TO hris_admin;

--
-- Name: role_page_access_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.role_page_access_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.role_page_access_id_seq OWNER TO hris_admin;

--
-- Name: role_page_access_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.role_page_access_id_seq OWNED BY public.role_page_access.id;


--
-- Name: role_permissions; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.role_permissions (
    id bigint NOT NULL,
    role_id bigint NOT NULL,
    permission_id bigint NOT NULL,
    granted boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.role_permissions OWNER TO hris_admin;

--
-- Name: role_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.role_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.role_permissions_id_seq OWNER TO hris_admin;

--
-- Name: role_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.role_permissions_id_seq OWNED BY public.role_permissions.id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.roles (
    id bigint NOT NULL,
    company_id bigint,
    code character varying(50) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    is_system_role boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.roles OWNER TO hris_admin;

--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.roles_id_seq OWNER TO hris_admin;

--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- Name: search_index; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.search_index (
    id integer NOT NULL,
    entity_type character varying(60) NOT NULL,
    entity_id integer NOT NULL,
    title character varying(255) NOT NULL,
    subtitle character varying(255),
    target_url character varying(255) NOT NULL,
    keywords text
);


ALTER TABLE public.search_index OWNER TO hris_admin;

--
-- Name: search_index_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.search_index_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.search_index_id_seq OWNER TO hris_admin;

--
-- Name: search_index_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.search_index_id_seq OWNED BY public.search_index.id;


--
-- Name: status_definitions; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.status_definitions (
    id integer NOT NULL,
    status_group character varying(60) NOT NULL,
    status_code character varying(60) NOT NULL,
    status_label character varying(120) NOT NULL,
    badge_color character varying(30),
    is_terminal boolean DEFAULT false,
    sort_order integer DEFAULT 0
);


ALTER TABLE public.status_definitions OWNER TO hris_admin;

--
-- Name: status_definitions_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.status_definitions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.status_definitions_id_seq OWNER TO hris_admin;

--
-- Name: status_definitions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.status_definitions_id_seq OWNED BY public.status_definitions.id;


--
-- Name: sys_audit_logs; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.sys_audit_logs (
    id bigint NOT NULL,
    company_id bigint,
    user_id bigint,
    employee_id bigint,
    module character varying(50) NOT NULL,
    action character varying(50) NOT NULL,
    resource_type character varying(100),
    resource_id bigint,
    old_values jsonb,
    new_values jsonb,
    ip_address inet,
    user_agent text,
    session_id character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
)
PARTITION BY RANGE (created_at);


ALTER TABLE public.sys_audit_logs OWNER TO hris_admin;

--
-- Name: sys_audit_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.sys_audit_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_audit_logs_id_seq OWNER TO hris_admin;

--
-- Name: sys_audit_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.sys_audit_logs_id_seq OWNED BY public.sys_audit_logs.id;


--
-- Name: sys_audit_logs_2025; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.sys_audit_logs_2025 (
    id bigint DEFAULT nextval('public.sys_audit_logs_id_seq'::regclass) NOT NULL,
    company_id bigint,
    user_id bigint,
    employee_id bigint,
    module character varying(50) NOT NULL,
    action character varying(50) NOT NULL,
    resource_type character varying(100),
    resource_id bigint,
    old_values jsonb,
    new_values jsonb,
    ip_address inet,
    user_agent text,
    session_id character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.sys_audit_logs_2025 OWNER TO hris_admin;

--
-- Name: sys_audit_logs_2026; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.sys_audit_logs_2026 (
    id bigint DEFAULT nextval('public.sys_audit_logs_id_seq'::regclass) NOT NULL,
    company_id bigint,
    user_id bigint,
    employee_id bigint,
    module character varying(50) NOT NULL,
    action character varying(50) NOT NULL,
    resource_type character varying(100),
    resource_id bigint,
    old_values jsonb,
    new_values jsonb,
    ip_address inet,
    user_agent text,
    session_id character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.sys_audit_logs_2026 OWNER TO hris_admin;

--
-- Name: sys_audit_logs_2027; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.sys_audit_logs_2027 (
    id bigint DEFAULT nextval('public.sys_audit_logs_id_seq'::regclass) NOT NULL,
    company_id bigint,
    user_id bigint,
    employee_id bigint,
    module character varying(50) NOT NULL,
    action character varying(50) NOT NULL,
    resource_type character varying(100),
    resource_id bigint,
    old_values jsonb,
    new_values jsonb,
    ip_address inet,
    user_agent text,
    session_id character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.sys_audit_logs_2027 OWNER TO hris_admin;

--
-- Name: sys_audit_logs_2028; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.sys_audit_logs_2028 (
    id bigint DEFAULT nextval('public.sys_audit_logs_id_seq'::regclass) NOT NULL,
    company_id bigint,
    user_id bigint,
    employee_id bigint,
    module character varying(50) NOT NULL,
    action character varying(50) NOT NULL,
    resource_type character varying(100),
    resource_id bigint,
    old_values jsonb,
    new_values jsonb,
    ip_address inet,
    user_agent text,
    session_id character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.sys_audit_logs_2028 OWNER TO hris_admin;

--
-- Name: sys_change_log; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.sys_change_log (
    id bigint NOT NULL,
    schema_name character varying(63) DEFAULT 'public'::character varying NOT NULL,
    table_name character varying(100) NOT NULL,
    operation character varying(10) NOT NULL,
    row_id bigint,
    row_uuid uuid,
    old_data jsonb,
    new_data jsonb,
    changed_fields text[],
    user_id bigint,
    company_id bigint,
    client_ip inet,
    session_id character varying(100),
    app_context character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
)
PARTITION BY RANGE (created_at);


ALTER TABLE public.sys_change_log OWNER TO hris_admin;

--
-- Name: sys_change_log_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.sys_change_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_change_log_id_seq OWNER TO hris_admin;

--
-- Name: sys_change_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.sys_change_log_id_seq OWNED BY public.sys_change_log.id;


--
-- Name: sys_change_log_2025; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.sys_change_log_2025 (
    id bigint DEFAULT nextval('public.sys_change_log_id_seq'::regclass) NOT NULL,
    schema_name character varying(63) DEFAULT 'public'::character varying NOT NULL,
    table_name character varying(100) NOT NULL,
    operation character varying(10) NOT NULL,
    row_id bigint,
    row_uuid uuid,
    old_data jsonb,
    new_data jsonb,
    changed_fields text[],
    user_id bigint,
    company_id bigint,
    client_ip inet,
    session_id character varying(100),
    app_context character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.sys_change_log_2025 OWNER TO hris_admin;

--
-- Name: sys_change_log_2026; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.sys_change_log_2026 (
    id bigint DEFAULT nextval('public.sys_change_log_id_seq'::regclass) NOT NULL,
    schema_name character varying(63) DEFAULT 'public'::character varying NOT NULL,
    table_name character varying(100) NOT NULL,
    operation character varying(10) NOT NULL,
    row_id bigint,
    row_uuid uuid,
    old_data jsonb,
    new_data jsonb,
    changed_fields text[],
    user_id bigint,
    company_id bigint,
    client_ip inet,
    session_id character varying(100),
    app_context character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.sys_change_log_2026 OWNER TO hris_admin;

--
-- Name: sys_change_log_2027; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.sys_change_log_2027 (
    id bigint DEFAULT nextval('public.sys_change_log_id_seq'::regclass) NOT NULL,
    schema_name character varying(63) DEFAULT 'public'::character varying NOT NULL,
    table_name character varying(100) NOT NULL,
    operation character varying(10) NOT NULL,
    row_id bigint,
    row_uuid uuid,
    old_data jsonb,
    new_data jsonb,
    changed_fields text[],
    user_id bigint,
    company_id bigint,
    client_ip inet,
    session_id character varying(100),
    app_context character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.sys_change_log_2027 OWNER TO hris_admin;

--
-- Name: sys_change_log_2028; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.sys_change_log_2028 (
    id bigint DEFAULT nextval('public.sys_change_log_id_seq'::regclass) NOT NULL,
    schema_name character varying(63) DEFAULT 'public'::character varying NOT NULL,
    table_name character varying(100) NOT NULL,
    operation character varying(10) NOT NULL,
    row_id bigint,
    row_uuid uuid,
    old_data jsonb,
    new_data jsonb,
    changed_fields text[],
    user_id bigint,
    company_id bigint,
    client_ip inet,
    session_id character varying(100),
    app_context character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.sys_change_log_2028 OWNER TO hris_admin;

--
-- Name: sys_compliance_reports; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.sys_compliance_reports (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    report_type character varying(50) NOT NULL,
    period_from date,
    period_to date,
    file_path text,
    status character varying(20) DEFAULT 'GENERATED'::character varying NOT NULL,
    generated_by bigint,
    generated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.sys_compliance_reports OWNER TO hris_admin;

--
-- Name: sys_compliance_reports_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.sys_compliance_reports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_compliance_reports_id_seq OWNER TO hris_admin;

--
-- Name: sys_compliance_reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.sys_compliance_reports_id_seq OWNED BY public.sys_compliance_reports.id;


--
-- Name: sys_field_changes; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.sys_field_changes (
    id bigint NOT NULL,
    change_log_id bigint NOT NULL,
    table_name character varying(100) NOT NULL,
    row_id bigint,
    field_name character varying(100) NOT NULL,
    old_value text,
    new_value text,
    data_type character varying(50),
    user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
)
PARTITION BY RANGE (created_at);


ALTER TABLE public.sys_field_changes OWNER TO hris_admin;

--
-- Name: sys_field_changes_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.sys_field_changes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_field_changes_id_seq OWNER TO hris_admin;

--
-- Name: sys_field_changes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.sys_field_changes_id_seq OWNED BY public.sys_field_changes.id;


--
-- Name: sys_field_changes_2025; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.sys_field_changes_2025 (
    id bigint DEFAULT nextval('public.sys_field_changes_id_seq'::regclass) NOT NULL,
    change_log_id bigint NOT NULL,
    table_name character varying(100) NOT NULL,
    row_id bigint,
    field_name character varying(100) NOT NULL,
    old_value text,
    new_value text,
    data_type character varying(50),
    user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.sys_field_changes_2025 OWNER TO hris_admin;

--
-- Name: sys_field_changes_2026; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.sys_field_changes_2026 (
    id bigint DEFAULT nextval('public.sys_field_changes_id_seq'::regclass) NOT NULL,
    change_log_id bigint NOT NULL,
    table_name character varying(100) NOT NULL,
    row_id bigint,
    field_name character varying(100) NOT NULL,
    old_value text,
    new_value text,
    data_type character varying(50),
    user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.sys_field_changes_2026 OWNER TO hris_admin;

--
-- Name: sys_field_changes_2027; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.sys_field_changes_2027 (
    id bigint DEFAULT nextval('public.sys_field_changes_id_seq'::regclass) NOT NULL,
    change_log_id bigint NOT NULL,
    table_name character varying(100) NOT NULL,
    row_id bigint,
    field_name character varying(100) NOT NULL,
    old_value text,
    new_value text,
    data_type character varying(50),
    user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.sys_field_changes_2027 OWNER TO hris_admin;

--
-- Name: sys_field_changes_2028; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.sys_field_changes_2028 (
    id bigint DEFAULT nextval('public.sys_field_changes_id_seq'::regclass) NOT NULL,
    change_log_id bigint NOT NULL,
    table_name character varying(100) NOT NULL,
    row_id bigint,
    field_name character varying(100) NOT NULL,
    old_value text,
    new_value text,
    data_type character varying(50),
    user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.sys_field_changes_2028 OWNER TO hris_admin;

--
-- Name: sys_integrations; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.sys_integrations (
    id bigint NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(200) NOT NULL,
    integration_type character varying(50) NOT NULL,
    endpoint_url character varying(500),
    auth_type character varying(30),
    config jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    last_sync_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.sys_integrations OWNER TO hris_admin;

--
-- Name: sys_integrations_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.sys_integrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_integrations_id_seq OWNER TO hris_admin;

--
-- Name: sys_integrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.sys_integrations_id_seq OWNED BY public.sys_integrations.id;


--
-- Name: sys_regulatory_deadlines; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.sys_regulatory_deadlines (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    agency character varying(50) NOT NULL,
    requirement character varying(200) NOT NULL,
    deadline_date date NOT NULL,
    frequency character varying(20) DEFAULT 'MONTHLY'::character varying NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    filed_at timestamp with time zone,
    filed_by bigint,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.sys_regulatory_deadlines OWNER TO hris_admin;

--
-- Name: sys_regulatory_deadlines_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.sys_regulatory_deadlines_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_regulatory_deadlines_id_seq OWNER TO hris_admin;

--
-- Name: sys_regulatory_deadlines_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.sys_regulatory_deadlines_id_seq OWNED BY public.sys_regulatory_deadlines.id;


--
-- Name: sys_sync_logs; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.sys_sync_logs (
    id bigint NOT NULL,
    integration_id bigint NOT NULL,
    sync_type character varying(50) NOT NULL,
    status character varying(20) NOT NULL,
    records_processed integer DEFAULT 0 NOT NULL,
    records_success integer DEFAULT 0 NOT NULL,
    records_failed integer DEFAULT 0 NOT NULL,
    error_summary text,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone
);


ALTER TABLE public.sys_sync_logs OWNER TO hris_admin;

--
-- Name: sys_sync_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.sys_sync_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_sync_logs_id_seq OWNER TO hris_admin;

--
-- Name: sys_sync_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.sys_sync_logs_id_seq OWNED BY public.sys_sync_logs.id;


--
-- Name: transaction_qr_tokens; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.transaction_qr_tokens (
    id integer NOT NULL,
    transaction_id integer,
    public_token character varying(80) NOT NULL
);


ALTER TABLE public.transaction_qr_tokens OWNER TO hris_admin;

--
-- Name: transaction_qr_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.transaction_qr_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.transaction_qr_tokens_id_seq OWNER TO hris_admin;

--
-- Name: transaction_qr_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.transaction_qr_tokens_id_seq OWNED BY public.transaction_qr_tokens.id;


--
-- Name: transaction_registry; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.transaction_registry (
    id integer NOT NULL,
    module_code character varying(60) NOT NULL,
    reference_no character varying(40) NOT NULL,
    status_id integer,
    current_step_id integer,
    summary_text text
);


ALTER TABLE public.transaction_registry OWNER TO hris_admin;

--
-- Name: transaction_registry_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.transaction_registry_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.transaction_registry_id_seq OWNER TO hris_admin;

--
-- Name: transaction_registry_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.transaction_registry_id_seq OWNED BY public.transaction_registry.id;


--
-- Name: transaction_timeline; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.transaction_timeline (
    id integer NOT NULL,
    transaction_id integer,
    event_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    event_text text NOT NULL
);


ALTER TABLE public.transaction_timeline OWNER TO hris_admin;

--
-- Name: transaction_timeline_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.transaction_timeline_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.transaction_timeline_id_seq OWNER TO hris_admin;

--
-- Name: transaction_timeline_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.transaction_timeline_id_seq OWNED BY public.transaction_timeline.id;


--
-- Name: trn_employee_history; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.trn_employee_history (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    program_name character varying(200) NOT NULL,
    provider character varying(200),
    date_completed date,
    hours numeric(5,1),
    certificate_path text,
    is_external boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.trn_employee_history OWNER TO hris_admin;

--
-- Name: trn_employee_history_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.trn_employee_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.trn_employee_history_id_seq OWNER TO hris_admin;

--
-- Name: trn_employee_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.trn_employee_history_id_seq OWNED BY public.trn_employee_history.id;


--
-- Name: trn_enrollments; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.trn_enrollments (
    id bigint NOT NULL,
    session_id bigint NOT NULL,
    employee_id bigint NOT NULL,
    status character varying(20) DEFAULT 'ENROLLED'::character varying NOT NULL,
    pre_eval_score numeric(5,2),
    post_eval_score numeric(5,2),
    passed boolean,
    certificate_path text,
    completed_at date,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.trn_enrollments OWNER TO hris_admin;

--
-- Name: trn_enrollments_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.trn_enrollments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.trn_enrollments_id_seq OWNER TO hris_admin;

--
-- Name: trn_enrollments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.trn_enrollments_id_seq OWNED BY public.trn_enrollments.id;


--
-- Name: trn_programs; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.trn_programs (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    code character varying(30) NOT NULL,
    name character varying(200) NOT NULL,
    description text,
    category character varying(50),
    provider character varying(200),
    duration_hours numeric(5,1),
    is_mandatory boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.trn_programs OWNER TO hris_admin;

--
-- Name: trn_programs_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.trn_programs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.trn_programs_id_seq OWNER TO hris_admin;

--
-- Name: trn_programs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.trn_programs_id_seq OWNED BY public.trn_programs.id;


--
-- Name: trn_sessions; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.trn_sessions (
    id bigint NOT NULL,
    program_id bigint NOT NULL,
    session_code character varying(30) NOT NULL,
    facilitator character varying(200),
    venue character varying(200),
    mode character varying(20) DEFAULT 'IN_PERSON'::character varying NOT NULL,
    date_from date NOT NULL,
    date_to date NOT NULL,
    max_participants integer,
    status character varying(20) DEFAULT 'SCHEDULED'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.trn_sessions OWNER TO hris_admin;

--
-- Name: trn_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.trn_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.trn_sessions_id_seq OWNER TO hris_admin;

--
-- Name: trn_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.trn_sessions_id_seq OWNED BY public.trn_sessions.id;


--
-- Name: ui_themes; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.ui_themes (
    id integer NOT NULL,
    code character varying(40) NOT NULL,
    name character varying(120) NOT NULL,
    properties jsonb NOT NULL,
    is_active boolean DEFAULT false
);


ALTER TABLE public.ui_themes OWNER TO hris_admin;

--
-- Name: ui_themes_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.ui_themes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ui_themes_id_seq OWNER TO hris_admin;

--
-- Name: ui_themes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.ui_themes_id_seq OWNED BY public.ui_themes.id;


--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.user_roles (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    role_id bigint NOT NULL,
    assigned_at timestamp with time zone DEFAULT now() NOT NULL,
    assigned_by bigint,
    expires_at timestamp with time zone,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.user_roles OWNER TO hris_admin;

--
-- Name: user_roles_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.user_roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.user_roles_id_seq OWNER TO hris_admin;

--
-- Name: user_roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.user_roles_id_seq OWNED BY public.user_roles.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.users (
    id integer NOT NULL,
    display_name character varying(120) NOT NULL,
    email character varying(120) NOT NULL,
    role_code character varying(50) NOT NULL,
    is_active boolean DEFAULT true
);


ALTER TABLE public.users OWNER TO hris_admin;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO hris_admin;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: v_change_volume_daily; Type: VIEW; Schema: public; Owner: hris_admin
--

CREATE VIEW public.v_change_volume_daily AS
 SELECT date_trunc('day'::text, sys_change_log.created_at) AS day,
    sys_change_log.table_name,
    sys_change_log.operation,
    count(*) AS change_count,
    count(DISTINCT sys_change_log.user_id) AS distinct_users
   FROM public.sys_change_log
  GROUP BY (date_trunc('day'::text, sys_change_log.created_at)), sys_change_log.table_name, sys_change_log.operation
  ORDER BY (date_trunc('day'::text, sys_change_log.created_at)) DESC, (count(*)) DESC;


ALTER TABLE public.v_change_volume_daily OWNER TO hris_admin;

--
-- Name: v_payroll_summary; Type: VIEW; Schema: public; Owner: hris_admin
--

CREATE VIEW public.v_payroll_summary AS
 SELECT pr.id AS run_id,
    pp.period_code,
    pp.date_from,
    pp.date_to,
    pp.payment_date,
    pr.status,
    pr.total_employees,
    pr.total_gross,
    pr.total_deductions,
    pr.total_net,
    c.name AS company_name
   FROM ((public.pay_runs pr
     JOIN public.pay_periods pp ON ((pr.period_id = pp.id)))
     JOIN public.companies c ON ((pp.company_id = c.id)));


ALTER TABLE public.v_payroll_summary OWNER TO hris_admin;

--
-- Name: v_top_changed_fields; Type: VIEW; Schema: public; Owner: hris_admin
--

CREATE VIEW public.v_top_changed_fields AS
 SELECT sys_field_changes.table_name,
    sys_field_changes.field_name,
    count(*) AS change_count,
    count(DISTINCT sys_field_changes.user_id) AS distinct_users,
    max(sys_field_changes.created_at) AS last_changed_at
   FROM public.sys_field_changes
  GROUP BY sys_field_changes.table_name, sys_field_changes.field_name
  ORDER BY (count(*)) DESC;


ALTER TABLE public.v_top_changed_fields OWNER TO hris_admin;

--
-- Name: workflow_action_logs; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.workflow_action_logs (
    id integer NOT NULL,
    instance_id integer,
    action_code character varying(40) NOT NULL,
    action_note text,
    action_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.workflow_action_logs OWNER TO hris_admin;

--
-- Name: workflow_action_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.workflow_action_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflow_action_logs_id_seq OWNER TO hris_admin;

--
-- Name: workflow_action_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.workflow_action_logs_id_seq OWNED BY public.workflow_action_logs.id;


--
-- Name: workflow_checklist_items; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.workflow_checklist_items (
    id integer NOT NULL,
    workflow_checklist_id integer,
    item_label character varying(120) NOT NULL,
    is_required boolean DEFAULT true,
    is_gate boolean DEFAULT false
);


ALTER TABLE public.workflow_checklist_items OWNER TO hris_admin;

--
-- Name: workflow_checklist_items_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.workflow_checklist_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflow_checklist_items_id_seq OWNER TO hris_admin;

--
-- Name: workflow_checklist_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.workflow_checklist_items_id_seq OWNED BY public.workflow_checklist_items.id;


--
-- Name: workflow_checklists; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.workflow_checklists (
    id integer NOT NULL,
    workflow_step_id integer,
    checklist_name character varying(120) NOT NULL
);


ALTER TABLE public.workflow_checklists OWNER TO hris_admin;

--
-- Name: workflow_checklists_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.workflow_checklists_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflow_checklists_id_seq OWNER TO hris_admin;

--
-- Name: workflow_checklists_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.workflow_checklists_id_seq OWNED BY public.workflow_checklists.id;


--
-- Name: workflow_definitions; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.workflow_definitions (
    id integer NOT NULL,
    workflow_code character varying(60) NOT NULL,
    workflow_name character varying(120) NOT NULL,
    module_code character varying(60) NOT NULL
);


ALTER TABLE public.workflow_definitions OWNER TO hris_admin;

--
-- Name: workflow_definitions_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.workflow_definitions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflow_definitions_id_seq OWNER TO hris_admin;

--
-- Name: workflow_definitions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.workflow_definitions_id_seq OWNED BY public.workflow_definitions.id;


--
-- Name: workflow_instances; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.workflow_instances (
    id integer NOT NULL,
    workflow_definition_id integer,
    reference_no character varying(40) NOT NULL,
    status_id integer,
    current_step_id integer
);


ALTER TABLE public.workflow_instances OWNER TO hris_admin;

--
-- Name: workflow_instances_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.workflow_instances_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflow_instances_id_seq OWNER TO hris_admin;

--
-- Name: workflow_instances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.workflow_instances_id_seq OWNED BY public.workflow_instances.id;


--
-- Name: workflow_routes; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.workflow_routes (
    id integer NOT NULL,
    from_step_id integer,
    action_code character varying(40) NOT NULL,
    to_step_id integer,
    route_type character varying(40) NOT NULL
);


ALTER TABLE public.workflow_routes OWNER TO hris_admin;

--
-- Name: workflow_routes_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.workflow_routes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflow_routes_id_seq OWNER TO hris_admin;

--
-- Name: workflow_routes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.workflow_routes_id_seq OWNED BY public.workflow_routes.id;


--
-- Name: workflow_steps; Type: TABLE; Schema: public; Owner: hris_admin
--

CREATE TABLE public.workflow_steps (
    id integer NOT NULL,
    workflow_definition_id integer,
    step_order integer NOT NULL,
    step_name character varying(120) NOT NULL,
    approver_role_code character varying(50) NOT NULL,
    is_gate boolean DEFAULT false
);


ALTER TABLE public.workflow_steps OWNER TO hris_admin;

--
-- Name: workflow_steps_id_seq; Type: SEQUENCE; Schema: public; Owner: hris_admin
--

CREATE SEQUENCE public.workflow_steps_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflow_steps_id_seq OWNER TO hris_admin;

--
-- Name: workflow_steps_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hris_admin
--

ALTER SEQUENCE public.workflow_steps_id_seq OWNED BY public.workflow_steps.id;


--
-- Name: rec_applicants; Type: TABLE; Schema: recruitment; Owner: hris_admin
--

CREATE TABLE recruitment.rec_applicants (
    id bigint NOT NULL,
    posting_id bigint,
    first_name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    email character varying(200),
    mobile_no character varying(20),
    resume_path text,
    stage character varying(30) DEFAULT 'APPLIED'::character varying NOT NULL,
    source character varying(50),
    score numeric(4,2),
    remarks text,
    hired_as_employee_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE recruitment.rec_applicants OWNER TO hris_admin;

--
-- Name: rec_applicants_id_seq; Type: SEQUENCE; Schema: recruitment; Owner: hris_admin
--

CREATE SEQUENCE recruitment.rec_applicants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE recruitment.rec_applicants_id_seq OWNER TO hris_admin;

--
-- Name: rec_applicants_id_seq; Type: SEQUENCE OWNED BY; Schema: recruitment; Owner: hris_admin
--

ALTER SEQUENCE recruitment.rec_applicants_id_seq OWNED BY recruitment.rec_applicants.id;


--
-- Name: rec_appointments; Type: TABLE; Schema: recruitment; Owner: hris_admin
--

CREATE TABLE recruitment.rec_appointments (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    position_id bigint NOT NULL,
    plantilla_item_id bigint,
    appointment_type character varying(20) DEFAULT 'PERMANENT'::character varying NOT NULL,
    appointment_no character varying(60) NOT NULL,
    effective_date date NOT NULL,
    end_date date,
    salary_grade integer NOT NULL,
    step_no integer DEFAULT 1 NOT NULL,
    monthly_salary numeric(14,2) NOT NULL,
    issued_by bigint,
    approved_by bigint,
    csc_attested_at timestamp with time zone,
    document_path character varying(500),
    workflow_instance_id bigint,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    remarks text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT rec_appointments_appointment_type_check CHECK (((appointment_type)::text = ANY ((ARRAY['PERMANENT'::character varying, 'TEMPORARY'::character varying, 'CASUAL'::character varying, 'COTERMINOUS'::character varying, 'CONTRACTUAL'::character varying])::text[]))),
    CONSTRAINT rec_appointments_salary_grade_check CHECK (((salary_grade >= 1) AND (salary_grade <= 33))),
    CONSTRAINT rec_appointments_status_check CHECK (((status)::text = ANY ((ARRAY['DRAFT'::character varying, 'FOR_SIGNATURE'::character varying, 'ATTESTED'::character varying, 'CANCELLED'::character varying])::text[]))),
    CONSTRAINT rec_appointments_step_no_check CHECK (((step_no >= 1) AND (step_no <= 8)))
);


ALTER TABLE recruitment.rec_appointments OWNER TO hris_admin;

--
-- Name: rec_appointments_id_seq; Type: SEQUENCE; Schema: recruitment; Owner: hris_admin
--

CREATE SEQUENCE recruitment.rec_appointments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE recruitment.rec_appointments_id_seq OWNER TO hris_admin;

--
-- Name: rec_appointments_id_seq; Type: SEQUENCE OWNED BY; Schema: recruitment; Owner: hris_admin
--

ALTER SEQUENCE recruitment.rec_appointments_id_seq OWNED BY recruitment.rec_appointments.id;


--
-- Name: rec_csc_eligibilities; Type: TABLE; Schema: recruitment; Owner: hris_admin
--

CREATE TABLE recruitment.rec_csc_eligibilities (
    id bigint NOT NULL,
    code character varying(40) NOT NULL,
    name character varying(200) NOT NULL,
    category character varying(60),
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE recruitment.rec_csc_eligibilities OWNER TO hris_admin;

--
-- Name: rec_csc_eligibilities_id_seq; Type: SEQUENCE; Schema: recruitment; Owner: hris_admin
--

CREATE SEQUENCE recruitment.rec_csc_eligibilities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE recruitment.rec_csc_eligibilities_id_seq OWNER TO hris_admin;

--
-- Name: rec_csc_eligibilities_id_seq; Type: SEQUENCE OWNED BY; Schema: recruitment; Owner: hris_admin
--

ALTER SEQUENCE recruitment.rec_csc_eligibilities_id_seq OWNED BY recruitment.rec_csc_eligibilities.id;


--
-- Name: rec_employee_eligibilities; Type: TABLE; Schema: recruitment; Owner: hris_admin
--

CREATE TABLE recruitment.rec_employee_eligibilities (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    eligibility_id bigint NOT NULL,
    rating numeric(5,2),
    exam_date date,
    exam_place character varying(200),
    license_no character varying(60),
    license_expiry date,
    is_verified boolean DEFAULT false NOT NULL,
    verified_by bigint,
    verified_at timestamp with time zone,
    document_path character varying(500),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE recruitment.rec_employee_eligibilities OWNER TO hris_admin;

--
-- Name: rec_employee_eligibilities_id_seq; Type: SEQUENCE; Schema: recruitment; Owner: hris_admin
--

CREATE SEQUENCE recruitment.rec_employee_eligibilities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE recruitment.rec_employee_eligibilities_id_seq OWNER TO hris_admin;

--
-- Name: rec_employee_eligibilities_id_seq; Type: SEQUENCE OWNED BY; Schema: recruitment; Owner: hris_admin
--

ALTER SEQUENCE recruitment.rec_employee_eligibilities_id_seq OWNED BY recruitment.rec_employee_eligibilities.id;


--
-- Name: rec_interview_schedules; Type: TABLE; Schema: recruitment; Owner: hris_admin
--

CREATE TABLE recruitment.rec_interview_schedules (
    id bigint NOT NULL,
    applicant_id bigint NOT NULL,
    interviewer_id bigint,
    scheduled_at timestamp with time zone NOT NULL,
    interview_type character varying(30) DEFAULT 'INITIAL'::character varying NOT NULL,
    location character varying(200),
    notes text,
    outcome character varying(30),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE recruitment.rec_interview_schedules OWNER TO hris_admin;

--
-- Name: rec_interview_schedules_id_seq; Type: SEQUENCE; Schema: recruitment; Owner: hris_admin
--

CREATE SEQUENCE recruitment.rec_interview_schedules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE recruitment.rec_interview_schedules_id_seq OWNER TO hris_admin;

--
-- Name: rec_interview_schedules_id_seq; Type: SEQUENCE OWNED BY; Schema: recruitment; Owner: hris_admin
--

ALTER SEQUENCE recruitment.rec_interview_schedules_id_seq OWNED BY recruitment.rec_interview_schedules.id;


--
-- Name: rec_job_postings; Type: TABLE; Schema: recruitment; Owner: hris_admin
--

CREATE TABLE recruitment.rec_job_postings (
    id bigint NOT NULL,
    requisition_id bigint,
    title character varying(200) NOT NULL,
    description text,
    requirements text,
    employment_type character varying(30),
    salary_range character varying(100),
    location character varying(200),
    posted_on date,
    closed_on date,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    is_internal boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE recruitment.rec_job_postings OWNER TO hris_admin;

--
-- Name: rec_job_postings_id_seq; Type: SEQUENCE; Schema: recruitment; Owner: hris_admin
--

CREATE SEQUENCE recruitment.rec_job_postings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE recruitment.rec_job_postings_id_seq OWNER TO hris_admin;

--
-- Name: rec_job_postings_id_seq; Type: SEQUENCE OWNED BY; Schema: recruitment; Owner: hris_admin
--

ALTER SEQUENCE recruitment.rec_job_postings_id_seq OWNED BY recruitment.rec_job_postings.id;


--
-- Name: rec_next_in_rank_list; Type: TABLE; Schema: recruitment; Owner: hris_admin
--

CREATE TABLE recruitment.rec_next_in_rank_list (
    id bigint NOT NULL,
    position_id bigint NOT NULL,
    employee_id bigint NOT NULL,
    qualification_met boolean DEFAULT false NOT NULL,
    rank integer NOT NULL,
    assessed_on date DEFAULT CURRENT_DATE NOT NULL,
    assessed_by bigint,
    notified_at timestamp with time zone,
    notification_ref character varying(100),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE recruitment.rec_next_in_rank_list OWNER TO hris_admin;

--
-- Name: rec_next_in_rank_list_id_seq; Type: SEQUENCE; Schema: recruitment; Owner: hris_admin
--

CREATE SEQUENCE recruitment.rec_next_in_rank_list_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE recruitment.rec_next_in_rank_list_id_seq OWNER TO hris_admin;

--
-- Name: rec_next_in_rank_list_id_seq; Type: SEQUENCE OWNED BY; Schema: recruitment; Owner: hris_admin
--

ALTER SEQUENCE recruitment.rec_next_in_rank_list_id_seq OWNED BY recruitment.rec_next_in_rank_list.id;


--
-- Name: rec_offers; Type: TABLE; Schema: recruitment; Owner: hris_admin
--

CREATE TABLE recruitment.rec_offers (
    id bigint NOT NULL,
    applicant_id bigint NOT NULL,
    offered_salary numeric(14,2),
    position_id bigint,
    start_date date,
    offer_date date,
    expiry_date date,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    accepted_at timestamp with time zone,
    declined_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE recruitment.rec_offers OWNER TO hris_admin;

--
-- Name: rec_offers_id_seq; Type: SEQUENCE; Schema: recruitment; Owner: hris_admin
--

CREATE SEQUENCE recruitment.rec_offers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE recruitment.rec_offers_id_seq OWNER TO hris_admin;

--
-- Name: rec_offers_id_seq; Type: SEQUENCE OWNED BY; Schema: recruitment; Owner: hris_admin
--

ALTER SEQUENCE recruitment.rec_offers_id_seq OWNED BY recruitment.rec_offers.id;


--
-- Name: rec_plantilla_items; Type: TABLE; Schema: recruitment; Owner: hris_admin
--

CREATE TABLE recruitment.rec_plantilla_items (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    department_id bigint,
    position_id bigint,
    item_number character varying(30) NOT NULL,
    salary_grade integer NOT NULL,
    step_no integer DEFAULT 1 NOT NULL,
    authorized_year integer,
    filled_by bigint,
    status character varying(20) DEFAULT 'VACANT'::character varying NOT NULL,
    remarks text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT rec_plantilla_items_salary_grade_check CHECK (((salary_grade >= 1) AND (salary_grade <= 33))),
    CONSTRAINT rec_plantilla_items_status_check CHECK (((status)::text = ANY ((ARRAY['FILLED'::character varying, 'VACANT'::character varying, 'PROPOSED'::character varying, 'ABOLISHED'::character varying])::text[]))),
    CONSTRAINT rec_plantilla_items_step_no_check CHECK (((step_no >= 1) AND (step_no <= 8)))
);


ALTER TABLE recruitment.rec_plantilla_items OWNER TO hris_admin;

--
-- Name: rec_plantilla_items_id_seq; Type: SEQUENCE; Schema: recruitment; Owner: hris_admin
--

CREATE SEQUENCE recruitment.rec_plantilla_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE recruitment.rec_plantilla_items_id_seq OWNER TO hris_admin;

--
-- Name: rec_plantilla_items_id_seq; Type: SEQUENCE OWNED BY; Schema: recruitment; Owner: hris_admin
--

ALTER SEQUENCE recruitment.rec_plantilla_items_id_seq OWNED BY recruitment.rec_plantilla_items.id;


--
-- Name: rec_psb_deliberations; Type: TABLE; Schema: recruitment; Owner: hris_admin
--

CREATE TABLE recruitment.rec_psb_deliberations (
    id bigint NOT NULL,
    requisition_id bigint NOT NULL,
    deliberation_date date NOT NULL,
    chairperson_id bigint,
    minutes_path character varying(500),
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    resolution text,
    created_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT rec_psb_deliberations_status_check CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'COMPLETED'::character varying, 'DEFERRED'::character varying])::text[])))
);


ALTER TABLE recruitment.rec_psb_deliberations OWNER TO hris_admin;

--
-- Name: rec_psb_deliberations_id_seq; Type: SEQUENCE; Schema: recruitment; Owner: hris_admin
--

CREATE SEQUENCE recruitment.rec_psb_deliberations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE recruitment.rec_psb_deliberations_id_seq OWNER TO hris_admin;

--
-- Name: rec_psb_deliberations_id_seq; Type: SEQUENCE OWNED BY; Schema: recruitment; Owner: hris_admin
--

ALTER SEQUENCE recruitment.rec_psb_deliberations_id_seq OWNED BY recruitment.rec_psb_deliberations.id;


--
-- Name: rec_psb_members; Type: TABLE; Schema: recruitment; Owner: hris_admin
--

CREATE TABLE recruitment.rec_psb_members (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    member_employee_id bigint NOT NULL,
    role character varying(20) DEFAULT 'MEMBER'::character varying NOT NULL,
    effective_from date DEFAULT CURRENT_DATE NOT NULL,
    effective_to date,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT rec_psb_members_role_check CHECK (((role)::text = ANY ((ARRAY['CHAIR'::character varying, 'MEMBER'::character varying, 'OBSERVER'::character varying, 'HR_REP'::character varying])::text[])))
);


ALTER TABLE recruitment.rec_psb_members OWNER TO hris_admin;

--
-- Name: rec_psb_members_id_seq; Type: SEQUENCE; Schema: recruitment; Owner: hris_admin
--

CREATE SEQUENCE recruitment.rec_psb_members_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE recruitment.rec_psb_members_id_seq OWNER TO hris_admin;

--
-- Name: rec_psb_members_id_seq; Type: SEQUENCE OWNED BY; Schema: recruitment; Owner: hris_admin
--

ALTER SEQUENCE recruitment.rec_psb_members_id_seq OWNED BY recruitment.rec_psb_members.id;


--
-- Name: rec_psb_scores; Type: TABLE; Schema: recruitment; Owner: hris_admin
--

CREATE TABLE recruitment.rec_psb_scores (
    id bigint NOT NULL,
    deliberation_id bigint NOT NULL,
    applicant_id bigint NOT NULL,
    education_score numeric(5,2) DEFAULT 0 NOT NULL,
    experience_score numeric(5,2) DEFAULT 0 NOT NULL,
    training_score numeric(5,2) DEFAULT 0 NOT NULL,
    performance_score numeric(5,2) DEFAULT 0 NOT NULL,
    interview_score numeric(5,2) DEFAULT 0 NOT NULL,
    total_score numeric(6,2) GENERATED ALWAYS AS (((((education_score + experience_score) + training_score) + performance_score) + interview_score)) STORED,
    rank integer,
    is_next_in_rank boolean DEFAULT false NOT NULL,
    remarks text,
    scored_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE recruitment.rec_psb_scores OWNER TO hris_admin;

--
-- Name: rec_psb_scores_id_seq; Type: SEQUENCE; Schema: recruitment; Owner: hris_admin
--

CREATE SEQUENCE recruitment.rec_psb_scores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE recruitment.rec_psb_scores_id_seq OWNER TO hris_admin;

--
-- Name: rec_psb_scores_id_seq; Type: SEQUENCE OWNED BY; Schema: recruitment; Owner: hris_admin
--

ALTER SEQUENCE recruitment.rec_psb_scores_id_seq OWNED BY recruitment.rec_psb_scores.id;


--
-- Name: rec_publications; Type: TABLE; Schema: recruitment; Owner: hris_admin
--

CREATE TABLE recruitment.rec_publications (
    id bigint NOT NULL,
    requisition_id bigint NOT NULL,
    posting_id bigint,
    published_at timestamp with time zone,
    closes_at timestamp with time zone,
    published_by bigint,
    csc_reference_no character varying(60),
    channel character varying(30) DEFAULT 'AGENCY_BULLETIN'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT rec_publications_channel_check CHECK (((channel)::text = ANY ((ARRAY['CSC_BOARD'::character varying, 'AGENCY_BULLETIN'::character varying, 'WEBSITE'::character varying, 'JOBSTREET'::character varying, 'PHILJOBNET'::character varying])::text[])))
);


ALTER TABLE recruitment.rec_publications OWNER TO hris_admin;

--
-- Name: rec_publications_id_seq; Type: SEQUENCE; Schema: recruitment; Owner: hris_admin
--

CREATE SEQUENCE recruitment.rec_publications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE recruitment.rec_publications_id_seq OWNER TO hris_admin;

--
-- Name: rec_publications_id_seq; Type: SEQUENCE OWNED BY; Schema: recruitment; Owner: hris_admin
--

ALTER SEQUENCE recruitment.rec_publications_id_seq OWNED BY recruitment.rec_publications.id;


--
-- Name: rec_qualification_standards; Type: TABLE; Schema: recruitment; Owner: hris_admin
--

CREATE TABLE recruitment.rec_qualification_standards (
    id bigint NOT NULL,
    position_id bigint NOT NULL,
    education text,
    experience text,
    training text,
    eligibility text,
    competencies jsonb DEFAULT '[]'::jsonb NOT NULL,
    effective_date date DEFAULT CURRENT_DATE NOT NULL,
    created_by bigint,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE recruitment.rec_qualification_standards OWNER TO hris_admin;

--
-- Name: rec_qualification_standards_id_seq; Type: SEQUENCE; Schema: recruitment; Owner: hris_admin
--

CREATE SEQUENCE recruitment.rec_qualification_standards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE recruitment.rec_qualification_standards_id_seq OWNER TO hris_admin;

--
-- Name: rec_qualification_standards_id_seq; Type: SEQUENCE OWNED BY; Schema: recruitment; Owner: hris_admin
--

ALTER SEQUENCE recruitment.rec_qualification_standards_id_seq OWNED BY recruitment.rec_qualification_standards.id;


--
-- Name: rec_requisitions; Type: TABLE; Schema: recruitment; Owner: hris_admin
--

CREATE TABLE recruitment.rec_requisitions (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    reference_no character varying(40) NOT NULL,
    department_id bigint,
    position_id bigint,
    headcount integer DEFAULT 1 NOT NULL,
    justification text,
    status character varying(30) DEFAULT 'DRAFT'::character varying NOT NULL,
    workflow_instance_id bigint,
    requested_by bigint,
    approved_by bigint,
    target_hire_date date,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE recruitment.rec_requisitions OWNER TO hris_admin;

--
-- Name: rec_requisitions_id_seq; Type: SEQUENCE; Schema: recruitment; Owner: hris_admin
--

CREATE SEQUENCE recruitment.rec_requisitions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE recruitment.rec_requisitions_id_seq OWNER TO hris_admin;

--
-- Name: rec_requisitions_id_seq; Type: SEQUENCE OWNED BY; Schema: recruitment; Owner: hris_admin
--

ALTER SEQUENCE recruitment.rec_requisitions_id_seq OWNED BY recruitment.rec_requisitions.id;


--
-- Name: v_next_in_rank; Type: VIEW; Schema: recruitment; Owner: hris_admin
--

CREATE VIEW recruitment.v_next_in_rank AS
 SELECT nir.id,
    nir.position_id,
    nir.employee_id,
    nir.qualification_met,
    nir.rank,
    nir.assessed_on,
    nir.notified_at,
    pos.title AS position_title,
    jg_pos.grade_level AS target_sg,
    (((e.first_name)::text || ' '::text) || (e.last_name)::text) AS employee_name,
    jg_emp.grade_level AS current_sg,
    et.code AS employment_type,
    d.name AS department_name
   FROM ((((((recruitment.rec_next_in_rank_list nir
     JOIN core.positions pos ON ((pos.id = nir.position_id)))
     JOIN core.employees e ON ((e.id = nir.employee_id)))
     LEFT JOIN core.departments d ON ((d.id = e.department_id)))
     LEFT JOIN core.job_grades jg_pos ON ((jg_pos.id = pos.job_grade_id)))
     LEFT JOIN core.job_grades jg_emp ON ((jg_emp.id = e.job_grade_id)))
     LEFT JOIN core.employment_types et ON ((et.id = e.employment_type_id)))
  WHERE (nir.is_active = true);


ALTER TABLE recruitment.v_next_in_rank OWNER TO hris_admin;

--
-- Name: rwd_awards; Type: TABLE; Schema: rewards; Owner: hris_admin
--

CREATE TABLE rewards.rwd_awards (
    id bigint NOT NULL,
    nomination_id bigint,
    employee_id bigint NOT NULL,
    category_id bigint NOT NULL,
    awarded_on date DEFAULT CURRENT_DATE NOT NULL,
    award_value numeric(12,2),
    certificate_path text,
    announced_via character varying(50),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE rewards.rwd_awards OWNER TO hris_admin;

--
-- Name: rwd_awards_id_seq; Type: SEQUENCE; Schema: rewards; Owner: hris_admin
--

CREATE SEQUENCE rewards.rwd_awards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rewards.rwd_awards_id_seq OWNER TO hris_admin;

--
-- Name: rwd_awards_id_seq; Type: SEQUENCE OWNED BY; Schema: rewards; Owner: hris_admin
--

ALTER SEQUENCE rewards.rwd_awards_id_seq OWNED BY rewards.rwd_awards.id;


--
-- Name: rwd_categories; Type: TABLE; Schema: rewards; Owner: hris_admin
--

CREATE TABLE rewards.rwd_categories (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    code character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    award_type character varying(30) DEFAULT 'NON_MONETARY'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE rewards.rwd_categories OWNER TO hris_admin;

--
-- Name: rwd_categories_id_seq; Type: SEQUENCE; Schema: rewards; Owner: hris_admin
--

CREATE SEQUENCE rewards.rwd_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rewards.rwd_categories_id_seq OWNER TO hris_admin;

--
-- Name: rwd_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: rewards; Owner: hris_admin
--

ALTER SEQUENCE rewards.rwd_categories_id_seq OWNED BY rewards.rwd_categories.id;


--
-- Name: rwd_loyalty_milestones; Type: TABLE; Schema: rewards; Owner: hris_admin
--

CREATE TABLE rewards.rwd_loyalty_milestones (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    service_years integer NOT NULL,
    award_type character varying(20) DEFAULT 'COMBINATION'::character varying NOT NULL,
    award_value numeric(12,2),
    eligibility_date date NOT NULL,
    status character varying(20) DEFAULT 'UPCOMING'::character varying NOT NULL,
    awarded_at timestamp with time zone,
    awarded_by bigint,
    certificate_path character varying(500),
    notified_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT rwd_loyalty_milestones_award_type_check CHECK (((award_type)::text = ANY ((ARRAY['PLAQUE'::character varying, 'CASH_GIFT'::character varying, 'LEAVE_CREDITS'::character varying, 'COMBINATION'::character varying])::text[]))),
    CONSTRAINT rwd_loyalty_milestones_status_check CHECK (((status)::text = ANY ((ARRAY['UPCOMING'::character varying, 'ELIGIBLE'::character varying, 'AWARDED'::character varying, 'WAIVED'::character varying])::text[])))
);


ALTER TABLE rewards.rwd_loyalty_milestones OWNER TO hris_admin;

--
-- Name: rwd_loyalty_milestones_id_seq; Type: SEQUENCE; Schema: rewards; Owner: hris_admin
--

CREATE SEQUENCE rewards.rwd_loyalty_milestones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rewards.rwd_loyalty_milestones_id_seq OWNER TO hris_admin;

--
-- Name: rwd_loyalty_milestones_id_seq; Type: SEQUENCE OWNED BY; Schema: rewards; Owner: hris_admin
--

ALTER SEQUENCE rewards.rwd_loyalty_milestones_id_seq OWNED BY rewards.rwd_loyalty_milestones.id;


--
-- Name: rwd_nominations; Type: TABLE; Schema: rewards; Owner: hris_admin
--

CREATE TABLE rewards.rwd_nominations (
    id bigint NOT NULL,
    category_id bigint NOT NULL,
    nominee_employee_id bigint NOT NULL,
    nominated_by bigint NOT NULL,
    period character varying(30) NOT NULL,
    justification text NOT NULL,
    status character varying(30) DEFAULT 'PENDING'::character varying NOT NULL,
    workflow_instance_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    praise_category_id bigint,
    period_year integer,
    period_quarter integer
);


ALTER TABLE rewards.rwd_nominations OWNER TO hris_admin;

--
-- Name: rwd_nominations_id_seq; Type: SEQUENCE; Schema: rewards; Owner: hris_admin
--

CREATE SEQUENCE rewards.rwd_nominations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rewards.rwd_nominations_id_seq OWNER TO hris_admin;

--
-- Name: rwd_nominations_id_seq; Type: SEQUENCE OWNED BY; Schema: rewards; Owner: hris_admin
--

ALTER SEQUENCE rewards.rwd_nominations_id_seq OWNED BY rewards.rwd_nominations.id;


--
-- Name: rwd_pbb_records; Type: TABLE; Schema: rewards; Owner: hris_admin
--

CREATE TABLE rewards.rwd_pbb_records (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    year integer NOT NULL,
    ipcr_summary_id bigint,
    ipcr_adjectival character varying(30),
    opcr_adjectival character varying(30),
    pbb_tier character varying(20) DEFAULT 'NOT_ELIGIBLE'::character varying NOT NULL,
    pbb_amount numeric(12,2),
    conditions_met text,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    released_at timestamp with time zone,
    released_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT rwd_pbb_records_pbb_tier_check CHECK (((pbb_tier)::text = ANY ((ARRAY['TIER_1'::character varying, 'TIER_2'::character varying, 'TIER_3'::character varying, 'TIER_4'::character varying, 'NOT_ELIGIBLE'::character varying])::text[]))),
    CONSTRAINT rwd_pbb_records_status_check CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'APPROVED'::character varying, 'RELEASED'::character varying])::text[])))
);


ALTER TABLE rewards.rwd_pbb_records OWNER TO hris_admin;

--
-- Name: rwd_pbb_records_id_seq; Type: SEQUENCE; Schema: rewards; Owner: hris_admin
--

CREATE SEQUENCE rewards.rwd_pbb_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rewards.rwd_pbb_records_id_seq OWNER TO hris_admin;

--
-- Name: rwd_pbb_records_id_seq; Type: SEQUENCE OWNED BY; Schema: rewards; Owner: hris_admin
--

ALTER SEQUENCE rewards.rwd_pbb_records_id_seq OWNED BY rewards.rwd_pbb_records.id;


--
-- Name: rwd_praise_config; Type: TABLE; Schema: rewards; Owner: hris_admin
--

CREATE TABLE rewards.rwd_praise_config (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    award_type character varying(30) NOT NULL,
    criteria_description text,
    monetary_equivalent numeric(12,2),
    non_monetary_description text,
    is_active boolean DEFAULT true NOT NULL,
    created_by bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT rwd_praise_config_award_type_check CHECK (((award_type)::text = ANY ((ARRAY['EMPLOYEE_OF_MONTH'::character varying, 'EMPLOYEE_OF_YEAR'::character varying, 'BEST_TEAM'::character varying, 'INNOVATION'::character varying, 'LOYALTY'::character varying, 'PERFECT_ATTENDANCE'::character varying, 'OUTSTANDING_PERFORMANCE'::character varying])::text[])))
);


ALTER TABLE rewards.rwd_praise_config OWNER TO hris_admin;

--
-- Name: rwd_praise_config_id_seq; Type: SEQUENCE; Schema: rewards; Owner: hris_admin
--

CREATE SEQUENCE rewards.rwd_praise_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rewards.rwd_praise_config_id_seq OWNER TO hris_admin;

--
-- Name: rwd_praise_config_id_seq; Type: SEQUENCE OWNED BY; Schema: rewards; Owner: hris_admin
--

ALTER SEQUENCE rewards.rwd_praise_config_id_seq OWNED BY rewards.rwd_praise_config.id;


--
-- Name: rwd_retirement_alerts; Type: TABLE; Schema: rewards; Owner: hris_admin
--

CREATE TABLE rewards.rwd_retirement_alerts (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    retirement_age integer NOT NULL,
    projected_retirement_date date NOT NULL,
    alert_type character varying(20) NOT NULL,
    scheduled_send_date date NOT NULL,
    sent_at timestamp with time zone,
    recipient_ids jsonb DEFAULT '[]'::jsonb NOT NULL,
    notification_ref character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT rwd_retirement_alerts_alert_type_check CHECK (((alert_type)::text = ANY ((ARRAY['AGE_60_NOTICE'::character varying, 'AGE_63_NOTICE'::character varying, 'AGE_65_NOTICE'::character varying, '6MO_NOTICE'::character varying, '3MO_NOTICE'::character varying, '1MO_NOTICE'::character varying])::text[])))
);


ALTER TABLE rewards.rwd_retirement_alerts OWNER TO hris_admin;

--
-- Name: rwd_retirement_alerts_id_seq; Type: SEQUENCE; Schema: rewards; Owner: hris_admin
--

CREATE SEQUENCE rewards.rwd_retirement_alerts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rewards.rwd_retirement_alerts_id_seq OWNER TO hris_admin;

--
-- Name: rwd_retirement_alerts_id_seq; Type: SEQUENCE OWNED BY; Schema: rewards; Owner: hris_admin
--

ALTER SEQUENCE rewards.rwd_retirement_alerts_id_seq OWNED BY rewards.rwd_retirement_alerts.id;


--
-- Name: rwd_retirement_plans; Type: TABLE; Schema: rewards; Owner: hris_admin
--

CREATE TABLE rewards.rwd_retirement_plans (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    projected_retirement_date date,
    retirement_status character varying(30) DEFAULT 'ACTIVE'::character varying NOT NULL,
    remarks text,
    updated_by bigint,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    alert_sent_60d boolean DEFAULT false NOT NULL,
    alert_sent_30d boolean DEFAULT false NOT NULL,
    alert_sent_age60 boolean DEFAULT false NOT NULL
);


ALTER TABLE rewards.rwd_retirement_plans OWNER TO hris_admin;

--
-- Name: rwd_retirement_plans_id_seq; Type: SEQUENCE; Schema: rewards; Owner: hris_admin
--

CREATE SEQUENCE rewards.rwd_retirement_plans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rewards.rwd_retirement_plans_id_seq OWNER TO hris_admin;

--
-- Name: rwd_retirement_plans_id_seq; Type: SEQUENCE OWNED BY; Schema: rewards; Owner: hris_admin
--

ALTER SEQUENCE rewards.rwd_retirement_plans_id_seq OWNED BY rewards.rwd_retirement_plans.id;


--
-- Name: rwd_ssl_table; Type: TABLE; Schema: rewards; Owner: hris_admin
--

CREATE TABLE rewards.rwd_ssl_table (
    id bigint NOT NULL,
    salary_grade integer NOT NULL,
    step_no integer NOT NULL,
    monthly_rate numeric(12,2) NOT NULL,
    effective_date date DEFAULT '2024-01-01'::date NOT NULL,
    ssl_version character varying(30) DEFAULT 'SSL V'::character varying NOT NULL,
    CONSTRAINT rwd_ssl_table_salary_grade_check CHECK (((salary_grade >= 1) AND (salary_grade <= 33))),
    CONSTRAINT rwd_ssl_table_step_no_check CHECK (((step_no >= 1) AND (step_no <= 8)))
);


ALTER TABLE rewards.rwd_ssl_table OWNER TO hris_admin;

--
-- Name: rwd_ssl_table_id_seq; Type: SEQUENCE; Schema: rewards; Owner: hris_admin
--

CREATE SEQUENCE rewards.rwd_ssl_table_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rewards.rwd_ssl_table_id_seq OWNER TO hris_admin;

--
-- Name: rwd_ssl_table_id_seq; Type: SEQUENCE OWNED BY; Schema: rewards; Owner: hris_admin
--

ALTER SEQUENCE rewards.rwd_ssl_table_id_seq OWNED BY rewards.rwd_ssl_table.id;


--
-- Name: rwd_step_increments; Type: TABLE; Schema: rewards; Owner: hris_admin
--

CREATE TABLE rewards.rwd_step_increments (
    id bigint NOT NULL,
    employee_id bigint NOT NULL,
    current_sg integer NOT NULL,
    current_step integer NOT NULL,
    next_step integer NOT NULL,
    last_increment_date date NOT NULL,
    next_increment_due date GENERATED ALWAYS AS ((last_increment_date + '3 years'::interval)) STORED,
    eligibility_status character varying(20) DEFAULT 'PENDING_RATING'::character varying NOT NULL,
    ipcr_summary_id bigint,
    processed_at timestamp with time zone,
    processed_by bigint,
    payroll_effective_date date,
    remarks text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT rwd_step_increments_eligibility_status_check CHECK (((eligibility_status)::text = ANY ((ARRAY['ELIGIBLE'::character varying, 'PENDING_RATING'::character varying, 'PROCESSED'::character varying, 'SKIPPED'::character varying])::text[])))
);


ALTER TABLE rewards.rwd_step_increments OWNER TO hris_admin;

--
-- Name: rwd_step_increments_id_seq; Type: SEQUENCE; Schema: rewards; Owner: hris_admin
--

CREATE SEQUENCE rewards.rwd_step_increments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rewards.rwd_step_increments_id_seq OWNER TO hris_admin;

--
-- Name: rwd_step_increments_id_seq; Type: SEQUENCE OWNED BY; Schema: rewards; Owner: hris_admin
--

ALTER SEQUENCE rewards.rwd_step_increments_id_seq OWNED BY rewards.rwd_step_increments.id;


--
-- Name: v_retirement_notices; Type: VIEW; Schema: rewards; Owner: hris_admin
--

CREATE VIEW rewards.v_retirement_notices AS
 SELECT ra.id,
    ra.employee_id,
    ra.retirement_age,
    ra.projected_retirement_date,
    ra.alert_type,
    ra.scheduled_send_date,
    ra.sent_at,
    (((e.first_name)::text || ' '::text) || (e.last_name)::text) AS employee_name,
    e.date_of_birth AS birth_date,
    d.name AS department_name,
    pos.title AS position_title,
    (ra.projected_retirement_date - CURRENT_DATE) AS days_until_retirement
   FROM (((rewards.rwd_retirement_alerts ra
     JOIN core.employees e ON ((e.id = ra.employee_id)))
     LEFT JOIN core.departments d ON ((d.id = e.department_id)))
     LEFT JOIN core.positions pos ON ((pos.id = e.position_id)));


ALTER TABLE rewards.v_retirement_notices OWNER TO hris_admin;

--
-- Name: v_step_increment_due; Type: VIEW; Schema: rewards; Owner: hris_admin
--

CREATE VIEW rewards.v_step_increment_due AS
 SELECT si.id,
    si.employee_id,
    si.current_sg,
    si.current_step,
    si.next_step,
    si.last_increment_date,
    si.next_increment_due,
    si.eligibility_status,
    (((e.first_name)::text || ' '::text) || (e.last_name)::text) AS employee_name,
    d.name AS department_name,
    ssl_curr.monthly_rate AS current_rate,
    ssl_next.monthly_rate AS next_rate,
    (COALESCE(ssl_next.monthly_rate, (0)::numeric) - COALESCE(ssl_curr.monthly_rate, (0)::numeric)) AS increment_amount
   FROM ((((rewards.rwd_step_increments si
     JOIN core.employees e ON ((e.id = si.employee_id)))
     LEFT JOIN core.departments d ON ((d.id = e.department_id)))
     LEFT JOIN rewards.rwd_ssl_table ssl_curr ON (((ssl_curr.salary_grade = si.current_sg) AND (ssl_curr.step_no = si.current_step))))
     LEFT JOIN rewards.rwd_ssl_table ssl_next ON (((ssl_next.salary_grade = si.current_sg) AND (ssl_next.step_no = si.next_step))))
  WHERE ((si.eligibility_status)::text = ANY ((ARRAY['ELIGIBLE'::character varying, 'PENDING_RATING'::character varying])::text[]));


ALTER TABLE rewards.v_step_increment_due OWNER TO hris_admin;

--
-- Name: instance_checklist_items; Type: TABLE; Schema: workflow; Owner: hris_admin
--

CREATE TABLE workflow.instance_checklist_items (
    id bigint NOT NULL,
    instance_id bigint NOT NULL,
    checklist_id bigint NOT NULL,
    is_completed boolean DEFAULT false NOT NULL,
    completed_by bigint,
    completed_at timestamp with time zone
);


ALTER TABLE workflow.instance_checklist_items OWNER TO hris_admin;

--
-- Name: instance_checklist_items_id_seq; Type: SEQUENCE; Schema: workflow; Owner: hris_admin
--

CREATE SEQUENCE workflow.instance_checklist_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE workflow.instance_checklist_items_id_seq OWNER TO hris_admin;

--
-- Name: instance_checklist_items_id_seq; Type: SEQUENCE OWNED BY; Schema: workflow; Owner: hris_admin
--

ALTER SEQUENCE workflow.instance_checklist_items_id_seq OWNED BY workflow.instance_checklist_items.id;


--
-- Name: workflow_definitions; Type: TABLE; Schema: workflow; Owner: hris_admin
--

CREATE TABLE workflow.workflow_definitions (
    id bigint NOT NULL,
    code character varying(60) NOT NULL,
    name character varying(200) NOT NULL,
    module character varying(50) NOT NULL,
    description text,
    version integer DEFAULT 1 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE workflow.workflow_definitions OWNER TO hris_admin;

--
-- Name: workflow_instances; Type: TABLE; Schema: workflow; Owner: hris_admin
--

CREATE TABLE workflow.workflow_instances (
    id bigint NOT NULL,
    definition_id bigint NOT NULL,
    current_step_id bigint,
    module character varying(50) NOT NULL,
    entity_type character varying(60),
    entity_id bigint,
    reference_no character varying(60),
    status character varying(20) DEFAULT 'IN_PROGRESS'::character varying NOT NULL,
    initiated_by bigint,
    completed_at timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE workflow.workflow_instances OWNER TO hris_admin;

--
-- Name: workflow_steps; Type: TABLE; Schema: workflow; Owner: hris_admin
--

CREATE TABLE workflow.workflow_steps (
    id bigint NOT NULL,
    workflow_id bigint NOT NULL,
    step_order integer NOT NULL,
    code character varying(60) NOT NULL,
    name character varying(200) NOT NULL,
    role_required character varying(50),
    is_final boolean DEFAULT false NOT NULL,
    description text,
    sla_hours integer
);


ALTER TABLE workflow.workflow_steps OWNER TO hris_admin;

--
-- Name: v_pending_approvals; Type: VIEW; Schema: workflow; Owner: hris_admin
--

CREATE VIEW workflow.v_pending_approvals AS
 SELECT wi.id AS instance_id,
    wi.reference_no,
    wd.name AS workflow_name,
    wd.module,
    ws.name AS current_step,
    wi.entity_type,
    wi.entity_id,
    u.display_name AS initiated_by,
    wi.created_at AS filed_at,
    (EXTRACT(epoch FROM (now() - wi.created_at)) / (3600)::numeric) AS hours_pending
   FROM (((workflow.workflow_instances wi
     JOIN workflow.workflow_definitions wd ON ((wd.id = wi.definition_id)))
     LEFT JOIN workflow.workflow_steps ws ON ((ws.id = wi.current_step_id)))
     LEFT JOIN core.users u ON ((u.id = wi.initiated_by)))
  WHERE ((wi.status)::text = 'IN_PROGRESS'::text)
  ORDER BY wi.created_at;


ALTER TABLE workflow.v_pending_approvals OWNER TO hris_admin;

--
-- Name: workflow_action_logs; Type: TABLE; Schema: workflow; Owner: hris_admin
--

CREATE TABLE workflow.workflow_action_logs (
    id bigint NOT NULL,
    instance_id bigint NOT NULL,
    step_id bigint,
    action_code character varying(30) NOT NULL,
    performed_by bigint,
    comments text,
    from_status character varying(30),
    to_status character varying(30),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE workflow.workflow_action_logs OWNER TO hris_admin;

--
-- Name: workflow_action_logs_id_seq; Type: SEQUENCE; Schema: workflow; Owner: hris_admin
--

CREATE SEQUENCE workflow.workflow_action_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE workflow.workflow_action_logs_id_seq OWNER TO hris_admin;

--
-- Name: workflow_action_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: workflow; Owner: hris_admin
--

ALTER SEQUENCE workflow.workflow_action_logs_id_seq OWNED BY workflow.workflow_action_logs.id;


--
-- Name: workflow_checklists; Type: TABLE; Schema: workflow; Owner: hris_admin
--

CREATE TABLE workflow.workflow_checklists (
    id bigint NOT NULL,
    step_id bigint NOT NULL,
    name character varying(200) NOT NULL,
    description text,
    is_gate boolean DEFAULT false NOT NULL,
    sort_order integer DEFAULT 99 NOT NULL
);


ALTER TABLE workflow.workflow_checklists OWNER TO hris_admin;

--
-- Name: workflow_checklists_id_seq; Type: SEQUENCE; Schema: workflow; Owner: hris_admin
--

CREATE SEQUENCE workflow.workflow_checklists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE workflow.workflow_checklists_id_seq OWNER TO hris_admin;

--
-- Name: workflow_checklists_id_seq; Type: SEQUENCE OWNED BY; Schema: workflow; Owner: hris_admin
--

ALTER SEQUENCE workflow.workflow_checklists_id_seq OWNED BY workflow.workflow_checklists.id;


--
-- Name: workflow_definitions_id_seq; Type: SEQUENCE; Schema: workflow; Owner: hris_admin
--

CREATE SEQUENCE workflow.workflow_definitions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE workflow.workflow_definitions_id_seq OWNER TO hris_admin;

--
-- Name: workflow_definitions_id_seq; Type: SEQUENCE OWNED BY; Schema: workflow; Owner: hris_admin
--

ALTER SEQUENCE workflow.workflow_definitions_id_seq OWNED BY workflow.workflow_definitions.id;


--
-- Name: workflow_event_hooks; Type: TABLE; Schema: workflow; Owner: hris_admin
--

CREATE TABLE workflow.workflow_event_hooks (
    id bigint NOT NULL,
    definition_id bigint NOT NULL,
    event_type character varying(60) NOT NULL,
    hook_action character varying(60) NOT NULL,
    config jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE workflow.workflow_event_hooks OWNER TO hris_admin;

--
-- Name: workflow_event_hooks_id_seq; Type: SEQUENCE; Schema: workflow; Owner: hris_admin
--

CREATE SEQUENCE workflow.workflow_event_hooks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE workflow.workflow_event_hooks_id_seq OWNER TO hris_admin;

--
-- Name: workflow_event_hooks_id_seq; Type: SEQUENCE OWNED BY; Schema: workflow; Owner: hris_admin
--

ALTER SEQUENCE workflow.workflow_event_hooks_id_seq OWNED BY workflow.workflow_event_hooks.id;


--
-- Name: workflow_instances_id_seq; Type: SEQUENCE; Schema: workflow; Owner: hris_admin
--

CREATE SEQUENCE workflow.workflow_instances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE workflow.workflow_instances_id_seq OWNER TO hris_admin;

--
-- Name: workflow_instances_id_seq; Type: SEQUENCE OWNED BY; Schema: workflow; Owner: hris_admin
--

ALTER SEQUENCE workflow.workflow_instances_id_seq OWNED BY workflow.workflow_instances.id;


--
-- Name: workflow_routes; Type: TABLE; Schema: workflow; Owner: hris_admin
--

CREATE TABLE workflow.workflow_routes (
    id bigint NOT NULL,
    step_id bigint NOT NULL,
    action_code character varying(30) NOT NULL,
    next_step_id bigint,
    label character varying(100)
);


ALTER TABLE workflow.workflow_routes OWNER TO hris_admin;

--
-- Name: workflow_routes_id_seq; Type: SEQUENCE; Schema: workflow; Owner: hris_admin
--

CREATE SEQUENCE workflow.workflow_routes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE workflow.workflow_routes_id_seq OWNER TO hris_admin;

--
-- Name: workflow_routes_id_seq; Type: SEQUENCE OWNED BY; Schema: workflow; Owner: hris_admin
--

ALTER SEQUENCE workflow.workflow_routes_id_seq OWNED BY workflow.workflow_routes.id;


--
-- Name: workflow_steps_id_seq; Type: SEQUENCE; Schema: workflow; Owner: hris_admin
--

CREATE SEQUENCE workflow.workflow_steps_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE workflow.workflow_steps_id_seq OWNER TO hris_admin;

--
-- Name: workflow_steps_id_seq; Type: SEQUENCE OWNED BY; Schema: workflow; Owner: hris_admin
--

ALTER SEQUENCE workflow.workflow_steps_id_seq OWNED BY workflow.workflow_steps.id;


--
-- Name: att_logs_2025; Type: TABLE ATTACH; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_logs ATTACH PARTITION attendance.att_logs_2025 FOR VALUES FROM ('2025-01-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');


--
-- Name: att_logs_2026; Type: TABLE ATTACH; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_logs ATTACH PARTITION attendance.att_logs_2026 FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');


--
-- Name: att_logs_2027; Type: TABLE ATTACH; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_logs ATTACH PARTITION attendance.att_logs_2027 FOR VALUES FROM ('2027-01-01 00:00:00+00') TO ('2028-01-01 00:00:00+00');


--
-- Name: att_logs_2028; Type: TABLE ATTACH; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_logs ATTACH PARTITION attendance.att_logs_2028 FOR VALUES FROM ('2028-01-01 00:00:00+00') TO ('2029-01-01 00:00:00+00');


--
-- Name: sys_change_log_2025; Type: TABLE ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_change_log ATTACH PARTITION audit_logs.sys_change_log_2025 FOR VALUES FROM ('2025-01-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');


--
-- Name: sys_change_log_2026; Type: TABLE ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_change_log ATTACH PARTITION audit_logs.sys_change_log_2026 FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');


--
-- Name: sys_change_log_2027; Type: TABLE ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_change_log ATTACH PARTITION audit_logs.sys_change_log_2027 FOR VALUES FROM ('2027-01-01 00:00:00+00') TO ('2028-01-01 00:00:00+00');


--
-- Name: sys_change_log_2028; Type: TABLE ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_change_log ATTACH PARTITION audit_logs.sys_change_log_2028 FOR VALUES FROM ('2028-01-01 00:00:00+00') TO ('2029-01-01 00:00:00+00');


--
-- Name: sys_field_changes_2025; Type: TABLE ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_field_changes ATTACH PARTITION audit_logs.sys_field_changes_2025 FOR VALUES FROM ('2025-01-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');


--
-- Name: sys_field_changes_2026; Type: TABLE ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_field_changes ATTACH PARTITION audit_logs.sys_field_changes_2026 FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');


--
-- Name: sys_field_changes_2027; Type: TABLE ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_field_changes ATTACH PARTITION audit_logs.sys_field_changes_2027 FOR VALUES FROM ('2027-01-01 00:00:00+00') TO ('2028-01-01 00:00:00+00');


--
-- Name: sys_field_changes_2028; Type: TABLE ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_field_changes ATTACH PARTITION audit_logs.sys_field_changes_2028 FOR VALUES FROM ('2028-01-01 00:00:00+00') TO ('2029-01-01 00:00:00+00');


--
-- Name: att_logs_2025; Type: TABLE ATTACH; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_logs ATTACH PARTITION public.att_logs_2025 FOR VALUES FROM ('2025-01-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');


--
-- Name: att_logs_2026; Type: TABLE ATTACH; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_logs ATTACH PARTITION public.att_logs_2026 FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');


--
-- Name: att_logs_2027; Type: TABLE ATTACH; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_logs ATTACH PARTITION public.att_logs_2027 FOR VALUES FROM ('2027-01-01 00:00:00+00') TO ('2028-01-01 00:00:00+00');


--
-- Name: att_logs_2028; Type: TABLE ATTACH; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_logs ATTACH PARTITION public.att_logs_2028 FOR VALUES FROM ('2028-01-01 00:00:00+00') TO ('2029-01-01 00:00:00+00');


--
-- Name: ntf_notifications_2025; Type: TABLE ATTACH; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ntf_notifications ATTACH PARTITION public.ntf_notifications_2025 FOR VALUES FROM ('2025-01-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');


--
-- Name: ntf_notifications_2026; Type: TABLE ATTACH; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ntf_notifications ATTACH PARTITION public.ntf_notifications_2026 FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');


--
-- Name: ntf_notifications_2027; Type: TABLE ATTACH; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ntf_notifications ATTACH PARTITION public.ntf_notifications_2027 FOR VALUES FROM ('2027-01-01 00:00:00+00') TO ('2028-01-01 00:00:00+00');


--
-- Name: ntf_notifications_2028; Type: TABLE ATTACH; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ntf_notifications ATTACH PARTITION public.ntf_notifications_2028 FOR VALUES FROM ('2028-01-01 00:00:00+00') TO ('2029-01-01 00:00:00+00');


--
-- Name: sys_audit_logs_2025; Type: TABLE ATTACH; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_audit_logs ATTACH PARTITION public.sys_audit_logs_2025 FOR VALUES FROM ('2025-01-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');


--
-- Name: sys_audit_logs_2026; Type: TABLE ATTACH; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_audit_logs ATTACH PARTITION public.sys_audit_logs_2026 FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');


--
-- Name: sys_audit_logs_2027; Type: TABLE ATTACH; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_audit_logs ATTACH PARTITION public.sys_audit_logs_2027 FOR VALUES FROM ('2027-01-01 00:00:00+00') TO ('2028-01-01 00:00:00+00');


--
-- Name: sys_audit_logs_2028; Type: TABLE ATTACH; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_audit_logs ATTACH PARTITION public.sys_audit_logs_2028 FOR VALUES FROM ('2028-01-01 00:00:00+00') TO ('2029-01-01 00:00:00+00');


--
-- Name: sys_change_log_2025; Type: TABLE ATTACH; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_change_log ATTACH PARTITION public.sys_change_log_2025 FOR VALUES FROM ('2025-01-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');


--
-- Name: sys_change_log_2026; Type: TABLE ATTACH; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_change_log ATTACH PARTITION public.sys_change_log_2026 FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');


--
-- Name: sys_change_log_2027; Type: TABLE ATTACH; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_change_log ATTACH PARTITION public.sys_change_log_2027 FOR VALUES FROM ('2027-01-01 00:00:00+00') TO ('2028-01-01 00:00:00+00');


--
-- Name: sys_change_log_2028; Type: TABLE ATTACH; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_change_log ATTACH PARTITION public.sys_change_log_2028 FOR VALUES FROM ('2028-01-01 00:00:00+00') TO ('2029-01-01 00:00:00+00');


--
-- Name: sys_field_changes_2025; Type: TABLE ATTACH; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_field_changes ATTACH PARTITION public.sys_field_changes_2025 FOR VALUES FROM ('2025-01-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');


--
-- Name: sys_field_changes_2026; Type: TABLE ATTACH; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_field_changes ATTACH PARTITION public.sys_field_changes_2026 FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');


--
-- Name: sys_field_changes_2027; Type: TABLE ATTACH; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_field_changes ATTACH PARTITION public.sys_field_changes_2027 FOR VALUES FROM ('2027-01-01 00:00:00+00') TO ('2028-01-01 00:00:00+00');


--
-- Name: sys_field_changes_2028; Type: TABLE ATTACH; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_field_changes ATTACH PARTITION public.sys_field_changes_2028 FOR VALUES FROM ('2028-01-01 00:00:00+00') TO ('2029-01-01 00:00:00+00');


--
-- Name: ai_feature_store id; Type: DEFAULT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_feature_store ALTER COLUMN id SET DEFAULT nextval('ai.ai_feature_store_id_seq'::regclass);


--
-- Name: ai_insight_results id; Type: DEFAULT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_insight_results ALTER COLUMN id SET DEFAULT nextval('ai.ai_insight_results_id_seq'::regclass);


--
-- Name: ai_messages id; Type: DEFAULT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_messages ALTER COLUMN id SET DEFAULT nextval('ai.ai_messages_id_seq'::regclass);


--
-- Name: ai_persona_configs id; Type: DEFAULT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_persona_configs ALTER COLUMN id SET DEFAULT nextval('ai.ai_persona_configs_id_seq'::regclass);


--
-- Name: ai_recommendations id; Type: DEFAULT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_recommendations ALTER COLUMN id SET DEFAULT nextval('ai.ai_recommendations_id_seq'::regclass);


--
-- Name: ai_risk_scores id; Type: DEFAULT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_risk_scores ALTER COLUMN id SET DEFAULT nextval('ai.ai_risk_scores_id_seq'::regclass);


--
-- Name: ai_sessions id; Type: DEFAULT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_sessions ALTER COLUMN id SET DEFAULT nextval('ai.ai_sessions_id_seq'::regclass);


--
-- Name: ai_tool_call_logs id; Type: DEFAULT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_tool_call_logs ALTER COLUMN id SET DEFAULT nextval('ai.ai_tool_call_logs_id_seq'::regclass);


--
-- Name: dim_department surrogate_key; Type: DEFAULT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.dim_department ALTER COLUMN surrogate_key SET DEFAULT nextval('analytics.dim_department_surrogate_key_seq'::regclass);


--
-- Name: dim_employee surrogate_key; Type: DEFAULT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.dim_employee ALTER COLUMN surrogate_key SET DEFAULT nextval('analytics.dim_employee_surrogate_key_seq'::regclass);


--
-- Name: dim_position surrogate_key; Type: DEFAULT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.dim_position ALTER COLUMN surrogate_key SET DEFAULT nextval('analytics.dim_position_surrogate_key_seq'::regclass);


--
-- Name: fact_attendance id; Type: DEFAULT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.fact_attendance ALTER COLUMN id SET DEFAULT nextval('analytics.fact_attendance_id_seq'::regclass);


--
-- Name: fact_leave id; Type: DEFAULT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.fact_leave ALTER COLUMN id SET DEFAULT nextval('analytics.fact_leave_id_seq'::regclass);


--
-- Name: fact_payroll id; Type: DEFAULT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.fact_payroll ALTER COLUMN id SET DEFAULT nextval('analytics.fact_payroll_id_seq'::regclass);


--
-- Name: fact_training id; Type: DEFAULT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.fact_training ALTER COLUMN id SET DEFAULT nextval('analytics.fact_training_id_seq'::regclass);


--
-- Name: kpi_snapshots id; Type: DEFAULT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.kpi_snapshots ALTER COLUMN id SET DEFAULT nextval('analytics.kpi_snapshots_id_seq'::regclass);


--
-- Name: report_data_sources id; Type: DEFAULT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.report_data_sources ALTER COLUMN id SET DEFAULT nextval('analytics.report_data_sources_id_seq'::regclass);


--
-- Name: report_field_registry id; Type: DEFAULT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.report_field_registry ALTER COLUMN id SET DEFAULT nextval('analytics.report_field_registry_id_seq'::regclass);


--
-- Name: report_run_history id; Type: DEFAULT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.report_run_history ALTER COLUMN id SET DEFAULT nextval('analytics.report_run_history_id_seq'::regclass);


--
-- Name: report_schedules id; Type: DEFAULT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.report_schedules ALTER COLUMN id SET DEFAULT nextval('analytics.report_schedules_id_seq'::regclass);


--
-- Name: saved_reports id; Type: DEFAULT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.saved_reports ALTER COLUMN id SET DEFAULT nextval('analytics.saved_reports_id_seq'::regclass);


--
-- Name: att_admin_overrides id; Type: DEFAULT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_admin_overrides ALTER COLUMN id SET DEFAULT nextval('attendance.att_admin_overrides_id_seq'::regclass);


--
-- Name: att_daily id; Type: DEFAULT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_daily ALTER COLUMN id SET DEFAULT nextval('attendance.att_daily_id_seq'::regclass);


--
-- Name: att_dtr_corrections id; Type: DEFAULT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_dtr_corrections ALTER COLUMN id SET DEFAULT nextval('attendance.att_dtr_corrections_id_seq'::regclass);


--
-- Name: att_holiday_types id; Type: DEFAULT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_holiday_types ALTER COLUMN id SET DEFAULT nextval('attendance.att_holiday_types_id_seq'::regclass);


--
-- Name: att_holidays id; Type: DEFAULT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_holidays ALTER COLUMN id SET DEFAULT nextval('attendance.att_holidays_id_seq'::regclass);


--
-- Name: att_logs id; Type: DEFAULT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_logs ALTER COLUMN id SET DEFAULT nextval('attendance.att_logs_id_seq'::regclass);


--
-- Name: att_overtime_requests id; Type: DEFAULT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_overtime_requests ALTER COLUMN id SET DEFAULT nextval('attendance.att_overtime_requests_id_seq'::regclass);


--
-- Name: att_shift_assignments id; Type: DEFAULT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_shift_assignments ALTER COLUMN id SET DEFAULT nextval('attendance.att_shift_assignments_id_seq'::regclass);


--
-- Name: att_shifts id; Type: DEFAULT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_shifts ALTER COLUMN id SET DEFAULT nextval('attendance.att_shifts_id_seq'::regclass);


--
-- Name: sys_bulk_operation_logs id; Type: DEFAULT; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_bulk_operation_logs ALTER COLUMN id SET DEFAULT nextval('audit_logs.sys_bulk_operation_logs_id_seq'::regclass);


--
-- Name: sys_change_log id; Type: DEFAULT; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_change_log ALTER COLUMN id SET DEFAULT nextval('audit_logs.sys_change_log_id_seq'::regclass);


--
-- Name: sys_data_exports id; Type: DEFAULT; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_data_exports ALTER COLUMN id SET DEFAULT nextval('audit_logs.sys_data_exports_id_seq'::regclass);


--
-- Name: sys_field_changes id; Type: DEFAULT; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_field_changes ALTER COLUMN id SET DEFAULT nextval('audit_logs.sys_field_changes_id_seq'::regclass);


--
-- Name: sys_login_logs id; Type: DEFAULT; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_login_logs ALTER COLUMN id SET DEFAULT nextval('audit_logs.sys_login_logs_id_seq'::regclass);


--
-- Name: sys_payroll_audit id; Type: DEFAULT; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_payroll_audit ALTER COLUMN id SET DEFAULT nextval('audit_logs.sys_payroll_audit_id_seq'::regclass);


--
-- Name: sys_status_transitions id; Type: DEFAULT; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_status_transitions ALTER COLUMN id SET DEFAULT nextval('audit_logs.sys_status_transitions_id_seq'::regclass);


--
-- Name: business_units id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.business_units ALTER COLUMN id SET DEFAULT nextval('core.business_units_id_seq'::regclass);


--
-- Name: companies id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.companies ALTER COLUMN id SET DEFAULT nextval('core.companies_id_seq'::regclass);


--
-- Name: company_branding id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.company_branding ALTER COLUMN id SET DEFAULT nextval('core.company_branding_id_seq'::regclass);


--
-- Name: dashboard_metrics id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.dashboard_metrics ALTER COLUMN id SET DEFAULT nextval('core.dashboard_metrics_id_seq'::regclass);


--
-- Name: demo_profiles id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.demo_profiles ALTER COLUMN id SET DEFAULT nextval('core.demo_profiles_id_seq'::regclass);


--
-- Name: departments id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.departments ALTER COLUMN id SET DEFAULT nextval('core.departments_id_seq'::regclass);


--
-- Name: documents id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.documents ALTER COLUMN id SET DEFAULT nextval('core.documents_id_seq'::regclass);


--
-- Name: dynamic_forms id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.dynamic_forms ALTER COLUMN id SET DEFAULT nextval('core.dynamic_forms_id_seq'::regclass);


--
-- Name: emp_addresses id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_addresses ALTER COLUMN id SET DEFAULT nextval('core.emp_addresses_id_seq'::regclass);


--
-- Name: emp_bank_accounts id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_bank_accounts ALTER COLUMN id SET DEFAULT nextval('core.emp_bank_accounts_id_seq'::regclass);


--
-- Name: emp_dependents id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_dependents ALTER COLUMN id SET DEFAULT nextval('core.emp_dependents_id_seq'::regclass);


--
-- Name: emp_education id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_education ALTER COLUMN id SET DEFAULT nextval('core.emp_education_id_seq'::regclass);


--
-- Name: emp_emergency_contacts id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_emergency_contacts ALTER COLUMN id SET DEFAULT nextval('core.emp_emergency_contacts_id_seq'::regclass);


--
-- Name: emp_government_ids id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_government_ids ALTER COLUMN id SET DEFAULT nextval('core.emp_government_ids_id_seq'::regclass);


--
-- Name: emp_status_history id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_status_history ALTER COLUMN id SET DEFAULT nextval('core.emp_status_history_id_seq'::regclass);


--
-- Name: emp_work_history id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_work_history ALTER COLUMN id SET DEFAULT nextval('core.emp_work_history_id_seq'::regclass);


--
-- Name: employees id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.employees ALTER COLUMN id SET DEFAULT nextval('core.employees_id_seq'::regclass);


--
-- Name: employment_types id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.employment_types ALTER COLUMN id SET DEFAULT nextval('core.employment_types_id_seq'::regclass);


--
-- Name: feature_registry id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.feature_registry ALTER COLUMN id SET DEFAULT nextval('core.feature_registry_id_seq'::regclass);


--
-- Name: field_privacy_rules id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.field_privacy_rules ALTER COLUMN id SET DEFAULT nextval('core.field_privacy_rules_id_seq'::regclass);


--
-- Name: form_fields id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.form_fields ALTER COLUMN id SET DEFAULT nextval('core.form_fields_id_seq'::regclass);


--
-- Name: job_grades id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.job_grades ALTER COLUMN id SET DEFAULT nextval('core.job_grades_id_seq'::regclass);


--
-- Name: mod_permissions id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.mod_permissions ALTER COLUMN id SET DEFAULT nextval('core.mod_permissions_id_seq'::regclass);


--
-- Name: orchestration_flows id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.orchestration_flows ALTER COLUMN id SET DEFAULT nextval('core.orchestration_flows_id_seq'::regclass);


--
-- Name: orchestration_steps id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.orchestration_steps ALTER COLUMN id SET DEFAULT nextval('core.orchestration_steps_id_seq'::regclass);


--
-- Name: org_chart_nodes id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.org_chart_nodes ALTER COLUMN id SET DEFAULT nextval('core.org_chart_nodes_id_seq'::regclass);


--
-- Name: page_registry id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.page_registry ALTER COLUMN id SET DEFAULT nextval('core.page_registry_id_seq'::regclass);


--
-- Name: permissions id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.permissions ALTER COLUMN id SET DEFAULT nextval('core.permissions_id_seq'::regclass);


--
-- Name: positions id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.positions ALTER COLUMN id SET DEFAULT nextval('core.positions_id_seq'::regclass);


--
-- Name: role_feature_access id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.role_feature_access ALTER COLUMN id SET DEFAULT nextval('core.role_feature_access_id_seq'::regclass);


--
-- Name: role_page_access id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.role_page_access ALTER COLUMN id SET DEFAULT nextval('core.role_page_access_id_seq'::regclass);


--
-- Name: role_permissions id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.role_permissions ALTER COLUMN id SET DEFAULT nextval('core.role_permissions_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.roles ALTER COLUMN id SET DEFAULT nextval('core.roles_id_seq'::regclass);


--
-- Name: search_index id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.search_index ALTER COLUMN id SET DEFAULT nextval('core.search_index_id_seq'::regclass);


--
-- Name: status_definitions id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.status_definitions ALTER COLUMN id SET DEFAULT nextval('core.status_definitions_id_seq'::regclass);


--
-- Name: task_inbox id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.task_inbox ALTER COLUMN id SET DEFAULT nextval('core.task_inbox_id_seq'::regclass);


--
-- Name: transaction_qr_tokens id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.transaction_qr_tokens ALTER COLUMN id SET DEFAULT nextval('core.transaction_qr_tokens_id_seq'::regclass);


--
-- Name: transaction_registry id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.transaction_registry ALTER COLUMN id SET DEFAULT nextval('core.transaction_registry_id_seq'::regclass);


--
-- Name: ui_themes id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.ui_themes ALTER COLUMN id SET DEFAULT nextval('core.ui_themes_id_seq'::regclass);


--
-- Name: user_feature_access id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.user_feature_access ALTER COLUMN id SET DEFAULT nextval('core.user_feature_access_id_seq'::regclass);


--
-- Name: user_page_access id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.user_page_access ALTER COLUMN id SET DEFAULT nextval('core.user_page_access_id_seq'::regclass);


--
-- Name: user_roles id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.user_roles ALTER COLUMN id SET DEFAULT nextval('core.user_roles_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.users ALTER COLUMN id SET DEFAULT nextval('core.users_id_seq'::regclass);


--
-- Name: appeals id; Type: DEFAULT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.appeals ALTER COLUMN id SET DEFAULT nextval('discipline.appeals_id_seq'::regclass);


--
-- Name: case_types id; Type: DEFAULT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.case_types ALTER COLUMN id SET DEFAULT nextval('discipline.case_types_id_seq'::regclass);


--
-- Name: cases id; Type: DEFAULT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.cases ALTER COLUMN id SET DEFAULT nextval('discipline.cases_id_seq'::regclass);


--
-- Name: complaints id; Type: DEFAULT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.complaints ALTER COLUMN id SET DEFAULT nextval('discipline.complaints_id_seq'::regclass);


--
-- Name: decisions id; Type: DEFAULT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.decisions ALTER COLUMN id SET DEFAULT nextval('discipline.decisions_id_seq'::regclass);


--
-- Name: formal_charges id; Type: DEFAULT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.formal_charges ALTER COLUMN id SET DEFAULT nextval('discipline.formal_charges_id_seq'::regclass);


--
-- Name: hearings id; Type: DEFAULT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.hearings ALTER COLUMN id SET DEFAULT nextval('discipline.hearings_id_seq'::regclass);


--
-- Name: investigations id; Type: DEFAULT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.investigations ALTER COLUMN id SET DEFAULT nextval('discipline.investigations_id_seq'::regclass);


--
-- Name: preventive_suspensions id; Type: DEFAULT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.preventive_suspensions ALTER COLUMN id SET DEFAULT nextval('discipline.preventive_suspensions_id_seq'::regclass);


--
-- Name: certificate_requests id; Type: DEFAULT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.certificate_requests ALTER COLUMN id SET DEFAULT nextval('dms.certificate_requests_id_seq'::regclass);


--
-- Name: certificate_types id; Type: DEFAULT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.certificate_types ALTER COLUMN id SET DEFAULT nextval('dms.certificate_types_id_seq'::regclass);


--
-- Name: checklist_items id; Type: DEFAULT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.checklist_items ALTER COLUMN id SET DEFAULT nextval('dms.checklist_items_id_seq'::regclass);


--
-- Name: checklist_templates id; Type: DEFAULT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.checklist_templates ALTER COLUMN id SET DEFAULT nextval('dms.checklist_templates_id_seq'::regclass);


--
-- Name: document_categories id; Type: DEFAULT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.document_categories ALTER COLUMN id SET DEFAULT nextval('dms.document_categories_id_seq'::regclass);


--
-- Name: document_requests id; Type: DEFAULT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.document_requests ALTER COLUMN id SET DEFAULT nextval('dms.document_requests_id_seq'::regclass);


--
-- Name: retention_policies id; Type: DEFAULT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.retention_policies ALTER COLUMN id SET DEFAULT nextval('dms.retention_policies_id_seq'::regclass);


--
-- Name: service_record_snapshots id; Type: DEFAULT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.service_record_snapshots ALTER COLUMN id SET DEFAULT nextval('dms.service_record_snapshots_id_seq'::regclass);


--
-- Name: health_certificates id; Type: DEFAULT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.health_certificates ALTER COLUMN id SET DEFAULT nextval('health.health_certificates_id_seq'::regclass);


--
-- Name: incident_investigations id; Type: DEFAULT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.incident_investigations ALTER COLUMN id SET DEFAULT nextval('health.incident_investigations_id_seq'::regclass);


--
-- Name: incident_persons id; Type: DEFAULT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.incident_persons ALTER COLUMN id SET DEFAULT nextval('health.incident_persons_id_seq'::regclass);


--
-- Name: incidents id; Type: DEFAULT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.incidents ALTER COLUMN id SET DEFAULT nextval('health.incidents_id_seq'::regclass);


--
-- Name: medical_records id; Type: DEFAULT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.medical_records ALTER COLUMN id SET DEFAULT nextval('health.medical_records_id_seq'::regclass);


--
-- Name: pe_results id; Type: DEFAULT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.pe_results ALTER COLUMN id SET DEFAULT nextval('health.pe_results_id_seq'::regclass);


--
-- Name: pe_schedules id; Type: DEFAULT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.pe_schedules ALTER COLUMN id SET DEFAULT nextval('health.pe_schedules_id_seq'::regclass);


--
-- Name: wellness_enrollments id; Type: DEFAULT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.wellness_enrollments ALTER COLUMN id SET DEFAULT nextval('health.wellness_enrollments_id_seq'::regclass);


--
-- Name: wellness_programs id; Type: DEFAULT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.wellness_programs ALTER COLUMN id SET DEFAULT nextval('health.wellness_programs_id_seq'::regclass);


--
-- Name: lrn_attendance_logs id; Type: DEFAULT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_attendance_logs ALTER COLUMN id SET DEFAULT nextval('learning.lrn_attendance_logs_id_seq'::regclass);


--
-- Name: lrn_employee_skills id; Type: DEFAULT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_employee_skills ALTER COLUMN id SET DEFAULT nextval('learning.lrn_employee_skills_id_seq'::regclass);


--
-- Name: lrn_enrollments id; Type: DEFAULT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_enrollments ALTER COLUMN id SET DEFAULT nextval('learning.lrn_enrollments_id_seq'::regclass);


--
-- Name: lrn_idp_actions id; Type: DEFAULT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_idp_actions ALTER COLUMN id SET DEFAULT nextval('learning.lrn_idp_actions_id_seq'::regclass);


--
-- Name: lrn_lsp_registry id; Type: DEFAULT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_lsp_registry ALTER COLUMN id SET DEFAULT nextval('learning.lrn_lsp_registry_id_seq'::regclass);


--
-- Name: lrn_narrative_reports id; Type: DEFAULT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_narrative_reports ALTER COLUMN id SET DEFAULT nextval('learning.lrn_narrative_reports_id_seq'::regclass);


--
-- Name: lrn_programs id; Type: DEFAULT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_programs ALTER COLUMN id SET DEFAULT nextval('learning.lrn_programs_id_seq'::regclass);


--
-- Name: lrn_scholarships id; Type: DEFAULT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_scholarships ALTER COLUMN id SET DEFAULT nextval('learning.lrn_scholarships_id_seq'::regclass);


--
-- Name: lrn_sessions id; Type: DEFAULT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_sessions ALTER COLUMN id SET DEFAULT nextval('learning.lrn_sessions_id_seq'::regclass);


--
-- Name: lrn_skills id; Type: DEFAULT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_skills ALTER COLUMN id SET DEFAULT nextval('learning.lrn_skills_id_seq'::regclass);


--
-- Name: lrn_tna_entries id; Type: DEFAULT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_tna_entries ALTER COLUMN id SET DEFAULT nextval('learning.lrn_tna_entries_id_seq'::regclass);


--
-- Name: lv_approvals id; Type: DEFAULT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_approvals ALTER COLUMN id SET DEFAULT nextval('leave_mgmt.lv_approvals_id_seq'::regclass);


--
-- Name: lv_balance_adjustments id; Type: DEFAULT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_balance_adjustments ALTER COLUMN id SET DEFAULT nextval('leave_mgmt.lv_balance_adjustments_id_seq'::regclass);


--
-- Name: lv_balances id; Type: DEFAULT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_balances ALTER COLUMN id SET DEFAULT nextval('leave_mgmt.lv_balances_id_seq'::regclass);


--
-- Name: lv_cto_credits id; Type: DEFAULT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_cto_credits ALTER COLUMN id SET DEFAULT nextval('leave_mgmt.lv_cto_credits_id_seq'::regclass);


--
-- Name: lv_holidays id; Type: DEFAULT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_holidays ALTER COLUMN id SET DEFAULT nextval('leave_mgmt.lv_holidays_id_seq'::regclass);


--
-- Name: lv_ledger id; Type: DEFAULT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_ledger ALTER COLUMN id SET DEFAULT nextval('leave_mgmt.lv_ledger_id_seq'::regclass);


--
-- Name: lv_locator_entries id; Type: DEFAULT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_locator_entries ALTER COLUMN id SET DEFAULT nextval('leave_mgmt.lv_locator_entries_id_seq'::regclass);


--
-- Name: lv_policies id; Type: DEFAULT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_policies ALTER COLUMN id SET DEFAULT nextval('leave_mgmt.lv_policies_id_seq'::regclass);


--
-- Name: lv_requests id; Type: DEFAULT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_requests ALTER COLUMN id SET DEFAULT nextval('leave_mgmt.lv_requests_id_seq'::regclass);


--
-- Name: lv_travel_orders id; Type: DEFAULT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_travel_orders ALTER COLUMN id SET DEFAULT nextval('leave_mgmt.lv_travel_orders_id_seq'::regclass);


--
-- Name: lv_types id; Type: DEFAULT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_types ALTER COLUMN id SET DEFAULT nextval('leave_mgmt.lv_types_id_seq'::regclass);


--
-- Name: ntf_channels id; Type: DEFAULT; Schema: notifications; Owner: hris_admin
--

ALTER TABLE ONLY notifications.ntf_channels ALTER COLUMN id SET DEFAULT nextval('notifications.ntf_channels_id_seq'::regclass);


--
-- Name: ntf_in_app id; Type: DEFAULT; Schema: notifications; Owner: hris_admin
--

ALTER TABLE ONLY notifications.ntf_in_app ALTER COLUMN id SET DEFAULT nextval('notifications.ntf_in_app_id_seq'::regclass);


--
-- Name: ntf_queue id; Type: DEFAULT; Schema: notifications; Owner: hris_admin
--

ALTER TABLE ONLY notifications.ntf_queue ALTER COLUMN id SET DEFAULT nextval('notifications.ntf_queue_id_seq'::regclass);


--
-- Name: ntf_templates id; Type: DEFAULT; Schema: notifications; Owner: hris_admin
--

ALTER TABLE ONLY notifications.ntf_templates ALTER COLUMN id SET DEFAULT nextval('notifications.ntf_templates_id_seq'::regclass);


--
-- Name: reminder_rules id; Type: DEFAULT; Schema: notifications; Owner: hris_admin
--

ALTER TABLE ONLY notifications.reminder_rules ALTER COLUMN id SET DEFAULT nextval('notifications.reminder_rules_id_seq'::regclass);


--
-- Name: offb_clearance_items id; Type: DEFAULT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.offb_clearance_items ALTER COLUMN id SET DEFAULT nextval('onboarding.offb_clearance_items_id_seq'::regclass);


--
-- Name: offb_exit_interviews id; Type: DEFAULT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.offb_exit_interviews ALTER COLUMN id SET DEFAULT nextval('onboarding.offb_exit_interviews_id_seq'::regclass);


--
-- Name: onb_buddy_assignments id; Type: DEFAULT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.onb_buddy_assignments ALTER COLUMN id SET DEFAULT nextval('onboarding.onb_buddy_assignments_id_seq'::regclass);


--
-- Name: onb_checklist_items id; Type: DEFAULT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.onb_checklist_items ALTER COLUMN id SET DEFAULT nextval('onboarding.onb_checklist_items_id_seq'::regclass);


--
-- Name: onb_checklists id; Type: DEFAULT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.onb_checklists ALTER COLUMN id SET DEFAULT nextval('onboarding.onb_checklists_id_seq'::regclass);


--
-- Name: onb_pre_employment_reqs id; Type: DEFAULT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.onb_pre_employment_reqs ALTER COLUMN id SET DEFAULT nextval('onboarding.onb_pre_employment_reqs_id_seq'::regclass);


--
-- Name: pay_13th_month id; Type: DEFAULT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_13th_month ALTER COLUMN id SET DEFAULT nextval('payroll.pay_13th_month_id_seq'::regclass);


--
-- Name: pay_adjustments id; Type: DEFAULT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_adjustments ALTER COLUMN id SET DEFAULT nextval('payroll.pay_adjustments_id_seq'::regclass);


--
-- Name: pay_annual_bonuses id; Type: DEFAULT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_annual_bonuses ALTER COLUMN id SET DEFAULT nextval('payroll.pay_annual_bonuses_id_seq'::regclass);


--
-- Name: pay_bir_tax_table id; Type: DEFAULT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_bir_tax_table ALTER COLUMN id SET DEFAULT nextval('payroll.pay_bir_tax_table_id_seq'::regclass);


--
-- Name: pay_coop_members id; Type: DEFAULT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_coop_members ALTER COLUMN id SET DEFAULT nextval('payroll.pay_coop_members_id_seq'::regclass);


--
-- Name: pay_employee_allowances id; Type: DEFAULT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_employee_allowances ALTER COLUMN id SET DEFAULT nextval('payroll.pay_employee_allowances_id_seq'::regclass);


--
-- Name: pay_employee_allowances_gov id; Type: DEFAULT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_employee_allowances_gov ALTER COLUMN id SET DEFAULT nextval('payroll.pay_employee_allowances_gov_id_seq'::regclass);


--
-- Name: pay_employee_payroll id; Type: DEFAULT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_employee_payroll ALTER COLUMN id SET DEFAULT nextval('payroll.pay_employee_payroll_id_seq'::regclass);


--
-- Name: pay_gov_allowances id; Type: DEFAULT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_gov_allowances ALTER COLUMN id SET DEFAULT nextval('payroll.pay_gov_allowances_id_seq'::regclass);


--
-- Name: pay_government_remittances id; Type: DEFAULT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_government_remittances ALTER COLUMN id SET DEFAULT nextval('payroll.pay_government_remittances_id_seq'::regclass);


--
-- Name: pay_gsis_schedule id; Type: DEFAULT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_gsis_schedule ALTER COLUMN id SET DEFAULT nextval('payroll.pay_gsis_schedule_id_seq'::regclass);


--
-- Name: pay_loan_payments id; Type: DEFAULT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_loan_payments ALTER COLUMN id SET DEFAULT nextval('payroll.pay_loan_payments_id_seq'::regclass);


--
-- Name: pay_loans id; Type: DEFAULT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_loans ALTER COLUMN id SET DEFAULT nextval('payroll.pay_loans_id_seq'::regclass);


--
-- Name: pay_pagibig_schedule id; Type: DEFAULT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_pagibig_schedule ALTER COLUMN id SET DEFAULT nextval('payroll.pay_pagibig_schedule_id_seq'::regclass);


--
-- Name: pay_periods id; Type: DEFAULT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_periods ALTER COLUMN id SET DEFAULT nextval('payroll.pay_periods_id_seq'::regclass);


--
-- Name: pay_rata_schedule id; Type: DEFAULT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_rata_schedule ALTER COLUMN id SET DEFAULT nextval('payroll.pay_rata_schedule_id_seq'::regclass);


--
-- Name: pay_runs id; Type: DEFAULT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_runs ALTER COLUMN id SET DEFAULT nextval('payroll.pay_runs_id_seq'::regclass);


--
-- Name: pay_tax_tables id; Type: DEFAULT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_tax_tables ALTER COLUMN id SET DEFAULT nextval('payroll.pay_tax_tables_id_seq'::regclass);


--
-- Name: perf_competencies id; Type: DEFAULT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_competencies ALTER COLUMN id SET DEFAULT nextval('performance.perf_competencies_id_seq'::regclass);


--
-- Name: perf_cycles id; Type: DEFAULT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_cycles ALTER COLUMN id SET DEFAULT nextval('performance.perf_cycles_id_seq'::regclass);


--
-- Name: perf_employee_kpis id; Type: DEFAULT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_employee_kpis ALTER COLUMN id SET DEFAULT nextval('performance.perf_employee_kpis_id_seq'::regclass);


--
-- Name: perf_idp_plans id; Type: DEFAULT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_idp_plans ALTER COLUMN id SET DEFAULT nextval('performance.perf_idp_plans_id_seq'::regclass);


--
-- Name: perf_ipcr id; Type: DEFAULT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_ipcr ALTER COLUMN id SET DEFAULT nextval('performance.perf_ipcr_id_seq'::regclass);


--
-- Name: perf_ipcr_summary id; Type: DEFAULT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_ipcr_summary ALTER COLUMN id SET DEFAULT nextval('performance.perf_ipcr_summary_id_seq'::regclass);


--
-- Name: perf_opcr id; Type: DEFAULT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_opcr ALTER COLUMN id SET DEFAULT nextval('performance.perf_opcr_id_seq'::regclass);


--
-- Name: perf_reviews id; Type: DEFAULT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_reviews ALTER COLUMN id SET DEFAULT nextval('performance.perf_reviews_id_seq'::regclass);


--
-- Name: perf_strategic_plans id; Type: DEFAULT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_strategic_plans ALTER COLUMN id SET DEFAULT nextval('performance.perf_strategic_plans_id_seq'::regclass);


--
-- Name: perf_succession_matrix id; Type: DEFAULT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_succession_matrix ALTER COLUMN id SET DEFAULT nextval('performance.perf_succession_matrix_id_seq'::regclass);


--
-- Name: ai_persona_configs id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ai_persona_configs ALTER COLUMN id SET DEFAULT nextval('public.ai_persona_configs_id_seq'::regclass);


--
-- Name: analytics_metric_definitions id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.analytics_metric_definitions ALTER COLUMN id SET DEFAULT nextval('public.analytics_metric_definitions_id_seq'::regclass);


--
-- Name: att_daily id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_daily ALTER COLUMN id SET DEFAULT nextval('public.att_daily_id_seq'::regclass);


--
-- Name: att_holiday_types id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_holiday_types ALTER COLUMN id SET DEFAULT nextval('public.att_holiday_types_id_seq'::regclass);


--
-- Name: att_holidays id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_holidays ALTER COLUMN id SET DEFAULT nextval('public.att_holidays_id_seq'::regclass);


--
-- Name: att_logs id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_logs ALTER COLUMN id SET DEFAULT nextval('public.att_logs_id_seq'::regclass);


--
-- Name: att_overtime_requests id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_overtime_requests ALTER COLUMN id SET DEFAULT nextval('public.att_overtime_requests_id_seq'::regclass);


--
-- Name: att_shift_assignments id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_shift_assignments ALTER COLUMN id SET DEFAULT nextval('public.att_shift_assignments_id_seq'::regclass);


--
-- Name: att_shifts id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_shifts ALTER COLUMN id SET DEFAULT nextval('public.att_shifts_id_seq'::regclass);


--
-- Name: business_units id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.business_units ALTER COLUMN id SET DEFAULT nextval('public.business_units_id_seq'::regclass);


--
-- Name: companies id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.companies ALTER COLUMN id SET DEFAULT nextval('public.companies_id_seq'::regclass);


--
-- Name: company_branding id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.company_branding ALTER COLUMN id SET DEFAULT nextval('public.company_branding_id_seq'::regclass);


--
-- Name: dashboard_metrics id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.dashboard_metrics ALTER COLUMN id SET DEFAULT nextval('public.dashboard_metrics_id_seq'::regclass);


--
-- Name: departments id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.departments ALTER COLUMN id SET DEFAULT nextval('public.departments_id_seq'::regclass);


--
-- Name: dim_employee surrogate_key; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.dim_employee ALTER COLUMN surrogate_key SET DEFAULT nextval('public.dim_employee_surrogate_key_seq'::regclass);


--
-- Name: doc_categories id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.doc_categories ALTER COLUMN id SET DEFAULT nextval('public.doc_categories_id_seq'::regclass);


--
-- Name: doc_employee_files id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.doc_employee_files ALTER COLUMN id SET DEFAULT nextval('public.doc_employee_files_id_seq'::regclass);


--
-- Name: doc_versions id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.doc_versions ALTER COLUMN id SET DEFAULT nextval('public.doc_versions_id_seq'::regclass);


--
-- Name: dq_column_stats id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.dq_column_stats ALTER COLUMN id SET DEFAULT nextval('public.dq_column_stats_id_seq'::regclass);


--
-- Name: dq_data_issues id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.dq_data_issues ALTER COLUMN id SET DEFAULT nextval('public.dq_data_issues_id_seq'::regclass);


--
-- Name: dynamic_forms id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.dynamic_forms ALTER COLUMN id SET DEFAULT nextval('public.dynamic_forms_id_seq'::regclass);


--
-- Name: emp_addresses id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.emp_addresses ALTER COLUMN id SET DEFAULT nextval('public.emp_addresses_id_seq'::regclass);


--
-- Name: emp_bank_accounts id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.emp_bank_accounts ALTER COLUMN id SET DEFAULT nextval('public.emp_bank_accounts_id_seq'::regclass);


--
-- Name: emp_dependents id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.emp_dependents ALTER COLUMN id SET DEFAULT nextval('public.emp_dependents_id_seq'::regclass);


--
-- Name: emp_education id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.emp_education ALTER COLUMN id SET DEFAULT nextval('public.emp_education_id_seq'::regclass);


--
-- Name: emp_emergency_contacts id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.emp_emergency_contacts ALTER COLUMN id SET DEFAULT nextval('public.emp_emergency_contacts_id_seq'::regclass);


--
-- Name: emp_government_ids id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.emp_government_ids ALTER COLUMN id SET DEFAULT nextval('public.emp_government_ids_id_seq'::regclass);


--
-- Name: emp_status_history id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.emp_status_history ALTER COLUMN id SET DEFAULT nextval('public.emp_status_history_id_seq'::regclass);


--
-- Name: emp_work_history id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.emp_work_history ALTER COLUMN id SET DEFAULT nextval('public.emp_work_history_id_seq'::regclass);


--
-- Name: employee_documents id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.employee_documents ALTER COLUMN id SET DEFAULT nextval('public.employee_documents_id_seq'::regclass);


--
-- Name: employees id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.employees ALTER COLUMN id SET DEFAULT nextval('public.employees_id_seq'::regclass);


--
-- Name: employment_types id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.employment_types ALTER COLUMN id SET DEFAULT nextval('public.employment_types_id_seq'::regclass);


--
-- Name: fact_attendance id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_attendance ALTER COLUMN id SET DEFAULT nextval('public.fact_attendance_id_seq'::regclass);


--
-- Name: fact_leave id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_leave ALTER COLUMN id SET DEFAULT nextval('public.fact_leave_id_seq'::regclass);


--
-- Name: fact_payroll id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_payroll ALTER COLUMN id SET DEFAULT nextval('public.fact_payroll_id_seq'::regclass);


--
-- Name: fact_performance id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_performance ALTER COLUMN id SET DEFAULT nextval('public.fact_performance_id_seq'::regclass);


--
-- Name: fact_recruitment id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_recruitment ALTER COLUMN id SET DEFAULT nextval('public.fact_recruitment_id_seq'::regclass);


--
-- Name: feature_registry id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.feature_registry ALTER COLUMN id SET DEFAULT nextval('public.feature_registry_id_seq'::regclass);


--
-- Name: form_fields id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.form_fields ALTER COLUMN id SET DEFAULT nextval('public.form_fields_id_seq'::regclass);


--
-- Name: instance_checklist_items id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.instance_checklist_items ALTER COLUMN id SET DEFAULT nextval('public.instance_checklist_items_id_seq'::regclass);


--
-- Name: job_grades id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.job_grades ALTER COLUMN id SET DEFAULT nextval('public.job_grades_id_seq'::regclass);


--
-- Name: kpi_query_registry id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.kpi_query_registry ALTER COLUMN id SET DEFAULT nextval('public.kpi_query_registry_id_seq'::regclass);


--
-- Name: lv_approvals id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.lv_approvals ALTER COLUMN id SET DEFAULT nextval('public.lv_approvals_id_seq'::regclass);


--
-- Name: lv_balances id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.lv_balances ALTER COLUMN id SET DEFAULT nextval('public.lv_balances_id_seq'::regclass);


--
-- Name: lv_ledger id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.lv_ledger ALTER COLUMN id SET DEFAULT nextval('public.lv_ledger_id_seq'::regclass);


--
-- Name: lv_policies id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.lv_policies ALTER COLUMN id SET DEFAULT nextval('public.lv_policies_id_seq'::regclass);


--
-- Name: lv_requests id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.lv_requests ALTER COLUMN id SET DEFAULT nextval('public.lv_requests_id_seq'::regclass);


--
-- Name: lv_types id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.lv_types ALTER COLUMN id SET DEFAULT nextval('public.lv_types_id_seq'::regclass);


--
-- Name: ml_feature_catalog id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ml_feature_catalog ALTER COLUMN id SET DEFAULT nextval('public.ml_feature_catalog_id_seq'::regclass);


--
-- Name: ml_model_monitoring id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ml_model_monitoring ALTER COLUMN id SET DEFAULT nextval('public.ml_model_monitoring_id_seq'::regclass);


--
-- Name: ml_model_versions id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ml_model_versions ALTER COLUMN id SET DEFAULT nextval('public.ml_model_versions_id_seq'::regclass);


--
-- Name: ml_models id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ml_models ALTER COLUMN id SET DEFAULT nextval('public.ml_models_id_seq'::regclass);


--
-- Name: ml_training_datasets id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ml_training_datasets ALTER COLUMN id SET DEFAULT nextval('public.ml_training_datasets_id_seq'::regclass);


--
-- Name: ntf_notifications id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ntf_notifications ALTER COLUMN id SET DEFAULT nextval('public.ntf_notifications_id_seq'::regclass);


--
-- Name: ntf_templates id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ntf_templates ALTER COLUMN id SET DEFAULT nextval('public.ntf_templates_id_seq'::regclass);


--
-- Name: orchestration_flows id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.orchestration_flows ALTER COLUMN id SET DEFAULT nextval('public.orchestration_flows_id_seq'::regclass);


--
-- Name: orchestration_steps id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.orchestration_steps ALTER COLUMN id SET DEFAULT nextval('public.orchestration_steps_id_seq'::regclass);


--
-- Name: page_registry id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.page_registry ALTER COLUMN id SET DEFAULT nextval('public.page_registry_id_seq'::regclass);


--
-- Name: pay_13th_month id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_13th_month ALTER COLUMN id SET DEFAULT nextval('public.pay_13th_month_id_seq'::regclass);


--
-- Name: pay_bir_tax_table id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_bir_tax_table ALTER COLUMN id SET DEFAULT nextval('public.pay_bir_tax_table_id_seq'::regclass);


--
-- Name: pay_deductions_detail id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_deductions_detail ALTER COLUMN id SET DEFAULT nextval('public.pay_deductions_detail_id_seq'::regclass);


--
-- Name: pay_earnings_detail id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_earnings_detail ALTER COLUMN id SET DEFAULT nextval('public.pay_earnings_detail_id_seq'::regclass);


--
-- Name: pay_employee_allowances id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_employee_allowances ALTER COLUMN id SET DEFAULT nextval('public.pay_employee_allowances_id_seq'::regclass);


--
-- Name: pay_employee_loans id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_employee_loans ALTER COLUMN id SET DEFAULT nextval('public.pay_employee_loans_id_seq'::regclass);


--
-- Name: pay_employee_payroll id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_employee_payroll ALTER COLUMN id SET DEFAULT nextval('public.pay_employee_payroll_id_seq'::regclass);


--
-- Name: pay_pagibig_table id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_pagibig_table ALTER COLUMN id SET DEFAULT nextval('public.pay_pagibig_table_id_seq'::regclass);


--
-- Name: pay_periods id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_periods ALTER COLUMN id SET DEFAULT nextval('public.pay_periods_id_seq'::regclass);


--
-- Name: pay_philhealth_table id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_philhealth_table ALTER COLUMN id SET DEFAULT nextval('public.pay_philhealth_table_id_seq'::regclass);


--
-- Name: pay_runs id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_runs ALTER COLUMN id SET DEFAULT nextval('public.pay_runs_id_seq'::regclass);


--
-- Name: pay_sss_table id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_sss_table ALTER COLUMN id SET DEFAULT nextval('public.pay_sss_table_id_seq'::regclass);


--
-- Name: perf_cycles id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_cycles ALTER COLUMN id SET DEFAULT nextval('public.perf_cycles_id_seq'::regclass);


--
-- Name: perf_employee_kpis id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_employee_kpis ALTER COLUMN id SET DEFAULT nextval('public.perf_employee_kpis_id_seq'::regclass);


--
-- Name: perf_kpi_categories id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_kpi_categories ALTER COLUMN id SET DEFAULT nextval('public.perf_kpi_categories_id_seq'::regclass);


--
-- Name: perf_kpis id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_kpis ALTER COLUMN id SET DEFAULT nextval('public.perf_kpis_id_seq'::regclass);


--
-- Name: perf_review_feedback id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_review_feedback ALTER COLUMN id SET DEFAULT nextval('public.perf_review_feedback_id_seq'::regclass);


--
-- Name: perf_review_ratings id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_review_ratings ALTER COLUMN id SET DEFAULT nextval('public.perf_review_ratings_id_seq'::regclass);


--
-- Name: perf_reviews id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_reviews ALTER COLUMN id SET DEFAULT nextval('public.perf_reviews_id_seq'::regclass);


--
-- Name: permissions id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.permissions ALTER COLUMN id SET DEFAULT nextval('public.permissions_id_seq'::regclass);


--
-- Name: positions id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.positions ALTER COLUMN id SET DEFAULT nextval('public.positions_id_seq'::regclass);


--
-- Name: rec_applicants id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.rec_applicants ALTER COLUMN id SET DEFAULT nextval('public.rec_applicants_id_seq'::regclass);


--
-- Name: rec_application_history id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.rec_application_history ALTER COLUMN id SET DEFAULT nextval('public.rec_application_history_id_seq'::regclass);


--
-- Name: rec_job_postings id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.rec_job_postings ALTER COLUMN id SET DEFAULT nextval('public.rec_job_postings_id_seq'::regclass);


--
-- Name: role_feature_access id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.role_feature_access ALTER COLUMN id SET DEFAULT nextval('public.role_feature_access_id_seq'::regclass);


--
-- Name: role_page_access id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.role_page_access ALTER COLUMN id SET DEFAULT nextval('public.role_page_access_id_seq'::regclass);


--
-- Name: role_permissions id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.role_permissions ALTER COLUMN id SET DEFAULT nextval('public.role_permissions_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- Name: search_index id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.search_index ALTER COLUMN id SET DEFAULT nextval('public.search_index_id_seq'::regclass);


--
-- Name: status_definitions id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.status_definitions ALTER COLUMN id SET DEFAULT nextval('public.status_definitions_id_seq'::regclass);


--
-- Name: sys_audit_logs id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_audit_logs ALTER COLUMN id SET DEFAULT nextval('public.sys_audit_logs_id_seq'::regclass);


--
-- Name: sys_change_log id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_change_log ALTER COLUMN id SET DEFAULT nextval('public.sys_change_log_id_seq'::regclass);


--
-- Name: sys_compliance_reports id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_compliance_reports ALTER COLUMN id SET DEFAULT nextval('public.sys_compliance_reports_id_seq'::regclass);


--
-- Name: sys_field_changes id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_field_changes ALTER COLUMN id SET DEFAULT nextval('public.sys_field_changes_id_seq'::regclass);


--
-- Name: sys_integrations id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_integrations ALTER COLUMN id SET DEFAULT nextval('public.sys_integrations_id_seq'::regclass);


--
-- Name: sys_regulatory_deadlines id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_regulatory_deadlines ALTER COLUMN id SET DEFAULT nextval('public.sys_regulatory_deadlines_id_seq'::regclass);


--
-- Name: sys_sync_logs id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_sync_logs ALTER COLUMN id SET DEFAULT nextval('public.sys_sync_logs_id_seq'::regclass);


--
-- Name: transaction_qr_tokens id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.transaction_qr_tokens ALTER COLUMN id SET DEFAULT nextval('public.transaction_qr_tokens_id_seq'::regclass);


--
-- Name: transaction_registry id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.transaction_registry ALTER COLUMN id SET DEFAULT nextval('public.transaction_registry_id_seq'::regclass);


--
-- Name: transaction_timeline id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.transaction_timeline ALTER COLUMN id SET DEFAULT nextval('public.transaction_timeline_id_seq'::regclass);


--
-- Name: trn_employee_history id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.trn_employee_history ALTER COLUMN id SET DEFAULT nextval('public.trn_employee_history_id_seq'::regclass);


--
-- Name: trn_enrollments id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.trn_enrollments ALTER COLUMN id SET DEFAULT nextval('public.trn_enrollments_id_seq'::regclass);


--
-- Name: trn_programs id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.trn_programs ALTER COLUMN id SET DEFAULT nextval('public.trn_programs_id_seq'::regclass);


--
-- Name: trn_sessions id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.trn_sessions ALTER COLUMN id SET DEFAULT nextval('public.trn_sessions_id_seq'::regclass);


--
-- Name: ui_themes id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ui_themes ALTER COLUMN id SET DEFAULT nextval('public.ui_themes_id_seq'::regclass);


--
-- Name: user_roles id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.user_roles ALTER COLUMN id SET DEFAULT nextval('public.user_roles_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: workflow_action_logs id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_action_logs ALTER COLUMN id SET DEFAULT nextval('public.workflow_action_logs_id_seq'::regclass);


--
-- Name: workflow_checklist_items id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_checklist_items ALTER COLUMN id SET DEFAULT nextval('public.workflow_checklist_items_id_seq'::regclass);


--
-- Name: workflow_checklists id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_checklists ALTER COLUMN id SET DEFAULT nextval('public.workflow_checklists_id_seq'::regclass);


--
-- Name: workflow_definitions id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_definitions ALTER COLUMN id SET DEFAULT nextval('public.workflow_definitions_id_seq'::regclass);


--
-- Name: workflow_instances id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_instances ALTER COLUMN id SET DEFAULT nextval('public.workflow_instances_id_seq'::regclass);


--
-- Name: workflow_routes id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_routes ALTER COLUMN id SET DEFAULT nextval('public.workflow_routes_id_seq'::regclass);


--
-- Name: workflow_steps id; Type: DEFAULT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_steps ALTER COLUMN id SET DEFAULT nextval('public.workflow_steps_id_seq'::regclass);


--
-- Name: rec_applicants id; Type: DEFAULT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_applicants ALTER COLUMN id SET DEFAULT nextval('recruitment.rec_applicants_id_seq'::regclass);


--
-- Name: rec_appointments id; Type: DEFAULT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_appointments ALTER COLUMN id SET DEFAULT nextval('recruitment.rec_appointments_id_seq'::regclass);


--
-- Name: rec_csc_eligibilities id; Type: DEFAULT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_csc_eligibilities ALTER COLUMN id SET DEFAULT nextval('recruitment.rec_csc_eligibilities_id_seq'::regclass);


--
-- Name: rec_employee_eligibilities id; Type: DEFAULT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_employee_eligibilities ALTER COLUMN id SET DEFAULT nextval('recruitment.rec_employee_eligibilities_id_seq'::regclass);


--
-- Name: rec_interview_schedules id; Type: DEFAULT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_interview_schedules ALTER COLUMN id SET DEFAULT nextval('recruitment.rec_interview_schedules_id_seq'::regclass);


--
-- Name: rec_job_postings id; Type: DEFAULT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_job_postings ALTER COLUMN id SET DEFAULT nextval('recruitment.rec_job_postings_id_seq'::regclass);


--
-- Name: rec_next_in_rank_list id; Type: DEFAULT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_next_in_rank_list ALTER COLUMN id SET DEFAULT nextval('recruitment.rec_next_in_rank_list_id_seq'::regclass);


--
-- Name: rec_offers id; Type: DEFAULT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_offers ALTER COLUMN id SET DEFAULT nextval('recruitment.rec_offers_id_seq'::regclass);


--
-- Name: rec_plantilla_items id; Type: DEFAULT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_plantilla_items ALTER COLUMN id SET DEFAULT nextval('recruitment.rec_plantilla_items_id_seq'::regclass);


--
-- Name: rec_psb_deliberations id; Type: DEFAULT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_psb_deliberations ALTER COLUMN id SET DEFAULT nextval('recruitment.rec_psb_deliberations_id_seq'::regclass);


--
-- Name: rec_psb_members id; Type: DEFAULT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_psb_members ALTER COLUMN id SET DEFAULT nextval('recruitment.rec_psb_members_id_seq'::regclass);


--
-- Name: rec_psb_scores id; Type: DEFAULT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_psb_scores ALTER COLUMN id SET DEFAULT nextval('recruitment.rec_psb_scores_id_seq'::regclass);


--
-- Name: rec_publications id; Type: DEFAULT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_publications ALTER COLUMN id SET DEFAULT nextval('recruitment.rec_publications_id_seq'::regclass);


--
-- Name: rec_qualification_standards id; Type: DEFAULT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_qualification_standards ALTER COLUMN id SET DEFAULT nextval('recruitment.rec_qualification_standards_id_seq'::regclass);


--
-- Name: rec_requisitions id; Type: DEFAULT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_requisitions ALTER COLUMN id SET DEFAULT nextval('recruitment.rec_requisitions_id_seq'::regclass);


--
-- Name: rwd_awards id; Type: DEFAULT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_awards ALTER COLUMN id SET DEFAULT nextval('rewards.rwd_awards_id_seq'::regclass);


--
-- Name: rwd_categories id; Type: DEFAULT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_categories ALTER COLUMN id SET DEFAULT nextval('rewards.rwd_categories_id_seq'::regclass);


--
-- Name: rwd_loyalty_milestones id; Type: DEFAULT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_loyalty_milestones ALTER COLUMN id SET DEFAULT nextval('rewards.rwd_loyalty_milestones_id_seq'::regclass);


--
-- Name: rwd_nominations id; Type: DEFAULT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_nominations ALTER COLUMN id SET DEFAULT nextval('rewards.rwd_nominations_id_seq'::regclass);


--
-- Name: rwd_pbb_records id; Type: DEFAULT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_pbb_records ALTER COLUMN id SET DEFAULT nextval('rewards.rwd_pbb_records_id_seq'::regclass);


--
-- Name: rwd_praise_config id; Type: DEFAULT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_praise_config ALTER COLUMN id SET DEFAULT nextval('rewards.rwd_praise_config_id_seq'::regclass);


--
-- Name: rwd_retirement_alerts id; Type: DEFAULT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_retirement_alerts ALTER COLUMN id SET DEFAULT nextval('rewards.rwd_retirement_alerts_id_seq'::regclass);


--
-- Name: rwd_retirement_plans id; Type: DEFAULT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_retirement_plans ALTER COLUMN id SET DEFAULT nextval('rewards.rwd_retirement_plans_id_seq'::regclass);


--
-- Name: rwd_ssl_table id; Type: DEFAULT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_ssl_table ALTER COLUMN id SET DEFAULT nextval('rewards.rwd_ssl_table_id_seq'::regclass);


--
-- Name: rwd_step_increments id; Type: DEFAULT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_step_increments ALTER COLUMN id SET DEFAULT nextval('rewards.rwd_step_increments_id_seq'::regclass);


--
-- Name: instance_checklist_items id; Type: DEFAULT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.instance_checklist_items ALTER COLUMN id SET DEFAULT nextval('workflow.instance_checklist_items_id_seq'::regclass);


--
-- Name: workflow_action_logs id; Type: DEFAULT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_action_logs ALTER COLUMN id SET DEFAULT nextval('workflow.workflow_action_logs_id_seq'::regclass);


--
-- Name: workflow_checklists id; Type: DEFAULT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_checklists ALTER COLUMN id SET DEFAULT nextval('workflow.workflow_checklists_id_seq'::regclass);


--
-- Name: workflow_definitions id; Type: DEFAULT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_definitions ALTER COLUMN id SET DEFAULT nextval('workflow.workflow_definitions_id_seq'::regclass);


--
-- Name: workflow_event_hooks id; Type: DEFAULT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_event_hooks ALTER COLUMN id SET DEFAULT nextval('workflow.workflow_event_hooks_id_seq'::regclass);


--
-- Name: workflow_instances id; Type: DEFAULT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_instances ALTER COLUMN id SET DEFAULT nextval('workflow.workflow_instances_id_seq'::regclass);


--
-- Name: workflow_routes id; Type: DEFAULT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_routes ALTER COLUMN id SET DEFAULT nextval('workflow.workflow_routes_id_seq'::regclass);


--
-- Name: workflow_steps id; Type: DEFAULT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_steps ALTER COLUMN id SET DEFAULT nextval('workflow.workflow_steps_id_seq'::regclass);


--
-- Name: ai_feature_store ai_feature_store_employee_id_snapshot_date_key; Type: CONSTRAINT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_feature_store
    ADD CONSTRAINT ai_feature_store_employee_id_snapshot_date_key UNIQUE (employee_id, snapshot_date);


--
-- Name: ai_feature_store ai_feature_store_pkey; Type: CONSTRAINT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_feature_store
    ADD CONSTRAINT ai_feature_store_pkey PRIMARY KEY (id);


--
-- Name: ai_insight_results ai_insight_results_pkey; Type: CONSTRAINT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_insight_results
    ADD CONSTRAINT ai_insight_results_pkey PRIMARY KEY (id);


--
-- Name: ai_messages ai_messages_pkey; Type: CONSTRAINT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_messages
    ADD CONSTRAINT ai_messages_pkey PRIMARY KEY (id);


--
-- Name: ai_persona_configs ai_persona_configs_persona_code_key; Type: CONSTRAINT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_persona_configs
    ADD CONSTRAINT ai_persona_configs_persona_code_key UNIQUE (persona_code);


--
-- Name: ai_persona_configs ai_persona_configs_pkey; Type: CONSTRAINT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_persona_configs
    ADD CONSTRAINT ai_persona_configs_pkey PRIMARY KEY (id);


--
-- Name: ai_recommendations ai_recommendations_pkey; Type: CONSTRAINT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_recommendations
    ADD CONSTRAINT ai_recommendations_pkey PRIMARY KEY (id);


--
-- Name: ai_risk_scores ai_risk_scores_employee_id_score_date_risk_type_key; Type: CONSTRAINT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_risk_scores
    ADD CONSTRAINT ai_risk_scores_employee_id_score_date_risk_type_key UNIQUE (employee_id, score_date, risk_type);


--
-- Name: ai_risk_scores ai_risk_scores_pkey; Type: CONSTRAINT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_risk_scores
    ADD CONSTRAINT ai_risk_scores_pkey PRIMARY KEY (id);


--
-- Name: ai_sessions ai_sessions_pkey; Type: CONSTRAINT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_sessions
    ADD CONSTRAINT ai_sessions_pkey PRIMARY KEY (id);


--
-- Name: ai_sessions ai_sessions_session_token_key; Type: CONSTRAINT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_sessions
    ADD CONSTRAINT ai_sessions_session_token_key UNIQUE (session_token);


--
-- Name: ai_tool_call_logs ai_tool_call_logs_pkey; Type: CONSTRAINT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_tool_call_logs
    ADD CONSTRAINT ai_tool_call_logs_pkey PRIMARY KEY (id);


--
-- Name: dim_date dim_date_full_date_key; Type: CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.dim_date
    ADD CONSTRAINT dim_date_full_date_key UNIQUE (full_date);


--
-- Name: dim_date dim_date_pkey; Type: CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.dim_date
    ADD CONSTRAINT dim_date_pkey PRIMARY KEY (date_key);


--
-- Name: dim_department dim_department_pkey; Type: CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.dim_department
    ADD CONSTRAINT dim_department_pkey PRIMARY KEY (surrogate_key);


--
-- Name: dim_employee dim_employee_pkey; Type: CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.dim_employee
    ADD CONSTRAINT dim_employee_pkey PRIMARY KEY (surrogate_key);


--
-- Name: dim_position dim_position_pkey; Type: CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.dim_position
    ADD CONSTRAINT dim_position_pkey PRIMARY KEY (surrogate_key);


--
-- Name: fact_attendance fact_attendance_date_key_employee_key_key; Type: CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.fact_attendance
    ADD CONSTRAINT fact_attendance_date_key_employee_key_key UNIQUE (date_key, employee_key);


--
-- Name: fact_attendance fact_attendance_pkey; Type: CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.fact_attendance
    ADD CONSTRAINT fact_attendance_pkey PRIMARY KEY (id);


--
-- Name: fact_leave fact_leave_leave_request_id_key; Type: CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.fact_leave
    ADD CONSTRAINT fact_leave_leave_request_id_key UNIQUE (leave_request_id);


--
-- Name: fact_leave fact_leave_pkey; Type: CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.fact_leave
    ADD CONSTRAINT fact_leave_pkey PRIMARY KEY (id);


--
-- Name: fact_payroll fact_payroll_pkey; Type: CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.fact_payroll
    ADD CONSTRAINT fact_payroll_pkey PRIMARY KEY (id);


--
-- Name: fact_payroll fact_payroll_run_id_employee_key_key; Type: CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.fact_payroll
    ADD CONSTRAINT fact_payroll_run_id_employee_key_key UNIQUE (run_id, employee_key);


--
-- Name: fact_training fact_training_pkey; Type: CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.fact_training
    ADD CONSTRAINT fact_training_pkey PRIMARY KEY (id);


--
-- Name: kpi_snapshots kpi_snapshots_pkey; Type: CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.kpi_snapshots
    ADD CONSTRAINT kpi_snapshots_pkey PRIMARY KEY (id);


--
-- Name: report_data_sources report_data_sources_pkey; Type: CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.report_data_sources
    ADD CONSTRAINT report_data_sources_pkey PRIMARY KEY (id);


--
-- Name: report_data_sources report_data_sources_source_code_key; Type: CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.report_data_sources
    ADD CONSTRAINT report_data_sources_source_code_key UNIQUE (source_code);


--
-- Name: report_field_registry report_field_registry_pkey; Type: CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.report_field_registry
    ADD CONSTRAINT report_field_registry_pkey PRIMARY KEY (id);


--
-- Name: report_field_registry report_field_registry_source_id_field_code_key; Type: CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.report_field_registry
    ADD CONSTRAINT report_field_registry_source_id_field_code_key UNIQUE (source_id, field_code);


--
-- Name: report_run_history report_run_history_pkey; Type: CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.report_run_history
    ADD CONSTRAINT report_run_history_pkey PRIMARY KEY (id);


--
-- Name: report_schedules report_schedules_pkey; Type: CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.report_schedules
    ADD CONSTRAINT report_schedules_pkey PRIMARY KEY (id);


--
-- Name: saved_reports saved_reports_pkey; Type: CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.saved_reports
    ADD CONSTRAINT saved_reports_pkey PRIMARY KEY (id);


--
-- Name: att_admin_overrides att_admin_overrides_pkey; Type: CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_admin_overrides
    ADD CONSTRAINT att_admin_overrides_pkey PRIMARY KEY (id);


--
-- Name: att_daily att_daily_employee_id_work_date_key; Type: CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_daily
    ADD CONSTRAINT att_daily_employee_id_work_date_key UNIQUE (employee_id, work_date);


--
-- Name: att_daily att_daily_pkey; Type: CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_daily
    ADD CONSTRAINT att_daily_pkey PRIMARY KEY (id);


--
-- Name: att_dtr_corrections att_dtr_corrections_pkey; Type: CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_dtr_corrections
    ADD CONSTRAINT att_dtr_corrections_pkey PRIMARY KEY (id);


--
-- Name: att_holiday_types att_holiday_types_code_key; Type: CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_holiday_types
    ADD CONSTRAINT att_holiday_types_code_key UNIQUE (code);


--
-- Name: att_holiday_types att_holiday_types_pkey; Type: CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_holiday_types
    ADD CONSTRAINT att_holiday_types_pkey PRIMARY KEY (id);


--
-- Name: att_holidays att_holidays_company_id_holiday_date_name_key; Type: CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_holidays
    ADD CONSTRAINT att_holidays_company_id_holiday_date_name_key UNIQUE (company_id, holiday_date, name);


--
-- Name: att_holidays att_holidays_pkey; Type: CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_holidays
    ADD CONSTRAINT att_holidays_pkey PRIMARY KEY (id);


--
-- Name: att_logs att_logs_pkey; Type: CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_logs
    ADD CONSTRAINT att_logs_pkey PRIMARY KEY (id, log_datetime);


--
-- Name: att_logs_2025 att_logs_2025_pkey; Type: CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_logs_2025
    ADD CONSTRAINT att_logs_2025_pkey PRIMARY KEY (id, log_datetime);


--
-- Name: att_logs_2026 att_logs_2026_pkey; Type: CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_logs_2026
    ADD CONSTRAINT att_logs_2026_pkey PRIMARY KEY (id, log_datetime);


--
-- Name: att_logs_2027 att_logs_2027_pkey; Type: CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_logs_2027
    ADD CONSTRAINT att_logs_2027_pkey PRIMARY KEY (id, log_datetime);


--
-- Name: att_logs_2028 att_logs_2028_pkey; Type: CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_logs_2028
    ADD CONSTRAINT att_logs_2028_pkey PRIMARY KEY (id, log_datetime);


--
-- Name: att_overtime_requests att_overtime_requests_pkey; Type: CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_overtime_requests
    ADD CONSTRAINT att_overtime_requests_pkey PRIMARY KEY (id);


--
-- Name: att_shift_assignments att_shift_assignments_pkey; Type: CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_shift_assignments
    ADD CONSTRAINT att_shift_assignments_pkey PRIMARY KEY (id);


--
-- Name: att_shifts att_shifts_company_id_code_key; Type: CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_shifts
    ADD CONSTRAINT att_shifts_company_id_code_key UNIQUE (company_id, code);


--
-- Name: att_shifts att_shifts_pkey; Type: CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_shifts
    ADD CONSTRAINT att_shifts_pkey PRIMARY KEY (id);


--
-- Name: sys_bulk_operation_logs sys_bulk_operation_logs_pkey; Type: CONSTRAINT; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_bulk_operation_logs
    ADD CONSTRAINT sys_bulk_operation_logs_pkey PRIMARY KEY (id);


--
-- Name: sys_change_log sys_change_log_pkey; Type: CONSTRAINT; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_change_log
    ADD CONSTRAINT sys_change_log_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_change_log_2025 sys_change_log_2025_pkey; Type: CONSTRAINT; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_change_log_2025
    ADD CONSTRAINT sys_change_log_2025_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_change_log_2026 sys_change_log_2026_pkey; Type: CONSTRAINT; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_change_log_2026
    ADD CONSTRAINT sys_change_log_2026_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_change_log_2027 sys_change_log_2027_pkey; Type: CONSTRAINT; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_change_log_2027
    ADD CONSTRAINT sys_change_log_2027_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_change_log_2028 sys_change_log_2028_pkey; Type: CONSTRAINT; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_change_log_2028
    ADD CONSTRAINT sys_change_log_2028_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_data_exports sys_data_exports_pkey; Type: CONSTRAINT; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_data_exports
    ADD CONSTRAINT sys_data_exports_pkey PRIMARY KEY (id);


--
-- Name: sys_field_changes sys_field_changes_pkey; Type: CONSTRAINT; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_field_changes
    ADD CONSTRAINT sys_field_changes_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_field_changes_2025 sys_field_changes_2025_pkey; Type: CONSTRAINT; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_field_changes_2025
    ADD CONSTRAINT sys_field_changes_2025_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_field_changes_2026 sys_field_changes_2026_pkey; Type: CONSTRAINT; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_field_changes_2026
    ADD CONSTRAINT sys_field_changes_2026_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_field_changes_2027 sys_field_changes_2027_pkey; Type: CONSTRAINT; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_field_changes_2027
    ADD CONSTRAINT sys_field_changes_2027_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_field_changes_2028 sys_field_changes_2028_pkey; Type: CONSTRAINT; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_field_changes_2028
    ADD CONSTRAINT sys_field_changes_2028_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_login_logs sys_login_logs_pkey; Type: CONSTRAINT; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_login_logs
    ADD CONSTRAINT sys_login_logs_pkey PRIMARY KEY (id);


--
-- Name: sys_payroll_audit sys_payroll_audit_pkey; Type: CONSTRAINT; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_payroll_audit
    ADD CONSTRAINT sys_payroll_audit_pkey PRIMARY KEY (id);


--
-- Name: sys_status_transitions sys_status_transitions_pkey; Type: CONSTRAINT; Schema: audit_logs; Owner: hris_admin
--

ALTER TABLE ONLY audit_logs.sys_status_transitions
    ADD CONSTRAINT sys_status_transitions_pkey PRIMARY KEY (id);


--
-- Name: business_units business_units_company_id_code_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.business_units
    ADD CONSTRAINT business_units_company_id_code_key UNIQUE (company_id, code);


--
-- Name: business_units business_units_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.business_units
    ADD CONSTRAINT business_units_pkey PRIMARY KEY (id);


--
-- Name: companies companies_code_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.companies
    ADD CONSTRAINT companies_code_key UNIQUE (code);


--
-- Name: companies companies_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.companies
    ADD CONSTRAINT companies_pkey PRIMARY KEY (id);


--
-- Name: company_branding company_branding_key_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.company_branding
    ADD CONSTRAINT company_branding_key_key UNIQUE (key);


--
-- Name: company_branding company_branding_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.company_branding
    ADD CONSTRAINT company_branding_pkey PRIMARY KEY (id);


--
-- Name: dashboard_metrics dashboard_metrics_code_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.dashboard_metrics
    ADD CONSTRAINT dashboard_metrics_code_key UNIQUE (code);


--
-- Name: dashboard_metrics dashboard_metrics_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.dashboard_metrics
    ADD CONSTRAINT dashboard_metrics_pkey PRIMARY KEY (id);


--
-- Name: demo_profiles demo_profiles_code_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.demo_profiles
    ADD CONSTRAINT demo_profiles_code_key UNIQUE (code);


--
-- Name: demo_profiles demo_profiles_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.demo_profiles
    ADD CONSTRAINT demo_profiles_pkey PRIMARY KEY (id);


--
-- Name: departments departments_company_id_code_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.departments
    ADD CONSTRAINT departments_company_id_code_key UNIQUE (company_id, code);


--
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


--
-- Name: dynamic_forms dynamic_forms_form_code_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.dynamic_forms
    ADD CONSTRAINT dynamic_forms_form_code_key UNIQUE (form_code);


--
-- Name: dynamic_forms dynamic_forms_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.dynamic_forms
    ADD CONSTRAINT dynamic_forms_pkey PRIMARY KEY (id);


--
-- Name: emp_addresses emp_addresses_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_addresses
    ADD CONSTRAINT emp_addresses_pkey PRIMARY KEY (id);


--
-- Name: emp_bank_accounts emp_bank_accounts_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_bank_accounts
    ADD CONSTRAINT emp_bank_accounts_pkey PRIMARY KEY (id);


--
-- Name: emp_dependents emp_dependents_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_dependents
    ADD CONSTRAINT emp_dependents_pkey PRIMARY KEY (id);


--
-- Name: emp_education emp_education_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_education
    ADD CONSTRAINT emp_education_pkey PRIMARY KEY (id);


--
-- Name: emp_emergency_contacts emp_emergency_contacts_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_emergency_contacts
    ADD CONSTRAINT emp_emergency_contacts_pkey PRIMARY KEY (id);


--
-- Name: emp_government_ids emp_government_ids_employee_id_id_type_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_government_ids
    ADD CONSTRAINT emp_government_ids_employee_id_id_type_key UNIQUE (employee_id, id_type);


--
-- Name: emp_government_ids emp_government_ids_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_government_ids
    ADD CONSTRAINT emp_government_ids_pkey PRIMARY KEY (id);


--
-- Name: emp_status_history emp_status_history_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_status_history
    ADD CONSTRAINT emp_status_history_pkey PRIMARY KEY (id);


--
-- Name: emp_work_history emp_work_history_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_work_history
    ADD CONSTRAINT emp_work_history_pkey PRIMARY KEY (id);


--
-- Name: employees employees_company_id_employee_no_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.employees
    ADD CONSTRAINT employees_company_id_employee_no_key UNIQUE (company_id, employee_no);


--
-- Name: employees employees_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (id);


--
-- Name: employees employees_uuid_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.employees
    ADD CONSTRAINT employees_uuid_key UNIQUE (uuid);


--
-- Name: employment_types employment_types_code_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.employment_types
    ADD CONSTRAINT employment_types_code_key UNIQUE (code);


--
-- Name: employment_types employment_types_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.employment_types
    ADD CONSTRAINT employment_types_pkey PRIMARY KEY (id);


--
-- Name: feature_registry feature_registry_code_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.feature_registry
    ADD CONSTRAINT feature_registry_code_key UNIQUE (code);


--
-- Name: feature_registry feature_registry_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.feature_registry
    ADD CONSTRAINT feature_registry_pkey PRIMARY KEY (id);


--
-- Name: field_privacy_rules field_privacy_rules_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.field_privacy_rules
    ADD CONSTRAINT field_privacy_rules_pkey PRIMARY KEY (id);


--
-- Name: field_privacy_rules field_privacy_rules_section_field_name_role_code_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.field_privacy_rules
    ADD CONSTRAINT field_privacy_rules_section_field_name_role_code_key UNIQUE (section, field_name, role_code);


--
-- Name: form_fields form_fields_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.form_fields
    ADD CONSTRAINT form_fields_pkey PRIMARY KEY (id);


--
-- Name: job_grades job_grades_company_id_code_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.job_grades
    ADD CONSTRAINT job_grades_company_id_code_key UNIQUE (company_id, code);


--
-- Name: job_grades job_grades_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.job_grades
    ADD CONSTRAINT job_grades_pkey PRIMARY KEY (id);


--
-- Name: mod_permissions mod_permissions_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.mod_permissions
    ADD CONSTRAINT mod_permissions_pkey PRIMARY KEY (id);


--
-- Name: mod_permissions mp_role_unique; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.mod_permissions
    ADD CONSTRAINT mp_role_unique UNIQUE (module_code, grantee_type, grantee_role);


--
-- Name: mod_permissions mp_user_unique; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.mod_permissions
    ADD CONSTRAINT mp_user_unique UNIQUE (module_code, grantee_type, grantee_user_id);


--
-- Name: orchestration_flows orchestration_flows_flow_code_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.orchestration_flows
    ADD CONSTRAINT orchestration_flows_flow_code_key UNIQUE (flow_code);


--
-- Name: orchestration_flows orchestration_flows_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.orchestration_flows
    ADD CONSTRAINT orchestration_flows_pkey PRIMARY KEY (id);


--
-- Name: orchestration_steps orchestration_steps_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.orchestration_steps
    ADD CONSTRAINT orchestration_steps_pkey PRIMARY KEY (id);


--
-- Name: org_chart_nodes org_chart_nodes_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.org_chart_nodes
    ADD CONSTRAINT org_chart_nodes_pkey PRIMARY KEY (id);


--
-- Name: page_registry page_registry_path_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.page_registry
    ADD CONSTRAINT page_registry_path_key UNIQUE (path);


--
-- Name: page_registry page_registry_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.page_registry
    ADD CONSTRAINT page_registry_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_module_resource_action_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.permissions
    ADD CONSTRAINT permissions_module_resource_action_key UNIQUE (module, resource, action);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: positions positions_company_id_code_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.positions
    ADD CONSTRAINT positions_company_id_code_key UNIQUE (company_id, code);


--
-- Name: positions positions_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.positions
    ADD CONSTRAINT positions_pkey PRIMARY KEY (id);


--
-- Name: role_feature_access role_feature_access_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.role_feature_access
    ADD CONSTRAINT role_feature_access_pkey PRIMARY KEY (id);


--
-- Name: role_feature_access role_feature_access_role_code_feature_id_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.role_feature_access
    ADD CONSTRAINT role_feature_access_role_code_feature_id_key UNIQUE (role_code, feature_id);


--
-- Name: role_page_access role_page_access_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.role_page_access
    ADD CONSTRAINT role_page_access_pkey PRIMARY KEY (id);


--
-- Name: role_page_access role_page_access_role_code_page_id_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.role_page_access
    ADD CONSTRAINT role_page_access_role_code_page_id_key UNIQUE (role_code, page_id);


--
-- Name: role_permissions role_permissions_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.role_permissions
    ADD CONSTRAINT role_permissions_pkey PRIMARY KEY (id);


--
-- Name: role_permissions role_permissions_role_id_permission_id_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.role_permissions
    ADD CONSTRAINT role_permissions_role_id_permission_id_key UNIQUE (role_id, permission_id);


--
-- Name: roles roles_company_id_code_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.roles
    ADD CONSTRAINT roles_company_id_code_key UNIQUE (company_id, code);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: search_index search_index_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.search_index
    ADD CONSTRAINT search_index_pkey PRIMARY KEY (id);


--
-- Name: status_definitions status_definitions_module_code_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.status_definitions
    ADD CONSTRAINT status_definitions_module_code_key UNIQUE (module, code);


--
-- Name: status_definitions status_definitions_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.status_definitions
    ADD CONSTRAINT status_definitions_pkey PRIMARY KEY (id);


--
-- Name: task_inbox task_inbox_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.task_inbox
    ADD CONSTRAINT task_inbox_pkey PRIMARY KEY (id);


--
-- Name: transaction_qr_tokens transaction_qr_tokens_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.transaction_qr_tokens
    ADD CONSTRAINT transaction_qr_tokens_pkey PRIMARY KEY (id);


--
-- Name: transaction_qr_tokens transaction_qr_tokens_token_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.transaction_qr_tokens
    ADD CONSTRAINT transaction_qr_tokens_token_key UNIQUE (token);


--
-- Name: transaction_registry transaction_registry_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.transaction_registry
    ADD CONSTRAINT transaction_registry_pkey PRIMARY KEY (id);


--
-- Name: transaction_registry transaction_registry_type_code_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.transaction_registry
    ADD CONSTRAINT transaction_registry_type_code_key UNIQUE (type_code);


--
-- Name: ui_themes ui_themes_name_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.ui_themes
    ADD CONSTRAINT ui_themes_name_key UNIQUE (name);


--
-- Name: ui_themes ui_themes_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.ui_themes
    ADD CONSTRAINT ui_themes_pkey PRIMARY KEY (id);


--
-- Name: user_feature_access user_feature_access_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.user_feature_access
    ADD CONSTRAINT user_feature_access_pkey PRIMARY KEY (id);


--
-- Name: user_feature_access user_feature_access_user_id_feature_id_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.user_feature_access
    ADD CONSTRAINT user_feature_access_user_id_feature_id_key UNIQUE (user_id, feature_id);


--
-- Name: user_page_access user_page_access_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.user_page_access
    ADD CONSTRAINT user_page_access_pkey PRIMARY KEY (id);


--
-- Name: user_page_access user_page_access_user_id_page_id_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.user_page_access
    ADD CONSTRAINT user_page_access_user_id_page_id_key UNIQUE (user_id, page_id);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (id);


--
-- Name: user_roles user_roles_user_id_role_id_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.user_roles
    ADD CONSTRAINT user_roles_user_id_role_id_key UNIQUE (user_id, role_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: appeals appeals_pkey; Type: CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.appeals
    ADD CONSTRAINT appeals_pkey PRIMARY KEY (id);


--
-- Name: case_types case_types_code_key; Type: CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.case_types
    ADD CONSTRAINT case_types_code_key UNIQUE (code);


--
-- Name: case_types case_types_pkey; Type: CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.case_types
    ADD CONSTRAINT case_types_pkey PRIMARY KEY (id);


--
-- Name: cases cases_case_no_key; Type: CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.cases
    ADD CONSTRAINT cases_case_no_key UNIQUE (case_no);


--
-- Name: cases cases_pkey; Type: CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.cases
    ADD CONSTRAINT cases_pkey PRIMARY KEY (id);


--
-- Name: complaints complaints_pkey; Type: CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.complaints
    ADD CONSTRAINT complaints_pkey PRIMARY KEY (id);


--
-- Name: decisions decisions_pkey; Type: CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.decisions
    ADD CONSTRAINT decisions_pkey PRIMARY KEY (id);


--
-- Name: formal_charges formal_charges_pkey; Type: CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.formal_charges
    ADD CONSTRAINT formal_charges_pkey PRIMARY KEY (id);


--
-- Name: hearings hearings_pkey; Type: CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.hearings
    ADD CONSTRAINT hearings_pkey PRIMARY KEY (id);


--
-- Name: investigations investigations_pkey; Type: CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.investigations
    ADD CONSTRAINT investigations_pkey PRIMARY KEY (id);


--
-- Name: preventive_suspensions preventive_suspensions_pkey; Type: CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.preventive_suspensions
    ADD CONSTRAINT preventive_suspensions_pkey PRIMARY KEY (id);


--
-- Name: certificate_requests certificate_requests_pkey; Type: CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.certificate_requests
    ADD CONSTRAINT certificate_requests_pkey PRIMARY KEY (id);


--
-- Name: certificate_types certificate_types_code_key; Type: CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.certificate_types
    ADD CONSTRAINT certificate_types_code_key UNIQUE (code);


--
-- Name: certificate_types certificate_types_pkey; Type: CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.certificate_types
    ADD CONSTRAINT certificate_types_pkey PRIMARY KEY (id);


--
-- Name: checklist_items checklist_items_pkey; Type: CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.checklist_items
    ADD CONSTRAINT checklist_items_pkey PRIMARY KEY (id);


--
-- Name: checklist_templates checklist_templates_pkey; Type: CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.checklist_templates
    ADD CONSTRAINT checklist_templates_pkey PRIMARY KEY (id);


--
-- Name: document_categories document_categories_company_id_code_key; Type: CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.document_categories
    ADD CONSTRAINT document_categories_company_id_code_key UNIQUE (company_id, code);


--
-- Name: document_categories document_categories_pkey; Type: CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.document_categories
    ADD CONSTRAINT document_categories_pkey PRIMARY KEY (id);


--
-- Name: document_requests document_requests_pkey; Type: CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.document_requests
    ADD CONSTRAINT document_requests_pkey PRIMARY KEY (id);


--
-- Name: retention_policies retention_policies_company_id_category_id_key; Type: CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.retention_policies
    ADD CONSTRAINT retention_policies_company_id_category_id_key UNIQUE (company_id, category_id);


--
-- Name: retention_policies retention_policies_pkey; Type: CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.retention_policies
    ADD CONSTRAINT retention_policies_pkey PRIMARY KEY (id);


--
-- Name: service_record_snapshots service_record_snapshots_pkey; Type: CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.service_record_snapshots
    ADD CONSTRAINT service_record_snapshots_pkey PRIMARY KEY (id);


--
-- Name: health_certificates health_certificates_pkey; Type: CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.health_certificates
    ADD CONSTRAINT health_certificates_pkey PRIMARY KEY (id);


--
-- Name: incident_investigations incident_investigations_pkey; Type: CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.incident_investigations
    ADD CONSTRAINT incident_investigations_pkey PRIMARY KEY (id);


--
-- Name: incident_persons incident_persons_pkey; Type: CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.incident_persons
    ADD CONSTRAINT incident_persons_pkey PRIMARY KEY (id);


--
-- Name: incidents incidents_incident_no_key; Type: CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.incidents
    ADD CONSTRAINT incidents_incident_no_key UNIQUE (incident_no);


--
-- Name: incidents incidents_pkey; Type: CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.incidents
    ADD CONSTRAINT incidents_pkey PRIMARY KEY (id);


--
-- Name: medical_records medical_records_employee_id_key; Type: CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.medical_records
    ADD CONSTRAINT medical_records_employee_id_key UNIQUE (employee_id);


--
-- Name: medical_records medical_records_pkey; Type: CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.medical_records
    ADD CONSTRAINT medical_records_pkey PRIMARY KEY (id);


--
-- Name: pe_results pe_results_pkey; Type: CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.pe_results
    ADD CONSTRAINT pe_results_pkey PRIMARY KEY (id);


--
-- Name: pe_results pe_results_schedule_id_employee_id_key; Type: CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.pe_results
    ADD CONSTRAINT pe_results_schedule_id_employee_id_key UNIQUE (schedule_id, employee_id);


--
-- Name: pe_schedules pe_schedules_company_id_year_key; Type: CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.pe_schedules
    ADD CONSTRAINT pe_schedules_company_id_year_key UNIQUE (company_id, year);


--
-- Name: pe_schedules pe_schedules_pkey; Type: CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.pe_schedules
    ADD CONSTRAINT pe_schedules_pkey PRIMARY KEY (id);


--
-- Name: wellness_enrollments wellness_enrollments_pkey; Type: CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.wellness_enrollments
    ADD CONSTRAINT wellness_enrollments_pkey PRIMARY KEY (id);


--
-- Name: wellness_enrollments wellness_enrollments_program_id_employee_id_key; Type: CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.wellness_enrollments
    ADD CONSTRAINT wellness_enrollments_program_id_employee_id_key UNIQUE (program_id, employee_id);


--
-- Name: wellness_programs wellness_programs_pkey; Type: CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.wellness_programs
    ADD CONSTRAINT wellness_programs_pkey PRIMARY KEY (id);


--
-- Name: lrn_attendance_logs lrn_attendance_logs_pkey; Type: CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_attendance_logs
    ADD CONSTRAINT lrn_attendance_logs_pkey PRIMARY KEY (id);


--
-- Name: lrn_employee_skills lrn_employee_skills_employee_id_skill_id_key; Type: CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_employee_skills
    ADD CONSTRAINT lrn_employee_skills_employee_id_skill_id_key UNIQUE (employee_id, skill_id);


--
-- Name: lrn_employee_skills lrn_employee_skills_pkey; Type: CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_employee_skills
    ADD CONSTRAINT lrn_employee_skills_pkey PRIMARY KEY (id);


--
-- Name: lrn_enrollments lrn_enrollments_pkey; Type: CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_enrollments
    ADD CONSTRAINT lrn_enrollments_pkey PRIMARY KEY (id);


--
-- Name: lrn_enrollments lrn_enrollments_session_id_employee_id_key; Type: CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_enrollments
    ADD CONSTRAINT lrn_enrollments_session_id_employee_id_key UNIQUE (session_id, employee_id);


--
-- Name: lrn_idp_actions lrn_idp_actions_pkey; Type: CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_idp_actions
    ADD CONSTRAINT lrn_idp_actions_pkey PRIMARY KEY (id);


--
-- Name: lrn_lsp_registry lrn_lsp_registry_pkey; Type: CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_lsp_registry
    ADD CONSTRAINT lrn_lsp_registry_pkey PRIMARY KEY (id);


--
-- Name: lrn_narrative_reports lrn_narrative_reports_pkey; Type: CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_narrative_reports
    ADD CONSTRAINT lrn_narrative_reports_pkey PRIMARY KEY (id);


--
-- Name: lrn_programs lrn_programs_company_id_code_key; Type: CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_programs
    ADD CONSTRAINT lrn_programs_company_id_code_key UNIQUE (company_id, code);


--
-- Name: lrn_programs lrn_programs_pkey; Type: CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_programs
    ADD CONSTRAINT lrn_programs_pkey PRIMARY KEY (id);


--
-- Name: lrn_scholarships lrn_scholarships_pkey; Type: CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_scholarships
    ADD CONSTRAINT lrn_scholarships_pkey PRIMARY KEY (id);


--
-- Name: lrn_sessions lrn_sessions_pkey; Type: CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_sessions
    ADD CONSTRAINT lrn_sessions_pkey PRIMARY KEY (id);


--
-- Name: lrn_skills lrn_skills_pkey; Type: CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_skills
    ADD CONSTRAINT lrn_skills_pkey PRIMARY KEY (id);


--
-- Name: lrn_tna_entries lrn_tna_entries_pkey; Type: CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_tna_entries
    ADD CONSTRAINT lrn_tna_entries_pkey PRIMARY KEY (id);


--
-- Name: lv_approvals lv_approvals_pkey; Type: CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_approvals
    ADD CONSTRAINT lv_approvals_pkey PRIMARY KEY (id);


--
-- Name: lv_balance_adjustments lv_balance_adjustments_pkey; Type: CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_balance_adjustments
    ADD CONSTRAINT lv_balance_adjustments_pkey PRIMARY KEY (id);


--
-- Name: lv_balances lv_balances_employee_id_leave_type_id_year_key; Type: CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_balances
    ADD CONSTRAINT lv_balances_employee_id_leave_type_id_year_key UNIQUE (employee_id, leave_type_id, year);


--
-- Name: lv_balances lv_balances_pkey; Type: CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_balances
    ADD CONSTRAINT lv_balances_pkey PRIMARY KEY (id);


--
-- Name: lv_cto_credits lv_cto_credits_pkey; Type: CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_cto_credits
    ADD CONSTRAINT lv_cto_credits_pkey PRIMARY KEY (id);


--
-- Name: lv_holidays lv_holidays_company_id_hdate_name_key; Type: CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_holidays
    ADD CONSTRAINT lv_holidays_company_id_hdate_name_key UNIQUE (company_id, hdate, name);


--
-- Name: lv_holidays lv_holidays_pkey; Type: CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_holidays
    ADD CONSTRAINT lv_holidays_pkey PRIMARY KEY (id);


--
-- Name: lv_ledger lv_ledger_pkey; Type: CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_ledger
    ADD CONSTRAINT lv_ledger_pkey PRIMARY KEY (id);


--
-- Name: lv_locator_entries lv_locator_entries_employee_id_log_date_key; Type: CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_locator_entries
    ADD CONSTRAINT lv_locator_entries_employee_id_log_date_key UNIQUE (employee_id, log_date);


--
-- Name: lv_locator_entries lv_locator_entries_pkey; Type: CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_locator_entries
    ADD CONSTRAINT lv_locator_entries_pkey PRIMARY KEY (id);


--
-- Name: lv_policies lv_policies_pkey; Type: CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_policies
    ADD CONSTRAINT lv_policies_pkey PRIMARY KEY (id);


--
-- Name: lv_requests lv_requests_pkey; Type: CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_requests
    ADD CONSTRAINT lv_requests_pkey PRIMARY KEY (id);


--
-- Name: lv_requests lv_requests_reference_no_key; Type: CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_requests
    ADD CONSTRAINT lv_requests_reference_no_key UNIQUE (reference_no);


--
-- Name: lv_travel_orders lv_travel_orders_pkey; Type: CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_travel_orders
    ADD CONSTRAINT lv_travel_orders_pkey PRIMARY KEY (id);


--
-- Name: lv_travel_orders lv_travel_orders_reference_no_key; Type: CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_travel_orders
    ADD CONSTRAINT lv_travel_orders_reference_no_key UNIQUE (reference_no);


--
-- Name: lv_types lv_types_company_id_code_key; Type: CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_types
    ADD CONSTRAINT lv_types_company_id_code_key UNIQUE (company_id, code);


--
-- Name: lv_types lv_types_pkey; Type: CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_types
    ADD CONSTRAINT lv_types_pkey PRIMARY KEY (id);


--
-- Name: ntf_channels ntf_channels_code_key; Type: CONSTRAINT; Schema: notifications; Owner: hris_admin
--

ALTER TABLE ONLY notifications.ntf_channels
    ADD CONSTRAINT ntf_channels_code_key UNIQUE (code);


--
-- Name: ntf_channels ntf_channels_pkey; Type: CONSTRAINT; Schema: notifications; Owner: hris_admin
--

ALTER TABLE ONLY notifications.ntf_channels
    ADD CONSTRAINT ntf_channels_pkey PRIMARY KEY (id);


--
-- Name: ntf_in_app ntf_in_app_pkey; Type: CONSTRAINT; Schema: notifications; Owner: hris_admin
--

ALTER TABLE ONLY notifications.ntf_in_app
    ADD CONSTRAINT ntf_in_app_pkey PRIMARY KEY (id);


--
-- Name: ntf_queue ntf_queue_pkey; Type: CONSTRAINT; Schema: notifications; Owner: hris_admin
--

ALTER TABLE ONLY notifications.ntf_queue
    ADD CONSTRAINT ntf_queue_pkey PRIMARY KEY (id);


--
-- Name: ntf_templates ntf_templates_pkey; Type: CONSTRAINT; Schema: notifications; Owner: hris_admin
--

ALTER TABLE ONLY notifications.ntf_templates
    ADD CONSTRAINT ntf_templates_pkey PRIMARY KEY (id);


--
-- Name: ntf_templates ntf_templates_template_code_key; Type: CONSTRAINT; Schema: notifications; Owner: hris_admin
--

ALTER TABLE ONLY notifications.ntf_templates
    ADD CONSTRAINT ntf_templates_template_code_key UNIQUE (template_code);


--
-- Name: reminder_rules reminder_rules_code_key; Type: CONSTRAINT; Schema: notifications; Owner: hris_admin
--

ALTER TABLE ONLY notifications.reminder_rules
    ADD CONSTRAINT reminder_rules_code_key UNIQUE (code);


--
-- Name: reminder_rules reminder_rules_pkey; Type: CONSTRAINT; Schema: notifications; Owner: hris_admin
--

ALTER TABLE ONLY notifications.reminder_rules
    ADD CONSTRAINT reminder_rules_pkey PRIMARY KEY (id);


--
-- Name: offb_clearance_items offb_clearance_items_employee_id_clearance_type_key; Type: CONSTRAINT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.offb_clearance_items
    ADD CONSTRAINT offb_clearance_items_employee_id_clearance_type_key UNIQUE (employee_id, clearance_type);


--
-- Name: offb_clearance_items offb_clearance_items_pkey; Type: CONSTRAINT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.offb_clearance_items
    ADD CONSTRAINT offb_clearance_items_pkey PRIMARY KEY (id);


--
-- Name: offb_exit_interviews offb_exit_interviews_pkey; Type: CONSTRAINT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.offb_exit_interviews
    ADD CONSTRAINT offb_exit_interviews_pkey PRIMARY KEY (id);


--
-- Name: onb_buddy_assignments onb_buddy_assignments_pkey; Type: CONSTRAINT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.onb_buddy_assignments
    ADD CONSTRAINT onb_buddy_assignments_pkey PRIMARY KEY (id);


--
-- Name: onb_checklist_items onb_checklist_items_pkey; Type: CONSTRAINT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.onb_checklist_items
    ADD CONSTRAINT onb_checklist_items_pkey PRIMARY KEY (id);


--
-- Name: onb_checklists onb_checklists_pkey; Type: CONSTRAINT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.onb_checklists
    ADD CONSTRAINT onb_checklists_pkey PRIMARY KEY (id);


--
-- Name: onb_pre_employment_reqs onb_pre_employment_reqs_pkey; Type: CONSTRAINT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.onb_pre_employment_reqs
    ADD CONSTRAINT onb_pre_employment_reqs_pkey PRIMARY KEY (id);


--
-- Name: pay_13th_month pay_13th_month_employee_id_year_key; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_13th_month
    ADD CONSTRAINT pay_13th_month_employee_id_year_key UNIQUE (employee_id, year);


--
-- Name: pay_13th_month pay_13th_month_pkey; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_13th_month
    ADD CONSTRAINT pay_13th_month_pkey PRIMARY KEY (id);


--
-- Name: pay_adjustments pay_adjustments_pkey; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_adjustments
    ADD CONSTRAINT pay_adjustments_pkey PRIMARY KEY (id);


--
-- Name: pay_annual_bonuses pay_annual_bonuses_employee_id_bonus_type_year_key; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_annual_bonuses
    ADD CONSTRAINT pay_annual_bonuses_employee_id_bonus_type_year_key UNIQUE (employee_id, bonus_type, year);


--
-- Name: pay_annual_bonuses pay_annual_bonuses_pkey; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_annual_bonuses
    ADD CONSTRAINT pay_annual_bonuses_pkey PRIMARY KEY (id);


--
-- Name: pay_bir_tax_table pay_bir_tax_table_pkey; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_bir_tax_table
    ADD CONSTRAINT pay_bir_tax_table_pkey PRIMARY KEY (id);


--
-- Name: pay_coop_members pay_coop_members_pkey; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_coop_members
    ADD CONSTRAINT pay_coop_members_pkey PRIMARY KEY (id);


--
-- Name: pay_employee_allowances_gov pay_employee_allowances_gov_pkey; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_employee_allowances_gov
    ADD CONSTRAINT pay_employee_allowances_gov_pkey PRIMARY KEY (id);


--
-- Name: pay_employee_allowances pay_employee_allowances_pkey; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_employee_allowances
    ADD CONSTRAINT pay_employee_allowances_pkey PRIMARY KEY (id);


--
-- Name: pay_employee_payroll pay_employee_payroll_pkey; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_employee_payroll
    ADD CONSTRAINT pay_employee_payroll_pkey PRIMARY KEY (id);


--
-- Name: pay_employee_payroll pay_employee_payroll_run_id_employee_id_key; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_employee_payroll
    ADD CONSTRAINT pay_employee_payroll_run_id_employee_id_key UNIQUE (run_id, employee_id);


--
-- Name: pay_gov_allowances pay_gov_allowances_allowance_code_key; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_gov_allowances
    ADD CONSTRAINT pay_gov_allowances_allowance_code_key UNIQUE (allowance_code);


--
-- Name: pay_gov_allowances pay_gov_allowances_pkey; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_gov_allowances
    ADD CONSTRAINT pay_gov_allowances_pkey PRIMARY KEY (id);


--
-- Name: pay_government_remittances pay_government_remittances_pkey; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_government_remittances
    ADD CONSTRAINT pay_government_remittances_pkey PRIMARY KEY (id);


--
-- Name: pay_government_remittances pay_government_remittances_run_id_agency_key; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_government_remittances
    ADD CONSTRAINT pay_government_remittances_run_id_agency_key UNIQUE (run_id, agency);


--
-- Name: pay_gsis_schedule pay_gsis_schedule_pkey; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_gsis_schedule
    ADD CONSTRAINT pay_gsis_schedule_pkey PRIMARY KEY (id);


--
-- Name: pay_loan_payments pay_loan_payments_pkey; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_loan_payments
    ADD CONSTRAINT pay_loan_payments_pkey PRIMARY KEY (id);


--
-- Name: pay_loans pay_loans_pkey; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_loans
    ADD CONSTRAINT pay_loans_pkey PRIMARY KEY (id);


--
-- Name: pay_loans pay_loans_reference_no_key; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_loans
    ADD CONSTRAINT pay_loans_reference_no_key UNIQUE (reference_no);


--
-- Name: pay_pagibig_schedule pay_pagibig_schedule_pkey; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_pagibig_schedule
    ADD CONSTRAINT pay_pagibig_schedule_pkey PRIMARY KEY (id);


--
-- Name: pay_periods pay_periods_company_id_period_code_key; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_periods
    ADD CONSTRAINT pay_periods_company_id_period_code_key UNIQUE (company_id, period_code);


--
-- Name: pay_periods pay_periods_pkey; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_periods
    ADD CONSTRAINT pay_periods_pkey PRIMARY KEY (id);


--
-- Name: pay_rata_schedule pay_rata_schedule_pkey; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_rata_schedule
    ADD CONSTRAINT pay_rata_schedule_pkey PRIMARY KEY (id);


--
-- Name: pay_runs pay_runs_period_id_run_number_key; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_runs
    ADD CONSTRAINT pay_runs_period_id_run_number_key UNIQUE (period_id, run_number);


--
-- Name: pay_runs pay_runs_pkey; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_runs
    ADD CONSTRAINT pay_runs_pkey PRIMARY KEY (id);


--
-- Name: pay_tax_tables pay_tax_tables_pkey; Type: CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_tax_tables
    ADD CONSTRAINT pay_tax_tables_pkey PRIMARY KEY (id);


--
-- Name: perf_competencies perf_competencies_pkey; Type: CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_competencies
    ADD CONSTRAINT perf_competencies_pkey PRIMARY KEY (id);


--
-- Name: perf_cycles perf_cycles_pkey; Type: CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_cycles
    ADD CONSTRAINT perf_cycles_pkey PRIMARY KEY (id);


--
-- Name: perf_employee_kpis perf_employee_kpis_pkey; Type: CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_employee_kpis
    ADD CONSTRAINT perf_employee_kpis_pkey PRIMARY KEY (id);


--
-- Name: perf_idp_plans perf_idp_plans_pkey; Type: CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_idp_plans
    ADD CONSTRAINT perf_idp_plans_pkey PRIMARY KEY (id);


--
-- Name: perf_ipcr perf_ipcr_pkey; Type: CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_ipcr
    ADD CONSTRAINT perf_ipcr_pkey PRIMARY KEY (id);


--
-- Name: perf_ipcr_summary perf_ipcr_summary_employee_id_cycle_id_key; Type: CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_ipcr_summary
    ADD CONSTRAINT perf_ipcr_summary_employee_id_cycle_id_key UNIQUE (employee_id, cycle_id);


--
-- Name: perf_ipcr_summary perf_ipcr_summary_pkey; Type: CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_ipcr_summary
    ADD CONSTRAINT perf_ipcr_summary_pkey PRIMARY KEY (id);


--
-- Name: perf_opcr perf_opcr_pkey; Type: CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_opcr
    ADD CONSTRAINT perf_opcr_pkey PRIMARY KEY (id);


--
-- Name: perf_reviews perf_reviews_cycle_id_employee_id_reviewer_id_key; Type: CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_reviews
    ADD CONSTRAINT perf_reviews_cycle_id_employee_id_reviewer_id_key UNIQUE (cycle_id, employee_id, reviewer_id);


--
-- Name: perf_reviews perf_reviews_pkey; Type: CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_reviews
    ADD CONSTRAINT perf_reviews_pkey PRIMARY KEY (id);


--
-- Name: perf_strategic_plans perf_strategic_plans_company_id_year_key; Type: CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_strategic_plans
    ADD CONSTRAINT perf_strategic_plans_company_id_year_key UNIQUE (company_id, year);


--
-- Name: perf_strategic_plans perf_strategic_plans_pkey; Type: CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_strategic_plans
    ADD CONSTRAINT perf_strategic_plans_pkey PRIMARY KEY (id);


--
-- Name: perf_succession_matrix perf_succession_matrix_key_position_id_successor_employee_i_key; Type: CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_succession_matrix
    ADD CONSTRAINT perf_succession_matrix_key_position_id_successor_employee_i_key UNIQUE (key_position_id, successor_employee_id);


--
-- Name: perf_succession_matrix perf_succession_matrix_pkey; Type: CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_succession_matrix
    ADD CONSTRAINT perf_succession_matrix_pkey PRIMARY KEY (id);


--
-- Name: ai_persona_configs ai_persona_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ai_persona_configs
    ADD CONSTRAINT ai_persona_configs_pkey PRIMARY KEY (id);


--
-- Name: ai_persona_configs ai_persona_configs_role_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ai_persona_configs
    ADD CONSTRAINT ai_persona_configs_role_code_key UNIQUE (role_code);


--
-- Name: analytics_metric_definitions analytics_metric_definitions_metric_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.analytics_metric_definitions
    ADD CONSTRAINT analytics_metric_definitions_metric_code_key UNIQUE (metric_code);


--
-- Name: analytics_metric_definitions analytics_metric_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.analytics_metric_definitions
    ADD CONSTRAINT analytics_metric_definitions_pkey PRIMARY KEY (id);


--
-- Name: att_daily att_daily_employee_id_work_date_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_daily
    ADD CONSTRAINT att_daily_employee_id_work_date_key UNIQUE (employee_id, work_date);


--
-- Name: att_daily att_daily_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_daily
    ADD CONSTRAINT att_daily_pkey PRIMARY KEY (id);


--
-- Name: att_holiday_types att_holiday_types_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_holiday_types
    ADD CONSTRAINT att_holiday_types_code_key UNIQUE (code);


--
-- Name: att_holiday_types att_holiday_types_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_holiday_types
    ADD CONSTRAINT att_holiday_types_pkey PRIMARY KEY (id);


--
-- Name: att_holidays att_holidays_company_id_holiday_date_name_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_holidays
    ADD CONSTRAINT att_holidays_company_id_holiday_date_name_key UNIQUE (company_id, holiday_date, name);


--
-- Name: att_holidays att_holidays_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_holidays
    ADD CONSTRAINT att_holidays_pkey PRIMARY KEY (id);


--
-- Name: att_logs att_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_logs
    ADD CONSTRAINT att_logs_pkey PRIMARY KEY (id, log_datetime);


--
-- Name: att_logs_2025 att_logs_2025_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_logs_2025
    ADD CONSTRAINT att_logs_2025_pkey PRIMARY KEY (id, log_datetime);


--
-- Name: att_logs_2026 att_logs_2026_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_logs_2026
    ADD CONSTRAINT att_logs_2026_pkey PRIMARY KEY (id, log_datetime);


--
-- Name: att_logs_2027 att_logs_2027_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_logs_2027
    ADD CONSTRAINT att_logs_2027_pkey PRIMARY KEY (id, log_datetime);


--
-- Name: att_logs_2028 att_logs_2028_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_logs_2028
    ADD CONSTRAINT att_logs_2028_pkey PRIMARY KEY (id, log_datetime);


--
-- Name: att_overtime_requests att_overtime_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_overtime_requests
    ADD CONSTRAINT att_overtime_requests_pkey PRIMARY KEY (id);


--
-- Name: att_shift_assignments att_shift_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_shift_assignments
    ADD CONSTRAINT att_shift_assignments_pkey PRIMARY KEY (id);


--
-- Name: att_shifts att_shifts_company_id_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_shifts
    ADD CONSTRAINT att_shifts_company_id_code_key UNIQUE (company_id, code);


--
-- Name: att_shifts att_shifts_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_shifts
    ADD CONSTRAINT att_shifts_pkey PRIMARY KEY (id);


--
-- Name: business_units business_units_company_id_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.business_units
    ADD CONSTRAINT business_units_company_id_code_key UNIQUE (company_id, code);


--
-- Name: business_units business_units_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.business_units
    ADD CONSTRAINT business_units_pkey PRIMARY KEY (id);


--
-- Name: companies companies_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_code_key UNIQUE (code);


--
-- Name: companies companies_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_pkey PRIMARY KEY (id);


--
-- Name: company_branding company_branding_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.company_branding
    ADD CONSTRAINT company_branding_pkey PRIMARY KEY (id);


--
-- Name: dashboard_metrics dashboard_metrics_metric_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.dashboard_metrics
    ADD CONSTRAINT dashboard_metrics_metric_code_key UNIQUE (metric_code);


--
-- Name: dashboard_metrics dashboard_metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.dashboard_metrics
    ADD CONSTRAINT dashboard_metrics_pkey PRIMARY KEY (id);


--
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);


--
-- Name: dim_date dim_date_full_date_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.dim_date
    ADD CONSTRAINT dim_date_full_date_key UNIQUE (full_date);


--
-- Name: dim_date dim_date_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.dim_date
    ADD CONSTRAINT dim_date_pkey PRIMARY KEY (date_key);


--
-- Name: dim_employee dim_employee_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.dim_employee
    ADD CONSTRAINT dim_employee_pkey PRIMARY KEY (surrogate_key);


--
-- Name: doc_categories doc_categories_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.doc_categories
    ADD CONSTRAINT doc_categories_code_key UNIQUE (code);


--
-- Name: doc_categories doc_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.doc_categories
    ADD CONSTRAINT doc_categories_pkey PRIMARY KEY (id);


--
-- Name: doc_employee_files doc_employee_files_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.doc_employee_files
    ADD CONSTRAINT doc_employee_files_pkey PRIMARY KEY (id);


--
-- Name: doc_versions doc_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.doc_versions
    ADD CONSTRAINT doc_versions_pkey PRIMARY KEY (id);


--
-- Name: dq_column_stats dq_column_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.dq_column_stats
    ADD CONSTRAINT dq_column_stats_pkey PRIMARY KEY (id);


--
-- Name: dq_data_issues dq_data_issues_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.dq_data_issues
    ADD CONSTRAINT dq_data_issues_pkey PRIMARY KEY (id);


--
-- Name: dynamic_forms dynamic_forms_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.dynamic_forms
    ADD CONSTRAINT dynamic_forms_pkey PRIMARY KEY (id);


--
-- Name: emp_addresses emp_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.emp_addresses
    ADD CONSTRAINT emp_addresses_pkey PRIMARY KEY (id);


--
-- Name: emp_bank_accounts emp_bank_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.emp_bank_accounts
    ADD CONSTRAINT emp_bank_accounts_pkey PRIMARY KEY (id);


--
-- Name: emp_dependents emp_dependents_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.emp_dependents
    ADD CONSTRAINT emp_dependents_pkey PRIMARY KEY (id);


--
-- Name: emp_education emp_education_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.emp_education
    ADD CONSTRAINT emp_education_pkey PRIMARY KEY (id);


--
-- Name: emp_emergency_contacts emp_emergency_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.emp_emergency_contacts
    ADD CONSTRAINT emp_emergency_contacts_pkey PRIMARY KEY (id);


--
-- Name: emp_government_ids emp_government_ids_employee_id_id_type_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.emp_government_ids
    ADD CONSTRAINT emp_government_ids_employee_id_id_type_key UNIQUE (employee_id, id_type);


--
-- Name: emp_government_ids emp_government_ids_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.emp_government_ids
    ADD CONSTRAINT emp_government_ids_pkey PRIMARY KEY (id);


--
-- Name: emp_status_history emp_status_history_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.emp_status_history
    ADD CONSTRAINT emp_status_history_pkey PRIMARY KEY (id);


--
-- Name: emp_work_history emp_work_history_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.emp_work_history
    ADD CONSTRAINT emp_work_history_pkey PRIMARY KEY (id);


--
-- Name: employee_documents employee_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.employee_documents
    ADD CONSTRAINT employee_documents_pkey PRIMARY KEY (id);


--
-- Name: employees employees_employee_no_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_employee_no_key UNIQUE (employee_no);


--
-- Name: employees employees_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (id);


--
-- Name: employment_types employment_types_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.employment_types
    ADD CONSTRAINT employment_types_code_key UNIQUE (code);


--
-- Name: employment_types employment_types_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.employment_types
    ADD CONSTRAINT employment_types_pkey PRIMARY KEY (id);


--
-- Name: fact_attendance fact_attendance_employee_id_date_key_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_attendance
    ADD CONSTRAINT fact_attendance_employee_id_date_key_key UNIQUE (employee_id, date_key);


--
-- Name: fact_attendance fact_attendance_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_attendance
    ADD CONSTRAINT fact_attendance_pkey PRIMARY KEY (id);


--
-- Name: fact_leave fact_leave_leave_request_id_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_leave
    ADD CONSTRAINT fact_leave_leave_request_id_key UNIQUE (leave_request_id);


--
-- Name: fact_leave fact_leave_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_leave
    ADD CONSTRAINT fact_leave_pkey PRIMARY KEY (id);


--
-- Name: fact_payroll fact_payroll_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_payroll
    ADD CONSTRAINT fact_payroll_pkey PRIMARY KEY (id);


--
-- Name: fact_payroll fact_payroll_run_id_employee_id_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_payroll
    ADD CONSTRAINT fact_payroll_run_id_employee_id_key UNIQUE (run_id, employee_id);


--
-- Name: fact_performance fact_performance_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_performance
    ADD CONSTRAINT fact_performance_pkey PRIMARY KEY (id);


--
-- Name: fact_performance fact_performance_review_id_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_performance
    ADD CONSTRAINT fact_performance_review_id_key UNIQUE (review_id);


--
-- Name: fact_recruitment fact_recruitment_applicant_id_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_recruitment
    ADD CONSTRAINT fact_recruitment_applicant_id_key UNIQUE (applicant_id);


--
-- Name: fact_recruitment fact_recruitment_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_recruitment
    ADD CONSTRAINT fact_recruitment_pkey PRIMARY KEY (id);


--
-- Name: feature_registry feature_registry_feature_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.feature_registry
    ADD CONSTRAINT feature_registry_feature_code_key UNIQUE (feature_code);


--
-- Name: feature_registry feature_registry_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.feature_registry
    ADD CONSTRAINT feature_registry_pkey PRIMARY KEY (id);


--
-- Name: form_fields form_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.form_fields
    ADD CONSTRAINT form_fields_pkey PRIMARY KEY (id);


--
-- Name: instance_checklist_items instance_checklist_items_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.instance_checklist_items
    ADD CONSTRAINT instance_checklist_items_pkey PRIMARY KEY (id);


--
-- Name: job_grades job_grades_company_id_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.job_grades
    ADD CONSTRAINT job_grades_company_id_code_key UNIQUE (company_id, code);


--
-- Name: job_grades job_grades_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.job_grades
    ADD CONSTRAINT job_grades_pkey PRIMARY KEY (id);


--
-- Name: kpi_query_registry kpi_query_registry_kpi_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.kpi_query_registry
    ADD CONSTRAINT kpi_query_registry_kpi_code_key UNIQUE (kpi_code);


--
-- Name: kpi_query_registry kpi_query_registry_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.kpi_query_registry
    ADD CONSTRAINT kpi_query_registry_pkey PRIMARY KEY (id);


--
-- Name: lv_approvals lv_approvals_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.lv_approvals
    ADD CONSTRAINT lv_approvals_pkey PRIMARY KEY (id);


--
-- Name: lv_balances lv_balances_employee_id_leave_type_id_year_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.lv_balances
    ADD CONSTRAINT lv_balances_employee_id_leave_type_id_year_key UNIQUE (employee_id, leave_type_id, year);


--
-- Name: lv_balances lv_balances_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.lv_balances
    ADD CONSTRAINT lv_balances_pkey PRIMARY KEY (id);


--
-- Name: lv_ledger lv_ledger_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.lv_ledger
    ADD CONSTRAINT lv_ledger_pkey PRIMARY KEY (id);


--
-- Name: lv_policies lv_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.lv_policies
    ADD CONSTRAINT lv_policies_pkey PRIMARY KEY (id);


--
-- Name: lv_requests lv_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.lv_requests
    ADD CONSTRAINT lv_requests_pkey PRIMARY KEY (id);


--
-- Name: lv_types lv_types_company_id_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.lv_types
    ADD CONSTRAINT lv_types_company_id_code_key UNIQUE (company_id, code);


--
-- Name: lv_types lv_types_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.lv_types
    ADD CONSTRAINT lv_types_pkey PRIMARY KEY (id);


--
-- Name: ml_feature_catalog ml_feature_catalog_feature_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ml_feature_catalog
    ADD CONSTRAINT ml_feature_catalog_feature_code_key UNIQUE (feature_code);


--
-- Name: ml_feature_catalog ml_feature_catalog_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ml_feature_catalog
    ADD CONSTRAINT ml_feature_catalog_pkey PRIMARY KEY (id);


--
-- Name: ml_model_monitoring ml_model_monitoring_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ml_model_monitoring
    ADD CONSTRAINT ml_model_monitoring_pkey PRIMARY KEY (id);


--
-- Name: ml_model_versions ml_model_versions_model_id_version_tag_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ml_model_versions
    ADD CONSTRAINT ml_model_versions_model_id_version_tag_key UNIQUE (model_id, version_tag);


--
-- Name: ml_model_versions ml_model_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ml_model_versions
    ADD CONSTRAINT ml_model_versions_pkey PRIMARY KEY (id);


--
-- Name: ml_models ml_models_model_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ml_models
    ADD CONSTRAINT ml_models_model_code_key UNIQUE (model_code);


--
-- Name: ml_models ml_models_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ml_models
    ADD CONSTRAINT ml_models_pkey PRIMARY KEY (id);


--
-- Name: ml_training_datasets ml_training_datasets_dataset_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ml_training_datasets
    ADD CONSTRAINT ml_training_datasets_dataset_code_key UNIQUE (dataset_code);


--
-- Name: ml_training_datasets ml_training_datasets_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ml_training_datasets
    ADD CONSTRAINT ml_training_datasets_pkey PRIMARY KEY (id);


--
-- Name: ntf_notifications ntf_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ntf_notifications
    ADD CONSTRAINT ntf_notifications_pkey PRIMARY KEY (id, created_at);


--
-- Name: ntf_notifications_2025 ntf_notifications_2025_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ntf_notifications_2025
    ADD CONSTRAINT ntf_notifications_2025_pkey PRIMARY KEY (id, created_at);


--
-- Name: ntf_notifications_2026 ntf_notifications_2026_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ntf_notifications_2026
    ADD CONSTRAINT ntf_notifications_2026_pkey PRIMARY KEY (id, created_at);


--
-- Name: ntf_notifications_2027 ntf_notifications_2027_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ntf_notifications_2027
    ADD CONSTRAINT ntf_notifications_2027_pkey PRIMARY KEY (id, created_at);


--
-- Name: ntf_notifications_2028 ntf_notifications_2028_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ntf_notifications_2028
    ADD CONSTRAINT ntf_notifications_2028_pkey PRIMARY KEY (id, created_at);


--
-- Name: ntf_templates ntf_templates_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ntf_templates
    ADD CONSTRAINT ntf_templates_code_key UNIQUE (code);


--
-- Name: ntf_templates ntf_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ntf_templates
    ADD CONSTRAINT ntf_templates_pkey PRIMARY KEY (id);


--
-- Name: orchestration_flows orchestration_flows_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.orchestration_flows
    ADD CONSTRAINT orchestration_flows_pkey PRIMARY KEY (id);


--
-- Name: orchestration_steps orchestration_steps_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.orchestration_steps
    ADD CONSTRAINT orchestration_steps_pkey PRIMARY KEY (id);


--
-- Name: page_registry page_registry_page_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.page_registry
    ADD CONSTRAINT page_registry_page_code_key UNIQUE (page_code);


--
-- Name: page_registry page_registry_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.page_registry
    ADD CONSTRAINT page_registry_pkey PRIMARY KEY (id);


--
-- Name: pay_13th_month pay_13th_month_company_id_employee_id_year_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_13th_month
    ADD CONSTRAINT pay_13th_month_company_id_employee_id_year_key UNIQUE (company_id, employee_id, year);


--
-- Name: pay_13th_month pay_13th_month_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_13th_month
    ADD CONSTRAINT pay_13th_month_pkey PRIMARY KEY (id);


--
-- Name: pay_bir_tax_table pay_bir_tax_table_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_bir_tax_table
    ADD CONSTRAINT pay_bir_tax_table_pkey PRIMARY KEY (id);


--
-- Name: pay_deductions_detail pay_deductions_detail_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_deductions_detail
    ADD CONSTRAINT pay_deductions_detail_pkey PRIMARY KEY (id);


--
-- Name: pay_earnings_detail pay_earnings_detail_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_earnings_detail
    ADD CONSTRAINT pay_earnings_detail_pkey PRIMARY KEY (id);


--
-- Name: pay_employee_allowances pay_employee_allowances_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_employee_allowances
    ADD CONSTRAINT pay_employee_allowances_pkey PRIMARY KEY (id);


--
-- Name: pay_employee_loans pay_employee_loans_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_employee_loans
    ADD CONSTRAINT pay_employee_loans_pkey PRIMARY KEY (id);


--
-- Name: pay_employee_payroll pay_employee_payroll_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_employee_payroll
    ADD CONSTRAINT pay_employee_payroll_pkey PRIMARY KEY (id);


--
-- Name: pay_employee_payroll pay_employee_payroll_run_id_employee_id_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_employee_payroll
    ADD CONSTRAINT pay_employee_payroll_run_id_employee_id_key UNIQUE (run_id, employee_id);


--
-- Name: pay_pagibig_table pay_pagibig_table_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_pagibig_table
    ADD CONSTRAINT pay_pagibig_table_pkey PRIMARY KEY (id);


--
-- Name: pay_periods pay_periods_company_id_period_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_periods
    ADD CONSTRAINT pay_periods_company_id_period_code_key UNIQUE (company_id, period_code);


--
-- Name: pay_periods pay_periods_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_periods
    ADD CONSTRAINT pay_periods_pkey PRIMARY KEY (id);


--
-- Name: pay_philhealth_table pay_philhealth_table_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_philhealth_table
    ADD CONSTRAINT pay_philhealth_table_pkey PRIMARY KEY (id);


--
-- Name: pay_runs pay_runs_period_id_run_number_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_runs
    ADD CONSTRAINT pay_runs_period_id_run_number_key UNIQUE (period_id, run_number);


--
-- Name: pay_runs pay_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_runs
    ADD CONSTRAINT pay_runs_pkey PRIMARY KEY (id);


--
-- Name: pay_sss_table pay_sss_table_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_sss_table
    ADD CONSTRAINT pay_sss_table_pkey PRIMARY KEY (id);


--
-- Name: perf_cycles perf_cycles_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_cycles
    ADD CONSTRAINT perf_cycles_pkey PRIMARY KEY (id);


--
-- Name: perf_employee_kpis perf_employee_kpis_cycle_id_employee_id_kpi_id_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_employee_kpis
    ADD CONSTRAINT perf_employee_kpis_cycle_id_employee_id_kpi_id_key UNIQUE (cycle_id, employee_id, kpi_id);


--
-- Name: perf_employee_kpis perf_employee_kpis_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_employee_kpis
    ADD CONSTRAINT perf_employee_kpis_pkey PRIMARY KEY (id);


--
-- Name: perf_kpi_categories perf_kpi_categories_company_id_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_kpi_categories
    ADD CONSTRAINT perf_kpi_categories_company_id_code_key UNIQUE (company_id, code);


--
-- Name: perf_kpi_categories perf_kpi_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_kpi_categories
    ADD CONSTRAINT perf_kpi_categories_pkey PRIMARY KEY (id);


--
-- Name: perf_kpis perf_kpis_company_id_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_kpis
    ADD CONSTRAINT perf_kpis_company_id_code_key UNIQUE (company_id, code);


--
-- Name: perf_kpis perf_kpis_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_kpis
    ADD CONSTRAINT perf_kpis_pkey PRIMARY KEY (id);


--
-- Name: perf_review_feedback perf_review_feedback_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_review_feedback
    ADD CONSTRAINT perf_review_feedback_pkey PRIMARY KEY (id);


--
-- Name: perf_review_ratings perf_review_ratings_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_review_ratings
    ADD CONSTRAINT perf_review_ratings_pkey PRIMARY KEY (id);


--
-- Name: perf_reviews perf_reviews_cycle_id_employee_id_reviewer_id_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_reviews
    ADD CONSTRAINT perf_reviews_cycle_id_employee_id_reviewer_id_key UNIQUE (cycle_id, employee_id, reviewer_id);


--
-- Name: perf_reviews perf_reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_reviews
    ADD CONSTRAINT perf_reviews_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_module_resource_action_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_module_resource_action_key UNIQUE (module, resource, action);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: positions positions_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.positions
    ADD CONSTRAINT positions_pkey PRIMARY KEY (id);


--
-- Name: rec_applicants rec_applicants_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.rec_applicants
    ADD CONSTRAINT rec_applicants_pkey PRIMARY KEY (id);


--
-- Name: rec_application_history rec_application_history_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.rec_application_history
    ADD CONSTRAINT rec_application_history_pkey PRIMARY KEY (id);


--
-- Name: rec_job_postings rec_job_postings_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.rec_job_postings
    ADD CONSTRAINT rec_job_postings_pkey PRIMARY KEY (id);


--
-- Name: role_feature_access role_feature_access_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.role_feature_access
    ADD CONSTRAINT role_feature_access_pkey PRIMARY KEY (id);


--
-- Name: role_page_access role_page_access_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.role_page_access
    ADD CONSTRAINT role_page_access_pkey PRIMARY KEY (id);


--
-- Name: role_permissions role_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_pkey PRIMARY KEY (id);


--
-- Name: role_permissions role_permissions_role_id_permission_id_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_role_id_permission_id_key UNIQUE (role_id, permission_id);


--
-- Name: roles roles_company_id_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_company_id_code_key UNIQUE (company_id, code);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: search_index search_index_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.search_index
    ADD CONSTRAINT search_index_pkey PRIMARY KEY (id);


--
-- Name: status_definitions status_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.status_definitions
    ADD CONSTRAINT status_definitions_pkey PRIMARY KEY (id);


--
-- Name: sys_audit_logs sys_audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_audit_logs
    ADD CONSTRAINT sys_audit_logs_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_audit_logs_2025 sys_audit_logs_2025_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_audit_logs_2025
    ADD CONSTRAINT sys_audit_logs_2025_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_audit_logs_2026 sys_audit_logs_2026_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_audit_logs_2026
    ADD CONSTRAINT sys_audit_logs_2026_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_audit_logs_2027 sys_audit_logs_2027_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_audit_logs_2027
    ADD CONSTRAINT sys_audit_logs_2027_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_audit_logs_2028 sys_audit_logs_2028_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_audit_logs_2028
    ADD CONSTRAINT sys_audit_logs_2028_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_change_log sys_change_log_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_change_log
    ADD CONSTRAINT sys_change_log_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_change_log_2025 sys_change_log_2025_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_change_log_2025
    ADD CONSTRAINT sys_change_log_2025_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_change_log_2026 sys_change_log_2026_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_change_log_2026
    ADD CONSTRAINT sys_change_log_2026_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_change_log_2027 sys_change_log_2027_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_change_log_2027
    ADD CONSTRAINT sys_change_log_2027_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_change_log_2028 sys_change_log_2028_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_change_log_2028
    ADD CONSTRAINT sys_change_log_2028_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_compliance_reports sys_compliance_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_compliance_reports
    ADD CONSTRAINT sys_compliance_reports_pkey PRIMARY KEY (id);


--
-- Name: sys_field_changes sys_field_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_field_changes
    ADD CONSTRAINT sys_field_changes_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_field_changes_2025 sys_field_changes_2025_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_field_changes_2025
    ADD CONSTRAINT sys_field_changes_2025_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_field_changes_2026 sys_field_changes_2026_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_field_changes_2026
    ADD CONSTRAINT sys_field_changes_2026_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_field_changes_2027 sys_field_changes_2027_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_field_changes_2027
    ADD CONSTRAINT sys_field_changes_2027_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_field_changes_2028 sys_field_changes_2028_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_field_changes_2028
    ADD CONSTRAINT sys_field_changes_2028_pkey PRIMARY KEY (id, created_at);


--
-- Name: sys_integrations sys_integrations_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_integrations
    ADD CONSTRAINT sys_integrations_code_key UNIQUE (code);


--
-- Name: sys_integrations sys_integrations_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_integrations
    ADD CONSTRAINT sys_integrations_pkey PRIMARY KEY (id);


--
-- Name: sys_regulatory_deadlines sys_regulatory_deadlines_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_regulatory_deadlines
    ADD CONSTRAINT sys_regulatory_deadlines_pkey PRIMARY KEY (id);


--
-- Name: sys_sync_logs sys_sync_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_sync_logs
    ADD CONSTRAINT sys_sync_logs_pkey PRIMARY KEY (id);


--
-- Name: transaction_qr_tokens transaction_qr_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.transaction_qr_tokens
    ADD CONSTRAINT transaction_qr_tokens_pkey PRIMARY KEY (id);


--
-- Name: transaction_qr_tokens transaction_qr_tokens_public_token_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.transaction_qr_tokens
    ADD CONSTRAINT transaction_qr_tokens_public_token_key UNIQUE (public_token);


--
-- Name: transaction_registry transaction_registry_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.transaction_registry
    ADD CONSTRAINT transaction_registry_pkey PRIMARY KEY (id);


--
-- Name: transaction_registry transaction_registry_reference_no_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.transaction_registry
    ADD CONSTRAINT transaction_registry_reference_no_key UNIQUE (reference_no);


--
-- Name: transaction_timeline transaction_timeline_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.transaction_timeline
    ADD CONSTRAINT transaction_timeline_pkey PRIMARY KEY (id);


--
-- Name: trn_employee_history trn_employee_history_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.trn_employee_history
    ADD CONSTRAINT trn_employee_history_pkey PRIMARY KEY (id);


--
-- Name: trn_enrollments trn_enrollments_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.trn_enrollments
    ADD CONSTRAINT trn_enrollments_pkey PRIMARY KEY (id);


--
-- Name: trn_enrollments trn_enrollments_session_id_employee_id_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.trn_enrollments
    ADD CONSTRAINT trn_enrollments_session_id_employee_id_key UNIQUE (session_id, employee_id);


--
-- Name: trn_programs trn_programs_company_id_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.trn_programs
    ADD CONSTRAINT trn_programs_company_id_code_key UNIQUE (company_id, code);


--
-- Name: trn_programs trn_programs_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.trn_programs
    ADD CONSTRAINT trn_programs_pkey PRIMARY KEY (id);


--
-- Name: trn_sessions trn_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.trn_sessions
    ADD CONSTRAINT trn_sessions_pkey PRIMARY KEY (id);


--
-- Name: trn_sessions trn_sessions_program_id_session_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.trn_sessions
    ADD CONSTRAINT trn_sessions_program_id_session_code_key UNIQUE (program_id, session_code);


--
-- Name: ui_themes ui_themes_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ui_themes
    ADD CONSTRAINT ui_themes_code_key UNIQUE (code);


--
-- Name: ui_themes ui_themes_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ui_themes
    ADD CONSTRAINT ui_themes_pkey PRIMARY KEY (id);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (id);


--
-- Name: user_roles user_roles_user_id_role_id_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_role_id_key UNIQUE (user_id, role_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: workflow_action_logs workflow_action_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_action_logs
    ADD CONSTRAINT workflow_action_logs_pkey PRIMARY KEY (id);


--
-- Name: workflow_checklist_items workflow_checklist_items_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_checklist_items
    ADD CONSTRAINT workflow_checklist_items_pkey PRIMARY KEY (id);


--
-- Name: workflow_checklists workflow_checklists_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_checklists
    ADD CONSTRAINT workflow_checklists_pkey PRIMARY KEY (id);


--
-- Name: workflow_definitions workflow_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_definitions
    ADD CONSTRAINT workflow_definitions_pkey PRIMARY KEY (id);


--
-- Name: workflow_definitions workflow_definitions_workflow_code_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_definitions
    ADD CONSTRAINT workflow_definitions_workflow_code_key UNIQUE (workflow_code);


--
-- Name: workflow_instances workflow_instances_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_instances
    ADD CONSTRAINT workflow_instances_pkey PRIMARY KEY (id);


--
-- Name: workflow_instances workflow_instances_reference_no_key; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_instances
    ADD CONSTRAINT workflow_instances_reference_no_key UNIQUE (reference_no);


--
-- Name: workflow_routes workflow_routes_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_routes
    ADD CONSTRAINT workflow_routes_pkey PRIMARY KEY (id);


--
-- Name: workflow_steps workflow_steps_pkey; Type: CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_steps
    ADD CONSTRAINT workflow_steps_pkey PRIMARY KEY (id);


--
-- Name: rec_applicants rec_applicants_pkey; Type: CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_applicants
    ADD CONSTRAINT rec_applicants_pkey PRIMARY KEY (id);


--
-- Name: rec_appointments rec_appointments_appointment_no_key; Type: CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_appointments
    ADD CONSTRAINT rec_appointments_appointment_no_key UNIQUE (appointment_no);


--
-- Name: rec_appointments rec_appointments_pkey; Type: CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_appointments
    ADD CONSTRAINT rec_appointments_pkey PRIMARY KEY (id);


--
-- Name: rec_csc_eligibilities rec_csc_eligibilities_code_key; Type: CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_csc_eligibilities
    ADD CONSTRAINT rec_csc_eligibilities_code_key UNIQUE (code);


--
-- Name: rec_csc_eligibilities rec_csc_eligibilities_pkey; Type: CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_csc_eligibilities
    ADD CONSTRAINT rec_csc_eligibilities_pkey PRIMARY KEY (id);


--
-- Name: rec_employee_eligibilities rec_employee_eligibilities_pkey; Type: CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_employee_eligibilities
    ADD CONSTRAINT rec_employee_eligibilities_pkey PRIMARY KEY (id);


--
-- Name: rec_interview_schedules rec_interview_schedules_pkey; Type: CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_interview_schedules
    ADD CONSTRAINT rec_interview_schedules_pkey PRIMARY KEY (id);


--
-- Name: rec_job_postings rec_job_postings_pkey; Type: CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_job_postings
    ADD CONSTRAINT rec_job_postings_pkey PRIMARY KEY (id);


--
-- Name: rec_next_in_rank_list rec_next_in_rank_list_pkey; Type: CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_next_in_rank_list
    ADD CONSTRAINT rec_next_in_rank_list_pkey PRIMARY KEY (id);


--
-- Name: rec_next_in_rank_list rec_next_in_rank_list_position_id_employee_id_key; Type: CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_next_in_rank_list
    ADD CONSTRAINT rec_next_in_rank_list_position_id_employee_id_key UNIQUE (position_id, employee_id);


--
-- Name: rec_offers rec_offers_pkey; Type: CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_offers
    ADD CONSTRAINT rec_offers_pkey PRIMARY KEY (id);


--
-- Name: rec_plantilla_items rec_plantilla_items_item_number_key; Type: CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_plantilla_items
    ADD CONSTRAINT rec_plantilla_items_item_number_key UNIQUE (item_number);


--
-- Name: rec_plantilla_items rec_plantilla_items_pkey; Type: CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_plantilla_items
    ADD CONSTRAINT rec_plantilla_items_pkey PRIMARY KEY (id);


--
-- Name: rec_psb_deliberations rec_psb_deliberations_pkey; Type: CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_psb_deliberations
    ADD CONSTRAINT rec_psb_deliberations_pkey PRIMARY KEY (id);


--
-- Name: rec_psb_members rec_psb_members_pkey; Type: CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_psb_members
    ADD CONSTRAINT rec_psb_members_pkey PRIMARY KEY (id);


--
-- Name: rec_psb_scores rec_psb_scores_deliberation_id_applicant_id_key; Type: CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_psb_scores
    ADD CONSTRAINT rec_psb_scores_deliberation_id_applicant_id_key UNIQUE (deliberation_id, applicant_id);


--
-- Name: rec_psb_scores rec_psb_scores_pkey; Type: CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_psb_scores
    ADD CONSTRAINT rec_psb_scores_pkey PRIMARY KEY (id);


--
-- Name: rec_publications rec_publications_pkey; Type: CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_publications
    ADD CONSTRAINT rec_publications_pkey PRIMARY KEY (id);


--
-- Name: rec_qualification_standards rec_qualification_standards_pkey; Type: CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_qualification_standards
    ADD CONSTRAINT rec_qualification_standards_pkey PRIMARY KEY (id);


--
-- Name: rec_requisitions rec_requisitions_pkey; Type: CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_requisitions
    ADD CONSTRAINT rec_requisitions_pkey PRIMARY KEY (id);


--
-- Name: rec_requisitions rec_requisitions_reference_no_key; Type: CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_requisitions
    ADD CONSTRAINT rec_requisitions_reference_no_key UNIQUE (reference_no);


--
-- Name: rwd_awards rwd_awards_pkey; Type: CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_awards
    ADD CONSTRAINT rwd_awards_pkey PRIMARY KEY (id);


--
-- Name: rwd_categories rwd_categories_pkey; Type: CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_categories
    ADD CONSTRAINT rwd_categories_pkey PRIMARY KEY (id);


--
-- Name: rwd_loyalty_milestones rwd_loyalty_milestones_employee_id_service_years_key; Type: CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_loyalty_milestones
    ADD CONSTRAINT rwd_loyalty_milestones_employee_id_service_years_key UNIQUE (employee_id, service_years);


--
-- Name: rwd_loyalty_milestones rwd_loyalty_milestones_pkey; Type: CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_loyalty_milestones
    ADD CONSTRAINT rwd_loyalty_milestones_pkey PRIMARY KEY (id);


--
-- Name: rwd_nominations rwd_nominations_pkey; Type: CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_nominations
    ADD CONSTRAINT rwd_nominations_pkey PRIMARY KEY (id);


--
-- Name: rwd_pbb_records rwd_pbb_records_employee_id_year_key; Type: CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_pbb_records
    ADD CONSTRAINT rwd_pbb_records_employee_id_year_key UNIQUE (employee_id, year);


--
-- Name: rwd_pbb_records rwd_pbb_records_pkey; Type: CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_pbb_records
    ADD CONSTRAINT rwd_pbb_records_pkey PRIMARY KEY (id);


--
-- Name: rwd_praise_config rwd_praise_config_pkey; Type: CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_praise_config
    ADD CONSTRAINT rwd_praise_config_pkey PRIMARY KEY (id);


--
-- Name: rwd_retirement_alerts rwd_retirement_alerts_pkey; Type: CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_retirement_alerts
    ADD CONSTRAINT rwd_retirement_alerts_pkey PRIMARY KEY (id);


--
-- Name: rwd_retirement_plans rwd_retirement_plans_employee_id_key; Type: CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_retirement_plans
    ADD CONSTRAINT rwd_retirement_plans_employee_id_key UNIQUE (employee_id);


--
-- Name: rwd_retirement_plans rwd_retirement_plans_pkey; Type: CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_retirement_plans
    ADD CONSTRAINT rwd_retirement_plans_pkey PRIMARY KEY (id);


--
-- Name: rwd_ssl_table rwd_ssl_table_pkey; Type: CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_ssl_table
    ADD CONSTRAINT rwd_ssl_table_pkey PRIMARY KEY (id);


--
-- Name: rwd_ssl_table rwd_ssl_table_salary_grade_step_no_effective_date_key; Type: CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_ssl_table
    ADD CONSTRAINT rwd_ssl_table_salary_grade_step_no_effective_date_key UNIQUE (salary_grade, step_no, effective_date);


--
-- Name: rwd_step_increments rwd_step_increments_pkey; Type: CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_step_increments
    ADD CONSTRAINT rwd_step_increments_pkey PRIMARY KEY (id);


--
-- Name: instance_checklist_items instance_checklist_items_instance_id_checklist_id_key; Type: CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.instance_checklist_items
    ADD CONSTRAINT instance_checklist_items_instance_id_checklist_id_key UNIQUE (instance_id, checklist_id);


--
-- Name: instance_checklist_items instance_checklist_items_pkey; Type: CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.instance_checklist_items
    ADD CONSTRAINT instance_checklist_items_pkey PRIMARY KEY (id);


--
-- Name: workflow_action_logs workflow_action_logs_pkey; Type: CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_action_logs
    ADD CONSTRAINT workflow_action_logs_pkey PRIMARY KEY (id);


--
-- Name: workflow_checklists workflow_checklists_pkey; Type: CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_checklists
    ADD CONSTRAINT workflow_checklists_pkey PRIMARY KEY (id);


--
-- Name: workflow_definitions workflow_definitions_code_key; Type: CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_definitions
    ADD CONSTRAINT workflow_definitions_code_key UNIQUE (code);


--
-- Name: workflow_definitions workflow_definitions_pkey; Type: CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_definitions
    ADD CONSTRAINT workflow_definitions_pkey PRIMARY KEY (id);


--
-- Name: workflow_event_hooks workflow_event_hooks_pkey; Type: CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_event_hooks
    ADD CONSTRAINT workflow_event_hooks_pkey PRIMARY KEY (id);


--
-- Name: workflow_instances workflow_instances_pkey; Type: CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_instances
    ADD CONSTRAINT workflow_instances_pkey PRIMARY KEY (id);


--
-- Name: workflow_routes workflow_routes_pkey; Type: CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_routes
    ADD CONSTRAINT workflow_routes_pkey PRIMARY KEY (id);


--
-- Name: workflow_routes workflow_routes_step_id_action_code_key; Type: CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_routes
    ADD CONSTRAINT workflow_routes_step_id_action_code_key UNIQUE (step_id, action_code);


--
-- Name: workflow_steps workflow_steps_pkey; Type: CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_steps
    ADD CONSTRAINT workflow_steps_pkey PRIMARY KEY (id);


--
-- Name: workflow_steps workflow_steps_workflow_id_step_order_key; Type: CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_steps
    ADD CONSTRAINT workflow_steps_workflow_id_step_order_key UNIQUE (workflow_id, step_order);


--
-- Name: idx_ai_risk_emp; Type: INDEX; Schema: ai; Owner: hris_admin
--

CREATE INDEX idx_ai_risk_emp ON ai.ai_risk_scores USING btree (employee_id, score_date);


--
-- Name: idx_ai_risk_type; Type: INDEX; Schema: ai; Owner: hris_admin
--

CREATE INDEX idx_ai_risk_type ON ai.ai_risk_scores USING btree (risk_type, score_date, risk_level);


--
-- Name: idx_dim_emp_current; Type: INDEX; Schema: analytics; Owner: hris_admin
--

CREATE UNIQUE INDEX idx_dim_emp_current ON analytics.dim_employee USING btree (employee_id) WHERE is_current;


--
-- Name: idx_dim_emp_dept; Type: INDEX; Schema: analytics; Owner: hris_admin
--

CREATE INDEX idx_dim_emp_dept ON analytics.dim_employee USING btree (department_id, is_current);


--
-- Name: idx_fa_date; Type: INDEX; Schema: analytics; Owner: hris_admin
--

CREATE INDEX idx_fa_date ON analytics.fact_attendance USING btree (date_key, is_present);


--
-- Name: idx_fa_dept; Type: INDEX; Schema: analytics; Owner: hris_admin
--

CREATE INDEX idx_fa_dept ON analytics.fact_attendance USING btree (department_key, date_key);


--
-- Name: idx_fa_emp; Type: INDEX; Schema: analytics; Owner: hris_admin
--

CREATE INDEX idx_fa_emp ON analytics.fact_attendance USING btree (employee_key, date_key);


--
-- Name: idx_kpi_snap_code; Type: INDEX; Schema: analytics; Owner: hris_admin
--

CREATE INDEX idx_kpi_snap_code ON analytics.kpi_snapshots USING btree (kpi_code, snapshot_date);


--
-- Name: idx_kpi_snap_date; Type: INDEX; Schema: analytics; Owner: hris_admin
--

CREATE INDEX idx_kpi_snap_date ON analytics.kpi_snapshots USING btree (snapshot_date, module);


--
-- Name: idx_report_runs_report; Type: INDEX; Schema: analytics; Owner: hris_admin
--

CREATE INDEX idx_report_runs_report ON analytics.report_run_history USING btree (report_id);


--
-- Name: idx_report_runs_status; Type: INDEX; Schema: analytics; Owner: hris_admin
--

CREATE INDEX idx_report_runs_status ON analytics.report_run_history USING btree (status);


--
-- Name: idx_saved_reports_user; Type: INDEX; Schema: analytics; Owner: hris_admin
--

CREATE INDEX idx_saved_reports_user ON analytics.saved_reports USING btree (created_by);


--
-- Name: idx_att_logs_emp; Type: INDEX; Schema: attendance; Owner: hris_admin
--

CREATE INDEX idx_att_logs_emp ON ONLY attendance.att_logs USING btree (employee_id, log_datetime);


--
-- Name: att_logs_2025_employee_id_log_datetime_idx; Type: INDEX; Schema: attendance; Owner: hris_admin
--

CREATE INDEX att_logs_2025_employee_id_log_datetime_idx ON attendance.att_logs_2025 USING btree (employee_id, log_datetime);


--
-- Name: att_logs_2026_employee_id_log_datetime_idx; Type: INDEX; Schema: attendance; Owner: hris_admin
--

CREATE INDEX att_logs_2026_employee_id_log_datetime_idx ON attendance.att_logs_2026 USING btree (employee_id, log_datetime);


--
-- Name: att_logs_2027_employee_id_log_datetime_idx; Type: INDEX; Schema: attendance; Owner: hris_admin
--

CREATE INDEX att_logs_2027_employee_id_log_datetime_idx ON attendance.att_logs_2027 USING btree (employee_id, log_datetime);


--
-- Name: att_logs_2028_employee_id_log_datetime_idx; Type: INDEX; Schema: attendance; Owner: hris_admin
--

CREATE INDEX att_logs_2028_employee_id_log_datetime_idx ON attendance.att_logs_2028 USING btree (employee_id, log_datetime);


--
-- Name: idx_att_daily_date; Type: INDEX; Schema: attendance; Owner: hris_admin
--

CREATE INDEX idx_att_daily_date ON attendance.att_daily USING btree (work_date, status);


--
-- Name: idx_att_daily_emp; Type: INDEX; Schema: attendance; Owner: hris_admin
--

CREATE INDEX idx_att_daily_emp ON attendance.att_daily USING btree (employee_id, work_date);


--
-- Name: idx_att_ot_emp; Type: INDEX; Schema: attendance; Owner: hris_admin
--

CREATE INDEX idx_att_ot_emp ON attendance.att_overtime_requests USING btree (employee_id);


--
-- Name: idx_att_ot_status; Type: INDEX; Schema: attendance; Owner: hris_admin
--

CREATE INDEX idx_att_ot_status ON attendance.att_overtime_requests USING btree (status, request_date);


--
-- Name: idx_chg_company; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX idx_chg_company ON ONLY audit_logs.sys_change_log USING btree (company_id, created_at);


--
-- Name: idx_chg_operation; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX idx_chg_operation ON ONLY audit_logs.sys_change_log USING btree (operation, table_name, created_at);


--
-- Name: idx_chg_table_rowid; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX idx_chg_table_rowid ON ONLY audit_logs.sys_change_log USING btree (table_name, row_id, created_at);


--
-- Name: idx_chg_user; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX idx_chg_user ON ONLY audit_logs.sys_change_log USING btree (user_id, created_at);


--
-- Name: idx_export_type; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX idx_export_type ON audit_logs.sys_data_exports USING btree (export_type, created_at);


--
-- Name: idx_export_user; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX idx_export_user ON audit_logs.sys_data_exports USING btree (user_id, created_at);


--
-- Name: idx_fchg_row; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX idx_fchg_row ON ONLY audit_logs.sys_field_changes USING btree (table_name, row_id, created_at);


--
-- Name: idx_fchg_table_field; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX idx_fchg_table_field ON ONLY audit_logs.sys_field_changes USING btree (table_name, field_name, created_at);


--
-- Name: idx_fchg_user; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX idx_fchg_user ON ONLY audit_logs.sys_field_changes USING btree (user_id, created_at);


--
-- Name: idx_login_event; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX idx_login_event ON audit_logs.sys_login_logs USING btree (event_type, created_at);


--
-- Name: idx_login_ip; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX idx_login_ip ON audit_logs.sys_login_logs USING btree (client_ip, created_at);


--
-- Name: idx_login_user; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX idx_login_user ON audit_logs.sys_login_logs USING btree (user_id, created_at);


--
-- Name: idx_pay_audit_emp; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX idx_pay_audit_emp ON audit_logs.sys_payroll_audit USING btree (employee_id, created_at);


--
-- Name: idx_pay_audit_run; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX idx_pay_audit_run ON audit_logs.sys_payroll_audit USING btree (run_id);


--
-- Name: idx_st_created; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX idx_st_created ON audit_logs.sys_status_transitions USING btree (created_at);


--
-- Name: idx_st_module_entity; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX idx_st_module_entity ON audit_logs.sys_status_transitions USING btree (module, entity_type, entity_id);


--
-- Name: idx_st_to_status; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX idx_st_to_status ON audit_logs.sys_status_transitions USING btree (module, to_status, created_at);


--
-- Name: sys_change_log_2025_company_id_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_change_log_2025_company_id_created_at_idx ON audit_logs.sys_change_log_2025 USING btree (company_id, created_at);


--
-- Name: sys_change_log_2025_operation_table_name_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_change_log_2025_operation_table_name_created_at_idx ON audit_logs.sys_change_log_2025 USING btree (operation, table_name, created_at);


--
-- Name: sys_change_log_2025_table_name_row_id_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_change_log_2025_table_name_row_id_created_at_idx ON audit_logs.sys_change_log_2025 USING btree (table_name, row_id, created_at);


--
-- Name: sys_change_log_2025_user_id_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_change_log_2025_user_id_created_at_idx ON audit_logs.sys_change_log_2025 USING btree (user_id, created_at);


--
-- Name: sys_change_log_2026_company_id_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_change_log_2026_company_id_created_at_idx ON audit_logs.sys_change_log_2026 USING btree (company_id, created_at);


--
-- Name: sys_change_log_2026_operation_table_name_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_change_log_2026_operation_table_name_created_at_idx ON audit_logs.sys_change_log_2026 USING btree (operation, table_name, created_at);


--
-- Name: sys_change_log_2026_table_name_row_id_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_change_log_2026_table_name_row_id_created_at_idx ON audit_logs.sys_change_log_2026 USING btree (table_name, row_id, created_at);


--
-- Name: sys_change_log_2026_user_id_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_change_log_2026_user_id_created_at_idx ON audit_logs.sys_change_log_2026 USING btree (user_id, created_at);


--
-- Name: sys_change_log_2027_company_id_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_change_log_2027_company_id_created_at_idx ON audit_logs.sys_change_log_2027 USING btree (company_id, created_at);


--
-- Name: sys_change_log_2027_operation_table_name_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_change_log_2027_operation_table_name_created_at_idx ON audit_logs.sys_change_log_2027 USING btree (operation, table_name, created_at);


--
-- Name: sys_change_log_2027_table_name_row_id_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_change_log_2027_table_name_row_id_created_at_idx ON audit_logs.sys_change_log_2027 USING btree (table_name, row_id, created_at);


--
-- Name: sys_change_log_2027_user_id_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_change_log_2027_user_id_created_at_idx ON audit_logs.sys_change_log_2027 USING btree (user_id, created_at);


--
-- Name: sys_change_log_2028_company_id_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_change_log_2028_company_id_created_at_idx ON audit_logs.sys_change_log_2028 USING btree (company_id, created_at);


--
-- Name: sys_change_log_2028_operation_table_name_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_change_log_2028_operation_table_name_created_at_idx ON audit_logs.sys_change_log_2028 USING btree (operation, table_name, created_at);


--
-- Name: sys_change_log_2028_table_name_row_id_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_change_log_2028_table_name_row_id_created_at_idx ON audit_logs.sys_change_log_2028 USING btree (table_name, row_id, created_at);


--
-- Name: sys_change_log_2028_user_id_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_change_log_2028_user_id_created_at_idx ON audit_logs.sys_change_log_2028 USING btree (user_id, created_at);


--
-- Name: sys_field_changes_2025_table_name_field_name_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2025_table_name_field_name_created_at_idx ON audit_logs.sys_field_changes_2025 USING btree (table_name, field_name, created_at);


--
-- Name: sys_field_changes_2025_table_name_row_id_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2025_table_name_row_id_created_at_idx ON audit_logs.sys_field_changes_2025 USING btree (table_name, row_id, created_at);


--
-- Name: sys_field_changes_2025_user_id_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2025_user_id_created_at_idx ON audit_logs.sys_field_changes_2025 USING btree (user_id, created_at);


--
-- Name: sys_field_changes_2026_table_name_field_name_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2026_table_name_field_name_created_at_idx ON audit_logs.sys_field_changes_2026 USING btree (table_name, field_name, created_at);


--
-- Name: sys_field_changes_2026_table_name_row_id_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2026_table_name_row_id_created_at_idx ON audit_logs.sys_field_changes_2026 USING btree (table_name, row_id, created_at);


--
-- Name: sys_field_changes_2026_user_id_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2026_user_id_created_at_idx ON audit_logs.sys_field_changes_2026 USING btree (user_id, created_at);


--
-- Name: sys_field_changes_2027_table_name_field_name_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2027_table_name_field_name_created_at_idx ON audit_logs.sys_field_changes_2027 USING btree (table_name, field_name, created_at);


--
-- Name: sys_field_changes_2027_table_name_row_id_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2027_table_name_row_id_created_at_idx ON audit_logs.sys_field_changes_2027 USING btree (table_name, row_id, created_at);


--
-- Name: sys_field_changes_2027_user_id_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2027_user_id_created_at_idx ON audit_logs.sys_field_changes_2027 USING btree (user_id, created_at);


--
-- Name: sys_field_changes_2028_table_name_field_name_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2028_table_name_field_name_created_at_idx ON audit_logs.sys_field_changes_2028 USING btree (table_name, field_name, created_at);


--
-- Name: sys_field_changes_2028_table_name_row_id_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2028_table_name_row_id_created_at_idx ON audit_logs.sys_field_changes_2028 USING btree (table_name, row_id, created_at);


--
-- Name: sys_field_changes_2028_user_id_created_at_idx; Type: INDEX; Schema: audit_logs; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2028_user_id_created_at_idx ON audit_logs.sys_field_changes_2028 USING btree (user_id, created_at);


--
-- Name: idx_demo_profiles_active; Type: INDEX; Schema: core; Owner: hris_admin
--

CREATE UNIQUE INDEX idx_demo_profiles_active ON core.demo_profiles USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_docs_archived; Type: INDEX; Schema: core; Owner: hris_admin
--

CREATE INDEX idx_docs_archived ON core.documents USING btree (is_archived) WHERE is_archived;


--
-- Name: idx_docs_category; Type: INDEX; Schema: core; Owner: hris_admin
--

CREATE INDEX idx_docs_category ON core.documents USING btree (category_id);


--
-- Name: idx_docs_employee; Type: INDEX; Schema: core; Owner: hris_admin
--

CREATE INDEX idx_docs_employee ON core.documents USING btree (employee_id, status);


--
-- Name: idx_docs_expiry; Type: INDEX; Schema: core; Owner: hris_admin
--

CREATE INDEX idx_docs_expiry ON core.documents USING btree (expiry_date) WHERE (expiry_date IS NOT NULL);


--
-- Name: idx_docs_missing; Type: INDEX; Schema: core; Owner: hris_admin
--

CREATE INDEX idx_docs_missing ON core.documents USING btree (company_id, is_missing) WHERE is_missing;


--
-- Name: idx_emp_company; Type: INDEX; Schema: core; Owner: hris_admin
--

CREATE INDEX idx_emp_company ON core.employees USING btree (company_id, is_active);


--
-- Name: idx_emp_dept; Type: INDEX; Schema: core; Owner: hris_admin
--

CREATE INDEX idx_emp_dept ON core.employees USING btree (department_id);


--
-- Name: idx_emp_name_trgm; Type: INDEX; Schema: core; Owner: hris_admin
--

CREATE INDEX idx_emp_name_trgm ON core.employees USING gin (lower((((last_name)::text || ' '::text) || (first_name)::text)) public.gin_trgm_ops);


--
-- Name: idx_emp_status; Type: INDEX; Schema: core; Owner: hris_admin
--

CREATE INDEX idx_emp_status ON core.employees USING btree (status);


--
-- Name: idx_emp_supervisor; Type: INDEX; Schema: core; Owner: hris_admin
--

CREATE INDEX idx_emp_supervisor ON core.employees USING btree (immediate_supervisor_id);


--
-- Name: idx_search_fts; Type: INDEX; Schema: core; Owner: hris_admin
--

CREATE INDEX idx_search_fts ON core.search_index USING gin (to_tsvector('english'::regconfig, (((((COALESCE(title, ''::character varying))::text || ' '::text) || (COALESCE(subtitle, ''::character varying))::text) || ' '::text) || COALESCE(keywords, ''::text))));


--
-- Name: idx_disc_cases_company; Type: INDEX; Schema: discipline; Owner: hris_admin
--

CREATE INDEX idx_disc_cases_company ON discipline.cases USING btree (company_id, status);


--
-- Name: idx_disc_cases_respondent; Type: INDEX; Schema: discipline; Owner: hris_admin
--

CREATE INDEX idx_disc_cases_respondent ON discipline.cases USING btree (respondent_id, status);


--
-- Name: idx_disc_hearings_date; Type: INDEX; Schema: discipline; Owner: hris_admin
--

CREATE INDEX idx_disc_hearings_date ON discipline.hearings USING btree (scheduled_date, status);


--
-- Name: idx_disc_prev_susp; Type: INDEX; Schema: discipline; Owner: hris_admin
--

CREATE INDEX idx_disc_prev_susp ON discipline.preventive_suspensions USING btree (employee_id, is_active);


--
-- Name: idx_cert_req_emp; Type: INDEX; Schema: dms; Owner: hris_admin
--

CREATE INDEX idx_cert_req_emp ON dms.certificate_requests USING btree (employee_id, status);


--
-- Name: idx_cert_req_status; Type: INDEX; Schema: dms; Owner: hris_admin
--

CREATE INDEX idx_cert_req_status ON dms.certificate_requests USING btree (status) WHERE ((status)::text = ANY ((ARRAY['PENDING'::character varying, 'PROCESSING'::character varying])::text[]));


--
-- Name: idx_dms_requests_emp; Type: INDEX; Schema: dms; Owner: hris_admin
--

CREATE INDEX idx_dms_requests_emp ON dms.document_requests USING btree (employee_id, status);


--
-- Name: idx_svc_record_emp; Type: INDEX; Schema: dms; Owner: hris_admin
--

CREATE INDEX idx_svc_record_emp ON dms.service_record_snapshots USING btree (employee_id, is_latest) WHERE (is_latest = true);


--
-- Name: idx_health_certs_emp; Type: INDEX; Schema: health; Owner: hris_admin
--

CREATE INDEX idx_health_certs_emp ON health.health_certificates USING btree (employee_id, status);


--
-- Name: idx_health_certs_expiry; Type: INDEX; Schema: health; Owner: hris_admin
--

CREATE INDEX idx_health_certs_expiry ON health.health_certificates USING btree (expiry_date) WHERE ((status)::text = 'ACTIVE'::text);


--
-- Name: idx_incidents_company; Type: INDEX; Schema: health; Owner: hris_admin
--

CREATE INDEX idx_incidents_company ON health.incidents USING btree (company_id, status);


--
-- Name: idx_incidents_date; Type: INDEX; Schema: health; Owner: hris_admin
--

CREATE INDEX idx_incidents_date ON health.incidents USING btree (incident_date);


--
-- Name: idx_pe_results_emp; Type: INDEX; Schema: health; Owner: hris_admin
--

CREATE INDEX idx_pe_results_emp ON health.pe_results USING btree (employee_id);


--
-- Name: idx_wellness_enroll; Type: INDEX; Schema: health; Owner: hris_admin
--

CREATE INDEX idx_wellness_enroll ON health.wellness_enrollments USING btree (employee_id);


--
-- Name: idx_lrn_att_enrollment; Type: INDEX; Schema: learning; Owner: hris_admin
--

CREATE INDEX idx_lrn_att_enrollment ON learning.lrn_attendance_logs USING btree (enrollment_id);


--
-- Name: idx_lrn_att_session; Type: INDEX; Schema: learning; Owner: hris_admin
--

CREATE INDEX idx_lrn_att_session ON learning.lrn_attendance_logs USING btree (session_id);


--
-- Name: idx_scholarship_employee; Type: INDEX; Schema: learning; Owner: hris_admin
--

CREATE INDEX idx_scholarship_employee ON learning.lrn_scholarships USING btree (employee_id);


--
-- Name: idx_tna_cycle; Type: INDEX; Schema: learning; Owner: hris_admin
--

CREATE INDEX idx_tna_cycle ON learning.lrn_tna_entries USING btree (cycle_id);


--
-- Name: idx_tna_employee; Type: INDEX; Schema: learning; Owner: hris_admin
--

CREATE INDEX idx_tna_employee ON learning.lrn_tna_entries USING btree (employee_id);


--
-- Name: idx_cto_emp; Type: INDEX; Schema: leave_mgmt; Owner: hris_admin
--

CREATE INDEX idx_cto_emp ON leave_mgmt.lv_cto_credits USING btree (employee_id, reference_date);


--
-- Name: idx_locator_date; Type: INDEX; Schema: leave_mgmt; Owner: hris_admin
--

CREATE INDEX idx_locator_date ON leave_mgmt.lv_locator_entries USING btree (log_date, location_type);


--
-- Name: idx_lv_bal_emp; Type: INDEX; Schema: leave_mgmt; Owner: hris_admin
--

CREATE INDEX idx_lv_bal_emp ON leave_mgmt.lv_balances USING btree (employee_id, year);


--
-- Name: idx_lv_req_dates; Type: INDEX; Schema: leave_mgmt; Owner: hris_admin
--

CREATE INDEX idx_lv_req_dates ON leave_mgmt.lv_requests USING btree (date_from, date_to);


--
-- Name: idx_lv_req_emp; Type: INDEX; Schema: leave_mgmt; Owner: hris_admin
--

CREATE INDEX idx_lv_req_emp ON leave_mgmt.lv_requests USING btree (employee_id, status);


--
-- Name: idx_lv_req_status; Type: INDEX; Schema: leave_mgmt; Owner: hris_admin
--

CREATE INDEX idx_lv_req_status ON leave_mgmt.lv_requests USING btree (status, date_from);


--
-- Name: idx_to_dates; Type: INDEX; Schema: leave_mgmt; Owner: hris_admin
--

CREATE INDEX idx_to_dates ON leave_mgmt.lv_travel_orders USING btree (date_from, date_to);


--
-- Name: idx_to_emp; Type: INDEX; Schema: leave_mgmt; Owner: hris_admin
--

CREATE INDEX idx_to_emp ON leave_mgmt.lv_travel_orders USING btree (employee_id, status);


--
-- Name: idx_ntf_in_app_user; Type: INDEX; Schema: notifications; Owner: hris_admin
--

CREATE INDEX idx_ntf_in_app_user ON notifications.ntf_in_app USING btree (user_id, created_at DESC);


--
-- Name: idx_ntf_in_app_user_unread; Type: INDEX; Schema: notifications; Owner: hris_admin
--

CREATE INDEX idx_ntf_in_app_user_unread ON notifications.ntf_in_app USING btree (user_id, is_read) WHERE (NOT is_read);


--
-- Name: idx_ntfq_status; Type: INDEX; Schema: notifications; Owner: hris_admin
--

CREATE INDEX idx_ntfq_status ON notifications.ntf_queue USING btree (status, scheduled_at);


--
-- Name: idx_ntfq_user; Type: INDEX; Schema: notifications; Owner: hris_admin
--

CREATE INDEX idx_ntfq_user ON notifications.ntf_queue USING btree (recipient_user_id, status);


--
-- Name: idx_clearance_employee; Type: INDEX; Schema: onboarding; Owner: hris_admin
--

CREATE INDEX idx_clearance_employee ON onboarding.offb_clearance_items USING btree (employee_id);


--
-- Name: idx_pre_emp_employee; Type: INDEX; Schema: onboarding; Owner: hris_admin
--

CREATE INDEX idx_pre_emp_employee ON onboarding.onb_pre_employment_reqs USING btree (employee_id);


--
-- Name: idx_bir_current; Type: INDEX; Schema: payroll; Owner: hris_admin
--

CREATE INDEX idx_bir_current ON payroll.pay_bir_tax_table USING btree (is_current, frequency) WHERE (is_current = true);


--
-- Name: idx_coop_employee; Type: INDEX; Schema: payroll; Owner: hris_admin
--

CREATE INDEX idx_coop_employee ON payroll.pay_coop_members USING btree (employee_id);


--
-- Name: idx_emp_gov_allow; Type: INDEX; Schema: payroll; Owner: hris_admin
--

CREATE INDEX idx_emp_gov_allow ON payroll.pay_employee_allowances_gov USING btree (employee_id);


--
-- Name: idx_gsis_current; Type: INDEX; Schema: payroll; Owner: hris_admin
--

CREATE INDEX idx_gsis_current ON payroll.pay_gsis_schedule USING btree (is_current) WHERE (is_current = true);


--
-- Name: idx_loans_emp; Type: INDEX; Schema: payroll; Owner: hris_admin
--

CREATE INDEX idx_loans_emp ON payroll.pay_loans USING btree (employee_id, status);


--
-- Name: idx_pagibig_current; Type: INDEX; Schema: payroll; Owner: hris_admin
--

CREATE INDEX idx_pagibig_current ON payroll.pay_pagibig_schedule USING btree (is_current) WHERE (is_current = true);


--
-- Name: idx_pay_runs_status; Type: INDEX; Schema: payroll; Owner: hris_admin
--

CREATE INDEX idx_pay_runs_status ON payroll.pay_runs USING btree (status);


--
-- Name: idx_payslip_emp; Type: INDEX; Schema: payroll; Owner: hris_admin
--

CREATE INDEX idx_payslip_emp ON payroll.pay_employee_payroll USING btree (employee_id, run_id);


--
-- Name: idx_ipcr_employee_cycle; Type: INDEX; Schema: performance; Owner: hris_admin
--

CREATE INDEX idx_ipcr_employee_cycle ON performance.perf_ipcr USING btree (employee_id, cycle_id);


--
-- Name: idx_ipcr_evaluator; Type: INDEX; Schema: performance; Owner: hris_admin
--

CREATE INDEX idx_ipcr_evaluator ON performance.perf_ipcr USING btree (evaluator_id);


--
-- Name: idx_ipcr_summary_pbb; Type: INDEX; Schema: performance; Owner: hris_admin
--

CREATE INDEX idx_ipcr_summary_pbb ON performance.perf_ipcr_summary USING btree (pbb_eligible) WHERE (pbb_eligible = true);


--
-- Name: idx_opcr_cycle_dept; Type: INDEX; Schema: performance; Owner: hris_admin
--

CREATE INDEX idx_opcr_cycle_dept ON performance.perf_opcr USING btree (cycle_id, department_id);


--
-- Name: idx_att_daily_date; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_att_daily_date ON public.att_daily USING btree (work_date);


--
-- Name: idx_att_daily_emp; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_att_daily_emp ON public.att_daily USING btree (employee_id);


--
-- Name: idx_att_daily_emp_date; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_att_daily_emp_date ON public.att_daily USING btree (employee_id, work_date);


--
-- Name: idx_att_daily_status; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_att_daily_status ON public.att_daily USING btree (status, work_date);


--
-- Name: idx_audit_company; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_audit_company ON ONLY public.sys_audit_logs USING btree (company_id, created_at);


--
-- Name: idx_audit_resource; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_audit_resource ON ONLY public.sys_audit_logs USING btree (resource_type, resource_id);


--
-- Name: idx_audit_user; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_audit_user ON ONLY public.sys_audit_logs USING btree (user_id, created_at);


--
-- Name: idx_chg_company; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_chg_company ON ONLY public.sys_change_log USING btree (company_id, created_at);


--
-- Name: idx_chg_operation; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_chg_operation ON ONLY public.sys_change_log USING btree (operation, table_name, created_at);


--
-- Name: idx_chg_table_rowid; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_chg_table_rowid ON ONLY public.sys_change_log USING btree (table_name, row_id, created_at);


--
-- Name: idx_chg_user; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_chg_user ON ONLY public.sys_change_log USING btree (user_id, created_at);


--
-- Name: idx_companies_code; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_companies_code ON public.companies USING btree (code);


--
-- Name: idx_dim_date_year_month; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_dim_date_year_month ON public.dim_date USING btree (year, month_number);


--
-- Name: idx_dim_emp_current; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_dim_emp_current ON public.dim_employee USING btree (employee_id) WHERE (is_current = true);


--
-- Name: idx_dim_emp_dept; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_dim_emp_dept ON public.dim_employee USING btree (department_id);


--
-- Name: idx_dim_emp_effective; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_dim_emp_effective ON public.dim_employee USING btree (effective_from, effective_to);


--
-- Name: idx_dim_emp_natural; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_dim_emp_natural ON public.dim_employee USING btree (employee_id, is_current);


--
-- Name: idx_doc_files_emp; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_doc_files_emp ON public.doc_employee_files USING btree (employee_id);


--
-- Name: idx_doc_files_expiry; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_doc_files_expiry ON public.doc_employee_files USING btree (expiry_date) WHERE (expiry_date IS NOT NULL);


--
-- Name: idx_dq_issues_open; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_dq_issues_open ON public.dq_data_issues USING btree (company_id, status, severity) WHERE ((status)::text = 'OPEN'::text);


--
-- Name: idx_fact_att_company; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_fact_att_company ON public.fact_attendance USING btree (company_id, date_key);


--
-- Name: idx_fact_att_dept_date; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_fact_att_dept_date ON public.fact_attendance USING btree (department_id, date_key);


--
-- Name: idx_fact_att_emp; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_fact_att_emp ON public.fact_attendance USING btree (employee_id, date_key);


--
-- Name: idx_fact_lv_emp; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_fact_lv_emp ON public.fact_leave USING btree (employee_id, filed_date_key);


--
-- Name: idx_fact_lv_status; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_fact_lv_status ON public.fact_leave USING btree (status);


--
-- Name: idx_fact_lv_type; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_fact_lv_type ON public.fact_leave USING btree (leave_type_id, filed_date_key);


--
-- Name: idx_fact_pay_company; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_fact_pay_company ON public.fact_payroll USING btree (company_id, period_date_key);


--
-- Name: idx_fact_pay_dept; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_fact_pay_dept ON public.fact_payroll USING btree (department_id, period_date_key);


--
-- Name: idx_fact_pay_emp; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_fact_pay_emp ON public.fact_payroll USING btree (employee_id, period_date_key);


--
-- Name: idx_fact_perf_cycle; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_fact_perf_cycle ON public.fact_performance USING btree (cycle_id);


--
-- Name: idx_fact_perf_emp; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_fact_perf_emp ON public.fact_performance USING btree (employee_id, review_date_key);


--
-- Name: idx_fchg_row; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_fchg_row ON ONLY public.sys_field_changes USING btree (table_name, row_id, created_at);


--
-- Name: idx_fchg_table_field; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_fchg_table_field ON ONLY public.sys_field_changes USING btree (table_name, field_name, created_at);


--
-- Name: idx_fchg_user; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_fchg_user ON ONLY public.sys_field_changes USING btree (user_id, created_at);


--
-- Name: idx_govt_id_number; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_govt_id_number ON public.emp_government_ids USING btree (id_number);


--
-- Name: idx_lv_bal_emp_year; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_lv_bal_emp_year ON public.lv_balances USING btree (employee_id, year);


--
-- Name: idx_lv_req_dates; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_lv_req_dates ON public.lv_requests USING btree (date_from, date_to);


--
-- Name: idx_lv_req_employee; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_lv_req_employee ON public.lv_requests USING btree (employee_id);


--
-- Name: idx_lv_req_status; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_lv_req_status ON public.lv_requests USING btree (status);


--
-- Name: idx_mlv_model_status; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_mlv_model_status ON public.ml_model_versions USING btree (model_id, status);


--
-- Name: idx_ntf_recipient_status; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_ntf_recipient_status ON ONLY public.ntf_notifications USING btree (recipient_user_id, status);


--
-- Name: idx_pay_payroll_emp; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_pay_payroll_emp ON public.pay_employee_payroll USING btree (employee_id);


--
-- Name: idx_pay_payroll_run; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_pay_payroll_run ON public.pay_employee_payroll USING btree (run_id);


--
-- Name: idx_pay_period_company; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_pay_period_company ON public.pay_periods USING btree (company_id, date_from, date_to);


--
-- Name: idx_perf_review_cycle; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_perf_review_cycle ON public.perf_reviews USING btree (cycle_id);


--
-- Name: idx_perf_review_emp; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX idx_perf_review_emp ON public.perf_reviews USING btree (employee_id);


--
-- Name: ntf_notifications_2025_recipient_user_id_status_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX ntf_notifications_2025_recipient_user_id_status_idx ON public.ntf_notifications_2025 USING btree (recipient_user_id, status);


--
-- Name: ntf_notifications_2026_recipient_user_id_status_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX ntf_notifications_2026_recipient_user_id_status_idx ON public.ntf_notifications_2026 USING btree (recipient_user_id, status);


--
-- Name: ntf_notifications_2027_recipient_user_id_status_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX ntf_notifications_2027_recipient_user_id_status_idx ON public.ntf_notifications_2027 USING btree (recipient_user_id, status);


--
-- Name: ntf_notifications_2028_recipient_user_id_status_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX ntf_notifications_2028_recipient_user_id_status_idx ON public.ntf_notifications_2028 USING btree (recipient_user_id, status);


--
-- Name: sys_audit_logs_2025_company_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_audit_logs_2025_company_id_created_at_idx ON public.sys_audit_logs_2025 USING btree (company_id, created_at);


--
-- Name: sys_audit_logs_2025_resource_type_resource_id_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_audit_logs_2025_resource_type_resource_id_idx ON public.sys_audit_logs_2025 USING btree (resource_type, resource_id);


--
-- Name: sys_audit_logs_2025_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_audit_logs_2025_user_id_created_at_idx ON public.sys_audit_logs_2025 USING btree (user_id, created_at);


--
-- Name: sys_audit_logs_2026_company_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_audit_logs_2026_company_id_created_at_idx ON public.sys_audit_logs_2026 USING btree (company_id, created_at);


--
-- Name: sys_audit_logs_2026_resource_type_resource_id_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_audit_logs_2026_resource_type_resource_id_idx ON public.sys_audit_logs_2026 USING btree (resource_type, resource_id);


--
-- Name: sys_audit_logs_2026_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_audit_logs_2026_user_id_created_at_idx ON public.sys_audit_logs_2026 USING btree (user_id, created_at);


--
-- Name: sys_audit_logs_2027_company_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_audit_logs_2027_company_id_created_at_idx ON public.sys_audit_logs_2027 USING btree (company_id, created_at);


--
-- Name: sys_audit_logs_2027_resource_type_resource_id_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_audit_logs_2027_resource_type_resource_id_idx ON public.sys_audit_logs_2027 USING btree (resource_type, resource_id);


--
-- Name: sys_audit_logs_2027_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_audit_logs_2027_user_id_created_at_idx ON public.sys_audit_logs_2027 USING btree (user_id, created_at);


--
-- Name: sys_audit_logs_2028_company_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_audit_logs_2028_company_id_created_at_idx ON public.sys_audit_logs_2028 USING btree (company_id, created_at);


--
-- Name: sys_audit_logs_2028_resource_type_resource_id_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_audit_logs_2028_resource_type_resource_id_idx ON public.sys_audit_logs_2028 USING btree (resource_type, resource_id);


--
-- Name: sys_audit_logs_2028_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_audit_logs_2028_user_id_created_at_idx ON public.sys_audit_logs_2028 USING btree (user_id, created_at);


--
-- Name: sys_change_log_2025_company_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_change_log_2025_company_id_created_at_idx ON public.sys_change_log_2025 USING btree (company_id, created_at);


--
-- Name: sys_change_log_2025_operation_table_name_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_change_log_2025_operation_table_name_created_at_idx ON public.sys_change_log_2025 USING btree (operation, table_name, created_at);


--
-- Name: sys_change_log_2025_table_name_row_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_change_log_2025_table_name_row_id_created_at_idx ON public.sys_change_log_2025 USING btree (table_name, row_id, created_at);


--
-- Name: sys_change_log_2025_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_change_log_2025_user_id_created_at_idx ON public.sys_change_log_2025 USING btree (user_id, created_at);


--
-- Name: sys_change_log_2026_company_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_change_log_2026_company_id_created_at_idx ON public.sys_change_log_2026 USING btree (company_id, created_at);


--
-- Name: sys_change_log_2026_operation_table_name_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_change_log_2026_operation_table_name_created_at_idx ON public.sys_change_log_2026 USING btree (operation, table_name, created_at);


--
-- Name: sys_change_log_2026_table_name_row_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_change_log_2026_table_name_row_id_created_at_idx ON public.sys_change_log_2026 USING btree (table_name, row_id, created_at);


--
-- Name: sys_change_log_2026_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_change_log_2026_user_id_created_at_idx ON public.sys_change_log_2026 USING btree (user_id, created_at);


--
-- Name: sys_change_log_2027_company_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_change_log_2027_company_id_created_at_idx ON public.sys_change_log_2027 USING btree (company_id, created_at);


--
-- Name: sys_change_log_2027_operation_table_name_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_change_log_2027_operation_table_name_created_at_idx ON public.sys_change_log_2027 USING btree (operation, table_name, created_at);


--
-- Name: sys_change_log_2027_table_name_row_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_change_log_2027_table_name_row_id_created_at_idx ON public.sys_change_log_2027 USING btree (table_name, row_id, created_at);


--
-- Name: sys_change_log_2027_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_change_log_2027_user_id_created_at_idx ON public.sys_change_log_2027 USING btree (user_id, created_at);


--
-- Name: sys_change_log_2028_company_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_change_log_2028_company_id_created_at_idx ON public.sys_change_log_2028 USING btree (company_id, created_at);


--
-- Name: sys_change_log_2028_operation_table_name_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_change_log_2028_operation_table_name_created_at_idx ON public.sys_change_log_2028 USING btree (operation, table_name, created_at);


--
-- Name: sys_change_log_2028_table_name_row_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_change_log_2028_table_name_row_id_created_at_idx ON public.sys_change_log_2028 USING btree (table_name, row_id, created_at);


--
-- Name: sys_change_log_2028_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_change_log_2028_user_id_created_at_idx ON public.sys_change_log_2028 USING btree (user_id, created_at);


--
-- Name: sys_field_changes_2025_table_name_field_name_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2025_table_name_field_name_created_at_idx ON public.sys_field_changes_2025 USING btree (table_name, field_name, created_at);


--
-- Name: sys_field_changes_2025_table_name_row_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2025_table_name_row_id_created_at_idx ON public.sys_field_changes_2025 USING btree (table_name, row_id, created_at);


--
-- Name: sys_field_changes_2025_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2025_user_id_created_at_idx ON public.sys_field_changes_2025 USING btree (user_id, created_at);


--
-- Name: sys_field_changes_2026_table_name_field_name_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2026_table_name_field_name_created_at_idx ON public.sys_field_changes_2026 USING btree (table_name, field_name, created_at);


--
-- Name: sys_field_changes_2026_table_name_row_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2026_table_name_row_id_created_at_idx ON public.sys_field_changes_2026 USING btree (table_name, row_id, created_at);


--
-- Name: sys_field_changes_2026_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2026_user_id_created_at_idx ON public.sys_field_changes_2026 USING btree (user_id, created_at);


--
-- Name: sys_field_changes_2027_table_name_field_name_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2027_table_name_field_name_created_at_idx ON public.sys_field_changes_2027 USING btree (table_name, field_name, created_at);


--
-- Name: sys_field_changes_2027_table_name_row_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2027_table_name_row_id_created_at_idx ON public.sys_field_changes_2027 USING btree (table_name, row_id, created_at);


--
-- Name: sys_field_changes_2027_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2027_user_id_created_at_idx ON public.sys_field_changes_2027 USING btree (user_id, created_at);


--
-- Name: sys_field_changes_2028_table_name_field_name_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2028_table_name_field_name_created_at_idx ON public.sys_field_changes_2028 USING btree (table_name, field_name, created_at);


--
-- Name: sys_field_changes_2028_table_name_row_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2028_table_name_row_id_created_at_idx ON public.sys_field_changes_2028 USING btree (table_name, row_id, created_at);


--
-- Name: sys_field_changes_2028_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE INDEX sys_field_changes_2028_user_id_created_at_idx ON public.sys_field_changes_2028 USING btree (user_id, created_at);


--
-- Name: uidx_mv_payroll; Type: INDEX; Schema: public; Owner: hris_admin
--

CREATE UNIQUE INDEX uidx_mv_payroll ON public.mv_payroll_cost_monthly USING btree (company_id, department_id, employment_type, year, month_number);


--
-- Name: idx_appt_employee; Type: INDEX; Schema: recruitment; Owner: hris_admin
--

CREATE INDEX idx_appt_employee ON recruitment.rec_appointments USING btree (employee_id);


--
-- Name: idx_appt_position; Type: INDEX; Schema: recruitment; Owner: hris_admin
--

CREATE INDEX idx_appt_position ON recruitment.rec_appointments USING btree (position_id, status);


--
-- Name: idx_emp_elig_employee; Type: INDEX; Schema: recruitment; Owner: hris_admin
--

CREATE INDEX idx_emp_elig_employee ON recruitment.rec_employee_eligibilities USING btree (employee_id);


--
-- Name: idx_emp_elig_unique; Type: INDEX; Schema: recruitment; Owner: hris_admin
--

CREATE UNIQUE INDEX idx_emp_elig_unique ON recruitment.rec_employee_eligibilities USING btree (employee_id, eligibility_id);


--
-- Name: idx_nir_employee; Type: INDEX; Schema: recruitment; Owner: hris_admin
--

CREATE INDEX idx_nir_employee ON recruitment.rec_next_in_rank_list USING btree (employee_id);


--
-- Name: idx_nir_position; Type: INDEX; Schema: recruitment; Owner: hris_admin
--

CREATE INDEX idx_nir_position ON recruitment.rec_next_in_rank_list USING btree (position_id, qualification_met);


--
-- Name: idx_plantilla_company; Type: INDEX; Schema: recruitment; Owner: hris_admin
--

CREATE INDEX idx_plantilla_company ON recruitment.rec_plantilla_items USING btree (company_id, status);


--
-- Name: idx_plantilla_dept; Type: INDEX; Schema: recruitment; Owner: hris_admin
--

CREATE INDEX idx_plantilla_dept ON recruitment.rec_plantilla_items USING btree (department_id);


--
-- Name: idx_plantilla_position; Type: INDEX; Schema: recruitment; Owner: hris_admin
--

CREATE INDEX idx_plantilla_position ON recruitment.rec_plantilla_items USING btree (position_id);


--
-- Name: idx_psb_company; Type: INDEX; Schema: recruitment; Owner: hris_admin
--

CREATE INDEX idx_psb_company ON recruitment.rec_psb_members USING btree (company_id);


--
-- Name: idx_psb_delib_req; Type: INDEX; Schema: recruitment; Owner: hris_admin
--

CREATE INDEX idx_psb_delib_req ON recruitment.rec_psb_deliberations USING btree (requisition_id);


--
-- Name: idx_psb_scores_applic; Type: INDEX; Schema: recruitment; Owner: hris_admin
--

CREATE INDEX idx_psb_scores_applic ON recruitment.rec_psb_scores USING btree (applicant_id);


--
-- Name: idx_psb_scores_delib; Type: INDEX; Schema: recruitment; Owner: hris_admin
--

CREATE INDEX idx_psb_scores_delib ON recruitment.rec_psb_scores USING btree (deliberation_id);


--
-- Name: idx_pub_requisition; Type: INDEX; Schema: recruitment; Owner: hris_admin
--

CREATE INDEX idx_pub_requisition ON recruitment.rec_publications USING btree (requisition_id);


--
-- Name: idx_qs_position_active; Type: INDEX; Schema: recruitment; Owner: hris_admin
--

CREATE UNIQUE INDEX idx_qs_position_active ON recruitment.rec_qualification_standards USING btree (position_id) WHERE (is_active = true);


--
-- Name: idx_loyalty_status; Type: INDEX; Schema: rewards; Owner: hris_admin
--

CREATE INDEX idx_loyalty_status ON rewards.rwd_loyalty_milestones USING btree (status, eligibility_date);


--
-- Name: idx_pbb_year; Type: INDEX; Schema: rewards; Owner: hris_admin
--

CREATE INDEX idx_pbb_year ON rewards.rwd_pbb_records USING btree (year, pbb_tier);


--
-- Name: idx_ret_alert_schedule; Type: INDEX; Schema: rewards; Owner: hris_admin
--

CREATE INDEX idx_ret_alert_schedule ON rewards.rwd_retirement_alerts USING btree (scheduled_send_date) WHERE (sent_at IS NULL);


--
-- Name: idx_ssl_sg_step; Type: INDEX; Schema: rewards; Owner: hris_admin
--

CREATE INDEX idx_ssl_sg_step ON rewards.rwd_ssl_table USING btree (salary_grade, step_no);


--
-- Name: idx_step_inc_due; Type: INDEX; Schema: rewards; Owner: hris_admin
--

CREATE INDEX idx_step_inc_due ON rewards.rwd_step_increments USING btree (next_increment_due) WHERE ((eligibility_status)::text = ANY ((ARRAY['ELIGIBLE'::character varying, 'PENDING_RATING'::character varying])::text[]));


--
-- Name: idx_step_inc_employee; Type: INDEX; Schema: rewards; Owner: hris_admin
--

CREATE INDEX idx_step_inc_employee ON rewards.rwd_step_increments USING btree (employee_id);


--
-- Name: idx_wal_instance; Type: INDEX; Schema: workflow; Owner: hris_admin
--

CREATE INDEX idx_wal_instance ON workflow.workflow_action_logs USING btree (instance_id, created_at);


--
-- Name: idx_wi_module_entity; Type: INDEX; Schema: workflow; Owner: hris_admin
--

CREATE INDEX idx_wi_module_entity ON workflow.workflow_instances USING btree (module, entity_type, entity_id);


--
-- Name: idx_wi_status; Type: INDEX; Schema: workflow; Owner: hris_admin
--

CREATE INDEX idx_wi_status ON workflow.workflow_instances USING btree (status);


--
-- Name: idx_wi_step; Type: INDEX; Schema: workflow; Owner: hris_admin
--

CREATE INDEX idx_wi_step ON workflow.workflow_instances USING btree (current_step_id);


--
-- Name: att_logs_2025_employee_id_log_datetime_idx; Type: INDEX ATTACH; Schema: attendance; Owner: hris_admin
--

ALTER INDEX attendance.idx_att_logs_emp ATTACH PARTITION attendance.att_logs_2025_employee_id_log_datetime_idx;


--
-- Name: att_logs_2025_pkey; Type: INDEX ATTACH; Schema: attendance; Owner: hris_admin
--

ALTER INDEX attendance.att_logs_pkey ATTACH PARTITION attendance.att_logs_2025_pkey;


--
-- Name: att_logs_2026_employee_id_log_datetime_idx; Type: INDEX ATTACH; Schema: attendance; Owner: hris_admin
--

ALTER INDEX attendance.idx_att_logs_emp ATTACH PARTITION attendance.att_logs_2026_employee_id_log_datetime_idx;


--
-- Name: att_logs_2026_pkey; Type: INDEX ATTACH; Schema: attendance; Owner: hris_admin
--

ALTER INDEX attendance.att_logs_pkey ATTACH PARTITION attendance.att_logs_2026_pkey;


--
-- Name: att_logs_2027_employee_id_log_datetime_idx; Type: INDEX ATTACH; Schema: attendance; Owner: hris_admin
--

ALTER INDEX attendance.idx_att_logs_emp ATTACH PARTITION attendance.att_logs_2027_employee_id_log_datetime_idx;


--
-- Name: att_logs_2027_pkey; Type: INDEX ATTACH; Schema: attendance; Owner: hris_admin
--

ALTER INDEX attendance.att_logs_pkey ATTACH PARTITION attendance.att_logs_2027_pkey;


--
-- Name: att_logs_2028_employee_id_log_datetime_idx; Type: INDEX ATTACH; Schema: attendance; Owner: hris_admin
--

ALTER INDEX attendance.idx_att_logs_emp ATTACH PARTITION attendance.att_logs_2028_employee_id_log_datetime_idx;


--
-- Name: att_logs_2028_pkey; Type: INDEX ATTACH; Schema: attendance; Owner: hris_admin
--

ALTER INDEX attendance.att_logs_pkey ATTACH PARTITION attendance.att_logs_2028_pkey;


--
-- Name: sys_change_log_2025_company_id_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_chg_company ATTACH PARTITION audit_logs.sys_change_log_2025_company_id_created_at_idx;


--
-- Name: sys_change_log_2025_operation_table_name_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_chg_operation ATTACH PARTITION audit_logs.sys_change_log_2025_operation_table_name_created_at_idx;


--
-- Name: sys_change_log_2025_pkey; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.sys_change_log_pkey ATTACH PARTITION audit_logs.sys_change_log_2025_pkey;


--
-- Name: sys_change_log_2025_table_name_row_id_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_chg_table_rowid ATTACH PARTITION audit_logs.sys_change_log_2025_table_name_row_id_created_at_idx;


--
-- Name: sys_change_log_2025_user_id_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_chg_user ATTACH PARTITION audit_logs.sys_change_log_2025_user_id_created_at_idx;


--
-- Name: sys_change_log_2026_company_id_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_chg_company ATTACH PARTITION audit_logs.sys_change_log_2026_company_id_created_at_idx;


--
-- Name: sys_change_log_2026_operation_table_name_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_chg_operation ATTACH PARTITION audit_logs.sys_change_log_2026_operation_table_name_created_at_idx;


--
-- Name: sys_change_log_2026_pkey; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.sys_change_log_pkey ATTACH PARTITION audit_logs.sys_change_log_2026_pkey;


--
-- Name: sys_change_log_2026_table_name_row_id_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_chg_table_rowid ATTACH PARTITION audit_logs.sys_change_log_2026_table_name_row_id_created_at_idx;


--
-- Name: sys_change_log_2026_user_id_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_chg_user ATTACH PARTITION audit_logs.sys_change_log_2026_user_id_created_at_idx;


--
-- Name: sys_change_log_2027_company_id_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_chg_company ATTACH PARTITION audit_logs.sys_change_log_2027_company_id_created_at_idx;


--
-- Name: sys_change_log_2027_operation_table_name_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_chg_operation ATTACH PARTITION audit_logs.sys_change_log_2027_operation_table_name_created_at_idx;


--
-- Name: sys_change_log_2027_pkey; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.sys_change_log_pkey ATTACH PARTITION audit_logs.sys_change_log_2027_pkey;


--
-- Name: sys_change_log_2027_table_name_row_id_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_chg_table_rowid ATTACH PARTITION audit_logs.sys_change_log_2027_table_name_row_id_created_at_idx;


--
-- Name: sys_change_log_2027_user_id_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_chg_user ATTACH PARTITION audit_logs.sys_change_log_2027_user_id_created_at_idx;


--
-- Name: sys_change_log_2028_company_id_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_chg_company ATTACH PARTITION audit_logs.sys_change_log_2028_company_id_created_at_idx;


--
-- Name: sys_change_log_2028_operation_table_name_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_chg_operation ATTACH PARTITION audit_logs.sys_change_log_2028_operation_table_name_created_at_idx;


--
-- Name: sys_change_log_2028_pkey; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.sys_change_log_pkey ATTACH PARTITION audit_logs.sys_change_log_2028_pkey;


--
-- Name: sys_change_log_2028_table_name_row_id_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_chg_table_rowid ATTACH PARTITION audit_logs.sys_change_log_2028_table_name_row_id_created_at_idx;


--
-- Name: sys_change_log_2028_user_id_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_chg_user ATTACH PARTITION audit_logs.sys_change_log_2028_user_id_created_at_idx;


--
-- Name: sys_field_changes_2025_pkey; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.sys_field_changes_pkey ATTACH PARTITION audit_logs.sys_field_changes_2025_pkey;


--
-- Name: sys_field_changes_2025_table_name_field_name_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_fchg_table_field ATTACH PARTITION audit_logs.sys_field_changes_2025_table_name_field_name_created_at_idx;


--
-- Name: sys_field_changes_2025_table_name_row_id_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_fchg_row ATTACH PARTITION audit_logs.sys_field_changes_2025_table_name_row_id_created_at_idx;


--
-- Name: sys_field_changes_2025_user_id_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_fchg_user ATTACH PARTITION audit_logs.sys_field_changes_2025_user_id_created_at_idx;


--
-- Name: sys_field_changes_2026_pkey; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.sys_field_changes_pkey ATTACH PARTITION audit_logs.sys_field_changes_2026_pkey;


--
-- Name: sys_field_changes_2026_table_name_field_name_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_fchg_table_field ATTACH PARTITION audit_logs.sys_field_changes_2026_table_name_field_name_created_at_idx;


--
-- Name: sys_field_changes_2026_table_name_row_id_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_fchg_row ATTACH PARTITION audit_logs.sys_field_changes_2026_table_name_row_id_created_at_idx;


--
-- Name: sys_field_changes_2026_user_id_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_fchg_user ATTACH PARTITION audit_logs.sys_field_changes_2026_user_id_created_at_idx;


--
-- Name: sys_field_changes_2027_pkey; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.sys_field_changes_pkey ATTACH PARTITION audit_logs.sys_field_changes_2027_pkey;


--
-- Name: sys_field_changes_2027_table_name_field_name_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_fchg_table_field ATTACH PARTITION audit_logs.sys_field_changes_2027_table_name_field_name_created_at_idx;


--
-- Name: sys_field_changes_2027_table_name_row_id_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_fchg_row ATTACH PARTITION audit_logs.sys_field_changes_2027_table_name_row_id_created_at_idx;


--
-- Name: sys_field_changes_2027_user_id_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_fchg_user ATTACH PARTITION audit_logs.sys_field_changes_2027_user_id_created_at_idx;


--
-- Name: sys_field_changes_2028_pkey; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.sys_field_changes_pkey ATTACH PARTITION audit_logs.sys_field_changes_2028_pkey;


--
-- Name: sys_field_changes_2028_table_name_field_name_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_fchg_table_field ATTACH PARTITION audit_logs.sys_field_changes_2028_table_name_field_name_created_at_idx;


--
-- Name: sys_field_changes_2028_table_name_row_id_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_fchg_row ATTACH PARTITION audit_logs.sys_field_changes_2028_table_name_row_id_created_at_idx;


--
-- Name: sys_field_changes_2028_user_id_created_at_idx; Type: INDEX ATTACH; Schema: audit_logs; Owner: hris_admin
--

ALTER INDEX audit_logs.idx_fchg_user ATTACH PARTITION audit_logs.sys_field_changes_2028_user_id_created_at_idx;


--
-- Name: att_logs_2025_pkey; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.att_logs_pkey ATTACH PARTITION public.att_logs_2025_pkey;


--
-- Name: att_logs_2026_pkey; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.att_logs_pkey ATTACH PARTITION public.att_logs_2026_pkey;


--
-- Name: att_logs_2027_pkey; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.att_logs_pkey ATTACH PARTITION public.att_logs_2027_pkey;


--
-- Name: att_logs_2028_pkey; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.att_logs_pkey ATTACH PARTITION public.att_logs_2028_pkey;


--
-- Name: ntf_notifications_2025_pkey; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.ntf_notifications_pkey ATTACH PARTITION public.ntf_notifications_2025_pkey;


--
-- Name: ntf_notifications_2025_recipient_user_id_status_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_ntf_recipient_status ATTACH PARTITION public.ntf_notifications_2025_recipient_user_id_status_idx;


--
-- Name: ntf_notifications_2026_pkey; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.ntf_notifications_pkey ATTACH PARTITION public.ntf_notifications_2026_pkey;


--
-- Name: ntf_notifications_2026_recipient_user_id_status_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_ntf_recipient_status ATTACH PARTITION public.ntf_notifications_2026_recipient_user_id_status_idx;


--
-- Name: ntf_notifications_2027_pkey; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.ntf_notifications_pkey ATTACH PARTITION public.ntf_notifications_2027_pkey;


--
-- Name: ntf_notifications_2027_recipient_user_id_status_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_ntf_recipient_status ATTACH PARTITION public.ntf_notifications_2027_recipient_user_id_status_idx;


--
-- Name: ntf_notifications_2028_pkey; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.ntf_notifications_pkey ATTACH PARTITION public.ntf_notifications_2028_pkey;


--
-- Name: ntf_notifications_2028_recipient_user_id_status_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_ntf_recipient_status ATTACH PARTITION public.ntf_notifications_2028_recipient_user_id_status_idx;


--
-- Name: sys_audit_logs_2025_company_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_audit_company ATTACH PARTITION public.sys_audit_logs_2025_company_id_created_at_idx;


--
-- Name: sys_audit_logs_2025_pkey; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.sys_audit_logs_pkey ATTACH PARTITION public.sys_audit_logs_2025_pkey;


--
-- Name: sys_audit_logs_2025_resource_type_resource_id_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_audit_resource ATTACH PARTITION public.sys_audit_logs_2025_resource_type_resource_id_idx;


--
-- Name: sys_audit_logs_2025_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_audit_user ATTACH PARTITION public.sys_audit_logs_2025_user_id_created_at_idx;


--
-- Name: sys_audit_logs_2026_company_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_audit_company ATTACH PARTITION public.sys_audit_logs_2026_company_id_created_at_idx;


--
-- Name: sys_audit_logs_2026_pkey; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.sys_audit_logs_pkey ATTACH PARTITION public.sys_audit_logs_2026_pkey;


--
-- Name: sys_audit_logs_2026_resource_type_resource_id_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_audit_resource ATTACH PARTITION public.sys_audit_logs_2026_resource_type_resource_id_idx;


--
-- Name: sys_audit_logs_2026_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_audit_user ATTACH PARTITION public.sys_audit_logs_2026_user_id_created_at_idx;


--
-- Name: sys_audit_logs_2027_company_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_audit_company ATTACH PARTITION public.sys_audit_logs_2027_company_id_created_at_idx;


--
-- Name: sys_audit_logs_2027_pkey; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.sys_audit_logs_pkey ATTACH PARTITION public.sys_audit_logs_2027_pkey;


--
-- Name: sys_audit_logs_2027_resource_type_resource_id_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_audit_resource ATTACH PARTITION public.sys_audit_logs_2027_resource_type_resource_id_idx;


--
-- Name: sys_audit_logs_2027_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_audit_user ATTACH PARTITION public.sys_audit_logs_2027_user_id_created_at_idx;


--
-- Name: sys_audit_logs_2028_company_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_audit_company ATTACH PARTITION public.sys_audit_logs_2028_company_id_created_at_idx;


--
-- Name: sys_audit_logs_2028_pkey; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.sys_audit_logs_pkey ATTACH PARTITION public.sys_audit_logs_2028_pkey;


--
-- Name: sys_audit_logs_2028_resource_type_resource_id_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_audit_resource ATTACH PARTITION public.sys_audit_logs_2028_resource_type_resource_id_idx;


--
-- Name: sys_audit_logs_2028_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_audit_user ATTACH PARTITION public.sys_audit_logs_2028_user_id_created_at_idx;


--
-- Name: sys_change_log_2025_company_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_chg_company ATTACH PARTITION public.sys_change_log_2025_company_id_created_at_idx;


--
-- Name: sys_change_log_2025_operation_table_name_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_chg_operation ATTACH PARTITION public.sys_change_log_2025_operation_table_name_created_at_idx;


--
-- Name: sys_change_log_2025_pkey; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.sys_change_log_pkey ATTACH PARTITION public.sys_change_log_2025_pkey;


--
-- Name: sys_change_log_2025_table_name_row_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_chg_table_rowid ATTACH PARTITION public.sys_change_log_2025_table_name_row_id_created_at_idx;


--
-- Name: sys_change_log_2025_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_chg_user ATTACH PARTITION public.sys_change_log_2025_user_id_created_at_idx;


--
-- Name: sys_change_log_2026_company_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_chg_company ATTACH PARTITION public.sys_change_log_2026_company_id_created_at_idx;


--
-- Name: sys_change_log_2026_operation_table_name_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_chg_operation ATTACH PARTITION public.sys_change_log_2026_operation_table_name_created_at_idx;


--
-- Name: sys_change_log_2026_pkey; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.sys_change_log_pkey ATTACH PARTITION public.sys_change_log_2026_pkey;


--
-- Name: sys_change_log_2026_table_name_row_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_chg_table_rowid ATTACH PARTITION public.sys_change_log_2026_table_name_row_id_created_at_idx;


--
-- Name: sys_change_log_2026_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_chg_user ATTACH PARTITION public.sys_change_log_2026_user_id_created_at_idx;


--
-- Name: sys_change_log_2027_company_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_chg_company ATTACH PARTITION public.sys_change_log_2027_company_id_created_at_idx;


--
-- Name: sys_change_log_2027_operation_table_name_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_chg_operation ATTACH PARTITION public.sys_change_log_2027_operation_table_name_created_at_idx;


--
-- Name: sys_change_log_2027_pkey; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.sys_change_log_pkey ATTACH PARTITION public.sys_change_log_2027_pkey;


--
-- Name: sys_change_log_2027_table_name_row_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_chg_table_rowid ATTACH PARTITION public.sys_change_log_2027_table_name_row_id_created_at_idx;


--
-- Name: sys_change_log_2027_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_chg_user ATTACH PARTITION public.sys_change_log_2027_user_id_created_at_idx;


--
-- Name: sys_change_log_2028_company_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_chg_company ATTACH PARTITION public.sys_change_log_2028_company_id_created_at_idx;


--
-- Name: sys_change_log_2028_operation_table_name_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_chg_operation ATTACH PARTITION public.sys_change_log_2028_operation_table_name_created_at_idx;


--
-- Name: sys_change_log_2028_pkey; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.sys_change_log_pkey ATTACH PARTITION public.sys_change_log_2028_pkey;


--
-- Name: sys_change_log_2028_table_name_row_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_chg_table_rowid ATTACH PARTITION public.sys_change_log_2028_table_name_row_id_created_at_idx;


--
-- Name: sys_change_log_2028_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_chg_user ATTACH PARTITION public.sys_change_log_2028_user_id_created_at_idx;


--
-- Name: sys_field_changes_2025_pkey; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.sys_field_changes_pkey ATTACH PARTITION public.sys_field_changes_2025_pkey;


--
-- Name: sys_field_changes_2025_table_name_field_name_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_fchg_table_field ATTACH PARTITION public.sys_field_changes_2025_table_name_field_name_created_at_idx;


--
-- Name: sys_field_changes_2025_table_name_row_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_fchg_row ATTACH PARTITION public.sys_field_changes_2025_table_name_row_id_created_at_idx;


--
-- Name: sys_field_changes_2025_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_fchg_user ATTACH PARTITION public.sys_field_changes_2025_user_id_created_at_idx;


--
-- Name: sys_field_changes_2026_pkey; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.sys_field_changes_pkey ATTACH PARTITION public.sys_field_changes_2026_pkey;


--
-- Name: sys_field_changes_2026_table_name_field_name_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_fchg_table_field ATTACH PARTITION public.sys_field_changes_2026_table_name_field_name_created_at_idx;


--
-- Name: sys_field_changes_2026_table_name_row_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_fchg_row ATTACH PARTITION public.sys_field_changes_2026_table_name_row_id_created_at_idx;


--
-- Name: sys_field_changes_2026_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_fchg_user ATTACH PARTITION public.sys_field_changes_2026_user_id_created_at_idx;


--
-- Name: sys_field_changes_2027_pkey; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.sys_field_changes_pkey ATTACH PARTITION public.sys_field_changes_2027_pkey;


--
-- Name: sys_field_changes_2027_table_name_field_name_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_fchg_table_field ATTACH PARTITION public.sys_field_changes_2027_table_name_field_name_created_at_idx;


--
-- Name: sys_field_changes_2027_table_name_row_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_fchg_row ATTACH PARTITION public.sys_field_changes_2027_table_name_row_id_created_at_idx;


--
-- Name: sys_field_changes_2027_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_fchg_user ATTACH PARTITION public.sys_field_changes_2027_user_id_created_at_idx;


--
-- Name: sys_field_changes_2028_pkey; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.sys_field_changes_pkey ATTACH PARTITION public.sys_field_changes_2028_pkey;


--
-- Name: sys_field_changes_2028_table_name_field_name_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_fchg_table_field ATTACH PARTITION public.sys_field_changes_2028_table_name_field_name_created_at_idx;


--
-- Name: sys_field_changes_2028_table_name_row_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_fchg_row ATTACH PARTITION public.sys_field_changes_2028_table_name_row_id_created_at_idx;


--
-- Name: sys_field_changes_2028_user_id_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: hris_admin
--

ALTER INDEX public.idx_fchg_user ATTACH PARTITION public.sys_field_changes_2028_user_id_created_at_idx;


--
-- Name: att_daily trg_capture_change; Type: TRIGGER; Schema: attendance; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON attendance.att_daily FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: att_dtr_corrections trg_capture_change; Type: TRIGGER; Schema: attendance; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON attendance.att_dtr_corrections FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: att_holidays trg_capture_change; Type: TRIGGER; Schema: attendance; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON attendance.att_holidays FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: att_overtime_requests trg_capture_change; Type: TRIGGER; Schema: attendance; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON attendance.att_overtime_requests FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: att_shift_assignments trg_capture_change; Type: TRIGGER; Schema: attendance; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON attendance.att_shift_assignments FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: att_shifts trg_capture_change; Type: TRIGGER; Schema: attendance; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON attendance.att_shifts FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: att_overtime_requests trg_status_transition; Type: TRIGGER; Schema: attendance; Owner: hris_admin
--

CREATE TRIGGER trg_status_transition AFTER UPDATE OF status ON attendance.att_overtime_requests FOR EACH ROW WHEN (((old.status)::text IS DISTINCT FROM (new.status)::text)) EXECUTE FUNCTION audit_logs.fn_capture_status_change();


--
-- Name: companies trg_capture_change; Type: TRIGGER; Schema: core; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON core.companies FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: departments trg_capture_change; Type: TRIGGER; Schema: core; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON core.departments FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: documents trg_capture_change; Type: TRIGGER; Schema: core; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON core.documents FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: emp_addresses trg_capture_change; Type: TRIGGER; Schema: core; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON core.emp_addresses FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: emp_bank_accounts trg_capture_change; Type: TRIGGER; Schema: core; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON core.emp_bank_accounts FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: emp_dependents trg_capture_change; Type: TRIGGER; Schema: core; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON core.emp_dependents FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: emp_education trg_capture_change; Type: TRIGGER; Schema: core; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON core.emp_education FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: emp_emergency_contacts trg_capture_change; Type: TRIGGER; Schema: core; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON core.emp_emergency_contacts FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: emp_government_ids trg_capture_change; Type: TRIGGER; Schema: core; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON core.emp_government_ids FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: emp_status_history trg_capture_change; Type: TRIGGER; Schema: core; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON core.emp_status_history FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: emp_work_history trg_capture_change; Type: TRIGGER; Schema: core; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON core.emp_work_history FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: employees trg_capture_change; Type: TRIGGER; Schema: core; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON core.employees FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: employment_types trg_capture_change; Type: TRIGGER; Schema: core; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON core.employment_types FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: job_grades trg_capture_change; Type: TRIGGER; Schema: core; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON core.job_grades FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: positions trg_capture_change; Type: TRIGGER; Schema: core; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON core.positions FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: users trg_capture_change; Type: TRIGGER; Schema: core; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON core.users FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: employees trg_status_transition; Type: TRIGGER; Schema: core; Owner: hris_admin
--

CREATE TRIGGER trg_status_transition AFTER UPDATE OF status ON core.employees FOR EACH ROW WHEN (((old.status)::text IS DISTINCT FROM (new.status)::text)) EXECUTE FUNCTION audit_logs.fn_capture_status_change();


--
-- Name: appeals trg_capture_change; Type: TRIGGER; Schema: discipline; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON discipline.appeals FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: cases trg_capture_change; Type: TRIGGER; Schema: discipline; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON discipline.cases FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: complaints trg_capture_change; Type: TRIGGER; Schema: discipline; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON discipline.complaints FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: decisions trg_capture_change; Type: TRIGGER; Schema: discipline; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON discipline.decisions FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: formal_charges trg_capture_change; Type: TRIGGER; Schema: discipline; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON discipline.formal_charges FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: hearings trg_capture_change; Type: TRIGGER; Schema: discipline; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON discipline.hearings FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: investigations trg_capture_change; Type: TRIGGER; Schema: discipline; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON discipline.investigations FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: preventive_suspensions trg_capture_change; Type: TRIGGER; Schema: discipline; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON discipline.preventive_suspensions FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: document_categories trg_capture_change; Type: TRIGGER; Schema: dms; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON dms.document_categories FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: document_requests trg_capture_change; Type: TRIGGER; Schema: dms; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON dms.document_requests FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: retention_policies trg_capture_change; Type: TRIGGER; Schema: dms; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON dms.retention_policies FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: service_record_snapshots trg_capture_change; Type: TRIGGER; Schema: dms; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON dms.service_record_snapshots FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: health_certificates trg_capture_change; Type: TRIGGER; Schema: health; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON health.health_certificates FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: incident_investigations trg_capture_change; Type: TRIGGER; Schema: health; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON health.incident_investigations FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: incidents trg_capture_change; Type: TRIGGER; Schema: health; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON health.incidents FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: medical_records trg_capture_change; Type: TRIGGER; Schema: health; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON health.medical_records FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: pe_results trg_capture_change; Type: TRIGGER; Schema: health; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON health.pe_results FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: wellness_programs trg_capture_change; Type: TRIGGER; Schema: health; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON health.wellness_programs FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: lrn_attendance_logs trg_capture_change; Type: TRIGGER; Schema: learning; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON learning.lrn_attendance_logs FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: lrn_enrollments trg_capture_change; Type: TRIGGER; Schema: learning; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON learning.lrn_enrollments FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: lrn_narrative_reports trg_capture_change; Type: TRIGGER; Schema: learning; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON learning.lrn_narrative_reports FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: lrn_scholarships trg_capture_change; Type: TRIGGER; Schema: learning; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON learning.lrn_scholarships FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: lv_approvals trg_capture_change; Type: TRIGGER; Schema: leave_mgmt; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON leave_mgmt.lv_approvals FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: lv_balances trg_capture_change; Type: TRIGGER; Schema: leave_mgmt; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON leave_mgmt.lv_balances FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: lv_policies trg_capture_change; Type: TRIGGER; Schema: leave_mgmt; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON leave_mgmt.lv_policies FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: lv_requests trg_capture_change; Type: TRIGGER; Schema: leave_mgmt; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON leave_mgmt.lv_requests FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: lv_travel_orders trg_capture_change; Type: TRIGGER; Schema: leave_mgmt; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON leave_mgmt.lv_travel_orders FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: lv_types trg_capture_change; Type: TRIGGER; Schema: leave_mgmt; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON leave_mgmt.lv_types FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: lv_requests trg_status_transition; Type: TRIGGER; Schema: leave_mgmt; Owner: hris_admin
--

CREATE TRIGGER trg_status_transition AFTER UPDATE OF status ON leave_mgmt.lv_requests FOR EACH ROW WHEN (((old.status)::text IS DISTINCT FROM (new.status)::text)) EXECUTE FUNCTION audit_logs.fn_capture_status_change();


--
-- Name: offb_clearance_items trg_capture_change; Type: TRIGGER; Schema: onboarding; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON onboarding.offb_clearance_items FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: onb_pre_employment_reqs trg_capture_change; Type: TRIGGER; Schema: onboarding; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON onboarding.onb_pre_employment_reqs FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: pay_annual_bonuses trg_capture_change; Type: TRIGGER; Schema: payroll; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON payroll.pay_annual_bonuses FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: pay_coop_members trg_capture_change; Type: TRIGGER; Schema: payroll; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON payroll.pay_coop_members FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: pay_employee_payroll trg_capture_change; Type: TRIGGER; Schema: payroll; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON payroll.pay_employee_payroll FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: pay_loans trg_capture_change; Type: TRIGGER; Schema: payroll; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON payroll.pay_loans FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: pay_periods trg_capture_change; Type: TRIGGER; Schema: payroll; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON payroll.pay_periods FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: pay_runs trg_capture_change; Type: TRIGGER; Schema: payroll; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON payroll.pay_runs FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: pay_loans trg_status_transition; Type: TRIGGER; Schema: payroll; Owner: hris_admin
--

CREATE TRIGGER trg_status_transition AFTER UPDATE OF status ON payroll.pay_loans FOR EACH ROW WHEN (((old.status)::text IS DISTINCT FROM (new.status)::text)) EXECUTE FUNCTION audit_logs.fn_capture_status_change();


--
-- Name: pay_runs trg_status_transition; Type: TRIGGER; Schema: payroll; Owner: hris_admin
--

CREATE TRIGGER trg_status_transition AFTER UPDATE OF status ON payroll.pay_runs FOR EACH ROW WHEN (((old.status)::text IS DISTINCT FROM (new.status)::text)) EXECUTE FUNCTION audit_logs.fn_capture_status_change();


--
-- Name: perf_employee_kpis trg_capture_change; Type: TRIGGER; Schema: performance; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON performance.perf_employee_kpis FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: perf_ipcr trg_capture_change; Type: TRIGGER; Schema: performance; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON performance.perf_ipcr FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: perf_ipcr_summary trg_capture_change; Type: TRIGGER; Schema: performance; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON performance.perf_ipcr_summary FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: perf_opcr trg_capture_change; Type: TRIGGER; Schema: performance; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON performance.perf_opcr FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: perf_reviews trg_capture_change; Type: TRIGGER; Schema: performance; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON performance.perf_reviews FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: perf_succession_matrix trg_capture_change; Type: TRIGGER; Schema: performance; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON performance.perf_succession_matrix FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: rec_applicants trg_capture_change; Type: TRIGGER; Schema: recruitment; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON recruitment.rec_applicants FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: rec_appointments trg_capture_change; Type: TRIGGER; Schema: recruitment; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON recruitment.rec_appointments FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: rec_next_in_rank_list trg_capture_change; Type: TRIGGER; Schema: recruitment; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON recruitment.rec_next_in_rank_list FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: rec_plantilla_items trg_capture_change; Type: TRIGGER; Schema: recruitment; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON recruitment.rec_plantilla_items FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: rec_psb_scores trg_capture_change; Type: TRIGGER; Schema: recruitment; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON recruitment.rec_psb_scores FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: rec_requisitions trg_capture_change; Type: TRIGGER; Schema: recruitment; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON recruitment.rec_requisitions FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: rwd_loyalty_milestones trg_capture_change; Type: TRIGGER; Schema: rewards; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON rewards.rwd_loyalty_milestones FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: rwd_pbb_records trg_capture_change; Type: TRIGGER; Schema: rewards; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON rewards.rwd_pbb_records FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: rwd_retirement_alerts trg_capture_change; Type: TRIGGER; Schema: rewards; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON rewards.rwd_retirement_alerts FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: rwd_step_increments trg_capture_change; Type: TRIGGER; Schema: rewards; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON rewards.rwd_step_increments FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: workflow_action_logs trg_capture_change; Type: TRIGGER; Schema: workflow; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON workflow.workflow_action_logs FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: workflow_instances trg_capture_change; Type: TRIGGER; Schema: workflow; Owner: hris_admin
--

CREATE TRIGGER trg_capture_change AFTER INSERT OR DELETE OR UPDATE ON workflow.workflow_instances FOR EACH ROW EXECUTE FUNCTION audit_logs.fn_capture_change();


--
-- Name: workflow_instances trg_status_transition; Type: TRIGGER; Schema: workflow; Owner: hris_admin
--

CREATE TRIGGER trg_status_transition AFTER UPDATE OF status ON workflow.workflow_instances FOR EACH ROW WHEN (((old.status)::text IS DISTINCT FROM (new.status)::text)) EXECUTE FUNCTION audit_logs.fn_capture_status_change();


--
-- Name: ai_feature_store ai_feature_store_employee_id_fkey; Type: FK CONSTRAINT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_feature_store
    ADD CONSTRAINT ai_feature_store_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: ai_messages ai_messages_session_id_fkey; Type: FK CONSTRAINT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_messages
    ADD CONSTRAINT ai_messages_session_id_fkey FOREIGN KEY (session_id) REFERENCES ai.ai_sessions(id);


--
-- Name: ai_recommendations ai_recommendations_target_employee_id_fkey; Type: FK CONSTRAINT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_recommendations
    ADD CONSTRAINT ai_recommendations_target_employee_id_fkey FOREIGN KEY (target_employee_id) REFERENCES core.employees(id);


--
-- Name: ai_recommendations ai_recommendations_target_user_id_fkey; Type: FK CONSTRAINT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_recommendations
    ADD CONSTRAINT ai_recommendations_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES core.users(id);


--
-- Name: ai_risk_scores ai_risk_scores_employee_id_fkey; Type: FK CONSTRAINT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_risk_scores
    ADD CONSTRAINT ai_risk_scores_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: ai_sessions ai_sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_sessions
    ADD CONSTRAINT ai_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES core.users(id);


--
-- Name: ai_tool_call_logs ai_tool_call_logs_message_id_fkey; Type: FK CONSTRAINT; Schema: ai; Owner: hris_admin
--

ALTER TABLE ONLY ai.ai_tool_call_logs
    ADD CONSTRAINT ai_tool_call_logs_message_id_fkey FOREIGN KEY (message_id) REFERENCES ai.ai_messages(id);


--
-- Name: dim_department dim_department_department_id_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.dim_department
    ADD CONSTRAINT dim_department_department_id_fkey FOREIGN KEY (department_id) REFERENCES core.departments(id);


--
-- Name: dim_employee dim_employee_employee_id_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.dim_employee
    ADD CONSTRAINT dim_employee_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: dim_position dim_position_position_id_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.dim_position
    ADD CONSTRAINT dim_position_position_id_fkey FOREIGN KEY (position_id) REFERENCES core.positions(id);


--
-- Name: fact_attendance fact_attendance_date_key_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.fact_attendance
    ADD CONSTRAINT fact_attendance_date_key_fkey FOREIGN KEY (date_key) REFERENCES analytics.dim_date(date_key);


--
-- Name: fact_attendance fact_attendance_department_key_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.fact_attendance
    ADD CONSTRAINT fact_attendance_department_key_fkey FOREIGN KEY (department_key) REFERENCES analytics.dim_department(surrogate_key);


--
-- Name: fact_attendance fact_attendance_employee_key_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.fact_attendance
    ADD CONSTRAINT fact_attendance_employee_key_fkey FOREIGN KEY (employee_key) REFERENCES analytics.dim_employee(surrogate_key);


--
-- Name: fact_leave fact_leave_date_key_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.fact_leave
    ADD CONSTRAINT fact_leave_date_key_fkey FOREIGN KEY (date_key) REFERENCES analytics.dim_date(date_key);


--
-- Name: fact_leave fact_leave_employee_key_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.fact_leave
    ADD CONSTRAINT fact_leave_employee_key_fkey FOREIGN KEY (employee_key) REFERENCES analytics.dim_employee(surrogate_key);


--
-- Name: fact_payroll fact_payroll_date_key_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.fact_payroll
    ADD CONSTRAINT fact_payroll_date_key_fkey FOREIGN KEY (date_key) REFERENCES analytics.dim_date(date_key);


--
-- Name: fact_payroll fact_payroll_department_key_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.fact_payroll
    ADD CONSTRAINT fact_payroll_department_key_fkey FOREIGN KEY (department_key) REFERENCES analytics.dim_department(surrogate_key);


--
-- Name: fact_payroll fact_payroll_employee_key_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.fact_payroll
    ADD CONSTRAINT fact_payroll_employee_key_fkey FOREIGN KEY (employee_key) REFERENCES analytics.dim_employee(surrogate_key);


--
-- Name: fact_training fact_training_date_key_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.fact_training
    ADD CONSTRAINT fact_training_date_key_fkey FOREIGN KEY (date_key) REFERENCES analytics.dim_date(date_key);


--
-- Name: fact_training fact_training_employee_key_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.fact_training
    ADD CONSTRAINT fact_training_employee_key_fkey FOREIGN KEY (employee_key) REFERENCES analytics.dim_employee(surrogate_key);


--
-- Name: report_field_registry report_field_registry_source_id_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.report_field_registry
    ADD CONSTRAINT report_field_registry_source_id_fkey FOREIGN KEY (source_id) REFERENCES analytics.report_data_sources(id);


--
-- Name: report_run_history report_run_history_report_id_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.report_run_history
    ADD CONSTRAINT report_run_history_report_id_fkey FOREIGN KEY (report_id) REFERENCES analytics.saved_reports(id);


--
-- Name: report_run_history report_run_history_run_by_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.report_run_history
    ADD CONSTRAINT report_run_history_run_by_fkey FOREIGN KEY (run_by) REFERENCES core.users(id);


--
-- Name: report_run_history report_run_history_schedule_id_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.report_run_history
    ADD CONSTRAINT report_run_history_schedule_id_fkey FOREIGN KEY (schedule_id) REFERENCES analytics.report_schedules(id);


--
-- Name: report_schedules report_schedules_created_by_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.report_schedules
    ADD CONSTRAINT report_schedules_created_by_fkey FOREIGN KEY (created_by) REFERENCES core.users(id);


--
-- Name: report_schedules report_schedules_report_id_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.report_schedules
    ADD CONSTRAINT report_schedules_report_id_fkey FOREIGN KEY (report_id) REFERENCES analytics.saved_reports(id) ON DELETE CASCADE;


--
-- Name: saved_reports saved_reports_created_by_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.saved_reports
    ADD CONSTRAINT saved_reports_created_by_fkey FOREIGN KEY (created_by) REFERENCES core.users(id);


--
-- Name: saved_reports saved_reports_source_id_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: hris_admin
--

ALTER TABLE ONLY analytics.saved_reports
    ADD CONSTRAINT saved_reports_source_id_fkey FOREIGN KEY (source_id) REFERENCES analytics.report_data_sources(id);


--
-- Name: att_admin_overrides att_admin_overrides_employee_id_fkey; Type: FK CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_admin_overrides
    ADD CONSTRAINT att_admin_overrides_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: att_admin_overrides att_admin_overrides_overridden_by_fkey; Type: FK CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_admin_overrides
    ADD CONSTRAINT att_admin_overrides_overridden_by_fkey FOREIGN KEY (overridden_by) REFERENCES core.users(id);


--
-- Name: att_daily att_daily_employee_id_fkey; Type: FK CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_daily
    ADD CONSTRAINT att_daily_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: att_daily att_daily_holiday_id_fkey; Type: FK CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_daily
    ADD CONSTRAINT att_daily_holiday_id_fkey FOREIGN KEY (holiday_id) REFERENCES attendance.att_holidays(id);


--
-- Name: att_daily att_daily_locked_by_fkey; Type: FK CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_daily
    ADD CONSTRAINT att_daily_locked_by_fkey FOREIGN KEY (locked_by) REFERENCES core.users(id);


--
-- Name: att_daily att_daily_shift_id_fkey; Type: FK CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_daily
    ADD CONSTRAINT att_daily_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES attendance.att_shifts(id);


--
-- Name: att_dtr_corrections att_dtr_corrections_employee_id_fkey; Type: FK CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_dtr_corrections
    ADD CONSTRAINT att_dtr_corrections_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: att_dtr_corrections att_dtr_corrections_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_dtr_corrections
    ADD CONSTRAINT att_dtr_corrections_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES core.users(id);


--
-- Name: att_holidays att_holidays_company_id_fkey; Type: FK CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_holidays
    ADD CONSTRAINT att_holidays_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: att_holidays att_holidays_holiday_type_id_fkey; Type: FK CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_holidays
    ADD CONSTRAINT att_holidays_holiday_type_id_fkey FOREIGN KEY (holiday_type_id) REFERENCES attendance.att_holiday_types(id);


--
-- Name: att_logs att_logs_employee_id_fkey; Type: FK CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE attendance.att_logs
    ADD CONSTRAINT att_logs_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: att_logs att_logs_invalidated_by_fkey; Type: FK CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE attendance.att_logs
    ADD CONSTRAINT att_logs_invalidated_by_fkey FOREIGN KEY (invalidated_by) REFERENCES core.users(id);


--
-- Name: att_overtime_requests att_overtime_requests_approved_by_fkey; Type: FK CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_overtime_requests
    ADD CONSTRAINT att_overtime_requests_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES core.employees(id);


--
-- Name: att_overtime_requests att_overtime_requests_employee_id_fkey; Type: FK CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_overtime_requests
    ADD CONSTRAINT att_overtime_requests_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: att_shift_assignments att_shift_assignments_created_by_fkey; Type: FK CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_shift_assignments
    ADD CONSTRAINT att_shift_assignments_created_by_fkey FOREIGN KEY (created_by) REFERENCES core.users(id);


--
-- Name: att_shift_assignments att_shift_assignments_employee_id_fkey; Type: FK CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_shift_assignments
    ADD CONSTRAINT att_shift_assignments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: att_shift_assignments att_shift_assignments_shift_id_fkey; Type: FK CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_shift_assignments
    ADD CONSTRAINT att_shift_assignments_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES attendance.att_shifts(id);


--
-- Name: att_shifts att_shifts_company_id_fkey; Type: FK CONSTRAINT; Schema: attendance; Owner: hris_admin
--

ALTER TABLE ONLY attendance.att_shifts
    ADD CONSTRAINT att_shifts_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: business_units business_units_company_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.business_units
    ADD CONSTRAINT business_units_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: business_units business_units_parent_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.business_units
    ADD CONSTRAINT business_units_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES core.business_units(id);


--
-- Name: company_branding company_branding_company_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.company_branding
    ADD CONSTRAINT company_branding_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: demo_profiles demo_profiles_loaded_by_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.demo_profiles
    ADD CONSTRAINT demo_profiles_loaded_by_fkey FOREIGN KEY (loaded_by) REFERENCES core.users(id);


--
-- Name: departments departments_business_unit_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.departments
    ADD CONSTRAINT departments_business_unit_id_fkey FOREIGN KEY (business_unit_id) REFERENCES core.business_units(id);


--
-- Name: departments departments_company_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.departments
    ADD CONSTRAINT departments_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: departments departments_parent_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.departments
    ADD CONSTRAINT departments_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES core.departments(id);


--
-- Name: documents documents_company_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.documents
    ADD CONSTRAINT documents_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: documents documents_employee_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.documents
    ADD CONSTRAINT documents_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: documents documents_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.documents
    ADD CONSTRAINT documents_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES core.users(id);


--
-- Name: documents documents_verified_by_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.documents
    ADD CONSTRAINT documents_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES core.users(id);


--
-- Name: emp_addresses emp_addresses_employee_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_addresses
    ADD CONSTRAINT emp_addresses_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id) ON DELETE CASCADE;


--
-- Name: emp_bank_accounts emp_bank_accounts_employee_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_bank_accounts
    ADD CONSTRAINT emp_bank_accounts_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id) ON DELETE CASCADE;


--
-- Name: emp_dependents emp_dependents_employee_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_dependents
    ADD CONSTRAINT emp_dependents_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id) ON DELETE CASCADE;


--
-- Name: emp_education emp_education_employee_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_education
    ADD CONSTRAINT emp_education_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id) ON DELETE CASCADE;


--
-- Name: emp_emergency_contacts emp_emergency_contacts_employee_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_emergency_contacts
    ADD CONSTRAINT emp_emergency_contacts_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id) ON DELETE CASCADE;


--
-- Name: emp_government_ids emp_government_ids_employee_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_government_ids
    ADD CONSTRAINT emp_government_ids_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id) ON DELETE CASCADE;


--
-- Name: emp_government_ids emp_government_ids_verified_by_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_government_ids
    ADD CONSTRAINT emp_government_ids_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES core.users(id);


--
-- Name: emp_status_history emp_status_history_changed_by_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_status_history
    ADD CONSTRAINT emp_status_history_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES core.users(id);


--
-- Name: emp_status_history emp_status_history_employee_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_status_history
    ADD CONSTRAINT emp_status_history_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id) ON DELETE CASCADE;


--
-- Name: emp_work_history emp_work_history_employee_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.emp_work_history
    ADD CONSTRAINT emp_work_history_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id) ON DELETE CASCADE;


--
-- Name: employees employees_company_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.employees
    ADD CONSTRAINT employees_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: employees employees_created_by_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.employees
    ADD CONSTRAINT employees_created_by_fkey FOREIGN KEY (created_by) REFERENCES core.users(id);


--
-- Name: employees employees_department_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.employees
    ADD CONSTRAINT employees_department_id_fkey FOREIGN KEY (department_id) REFERENCES core.departments(id);


--
-- Name: employees employees_employment_type_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.employees
    ADD CONSTRAINT employees_employment_type_id_fkey FOREIGN KEY (employment_type_id) REFERENCES core.employment_types(id);


--
-- Name: employees employees_immediate_supervisor_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.employees
    ADD CONSTRAINT employees_immediate_supervisor_id_fkey FOREIGN KEY (immediate_supervisor_id) REFERENCES core.employees(id);


--
-- Name: employees employees_job_grade_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.employees
    ADD CONSTRAINT employees_job_grade_id_fkey FOREIGN KEY (job_grade_id) REFERENCES core.job_grades(id);


--
-- Name: employees employees_position_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.employees
    ADD CONSTRAINT employees_position_id_fkey FOREIGN KEY (position_id) REFERENCES core.positions(id);


--
-- Name: employees employees_updated_by_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.employees
    ADD CONSTRAINT employees_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES core.users(id);


--
-- Name: feature_registry feature_registry_page_path_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.feature_registry
    ADD CONSTRAINT feature_registry_page_path_fkey FOREIGN KEY (page_path) REFERENCES core.page_registry(path) ON DELETE SET NULL DEFERRABLE;


--
-- Name: field_privacy_rules field_privacy_rules_updated_by_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.field_privacy_rules
    ADD CONSTRAINT field_privacy_rules_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES core.users(id) ON DELETE SET NULL;


--
-- Name: business_units fk_bu_head; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.business_units
    ADD CONSTRAINT fk_bu_head FOREIGN KEY (head_employee_id) REFERENCES core.employees(id);


--
-- Name: departments fk_dept_head; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.departments
    ADD CONSTRAINT fk_dept_head FOREIGN KEY (head_employee_id) REFERENCES core.employees(id);


--
-- Name: documents fk_docs_category; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.documents
    ADD CONSTRAINT fk_docs_category FOREIGN KEY (category_id) REFERENCES dms.document_categories(id);


--
-- Name: users fk_users_employee; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.users
    ADD CONSTRAINT fk_users_employee FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: form_fields form_fields_form_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.form_fields
    ADD CONSTRAINT form_fields_form_id_fkey FOREIGN KEY (form_id) REFERENCES core.dynamic_forms(id) ON DELETE CASCADE;


--
-- Name: job_grades job_grades_company_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.job_grades
    ADD CONSTRAINT job_grades_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: mod_permissions mod_permissions_granted_by_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.mod_permissions
    ADD CONSTRAINT mod_permissions_granted_by_fkey FOREIGN KEY (granted_by) REFERENCES core.users(id);


--
-- Name: mod_permissions mod_permissions_grantee_user_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.mod_permissions
    ADD CONSTRAINT mod_permissions_grantee_user_id_fkey FOREIGN KEY (grantee_user_id) REFERENCES core.users(id) ON DELETE CASCADE;


--
-- Name: orchestration_steps orchestration_steps_flow_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.orchestration_steps
    ADD CONSTRAINT orchestration_steps_flow_id_fkey FOREIGN KEY (flow_id) REFERENCES core.orchestration_flows(id) ON DELETE CASCADE;


--
-- Name: org_chart_nodes org_chart_nodes_company_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.org_chart_nodes
    ADD CONSTRAINT org_chart_nodes_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: org_chart_nodes org_chart_nodes_employee_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.org_chart_nodes
    ADD CONSTRAINT org_chart_nodes_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: org_chart_nodes org_chart_nodes_parent_node_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.org_chart_nodes
    ADD CONSTRAINT org_chart_nodes_parent_node_id_fkey FOREIGN KEY (parent_node_id) REFERENCES core.org_chart_nodes(id);


--
-- Name: org_chart_nodes org_chart_nodes_position_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.org_chart_nodes
    ADD CONSTRAINT org_chart_nodes_position_id_fkey FOREIGN KEY (position_id) REFERENCES core.positions(id);


--
-- Name: positions positions_company_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.positions
    ADD CONSTRAINT positions_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: positions positions_department_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.positions
    ADD CONSTRAINT positions_department_id_fkey FOREIGN KEY (department_id) REFERENCES core.departments(id);


--
-- Name: positions positions_job_grade_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.positions
    ADD CONSTRAINT positions_job_grade_id_fkey FOREIGN KEY (job_grade_id) REFERENCES core.job_grades(id);


--
-- Name: role_feature_access role_feature_access_feature_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.role_feature_access
    ADD CONSTRAINT role_feature_access_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES core.feature_registry(id) ON DELETE CASCADE;


--
-- Name: role_page_access role_page_access_page_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.role_page_access
    ADD CONSTRAINT role_page_access_page_id_fkey FOREIGN KEY (page_id) REFERENCES core.page_registry(id) ON DELETE CASCADE;


--
-- Name: role_permissions role_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.role_permissions
    ADD CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES core.permissions(id) ON DELETE CASCADE;


--
-- Name: role_permissions role_permissions_role_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.role_permissions
    ADD CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES core.roles(id) ON DELETE CASCADE;


--
-- Name: roles roles_company_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.roles
    ADD CONSTRAINT roles_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: task_inbox task_inbox_employee_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.task_inbox
    ADD CONSTRAINT task_inbox_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: task_inbox task_inbox_user_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.task_inbox
    ADD CONSTRAINT task_inbox_user_id_fkey FOREIGN KEY (user_id) REFERENCES core.users(id);


--
-- Name: user_feature_access user_feature_access_feature_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.user_feature_access
    ADD CONSTRAINT user_feature_access_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES core.feature_registry(id) ON DELETE CASCADE;


--
-- Name: user_feature_access user_feature_access_granted_by_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.user_feature_access
    ADD CONSTRAINT user_feature_access_granted_by_fkey FOREIGN KEY (granted_by) REFERENCES core.users(id);


--
-- Name: user_feature_access user_feature_access_user_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.user_feature_access
    ADD CONSTRAINT user_feature_access_user_id_fkey FOREIGN KEY (user_id) REFERENCES core.users(id) ON DELETE CASCADE;


--
-- Name: user_page_access user_page_access_granted_by_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.user_page_access
    ADD CONSTRAINT user_page_access_granted_by_fkey FOREIGN KEY (granted_by) REFERENCES core.users(id);


--
-- Name: user_page_access user_page_access_page_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.user_page_access
    ADD CONSTRAINT user_page_access_page_id_fkey FOREIGN KEY (page_id) REFERENCES core.page_registry(id) ON DELETE CASCADE;


--
-- Name: user_page_access user_page_access_user_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.user_page_access
    ADD CONSTRAINT user_page_access_user_id_fkey FOREIGN KEY (user_id) REFERENCES core.users(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_assigned_by_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.user_roles
    ADD CONSTRAINT user_roles_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES core.users(id);


--
-- Name: user_roles user_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.user_roles
    ADD CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES core.roles(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES core.users(id) ON DELETE CASCADE;


--
-- Name: users users_company_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.users
    ADD CONSTRAINT users_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: users users_theme_id_fkey; Type: FK CONSTRAINT; Schema: core; Owner: hris_admin
--

ALTER TABLE ONLY core.users
    ADD CONSTRAINT users_theme_id_fkey FOREIGN KEY (theme_id) REFERENCES core.ui_themes(id);


--
-- Name: appeals appeals_case_id_fkey; Type: FK CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.appeals
    ADD CONSTRAINT appeals_case_id_fkey FOREIGN KEY (case_id) REFERENCES discipline.cases(id) ON DELETE CASCADE;


--
-- Name: appeals appeals_decision_id_fkey; Type: FK CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.appeals
    ADD CONSTRAINT appeals_decision_id_fkey FOREIGN KEY (decision_id) REFERENCES discipline.decisions(id);


--
-- Name: appeals appeals_filed_by_fkey; Type: FK CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.appeals
    ADD CONSTRAINT appeals_filed_by_fkey FOREIGN KEY (filed_by) REFERENCES core.users(id);


--
-- Name: cases cases_assigned_to_fkey; Type: FK CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.cases
    ADD CONSTRAINT cases_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES core.users(id);


--
-- Name: cases cases_case_type_id_fkey; Type: FK CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.cases
    ADD CONSTRAINT cases_case_type_id_fkey FOREIGN KEY (case_type_id) REFERENCES discipline.case_types(id);


--
-- Name: cases cases_company_id_fkey; Type: FK CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.cases
    ADD CONSTRAINT cases_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: cases cases_complainant_id_fkey; Type: FK CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.cases
    ADD CONSTRAINT cases_complainant_id_fkey FOREIGN KEY (complainant_id) REFERENCES core.employees(id);


--
-- Name: cases cases_created_by_fkey; Type: FK CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.cases
    ADD CONSTRAINT cases_created_by_fkey FOREIGN KEY (created_by) REFERENCES core.users(id);


--
-- Name: cases cases_respondent_id_fkey; Type: FK CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.cases
    ADD CONSTRAINT cases_respondent_id_fkey FOREIGN KEY (respondent_id) REFERENCES core.employees(id);


--
-- Name: complaints complaints_case_id_fkey; Type: FK CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.complaints
    ADD CONSTRAINT complaints_case_id_fkey FOREIGN KEY (case_id) REFERENCES discipline.cases(id) ON DELETE CASCADE;


--
-- Name: complaints complaints_filed_by_fkey; Type: FK CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.complaints
    ADD CONSTRAINT complaints_filed_by_fkey FOREIGN KEY (filed_by) REFERENCES core.users(id);


--
-- Name: decisions decisions_case_id_fkey; Type: FK CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.decisions
    ADD CONSTRAINT decisions_case_id_fkey FOREIGN KEY (case_id) REFERENCES discipline.cases(id) ON DELETE CASCADE;


--
-- Name: decisions decisions_decided_by_fkey; Type: FK CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.decisions
    ADD CONSTRAINT decisions_decided_by_fkey FOREIGN KEY (decided_by) REFERENCES core.users(id);


--
-- Name: formal_charges formal_charges_case_id_fkey; Type: FK CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.formal_charges
    ADD CONSTRAINT formal_charges_case_id_fkey FOREIGN KEY (case_id) REFERENCES discipline.cases(id) ON DELETE CASCADE;


--
-- Name: formal_charges formal_charges_issued_by_fkey; Type: FK CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.formal_charges
    ADD CONSTRAINT formal_charges_issued_by_fkey FOREIGN KEY (issued_by) REFERENCES core.users(id);


--
-- Name: hearings hearings_case_id_fkey; Type: FK CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.hearings
    ADD CONSTRAINT hearings_case_id_fkey FOREIGN KEY (case_id) REFERENCES discipline.cases(id) ON DELETE CASCADE;


--
-- Name: hearings hearings_presiding_officer_id_fkey; Type: FK CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.hearings
    ADD CONSTRAINT hearings_presiding_officer_id_fkey FOREIGN KEY (presiding_officer_id) REFERENCES core.users(id);


--
-- Name: investigations investigations_case_id_fkey; Type: FK CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.investigations
    ADD CONSTRAINT investigations_case_id_fkey FOREIGN KEY (case_id) REFERENCES discipline.cases(id) ON DELETE CASCADE;


--
-- Name: investigations investigations_investigator_id_fkey; Type: FK CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.investigations
    ADD CONSTRAINT investigations_investigator_id_fkey FOREIGN KEY (investigator_id) REFERENCES core.users(id);


--
-- Name: preventive_suspensions preventive_suspensions_approved_by_fkey; Type: FK CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.preventive_suspensions
    ADD CONSTRAINT preventive_suspensions_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES core.users(id);


--
-- Name: preventive_suspensions preventive_suspensions_case_id_fkey; Type: FK CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.preventive_suspensions
    ADD CONSTRAINT preventive_suspensions_case_id_fkey FOREIGN KEY (case_id) REFERENCES discipline.cases(id) ON DELETE CASCADE;


--
-- Name: preventive_suspensions preventive_suspensions_employee_id_fkey; Type: FK CONSTRAINT; Schema: discipline; Owner: hris_admin
--

ALTER TABLE ONLY discipline.preventive_suspensions
    ADD CONSTRAINT preventive_suspensions_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: certificate_requests certificate_requests_cert_type_id_fkey; Type: FK CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.certificate_requests
    ADD CONSTRAINT certificate_requests_cert_type_id_fkey FOREIGN KEY (cert_type_id) REFERENCES dms.certificate_types(id);


--
-- Name: certificate_requests certificate_requests_document_id_fkey; Type: FK CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.certificate_requests
    ADD CONSTRAINT certificate_requests_document_id_fkey FOREIGN KEY (document_id) REFERENCES core.documents(id);


--
-- Name: certificate_requests certificate_requests_employee_id_fkey; Type: FK CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.certificate_requests
    ADD CONSTRAINT certificate_requests_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: certificate_requests certificate_requests_processed_by_fkey; Type: FK CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.certificate_requests
    ADD CONSTRAINT certificate_requests_processed_by_fkey FOREIGN KEY (processed_by) REFERENCES core.users(id);


--
-- Name: certificate_requests certificate_requests_released_by_fkey; Type: FK CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.certificate_requests
    ADD CONSTRAINT certificate_requests_released_by_fkey FOREIGN KEY (released_by) REFERENCES core.users(id);


--
-- Name: checklist_items checklist_items_category_id_fkey; Type: FK CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.checklist_items
    ADD CONSTRAINT checklist_items_category_id_fkey FOREIGN KEY (category_id) REFERENCES dms.document_categories(id);


--
-- Name: checklist_items checklist_items_template_id_fkey; Type: FK CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.checklist_items
    ADD CONSTRAINT checklist_items_template_id_fkey FOREIGN KEY (template_id) REFERENCES dms.checklist_templates(id) ON DELETE CASCADE;


--
-- Name: checklist_templates checklist_templates_company_id_fkey; Type: FK CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.checklist_templates
    ADD CONSTRAINT checklist_templates_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: checklist_templates checklist_templates_employment_type_id_fkey; Type: FK CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.checklist_templates
    ADD CONSTRAINT checklist_templates_employment_type_id_fkey FOREIGN KEY (employment_type_id) REFERENCES core.employment_types(id);


--
-- Name: document_categories document_categories_company_id_fkey; Type: FK CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.document_categories
    ADD CONSTRAINT document_categories_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: document_categories document_categories_parent_id_fkey; Type: FK CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.document_categories
    ADD CONSTRAINT document_categories_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES dms.document_categories(id);


--
-- Name: document_requests document_requests_company_id_fkey; Type: FK CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.document_requests
    ADD CONSTRAINT document_requests_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: document_requests document_requests_employee_id_fkey; Type: FK CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.document_requests
    ADD CONSTRAINT document_requests_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: document_requests document_requests_fulfilled_doc_id_fkey; Type: FK CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.document_requests
    ADD CONSTRAINT document_requests_fulfilled_doc_id_fkey FOREIGN KEY (fulfilled_doc_id) REFERENCES core.documents(id);


--
-- Name: document_requests document_requests_requested_by_fkey; Type: FK CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.document_requests
    ADD CONSTRAINT document_requests_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES core.users(id);


--
-- Name: retention_policies retention_policies_category_id_fkey; Type: FK CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.retention_policies
    ADD CONSTRAINT retention_policies_category_id_fkey FOREIGN KEY (category_id) REFERENCES dms.document_categories(id);


--
-- Name: retention_policies retention_policies_company_id_fkey; Type: FK CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.retention_policies
    ADD CONSTRAINT retention_policies_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: service_record_snapshots service_record_snapshots_employee_id_fkey; Type: FK CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.service_record_snapshots
    ADD CONSTRAINT service_record_snapshots_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: service_record_snapshots service_record_snapshots_generated_by_fkey; Type: FK CONSTRAINT; Schema: dms; Owner: hris_admin
--

ALTER TABLE ONLY dms.service_record_snapshots
    ADD CONSTRAINT service_record_snapshots_generated_by_fkey FOREIGN KEY (generated_by) REFERENCES core.users(id);


--
-- Name: health_certificates health_certificates_document_id_fkey; Type: FK CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.health_certificates
    ADD CONSTRAINT health_certificates_document_id_fkey FOREIGN KEY (document_id) REFERENCES core.documents(id);


--
-- Name: health_certificates health_certificates_employee_id_fkey; Type: FK CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.health_certificates
    ADD CONSTRAINT health_certificates_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: incident_investigations incident_investigations_incident_id_fkey; Type: FK CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.incident_investigations
    ADD CONSTRAINT incident_investigations_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES health.incidents(id) ON DELETE CASCADE;


--
-- Name: incident_investigations incident_investigations_investigator_id_fkey; Type: FK CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.incident_investigations
    ADD CONSTRAINT incident_investigations_investigator_id_fkey FOREIGN KEY (investigator_id) REFERENCES core.users(id);


--
-- Name: incident_persons incident_persons_employee_id_fkey; Type: FK CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.incident_persons
    ADD CONSTRAINT incident_persons_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: incident_persons incident_persons_incident_id_fkey; Type: FK CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.incident_persons
    ADD CONSTRAINT incident_persons_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES health.incidents(id) ON DELETE CASCADE;


--
-- Name: incidents incidents_company_id_fkey; Type: FK CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.incidents
    ADD CONSTRAINT incidents_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: incidents incidents_reported_by_fkey; Type: FK CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.incidents
    ADD CONSTRAINT incidents_reported_by_fkey FOREIGN KEY (reported_by) REFERENCES core.users(id);


--
-- Name: medical_records medical_records_employee_id_fkey; Type: FK CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.medical_records
    ADD CONSTRAINT medical_records_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: medical_records medical_records_last_updated_by_fkey; Type: FK CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.medical_records
    ADD CONSTRAINT medical_records_last_updated_by_fkey FOREIGN KEY (last_updated_by) REFERENCES core.users(id);


--
-- Name: pe_results pe_results_employee_id_fkey; Type: FK CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.pe_results
    ADD CONSTRAINT pe_results_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: pe_results pe_results_result_document_id_fkey; Type: FK CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.pe_results
    ADD CONSTRAINT pe_results_result_document_id_fkey FOREIGN KEY (result_document_id) REFERENCES core.documents(id);


--
-- Name: pe_results pe_results_schedule_id_fkey; Type: FK CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.pe_results
    ADD CONSTRAINT pe_results_schedule_id_fkey FOREIGN KEY (schedule_id) REFERENCES health.pe_schedules(id);


--
-- Name: pe_schedules pe_schedules_company_id_fkey; Type: FK CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.pe_schedules
    ADD CONSTRAINT pe_schedules_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: pe_schedules pe_schedules_created_by_fkey; Type: FK CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.pe_schedules
    ADD CONSTRAINT pe_schedules_created_by_fkey FOREIGN KEY (created_by) REFERENCES core.users(id);


--
-- Name: wellness_enrollments wellness_enrollments_employee_id_fkey; Type: FK CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.wellness_enrollments
    ADD CONSTRAINT wellness_enrollments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: wellness_enrollments wellness_enrollments_program_id_fkey; Type: FK CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.wellness_enrollments
    ADD CONSTRAINT wellness_enrollments_program_id_fkey FOREIGN KEY (program_id) REFERENCES health.wellness_programs(id) ON DELETE CASCADE;


--
-- Name: wellness_programs wellness_programs_company_id_fkey; Type: FK CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.wellness_programs
    ADD CONSTRAINT wellness_programs_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: wellness_programs wellness_programs_created_by_fkey; Type: FK CONSTRAINT; Schema: health; Owner: hris_admin
--

ALTER TABLE ONLY health.wellness_programs
    ADD CONSTRAINT wellness_programs_created_by_fkey FOREIGN KEY (created_by) REFERENCES core.users(id);


--
-- Name: lrn_enrollments fk_enrollment_nrf; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_enrollments
    ADD CONSTRAINT fk_enrollment_nrf FOREIGN KEY (narrative_report_id) REFERENCES learning.lrn_narrative_reports(id);


--
-- Name: lrn_programs fk_program_lsp; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_programs
    ADD CONSTRAINT fk_program_lsp FOREIGN KEY (lsp_id) REFERENCES learning.lrn_lsp_registry(id);


--
-- Name: lrn_attendance_logs lrn_attendance_logs_employee_id_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_attendance_logs
    ADD CONSTRAINT lrn_attendance_logs_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: lrn_attendance_logs lrn_attendance_logs_enrollment_id_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_attendance_logs
    ADD CONSTRAINT lrn_attendance_logs_enrollment_id_fkey FOREIGN KEY (enrollment_id) REFERENCES learning.lrn_enrollments(id);


--
-- Name: lrn_attendance_logs lrn_attendance_logs_session_id_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_attendance_logs
    ADD CONSTRAINT lrn_attendance_logs_session_id_fkey FOREIGN KEY (session_id) REFERENCES learning.lrn_sessions(id);


--
-- Name: lrn_attendance_logs lrn_attendance_logs_verified_by_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_attendance_logs
    ADD CONSTRAINT lrn_attendance_logs_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES core.users(id);


--
-- Name: lrn_employee_skills lrn_employee_skills_assessed_by_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_employee_skills
    ADD CONSTRAINT lrn_employee_skills_assessed_by_fkey FOREIGN KEY (assessed_by) REFERENCES core.users(id);


--
-- Name: lrn_employee_skills lrn_employee_skills_employee_id_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_employee_skills
    ADD CONSTRAINT lrn_employee_skills_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: lrn_employee_skills lrn_employee_skills_skill_id_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_employee_skills
    ADD CONSTRAINT lrn_employee_skills_skill_id_fkey FOREIGN KEY (skill_id) REFERENCES learning.lrn_skills(id);


--
-- Name: lrn_enrollments lrn_enrollments_employee_id_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_enrollments
    ADD CONSTRAINT lrn_enrollments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: lrn_enrollments lrn_enrollments_session_id_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_enrollments
    ADD CONSTRAINT lrn_enrollments_session_id_fkey FOREIGN KEY (session_id) REFERENCES learning.lrn_sessions(id);


--
-- Name: lrn_idp_actions lrn_idp_actions_idp_plan_id_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_idp_actions
    ADD CONSTRAINT lrn_idp_actions_idp_plan_id_fkey FOREIGN KEY (idp_plan_id) REFERENCES performance.perf_idp_plans(id);


--
-- Name: lrn_idp_actions lrn_idp_actions_session_id_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_idp_actions
    ADD CONSTRAINT lrn_idp_actions_session_id_fkey FOREIGN KEY (session_id) REFERENCES learning.lrn_sessions(id);


--
-- Name: lrn_idp_actions lrn_idp_actions_tna_entry_id_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_idp_actions
    ADD CONSTRAINT lrn_idp_actions_tna_entry_id_fkey FOREIGN KEY (tna_entry_id) REFERENCES learning.lrn_tna_entries(id);


--
-- Name: lrn_lsp_registry lrn_lsp_registry_company_id_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_lsp_registry
    ADD CONSTRAINT lrn_lsp_registry_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: lrn_narrative_reports lrn_narrative_reports_approved_by_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_narrative_reports
    ADD CONSTRAINT lrn_narrative_reports_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES core.users(id);


--
-- Name: lrn_narrative_reports lrn_narrative_reports_employee_id_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_narrative_reports
    ADD CONSTRAINT lrn_narrative_reports_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: lrn_narrative_reports lrn_narrative_reports_enrollment_id_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_narrative_reports
    ADD CONSTRAINT lrn_narrative_reports_enrollment_id_fkey FOREIGN KEY (enrollment_id) REFERENCES learning.lrn_enrollments(id);


--
-- Name: lrn_programs lrn_programs_company_id_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_programs
    ADD CONSTRAINT lrn_programs_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: lrn_scholarships lrn_scholarships_approved_by_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_scholarships
    ADD CONSTRAINT lrn_scholarships_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES core.users(id);


--
-- Name: lrn_scholarships lrn_scholarships_employee_id_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_scholarships
    ADD CONSTRAINT lrn_scholarships_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: lrn_sessions lrn_sessions_program_id_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_sessions
    ADD CONSTRAINT lrn_sessions_program_id_fkey FOREIGN KEY (program_id) REFERENCES learning.lrn_programs(id);


--
-- Name: lrn_skills lrn_skills_company_id_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_skills
    ADD CONSTRAINT lrn_skills_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: lrn_tna_entries lrn_tna_entries_cycle_id_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_tna_entries
    ADD CONSTRAINT lrn_tna_entries_cycle_id_fkey FOREIGN KEY (cycle_id) REFERENCES performance.perf_cycles(id);


--
-- Name: lrn_tna_entries lrn_tna_entries_employee_id_fkey; Type: FK CONSTRAINT; Schema: learning; Owner: hris_admin
--

ALTER TABLE ONLY learning.lrn_tna_entries
    ADD CONSTRAINT lrn_tna_entries_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: lv_approvals lv_approvals_approver_id_fkey; Type: FK CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_approvals
    ADD CONSTRAINT lv_approvals_approver_id_fkey FOREIGN KEY (approver_id) REFERENCES core.employees(id);


--
-- Name: lv_approvals lv_approvals_request_id_fkey; Type: FK CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_approvals
    ADD CONSTRAINT lv_approvals_request_id_fkey FOREIGN KEY (request_id) REFERENCES leave_mgmt.lv_requests(id) ON DELETE CASCADE;


--
-- Name: lv_balance_adjustments lv_balance_adjustments_adjusted_by_fkey; Type: FK CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_balance_adjustments
    ADD CONSTRAINT lv_balance_adjustments_adjusted_by_fkey FOREIGN KEY (adjusted_by) REFERENCES core.users(id);


--
-- Name: lv_balance_adjustments lv_balance_adjustments_employee_id_fkey; Type: FK CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_balance_adjustments
    ADD CONSTRAINT lv_balance_adjustments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: lv_balance_adjustments lv_balance_adjustments_leave_type_id_fkey; Type: FK CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_balance_adjustments
    ADD CONSTRAINT lv_balance_adjustments_leave_type_id_fkey FOREIGN KEY (leave_type_id) REFERENCES leave_mgmt.lv_types(id);


--
-- Name: lv_balances lv_balances_employee_id_fkey; Type: FK CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_balances
    ADD CONSTRAINT lv_balances_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: lv_balances lv_balances_leave_type_id_fkey; Type: FK CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_balances
    ADD CONSTRAINT lv_balances_leave_type_id_fkey FOREIGN KEY (leave_type_id) REFERENCES leave_mgmt.lv_types(id);


--
-- Name: lv_cto_credits lv_cto_credits_approved_by_fkey; Type: FK CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_cto_credits
    ADD CONSTRAINT lv_cto_credits_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES core.users(id);


--
-- Name: lv_cto_credits lv_cto_credits_employee_id_fkey; Type: FK CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_cto_credits
    ADD CONSTRAINT lv_cto_credits_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: lv_holidays lv_holidays_company_id_fkey; Type: FK CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_holidays
    ADD CONSTRAINT lv_holidays_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: lv_ledger lv_ledger_created_by_fkey; Type: FK CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_ledger
    ADD CONSTRAINT lv_ledger_created_by_fkey FOREIGN KEY (created_by) REFERENCES core.users(id);


--
-- Name: lv_ledger lv_ledger_employee_id_fkey; Type: FK CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_ledger
    ADD CONSTRAINT lv_ledger_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: lv_ledger lv_ledger_leave_type_id_fkey; Type: FK CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_ledger
    ADD CONSTRAINT lv_ledger_leave_type_id_fkey FOREIGN KEY (leave_type_id) REFERENCES leave_mgmt.lv_types(id);


--
-- Name: lv_locator_entries lv_locator_entries_employee_id_fkey; Type: FK CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_locator_entries
    ADD CONSTRAINT lv_locator_entries_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: lv_policies lv_policies_company_id_fkey; Type: FK CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_policies
    ADD CONSTRAINT lv_policies_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: lv_policies lv_policies_employment_type_id_fkey; Type: FK CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_policies
    ADD CONSTRAINT lv_policies_employment_type_id_fkey FOREIGN KEY (employment_type_id) REFERENCES core.employment_types(id);


--
-- Name: lv_policies lv_policies_leave_type_id_fkey; Type: FK CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_policies
    ADD CONSTRAINT lv_policies_leave_type_id_fkey FOREIGN KEY (leave_type_id) REFERENCES leave_mgmt.lv_types(id);


--
-- Name: lv_requests lv_requests_employee_id_fkey; Type: FK CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_requests
    ADD CONSTRAINT lv_requests_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: lv_requests lv_requests_leave_type_id_fkey; Type: FK CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_requests
    ADD CONSTRAINT lv_requests_leave_type_id_fkey FOREIGN KEY (leave_type_id) REFERENCES leave_mgmt.lv_types(id);


--
-- Name: lv_travel_orders lv_travel_orders_approved_by_fkey; Type: FK CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_travel_orders
    ADD CONSTRAINT lv_travel_orders_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES core.users(id);


--
-- Name: lv_travel_orders lv_travel_orders_employee_id_fkey; Type: FK CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_travel_orders
    ADD CONSTRAINT lv_travel_orders_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: lv_types lv_types_company_id_fkey; Type: FK CONSTRAINT; Schema: leave_mgmt; Owner: hris_admin
--

ALTER TABLE ONLY leave_mgmt.lv_types
    ADD CONSTRAINT lv_types_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: ntf_in_app ntf_in_app_user_id_fkey; Type: FK CONSTRAINT; Schema: notifications; Owner: hris_admin
--

ALTER TABLE ONLY notifications.ntf_in_app
    ADD CONSTRAINT ntf_in_app_user_id_fkey FOREIGN KEY (user_id) REFERENCES core.users(id);


--
-- Name: ntf_queue ntf_queue_recipient_user_id_fkey; Type: FK CONSTRAINT; Schema: notifications; Owner: hris_admin
--

ALTER TABLE ONLY notifications.ntf_queue
    ADD CONSTRAINT ntf_queue_recipient_user_id_fkey FOREIGN KEY (recipient_user_id) REFERENCES core.users(id);


--
-- Name: ntf_queue ntf_queue_template_id_fkey; Type: FK CONSTRAINT; Schema: notifications; Owner: hris_admin
--

ALTER TABLE ONLY notifications.ntf_queue
    ADD CONSTRAINT ntf_queue_template_id_fkey FOREIGN KEY (template_id) REFERENCES notifications.ntf_templates(id);


--
-- Name: ntf_templates ntf_templates_channel_id_fkey; Type: FK CONSTRAINT; Schema: notifications; Owner: hris_admin
--

ALTER TABLE ONLY notifications.ntf_templates
    ADD CONSTRAINT ntf_templates_channel_id_fkey FOREIGN KEY (channel_id) REFERENCES notifications.ntf_channels(id);


--
-- Name: offb_clearance_items offb_clearance_items_cleared_by_fkey; Type: FK CONSTRAINT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.offb_clearance_items
    ADD CONSTRAINT offb_clearance_items_cleared_by_fkey FOREIGN KEY (cleared_by) REFERENCES core.users(id);


--
-- Name: offb_clearance_items offb_clearance_items_employee_id_fkey; Type: FK CONSTRAINT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.offb_clearance_items
    ADD CONSTRAINT offb_clearance_items_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: offb_exit_interviews offb_exit_interviews_employee_id_fkey; Type: FK CONSTRAINT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.offb_exit_interviews
    ADD CONSTRAINT offb_exit_interviews_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: offb_exit_interviews offb_exit_interviews_interviewer_id_fkey; Type: FK CONSTRAINT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.offb_exit_interviews
    ADD CONSTRAINT offb_exit_interviews_interviewer_id_fkey FOREIGN KEY (interviewer_id) REFERENCES core.users(id);


--
-- Name: onb_buddy_assignments onb_buddy_assignments_buddy_id_fkey; Type: FK CONSTRAINT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.onb_buddy_assignments
    ADD CONSTRAINT onb_buddy_assignments_buddy_id_fkey FOREIGN KEY (buddy_id) REFERENCES core.employees(id);


--
-- Name: onb_buddy_assignments onb_buddy_assignments_employee_id_fkey; Type: FK CONSTRAINT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.onb_buddy_assignments
    ADD CONSTRAINT onb_buddy_assignments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: onb_checklist_items onb_checklist_items_checklist_id_fkey; Type: FK CONSTRAINT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.onb_checklist_items
    ADD CONSTRAINT onb_checklist_items_checklist_id_fkey FOREIGN KEY (checklist_id) REFERENCES onboarding.onb_checklists(id) ON DELETE CASCADE;


--
-- Name: onb_checklist_items onb_checklist_items_completed_by_fkey; Type: FK CONSTRAINT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.onb_checklist_items
    ADD CONSTRAINT onb_checklist_items_completed_by_fkey FOREIGN KEY (completed_by) REFERENCES core.users(id);


--
-- Name: onb_checklists onb_checklists_employee_id_fkey; Type: FK CONSTRAINT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.onb_checklists
    ADD CONSTRAINT onb_checklists_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: onb_pre_employment_reqs onb_pre_employment_reqs_employee_id_fkey; Type: FK CONSTRAINT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.onb_pre_employment_reqs
    ADD CONSTRAINT onb_pre_employment_reqs_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: onb_pre_employment_reqs onb_pre_employment_reqs_verified_by_fkey; Type: FK CONSTRAINT; Schema: onboarding; Owner: hris_admin
--

ALTER TABLE ONLY onboarding.onb_pre_employment_reqs
    ADD CONSTRAINT onb_pre_employment_reqs_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES core.users(id);


--
-- Name: pay_13th_month pay_13th_month_employee_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_13th_month
    ADD CONSTRAINT pay_13th_month_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: pay_13th_month pay_13th_month_run_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_13th_month
    ADD CONSTRAINT pay_13th_month_run_id_fkey FOREIGN KEY (run_id) REFERENCES payroll.pay_runs(id);


--
-- Name: pay_adjustments pay_adjustments_applied_by_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_adjustments
    ADD CONSTRAINT pay_adjustments_applied_by_fkey FOREIGN KEY (applied_by) REFERENCES core.users(id);


--
-- Name: pay_adjustments pay_adjustments_employee_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_adjustments
    ADD CONSTRAINT pay_adjustments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: pay_adjustments pay_adjustments_run_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_adjustments
    ADD CONSTRAINT pay_adjustments_run_id_fkey FOREIGN KEY (run_id) REFERENCES payroll.pay_runs(id);


--
-- Name: pay_annual_bonuses pay_annual_bonuses_employee_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_annual_bonuses
    ADD CONSTRAINT pay_annual_bonuses_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: pay_annual_bonuses pay_annual_bonuses_pay_run_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_annual_bonuses
    ADD CONSTRAINT pay_annual_bonuses_pay_run_id_fkey FOREIGN KEY (pay_run_id) REFERENCES payroll.pay_runs(id);


--
-- Name: pay_annual_bonuses pay_annual_bonuses_released_by_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_annual_bonuses
    ADD CONSTRAINT pay_annual_bonuses_released_by_fkey FOREIGN KEY (released_by) REFERENCES core.users(id);


--
-- Name: pay_coop_members pay_coop_members_employee_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_coop_members
    ADD CONSTRAINT pay_coop_members_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: pay_employee_allowances pay_employee_allowances_employee_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_employee_allowances
    ADD CONSTRAINT pay_employee_allowances_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: pay_employee_allowances_gov pay_employee_allowances_gov_allowance_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_employee_allowances_gov
    ADD CONSTRAINT pay_employee_allowances_gov_allowance_id_fkey FOREIGN KEY (allowance_id) REFERENCES payroll.pay_gov_allowances(id);


--
-- Name: pay_employee_allowances_gov pay_employee_allowances_gov_approved_by_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_employee_allowances_gov
    ADD CONSTRAINT pay_employee_allowances_gov_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES core.users(id);


--
-- Name: pay_employee_allowances_gov pay_employee_allowances_gov_employee_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_employee_allowances_gov
    ADD CONSTRAINT pay_employee_allowances_gov_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: pay_employee_payroll pay_employee_payroll_employee_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_employee_payroll
    ADD CONSTRAINT pay_employee_payroll_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: pay_employee_payroll pay_employee_payroll_run_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_employee_payroll
    ADD CONSTRAINT pay_employee_payroll_run_id_fkey FOREIGN KEY (run_id) REFERENCES payroll.pay_runs(id);


--
-- Name: pay_gov_allowances pay_gov_allowances_company_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_gov_allowances
    ADD CONSTRAINT pay_gov_allowances_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: pay_government_remittances pay_government_remittances_run_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_government_remittances
    ADD CONSTRAINT pay_government_remittances_run_id_fkey FOREIGN KEY (run_id) REFERENCES payroll.pay_runs(id);


--
-- Name: pay_loan_payments pay_loan_payments_loan_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_loan_payments
    ADD CONSTRAINT pay_loan_payments_loan_id_fkey FOREIGN KEY (loan_id) REFERENCES payroll.pay_loans(id);


--
-- Name: pay_loan_payments pay_loan_payments_run_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_loan_payments
    ADD CONSTRAINT pay_loan_payments_run_id_fkey FOREIGN KEY (run_id) REFERENCES payroll.pay_runs(id);


--
-- Name: pay_loans pay_loans_approved_by_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_loans
    ADD CONSTRAINT pay_loans_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES core.users(id);


--
-- Name: pay_loans pay_loans_employee_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_loans
    ADD CONSTRAINT pay_loans_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: pay_periods pay_periods_company_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_periods
    ADD CONSTRAINT pay_periods_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: pay_rata_schedule pay_rata_schedule_position_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_rata_schedule
    ADD CONSTRAINT pay_rata_schedule_position_id_fkey FOREIGN KEY (position_id) REFERENCES core.positions(id);


--
-- Name: pay_runs pay_runs_approved_by_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_runs
    ADD CONSTRAINT pay_runs_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES core.users(id);


--
-- Name: pay_runs pay_runs_computed_by_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_runs
    ADD CONSTRAINT pay_runs_computed_by_fkey FOREIGN KEY (computed_by) REFERENCES core.users(id);


--
-- Name: pay_runs pay_runs_period_id_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_runs
    ADD CONSTRAINT pay_runs_period_id_fkey FOREIGN KEY (period_id) REFERENCES payroll.pay_periods(id);


--
-- Name: pay_runs pay_runs_posted_by_fkey; Type: FK CONSTRAINT; Schema: payroll; Owner: hris_admin
--

ALTER TABLE ONLY payroll.pay_runs
    ADD CONSTRAINT pay_runs_posted_by_fkey FOREIGN KEY (posted_by) REFERENCES core.users(id);


--
-- Name: perf_competencies perf_competencies_company_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_competencies
    ADD CONSTRAINT perf_competencies_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: perf_cycles perf_cycles_company_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_cycles
    ADD CONSTRAINT perf_cycles_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: perf_employee_kpis perf_employee_kpis_cycle_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_employee_kpis
    ADD CONSTRAINT perf_employee_kpis_cycle_id_fkey FOREIGN KEY (cycle_id) REFERENCES performance.perf_cycles(id);


--
-- Name: perf_employee_kpis perf_employee_kpis_employee_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_employee_kpis
    ADD CONSTRAINT perf_employee_kpis_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: perf_idp_plans perf_idp_plans_cycle_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_idp_plans
    ADD CONSTRAINT perf_idp_plans_cycle_id_fkey FOREIGN KEY (cycle_id) REFERENCES performance.perf_cycles(id);


--
-- Name: perf_idp_plans perf_idp_plans_employee_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_idp_plans
    ADD CONSTRAINT perf_idp_plans_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: perf_ipcr perf_ipcr_cycle_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_ipcr
    ADD CONSTRAINT perf_ipcr_cycle_id_fkey FOREIGN KEY (cycle_id) REFERENCES performance.perf_cycles(id);


--
-- Name: perf_ipcr perf_ipcr_employee_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_ipcr
    ADD CONSTRAINT perf_ipcr_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: perf_ipcr perf_ipcr_evaluator_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_ipcr
    ADD CONSTRAINT perf_ipcr_evaluator_id_fkey FOREIGN KEY (evaluator_id) REFERENCES core.employees(id);


--
-- Name: perf_ipcr perf_ipcr_opcr_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_ipcr
    ADD CONSTRAINT perf_ipcr_opcr_id_fkey FOREIGN KEY (opcr_id) REFERENCES performance.perf_opcr(id);


--
-- Name: perf_ipcr_summary perf_ipcr_summary_approved_by_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_ipcr_summary
    ADD CONSTRAINT perf_ipcr_summary_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES core.users(id);


--
-- Name: perf_ipcr_summary perf_ipcr_summary_cycle_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_ipcr_summary
    ADD CONSTRAINT perf_ipcr_summary_cycle_id_fkey FOREIGN KEY (cycle_id) REFERENCES performance.perf_cycles(id);


--
-- Name: perf_ipcr_summary perf_ipcr_summary_employee_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_ipcr_summary
    ADD CONSTRAINT perf_ipcr_summary_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: perf_opcr perf_opcr_company_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_opcr
    ADD CONSTRAINT perf_opcr_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: perf_opcr perf_opcr_cycle_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_opcr
    ADD CONSTRAINT perf_opcr_cycle_id_fkey FOREIGN KEY (cycle_id) REFERENCES performance.perf_cycles(id);


--
-- Name: perf_opcr perf_opcr_department_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_opcr
    ADD CONSTRAINT perf_opcr_department_id_fkey FOREIGN KEY (department_id) REFERENCES core.departments(id);


--
-- Name: perf_reviews perf_reviews_cycle_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_reviews
    ADD CONSTRAINT perf_reviews_cycle_id_fkey FOREIGN KEY (cycle_id) REFERENCES performance.perf_cycles(id);


--
-- Name: perf_reviews perf_reviews_employee_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_reviews
    ADD CONSTRAINT perf_reviews_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: perf_reviews perf_reviews_reviewer_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_reviews
    ADD CONSTRAINT perf_reviews_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES core.employees(id);


--
-- Name: perf_strategic_plans perf_strategic_plans_approved_by_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_strategic_plans
    ADD CONSTRAINT perf_strategic_plans_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES core.users(id);


--
-- Name: perf_strategic_plans perf_strategic_plans_company_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_strategic_plans
    ADD CONSTRAINT perf_strategic_plans_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: perf_strategic_plans perf_strategic_plans_created_by_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_strategic_plans
    ADD CONSTRAINT perf_strategic_plans_created_by_fkey FOREIGN KEY (created_by) REFERENCES core.users(id);


--
-- Name: perf_succession_matrix perf_succession_matrix_assessed_by_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_succession_matrix
    ADD CONSTRAINT perf_succession_matrix_assessed_by_fkey FOREIGN KEY (assessed_by) REFERENCES core.users(id);


--
-- Name: perf_succession_matrix perf_succession_matrix_cycle_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_succession_matrix
    ADD CONSTRAINT perf_succession_matrix_cycle_id_fkey FOREIGN KEY (cycle_id) REFERENCES performance.perf_cycles(id);


--
-- Name: perf_succession_matrix perf_succession_matrix_key_position_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_succession_matrix
    ADD CONSTRAINT perf_succession_matrix_key_position_id_fkey FOREIGN KEY (key_position_id) REFERENCES core.positions(id);


--
-- Name: perf_succession_matrix perf_succession_matrix_successor_employee_id_fkey; Type: FK CONSTRAINT; Schema: performance; Owner: hris_admin
--

ALTER TABLE ONLY performance.perf_succession_matrix
    ADD CONSTRAINT perf_succession_matrix_successor_employee_id_fkey FOREIGN KEY (successor_employee_id) REFERENCES core.employees(id);


--
-- Name: att_daily att_daily_holiday_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_daily
    ADD CONSTRAINT att_daily_holiday_id_fkey FOREIGN KEY (holiday_id) REFERENCES public.att_holidays(id);


--
-- Name: att_daily att_daily_shift_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_daily
    ADD CONSTRAINT att_daily_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES public.att_shifts(id);


--
-- Name: att_holidays att_holidays_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_holidays
    ADD CONSTRAINT att_holidays_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: att_holidays att_holidays_holiday_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_holidays
    ADD CONSTRAINT att_holidays_holiday_type_id_fkey FOREIGN KEY (holiday_type_id) REFERENCES public.att_holiday_types(id);


--
-- Name: att_shift_assignments att_shift_assignments_shift_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_shift_assignments
    ADD CONSTRAINT att_shift_assignments_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES public.att_shifts(id);


--
-- Name: att_shifts att_shifts_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_shifts
    ADD CONSTRAINT att_shifts_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: business_units business_units_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.business_units
    ADD CONSTRAINT business_units_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: business_units business_units_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.business_units
    ADD CONSTRAINT business_units_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.business_units(id);


--
-- Name: doc_employee_files doc_employee_files_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.doc_employee_files
    ADD CONSTRAINT doc_employee_files_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.doc_categories(id);


--
-- Name: doc_versions doc_versions_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.doc_versions
    ADD CONSTRAINT doc_versions_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.doc_employee_files(id);


--
-- Name: employee_documents employee_documents_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.employee_documents
    ADD CONSTRAINT employee_documents_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id);


--
-- Name: employees employees_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id);


--
-- Name: employees employees_position_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_position_id_fkey FOREIGN KEY (position_id) REFERENCES public.positions(id);


--
-- Name: employees employees_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.status_definitions(id);


--
-- Name: fact_attendance fact_attendance_date_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_attendance
    ADD CONSTRAINT fact_attendance_date_key_fkey FOREIGN KEY (date_key) REFERENCES public.dim_date(date_key);


--
-- Name: fact_attendance fact_attendance_employee_surrogate_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_attendance
    ADD CONSTRAINT fact_attendance_employee_surrogate_fkey FOREIGN KEY (employee_surrogate) REFERENCES public.dim_employee(surrogate_key);


--
-- Name: fact_leave fact_leave_employee_surrogate_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_leave
    ADD CONSTRAINT fact_leave_employee_surrogate_fkey FOREIGN KEY (employee_surrogate) REFERENCES public.dim_employee(surrogate_key);


--
-- Name: fact_leave fact_leave_filed_date_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_leave
    ADD CONSTRAINT fact_leave_filed_date_key_fkey FOREIGN KEY (filed_date_key) REFERENCES public.dim_date(date_key);


--
-- Name: fact_leave fact_leave_from_date_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_leave
    ADD CONSTRAINT fact_leave_from_date_key_fkey FOREIGN KEY (from_date_key) REFERENCES public.dim_date(date_key);


--
-- Name: fact_payroll fact_payroll_employee_surrogate_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_payroll
    ADD CONSTRAINT fact_payroll_employee_surrogate_fkey FOREIGN KEY (employee_surrogate) REFERENCES public.dim_employee(surrogate_key);


--
-- Name: fact_payroll fact_payroll_period_date_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_payroll
    ADD CONSTRAINT fact_payroll_period_date_key_fkey FOREIGN KEY (period_date_key) REFERENCES public.dim_date(date_key);


--
-- Name: fact_performance fact_performance_employee_surrogate_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_performance
    ADD CONSTRAINT fact_performance_employee_surrogate_fkey FOREIGN KEY (employee_surrogate) REFERENCES public.dim_employee(surrogate_key);


--
-- Name: fact_performance fact_performance_review_date_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_performance
    ADD CONSTRAINT fact_performance_review_date_key_fkey FOREIGN KEY (review_date_key) REFERENCES public.dim_date(date_key);


--
-- Name: fact_recruitment fact_recruitment_applied_date_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.fact_recruitment
    ADD CONSTRAINT fact_recruitment_applied_date_key_fkey FOREIGN KEY (applied_date_key) REFERENCES public.dim_date(date_key);


--
-- Name: att_daily fk_att_daily_leave; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.att_daily
    ADD CONSTRAINT fk_att_daily_leave FOREIGN KEY (leave_request_id) REFERENCES public.lv_requests(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: form_fields form_fields_dynamic_form_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.form_fields
    ADD CONSTRAINT form_fields_dynamic_form_id_fkey FOREIGN KEY (dynamic_form_id) REFERENCES public.dynamic_forms(id);


--
-- Name: instance_checklist_items instance_checklist_items_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.instance_checklist_items
    ADD CONSTRAINT instance_checklist_items_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.workflow_instances(id);


--
-- Name: instance_checklist_items instance_checklist_items_workflow_checklist_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.instance_checklist_items
    ADD CONSTRAINT instance_checklist_items_workflow_checklist_item_id_fkey FOREIGN KEY (workflow_checklist_item_id) REFERENCES public.workflow_checklist_items(id);


--
-- Name: job_grades job_grades_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.job_grades
    ADD CONSTRAINT job_grades_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: lv_approvals lv_approvals_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.lv_approvals
    ADD CONSTRAINT lv_approvals_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.lv_requests(id) ON DELETE CASCADE;


--
-- Name: lv_balances lv_balances_leave_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.lv_balances
    ADD CONSTRAINT lv_balances_leave_type_id_fkey FOREIGN KEY (leave_type_id) REFERENCES public.lv_types(id);


--
-- Name: lv_ledger lv_ledger_leave_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.lv_ledger
    ADD CONSTRAINT lv_ledger_leave_type_id_fkey FOREIGN KEY (leave_type_id) REFERENCES public.lv_types(id);


--
-- Name: lv_policies lv_policies_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.lv_policies
    ADD CONSTRAINT lv_policies_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: lv_policies lv_policies_employment_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.lv_policies
    ADD CONSTRAINT lv_policies_employment_type_id_fkey FOREIGN KEY (employment_type_id) REFERENCES public.employment_types(id);


--
-- Name: lv_policies lv_policies_leave_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.lv_policies
    ADD CONSTRAINT lv_policies_leave_type_id_fkey FOREIGN KEY (leave_type_id) REFERENCES public.lv_types(id);


--
-- Name: lv_requests lv_requests_leave_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.lv_requests
    ADD CONSTRAINT lv_requests_leave_type_id_fkey FOREIGN KEY (leave_type_id) REFERENCES public.lv_types(id);


--
-- Name: lv_types lv_types_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.lv_types
    ADD CONSTRAINT lv_types_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: ml_model_monitoring ml_model_monitoring_model_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ml_model_monitoring
    ADD CONSTRAINT ml_model_monitoring_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES public.ml_model_versions(id);


--
-- Name: ml_model_versions ml_model_versions_dataset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ml_model_versions
    ADD CONSTRAINT ml_model_versions_dataset_id_fkey FOREIGN KEY (dataset_id) REFERENCES public.ml_training_datasets(id);


--
-- Name: ml_model_versions ml_model_versions_model_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.ml_model_versions
    ADD CONSTRAINT ml_model_versions_model_id_fkey FOREIGN KEY (model_id) REFERENCES public.ml_models(id);


--
-- Name: ntf_notifications ntf_notifications_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE public.ntf_notifications
    ADD CONSTRAINT ntf_notifications_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.ntf_templates(id);


--
-- Name: orchestration_steps orchestration_steps_orchestration_flow_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.orchestration_steps
    ADD CONSTRAINT orchestration_steps_orchestration_flow_id_fkey FOREIGN KEY (orchestration_flow_id) REFERENCES public.orchestration_flows(id);


--
-- Name: pay_13th_month pay_13th_month_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_13th_month
    ADD CONSTRAINT pay_13th_month_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: pay_13th_month pay_13th_month_released_via_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_13th_month
    ADD CONSTRAINT pay_13th_month_released_via_run_id_fkey FOREIGN KEY (released_via_run_id) REFERENCES public.pay_runs(id);


--
-- Name: pay_deductions_detail pay_deductions_detail_payroll_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_deductions_detail
    ADD CONSTRAINT pay_deductions_detail_payroll_id_fkey FOREIGN KEY (payroll_id) REFERENCES public.pay_employee_payroll(id) ON DELETE CASCADE;


--
-- Name: pay_earnings_detail pay_earnings_detail_payroll_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_earnings_detail
    ADD CONSTRAINT pay_earnings_detail_payroll_id_fkey FOREIGN KEY (payroll_id) REFERENCES public.pay_employee_payroll(id) ON DELETE CASCADE;


--
-- Name: pay_employee_payroll pay_employee_payroll_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_employee_payroll
    ADD CONSTRAINT pay_employee_payroll_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.pay_runs(id);


--
-- Name: pay_periods pay_periods_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_periods
    ADD CONSTRAINT pay_periods_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: pay_runs pay_runs_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.pay_runs
    ADD CONSTRAINT pay_runs_period_id_fkey FOREIGN KEY (period_id) REFERENCES public.pay_periods(id);


--
-- Name: perf_cycles perf_cycles_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_cycles
    ADD CONSTRAINT perf_cycles_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: perf_employee_kpis perf_employee_kpis_cycle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_employee_kpis
    ADD CONSTRAINT perf_employee_kpis_cycle_id_fkey FOREIGN KEY (cycle_id) REFERENCES public.perf_cycles(id);


--
-- Name: perf_employee_kpis perf_employee_kpis_kpi_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_employee_kpis
    ADD CONSTRAINT perf_employee_kpis_kpi_id_fkey FOREIGN KEY (kpi_id) REFERENCES public.perf_kpis(id);


--
-- Name: perf_kpi_categories perf_kpi_categories_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_kpi_categories
    ADD CONSTRAINT perf_kpi_categories_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: perf_kpis perf_kpis_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_kpis
    ADD CONSTRAINT perf_kpis_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.perf_kpi_categories(id);


--
-- Name: perf_kpis perf_kpis_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_kpis
    ADD CONSTRAINT perf_kpis_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: perf_review_feedback perf_review_feedback_review_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_review_feedback
    ADD CONSTRAINT perf_review_feedback_review_id_fkey FOREIGN KEY (review_id) REFERENCES public.perf_reviews(id) ON DELETE CASCADE;


--
-- Name: perf_review_ratings perf_review_ratings_kpi_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_review_ratings
    ADD CONSTRAINT perf_review_ratings_kpi_id_fkey FOREIGN KEY (kpi_id) REFERENCES public.perf_kpis(id);


--
-- Name: perf_review_ratings perf_review_ratings_review_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_review_ratings
    ADD CONSTRAINT perf_review_ratings_review_id_fkey FOREIGN KEY (review_id) REFERENCES public.perf_reviews(id) ON DELETE CASCADE;


--
-- Name: perf_reviews perf_reviews_cycle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.perf_reviews
    ADD CONSTRAINT perf_reviews_cycle_id_fkey FOREIGN KEY (cycle_id) REFERENCES public.perf_cycles(id);


--
-- Name: rec_applicants rec_applicants_posting_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.rec_applicants
    ADD CONSTRAINT rec_applicants_posting_id_fkey FOREIGN KEY (posting_id) REFERENCES public.rec_job_postings(id);


--
-- Name: rec_application_history rec_application_history_applicant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.rec_application_history
    ADD CONSTRAINT rec_application_history_applicant_id_fkey FOREIGN KEY (applicant_id) REFERENCES public.rec_applicants(id);


--
-- Name: rec_job_postings rec_job_postings_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.rec_job_postings
    ADD CONSTRAINT rec_job_postings_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: rec_job_postings rec_job_postings_employment_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.rec_job_postings
    ADD CONSTRAINT rec_job_postings_employment_type_id_fkey FOREIGN KEY (employment_type_id) REFERENCES public.employment_types(id);


--
-- Name: role_permissions role_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES public.permissions(id) ON DELETE CASCADE;


--
-- Name: role_permissions role_permissions_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: roles roles_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: sys_audit_logs sys_audit_logs_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE public.sys_audit_logs
    ADD CONSTRAINT sys_audit_logs_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: sys_compliance_reports sys_compliance_reports_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_compliance_reports
    ADD CONSTRAINT sys_compliance_reports_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: sys_regulatory_deadlines sys_regulatory_deadlines_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_regulatory_deadlines
    ADD CONSTRAINT sys_regulatory_deadlines_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: sys_sync_logs sys_sync_logs_integration_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.sys_sync_logs
    ADD CONSTRAINT sys_sync_logs_integration_id_fkey FOREIGN KEY (integration_id) REFERENCES public.sys_integrations(id);


--
-- Name: transaction_qr_tokens transaction_qr_tokens_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.transaction_qr_tokens
    ADD CONSTRAINT transaction_qr_tokens_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transaction_registry(id);


--
-- Name: transaction_registry transaction_registry_current_step_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.transaction_registry
    ADD CONSTRAINT transaction_registry_current_step_id_fkey FOREIGN KEY (current_step_id) REFERENCES public.workflow_steps(id);


--
-- Name: transaction_registry transaction_registry_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.transaction_registry
    ADD CONSTRAINT transaction_registry_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.status_definitions(id);


--
-- Name: transaction_timeline transaction_timeline_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.transaction_timeline
    ADD CONSTRAINT transaction_timeline_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transaction_registry(id);


--
-- Name: trn_enrollments trn_enrollments_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.trn_enrollments
    ADD CONSTRAINT trn_enrollments_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.trn_sessions(id);


--
-- Name: trn_programs trn_programs_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.trn_programs
    ADD CONSTRAINT trn_programs_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: trn_sessions trn_sessions_program_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.trn_sessions
    ADD CONSTRAINT trn_sessions_program_id_fkey FOREIGN KEY (program_id) REFERENCES public.trn_programs(id);


--
-- Name: user_roles user_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: workflow_action_logs workflow_action_logs_instance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_action_logs
    ADD CONSTRAINT workflow_action_logs_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES public.workflow_instances(id);


--
-- Name: workflow_checklist_items workflow_checklist_items_workflow_checklist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_checklist_items
    ADD CONSTRAINT workflow_checklist_items_workflow_checklist_id_fkey FOREIGN KEY (workflow_checklist_id) REFERENCES public.workflow_checklists(id);


--
-- Name: workflow_checklists workflow_checklists_workflow_step_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_checklists
    ADD CONSTRAINT workflow_checklists_workflow_step_id_fkey FOREIGN KEY (workflow_step_id) REFERENCES public.workflow_steps(id);


--
-- Name: workflow_instances workflow_instances_current_step_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_instances
    ADD CONSTRAINT workflow_instances_current_step_id_fkey FOREIGN KEY (current_step_id) REFERENCES public.workflow_steps(id);


--
-- Name: workflow_instances workflow_instances_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_instances
    ADD CONSTRAINT workflow_instances_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.status_definitions(id);


--
-- Name: workflow_instances workflow_instances_workflow_definition_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_instances
    ADD CONSTRAINT workflow_instances_workflow_definition_id_fkey FOREIGN KEY (workflow_definition_id) REFERENCES public.workflow_definitions(id);


--
-- Name: workflow_routes workflow_routes_from_step_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_routes
    ADD CONSTRAINT workflow_routes_from_step_id_fkey FOREIGN KEY (from_step_id) REFERENCES public.workflow_steps(id);


--
-- Name: workflow_routes workflow_routes_to_step_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_routes
    ADD CONSTRAINT workflow_routes_to_step_id_fkey FOREIGN KEY (to_step_id) REFERENCES public.workflow_steps(id);


--
-- Name: workflow_steps workflow_steps_workflow_definition_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hris_admin
--

ALTER TABLE ONLY public.workflow_steps
    ADD CONSTRAINT workflow_steps_workflow_definition_id_fkey FOREIGN KEY (workflow_definition_id) REFERENCES public.workflow_definitions(id);


--
-- Name: rec_applicants rec_applicants_hired_as_employee_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_applicants
    ADD CONSTRAINT rec_applicants_hired_as_employee_id_fkey FOREIGN KEY (hired_as_employee_id) REFERENCES core.employees(id);


--
-- Name: rec_applicants rec_applicants_posting_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_applicants
    ADD CONSTRAINT rec_applicants_posting_id_fkey FOREIGN KEY (posting_id) REFERENCES recruitment.rec_job_postings(id);


--
-- Name: rec_appointments rec_appointments_approved_by_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_appointments
    ADD CONSTRAINT rec_appointments_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES core.users(id);


--
-- Name: rec_appointments rec_appointments_employee_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_appointments
    ADD CONSTRAINT rec_appointments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: rec_appointments rec_appointments_issued_by_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_appointments
    ADD CONSTRAINT rec_appointments_issued_by_fkey FOREIGN KEY (issued_by) REFERENCES core.users(id);


--
-- Name: rec_appointments rec_appointments_plantilla_item_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_appointments
    ADD CONSTRAINT rec_appointments_plantilla_item_id_fkey FOREIGN KEY (plantilla_item_id) REFERENCES recruitment.rec_plantilla_items(id);


--
-- Name: rec_appointments rec_appointments_position_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_appointments
    ADD CONSTRAINT rec_appointments_position_id_fkey FOREIGN KEY (position_id) REFERENCES core.positions(id);


--
-- Name: rec_employee_eligibilities rec_employee_eligibilities_eligibility_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_employee_eligibilities
    ADD CONSTRAINT rec_employee_eligibilities_eligibility_id_fkey FOREIGN KEY (eligibility_id) REFERENCES recruitment.rec_csc_eligibilities(id);


--
-- Name: rec_employee_eligibilities rec_employee_eligibilities_employee_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_employee_eligibilities
    ADD CONSTRAINT rec_employee_eligibilities_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: rec_employee_eligibilities rec_employee_eligibilities_verified_by_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_employee_eligibilities
    ADD CONSTRAINT rec_employee_eligibilities_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES core.users(id);


--
-- Name: rec_interview_schedules rec_interview_schedules_applicant_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_interview_schedules
    ADD CONSTRAINT rec_interview_schedules_applicant_id_fkey FOREIGN KEY (applicant_id) REFERENCES recruitment.rec_applicants(id);


--
-- Name: rec_interview_schedules rec_interview_schedules_interviewer_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_interview_schedules
    ADD CONSTRAINT rec_interview_schedules_interviewer_id_fkey FOREIGN KEY (interviewer_id) REFERENCES core.users(id);


--
-- Name: rec_job_postings rec_job_postings_requisition_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_job_postings
    ADD CONSTRAINT rec_job_postings_requisition_id_fkey FOREIGN KEY (requisition_id) REFERENCES recruitment.rec_requisitions(id);


--
-- Name: rec_next_in_rank_list rec_next_in_rank_list_assessed_by_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_next_in_rank_list
    ADD CONSTRAINT rec_next_in_rank_list_assessed_by_fkey FOREIGN KEY (assessed_by) REFERENCES core.users(id);


--
-- Name: rec_next_in_rank_list rec_next_in_rank_list_employee_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_next_in_rank_list
    ADD CONSTRAINT rec_next_in_rank_list_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: rec_next_in_rank_list rec_next_in_rank_list_position_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_next_in_rank_list
    ADD CONSTRAINT rec_next_in_rank_list_position_id_fkey FOREIGN KEY (position_id) REFERENCES core.positions(id);


--
-- Name: rec_offers rec_offers_applicant_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_offers
    ADD CONSTRAINT rec_offers_applicant_id_fkey FOREIGN KEY (applicant_id) REFERENCES recruitment.rec_applicants(id);


--
-- Name: rec_offers rec_offers_position_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_offers
    ADD CONSTRAINT rec_offers_position_id_fkey FOREIGN KEY (position_id) REFERENCES core.positions(id);


--
-- Name: rec_plantilla_items rec_plantilla_items_company_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_plantilla_items
    ADD CONSTRAINT rec_plantilla_items_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: rec_plantilla_items rec_plantilla_items_department_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_plantilla_items
    ADD CONSTRAINT rec_plantilla_items_department_id_fkey FOREIGN KEY (department_id) REFERENCES core.departments(id);


--
-- Name: rec_plantilla_items rec_plantilla_items_filled_by_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_plantilla_items
    ADD CONSTRAINT rec_plantilla_items_filled_by_fkey FOREIGN KEY (filled_by) REFERENCES core.employees(id);


--
-- Name: rec_plantilla_items rec_plantilla_items_position_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_plantilla_items
    ADD CONSTRAINT rec_plantilla_items_position_id_fkey FOREIGN KEY (position_id) REFERENCES core.positions(id);


--
-- Name: rec_psb_deliberations rec_psb_deliberations_chairperson_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_psb_deliberations
    ADD CONSTRAINT rec_psb_deliberations_chairperson_id_fkey FOREIGN KEY (chairperson_id) REFERENCES core.employees(id);


--
-- Name: rec_psb_deliberations rec_psb_deliberations_created_by_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_psb_deliberations
    ADD CONSTRAINT rec_psb_deliberations_created_by_fkey FOREIGN KEY (created_by) REFERENCES core.users(id);


--
-- Name: rec_psb_deliberations rec_psb_deliberations_requisition_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_psb_deliberations
    ADD CONSTRAINT rec_psb_deliberations_requisition_id_fkey FOREIGN KEY (requisition_id) REFERENCES recruitment.rec_requisitions(id);


--
-- Name: rec_psb_members rec_psb_members_company_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_psb_members
    ADD CONSTRAINT rec_psb_members_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: rec_psb_members rec_psb_members_member_employee_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_psb_members
    ADD CONSTRAINT rec_psb_members_member_employee_id_fkey FOREIGN KEY (member_employee_id) REFERENCES core.employees(id);


--
-- Name: rec_psb_scores rec_psb_scores_applicant_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_psb_scores
    ADD CONSTRAINT rec_psb_scores_applicant_id_fkey FOREIGN KEY (applicant_id) REFERENCES recruitment.rec_applicants(id);


--
-- Name: rec_psb_scores rec_psb_scores_deliberation_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_psb_scores
    ADD CONSTRAINT rec_psb_scores_deliberation_id_fkey FOREIGN KEY (deliberation_id) REFERENCES recruitment.rec_psb_deliberations(id);


--
-- Name: rec_psb_scores rec_psb_scores_scored_by_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_psb_scores
    ADD CONSTRAINT rec_psb_scores_scored_by_fkey FOREIGN KEY (scored_by) REFERENCES core.users(id);


--
-- Name: rec_publications rec_publications_posting_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_publications
    ADD CONSTRAINT rec_publications_posting_id_fkey FOREIGN KEY (posting_id) REFERENCES recruitment.rec_job_postings(id);


--
-- Name: rec_publications rec_publications_published_by_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_publications
    ADD CONSTRAINT rec_publications_published_by_fkey FOREIGN KEY (published_by) REFERENCES core.users(id);


--
-- Name: rec_publications rec_publications_requisition_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_publications
    ADD CONSTRAINT rec_publications_requisition_id_fkey FOREIGN KEY (requisition_id) REFERENCES recruitment.rec_requisitions(id);


--
-- Name: rec_qualification_standards rec_qualification_standards_created_by_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_qualification_standards
    ADD CONSTRAINT rec_qualification_standards_created_by_fkey FOREIGN KEY (created_by) REFERENCES core.users(id);


--
-- Name: rec_qualification_standards rec_qualification_standards_position_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_qualification_standards
    ADD CONSTRAINT rec_qualification_standards_position_id_fkey FOREIGN KEY (position_id) REFERENCES core.positions(id);


--
-- Name: rec_requisitions rec_requisitions_approved_by_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_requisitions
    ADD CONSTRAINT rec_requisitions_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES core.users(id);


--
-- Name: rec_requisitions rec_requisitions_company_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_requisitions
    ADD CONSTRAINT rec_requisitions_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: rec_requisitions rec_requisitions_department_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_requisitions
    ADD CONSTRAINT rec_requisitions_department_id_fkey FOREIGN KEY (department_id) REFERENCES core.departments(id);


--
-- Name: rec_requisitions rec_requisitions_position_id_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_requisitions
    ADD CONSTRAINT rec_requisitions_position_id_fkey FOREIGN KEY (position_id) REFERENCES core.positions(id);


--
-- Name: rec_requisitions rec_requisitions_requested_by_fkey; Type: FK CONSTRAINT; Schema: recruitment; Owner: hris_admin
--

ALTER TABLE ONLY recruitment.rec_requisitions
    ADD CONSTRAINT rec_requisitions_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES core.users(id);


--
-- Name: rwd_awards rwd_awards_category_id_fkey; Type: FK CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_awards
    ADD CONSTRAINT rwd_awards_category_id_fkey FOREIGN KEY (category_id) REFERENCES rewards.rwd_categories(id);


--
-- Name: rwd_awards rwd_awards_employee_id_fkey; Type: FK CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_awards
    ADD CONSTRAINT rwd_awards_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: rwd_awards rwd_awards_nomination_id_fkey; Type: FK CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_awards
    ADD CONSTRAINT rwd_awards_nomination_id_fkey FOREIGN KEY (nomination_id) REFERENCES rewards.rwd_nominations(id);


--
-- Name: rwd_categories rwd_categories_company_id_fkey; Type: FK CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_categories
    ADD CONSTRAINT rwd_categories_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: rwd_loyalty_milestones rwd_loyalty_milestones_awarded_by_fkey; Type: FK CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_loyalty_milestones
    ADD CONSTRAINT rwd_loyalty_milestones_awarded_by_fkey FOREIGN KEY (awarded_by) REFERENCES core.users(id);


--
-- Name: rwd_loyalty_milestones rwd_loyalty_milestones_employee_id_fkey; Type: FK CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_loyalty_milestones
    ADD CONSTRAINT rwd_loyalty_milestones_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: rwd_nominations rwd_nominations_category_id_fkey; Type: FK CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_nominations
    ADD CONSTRAINT rwd_nominations_category_id_fkey FOREIGN KEY (category_id) REFERENCES rewards.rwd_categories(id);


--
-- Name: rwd_nominations rwd_nominations_nominated_by_fkey; Type: FK CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_nominations
    ADD CONSTRAINT rwd_nominations_nominated_by_fkey FOREIGN KEY (nominated_by) REFERENCES core.users(id);


--
-- Name: rwd_nominations rwd_nominations_nominee_employee_id_fkey; Type: FK CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_nominations
    ADD CONSTRAINT rwd_nominations_nominee_employee_id_fkey FOREIGN KEY (nominee_employee_id) REFERENCES core.employees(id);


--
-- Name: rwd_pbb_records rwd_pbb_records_employee_id_fkey; Type: FK CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_pbb_records
    ADD CONSTRAINT rwd_pbb_records_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: rwd_pbb_records rwd_pbb_records_ipcr_summary_id_fkey; Type: FK CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_pbb_records
    ADD CONSTRAINT rwd_pbb_records_ipcr_summary_id_fkey FOREIGN KEY (ipcr_summary_id) REFERENCES performance.perf_ipcr_summary(id);


--
-- Name: rwd_pbb_records rwd_pbb_records_released_by_fkey; Type: FK CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_pbb_records
    ADD CONSTRAINT rwd_pbb_records_released_by_fkey FOREIGN KEY (released_by) REFERENCES core.users(id);


--
-- Name: rwd_praise_config rwd_praise_config_company_id_fkey; Type: FK CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_praise_config
    ADD CONSTRAINT rwd_praise_config_company_id_fkey FOREIGN KEY (company_id) REFERENCES core.companies(id);


--
-- Name: rwd_praise_config rwd_praise_config_created_by_fkey; Type: FK CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_praise_config
    ADD CONSTRAINT rwd_praise_config_created_by_fkey FOREIGN KEY (created_by) REFERENCES core.users(id);


--
-- Name: rwd_retirement_alerts rwd_retirement_alerts_employee_id_fkey; Type: FK CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_retirement_alerts
    ADD CONSTRAINT rwd_retirement_alerts_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: rwd_retirement_plans rwd_retirement_plans_employee_id_fkey; Type: FK CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_retirement_plans
    ADD CONSTRAINT rwd_retirement_plans_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: rwd_retirement_plans rwd_retirement_plans_updated_by_fkey; Type: FK CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_retirement_plans
    ADD CONSTRAINT rwd_retirement_plans_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES core.users(id);


--
-- Name: rwd_step_increments rwd_step_increments_employee_id_fkey; Type: FK CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_step_increments
    ADD CONSTRAINT rwd_step_increments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES core.employees(id);


--
-- Name: rwd_step_increments rwd_step_increments_ipcr_summary_id_fkey; Type: FK CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_step_increments
    ADD CONSTRAINT rwd_step_increments_ipcr_summary_id_fkey FOREIGN KEY (ipcr_summary_id) REFERENCES performance.perf_ipcr_summary(id);


--
-- Name: rwd_step_increments rwd_step_increments_processed_by_fkey; Type: FK CONSTRAINT; Schema: rewards; Owner: hris_admin
--

ALTER TABLE ONLY rewards.rwd_step_increments
    ADD CONSTRAINT rwd_step_increments_processed_by_fkey FOREIGN KEY (processed_by) REFERENCES core.users(id);


--
-- Name: instance_checklist_items instance_checklist_items_checklist_id_fkey; Type: FK CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.instance_checklist_items
    ADD CONSTRAINT instance_checklist_items_checklist_id_fkey FOREIGN KEY (checklist_id) REFERENCES workflow.workflow_checklists(id);


--
-- Name: instance_checklist_items instance_checklist_items_completed_by_fkey; Type: FK CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.instance_checklist_items
    ADD CONSTRAINT instance_checklist_items_completed_by_fkey FOREIGN KEY (completed_by) REFERENCES core.users(id);


--
-- Name: instance_checklist_items instance_checklist_items_instance_id_fkey; Type: FK CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.instance_checklist_items
    ADD CONSTRAINT instance_checklist_items_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES workflow.workflow_instances(id) ON DELETE CASCADE;


--
-- Name: workflow_action_logs workflow_action_logs_instance_id_fkey; Type: FK CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_action_logs
    ADD CONSTRAINT workflow_action_logs_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES workflow.workflow_instances(id) ON DELETE CASCADE;


--
-- Name: workflow_action_logs workflow_action_logs_performed_by_fkey; Type: FK CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_action_logs
    ADD CONSTRAINT workflow_action_logs_performed_by_fkey FOREIGN KEY (performed_by) REFERENCES core.users(id);


--
-- Name: workflow_action_logs workflow_action_logs_step_id_fkey; Type: FK CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_action_logs
    ADD CONSTRAINT workflow_action_logs_step_id_fkey FOREIGN KEY (step_id) REFERENCES workflow.workflow_steps(id);


--
-- Name: workflow_checklists workflow_checklists_step_id_fkey; Type: FK CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_checklists
    ADD CONSTRAINT workflow_checklists_step_id_fkey FOREIGN KEY (step_id) REFERENCES workflow.workflow_steps(id) ON DELETE CASCADE;


--
-- Name: workflow_event_hooks workflow_event_hooks_definition_id_fkey; Type: FK CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_event_hooks
    ADD CONSTRAINT workflow_event_hooks_definition_id_fkey FOREIGN KEY (definition_id) REFERENCES workflow.workflow_definitions(id) ON DELETE CASCADE;


--
-- Name: workflow_instances workflow_instances_current_step_id_fkey; Type: FK CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_instances
    ADD CONSTRAINT workflow_instances_current_step_id_fkey FOREIGN KEY (current_step_id) REFERENCES workflow.workflow_steps(id);


--
-- Name: workflow_instances workflow_instances_definition_id_fkey; Type: FK CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_instances
    ADD CONSTRAINT workflow_instances_definition_id_fkey FOREIGN KEY (definition_id) REFERENCES workflow.workflow_definitions(id);


--
-- Name: workflow_instances workflow_instances_initiated_by_fkey; Type: FK CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_instances
    ADD CONSTRAINT workflow_instances_initiated_by_fkey FOREIGN KEY (initiated_by) REFERENCES core.users(id);


--
-- Name: workflow_routes workflow_routes_next_step_id_fkey; Type: FK CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_routes
    ADD CONSTRAINT workflow_routes_next_step_id_fkey FOREIGN KEY (next_step_id) REFERENCES workflow.workflow_steps(id);


--
-- Name: workflow_routes workflow_routes_step_id_fkey; Type: FK CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_routes
    ADD CONSTRAINT workflow_routes_step_id_fkey FOREIGN KEY (step_id) REFERENCES workflow.workflow_steps(id) ON DELETE CASCADE;


--
-- Name: workflow_steps workflow_steps_workflow_id_fkey; Type: FK CONSTRAINT; Schema: workflow; Owner: hris_admin
--

ALTER TABLE ONLY workflow.workflow_steps
    ADD CONSTRAINT workflow_steps_workflow_id_fkey FOREIGN KEY (workflow_id) REFERENCES workflow.workflow_definitions(id) ON DELETE CASCADE;


--
-- Name: SCHEMA ai; Type: ACL; Schema: -; Owner: hris_admin
--

GRANT USAGE ON SCHEMA ai TO PUBLIC;


--
-- Name: SCHEMA analytics; Type: ACL; Schema: -; Owner: hris_admin
--

GRANT USAGE ON SCHEMA analytics TO PUBLIC;


--
-- Name: SCHEMA attendance; Type: ACL; Schema: -; Owner: hris_admin
--

GRANT USAGE ON SCHEMA attendance TO PUBLIC;


--
-- Name: SCHEMA audit_logs; Type: ACL; Schema: -; Owner: hris_admin
--

GRANT USAGE ON SCHEMA audit_logs TO PUBLIC;


--
-- Name: SCHEMA core; Type: ACL; Schema: -; Owner: hris_admin
--

GRANT USAGE ON SCHEMA core TO PUBLIC;


--
-- Name: SCHEMA learning; Type: ACL; Schema: -; Owner: hris_admin
--

GRANT USAGE ON SCHEMA learning TO PUBLIC;


--
-- Name: SCHEMA leave_mgmt; Type: ACL; Schema: -; Owner: hris_admin
--

GRANT USAGE ON SCHEMA leave_mgmt TO PUBLIC;


--
-- Name: SCHEMA notifications; Type: ACL; Schema: -; Owner: hris_admin
--

GRANT USAGE ON SCHEMA notifications TO PUBLIC;


--
-- Name: SCHEMA onboarding; Type: ACL; Schema: -; Owner: hris_admin
--

GRANT USAGE ON SCHEMA onboarding TO PUBLIC;


--
-- Name: SCHEMA payroll; Type: ACL; Schema: -; Owner: hris_admin
--

GRANT USAGE ON SCHEMA payroll TO PUBLIC;


--
-- Name: SCHEMA performance; Type: ACL; Schema: -; Owner: hris_admin
--

GRANT USAGE ON SCHEMA performance TO PUBLIC;


--
-- Name: SCHEMA recruitment; Type: ACL; Schema: -; Owner: hris_admin
--

GRANT USAGE ON SCHEMA recruitment TO PUBLIC;


--
-- Name: SCHEMA rewards; Type: ACL; Schema: -; Owner: hris_admin
--

GRANT USAGE ON SCHEMA rewards TO PUBLIC;


--
-- Name: SCHEMA workflow; Type: ACL; Schema: -; Owner: hris_admin
--

GRANT USAGE ON SCHEMA workflow TO PUBLIC;


--
-- Name: TABLE ai_feature_store; Type: ACL; Schema: ai; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ai.ai_feature_store TO PUBLIC;


--
-- Name: SEQUENCE ai_feature_store_id_seq; Type: ACL; Schema: ai; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE ai.ai_feature_store_id_seq TO PUBLIC;


--
-- Name: TABLE ai_insight_results; Type: ACL; Schema: ai; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ai.ai_insight_results TO PUBLIC;


--
-- Name: SEQUENCE ai_insight_results_id_seq; Type: ACL; Schema: ai; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE ai.ai_insight_results_id_seq TO PUBLIC;


--
-- Name: TABLE ai_messages; Type: ACL; Schema: ai; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ai.ai_messages TO PUBLIC;


--
-- Name: SEQUENCE ai_messages_id_seq; Type: ACL; Schema: ai; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE ai.ai_messages_id_seq TO PUBLIC;


--
-- Name: TABLE ai_persona_configs; Type: ACL; Schema: ai; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ai.ai_persona_configs TO PUBLIC;


--
-- Name: SEQUENCE ai_persona_configs_id_seq; Type: ACL; Schema: ai; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE ai.ai_persona_configs_id_seq TO PUBLIC;


--
-- Name: TABLE ai_recommendations; Type: ACL; Schema: ai; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ai.ai_recommendations TO PUBLIC;


--
-- Name: SEQUENCE ai_recommendations_id_seq; Type: ACL; Schema: ai; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE ai.ai_recommendations_id_seq TO PUBLIC;


--
-- Name: TABLE ai_risk_scores; Type: ACL; Schema: ai; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ai.ai_risk_scores TO PUBLIC;


--
-- Name: SEQUENCE ai_risk_scores_id_seq; Type: ACL; Schema: ai; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE ai.ai_risk_scores_id_seq TO PUBLIC;


--
-- Name: TABLE ai_sessions; Type: ACL; Schema: ai; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ai.ai_sessions TO PUBLIC;


--
-- Name: SEQUENCE ai_sessions_id_seq; Type: ACL; Schema: ai; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE ai.ai_sessions_id_seq TO PUBLIC;


--
-- Name: TABLE ai_tool_call_logs; Type: ACL; Schema: ai; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ai.ai_tool_call_logs TO PUBLIC;


--
-- Name: SEQUENCE ai_tool_call_logs_id_seq; Type: ACL; Schema: ai; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE ai.ai_tool_call_logs_id_seq TO PUBLIC;


--
-- Name: TABLE dim_date; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE analytics.dim_date TO PUBLIC;


--
-- Name: TABLE dim_department; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE analytics.dim_department TO PUBLIC;


--
-- Name: SEQUENCE dim_department_surrogate_key_seq; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE analytics.dim_department_surrogate_key_seq TO PUBLIC;


--
-- Name: TABLE dim_employee; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE analytics.dim_employee TO PUBLIC;


--
-- Name: SEQUENCE dim_employee_surrogate_key_seq; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE analytics.dim_employee_surrogate_key_seq TO PUBLIC;


--
-- Name: TABLE dim_position; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE analytics.dim_position TO PUBLIC;


--
-- Name: SEQUENCE dim_position_surrogate_key_seq; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE analytics.dim_position_surrogate_key_seq TO PUBLIC;


--
-- Name: TABLE fact_attendance; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE analytics.fact_attendance TO PUBLIC;


--
-- Name: SEQUENCE fact_attendance_id_seq; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE analytics.fact_attendance_id_seq TO PUBLIC;


--
-- Name: TABLE fact_leave; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE analytics.fact_leave TO PUBLIC;


--
-- Name: SEQUENCE fact_leave_id_seq; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE analytics.fact_leave_id_seq TO PUBLIC;


--
-- Name: TABLE fact_payroll; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE analytics.fact_payroll TO PUBLIC;


--
-- Name: SEQUENCE fact_payroll_id_seq; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE analytics.fact_payroll_id_seq TO PUBLIC;


--
-- Name: TABLE fact_training; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE analytics.fact_training TO PUBLIC;


--
-- Name: SEQUENCE fact_training_id_seq; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE analytics.fact_training_id_seq TO PUBLIC;


--
-- Name: TABLE kpi_snapshots; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE analytics.kpi_snapshots TO PUBLIC;


--
-- Name: SEQUENCE kpi_snapshots_id_seq; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE analytics.kpi_snapshots_id_seq TO PUBLIC;


--
-- Name: TABLE report_data_sources; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE analytics.report_data_sources TO PUBLIC;


--
-- Name: SEQUENCE report_data_sources_id_seq; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE analytics.report_data_sources_id_seq TO PUBLIC;


--
-- Name: TABLE report_field_registry; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE analytics.report_field_registry TO PUBLIC;


--
-- Name: SEQUENCE report_field_registry_id_seq; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE analytics.report_field_registry_id_seq TO PUBLIC;


--
-- Name: TABLE report_run_history; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE analytics.report_run_history TO PUBLIC;


--
-- Name: SEQUENCE report_run_history_id_seq; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE analytics.report_run_history_id_seq TO PUBLIC;


--
-- Name: TABLE report_schedules; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE analytics.report_schedules TO PUBLIC;


--
-- Name: SEQUENCE report_schedules_id_seq; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE analytics.report_schedules_id_seq TO PUBLIC;


--
-- Name: TABLE saved_reports; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE analytics.saved_reports TO PUBLIC;


--
-- Name: SEQUENCE saved_reports_id_seq; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE analytics.saved_reports_id_seq TO PUBLIC;


--
-- Name: TABLE att_daily; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE attendance.att_daily TO PUBLIC;


--
-- Name: TABLE departments; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.departments TO PUBLIC;


--
-- Name: TABLE employees; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.employees TO PUBLIC;


--
-- Name: TABLE v_attendance_rate_30d; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE analytics.v_attendance_rate_30d TO PUBLIC;


--
-- Name: TABLE v_headcount_by_dept; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE analytics.v_headcount_by_dept TO PUBLIC;


--
-- Name: TABLE lv_requests; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE leave_mgmt.lv_requests TO PUBLIC;


--
-- Name: TABLE lv_types; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE leave_mgmt.lv_types TO PUBLIC;


--
-- Name: TABLE v_leave_utilization_ytd; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE analytics.v_leave_utilization_ytd TO PUBLIC;


--
-- Name: TABLE pay_employee_payroll; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE payroll.pay_employee_payroll TO PUBLIC;


--
-- Name: TABLE pay_periods; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE payroll.pay_periods TO PUBLIC;


--
-- Name: TABLE pay_runs; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE payroll.pay_runs TO PUBLIC;


--
-- Name: TABLE v_payroll_cost_mtd; Type: ACL; Schema: analytics; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE analytics.v_payroll_cost_mtd TO PUBLIC;


--
-- Name: TABLE att_admin_overrides; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE attendance.att_admin_overrides TO PUBLIC;


--
-- Name: SEQUENCE att_admin_overrides_id_seq; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE attendance.att_admin_overrides_id_seq TO PUBLIC;


--
-- Name: SEQUENCE att_daily_id_seq; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE attendance.att_daily_id_seq TO PUBLIC;


--
-- Name: TABLE att_dtr_corrections; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE attendance.att_dtr_corrections TO PUBLIC;


--
-- Name: SEQUENCE att_dtr_corrections_id_seq; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE attendance.att_dtr_corrections_id_seq TO PUBLIC;


--
-- Name: TABLE att_holiday_types; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE attendance.att_holiday_types TO PUBLIC;


--
-- Name: SEQUENCE att_holiday_types_id_seq; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE attendance.att_holiday_types_id_seq TO PUBLIC;


--
-- Name: TABLE att_holidays; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE attendance.att_holidays TO PUBLIC;


--
-- Name: SEQUENCE att_holidays_id_seq; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE attendance.att_holidays_id_seq TO PUBLIC;


--
-- Name: TABLE att_logs; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE attendance.att_logs TO PUBLIC;


--
-- Name: SEQUENCE att_logs_id_seq; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE attendance.att_logs_id_seq TO PUBLIC;


--
-- Name: TABLE att_logs_2025; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE attendance.att_logs_2025 TO PUBLIC;


--
-- Name: TABLE att_logs_2026; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE attendance.att_logs_2026 TO PUBLIC;


--
-- Name: TABLE att_logs_2027; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE attendance.att_logs_2027 TO PUBLIC;


--
-- Name: TABLE att_logs_2028; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE attendance.att_logs_2028 TO PUBLIC;


--
-- Name: TABLE att_overtime_requests; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE attendance.att_overtime_requests TO PUBLIC;


--
-- Name: SEQUENCE att_overtime_requests_id_seq; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE attendance.att_overtime_requests_id_seq TO PUBLIC;


--
-- Name: TABLE att_shift_assignments; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE attendance.att_shift_assignments TO PUBLIC;


--
-- Name: SEQUENCE att_shift_assignments_id_seq; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE attendance.att_shift_assignments_id_seq TO PUBLIC;


--
-- Name: TABLE att_shifts; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE attendance.att_shifts TO PUBLIC;


--
-- Name: SEQUENCE att_shifts_id_seq; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE attendance.att_shifts_id_seq TO PUBLIC;


--
-- Name: TABLE v_attendance_summary; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE attendance.v_attendance_summary TO PUBLIC;


--
-- Name: TABLE v_today_board; Type: ACL; Schema: attendance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE attendance.v_today_board TO PUBLIC;


--
-- Name: TABLE sys_bulk_operation_logs; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit_logs.sys_bulk_operation_logs TO PUBLIC;


--
-- Name: SEQUENCE sys_bulk_operation_logs_id_seq; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE audit_logs.sys_bulk_operation_logs_id_seq TO PUBLIC;


--
-- Name: TABLE sys_change_log; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit_logs.sys_change_log TO PUBLIC;


--
-- Name: SEQUENCE sys_change_log_id_seq; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE audit_logs.sys_change_log_id_seq TO PUBLIC;


--
-- Name: TABLE sys_change_log_2025; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit_logs.sys_change_log_2025 TO PUBLIC;


--
-- Name: TABLE sys_change_log_2026; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit_logs.sys_change_log_2026 TO PUBLIC;


--
-- Name: TABLE sys_change_log_2027; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit_logs.sys_change_log_2027 TO PUBLIC;


--
-- Name: TABLE sys_change_log_2028; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit_logs.sys_change_log_2028 TO PUBLIC;


--
-- Name: TABLE sys_data_exports; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit_logs.sys_data_exports TO PUBLIC;


--
-- Name: SEQUENCE sys_data_exports_id_seq; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE audit_logs.sys_data_exports_id_seq TO PUBLIC;


--
-- Name: TABLE sys_field_changes; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit_logs.sys_field_changes TO PUBLIC;


--
-- Name: SEQUENCE sys_field_changes_id_seq; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE audit_logs.sys_field_changes_id_seq TO PUBLIC;


--
-- Name: TABLE sys_field_changes_2025; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit_logs.sys_field_changes_2025 TO PUBLIC;


--
-- Name: TABLE sys_field_changes_2026; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit_logs.sys_field_changes_2026 TO PUBLIC;


--
-- Name: TABLE sys_field_changes_2027; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit_logs.sys_field_changes_2027 TO PUBLIC;


--
-- Name: TABLE sys_field_changes_2028; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit_logs.sys_field_changes_2028 TO PUBLIC;


--
-- Name: TABLE sys_login_logs; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit_logs.sys_login_logs TO PUBLIC;


--
-- Name: SEQUENCE sys_login_logs_id_seq; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE audit_logs.sys_login_logs_id_seq TO PUBLIC;


--
-- Name: TABLE sys_payroll_audit; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit_logs.sys_payroll_audit TO PUBLIC;


--
-- Name: SEQUENCE sys_payroll_audit_id_seq; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE audit_logs.sys_payroll_audit_id_seq TO PUBLIC;


--
-- Name: TABLE sys_status_transitions; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit_logs.sys_status_transitions TO PUBLIC;


--
-- Name: SEQUENCE sys_status_transitions_id_seq; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE audit_logs.sys_status_transitions_id_seq TO PUBLIC;


--
-- Name: TABLE users; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.users TO PUBLIC;


--
-- Name: TABLE v_recent_changes; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit_logs.v_recent_changes TO PUBLIC;


--
-- Name: TABLE v_security_events; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit_logs.v_security_events TO PUBLIC;


--
-- Name: TABLE v_user_activity_summary; Type: ACL; Schema: audit_logs; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit_logs.v_user_activity_summary TO PUBLIC;


--
-- Name: TABLE business_units; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.business_units TO PUBLIC;


--
-- Name: SEQUENCE business_units_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.business_units_id_seq TO PUBLIC;


--
-- Name: TABLE companies; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.companies TO PUBLIC;


--
-- Name: SEQUENCE companies_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.companies_id_seq TO PUBLIC;


--
-- Name: TABLE company_branding; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.company_branding TO PUBLIC;


--
-- Name: SEQUENCE company_branding_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.company_branding_id_seq TO PUBLIC;


--
-- Name: TABLE dashboard_metrics; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.dashboard_metrics TO PUBLIC;


--
-- Name: SEQUENCE dashboard_metrics_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.dashboard_metrics_id_seq TO PUBLIC;


--
-- Name: TABLE demo_profiles; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.demo_profiles TO PUBLIC;


--
-- Name: SEQUENCE demo_profiles_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.demo_profiles_id_seq TO PUBLIC;


--
-- Name: SEQUENCE departments_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.departments_id_seq TO PUBLIC;


--
-- Name: TABLE documents; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.documents TO PUBLIC;


--
-- Name: SEQUENCE documents_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.documents_id_seq TO PUBLIC;


--
-- Name: TABLE dynamic_forms; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.dynamic_forms TO PUBLIC;


--
-- Name: SEQUENCE dynamic_forms_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.dynamic_forms_id_seq TO PUBLIC;


--
-- Name: TABLE emp_addresses; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.emp_addresses TO PUBLIC;


--
-- Name: SEQUENCE emp_addresses_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.emp_addresses_id_seq TO PUBLIC;


--
-- Name: TABLE emp_bank_accounts; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.emp_bank_accounts TO PUBLIC;


--
-- Name: SEQUENCE emp_bank_accounts_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.emp_bank_accounts_id_seq TO PUBLIC;


--
-- Name: TABLE emp_dependents; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.emp_dependents TO PUBLIC;


--
-- Name: SEQUENCE emp_dependents_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.emp_dependents_id_seq TO PUBLIC;


--
-- Name: TABLE emp_education; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.emp_education TO PUBLIC;


--
-- Name: SEQUENCE emp_education_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.emp_education_id_seq TO PUBLIC;


--
-- Name: TABLE emp_emergency_contacts; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.emp_emergency_contacts TO PUBLIC;


--
-- Name: SEQUENCE emp_emergency_contacts_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.emp_emergency_contacts_id_seq TO PUBLIC;


--
-- Name: TABLE emp_government_ids; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.emp_government_ids TO PUBLIC;


--
-- Name: SEQUENCE emp_government_ids_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.emp_government_ids_id_seq TO PUBLIC;


--
-- Name: TABLE emp_status_history; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.emp_status_history TO PUBLIC;


--
-- Name: SEQUENCE emp_status_history_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.emp_status_history_id_seq TO PUBLIC;


--
-- Name: TABLE emp_work_history; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.emp_work_history TO PUBLIC;


--
-- Name: SEQUENCE emp_work_history_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.emp_work_history_id_seq TO PUBLIC;


--
-- Name: SEQUENCE employees_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.employees_id_seq TO PUBLIC;


--
-- Name: TABLE employment_types; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.employment_types TO PUBLIC;


--
-- Name: SEQUENCE employment_types_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.employment_types_id_seq TO PUBLIC;


--
-- Name: TABLE feature_registry; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.feature_registry TO PUBLIC;


--
-- Name: SEQUENCE feature_registry_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.feature_registry_id_seq TO PUBLIC;


--
-- Name: TABLE field_privacy_rules; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.field_privacy_rules TO PUBLIC;


--
-- Name: SEQUENCE field_privacy_rules_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.field_privacy_rules_id_seq TO PUBLIC;


--
-- Name: TABLE form_fields; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.form_fields TO PUBLIC;


--
-- Name: SEQUENCE form_fields_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.form_fields_id_seq TO PUBLIC;


--
-- Name: TABLE job_grades; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.job_grades TO PUBLIC;


--
-- Name: SEQUENCE job_grades_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.job_grades_id_seq TO PUBLIC;


--
-- Name: TABLE mod_permissions; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.mod_permissions TO PUBLIC;


--
-- Name: SEQUENCE mod_permissions_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.mod_permissions_id_seq TO PUBLIC;


--
-- Name: TABLE orchestration_flows; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.orchestration_flows TO PUBLIC;


--
-- Name: SEQUENCE orchestration_flows_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.orchestration_flows_id_seq TO PUBLIC;


--
-- Name: TABLE orchestration_steps; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.orchestration_steps TO PUBLIC;


--
-- Name: SEQUENCE orchestration_steps_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.orchestration_steps_id_seq TO PUBLIC;


--
-- Name: TABLE org_chart_nodes; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.org_chart_nodes TO PUBLIC;


--
-- Name: SEQUENCE org_chart_nodes_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.org_chart_nodes_id_seq TO PUBLIC;


--
-- Name: TABLE page_registry; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.page_registry TO PUBLIC;


--
-- Name: SEQUENCE page_registry_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.page_registry_id_seq TO PUBLIC;


--
-- Name: TABLE permissions; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.permissions TO PUBLIC;


--
-- Name: SEQUENCE permissions_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.permissions_id_seq TO PUBLIC;


--
-- Name: TABLE positions; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.positions TO PUBLIC;


--
-- Name: SEQUENCE positions_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.positions_id_seq TO PUBLIC;


--
-- Name: TABLE role_feature_access; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.role_feature_access TO PUBLIC;


--
-- Name: SEQUENCE role_feature_access_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.role_feature_access_id_seq TO PUBLIC;


--
-- Name: TABLE role_page_access; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.role_page_access TO PUBLIC;


--
-- Name: SEQUENCE role_page_access_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.role_page_access_id_seq TO PUBLIC;


--
-- Name: TABLE role_permissions; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.role_permissions TO PUBLIC;


--
-- Name: SEQUENCE role_permissions_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.role_permissions_id_seq TO PUBLIC;


--
-- Name: TABLE roles; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.roles TO PUBLIC;


--
-- Name: SEQUENCE roles_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.roles_id_seq TO PUBLIC;


--
-- Name: TABLE search_index; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.search_index TO PUBLIC;


--
-- Name: SEQUENCE search_index_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.search_index_id_seq TO PUBLIC;


--
-- Name: TABLE status_definitions; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.status_definitions TO PUBLIC;


--
-- Name: SEQUENCE status_definitions_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.status_definitions_id_seq TO PUBLIC;


--
-- Name: TABLE task_inbox; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.task_inbox TO PUBLIC;


--
-- Name: SEQUENCE task_inbox_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.task_inbox_id_seq TO PUBLIC;


--
-- Name: TABLE transaction_qr_tokens; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.transaction_qr_tokens TO PUBLIC;


--
-- Name: SEQUENCE transaction_qr_tokens_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.transaction_qr_tokens_id_seq TO PUBLIC;


--
-- Name: TABLE transaction_registry; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.transaction_registry TO PUBLIC;


--
-- Name: SEQUENCE transaction_registry_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.transaction_registry_id_seq TO PUBLIC;


--
-- Name: TABLE ui_themes; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.ui_themes TO PUBLIC;


--
-- Name: SEQUENCE ui_themes_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.ui_themes_id_seq TO PUBLIC;


--
-- Name: TABLE user_feature_access; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.user_feature_access TO PUBLIC;


--
-- Name: SEQUENCE user_feature_access_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.user_feature_access_id_seq TO PUBLIC;


--
-- Name: TABLE user_page_access; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.user_page_access TO PUBLIC;


--
-- Name: SEQUENCE user_page_access_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.user_page_access_id_seq TO PUBLIC;


--
-- Name: TABLE user_roles; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.user_roles TO PUBLIC;


--
-- Name: SEQUENCE user_roles_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.user_roles_id_seq TO PUBLIC;


--
-- Name: SEQUENCE users_id_seq; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE core.users_id_seq TO PUBLIC;


--
-- Name: TABLE v_employees_full; Type: ACL; Schema: core; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.v_employees_full TO PUBLIC;


--
-- Name: TABLE lrn_attendance_logs; Type: ACL; Schema: learning; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE learning.lrn_attendance_logs TO PUBLIC;


--
-- Name: SEQUENCE lrn_attendance_logs_id_seq; Type: ACL; Schema: learning; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE learning.lrn_attendance_logs_id_seq TO PUBLIC;


--
-- Name: TABLE lrn_employee_skills; Type: ACL; Schema: learning; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE learning.lrn_employee_skills TO PUBLIC;


--
-- Name: SEQUENCE lrn_employee_skills_id_seq; Type: ACL; Schema: learning; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE learning.lrn_employee_skills_id_seq TO PUBLIC;


--
-- Name: TABLE lrn_enrollments; Type: ACL; Schema: learning; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE learning.lrn_enrollments TO PUBLIC;


--
-- Name: SEQUENCE lrn_enrollments_id_seq; Type: ACL; Schema: learning; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE learning.lrn_enrollments_id_seq TO PUBLIC;


--
-- Name: TABLE lrn_idp_actions; Type: ACL; Schema: learning; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE learning.lrn_idp_actions TO PUBLIC;


--
-- Name: SEQUENCE lrn_idp_actions_id_seq; Type: ACL; Schema: learning; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE learning.lrn_idp_actions_id_seq TO PUBLIC;


--
-- Name: TABLE lrn_lsp_registry; Type: ACL; Schema: learning; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE learning.lrn_lsp_registry TO PUBLIC;


--
-- Name: SEQUENCE lrn_lsp_registry_id_seq; Type: ACL; Schema: learning; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE learning.lrn_lsp_registry_id_seq TO PUBLIC;


--
-- Name: TABLE lrn_narrative_reports; Type: ACL; Schema: learning; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE learning.lrn_narrative_reports TO PUBLIC;


--
-- Name: SEQUENCE lrn_narrative_reports_id_seq; Type: ACL; Schema: learning; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE learning.lrn_narrative_reports_id_seq TO PUBLIC;


--
-- Name: TABLE lrn_programs; Type: ACL; Schema: learning; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE learning.lrn_programs TO PUBLIC;


--
-- Name: SEQUENCE lrn_programs_id_seq; Type: ACL; Schema: learning; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE learning.lrn_programs_id_seq TO PUBLIC;


--
-- Name: TABLE lrn_scholarships; Type: ACL; Schema: learning; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE learning.lrn_scholarships TO PUBLIC;


--
-- Name: SEQUENCE lrn_scholarships_id_seq; Type: ACL; Schema: learning; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE learning.lrn_scholarships_id_seq TO PUBLIC;


--
-- Name: TABLE lrn_sessions; Type: ACL; Schema: learning; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE learning.lrn_sessions TO PUBLIC;


--
-- Name: SEQUENCE lrn_sessions_id_seq; Type: ACL; Schema: learning; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE learning.lrn_sessions_id_seq TO PUBLIC;


--
-- Name: TABLE lrn_skills; Type: ACL; Schema: learning; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE learning.lrn_skills TO PUBLIC;


--
-- Name: SEQUENCE lrn_skills_id_seq; Type: ACL; Schema: learning; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE learning.lrn_skills_id_seq TO PUBLIC;


--
-- Name: TABLE lrn_tna_entries; Type: ACL; Schema: learning; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE learning.lrn_tna_entries TO PUBLIC;


--
-- Name: SEQUENCE lrn_tna_entries_id_seq; Type: ACL; Schema: learning; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE learning.lrn_tna_entries_id_seq TO PUBLIC;


--
-- Name: TABLE lv_approvals; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE leave_mgmt.lv_approvals TO PUBLIC;


--
-- Name: SEQUENCE lv_approvals_id_seq; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE leave_mgmt.lv_approvals_id_seq TO PUBLIC;


--
-- Name: TABLE lv_balance_adjustments; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE leave_mgmt.lv_balance_adjustments TO PUBLIC;


--
-- Name: SEQUENCE lv_balance_adjustments_id_seq; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE leave_mgmt.lv_balance_adjustments_id_seq TO PUBLIC;


--
-- Name: TABLE lv_balances; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE leave_mgmt.lv_balances TO PUBLIC;


--
-- Name: SEQUENCE lv_balances_id_seq; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE leave_mgmt.lv_balances_id_seq TO PUBLIC;


--
-- Name: TABLE lv_cto_credits; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE leave_mgmt.lv_cto_credits TO PUBLIC;


--
-- Name: SEQUENCE lv_cto_credits_id_seq; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE leave_mgmt.lv_cto_credits_id_seq TO PUBLIC;


--
-- Name: TABLE lv_holidays; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE leave_mgmt.lv_holidays TO PUBLIC;


--
-- Name: SEQUENCE lv_holidays_id_seq; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE leave_mgmt.lv_holidays_id_seq TO PUBLIC;


--
-- Name: TABLE lv_ledger; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE leave_mgmt.lv_ledger TO PUBLIC;


--
-- Name: SEQUENCE lv_ledger_id_seq; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE leave_mgmt.lv_ledger_id_seq TO PUBLIC;


--
-- Name: TABLE lv_locator_entries; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE leave_mgmt.lv_locator_entries TO PUBLIC;


--
-- Name: SEQUENCE lv_locator_entries_id_seq; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE leave_mgmt.lv_locator_entries_id_seq TO PUBLIC;


--
-- Name: TABLE lv_policies; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE leave_mgmt.lv_policies TO PUBLIC;


--
-- Name: SEQUENCE lv_policies_id_seq; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE leave_mgmt.lv_policies_id_seq TO PUBLIC;


--
-- Name: SEQUENCE lv_requests_id_seq; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE leave_mgmt.lv_requests_id_seq TO PUBLIC;


--
-- Name: TABLE lv_travel_orders; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE leave_mgmt.lv_travel_orders TO PUBLIC;


--
-- Name: SEQUENCE lv_travel_orders_id_seq; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE leave_mgmt.lv_travel_orders_id_seq TO PUBLIC;


--
-- Name: SEQUENCE lv_types_id_seq; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE leave_mgmt.lv_types_id_seq TO PUBLIC;


--
-- Name: TABLE v_leave_balance_matrix; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE leave_mgmt.v_leave_balance_matrix TO PUBLIC;


--
-- Name: TABLE v_leave_requests_full; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE leave_mgmt.v_leave_requests_full TO PUBLIC;


--
-- Name: TABLE v_locator_today; Type: ACL; Schema: leave_mgmt; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE leave_mgmt.v_locator_today TO PUBLIC;


--
-- Name: TABLE ntf_channels; Type: ACL; Schema: notifications; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE notifications.ntf_channels TO PUBLIC;


--
-- Name: SEQUENCE ntf_channels_id_seq; Type: ACL; Schema: notifications; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE notifications.ntf_channels_id_seq TO PUBLIC;


--
-- Name: TABLE ntf_in_app; Type: ACL; Schema: notifications; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE notifications.ntf_in_app TO PUBLIC;


--
-- Name: SEQUENCE ntf_in_app_id_seq; Type: ACL; Schema: notifications; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE notifications.ntf_in_app_id_seq TO PUBLIC;


--
-- Name: TABLE ntf_queue; Type: ACL; Schema: notifications; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE notifications.ntf_queue TO PUBLIC;


--
-- Name: SEQUENCE ntf_queue_id_seq; Type: ACL; Schema: notifications; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE notifications.ntf_queue_id_seq TO PUBLIC;


--
-- Name: TABLE ntf_templates; Type: ACL; Schema: notifications; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE notifications.ntf_templates TO PUBLIC;


--
-- Name: SEQUENCE ntf_templates_id_seq; Type: ACL; Schema: notifications; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE notifications.ntf_templates_id_seq TO PUBLIC;


--
-- Name: TABLE reminder_rules; Type: ACL; Schema: notifications; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE notifications.reminder_rules TO PUBLIC;


--
-- Name: SEQUENCE reminder_rules_id_seq; Type: ACL; Schema: notifications; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE notifications.reminder_rules_id_seq TO PUBLIC;


--
-- Name: TABLE offb_clearance_items; Type: ACL; Schema: onboarding; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE onboarding.offb_clearance_items TO PUBLIC;


--
-- Name: SEQUENCE offb_clearance_items_id_seq; Type: ACL; Schema: onboarding; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE onboarding.offb_clearance_items_id_seq TO PUBLIC;


--
-- Name: TABLE offb_exit_interviews; Type: ACL; Schema: onboarding; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE onboarding.offb_exit_interviews TO PUBLIC;


--
-- Name: SEQUENCE offb_exit_interviews_id_seq; Type: ACL; Schema: onboarding; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE onboarding.offb_exit_interviews_id_seq TO PUBLIC;


--
-- Name: TABLE onb_buddy_assignments; Type: ACL; Schema: onboarding; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE onboarding.onb_buddy_assignments TO PUBLIC;


--
-- Name: SEQUENCE onb_buddy_assignments_id_seq; Type: ACL; Schema: onboarding; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE onboarding.onb_buddy_assignments_id_seq TO PUBLIC;


--
-- Name: TABLE onb_checklist_items; Type: ACL; Schema: onboarding; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE onboarding.onb_checklist_items TO PUBLIC;


--
-- Name: SEQUENCE onb_checklist_items_id_seq; Type: ACL; Schema: onboarding; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE onboarding.onb_checklist_items_id_seq TO PUBLIC;


--
-- Name: TABLE onb_checklists; Type: ACL; Schema: onboarding; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE onboarding.onb_checklists TO PUBLIC;


--
-- Name: SEQUENCE onb_checklists_id_seq; Type: ACL; Schema: onboarding; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE onboarding.onb_checklists_id_seq TO PUBLIC;


--
-- Name: TABLE onb_pre_employment_reqs; Type: ACL; Schema: onboarding; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE onboarding.onb_pre_employment_reqs TO PUBLIC;


--
-- Name: SEQUENCE onb_pre_employment_reqs_id_seq; Type: ACL; Schema: onboarding; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE onboarding.onb_pre_employment_reqs_id_seq TO PUBLIC;


--
-- Name: TABLE pay_13th_month; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE payroll.pay_13th_month TO PUBLIC;


--
-- Name: SEQUENCE pay_13th_month_id_seq; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE payroll.pay_13th_month_id_seq TO PUBLIC;


--
-- Name: TABLE pay_adjustments; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE payroll.pay_adjustments TO PUBLIC;


--
-- Name: SEQUENCE pay_adjustments_id_seq; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE payroll.pay_adjustments_id_seq TO PUBLIC;


--
-- Name: TABLE pay_annual_bonuses; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE payroll.pay_annual_bonuses TO PUBLIC;


--
-- Name: SEQUENCE pay_annual_bonuses_id_seq; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE payroll.pay_annual_bonuses_id_seq TO PUBLIC;


--
-- Name: TABLE pay_bir_tax_table; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE payroll.pay_bir_tax_table TO PUBLIC;


--
-- Name: SEQUENCE pay_bir_tax_table_id_seq; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE payroll.pay_bir_tax_table_id_seq TO PUBLIC;


--
-- Name: TABLE pay_coop_members; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE payroll.pay_coop_members TO PUBLIC;


--
-- Name: SEQUENCE pay_coop_members_id_seq; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE payroll.pay_coop_members_id_seq TO PUBLIC;


--
-- Name: TABLE pay_employee_allowances; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE payroll.pay_employee_allowances TO PUBLIC;


--
-- Name: TABLE pay_employee_allowances_gov; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE payroll.pay_employee_allowances_gov TO PUBLIC;


--
-- Name: SEQUENCE pay_employee_allowances_gov_id_seq; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE payroll.pay_employee_allowances_gov_id_seq TO PUBLIC;


--
-- Name: SEQUENCE pay_employee_allowances_id_seq; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE payroll.pay_employee_allowances_id_seq TO PUBLIC;


--
-- Name: SEQUENCE pay_employee_payroll_id_seq; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE payroll.pay_employee_payroll_id_seq TO PUBLIC;


--
-- Name: TABLE pay_gov_allowances; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE payroll.pay_gov_allowances TO PUBLIC;


--
-- Name: SEQUENCE pay_gov_allowances_id_seq; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE payroll.pay_gov_allowances_id_seq TO PUBLIC;


--
-- Name: TABLE pay_government_remittances; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE payroll.pay_government_remittances TO PUBLIC;


--
-- Name: SEQUENCE pay_government_remittances_id_seq; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE payroll.pay_government_remittances_id_seq TO PUBLIC;


--
-- Name: TABLE pay_gsis_schedule; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE payroll.pay_gsis_schedule TO PUBLIC;


--
-- Name: SEQUENCE pay_gsis_schedule_id_seq; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE payroll.pay_gsis_schedule_id_seq TO PUBLIC;


--
-- Name: TABLE pay_loan_payments; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE payroll.pay_loan_payments TO PUBLIC;


--
-- Name: SEQUENCE pay_loan_payments_id_seq; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE payroll.pay_loan_payments_id_seq TO PUBLIC;


--
-- Name: TABLE pay_loans; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE payroll.pay_loans TO PUBLIC;


--
-- Name: SEQUENCE pay_loans_id_seq; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE payroll.pay_loans_id_seq TO PUBLIC;


--
-- Name: TABLE pay_pagibig_schedule; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE payroll.pay_pagibig_schedule TO PUBLIC;


--
-- Name: SEQUENCE pay_pagibig_schedule_id_seq; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE payroll.pay_pagibig_schedule_id_seq TO PUBLIC;


--
-- Name: SEQUENCE pay_periods_id_seq; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE payroll.pay_periods_id_seq TO PUBLIC;


--
-- Name: TABLE pay_rata_schedule; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE payroll.pay_rata_schedule TO PUBLIC;


--
-- Name: SEQUENCE pay_rata_schedule_id_seq; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE payroll.pay_rata_schedule_id_seq TO PUBLIC;


--
-- Name: SEQUENCE pay_runs_id_seq; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE payroll.pay_runs_id_seq TO PUBLIC;


--
-- Name: TABLE pay_tax_tables; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE payroll.pay_tax_tables TO PUBLIC;


--
-- Name: SEQUENCE pay_tax_tables_id_seq; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE payroll.pay_tax_tables_id_seq TO PUBLIC;


--
-- Name: TABLE v_current_cutoff; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE payroll.v_current_cutoff TO PUBLIC;


--
-- Name: TABLE v_gov_payroll_summary; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE payroll.v_gov_payroll_summary TO PUBLIC;


--
-- Name: TABLE v_payslip; Type: ACL; Schema: payroll; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE payroll.v_payslip TO PUBLIC;


--
-- Name: TABLE perf_competencies; Type: ACL; Schema: performance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE performance.perf_competencies TO PUBLIC;


--
-- Name: SEQUENCE perf_competencies_id_seq; Type: ACL; Schema: performance; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE performance.perf_competencies_id_seq TO PUBLIC;


--
-- Name: TABLE perf_cycles; Type: ACL; Schema: performance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE performance.perf_cycles TO PUBLIC;


--
-- Name: SEQUENCE perf_cycles_id_seq; Type: ACL; Schema: performance; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE performance.perf_cycles_id_seq TO PUBLIC;


--
-- Name: TABLE perf_employee_kpis; Type: ACL; Schema: performance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE performance.perf_employee_kpis TO PUBLIC;


--
-- Name: SEQUENCE perf_employee_kpis_id_seq; Type: ACL; Schema: performance; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE performance.perf_employee_kpis_id_seq TO PUBLIC;


--
-- Name: TABLE perf_idp_plans; Type: ACL; Schema: performance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE performance.perf_idp_plans TO PUBLIC;


--
-- Name: SEQUENCE perf_idp_plans_id_seq; Type: ACL; Schema: performance; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE performance.perf_idp_plans_id_seq TO PUBLIC;


--
-- Name: TABLE perf_ipcr; Type: ACL; Schema: performance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE performance.perf_ipcr TO PUBLIC;


--
-- Name: SEQUENCE perf_ipcr_id_seq; Type: ACL; Schema: performance; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE performance.perf_ipcr_id_seq TO PUBLIC;


--
-- Name: TABLE perf_ipcr_summary; Type: ACL; Schema: performance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE performance.perf_ipcr_summary TO PUBLIC;


--
-- Name: SEQUENCE perf_ipcr_summary_id_seq; Type: ACL; Schema: performance; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE performance.perf_ipcr_summary_id_seq TO PUBLIC;


--
-- Name: TABLE perf_opcr; Type: ACL; Schema: performance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE performance.perf_opcr TO PUBLIC;


--
-- Name: SEQUENCE perf_opcr_id_seq; Type: ACL; Schema: performance; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE performance.perf_opcr_id_seq TO PUBLIC;


--
-- Name: TABLE perf_reviews; Type: ACL; Schema: performance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE performance.perf_reviews TO PUBLIC;


--
-- Name: SEQUENCE perf_reviews_id_seq; Type: ACL; Schema: performance; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE performance.perf_reviews_id_seq TO PUBLIC;


--
-- Name: TABLE perf_strategic_plans; Type: ACL; Schema: performance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE performance.perf_strategic_plans TO PUBLIC;


--
-- Name: SEQUENCE perf_strategic_plans_id_seq; Type: ACL; Schema: performance; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE performance.perf_strategic_plans_id_seq TO PUBLIC;


--
-- Name: TABLE perf_succession_matrix; Type: ACL; Schema: performance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE performance.perf_succession_matrix TO PUBLIC;


--
-- Name: SEQUENCE perf_succession_matrix_id_seq; Type: ACL; Schema: performance; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE performance.perf_succession_matrix_id_seq TO PUBLIC;


--
-- Name: TABLE v_ipcr_summary; Type: ACL; Schema: performance; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE performance.v_ipcr_summary TO PUBLIC;


--
-- Name: TABLE rec_applicants; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE recruitment.rec_applicants TO PUBLIC;


--
-- Name: SEQUENCE rec_applicants_id_seq; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE recruitment.rec_applicants_id_seq TO PUBLIC;


--
-- Name: TABLE rec_appointments; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE recruitment.rec_appointments TO PUBLIC;


--
-- Name: SEQUENCE rec_appointments_id_seq; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE recruitment.rec_appointments_id_seq TO PUBLIC;


--
-- Name: TABLE rec_csc_eligibilities; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE recruitment.rec_csc_eligibilities TO PUBLIC;


--
-- Name: SEQUENCE rec_csc_eligibilities_id_seq; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE recruitment.rec_csc_eligibilities_id_seq TO PUBLIC;


--
-- Name: TABLE rec_employee_eligibilities; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE recruitment.rec_employee_eligibilities TO PUBLIC;


--
-- Name: SEQUENCE rec_employee_eligibilities_id_seq; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE recruitment.rec_employee_eligibilities_id_seq TO PUBLIC;


--
-- Name: TABLE rec_interview_schedules; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE recruitment.rec_interview_schedules TO PUBLIC;


--
-- Name: SEQUENCE rec_interview_schedules_id_seq; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE recruitment.rec_interview_schedules_id_seq TO PUBLIC;


--
-- Name: TABLE rec_job_postings; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE recruitment.rec_job_postings TO PUBLIC;


--
-- Name: SEQUENCE rec_job_postings_id_seq; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE recruitment.rec_job_postings_id_seq TO PUBLIC;


--
-- Name: TABLE rec_next_in_rank_list; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE recruitment.rec_next_in_rank_list TO PUBLIC;


--
-- Name: SEQUENCE rec_next_in_rank_list_id_seq; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE recruitment.rec_next_in_rank_list_id_seq TO PUBLIC;


--
-- Name: TABLE rec_offers; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE recruitment.rec_offers TO PUBLIC;


--
-- Name: SEQUENCE rec_offers_id_seq; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE recruitment.rec_offers_id_seq TO PUBLIC;


--
-- Name: TABLE rec_plantilla_items; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE recruitment.rec_plantilla_items TO PUBLIC;


--
-- Name: SEQUENCE rec_plantilla_items_id_seq; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE recruitment.rec_plantilla_items_id_seq TO PUBLIC;


--
-- Name: TABLE rec_psb_deliberations; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE recruitment.rec_psb_deliberations TO PUBLIC;


--
-- Name: SEQUENCE rec_psb_deliberations_id_seq; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE recruitment.rec_psb_deliberations_id_seq TO PUBLIC;


--
-- Name: TABLE rec_psb_members; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE recruitment.rec_psb_members TO PUBLIC;


--
-- Name: SEQUENCE rec_psb_members_id_seq; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE recruitment.rec_psb_members_id_seq TO PUBLIC;


--
-- Name: TABLE rec_psb_scores; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE recruitment.rec_psb_scores TO PUBLIC;


--
-- Name: SEQUENCE rec_psb_scores_id_seq; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE recruitment.rec_psb_scores_id_seq TO PUBLIC;


--
-- Name: TABLE rec_publications; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE recruitment.rec_publications TO PUBLIC;


--
-- Name: SEQUENCE rec_publications_id_seq; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE recruitment.rec_publications_id_seq TO PUBLIC;


--
-- Name: TABLE rec_qualification_standards; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE recruitment.rec_qualification_standards TO PUBLIC;


--
-- Name: SEQUENCE rec_qualification_standards_id_seq; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE recruitment.rec_qualification_standards_id_seq TO PUBLIC;


--
-- Name: TABLE rec_requisitions; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE recruitment.rec_requisitions TO PUBLIC;


--
-- Name: SEQUENCE rec_requisitions_id_seq; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE recruitment.rec_requisitions_id_seq TO PUBLIC;


--
-- Name: TABLE v_next_in_rank; Type: ACL; Schema: recruitment; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE recruitment.v_next_in_rank TO PUBLIC;


--
-- Name: TABLE rwd_awards; Type: ACL; Schema: rewards; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE rewards.rwd_awards TO PUBLIC;


--
-- Name: SEQUENCE rwd_awards_id_seq; Type: ACL; Schema: rewards; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE rewards.rwd_awards_id_seq TO PUBLIC;


--
-- Name: TABLE rwd_categories; Type: ACL; Schema: rewards; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE rewards.rwd_categories TO PUBLIC;


--
-- Name: SEQUENCE rwd_categories_id_seq; Type: ACL; Schema: rewards; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE rewards.rwd_categories_id_seq TO PUBLIC;


--
-- Name: TABLE rwd_loyalty_milestones; Type: ACL; Schema: rewards; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE rewards.rwd_loyalty_milestones TO PUBLIC;


--
-- Name: SEQUENCE rwd_loyalty_milestones_id_seq; Type: ACL; Schema: rewards; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE rewards.rwd_loyalty_milestones_id_seq TO PUBLIC;


--
-- Name: TABLE rwd_nominations; Type: ACL; Schema: rewards; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE rewards.rwd_nominations TO PUBLIC;


--
-- Name: SEQUENCE rwd_nominations_id_seq; Type: ACL; Schema: rewards; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE rewards.rwd_nominations_id_seq TO PUBLIC;


--
-- Name: TABLE rwd_pbb_records; Type: ACL; Schema: rewards; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE rewards.rwd_pbb_records TO PUBLIC;


--
-- Name: SEQUENCE rwd_pbb_records_id_seq; Type: ACL; Schema: rewards; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE rewards.rwd_pbb_records_id_seq TO PUBLIC;


--
-- Name: TABLE rwd_praise_config; Type: ACL; Schema: rewards; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE rewards.rwd_praise_config TO PUBLIC;


--
-- Name: SEQUENCE rwd_praise_config_id_seq; Type: ACL; Schema: rewards; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE rewards.rwd_praise_config_id_seq TO PUBLIC;


--
-- Name: TABLE rwd_retirement_alerts; Type: ACL; Schema: rewards; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE rewards.rwd_retirement_alerts TO PUBLIC;


--
-- Name: SEQUENCE rwd_retirement_alerts_id_seq; Type: ACL; Schema: rewards; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE rewards.rwd_retirement_alerts_id_seq TO PUBLIC;


--
-- Name: TABLE rwd_retirement_plans; Type: ACL; Schema: rewards; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE rewards.rwd_retirement_plans TO PUBLIC;


--
-- Name: SEQUENCE rwd_retirement_plans_id_seq; Type: ACL; Schema: rewards; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE rewards.rwd_retirement_plans_id_seq TO PUBLIC;


--
-- Name: TABLE rwd_ssl_table; Type: ACL; Schema: rewards; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE rewards.rwd_ssl_table TO PUBLIC;


--
-- Name: SEQUENCE rwd_ssl_table_id_seq; Type: ACL; Schema: rewards; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE rewards.rwd_ssl_table_id_seq TO PUBLIC;


--
-- Name: TABLE rwd_step_increments; Type: ACL; Schema: rewards; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE rewards.rwd_step_increments TO PUBLIC;


--
-- Name: SEQUENCE rwd_step_increments_id_seq; Type: ACL; Schema: rewards; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE rewards.rwd_step_increments_id_seq TO PUBLIC;


--
-- Name: TABLE v_retirement_notices; Type: ACL; Schema: rewards; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE rewards.v_retirement_notices TO PUBLIC;


--
-- Name: TABLE v_step_increment_due; Type: ACL; Schema: rewards; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE rewards.v_step_increment_due TO PUBLIC;


--
-- Name: TABLE instance_checklist_items; Type: ACL; Schema: workflow; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE workflow.instance_checklist_items TO PUBLIC;


--
-- Name: SEQUENCE instance_checklist_items_id_seq; Type: ACL; Schema: workflow; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE workflow.instance_checklist_items_id_seq TO PUBLIC;


--
-- Name: TABLE workflow_definitions; Type: ACL; Schema: workflow; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE workflow.workflow_definitions TO PUBLIC;


--
-- Name: TABLE workflow_instances; Type: ACL; Schema: workflow; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE workflow.workflow_instances TO PUBLIC;


--
-- Name: TABLE workflow_steps; Type: ACL; Schema: workflow; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE workflow.workflow_steps TO PUBLIC;


--
-- Name: TABLE v_pending_approvals; Type: ACL; Schema: workflow; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE workflow.v_pending_approvals TO PUBLIC;


--
-- Name: TABLE workflow_action_logs; Type: ACL; Schema: workflow; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE workflow.workflow_action_logs TO PUBLIC;


--
-- Name: SEQUENCE workflow_action_logs_id_seq; Type: ACL; Schema: workflow; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE workflow.workflow_action_logs_id_seq TO PUBLIC;


--
-- Name: TABLE workflow_checklists; Type: ACL; Schema: workflow; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE workflow.workflow_checklists TO PUBLIC;


--
-- Name: SEQUENCE workflow_checklists_id_seq; Type: ACL; Schema: workflow; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE workflow.workflow_checklists_id_seq TO PUBLIC;


--
-- Name: SEQUENCE workflow_definitions_id_seq; Type: ACL; Schema: workflow; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE workflow.workflow_definitions_id_seq TO PUBLIC;


--
-- Name: TABLE workflow_event_hooks; Type: ACL; Schema: workflow; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE workflow.workflow_event_hooks TO PUBLIC;


--
-- Name: SEQUENCE workflow_event_hooks_id_seq; Type: ACL; Schema: workflow; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE workflow.workflow_event_hooks_id_seq TO PUBLIC;


--
-- Name: SEQUENCE workflow_instances_id_seq; Type: ACL; Schema: workflow; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE workflow.workflow_instances_id_seq TO PUBLIC;


--
-- Name: TABLE workflow_routes; Type: ACL; Schema: workflow; Owner: hris_admin
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE workflow.workflow_routes TO PUBLIC;


--
-- Name: SEQUENCE workflow_routes_id_seq; Type: ACL; Schema: workflow; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE workflow.workflow_routes_id_seq TO PUBLIC;


--
-- Name: SEQUENCE workflow_steps_id_seq; Type: ACL; Schema: workflow; Owner: hris_admin
--

GRANT SELECT,USAGE ON SEQUENCE workflow.workflow_steps_id_seq TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: ai; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA ai GRANT SELECT,USAGE ON SEQUENCES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: ai; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA ai GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: analytics; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA analytics GRANT SELECT,USAGE ON SEQUENCES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: analytics; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA analytics GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: attendance; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA attendance GRANT SELECT,USAGE ON SEQUENCES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: attendance; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA attendance GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: audit_logs; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA audit_logs GRANT SELECT,USAGE ON SEQUENCES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: audit_logs; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA audit_logs GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: core; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA core GRANT SELECT,USAGE ON SEQUENCES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: core; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA core GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: learning; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA learning GRANT SELECT,USAGE ON SEQUENCES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: learning; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA learning GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: leave_mgmt; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA leave_mgmt GRANT SELECT,USAGE ON SEQUENCES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: leave_mgmt; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA leave_mgmt GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: notifications; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA notifications GRANT SELECT,USAGE ON SEQUENCES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: notifications; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA notifications GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: onboarding; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA onboarding GRANT SELECT,USAGE ON SEQUENCES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: onboarding; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA onboarding GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: payroll; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA payroll GRANT SELECT,USAGE ON SEQUENCES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: payroll; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA payroll GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: performance; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA performance GRANT SELECT,USAGE ON SEQUENCES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: performance; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA performance GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: recruitment; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA recruitment GRANT SELECT,USAGE ON SEQUENCES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: recruitment; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA recruitment GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: rewards; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA rewards GRANT SELECT,USAGE ON SEQUENCES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: rewards; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA rewards GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: workflow; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA workflow GRANT SELECT,USAGE ON SEQUENCES  TO PUBLIC;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: workflow; Owner: hris_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE hris_admin IN SCHEMA workflow GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES  TO PUBLIC;


--
-- PostgreSQL database dump complete
--

\unrestrict ogVg8xMH7NleGJJVgXHKxYFR8Xc3e4h8ah4IsCd8z8ixZaGc4noUV7RvKLBaeqe

