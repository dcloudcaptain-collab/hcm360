"""Database connection service — adapted for standalone payroll app."""
from contextlib import contextmanager
import psycopg2
from psycopg2.extras import RealDictCursor
from flask import current_app, g, session, request

_SEARCH_PATH = (
    'core, attendance, leave_mgmt, payroll, rewards, public'
)


def get_conn():
    return psycopg2.connect(current_app.config['DATABASE_URL'])


@contextmanager
def get_cursor(commit=False):
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute(f'SET search_path TO {_SEARCH_PATH}')

        user_id    = session.get('user_id')
        company_id = getattr(g, 'company_id', 1)
        client_ip  = request.remote_addr if request else None
        sess_id    = session.get('_id', '')

        if user_id:
            cur.execute(
                'SET LOCAL app.current_user_id    = %s;'
                'SET LOCAL app.current_company_id = %s;'
                'SET LOCAL app.client_ip          = %s;'
                'SET LOCAL app.session_id         = %s;',
                (str(user_id), str(company_id),
                 str(client_ip or ''), str(sess_id))
            )

        yield cur
        if commit:
            conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        cur.close()
        conn.close()
