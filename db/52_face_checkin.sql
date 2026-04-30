-- ================================================================
-- HCM360 — 52: FACE-RECOGNITION + GEOTAG CHECK-IN
--
-- Tables
--   attendance.att_face_enrollments   — 128-d face descriptor per employee
--   attendance.att_checkins           — check-in events with geo + face match
--   attendance.att_checkin_settings   — per-company configuration
--
-- Pages / Features registered so they appear in /admin/access-matrix.
-- ================================================================
SET search_path TO attendance, core, public;

-- ── Face Enrollment ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS attendance.att_face_enrollments (
    id            BIGSERIAL   PRIMARY KEY,
    employee_id   BIGINT      NOT NULL REFERENCES core.employees(id) ON DELETE CASCADE,
    descriptor    JSONB       NOT NULL,               -- 128 floats (face-api.js)
    sample_count  INT         NOT NULL DEFAULT 1,     -- how many samples averaged
    enrolled_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    enrolled_by   BIGINT      REFERENCES core.users(id),
    is_active     BOOLEAN     NOT NULL DEFAULT TRUE,
    note          TEXT,
    UNIQUE (employee_id)
);
CREATE INDEX IF NOT EXISTS idx_att_face_enr_emp
    ON attendance.att_face_enrollments (employee_id);

-- ── Check-in Events ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS attendance.att_checkins (
    id                BIGSERIAL   PRIMARY KEY,
    employee_id       BIGINT      NOT NULL REFERENCES core.employees(id),
    check_type        VARCHAR(10) NOT NULL CHECK (check_type IN ('IN', 'OUT')),
    checked_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    latitude          NUMERIC(10,7),
    longitude         NUMERIC(10,7),
    accuracy_m        NUMERIC(8,2),                   -- GPS accuracy in meters
    face_match_score  NUMERIC(5,4),                   -- 0.0 (worst) .. 1.0 (best)
    face_verified     BOOLEAN,
    geo_verified      BOOLEAN,
    device_kind       VARCHAR(20),                    -- 'laptop' / 'desktop' / 'mobile'
    device_info       JSONB,                          -- user agent, platform, etc.
    ip_address        VARCHAR(45),
    photo_path        TEXT,                           -- optional captured snapshot
    activity          VARCHAR(30),                    -- e.g., 'regular', 'flag_raising'
    notes             TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_att_checkins_emp_date
    ON attendance.att_checkins (employee_id, checked_at DESC);
CREATE INDEX IF NOT EXISTS idx_att_checkins_date
    ON attendance.att_checkins (checked_at DESC);

-- ── Settings (per company) ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS attendance.att_checkin_settings (
    company_id            BIGINT       PRIMARY KEY REFERENCES core.companies(id) ON DELETE CASCADE,
    require_face          BOOLEAN      NOT NULL DEFAULT TRUE,
    require_geotag        BOOLEAN      NOT NULL DEFAULT TRUE,
    capture_photo         BOOLEAN      NOT NULL DEFAULT FALSE,
    face_threshold        NUMERIC(4,3) NOT NULL DEFAULT 0.500, -- max Euclidean distance
    geofence_lat          NUMERIC(10,7),
    geofence_lng          NUMERIC(10,7),
    geofence_radius_m     INT          DEFAULT 200,           -- 200m default
    allowed_device_kinds  VARCHAR(100) NOT NULL DEFAULT 'laptop,desktop,mobile',
    preferred_camera      VARCHAR(20)  NOT NULL DEFAULT 'any',-- any|front|back|laptop
    activity_types        VARCHAR(200) NOT NULL DEFAULT 'regular,flag_raising,flag_lowering',
    updated_by            BIGINT       REFERENCES core.users(id),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Seed default settings row for demo company
INSERT INTO attendance.att_checkin_settings (company_id)
SELECT id FROM core.companies WHERE code = 'DEMO'
ON CONFLICT (company_id) DO NOTHING;

-- ── Page Registry Entries ──────────────────────────────────────────
INSERT INTO core.page_registry
    (path, title, module, nav_group, nav_label, nav_icon, nav_order, is_visible)
VALUES
    ('/checkin/',
        'Check-In / Check-Out',
        'attendance', 'Self-Service', 'Face Check-In', 'camera', 33, TRUE),
    ('/checkin/enroll',
        'Face Enrollment',
        'attendance', 'Self-Service', 'Face Enrollment', 'user-check', 34, FALSE),
    ('/checkin/history',
        'My Check-In History',
        'attendance', 'Self-Service', 'Check-In History', 'list', 35, FALSE),
    ('/admin/checkin-settings',
        'Check-In Settings',
        'admin', 'Administration', 'Face / Geotag Settings', 'sliders', 96, TRUE)
ON CONFLICT (path) DO NOTHING;

-- ── Feature Registry ───────────────────────────────────────────────
INSERT INTO core.feature_registry
    (code, name, description, module, is_enabled, feature_type, action_type, page_path)
VALUES
    ('CHECKIN_SUBMIT',
        'Submit Check-In',
        'Allows employees to check in/out via camera + GPS',
        'attendance', TRUE, 'ACTION', 'CREATE', '/checkin/'),
    ('CHECKIN_ENROLL_SELF',
        'Enroll Own Face',
        'Allows an employee to enroll their own face',
        'attendance', TRUE, 'ACTION', 'CREATE', '/checkin/enroll'),
    ('CHECKIN_ENROLL_OTHERS',
        'Enroll Face for Others',
        'Allows HR/Admin to enroll face on behalf of an employee',
        'attendance', TRUE, 'ACTION', 'CREATE', '/checkin/enroll'),
    ('CHECKIN_SETTINGS_EDIT',
        'Manage Check-In Settings',
        'Configure face/geotag requirements, geofence, thresholds',
        'admin', TRUE, 'ACTION', 'EDIT', '/admin/checkin-settings')
ON CONFLICT (code) DO NOTHING;

-- ── Role Access ────────────────────────────────────────────────────
-- Employees + Managers + Executives + HR + Super all can check in
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
FROM core.page_registry p
CROSS JOIN (VALUES
    ('SUPER_ADMIN'), ('HR_ADMIN'), ('MANAGER'),
    ('EMPLOYEE'), ('EXECUTIVE')
) AS r(role_code)
WHERE p.path IN ('/checkin/', '/checkin/enroll', '/checkin/history')
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

-- Admin settings page — SUPER_ADMIN + HR_ADMIN only
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
FROM core.page_registry p
CROSS JOIN (VALUES ('SUPER_ADMIN'), ('HR_ADMIN')) AS r(role_code)
WHERE p.path = '/admin/checkin-settings'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

-- Deny admin settings to others
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, FALSE
FROM core.page_registry p
CROSS JOIN (VALUES ('MANAGER'), ('EMPLOYEE'), ('EXECUTIVE')) AS r(role_code)
WHERE p.path = '/admin/checkin-settings'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = FALSE;

-- ── Role Feature Access ────────────────────────────────────────────
-- Everyone can submit + enroll own face
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.role_code, f.id, TRUE
FROM core.feature_registry f
CROSS JOIN (VALUES
    ('SUPER_ADMIN'), ('HR_ADMIN'), ('MANAGER'),
    ('EMPLOYEE'), ('EXECUTIVE')
) AS r(role_code)
WHERE f.code IN ('CHECKIN_SUBMIT', 'CHECKIN_ENROLL_SELF')
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = TRUE;

-- HR + Admin can enroll others
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.role_code, f.id, TRUE
FROM core.feature_registry f
CROSS JOIN (VALUES ('SUPER_ADMIN'), ('HR_ADMIN')) AS r(role_code)
WHERE f.code IN ('CHECKIN_ENROLL_OTHERS', 'CHECKIN_SETTINGS_EDIT')
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = TRUE;
