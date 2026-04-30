"""Discipline service — administrative cases per CSC RRACA."""
from datetime import date, timedelta
from services.db import get_cursor


def _generate_case_no(cur, company_id):
    yr = date.today().year
    cur.execute("""
        SELECT COUNT(*) + 1 AS seq FROM discipline.cases
        WHERE company_id = %s AND EXTRACT(YEAR FROM date_filed) = %s
    """, (company_id, yr))
    seq = cur.fetchone()['seq']
    return f'AC-{yr}-{seq:04d}'


# ---------------------------------------------------------------------------
# Cases
# ---------------------------------------------------------------------------

def get_cases(company_id, status=None, respondent_id=None, user_id=None, user_role=None):
    """List cases with confidentiality filtering."""
    conditions = ['c.company_id = %s']
    params = [company_id]
    if status:
        conditions.append('c.status = %s')
        params.append(status)
    if respondent_id:
        conditions.append('c.respondent_id = %s')
        params.append(respondent_id)
    # Confidentiality: EMPLOYEE can only see own cases
    if user_role == 'EMPLOYEE' and user_id:
        conditions.append("""
            (c.respondent_id = (SELECT employee_id FROM core.users WHERE id = %s)
             OR c.is_confidential = FALSE)
        """)
        params.append(user_id)

    with get_cursor() as cur:
        cur.execute(f"""
            SELECT c.*, ct.name AS offense_type, ct.gravity,
                   e.first_name || ' ' || e.last_name AS respondent_name,
                   d.name AS department_name,
                   CURRENT_DATE - c.date_filed AS days_since_filed,
                   u.display_name AS assigned_to_name
            FROM discipline.cases c
            JOIN discipline.case_types ct ON ct.id = c.case_type_id
            JOIN core.employees e ON e.id = c.respondent_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.users u ON u.id = c.assigned_to
            WHERE {' AND '.join(conditions)}
            ORDER BY c.created_at DESC
        """, params)
        return cur.fetchall()


def get_case(case_id):
    """Full case detail with all related records."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT c.*, ct.name AS offense_type, ct.gravity, ct.legal_basis,
                   e.first_name || ' ' || e.last_name AS respondent_name,
                   d.name AS department_name
            FROM discipline.cases c
            JOIN discipline.case_types ct ON ct.id = c.case_type_id
            JOIN core.employees e ON e.id = c.respondent_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            WHERE c.id = %s
        """, (case_id,))
        case = cur.fetchone()
        if not case:
            return None

        cur.execute("SELECT * FROM discipline.complaints WHERE case_id = %s ORDER BY filed_at", (case_id,))
        complaints = cur.fetchall()

        cur.execute("SELECT * FROM discipline.investigations WHERE case_id = %s ORDER BY started_at", (case_id,))
        investigations = cur.fetchall()

        cur.execute("SELECT * FROM discipline.formal_charges WHERE case_id = %s ORDER BY charge_date", (case_id,))
        charges = cur.fetchall()

        cur.execute("SELECT * FROM discipline.preventive_suspensions WHERE case_id = %s ORDER BY start_date", (case_id,))
        suspensions = cur.fetchall()

        cur.execute("""
            SELECT h.*, u.display_name AS presiding_officer_name
            FROM discipline.hearings h
            LEFT JOIN core.users u ON u.id = h.presiding_officer_id
            WHERE h.case_id = %s ORDER BY h.scheduled_date
        """, (case_id,))
        hearings = cur.fetchall()

        cur.execute("""
            SELECT dec.*, u.display_name AS decided_by_name
            FROM discipline.decisions dec
            LEFT JOIN core.users u ON u.id = dec.decided_by
            WHERE dec.case_id = %s ORDER BY dec.decision_date
        """, (case_id,))
        decisions = cur.fetchall()

        cur.execute("SELECT * FROM discipline.appeals WHERE case_id = %s ORDER BY appeal_date", (case_id,))
        appeals = cur.fetchall()

        return {
            'case': case, 'complaints': complaints, 'investigations': investigations,
            'charges': charges, 'suspensions': suspensions, 'hearings': hearings,
            'decisions': decisions, 'appeals': appeals,
        }


def create_case(company_id, respondent_id, complainant_id, case_type_id,
                offense_description, date_of_offense, created_by):
    with get_cursor(commit=True) as cur:
        case_no = _generate_case_no(cur, company_id)
        cur.execute("""
            INSERT INTO discipline.cases
                (company_id, case_no, respondent_id, complainant_id, case_type_id,
                 offense_description, date_of_offense, created_by)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id, case_no
        """, (company_id, case_no, respondent_id, complainant_id or None,
              case_type_id, offense_description, date_of_offense or None, created_by))
        return cur.fetchone()


def update_case_status(case_id, new_status):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE discipline.cases SET status = %s, updated_at = NOW()
            WHERE id = %s
        """, (new_status, case_id))


def file_complaint(case_id, complaint_text, evidence_summary, filed_by):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO discipline.complaints (case_id, complaint_text, evidence_summary, filed_by)
            VALUES (%s, %s, %s, %s) RETURNING id
        """, (case_id, complaint_text, evidence_summary, filed_by))
        return cur.fetchone()


def start_investigation(case_id, investigator_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO discipline.investigations (case_id, investigator_id)
            VALUES (%s, %s) RETURNING id
        """, (case_id, investigator_id))
        update_case_status(case_id, 'PRELIMINARY_INVESTIGATION')
        return cur.fetchone()


def complete_investigation(investigation_id, findings, recommendation, user_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE discipline.investigations
            SET findings = %s, recommendation = %s, status = 'COMPLETED', completed_at = NOW()
            WHERE id = %s RETURNING case_id
        """, (findings, recommendation, investigation_id))
        row = cur.fetchone()
        if row and recommendation == 'PROCEED_FORMAL_CHARGE':
            update_case_status(row['case_id'], 'FORMAL_CHARGE')
        elif row and recommendation == 'DISMISS':
            update_case_status(row['case_id'], 'DISMISSED')
        return row


def issue_formal_charge(case_id, charge_text, offense_classification, issued_by):
    deadline = date.today() + timedelta(days=5)
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO discipline.formal_charges
                (case_id, charge_text, offense_classification, answer_deadline, issued_by)
            VALUES (%s, %s, %s, %s, %s) RETURNING id
        """, (case_id, charge_text, offense_classification, deadline, issued_by))
        update_case_status(case_id, 'FORMAL_CHARGE')
        return cur.fetchone()


def impose_preventive_suspension(case_id, employee_id, start_date, end_date, reason, approved_by):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO discipline.preventive_suspensions
                (case_id, employee_id, start_date, end_date, reason, approved_by)
            VALUES (%s, %s, %s, %s, %s, %s) RETURNING id
        """, (case_id, employee_id, start_date, end_date, reason, approved_by))
        update_case_status(case_id, 'PREVENTIVE_SUSPENSION')
        return cur.fetchone()


def schedule_hearing(case_id, hearing_type, scheduled_date, venue, presiding_officer_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO discipline.hearings
                (case_id, hearing_type, scheduled_date, venue, presiding_officer_id)
            VALUES (%s, %s, %s, %s, %s) RETURNING id
        """, (case_id, hearing_type, scheduled_date, venue, presiding_officer_id))
        update_case_status(case_id, 'HEARING')
        return cur.fetchone()


def record_decision(case_id, verdict, penalty, penalty_details, decision_text, decided_by, effectivity_date=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO discipline.decisions
                (case_id, decision_date, verdict, penalty, penalty_details,
                 decision_text, decided_by, effectivity_date)
            VALUES (%s, CURRENT_DATE, %s, %s, %s, %s, %s, %s) RETURNING id
        """, (case_id, verdict, penalty, penalty_details, decision_text, decided_by, effectivity_date))
        update_case_status(case_id, 'DECISION')
        return cur.fetchone()


def file_appeal(case_id, decision_id, grounds, appeal_body, filed_by):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO discipline.appeals
                (case_id, decision_id, appeal_date, appeal_body, grounds, filed_by)
            VALUES (%s, %s, CURRENT_DATE, %s, %s, %s) RETURNING id
        """, (case_id, decision_id, appeal_body, grounds, filed_by))
        update_case_status(case_id, 'APPEAL')
        return cur.fetchone()


def get_case_types():
    with get_cursor() as cur:
        cur.execute("SELECT * FROM discipline.case_types WHERE is_active = TRUE ORDER BY gravity, name")
        return cur.fetchall()
