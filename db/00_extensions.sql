-- ================================================================
-- HCM360 HRIS — 00: EXTENSIONS & SCHEMA CREATION
-- Database : hris_db
-- Run order: FIRST — all other files depend on these schemas
-- ================================================================

-- ── PostgreSQL Extensions ─────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "unaccent";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- ── Create all schemas in dependency order ────────────────────────
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS workflow;
CREATE SCHEMA IF NOT EXISTS notifications;
CREATE SCHEMA IF NOT EXISTS audit_logs;
CREATE SCHEMA IF NOT EXISTS attendance;
CREATE SCHEMA IF NOT EXISTS leave_mgmt;
CREATE SCHEMA IF NOT EXISTS recruitment;
CREATE SCHEMA IF NOT EXISTS onboarding;
CREATE SCHEMA IF NOT EXISTS performance;
CREATE SCHEMA IF NOT EXISTS learning;
CREATE SCHEMA IF NOT EXISTS rewards;
CREATE SCHEMA IF NOT EXISTS payroll;
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS ai;

-- ── Grant schema usage to app user ───────────────────────────────
-- (adjust role name if your app connects as a different user)
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT schema_name FROM information_schema.schemata
           WHERE schema_name IN (
             'core','workflow','notifications','audit_logs',
             'attendance','leave_mgmt','recruitment','onboarding',
             'performance','learning','rewards','payroll',
             'analytics','ai'
           )
  LOOP
    EXECUTE format('GRANT USAGE ON SCHEMA %I TO PUBLIC', r.schema_name);
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO PUBLIC', r.schema_name);
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT USAGE, SELECT ON SEQUENCES TO PUBLIC', r.schema_name);
  END LOOP;
END
$$;

-- ── Set default search path for this session ─────────────────────
-- The application also sets this per connection in services/db.py
SET search_path TO core, workflow, notifications, audit_logs,
    attendance, leave_mgmt, recruitment, onboarding,
    performance, learning, rewards, payroll,
    analytics, ai, public;
