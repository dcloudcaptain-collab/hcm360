-- ================================================================
-- HCM360 — 51: WORKFORCE PLANNING — PAGE & FEATURE REGISTRY
--
-- Registers workforce planning pages and action features so they
-- appear in the Access Matrix admin UI under "Workforce Planning".
--
-- Access: SUPER_ADMIN, HR_ADMIN, EXECUTIVE (matches _hr_required)
-- ================================================================
SET search_path TO core, public;

-- ── Pages ─────────────────────────────────────────────────────────
INSERT INTO core.page_registry
    (path, title, module, nav_group, nav_label, nav_icon, nav_order, is_visible)
VALUES
    ('/workforce-planning/',
        'Workforce Planning',
        'workforce_planning', 'Workforce', 'Workforce Planning', '📈', 60, TRUE),
    ('/workforce-planning/scenarios/new',
        'New Planning Scenario',
        'workforce_planning', 'Workforce', 'New Scenario', '➕', 61, FALSE),
    ('/workforce-planning/scenarios/',
        'Scenario Detail',
        'workforce_planning', 'Workforce', 'Scenario Detail', '🔍', 62, FALSE)
ON CONFLICT (path) DO NOTHING;

-- ── Features (action-level) ───────────────────────────────────────
INSERT INTO core.feature_registry
    (code, name, description, module, is_enabled, feature_type, action_type, page_path)
VALUES
    ('WFP_SCENARIO_CREATE',
        'Create Planning Scenario',
        'Allows creating new headcount/cost planning scenarios',
        'workforce_planning', TRUE, 'ACTION', 'CREATE', '/workforce-planning/scenarios/new'),
    ('WFP_SCENARIO_REGENERATE',
        'Regenerate Projections',
        'Recalculates headcount projections from current data',
        'workforce_planning', TRUE, 'ACTION', 'EDIT', '/workforce-planning/scenarios/'),
    ('WFP_SCENARIO_STATUS',
        'Update Scenario Status',
        'Activates, archives or closes a planning scenario',
        'workforce_planning', TRUE, 'ACTION', 'EDIT', '/workforce-planning/scenarios/'),
    ('WFP_SKILL_ADD',
        'Add Skill Demand',
        'Adds skill supply/demand gap entries to a scenario',
        'workforce_planning', TRUE, 'ACTION', 'CREATE', '/workforce-planning/scenarios/')
ON CONFLICT (code) DO NOTHING;

-- ── Role Page Access ──────────────────────────────────────────────
-- SUPER_ADMIN is bypassed in code; HR_ADMIN and EXECUTIVE get access
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, TRUE
FROM core.page_registry p
CROSS JOIN (VALUES
    ('SUPER_ADMIN'),
    ('HR_ADMIN'),
    ('EXECUTIVE')
) AS r(role_code)
WHERE p.module = 'workforce_planning'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

-- MANAGER and EMPLOYEE explicitly denied
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.role_code, p.id, FALSE
FROM core.page_registry p
CROSS JOIN (VALUES
    ('MANAGER'),
    ('EMPLOYEE')
) AS r(role_code)
WHERE p.module = 'workforce_planning'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = FALSE;

-- ── Role Feature Access ───────────────────────────────────────────
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.role_code, f.id, TRUE
FROM core.feature_registry f
CROSS JOIN (VALUES
    ('SUPER_ADMIN'),
    ('HR_ADMIN'),
    ('EXECUTIVE')
) AS r(role_code)
WHERE f.module = 'workforce_planning'
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = TRUE;

INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.role_code, f.id, FALSE
FROM core.feature_registry f
CROSS JOIN (VALUES
    ('MANAGER'),
    ('EMPLOYEE')
) AS r(role_code)
WHERE f.module = 'workforce_planning'
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = FALSE;
