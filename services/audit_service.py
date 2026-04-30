"""
Audit Service
Python-level audit helpers that complement the PostgreSQL trigger system.
Triggers in 15_triggers.sql automatically capture field-level changes.
This service provides:
  - log_action()       : explicit application-level event logging
  - get_timeline()     : full audit trail for any entity
  - set_audit_context(): push session vars so triggers can attribute changes
"""
from services.db import get_cursor


# ---------------------------------------------------------------------------
# Context helpers (called internally from services/db.py via get_cursor)
# ---------------------------------------------------------------------------

def set_audit_context(cur, user_id, company_id=None, client_ip=None, session_id=None):
    """
    Push PostgreSQL session-level variables consumed by fn_capture_change().
    Must be called inside an existing cursor transaction (not committed here).
    """
    cur.execute(
        "SELECT set_config('app.current_user_id',   %s, TRUE),"
        "       set_config('app.current_company_id', %s, TRUE),"
        "       set_config('app.client_ip',          %s, TRUE),"
        "       set_config('app.session_id',         %s, TRUE)",
        (
            str(user_id)     if user_id     else '',
            str(company_id)  if company_id  else '',
            str(client_ip)   if client_ip   else '',
            str(session_id)  if session_id  else '',
        ),
    )


# ---------------------------------------------------------------------------
# Explicit event log (for actions not covered by row-level triggers)
# ---------------------------------------------------------------------------

def log_action(entity_type, entity_id, action, performed_by=None,
               old_val=None, new_val=None, notes=None, module=None):
    """
    Insert a record into audit_logs.sys_change_log directly.
    Use this for business events that are not simple INSERT/UPDATE/DELETE:
      - bulk imports, exports, password changes, permission grants, etc.
    """
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO audit_logs.sys_change_log
                (schema_name, table_name, operation, row_id,
                 changed_by_user_id, old_data, new_data, extra_notes)
            VALUES ('app', %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (
            entity_type,
            action.upper(),
            str(entity_id) if entity_id else None,
            performed_by,
            old_val,
            new_val,
            notes,
        ))
        return cur.fetchone()['id']


# ---------------------------------------------------------------------------
# Status transition log (mirrors the trigger but callable from Python)
# ---------------------------------------------------------------------------

def log_status_change(entity_type, entity_id, from_status, to_status,
                      performed_by=None, reason=None, module=None):
    """Log an explicit status transition to sys_status_transitions."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO audit_logs.sys_status_transitions
                (entity_type, entity_id, from_status, to_status,
                 changed_by_user_id, reason)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (entity_type, str(entity_id), from_status, to_status,
              performed_by, reason))
        return cur.fetchone()['id']


# ---------------------------------------------------------------------------
# Login / logout logging
# ---------------------------------------------------------------------------

def log_login(user_id, username, ip_address=None, user_agent=None,
              success=True, failure_reason=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO audit_logs.sys_login_logs
                (user_id, username, ip_address, user_agent, success, failure_reason)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (user_id, username, ip_address, user_agent, success, failure_reason))
        return cur.fetchone()['id']


def log_logout(user_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE audit_logs.sys_login_logs
            SET logged_out_at = NOW()
            WHERE user_id = %s
              AND logged_out_at IS NULL
              AND created_at > NOW() - INTERVAL '24 hours'
        """, (user_id,))


# ---------------------------------------------------------------------------
# Data export log
# ---------------------------------------------------------------------------

def log_export(user_id, export_type, record_count=None,
               filters_applied=None, file_format=None, module='analytics'):
    try:
        with get_cursor(commit=True) as cur:
            cur.execute("""
                INSERT INTO audit_logs.sys_data_exports
                    (user_id, export_type, module, row_count,
                     filter_params, format)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id
            """, (user_id, export_type, module, record_count,
                  filters_applied, file_format))
            return cur.fetchone()['id']
    except Exception:
        return None  # audit logging should never block exports


# ---------------------------------------------------------------------------
# Timeline / history queries
# ---------------------------------------------------------------------------

def get_timeline(entity_type, entity_id, limit=50):
    """
    Return full audit trail for any entity — combines:
      - sys_change_log    (row-level INS/UPD/DEL + explicit events)
      - sys_status_transitions (status history)
    Sorted by created_at DESC.
    """
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                cl.created_at,
                cl.operation         AS action,
                cl.old_data,
                cl.new_data,
                cl.extra_notes       AS notes,
                u.display_name       AS performed_by,
                'change'             AS log_type
            FROM audit_logs.sys_change_log cl
            LEFT JOIN core.users u ON u.id = cl.changed_by_user_id
            WHERE cl.table_name = %s
              AND cl.row_id     = %s::TEXT

            UNION ALL

            SELECT
                st.created_at,
                'STATUS_CHANGE'      AS action,
                st.from_status::TEXT AS old_data,
                st.to_status::TEXT   AS new_data,
                st.reason            AS notes,
                u.display_name       AS performed_by,
                'status'             AS log_type
            FROM audit_logs.sys_status_transitions st
            LEFT JOIN core.users u ON u.id = st.changed_by_user_id
            WHERE st.entity_type = %s
              AND st.entity_id   = %s::TEXT

            ORDER BY created_at DESC
            LIMIT %s
        """, (entity_type, str(entity_id),
              entity_type, str(entity_id),
              limit))
        return cur.fetchall()


def get_user_activity(user_id, limit=100):
    """Return recent activity for a specific user across all audit tables."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                cl.created_at,
                cl.schema_name,
                cl.table_name,
                cl.row_id,
                cl.operation,
                cl.extra_notes
            FROM audit_logs.sys_change_log cl
            WHERE cl.changed_by_user_id = %s
            ORDER BY cl.created_at DESC
            LIMIT %s
        """, (user_id, limit))
        return cur.fetchall()


def get_recent_changes(limit=100, schema_name=None, table_name=None):
    """HR Admin: recent change log across the system."""
    with get_cursor() as cur:
        if schema_name and table_name:
            cur.execute("""
                SELECT * FROM audit_logs.v_recent_changes
                WHERE schema_name = %s AND table_name = %s
                ORDER BY changed_at DESC LIMIT %s
            """, (schema_name, table_name, limit))
        else:
            cur.execute("""
                SELECT * FROM audit_logs.v_recent_changes
                ORDER BY changed_at DESC LIMIT %s
            """, (limit,))
        return cur.fetchall()


def get_login_logs(user_id=None, limit=50):
    """Return login history, optionally filtered to a single user."""
    with get_cursor() as cur:
        if user_id:
            cur.execute("""
                SELECT * FROM audit_logs.sys_login_logs
                WHERE user_id = %s
                ORDER BY created_at DESC LIMIT %s
            """, (user_id, limit))
        else:
            cur.execute("""
                SELECT ll.*, u.display_name
                FROM audit_logs.sys_login_logs ll
                LEFT JOIN core.users u ON u.id = ll.user_id
                ORDER BY ll.created_at DESC LIMIT %s
            """, (limit,))
        return cur.fetchall()
