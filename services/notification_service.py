"""
Notification Service
Handles in-app notifications and notification queue.
All modules call push_in_app() or notify() — never insert directly.
"""
from services.db import get_cursor


def push_in_app(user_id, title, body, action_url=None,
                module=None, entity_type=None, entity_id=None):
    """Insert an in-app bell notification for a user."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO notifications.ntf_in_app
                (user_id, title, body, action_url, module, entity_type, entity_id)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (user_id, title, body, action_url, module, entity_type, entity_id))
        return cur.fetchone()['id']


def notify(user_id, event_type, payload=None, recipient_email=None):
    """
    Queue a notification using a registered template.
    Falls back to in-app if no template found.
    """
    payload = payload or {}
    with get_cursor(commit=True) as cur:
        cur.execute("""
            SELECT nt.id, nt.body_template, nt.subject_template, nt.channel_id,
                   nc.code AS channel_code
            FROM notifications.ntf_templates nt
            JOIN notifications.ntf_channels nc ON nc.id = nt.channel_id
            WHERE nt.event_type = %s AND nt.is_active = TRUE
            LIMIT 1
        """, (event_type,))
        template = cur.fetchone()
        if not template:
            return None

        # Render simple {{key}} substitution
        body = template['body_template']
        subject = template['subject_template'] or ''
        for k, v in payload.items():
            body = body.replace('{{' + k + '}}', str(v))
            subject = subject.replace('{{' + k + '}}', str(v))

        cur.execute("""
            INSERT INTO notifications.ntf_queue
                (template_id, recipient_user_id, recipient_email, payload, status)
            VALUES (%s, %s, %s, %s, 'PENDING')
            RETURNING id
        """, (template['id'], user_id, recipient_email, payload))
        queue_id = cur.fetchone()['id']

        # Always also create in-app notification
        if user_id:
            cur.execute("""
                INSERT INTO notifications.ntf_in_app
                    (user_id, title, body, module)
                VALUES (%s, %s, %s, %s)
            """, (user_id, subject or event_type, body,
                  payload.get('module', None)))

        return queue_id


def get_unread(user_id):
    """Returns count and latest 10 unread in-app notifications."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT COUNT(*) AS count
            FROM notifications.ntf_in_app
            WHERE user_id=%s AND is_read=FALSE
        """, (user_id,))
        count = cur.fetchone()['count']
        cur.execute("""
            SELECT id, title, body, action_url, module, entity_type,
                   entity_id, created_at
            FROM notifications.ntf_in_app
            WHERE user_id=%s AND is_read=FALSE
            ORDER BY created_at DESC LIMIT 10
        """, (user_id,))
        notifications = cur.fetchall()
        return count, notifications


def mark_read(notification_id, user_id):
    """Mark a single notification as read."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE notifications.ntf_in_app
            SET is_read=TRUE, read_at=NOW()
            WHERE id=%s AND user_id=%s
        """, (notification_id, user_id))


def mark_all_read(user_id):
    """Mark all notifications as read for a user."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE notifications.ntf_in_app
            SET is_read=TRUE, read_at=NOW()
            WHERE user_id=%s AND is_read=FALSE
        """, (user_id,))
