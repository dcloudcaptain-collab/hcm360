-- ================================================================
-- HCM360 — 66: SELF-SERVICE ACCESS REQUEST QUEUE
--
-- When an employee hits a 403 Forbidden page, a friendly modal
-- lets them request access. This table stores the request,
-- /admin/access-requests surfaces a queue to SUPER_ADMIN/HR_ADMIN,
-- and a task is auto-pushed to every admin's inbox.
--
-- States: PENDING → GRANTED | DENIED  (reviewer_id + reviewed_at stamped)
-- ================================================================
SET search_path TO core, public;

CREATE TABLE IF NOT EXISTS core.access_requests (
    id                 BIGSERIAL   PRIMARY KEY,
    requester_user_id  BIGINT      NOT NULL REFERENCES core.users(id) ON DELETE CASCADE,
    requested_path     VARCHAR(300) NOT NULL,
    requested_module   VARCHAR(80),
    page_title         VARCHAR(200),
    reason             TEXT,
    status             VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                       CHECK (status IN ('PENDING','GRANTED','DENIED','CANCELLED')),
    reviewer_id        BIGINT      REFERENCES core.users(id),
    reviewed_at        TIMESTAMPTZ,
    review_notes       TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_acc_req_status      ON core.access_requests (status);
CREATE INDEX IF NOT EXISTS idx_acc_req_requester   ON core.access_requests (requester_user_id);
CREATE INDEX IF NOT EXISTS idx_acc_req_path        ON core.access_requests (requested_path);


-- ── Page registry + role access ────────────────────────────────
INSERT INTO core.page_registry
    (path, title, module, nav_group, nav_label, nav_icon, nav_order, is_visible)
VALUES
    ('/admin/access-requests', 'Access Requests', 'admin',
     'Administration', 'Access Requests', 'key', 96, TRUE)
ON CONFLICT (path) DO NOTHING;

INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
  FROM core.page_registry p
  CROSS JOIN (VALUES ('SUPER_ADMIN'), ('HR_ADMIN')) AS r(role_code)
 WHERE p.path = '/admin/access-requests'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, FALSE
  FROM core.page_registry p
  CROSS JOIN (VALUES ('MANAGER'), ('EMPLOYEE'), ('EXECUTIVE')) AS r(role_code)
 WHERE p.path = '/admin/access-requests'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = FALSE;


-- ── Notification templates ─────────────────────────────────────
INSERT INTO notifications.ntf_templates
    (template_code, module, event_type, channel_id, subject_template, body_template)
VALUES
    ('access_request_submitted', 'admin', 'ACCESS_REQUEST',
     (SELECT id FROM notifications.ntf_channels WHERE code = 'IN_APP' LIMIT 1),
     'Access request — {{requester_name}}',
     '{{requester_name}} is requesting access to {{requested_path}}. Reason: {{reason}}'),
    ('access_request_granted', 'admin', 'ACCESS_GRANTED',
     (SELECT id FROM notifications.ntf_channels WHERE code = 'IN_APP' LIMIT 1),
     'Access granted — {{requested_path}}',
     'Your request to access {{requested_path}} has been granted by {{reviewer_name}}. You may now proceed.'),
    ('access_request_denied', 'admin', 'ACCESS_DENIED',
     (SELECT id FROM notifications.ntf_channels WHERE code = 'IN_APP' LIMIT 1),
     'Access denied — {{requested_path}}',
     'Your request to access {{requested_path}} was denied. {{review_notes}}')
ON CONFLICT (template_code) DO UPDATE SET
    subject_template = EXCLUDED.subject_template,
    body_template    = EXCLUDED.body_template;


-- ── data-hint tooltip seeds (if page uses registry-driven hints) ──
-- (The 403 template + admin queue use inline data-hint attributes.)
