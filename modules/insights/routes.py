"""Insights blueprint.

Routes:
  GET  /analytics                       — personal analytics dashboard
  GET  /admin/insights-library          — admin catalog of canned insights
  POST /admin/insights-library/toggle   — AJAX pin/unpin
  GET  /api/insights/<code>/data        — JSON chart data for lazy refresh
"""
from functools import wraps
from flask import (Blueprint, abort, jsonify, redirect, render_template,
                   request, session, url_for)

from services import insights_service as svc

insights_bp = Blueprint(
    'insights', __name__,
    template_folder='../../templates/insights'
)


# ── decorators ──────────────────────────────────────────────────────
def _login_required(f):
    @wraps(f)
    def wrap(*a, **kw):
        if 'user_id' not in session:
            return redirect(url_for('login'))
        return f(*a, **kw)
    return wrap


def _admin_required(f):
    @wraps(f)
    def wrap(*a, **kw):
        if session.get('role_code') not in ('SUPER_ADMIN', 'HR_ADMIN'):
            abort(403)
        return f(*a, **kw)
    return wrap


# ── /analytics — the user's personalized dashboard ─────────────────
@insights_bp.route('/analytics')
@_login_required
def dashboard():
    user_id = session['user_id']
    role_code = session.get('role_code') or 'EMPLOYEE'
    pinned = svc.get_pinned(user_id, role_code)
    # Render each insight's data server-side so Chart.js gets JSON immediately
    rendered = svc.run_many([p['code'] for p in pinned])
    pinned_count = svc.pinned_count(user_id)
    return render_template(
        'insights/dashboard.html',
        rendered=rendered,
        pinned_count=pinned_count,
        role_code=role_code,
    )


# ── /admin/insights-library — catalog with checkboxes ─────────────
@insights_bp.route('/admin/insights-library')
@_login_required
@_admin_required
def library():
    user_id = session['user_id']
    role_code = session.get('role_code') or 'EMPLOYEE'
    insights = svc.list_library(role_code, user_id)

    # Bucket by category for the category filter view
    categories = []
    seen = set()
    for i in insights:
        if i['category'] not in seen:
            categories.append(i['category'])
            seen.add(i['category'])

    pinned_now = sum(1 for i in insights if i['is_pinned'])
    return render_template(
        'insights/library.html',
        insights=insights,
        categories=categories,
        pinned_count=pinned_now,
    )


# ── Toggle (AJAX) ───────────────────────────────────────────────────
@insights_bp.route('/admin/insights-library/toggle', methods=['POST'])
@_login_required
def toggle():
    """Any logged-in user can toggle their OWN preferences. The admin nav
    entry-point is restricted, but the endpoint itself does not need to
    be — preferences are always per-user."""
    code = (request.form.get('code') or '').strip()
    enabled = (request.form.get('enabled') or '').lower() in ('1', 'true', 'on', 'yes')
    if not code:
        return jsonify({'ok': False, 'error': 'code is required'}), 400

    ok = svc.toggle(session['user_id'], code, enabled)
    return jsonify({
        'ok': bool(ok),
        'code': code,
        'enabled': enabled,
        'pinned_count': svc.pinned_count(session['user_id']),
    })


# ── Chart data refresh ─────────────────────────────────────────────
@insights_bp.route('/api/insights/<code>/data')
@_login_required
def data(code):
    r = svc.run_insight(code)
    if not r:
        return jsonify({'ok': False, 'error': 'not found'}), 404
    return jsonify({'ok': True, 'insight': r})
