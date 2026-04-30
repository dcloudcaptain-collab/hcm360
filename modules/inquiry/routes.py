"""
Public, unauthenticated transaction inquiry by QR token.

The actual `core.transaction_qr_tokens` table is polymorphic:
    (token, module, entity_type, entity_id)

So a token does not embed the data — we look up the entity by
(module, entity_type, entity_id) on demand.
"""

import io
import qrcode
from flask import Blueprint, render_template, send_file, request
from services.db import get_cursor

bp = Blueprint('inquiry', __name__, url_prefix='/inquiry')


# ── Per-entity-type fetch helpers ─────────────────────────────────

def _fetch_leave_request(cur, entity_id):
    cur.execute("""
        SELECT lr.reference_no,
               lr.status                       AS status_label,
               lt.name                         AS step_name,
               'Leave request: ' || lt.name || ' (' || lr.days_requested || ' day(s))'
                                               AS summary_text,
               lr.filed_at                     AS filed_at,
               e.first_name || ' ' || e.last_name AS subject_name
        FROM leave_mgmt.lv_requests lr
        JOIN leave_mgmt.lv_types lt ON lt.id = lr.leave_type_id
        JOIN core.employees e       ON e.id  = lr.employee_id
        WHERE lr.id = %s
    """, (entity_id,))
    return cur.fetchone()


def _fetch_leave_timeline(cur, entity_id):
    cur.execute("""
        SELECT lr.filed_at AS event_time,
               'Leave request filed by ' || e.first_name || ' ' || e.last_name AS event_text
        FROM leave_mgmt.lv_requests lr
        JOIN core.employees e ON e.id = lr.employee_id
        WHERE lr.id = %s
        UNION ALL
        SELECT a.acted_at,
               'Approval level ' || a.approval_level || ' — ' || a.status ||
               COALESCE(' (' || a.remarks || ')', '')
        FROM leave_mgmt.lv_approvals a
        WHERE a.request_id = %s AND a.acted_at IS NOT NULL
        ORDER BY 1 DESC
    """, (entity_id, entity_id))
    return cur.fetchall()


def _fetch_discipline_case(cur, entity_id):
    cur.execute("""
        SELECT c.case_no                       AS reference_no,
               c.status                        AS status_label,
               COALESCE(ct.name, c.status)     AS step_name,
               c.offense_description           AS summary_text,
               c.date_filed                    AS filed_at,
               e.first_name || ' ' || e.last_name AS subject_name
        FROM discipline.cases c
        LEFT JOIN discipline.case_types ct ON ct.id = c.case_type_id
        JOIN core.employees e              ON e.id  = c.respondent_id
        WHERE c.id = %s
    """, (entity_id,))
    return cur.fetchone()


def _fetch_discipline_timeline(cur, entity_id):
    cur.execute("""
        SELECT date_filed AS event_time,
               'Case filed against respondent' AS event_text
        FROM discipline.cases WHERE id = %s
        UNION ALL
        SELECT created_at,
               'Case status: ' || status
        FROM discipline.cases WHERE id = %s
        ORDER BY 1 DESC
    """, (entity_id, entity_id))
    return cur.fetchall()


def _fetch_recruitment_requisition(cur, entity_id):
    cur.execute("""
        SELECT r.reference_no,
               r.status                  AS status_label,
               r.status                  AS step_name,
               COALESCE(p.title, 'Unspecified position') ||
                 ' (' || r.headcount || ' position(s)) — ' || COALESCE(r.justification,'') AS summary_text,
               r.created_at              AS filed_at,
               COALESCE(p.title, '—')    AS subject_name
        FROM recruitment.rec_requisitions r
        LEFT JOIN core.positions p ON p.id = r.position_id
        WHERE r.id = %s
    """, (entity_id,))
    return cur.fetchone()


def _fetch_recruitment_timeline(cur, entity_id):
    cur.execute("""
        SELECT created_at AS event_time,
               'Requisition created' AS event_text
        FROM recruitment.rec_requisitions WHERE id = %s
        UNION ALL
        SELECT created_at,
               'Status: ' || status
        FROM recruitment.rec_requisitions WHERE id = %s
        ORDER BY 1 DESC
    """, (entity_id, entity_id))
    return cur.fetchall()


# ── Dispatcher ────────────────────────────────────────────────────

_FETCHERS = {
    ('LEAVE',       'lv_request'):       (_fetch_leave_request,       _fetch_leave_timeline),
    ('DISCIPLINE',  'disc_case'):        (_fetch_discipline_case,     _fetch_discipline_timeline),
    ('RECRUITMENT', 'rec_requisition'):  (_fetch_recruitment_requisition, _fetch_recruitment_timeline),
}


def _resolve_token(cur, token):
    cur.execute("""
        SELECT module, entity_type, entity_id, expires_at
        FROM core.transaction_qr_tokens
        WHERE token = %s
    """, (token,))
    return cur.fetchone()


# ── Routes ────────────────────────────────────────────────────────

@bp.route('/<token>')
def view(token):
    tx = None
    timeline = []
    module_label = None

    with get_cursor() as cur:
        tok = _resolve_token(cur, token)
        if tok:
            module_label = tok['module']
            key = (tok['module'], tok['entity_type'])
            fetcher = _FETCHERS.get(key)
            if fetcher:
                fetch_entity, fetch_timeline = fetcher
                tx = fetch_entity(cur, tok['entity_id'])
                if tx:
                    # Add module_code field that template expects
                    tx = dict(tx)
                    tx['module_code'] = tok['module']
                timeline = fetch_timeline(cur, tok['entity_id']) or []

    return render_template('inquiry/view.html',
                           tx=tx, timeline=timeline, token=token,
                           module_label=module_label)


@bp.route('/<token>/qr.png')
def qr_image(token):
    """Generate a PNG QR that encodes the public inquiry URL for `token`."""
    base = request.host_url.rstrip('/')
    img = qrcode.make(f"{base}/inquiry/{token}")
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    buf.seek(0)
    return send_file(buf, mimetype='image/png')
