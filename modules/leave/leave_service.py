"""Leave module service — requests, balances, travel orders, locator, CTO."""
from datetime import date, timedelta
from services.db import get_cursor
from services import workflow_service, notification_service, analytics_service


# ---------------------------------------------------------------------------
# Leave Types & Balances
# ---------------------------------------------------------------------------

def get_leave_types(active_only=True):
    with get_cursor() as cur:
        sql = "SELECT * FROM leave_mgmt.lv_types"
        if active_only:
            sql += " WHERE is_active = TRUE"
        cur.execute(sql + " ORDER BY name")
        return cur.fetchall()


def get_balances(employee_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT lb.*, lt.name AS leave_type_name, lt.code AS leave_type_code,
                   lt.is_paid, lt.requires_document
            FROM leave_mgmt.lv_balances lb
            JOIN leave_mgmt.lv_types lt ON lt.id = lb.leave_type_id
            WHERE lb.employee_id = %s
              AND lb.year = EXTRACT(YEAR FROM CURRENT_DATE)
            ORDER BY lt.name
        """, (employee_id,))
        return cur.fetchall()


def get_departments():
    with get_cursor() as cur:
        cur.execute("SELECT id, name FROM core.departments WHERE is_active = TRUE ORDER BY name")
        return cur.fetchall()


def get_balance_matrix(department_id=None):
    with get_cursor() as cur:
        cur.execute("SELECT * FROM leave_mgmt.v_leave_balance_matrix")
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Leave Requests
# ---------------------------------------------------------------------------

def get_requests(employee_id=None, department_id=None, status=None,
                 date_from=None, date_to=None, page=1, per_page=30):
    conditions = ['1=1']
    params     = []
    if employee_id:
        conditions.append('lr.employee_id = %s')
        params.append(employee_id)
    if department_id:
        conditions.append('e.department_id = %s')
        params.append(department_id)
    if status:
        conditions.append('lr.status = %s')
        params.append(status)
    if date_from:
        conditions.append('lr.date_from >= %s')
        params.append(date_from)
    if date_to:
        conditions.append('lr.date_to <= %s')
        params.append(date_to)

    where  = ' AND '.join(conditions)
    offset = (page - 1) * per_page

    with get_cursor() as cur:
        cur.execute(f"""
            SELECT * FROM leave_mgmt.v_leave_requests_full lr
            JOIN core.v_employees_full e ON e.id = lr.employee_id
            WHERE {where}
            ORDER BY lr.filed_at DESC
            LIMIT %s OFFSET %s
        """, params + [per_page, offset])
        rows = cur.fetchall()
        cur.execute(f"""
            SELECT COUNT(*) FROM leave_mgmt.v_leave_requests_full lr
            JOIN core.v_employees_full e ON e.id = lr.employee_id
            WHERE {where}
        """, params)
        total = cur.fetchone()['count']
    return rows, total


def get_request_detail(request_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM leave_mgmt.v_leave_requests_full
            WHERE id = %s
        """, (request_id,))
        return cur.fetchone()


def submit_request(employee_id, leave_type_id, date_from, date_to,
                   reason, submitted_by, half_day=False, half_day_period=None):
    # Calculate total days
    d_from = date.fromisoformat(str(date_from))
    d_to   = date.fromisoformat(str(date_to))
    total_days = (d_to - d_from).days + 1
    if half_day:
        total_days = 0.5

    # Check balance
    with get_cursor() as cur:
        cur.execute("""
            SELECT balance FROM leave_mgmt.lv_balances
            WHERE employee_id = %s AND leave_type_id = %s
              AND year = EXTRACT(YEAR FROM CURRENT_DATE)
        """, (employee_id, leave_type_id))
        bal = cur.fetchone()

    if bal and float(bal['balance']) < total_days:
        return {'ok': False, 'message': f'Insufficient leave balance. Available: {bal["balance"]} days.'}

    with get_cursor(commit=True) as cur:
        cur.execute("SELECT nextval('leave_mgmt.lv_requests_id_seq') AS id")
        lr_id = cur.fetchone()['id']
        reference_no = f'LV-{lr_id:05d}'
        cur.execute("""
            INSERT INTO leave_mgmt.lv_requests
                (id, reference_no, employee_id, leave_type_id, date_from, date_to,
                 days_requested, reason, status, is_half_day, half_day_type)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'PENDING', %s, %s)
        """, (lr_id, reference_no, employee_id, leave_type_id, date_from, date_to,
              total_days, reason, half_day, half_day_period))

    instance_id = workflow_service.create_instance(
        definition_code='LEAVE_APPROVAL',
        module='leave_mgmt',
        entity_type='lv_requests',
        entity_id=lr_id,
        initiated_by=submitted_by,
        reference_no=f'LV-{lr_id:05d}',
    )
    if instance_id:
        with get_cursor(commit=True) as cur:
            cur.execute("""
                UPDATE leave_mgmt.lv_requests
                SET workflow_instance_id = %s WHERE id = %s
            """, (instance_id, lr_id))

    return {'ok': True, 'id': lr_id}


def action_request(request_id, action_code, performed_by, comments=None):
    with get_cursor() as cur:
        cur.execute("""
            SELECT workflow_instance_id, employee_id, leave_type_id,
                   days_requested, status
            FROM leave_mgmt.lv_requests WHERE id = %s
        """, (request_id,))
        req = cur.fetchone()

    if not req:
        return {'ok': False, 'message': 'Leave request not found.'}

    result = workflow_service.execute_action(
        req['workflow_instance_id'], action_code, performed_by, comments
    )
    if not result['ok']:
        return result

    new_status = 'APPROVED' if action_code == 'APPROVE' else 'REJECTED'
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE leave_mgmt.lv_requests
            SET status = %s
            WHERE id = %s
        """, (new_status, request_id))

        if new_status == 'APPROVED':
            # Deduct from balance
            cur.execute("""
                UPDATE leave_mgmt.lv_balances
                SET used_days = used_days + %s
                WHERE employee_id = %s AND leave_type_id = %s
                  AND year = EXTRACT(YEAR FROM CURRENT_DATE)
            """, (req['days_requested'], req['employee_id'], req['leave_type_id']))

            # Ledger entry
            cur.execute("""
                INSERT INTO leave_mgmt.lv_ledger
                    (employee_id, leave_type_id, year, transaction_type,
                     days, reference_id, reference_type, remarks)
                VALUES (%s, %s, EXTRACT(YEAR FROM CURRENT_DATE), 'USED', %s, %s, 'lv_requests', 'Leave approved')
            """, (req['employee_id'], req['leave_type_id'],
                  req['days_requested'], request_id))

            # Update fact table
            analytics_service.refresh_fact_leave(leave_request_id=request_id)

    event_type = 'LEAVE_APPROVED' if new_status == 'APPROVED' else 'LEAVE_REJECTED'
    notification_service.notify(
        user_id=None,
        event_type=event_type,
        payload={'request_id': request_id, 'status': new_status},
    )
    return result


def cancel_request(request_id, cancelled_by):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE leave_mgmt.lv_requests
            SET status = 'CANCELLED'
            WHERE id = %s AND employee_id = (
                SELECT employee_id FROM core.users WHERE id = %s
            ) AND status = 'PENDING'
        """, (request_id, cancelled_by))
    return True


# ---------------------------------------------------------------------------
# Travel Orders
# ---------------------------------------------------------------------------

def get_travel_orders(employee_id=None, status=None, page=1, per_page=30):
    conditions = ['1=1']
    params     = []
    if employee_id:
        conditions.append('to_.employee_id = %s')
        params.append(employee_id)
    if status:
        conditions.append('to_.status = %s')
        params.append(status)
    where  = ' AND '.join(conditions)
    offset = (page - 1) * per_page
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT to_.*, e.employee_no, e.full_name, e.department_name AS department
            FROM leave_mgmt.lv_travel_orders to_
            JOIN core.v_employees_full e ON e.id = to_.employee_id
            WHERE {where}
            ORDER BY to_.created_at DESC
            LIMIT %s OFFSET %s
        """, params + [per_page, offset])
        rows = cur.fetchall()
        cur.execute(f"""
            SELECT COUNT(*) FROM leave_mgmt.lv_travel_orders to_
            JOIN core.v_employees_full e ON e.id = to_.employee_id
            WHERE {where}
        """, params)
        total = cur.fetchone()['count']
    return rows, total


def submit_travel_order(employee_id, destination, date_from, date_to,
                        purpose, transport_mode, submitted_by):
    with get_cursor(commit=True) as cur:
        ref_no = f'TO-{__import__("uuid").uuid4().hex[:8].upper()}'
        cur.execute("""
            INSERT INTO leave_mgmt.lv_travel_orders
                (reference_no, employee_id, destination, date_from, date_to,
                 purpose, transport_mode, status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, 'DRAFT')
            RETURNING id
        """, (ref_no, employee_id, destination, date_from, date_to,
              purpose, transport_mode))
        to_id = cur.fetchone()['id']

    workflow_service.create_instance(
        definition_code='TRAVEL_APPROVAL',
        module='leave_mgmt',
        entity_type='lv_travel_orders',
        entity_id=to_id,
        initiated_by=submitted_by,
        reference_no=f'TO-{to_id:05d}',
    )
    return to_id


# ---------------------------------------------------------------------------
# Locator Board
# ---------------------------------------------------------------------------

def get_locator_today(department_id=None):
    with get_cursor() as cur:
        if department_id:
            cur.execute("""
                SELECT * FROM leave_mgmt.v_locator_today
                WHERE department_id = %s
                ORDER BY full_name
            """, (department_id,))
        else:
            cur.execute("""
                SELECT * FROM leave_mgmt.v_locator_today
                ORDER BY department, full_name
            """)
        return cur.fetchall()


def log_locator(employee_id, location_status, notes=None, logged_by=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO leave_mgmt.lv_locator_entries
                (employee_id, log_date, location_type)
            VALUES (%s, CURRENT_DATE, %s)
            ON CONFLICT (employee_id, log_date)
            DO UPDATE SET location_type = EXCLUDED.location_type
        """, (employee_id, location_status))


# ---------------------------------------------------------------------------
# CTO Credits
# ---------------------------------------------------------------------------

def get_cto_ledger(employee_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                cc.reference_date AS transaction_date, cc.credit_type AS transaction_type,
                cc.hours_credit AS hours, cc.reason AS remarks, cc.created_at,
                SUM(CASE WHEN cc.credit_type = 'EARNED' THEN cc.hours_credit ELSE 0 END)
                  OVER (ORDER BY cc.reference_date, cc.id) AS running_earned,
                SUM(CASE WHEN cc.credit_type = 'USED'   THEN cc.hours_credit ELSE 0 END)
                  OVER (ORDER BY cc.reference_date, cc.id) AS running_used
            FROM leave_mgmt.lv_cto_credits cc
            WHERE cc.employee_id = %s
            ORDER BY cc.reference_date DESC, cc.id DESC
        """, (employee_id,))
        rows = cur.fetchall()

        cur.execute("""
            SELECT
                COALESCE(SUM(CASE WHEN credit_type = 'EARNED'                    THEN hours_credit ELSE 0 END), 0)
              - COALESCE(SUM(CASE WHEN credit_type IN ('USED','FORFEITED','EXPIRED') THEN hours_credit ELSE 0 END), 0)
              AS balance_hours
            FROM leave_mgmt.lv_cto_credits
            WHERE employee_id = %s
        """, (employee_id,))
        balance = cur.fetchone()['balance_hours']
    return rows, balance


def adjust_balance(employee_id, leave_type_id, year, adjustment_days,
                   reason, adjusted_by):
    """Manually credit (+) or debit (–) a leave balance and log the adjustment."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT id, accrued_days, used_days
            FROM leave_mgmt.lv_balances
            WHERE employee_id = %s AND leave_type_id = %s AND year = %s
        """, (employee_id, leave_type_id, year))
        bal = cur.fetchone()

    if not bal:
        return {'ok': False, 'message': 'Leave balance record not found for that employee/type/year.'}

    new_accrued = float(bal['accrued_days']) + adjustment_days
    if new_accrued < 0:
        return {'ok': False, 'message': f'Adjustment would result in negative accrued balance ({new_accrued:.2f}).'}

    with get_cursor(commit=True) as cur:
        # Update the balance
        cur.execute("""
            UPDATE leave_mgmt.lv_balances
            SET accrued_days = accrued_days + %s
            WHERE id = %s
        """, (adjustment_days, bal['id']))
        # Write audit record
        cur.execute("""
            INSERT INTO leave_mgmt.lv_balance_adjustments
                (employee_id, leave_type_id, year, adjustment_days, reason, adjusted_by)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (employee_id, leave_type_id, year, adjustment_days, reason, adjusted_by))
        adj_id = cur.fetchone()['id']

    return {'ok': True, 'id': adj_id,
            'message': f'Balance adjusted by {adjustment_days:+.2f} days. Audit record #{adj_id} created.'}


def get_balance_adjustments(employee_id, year=None):
    """Return balance adjustment history for an employee."""
    with get_cursor() as cur:
        params = [employee_id]
        year_clause = 'AND a.year = %s' if year else ''
        if year:
            params.append(year)
        cur.execute(f"""
            SELECT a.*, lt.name AS leave_type_name, lt.code AS leave_type_code,
                   u.display_name AS adjusted_by_name
            FROM leave_mgmt.lv_balance_adjustments a
            JOIN leave_mgmt.lv_types lt ON lt.id = a.leave_type_id
            JOIN core.users u ON u.id = a.adjusted_by
            WHERE a.employee_id = %s {year_clause}
            ORDER BY a.adjusted_at DESC
        """, params)
        return cur.fetchall()


def adjust_cto(employee_id, transaction_type, hours, remarks, adjusted_by,
               reference_id=None, reference_type=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO leave_mgmt.lv_cto_credits
                (employee_id, reference_date, credit_type, hours_credit, reason, approved_by)
            VALUES (%s, CURRENT_DATE, %s, %s, %s, %s)
            RETURNING id
        """, (employee_id, transaction_type.upper(), hours, remarks, adjusted_by))
        return cur.fetchone()['id']
