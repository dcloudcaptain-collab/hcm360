from services.db import get_cursor
import psycopg2


# ─────────────────────────────────────────────────────────────────
# Dashboard metrics (KPI tiles on /)
# ─────────────────────────────────────────────────────────────────

def get_dashboard_metrics(role_code=None, user_id=None):
    """
    Returns dashboard KPI cards from core.dashboard_metrics.

    If `user_id` is provided AND the user has pinned any metrics in
    core.user_dashboard_pins, only those pins are returned — in the
    user's pin order — respecting role visibility.

    If `user_id` is provided but the user has NO pins, the classic
    role-filtered list is returned (first-time users see a populated
    dashboard out of the box).
    """
    with get_cursor() as cur:
        # Does this user have pins?
        if user_id is not None:
            cur.execute(
                "SELECT COUNT(*) AS n FROM core.user_dashboard_pins WHERE user_id = %s",
                (user_id,),
            )
            has_pins = (cur.fetchone() or {}).get('n', 0) > 0
        else:
            has_pins = False

        if has_pins:
            cur.execute("""
                SELECT m.code, m.label, m.icon, m.module, m.category, m.description,
                       m.sql_query, m.filter_url, m.sort_order
                  FROM core.dashboard_metrics m
                  JOIN core.user_dashboard_pins p
                       ON p.metric_code = m.code AND p.user_id = %s
                 WHERE m.is_active = TRUE
                   AND (%s = ANY(m.roles) OR 'ALL' = ANY(m.roles))
                 ORDER BY p.sort_order, m.sort_order, m.code
            """, (user_id, role_code or ''))
        elif role_code:
            cur.execute("""
                SELECT code, label, icon, module, category, description,
                       sql_query, filter_url, sort_order
                  FROM core.dashboard_metrics
                 WHERE is_active = TRUE
                   AND (%s = ANY(roles) OR 'ALL' = ANY(roles))
                 ORDER BY sort_order, code
            """, (role_code,))
        else:
            cur.execute("""
                SELECT code, label, icon, module, category, description,
                       sql_query, filter_url, sort_order
                  FROM core.dashboard_metrics
                 WHERE is_active = TRUE
                 ORDER BY sort_order, code
            """)
        metrics_meta = cur.fetchall()

        results = []
        for m in metrics_meta:
            value = '--'
            try:
                cur.execute(m['sql_query'])
                row = cur.fetchone()
                value = list(row.values())[0] if row else 0
            except psycopg2.errors.ProgrammingError:
                try:
                    cur.connection.rollback()
                except Exception:
                    pass
                value = '--'
            except Exception:
                value = '--'

            results.append({
                'code':        m['code'],
                'label':       m['label'],
                'icon':        m['icon'],
                'module':      m['module'],
                'category':    m.get('category') if isinstance(m, dict) else m['category'],
                'description': m.get('description') if isinstance(m, dict) else m['description'],
                'value':       value,
                'filter_url':  m['filter_url'],
                'trend':       None,
            })
        return results


# ─────────────────────────────────────────────────────────────────
# Library + pin management (powers /dashboard/manage)
# ─────────────────────────────────────────────────────────────────

def list_dashboard_library(role_code, user_id):
    """Every role-appropriate KPI in the library, flagged is_pinned."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT m.id, m.code, m.label, m.icon, m.module, m.category,
                   m.description, m.filter_url, m.roles, m.sort_order,
                   (p.user_id IS NOT NULL) AS is_pinned
              FROM core.dashboard_metrics m
              LEFT JOIN core.user_dashboard_pins p
                     ON p.metric_code = m.code AND p.user_id = %s
             WHERE m.is_active = TRUE
               AND (%s = ANY(m.roles) OR 'ALL' = ANY(m.roles))
             ORDER BY m.category, m.sort_order, m.code
        """, (user_id, role_code))
        return cur.fetchall()


def toggle_dashboard_pin(user_id, metric_code, enabled):
    """Idempotent pin/unpin."""
    with get_cursor(commit=True) as cur:
        cur.execute(
            "SELECT 1 FROM core.dashboard_metrics WHERE code = %s AND is_active = TRUE",
            (metric_code,),
        )
        if not cur.fetchone():
            return False

        if enabled:
            cur.execute("""
                INSERT INTO core.user_dashboard_pins (user_id, metric_code, sort_order)
                VALUES (%s, %s, 100)
                ON CONFLICT (user_id, metric_code) DO NOTHING
            """, (user_id, metric_code))
        else:
            cur.execute("""
                DELETE FROM core.user_dashboard_pins
                 WHERE user_id = %s AND metric_code = %s
            """, (user_id, metric_code))
        return True


def dashboard_pin_count(user_id):
    with get_cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) AS n FROM core.user_dashboard_pins WHERE user_id = %s",
            (user_id,),
        )
        return cur.fetchone()['n']


# ─────────────────────────────────────────────────────────────────
# KPI snapshots (unchanged)
# ─────────────────────────────────────────────────────────────────

def get_kpi_snapshot(module=None, kpi_code=None):
    """Pull today's KPI snapshot from analytics schema."""
    with get_cursor() as cur:
        if module and kpi_code:
            cur.execute("""
                SELECT kpi_code, kpi_label, kpi_value, snapshot_date
                FROM analytics.kpi_snapshots
                WHERE module=%s AND kpi_code=%s
                  AND snapshot_date = CURRENT_DATE
                ORDER BY created_at DESC LIMIT 1
            """, (module, kpi_code))
        elif module:
            cur.execute("""
                SELECT kpi_code, kpi_label, kpi_value, snapshot_date
                FROM analytics.kpi_snapshots
                WHERE module=%s AND snapshot_date=CURRENT_DATE
                ORDER BY kpi_code
            """, (module,))
        else:
            cur.execute("""
                SELECT module, kpi_code, kpi_label, kpi_value, snapshot_date
                FROM analytics.kpi_snapshots
                WHERE snapshot_date=CURRENT_DATE
                ORDER BY module, kpi_code
            """)
        return cur.fetchall()
