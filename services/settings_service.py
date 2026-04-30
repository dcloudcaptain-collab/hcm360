from services.db import get_cursor


# Default values used when a key has never been written to the DB yet.
BRANDING_DEFAULTS = {
    'company_name':          'HCM360',
    'short_name':            'HCM360',
    'tagline':               'Intelligent HR for Growing Enterprises',
    'primary_color':         '#1e40af',
    'logo_text':             'HCM360',
    'login_wallpaper_url':   '/static/img/login-wallpaper.svg',
    'login_tagline':         'Intelligent HR for the Public Sector & Growing Enterprises',
    'login_powered_by':      'CXTech Solutions',
    'login_show_wallpaper':  'true',
}

# Keys the /admin/branding form exposes (ordered for the form layout).
EDITABLE_BRANDING_KEYS = [
    'company_name', 'short_name', 'tagline', 'primary_color', 'logo_text',
    'login_wallpaper_url', 'login_tagline', 'login_powered_by',
    'login_show_wallpaper',
]


def get_branding():
    """Return a dict of every branding key, merged with defaults."""
    with get_cursor() as cur:
        cur.execute('SELECT key, value FROM core.company_branding ORDER BY key')
        rows = cur.fetchall()
    merged = dict(BRANDING_DEFAULTS)
    for r in (rows or []):
        if r['value'] is not None and r['value'] != '':
            merged[r['key']] = r['value']
    return merged


def save_branding(key, value):
    """Upsert one branding key. `value=None` or '' deletes the row so the
    default kicks back in."""
    with get_cursor(commit=True) as cur:
        if value is None or value == '':
            cur.execute('DELETE FROM core.company_branding WHERE key = %s', (key,))
            return
        cur.execute("""
            INSERT INTO core.company_branding (key, value)
            VALUES (%s, %s)
            ON CONFLICT (key) DO UPDATE SET
                value = EXCLUDED.value,
                updated_at = NOW()
        """, (key, value))


def save_branding_bulk(form_dict):
    """Save every editable key present in `form_dict`."""
    for k in EDITABLE_BRANDING_KEYS:
        if k in form_dict:
            save_branding(k, (form_dict.get(k) or '').strip())
