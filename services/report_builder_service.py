"""
Report Builder Service — dynamic SQL generation from saved report configs.
Builds safe, parameterized queries from report_data_sources + report_field_registry.
"""
import re
from datetime import date, datetime
from services.db import get_cursor


# ---------------------------------------------------------------------------
# Field & Source Loaders
# ---------------------------------------------------------------------------

def get_data_sources():
    with get_cursor() as cur:
        cur.execute("""
            SELECT id, source_code, source_label, module, description
            FROM analytics.report_data_sources
            WHERE is_active = TRUE
            ORDER BY sort_order
        """)
        return cur.fetchall()


def get_fields_for_source(source_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT id, field_code, field_label, field_type, sql_expression,
                   is_groupable, is_filterable, is_sortable,
                   is_aggregatable, default_aggregate
            FROM analytics.report_field_registry
            WHERE source_id = %s
            ORDER BY sort_order
        """, (source_id,))
        return cur.fetchall()


def get_source(source_id):
    with get_cursor() as cur:
        cur.execute("SELECT * FROM analytics.report_data_sources WHERE id = %s", (source_id,))
        return cur.fetchone()


# ---------------------------------------------------------------------------
# Safe SQL Builder
# ---------------------------------------------------------------------------

_VALID_OPS = {'=', '!=', '>', '<', '>=', '<=', 'LIKE', 'ILIKE', 'IN', 'NOT IN', 'IS NULL', 'IS NOT NULL'}
_VALID_AGG = {'COUNT', 'SUM', 'AVG', 'MIN', 'MAX'}
_VALID_DIR = {'ASC', 'DESC'}


def _sanitize_identifier(s):
    """Allow only alphanumeric, underscore, dot — prevent injection.

    Use this ONLY for user-supplied identifiers like column aliases or
    filter field codes. DO NOT use on `sql_expression` values from
    `analytics.report_field_registry` — those are admin-defined and may
    contain operators (||), literals ('...'), function calls, etc.
    For registry-defined expressions, use `_sanitize_expression` instead.
    """
    return re.sub(r'[^a-zA-Z0-9_.]', '', str(s))


def _sanitize_expression(s):
    """
    Sanitizer for admin-defined SQL expressions from report_field_registry.

    Expressions are trusted (they come from a SUPER_ADMIN-only table), but
    we still reject anything that looks like statement injection:
      * SQL comment markers (-- /* */)
      * Semicolons (statement terminators)
      * DDL/DML keywords that should never appear in a SELECT expression
    Allowed: alphanumerics, ._()|| '' spaces, arithmetic operators,
             CASE/WHEN/ELSE/END/NULL, standard functions, etc.
    """
    if s is None:
        return 'NULL'
    text = str(s)
    # Reject obvious injection attempts
    lowered = text.lower()
    banned = [';', '--', '/*', '*/',
              ' drop ', ' delete ', ' insert ', ' update ',
              ' truncate ', ' alter ', ' grant ', ' revoke ',
              ' create ', ' execute ', ' exec ']
    for b in banned:
        if b in lowered:
            # Fall back to NULL rather than leak the expression
            return 'NULL'
    return text


def build_query(source_id, config):
    """
    Build a SQL query from a report config dict:
      config = {
        "columns":    ["field_code", ...],
        "filters":    [{"field": "x", "op": "=", "value": "v"}, ...],
        "group_by":   ["field_code", ...],
        "order_by":   [{"field": "x", "dir": "ASC"}, ...],
        "aggregates": [{"field": "x", "fn": "SUM"}, ...],
        "limit":      500
      }
    Returns: (sql_string, params_list)
    """
    source = get_source(source_id)
    if not source:
        raise ValueError(f"Data source {source_id} not found")

    fields = {f['field_code']: f for f in get_fields_for_source(source_id)}
    columns = config.get('columns', [])
    filters = config.get('filters', [])
    group_by = config.get('group_by', [])
    order_by = config.get('order_by', [])
    aggregates = config.get('aggregates', [])
    limit = min(int(config.get('limit', 5000)), 10000)

    # If no columns specified, use all
    if not columns:
        columns = list(fields.keys())

    # Validate columns exist
    valid_cols = [c for c in columns if c in fields]
    if not valid_cols:
        valid_cols = list(fields.keys())

    # Build SELECT clause
    select_parts = []
    agg_map = {a['field']: a['fn'].upper() for a in aggregates if a.get('fn', '').upper() in _VALID_AGG}
    group_set = set(group_by)

    for col in valid_cols:
        f = fields[col]
        expr = _sanitize_expression(f['sql_expression'])
        safe_alias = _sanitize_identifier(col)
        if col in agg_map:
            # Explicit aggregate requested
            select_parts.append(f"{agg_map[col]}({expr}) AS {safe_alias}")
        elif group_set and col not in group_set:
            # GROUP BY is active and this column is NOT grouped —
            # auto-apply default aggregate or COUNT
            default_fn = f.get('default_aggregate') or ('SUM' if f['field_type'] in ('NUMBER', 'CURRENCY') else 'COUNT')
            select_parts.append(f"{default_fn}({expr}) AS {safe_alias}")
        else:
            select_parts.append(f"{expr} AS {safe_alias}")

    select_clause = ', '.join(select_parts)

    # Base SQL wrapped as subquery
    base_sql = source['base_sql']

    # Build WHERE clause for filters
    where_parts = []
    params = []
    for flt in filters:
        fc = flt.get('field', '')
        op = flt.get('op', '=').upper()
        val = flt.get('value')

        if fc not in fields:
            continue
        if op not in _VALID_OPS:
            continue

        expr = _sanitize_expression(fields[fc]['sql_expression'])

        if op in ('IS NULL', 'IS NOT NULL'):
            where_parts.append(f"{expr} {op}")
        elif op in ('IN', 'NOT IN') and isinstance(val, list):
            placeholders = ', '.join(['%s'] * len(val))
            where_parts.append(f"{expr} {op} ({placeholders})")
            params.extend(val)
        elif op in ('LIKE', 'ILIKE'):
            where_parts.append(f"{expr} {op} %s")
            params.append(f"%{val}%")
        else:
            where_parts.append(f"{expr} {op} %s")
            params.append(val)

    where_clause = (' AND '.join(where_parts)) if where_parts else '1=1'

    # Build GROUP BY
    group_parts = []
    for gc in group_by:
        if gc in fields:
            group_parts.append(_sanitize_expression(fields[gc]['sql_expression']))
    group_clause = f"GROUP BY {', '.join(group_parts)}" if group_parts else ''

    # Build ORDER BY
    order_parts = []
    for ob in order_by:
        fc = ob.get('field', '')
        d = ob.get('dir', 'ASC').upper()
        if fc in fields and d in _VALID_DIR:
            order_parts.append(f"{_sanitize_expression(fields[fc]['sql_expression'])} {d}")
    order_clause = f"ORDER BY {', '.join(order_parts)}" if order_parts else ''

    sql = f"""
        SELECT {select_clause}
        FROM ({base_sql}) AS _src
        WHERE {where_clause}
        {group_clause}
        {order_clause}
        LIMIT {limit}
    """

    return sql, params


def execute_report(source_id, config):
    """Build and execute the report query, return (rows, column_order).
    Rows are plain dicts; column_order preserves the user's drag order.
    """
    sql, params = build_query(source_id, config)
    with get_cursor() as cur:
        cur.execute(sql, params)
        col_order = [desc[0] for desc in cur.description]
        result = []
        for row in cur.fetchall():
            result.append({col: row[col] for col in col_order})
        return result, col_order


# ---------------------------------------------------------------------------
# Saved Reports CRUD
# ---------------------------------------------------------------------------

def list_saved_reports(user_id=None, shared_only=False):
    conditions = ['1=1']
    params = []
    if user_id and not shared_only:
        conditions.append('(sr.created_by = %s OR sr.is_shared = TRUE)')
        params.append(user_id)
    elif shared_only:
        conditions.append('sr.is_shared = TRUE')
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT sr.*, ds.source_label, ds.source_code,
                   u.display_name AS created_by_name
            FROM analytics.saved_reports sr
            JOIN analytics.report_data_sources ds ON ds.id = sr.source_id
            LEFT JOIN core.users u ON u.id = sr.created_by
            WHERE {' AND '.join(conditions)}
            ORDER BY sr.updated_at DESC
        """, params)
        return cur.fetchall()


def get_saved_report(report_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT sr.*, ds.source_label, ds.source_code, ds.base_sql
            FROM analytics.saved_reports sr
            JOIN analytics.report_data_sources ds ON ds.id = sr.source_id
            WHERE sr.id = %s
        """, (report_id,))
        return cur.fetchone()


def save_report(data, user_id):
    import json
    config = data.get('config', {})
    if isinstance(config, str):
        config = json.loads(config)

    with get_cursor(commit=True) as cur:
        if data.get('id'):
            cur.execute("""
                UPDATE analytics.saved_reports
                SET name = %s, description = %s, source_id = %s,
                    config = %s, is_shared = %s, updated_at = NOW()
                WHERE id = %s RETURNING id
            """, (data['name'], data.get('description'), data['source_id'],
                  json.dumps(config), data.get('is_shared', False), data['id']))
        else:
            cur.execute("""
                INSERT INTO analytics.saved_reports
                    (name, description, source_id, config, created_by, is_shared)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id
            """, (data['name'], data.get('description'), data['source_id'],
                  json.dumps(config), user_id, data.get('is_shared', False)))
        return cur.fetchone()


def delete_report(report_id, user_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            DELETE FROM analytics.saved_reports
            WHERE id = %s AND (created_by = %s OR is_system = FALSE)
        """, (report_id, user_id))
        return cur.rowcount > 0


def log_report_run(report_id, user_id, fmt, row_count, file_path=None,
                   schedule_id=None, triggered_by='MANUAL'):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO analytics.report_run_history
                (report_id, schedule_id, triggered_by, output_format,
                 row_count, file_path, status, run_by, completed_at)
            VALUES (%s, %s, %s, %s, %s, %s, 'COMPLETED', %s, NOW())
            RETURNING id
        """, (report_id, schedule_id, triggered_by, fmt, row_count, file_path, user_id))
        result = cur.fetchone()
        # Update last_run on saved report
        if report_id:
            cur.execute("""
                UPDATE analytics.saved_reports
                SET last_run_at = NOW(), run_count = run_count + 1
                WHERE id = %s
            """, (report_id,))
        return result


# ---------------------------------------------------------------------------
# Schedule CRUD
# ---------------------------------------------------------------------------

def get_schedules(user_id=None):
    conditions = ['1=1']
    params = []
    if user_id:
        conditions.append('rs.created_by = %s')
        params.append(user_id)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT rs.*, sr.name AS report_name, sr.source_id,
                   ds.source_label
            FROM analytics.report_schedules rs
            JOIN analytics.saved_reports sr ON sr.id = rs.report_id
            JOIN analytics.report_data_sources ds ON ds.id = sr.source_id
            WHERE {' AND '.join(conditions)}
            ORDER BY rs.next_run_at NULLS LAST
        """, params)
        return cur.fetchall()


def save_schedule(data, user_id):
    with get_cursor(commit=True) as cur:
        import json
        recipients = data.get('recipients', [])
        if isinstance(recipients, str):
            recipients = json.loads(recipients) if recipients.strip() else []

        if data.get('id'):
            cur.execute("""
                UPDATE analytics.report_schedules
                SET schedule_type = %s, day_of_week = %s, day_of_month = %s,
                    run_time = %s, output_format = %s, recipients = %s,
                    is_enabled = %s
                WHERE id = %s RETURNING id
            """, (data['schedule_type'], data.get('day_of_week'),
                  data.get('day_of_month'), data.get('run_time', '07:00'),
                  data.get('output_format', 'XLSX'), json.dumps(recipients),
                  data.get('is_enabled', True), data['id']))
        else:
            cur.execute("""
                INSERT INTO analytics.report_schedules
                    (report_id, schedule_type, day_of_week, day_of_month,
                     run_time, output_format, recipients, created_by)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING id
            """, (data['report_id'], data['schedule_type'],
                  data.get('day_of_week'), data.get('day_of_month'),
                  data.get('run_time', '07:00'), data.get('output_format', 'XLSX'),
                  json.dumps(recipients), user_id))
        return cur.fetchone()


def get_run_history(report_id=None, limit=50):
    conditions = ['1=1']
    params = []
    if report_id:
        conditions.append('rh.report_id = %s')
        params.append(report_id)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT rh.*, sr.name AS report_name, u.display_name AS run_by_name
            FROM analytics.report_run_history rh
            LEFT JOIN analytics.saved_reports sr ON sr.id = rh.report_id
            LEFT JOIN core.users u ON u.id = rh.run_by
            WHERE {' AND '.join(conditions)}
            ORDER BY rh.started_at DESC
            LIMIT %s
        """, params + [limit])
        return cur.fetchall()
