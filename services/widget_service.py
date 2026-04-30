"""
Widget Service

Powers the Dashboard Widget Library (/dashboard/widgets) and the
widget grid rendered on `/`. Each widget is a row in core.widget_library
with a canned base_sql + JSONB columns_meta describing how to render
its rows. Users pin widgets they want to see.

Columns meta shape (per column):
    {
      "label": "Employee",         # th text
      "field": "employee",          # key in the SELECT row
      "type":  "text"|"muted"|"mono"|"int"|"badge",
      "badge_map": {"PENDING": "amber", ...}   # only for type=badge
    }
"""
import psycopg2
from services.db import get_cursor


# ── Library listing ────────────────────────────────────────────────
def list_library(role_code, user_id):
    """Every active widget visible to this role, with `is_pinned` flag."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT wl.id, wl.code, wl.title, wl.description, wl.category,
                   wl.icon, wl.render_mode, wl.link_url, wl.link_label,
                   wl.required_roles, wl.default_pinned, wl.sort_order,
                   wl.max_rows,
                   (p.user_id IS NOT NULL) AS is_pinned
              FROM core.widget_library wl
              LEFT JOIN core.user_widget_pins p
                     ON p.widget_code = wl.code AND p.user_id = %s
             WHERE wl.is_active = TRUE
               AND %s = ANY(wl.required_roles)
             ORDER BY wl.category, wl.sort_order, wl.title
        """, (user_id, role_code))
        return cur.fetchall()


# ── Pinned widgets for a user ──────────────────────────────────────
def get_pinned(user_id, role_code):
    """Return user's pinned widgets. If none, return default-pinned set."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT wl.code, wl.title, wl.description, wl.category,
                   wl.icon, wl.render_mode, wl.base_sql, wl.columns_meta,
                   wl.link_url, wl.link_label, wl.max_rows
              FROM core.widget_library wl
              JOIN core.user_widget_pins p
                ON p.widget_code = wl.code AND p.user_id = %s
             WHERE wl.is_active = TRUE
               AND %s = ANY(wl.required_roles)
             ORDER BY p.sort_order, wl.sort_order, wl.title
        """, (user_id, role_code))
        rows = cur.fetchall()
        if rows:
            return rows
        cur.execute("""
            SELECT wl.code, wl.title, wl.description, wl.category,
                   wl.icon, wl.render_mode, wl.base_sql, wl.columns_meta,
                   wl.link_url, wl.link_label, wl.max_rows
              FROM core.widget_library wl
             WHERE wl.is_active = TRUE
               AND wl.default_pinned = TRUE
               AND %s = ANY(wl.required_roles)
             ORDER BY wl.sort_order, wl.title
        """, (role_code,))
        return cur.fetchall()


# ── Toggle pin (AJAX) ──────────────────────────────────────────────
def toggle(user_id, widget_code, enabled):
    with get_cursor(commit=True) as cur:
        cur.execute(
            "SELECT 1 FROM core.widget_library WHERE code = %s AND is_active = TRUE",
            (widget_code,),
        )
        if not cur.fetchone():
            return False
        if enabled:
            cur.execute("""
                INSERT INTO core.user_widget_pins (user_id, widget_code, sort_order)
                VALUES (%s, %s, 100)
                ON CONFLICT (user_id, widget_code) DO NOTHING
            """, (user_id, widget_code))
        else:
            cur.execute("""
                DELETE FROM core.user_widget_pins
                 WHERE user_id = %s AND widget_code = %s
            """, (user_id, widget_code))
        return True


def pinned_count(user_id):
    with get_cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) AS n FROM core.user_widget_pins WHERE user_id = %s",
            (user_id,),
        )
        return cur.fetchone()['n']


# ── Execute one widget — returns rows ready for the template ──────
def run_widget(widget):
    """Execute widget.base_sql; attach `.rows` (list of dicts). Never
    raises — SQL errors are captured into `.error`."""
    out = dict(widget)
    out['rows'] = []
    out['error'] = None
    if not widget.get('base_sql'):
        return out
    try:
        with get_cursor() as cur:
            cur.execute(widget['base_sql'])
            # psycopg2 RealDictRow → plain dict for Jinja
            rows = [dict(r) for r in cur.fetchall()]
        out['rows'] = rows
    except psycopg2.errors.ProgrammingError as e:
        try:
            cur.connection.rollback()
        except Exception:
            pass
        out['error'] = str(e)
    except Exception as e:
        out['error'] = str(e)
    return out


def run_many(widgets):
    """Run a list of widget rows; return list of rendered widgets."""
    return [run_widget(w) for w in widgets]
