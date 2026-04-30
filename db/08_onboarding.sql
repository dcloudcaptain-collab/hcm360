-- ================================================================
-- HCM360 HRIS — 08: ONBOARDING SCHEMA (Phase 2)
-- Schema    : onboarding
-- ================================================================
SET search_path TO onboarding, core, public;

CREATE TABLE onboarding.onb_checklists (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    workflow_instance_id BIGINT,
    type            VARCHAR(20)  NOT NULL DEFAULT 'ONBOARDING',
    status          VARCHAR(20)  NOT NULL DEFAULT 'IN_PROGRESS',
    target_date     DATE,
    completed_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE onboarding.onb_checklist_items (
    id              BIGSERIAL    PRIMARY KEY,
    checklist_id    BIGINT       NOT NULL REFERENCES onboarding.onb_checklists(id) ON DELETE CASCADE,
    category        VARCHAR(50)  NOT NULL,
    item_name       VARCHAR(200) NOT NULL,
    is_required     BOOLEAN      NOT NULL DEFAULT TRUE,
    is_completed    BOOLEAN      NOT NULL DEFAULT FALSE,
    completed_by    BIGINT       REFERENCES core.users(id),
    completed_at    TIMESTAMPTZ,
    notes           TEXT,
    sort_order      INTEGER      NOT NULL DEFAULT 99
);

CREATE TABLE onboarding.onb_buddy_assignments (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    buddy_id        BIGINT       NOT NULL REFERENCES core.employees(id),
    assigned_from   DATE         NOT NULL,
    assigned_to     DATE,
    notes           TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE onboarding.offb_exit_interviews (
    id                  BIGSERIAL    PRIMARY KEY,
    employee_id         BIGINT       NOT NULL REFERENCES core.employees(id),
    interview_date      DATE,
    interviewer_id      BIGINT       REFERENCES core.users(id),
    reason_for_leaving  TEXT,
    would_return        BOOLEAN,
    satisfaction_score  INTEGER,
    feedback            TEXT,
    last_working_day    DATE,
    clearance_completed BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
