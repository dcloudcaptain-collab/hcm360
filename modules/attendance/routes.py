"""Attendance Blueprint — DTR, OT requests, corrections, calendar, holidays."""
from flask import Blueprint, render_template, request, redirect, url_for, \
    flash, session, jsonify, send_file, current_app
import io
from datetime import date, datetime
from modules.attendance import attendance_service as svc
from services import reporting_service

attendance_bp = Blueprint('attendance', __name__,
                          url_prefix='/attendance',
                          template_folder='../../templates/attendance')


def _login_required(f):
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated


# ---------------------------------------------------------------------------
# DTR Browser
# ---------------------------------------------------------------------------

@attendance_bp.route('/dtr')
@_login_required
def dtr():
    date_from   = request.args.get('date_from') or str(date.today() - __import__('datetime').timedelta(days=6))
    date_to     = request.args.get('date_to')   or str(date.today())
    dept_id     = request.args.get('dept_id',    type=int)
    emp_id      = request.args.get('employee_id', type=int)
    status      = request.args.get('status')
    page        = request.args.get('page', 1, type=int)

    rows, total = svc.get_dtr(
        employee_id=emp_id,
        department_id=dept_id,
        date_from=date_from,
        date_to=date_to,
        status=status,
        page=page,
    )
    shifts = svc.get_shifts()
    departments = svc.get_departments()
    filters = {'date_from': date_from, 'date_to': date_to,
               'department_id': dept_id, 'employee_id': emp_id, 'status': status}
    return render_template('attendance/dtr.html',
                           rows=rows, total=total, page=page, per_page=30,
                           filters=filters, shifts=shifts, departments=departments)


@attendance_bp.route('/dtr/<int:employee_id>/<work_date>/override', methods=['POST'])
@_login_required
def dtr_override(employee_id, work_date):
    """Admin direct edit of a DTR record — requires ATTENDANCE modify permission."""
    from services.access_service import can_modify
    role_code = session.get('role_code', '')
    user_id   = session.get('user_id')
    if not can_modify(role_code, 'ATTENDANCE', user_id):
        flash('You do not have permission to override attendance records.', 'danger')
        return redirect(url_for('attendance.dtr_detail',
                                employee_id=employee_id, work_date=work_date))

    new_time_in  = request.form.get('new_time_in', '').strip() or None
    new_time_out = request.form.get('new_time_out', '').strip() or None
    new_status   = request.form.get('new_status', '').strip() or None
    reason       = request.form.get('reason', '').strip()

    if not reason:
        flash('Reason is required for a DTR override.', 'danger')
        return redirect(url_for('attendance.dtr_detail',
                                employee_id=employee_id, work_date=work_date))

    result = svc.admin_override_dtr(
        employee_id=employee_id,
        work_date=work_date,
        new_time_in=new_time_in,
        new_time_out=new_time_out,
        new_status=new_status,
        reason=reason,
        overridden_by=user_id,
    )
    if result['ok']:
        flash(result['message'], 'success')
    else:
        flash(result['message'], 'danger')
    return redirect(url_for('attendance.dtr_detail',
                            employee_id=employee_id, work_date=work_date))


@attendance_bp.route('/dtr/<int:employee_id>/<work_date>')
@_login_required
def dtr_detail(employee_id, work_date):
    from services.access_service import can_modify
    detail = svc.get_dtr_detail(employee_id, work_date)
    if not detail:
        flash('Record not found.', 'warning')
        return redirect(url_for('attendance.dtr'))
    overrides = svc.get_dtr_overrides(employee_id, work_date)
    can_edit  = can_modify(session.get('role_code', ''), 'ATTENDANCE', session.get('user_id'))
    return render_template('attendance/dtr_detail.html', detail=detail,
                           overrides=overrides, can_edit=can_edit)


@attendance_bp.route('/dtr/correction', methods=['GET', 'POST'])
@_login_required
def dtr_correction():
    if request.method == 'POST':
        emp_id     = request.form.get('employee_id', type=int)
        work_date  = request.form.get('work_date')
        time_in    = request.form.get('correct_time_in')
        time_out   = request.form.get('correct_time_out')
        reason     = request.form.get('reason', '').strip()
        corr_id = svc.submit_correction(
            employee_id=emp_id or session['employee_id'],
            work_date=work_date,
            correct_time_in=time_in or None,
            correct_time_out=time_out or None,
            reason=reason,
            submitted_by=session['user_id'],
        )
        flash(f'Correction request #{corr_id} submitted successfully.', 'success')
        return redirect(url_for('attendance.dtr'))

    corrections = svc.get_corrections(
        employee_id=session.get('employee_id'),
        status=request.args.get('status'),
    )
    return render_template('attendance/dtr_correction.html',
                           corrections=corrections)


# ---------------------------------------------------------------------------
# Overtime
# ---------------------------------------------------------------------------

@attendance_bp.route('/overtime')
@_login_required
def overtime():
    status  = request.args.get('status')
    emp_id  = request.args.get('employee_id', type=int)
    page    = request.args.get('page', 1, type=int)
    rows, total = svc.get_overtime_requests(status=status,
                                            employee_id=emp_id, page=page)
    return render_template('attendance/overtime.html',
                           rows=rows, total=total, page=page, per_page=30,
                           status=status)


@attendance_bp.route('/overtime/new', methods=['GET', 'POST'])
@_login_required
def overtime_new():
    if request.method == 'POST':
        work_date = request.form.get('work_date')
        ot_hours  = request.form.get('expected_ot_hours', type=float) or request.form.get('ot_hours', type=float)
        reason    = request.form.get('reason', '').strip()
        if not work_date or not ot_hours:
            flash('Work date and OT hours are required.', 'danger')
        else:
            ot_id = svc.submit_overtime(
                employee_id=session['employee_id'],
                work_date=work_date,
                ot_hours=ot_hours,
                reason=reason,
                submitted_by=session['user_id'],
            )
            flash(f'OT request #{ot_id} submitted.', 'success')
            return redirect(url_for('attendance.overtime'))
    return render_template('attendance/overtime_new.html')


@attendance_bp.route('/overtime/<int:ot_id>/action', methods=['POST'])
@_login_required
def overtime_action(ot_id):
    action    = request.form.get('action_code', '').upper()
    comments  = request.form.get('comments', '').strip()
    ot_hours  = request.form.get('ot_hours_approved', type=float)
    result = svc.action_overtime(
        ot_id=ot_id,
        action_code=action,
        performed_by=session['user_id'],
        comments=comments or None,
        ot_hours_approved=ot_hours,
    )
    if result['ok']:
        flash(result['message'], 'success')
    else:
        flash(result['message'], 'danger')
    return redirect(url_for('attendance.overtime'))


# ---------------------------------------------------------------------------
# Calendar
# ---------------------------------------------------------------------------

@attendance_bp.route('/calendar')
@_login_required
def calendar():
    year  = request.args.get('year',  date.today().year,  type=int)
    month = request.args.get('month', date.today().month, type=int)
    emp_id = request.args.get('employee_id', session.get('employee_id'), type=int)
    data  = svc.get_calendar_data(emp_id, year, month)
    return render_template('attendance/calendar.html',
                           data=data, year=year, month=month,
                           employee_id=emp_id)


# ---------------------------------------------------------------------------
# Holidays
# ---------------------------------------------------------------------------

@attendance_bp.route('/holidays')
@_login_required
def holidays():
    year     = request.args.get('year', date.today().year, type=int)
    holidays = svc.get_holidays(year)
    return render_template('attendance/holidays.html',
                           holidays=holidays, year=year)


@attendance_bp.route('/holidays/new', methods=['POST'])
@_login_required
def holidays_new():
    holiday_date   = request.form.get('holiday_date')
    name           = request.form.get('name', '').strip()
    holiday_type_id = request.form.get('holiday_type_id', type=int)
    if not holiday_date or not name:
        flash('Date and name are required.', 'danger')
    else:
        svc.add_holiday(holiday_date, name, holiday_type_id,
                        added_by=session['user_id'])
        flash('Holiday added.', 'success')
    return redirect(url_for('attendance.holidays'))


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------

@attendance_bp.route('/dtr/export')
@_login_required
def dtr_export():
    from services.audit_service import log_export
    date_from = request.args.get('date_from') or str(date.today() - __import__('datetime').timedelta(days=6))
    date_to   = request.args.get('date_to')   or str(date.today())
    fmt       = request.args.get('fmt', 'csv')

    rows, _ = svc.get_dtr(date_from=date_from, date_to=date_to, per_page=9999)
    columns = [
        ('employee_no', 'Employee No'), ('full_name', 'Full Name'),
        ('department', 'Department'), ('work_date', 'Date'),
        ('shift_name', 'Shift'), ('time_in', 'Time In'),
        ('time_out', 'Time Out'), ('worked_hours', 'Worked Hours'),
        ('late_minutes', 'Late (min)'), ('ot_hours', 'OT Hours'),
        ('is_present', 'Present'), ('is_late', 'Late'),
        ('is_absent', 'Absent'),
    ]

    log_export(session['user_id'], 'ATTENDANCE_DTR',
               record_count=len(rows), file_format=fmt.upper())

    if fmt == 'xlsx':
        from services.reporting_service import to_xlsx
        data = to_xlsx(rows, sheet_name='DTR', columns=columns,
                       title=f'DTR {date_from} to {date_to}')
        return send_file(
            io.BytesIO(data),
            mimetype='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            as_attachment=True,
            download_name=f'dtr_{date_from}_{date_to}.xlsx',
        )
    else:
        from services.reporting_service import to_csv
        data = to_csv(rows, columns=columns)
        return send_file(
            io.BytesIO(data), mimetype='text/csv',
            as_attachment=True,
            download_name=f'dtr_{date_from}_{date_to}.csv',
        )


# ---------------------------------------------------------------------------
# CS Form No. 6 (revised 2020)
# ---------------------------------------------------------------------------

@attendance_bp.route('/cs-form6/<int:employee_id>')
@_login_required
def cs_form6(employee_id):
    month = request.args.get('month', type=int) or date.today().month
    year = request.args.get('year', type=int) or date.today().year
    data = svc.get_cs_form6_data(employee_id, month, year)
    return render_template('attendance/cs_form6.html', data=data)


# ---------------------------------------------------------------------------
# Attendance Alerts (Habitual Tardiness, AWOL, Low Leave)
# ---------------------------------------------------------------------------

@attendance_bp.route('/alerts')
@_login_required
def alerts():
    from services.db import get_cursor
    with get_cursor() as cur:
        cur.execute("SELECT id FROM core.companies LIMIT 1")
        company_id = cur.fetchone()['id']
    month = request.args.get('month', type=int) or date.today().month
    year = request.args.get('year', type=int) or date.today().year
    tardiness = svc.detect_habitual_tardiness(company_id, month, year)
    awol = svc.detect_awol(company_id, month, year)
    low_leave = svc.get_low_leave_alerts(company_id)
    return render_template('attendance/alerts.html',
                           tardiness=tardiness, awol=awol, low_leave=low_leave,
                           month=month, year=year)


# ---------------------------------------------------------------------------
# Shift Schedule Management
# ---------------------------------------------------------------------------

@attendance_bp.route('/shifts')
@_login_required
def shifts():
    all_shifts = svc.get_shifts()
    return render_template('attendance/shifts.html', shifts=all_shifts)


@attendance_bp.route('/shifts/save', methods=['POST'])
@_login_required
def save_shift():
    data = {
        'code': request.form.get('code'),
        'name': request.form.get('name'),
        'time_in': request.form.get('time_in'),
        'time_out': request.form.get('time_out'),
        'break_minutes': request.form.get('break_minutes', 60, type=int),
        'grace_period_minutes': request.form.get('grace_period_minutes', 15, type=int),
        'is_night_shift': request.form.get('is_night_shift') == '1',
        'crosses_midnight': request.form.get('crosses_midnight') == '1',
    }
    shift_id = request.form.get('shift_id', type=int)
    if shift_id:
        svc.update_shift(shift_id, data)
        flash('Shift updated.', 'success')
    else:
        svc.create_shift(data)
        flash('Shift created.', 'success')
    return redirect(url_for('attendance.shifts'))


@attendance_bp.route('/shift-assignments')
@_login_required
def shift_assignments():
    from services.db import get_cursor
    dept_id = request.args.get('department_id', type=int)
    assignments = svc.get_shift_assignments(department_id=dept_id)
    all_shifts = svc.get_shifts()
    with get_cursor() as cur:
        cur.execute("SELECT id, name FROM core.departments ORDER BY name")
        departments = cur.fetchall()
        cur.execute("SELECT id, first_name || ' ' || last_name AS name FROM core.employees WHERE is_active = TRUE ORDER BY last_name")
        employees = cur.fetchall()
    return render_template('attendance/shift_assignments.html',
                           assignments=assignments, shifts=all_shifts,
                           departments=departments, employees=employees, dept_id=dept_id)


@attendance_bp.route('/shift-assignments/assign', methods=['POST'])
@_login_required
def assign_shift():
    employee_id = request.form.get('employee_id', type=int)
    shift_id = request.form.get('shift_id', type=int)
    effective_from = request.form.get('effective_from')
    effective_to = request.form.get('effective_to') or None
    svc.assign_shift(employee_id, shift_id, effective_from, effective_to)
    flash('Shift assigned.', 'success')
    return redirect(url_for('attendance.shift_assignments'))


@attendance_bp.route('/shift-assignments/bulk', methods=['POST'])
@_login_required
def bulk_assign():
    employee_ids = request.form.getlist('employee_ids', type=int)
    shift_id = request.form.get('shift_id', type=int)
    effective_from = request.form.get('effective_from')
    effective_to = request.form.get('effective_to') or None
    count = svc.bulk_assign_shift(employee_ids, shift_id, effective_from, effective_to)
    flash(f'Shift assigned to {count} employee(s).', 'success')
    return redirect(url_for('attendance.shift_assignments'))
