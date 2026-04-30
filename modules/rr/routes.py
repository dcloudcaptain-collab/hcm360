"""RR Blueprint — Rewards & Recognition."""
from flask import Blueprint, render_template, request, redirect, url_for, flash, session
from functools import wraps
from modules.rr import rr_service as svc
from services.db import get_cursor

rr_bp = Blueprint('rr', __name__,
                  url_prefix='/rr',
                  template_folder='../../templates/rr')


def _login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated


@rr_bp.route('/nominations')
@_login_required
def nominations():
    with get_cursor() as cur:
        cur.execute("""
            SELECT n.*, c.name AS category_name,
                   e.first_name || ' ' || e.last_name AS nominee_name,
                   u.display_name AS nominated_by_name
            FROM rewards.rwd_nominations n
            JOIN rewards.rwd_categories c ON c.id = n.category_id
            JOIN core.employees e ON e.id = n.nominee_employee_id
            JOIN core.users u ON u.id = n.nominated_by
            ORDER BY n.created_at DESC
        """)
        noms = cur.fetchall()
    return render_template('rr/nominations.html', nominations=noms)


@rr_bp.route('/step-increments')
@_login_required
def step_increments():
    status = request.args.get('status')
    increments = svc.get_step_increments(status=status)
    return render_template('rr/step_increments.html',
                           increments=increments, status_filter=status)


@rr_bp.route('/step-increments/compute', methods=['POST'])
@_login_required
def compute_increments():
    count = svc.compute_step_increment_eligibility()
    flash(f'Step increment eligibility computed: {count} records processed.', 'success')
    return redirect(url_for('rr.step_increments'))


@rr_bp.route('/step-increments/<int:inc_id>/process', methods=['POST'])
@_login_required
def process_increment(inc_id):
    eff_date = request.form.get('effective_date')
    svc.process_step_increment(inc_id, session['user_id'], eff_date)
    flash('Step increment processed.', 'success')
    return redirect(url_for('rr.step_increments'))


@rr_bp.route('/loyalty')
@_login_required
def loyalty():
    status = request.args.get('status')
    milestones = svc.get_loyalty_milestones(status=status)
    return render_template('rr/loyalty_awards.html',
                           milestones=milestones, status_filter=status)


@rr_bp.route('/loyalty/scan', methods=['POST'])
@_login_required
def scan_loyalty():
    count = svc.scan_loyalty_milestones()
    flash(f'Loyalty scan complete: {count} milestones checked.', 'success')
    return redirect(url_for('rr.loyalty'))


@rr_bp.route('/pbb')
@_login_required
def pbb():
    year = request.args.get('year', type=int)
    tier = request.args.get('tier')
    records = svc.get_pbb_records(year=year, tier=tier)
    return render_template('rr/pbb.html', records=records, year=year, tier_filter=tier)


@rr_bp.route('/retirement-notices')
@_login_required
def retirement_notices():
    from datetime import date
    notices = svc.get_retirement_notices()
    return render_template('rr/retirement_notices.html', notices=notices, today=date.today())


@rr_bp.route('/retirement-notices/schedule', methods=['POST'])
@_login_required
def schedule_alerts():
    count = svc.schedule_retirement_alerts()
    flash(f'Retirement alerts scheduled: {count} notices.', 'success')
    return redirect(url_for('rr.retirement_notices'))


@rr_bp.route('/ssl-table')
@_login_required
def ssl_table():
    sg = request.args.get('salary_grade', type=int)
    rows = svc.get_ssl_table(salary_grade=sg)
    return render_template('rr/ssl_table.html', rows=rows, sg_filter=sg)
