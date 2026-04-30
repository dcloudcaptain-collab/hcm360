"""Attendance module service — DTR, OT requests, corrections, holidays."""
from datetime import date, timedelta
from services.db import get_cursor
from services import workflow_service, notification_service


# ---------------------------------------------------------------------------
# DTR / Daily Logs
# ---------------------------------------------------------------------------

def get_dtr(employee_id=None, department_id=None, date_from=None, date_to=None,
            status=None, page=1, per_page=50):
    """Return att_daily rows with employee info, paginated."""
    date_to   = date_to   or date.today()
    date_from = date_from or (date_to - timedelta(days=6))

    conditions = ['ad.work_date BETWEEN %s AND %s']
    params     = [date_from, date_to]

    if employee_id:
        conditions.append('ad.employee_id = %s')
        params.append(employee_id)
    if department_id:
        conditions.append('e.department_id = %s')
        params.append(department_id)
    if status == 'PRESENT':
        conditions.append("ad.status = 'PRESENT'")
    elif status == 'LATE':
        conditions.append("ad.status = 'LATE'")
    elif status == 'ABSENT':
        conditions.append("ad.status = 'ABSENT'")

    where = ' AND '.join(conditions)
    offset = (page - 1) * per_page

    with get_cursor() as cur:
        cur.execute(f"""
            SELECT
                ad.id, ad.work_date, ad.employee_id,
                e.employee_no, e.full_name,
                d.name AS department,
                s.name AS shift_name,
                ad.time_in, ad.time_out, ad.hours_worked,
                ad.hours_late, ad.hours_overtime,
                ad.status AS attendance_status,
                ad.is_holiday, ad.is_restday, ad.remarks
            FROM attendance.att_daily ad
            JOIN core.v_employees_full e     ON e.id = ad.employee_id
            JOIN core.departments d   ON d.id = e.department_id
            LEFT JOIN attendance.att_shifts s ON s.id = ad.shift_id
            WHERE {where}
            ORDER BY ad.work_date DESC, d.name, e.full_name
            LIMIT %s OFFSET %s
        """, params + [per_page, offset])
        rows = cur.fetchall()

        cur.execute(f"""
            SELECT COUNT(*)
            FROM attendance.att_daily ad
            JOIN core.v_employees_full e ON e.id = ad.employee_id
            WHERE {where}
        """, params)
        total = cur.fetchone()['count']

    return rows, total


def get_dtr_detail(employee_id, work_date):
    with get_cursor() as cur:
        cur.execute("""
            SELECT ad.*, e.employee_no, e.full_name,
                   d.name AS department, s.name AS shift_name,
                   s.time_in AS shift_start, s.time_out AS shift_end
            FROM attendance.att_daily ad
            JOIN core.v_employees_full e   ON e.id = ad.employee_id
            JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN attendance.att_shifts s ON s.id = ad.shift_id
            WHERE ad.employee_id = %s AND ad.work_date = %s
        """, (employee_id, work_date))
        return cur.fetchone()


# ---------------------------------------------------------------------------
# OT Requests
# ---------------------------------------------------------------------------

def get_overtime_requests(status=None, employee_id=None, page=1, per_page=30):
    conditions = ['1=1']
    params     = []
    if status:
        conditions.append('aor.status = %s')
        params.append(status)
    if employee_id:
        conditions.append('aor.employee_id = %s')
        params.append(employee_id)
    where  = ' AND '.join(conditions)
    offset = (page - 1) * per_page

    with get_cursor() as cur:
        cur.execute(f"""
            SELECT
                aor.id, aor.request_date, aor.expected_ot_hours,
                NULL AS ot_hours_approved, aor.reason, aor.status,
                aor.workflow_instance_id, aor.created_at,
                e.employee_no, e.full_name,
                d.name AS department,
                approver.display_name AS approved_by_name
            FROM attendance.att_overtime_requests aor
            JOIN core.v_employees_full e   ON e.id = aor.employee_id
            JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.users approver ON approver.id = aor.approved_by
            WHERE {where}
            ORDER BY aor.created_at DESC
            LIMIT %s OFFSET %s
        """, params + [per_page, offset])
        rows = cur.fetchall()
        cur.execute(f"""
            SELECT COUNT(*) FROM attendance.att_overtime_requests aor
            JOIN core.v_employees_full e ON e.id = aor.employee_id
            WHERE {where}
        """, params)
        total = cur.fetchone()['count']
    return rows, total


def submit_overtime(employee_id, work_date, ot_hours, reason, submitted_by):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO attendance.att_overtime_requests
                (employee_id, request_date, expected_ot_hours, reason, status)
            VALUES (%s, %s, %s, %s, 'PENDING')
            RETURNING id
        """, (employee_id, work_date, ot_hours, reason))
        ot_id = cur.fetchone()['id']

    instance_id = workflow_service.create_instance(
        definition_code='OT_APPROVAL',
        module='attendance',
        entity_type='att_overtime_requests',
        entity_id=ot_id,
        initiated_by=submitted_by,
        reference_no=f'OT-{ot_id:05d}',
    )
    if instance_id:
        with get_cursor(commit=True) as cur:
            cur.execute("""
                UPDATE attendance.att_overtime_requests
                SET workflow_instance_id = %s WHERE id = %s
            """, (instance_id, ot_id))

    return ot_id


def action_overtime(ot_id, action_code, performed_by, comments=None,
                    ot_hours_approved=None):
    with get_cursor() as cur:
        cur.execute("""
            SELECT workflow_instance_id, employee_id, expected_ot_hours, request_date
            FROM attendance.att_overtime_requests WHERE id = %s
        """, (ot_id,))
        req = cur.fetchone()

    if not req:
        return {'ok': False, 'message': 'OT request not found.'}

    # Execute workflow action
    result = workflow_service.execute_action(
        req['workflow_instance_id'], action_code, performed_by, comments
    )
    if not result['ok']:
        return result

    new_status = 'APPROVED' if action_code == 'APPROVE' else 'REJECTED'
    hours_approved = ot_hours_approved if action_code == 'APPROVE' else None

    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE attendance.att_overtime_requests
            SET status = %s, approved_by = %s,
                approved_at = NOW()
            WHERE id = %s
        """, (new_status, performed_by, ot_id))

        # Update att_daily ot_hours if approved
        if new_status == 'APPROVED' and hours_approved:
            cur.execute("""
                UPDATE attendance.att_daily
                SET hours_overtime = %s
                WHERE employee_id = %s AND work_date = %s
            """, (hours_approved, req['employee_id'], req['request_date']))

    # In-app notification to employee
    notification_service.notify(
        user_id=None,  # resolved via employee_id lookup in notify()
        event_type='OT_APPROVED' if new_status == 'APPROVED' else 'OT_REJECTED',
        payload={'ot_id': ot_id, 'status': new_status},
    )
    return result


# ---------------------------------------------------------------------------
# DTR Corrections
# ---------------------------------------------------------------------------

def submit_correction(employee_id, work_date, correct_time_in,
                      correct_time_out, reason, submitted_by):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO attendance.att_dtr_corrections
                (employee_id, work_date, correct_time_in,
                 correct_time_out, reason, status)
            VALUES (%s, %s, %s, %s, %s, 'PENDING')
            RETURNING id
        """, (employee_id, work_date, correct_time_in,
              correct_time_out, reason))
        corr_id = cur.fetchone()['id']

    workflow_service.create_instance(
        definition_code='DTR_CORRECTION',
        module='attendance',
        entity_type='att_dtr_corrections',
        entity_id=corr_id,
        initiated_by=submitted_by,
        reference_no=f'DTRC-{corr_id:05d}',
    )
    return corr_id


def admin_override_dtr(employee_id, work_date, new_time_in, new_time_out,
                       new_status, reason, overridden_by):
    """Directly update att_daily and log the change in att_admin_overrides."""
    from decimal import Decimal
    with get_cursor() as cur:
        cur.execute("""
            SELECT time_in, time_out, hours_worked, status
            FROM attendance.att_daily
            WHERE employee_id = %s AND work_date = %s
        """, (employee_id, work_date))
        orig = cur.fetchone()

    if not orig:
        return {'ok': False, 'message': 'No attendance record found for that date.'}

    # Compute hours_worked from new times if both provided
    new_hours = orig['hours_worked']
    if new_time_in and new_time_out:
        from datetime import datetime
        fmt = '%Y-%m-%d %H:%M'
        try:
            ti = datetime.strptime(f'{work_date} {new_time_in}', fmt)
            to = datetime.strptime(f'{work_date} {new_time_out}', fmt)
            new_hours = round((to - ti).total_seconds() / 3600, 2)
        except ValueError:
            pass

    new_time_in_ts  = f'{work_date} {new_time_in}'  if new_time_in  else None
    new_time_out_ts = f'{work_date} {new_time_out}' if new_time_out else None

    with get_cursor(commit=True) as cur:
        # Write audit log first
        cur.execute("""
            INSERT INTO attendance.att_admin_overrides
                (employee_id, work_date,
                 orig_time_in, orig_time_out, orig_hours, orig_status,
                 new_time_in,  new_time_out,  new_hours,  new_status,
                 reason, overridden_by)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (employee_id, work_date,
              orig['time_in'], orig['time_out'], orig['hours_worked'], orig['status'],
              new_time_in_ts, new_time_out_ts, new_hours, new_status or orig['status'],
              reason, overridden_by))

        # Apply override
        cur.execute("""
            UPDATE attendance.att_daily SET
                time_in      = COALESCE(%s::TIMESTAMP, time_in),
                time_out     = COALESCE(%s::TIMESTAMP, time_out),
                hours_worked = %s,
                status       = %s
            WHERE employee_id = %s AND work_date = %s
        """, (new_time_in_ts, new_time_out_ts, new_hours,
              new_status or orig['status'], employee_id, work_date))

    return {'ok': True, 'message': f'DTR for {work_date} updated successfully.'}


def get_dtr_overrides(employee_id, work_date):
    """Return admin override history for a specific DTR record."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT o.*, u.display_name AS overridden_by_name
            FROM attendance.att_admin_overrides o
            JOIN core.users u ON u.id = o.overridden_by
            WHERE o.employee_id = %s AND o.work_date = %s
            ORDER BY o.overridden_at DESC
        """, (employee_id, work_date))
        return cur.fetchall()


def get_corrections(employee_id=None, status=None):
    conditions = ['1=1']
    params     = []
    if employee_id:
        conditions.append('c.employee_id = %s')
        params.append(employee_id)
    if status:
        conditions.append('c.status = %s')
        params.append(status)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT c.*, e.employee_no, e.full_name, d.name AS department
            FROM attendance.att_dtr_corrections c
            JOIN core.v_employees_full e   ON e.id = c.employee_id
            JOIN core.departments d ON d.id = e.department_id
            WHERE {' AND '.join(conditions)}
            ORDER BY c.created_at DESC
        """, params)
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Attendance Calendar (monthly heatmap data)
# ---------------------------------------------------------------------------

def get_calendar_data(employee_id, year, month):
    """Return all att_daily rows for an employee for a given month."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT work_date, time_in, time_out, hours_worked,
                   hours_late, hours_overtime, status,
                   is_holiday, is_restday, remarks
            FROM attendance.att_daily
            WHERE employee_id = %s
              AND EXTRACT(YEAR  FROM work_date) = %s
              AND EXTRACT(MONTH FROM work_date) = %s
            ORDER BY work_date
        """, (employee_id, year, month))
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Holidays
# ---------------------------------------------------------------------------

def get_holidays(year=None):
    year = year or date.today().year
    with get_cursor() as cur:
        cur.execute("""
            SELECT h.holiday_date, h.name, ht.name AS type_name, ht.pay_multiplier
            FROM attendance.att_holidays h
            JOIN attendance.att_holiday_types ht ON ht.id = h.holiday_type_id
            WHERE EXTRACT(YEAR FROM h.holiday_date) = %s
            ORDER BY h.holiday_date
        """, (year,))
        return cur.fetchall()


def add_holiday(holiday_date, name, holiday_type_id, added_by):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO attendance.att_holidays
                (holiday_date, name, holiday_type_id, created_by)
            VALUES (%s, %s, %s, %s)
            RETURNING id
        """, (holiday_date, name, holiday_type_id, added_by))
        return cur.fetchone()['id']


# ---------------------------------------------------------------------------
# Shifts
# ---------------------------------------------------------------------------

def get_departments():
    with get_cursor() as cur:
        cur.execute("""
            SELECT id, name FROM core.departments WHERE is_active = TRUE ORDER BY name
        """)
        return cur.fetchall()


def get_shifts():
    with get_cursor() as cur:
        cur.execute("""
            SELECT id, code, name, shift_type, time_in, time_out,
                   break_minutes, grace_period_minutes, is_night_shift
            FROM attendance.att_shifts
            WHERE is_active = TRUE ORDER BY code
        """)
        return cur.fetchall()


# ---------------------------------------------------------------------------
# CS Form No. 6 — Daily Time Record (revised 2020)
# ---------------------------------------------------------------------------

def get_cs_form6_data(employee_id, month, year):
    """DTR data formatted for CS Form 6: AM in/out, PM in/out, undertime, per day."""
    import calendar
    days_in_month = calendar.monthrange(year, month)[1]
    first = date(year, month, 1)
    last = date(year, month, days_in_month)

    with get_cursor() as cur:
        cur.execute("""
            SELECT e.first_name || ' ' || e.last_name AS employee_name,
                   e.employee_no, d.name AS department_name,
                   p.title AS position_title
            FROM core.employees e
            LEFT JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.positions p ON p.id = e.position_id
            WHERE e.id = %s
        """, (employee_id,))
        emp = cur.fetchone()

        cur.execute("""
            SELECT ad.work_date, ad.time_in, ad.time_out,
                   ad.hours_late, ad.hours_undertime, ad.hours_worked,
                   ad.status, ad.is_holiday, ad.is_restday, ad.remarks,
                   sh.time_in AS sched_in, sh.time_out AS sched_out
            FROM attendance.att_daily ad
            LEFT JOIN attendance.att_shift_assignments sa
                ON sa.employee_id = ad.employee_id
                AND ad.work_date BETWEEN sa.effective_from AND COALESCE(sa.effective_to, '9999-12-31')
            LEFT JOIN attendance.att_shifts sh ON sh.id = sa.shift_id
            WHERE ad.employee_id = %s AND ad.work_date BETWEEN %s AND %s
            ORDER BY ad.work_date
        """, (employee_id, first, last))
        entries = cur.fetchall()

    # Build day-indexed dict
    dtr_map = {e['work_date']: e for e in entries}
    days = []
    total_late = 0
    total_undertime = 0
    for d in range(1, days_in_month + 1):
        dt = date(year, month, d)
        entry = dtr_map.get(dt)
        row = {
            'day': d, 'date': dt, 'weekday': dt.strftime('%a'),
            'am_in': None, 'am_out': None, 'pm_in': None, 'pm_out': None,
            'hours_undertime': 0, 'status': None, 'remarks': '',
        }
        if entry:
            row['status'] = entry['status']
            row['remarks'] = entry['remarks'] or ''
            row['hours_undertime'] = float(entry['hours_undertime'] or 0)
            total_late += float(entry['hours_late'] or 0)
            total_undertime += float(entry['hours_undertime'] or 0)
            # Split time_in/time_out into AM/PM (noon = 12:00)
            if entry['time_in']:
                t = entry['time_in']
                if hasattr(t, 'hour'):
                    row['am_in'] = t.strftime('%H:%M') if t.hour < 12 else None
                    row['pm_in'] = t.strftime('%H:%M') if t.hour >= 12 else None
                else:
                    row['am_in'] = str(t)[:5]
            if entry['time_out']:
                t = entry['time_out']
                if hasattr(t, 'hour'):
                    row['am_out'] = t.strftime('%H:%M') if t.hour <= 12 else None
                    row['pm_out'] = t.strftime('%H:%M') if t.hour > 12 else None
                else:
                    row['pm_out'] = str(t)[:5]
            if entry['is_holiday']:
                row['remarks'] = 'HOLIDAY'
            if entry['is_restday']:
                row['remarks'] = 'REST DAY'
        else:
            if dt.weekday() >= 5:
                row['remarks'] = 'SAT' if dt.weekday() == 5 else 'SUN'
        days.append(row)

    return {
        'employee': emp, 'month': month, 'year': year,
        'days': days, 'total_late': total_late, 'total_undertime': total_undertime,
    }


# ---------------------------------------------------------------------------
# Habitual Tardiness / AWOL / Low Leave Detection
# ---------------------------------------------------------------------------

def detect_habitual_tardiness(company_id, month, year):
    """Employees with >= 7 tardiness instances in a given month."""
    first = date(year, month, 1)
    import calendar
    last = date(year, month, calendar.monthrange(year, month)[1])
    with get_cursor() as cur:
        cur.execute("""
            SELECT e.id AS employee_id,
                   e.first_name || ' ' || e.last_name AS employee_name,
                   d.name AS department_name,
                   COUNT(*) AS late_count,
                   SUM(ad.hours_late) AS total_late_hours
            FROM attendance.att_daily ad
            JOIN core.employees e ON e.id = ad.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            WHERE e.company_id = %s
              AND ad.work_date BETWEEN %s AND %s
              AND ad.status = 'LATE'
            GROUP BY e.id, e.first_name, e.last_name, d.name
            HAVING COUNT(*) >= 7
            ORDER BY COUNT(*) DESC
        """, (company_id, first, last))
        return cur.fetchall()


def detect_awol(company_id, month, year):
    """Employees absent without approved leave in a given month."""
    first = date(year, month, 1)
    import calendar
    last = date(year, month, calendar.monthrange(year, month)[1])
    with get_cursor() as cur:
        cur.execute("""
            SELECT e.id AS employee_id,
                   e.first_name || ' ' || e.last_name AS employee_name,
                   d.name AS department_name,
                   COUNT(*) AS awol_days,
                   ARRAY_AGG(ad.work_date ORDER BY ad.work_date) AS awol_dates
            FROM attendance.att_daily ad
            JOIN core.employees e ON e.id = ad.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            WHERE e.company_id = %s
              AND ad.work_date BETWEEN %s AND %s
              AND ad.status = 'ABSENT'
              AND ad.leave_request_id IS NULL
            GROUP BY e.id, e.first_name, e.last_name, d.name
            ORDER BY COUNT(*) DESC
        """, (company_id, first, last))
        return cur.fetchall()


def get_low_leave_alerts(company_id):
    """Employees with Vacation Leave balance < 5 days."""
    yr = date.today().year
    with get_cursor() as cur:
        cur.execute("""
            SELECT e.id AS employee_id,
                   e.first_name || ' ' || e.last_name AS employee_name,
                   d.name AS department_name,
                   lb.balance
            FROM leave_mgmt.lv_balances lb
            JOIN leave_mgmt.lv_types lt ON lt.id = lb.leave_type_id
            JOIN core.employees e ON e.id = lb.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            WHERE e.company_id = %s AND e.is_active = TRUE
              AND lb.year = %s
              AND lt.code = 'VL'
              AND lb.balance < 5
            ORDER BY lb.balance ASC
        """, (company_id, yr))
        return cur.fetchall()


def validate_date_overlap(employee_id, date_from, date_to):
    """Check for overlapping leave requests, travel orders, or attendance entries.
    Returns list of conflicts or empty list if clear."""
    conflicts = []
    with get_cursor() as cur:
        # Check leave requests
        cur.execute("""
            SELECT 'Leave Request' AS conflict_type, lr.id, lt.name AS detail,
                   lr.date_from, lr.date_to, lr.status
            FROM leave_mgmt.lv_requests lr
            JOIN leave_mgmt.lv_types lt ON lt.id = lr.leave_type_id
            WHERE lr.employee_id = %s
              AND lr.status NOT IN ('REJECTED', 'CANCELLED')
              AND lr.date_from <= %s AND lr.date_to >= %s
        """, (employee_id, date_to, date_from))
        conflicts.extend(cur.fetchall())

        # Check travel orders
        cur.execute("""
            SELECT 'Travel Order' AS conflict_type, to2.id, to2.destination AS detail,
                   to2.date_from, to2.date_to, to2.status
            FROM leave_mgmt.lv_travel_orders to2
            WHERE to2.employee_id = %s
              AND to2.status NOT IN ('REJECTED', 'CANCELLED')
              AND to2.date_from <= %s AND to2.date_to >= %s
        """, (employee_id, date_to, date_from))
        conflicts.extend(cur.fetchall())

    return conflicts


# ---------------------------------------------------------------------------
# Shift Schedule Management
# ---------------------------------------------------------------------------

def get_shift_assignments(department_id=None, employee_id=None):
    conditions = ['1=1']
    params = []
    if department_id:
        conditions.append('e.department_id = %s')
        params.append(department_id)
    if employee_id:
        conditions.append('sa.employee_id = %s')
        params.append(employee_id)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT sa.*, sh.name AS shift_name, sh.code AS shift_code,
                   sh.time_in, sh.time_out,
                   e.first_name || ' ' || e.last_name AS employee_name,
                   d.name AS department_name
            FROM attendance.att_shift_assignments sa
            JOIN attendance.att_shifts sh ON sh.id = sa.shift_id
            JOIN core.employees e ON e.id = sa.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            WHERE {' AND '.join(conditions)}
              AND (sa.effective_to IS NULL OR sa.effective_to >= CURRENT_DATE)
            ORDER BY d.name, e.last_name
        """, params)
        return cur.fetchall()


def assign_shift(employee_id, shift_id, effective_from, effective_to=None):
    with get_cursor(commit=True) as cur:
        # End any current assignment
        cur.execute("""
            UPDATE attendance.att_shift_assignments
            SET effective_to = %s
            WHERE employee_id = %s AND (effective_to IS NULL OR effective_to > %s)
        """, (effective_from, employee_id, effective_from))
        cur.execute("""
            INSERT INTO attendance.att_shift_assignments
                (employee_id, shift_id, effective_from, effective_to)
            VALUES (%s, %s, %s, %s)
            RETURNING id
        """, (employee_id, shift_id, effective_from, effective_to))
        return cur.fetchone()


def bulk_assign_shift(employee_ids, shift_id, effective_from, effective_to=None):
    count = 0
    for emp_id in employee_ids:
        assign_shift(emp_id, shift_id, effective_from, effective_to)
        count += 1
    return count


def create_shift(data):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO attendance.att_shifts
                (code, name, shift_type, time_in, time_out, break_minutes,
                 grace_period_minutes, is_night_shift, crosses_midnight)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (data['code'], data['name'], data.get('shift_type', 'FIXED'),
              data['time_in'], data['time_out'], data.get('break_minutes', 60),
              data.get('grace_period_minutes', 15), data.get('is_night_shift', False),
              data.get('crosses_midnight', False)))
        return cur.fetchone()


def update_shift(shift_id, data):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE attendance.att_shifts SET
                name = %s, time_in = %s, time_out = %s,
                break_minutes = %s, grace_period_minutes = %s,
                is_night_shift = %s, crosses_midnight = %s
            WHERE id = %s
        """, (data['name'], data['time_in'], data['time_out'],
              data.get('break_minutes', 60), data.get('grace_period_minutes', 15),
              data.get('is_night_shift', False), data.get('crosses_midnight', False),
              shift_id))
