"""
Job Requisition Blueprint.

Routes mounted at /rsp/requisitions (consistent with siblings /rsp/vacancies,
/rsp/applicants). A redirect alias is also exposed at /recruitment/requisitions*
so the gap-analysis-specified URL keeps working.
"""
import os
from functools import wraps
from flask import (Blueprint, render_template, request, redirect, url_for,
                    flash, session, jsonify, send_file, abort, make_response)

from services import requisition_service as svc
from services.db import get_cursor


requisitions_bp = Blueprint('requisitions', __name__,
                             url_prefix='/rsp/requisitions',
                             template_folder='../../templates/requisitions')

# Alias blueprint so /recruitment/requisitions/* → redirect to /rsp/requisitions/*
recruitment_alias_bp = Blueprint('recruitment_alias', __name__,
                                  url_prefix='/recruitment/requisitions')


def _login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated


def _role_required(*allowed):
    def deco(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            if 'user_id' not in session:
                return redirect(url_for('auth.login'))
            role = session.get('role_code')
            if role not in allowed:
                flash(f'Access denied — requires one of: {", ".join(allowed)}', 'error')
                return redirect(url_for('requisitions.list_view'))
            return f(*args, **kwargs)
        return decorated
    return deco


def _get_company_id():
    with get_cursor() as cur:
        cur.execute("SELECT id FROM core.companies ORDER BY id LIMIT 1")
        row = cur.fetchone()
        return row['id'] if row else None


def _can_create(role):
    return role in ('SUPER_ADMIN', 'HR_ADMIN', 'MANAGER')


def _can_approve(role):
    return role in ('SUPER_ADMIN', 'HR_ADMIN', 'MANAGER', 'EXECUTIVE')


# ══════════════════════════════════════════════════════════════════════
# List + alias
# ══════════════════════════════════════════════════════════════════════
@requisitions_bp.route('/')
@_login_required
def list_view():
    company_id = _get_company_id()
    status = request.args.get('status') or None
    dept_id = request.args.get('department_id', type=int)
    priority = request.args.get('priority') or None
    items = svc.list_requisitions(
        company_id=company_id,
        status=status,
        user_id=session.get('user_id'),
        role_code=session.get('role_code'),
        department_id=dept_id,
        priority=priority,
    )
    stats = svc.get_summary_stats(company_id)
    lookups = svc.get_form_lookups(company_id)

    return render_template('requisitions/list.html',
                           items=items,
                           stats=stats,
                           departments=lookups['departments'],
                           status_filter=status,
                           dept_filter=dept_id,
                           priority_filter=priority,
                           can_create=_can_create(session.get('role_code')))


@recruitment_alias_bp.route('/', defaults={'subpath': ''})
@recruitment_alias_bp.route('/<path:subpath>')
def alias_redirect(subpath):
    target = '/rsp/requisitions/'
    if subpath:
        target += subpath
    qs = request.query_string.decode('utf-8')
    if qs:
        target += '?' + qs
    return redirect(target, code=301)


# ══════════════════════════════════════════════════════════════════════
# New / Create
# ══════════════════════════════════════════════════════════════════════
@requisitions_bp.route('/new', methods=['GET', 'POST'])
@_login_required
def new():
    role = session.get('role_code')
    if not _can_create(role):
        flash('Only SUPER_ADMIN, HR_ADMIN, or MANAGER can create requisitions.', 'error')
        return redirect(url_for('requisitions.list_view'))

    company_id = _get_company_id()
    lookups = svc.get_form_lookups(company_id)

    clone_id = request.args.get('clone', type=int)
    preset = {}
    if clone_id:
        data = svc.get_requisition(clone_id)
        if data:
            preset = dict(data['row'])

    if request.method == 'POST':
        form = {k: v for k, v in request.form.items()}
        do_submit = form.get('action') == 'submit'
        try:
            req_id, ref_no = svc.create_requisition(
                company_id=company_id,
                form=form,
                user_id=session['user_id'],
                submit=do_submit,
            )
            flash(f'Requisition {ref_no} created.' +
                  (' Submitted for approval.' if do_submit else ' Saved as DRAFT.'),
                  'success')
            return redirect(url_for('requisitions.view', req_id=req_id))
        except Exception as ex:
            flash(f'Error: {ex}', 'error')

    return render_template('requisitions/new.html',
                           lookups=lookups,
                           preset=preset,
                           clone_id=clone_id)


# ══════════════════════════════════════════════════════════════════════
# Detail
# ══════════════════════════════════════════════════════════════════════
@requisitions_bp.route('/<int:req_id>')
@_login_required
def view(req_id):
    data = svc.get_requisition(req_id, user_id=session.get('user_id'),
                                role_code=session.get('role_code'))
    if not data:
        flash('Requisition not found.', 'error')
        return redirect(url_for('requisitions.list_view'))

    r = data['row']
    warn = svc.wfp_warning(r.get('department_id'), r.get('headcount'))
    duplicates = svc.find_duplicates(r.get('position_id'), exclude_id=req_id)
    role = session.get('role_code')

    # Can this user act on the current workflow step?
    can_approve_now = (
        r.get('status') == 'PENDING_APPROVAL'
        and r.get('current_step_role')
        and (role == 'SUPER_ADMIN' or role == r.get('current_step_role'))
    )

    return render_template('requisitions/view.html',
                           r=r,
                           attachments=data['attachments'],
                           history=data['history'],
                           postings=data['postings'],
                           chain=data['chain'],
                           wfp_warning=warn,
                           duplicates=duplicates,
                           can_approve=can_approve_now,
                           can_cancel=(r.get('status') in ('DRAFT', 'PENDING_APPROVAL')
                                       and (role in ('SUPER_ADMIN', 'HR_ADMIN')
                                            or r.get('requested_by') == session.get('user_id'))),
                           can_submit=(r.get('status') == 'DRAFT'
                                       and r.get('requested_by') == session.get('user_id')),
                           is_super=(role == 'SUPER_ADMIN'))


# ══════════════════════════════════════════════════════════════════════
# Transitions
# ══════════════════════════════════════════════════════════════════════
@requisitions_bp.route('/<int:req_id>/submit', methods=['POST'])
@_login_required
def submit(req_id):
    result = svc.submit(req_id, session['user_id'])
    flash(result['message'], 'success' if result['ok'] else 'error')
    return redirect(url_for('requisitions.view', req_id=req_id))


@requisitions_bp.route('/<int:req_id>/approve', methods=['POST'])
@_login_required
def approve(req_id):
    role = session.get('role_code')
    if not _can_approve(role):
        flash('You do not have permission to approve.', 'error')
        return redirect(url_for('requisitions.view', req_id=req_id))
    remarks = (request.form.get('remarks') or '').strip()
    approved_hc = request.form.get('approved_headcount', type=int)
    result = svc.approve(req_id, session['user_id'], remarks, approved_hc)
    flash(result['message'], 'success' if result['ok'] else 'error')
    return redirect(url_for('requisitions.view', req_id=req_id))


@requisitions_bp.route('/<int:req_id>/reject', methods=['POST'])
@_login_required
def reject(req_id):
    role = session.get('role_code')
    if not _can_approve(role):
        flash('You do not have permission to reject.', 'error')
        return redirect(url_for('requisitions.view', req_id=req_id))
    reason = (request.form.get('reason') or '').strip()
    result = svc.reject(req_id, session['user_id'], reason)
    flash(result['message'], 'success' if result['ok'] else 'error')
    return redirect(url_for('requisitions.view', req_id=req_id))


@requisitions_bp.route('/<int:req_id>/cancel', methods=['POST'])
@_login_required
def cancel(req_id):
    reason = (request.form.get('reason') or '').strip()
    result = svc.cancel(req_id, session['user_id'], reason)
    flash(result['message'], 'success' if result['ok'] else 'error')
    return redirect(url_for('requisitions.view', req_id=req_id))


@requisitions_bp.route('/<int:req_id>/clone', methods=['POST'])
@_login_required
def clone(req_id):
    if not _can_create(session.get('role_code')):
        flash('You cannot clone requisitions.', 'error')
        return redirect(url_for('requisitions.view', req_id=req_id))
    new_id, new_ref = svc.clone_requisition(req_id, session['user_id'])
    if not new_id:
        flash('Clone failed.', 'error')
        return redirect(url_for('requisitions.view', req_id=req_id))
    flash(f'Cloned into new DRAFT {new_ref}.', 'success')
    return redirect(url_for('requisitions.view', req_id=new_id))


# ══════════════════════════════════════════════════════════════════════
# CSC Form PDF
# ══════════════════════════════════════════════════════════════════════
@requisitions_bp.route('/<int:req_id>/csc-form.pdf')
@_login_required
def csc_form_pdf(req_id):
    pdf_bytes = svc.render_csc_form_pdf(req_id)
    if not pdf_bytes:
        abort(404)
    resp = make_response(pdf_bytes)
    resp.headers['Content-Type'] = 'application/pdf'
    resp.headers['Content-Disposition'] = f'inline; filename=requisition-{req_id}.pdf'
    return resp


# ══════════════════════════════════════════════════════════════════════
# Duplicate-detection AJAX
# ══════════════════════════════════════════════════════════════════════
@requisitions_bp.route('/<int:req_id>/duplicates')
@_login_required
def duplicates_json(req_id):
    data = svc.get_requisition(req_id)
    if not data:
        return jsonify({'ok': False, 'error': 'Not found'}), 404
    dups = svc.find_duplicates(data['row'].get('position_id'), exclude_id=req_id)
    return jsonify({
        'ok': True,
        'duplicates': [{
            'id': d['id'],
            'reference_no': d['reference_no'],
            'status': d['status'],
            'headcount': d['headcount'],
            'requested_by_name': d['requested_by_name'],
            'department_name': d['department_name'],
            'created_at': d['created_at'].isoformat() if d.get('created_at') else None,
        } for d in dups],
    })


# Duplicate check for the NEW form (no req_id yet)
@requisitions_bp.route('/check-duplicates')
@_login_required
def check_duplicates_json():
    position_id = request.args.get('position_id', type=int)
    dups = svc.find_duplicates(position_id) if position_id else []
    return jsonify({
        'ok': True,
        'duplicates': [{
            'id': d['id'],
            'reference_no': d['reference_no'],
            'status': d['status'],
            'headcount': d['headcount'],
            'requested_by_name': d['requested_by_name'],
            'department_name': d['department_name'],
        } for d in dups],
    })


# ══════════════════════════════════════════════════════════════════════
# Attachments
# ══════════════════════════════════════════════════════════════════════
UPLOAD_ROOT = '/app/uploads/requisitions'


@requisitions_bp.route('/<int:req_id>/attachments', methods=['POST'])
@_login_required
def upload_attachment(req_id):
    if 'file' not in request.files:
        flash('No file selected.', 'error')
        return redirect(url_for('requisitions.view', req_id=req_id))
    f = request.files['file']
    if not f or not f.filename:
        flash('No file selected.', 'error')
        return redirect(url_for('requisitions.view', req_id=req_id))

    attachment_type = request.form.get('attachment_type') or 'OTHER'
    os.makedirs(f'{UPLOAD_ROOT}/{req_id}', exist_ok=True)
    safe_name = f.filename.replace('/', '_').replace('\\', '_')
    dest = f'{UPLOAD_ROOT}/{req_id}/{safe_name}'
    f.save(dest)
    size_kb = int(os.path.getsize(dest) / 1024)
    svc.save_attachment(req_id, attachment_type, safe_name, dest,
                        size_kb, f.mimetype or 'application/octet-stream',
                        session['user_id'])
    flash(f'Uploaded {safe_name}.', 'success')
    return redirect(url_for('requisitions.view', req_id=req_id))
