"""
Guided Tour blueprint.

Public API (all logged-in users):
    GET  /api/tours/for-page?path=<url>    — tours applicable to a URL + role
    GET  /api/tours/<tour_key>             — single tour definition
    POST /api/tours/<tour_key>/complete    — mark finished
    POST /api/tours/<tour_key>/skip        — mark skipped
    POST /api/tours/<tour_key>/reset       — reset own completion

Admin UI (SUPER_ADMIN / HR_ADMIN):
    GET  /admin/tours                       — list
    GET  /admin/tours/new                   — create
    GET  /admin/tours/<id>/edit             — edit
    POST /admin/tours/save                  — upsert
    POST /admin/tours/<id>/deactivate
    POST /admin/tours/reset-role            — reset a role's completions
"""
import json
from functools import wraps

from flask import (Blueprint, flash, jsonify, redirect, render_template,
                   request, session, url_for, abort)

from services import tour_service as svc


tour_bp = Blueprint('tour', __name__, template_folder='../../templates/tour')


def _login_required(f):
    @wraps(f)
    def decorated(*a, **kw):
        if 'user_id' not in session:
            return jsonify({'ok': False, 'message': 'login required'}), 401 \
                if request.path.startswith('/api/') else redirect(url_for('login'))
        return f(*a, **kw)
    return decorated


def _admin_required(f):
    @wraps(f)
    def decorated(*a, **kw):
        if session.get('role_code') not in ('SUPER_ADMIN', 'HR_ADMIN'):
            flash('Admin access required.', 'error')
            return redirect(url_for('dashboard.index'))
        return f(*a, **kw)
    return decorated


# ══════════════════════════════════════════════════════════════════════
# Public API
# ══════════════════════════════════════════════════════════════════════
@tour_bp.route('/api/tours/for-page')
@_login_required
def api_for_page():
    path = request.args.get('path', '/')
    user_id = session.get('user_id')
    role = session.get('role_code', 'EMPLOYEE')
    tours = svc.tours_for_url(user_id, role, path)
    # Reduce payload: return steps only for auto-start+incomplete tours
    out = []
    for t in tours:
        row = {
            'tour_key': t['tour_key'],
            'title': t['title'],
            'description': t.get('description'),
            'module': t.get('module'),
            'version': t.get('version', 1),
            'auto_start': bool(t.get('auto_start', True)),
            'url_pattern': t.get('url_pattern'),
            'is_completed': bool(t.get('is_completed')),
            'is_skipped':   bool(t.get('is_skipped')),
            'steps': t.get('steps', []),
        }
        out.append(row)
    return jsonify({'ok': True, 'tours': out,
                    'role': role, 'user_id': user_id})


@tour_bp.route('/api/tours/<tour_key>')
@_login_required
def api_get_tour(tour_key):
    t = svc.get_tour(tour_key)
    if not t:
        return jsonify({'ok': False, 'message': 'tour not found'}), 404
    if not svc.tour_visible_to(session.get('user_id'),
                                session.get('role_code'), t):
        return jsonify({'ok': False, 'message': 'forbidden for your role'}), 403
    steps = t['steps']
    if isinstance(steps, str):
        steps = json.loads(steps)
    return jsonify({'ok': True, 'tour': {
        'tour_key': t['tour_key'], 'title': t['title'],
        'description': t['description'], 'version': t['version'],
        'module': t['module'], 'allowed_roles': t['allowed_roles'],
        'steps': steps,
    }})


@tour_bp.route('/api/tours/<tour_key>/complete', methods=['POST'])
@_login_required
def api_complete(tour_key):
    data = request.get_json(silent=True) or {}
    svc.mark_completed(session.get('user_id'), tour_key,
                       version=int(data.get('version') or 1),
                       skipped=False,
                       step_reached=int(data.get('step_reached') or 0))
    return jsonify({'ok': True})


@tour_bp.route('/api/tours/<tour_key>/skip', methods=['POST'])
@_login_required
def api_skip(tour_key):
    data = request.get_json(silent=True) or {}
    svc.mark_completed(session.get('user_id'), tour_key,
                       version=int(data.get('version') or 1),
                       skipped=True,
                       step_reached=int(data.get('step_reached') or 0))
    return jsonify({'ok': True})


@tour_bp.route('/api/tours/<tour_key>/reset', methods=['POST'])
@_login_required
def api_reset(tour_key):
    svc.reset_completion(session.get('user_id'), tour_key)
    return jsonify({'ok': True})


# ══════════════════════════════════════════════════════════════════════
# Admin UI
# ══════════════════════════════════════════════════════════════════════
@tour_bp.route('/admin/tours')
@_login_required
@_admin_required
def admin_list():
    rows = svc.list_tours(only_active=False)
    stats = svc.summary()
    return render_template('tour/admin_list.html', rows=rows, stats=stats)


@tour_bp.route('/admin/tours/new', methods=['GET', 'POST'])
@_login_required
@_admin_required
def admin_new():
    if request.method == 'POST':
        return _save_from_form()
    return render_template('tour/admin_edit.html', tour=None)


@tour_bp.route('/admin/tours/<int:tid>/edit', methods=['GET', 'POST'])
@_login_required
@_admin_required
def admin_edit(tid):
    with __import__('services.db', fromlist=['get_cursor']).get_cursor() as cur:
        cur.execute("SELECT * FROM core.tours WHERE id = %s", (tid,))
        t = cur.fetchone()
    if not t:
        abort(404)
    if request.method == 'POST':
        return _save_from_form()
    # Pretty-print steps JSON for editing
    steps = t['steps']
    if isinstance(steps, list):
        steps_str = json.dumps(steps, indent=2)
    elif isinstance(steps, str):
        try:
            steps_str = json.dumps(json.loads(steps), indent=2)
        except Exception:
            steps_str = steps
    else:
        steps_str = '[]'
    return render_template('tour/admin_edit.html',
                           tour=t, steps_str=steps_str)


def _save_from_form():
    form = request.form.to_dict()
    try:
        # Parse steps JSON
        steps_str = form.get('steps') or '[]'
        steps = json.loads(steps_str)
    except Exception as ex:
        flash(f'Steps must be valid JSON: {ex}', 'error')
        return redirect(request.url)

    payload = {
        'tour_key':    form['tour_key'].strip(),
        'title':       form['title'].strip(),
        'description': form.get('description', ''),
        'module':      form.get('module', ''),
        'version':     int(form.get('version') or 1),
        'allowed_roles': [r.strip() for r in form.get('allowed_roles', '').split(',')
                          if r.strip()],
        'url_pattern': form.get('url_pattern', '').strip() or None,
        'auto_start':  form.get('auto_start') in ('on', 'true', '1', True),
        'is_active':   form.get('is_active') in ('on', 'true', '1', True),
        'steps':       steps,
    }
    try:
        row = svc.upsert_tour(payload, session.get('user_id'))
    except Exception as ex:
        flash(f'Failed to save: {ex}', 'error')
        return redirect(request.url)
    flash(f'Tour "{row["tour_key"]}" saved.', 'success')
    return redirect(url_for('tour.admin_list'))


@tour_bp.route('/admin/tours/<tour_key>/deactivate', methods=['POST'])
@_login_required
@_admin_required
def admin_deactivate(tour_key):
    svc.deactivate_tour(tour_key)
    return jsonify({'ok': True})


@tour_bp.route('/admin/tours/reset-role', methods=['POST'])
@_login_required
@_admin_required
def admin_reset_role():
    data = request.get_json(silent=True) or request.form.to_dict()
    role = data.get('role_code', '').strip()
    key = data.get('tour_key', '').strip() or None
    if not role:
        return jsonify({'ok': False, 'message': 'role_code required'}), 400
    removed = svc.reset_for_role(role, tour_key=key)
    return jsonify({'ok': True, 'removed': removed})
