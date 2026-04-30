"""Attendance Blueprint — DTR, shifts, OT, corrections, calendar, holidays, time logging."""
from flask import Blueprint, render_template, request, redirect, url_for, \
    flash, session, g, send_file, jsonify
import io
from datetime import date, datetime
from services import attendance_service as svc

attendance_bp = Blueprint('attendance', __name__,
                          url_prefix='/attendance',
                          template_folder='../templates/attendance')


def _login_required(f):
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect('/login')
        return f(*args, **kwargs)
    return decorated


# ── DTR Browser ─────────────────────────────────────────────────

@attendance_bp.route('/dtr')
@_login_required
def dtr():
    date_from = request.args.get('date_from') or str(date.today() - __import__('datetime').timedelta(days=6))
    date_to   = request.args.get('date_to')   or str(date.today())
    dept_id   = request.args.get('dept_id', type=int)
    emp_id    = request.args.get('employee_id', type=int)
    status    = request.args.get('status')
    page      = request.args.get('page', 1, type=int)

    rows, total = svc.get_dtr(
        company_id=g.company_id,
        employee_id=emp_id,
        department_id=dept_id,
        date_from=date_from,
        date_to=date_to,
        status=status,
        page=page,
    )
    summary = svc.get_attendance_summary(g.company_id, date_from, date_to)
    departments = svc.get_departments(g.company_id)
    filters = {'date_from': date_from, 'date_to': date_to,
               'department_id': dept_id, 'employee_id': emp_id, 'status': status}
    return render_template('attendance/dtr.html',
                           rows=rows, total=total, page=page, per_page=50,
                           filters=filters, departments=departments,
                           summary=summary)


@attendance_bp.route('/dtr/<int:employee_id>/<work_date>')
@_login_required
def dtr_detail(employee_id, work_date):
    detail = svc.get_dtr_detail(employee_id, work_date)
    if not detail:
        flash('Record not found.', 'warning')
        return redirect(url_for('attendance.dtr'))
    return render_template('attendance/dtr_detail.html', detail=detail)


# ── Time Logging ────────────────────────────────────────────────

@attendance_bp.route('/timelog', methods=['GET', 'POST'])
@_login_required
def timelog():
    if request.method == 'POST':
        emp_id     = request.form.get('employee_id', type=int) or session.get('employee_id')
        log_type   = request.form.get('log_type', 'IN')
        log_dt     = request.form.get('log_datetime')
        log_method = request.form.get('log_method', 'WEB')
        if not emp_id or not log_dt:
            flash('Employee and datetime are required.', 'danger')
        else:
            row = svc.log_time(emp_id, log_dt, log_type, log_method=log_method)
            flash(f'Time log #{row["id"]} recorded via {log_method}.', 'success')
            work_date = log_dt[:10]
            try:
                svc.process_daily_attendance(emp_id, work_date)
            except Exception:
                pass
            return redirect(url_for('attendance.timelog'))

    employees   = svc.get_employees(g.company_id)
    recent_logs = svc.get_recent_logs(g.company_id, limit=50)
    return render_template('attendance/timelog.html',
                           employees=employees, recent_logs=recent_logs)


# ── Time Log API (for devices / kiosks / QR / Face / Biometric) ──

@attendance_bp.route('/api/timelog', methods=['POST'])
def timelog_api():
    """JSON API endpoint for external devices (kiosks, biometric, QR scanners).
    No session required — devices authenticate via device_id or API key."""
    data = request.get_json(force=True)
    # employee_id can be omitted when rfid_tag or pin_code is provided
    required = ['log_type', 'log_method']
    missing = [k for k in required if not data.get(k)]
    if missing:
        return jsonify(ok=False, error=f'Missing fields: {", ".join(missing)}'), 400
    if not data.get('employee_id') and not data.get('rfid_tag') and not data.get('pin_code'):
        return jsonify(ok=False, error='Provide employee_id, rfid_tag, or pin_code'), 400

    emp_id     = data.get('employee_id')
    log_type   = data.get('log_type', 'IN')
    log_method = data.get('log_method', 'API')
    device_id  = data.get('device_id')
    location   = data.get('location')
    photo_path = data.get('photo_path')
    log_dt     = data.get('log_datetime', datetime.now().isoformat())

    # RFID lookup — resolve rfid_tag to employee_id
    if log_method == 'RFID':
        rfid_tag = data.get('rfid_tag') or str(emp_id or '')
        if not rfid_tag:
            return jsonify(ok=False, error='rfid_tag is required for RFID method'), 400
        emp = svc.get_employee_by_rfid(rfid_tag, data.get('company_id', 1))
        if not emp:
            return jsonify(ok=False, error='RFID tag not recognized'), 404
        emp_id = emp['id']

    # QR lookup: if employee_id is a string (QR code), resolve it
    if isinstance(emp_id, str) and not emp_id.isdigit():
        emp = svc.get_employee_by_qr(emp_id, data.get('company_id', 1))
        if not emp:
            return jsonify(ok=False, error='Employee not found for QR code'), 404
        emp_id = emp['id']

    # PIN lookup
    if log_method == 'PIN':
        pin = data.get('pin_code') or str(emp_id or '')
        if not pin:
            return jsonify(ok=False, error='pin_code is required for PIN method'), 400
        emp = svc.get_employee_by_pin(pin, data.get('company_id', 1))
        if not emp:
            return jsonify(ok=False, error='Invalid PIN'), 404
        emp_id = emp['id']

    try:
        row = svc.log_time(emp_id, log_dt, log_type,
                           log_method=log_method, device_id=device_id,
                           location=location, photo_path=photo_path)
        # Auto-process daily attendance
        work_date = log_dt[:10]
        try:
            svc.process_daily_attendance(emp_id, work_date)
        except Exception:
            pass
        return jsonify(ok=True, log_id=row['id'], employee_id=row['employee_id'],
                       log_type=row['log_type'], log_method=row['log_method'],
                       log_datetime=str(row['log_datetime']))
    except ValueError as e:
        return jsonify(ok=False, error=str(e)), 400
    except Exception as e:
        return jsonify(ok=False, error=str(e)), 500


@attendance_bp.route('/api/timelog/recent')
def timelog_recent_api():
    """JSON feed of recent logs for live-updating UI."""
    company_id = request.args.get('company_id', 1, type=int)
    limit      = request.args.get('limit', 20, type=int)
    logs = svc.get_recent_logs(company_id, limit=min(limit, 100))
    return jsonify([dict(r) for r in logs])


# ── Shifts ──────────────────────────────────────────────────────

@attendance_bp.route('/shifts', methods=['GET'])
@_login_required
def shifts():
    rows = svc.get_shifts(g.company_id)
    return render_template('attendance/shifts.html', rows=rows)


@attendance_bp.route('/shifts/new', methods=['POST'])
@_login_required
def shift_new():
    svc.create_shift(
        company_id=g.company_id,
        code=request.form['code'],
        name=request.form['name'],
        shift_type=request.form.get('shift_type', 'FIXED'),
        time_in=request.form['time_in'],
        time_out=request.form['time_out'],
        break_minutes=int(request.form.get('break_minutes', 60)),
        grace_period_minutes=int(request.form.get('grace_period_minutes', 0)),
        total_work_hours=float(request.form['total_work_hours']) if request.form.get('total_work_hours') else None,
        is_night_shift='is_night_shift' in request.form,
    )
    flash('Shift created.', 'success')
    return redirect(url_for('attendance.shifts'))


@attendance_bp.route('/shifts/<int:shift_id>/delete', methods=['POST'])
@_login_required
def shift_delete(shift_id):
    svc.delete_shift(shift_id)
    flash('Shift deactivated.', 'success')
    return redirect(url_for('attendance.shifts'))


# ── Overtime ────────────────────────────────────────────────────

@attendance_bp.route('/overtime')
@_login_required
def overtime():
    status = request.args.get('status')
    emp_id = request.args.get('employee_id', type=int)
    page   = request.args.get('page', 1, type=int)
    rows, total = svc.get_overtime_requests(
        company_id=g.company_id, status=status, employee_id=emp_id, page=page)
    return render_template('attendance/overtime.html',
                           rows=rows, total=total, page=page, per_page=30,
                           status=status)


@attendance_bp.route('/overtime/new', methods=['GET', 'POST'])
@_login_required
def overtime_new():
    if request.method == 'POST':
        work_date = request.form.get('work_date')
        ot_hours  = request.form.get('ot_hours', type=float)
        reason    = request.form.get('reason', '').strip()
        emp_id    = request.form.get('employee_id', type=int) or session.get('employee_id')
        if not work_date or not ot_hours:
            flash('Work date and OT hours are required.', 'danger')
        else:
            ot_id = svc.submit_overtime(emp_id, work_date, ot_hours, reason,
                                        session['user_id'])
            flash(f'OT request #{ot_id} submitted.', 'success')
            return redirect(url_for('attendance.overtime'))
    employees = svc.get_employees(g.company_id)
    return render_template('attendance/overtime_new.html', employees=employees)


@attendance_bp.route('/overtime/<int:ot_id>/action', methods=['POST'])
@_login_required
def overtime_action(ot_id):
    action   = request.form.get('action_code', '').upper()
    comments = request.form.get('comments', '').strip()
    ot_hours = request.form.get('ot_hours_approved', type=float)
    result = svc.action_overtime(ot_id, action, session['user_id'],
                                 comments or None, ot_hours)
    flash(result['message'], 'success' if result['ok'] else 'danger')
    return redirect(url_for('attendance.overtime'))


# ── DTR Corrections ─────────────────────────────────────────────

@attendance_bp.route('/dtr/correction', methods=['GET', 'POST'])
@_login_required
def dtr_correction():
    if request.method == 'POST':
        emp_id    = request.form.get('employee_id', type=int) or session.get('employee_id')
        work_date = request.form.get('work_date')
        time_in   = request.form.get('correct_time_in')
        time_out  = request.form.get('correct_time_out')
        reason    = request.form.get('reason', '').strip()
        corr_id = svc.submit_correction(emp_id, work_date, time_in or None,
                                         time_out or None, reason,
                                         session['user_id'])
        flash(f'Correction #{corr_id} submitted.', 'success')
        return redirect(url_for('attendance.dtr_correction'))

    corrections = svc.get_corrections(
        company_id=g.company_id,
        employee_id=request.args.get('employee_id', type=int),
        status=request.args.get('status'),
    )
    employees = svc.get_employees(g.company_id)
    return render_template('attendance/dtr_correction.html',
                           corrections=corrections, employees=employees)


@attendance_bp.route('/dtr/correction/<int:corr_id>/action', methods=['POST'])
@_login_required
def correction_action(corr_id):
    action  = request.form.get('action_code', '').upper()
    remarks = request.form.get('remarks', '').strip()
    result = svc.action_correction(corr_id, action, session['user_id'], remarks)
    flash(result['message'], 'success' if result['ok'] else 'danger')
    return redirect(url_for('attendance.dtr_correction'))


# ── Calendar ────────────────────────────────────────────────────

@attendance_bp.route('/calendar')
@_login_required
def calendar():
    year  = request.args.get('year', date.today().year, type=int)
    month = request.args.get('month', date.today().month, type=int)
    emp_id = request.args.get('employee_id', session.get('employee_id'), type=int)
    data = svc.get_calendar_data(emp_id, year, month) if emp_id else []
    employees = svc.get_employees(g.company_id)
    return render_template('attendance/calendar.html',
                           data=data, year=year, month=month,
                           employee_id=emp_id, employees=employees)


# ── Holidays ────────────────────────────────────────────────────

@attendance_bp.route('/holidays')
@_login_required
def holidays():
    year = request.args.get('year', date.today().year, type=int)
    rows = svc.get_holidays(g.company_id, year)
    holiday_types = svc.get_holiday_types()
    return render_template('attendance/holidays.html',
                           holidays=rows, year=year, holiday_types=holiday_types)


@attendance_bp.route('/holidays/new', methods=['POST'])
@_login_required
def holiday_new():
    svc.add_holiday(
        company_id=g.company_id,
        holiday_date=request.form['holiday_date'],
        name=request.form['name'],
        holiday_type_id=request.form.get('holiday_type_id', type=int),
        created_by=session['user_id'],
    )
    flash('Holiday added.', 'success')
    return redirect(url_for('attendance.holidays'))


@attendance_bp.route('/holidays/<int:holiday_id>/delete', methods=['POST'])
@_login_required
def holiday_delete(holiday_id):
    svc.delete_holiday(holiday_id)
    flash('Holiday deleted.', 'success')
    return redirect(url_for('attendance.holidays'))


# ── Attendance Processing ───────────────────────────────────────

@attendance_bp.route('/process', methods=['POST'])
@_login_required
def process():
    date_from = request.form.get('date_from')
    date_to   = request.form.get('date_to')
    if not date_from or not date_to:
        flash('Date range is required.', 'danger')
        return redirect(url_for('attendance.dtr'))
    count = svc.bulk_process_attendance(g.company_id, date_from, date_to)
    flash(f'Processed {count} attendance records.', 'success')
    return redirect(url_for('attendance.dtr'))
