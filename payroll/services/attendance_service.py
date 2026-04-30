"""Attendance service — DTR, shifts, OT, corrections, holidays, time logging."""
from datetime import date, timedelta
from services.db import get_cursor


# ── DTR / Daily Logs ────────────────────────────────────────────

def get_dtr(company_id=None, employee_id=None, department_id=None,
            date_from=None, date_to=None, status=None, page=1, per_page=50):
    date_to   = date_to   or str(date.today())
    date_from = date_from or str(date.today() - timedelta(days=6))

    conditions = ['ad.work_date BETWEEN %s AND %s']
    params     = [date_from, date_to]

    if company_id:
        conditions.append('e.company_id = %s')
        params.append(company_id)
    if employee_id:
        conditions.append('ad.employee_id = %s')
        params.append(employee_id)
    if department_id:
        conditions.append('e.department_id = %s')
        params.append(department_id)
    if status:
        conditions.append('ad.status = %s')
        params.append(status)

    where  = ' AND '.join(conditions)
    offset = (page - 1) * per_page

    with get_cursor() as cur:
        cur.execute(f"""
            SELECT
                ad.id, ad.work_date, ad.employee_id,
                e.employee_no, e.full_name,
                d.name AS department,
                s.name AS shift_name,
                ad.time_in, ad.time_out, ad.hours_worked,
                ad.hours_late, ad.hours_undertime, ad.hours_overtime,
                ad.hours_night_diff,
                ad.status AS attendance_status,
                ad.is_holiday, ad.is_restday, ad.remarks,
                ad.is_locked
            FROM attendance.att_daily ad
            JOIN core.v_employees_full e      ON e.id = ad.employee_id
            JOIN core.departments d    ON d.id = e.department_id
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
            JOIN core.v_employees_full e      ON e.id = ad.employee_id
            JOIN core.departments d    ON d.id = e.department_id
            LEFT JOIN attendance.att_shifts s ON s.id = ad.shift_id
            WHERE ad.employee_id = %s AND ad.work_date = %s
        """, (employee_id, work_date))
        return cur.fetchone()


def get_attendance_summary(company_id, date_from, date_to):
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                COUNT(*) AS total,
                COUNT(*) FILTER (WHERE ad.status = 'PRESENT') AS present,
                COUNT(*) FILTER (WHERE ad.status = 'LATE') AS late,
                COUNT(*) FILTER (WHERE ad.status = 'ABSENT') AS absent,
                COUNT(*) FILTER (WHERE ad.status = 'ON_LEAVE') AS on_leave,
                COUNT(*) FILTER (WHERE ad.status = 'ON_HOLIDAY') AS on_holiday,
                COALESCE(SUM(ad.hours_worked), 0) AS total_hours,
                COALESCE(SUM(ad.hours_overtime), 0) AS total_ot
            FROM attendance.att_daily ad
            JOIN core.v_employees_full e ON e.id = ad.employee_id
            WHERE e.company_id = %s
              AND ad.work_date BETWEEN %s AND %s
        """, (company_id, date_from, date_to))
        return cur.fetchone()


# ── Time Logging ────────────────────────────────────────────────

VALID_LOG_METHODS = ('WEB', 'QR', 'PIN', 'BIOMETRIC', 'FACE', 'RFID', 'MANUAL', 'API')


def log_time(employee_id, log_datetime, log_type,
             log_method='WEB', device_id=None, location=None, photo_path=None):
    """Insert a raw time log.  log_method is one of WEB|QR|PIN|BIOMETRIC|FACE|MANUAL|API."""
    if log_method not in VALID_LOG_METHODS:
        raise ValueError(f'Invalid log_method: {log_method}')
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO attendance.att_logs
                (employee_id, log_datetime, log_type, log_method,
                 device_id, location, photo_path)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            RETURNING id, employee_id, log_datetime, log_type, log_method
        """, (employee_id, log_datetime, log_type, log_method,
              device_id, location, photo_path))
        return cur.fetchone()


def get_recent_logs(company_id, limit=50):
    """Return the most recent time logs for a company, for the live feed."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT al.id, al.employee_id, e.employee_no, e.full_name,
                   al.log_datetime, al.log_type, al.log_method,
                   al.device_id, al.is_valid, al.created_at
            FROM attendance.att_logs al
            JOIN core.v_employees_full e ON e.id = al.employee_id
            WHERE e.company_id = %s
            ORDER BY al.log_datetime DESC
            LIMIT %s
        """, (company_id, limit))
        return cur.fetchall()


def get_employee_by_pin(pin_code, company_id):
    """Look up an employee by PIN code for PIN-based logging."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT e.id, e.employee_no, e.full_name
            FROM core.v_employees_full e
            WHERE e.company_id = %s AND e.employee_no = %s AND e.is_active
        """, (company_id, pin_code))
        return cur.fetchone()


def get_employee_by_qr(qr_code, company_id):
    """Look up an employee by QR code (employee_no or uuid)."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT e.id, e.employee_no, e.full_name
            FROM core.v_employees_full e
            WHERE e.company_id = %s
              AND (e.employee_no = %s OR e.uuid::text = %s)
              AND e.is_active
        """, (company_id, qr_code, qr_code))
        return cur.fetchone()


def get_employee_by_rfid(rfid_tag, company_id):
    """Look up an employee by RFID tag (stored in employee_no or a future rfid_tag column)."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT e.id, e.employee_no, e.full_name
            FROM core.v_employees_full e
            WHERE e.company_id = %s
              AND (e.employee_no = %s OR e.uuid::text = %s)
              AND e.is_active
        """, (company_id, rfid_tag, rfid_tag))
        return cur.fetchone()


def process_daily_attendance(employee_id, work_date):
    """Compute att_daily from att_logs for a given employee/date.
    Finds earliest IN and latest OUT log, computes hours, lateness, etc."""
    with get_cursor(commit=True) as cur:
        # Get shift assignment
        cur.execute("""
            SELECT sa.shift_id, s.time_in AS shift_start, s.time_out AS shift_end,
                   s.break_minutes, s.grace_period_minutes, s.total_work_hours,
                   s.is_night_shift
            FROM attendance.att_shift_assignments sa
            JOIN attendance.att_shifts s ON s.id = sa.shift_id
            WHERE sa.employee_id = %s
              AND sa.effective_from <= %s
              AND (sa.effective_to IS NULL OR sa.effective_to >= %s)
            ORDER BY sa.effective_from DESC LIMIT 1
        """, (employee_id, work_date, work_date))
        shift = cur.fetchone()

        # Get logs for the date
        cur.execute("""
            SELECT log_datetime, log_type
            FROM attendance.att_logs
            WHERE employee_id = %s
              AND log_datetime::date = %s
              AND is_valid = TRUE
            ORDER BY log_datetime
        """, (employee_id, work_date))
        logs = cur.fetchall()

        time_in = None
        time_out = None
        for log in logs:
            if log['log_type'] == 'IN' and time_in is None:
                time_in = log['log_datetime']
            elif log['log_type'] == 'OUT':
                time_out = log['log_datetime']

        hours_worked = 0
        hours_late = 0
        hours_undertime = 0
        status = 'ABSENT'

        if time_in and time_out:
            diff = (time_out - time_in).total_seconds() / 3600
            break_hrs = (shift['break_minutes'] / 60) if shift else 1
            hours_worked = max(round(diff - break_hrs, 2), 0)
            status = 'PRESENT'

            if shift:
                from datetime import datetime, timezone
                shift_start_dt = datetime.combine(work_date, shift['shift_start'],
                                                   tzinfo=time_in.tzinfo)
                grace = shift.get('grace_period_minutes') or 0
                late_seconds = (time_in - shift_start_dt).total_seconds() - (grace * 60)
                if late_seconds > 0:
                    hours_late = round(late_seconds / 3600, 2)
                    status = 'LATE'
        elif time_in:
            status = 'PRESENT'

        # Check if holiday
        cur.execute("""
            SELECT h.id, ht.code AS holiday_type
            FROM attendance.att_holidays h
            JOIN attendance.att_holiday_types ht ON ht.id = h.holiday_type_id
            WHERE h.holiday_date = %s
            LIMIT 1
        """, (work_date,))
        holiday = cur.fetchone()
        is_holiday = holiday is not None

        # Upsert att_daily
        cur.execute("""
            INSERT INTO attendance.att_daily
                (employee_id, work_date, shift_id, time_in, time_out,
                 hours_worked, hours_late, hours_undertime, status,
                 is_holiday, holiday_id)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (employee_id, work_date) DO UPDATE
            SET shift_id = EXCLUDED.shift_id,
                time_in = EXCLUDED.time_in,
                time_out = EXCLUDED.time_out,
                hours_worked = EXCLUDED.hours_worked,
                hours_late = EXCLUDED.hours_late,
                hours_undertime = EXCLUDED.hours_undertime,
                status = EXCLUDED.status,
                is_holiday = EXCLUDED.is_holiday,
                holiday_id = EXCLUDED.holiday_id,
                updated_at = NOW()
            WHERE NOT attendance.att_daily.is_locked
        """, (employee_id, work_date,
              shift['shift_id'] if shift else None,
              time_in, time_out,
              hours_worked, hours_late, hours_undertime,
              status, is_holiday,
              holiday['id'] if holiday else None))


def bulk_process_attendance(company_id, date_from, date_to):
    """Process daily attendance for all active employees in date range."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT id FROM core.employees
            WHERE company_id = %s AND is_active = TRUE
        """, (company_id,))
        employees = cur.fetchall()

    from datetime import datetime
    d_from = datetime.strptime(str(date_from), '%Y-%m-%d').date() if isinstance(date_from, str) else date_from
    d_to = datetime.strptime(str(date_to), '%Y-%m-%d').date() if isinstance(date_to, str) else date_to

    processed = 0
    current = d_from
    while current <= d_to:
        for emp in employees:
            try:
                process_daily_attendance(emp['id'], current)
                processed += 1
            except Exception:
                pass
        current += timedelta(days=1)

    return processed


# ── Shifts ──────────────────────────────────────────────────────

def get_shifts(company_id=None):
    with get_cursor() as cur:
        if company_id:
            cur.execute("""
                SELECT * FROM attendance.att_shifts
                WHERE company_id = %s AND is_active = TRUE ORDER BY code
            """, (company_id,))
        else:
            cur.execute("""
                SELECT * FROM attendance.att_shifts
                WHERE is_active = TRUE ORDER BY code
            """)
        return cur.fetchall()


def get_shift(shift_id):
    with get_cursor() as cur:
        cur.execute("SELECT * FROM attendance.att_shifts WHERE id = %s", (shift_id,))
        return cur.fetchone()


def create_shift(company_id, code, name, shift_type, time_in, time_out,
                 break_minutes=60, grace_period_minutes=0,
                 total_work_hours=None, is_night_shift=False):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO attendance.att_shifts
                (company_id, code, name, shift_type, time_in, time_out,
                 break_minutes, grace_period_minutes, total_work_hours,
                 is_night_shift)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (company_id, code, name, shift_type, time_in, time_out,
              break_minutes, grace_period_minutes, total_work_hours,
              is_night_shift))
        return cur.fetchone()['id']


def update_shift(shift_id, name, shift_type, time_in, time_out,
                 break_minutes, grace_period_minutes, total_work_hours,
                 is_night_shift):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE attendance.att_shifts
            SET name = %s, shift_type = %s, time_in = %s, time_out = %s,
                break_minutes = %s, grace_period_minutes = %s,
                total_work_hours = %s, is_night_shift = %s
            WHERE id = %s
        """, (name, shift_type, time_in, time_out, break_minutes,
              grace_period_minutes, total_work_hours, is_night_shift, shift_id))


def delete_shift(shift_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE attendance.att_shifts SET is_active = FALSE WHERE id = %s
        """, (shift_id,))


def get_shift_assignments(employee_id=None, company_id=None):
    conditions = ['1=1']
    params = []
    if employee_id:
        conditions.append('sa.employee_id = %s')
        params.append(employee_id)
    if company_id:
        conditions.append('e.company_id = %s')
        params.append(company_id)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT sa.*, e.employee_no, e.full_name, s.code AS shift_code, s.name AS shift_name
            FROM attendance.att_shift_assignments sa
            JOIN core.v_employees_full e ON e.id = sa.employee_id
            JOIN attendance.att_shifts s ON s.id = sa.shift_id
            WHERE {' AND '.join(conditions)}
            ORDER BY sa.effective_from DESC
        """, params)
        return cur.fetchall()


def assign_shift(employee_id, shift_id, effective_from, effective_to=None, created_by=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO attendance.att_shift_assignments
                (employee_id, shift_id, effective_from, effective_to, created_by)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING id
        """, (employee_id, shift_id, effective_from, effective_to, created_by))
        return cur.fetchone()['id']


# ── Overtime Requests ───────────────────────────────────────────

def get_overtime_requests(company_id=None, status=None, employee_id=None,
                          page=1, per_page=30):
    conditions = ['1=1']
    params     = []
    if company_id:
        conditions.append('e.company_id = %s')
        params.append(company_id)
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
                aor.reason, aor.status, aor.created_at,
                e.employee_no, e.full_name,
                d.name AS department,
                approver.display_name AS approved_by_name,
                aor.approved_at
            FROM attendance.att_overtime_requests aor
            JOIN core.v_employees_full e      ON e.id = aor.employee_id
            JOIN core.departments d    ON d.id = e.department_id
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
        return cur.fetchone()['id']


def action_overtime(ot_id, action_code, performed_by, comments=None,
                    ot_hours_approved=None):
    with get_cursor() as cur:
        cur.execute("""
            SELECT employee_id, expected_ot_hours, request_date
            FROM attendance.att_overtime_requests WHERE id = %s
        """, (ot_id,))
        req = cur.fetchone()

    if not req:
        return {'ok': False, 'message': 'OT request not found.'}

    new_status = 'APPROVED' if action_code.upper() == 'APPROVE' else 'REJECTED'
    hours_approved = ot_hours_approved or req['expected_ot_hours']

    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE attendance.att_overtime_requests
            SET status = %s, approved_by = %s, approved_at = NOW(),
                rejection_reason = %s
            WHERE id = %s
        """, (new_status, performed_by,
              comments if new_status == 'REJECTED' else None, ot_id))

        if new_status == 'APPROVED':
            cur.execute("""
                UPDATE attendance.att_daily
                SET hours_overtime = %s
                WHERE employee_id = %s AND work_date = %s
            """, (hours_approved, req['employee_id'], req['request_date']))

    return {'ok': True, 'message': f'OT request {new_status.lower()}.'}


# ── DTR Corrections ─────────────────────────────────────────────

def submit_correction(employee_id, work_date, correct_time_in,
                      correct_time_out, reason, submitted_by):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO attendance.att_dtr_corrections
                (employee_id, work_date, field_to_correct,
                 corrected_value, reason, status)
            VALUES (%s, %s, 'TIME_IN_OUT', %s, %s, 'PENDING')
            RETURNING id
        """, (employee_id, work_date,
              correct_time_in or correct_time_out, reason))
        return cur.fetchone()['id']


def get_corrections(company_id=None, employee_id=None, status=None):
    conditions = ['1=1']
    params     = []
    if company_id:
        conditions.append('e.company_id = %s')
        params.append(company_id)
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
            JOIN core.v_employees_full e      ON e.id = c.employee_id
            JOIN core.departments d    ON d.id = e.department_id
            WHERE {' AND '.join(conditions)}
            ORDER BY c.created_at DESC
        """, params)
        return cur.fetchall()


def action_correction(corr_id, action_code, reviewed_by, remarks=None):
    new_status = 'APPROVED' if action_code.upper() == 'APPROVE' else 'REJECTED'
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE attendance.att_dtr_corrections
            SET status = %s, reviewed_by = %s, reviewed_at = NOW(),
                review_remarks = %s
            WHERE id = %s
        """, (new_status, reviewed_by, remarks, corr_id))
    return {'ok': True, 'message': f'Correction {new_status.lower()}.'}


# ── Calendar ────────────────────────────────────────────────────

def get_calendar_data(employee_id, year, month):
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


# ── Holidays ────────────────────────────────────────────────────

def get_holidays(company_id=None, year=None):
    year = year or date.today().year
    conditions = ["EXTRACT(YEAR FROM h.holiday_date) = %s"]
    params = [year]
    if company_id:
        conditions.append('h.company_id = %s')
        params.append(company_id)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT h.*, ht.name AS type_name, ht.pay_multiplier, ht.code AS type_code
            FROM attendance.att_holidays h
            JOIN attendance.att_holiday_types ht ON ht.id = h.holiday_type_id
            WHERE {' AND '.join(conditions)}
            ORDER BY h.holiday_date
        """, params)
        return cur.fetchall()


def get_holiday_types():
    with get_cursor() as cur:
        cur.execute("SELECT * FROM attendance.att_holiday_types ORDER BY id")
        return cur.fetchall()


def add_holiday(company_id, holiday_date, name, holiday_type_id, created_by=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO attendance.att_holidays
                (company_id, holiday_type_id, holiday_date, name)
            VALUES (%s, %s, %s, %s)
            RETURNING id
        """, (company_id, holiday_type_id, holiday_date, name))
        return cur.fetchone()['id']


def update_holiday(holiday_id, holiday_date, name, holiday_type_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE attendance.att_holidays
            SET holiday_date = %s, name = %s, holiday_type_id = %s
            WHERE id = %s
        """, (holiday_date, name, holiday_type_id, holiday_id))


def delete_holiday(holiday_id):
    with get_cursor(commit=True) as cur:
        cur.execute("DELETE FROM attendance.att_holidays WHERE id = %s", (holiday_id,))


# ── Departments (reference) ────────────────────────────────────

def get_departments(company_id=None):
    with get_cursor() as cur:
        if company_id:
            cur.execute("""
                SELECT id, name FROM core.departments
                WHERE company_id = %s AND is_active = TRUE ORDER BY name
            """, (company_id,))
        else:
            cur.execute("""
                SELECT id, name FROM core.departments
                WHERE is_active = TRUE ORDER BY name
            """)
        return cur.fetchall()


def get_employees(company_id=None, department_id=None):
    conditions = ['e.is_active = TRUE']
    params = []
    if company_id:
        conditions.append('e.company_id = %s')
        params.append(company_id)
    if department_id:
        conditions.append('e.department_id = %s')
        params.append(department_id)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT e.id, e.employee_no, e.full_name, d.name AS department
            FROM core.v_employees_full e
            JOIN core.departments d ON d.id = e.department_id
            WHERE {' AND '.join(conditions)}
            ORDER BY e.full_name
        """, params)
        return cur.fetchall()
