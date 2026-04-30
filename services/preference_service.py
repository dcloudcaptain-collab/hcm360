"""
Preference Service — generic per-user K/V store.

Backed by core.user_preferences (one row per user × key). Used by:
  * The /portal landing-mode toggle (key: 'landing_layout')
  * Future toggles (theme override, dashboard density, etc.)

Values are stored as TEXT so the caller is responsible for casting.
"""
from services.db import get_cursor


# ── Constants ──────────────────────────────────────────────────
LANDING_KEY = 'landing_layout'
LANDING_VALUES = {'portal', 'dashboard', 'profile'}


# ── Generic K/V ────────────────────────────────────────────────
def get_pref(user_id, key, default=None):
    """Return the stored string value for (user_id, key), else `default`."""
    if not user_id or not key:
        return default
    with get_cursor() as cur:
        cur.execute(
            "SELECT pref_value FROM core.user_preferences "
            " WHERE user_id = %s AND pref_key = %s LIMIT 1",
            (user_id, key),
        )
        row = cur.fetchone()
        if row is None:
            return default
        return row['pref_value'] if row['pref_value'] is not None else default


def set_pref(user_id, key, value):
    """Upsert a single preference. Empty value deletes the row so the
    caller's default kicks back in."""
    if not user_id or not key:
        return False
    if value is None or value == '':
        return delete_pref(user_id, key)
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO core.user_preferences (user_id, pref_key, pref_value)
            VALUES (%s, %s, %s)
            ON CONFLICT (user_id, pref_key) DO UPDATE SET
                pref_value = EXCLUDED.pref_value,
                updated_at = NOW()
        """, (user_id, key, str(value)))
    return True


def delete_pref(user_id, key):
    if not user_id or not key:
        return False
    with get_cursor(commit=True) as cur:
        cur.execute(
            "DELETE FROM core.user_preferences "
            " WHERE user_id = %s AND pref_key = %s",
            (user_id, key),
        )
    return True


def get_all_prefs(user_id):
    """Return dict of every preference for the user."""
    if not user_id:
        return {}
    with get_cursor() as cur:
        cur.execute(
            "SELECT pref_key, pref_value FROM core.user_preferences "
            " WHERE user_id = %s ORDER BY pref_key",
            (user_id,),
        )
        return {r['pref_key']: r['pref_value'] for r in cur.fetchall()}


# ── Landing-page sugar ─────────────────────────────────────────
def get_landing_layout(user_id):
    """Return one of LANDING_VALUES if the user has set a preference,
    else None (caller falls back to role-based default)."""
    raw = get_pref(user_id, LANDING_KEY)
    if raw and raw.lower() in LANDING_VALUES:
        return raw.lower()
    return None


def set_landing_layout(user_id, layout):
    """Persist the landing preference. `layout` must be one of
    'portal', 'dashboard', or 'profile' — anything else clears the pref."""
    if not layout or layout.lower() not in LANDING_VALUES:
        return delete_pref(user_id, LANDING_KEY)
    return set_pref(user_id, LANDING_KEY, layout.lower())
