-- ================================================================
-- HCM360 — 45: SCHEMA PATCHES
-- Safe to re-run (IF NOT EXISTS / ON CONFLICT).
-- ================================================================

-- Add user theme preference column (was missing from initial migration)
ALTER TABLE core.users ADD COLUMN IF NOT EXISTS theme_id BIGINT REFERENCES core.ui_themes(id);

-- Fix: grant EMPLOYEE role access to /leave/locator (team locator board)
UPDATE core.role_page_access
SET can_access = TRUE
WHERE role_code = 'EMPLOYEE'
  AND page_id = (SELECT id FROM core.page_registry WHERE path = '/leave/locator');

-- Task Inbox table (unified pending actions across modules)
CREATE TABLE IF NOT EXISTS core.task_inbox (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT REFERENCES core.employees(id),
    user_id BIGINT REFERENCES core.users(id),
    task_type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    action_url VARCHAR(255),
    priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL',
    due_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    source_table VARCHAR(100),
    source_id BIGINT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_task_inbox_employee ON core.task_inbox(employee_id, status);
CREATE INDEX IF NOT EXISTS idx_task_inbox_source ON core.task_inbox(source_table, source_id, status);

-- Reminder rules table (drives the reminder engine)
CREATE TABLE IF NOT EXISTS notifications.reminder_rules (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    rule_type VARCHAR(50) NOT NULL DEFAULT 'SCHEDULED',
    source_query TEXT,
    task_type VARCHAR(50),
    priority VARCHAR(20) DEFAULT 'NORMAL',
    action_url_template VARCHAR(255),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
