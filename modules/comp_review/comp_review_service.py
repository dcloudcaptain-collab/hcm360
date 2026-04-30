"""Compensation Review Service — cycles, worksheets, budget tracking."""
from services.db import get_cursor


# ---------------------------------------------------------------------------
# Review Cycles
# ---------------------------------------------------------------------------

def get_review_cycles(status=None):
    """List cycles with worksheet counts and budget usage."""
    conditions = []
    params = []
    if status:
        conditions.append('c.status = %s')
        params.append(status)
    where = 'WHERE ' + ' AND '.join(conditions) if conditions else ''
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT c.*,
                   COUNT(w.id) AS worksheet_count,
                   COALESCE(SUM(w.proposed_increase_amt), 0) AS total_proposed,
                   COALESCE(SUM(w.bonus_amount), 0) AS total_bonus
            FROM payroll.comp_review_cycles c
            LEFT JOIN payroll.comp_worksheets w ON w.cycle_id = c.id
            {where}
            GROUP BY c.id
            ORDER BY c.year DESC, c.created_at DESC
        """, params)
        return cur.fetchall()


def get_cycle_detail(cycle_id):
    """Return cycle + all worksheets with employee info."""
    with get_cursor() as cur:
        cur.execute("SELECT * FROM payroll.comp_review_cycles WHERE id = %s", (cycle_id,))
        cycle = cur.fetchone()

        cur.execute("""
            SELECT w.*,
                   emp.first_name || ' ' || emp.last_name AS employee_name,
                   emp.employee_no,
                   d.name AS department_name,
                   p.title AS position_title,
                   mgr.first_name || ' ' || mgr.last_name AS manager_name
            FROM payroll.comp_worksheets w
            JOIN core.employees emp ON emp.id = w.employee_id
            LEFT JOIN core.departments d ON d.id = emp.department_id
            LEFT JOIN core.positions p ON p.id = emp.position_id
            LEFT JOIN core.employees mgr ON mgr.id = w.manager_id
            WHERE w.cycle_id = %s
            ORDER BY d.name, emp.last_name
        """, (cycle_id,))
        worksheets = cur.fetchall()

    return cycle, worksheets


def create_cycle(company_id, name, year, review_type, budget_amount, budget_pct,
                 open_date, close_date, created_by):
    """Insert a new compensation review cycle."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO payroll.comp_review_cycles
                (company_id, name, year, review_type, budget_amount, budget_pct,
                 open_date, close_date, created_by, status)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,'DRAFT')
            RETURNING id
        """, (company_id, name, year, review_type, budget_amount, budget_pct,
              open_date, close_date, created_by))
        return cur.fetchone()['id']


# ---------------------------------------------------------------------------
# Worksheets
# ---------------------------------------------------------------------------

def get_worksheets(cycle_id, manager_id=None):
    """Get worksheets, optionally filtered by manager."""
    conditions = ['w.cycle_id = %s']
    params = [cycle_id]
    if manager_id:
        conditions.append('w.manager_id = %s')
        params.append(manager_id)
    where = 'WHERE ' + ' AND '.join(conditions)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT w.*,
                   emp.first_name || ' ' || emp.last_name AS employee_name,
                   emp.employee_no
            FROM payroll.comp_worksheets w
            JOIN core.employees emp ON emp.id = w.employee_id
            {where}
            ORDER BY emp.last_name
        """, params)
        return cur.fetchall()


def create_worksheet(cycle_id, employee_id, manager_id, current_salary):
    """Create a worksheet. compa_ratio left NULL (salary structure not yet configured)."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO payroll.comp_worksheets
                (cycle_id, employee_id, manager_id, current_salary, compa_ratio, status)
            VALUES (%s, %s, %s, %s, NULL, 'DRAFT')
            RETURNING id
        """, (cycle_id, employee_id, manager_id, current_salary))
        return cur.fetchone()['id']


def update_worksheet(worksheet_id, proposed_increase_pct=None, bonus_amount=None,
                     manager_justification=None, hr_notes=None, status=None):
    """Update worksheet; auto-compute proposed amounts from percentage."""
    with get_cursor(commit=True) as cur:
        # Get current salary to compute amounts
        cur.execute("SELECT current_salary FROM payroll.comp_worksheets WHERE id = %s",
                    (worksheet_id,))
        ws = cur.fetchone()
        proposed_increase_amt = None
        proposed_new_salary = None
        if ws and proposed_increase_pct is not None:
            salary = float(ws['current_salary'])
            proposed_increase_amt = round(salary * (proposed_increase_pct / 100), 2)
            proposed_new_salary = round(salary + proposed_increase_amt, 2)

        sets = []
        params = []
        if proposed_increase_pct is not None:
            sets.append('proposed_increase_pct = %s')
            params.append(proposed_increase_pct)
        if proposed_increase_amt is not None:
            sets.append('proposed_increase_amt = %s')
            params.append(proposed_increase_amt)
        if proposed_new_salary is not None:
            sets.append('proposed_new_salary = %s')
            params.append(proposed_new_salary)
        if bonus_amount is not None:
            sets.append('bonus_amount = %s')
            params.append(bonus_amount)
        if manager_justification is not None:
            sets.append('manager_justification = %s')
            params.append(manager_justification)
        if hr_notes is not None:
            sets.append('hr_notes = %s')
            params.append(hr_notes)
        if status is not None:
            sets.append('status = %s')
            params.append(status)

        if sets:
            params.append(worksheet_id)
            cur.execute(f"""
                UPDATE payroll.comp_worksheets SET {', '.join(sets)} WHERE id = %s
            """, params)


def approve_worksheet(worksheet_id, status):
    """Set worksheet status (APPROVED / REJECTED)."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE payroll.comp_worksheets SET status = %s WHERE id = %s
        """, (status, worksheet_id))


# ---------------------------------------------------------------------------
# Budget
# ---------------------------------------------------------------------------

def get_budget_summary(cycle_id):
    """Total proposed vs budget, by department."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT c.budget_amount, c.budget_pct,
                   COALESCE(SUM(w.proposed_increase_amt), 0) AS total_proposed_increase,
                   COALESCE(SUM(w.bonus_amount), 0) AS total_bonus,
                   COALESCE(SUM(w.proposed_increase_amt), 0) + COALESCE(SUM(w.bonus_amount), 0) AS total_cost,
                   COUNT(w.id) AS worksheet_count
            FROM payroll.comp_review_cycles c
            LEFT JOIN payroll.comp_worksheets w ON w.cycle_id = c.id
            WHERE c.id = %s
            GROUP BY c.id
        """, (cycle_id,))
        summary = cur.fetchone()

        cur.execute("""
            SELECT d.name AS department_name,
                   COUNT(w.id) AS worksheets,
                   COALESCE(SUM(w.proposed_increase_amt), 0) AS dept_proposed,
                   COALESCE(SUM(w.bonus_amount), 0) AS dept_bonus
            FROM payroll.comp_worksheets w
            JOIN core.employees emp ON emp.id = w.employee_id
            JOIN core.departments d ON d.id = emp.department_id
            WHERE w.cycle_id = %s
            GROUP BY d.name
            ORDER BY SUM(w.proposed_increase_amt) DESC
        """, (cycle_id,))
        by_dept = cur.fetchall()

    return summary, by_dept


# ---------------------------------------------------------------------------
# Finalize
# ---------------------------------------------------------------------------

def finalize_cycle(cycle_id):
    """Set cycle to FINALIZED."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE payroll.comp_review_cycles SET status = 'FINALIZED' WHERE id = %s
        """, (cycle_id,))
