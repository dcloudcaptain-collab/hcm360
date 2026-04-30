"""
Insights Service

Powers the Insights Library (/admin/insights-library) and the
personal Analytics page (/analytics). Each insight is a row in
analytics.insight_library with a canned base_sql that returns
(label, value) pairs. Users can pin insights they want to see.
"""
from services.db import get_cursor


# ── Library listing ────────────────────────────────────────────────
def list_library(role_code, user_id):
    """Every active insight visible to this role, with an
    `is_pinned` boolean so the catalog UI can pre-check boxes."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT il.id, il.code, il.title, il.description,
                   il.category, il.icon, il.chart_type, il.color_scheme,
                   il.required_roles, il.default_pinned, il.sort_order,
                   (ui.user_id IS NOT NULL) AS is_pinned
              FROM analytics.insight_library il
              LEFT JOIN analytics.user_insights ui
                     ON ui.insight_code = il.code AND ui.user_id = %s
             WHERE il.is_active = TRUE
               AND %s = ANY(il.required_roles)
             ORDER BY il.category, il.sort_order, il.title
        """, (user_id, role_code))
        return cur.fetchall()


# ── Pinned for this user ───────────────────────────────────────────
def get_pinned(user_id, role_code):
    """Returns the user's pinned insights in sort_order.
    If user has no pins, returns the default_pinned set."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT il.code, il.title, il.description,
                   il.category, il.icon, il.chart_type, il.color_scheme
              FROM analytics.insight_library il
              JOIN analytics.user_insights ui
                ON ui.insight_code = il.code AND ui.user_id = %s
             WHERE il.is_active = TRUE
               AND %s = ANY(il.required_roles)
             ORDER BY ui.sort_order, il.sort_order, il.title
        """, (user_id, role_code))
        rows = cur.fetchall()
        if rows:
            return rows
        # Fall back to default-pinned
        cur.execute("""
            SELECT il.code, il.title, il.description,
                   il.category, il.icon, il.chart_type, il.color_scheme
              FROM analytics.insight_library il
             WHERE il.is_active = TRUE
               AND il.default_pinned = TRUE
               AND %s = ANY(il.required_roles)
             ORDER BY il.sort_order, il.title
        """, (role_code,))
        return cur.fetchall()


# ── Pin / unpin ────────────────────────────────────────────────────
def toggle(user_id, insight_code, enabled):
    """Idempotent. When `enabled` is True, inserts the pin; False, deletes."""
    with get_cursor(commit=True) as cur:
        # Validate the insight exists + is visible to the user's role —
        # but we don't have role here, so just ensure it exists.
        cur.execute("""
            SELECT 1 FROM analytics.insight_library WHERE code = %s AND is_active = TRUE
        """, (insight_code,))
        if not cur.fetchone():
            return False

        if enabled:
            cur.execute("""
                INSERT INTO analytics.user_insights (user_id, insight_code, sort_order)
                VALUES (%s, %s, 100)
                ON CONFLICT (user_id, insight_code) DO NOTHING
            """, (user_id, insight_code))
        else:
            cur.execute("""
                DELETE FROM analytics.user_insights
                 WHERE user_id = %s AND insight_code = %s
            """, (user_id, insight_code))
        return True


def pinned_count(user_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT COUNT(*) AS n FROM analytics.user_insights WHERE user_id = %s
        """, (user_id,))
        return cur.fetchone()['n']


# ── Execute one insight's SQL ──────────────────────────────────────
def run_insight(code):
    """Run the insight's base_sql and return a dict ready for Chart.js:
        { code, title, chart_type, color_scheme,
          labels: [...], values: [...], error: None|str }
    Wraps exceptions so a single broken insight can't kill the dashboard.
    """
    with get_cursor() as cur:
        cur.execute("""
            SELECT code, title, chart_type, color_scheme, icon,
                   category, description, base_sql
              FROM analytics.insight_library
             WHERE code = %s AND is_active = TRUE
        """, (code,))
        row = cur.fetchone()
        if not row:
            return None

    meta = dict(row)
    base = dict(meta)
    base.pop('base_sql', None)

    try:
        with get_cursor() as cur:
            cur.execute(meta['base_sql'])
            rows = cur.fetchall()
        labels, values = [], []
        for r in rows:
            labels.append(str(r['label']) if r['label'] is not None else '')
            v = r['value']
            # Cast decimal.Decimal / int to float for JSON-safe Chart.js
            if v is None:
                values.append(0)
            else:
                try:
                    values.append(float(v))
                except Exception:
                    values.append(0)
        base['labels'] = labels
        base['values'] = values
        base['error']  = None
    except Exception as e:
        base['labels'] = []
        base['values'] = []
        base['error']  = str(e)
    return base


def run_many(codes):
    """Convenience — returns a list of rendered insights, preserving order."""
    out = []
    for c in codes:
        r = run_insight(c)
        if r:
            out.append(r)
    return out
