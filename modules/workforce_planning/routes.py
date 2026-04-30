"""Workforce Planning Blueprint — scenario modeling, headcount planning, cost projections."""
from flask import Blueprint, render_template, request, redirect, url_for, \
    flash, session, g
from functools import wraps
from modules.workforce_planning import wfp_service as svc
from services.db import get_cursor

wfp_bp = Blueprint('wfp', __name__,
                   url_prefix='/workforce-planning',
                   template_folder='../../templates/workforce_planning')


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
        if session.get('role_code') not in ('SUPER_ADMIN', 'HR_ADMIN', 'EXECUTIVE'):
            flash('Access denied.', 'error')
            return redirect(url_for('dashboard.index'))
        return f(*args, **kwargs)
    return decorated


def _get_company_id():
    with get_cursor() as cur:
        cur.execute("SELECT id FROM core.companies LIMIT 1")
        row = cur.fetchone()
        return row['id'] if row else None


@wfp_bp.route('/')
@_login_required
@_hr_required
def index():
    stats = svc.get_wfp_stats()
    scenarios = svc.get_scenarios()
    current_vs_planned = svc.get_current_vs_planned()
    return render_template('workforce_planning/index.html',
                           stats=stats, scenarios=scenarios,
                           current_vs_planned=current_vs_planned)


@wfp_bp.route('/scenarios/new', methods=['GET', 'POST'])
@_login_required
@_hr_required
def scenario_new():
    if request.method == 'POST':
        assumptions = {
            'attrition_pct': request.form.get('attrition_pct', 5, type=float),
            'growth_pct': request.form.get('growth_pct', 3, type=float),
            'avg_salary_increase': request.form.get('avg_salary_increase', 5, type=float),
            'benefits_pct': request.form.get('benefits_pct', 25, type=float),
            'training_pct': request.form.get('training_pct', 2, type=float),
            'recruitment_cost_per_hire': request.form.get('recruitment_cost_per_hire', 15000, type=float),
        }
        sid = svc.create_scenario(
            _get_company_id(),
            request.form.get('name', '').strip(),
            request.form.get('description', '').strip(),
            request.form.get('scenario_type', 'HEADCOUNT'),
            request.form.get('horizon_months', 12, type=int),
            assumptions,
            session.get('user_id'),
        )
        svc.generate_headcount_plan(sid)
        flash('Scenario created with auto-generated projections.', 'success')
        return redirect(url_for('wfp.scenario_detail', scenario_id=sid), code=303)
    return render_template('workforce_planning/scenario_form.html')


@wfp_bp.route('/scenarios/<int:scenario_id>')
@_login_required
@_hr_required
def scenario_detail(scenario_id):
    data = svc.get_scenario(scenario_id)
    if not data:
        flash('Scenario not found.', 'error')
        return redirect(url_for('wfp.index'))
    return render_template('workforce_planning/scenario_detail.html', **data)


@wfp_bp.route('/scenarios/<int:scenario_id>/regenerate', methods=['POST'])
@_login_required
@_hr_required
def regenerate(scenario_id):
    svc.generate_headcount_plan(scenario_id)
    flash('Projections regenerated from current data.', 'success')
    return redirect(url_for('wfp.scenario_detail', scenario_id=scenario_id), code=303)


@wfp_bp.route('/scenarios/<int:scenario_id>/status', methods=['POST'])
@_login_required
@_hr_required
def scenario_status(scenario_id):
    svc.update_scenario_status(scenario_id, request.form.get('status', 'ACTIVE'))
    flash('Scenario status updated.', 'success')
    return redirect(url_for('wfp.scenario_detail', scenario_id=scenario_id), code=303)


@wfp_bp.route('/scenarios/<int:scenario_id>/skill', methods=['POST'])
@_login_required
@_hr_required
def add_skill(scenario_id):
    svc.add_skill_demand(
        scenario_id,
        request.form.get('skill_name', '').strip(),
        request.form.get('current_supply', 0, type=int),
        request.form.get('future_demand', 0, type=int),
        request.form.get('priority', 'MEDIUM'),
        request.form.get('mitigation', '').strip(),
    )
    flash('Skill demand added.', 'success')
    return redirect(url_for('wfp.scenario_detail', scenario_id=scenario_id), code=303)
