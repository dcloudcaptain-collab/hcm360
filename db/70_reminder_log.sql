-- ================================================================
-- HCM360 — 70: NOTIFICATIONS.REMINDER_LOG
--
-- Creates the missing log table used by services/reminder_engine.py.
-- Every time a reminder rule fires (via run_rule / fire_all), a row
-- is inserted so we can:
--   * show per-rule "fired today" / "pending" counts in the admin UI
--   * dedupe the same reminder firing twice for the same target
--   * escalate overdue reminders after N days
--
-- Columns chosen to match the queries in reminder_engine.py:
--   rl.rule_id, rl.employee_id, rl.user_id, rl.task_inbox_id,
--   rl.notification_id, rl.title, rl.due_date, rl.priority,
--   rl.status, rl.fired_at, rl.escalated_at
-- ================================================================
SET search_path TO notifications, public;

CREATE TABLE IF NOT EXISTS notifications.reminder_log (
    id              BIGSERIAL    PRIMARY KEY,
    rule_id         BIGINT       NOT NULL REFERENCES notifications.reminder_rules(id) ON DELETE CASCADE,
    employee_id     BIGINT       REFERENCES core.employees(id) ON DELETE SET NULL,
    user_id         BIGINT       REFERENCES core.users(id)     ON DELETE SET NULL,
    task_inbox_id   BIGINT,                 -- intentionally no FK (loose coupling)
    notification_id BIGINT,                 -- intentionally no FK
    title           VARCHAR(300),
    due_date        DATE,
    priority        VARCHAR(20)  NOT NULL DEFAULT 'NORMAL',
    status          VARCHAR(20)  NOT NULL DEFAULT 'SENT'
                    CHECK (status IN ('SENT', 'ESCALATED', 'RESOLVED', 'SUPPRESSED')),
    fired_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    escalated_at    TIMESTAMPTZ,
    resolved_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_rlog_rule      ON notifications.reminder_log (rule_id, fired_at);
CREATE INDEX IF NOT EXISTS idx_rlog_emp       ON notifications.reminder_log (employee_id, status);
CREATE INDEX IF NOT EXISTS idx_rlog_status    ON notifications.reminder_log (status, fired_at);
CREATE INDEX IF NOT EXISTS idx_rlog_fired_at  ON notifications.reminder_log (fired_at DESC);


-- ── Extend reminder_rules with columns the engine expects ──────
-- (name, category, escalation_to, escalation_days are referenced by
-- services/reminder_engine.py but were never added to the table.)
ALTER TABLE notifications.reminder_rules
    ADD COLUMN IF NOT EXISTS name             VARCHAR(255),
    ADD COLUMN IF NOT EXISTS category         VARCHAR(40) NOT NULL DEFAULT 'General',
    ADD COLUMN IF NOT EXISTS escalation_to    VARCHAR(30),
    ADD COLUMN IF NOT EXISTS escalation_days  INT,
    ADD COLUMN IF NOT EXISTS target_role      VARCHAR(30),
    ADD COLUMN IF NOT EXISTS last_run_at      TIMESTAMPTZ;

-- Back-fill `name` from `title` and set sensible categories by code prefix
UPDATE notifications.reminder_rules SET name = title WHERE name IS NULL;

UPDATE notifications.reminder_rules SET category =
    CASE
        WHEN code ILIKE 'LEAVE_%'        THEN 'Leave'
        WHEN code ILIKE 'ATTEND%'        THEN 'Attendance'
        WHEN code ILIKE 'PE_%'           THEN 'Health'
        WHEN code ILIKE 'CERT_%'         THEN 'Compliance'
        WHEN code ILIKE 'PROBATION%'     THEN 'Onboarding'
        WHEN code ILIKE 'CONTRACT_%'     THEN 'Core HR'
        WHEN code ILIKE 'BIRTHDAY'       THEN 'Engagement'
        WHEN code ILIKE 'TRAIN%'         THEN 'Learning'
        WHEN code ILIKE 'REVIEW_%'       THEN 'Performance'
        WHEN code ILIKE 'LOYALTY_%'      THEN 'Rewards'
        WHEN code ILIKE 'STEP_%'         THEN 'Rewards'
        WHEN code ILIKE 'RETIRE%'        THEN 'Workforce'
        WHEN code ILIKE 'REQ_%'          THEN 'Recruitment'
        WHEN code ILIKE 'TASK_%'         THEN 'Tasks'
        WHEN code ILIKE 'ACCESS_%'       THEN 'Admin'
        ELSE 'General'
    END
 WHERE category = 'General' OR category IS NULL;
