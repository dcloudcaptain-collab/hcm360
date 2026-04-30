"""Analytics/Reporting Blueprint — /reports."""
from flask import Blueprint, render_template, request, redirect, url_for, \
    flash, session, send_file, jsonify, current_app
import io, json
from datetime import date, datetime, timedelta
from modules.analytics import analytics_service as svc
from services import reporting_service, demographics_service as demo_svc
from services import report_builder_service as rb_svc
from services.access_service import get_allowed_source_ids

analytics_bp = Blueprint('analytics', __name__,
                         url_prefix='/reports',
                         template_folder='../../templates/analytics')


def _login_required(f):
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated


# ---------------------------------------------------------------------------
# Reporting Hub
# ---------------------------------------------------------------------------

@analytics_bp.route('/')
@_login_required
def index():
    role_code = session.get('role_code')
    widgets   = svc.get_dashboard_widgets(role_code=role_code)
    return render_template('analytics/overview.html', widgets=widgets)


# ---------------------------------------------------------------------------
# Headcount
# ---------------------------------------------------------------------------

@analytics_bp.route('/headcount')
@_login_required
def headcount():
    by_dept  = svc.get_headcount_by_dept()
    trend    = svc.get_headcount_trend(months=6)
    attrition = svc.get_attrition_summary()
    return render_template('analytics/headcount.html',
                           by_dept=by_dept, trend=trend,
                           attrition=attrition)


# ---------------------------------------------------------------------------
# Attendance report
# ---------------------------------------------------------------------------

@analytics_bp.route('/attendance')
@_login_required
def attendance():
    date_from = request.args.get('date_from') or str(date.today() - timedelta(days=29))
    date_to   = request.args.get('date_to')   or str(date.today())
    late_data = svc.get_late_analysis(date_from, date_to)
    ot_data   = svc.get_ot_summary(date_from, date_to)
    rate_trend = svc.get_attendance_rate_trend()
    return render_template('analytics/attendance.html',
                           late_data=late_data, ot_data=ot_data,
                           rate_trend=rate_trend,
                           date_from=date_from, date_to=date_to)


# ---------------------------------------------------------------------------
# Leave report
# ---------------------------------------------------------------------------

@analytics_bp.route('/leave')
@_login_required
def leave():
    utilization = svc.get_leave_utilization_ytd()
    trend       = svc.get_leave_trend(months=6)
    return render_template('analytics/leave.html',
                           utilization=utilization, trend=trend)


# ---------------------------------------------------------------------------
# Payroll report
# ---------------------------------------------------------------------------

@analytics_bp.route('/payroll')
@_login_required
def payroll():
    cost_mtd = svc.get_payroll_cost_mtd()
    trend    = svc.get_payroll_trend(months=6)
    return render_template('analytics/payroll_report.html',
                           cost_mtd=cost_mtd, trend=trend)


# ---------------------------------------------------------------------------
# KPI snapshot dashboard
# ---------------------------------------------------------------------------

@analytics_bp.route('/kpis')
@_login_required
def kpis():
    module = request.args.get('module')
    data   = svc.get_kpi_snapshot(module=module)
    trend  = None
    kpi_code = request.args.get('kpi_code')
    if module and kpi_code:
        trend = svc.get_kpi_trend(module, kpi_code, days=30)
    return render_template('analytics/kpis.html',
                           data=data, module=module,
                           kpi_code=kpi_code, trend=trend)


# ---------------------------------------------------------------------------
# KPI trend API (JSON — for chart.js)
# ---------------------------------------------------------------------------

@analytics_bp.route('/kpis/trend.json')
@_login_required
def kpi_trend_json():
    module   = request.args.get('module', 'attendance')
    kpi_code = request.args.get('kpi_code', 'PRESENT_TODAY')
    days     = request.args.get('days', 30, type=int)
    trend    = svc.get_kpi_trend(module, kpi_code, days=days)
    return jsonify([
        {'date': str(r['snapshot_date']), 'value': float(r['kpi_value'] or 0)}
        for r in trend
    ])


# ---------------------------------------------------------------------------
# Report Builder + Export
# ---------------------------------------------------------------------------

@analytics_bp.route('/reports')
@_login_required
def reports():
    return render_template('analytics/reports.html',
                           report_types=list(reporting_service.REPORT_QUERIES.keys()))


@analytics_bp.route('/export', methods=['POST'])
@_login_required
def export():
    from services.audit_service import log_export
    report_type = request.form.get('report_type', 'headcount')
    fmt         = request.form.get('fmt', 'xlsx')

    # Build dynamic params from form
    params = {}
    for key in ('date_from', 'date_to', 'pay_run_id', 'department_id'):
        val = request.form.get(key)
        if val:
            params[key] = val

    sql = reporting_service.REPORT_QUERIES.get(report_type)
    if not sql:
        flash(f'Unknown report type: {report_type}', 'danger')
        return redirect(url_for('analytics.reports'))

    try:
        data, mimetype, ext = reporting_service.build_report(
            sql=sql, params=params or None, fmt=fmt,
            sheet_name=report_type.replace('_', ' ').title(),
            title=report_type.replace('_', ' ').title(),
        )
    except Exception as e:
        flash(f'Export failed: {e}', 'danger')
        return redirect(url_for('analytics.reports'))

    log_export(session['user_id'], report_type.upper(),
               file_format=fmt.upper())

    filename = f'{report_type}_{date.today().isoformat()}.{ext}'
    return send_file(io.BytesIO(data), mimetype=mimetype,
                     as_attachment=True, download_name=filename)


# ---------------------------------------------------------------------------
# Admin: manual KPI refresh
# ---------------------------------------------------------------------------

@analytics_bp.route('/kpis/refresh', methods=['POST'])
@_login_required
def kpi_refresh():
    module = request.form.get('module') or None
    svc.refresh_kpi_snapshot(module=module)
    flash('KPI snapshot refreshed.', 'success')
    return redirect(url_for('analytics.kpis', module=module))


# ---------------------------------------------------------------------------
# HR Demographics Reports (PRIME-HRM)
# ---------------------------------------------------------------------------

@analytics_bp.route('/demographics')
@_login_required
def demographics():
    from services.db import get_cursor
    with get_cursor() as cur:
        cur.execute("SELECT id FROM core.companies LIMIT 1")
        row = cur.fetchone()
    company_id = row['id'] if row else None
    if not company_id:
        flash('No company configured.', 'error')
        return redirect(url_for('analytics.index'))

    year = request.args.get('year', type=int) or date.today().year
    reports = {
        'gender_profile': demo_svc.gender_profile(company_id),
        'age_profile': demo_svc.age_profile(company_id),
        'appointment_status': demo_svc.appointment_status(company_id),
        'rank_classification': demo_svc.rank_classification(company_id),
        'educational_attainment': demo_svc.educational_attainment(company_id),
        'eligibility_profile': demo_svc.eligibility_profile(company_id),
        'plantilla_summary': demo_svc.plantilla_summary(company_id),
        'salary_grade_dist': demo_svc.salary_grade_distribution(company_id),
        'training_participation': demo_svc.training_participation(company_id, year=year),
    }
    return render_template('analytics/demographics.html', reports=reports, year=year)


# ---------------------------------------------------------------------------
# REPORT BUILDER — custom drag-and-drop report creation
# ---------------------------------------------------------------------------

@analytics_bp.route('/builder')
@_login_required
def builder():
    sources = rb_svc.get_data_sources()
    # Filter by access grants (SUPER_ADMIN bypass inside get_allowed_source_ids)
    allowed = get_allowed_source_ids(session.get('role_code'), session.get('user_id'))
    sources = [s for s in sources if s['id'] in allowed]
    source_id = request.args.get('source_id', type=int)
    # Block query on a source the user cannot access
    if source_id and source_id not in allowed:
        flash('You do not have access to that data source.', 'error')
        source_id = None
    fields = rb_svc.get_fields_for_source(source_id) if source_id else []
    return render_template('analytics/builder.html',
                           sources=sources, fields=fields,
                           source_id=source_id)


@analytics_bp.route('/builder/fields/<int:source_id>')
@_login_required
def builder_fields(source_id):
    """JSON API: return fields for a given data source (for dynamic UI)."""
    allowed = get_allowed_source_ids(session.get('role_code'), session.get('user_id'))
    if source_id not in allowed:
        return jsonify({'error': 'forbidden'}), 403
    fields = rb_svc.get_fields_for_source(source_id)
    return jsonify([dict(f) for f in fields])


@analytics_bp.route('/builder/preview', methods=['POST'])
@_login_required
def builder_preview():
    """Run report and return JSON preview (first 50 rows)."""
    from decimal import Decimal
    from datetime import timedelta as td, time as tm
    data = request.get_json(silent=True) or {}
    source_id = data.get('source_id')
    config = data.get('config', {})
    config['limit'] = min(int(config.get('limit', 50)), 50)

    # Access gate
    allowed = get_allowed_source_ids(session.get('role_code'), session.get('user_id'))
    if source_id and int(source_id) not in allowed:
        return jsonify({'ok': False, 'error': 'forbidden'}), 403

    def _safe(v):
        if v is None:
            return None
        if isinstance(v, Decimal):
            return float(v)
        if isinstance(v, (date, datetime)):
            return v.isoformat()
        if isinstance(v, td):
            total = int(v.total_seconds())
            h, m = divmod(total // 60, 60)
            return f"{h}:{m:02d}"
        if isinstance(v, tm):
            return v.strftime('%H:%M')
        return v

    try:
        rows, col_order = rb_svc.execute_report(source_id, config)
        clean = []
        for r in rows:
            d = dict(r) if hasattr(r, 'keys') else r
            clean.append({str(k): _safe(v) for k, v in d.items()})
        return jsonify({'status': 'ok', 'rows': clean, 'columns': col_order, 'count': len(clean)})
    except Exception as e:
        import traceback
        current_app.logger.error(f"Preview error: {traceback.format_exc()}")
        return jsonify({'status': 'error', 'message': str(e)}), 400


@analytics_bp.route('/builder/export', methods=['POST'])
@_login_required
def builder_export():
    """Execute report and download as CSV/XLSX/PDF."""
    from services.audit_service import log_export
    data = request.form
    source_id = int(data.get('source_id', 0))
    config = json.loads(data.get('config', '{}'))
    fmt = data.get('fmt', 'xlsx')
    report_name = data.get('report_name', 'Custom Report')

    config['limit'] = min(int(config.get('limit', 5000)), 10000)

    try:
        sql, params = rb_svc.build_query(source_id, config)
        file_data, mimetype, ext = reporting_service.build_report(
            sql=sql, params=params, fmt=fmt,
            sheet_name=report_name[:31],
            title=report_name
        )
    except Exception as e:
        flash(f'Export failed: {e}', 'danger')
        return redirect(url_for('analytics.builder', source_id=source_id))

    # Log run
    report_id = data.get('report_id', type=int)
    from services.db import get_cursor
    with get_cursor() as cur:
        cur.execute(sql, params)
        row_count = cur.rowcount
    rb_svc.log_report_run(report_id, session['user_id'], fmt.upper(), row_count)
    log_export(session['user_id'], 'CUSTOM_REPORT', file_format=fmt.upper())

    filename = f'{report_name.replace(" ", "_")}_{date.today().isoformat()}.{ext}'
    return send_file(io.BytesIO(file_data), mimetype=mimetype,
                     as_attachment=True, download_name=filename)


# ---------------------------------------------------------------------------
# SAVED REPORTS
# ---------------------------------------------------------------------------

@analytics_bp.route('/saved')
@_login_required
def saved_reports():
    reports = rb_svc.list_saved_reports(user_id=session['user_id'])
    return render_template('analytics/saved_reports.html', reports=reports)


@analytics_bp.route('/saved/save', methods=['POST'])
@_login_required
def save_report():
    data = {
        'id': request.form.get('report_id', type=int),
        'name': request.form.get('name', 'Untitled Report'),
        'description': request.form.get('description', ''),
        'source_id': request.form.get('source_id', type=int),
        'config': request.form.get('config', '{}'),
        'is_shared': request.form.get('is_shared') == 'on',
    }
    rb_svc.save_report(data, session['user_id'])
    flash('Report saved.', 'success')
    return redirect(url_for('analytics.saved_reports'))


@analytics_bp.route('/saved/<int:report_id>/delete', methods=['POST'])
@_login_required
def delete_report(report_id):
    rb_svc.delete_report(report_id, session['user_id'])
    flash('Report deleted.', 'success')
    return redirect(url_for('analytics.saved_reports'))


@analytics_bp.route('/saved/<int:report_id>/run')
@_login_required
def run_saved_report(report_id):
    """Load a saved report into the builder."""
    rpt = rb_svc.get_saved_report(report_id)
    if not rpt:
        flash('Report not found.', 'error')
        return redirect(url_for('analytics.saved_reports'))
    allowed = get_allowed_source_ids(session.get('role_code'), session.get('user_id'))
    if rpt['source_id'] not in allowed:
        flash('You do not have access to the data source backing this report.', 'error')
        return redirect(url_for('analytics.saved_reports'))
    sources = [s for s in rb_svc.get_data_sources() if s['id'] in allowed]
    fields = rb_svc.get_fields_for_source(rpt['source_id'])
    return render_template('analytics/builder.html',
                           sources=sources, fields=fields,
                           source_id=rpt['source_id'],
                           saved_report=rpt)


# ---------------------------------------------------------------------------
# SCHEDULED REPORTS
# ---------------------------------------------------------------------------

@analytics_bp.route('/scheduled')
@_login_required
def scheduled():
    schedules = rb_svc.get_schedules()
    history = rb_svc.get_run_history(limit=20)
    saved_reports = rb_svc.list_saved_reports(user_id=session.get('user_id'))
    return render_template('analytics/scheduled.html',
                           schedules=schedules, history=history, saved_reports=saved_reports)


_ALLOWED_SCHEDULE_TYPES = {'DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY', 'YEARLY'}
_ALLOWED_OUTPUT_FORMATS = {'XLSX', 'CSV', 'PDF'}


@analytics_bp.route('/scheduled/save', methods=['POST'])
@_login_required
def save_schedule():
    # ── Validation ────────────────────────────────────────────────
    report_id = request.form.get('report_id', type=int)
    if not report_id:
        flash('Report is required.', 'error')
        return redirect(url_for('analytics.scheduled'))

    stype = (request.form.get('schedule_type') or 'WEEKLY').upper()
    if stype not in _ALLOWED_SCHEDULE_TYPES:
        flash(f'Invalid schedule type: {stype}. Must be one of '
              f'{", ".join(sorted(_ALLOWED_SCHEDULE_TYPES))}.', 'error')
        return redirect(url_for('analytics.scheduled'))

    output_format = (request.form.get('output_format') or 'XLSX').upper()
    if output_format not in _ALLOWED_OUTPUT_FORMATS:
        flash(f'Invalid output format: {output_format}. Must be one of '
              f'{", ".join(sorted(_ALLOWED_OUTPUT_FORMATS))}.', 'error')
        return redirect(url_for('analytics.scheduled'))

    # Parse recipients — accept JSON array, comma-separated string, or blank
    raw = (request.form.get('recipients') or '').strip()
    recipients = []
    if raw:
        try:
            import json as _json
            parsed = _json.loads(raw)
            if isinstance(parsed, list):
                recipients = [str(r).strip() for r in parsed if str(r).strip()]
            elif isinstance(parsed, str):
                recipients = [parsed.strip()] if parsed.strip() else []
        except Exception:
            # Fallback: treat as comma-separated
            recipients = [r.strip() for r in raw.split(',') if r.strip()]

    # Bound day fields
    dow = request.form.get('day_of_week', type=int)
    if dow is not None and (dow < 0 or dow > 6):
        dow = None
    dom = request.form.get('day_of_month', type=int)
    if dom is not None and (dom < 1 or dom > 31):
        dom = None

    data = {
        'id': request.form.get('schedule_id', type=int),
        'report_id': report_id,
        'schedule_type': stype,
        'day_of_week': dow,
        'day_of_month': dom,
        'run_time': request.form.get('run_time', '07:00'),
        'output_format': output_format,
        'recipients': recipients,
        'is_enabled': request.form.get('is_enabled') == 'on',
    }

    try:
        rb_svc.save_schedule(data, session['user_id'])
    except Exception as ex:
        current_app.logger.error(f'Schedule save failed: {ex}')
        flash(f'Could not save schedule: {ex}', 'error')
        return redirect(url_for('analytics.scheduled'))

    flash('Schedule saved.', 'success')
    return redirect(url_for('analytics.scheduled'))


@analytics_bp.route('/run-history')
@_login_required
def run_history():
    report_id = request.args.get('report_id', type=int)
    history = rb_svc.get_run_history(report_id=report_id, limit=100)
    return render_template('analytics/run_history.html', history=history)
