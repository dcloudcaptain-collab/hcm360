"""
Document Service
Handles 201-file document management: upload, retrieve, verify, flag missing/expired.
All files are stored on-disk under UPLOAD_FOLDER/<employee_id>/<filename>.
Metadata is persisted to core.documents.
"""
import os
import uuid
from datetime import date, timedelta
from werkzeug.utils import secure_filename
from flask import current_app
from services.db import get_cursor

ALLOWED_EXTENSIONS = {'pdf', 'jpg', 'jpeg', 'png', 'gif', 'doc', 'docx', 'xls', 'xlsx'}

REQUIRED_DOC_TYPES = [
    'RESUME', 'GOVT_ID', 'SSS', 'PHILHEALTH', 'HDMF', 'TIN',
    'BIRTH_CERT', 'EMPLOYMENT_CONTRACT', 'NBI_CLEARANCE',
]


def _allowed(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


def _employee_folder(employee_id):
    folder = os.path.join(current_app.config['UPLOAD_FOLDER'], str(employee_id))
    os.makedirs(folder, exist_ok=True)
    return folder


# ---------------------------------------------------------------------------
# Upload
# ---------------------------------------------------------------------------

def upload_document(employee_id, doc_type, file_obj, doc_name=None,
                    issue_date=None, expiry_date=None, uploaded_by=None):
    """
    Save an uploaded file to disk and create a core.documents record.
    Returns the new document id or raises ValueError on bad file.
    """
    if not _allowed(file_obj.filename):
        raise ValueError(f"File type not allowed. Allowed: {', '.join(ALLOWED_EXTENSIONS)}")

    original = secure_filename(file_obj.filename)
    ext = original.rsplit('.', 1)[1].lower()
    stored_name = f"{uuid.uuid4().hex}.{ext}"
    folder = _employee_folder(employee_id)
    file_path = os.path.join(folder, stored_name)
    file_obj.save(file_path)
    file_size = os.path.getsize(file_path)

    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO core.documents
                (employee_id, doc_type, doc_name, file_name, file_path,
                 file_size_kb, mime_type, issue_date, expiry_date, uploaded_by)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (
            employee_id,
            doc_type.upper(),
            doc_name or original,
            stored_name,
            file_path,
            round(file_size / 1024, 2),
            file_obj.content_type,
            issue_date,
            expiry_date,
            uploaded_by,
        ))
        return cur.fetchone()['id']


# ---------------------------------------------------------------------------
# Retrieve
# ---------------------------------------------------------------------------

def get_documents(employee_id, doc_type=None):
    """Return all documents for an employee, optionally filtered by type."""
    with get_cursor() as cur:
        if doc_type:
            cur.execute("""
                SELECT id, doc_type, doc_name, file_name, file_path,
                       file_size_kb, issue_date, expiry_date,
                       is_verified, verified_by, verified_at, created_at
                FROM core.documents
                WHERE employee_id = %s AND doc_type = %s
                ORDER BY created_at DESC
            """, (employee_id, doc_type.upper()))
        else:
            cur.execute("""
                SELECT id, doc_type, doc_name, file_name, file_path,
                       file_size_kb, issue_date, expiry_date,
                       is_verified, verified_by, verified_at, created_at
                FROM core.documents
                WHERE employee_id = %s
                ORDER BY doc_type, created_at DESC
            """, (employee_id,))
        return cur.fetchall()


def get_document(doc_id, employee_id=None):
    """Get a single document record. Optionally assert ownership."""
    with get_cursor() as cur:
        if employee_id:
            cur.execute("""
                SELECT * FROM core.documents
                WHERE id = %s AND employee_id = %s
            """, (doc_id, employee_id))
        else:
            cur.execute("SELECT * FROM core.documents WHERE id = %s", (doc_id,))
        return cur.fetchone()


# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------

def verify_document(doc_id, verified_by):
    """Mark a document as verified by HR."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.documents
            SET is_verified = TRUE,
                verified_by = %s,
                verified_at = NOW()
            WHERE id = %s
        """, (verified_by, doc_id))


def unverify_document(doc_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.documents
            SET is_verified = FALSE,
                verified_by = NULL,
                verified_at = NULL
            WHERE id = %s
        """, (doc_id,))


# ---------------------------------------------------------------------------
# Missing / Expiring flags
# ---------------------------------------------------------------------------

def get_missing_documents(employee_id=None):
    """
    Return employees who are missing one or more required document types.
    If employee_id is given, return only that employee's missing types.
    """
    with get_cursor() as cur:
        if employee_id:
            cur.execute("""
                SELECT
                    e.id AS employee_id,
                    e.employee_no,
                    e.full_name,
                    ARRAY(
                        SELECT unnest(ARRAY[%s]::TEXT[])
                        EXCEPT
                        SELECT DISTINCT d.doc_type FROM core.documents d
                        WHERE d.employee_id = e.id
                    ) AS missing_types
                FROM core.v_employees_full e
                WHERE e.id = %s
            """, (REQUIRED_DOC_TYPES, employee_id))
        else:
            cur.execute("""
                SELECT
                    e.id AS employee_id,
                    e.employee_no,
                    e.full_name,
                    d.dept_name,
                    (
                        SELECT COUNT(*) FROM (
                            SELECT unnest(ARRAY[%s]::TEXT[])
                            EXCEPT
                            SELECT DISTINCT doc_type FROM core.documents
                            WHERE employee_id = e.id
                        ) missing
                    ) AS missing_count
                FROM core.v_employees_full e
                WHERE e.is_active = TRUE
                HAVING (
                    SELECT COUNT(*) FROM (
                        SELECT unnest(ARRAY[%s]::TEXT[])
                        EXCEPT
                        SELECT DISTINCT doc_type FROM core.documents
                        WHERE employee_id = e.id
                    ) missing
                ) > 0
                ORDER BY missing_count DESC, e.full_name
            """, (REQUIRED_DOC_TYPES, REQUIRED_DOC_TYPES))
        return cur.fetchall()


def get_expiring_documents(days_ahead=30):
    """Return documents expiring within `days_ahead` days."""
    with get_cursor() as cur:
        cutoff = date.today() + timedelta(days=days_ahead)
        cur.execute("""
            SELECT
                d.id,
                d.doc_type,
                d.doc_name,
                d.expiry_date,
                d.expiry_date - CURRENT_DATE AS days_left,
                e.employee_no,
                e.full_name,
                e.work_email
            FROM core.documents d
            JOIN core.v_employees_full e ON e.id = d.employee_id
            WHERE d.expiry_date IS NOT NULL
              AND d.expiry_date <= %s
              AND d.expiry_date >= CURRENT_DATE
            ORDER BY d.expiry_date
        """, (cutoff,))
        return cur.fetchall()


def get_expired_documents():
    """Return documents that have already expired."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                d.id,
                d.doc_type,
                d.doc_name,
                d.expiry_date,
                CURRENT_DATE - d.expiry_date AS days_overdue,
                e.employee_no,
                e.full_name
            FROM core.documents d
            JOIN core.v_employees_full e ON e.id = d.employee_id
            WHERE d.expiry_date IS NOT NULL
              AND d.expiry_date < CURRENT_DATE
            ORDER BY d.expiry_date
        """)
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Delete
# ---------------------------------------------------------------------------

def delete_document(doc_id, employee_id=None):
    """Remove document record and its file from disk."""
    doc = get_document(doc_id, employee_id)
    if not doc:
        return False
    # Remove from disk
    if doc['file_path'] and os.path.exists(doc['file_path']):
        os.remove(doc['file_path'])
    with get_cursor(commit=True) as cur:
        cur.execute("DELETE FROM core.documents WHERE id = %s", (doc_id,))
    return True


# ---------------------------------------------------------------------------
# Summary for 360 profile
# ---------------------------------------------------------------------------

def get_document_summary(employee_id):
    """
    Return a grouped summary suitable for the employee 360 profile:
    {doc_type: [list of docs], ...}
    Plus flags: missing_types, expiring_soon.
    """
    docs = get_documents(employee_id)
    grouped = {}
    for d in docs:
        grouped.setdefault(d['doc_type'], []).append(d)

    uploaded_types = set(grouped.keys())
    missing_types = [t for t in REQUIRED_DOC_TYPES if t not in uploaded_types]

    expiring_soon = [
        d for docs_list in grouped.values()
        for d in docs_list
        if d['expiry_date'] and (d['expiry_date'] - date.today()).days <= 30
    ]

    return {
        'grouped':       grouped,
        'missing_types': missing_types,
        'expiring_soon': expiring_soon,
        'total_count':   len(docs),
    }
