"""Onboarding Blueprint — HR lifecycle management + employee self-service view."""
from flask import Blueprint, render_template, request, redirect, url_for, \
    flash, session, g, jsonify
from functools import wraps
from modules.onboarding import onboarding_service as svc
from services.db import get_cursor

onboarding_bp = Blueprint('onboarding_mod', __name__,
                          url_prefix='/onboarding',
                          template_folder='../../templates/onboarding')


def _login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated


def _hr_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if session.get('role_code') not in ('SUPER_ADMIN', 'HR_ADMIN'):
            flash('Access denied.', 'error')
            return redirect(url_for('dashboard.index'))
        return f(*args, **kwargs)
    return decorated


# ---------------------------------------------------------------------------
# HR Admin — Onboarding Dashboard
# ---------------------------------------------------------------------------

@onboarding_bp.route('/')
@_login_required
def index():
    stats = svc.get_onboarding_stats()
    status_filter = request.args.get('status')
    onboardings = svc.get_onboarding_list(status=status_filter)
    return render_template('onboarding/index.html',
                           stats=stats, onboardings=onboardings,
                           status_filter=status_filter)


@onboarding_bp.route('/<int:checklist_id>')
@_login_required
def detail(checklist_id):
    data = svc.get_onboarding_detail(checklist_id)
    if not data:
        flash('Onboarding record not found.', 'error')
        return redirect(url_for('onboarding_mod.index'))
    # Get available employees for buddy assignment
    with get_cursor() as cur:
        cur.execute("""
            SELECT id, first_name || ' ' || last_name AS name
            FROM core.employees WHERE is_active = TRUE AND id != %s
            ORDER BY last_name
        """, (data['checklist']['employee_id'],))
        employees = cur.fetchall()
    return render_template('onboarding/detail.html', **data, employees=employees)


# ---------------------------------------------------------------------------
# Actions — Requirements
# ---------------------------------------------------------------------------

@onboarding_bp.route('/req/<int:req_id>/verify', methods=['POST'])
@_login_required
@_hr_required
def verify_req(req_id):
    svc.verify_requirement(req_id, session['user_id'], request.form.get('remarks'))
    flash('Requirement verified.', 'success')
    return redirect(request.referrer or url_for('onboarding_mod.index'))


@onboarding_bp.route('/req/<int:req_id>/reject', methods=['POST'])
@_login_required
@_hr_required
def reject_req(req_id):
    svc.reject_requirement(req_id, session['user_id'], request.form.get('remarks'))
    flash('Requirement rejected.', 'error')
    return redirect(request.referrer or url_for('onboarding_mod.index'))


@onboarding_bp.route('/req/<int:req_id>/submit', methods=['POST'])
@_login_required
def submit_req(req_id):
    svc.submit_requirement(req_id)
    flash('Requirement submitted.', 'success')
    return redirect(request.referrer or url_for('onboarding_mod.index'))


# ---------------------------------------------------------------------------
# Actions — Checklist Items
# ---------------------------------------------------------------------------

@onboarding_bp.route('/item/<int:item_id>/complete', methods=['POST'])
@_login_required
def complete_item(item_id):
    svc.complete_checklist_item(item_id, session['user_id'])
    flash('Item completed.', 'success')
    return redirect(request.referrer or url_for('onboarding_mod.index'))


# ---------------------------------------------------------------------------
# Actions — Welcome Items
# ---------------------------------------------------------------------------

@onboarding_bp.route('/welcome/<int:item_id>/complete', methods=['POST'])
@_login_required
def complete_welcome(item_id):
    svc.complete_welcome_item(item_id)
    flash('Welcome item completed.', 'success')
    return redirect(request.referrer or url_for('onboarding_mod.index'))


# ---------------------------------------------------------------------------
# Actions — Buddy
# ---------------------------------------------------------------------------

@onboarding_bp.route('/<int:checklist_id>/assign-buddy', methods=['POST'])
@_login_required
@_hr_required
def assign_buddy(checklist_id):
    data = svc.get_onboarding_detail(checklist_id)
    buddy_id = request.form.get('buddy_id', type=int)
    if buddy_id and data:
        svc.assign_buddy(data['checklist']['employee_id'], buddy_id)
        flash('Buddy assigned.', 'success')
    return redirect(url_for('onboarding_mod.detail', checklist_id=checklist_id))


# ---------------------------------------------------------------------------
# Actions — Sign-offs
# ---------------------------------------------------------------------------

@onboarding_bp.route('/<int:checklist_id>/signoff', methods=['POST'])
@_login_required
def signoff(checklist_id):
    signoff_type = request.form.get('signoff_type', 'BUDDY')
    approve = request.form.get('action') != 'reject'
    remarks = request.form.get('remarks', '')
    svc.submit_signoff(checklist_id, signoff_type, session['user_id'], remarks, approve)
    flash(f'{signoff_type} sign-off {"approved" if approve else "rejected"}.', 'success')
    return redirect(url_for('onboarding_mod.detail', checklist_id=checklist_id))


# ---------------------------------------------------------------------------
# Actions — Stage Advance
# ---------------------------------------------------------------------------

@onboarding_bp.route('/<int:checklist_id>/advance', methods=['POST'])
@_login_required
@_hr_required
def advance(checklist_id):
    new_stage = svc.advance_stage(checklist_id)
    if new_stage:
        flash(f'Advanced to stage: {new_stage}', 'success')
    else:
        flash('Cannot advance — completion criteria not met.', 'warning')
    return redirect(url_for('onboarding_mod.detail', checklist_id=checklist_id))


# ---------------------------------------------------------------------------
# Create new onboarding
# ---------------------------------------------------------------------------

@onboarding_bp.route('/create', methods=['POST'])
@_login_required
@_hr_required
def create():
    emp_id = request.form.get('employee_id', type=int)
    if not emp_id:
        flash('Employee is required.', 'error')
        return redirect(url_for('onboarding_mod.index'))
    cid = svc.create_onboarding(emp_id, assigned_hr=session.get('user_id'))
    flash('Onboarding created.', 'success')
    return redirect(url_for('onboarding_mod.detail', checklist_id=cid))
