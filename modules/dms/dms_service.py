"""DMS service — 201 file, checklists, service records, retention."""
import json
from datetime import date
from services.db import get_cursor


# ---------------------------------------------------------------------------
# Document Categories
# ---------------------------------------------------------------------------

def get_categories(company_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM dms.document_categories
            WHERE company_id = %s AND is_active = TRUE
            ORDER BY sort_order
        """, (company_id,))
        return cur.fetchall()


# ---------------------------------------------------------------------------
# 201 File Checklist
# ---------------------------------------------------------------------------

def get_checklist_for_employee(employee_id):
    """Returns required docs vs submitted for an employee."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT ci.id AS item_id, ci.document_type, ci.label, ci.is_mandatory,
                   doc.id AS doc_id, doc.document_name, doc.file_path, doc.status AS doc_status,
                   doc.uploaded_by, doc.created_at AS uploaded_at
            FROM core.employees e
            JOIN dms.checklist_templates ct
                ON ct.company_id = e.company_id
                AND (ct.employment_type_id IS NULL OR ct.employment_type_id = e.employment_type_id)
                AND ct.is_active = TRUE
            JOIN dms.checklist_items ci ON ci.template_id = ct.id
            LEFT JOIN core.documents doc
                ON doc.employee_id = e.id
                AND doc.document_type = ci.document_type
                AND doc.status != 'REJECTED'
            WHERE e.id = %s
            ORDER BY ci.sort_order
        """, (employee_id,))
        return cur.fetchall()


def get_completeness_dashboard(company_id, department_id=None):
    """Aggregate 201 file completeness per employee."""
    conditions = ['e.is_active = TRUE', 'e.company_id = %s']
    params = [company_id]
    if department_id:
        conditions.append('e.department_id = %s')
        params.append(department_id)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT e.id AS employee_id,
                   e.first_name || ' ' || e.last_name AS employee_name,
                   d.name AS department_name,
                   COUNT(DISTINCT ci.id) AS required_count,
                   COUNT(DISTINCT doc.id) AS submitted_count
            FROM core.employees e
            LEFT JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN dms.checklist_templates ct
                ON ct.company_id = e.company_id
                AND (ct.employment_type_id IS NULL OR ct.employment_type_id = e.employment_type_id)
                AND ct.is_active = TRUE
            LEFT JOIN dms.checklist_items ci ON ci.template_id = ct.id
            LEFT JOIN core.documents doc
                ON doc.employee_id = e.id
                AND doc.document_type = ci.document_type
                AND doc.status != 'REJECTED'
            WHERE {' AND '.join(conditions)}
            GROUP BY e.id, e.first_name, e.last_name, d.name
            ORDER BY d.name, e.last_name
        """, params)
        rows = cur.fetchall()
        # compute pct in python to avoid division issues
        result = []
        for r in rows:
            row = dict(r)
            req = row['required_count'] or 0
            sub = row['submitted_count'] or 0
            row['pct_complete'] = round(sub / req * 100) if req > 0 else 0
            result.append(row)
        return result


# ---------------------------------------------------------------------------
# Document Requests
# ---------------------------------------------------------------------------

def get_document_requests(company_id, status=None, employee_id=None):
    conditions = ['dr.company_id = %s']
    params = [company_id]
    if status:
        conditions.append('dr.status = %s')
        params.append(status)
    if employee_id:
        conditions.append('dr.employee_id = %s')
        params.append(employee_id)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT dr.*,
                   e.first_name || ' ' || e.last_name AS employee_name,
                   u.display_name AS requested_by_name
            FROM dms.document_requests dr
            JOIN core.employees e ON e.id = dr.employee_id
            JOIN core.users u ON u.id = dr.requested_by
            WHERE {' AND '.join(conditions)}
            ORDER BY dr.created_at DESC
        """, params)
        return cur.fetchall()


def create_document_request(company_id, employee_id, document_type, purpose, requested_by, due_date=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO dms.document_requests
                (company_id, employee_id, document_type, purpose, requested_by, due_date)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (company_id, employee_id, document_type, purpose, requested_by, due_date))
        return cur.fetchone()


def fulfill_document_request(request_id, doc_id, user_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE dms.document_requests
            SET status = 'SUBMITTED', fulfilled_doc_id = %s, updated_at = NOW()
            WHERE id = %s
            RETURNING id
        """, (doc_id, request_id))
        return cur.fetchone()


# ---------------------------------------------------------------------------
# CSC Form 212 — Service Record Generator
# ---------------------------------------------------------------------------

def generate_service_record(employee_id, user_id):
    """Pull employee data from multiple tables and create a snapshot."""
    with get_cursor(commit=True) as cur:
        # Employee master
        cur.execute("""
            SELECT e.*, d.name AS department_name, p.title AS position_title,
                   jg.grade_level AS salary_grade
            FROM core.employees e
            LEFT JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.positions p ON p.id = e.position_id
            LEFT JOIN core.job_grades jg ON jg.id = e.job_grade_id
            WHERE e.id = %s
        """, (employee_id,))
        emp = cur.fetchone()
        if not emp:
            return None

        # Education
        cur.execute("""
            SELECT * FROM core.emp_education WHERE employee_id = %s ORDER BY year_to DESC
        """, (employee_id,))
        education = [dict(r) for r in cur.fetchall()]

        # Work history
        cur.execute("""
            SELECT * FROM core.emp_work_history WHERE employee_id = %s ORDER BY date_from DESC
        """, (employee_id,))
        work_history = [dict(r) for r in cur.fetchall()]

        # Government IDs
        cur.execute("""
            SELECT * FROM core.emp_government_ids WHERE employee_id = %s
        """, (employee_id,))
        gov_ids = [dict(r) for r in cur.fetchall()]

        # Build snapshot
        snapshot = {
            'employee': {k: str(v) if v is not None else None for k, v in dict(emp).items()},
            'education': education,
            'work_history': work_history,
            'government_ids': gov_ids,
            'generated_date': str(date.today()),
        }

        # Mark previous as not latest
        cur.execute("""
            UPDATE dms.service_record_snapshots
            SET is_latest = FALSE WHERE employee_id = %s
        """, (employee_id,))

        cur.execute("""
            INSERT INTO dms.service_record_snapshots
                (employee_id, generated_by, snapshot_data, is_latest)
            VALUES (%s, %s, %s, TRUE)
            RETURNING id
        """, (employee_id, user_id, json.dumps(snapshot, default=str)))
        return cur.fetchone()


def get_service_record(employee_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM dms.service_record_snapshots
            WHERE employee_id = %s AND is_latest = TRUE
            ORDER BY generated_at DESC LIMIT 1
        """, (employee_id,))
        return cur.fetchone()


# ---------------------------------------------------------------------------
# Leave Card Summary
# ---------------------------------------------------------------------------

def get_leave_card_summary(employee_id, year=None):
    yr = year or date.today().year
    with get_cursor() as cur:
        # Balances
        cur.execute("""
            SELECT lb.*, lt.name AS leave_type_name
            FROM leave_mgmt.lv_balances lb
            JOIN leave_mgmt.lv_types lt ON lt.id = lb.leave_type_id
            WHERE lb.employee_id = %s AND lb.year = %s
            ORDER BY lt.name
        """, (employee_id, yr))
        balances = cur.fetchall()

        # Leave requests for the year
        cur.execute("""
            SELECT lr.*, lt.name AS leave_type_name
            FROM leave_mgmt.lv_requests lr
            JOIN leave_mgmt.lv_types lt ON lt.id = lr.leave_type_id
            WHERE lr.employee_id = %s
              AND EXTRACT(YEAR FROM lr.date_from) = %s
            ORDER BY lr.date_from DESC
        """, (employee_id, yr))
        requests = cur.fetchall()

        return {'balances': balances, 'requests': requests, 'year': yr}


# ---------------------------------------------------------------------------
# Retention Alerts
# ---------------------------------------------------------------------------

def get_retention_alerts(company_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT doc.id, doc.document_name, doc.document_type,
                   doc.retention_until,
                   doc.retention_until - CURRENT_DATE AS days_remaining,
                   e.first_name || ' ' || e.last_name AS employee_name
            FROM core.documents doc
            JOIN core.employees e ON e.id = doc.employee_id
            WHERE doc.retention_until IS NOT NULL
              AND doc.is_archived = FALSE
              AND e.company_id = %s
              AND doc.retention_until <= CURRENT_DATE + INTERVAL '90 days'
            ORDER BY doc.retention_until
        """, (company_id,))
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Certificate Request System
# ---------------------------------------------------------------------------

def get_certificate_types():
    with get_cursor() as cur:
        cur.execute("SELECT * FROM dms.certificate_types WHERE is_active = TRUE ORDER BY name")
        return cur.fetchall()


def create_certificate_request(employee_id, cert_type_id, purpose, copies=1):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO dms.certificate_requests
                (employee_id, cert_type_id, purpose, copies_requested)
            VALUES (%s, %s, %s, %s)
            RETURNING id
        """, (employee_id, cert_type_id, purpose, copies))
        return cur.fetchone()


def get_certificate_requests(employee_id=None, status=None):
    conditions = ['1=1']
    params = []
    if employee_id:
        conditions.append('cr.employee_id = %s')
        params.append(employee_id)
    if status:
        conditions.append('cr.status = %s')
        params.append(status)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT cr.*,
                   ct.name AS cert_type_name, ct.code AS cert_code,
                   ct.processing_days,
                   e.first_name || ' ' || e.last_name AS employee_name,
                   d.name AS department_name,
                   u_proc.display_name AS processed_by_name
            FROM dms.certificate_requests cr
            JOIN dms.certificate_types ct ON ct.id = cr.cert_type_id
            JOIN core.employees e ON e.id = cr.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.users u_proc ON u_proc.id = cr.processed_by
            WHERE {' AND '.join(conditions)}
            ORDER BY cr.requested_at DESC
        """, params)
        return cur.fetchall()


def process_certificate_request(request_id, user_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE dms.certificate_requests
            SET status = 'PROCESSING', processed_by = %s, processed_at = NOW()
            WHERE id = %s AND status = 'PENDING'
            RETURNING id
        """, (user_id, request_id))
        return cur.fetchone()


def mark_certificate_ready(request_id, user_id, document_id=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE dms.certificate_requests
            SET status = 'READY', document_id = %s, processed_by = %s, processed_at = NOW()
            WHERE id = %s
            RETURNING id
        """, (document_id, user_id, request_id))
        return cur.fetchone()


def release_certificate(request_id, user_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE dms.certificate_requests
            SET status = 'RELEASED', released_by = %s, released_at = NOW()
            WHERE id = %s AND status IN ('READY', 'PROCESSING')
            RETURNING id
        """, (user_id, request_id))
        return cur.fetchone()


def reject_certificate_request(request_id, user_id, reason):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE dms.certificate_requests
            SET status = 'REJECTED', processed_by = %s, processed_at = NOW(), rejection_reason = %s
            WHERE id = %s
            RETURNING id
        """, (user_id, reason, request_id))
        return cur.fetchone()
