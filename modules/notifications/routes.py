from flask import render_template, request, redirect, url_for, session, abort
from services.db import get_cursor
from services import notification_service
from . import bp


@bp.route('/', methods=['GET'])
def list_notifications():
    """Display all notifications for current user with pagination & filtering."""
    user_id = session.get('user_id')
    if not user_id:
        abort(401)

    page = request.args.get('page', 1, type=int)
    per_page = 20
    status_filter = request.args.get('status', 'all')  # 'all', 'unread', 'read'

    with get_cursor() as cur:
        # Build WHERE clause
        where = "WHERE user_id = %s"
        params = [user_id]
        if status_filter == 'unread':
            where += " AND is_read = FALSE"
        elif status_filter == 'read':
            where += " AND is_read = TRUE"

        # Total count
        cur.execute(f"SELECT COUNT(*) as cnt FROM notifications.ntf_in_app {where}", params)
        total = cur.fetchone()['cnt']
        total_pages = max(1, (total + per_page - 1) // per_page)
        page = max(1, min(page, total_pages))
        offset = (page - 1) * per_page

        # Get notifications
        cur.execute(f"""
            SELECT id, user_id, title, body, action_url, module,
                   entity_type, entity_id, is_read, created_at, read_at
            FROM notifications.ntf_in_app
            {where}
            ORDER BY created_at DESC
            LIMIT %s OFFSET %s
        """, params + [per_page, offset])

        notifications = [dict(n) for n in cur.fetchall()]

    return render_template('notifications/list.html',
                           notifications=notifications,
                           page=page, total_pages=total_pages, total=total,
                           status_filter=status_filter, per_page=per_page)


@bp.route('/<int:notif_id>', methods=['GET'])
def view_notification(notif_id):
    """View a single notification and mark it as read."""
    user_id = session.get('user_id')
    if not user_id:
        abort(401)

    with get_cursor() as cur:
        cur.execute("""
            SELECT id, user_id, title, body, action_url, module,
                   entity_type, entity_id, is_read, created_at, read_at
            FROM notifications.ntf_in_app
            WHERE id = %s AND user_id = %s
        """, (notif_id, user_id))
        notif = cur.fetchone()

    if not notif:
        return redirect(url_for('notifications.list_notifications'))

    # Mark as read
    if not notif['is_read']:
        notification_service.mark_read(notif_id, user_id)

    return render_template('notifications/detail.html', notification=dict(notif))
