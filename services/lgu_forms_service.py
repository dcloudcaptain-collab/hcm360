"""
LGU critical-gap services: CS Form 6, Exit Interview + CS Form 7,
Travel Orders, Locator Slips, LGU Contracts, Personal Data Sheets.

Single file to keep related workflows co-located. Each section is
independent and may be split later if one grows large.
"""
import json
from datetime import date as Date
from services.db import get_cursor


# ══════════════════════════════════════════════════════════════════════
# Helpers
# ══════════════════════════════════════════════════════════════════════
def _emp_header(cur, employee_id: int):
    cur.execute("""
        SELECT e.id, e.employee_no,
               CONCAT_WS(' ', e.first_name, e.middle_name, e.last_name) AS full_name,
               e.gender, e.date_of_birth, e.civil_status, e.mobile_no,
               e.work_email, e.date_hired, e.date_regularized, e.status,
               d.name AS department_name,
               p.title AS position_title,
               jg.code AS salary_grade,
               jg.salary_max AS salary_reference,
               e.basic_salary,
               e.company_id
        FROM core.employees e
        LEFT JOIN core.departments d ON d.id = e.department_id
        LEFT JOIN core.positions p   ON p.id = e.position_id
        LEFT JOIN core.job_grades jg ON jg.id = e.job_grade_id
        WHERE e.id = %s
    """, (employee_id,))
    return cur.fetchone()


def _next_control_no(prefix: str) -> str:
    """Generate a sequential control number like TO-2026-000123."""
    year = Date.today().year
    with get_cursor(commit=True) as cur:
        cur.execute("""
            SELECT COALESCE(MAX(split_part(control_no, '-', 3)::int), 0) + 1 AS next_n
            FROM core.travel_orders
            WHERE control_no LIKE %s
        """, (f'{prefix}-{year}-%',))
        n = cur.fetchone()['next_n']
    return f'{prefix}-{year}-{n:06d}'


# ══════════════════════════════════════════════════════════════════════
# G01 · CS Form No. 6 (extends leave_mgmt.lv_requests)
# ══════════════════════════════════════════════════════════════════════
def cs6_create(employee_id: int, form: dict, user_id: int):
    """Create a leave request in CS Form No. 6 mode."""
    with get_cursor(commit=True) as cur:
        emp = _emp_header(cur, employee_id)
        if not emp:
            raise ValueError('Employee not found')

        # Generate reference_no (LV-YYYY-NNNNNN)
        cur.execute("""
            SELECT 'LV-' || EXTRACT(YEAR FROM CURRENT_DATE)::int ||
                   '-' || LPAD((COALESCE(MAX(
                       CASE WHEN reference_no ~ '^LV-[0-9]+-[0-9]+$'
                            THEN split_part(reference_no, '-', 3)::int
                            ELSE 0 END
                   ), 0) + 1)::text, 6, '0') AS ref
            FROM leave_mgmt.lv_requests
            WHERE reference_no LIKE 'LV-' || EXTRACT(YEAR FROM CURRENT_DATE)::int || '-%'
        """)
        ref_no = cur.fetchone()['ref']

        cur.execute("""
            INSERT INTO leave_mgmt.lv_requests
                (reference_no, employee_id, leave_type_id,
                 date_from, date_to, days_requested,
                 reason, status, cs_form6_mode,
                 salary_at_time, whereabouts, whereabouts_detail,
                 illness_specification, commutation, date_of_filing,
                 created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, 'PENDING', TRUE,
                    %s, %s, %s, %s, %s, COALESCE(%s, CURRENT_DATE), NOW())
            RETURNING id
        """, (
            ref_no,
            employee_id,
            form['leave_type_id'],
            form['date_from'], form['date_to'],
            form.get('days') or 1,
            form.get('reason', ''),
            emp.get('basic_salary'),
            form.get('whereabouts'),
            form.get('whereabouts_detail'),
            form.get('illness_specification'),
            form.get('commutation', 'NOT_REQUESTED'),
            form.get('date_of_filing'),
        ))
        return cur.fetchone()['id']


def cs6_get(request_id: int):
    with get_cursor() as cur:
        cur.execute("""
            SELECT r.*, lt.name AS leave_type_name, lt.code AS leave_type_code,
                   lt.legal_basis, lt.color,
                   e.employee_no,
                   CONCAT_WS(' ', e.first_name, e.middle_name, e.last_name) AS full_name,
                   e.date_of_birth, e.civil_status, e.gender,
                   d.name AS department_name, p.title AS position_title,
                   jg.code AS salary_grade
            FROM leave_mgmt.lv_requests r
            JOIN leave_mgmt.lv_types lt ON lt.id = r.leave_type_id
            JOIN core.employees e ON e.id = r.employee_id
            LEFT JOIN core.departments d  ON d.id = e.department_id
            LEFT JOIN core.positions p    ON p.id = e.position_id
            LEFT JOIN core.job_grades jg  ON jg.id = e.job_grade_id
            WHERE r.id = %s
        """, (request_id,))
        return cur.fetchone()


def cs6_list(employee_id: int = None, company_id: int = None, limit: int = 200):
    with get_cursor() as cur:
        sql = """
            SELECT r.id, r.date_from, r.date_to, r.days_requested AS days, r.status,
                   r.date_of_filing, r.commutation, lt.code AS leave_code,
                   lt.name AS leave_type_name,
                   e.employee_no,
                   CONCAT_WS(' ', e.first_name, e.middle_name, e.last_name) AS full_name
            FROM leave_mgmt.lv_requests r
            JOIN leave_mgmt.lv_types lt ON lt.id = r.leave_type_id
            JOIN core.employees e ON e.id = r.employee_id
            WHERE r.cs_form6_mode = TRUE
        """
        params = []
        if employee_id:
            sql += ' AND r.employee_id = %s'
            params.append(employee_id)
        if company_id:
            sql += ' AND e.company_id = %s'
            params.append(company_id)
        sql += ' ORDER BY r.date_of_filing DESC, r.id DESC LIMIT %s'
        params.append(limit)
        cur.execute(sql, tuple(params))
        return cur.fetchall()


def cs6_recommend(request_id: int, user_id: int, action: str, remarks: str = ''):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE leave_mgmt.lv_requests
            SET recommend_action = %s,
                recommend_by     = %s,
                recommend_at     = NOW(),
                head_remarks     = %s
            WHERE id = %s
            RETURNING id
        """, (action, user_id, remarks, request_id))
        return cur.fetchone()


def cs6_head_action(request_id: int, user_id: int, action: str, remarks: str = ''):
    status_map = {
        'APPROVED': 'APPROVED',
        'APPROVED_WITH_MOD': 'APPROVED',
        'DISAPPROVED': 'REJECTED',
    }
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE leave_mgmt.lv_requests
            SET head_action    = %s,
                head_action_by = %s,
                head_action_at = NOW(),
                head_remarks   = %s,
                status         = %s
            WHERE id = %s
            RETURNING id
        """, (action, user_id, remarks,
              status_map.get(action, 'PENDING'), request_id))
        return cur.fetchone()


# ══════════════════════════════════════════════════════════════════════
# G02 · Exit Interview + CS Form No. 7 Clearance
# ══════════════════════════════════════════════════════════════════════
EXIT_REASONS = [
    'better_opportunity', 'career_change', 'relocation', 'personal',
    'retirement', 'health', 'compensation', 'management_issues',
    'work_environment', 'other',
]

DEFAULT_CLEARANCE_ITEMS = [
    ('Immediate Supervisor', 'Pending assignments, deliverables, endorsement'),
    ('Property Custodian',   'Return of office equipment, tools, supplies'),
    ('IT Department',        'Return of laptop, access badges, revoke system access'),
    ('HR Department',        'Employee records, 201 file completion, company ID'),
    ('Finance / Accounting', 'Outstanding cash advances, liquidation, loans'),
    ('Budget / Payroll',     'Final pay computation, tax clearance'),
    ('Records / Archives',   'Return of documents, file endorsement'),
    ('Security / Custodian', 'Return of ID card, locker key'),
    ('Head of Office',       'Final approval'),
]


def exit_create(employee_id: int, form: dict):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO core.exit_interviews
                (employee_id, resignation_date, last_working_day,
                 reason_for_leaving, future_plans, would_recommend, would_rejoin,
                 overall_rating, manager_rating, compensation_rating, culture_rating,
                 best_aspects, improvement_areas, additional_comments, status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'DRAFT')
            RETURNING id
        """, (
            employee_id,
            form.get('resignation_date'),
            form['last_working_day'],
            form.get('reason_for_leaving'),
            form.get('future_plans'),
            form.get('would_recommend'),
            form.get('would_rejoin'),
            form.get('overall_rating'),
            form.get('manager_rating'),
            form.get('compensation_rating'),
            form.get('culture_rating'),
            form.get('best_aspects'),
            form.get('improvement_areas'),
            form.get('additional_comments'),
        ))
        return cur.fetchone()['id']


def exit_submit(interview_id: int):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.exit_interviews
            SET status = 'SUBMITTED', submitted_at = NOW(), updated_at = NOW()
            WHERE id = %s AND status = 'DRAFT'
            RETURNING id
        """, (interview_id,))
        return cur.fetchone()


def exit_get(interview_id: int):
    with get_cursor() as cur:
        cur.execute("""
            SELECT ei.*,
                   e.employee_no,
                   CONCAT_WS(' ', e.first_name, e.middle_name, e.last_name) AS full_name,
                   d.name AS department_name, p.title AS position_title
            FROM core.exit_interviews ei
            JOIN core.employees e ON e.id = ei.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.positions p   ON p.id = e.position_id
            WHERE ei.id = %s
        """, (interview_id,))
        return cur.fetchone()


def exit_list(company_id: int, status: str = None):
    with get_cursor() as cur:
        sql = """
            SELECT ei.id, ei.last_working_day, ei.reason_for_leaving,
                   ei.overall_rating, ei.status, ei.submitted_at,
                   e.employee_no,
                   CONCAT_WS(' ', e.first_name, e.last_name) AS full_name,
                   d.name AS department_name
            FROM core.exit_interviews ei
            JOIN core.employees e ON e.id = ei.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            WHERE e.company_id = %s
        """
        params = [company_id]
        if status:
            sql += ' AND ei.status = %s'
            params.append(status)
        sql += ' ORDER BY ei.last_working_day DESC LIMIT 200'
        cur.execute(sql, tuple(params))
        return cur.fetchall()


def clearance_create(employee_id: int, last_working_day, exit_interview_id=None):
    """Create a CS Form 7 clearance with default signatory items."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO core.clearance_forms
                (employee_id, exit_interview_id, last_working_day, status)
            VALUES (%s, %s, %s, 'IN_PROGRESS')
            ON CONFLICT (employee_id, last_working_day) DO UPDATE
                SET exit_interview_id = EXCLUDED.exit_interview_id
            RETURNING id
        """, (employee_id, exit_interview_id, last_working_day))
        cid = cur.fetchone()['id']
        # Add default signatory items
        for idx, (role, desc) in enumerate(DEFAULT_CLEARANCE_ITEMS):
            cur.execute("""
                INSERT INTO core.clearance_items
                    (clearance_id, signatory_role, description, sort_order)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT DO NOTHING
            """, (cid, role, desc, idx))
        return cid


def clearance_get(clearance_id: int):
    with get_cursor() as cur:
        cur.execute("""
            SELECT cf.*, e.employee_no,
                   CONCAT_WS(' ', e.first_name, e.middle_name, e.last_name) AS full_name,
                   d.name AS department_name, p.title AS position_title
            FROM core.clearance_forms cf
            JOIN core.employees e ON e.id = cf.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.positions p   ON p.id = e.position_id
            WHERE cf.id = %s
        """, (clearance_id,))
        form = cur.fetchone()
        if not form:
            return None
        cur.execute("""
            SELECT ci.*, u.display_name AS signatory_name
            FROM core.clearance_items ci
            LEFT JOIN core.users u ON u.id = ci.signatory_user_id
            WHERE ci.clearance_id = %s
            ORDER BY ci.sort_order
        """, (clearance_id,))
        items = cur.fetchall()
        return {'form': dict(form), 'items': items}


def clearance_list(company_id: int):
    with get_cursor() as cur:
        cur.execute("""
            SELECT cf.id, cf.last_working_day, cf.status,
                   e.employee_no,
                   CONCAT_WS(' ', e.first_name, e.last_name) AS full_name,
                   d.name AS department_name,
                   (SELECT COUNT(*) FROM core.clearance_items ci
                      WHERE ci.clearance_id = cf.id AND ci.is_cleared) AS cleared_count,
                   (SELECT COUNT(*) FROM core.clearance_items ci
                      WHERE ci.clearance_id = cf.id) AS total_count
            FROM core.clearance_forms cf
            JOIN core.employees e ON e.id = cf.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            WHERE e.company_id = %s
            ORDER BY cf.last_working_day DESC
            LIMIT 200
        """, (company_id,))
        return cur.fetchall()


def clearance_sign(item_id: int, user_id: int, cleared: bool, remarks: str = ''):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.clearance_items
            SET is_cleared        = %s,
                cleared_at        = CASE WHEN %s THEN NOW() ELSE NULL END,
                signatory_user_id = %s,
                remarks           = %s
            WHERE id = %s
            RETURNING clearance_id
        """, (cleared, cleared, user_id, remarks, item_id))
        row = cur.fetchone()
        if not row:
            return None
        # Auto-advance clearance to CLEARED when all items signed
        cid = row['clearance_id']
        cur.execute("""
            SELECT
                COUNT(*) FILTER (WHERE NOT is_cleared) AS pending
            FROM core.clearance_items
            WHERE clearance_id = %s
        """, (cid,))
        if cur.fetchone()['pending'] == 0:
            cur.execute("""
                UPDATE core.clearance_forms
                SET status = 'CLEARED', updated_at = NOW()
                WHERE id = %s
            """, (cid,))
        return cid


# ══════════════════════════════════════════════════════════════════════
# G03 · Travel Orders
# ══════════════════════════════════════════════════════════════════════
def travel_create(employee_id: int, form: dict, user_id: int):
    ctrl = _next_control_no('TO')
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO core.travel_orders
                (control_no, employee_id, purpose, destination,
                 date_from, date_to, time_from, time_to,
                 mode_of_transport, funds_source, estimated_cost,
                 companions, remarks, status, submitted_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                    'PENDING_SUPERVISOR', NOW())
            RETURNING id, control_no
        """, (
            ctrl, employee_id,
            form['purpose'], form['destination'],
            form['date_from'], form['date_to'],
            form.get('time_from'), form.get('time_to'),
            form.get('mode_of_transport'),
            form.get('funds_source'),
            form.get('estimated_cost'),
            form.get('companions'),
            form.get('remarks'),
        ))
        return cur.fetchone()


def travel_list(company_id: int, employee_id: int = None, status: str = None):
    with get_cursor() as cur:
        sql = """
            SELECT t.id, t.control_no, t.employee_id,
                   t.purpose, t.destination,
                   t.date_from, t.date_to, t.status, t.submitted_at,
                   e.employee_no,
                   CONCAT_WS(' ', e.first_name, e.last_name) AS full_name,
                   d.name AS department_name
            FROM core.travel_orders t
            JOIN core.employees e ON e.id = t.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            WHERE e.company_id = %s
        """
        params = [company_id]
        if employee_id:
            sql += ' AND t.employee_id = %s'
            params.append(employee_id)
        if status:
            sql += ' AND t.status = %s'
            params.append(status)
        sql += ' ORDER BY t.date_from DESC, t.id DESC LIMIT 200'
        cur.execute(sql, tuple(params))
        return cur.fetchall()


def travel_get(travel_id: int):
    with get_cursor() as cur:
        cur.execute("""
            SELECT t.*,
                   e.employee_no,
                   CONCAT_WS(' ', e.first_name, e.middle_name, e.last_name) AS full_name,
                   d.name AS department_name, p.title AS position_title
            FROM core.travel_orders t
            JOIN core.employees e ON e.id = t.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.positions p   ON p.id = e.position_id
            WHERE t.id = %s
        """, (travel_id,))
        return cur.fetchone()


def travel_action(travel_id: int, user_id: int, action: str,
                  level: str = 'supervisor', remarks: str = ''):
    """level: 'supervisor' or 'head'. action: APPROVE|REJECT|CANCEL."""
    action = action.upper()
    with get_cursor(commit=True) as cur:
        if action == 'APPROVE' and level == 'supervisor':
            cur.execute("""
                UPDATE core.travel_orders
                SET supervisor_user_id   = %s,
                    supervisor_action_at = NOW(),
                    supervisor_remarks   = %s,
                    status               = 'PENDING_HEAD',
                    updated_at           = NOW()
                WHERE id = %s
                RETURNING id
            """, (user_id, remarks, travel_id))
        elif action == 'APPROVE' and level == 'head':
            cur.execute("""
                UPDATE core.travel_orders
                SET head_user_id         = %s,
                    head_action_at       = NOW(),
                    head_remarks         = %s,
                    status               = 'APPROVED',
                    updated_at           = NOW()
                WHERE id = %s
                RETURNING id
            """, (user_id, remarks, travel_id))
        elif action == 'REJECT':
            cur.execute("""
                UPDATE core.travel_orders
                SET status = 'REJECTED', updated_at = NOW(),
                    head_remarks = %s
                WHERE id = %s
                RETURNING id
            """, (remarks, travel_id))
        elif action == 'CANCEL':
            cur.execute("""
                UPDATE core.travel_orders
                SET status = 'CANCELLED', updated_at = NOW()
                WHERE id = %s
                RETURNING id
            """, (travel_id,))
        else:
            return None
        return cur.fetchone()


# ══════════════════════════════════════════════════════════════════════
# G04 · Locator Slips
# ══════════════════════════════════════════════════════════════════════
def locator_create(employee_id: int, form: dict):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO core.locator_slips
                (employee_id, slip_date, purpose, destination,
                 time_out, expected_return, status)
            VALUES (%s, %s, %s, %s, %s, %s, 'PENDING')
            RETURNING id
        """, (
            employee_id,
            form.get('slip_date') or Date.today(),
            form['purpose'], form['destination'],
            form['time_out'], form.get('expected_return'),
        ))
        return cur.fetchone()['id']


def locator_list(company_id: int, employee_id: int = None,
                 status: str = None, date_from=None):
    with get_cursor() as cur:
        sql = """
            SELECT ls.id, ls.slip_date, ls.purpose, ls.destination,
                   ls.time_out, ls.expected_return, ls.actual_return, ls.status,
                   e.employee_no,
                   CONCAT_WS(' ', e.first_name, e.last_name) AS full_name,
                   d.name AS department_name
            FROM core.locator_slips ls
            JOIN core.employees e ON e.id = ls.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            WHERE e.company_id = %s
        """
        params = [company_id]
        if employee_id:
            sql += ' AND ls.employee_id = %s'
            params.append(employee_id)
        if status:
            sql += ' AND ls.status = %s'
            params.append(status)
        if date_from:
            sql += ' AND ls.slip_date >= %s'
            params.append(date_from)
        sql += ' ORDER BY ls.slip_date DESC, ls.time_out DESC LIMIT 200'
        cur.execute(sql, tuple(params))
        return cur.fetchall()


def locator_action(slip_id: int, user_id: int, action: str, remarks: str = ''):
    action = action.upper()
    status_map = {
        'APPROVE': 'APPROVED',
        'REJECT':  'REJECTED',
        'RETURN':  'COMPLETED',
    }
    new_status = status_map.get(action)
    if not new_status:
        return None
    with get_cursor(commit=True) as cur:
        if action == 'RETURN':
            cur.execute("""
                UPDATE core.locator_slips
                SET status = 'COMPLETED',
                    actual_return = CURRENT_TIME,
                    updated_at = NOW()
                WHERE id = %s
                RETURNING id
            """, (slip_id,))
        else:
            cur.execute("""
                UPDATE core.locator_slips
                SET status           = %s,
                    approver_user_id = %s,
                    approved_at      = NOW(),
                    remarks          = %s,
                    updated_at       = NOW()
                WHERE id = %s
                RETURNING id
            """, (new_status, user_id, remarks, slip_id))
        return cur.fetchone()


# ══════════════════════════════════════════════════════════════════════
# G07 · LGU Contracts
# ══════════════════════════════════════════════════════════════════════
def contract_types():
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM core.lgu_contract_types
            WHERE is_active = TRUE ORDER BY sort_order
        """)
        return cur.fetchall()


def contract_create(form: dict, user_id: int):
    with get_cursor(commit=True) as cur:
        # Generate contract_no
        cur.execute("""
            SELECT code FROM core.lgu_contract_types WHERE id = %s
        """, (form['contract_type_id'],))
        t = cur.fetchone()
        if not t:
            raise ValueError('Invalid contract type')
        year = Date.today().year
        cur.execute("""
            SELECT COALESCE(MAX(split_part(contract_no, '-', 3)::int), 0) + 1 AS n
            FROM core.lgu_contracts
            WHERE contract_no LIKE %s
        """, (f"{t['code']}-{year}-%",))
        seq = cur.fetchone()['n']
        cno = f"{t['code']}-{year}-{seq:05d}"

        cur.execute("""
            INSERT INTO core.lgu_contracts
                (contract_no, contract_type_id, employee_id,
                 full_name, address, contact_no, email, position_title,
                 department_id, barangay, school,
                 date_from, date_to, rate, rate_type,
                 funds_source, terms, status, created_by)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s,
                    %s, %s, %s,
                    %s, %s, %s, %s,
                    %s, %s, 'PENDING', %s)
            RETURNING id, contract_no
        """, (
            cno, form['contract_type_id'],
            form.get('employee_id'),
            form['full_name'],
            form.get('address'), form.get('contact_no'), form.get('email'),
            form.get('position_title'),
            form.get('department_id'), form.get('barangay'), form.get('school'),
            form['date_from'], form['date_to'],
            form.get('rate'), form.get('rate_type'),
            form.get('funds_source'), form.get('terms'),
            user_id,
        ))
        return cur.fetchone()


def contract_list(company_id: int = None, status: str = None,
                  contract_type_code: str = None):
    with get_cursor() as cur:
        sql = """
            SELECT c.id, c.contract_no, c.full_name, c.position_title,
                   c.date_from, c.date_to, c.rate, c.rate_type, c.status,
                   ct.code AS type_code, ct.name AS type_name,
                   d.name AS department_name
            FROM core.lgu_contracts c
            JOIN core.lgu_contract_types ct ON ct.id = c.contract_type_id
            LEFT JOIN core.departments d   ON d.id = c.department_id
            WHERE 1=1
        """
        params = []
        if status:
            sql += ' AND c.status = %s'
            params.append(status)
        if contract_type_code:
            sql += ' AND ct.code = %s'
            params.append(contract_type_code)
        sql += ' ORDER BY c.date_from DESC, c.id DESC LIMIT 200'
        cur.execute(sql, tuple(params))
        return cur.fetchall()


def contract_get(contract_id: int):
    with get_cursor() as cur:
        cur.execute("""
            SELECT c.*, ct.code AS type_code, ct.name AS type_name,
                   ct.legal_basis, ct.default_rate,
                   d.name AS department_name
            FROM core.lgu_contracts c
            JOIN core.lgu_contract_types ct ON ct.id = c.contract_type_id
            LEFT JOIN core.departments d ON d.id = c.department_id
            WHERE c.id = %s
        """, (contract_id,))
        return cur.fetchone()


def contract_action(contract_id: int, user_id: int, action: str):
    action = action.upper()
    status_map = {'APPROVE': 'APPROVED', 'ACTIVATE': 'ACTIVE',
                  'TERMINATE': 'TERMINATED'}
    new_status = status_map.get(action)
    if not new_status:
        return None
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.lgu_contracts
            SET status = %s,
                approver_user_id = CASE WHEN %s = 'APPROVED'
                                        THEN %s ELSE approver_user_id END,
                approved_at = CASE WHEN %s = 'APPROVED'
                                   THEN NOW() ELSE approved_at END,
                updated_at = NOW()
            WHERE id = %s
            RETURNING id
        """, (new_status, new_status, user_id, new_status, contract_id))
        return cur.fetchone()


def contract_summary(company_id: int = None):
    with get_cursor() as cur:
        cur.execute("""
            SELECT ct.code AS type_code, ct.name AS type_name,
                   COUNT(c.*) FILTER (WHERE c.status = 'ACTIVE')   AS active_count,
                   COUNT(c.*) FILTER (WHERE c.status = 'PENDING')  AS pending_count,
                   COUNT(c.*) FILTER (WHERE c.status = 'APPROVED') AS approved_count,
                   COUNT(c.*) FILTER (WHERE c.status = 'EXPIRED')  AS expired_count,
                   SUM(c.rate) FILTER (WHERE c.status = 'ACTIVE'
                                       AND c.rate_type = 'MONTHLY') AS monthly_cost
            FROM core.lgu_contract_types ct
            LEFT JOIN core.lgu_contracts c ON c.contract_type_id = ct.id
            GROUP BY ct.id, ct.code, ct.name, ct.sort_order
            ORDER BY ct.sort_order
        """)
        return cur.fetchall()


# ══════════════════════════════════════════════════════════════════════
# G14 · Personal Data Sheet (CSC Form 212)
# ══════════════════════════════════════════════════════════════════════
# Default structure of the PDS content JSONB.
PDS_SECTIONS = [
    'personal_info', 'family_background', 'educational_background',
    'civil_service_eligibility', 'work_experience', 'voluntary_work',
    'learning_development', 'other_information', 'references',
    'attestation',
]


def pds_get_current(employee_id: int):
    """Return the most recent PDS for an employee, or None."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT pds.*,
                   e.employee_no,
                   CONCAT_WS(' ', e.first_name, e.middle_name, e.last_name) AS full_name,
                   e.date_of_birth, e.gender, e.civil_status,
                   e.mobile_no, e.work_email
            FROM core.personal_data_sheets pds
            JOIN core.employees e ON e.id = pds.employee_id
            WHERE pds.employee_id = %s AND pds.is_current = TRUE
            ORDER BY pds.version DESC
            LIMIT 1
        """, (employee_id,))
        return cur.fetchone()


def pds_prefill_from_master(employee_id: int) -> dict:
    """Build a starter PDS dict from existing employee master data."""
    with get_cursor() as cur:
        emp = _emp_header(cur, employee_id)
        # Addresses
        try:
            cur.execute("""
                SELECT street, city, province, zip_code, address_type
                FROM core.emp_addresses
                WHERE employee_id = %s
            """, (employee_id,))
            addresses = cur.fetchall() or []
        except Exception:
            addresses = []
        # Government IDs
        try:
            cur.execute("""
                SELECT id_type, id_number
                FROM core.emp_government_ids
                WHERE employee_id = %s
            """, (employee_id,))
            gov_ids = cur.fetchall() or []
        except Exception:
            gov_ids = []
    gov_map = {g['id_type']: g['id_number'] for g in gov_ids}
    return {
        'personal_info': {
            'full_name': emp.get('full_name') if emp else '',
            'date_of_birth': str(emp.get('date_of_birth') or '') if emp else '',
            'gender': (emp.get('gender') or '') if emp else '',
            'civil_status': (emp.get('civil_status') or '') if emp else '',
            'mobile_no': (emp.get('mobile_no') or '') if emp else '',
            'email': (emp.get('work_email') or '') if emp else '',
            'tin': gov_map.get('TIN', ''),
            'sss_no': gov_map.get('SSS', ''),
            'gsis_no': gov_map.get('GSIS', ''),
            'philhealth_no': gov_map.get('PHILHEALTH', ''),
            'pagibig_no': gov_map.get('PAGIBIG', ''),
            'addresses': [dict(a) for a in addresses],
        },
        'family_background':   {'spouse': {}, 'father': {}, 'mother': {}, 'children': []},
        'educational_background': {
            'elementary': {}, 'secondary': {}, 'vocational': {},
            'college': {}, 'graduate': {},
        },
        'civil_service_eligibility': [],
        'work_experience':     [],
        'voluntary_work':      [],
        'learning_development': [],
        'other_information':   {
            'special_skills': [], 'hobbies': [],
            'nonacademic_distinctions': [], 'memberships': [],
        },
        'references': [],
        'attestation': {
            'signed_date': '', 'place': '',
        },
    }


def pds_save(employee_id: int, data: dict, user_id: int,
             submit: bool = False):
    """Create a new PDS version (or upsert on current draft)."""
    with get_cursor(commit=True) as cur:
        # Find current version number
        cur.execute("""
            SELECT COALESCE(MAX(version), 0) AS v
            FROM core.personal_data_sheets
            WHERE employee_id = %s
        """, (employee_id,))
        v = cur.fetchone()['v']
        # Retire existing current
        cur.execute("""
            UPDATE core.personal_data_sheets
            SET is_current = FALSE, updated_at = NOW()
            WHERE employee_id = %s AND is_current = TRUE
        """, (employee_id,))
        # Insert new version
        status = 'SUBMITTED' if submit else 'DRAFT'
        cur.execute("""
            INSERT INTO core.personal_data_sheets
                (employee_id, version, as_of_date, is_current,
                 data, status, submitted_at)
            VALUES (%s, %s, CURRENT_DATE, TRUE, %s, %s,
                    CASE WHEN %s THEN NOW() ELSE NULL END)
            RETURNING id, version
        """, (employee_id, v + 1, json.dumps(data), status, submit))
        return cur.fetchone()


def pds_verify(pds_id: int, user_id: int):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.personal_data_sheets
            SET status = 'VERIFIED', verified_at = NOW(), verified_by = %s
            WHERE id = %s AND status = 'SUBMITTED'
            RETURNING id
        """, (user_id, pds_id))
        return cur.fetchone()


def pds_list(company_id: int, status: str = None):
    with get_cursor() as cur:
        sql = """
            SELECT pds.id, pds.employee_id, pds.version, pds.as_of_date,
                   pds.status, pds.submitted_at, pds.verified_at,
                   e.employee_no,
                   CONCAT_WS(' ', e.first_name, e.last_name) AS full_name,
                   d.name AS department_name
            FROM core.personal_data_sheets pds
            JOIN core.employees e ON e.id = pds.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            WHERE e.company_id = %s AND pds.is_current = TRUE
        """
        params = [company_id]
        if status:
            sql += ' AND pds.status = %s'
            params.append(status)
        sql += ' ORDER BY pds.updated_at DESC LIMIT 200'
        cur.execute(sql, tuple(params))
        return cur.fetchall()
