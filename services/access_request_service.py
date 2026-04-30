"""
Access Request Service

Self-service flow for users who hit a 403 Forbidden page.
The user submits a reason; we:
  1. Insert into core.access_requests (status=PENDING)
  2. Push an in-app notification + task to every SUPER_ADMIN / HR_ADMIN
  3. Return the new request id so the 403 page can show a confirmation

Admin review:
  * grant_request(req_id, reviewer_id, notes)  — creates a user-level page
    override via core.user_page_access so the user can now visit the path.
  * deny_request(req_id, reviewer_id, notes)
  Both notify the requester via in-app notification.
"""
from services.db import get_cursor
from services import notification_service, task_inbox_service


# ── Admin lookup ─────────────────────────────────────────────────────
def _admin_user_ids():
    """All users who should see pending access requests."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT DISTINCT u.id, u.display_name, u.employee_id
              FROM core.users u
              LEFT JOIN core.user_roles ur ON ur.user_id = u.id
              LEFT JOIN core.roles r ON r.id = ur.role_id
             WHERE u.is_active = TRUE
               AND COALESCE(r.code, u.role_code) IN ('SUPER_ADMIN','HR_ADMIN')
        """)
        return cur.fetchall()


# ── Create ───────────────────────────────────────────────────────────
def create_request(requester_user_id, requested_path, reason,
                   page_title=None, module=None):
    """Insert the request + notify admins. Returns the new request row."""
    # De-dupe: if the same user already has a PENDING request for the same
    # path, just return that one and add a comment rather than spamming.
    with get_cursor(commit=True) as cur:
        cur.execute("""
            SELECT id FROM core.access_requests
             WHERE requester_user_id = %s
               AND requested_path    = %s
               AND status            = 'PENDING'
             LIMIT 1
        """, (requester_user_id, requested_path))
        existing = cur.fetchone()
        if existing:
            return {'id': existing['id'], 'deduped': True}

        cur.execute("""
            INSERT INTO core.access_requests
                (requester_user_id, requested_path, requested_module,
                 page_title, reason, status)
            VALUES (%s, %s, %s, %s, %s, 'PENDING')
            RETURNING id, requester_user_id, requested_path, reason,
                      page_title, created_at
        """, (requester_user_id, requested_path, module, page_title, reason))
        req = cur.fetchone()
        cur.execute("""
            SELECT display_name, employee_id FROM core.users WHERE id = %s
        """, (requester_user_id,))
        requester = cur.fetchone()

    requester_name = requester['display_name'] if requester else 'An employee'

    # Fire notification + task to every admin
    review_url = f'/admin/access-requests?highlight={req["id"]}'
    title = f'🔐 Access request: {requested_path}'
    body = (f'{requester_name} is requesting access to '
            f'{page_title or requested_path}.'
            + (f' Reason: "{reason}"' if reason else ''))

    for admin in _admin_user_ids():
        # In-app bell
        try:
            notification_service.push_in_app(
                user_id=admin['id'],
                title=title,
                body=body,
                action_url=review_url,
                module='admin',
                entity_type='access_request',
                entity_id=req['id'],
            )
        except Exception:
            pass

        # Task in the admin's inbox
        try:
            task_inbox_service.create_task(
                employee_id=admin['employee_id'],
                user_id=admin['id'],
                task_type='ACCESS_REQUEST',
                title=title,
                description=body,
                action_url=review_url,
                priority='HIGH',
                source_table='core.access_requests',
                source_id=req['id'],
                created_by=requester_user_id,
                task_category='SYSTEM',
            )
        except Exception:
            pass

    return {'id': req['id'], 'deduped': False}


# ── List ─────────────────────────────────────────────────────────────
def list_requests(status=None, requester_user_id=None, limit=200):
    conditions = ['1=1']
    params = []
    if status:
        conditions.append('ar.status = %s')
        params.append(status)
    if requester_user_id:
        conditions.append('ar.requester_user_id = %s')
        params.append(requester_user_id)
    params.append(limit)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT ar.*,
                   u.display_name  AS requester_name,
                   u.email         AS requester_email,
                   COALESCE(rr.code, u.role_code) AS requester_role,
                   rv.display_name AS reviewer_name
              FROM core.access_requests ar
              JOIN core.users u   ON u.id = ar.requester_user_id
              LEFT JOIN core.user_roles ur ON ur.user_id = u.id
              LEFT JOIN core.roles rr ON rr.id = ur.role_id
              LEFT JOIN core.users rv ON rv.id = ar.reviewer_id
             WHERE {' AND '.join(conditions)}
             ORDER BY
               CASE ar.status WHEN 'PENDING' THEN 0 ELSE 1 END,
               ar.created_at DESC
             LIMIT %s
        """, params)
        return cur.fetchall()


def get_request(req_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT ar.*,
                   u.display_name AS requester_name,
                   u.email        AS requester_email
              FROM core.access_requests ar
              JOIN core.users u ON u.id = ar.requester_user_id
             WHERE ar.id = %s
        """, (req_id,))
        return cur.fetchone()


# ── Review — grant ───────────────────────────────────────────────────
def grant_request(req_id, reviewer_id, notes=None):
    """Mark granted + create a user-level page-access override if the
    page is registered in core.page_registry."""
    req = get_request(req_id)
    if not req or req['status'] != 'PENDING':
        return None

    with get_cursor(commit=True) as cur:
        # Look up the page registry row (if any)
        cur.execute("""
            SELECT id FROM core.page_registry WHERE path = %s LIMIT 1
        """, (req['requested_path'],))
        page = cur.fetchone()
        if page:
            cur.execute("""
                INSERT INTO core.user_page_access (user_id, page_id, can_access)
                VALUES (%s, %s, TRUE)
                ON CONFLICT (user_id, page_id) DO UPDATE SET can_access = TRUE
            """, (req['requester_user_id'], page['id']))

        cur.execute("""
            UPDATE core.access_requests
               SET status = 'GRANTED',
                   reviewer_id = %s,
                   reviewed_at = NOW(),
                   review_notes = %s,
                   updated_at = NOW()
             WHERE id = %s
        """, (reviewer_id, notes, req_id))

        cur.execute("""
            SELECT display_name FROM core.users WHERE id = %s
        """, (reviewer_id,))
        reviewer = cur.fetchone()

    # Notify the requester
    try:
        notification_service.push_in_app(
            user_id=req['requester_user_id'],
            title=f'✅ Access granted — {req["requested_path"]}',
            body=(f'Your request to access {req["requested_path"]} has been '
                  f'granted by {reviewer["display_name"] if reviewer else "Admin"}. '
                  f'{notes or ""}').strip(),
            action_url=req['requested_path'],
            module='admin',
            entity_type='access_request',
            entity_id=req_id,
        )
    except Exception:
        pass

    return True


# ── Review — deny ────────────────────────────────────────────────────
def deny_request(req_id, reviewer_id, notes=None):
    req = get_request(req_id)
    if not req or req['status'] != 'PENDING':
        return None

    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.access_requests
               SET status = 'DENIED',
                   reviewer_id = %s,
                   reviewed_at = NOW(),
                   review_notes = %s,
                   updated_at = NOW()
             WHERE id = %s
        """, (reviewer_id, notes, req_id))

    try:
        notification_service.push_in_app(
            user_id=req['requester_user_id'],
            title=f'⛔ Access denied — {req["requested_path"]}',
            body=(f'Your request to access {req["requested_path"]} was denied. '
                  f'{notes or ""}').strip(),
            module='admin',
            entity_type='access_request',
            entity_id=req_id,
        )
    except Exception:
        pass

    return True


# ── Cancel (requester can cancel their own pending request) ─────────
def cancel_request(req_id, requester_user_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.access_requests
               SET status = 'CANCELLED', updated_at = NOW()
             WHERE id = %s
               AND requester_user_id = %s
               AND status = 'PENDING'
        """, (req_id, requester_user_id))
        return cur.rowcount
