-- ================================================================
-- HCM360 HRIS — 03: NOTIFICATIONS SCHEMA
-- Schema    : notifications
-- Contains  : channels, templates, queue, in-app bell notifications
-- ================================================================

SET search_path TO notifications, core, public;

CREATE TABLE notifications.ntf_channels (
    id          BIGSERIAL    PRIMARY KEY,
    code        VARCHAR(30)  NOT NULL UNIQUE,
    name        VARCHAR(100) NOT NULL,
    config      JSONB        NOT NULL DEFAULT '{}',
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE
);

INSERT INTO notifications.ntf_channels (code, name, is_active) VALUES
    ('IN_APP',  'In-App Notification', TRUE),
    ('EMAIL',   'Email',               FALSE),
    ('SMS',     'SMS',                 FALSE),
    ('WEBHOOK', 'Webhook',             FALSE);

CREATE TABLE notifications.ntf_templates (
    id              BIGSERIAL    PRIMARY KEY,
    template_code   VARCHAR(60)  NOT NULL UNIQUE,
    module          VARCHAR(50)  NOT NULL,
    event_type      VARCHAR(100) NOT NULL,
    channel_id      BIGINT       NOT NULL REFERENCES notifications.ntf_channels(id),
    subject_template TEXT,
    body_template   TEXT         NOT NULL,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

INSERT INTO notifications.ntf_templates (template_code, module, event_type, channel_id, subject_template, body_template) VALUES
    ('leave_submitted',    'leave_mgmt', 'LEAVE_SUBMITTED',    1, 'Leave Request Filed',   'Your leave request ({{days}} days) has been submitted for approval.'),
    ('leave_approved',     'leave_mgmt', 'LEAVE_APPROVED',     1, 'Leave Request Approved','Your leave request from {{date_from}} to {{date_to}} has been approved.'),
    ('leave_rejected',     'leave_mgmt', 'LEAVE_REJECTED',     1, 'Leave Request Rejected','Your leave request has been rejected. Reason: {{reason}}'),
    ('leave_pending_mgr',  'leave_mgmt', 'LEAVE_PENDING_MGR',  1, 'Leave Needs Your Approval','{{employee_name}} has filed a leave request ({{days}} days). Please review.'),
    ('ot_submitted',       'attendance', 'OT_SUBMITTED',       1, 'OT Request Filed',      'Your overtime request for {{date}} ({{hours}} hrs) has been submitted.'),
    ('ot_approved',        'attendance', 'OT_APPROVED',        1, 'OT Request Approved',   'Your overtime request for {{date}} has been approved.'),
    ('payroll_payslip',    'payroll',    'PAYSLIP_READY',       1, 'Your Payslip is Ready', 'Your payslip for {{period}} is now available.'),
    ('wf_action_required', 'workflow',   'ACTION_REQUIRED',    1, 'Action Required',       'A workflow item requires your action: {{workflow_name}} — {{reference_no}}');

CREATE TABLE notifications.ntf_queue (
    id                  BIGSERIAL    PRIMARY KEY,
    template_id         BIGINT       REFERENCES notifications.ntf_templates(id),
    recipient_user_id   BIGINT       REFERENCES core.users(id),
    recipient_email     VARCHAR(200),
    payload             JSONB        NOT NULL DEFAULT '{}',
    status              VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    priority            INTEGER      NOT NULL DEFAULT 5,
    scheduled_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    sent_at             TIMESTAMPTZ,
    error_msg           TEXT,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ntfq_status    ON notifications.ntf_queue(status, scheduled_at);
CREATE INDEX idx_ntfq_user      ON notifications.ntf_queue(recipient_user_id, status);

CREATE TABLE notifications.ntf_in_app (
    id              BIGSERIAL    PRIMARY KEY,
    user_id         BIGINT       NOT NULL REFERENCES core.users(id),
    title           VARCHAR(200) NOT NULL,
    body            TEXT         NOT NULL,
    action_url      VARCHAR(500),
    is_read         BOOLEAN      NOT NULL DEFAULT FALSE,
    read_at         TIMESTAMPTZ,
    module          VARCHAR(50),
    entity_type     VARCHAR(60),
    entity_id       BIGINT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ntf_in_app_user_unread ON notifications.ntf_in_app(user_id, is_read)
    WHERE NOT is_read;
CREATE INDEX idx_ntf_in_app_user        ON notifications.ntf_in_app(user_id, created_at DESC);
