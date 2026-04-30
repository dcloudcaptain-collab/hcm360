"""Config Blueprint — admin settings, rate tables, contribution schedules."""
from flask import Blueprint, render_template, request, redirect, url_for, flash, session, g
from services import config_service as svc

config_bp = Blueprint('config', __name__,
                      url_prefix='/config',
                      template_folder='../templates/config')


def _login_required(f):
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect('/login')
        return f(*args, **kwargs)
    return decorated


# ── Settings (key-value) ────────────────────────────────────────

@config_bp.route('/')
@_login_required
def index():
    rows = svc.get_all_config(g.company_id)
    return render_template('config/settings.html', rows=rows)


@config_bp.route('/save', methods=['POST'])
@_login_required
def save_settings():
    for key in request.form:
        if key.startswith('cfg_'):
            config_key = key[4:]
            svc.set_config(g.company_id, config_key,
                          request.form[key], session['user_id'])
    flash('Settings saved.', 'success')
    return redirect(url_for('config.index'))


# ── Rate Tables ─────────────────────────────────────────────────

@config_bp.route('/rates')
@_login_required
def rates():
    rows = svc.get_rate_tables(g.company_id)
    return render_template('config/rates.html', rows=rows)


@config_bp.route('/rates/save', methods=['POST'])
@_login_required
def rates_save():
    svc.upsert_rate(
        g.company_id,
        request.form['rate_code'],
        request.form['rate_name'],
        float(request.form['multiplier']),
        request.form.get('description', ''),
    )
    flash('Rate saved.', 'success')
    return redirect(url_for('config.rates'))


@config_bp.route('/rates/<int:rate_id>/delete', methods=['POST'])
@_login_required
def rates_delete(rate_id):
    svc.delete_rate(rate_id)
    flash('Rate deleted.', 'success')
    return redirect(url_for('config.rates'))


# ── SSS Schedule ────────────────────────────────────────────────

@config_bp.route('/sss')
@_login_required
def sss():
    rows = svc.get_sss_schedule()
    return render_template('config/sss.html', rows=rows)


@config_bp.route('/sss/save', methods=['POST'])
@_login_required
def sss_save():
    svc.upsert_sss_bracket(
        request.form.get('bracket_id', type=int) or None,
        request.form['effective_date'],
        float(request.form['bracket_from']),
        float(request.form['bracket_to']),
        float(request.form['monthly_salary_credit']),
        float(request.form['ee_contribution']),
        float(request.form['er_contribution']),
        float(request.form.get('ec_contribution', 10)),
    )
    flash('SSS bracket saved.', 'success')
    return redirect(url_for('config.sss'))


@config_bp.route('/sss/<int:bracket_id>/delete', methods=['POST'])
@_login_required
def sss_delete(bracket_id):
    svc.delete_sss_bracket(bracket_id)
    flash('SSS bracket deleted.', 'success')
    return redirect(url_for('config.sss'))


# ── GSIS Schedule ───────────────────────────────────────────────

@config_bp.route('/gsis')
@_login_required
def gsis():
    rows = svc.get_gsis_schedule()
    return render_template('config/gsis.html', rows=rows)


@config_bp.route('/gsis/save', methods=['POST'])
@_login_required
def gsis_save():
    svc.upsert_gsis_bracket(
        request.form.get('bracket_id', type=int) or None,
        request.form['effective_date'],
        float(request.form['bracket_from']),
        float(request.form['bracket_to']),
        float(request.form['ee_pct']),
        float(request.form['er_pct']),
        float(request.form.get('life_insurance_pct', 0)),
    )
    flash('GSIS bracket saved.', 'success')
    return redirect(url_for('config.gsis'))


@config_bp.route('/gsis/<int:bracket_id>/delete', methods=['POST'])
@_login_required
def gsis_delete(bracket_id):
    svc.delete_gsis_bracket(bracket_id)
    flash('GSIS bracket deleted.', 'success')
    return redirect(url_for('config.gsis'))


# ── PhilHealth Schedule ─────────────────────────────────────────

@config_bp.route('/philhealth')
@_login_required
def philhealth():
    rows = svc.get_philhealth_schedule()
    return render_template('config/philhealth.html', rows=rows)


@config_bp.route('/philhealth/save', methods=['POST'])
@_login_required
def philhealth_save():
    svc.upsert_philhealth_bracket(
        request.form.get('bracket_id', type=int) or None,
        request.form['effective_date'],
        float(request.form['bracket_from']),
        float(request.form['bracket_to']),
        float(request.form['premium_rate']),
        float(request.form['ee_share']),
        float(request.form['er_share']),
        float(request.form.get('min_premium', 500)),
        float(request.form.get('max_premium', 5000)),
    )
    flash('PhilHealth bracket saved.', 'success')
    return redirect(url_for('config.philhealth'))


@config_bp.route('/philhealth/<int:bracket_id>/delete', methods=['POST'])
@_login_required
def philhealth_delete(bracket_id):
    svc.delete_philhealth_bracket(bracket_id)
    flash('PhilHealth bracket deleted.', 'success')
    return redirect(url_for('config.philhealth'))


# ── Pag-IBIG Schedule ──────────────────────────────────────────

@config_bp.route('/pagibig')
@_login_required
def pagibig():
    rows = svc.get_pagibig_schedule()
    return render_template('config/pagibig.html', rows=rows)


@config_bp.route('/pagibig/save', methods=['POST'])
@_login_required
def pagibig_save():
    svc.upsert_pagibig_bracket(
        request.form.get('bracket_id', type=int) or None,
        request.form['effective_date'],
        float(request.form['bracket_from']),
        float(request.form['bracket_to']),
        float(request.form['ee_pct']),
        float(request.form['er_pct']),
    )
    flash('Pag-IBIG bracket saved.', 'success')
    return redirect(url_for('config.pagibig'))


@config_bp.route('/pagibig/<int:bracket_id>/delete', methods=['POST'])
@_login_required
def pagibig_delete(bracket_id):
    svc.delete_pagibig_bracket(bracket_id)
    flash('Pag-IBIG bracket deleted.', 'success')
    return redirect(url_for('config.pagibig'))


# ── BIR Tax Tables ──────────────────────────────────────────────

@config_bp.route('/tax')
@_login_required
def tax():
    rows = svc.get_all_tax_tables()
    return render_template('config/tax.html', rows=rows)


@config_bp.route('/tax/save', methods=['POST'])
@_login_required
def tax_save():
    svc.upsert_tax_bracket(
        request.form.get('bracket_id', type=int) or None,
        request.form['effective_date'],
        request.form['frequency'],
        float(request.form['bracket_from']),
        float(request.form['bracket_to']),
        float(request.form['base_tax']),
        float(request.form['excess_pct']),
    )
    flash('Tax bracket saved.', 'success')
    return redirect(url_for('config.tax'))


@config_bp.route('/tax/<int:bracket_id>/delete', methods=['POST'])
@_login_required
def tax_delete(bracket_id):
    svc.delete_tax_bracket(bracket_id)
    flash('Tax bracket deleted.', 'success')
    return redirect(url_for('config.tax'))
