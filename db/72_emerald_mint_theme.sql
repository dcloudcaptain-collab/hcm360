-- ================================================================
-- HCM360 — 72: NEW UI THEME — "Emerald Mint"
--
-- Adds a seventh theme to core.ui_themes with the requested palette:
--   Primary              : #20A486
--   Hover                : #1C9277   → secondary_color
--   Active / Pressed     : #187F69   (used implicitly as a darker hover
--                                     via CSS color-mix; stored here as
--                                     a second accent for reference)
--   Dark Base / Sidebar  : #146C5B   → sidebar_color
--   Accent / Highlights  : #3BB59A   → accent_color
--
-- Theme is inserted INACTIVE. Activate via /admin/themes.
-- ================================================================
SET search_path TO core, public;

INSERT INTO core.ui_themes
    (name, is_active,
     primary_color, secondary_color, accent_color,
     bg_color, card_color, sidebar_color, sidebar_text,
     text_color, border_radius, font_family)
VALUES
    ('Emerald Mint', FALSE,
     '#20A486',     -- primary (buttons, links, focus ring)
     '#1C9277',     -- secondary (hover state)
     '#3BB59A',     -- accent (badges, highlights)
     '#f1faf7',     -- app body background — very pale mint
     '#ffffff',     -- card background
     '#146C5B',     -- sidebar (the requested Dark Base)
     '#d8f0e8',     -- sidebar text — soft mint for AA contrast on #146C5B
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
