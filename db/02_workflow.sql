-- ================================================================
-- HCM360 HRIS — 02: WORKFLOW SCHEMA
-- Schema    : workflow
-- Contains  : generic approval engine used by ALL modules
-- ================================================================

SET search_path TO workflow, core, public;

CREATE TABLE workflow.workflow_definitions (
    id              BIGSERIAL    PRIMARY KEY,
    code            VARCHAR(60)  NOT NULL UNIQUE,
    name            VARCHAR(200) NOT NULL,
    module          VARCHAR(50)  NOT NULL,
    description     TEXT,
    version         INTEGER      NOT NULL DEFAULT 1,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE workflow.workflow_steps (
    id                  BIGSERIAL    PRIMARY KEY,
    workflow_id         BIGINT       NOT NULL REFERENCES workflow.workflow_definitions(id) ON DELETE CASCADE,
    step_order          INTEGER      NOT NULL,
    code                VARCHAR(60)  NOT NULL,
    name                VARCHAR(200) NOT NULL,
    role_required       VARCHAR(50),
    is_final            BOOLEAN      NOT NULL DEFAULT FALSE,
    description         TEXT,
    sla_hours           INTEGER,
    UNIQUE (workflow_id, step_order)
);

CREATE TABLE workflow.workflow_routes (
    id              BIGSERIAL    PRIMARY KEY,
    step_id         BIGINT       NOT NULL REFERENCES workflow.workflow_steps(id) ON DELETE CASCADE,
    action_code     VARCHAR(30)  NOT NULL,
    next_step_id    BIGINT       REFERENCES workflow.workflow_steps(id),
    label           VARCHAR(100),
    UNIQUE (step_id, action_code)
);

CREATE TABLE workflow.workflow_checklists (
    id              BIGSERIAL    PRIMARY KEY,
    step_id         BIGINT       NOT NULL REFERENCES workflow.workflow_steps(id) ON DELETE CASCADE,
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    is_gate         BOOLEAN      NOT NULL DEFAULT FALSE,
    sort_order      INTEGER      NOT NULL DEFAULT 99
);

CREATE TABLE workflow.workflow_instances (
    id                  BIGSERIAL    PRIMARY KEY,
    definition_id       BIGINT       NOT NULL REFERENCES workflow.workflow_definitions(id),
    current_step_id     BIGINT       REFERENCES workflow.workflow_steps(id),
    module              VARCHAR(50)  NOT NULL,
    entity_type         VARCHAR(60),
    entity_id           BIGINT,
    reference_no        VARCHAR(60),
    status              VARCHAR(20)  NOT NULL DEFAULT 'IN_PROGRESS',
    initiated_by        BIGINT       REFERENCES core.users(id),
    completed_at        TIMESTAMPTZ,
    metadata            JSONB        NOT NULL DEFAULT '{}',
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_wi_module_entity  ON workflow.workflow_instances(module, entity_type, entity_id);
CREATE INDEX idx_wi_status         ON workflow.workflow_instances(status);
CREATE INDEX idx_wi_step           ON workflow.workflow_instances(current_step_id);

CREATE TABLE workflow.instance_checklist_items (
    id              BIGSERIAL    PRIMARY KEY,
    instance_id     BIGINT       NOT NULL REFERENCES workflow.workflow_instances(id) ON DELETE CASCADE,
    checklist_id    BIGINT       NOT NULL REFERENCES workflow.workflow_checklists(id),
    is_completed    BOOLEAN      NOT NULL DEFAULT FALSE,
    completed_by    BIGINT       REFERENCES core.users(id),
    completed_at    TIMESTAMPTZ,
    UNIQUE (instance_id, checklist_id)
);

CREATE TABLE workflow.workflow_action_logs (
    id              BIGSERIAL    PRIMARY KEY,
    instance_id     BIGINT       NOT NULL REFERENCES workflow.workflow_instances(id) ON DELETE CASCADE,
    step_id         BIGINT       REFERENCES workflow.workflow_steps(id),
    action_code     VARCHAR(30)  NOT NULL,
    performed_by    BIGINT       REFERENCES core.users(id),
    comments        TEXT,
    from_status     VARCHAR(30),
    to_status       VARCHAR(30),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_wal_instance ON workflow.workflow_action_logs(instance_id, created_at);

CREATE TABLE workflow.workflow_event_hooks (
    id              BIGSERIAL    PRIMARY KEY,
    definition_id   BIGINT       NOT NULL REFERENCES workflow.workflow_definitions(id) ON DELETE CASCADE,
    event_type      VARCHAR(60)  NOT NULL,
    -- INSTANCE_CREATED | STEP_COMPLETED | INSTANCE_COMPLETED | STEP_OVERDUE
    hook_action     VARCHAR(60)  NOT NULL,
    -- NOTIFY_INITIATOR | NOTIFY_APPROVER | NOTIFY_HR | CALL_WEBHOOK
    config          JSONB        NOT NULL DEFAULT '{}',
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE
);
