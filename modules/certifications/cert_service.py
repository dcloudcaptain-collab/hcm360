"""Certifications Service — tracking, renewal, compliance."""
from services.db import get_cursor


# ---------------------------------------------------------------------------
# Certifications CRUD
# ---------------------------------------------------------------------------

def get_certifications(employee_id=None, status=None):
    """List certifications with employee name, optionally filtered."""
    conditions = []
    params = []
    if employee_id:
        conditions.append('ec.employee_id = %s')
        params.append(employee_id)
    if status:
        conditions.append('ec.status = %s')
        params.append(status)
    where = 'WHERE ' + ' AND '.join(conditions) if conditions else ''
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT ec.*,
                   emp.first_name || ' ' || emp.last_name AS employee_name,
                   emp.employee_no,
                   CASE WHEN ec.expiry_date < CURRENT_DATE THEN 'EXPIRED'
                        WHEN ec.expiry_date < CURRENT_DATE + INTERVAL '90 days' THEN 'EXPIRING'
                        ELSE 'ACTIVE' END AS computed_status,
                   (ec.expiry_date - CURRENT_DATE) AS days_until_expiry
            FROM core.employee_certifications ec
            JOIN core.employees emp ON emp.id = ec.employee_id
            {where}
            ORDER BY ec.expiry_date ASC NULLS LAST
        """, params)
        return cur.fetchall()


def get_expiring_soon(days=90):
    """Return certifications expiring within N days."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT ec.*,
                   emp.first_name || ' ' || emp.last_name AS employee_name,
                   emp.employee_no,
                   (ec.expiry_date - CURRENT_DATE) AS days_until_expiry
            FROM core.employee_certifications ec
            JOIN core.employees emp ON emp.id = ec.employee_id
            WHERE ec.expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + (%s || ' days')::INTERVAL
              AND ec.status != 'REVOKED'
            ORDER BY ec.expiry_date ASC
        """, (str(days),))
        return cur.fetchall()


def add_certification(employee_id, cert_name, cert_type, issuing_body, cert_number,
                      issued_date, expiry_date, is_required=False, document_path=None):
    """Insert a new certification."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO core.employee_certifications
                (employee_id, cert_name, cert_type, issuing_body, cert_number,
                 issued_date, expiry_date, is_required, document_path, status)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,'ACTIVE')
            RETURNING id
        """, (employee_id, cert_name, cert_type, issuing_body, cert_number,
              issued_date, expiry_date, is_required, document_path))
        return cur.fetchone()['id']


def renew_certification(cert_id, new_expiry_date):
    """Renew a certification with a new expiry date."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.employee_certifications
            SET status = 'RENEWED', expiry_date = %s, updated_at = NOW()
            WHERE id = %s
        """, (new_expiry_date, cert_id))


def get_employee_certs(employee_id):
    """Return employee certs grouped by type with expiry alerts."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT ec.*,
                   CASE WHEN ec.expiry_date < CURRENT_DATE THEN 'EXPIRED'
                        WHEN ec.expiry_date < CURRENT_DATE + INTERVAL '30 days' THEN 'EXPIRING_30'
                        WHEN ec.expiry_date < CURRENT_DATE + INTERVAL '90 days' THEN 'EXPIRING_90'
                        ELSE 'ACTIVE' END AS expiry_status,
                   (ec.expiry_date - CURRENT_DATE) AS days_until_expiry
            FROM core.employee_certifications ec
            WHERE ec.employee_id = %s
            ORDER BY ec.cert_type, ec.expiry_date ASC NULLS LAST
        """, (employee_id,))
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Compliance Dashboard
# ---------------------------------------------------------------------------

def get_compliance_dashboard():
    """Stats: total active, expiring 30/60/90 days, expired, required missing."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                (SELECT COUNT(*) FROM core.employee_certifications
                 WHERE status IN ('ACTIVE','RENEWED') AND (expiry_date IS NULL OR expiry_date >= CURRENT_DATE)) AS active_certs,
                (SELECT COUNT(*) FROM core.employee_certifications
                 WHERE expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days') AS expiring_30,
                (SELECT COUNT(*) FROM core.employee_certifications
                 WHERE expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '60 days') AS expiring_60,
                (SELECT COUNT(*) FROM core.employee_certifications
                 WHERE expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '90 days') AS expiring_90,
                (SELECT COUNT(*) FROM core.employee_certifications
                 WHERE expiry_date < CURRENT_DATE AND status != 'REVOKED') AS expired_certs,
                (SELECT COUNT(*) FROM core.employee_certifications
                 WHERE is_required = TRUE AND (expiry_date < CURRENT_DATE OR status = 'REVOKED')) AS required_missing
        """)
        return cur.fetchone()


def get_required_vs_completed(employee_id=None):
    """Check which required certs employees have vs missing."""
    conditions = []
    params = []
    if employee_id:
        conditions.append('emp.id = %s')
        params.append(employee_id)
    where = 'WHERE ' + ' AND '.join(conditions) if conditions else ''
    with get_cursor() as cur:
        # Get all required cert types
        cur.execute("""
            SELECT DISTINCT cert_type FROM core.employee_certifications WHERE is_required = TRUE
        """)
        required_types = [r['cert_type'] for r in cur.fetchall()]

        # Get employees and their certs
        cur.execute(f"""
            SELECT emp.id AS employee_id,
                   emp.first_name || ' ' || emp.last_name AS employee_name,
                   emp.employee_no,
                   ec.cert_type,
                   ec.cert_name,
                   ec.status,
                   ec.expiry_date,
                   CASE WHEN ec.expiry_date < CURRENT_DATE THEN 'EXPIRED'
                        WHEN ec.expiry_date < CURRENT_DATE + INTERVAL '90 days' THEN 'EXPIRING'
                        ELSE 'ACTIVE' END AS cert_status
            FROM core.employees emp
            LEFT JOIN core.employee_certifications ec
                 ON ec.employee_id = emp.id AND ec.is_required = TRUE
            {where}
            ORDER BY emp.last_name, ec.cert_type
        """, params)
        rows = cur.fetchall()

    return required_types, rows
