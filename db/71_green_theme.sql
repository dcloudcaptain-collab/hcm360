-- ================================================================
-- HCM360 — 71: NEW UI THEME — "Civic Green"
--
-- Adds a sixth theme to core.ui_themes using the requested palette:
--   Primary   : #006E00
--   Secondary : #0A640A
--   Accent    : #00780A
--   Dark      : #004D00   (used as the sidebar background)
--
-- Complementary values are picked to match an enterprise-grade green
-- identity (think LGU / DepEd / DOH). The theme is inserted INACTIVE
-- — admins activate it via /admin/themes.
-- ================================================================
SET search_path TO core, public;

INSERT INTO core.ui_themes
    (name, is_active,
     primary_color, secondary_color, accent_color,
     bg_color, card_color, sidebar_color, sidebar_text,
     text_color, border_radius, font_family)
VALUES
    ('Civic Green', FALSE,
     '#006E00',     -- primary
     '#0A640A',     -- secondary (hover / secondary CTA)
     '#00780A',     -- accent (badges, highlights)
     '#f3f8f2',     -- app body background (very pale green tint)
     '#ffffff',     -- card background
     '#004D00',     -- sidebar background (the requested Dark)
     '#e8f5e4',     -- sidebar text (soft mint for contrast)
     '#0f172a',     -- body text
     '8px',
     'Inter, system-ui, sans-serif')
ON CONFLICT (name) DO UPDATE SET
    primary_color   = EXCLUDED.primary_color,
    secondary_color = EXCLUDED.secondary_color,
    accent_color    = EXCLUDED.accent_color,
    bg_color        = EXCLUDED.bg_color,
    card_color      = EXCLUDED.card_color,
    sidebar_color   = EXCLUDED.sidebar_color,
    sidebar_text    = EXCLUDED.sidebar_text,
    text_color      = EXCLUDED.text_color,
    border_radius   = EXCLUDED.border_radius,
    font_family     = EXCLUDED.font_family;
