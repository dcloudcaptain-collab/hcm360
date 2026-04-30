"""Admin-facing extended employee data — 201 file sections + CRUD."""
from services.db import get_cursor


# ── Lookups for form dropdowns ─────────────────────────────────────
def get_form_options():
    """Return all dropdown options needed by the employee create/edit form."""
    with get_cursor() as cur:
        cur.execute("SELECT id, code, name FROM core.departments WHERE company_id = (SELECT id FROM core.companies LIMIT 1) ORDER BY name")
        departments = cur.fetchall()
        cur.execute("SELECT id, title FROM core.positions WHERE company_id = (SELECT id FROM core.companies LIMIT 1) ORDER BY title")
        positions = cur.fetchall()
        cur.execute("SELECT id, code, name FROM core.job_grades WHERE company_id = (SELECT id FROM core.companies LIMIT 1) ORDER BY grade_level")
        job_grades = cur.fetchall()
        cur.execute("SELECT id, code, name FROM core.employment_types ORDER BY name")
        employment_types = cur.fetchall()
        cur.execute("SELECT id, employee_no, first_name || ' ' || last_name AS full_name FROM core.employees WHERE is_active = TRUE ORDER BY last_name, first_name")
        supervisors = cur.fetchall()
    return {
        'departments': departments,
        'positions': positions,
        'job_grades': job_grades,
        'employment_types': employment_types,
        'supervisors': supervisors,
    }


def get_employee(employee_id):
    """Get a single employee record for editing."""
    with get_cursor() as cur:
        cur.execute("SELECT * FROM core.employees WHERE id = %s", (employee_id,))
        return cur.fetchone()


def _derive_username(first, last, employee_no):
    """firstname.lastname — spaces stripped, lowercase."""
    f = (first or '').strip().lower().replace(' ', '')
    l = (last or '').strip().lower().replace(' ', '')
    base = f'{f}.{l}' if (f and l) else (employee_no or 'user').lower()
    return base or 'user'


def _unique_username(cur, base):
    """Return `base`, or `base-N` if taken."""
    cur.execute("SELECT 1 FROM core.users WHERE username = %s", (base,))
    if not cur.fetchone():
        return base
    n = 2
    while True:
        cand = f'{base}-{n}'
        cur.execute("SELECT 1 FROM core.users WHERE username = %s", (cand,))
        if not cur.fetchone():
            return cand
        n += 1


def _ensure_user_for_employee(cur, employee_id, data, is_active=True):
    """Create or update the core.users row linked to this employee.

    Every employee gets a matching user account so they appear in the
    simulated-login dropdown and can be authenticated (once password is set).
    Returns the user_id.
    """
    # Already linked?
    cur.execute("SELECT id, username FROM core.users WHERE employee_id = %s LIMIT 1",
                (employee_id,))
    existing = cur.fetchone()

    display_name = ' '.join(filter(None, [
        (data.get('first_name') or '').strip(),
        (data.get('middle_name') or '').strip(),
        (data.get('last_name') or '').strip(),
    ])).strip() or data.get('employee_no') or f'Employee #{employee_id}'

    email = (data.get('work_email') or data.get('personal_email') or '').strip() or None

    if existing:
        # Keep display_name / email / active flag in sync on update
        cur.execute("""
            UPDATE core.users
               SET display_name = %s,
                   email        = COALESCE(%s, email),
                   is_active    = %s,
                   employee_id  = %s,
                   updated_at   = NOW()
             WHERE id = %s
        """, (display_name, email, is_active, employee_id, existing['id']))
        return existing['id']

    # Build a new user row
    cur.execute("SELECT company_id FROM core.employees WHERE id = %s", (employee_id,))
    row = cur.fetchone() or {}
    company_id = row.get('company_id')

    username = _unique_username(cur,
        _derive_username(data.get('first_name'), data.get('last_name'),
                         data.get('employee_no')))

    cur.execute("""
        INSERT INTO core.users
            (company_id, username, email, password_hash, display_name,
             role_code, employee_id, is_active, failed_attempts,
             mfa_enabled, password_changed_at, created_at, updated_at)
        VALUES (%s, %s, %s, '', %s, 'EMPLOYEE', %s, %s, 0, FALSE, NULL, NOW(), NOW())
        RETURNING id
    """, (company_id, username, email, display_name, employee_id, is_active))
    return cur.fetchone()['id']


class ValidationBlocked(Exception):
    """Raised when an industry-standard HR validation rule blocks a write.
    `result` carries the full {'errors': [...], 'warnings': [...]} payload."""
    def __init__(self, result):
        self.result = result
        codes = ', '.join(e['rule_code'] for e in result.get('errors', []))
        super().__init__(f'Validation blocked by: {codes}')


def _run_employee_validations(data, exclude_id=None):
    """Run validations and raise ValidationBlocked if any ERRORs survive bypass.
    Returns the result dict so callers can also surface warnings."""
    from services import validation_service  # local import to avoid cycles
    res = validation_service.validate('EMPLOYEE', dict(data), id=exclude_id)
    if validation_service.has_blockers(res):
        raise ValidationBlocked(res)
    return res


def create_employee(data, user_id=None):
    """Create a new employee + matching core.users row. Returns the new employee's id."""
    _run_employee_validations(data)
    with get_cursor(commit=True) as cur:
        cur.execute("SELECT id FROM core.companies LIMIT 1")
        co_id = cur.fetchone()['id']
        is_active = data.get('status', 'ACTIVE') == 'ACTIVE'
        cur.execute("""
            INSERT INTO core.employees
                (company_id, employee_no, last_name, first_name, middle_name, suffix,
                 gender, civil_status, nationality, date_of_birth, place_of_birth,
                 personal_email, work_email, mobile_no,
                 department_id, position_id, job_grade_id, employment_type_id,
                 immediate_supervisor_id, date_hired, basic_salary,
                 work_arrangement, status, is_active, created_by)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            RETURNING id
        """, (
            co_id,
            data.get('employee_no'), data.get('last_name'), data.get('first_name'),
            data.get('middle_name') or None, data.get('suffix') or None,
            data.get('gender') or None, data.get('civil_status') or None,
            data.get('nationality') or 'Filipino',
            data.get('date_of_birth') or None, data.get('place_of_birth') or None,
            data.get('personal_email') or None, data.get('work_email') or None,
            data.get('mobile_no') or None,
            int(data['department_id']) if data.get('department_id') else None,
            int(data['position_id']) if data.get('position_id') else None,
            int(data['job_grade_id']) if data.get('job_grade_id') else None,
            int(data['employment_type_id']) if data.get('employment_type_id') else None,
            int(data['immediate_supervisor_id']) if data.get('immediate_supervisor_id') else None,
            data.get('date_hired') or None,
            float(data['basic_salary']) if data.get('basic_salary') else None,
            data.get('work_arrangement') or 'ONSITE',
            data.get('status') or 'ACTIVE',
            is_active,
            user_id,
        ))
        emp_id = cur.fetchone()['id']

        # Auto-create matching user account so the employee appears in the
        # simulated-login dropdown and can be granted access.
        try:
            _ensure_user_for_employee(cur, emp_id, data, is_active=is_active)
        except Exception:
            pass  # Don't break employee creation if user provisioning fails

        return emp_id


def update_employee(employee_id, data, user_id=None):
    """Update an existing employee record + keep linked user row in sync."""
    _run_employee_validations(data, exclude_id=employee_id)
    is_active = data.get('status', 'ACTIVE') == 'ACTIVE'
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.employees SET
                employee_no = %s, last_name = %s, first_name = %s, middle_name = %s, suffix = %s,
                gender = %s, civil_status = %s, nationality = %s,
                date_of_birth = %s, place_of_birth = %s,
                personal_email = %s, work_email = %s, mobile_no = %s,
                department_id = %s, position_id = %s, job_grade_id = %s, employment_type_id = %s,
                immediate_supervisor_id = %s, date_hired = %s, basic_salary = %s,
                work_arrangement = %s, status = %s, is_active = %s,
                updated_by = %s, updated_at = NOW()
            WHERE id = %s
        """, (
            data.get('employee_no'), data.get('last_name'), data.get('first_name'),
            data.get('middle_name') or None, data.get('suffix') or None,
            data.get('gender') or None, data.get('civil_status') or None,
            data.get('nationality') or 'Filipino',
            data.get('date_of_birth') or None, data.get('place_of_birth') or None,
            data.get('personal_email') or None, data.get('work_email') or None,
            data.get('mobile_no') or None,
            int(data['department_id']) if data.get('department_id') else None,
            int(data['position_id']) if data.get('position_id') else None,
            int(data['job_grade_id']) if data.get('job_grade_id') else None,
            int(data['employment_type_id']) if data.get('employment_type_id') else None,
            int(data['immediate_supervisor_id']) if data.get('immediate_supervisor_id') else None,
            data.get('date_hired') or None,
            float(data['basic_salary']) if data.get('basic_salary') else None,
            data.get('work_arrangement') or 'ONSITE',
            data.get('status') or 'ACTIVE',
            is_active,
            user_id,
            employee_id,
        ))
        # Keep linked user row in sync (or create if missing)
        try:
            _ensure_user_for_employee(cur, employee_id, data, is_active=is_active)
        except Exception:
            pass


def backfill_user_accounts():
    """Create core.users rows for any active employees missing one.

    Used to catch up after fresh seeds or imports that bypassed create_employee().
    Safe to run repeatedly — only inserts for employees without a linked user.
    Returns the count of newly-created user rows.
    """
    created = 0
    with get_cursor(commit=True) as cur:
        cur.execute("""
            SELECT e.id, e.employee_no, e.first_name, e.middle_name, e.last_name,
                   e.work_email, e.personal_email, e.is_active
            FROM core.employees e
            WHERE NOT EXISTS (
                SELECT 1 FROM core.users u WHERE u.employee_id = e.id
            )
            ORDER BY e.id
        """)
        orphans = cur.fetchall()
        for e in orphans:
            try:
                _ensure_user_for_employee(cur, e['id'], dict(e),
                                           is_active=bool(e.get('is_active')))
                created += 1
            except Exception:
                continue
    return created


def delete_employee(employee_id):
    """Soft-delete an employee — set is_active=FALSE, status=SEPARATED.
    Also deactivate linked user account. Does NOT hard-delete the row."""
    with get_cursor(commit=True) as cur:
        # Deactivate linked user
        cur.execute("""
            UPDATE core.users SET is_active = FALSE
            WHERE employee_id = %s
        """, (employee_id,))
        # Soft-delete the employee
        cur.execute("""
            UPDATE core.employees
            SET is_active = FALSE, status = 'SEPARATED',
                date_separated = CURRENT_DATE, updated_at = NOW()
            WHERE id = %s
        """, (employee_id,))


# ── Sub-table CRUD: Addresses ──────────────────────────────────────
def get_addresses(employee_id):
    with get_cursor() as cur:
        cur.execute("SELECT * FROM core.emp_addresses WHERE employee_id = %s ORDER BY is_primary DESC, id", (employee_id,))
        return cur.fetchall()

def get_address(address_id):
    with get_cursor() as cur:
        cur.execute("SELECT * FROM core.emp_addresses WHERE id = %s", (address_id,))
        return cur.fetchone()

def save_address(data, employee_id, address_id=None):
    with get_cursor(commit=True) as cur:
        vals = (employee_id, data['address_type'], data['line1'], data.get('line2') or None,
                data.get('barangay') or None, data.get('city') or None,
                data.get('province') or None, data.get('region') or None,
                data.get('zip_code') or None, data.get('country') or 'Philippines',
                data.get('is_primary') == 'on')
        if address_id:
            cur.execute("""UPDATE core.emp_addresses SET
                address_type=%s, line1=%s, line2=%s, barangay=%s, city=%s,
                province=%s, region=%s, zip_code=%s, country=%s, is_primary=%s, updated_at=NOW()
                WHERE id=%s""", vals[1:] + (address_id,))
        else:
            cur.execute("""INSERT INTO core.emp_addresses
                (employee_id, address_type, line1, line2, barangay, city, province, region, zip_code, country, is_primary)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id""", vals)
            return cur.fetchone()['id']

def delete_address(address_id):
    with get_cursor(commit=True) as cur:
        cur.execute("DELETE FROM core.emp_addresses WHERE id = %s", (address_id,))


# ── Sub-table CRUD: Emergency Contacts ─────────────────────────────
def get_emergency_contacts(employee_id):
    with get_cursor() as cur:
        cur.execute("SELECT * FROM core.emp_emergency_contacts WHERE employee_id = %s ORDER BY is_primary DESC, id", (employee_id,))
        return cur.fetchall()

def get_emergency_contact(contact_id):
    with get_cursor() as cur:
        cur.execute("SELECT * FROM core.emp_emergency_contacts WHERE id = %s", (contact_id,))
        return cur.fetchone()

def save_emergency_contact(data, employee_id, contact_id=None):
    with get_cursor(commit=True) as cur:
        vals = (data['full_name'], data['relationship'],
                data.get('mobile_no') or None, data.get('phone_no') or None,
                data.get('address') or None, data.get('is_primary') == 'on')
        if contact_id:
            cur.execute("""UPDATE core.emp_emergency_contacts SET
                full_name=%s, relationship=%s, mobile_no=%s, phone_no=%s, address=%s, is_primary=%s
                WHERE id=%s""", vals + (contact_id,))
        else:
            cur.execute("""INSERT INTO core.emp_emergency_contacts
                (employee_id, full_name, relationship, mobile_no, phone_no, address, is_primary)
                VALUES (%s,%s,%s,%s,%s,%s,%s) RETURNING id""", (employee_id,) + vals)
            return cur.fetchone()['id']

def delete_emergency_contact(contact_id):
    with get_cursor(commit=True) as cur:
        cur.execute("DELETE FROM core.emp_emergency_contacts WHERE id = %s", (contact_id,))


# ── Sub-table CRUD: Government IDs ─────────────────────────────────
def get_government_ids(employee_id):
    with get_cursor() as cur:
        cur.execute("SELECT * FROM core.emp_government_ids WHERE employee_id = %s ORDER BY id_type", (employee_id,))
        return cur.fetchall()

def get_government_id(gov_id):
    with get_cursor() as cur:
        cur.execute("SELECT * FROM core.emp_government_ids WHERE id = %s", (gov_id,))
        return cur.fetchone()

def save_government_id(data, employee_id, gov_id=None):
    with get_cursor(commit=True) as cur:
        vals = (data['id_type'], data['id_number'],
                data.get('issue_date') or None, data.get('expiry_date') or None)
        if gov_id:
            cur.execute("""UPDATE core.emp_government_ids SET
                id_type=%s, id_number=%s, issue_date=%s, expiry_date=%s, updated_at=NOW()
                WHERE id=%s""", vals + (gov_id,))
        else:
            cur.execute("""INSERT INTO core.emp_government_ids
                (employee_id, id_type, id_number, issue_date, expiry_date)
                VALUES (%s,%s,%s,%s,%s) RETURNING id""", (employee_id,) + vals)
            return cur.fetchone()['id']

def delete_government_id(gov_id):
    with get_cursor(commit=True) as cur:
        cur.execute("DELETE FROM core.emp_government_ids WHERE id = %s", (gov_id,))


# ── Sub-table CRUD: Bank Accounts ──────────────────────────────────
def get_bank_accounts(employee_id):
    with get_cursor() as cur:
        cur.execute("SELECT * FROM core.emp_bank_accounts WHERE employee_id = %s ORDER BY is_primary DESC, id", (employee_id,))
        return cur.fetchall()

def get_bank_account(account_id):
    with get_cursor() as cur:
        cur.execute("SELECT * FROM core.emp_bank_accounts WHERE id = %s", (account_id,))
        return cur.fetchone()

def save_bank_account(data, employee_id, account_id=None):
    with get_cursor(commit=True) as cur:
        vals = (data['bank_name'], data.get('bank_code') or None,
                data['account_name'], data['account_number'],
                data.get('account_type') or 'SAVINGS',
                data.get('is_primary') == 'on')
        if account_id:
            cur.execute("""UPDATE core.emp_bank_accounts SET
                bank_name=%s, bank_code=%s, account_name=%s, account_number=%s,
                account_type=%s, is_primary=%s, updated_at=NOW()
                WHERE id=%s""", vals + (account_id,))
        else:
            cur.execute("""INSERT INTO core.emp_bank_accounts
                (employee_id, bank_name, bank_code, account_name, account_number, account_type, is_primary)
                VALUES (%s,%s,%s,%s,%s,%s,%s) RETURNING id""", (employee_id,) + vals)
            return cur.fetchone()['id']

def delete_bank_account(account_id):
    with get_cursor(commit=True) as cur:
        cur.execute("DELETE FROM core.emp_bank_accounts WHERE id = %s", (account_id,))


# ── Sub-table CRUD: Dependents ─────────────────────────────────────
def get_dependents(employee_id):
    with get_cursor() as cur:
        cur.execute("SELECT * FROM core.emp_dependents WHERE employee_id = %s ORDER BY relationship, full_name", (employee_id,))
        return cur.fetchall()

def get_dependent(dep_id):
    with get_cursor() as cur:
        cur.execute("SELECT * FROM core.emp_dependents WHERE id = %s", (dep_id,))
        return cur.fetchone()

def save_dependent(data, employee_id, dep_id=None):
    with get_cursor(commit=True) as cur:
        vals = (data['full_name'], data['relationship'],
                data.get('date_of_birth') or None, data.get('is_beneficiary') == 'on')
        if dep_id:
            cur.execute("""UPDATE core.emp_dependents SET
                full_name=%s, relationship=%s, date_of_birth=%s, is_beneficiary=%s
                WHERE id=%s""", vals + (dep_id,))
        else:
            cur.execute("""INSERT INTO core.emp_dependents
                (employee_id, full_name, relationship, date_of_birth, is_beneficiary)
                VALUES (%s,%s,%s,%s,%s) RETURNING id""", (employee_id,) + vals)
            return cur.fetchone()['id']

def delete_dependent(dep_id):
    with get_cursor(commit=True) as cur:
        cur.execute("DELETE FROM core.emp_dependents WHERE id = %s", (dep_id,))


def get_employee_extended(employee_id: int) -> dict:
    """Return all admin-only 201 sections for a given employee."""
    with get_cursor() as cur:

        # Education
        cur.execute("""
            SELECT level, institution, degree, field_of_study,
                   year_from, year_to, is_highest
            FROM core.emp_education
            WHERE employee_id = %s
            ORDER BY is_highest DESC, year_to DESC NULLS LAST
        """, (employee_id,))
        education = cur.fetchall()

        # Work History
        cur.execute("""
            SELECT company_name, position_held, date_from, date_to,
                   reason_for_leaving
            FROM core.emp_work_history
            WHERE employee_id = %s
            ORDER BY date_from DESC NULLS LAST
        """, (employee_id,))
        work_history = cur.fetchall()

        # Status History
        cur.execute("""
            SELECT sh.effective_date, sh.from_status, sh.to_status,
                   sh.reason, u.display_name AS changed_by_name
            FROM core.emp_status_history sh
            LEFT JOIN core.users u ON u.id = sh.changed_by
            WHERE sh.employee_id = %s
            ORDER BY sh.effective_date DESC
        """, (employee_id,))
        status_history = cur.fetchall()

        # Documents (201 file checklist)
        cur.execute("""
            SELECT document_type, document_name,
                   is_missing, is_expired, expiry_date
            FROM core.documents
            WHERE employee_id = %s
            ORDER BY document_type, document_name
        """, (employee_id,))
        documents = cur.fetchall()

        # Leave Balances (current year)
        cur.execute("""
            SELECT lb.leave_type_id, lt.name AS leave_type_name, lt.code,
                   lb.entitled_days, lb.used_days, lb.balance
            FROM leave_mgmt.lv_balances lb
            JOIN leave_mgmt.lv_types lt ON lt.id = lb.leave_type_id
            WHERE lb.employee_id = %s
              AND lb.year = EXTRACT(YEAR FROM CURRENT_DATE)
            ORDER BY lt.name
        """, (employee_id,))
        leave_balances = cur.fetchall()

        # Payroll History (last 6 completed runs)
        cur.execute("""
            SELECT ep.run_id, ep.basic_pay, ep.gross_pay, ep.net_pay,
                   prd.date_from, prd.date_to, prd.period_type,
                   prd.payment_date
            FROM payroll.pay_employee_payroll ep
            JOIN payroll.pay_runs pr ON pr.id = ep.run_id
            JOIN payroll.pay_periods prd ON prd.id = pr.period_id
            WHERE ep.employee_id = %s
              AND pr.status = 'COMPLETED'
            ORDER BY prd.date_from DESC
            LIMIT 6
        """, (employee_id,))
        payroll_history = cur.fetchall()

    return {
        'education':      education,
        'work_history':   work_history,
        'status_history': status_history,
        'documents':      documents,
        'leave_balances': leave_balances,
        'payroll_history': payroll_history,
    }
