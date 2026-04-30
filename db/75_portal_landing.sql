-- ================================================================
-- HCM360 — 75: PORTAL-STYLE LANDING PAGE
--
-- New table:
--   core.user_preferences (k/v) — generic per-user settings, used by
--   the /portal landing toggle, future toggles, etc.
--
-- Page registry:
--   /portal — alternate landing page (tile-grid launcher of every
--             page the user can access + left-rail inbox panel).
--             Visible to all 5 roles.
-- ================================================================
SET search_path TO core, public;


-- ── Generic per-user preferences ──────────────────────────────
CREATE TABLE IF NOT EXISTS core.user_preferences (
    id          BIGSERIAL    PRIMARY KEY,
    user_id     BIGINT       NOT NULL REFERENCES core.users(id) ON DELETE CASCADE,
    pref_key    VARCHAR(60)  NOT NULL,
    pref_value  TEXT,
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, pref_key)
);
CREATE INDEX IF NOT EXISTS idx_user_prefs_user ON core.user_preferences (user_id);
CREATE INDEX IF NOT EXISTS idx_user_prefs_key  ON core.user_preferences (pref_key);


-- ── Page registry — /portal as a quick-link in Self-Service ───
INSERT INTO core.page_registry
    (path, title, module, nav_group, nav_label, nav_icon, nav_order, is_visible)
VALUES
    ('/portal', 'Portal', 'core',
     'Self-Service', 'Portal Launcher', 'grid', 5, TRUE)
ON CONFLICT (path) DO UPDATE SET
    title       = EXCLUDED.title,
    nav_group   = EXCLUDED.nav_group,
    nav_label   = EXCLUDED.nav_label,
    nav_icon    = EXCLUDED.nav_icon,
    nav_order   = EXCLUDED.nav_order,
    is_visible  = EXCLUDED.is_visible;


-- All 5 roles get access — the portal IS the launcher, role-filtered
-- internally per-tile.
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
  FROM core.page_registry p
  CROSS JOIN (VALUES ('SUPER_ADMIN'),('HR_ADMIN'),('MANAGER'),('EMPLOYEE'),('EXECUTIVE')) AS r(role_code)
 WHERE p.path = '/portal'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;
