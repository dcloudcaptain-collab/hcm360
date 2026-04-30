-- ================================================================
-- HCM360 — 68: ENTERPRISE LOGIN BRANDING
--
-- Adds branding keys that control the new enterprise login page:
--   login_wallpaper_url   — public URL or /static path for background
--   login_tagline         — short marketing line shown below the title
--   login_powered_by      — footer attribution (default: CXTech Solutions)
--   login_show_wallpaper  — "true"/"false" toggle for fast A/B
--
-- Also registers a /admin/branding page for HR/SUPER_ADMIN to edit
-- every branding key from the UI.
-- ================================================================
SET search_path TO core, public;

-- New branding keys (idempotent; value defaults are safe on re-apply)
INSERT INTO core.company_branding (key, value) VALUES
    ('login_wallpaper_url',
     '/static/img/login-wallpaper.svg'),
    ('login_tagline',
     'Intelligent HR for the Public Sector & Growing Enterprises'),
    ('login_powered_by',
     'CXTech Solutions'),
    ('login_show_wallpaper',
     'true')
ON CONFLICT (key) DO NOTHING;


-- Page registry entry for the new admin page
INSERT INTO core.page_registry
    (path, title, module, nav_group, nav_label, nav_icon, nav_order, is_visible)
VALUES
    ('/admin/branding', 'Branding & Login',
     'admin', 'Administration', 'Branding & Login',
     'palette', 92, TRUE)
ON CONFLICT (path) DO NOTHING;

-- Role grants — admins only
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
  FROM core.page_registry p
  CROSS JOIN (VALUES ('SUPER_ADMIN'), ('HR_ADMIN')) AS r(role_code)
 WHERE p.path = '/admin/branding'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, FALSE
  FROM core.page_registry p
  CROSS JOIN (VALUES ('MANAGER'), ('EMPLOYEE'), ('EXECUTIVE')) AS r(role_code)
 WHERE p.path = '/admin/branding'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = FALSE;
