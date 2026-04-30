"""Access Requests blueprint.

Routes:
  POST /access-requests/new          — submit a request from the 403 page
  POST /access-requests/<id>/cancel  — requester cancels their pending request
  GET  /admin/access-requests        — admin queue
  POST /admin/access-requests/<id>/grant
  POST /admin/access-requests/<id>/deny
"""
from functools import wraps
from flask import (Blueprint, flash, jsonify, redirect, render_template,
                   request, session, url_for, abort)

from services import access_request_service as svc

access_req_bp = Blueprint(
    'access_requests', __name__,
    template_folder='../../templates/access_requests'
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


# ── submit ──────────────────────────────────────────────────────────
@access_req_bp.route('/access-requests/new', methods=['POST'])
@_login_required
def create():
    user_id = session['user_id']
    path = (request.form.get('requested_path') or '').strip()
    reason = (request.form.get('reason') or '').strip() or None
    page_title = (request.form.get('page_title') or '').strip() or None
    module = (request.form.get('module') or '').strip() or None

    if not path:
        if request.is_json:
            return jsonify({'ok': False, 'error': 'Path is required'}), 400
        flash('A page path is required to submit an access request.', 'error')
        return redirect(url_for('dashboard.index'))

    result = svc.create_request(
        requester_user_id=user_id,
        requested_path=path,
        reason=reason,
        page_title=page_title,
        module=module,
    )

    if request.is_json or request.headers.get('X-Requested-With') == 'XMLHttpRequest':
        return jsonify({
            'ok': True,
            'id': result['id'],
            'deduped': result['deduped'],
            'message': ('Your request is already pending — admins are notified.'
                        if result['deduped']
                        else 'Access request submitted. An admin will review shortly.'),
        })

    if result['deduped']:
        flash('You already have a pending request for this page. '
              'Admins have been re-notified.', 'success')
    else:
        flash('✅ Request submitted. Admins will review shortly and '
              'you will be notified once a decision is made.', 'success')
    return redirect(url_for('dashboard.index'))


@access_req_bp.route('/access-requests/<int:req_id>/cancel', methods=['POST'])
@_login_required
def cancel(req_id):
    n = svc.cancel_request(req_id, session['user_id'])
    if request.is_json:
        return jsonify({'ok': bool(n)})
    if n:
        flash('Access request cancelled.', 'success')
    return redirect(url_for('access_requests.admin_queue'))


# ── admin queue ─────────────────────────────────────────────────────
@access_req_bp.route('/admin/access-requests')
@_login_required
@_admin_required
def admin_queue():
    status = request.args.get('status') or None
    highlight = request.args.get('highlight', type=int)
    requests_rows = svc.list_requests(status=status)
    stats = {
        'pending': sum(1 for r in svc.list_requests(status='PENDING', limit=500)),
        'granted': sum(1 for r in svc.list_requests(status='GRANTED', limit=500)),
        'denied':  sum(1 for r in svc.list_requests(status='DENIED',  limit=500)),
    }
    return render_template(
        'access_requests/admin_queue.html',
        requests=requests_rows,
        status_filter=status,
        highlight_id=highlight,
        stats=stats,
    )


@access_req_bp.route('/admin/access-requests/<int:req_id>/grant', methods=['POST'])
@_login_required
@_admin_required
def grant(req_id):
    notes = (request.form.get('notes') or '').strip() or None
    ok = svc.grant_request(req_id, session['user_id'], notes)
    flash('Access granted — the user can now visit that page.' if ok
          else 'This request is no longer pending.',
          'success' if ok else 'error')
    return redirect(url_for('access_requests.admin_queue'))


@access_req_bp.route('/admin/access-requests/<int:req_id>/deny', methods=['POST'])
@_login_required
@_admin_required
def deny(req_id):
    notes = (request.form.get('notes') or '').strip() or None
    ok = svc.deny_request(req_id, session['user_id'], notes)
    flash('Request denied. Requester has been notified.' if ok
          else 'This request is no longer pending.',
          'success' if ok else 'error')
    return redirect(url_for('access_requests.admin_queue'))
