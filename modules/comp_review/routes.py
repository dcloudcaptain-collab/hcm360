"""Compensation Review Blueprint."""
from flask import Blueprint, render_template, request, redirect, url_for, flash, session

from modules.comp_review import comp_review_service as svc

comp_review_bp = Blueprint('comp_review', __name__,
                           url_prefix='/comp-review',
                           template_folder='../../templates/comp_review')


@comp_review_bp.route('/')
def index():
    cycles = svc.get_review_cycles()
    return render_template('comp_review/index.html', cycles=cycles)


@comp_review_bp.route('/create', methods=['POST'])
def create():
    company_id = request.form.get('company_id', 1, type=int)
    name = request.form.get('name', '')
    year = request.form.get('year', type=int)
    review_type = request.form.get('review_type', 'ANNUAL')
    budget_amount = request.form.get('budget_amount', 0, type=float)
    budget_pct = request.form.get('budget_pct', 0, type=float)
    open_date = request.form.get('open_date')
    close_date = request.form.get('close_date')
    created_by = session.get('user_id')
    cid = svc.create_cycle(company_id, name, year, review_type,
                           budget_amount, budget_pct, open_date, close_date, created_by)
    flash(f'Compensation review cycle created (ID {cid}).', 'success')
    return redirect(url_for('comp_review.detail', cycle_id=cid))


@comp_review_bp.route('/<int:cycle_id>')
def detail(cycle_id):
    cycle, worksheets = svc.get_cycle_detail(cycle_id)
    if not cycle:
        flash('Cycle not found.', 'error')
        return redirect(url_for('comp_review.index'))
    summary, by_dept = svc.get_budget_summary(cycle_id)
    return render_template('comp_review/detail.html',
                           cycle=cycle, worksheets=worksheets,
                           summary=summary, by_dept=by_dept)


@comp_review_bp.route('/<int:cycle_id>/worksheet', methods=['POST'])
def add_worksheet(cycle_id):
    employee_id = request.form.get('employee_id', type=int)
    manager_id = request.form.get('manager_id', type=int)
    current_salary = request.form.get('current_salary', 0, type=float)
    svc.create_worksheet(cycle_id, employee_id, manager_id, current_salary)
    flash('Worksheet added.', 'success')
    return redirect(url_for('comp_review.detail', cycle_id=cycle_id))


@comp_review_bp.route('/worksheet/<int:worksheet_id>/update', methods=['POST'])
def update_worksheet(worksheet_id):
    cycle_id = request.form.get('cycle_id', type=int)
    svc.update_worksheet(
        worksheet_id,
        proposed_increase_pct=request.form.get('proposed_increase_pct', type=float),
        bonus_amount=request.form.get('bonus_amount', type=float),
        manager_justification=request.form.get('manager_justification'),
        hr_notes=request.form.get('hr_notes'),
    )
    flash('Worksheet updated.', 'success')
    return redirect(url_for('comp_review.detail', cycle_id=cycle_id))


@comp_review_bp.route('/worksheet/<int:worksheet_id>/approve', methods=['POST'])
def approve_worksheet(worksheet_id):
    cycle_id = request.form.get('cycle_id', type=int)
    status = request.form.get('status', 'APPROVED')
    svc.approve_worksheet(worksheet_id, status)
    flash(f'Worksheet {status.lower()}.', 'success')
    return redirect(url_for('comp_review.detail', cycle_id=cycle_id))


@comp_review_bp.route('/<int:cycle_id>/finalize', methods=['POST'])
def finalize(cycle_id):
    svc.finalize_cycle(cycle_id)
    flash('Cycle finalized.', 'success')
    return redirect(url_for('comp_review.detail', cycle_id=cycle_id))
