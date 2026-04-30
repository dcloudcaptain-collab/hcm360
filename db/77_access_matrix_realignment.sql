-- ================================================================
-- HCM360 — 77: ACCESS MATRIX MODULE REALIGNMENT
--
-- The /admin/access-matrix UI groups pages by `core.page_registry.module`,
-- driven by the MODULES list in services/access_service.py. Several pages
-- carried module values that either:
--   • didn't exist in MODULES at all (`learning` orphan), or
--   • were lumped under generic 'core' when a domain-specific module
--     fits better (e.g. /retirement/ as compensation, /travel-orders/
--     as leave management).
--
-- Result before this migration:
--   • /learning/nrf was invisible in the access matrix entirely.
--   • /locator-slips/, /travel-orders/, /retirement/, /step-increments/
--     showed up under "Core" instead of their actual domain tab.
--   • /lgu-contracts/, /pds/ showed under "Core" instead of "201 File".
--   • /me/pds, /me/saln showed under "Core" instead of "ESS/MSS".
--
-- This migration normalises every visible page's `module` so that:
--   • every page maps to exactly one MODULES tab,
--   • the tab the page lands under matches the user's mental model
--     (and the new sidebar nav_group taxonomy from migration 76).
-- ================================================================
BEGIN;

-- ── Orphan: 'learning' module isn't in MODULES; merge into 'ld' ───
UPDATE core.page_registry SET module = 'ld'
 WHERE path = '/learning/nrf';

-- ── /retirement/, /step-increments/ → compensation/rewards ───────
UPDATE core.page_registry SET module = 'rr'
 WHERE path IN ('/retirement/', '/step-increments/');

-- ── /travel-orders/, /locator-slips/ → leave management ──────────
UPDATE core.page_registry SET module = 'leave_mgmt'
 WHERE path IN ('/travel-orders/', '/locator-slips/');

-- ── /lgu-contracts/, /pds/ → 201 File (DMS) ──────────────────────
UPDATE core.page_registry SET module = 'dms'
 WHERE path IN ('/lgu-contracts/', '/pds/');

-- ── Self-service views of own records → ESS/MSS ──────────────────
UPDATE core.page_registry SET module = 'ess_mss'
 WHERE path IN ('/me/pds', '/me/saln');

-- ── Sanity: any visible pages with NULL module? ──────────────────
-- (Informational only; if rows return, they need explicit assignment.)
-- SELECT path, nav_label FROM core.page_registry
--  WHERE is_visible = TRUE AND (module IS NULL OR module = '');

COMMIT;
