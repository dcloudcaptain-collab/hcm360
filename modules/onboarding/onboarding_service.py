"""Onboarding Lifecycle Service — stage machine, checklists, buddy, sign-off, activation."""
from datetime import date, timedelta
from services.db import get_cursor

# Stage progression order
STAGES = ['REQUIREMENTS', 'WELCOME', 'TRANSITION', 'SIGNOFF', 'READY', 'ACTIVATED']

REQUIREMENT_TYPES = [
    'MEDICAL_CERT', 'NBI_CLEARANCE', 'BIRTH_CERT', 'TOR',
    'PDS_CS9', 'OATHS', 'PMS_IPCR', 'SERVICE_RECORD', 'CLEARANCE_PREV_EMPLOYER',
]

DEFAULT_WELCOME_ITEMS = [
    ('MESSAGE', 'Welcome Message from HR', 'Read the welcome letter and organizational overview.', 1),
    ('POLICY_ACK', 'Code of Conduct Acknowledgement', 'Review and acknowledge the agency code of conduct.', 2),
    ('POLICY_ACK', 'Data Privacy Consent', 'Review and sign the data privacy consent form.', 3),
    ('ORIENTATION', 'General Orientation Session', 'Attend the scheduled orientation briefing.', 4),
    ('ORIENTATION', 'IT Systems Walkthrough', 'Complete the systems access and tools orientation.', 5),
    ('FIRST_DAY', 'ID Photo and Biometrics', 'Report to Admin for ID photo and biometric enrollment.', 6),
    ('FIRST_DAY', 'Workstation Setup', 'Verify your workstation, email, and system access.', 7),
    ('FIRST_WEEK', 'Meet Your Team', 'Introductions with immediate team members and supervisor.', 8),
    ('FIRST_WEEK', 'Department Tour', 'Complete the department and facility tour.', 9),
]

DEFAULT_CHECKLIST_ITEMS = [
    ('Documents', 'Submit all pre-employment requirements', 'EMPLOYEE', 1),
    ('Documents', 'HR validates submitted documents', 'HR', 2),
    ('IT Setup', 'Create email account', 'HR', 3),
    ('IT Setup', 'Configure workstation', 'HR', 4),
    ('IT Setup', 'Grant system access (HRIS, email, etc.)', 'HR', 5),
    ('Orientation', 'Complete general orientation', 'EMPLOYEE', 6),
    ('Orientation', 'Complete department orientation', 'MANAGER', 7),
    ('Buddy', 'Buddy introduction meeting', 'BUDDY', 8),
    ('Buddy', 'First-week daily check-ins with buddy', 'BUDDY', 9),
    ('Buddy', 'Buddy sign-off on readiness', 'BUDDY', 10),
    ('Manager', 'Manager readiness assessment', 'MANAGER', 11),
    ('HR', 'Final HR clearance and activation', 'HR', 12),
]


# ---------------------------------------------------------------------------
# Core CRUD
# ---------------------------------------------------------------------------

def get_onboarding_list(company_id=None, status=None):
    conditions = ['1=1']
    params = []
    if status:
        conditions.append('oc.status = %s')
        params.append(status)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT oc.*, e.first_name || ' ' || e.last_name AS employee_name,
                   e.employee_no, e.date_hired,
                   d.name AS department_name,
                   p.title AS position_title,
                   bu.first_name || ' ' || bu.last_name AS buddy_name,
                   hr_u.display_name AS hr_name,
                   mgr.first_name || ' ' || mgr.last_name AS manager_name,
                   (SELECT COUNT(*) FROM onboarding.onb_checklist_items ci
                    WHERE ci.checklist_id = oc.id AND ci.is_completed) AS items_done,
                   (SELECT COUNT(*) FROM onboarding.onb_checklist_items ci
                    WHERE ci.checklist_id = oc.id) AS items_total,
                   (SELECT COUNT(*) FROM onboarding.onb_pre_employment_reqs pr
                    WHERE pr.employee_id = oc.employee_id AND pr.status = 'VERIFIED') AS reqs_verified,
                   (SELECT COUNT(*) FROM onboarding.onb_pre_employment_reqs pr
                    WHERE pr.employee_id = oc.employee_id) AS reqs_total
            FROM onboarding.onb_checklists oc
            JOIN core.employees e ON e.id = oc.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.positions p ON p.id = e.position_id
            LEFT JOIN onboarding.onb_buddy_assignments ba
                ON ba.employee_id = oc.employee_id AND ba.status = 'ACTIVE'
            LEFT JOIN core.employees bu ON bu.id = ba.buddy_id
            LEFT JOIN core.users hr_u ON hr_u.id = oc.assigned_hr
            LEFT JOIN core.employees mgr ON mgr.id = oc.assigned_manager
            WHERE oc.type = 'ONBOARDING' AND {' AND '.join(conditions)}
            ORDER BY oc.created_at DESC
        """, params)
        return cur.fetchall()


def get_onboarding_detail(checklist_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT oc.*, e.first_name || ' ' || e.last_name AS employee_name,
                   e.employee_no, e.date_hired, e.profile_photo_path,
                   d.name AS department_name, p.title AS position_title,
                   e.work_email, e.mobile_no
            FROM onboarding.onb_checklists oc
            JOIN core.employees e ON e.id = oc.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.positions p ON p.id = e.position_id
            WHERE oc.id = %s
        """, (checklist_id,))
        checklist = cur.fetchone()
        if not checklist:
            return None

        eid = checklist['employee_id']

        # Checklist items
        cur.execute("""
            SELECT ci.*, u.display_name AS completed_by_name
            FROM onboarding.onb_checklist_items ci
            LEFT JOIN core.users u ON u.id = ci.completed_by
            WHERE ci.checklist_id = %s
            ORDER BY ci.sort_order, ci.id
        """, (checklist_id,))
        items = cur.fetchall()

        # Pre-employment requirements
        cur.execute("""
            SELECT pr.*, u.display_name AS verified_by_name
            FROM onboarding.onb_pre_employment_reqs pr
            LEFT JOIN core.users u ON u.id = pr.verified_by
            WHERE pr.employee_id = %s
            ORDER BY pr.requirement_type
        """, (eid,))
        requirements = cur.fetchall()

        # Welcome items
        cur.execute("""
            SELECT * FROM onboarding.onb_welcome_items
            WHERE checklist_id = %s ORDER BY sort_order
        """, (checklist_id,))
        welcome_items = cur.fetchall()

        # Buddy assignment
        cur.execute("""
            SELECT ba.*, b.first_name || ' ' || b.last_name AS buddy_name,
                   b.work_email AS buddy_email, bp.title AS buddy_position,
                   bd.name AS buddy_department
            FROM onboarding.onb_buddy_assignments ba
            JOIN core.employees b ON b.id = ba.buddy_id
            LEFT JOIN core.positions bp ON bp.id = b.position_id
            LEFT JOIN core.departments bd ON bd.id = b.department_id
            WHERE ba.employee_id = %s AND ba.status = 'ACTIVE'
            LIMIT 1
        """, (eid,))
        buddy = cur.fetchone()

        # Sign-offs
        cur.execute("""
            SELECT so.*, u.display_name AS signed_by_name
            FROM onboarding.onb_signoffs so
            LEFT JOIN core.users u ON u.id = so.signed_by
            WHERE so.checklist_id = %s
            ORDER BY so.signoff_type
        """, (checklist_id,))
        signoffs = cur.fetchall()

    return {
        'checklist': checklist,
        'items': items,
        'checklist_items': items,
        'requirements': requirements,
        'welcome_items': welcome_items,
        'buddy': buddy,
        'signoffs': signoffs,
    }


def get_employee_onboarding(employee_id):
    """Get onboarding for a specific employee (for ESS view)."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT id FROM onboarding.onb_checklists
            WHERE employee_id = %s AND type = 'ONBOARDING'
            ORDER BY created_at DESC LIMIT 1
        """, (employee_id,))
        row = cur.fetchone()
    if not row:
        return None
    return get_onboarding_detail(row['id'])


# ---------------------------------------------------------------------------
# Create / Initialize onboarding
# ---------------------------------------------------------------------------

def create_onboarding(employee_id, assigned_hr=None, assigned_manager=None, target_date=None):
    with get_cursor(commit=True) as cur:
        if not target_date:
            target_date = date.today() + timedelta(days=30)

        cur.execute("""
            INSERT INTO onboarding.onb_checklists
                (employee_id, type, status, stage, target_date, assigned_hr, assigned_manager)
            VALUES (%s, 'ONBOARDING', 'IN_PROGRESS', 'REQUIREMENTS', %s, %s, %s)
            RETURNING id
        """, (employee_id, target_date, assigned_hr, assigned_manager))
        checklist_id = cur.fetchone()['id']

        # Seed pre-employment requirements
        for rtype in REQUIREMENT_TYPES:
            cur.execute("""
                INSERT INTO onboarding.onb_pre_employment_reqs (employee_id, requirement_type, status)
                VALUES (%s, %s, 'PENDING') ON CONFLICT DO NOTHING
            """, (employee_id, rtype))

        # Seed welcome items
        for item_type, title, desc, sort in DEFAULT_WELCOME_ITEMS:
            cur.execute("""
                INSERT INTO onboarding.onb_welcome_items
                    (checklist_id, item_type, title, description, sort_order)
                VALUES (%s, %s, %s, %s, %s)
            """, (checklist_id, item_type, title, desc, sort))

        # Seed checklist items
        for cat, name, owner, sort in DEFAULT_CHECKLIST_ITEMS:
            due = target_date - timedelta(days=max(0, 12 - sort))
            cur.execute("""
                INSERT INTO onboarding.onb_checklist_items
                    (checklist_id, category, item_name, owner_role, due_date, sort_order)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (checklist_id, cat, name, owner, due, sort))

        # Seed sign-off placeholders
        for stype in ('BUDDY', 'MANAGER', 'HR'):
            cur.execute("""
                INSERT INTO onboarding.onb_signoffs (checklist_id, signoff_type)
                VALUES (%s, %s) ON CONFLICT DO NOTHING
            """, (checklist_id, stype))

    return checklist_id


# ---------------------------------------------------------------------------
# Stage progression
# ---------------------------------------------------------------------------

def advance_stage(checklist_id):
    """Try to advance to next stage based on completion criteria. Returns new stage or None."""
    detail = get_onboarding_detail(checklist_id)
    if not detail:
        return None
    ck = detail['checklist']
    current = ck['stage']
    idx = STAGES.index(current) if current in STAGES else 0

    can_advance = False

    if current == 'REQUIREMENTS':
        # All reqs verified?
        all_verified = all(r['status'] == 'VERIFIED' for r in detail['requirements']) if detail['requirements'] else False
        can_advance = all_verified or not detail['requirements']
    elif current == 'WELCOME':
        can_advance = all(w['is_completed'] for w in detail['welcome_items']) if detail['welcome_items'] else True
    elif current == 'TRANSITION':
        can_advance = all(i['is_completed'] for i in detail['items']) if detail['items'] else True
    elif current == 'SIGNOFF':
        can_advance = all(s['status'] == 'APPROVED' for s in detail['signoffs']) if detail['signoffs'] else True
    elif current == 'READY':
        can_advance = True  # HR manually activates

    if can_advance and idx < len(STAGES) - 1:
        new_stage = STAGES[idx + 1]
        with get_cursor(commit=True) as cur:
            if new_stage == 'ACTIVATED':
                cur.execute("""
                    UPDATE onboarding.onb_checklists
                    SET stage = %s, status = 'COMPLETED', activated_at = NOW(), completed_at = NOW()
                    WHERE id = %s
                """, (new_stage, checklist_id))
            else:
                cur.execute("""
                    UPDATE onboarding.onb_checklists SET stage = %s WHERE id = %s
                """, (new_stage, checklist_id))
        return new_stage
    return None


# ---------------------------------------------------------------------------
# Requirement actions
# ---------------------------------------------------------------------------

def submit_requirement(req_id, document_path=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE onboarding.onb_pre_employment_reqs
            SET status = 'SUBMITTED', submitted_at = NOW(), document_path = COALESCE(%s, document_path)
            WHERE id = %s
        """, (document_path, req_id))


def verify_requirement(req_id, verified_by, remarks=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE onboarding.onb_pre_employment_reqs
            SET status = 'VERIFIED', verified_by = %s, verified_at = NOW(), remarks = COALESCE(%s, remarks)
            WHERE id = %s
        """, (verified_by, remarks, req_id))


def reject_requirement(req_id, verified_by, remarks=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE onboarding.onb_pre_employment_reqs
            SET status = 'REJECTED', verified_by = %s, verified_at = NOW(), remarks = %s
            WHERE id = %s
        """, (verified_by, remarks, req_id))


# ---------------------------------------------------------------------------
# Checklist item actions
# ---------------------------------------------------------------------------

def complete_checklist_item(item_id, completed_by):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE onboarding.onb_checklist_items
            SET is_completed = TRUE, completed_by = %s, completed_at = NOW()
            WHERE id = %s
        """, (completed_by, item_id))


def add_item_comment(item_id, comments):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE onboarding.onb_checklist_items
            SET comments = COALESCE(comments || E'\n', '') || %s
            WHERE id = %s
        """, (comments, item_id))


# ---------------------------------------------------------------------------
# Welcome item actions
# ---------------------------------------------------------------------------

def complete_welcome_item(item_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE onboarding.onb_welcome_items
            SET is_completed = TRUE, completed_at = NOW()
            WHERE id = %s
        """, (item_id,))


# ---------------------------------------------------------------------------
# Buddy actions
# ---------------------------------------------------------------------------

def assign_buddy(employee_id, buddy_id, assigned_from=None):
    with get_cursor(commit=True) as cur:
        if not assigned_from:
            assigned_from = date.today()
        cur.execute("""
            UPDATE onboarding.onb_buddy_assignments SET status = 'REPLACED'
            WHERE employee_id = %s AND status = 'ACTIVE'
        """, (employee_id,))
        cur.execute("""
            INSERT INTO onboarding.onb_buddy_assignments
                (employee_id, buddy_id, assigned_from, status)
            VALUES (%s, %s, %s, 'ACTIVE')
            RETURNING id
        """, (employee_id, buddy_id, assigned_from))
        return cur.fetchone()['id']


def buddy_signoff(checklist_id, signed_by, remarks=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE onboarding.onb_signoffs
            SET status = 'APPROVED', signed_by = %s, signed_at = NOW(), remarks = %s
            WHERE checklist_id = %s AND signoff_type = 'BUDDY'
        """, (signed_by, remarks, checklist_id))
        # Also update buddy assignment
        cur.execute("""
            UPDATE onboarding.onb_buddy_assignments
            SET signed_off_at = NOW(), signoff_remarks = %s
            WHERE employee_id = (SELECT employee_id FROM onboarding.onb_checklists WHERE id = %s)
              AND status = 'ACTIVE'
        """, (remarks, checklist_id))


# ---------------------------------------------------------------------------
# Sign-off actions
# ---------------------------------------------------------------------------

def submit_signoff(checklist_id, signoff_type, signed_by, remarks=None, approve=True):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE onboarding.onb_signoffs
            SET status = %s, signed_by = %s, signed_at = NOW(), remarks = %s
            WHERE checklist_id = %s AND signoff_type = %s
        """, ('APPROVED' if approve else 'REJECTED', signed_by, remarks, checklist_id, signoff_type))


# ---------------------------------------------------------------------------
# Stats for dashboard
# ---------------------------------------------------------------------------

def get_onboarding_stats():
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                COUNT(*) FILTER (WHERE status = 'IN_PROGRESS') AS active,
                COUNT(*) FILTER (WHERE stage = 'REQUIREMENTS') AS in_requirements,
                COUNT(*) FILTER (WHERE stage = 'WELCOME') AS in_welcome,
                COUNT(*) FILTER (WHERE stage = 'TRANSITION') AS in_transition,
                COUNT(*) FILTER (WHERE stage = 'SIGNOFF') AS in_signoff,
                COUNT(*) FILTER (WHERE stage = 'READY') AS ready,
                COUNT(*) FILTER (WHERE stage = 'ACTIVATED') AS activated,
                COUNT(*) AS total
            FROM onboarding.onb_checklists
            WHERE type = 'ONBOARDING'
        """)
        return cur.fetchone()
