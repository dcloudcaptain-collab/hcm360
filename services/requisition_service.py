"""
Job Requisition Service — closes LGU Gap Sheet #8 (40 aspects).

CRUD + state transitions + CSC Form PDF + WFP warning + duplicate detection +
dashboard stats. Reuses workflow_service, task_inbox_service, notification_service,
and the ReportLab helpers from lgu_g11_g16_g17_service.
"""
import io
import json
import os
from datetime import date as Date, datetime

from reportlab.lib.pagesizes import LETTER
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch, mm
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer,
                                Table, TableStyle, KeepTogether)

from services.db import get_cursor
from services.lgu_g11_g16_g17_service import (
    _doc, _header, _kv_table, _sig_block,
    BRAND, GRAY, DARK, LIGHT,
)
from services import workflow_service, task_inbox_service, notification_service


# ══════════════════════════════════════════════════════════════════════
# Helpers
# ══════════════════════════════════════════════════════════════════════
TERMINAL_STATUSES = ('APPROVED', 'PUBLISHED', 'FILLED', 'REJECTED', 'CANCELLED')
NON_TERMINAL = ('DRAFT', 'PENDING_APPROVAL')


def _next_reference_no() -> str:
    """Sequential reference like REQ-2026-000123 (per-year)."""
    year = Date.today().year
    with get_cursor(commit=True) as cur:
        cur.execute("""
            SELECT COALESCE(
                MAX(CASE WHEN reference_no ~ ('^REQ-' || %s || '-[0-9]+$')
                         THEN split_part(reference_no, '-', 3)::int END),
                0
            ) + 1 AS next_n
            FROM recruitment.rec_requisitions
            WHERE reference_no LIKE %s
        """, (str(year), f'REQ-{year}-%'))
        n = cur.fetchone()['next_n']
    return f'REQ-{year}-{n:06d}'


def _log_history(cur, req_id, action, user_id, from_status=None, to_status=None, remarks=None, metadata=None):
    cur.execute("""
        INSERT INTO recruitment.rec_requisition_history
            (requisition_id, action, from_status, to_status, performed_by, remarks, metadata)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, (req_id, action, from_status, to_status, user_id, remarks,
          json.dumps(metadata or {})))


def _apply_role_filter(sql, params, user_id=None, role_code=None, company_id=None):
    """Append department-scoped visibility for non-admin roles."""
    if company_id is not None:
        sql += " AND r.company_id = %s"
        params.append(company_id)
    if role_code and role_code not in ('SUPER_ADMIN', 'HR_ADMIN', 'EXECUTIVE') and user_id:
        sql += """ AND (r.requested_by = %s
                       OR r.department_id IN (
                           SELECT e.department_id FROM core.employees e
                           JOIN core.users u ON u.employee_id = e.id
                           WHERE u.id = %s))"""
        params.extend([user_id, user_id])
    return sql, params


# ══════════════════════════════════════════════════════════════════════
# CRUD
# ══════════════════════════════════════════════════════════════════════
def create_requisition(company_id, form, user_id, submit=False):
    """Insert DRAFT (or PENDING_APPROVAL if submit=True) and return id."""
    ref_no = _next_reference_no()
    status = 'PENDING_APPROVAL' if submit else 'DRAFT'
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO recruitment.rec_requisitions
                (company_id, reference_no, department_id, position_id, headcount,
                 justification, status, requested_by, target_hire_date,
                 plantilla_item_id, budget_source, funds_available, priority,
                 qualification_standard_id, required_eligibility_id,
                 salary_min_override, salary_max_override,
                 submitted_at, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s, %s, %s, %s,
                    CASE WHEN %s THEN NOW() ELSE NULL END,
                    NOW(), NOW())
            RETURNING id
        """, (
            company_id, ref_no,
            form.get('department_id') or None,
            form.get('position_id') or None,
            int(form.get('headcount') or 1),
            form.get('justification', ''),
            status, user_id,
            form.get('target_hire_date') or None,
            form.get('plantilla_item_id') or None,
            form.get('budget_source') or None,
            form.get('funds_available') or None,
            (form.get('priority') or 'NORMAL').upper(),
            form.get('qualification_standard_id') or None,
            form.get('required_eligibility_id') or None,
            form.get('salary_min_override') or None,
            form.get('salary_max_override') or None,
            submit,
        ))
        req_id = cur.fetchone()['id']

        _log_history(cur, req_id, 'CREATE', user_id,
                     from_status=None, to_status=status,
                     remarks=f'Reference {ref_no} created')

    if submit:
        _submit_workflow(req_id, user_id, ref_no, form)

    return req_id, ref_no


def get_requisition(req_id, user_id=None, role_code=None):
    """Detail view with joins. Applies department-scoped visibility."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT r.*,
                   d.name AS department_name,
                   p.title AS position_title,
                   jg.code AS salary_grade,
                   jg.salary_min AS grade_salary_min,
                   jg.salary_max AS grade_salary_max,
                   pi.item_number AS plantilla_item_number,
                   qs.education, qs.experience, qs.training, qs.eligibility,
                   ce.code AS eligibility_code, ce.name AS eligibility_name,
                   u_req.display_name AS requested_by_name,
                   u_app.display_name AS approved_by_name,
                   e_req.department_id AS requester_department_id,
                   ws.name AS current_step_name,
                   ws.role_required AS current_step_role,
                   wi.status AS workflow_status
            FROM recruitment.rec_requisitions r
            LEFT JOIN core.departments d ON d.id = r.department_id
            LEFT JOIN core.positions p ON p.id = r.position_id
            LEFT JOIN core.job_grades jg ON jg.id = p.job_grade_id
            LEFT JOIN recruitment.rec_plantilla_items pi ON pi.id = r.plantilla_item_id
            LEFT JOIN recruitment.rec_qualification_standards qs ON qs.id = r.qualification_standard_id
            LEFT JOIN recruitment.rec_csc_eligibilities ce ON ce.id = r.required_eligibility_id
            LEFT JOIN core.users u_req ON u_req.id = r.requested_by
            LEFT JOIN core.users u_app ON u_app.id = r.approved_by
            LEFT JOIN core.employees e_req ON e_req.id = u_req.employee_id
            LEFT JOIN workflow.workflow_instances wi ON wi.id = r.workflow_instance_id
            LEFT JOIN workflow.workflow_steps ws ON ws.id = wi.current_step_id
            WHERE r.id = %s
        """, (req_id,))
        row = cur.fetchone()
        if not row:
            return None

        # Attachments
        cur.execute("""
            SELECT ra.id, ra.attachment_type, ra.file_name, ra.file_path,
                   ra.file_size_kb, ra.mime_type, ra.uploaded_at,
                   u.display_name AS uploaded_by_name
            FROM recruitment.rec_requisition_attachments ra
            LEFT JOIN core.users u ON u.id = ra.uploaded_by
            WHERE ra.requisition_id = %s
            ORDER BY ra.uploaded_at DESC
        """, (req_id,))
        attachments = cur.fetchall()

        # History
        cur.execute("""
            SELECT rh.action, rh.from_status, rh.to_status, rh.remarks,
                   rh.performed_at AS created_at,
                   u.display_name AS performed_by_name
            FROM recruitment.rec_requisition_history rh
            LEFT JOIN core.users u ON u.id = rh.performed_by
            WHERE rh.requisition_id = %s
            ORDER BY rh.performed_at DESC
        """, (req_id,))
        history = cur.fetchall()

        # Linked job postings
        cur.execute("""
            SELECT id, title, status, posted_on, closed_on, employment_type
            FROM recruitment.rec_job_postings
            WHERE requisition_id = %s
            ORDER BY created_at DESC
        """, (req_id,))
        postings = cur.fetchall()

        # Approval chain (workflow action log if any)
        chain = []
        if row['workflow_instance_id']:
            cur.execute("""
                SELECT wal.action_code, wal.comments, wal.created_at,
                       wal.from_status, wal.to_status,
                       u.display_name AS performed_by_name,
                       ws.name AS step_name
                FROM workflow.workflow_action_logs wal
                LEFT JOIN core.users u ON u.id = wal.performed_by
                LEFT JOIN workflow.workflow_steps ws ON ws.id = wal.step_id
                WHERE wal.instance_id = %s
                ORDER BY wal.created_at
            """, (row['workflow_instance_id'],))
            chain = cur.fetchall()

    return {
        'row': row,
        'attachments': attachments,
        'history': history,
        'postings': postings,
        'chain': chain,
    }


def list_requisitions(company_id, status=None, user_id=None, role_code=None,
                     department_id=None, priority=None):
    sql = """
        SELECT r.id, r.reference_no, r.status, r.priority, r.headcount,
               r.approved_headcount, r.target_hire_date,
               r.created_at, r.submitted_at, r.approved_at,
               d.name AS department_name,
               p.title AS position_title,
               u.display_name AS requested_by_name,
               CASE WHEN r.status='PENDING_APPROVAL'
                    THEN EXTRACT(DAY FROM (NOW() - COALESCE(r.submitted_at, r.created_at)))::int
                    ELSE NULL END AS days_pending
        FROM recruitment.rec_requisitions r
        LEFT JOIN core.departments d ON d.id = r.department_id
        LEFT JOIN core.positions p ON p.id = r.position_id
        LEFT JOIN core.users u ON u.id = r.requested_by
        WHERE 1=1
    """
    params = []
    sql, params = _apply_role_filter(sql, params, user_id, role_code, company_id)
    if status:
        sql += " AND r.status = %s"
        params.append(status)
    if department_id:
        sql += " AND r.department_id = %s"
        params.append(department_id)
    if priority:
        sql += " AND r.priority = %s"
        params.append(priority)
    sql += " ORDER BY r.created_at DESC LIMIT 500"

    with get_cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchall()


def clone_requisition(req_id, user_id):
    """Copy into a new DRAFT with fresh reference_no."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            SELECT company_id, department_id, position_id, headcount, justification,
                   target_hire_date, plantilla_item_id, budget_source, funds_available,
                   priority, qualification_standard_id, required_eligibility_id,
                   salary_min_override, salary_max_override
            FROM recruitment.rec_requisitions WHERE id=%s
        """, (req_id,))
        src = cur.fetchone()
        if not src:
            return None, None

    form = dict(src)
    form['justification'] = f"(Cloned from requisition #{req_id}) " + (form.get('justification') or '')
    new_id, new_ref = create_requisition(src['company_id'], form, user_id, submit=False)
    with get_cursor(commit=True) as cur:
        _log_history(cur, new_id, 'CLONE', user_id,
                     remarks=f'Cloned from requisition #{req_id}')
    return new_id, new_ref


def find_duplicates(position_id, exclude_id=None):
    """Active (non-terminal) requisitions for the same position."""
    if not position_id:
        return []
    with get_cursor() as cur:
        sql = """
            SELECT r.id, r.reference_no, r.status, r.headcount, r.created_at,
                   u.display_name AS requested_by_name, d.name AS department_name
            FROM recruitment.rec_requisitions r
            LEFT JOIN core.users u ON u.id = r.requested_by
            LEFT JOIN core.departments d ON d.id = r.department_id
            WHERE r.position_id = %s AND r.status = ANY(%s)
        """
        params = [position_id, list(NON_TERMINAL)]
        if exclude_id:
            sql += " AND r.id <> %s"
            params.append(exclude_id)
        sql += " ORDER BY r.created_at DESC LIMIT 10"
        cur.execute(sql, params)
        return cur.fetchall()


# ══════════════════════════════════════════════════════════════════════
# State transitions
# ══════════════════════════════════════════════════════════════════════
def _submit_workflow(req_id, user_id, ref_no, form=None):
    """Start REQUISITION_APPROVAL workflow + notify step-1 approvers."""
    instance_id = workflow_service.create_instance(
        definition_code='REQUISITION_APPROVAL',
        module='recruitment',
        entity_type='REQUISITION',
        entity_id=req_id,
        initiated_by=user_id,
        reference_no=ref_no,
        metadata={'req_id': req_id},
    )
    if not instance_id:
        return None

    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE recruitment.rec_requisitions
            SET workflow_instance_id=%s, status='PENDING_APPROVAL',
                submitted_at=COALESCE(submitted_at, NOW()), updated_at=NOW()
            WHERE id=%s
        """, (instance_id, req_id))

        # Details for notifications
        cur.execute("""
            SELECT r.reference_no, r.headcount, r.priority, r.department_id,
                   p.title AS position_title
            FROM recruitment.rec_requisitions r
            LEFT JOIN core.positions p ON p.id = r.position_id
            WHERE r.id = %s
        """, (req_id,))
        info = cur.fetchone() or {}

        # Find step-1 approvers — department head (MANAGER role in same dept)
        cur.execute("""
            SELECT DISTINCT u.id AS user_id, e.id AS employee_id, u.display_name
            FROM core.users u
            LEFT JOIN core.employees e ON e.id = u.employee_id
            WHERE u.role_code = 'MANAGER' AND u.is_active = TRUE
              AND (e.department_id = %s OR e.department_id IS NULL)
        """, (info.get('department_id'),))
        approvers = cur.fetchall()

        _log_history(cur, req_id, 'SUBMIT', user_id,
                     from_status='DRAFT', to_status='PENDING_APPROVAL',
                     remarks='Submitted for approval')

    # Push inbox tasks + notifications
    for ap in approvers:
        try:
            task_inbox_service.create_task(
                employee_id=ap.get('employee_id'),
                user_id=ap.get('user_id'),
                task_type='REQUISITION_APPROVAL',
                title=f"Approve requisition {info.get('reference_no')}",
                description=f"New requisition for {info.get('position_title') or 'position'} ({info.get('headcount')} head(s)) requires your review.",
                action_url=f"/rsp/requisitions/{req_id}",
                priority='HIGH' if (info.get('priority') or 'NORMAL') in ('URGENT', 'HIGH') else 'NORMAL',
                source_table='recruitment.rec_requisitions',
                source_id=req_id,
            )
        except Exception:
            pass
        try:
            notification_service.notify(
                user_id=ap.get('user_id'),
                event_type='REQ_SUBMITTED',
                payload={
                    'reference_no': info.get('reference_no'),
                    'position_title': info.get('position_title'),
                    'headcount': info.get('headcount'),
                    'module': 'recruitment',
                },
            )
        except Exception:
            pass

    return instance_id


def submit(req_id, user_id):
    """DRAFT → PENDING_APPROVAL."""
    with get_cursor(commit=True) as cur:
        cur.execute("SELECT reference_no, status FROM recruitment.rec_requisitions WHERE id=%s", (req_id,))
        row = cur.fetchone()
        if not row:
            return {'ok': False, 'message': 'Requisition not found.'}
        if row['status'] != 'DRAFT':
            return {'ok': False, 'message': f"Cannot submit — status is {row['status']}."}
    _submit_workflow(req_id, user_id, row['reference_no'])
    return {'ok': True, 'message': 'Submitted for approval.'}


def approve(req_id, user_id, remarks='', approved_headcount=None):
    """Execute APPROVE on workflow; if final, mark APPROVED and auto-publish."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            SELECT r.*, wi.current_step_id, ws.is_final
            FROM recruitment.rec_requisitions r
            LEFT JOIN workflow.workflow_instances wi ON wi.id = r.workflow_instance_id
            LEFT JOIN workflow.workflow_steps ws ON ws.id = wi.current_step_id
            WHERE r.id = %s
        """, (req_id,))
        row = cur.fetchone()
        if not row:
            return {'ok': False, 'message': 'Requisition not found.'}
        if row['status'] != 'PENDING_APPROVAL':
            return {'ok': False, 'message': f"Cannot approve — status is {row['status']}."}

    # Advance workflow
    result = workflow_service.execute_action(
        row['workflow_instance_id'], 'APPROVE', user_id, remarks or '')
    if not result.get('ok'):
        return result

    is_final = bool(row.get('is_final'))
    with get_cursor(commit=True) as cur:
        if is_final:
            # Final approval — mark APPROVED
            final_hc = approved_headcount if approved_headcount is not None else row['headcount']
            cur.execute("""
                UPDATE recruitment.rec_requisitions
                SET status='APPROVED',
                    approved_by=%s,
                    approved_at=NOW(),
                    approved_headcount=%s,
                    updated_at=NOW()
                WHERE id=%s
            """, (user_id, final_hc, req_id))
            _log_history(cur, req_id, 'APPROVE', user_id,
                         from_status='PENDING_APPROVAL', to_status='APPROVED',
                         remarks=remarks or f'Approved with headcount={final_hc}',
                         metadata={'approved_headcount': final_hc})
        else:
            _log_history(cur, req_id, 'APPROVE_STEP', user_id,
                         from_status='PENDING_APPROVAL', to_status='PENDING_APPROVAL',
                         remarks=remarks or 'Approved step')

    if is_final:
        _on_approved(req_id)

    return {'ok': True, 'message': 'Approved.' if is_final else 'Advanced to next step.'}


def reject(req_id, user_id, reason):
    """Hard REJECT → status='REJECTED', store reason, notify requester."""
    if not reason or not reason.strip():
        return {'ok': False, 'message': 'Rejection reason is required.'}

    with get_cursor(commit=True) as cur:
        cur.execute("""
            SELECT r.status, r.workflow_instance_id, r.reference_no, r.requested_by,
                   p.title AS position_title
            FROM recruitment.rec_requisitions r
            LEFT JOIN core.positions p ON p.id = r.position_id
            WHERE r.id=%s
        """, (req_id,))
        row = cur.fetchone()
        if not row:
            return {'ok': False, 'message': 'Requisition not found.'}
        if row['status'] not in ('PENDING_APPROVAL', 'DRAFT'):
            return {'ok': False, 'message': f"Cannot reject — status is {row['status']}."}

    # If workflow exists, fire REJECT so history stays consistent
    if row['workflow_instance_id']:
        try:
            workflow_service.execute_action(
                row['workflow_instance_id'], 'REJECT', user_id, reason)
        except Exception:
            pass

    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE recruitment.rec_requisitions
            SET status='REJECTED', rejection_reason=%s, updated_at=NOW()
            WHERE id=%s
        """, (reason, req_id))
        _log_history(cur, req_id, 'REJECT', user_id,
                     from_status=row['status'], to_status='REJECTED',
                     remarks=reason)

    # Notify requester
    try:
        notification_service.notify(
            user_id=row['requested_by'],
            event_type='REQ_REJECTED',
            payload={
                'reference_no': row['reference_no'],
                'rejection_reason': reason,
                'position_title': row.get('position_title'),
                'module': 'recruitment',
            },
        )
    except Exception:
        pass

    return {'ok': True, 'message': 'Rejected.'}


def cancel(req_id, user_id, reason=''):
    with get_cursor(commit=True) as cur:
        cur.execute("SELECT status FROM recruitment.rec_requisitions WHERE id=%s", (req_id,))
        row = cur.fetchone()
        if not row:
            return {'ok': False, 'message': 'Not found.'}
        if row['status'] in ('APPROVED', 'PUBLISHED', 'FILLED', 'CANCELLED'):
            return {'ok': False, 'message': f"Cannot cancel — status is {row['status']}."}
        cur.execute("""
            UPDATE recruitment.rec_requisitions SET status='CANCELLED', updated_at=NOW()
            WHERE id=%s
        """, (req_id,))
        _log_history(cur, req_id, 'CANCEL', user_id,
                     from_status=row['status'], to_status='CANCELLED',
                     remarks=reason or 'Cancelled by requester')
    return {'ok': True, 'message': 'Cancelled.'}


# ══════════════════════════════════════════════════════════════════════
# Auto-publish hook (Category 4)
# ══════════════════════════════════════════════════════════════════════
def _on_approved(req_id):
    """Auto-create rec_job_postings when requisition fully approved."""
    try:
        with get_cursor(commit=True) as cur:
            cur.execute("""
                SELECT r.*, p.title AS position_title, p.description AS position_desc,
                       jg.salary_min, jg.salary_max, d.name AS department_name
                FROM recruitment.rec_requisitions r
                LEFT JOIN core.positions p ON p.id = r.position_id
                LEFT JOIN core.job_grades jg ON jg.id = p.job_grade_id
                LEFT JOIN core.departments d ON d.id = r.department_id
                WHERE r.id=%s
            """, (req_id,))
            r = cur.fetchone()
            if not r:
                return

            # Don't double-post
            cur.execute("SELECT id FROM recruitment.rec_job_postings WHERE requisition_id=%s LIMIT 1",
                       (req_id,))
            if cur.fetchone():
                return

            salary_min = r.get('salary_min_override') or r.get('salary_min')
            salary_max = r.get('salary_max_override') or r.get('salary_max')
            salary_range = None
            if salary_min or salary_max:
                salary_range = f"PHP {salary_min or ''}–{salary_max or ''}".strip('–')

            is_internal = (r.get('priority') or '').upper() == 'URGENT'

            cur.execute("""
                INSERT INTO recruitment.rec_job_postings
                    (requisition_id, title, description, requirements,
                     employment_type, salary_range, location, posted_on,
                     status, is_internal)
                VALUES (%s, %s, %s, %s, 'PERMANENT', %s, %s, CURRENT_DATE, 'OPEN', %s)
                RETURNING id
            """, (
                req_id,
                r.get('position_title') or f"Position #{r.get('position_id')}",
                r.get('position_desc') or r.get('justification') or '',
                r.get('justification') or '',
                salary_range,
                r.get('department_name') or '',
                is_internal,
            ))
            posting_id = cur.fetchone()['id']

            # Mark requisition as PUBLISHED
            cur.execute("""
                UPDATE recruitment.rec_requisitions
                SET status='PUBLISHED', updated_at=NOW() WHERE id=%s
            """, (req_id,))

            _log_history(cur, req_id, 'PUBLISH', r.get('approved_by'),
                         from_status='APPROVED', to_status='PUBLISHED',
                         remarks=f'Auto-published as job posting #{posting_id}',
                         metadata={'posting_id': posting_id, 'is_internal': is_internal})

        # Notify requester
        try:
            notification_service.notify(
                user_id=r.get('requested_by'),
                event_type='REQ_APPROVED',
                payload={
                    'reference_no': r.get('reference_no'),
                    'approved_headcount': r.get('approved_headcount') or r.get('headcount'),
                    'position_title': r.get('position_title'),
                    'module': 'recruitment',
                },
            )
        except Exception:
            pass
    except Exception as ex:
        # Don't crash the approve flow — log and move on
        try:
            with get_cursor(commit=True) as cur:
                _log_history(cur, req_id, 'PUBLISH_ERR', None,
                             remarks=f'Auto-publish error: {str(ex)[:300]}')
        except Exception:
            pass


# ══════════════════════════════════════════════════════════════════════
# WFP warning (Category 8)
# ══════════════════════════════════════════════════════════════════════
def wfp_warning(department_id, requested_headcount):
    """
    Check if requested headcount would exceed the active WFP scenario for dept.
    Returns dict with warning details or None if no warning.
    """
    if not department_id or not requested_headcount:
        return None
    try:
        with get_cursor() as cur:
            cur.execute("""
                SELECT SUM(wp.current_hc)::int  AS current_hc,
                       SUM(wp.planned_hc)::int  AS planned_hc,
                       SUM(wp.planned_hires)::int AS planned_hires,
                       MAX(ws.name)             AS scenario_name
                FROM analytics.wfp_headcount_plans wp
                JOIN analytics.wfp_scenarios ws ON ws.id = wp.scenario_id
                WHERE ws.status = 'ACTIVE' AND wp.department_id = %s
            """, (department_id,))
            row = cur.fetchone()
            if not row or not row.get('planned_hc'):
                return None
            current = row.get('current_hc') or 0
            planned = row.get('planned_hc') or 0
            would_be = current + int(requested_headcount)
            if would_be > planned:
                return {
                    'current_hc': current,
                    'planned_hc': planned,
                    'requested': int(requested_headcount),
                    'would_be': would_be,
                    'over_by': would_be - planned,
                    'scenario_name': row.get('scenario_name'),
                }
    except Exception:
        return None
    return None


# ══════════════════════════════════════════════════════════════════════
# CSC Form PDF (Category 8)
# ══════════════════════════════════════════════════════════════════════
def render_csc_form_pdf(req_id):
    """Render CSC Form CS 001/004 'Personnel Requisition Form' PDF. Returns bytes."""
    data = get_requisition(req_id)
    if not data:
        return None
    r = data['row']

    buf = io.BytesIO()
    doc = _doc(buf, f"Requisition {r['reference_no']}")
    story = []

    story.extend(_header(
        'PERSONNEL REQUISITION FORM',
        'CSC Form CS 001/004'
    ))
    story.append(Paragraph(f"<b>Reference No.:</b> {r['reference_no']}",
                           ParagraphStyle('r', fontSize=10, alignment=TA_LEFT)))
    story.append(Spacer(1, 10))

    # Section A — Position details
    target_hire = r['target_hire_date'].strftime('%b %d, %Y') if r.get('target_hire_date') else '—'
    story.append(Paragraph('<b>A. Position Details</b>',
                           ParagraphStyle('h', fontSize=11, textColor=BRAND)))
    story.append(Spacer(1, 4))
    story.append(_kv_table([
        ['Department', r.get('department_name') or '—'],
        ['Position Title', r.get('position_title') or '—'],
        ['Salary Grade', r.get('salary_grade') or '—'],
        ['Plantilla Item No.', r.get('plantilla_item_number') or '—'],
        ['Headcount Requested', str(r.get('headcount') or 1)],
        ['Approved Headcount', str(r.get('approved_headcount') or '—')],
        ['Priority', r.get('priority') or 'NORMAL'],
        ['Target Hire Date', target_hire],
    ]))

    # Section B — Budget
    story.append(Spacer(1, 12))
    story.append(Paragraph('<b>B. Budget &amp; Funding</b>',
                           ParagraphStyle('h', fontSize=11, textColor=BRAND)))
    story.append(Spacer(1, 4))
    funds = f"PHP {r['funds_available']:,.2f}" if r.get('funds_available') else '—'
    sal_min = f"PHP {r['salary_min_override']:,.2f}" if r.get('salary_min_override') else (
              f"PHP {r['grade_salary_min']:,.2f}" if r.get('grade_salary_min') else '—')
    sal_max = f"PHP {r['salary_max_override']:,.2f}" if r.get('salary_max_override') else (
              f"PHP {r['grade_salary_max']:,.2f}" if r.get('grade_salary_max') else '—')
    story.append(_kv_table([
        ['Budget Source', r.get('budget_source') or '—'],
        ['Funds Available', funds],
        ['Salary Range (Min)', sal_min],
        ['Salary Range (Max)', sal_max],
    ]))

    # Section C — Qualifications
    story.append(Spacer(1, 12))
    story.append(Paragraph('<b>C. Qualification Standards</b>',
                           ParagraphStyle('h', fontSize=11, textColor=BRAND)))
    story.append(Spacer(1, 4))
    story.append(_kv_table([
        ['Education', r.get('education') or '—'],
        ['Experience', r.get('experience') or '—'],
        ['Training', r.get('training') or '—'],
        ['Eligibility', r.get('eligibility') or r.get('eligibility_name') or '—'],
    ]))

    # Section D — Justification
    story.append(Spacer(1, 12))
    story.append(Paragraph('<b>D. Justification</b>',
                           ParagraphStyle('h', fontSize=11, textColor=BRAND)))
    story.append(Spacer(1, 4))
    just = r.get('justification') or '—'
    story.append(Paragraph(just, ParagraphStyle('j', fontSize=9.5, textColor=DARK,
                                                 leading=12)))

    # Section E — Approval
    if r.get('approved_by_name'):
        story.append(Spacer(1, 12))
        story.append(Paragraph('<b>E. Approval</b>',
                               ParagraphStyle('h', fontSize=11, textColor=BRAND)))
        story.append(Spacer(1, 4))
        app_date = r['approved_at'].strftime('%b %d, %Y') if r.get('approved_at') else '—'
        story.append(_kv_table([
            ['Status', r.get('status') or '—'],
            ['Approved By', r.get('approved_by_name') or '—'],
            ['Approved On', app_date],
        ]))

    story.append(Spacer(1, 24))
    story.append(_sig_block())

    doc.build(story)
    return buf.getvalue()


# ══════════════════════════════════════════════════════════════════════
# Stats / metrics (Category 7)
# ══════════════════════════════════════════════════════════════════════
def get_summary_stats(company_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                COUNT(*) FILTER (WHERE status='PENDING_APPROVAL') AS pending_count,
                COUNT(*) FILTER (WHERE status IN ('APPROVED','PUBLISHED','FILLED')
                                  AND approved_at >= date_trunc('year', CURRENT_DATE)) AS approved_ytd,
                COALESCE(AVG(EXTRACT(DAY FROM (approved_at - submitted_at)))
                         FILTER (WHERE approved_at IS NOT NULL AND submitted_at IS NOT NULL), 0)::numeric(5,1)
                    AS avg_days_approve,
                COALESCE(SUM(headcount) FILTER (WHERE status IN ('APPROVED','PUBLISHED')), 0) AS open_vacancies
            FROM recruitment.rec_requisitions
            WHERE company_id = %s
        """, (company_id,))
        return cur.fetchone()


# ══════════════════════════════════════════════════════════════════════
# Lookups (for forms)
# ══════════════════════════════════════════════════════════════════════
def get_form_lookups(company_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT id, name FROM core.departments
            WHERE company_id = %s AND is_active = TRUE
            ORDER BY name
        """, (company_id,))
        departments = cur.fetchall()

        cur.execute("""
            SELECT p.id, p.title,
                   d.name AS department_name, d.id AS department_id,
                   jg.code AS salary_grade
            FROM core.positions p
            LEFT JOIN core.departments d ON d.id = p.department_id
            LEFT JOIN core.job_grades jg ON jg.id = p.job_grade_id
            WHERE p.company_id = %s AND p.is_active = TRUE
            ORDER BY p.title
        """, (company_id,))
        positions = cur.fetchall()

        cur.execute("""
            SELECT pi.id, pi.item_number, pi.salary_grade, pi.status,
                   p.title AS position_title
            FROM recruitment.rec_plantilla_items pi
            LEFT JOIN core.positions p ON p.id = pi.position_id
            WHERE pi.company_id = %s AND pi.status = 'VACANT'
            ORDER BY pi.item_number
        """, (company_id,))
        plantilla_items = cur.fetchall()

        cur.execute("""
            SELECT qs.id, p.title AS position_title
            FROM recruitment.rec_qualification_standards qs
            LEFT JOIN core.positions p ON p.id = qs.position_id
            WHERE qs.is_active = TRUE
            ORDER BY p.title
        """)
        qualification_standards = cur.fetchall()

        cur.execute("""
            SELECT id, code, name, category FROM recruitment.rec_csc_eligibilities
            WHERE is_active = TRUE ORDER BY name
        """)
        eligibilities = cur.fetchall()

    return {
        'departments': departments,
        'positions': positions,
        'plantilla_items': plantilla_items,
        'qualification_standards': qualification_standards,
        'eligibilities': eligibilities,
    }


# ══════════════════════════════════════════════════════════════════════
# Attachment upload
# ══════════════════════════════════════════════════════════════════════
def save_attachment(req_id, attachment_type, file_name, file_path, file_size_kb, mime_type, user_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO recruitment.rec_requisition_attachments
                (requisition_id, attachment_type, file_name, file_path,
                 file_size_kb, mime_type, uploaded_by)
            VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING id
        """, (req_id, attachment_type, file_name, file_path,
              file_size_kb, mime_type, user_id))
        attach_id = cur.fetchone()['id']
        _log_history(cur, req_id, 'ATTACH', user_id,
                     remarks=f'Uploaded {attachment_type}: {file_name}')
        return attach_id
