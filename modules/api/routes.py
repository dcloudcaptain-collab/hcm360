from flask import Blueprint, jsonify, request, session
from services.db import get_cursor
from services.kpi_service import get_dashboard_metrics
from services.search_service import search_all
from services.workflow_service import get_instances
from services import notification_service

bp = Blueprint('api', __name__, url_prefix='/api/v1')


# ── Notification endpoints (used by bell icon in base.html) ──────────────────

@bp.route('/notifications/unread')
def notif_unread():
    user_id = session.get('user_id')
    if not user_id:
        return jsonify({'count': 0, 'notifications': []})
    count, notifications = notification_service.get_unread(user_id)
    return jsonify({'count': count, 'notifications': [dict(n) for n in notifications]})


@bp.route('/notifications/<int:notif_id>/read', methods=['POST'])
def notif_mark_read(notif_id):
    user_id = session.get('user_id')
    if user_id:
        notification_service.mark_read(notif_id, user_id)
    return jsonify({'ok': True})


@bp.route('/notifications/read-all', methods=['POST'])
def notif_read_all():
    user_id = session.get('user_id')
    if user_id:
        notification_service.mark_all_read(user_id)
    return jsonify({'ok': True})


# Also expose under /api (no version prefix) for the bell script's simpler paths
notif_bp = Blueprint('notif_api', __name__, url_prefix='/api')


@bp.route('/kpis')
def kpis():
    return jsonify(get_dashboard_metrics())


@bp.route('/search')
def search():
    return jsonify(search_all(request.args.get('q', '')))


@bp.route('/workflow-instances')
def workflow_instances():
    return jsonify(get_instances())


@bp.route('/form-definitions')
def form_definitions():
    with get_cursor() as cur:
        cur.execute('SELECT * FROM dynamic_forms ORDER BY form_name')
        forms = cur.fetchall()
    return jsonify(forms)


@bp.route('/orchestrations')
def orchestrations():
    with get_cursor() as cur:
        cur.execute('SELECT * FROM orchestration_flows ORDER BY id')
        flows = cur.fetchall()
    return jsonify(flows)


@bp.route('/employees/search')
def employees_search():
    """Live employee search for autocomplete widgets. Returns up to 15 matches."""
    q = request.args.get('q', '').strip()
    if len(q) < 2:
        return jsonify([])
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                e.id,
                e.employee_no,
                CONCAT(e.first_name, ' ', e.last_name)   AS full_name,
                e.immediate_supervisor_id                 AS manager_id,
                CASE WHEN m.id IS NOT NULL
                     THEN CONCAT(m.first_name, ' ', m.last_name)
                     ELSE NULL
                END                                       AS manager_name,
                e.basic_salary                            AS current_salary,
                d.name                                    AS department_name,
                p.title                                   AS position_title
            FROM core.employees e
            LEFT JOIN core.employees   m ON m.id = e.immediate_supervisor_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.positions   p ON p.id = e.position_id
            WHERE e.is_active = TRUE
              AND (
                LOWER(CONCAT(e.first_name, ' ', e.last_name)) LIKE %(q)s
                OR LOWER(e.employee_no) LIKE %(q)s
                OR LOWER(e.last_name)   LIKE %(q)s
              )
            ORDER BY e.last_name, e.first_name
            LIMIT 15
        """, {'q': f'%{q.lower()}%'})
        rows = cur.fetchall()
    return jsonify([dict(r) for r in rows])


@bp.route('/mobile/inquiry/<token>')
def mobile_inquiry(token):
    with get_cursor() as cur:
        cur.execute("""
            SELECT tr.reference_no, tr.module_code, sd.status_label, tr.summary_text
            FROM transaction_registry tr
            JOIN transaction_qr_tokens qt ON qt.transaction_id = tr.id
            JOIN status_definitions sd ON sd.id = tr.status_id
            WHERE qt.public_token=%s
        """, (token,))
        tx = cur.fetchone()
    return jsonify(tx or {'error': 'Not found'})
