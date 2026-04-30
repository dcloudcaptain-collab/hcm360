from services.db import get_cursor


def _wrap_theme(row):
    """Add a synthetic .properties dict so templates work with both schemas."""
    if row is None:
        return None
    d = dict(row)
    d['properties'] = {
        'primary_color':   d.get('primary_color')   or '#0f6f8f',
        'secondary_color': d.get('secondary_color') or '#5fa8c6',
        'accent_color':    d.get('accent_color')    or '#5fa8c6',
        'bg_color':        d.get('bg_color')        or '#f4f7fb',
        'card_color':      d.get('card_color')      or '#ffffff',
        'sidebar_color':   d.get('sidebar_color')   or '#0f6f8f',
        'sidebar_text':    d.get('sidebar_text')    or '#e2f1f7',
        'text_color':      d.get('text_color')      or '#173042',
        'border_radius':   d.get('border_radius')   or '8px',
        'font_family':     d.get('font_family')     or 'Inter, "Segoe UI", Arial, sans-serif',
    }
    return d


def get_active_theme():
    """Global active theme (fallback when user has no preference)."""
    with get_cursor() as cur:
        cur.execute('SELECT * FROM core.ui_themes WHERE is_active=TRUE ORDER BY id DESC LIMIT 1')
        return _wrap_theme(cur.fetchone())


def get_user_theme(user_id):
    """Resolve theme for a specific user: user preference → global active → defaults."""
    with get_cursor() as cur:
        # 1. User's chosen theme
        cur.execute("""
            SELECT t.* FROM core.ui_themes t
            JOIN core.users u ON u.theme_id = t.id
            WHERE u.id = %s AND u.theme_id IS NOT NULL
        """, (user_id,))
        row = cur.fetchone()
        if row:
            return _wrap_theme(row)
        # 2. Fall back to global active
        return get_active_theme()


def set_user_theme(user_id, theme_id):
    """Set a user's preferred theme. Pass None to reset to global."""
    with get_cursor(commit=True) as cur:
        cur.execute('UPDATE core.users SET theme_id = %s WHERE id = %s', (theme_id, user_id))


def list_themes():
    with get_cursor() as cur:
        cur.execute("""
            SELECT id, name, is_active, primary_color, secondary_color,
                   accent_color, sidebar_color, sidebar_text, bg_color,
                   card_color, text_color, font_family, border_radius
            FROM core.ui_themes ORDER BY id
        """)
        return cur.fetchall()


def activate_theme(theme_id):
    """Set the global active theme (admin action)."""
    with get_cursor(commit=True) as cur:
        cur.execute('UPDATE core.ui_themes SET is_active=FALSE')
        cur.execute('UPDATE core.ui_themes SET is_active=TRUE WHERE id=%s', (theme_id,))
