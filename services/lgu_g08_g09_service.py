"""
G08 — Electronic Signature (Canvas + DocuSign adapter)
G09 — Training Attendance Check-In (with AM/PM shift_period)
"""
import base64
import json
import os
import uuid
from datetime import date as Date, datetime

from flask import current_app

from services.db import get_cursor


# ══════════════════════════════════════════════════════════════════════
# G08 · Electronic Signature
# ══════════════════════════════════════════════════════════════════════
def esig_get_settings(company_id: int):
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM core.esignature_settings WHERE company_id = %s
        """, (company_id,))
        row = cur.fetchone()
        return dict(row) if row else {
            'company_id': company_id,
            'default_mode': 'CANVAS',
            'docusign_integration_key': None,
            'docusign_account_id': None,
            'docusign_base_url': 'https://demo.docusign.net/restapi',
            'docusign_enabled': False,
        }


def esig_save_settings(company_id: int, settings: dict, user_id: int):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO core.esignature_settings
                (company_id, default_mode, docusign_integration_key,
                 docusign_account_id, docusign_base_url, docusign_enabled,
                 updated_by, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, NOW())
            ON CONFLICT (company_id) DO UPDATE SET
                default_mode             = EXCLUDED.default_mode,
                docusign_integration_key = EXCLUDED.docusign_integration_key,
                docusign_account_id      = EXCLUDED.docusign_account_id,
                docusign_base_url        = EXCLUDED.docusign_base_url,
                docusign_enabled         = EXCLUDED.docusign_enabled,
                updated_by               = EXCLUDED.updated_by,
                updated_at               = NOW()
        """, (
            company_id,
            settings.get('default_mode', 'CANVAS'),
            settings.get('docusign_integration_key') or None,
            settings.get('docusign_account_id') or None,
            settings.get('docusign_base_url') or 'https://demo.docusign.net/restapi',
            bool(settings.get('docusign_enabled', False)),
            user_id,
        ))


def esig_capture_canvas(entity_kind: str, entity_id: int, signer_user_id: int,
                         signer_name: str, signer_role: str,
                         signature_image_b64: str,
                         ip_address: str = None, user_agent: str = None,
                         document_id: int = None):
    """
    Capture a canvas signature (base64 PNG) for a given entity.

    Optionally also saves the signature as a PNG file under /uploads/signatures
    and stores a row in core.documents when document_id is None but the caller
    wants a file reference.
    """
    # Strip data URL prefix if present
    b64 = signature_image_b64
    if b64 and b64.startswith('data:'):
        b64 = b64.split(',', 1)[1]

    # Save as PNG file (optional, not strictly required since DB holds base64)
    saved_path = None
    try:
        upload_root = os.environ.get('UPLOAD_FOLDER', '/uploads')
        sig_folder = os.path.join(upload_root, 'signatures')
        os.makedirs(sig_folder, exist_ok=True)
        fname = f'{uuid.uuid4().hex}.png'
        saved_path = os.path.join(sig_folder, fname)
        with open(saved_path, 'wb') as fh:
            fh.write(base64.b64decode(b64))
    except Exception:
        saved_path = None  # non-fatal

    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO core.document_signatures
                (document_id, entity_kind, entity_id, signer_user_id,
                 signer_name, signer_role, signature_mode, signature_image,
                 status, signed_at, ip_address, user_agent)
            VALUES (%s, %s, %s, %s, %s, %s, 'CANVAS', %s,
                    'SIGNED', NOW(), %s, %s)
            RETURNING id
        """, (document_id, entity_kind, entity_id, signer_user_id,
              signer_name, signer_role, b64, ip_address, user_agent))
        sig_id = cur.fetchone()['id']

        # Increment counter on core.documents if linked
        if document_id:
            cur.execute("""
                UPDATE core.documents
                SET current_signatures_count = current_signatures_count + 1,
                    updated_at = NOW()
                WHERE id = %s
            """, (document_id,))

    return {'id': sig_id, 'saved_path': saved_path}


def esig_send_docusign(entity_kind: str, entity_id: int, signer_email: str,
                        signer_name: str, document_bytes: bytes = None,
                        subject: str = 'Please sign'):
    """
    Stub adapter for DocuSign. Returns a mock envelope id.
    In production, this would POST to /envelopes on the DocuSign REST API
    with the JWT-signed bearer token. Here we record the intent and
    return a placeholder so UI/webhook wiring can be exercised end-to-end.
    """
    envelope_id = f'ds-stub-{uuid.uuid4().hex[:12]}'
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO core.document_signatures
                (entity_kind, entity_id, signer_name, signer_role,
                 signature_mode, docusign_envelope_id, status, notes)
            VALUES (%s, %s, %s, %s, 'DOCUSIGN', %s, 'PENDING',
                    %s)
            RETURNING id
        """, (entity_kind, entity_id, signer_name,
              'External Signer', envelope_id,
              f'Subject: {subject}; email: {signer_email}'))
        sig_id = cur.fetchone()['id']
    return {'id': sig_id, 'envelope_id': envelope_id,
            'next_url': f'about:blank#docusign-stub-{envelope_id}'}


def esig_handle_docusign_webhook(envelope_id: str, status: str):
    """Called by DocuSign webhook to update our local state."""
    mapped = {'completed': 'SIGNED', 'declined': 'DECLINED',
              'voided': 'CANCELLED', 'expired': 'EXPIRED'}
    new_status = mapped.get(status.lower(), 'PENDING')
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.document_signatures
            SET status = %s,
                signed_at = CASE WHEN %s = 'SIGNED' THEN NOW()
                                 ELSE signed_at END
            WHERE docusign_envelope_id = %s
            RETURNING id, entity_kind, entity_id
        """, (new_status, new_status, envelope_id))
        return cur.fetchone()


def esig_list_for_entity(entity_kind: str, entity_id: int):
    with get_cursor() as cur:
        cur.execute("""
            SELECT id, signer_name, signer_role, signature_mode, status,
                   signed_at, docusign_envelope_id, signature_image, notes
            FROM core.document_signatures
            WHERE entity_kind = %s AND entity_id = %s
            ORDER BY created_at DESC
        """, (entity_kind, entity_id))
        return cur.fetchall()


def esig_list_recent(company_id: int, limit: int = 100):
    with get_cursor() as cur:
        cur.execute("""
            SELECT s.id, s.entity_kind, s.entity_id, s.signer_name,
                   s.signer_role, s.signature_mode, s.status, s.signed_at,
                   s.created_at
            FROM core.document_signatures s
            LEFT JOIN core.employees e ON e.id = s.signer_employee_id
            LEFT JOIN core.users u     ON u.id = s.signer_user_id
            WHERE (e.company_id = %s OR e.company_id IS NULL
                   OR u.company_id = %s)
            ORDER BY s.created_at DESC
            LIMIT %s
        """, (company_id, company_id, limit))
        return cur.fetchall()


# ══════════════════════════════════════════════════════════════════════
# G09 · Training Attendance Check-In
# ══════════════════════════════════════════════════════════════════════
def training_session_info(session_id: int):
    with get_cursor() as cur:
        cur.execute("""
            SELECT s.id, s.program_id, s.session_date, s.session_end,
                   s.venue, s.facilitator, s.status,
                   p.title AS program_title, p.category
            FROM learning.lrn_sessions s
            JOIN learning.lrn_programs p ON p.id = s.program_id
            WHERE s.id = %s
        """, (session_id,))
        return cur.fetchone()


def training_find_enrollment(employee_id: int, session_id: int):
    with get_cursor() as cur:
        cur.execute("""
            SELECT id FROM learning.lrn_enrollments
            WHERE employee_id = %s AND session_id = %s
            LIMIT 1
        """, (employee_id, session_id))
        row = cur.fetchone()
        return row['id'] if row else None


def training_checkin(enrollment_id: int, employee_id: int,
                      session_id: int, payload: dict,
                      ip_address: str = None):
    """
    G09 mobile check-in for training session with AM/PM shift.

    payload: {
      latitude, longitude, accuracy_m, shift_period ('AM'|'PM'),
      device_id, photo_b64 (optional)
    }
    """
    shift = payload.get('shift_period')
    if shift not in ('AM', 'PM'):
        return {'ok': False, 'message': 'shift_period must be AM or PM.'}

    accuracy = payload.get('accuracy_m')
    is_valid = True
    reason = None
    if accuracy and float(accuracy) > 500:
        is_valid = False
        reason = f'GPS accuracy too low: {accuracy}m'

    # Optional photo
    photo_path = None
    if payload.get('photo_b64'):
        try:
            b64 = payload['photo_b64']
            if b64.startswith('data:'):
                b64 = b64.split(',', 1)[1]
            upload_root = os.environ.get('UPLOAD_FOLDER', '/uploads')
            ph_dir = os.path.join(upload_root, 'training_attendance')
            os.makedirs(ph_dir, exist_ok=True)
            fname = f'{uuid.uuid4().hex}.jpg'
            photo_path = os.path.join(ph_dir, fname)
            with open(photo_path, 'wb') as fh:
                fh.write(base64.b64decode(b64))
        except Exception:
            photo_path = None

    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO learning.lrn_attendance_logs
                (enrollment_id, employee_id, session_id, checked_in_at,
                 checkin_lat, checkin_lng, checkin_accuracy_m,
                 device_id, ip_address, photo_path,
                 is_valid, invalidated_reason,
                 shift_period, session_date)
            VALUES (%s, %s, %s, NOW(), %s, %s, %s, %s, %s, %s, %s, %s, %s, CURRENT_DATE)
            RETURNING id, checked_in_at
        """, (enrollment_id, employee_id, session_id,
              payload.get('latitude'), payload.get('longitude'), accuracy,
              payload.get('device_id'), ip_address, photo_path,
              is_valid, reason, shift))
        row = cur.fetchone()

    return {
        'ok': is_valid,
        'id': row['id'],
        'checked_in_at': row['checked_in_at'].isoformat(),
        'shift_period': shift,
        'photo_path': photo_path,
        'message': 'Attendance recorded.' if is_valid else reason,
    }


def training_session_attendance(session_id: int):
    with get_cursor() as cur:
        cur.execute("""
            SELECT al.id, al.employee_id, al.shift_period,
                   al.checked_in_at, al.checkin_lat, al.checkin_lng,
                   al.checkin_accuracy_m, al.is_valid, al.photo_path,
                   e.employee_no,
                   CONCAT_WS(' ', e.first_name, e.last_name) AS full_name
            FROM learning.lrn_attendance_logs al
            JOIN core.employees e ON e.id = al.employee_id
            WHERE al.session_id = %s
            ORDER BY al.checked_in_at DESC
        """, (session_id,))
        return cur.fetchall()
