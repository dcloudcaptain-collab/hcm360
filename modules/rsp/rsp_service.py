"""RSP service — Recruitment, Selection & Placement.

Covers:
- Plantilla of Personnel (DBM positions)
- CSC Qualification Standards matching
- Next-in-Rank computation and auto-notification
- PSB deliberation & scoring
- Appointment paper issuance
- Onboarding / Offboarding checklists
"""
from datetime import date
from services.db import get_cursor
from services import workflow_service, notification_service


# ---------------------------------------------------------------------------
# Plantilla
# ---------------------------------------------------------------------------

def get_plantilla(company_id, status=None, department_id=None):
    conditions = ['pi.company_id = %s']
    params = [company_id]
    if status:
        conditions.append('pi.status = %s')
        params.append(status)
    if department_id:
        conditions.append('pi.department_id = %s')
        params.append(department_id)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT pi.*, d.name AS department_name, p.title AS position_title,
                   e.first_name || ' ' || e.last_name AS filled_by_name
            FROM recruitment.rec_plantilla_items pi
            LEFT JOIN core.departments d ON d.id = pi.department_id
            LEFT JOIN core.positions p   ON p.id = pi.position_id
            LEFT JOIN core.employees e   ON e.id = pi.filled_by
            WHERE {' AND '.join(conditions)}
            ORDER BY pi.salary_grade DESC, pi.item_number
        """, params)
        return cur.fetchall()


def get_plantilla_item(item_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT pi.*, d.name AS department_name, p.title AS position_title,
                   e.first_name || ' ' || e.last_name AS filled_by_name
            FROM recruitment.rec_plantilla_items pi
            LEFT JOIN core.departments d ON d.id = pi.department_id
            LEFT JOIN core.positions p   ON p.id = pi.position_id
            LEFT JOIN core.employees e   ON e.id = pi.filled_by
            WHERE pi.id = %s
        """, (item_id,))
        return cur.fetchone()


# ---------------------------------------------------------------------------
# Vacancies (postings with publication info)
# ---------------------------------------------------------------------------

def get_vacancies(company_id, status=None):
    conditions = ['rq.company_id = %s']
    params = [company_id]
    if status:
        conditions.append('rq.status = %s')
        params.append(status)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT rq.*, p.title AS position_title, d.name AS department_name,
                   jp.id AS posting_id, jp.title AS posting_title, jp.status AS posting_status,
                   pub.published_at, pub.closes_at, pub.csc_reference_no, pub.channel
            FROM recruitment.rec_requisitions rq
            LEFT JOIN core.positions p   ON p.id = rq.position_id
            LEFT JOIN core.departments d ON d.id = rq.department_id
            LEFT JOIN recruitment.rec_job_postings jp ON jp.requisition_id = rq.id
            LEFT JOIN recruitment.rec_publications pub ON pub.requisition_id = rq.id
                                                       AND pub.is_active = TRUE
            WHERE {' AND '.join(conditions)}
            ORDER BY rq.created_at DESC
        """, params)
        return cur.fetchall()


def publish_vacancy(requisition_id, posting_id, channel, csc_ref, closes_at, published_by):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO recruitment.rec_publications
                (requisition_id, posting_id, channel, csc_reference_no,
                 closes_at, published_by, published_at)
            VALUES (%s, %s, %s, %s, %s, %s, NOW())
            RETURNING id
        """, (requisition_id, posting_id, channel, csc_ref, closes_at, published_by))
        pub = cur.fetchone()
        # Update posting status
        cur.execute("""
            UPDATE recruitment.rec_job_postings
            SET status = 'ACTIVE' WHERE id = %s
        """, (posting_id,))
        return pub['id']


# ---------------------------------------------------------------------------
# Applicants
# ---------------------------------------------------------------------------

def get_applicants(posting_id=None, stage=None):
    conditions = ['1=1']
    params = []
    if posting_id:
        conditions.append('a.posting_id = %s')
        params.append(posting_id)
    if stage:
        conditions.append('a.stage = %s')
        params.append(stage)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT a.*,
                   jp.title AS posting_title,
                   rq.reference_no,
                   p.title AS position_title
            FROM recruitment.rec_applicants a
            LEFT JOIN recruitment.rec_job_postings jp ON jp.id = a.posting_id
            LEFT JOIN recruitment.rec_requisitions rq ON rq.id = jp.requisition_id
            LEFT JOIN core.positions p ON p.id = rq.position_id
            WHERE {' AND '.join(conditions)}
            ORDER BY a.created_at DESC
        """, params)
        return cur.fetchall()


def advance_applicant_stage(applicant_id, new_stage, user_id):
    valid_stages = ['APPLIED', 'SCREENING', 'INTERVIEW', 'PSB', 'OFFER', 'HIRED', 'REJECTED']
    if new_stage not in valid_stages:
        return False
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE recruitment.rec_applicants
            SET stage = %s, updated_at = NOW()
            WHERE id = %s
            RETURNING id
        """, (new_stage, applicant_id))
        return cur.fetchone() is not None


# ---------------------------------------------------------------------------
# PSB (Personnel Selection Board)
# ---------------------------------------------------------------------------

def get_psb_deliberations(requisition_id=None):
    with get_cursor() as cur:
        if requisition_id:
            cur.execute("""
                SELECT pd.*, rq.reference_no,
                       e.first_name || ' ' || e.last_name AS chair_name,
                       COUNT(ps.id) AS applicant_count
                FROM recruitment.rec_psb_deliberations pd
                LEFT JOIN recruitment.rec_requisitions rq ON rq.id = pd.requisition_id
                LEFT JOIN core.employees e ON e.id = pd.chairperson_id
                LEFT JOIN recruitment.rec_psb_scores ps ON ps.deliberation_id = pd.id
                WHERE pd.requisition_id = %s
                GROUP BY pd.id, rq.reference_no, e.first_name, e.last_name
                ORDER BY pd.deliberation_date DESC
            """, (requisition_id,))
        else:
            cur.execute("""
                SELECT pd.*, rq.reference_no,
                       e.first_name || ' ' || e.last_name AS chair_name,
                       COUNT(ps.id) AS applicant_count
                FROM recruitment.rec_psb_deliberations pd
                LEFT JOIN recruitment.rec_requisitions rq ON rq.id = pd.requisition_id
                LEFT JOIN core.employees e ON e.id = pd.chairperson_id
                LEFT JOIN recruitment.rec_psb_scores ps ON ps.deliberation_id = pd.id
                GROUP BY pd.id, rq.reference_no, e.first_name, e.last_name
                ORDER BY pd.deliberation_date DESC
            """)
        return cur.fetchall()


def get_psb_scores(deliberation_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT ps.*,
                   a.first_name || ' ' || a.last_name AS applicant_name,
                   a.stage
            FROM recruitment.rec_psb_scores ps
            JOIN recruitment.rec_applicants a ON a.id = ps.applicant_id
            WHERE ps.deliberation_id = %s
            ORDER BY ps.rank NULLS LAST, ps.total_score DESC
        """, (deliberation_id,))
        return cur.fetchall()


def save_psb_score(deliberation_id, applicant_id, scores, scored_by):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO recruitment.rec_psb_scores
                (deliberation_id, applicant_id, education_score, experience_score,
                 training_score, performance_score, interview_score, scored_by)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (deliberation_id, applicant_id) DO UPDATE SET
                education_score   = EXCLUDED.education_score,
                experience_score  = EXCLUDED.experience_score,
                training_score    = EXCLUDED.training_score,
                performance_score = EXCLUDED.performance_score,
                interview_score   = EXCLUDED.interview_score,
                scored_by         = EXCLUDED.scored_by
            RETURNING id, total_score
        """, (
            deliberation_id, applicant_id,
            scores.get('education', 0), scores.get('experience', 0),
            scores.get('training', 0), scores.get('performance', 0),
            scores.get('interview', 0), scored_by
        ))
        result = cur.fetchone()
        # Re-rank all applicants for this deliberation by total_score descending
        cur.execute("""
            WITH ranked AS (
                SELECT id,
                       ROW_NUMBER() OVER (ORDER BY total_score DESC) AS new_rank
                FROM recruitment.rec_psb_scores
                WHERE deliberation_id = %s
            )
            UPDATE recruitment.rec_psb_scores ps
            SET rank = ranked.new_rank
            FROM ranked
            WHERE ps.id = ranked.id
        """, (deliberation_id,))
        return result


# ---------------------------------------------------------------------------
# CSC Qualification Matching
# ---------------------------------------------------------------------------

def check_csc_qualifications(employee_id, position_id):
    """
    Returns dict with: qualified (bool), gaps (list of missing QS requirements).
    Compares employee eligibilities/education vs active QS for the position.
    """
    gaps = []
    with get_cursor() as cur:
        cur.execute("""
            SELECT qs.eligibility, qs.education, qs.experience, qs.training
            FROM recruitment.rec_qualification_standards qs
            WHERE qs.position_id = %s AND qs.is_active = TRUE
            LIMIT 1
        """, (position_id,))
        qs = cur.fetchone()
        if not qs:
            return {'qualified': True, 'gaps': [], 'note': 'No QS on file for this position'}

        # Check eligibility: employee must have at least one verified eligibility matching requirement
        cur.execute("""
            SELECT COUNT(*) AS cnt
            FROM recruitment.rec_employee_eligibilities ee
            JOIN recruitment.rec_csc_eligibilities ce ON ce.id = ee.eligibility_id
            WHERE ee.employee_id = %s AND ee.is_verified = TRUE AND ce.code != 'NONE'
        """, (employee_id,))
        elig_count = cur.fetchone()['cnt']
        if qs['eligibility'] and elig_count == 0:
            gaps.append(f"Eligibility: {qs['eligibility']}")

        # Education / experience / training gaps are noted from QS (text-based; flag for HR review)
        if qs['education']:
            gaps.append(f"Education requirement: {qs['education']}") if elig_count == 0 else None

    return {'qualified': len(gaps) == 0, 'gaps': gaps}


# ---------------------------------------------------------------------------
# Next-in-Rank
# ---------------------------------------------------------------------------

def compute_next_in_rank(position_id, assessed_by):
    """
    Ranks all employees who meet QS for this position.
    Updates rec_next_in_rank_list and triggers notifications for newly ranked employees.
    """
    with get_cursor(commit=True) as cur:
        # Get all active employees with their current SG
        cur.execute("""
            SELECT e.id AS employee_id,
                   jg.grade_level AS salary_grade,
                   e.date_hired,
                   COALESCE(e.first_name,'') || ' ' || COALESCE(e.last_name,'') AS full_name
            FROM core.employees e
            LEFT JOIN core.job_grades jg ON jg.id = e.job_grade_id
            WHERE e.is_active = TRUE
            ORDER BY jg.grade_level DESC NULLS LAST, e.date_hired
        """)
        employees = cur.fetchall()

        results = []
        rank = 0
        for emp in employees:
            check = check_csc_qualifications(emp['employee_id'], position_id)
            rank += 1
            results.append({
                'employee_id': emp['employee_id'],
                'qualified': check['qualified'],
                'rank': rank,
            })

        # Upsert results
        for r in results:
            cur.execute("""
                INSERT INTO recruitment.rec_next_in_rank_list
                    (position_id, employee_id, qualification_met, rank, assessed_on, assessed_by)
                VALUES (%s, %s, %s, %s, CURRENT_DATE, %s)
                ON CONFLICT (position_id, employee_id) DO UPDATE SET
                    qualification_met = EXCLUDED.qualification_met,
                    rank              = EXCLUDED.rank,
                    assessed_on       = EXCLUDED.assessed_on,
                    assessed_by       = EXCLUDED.assessed_by,
                    is_active         = TRUE
            """, (position_id, r['employee_id'], r['qualified'], r['rank'], assessed_by))

        return len(results)


def notify_next_in_rank(position_id, notified_by_user_id):
    """Send notifications to all qualified next-in-rank employees who haven't been notified yet."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT nir.id, nir.employee_id, nir.rank,
                   e.first_name || ' ' || e.last_name AS full_name,
                   p.title AS position_title,
                   u.id AS user_id
            FROM recruitment.rec_next_in_rank_list nir
            JOIN core.employees e ON e.id = nir.employee_id
            JOIN core.positions p ON p.id = %s
            LEFT JOIN core.users u ON u.employee_id = nir.employee_id
            WHERE nir.position_id = %s
              AND nir.qualification_met = TRUE
              AND nir.notified_at IS NULL
              AND nir.is_active = TRUE
        """, (position_id, position_id))
        candidates = cur.fetchall()

    notified = 0
    for c in candidates:
        if c['user_id']:
            notification_service.notify(
                user_id=c['user_id'],
                title='Next-in-Rank Notification',
                body=f"You are rank #{c['rank']} in line for position: {c['position_title']}. "
                     "Please ensure your application documents are updated.",
                category='RECRUITMENT',
                action_url='/rsp/next-in-rank'
            )
            with get_cursor(commit=True) as cur:
                cur.execute("""
                    UPDATE recruitment.rec_next_in_rank_list
                    SET notified_at = NOW(), notification_ref = %s
                    WHERE id = %s
                """, (f'NOTIF-NIR-{c["id"]}', c['id']))
            notified += 1
    return notified


def get_next_in_rank(position_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT nir.*, p.title AS position_title,
                   e.first_name || ' ' || e.last_name AS full_name,
                   jg.grade_level AS salary_grade,
                   et.code AS employment_type,
                   d.name AS department_name
            FROM recruitment.rec_next_in_rank_list nir
            JOIN core.employees e ON e.id = nir.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.job_grades jg ON jg.id = e.job_grade_id
            LEFT JOIN core.employment_types et ON et.id = e.employment_type_id
            CROSS JOIN core.positions p
            WHERE p.id = %s AND nir.position_id = %s AND nir.is_active = TRUE
            ORDER BY nir.rank
        """, (position_id, position_id))
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Appointments
# ---------------------------------------------------------------------------

def get_appointments(employee_id=None, status=None):
    conditions = ['1=1']
    params = []
    if employee_id:
        conditions.append('a.employee_id = %s')
        params.append(employee_id)
    if status:
        conditions.append('a.status = %s')
        params.append(status)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT a.*,
                   e.first_name || ' ' || e.last_name AS employee_name,
                   p.title AS position_title,
                   pi.item_number,
                   u_issued.display_name AS issued_by_name,
                   u_approved.display_name AS approved_by_name
            FROM recruitment.rec_appointments a
            JOIN core.employees e ON e.id = a.employee_id
            JOIN core.positions p ON p.id = a.position_id
            LEFT JOIN recruitment.rec_plantilla_items pi ON pi.id = a.plantilla_item_id
            LEFT JOIN core.users u_issued   ON u_issued.id = a.issued_by
            LEFT JOIN core.users u_approved ON u_approved.id = a.approved_by
            WHERE {' AND '.join(conditions)}
            ORDER BY a.effective_date DESC
        """, params)
        return cur.fetchall()


def issue_appointment(employee_id, position_id, plantilla_item_id, appt_type,
                      appt_no, effective_date, salary_grade, step_no,
                      monthly_salary, issued_by, end_date=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO recruitment.rec_appointments
                (employee_id, position_id, plantilla_item_id, appointment_type,
                 appointment_no, effective_date, end_date, salary_grade, step_no,
                 monthly_salary, issued_by, status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'DRAFT')
            RETURNING id
        """, (employee_id, position_id, plantilla_item_id, appt_type,
              appt_no, effective_date, end_date, salary_grade, step_no,
              monthly_salary, issued_by))
        appt = cur.fetchone()
        # Mark plantilla item as FILLED
        if plantilla_item_id:
            cur.execute("""
                UPDATE recruitment.rec_plantilla_items
                SET status = 'FILLED', filled_by = %s, updated_at = NOW()
                WHERE id = %s
            """, (employee_id, plantilla_item_id))
        # Start approval workflow
        wf = workflow_service.create_instance(
            definition_code='RSP_APPOINTMENT_APPROVAL',
            module='rsp',
            entity_type='rec_appointments',
            entity_id=appt['id'],
            reference_no=appt_no,
            initiated_by=issued_by
        )
        if wf:
            cur.execute("""
                UPDATE recruitment.rec_appointments
                SET workflow_instance_id = %s WHERE id = %s
            """, (wf, appt['id']))
        return appt['id']


def trigger_onboarding(employee_id, checklist_type='ONBOARDING', target_date=None):
    """Creates onboarding checklist with standard pre-employment requirements."""
    standard_items = [
        ('Documents', 'Medical Certificate', True),
        ('Documents', 'NBI Clearance', True),
        ('Documents', 'Birth Certificate (PSA)', True),
        ('Documents', 'Transcript of Records', True),
        ('Documents', 'Personal Data Sheet (CS Form 212)', True),
        ('Documents', 'Oath of Office', True),
        ('IT Setup', 'Create email account', True),
        ('IT Setup', 'Issue equipment', True),
        ('Orientation', 'Department orientation', True),
        ('Orientation', 'Systems access training', False),
    ]
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO onboarding.onb_checklists
                (employee_id, type, status, target_date)
            VALUES (%s, %s, 'IN_PROGRESS', %s)
            RETURNING id
        """, (employee_id, checklist_type, target_date))
        checklist_id = cur.fetchone()['id']

        for i, (category, item_name, required) in enumerate(standard_items):
            cur.execute("""
                INSERT INTO onboarding.onb_checklist_items
                    (checklist_id, category, item_name, is_required, sort_order)
                VALUES (%s, %s, %s, %s, %s)
            """, (checklist_id, category, item_name, required, i + 1))

        # Also seed pre-employment requirement rows
        for req_type in ['MEDICAL_CERT', 'NBI_CLEARANCE', 'BIRTH_CERT', 'TOR', 'PDS_CS9', 'OATHS']:
            cur.execute("""
                INSERT INTO onboarding.onb_pre_employment_reqs (employee_id, requirement_type)
                VALUES (%s, %s)
                ON CONFLICT DO NOTHING
            """, (employee_id, req_type))

        return checklist_id


# ---------------------------------------------------------------------------
# Offboarding
# ---------------------------------------------------------------------------

def get_clearance_items(employee_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT ci.*,
                   u.display_name AS cleared_by_name
            FROM onboarding.offb_clearance_items ci
            LEFT JOIN core.users u ON u.id = ci.cleared_by
            WHERE ci.employee_id = %s
            ORDER BY ci.clearance_type
        """, (employee_id,))
        return cur.fetchall()


def seed_clearance_items(employee_id):
    clearance_types = [
        'PROPERTY', 'CASH_ADVANCE', 'LIBRARY', 'IT_EQUIPMENT',
        'HR_201', 'FINANCE', 'GSIS', 'PAGIBIG'
    ]
    with get_cursor(commit=True) as cur:
        for ct in clearance_types:
            cur.execute("""
                INSERT INTO onboarding.offb_clearance_items (employee_id, clearance_type)
                VALUES (%s, %s) ON CONFLICT (employee_id, clearance_type) DO NOTHING
            """, (employee_id, ct))


def mark_clearance(employee_id, clearance_type, cleared_by, remarks=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO onboarding.offb_clearance_items
                (employee_id, clearance_type, cleared_by, cleared_at, remarks)
            VALUES (%s, %s, %s, NOW(), %s)
            ON CONFLICT (employee_id, clearance_type) DO UPDATE SET
                cleared_by = EXCLUDED.cleared_by,
                cleared_at = NOW(),
                remarks    = EXCLUDED.remarks
        """, (employee_id, clearance_type, cleared_by, remarks))
