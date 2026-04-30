"""Health & Safety service — PE, certificates, incidents, wellness."""
from datetime import date
from services.db import get_cursor


def _generate_incident_no(cur, company_id):
    yr = date.today().year
    cur.execute("""
        SELECT COUNT(*) + 1 AS seq FROM health.incidents
        WHERE company_id = %s AND EXTRACT(YEAR FROM incident_date) = %s
    """, (company_id, yr))
    seq = cur.fetchone()['seq']
    return f'INC-{yr}-{seq:04d}'


# ---------------------------------------------------------------------------
# Medical Records
# ---------------------------------------------------------------------------

def get_medical_record(employee_id):
    with get_cursor() as cur:
        cur.execute("SELECT * FROM health.medical_records WHERE employee_id = %s", (employee_id,))
        return cur.fetchone()


def update_medical_record(employee_id, data, updated_by):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO health.medical_records
                (employee_id, blood_type, allergies, chronic_conditions,
                 medications, emergency_medical_notes, last_updated_by)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (employee_id) DO UPDATE SET
                blood_type = EXCLUDED.blood_type,
                allergies = EXCLUDED.allergies,
                chronic_conditions = EXCLUDED.chronic_conditions,
                medications = EXCLUDED.medications,
                emergency_medical_notes = EXCLUDED.emergency_medical_notes,
                last_updated_by = EXCLUDED.last_updated_by,
                updated_at = NOW()
            RETURNING id
        """, (employee_id, data.get('blood_type'), data.get('allergies'),
              data.get('chronic_conditions'), data.get('medications'),
              data.get('emergency_medical_notes'), updated_by))
        return cur.fetchone()


# ---------------------------------------------------------------------------
# PE Schedules & Results
# ---------------------------------------------------------------------------

def get_pe_schedules(company_id, year=None):
    conditions = ['ps.company_id = %s']
    params = [company_id]
    if year:
        conditions.append('ps.year = %s')
        params.append(year)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT ps.*,
                   COUNT(pr.id) AS result_count,
                   COUNT(pr.id) FILTER (WHERE pr.overall_result NOT IN ('PENDING', 'NO_SHOW')) AS examined_count
            FROM health.pe_schedules ps
            LEFT JOIN health.pe_results pr ON pr.schedule_id = ps.id
            WHERE {' AND '.join(conditions)}
            GROUP BY ps.id
            ORDER BY ps.year DESC, ps.scheduled_from
        """, params)
        return cur.fetchall()


def get_pe_results(schedule_id, department_id=None):
    conditions = ['pr.schedule_id = %s']
    params = [schedule_id]
    if department_id:
        conditions.append('e.department_id = %s')
        params.append(department_id)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT pr.*,
                   e.first_name || ' ' || e.last_name AS employee_name,
                   d.name AS department_name
            FROM health.pe_results pr
            JOIN core.employees e ON e.id = pr.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            WHERE {' AND '.join(conditions)}
            ORDER BY d.name, e.last_name
        """, params)
        return cur.fetchall()


def record_pe_result(schedule_id, employee_id, exam_date, result, findings, recommendations, physician):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO health.pe_results
                (schedule_id, employee_id, exam_date, overall_result, findings,
                 recommendations, examining_physician)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (schedule_id, employee_id) DO UPDATE SET
                exam_date = EXCLUDED.exam_date,
                overall_result = EXCLUDED.overall_result,
                findings = EXCLUDED.findings,
                recommendations = EXCLUDED.recommendations,
                examining_physician = EXCLUDED.examining_physician,
                updated_at = NOW()
            RETURNING id
        """, (schedule_id, employee_id, exam_date, result, findings, recommendations, physician))
        return cur.fetchone()


def get_pe_compliance(company_id, year):
    with get_cursor() as cur:
        cur.execute("""
            SELECT d.name AS department_name,
                   COUNT(e.id) AS total,
                   COUNT(pr.id) FILTER (WHERE pr.overall_result NOT IN ('PENDING', 'NO_SHOW')) AS examined
            FROM core.employees e
            JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN health.pe_schedules ps ON ps.company_id = e.company_id AND ps.year = %s
            LEFT JOIN health.pe_results pr ON pr.schedule_id = ps.id AND pr.employee_id = e.id
            WHERE e.is_active = TRUE AND e.company_id = %s
            GROUP BY d.name
            ORDER BY d.name
        """, (year, company_id))
        rows = cur.fetchall()
        result = []
        for r in rows:
            row = dict(r)
            row['pct'] = round(row['examined'] / row['total'] * 100) if row['total'] > 0 else 0
            result.append(row)
        return result


# ---------------------------------------------------------------------------
# Health Certificates
# ---------------------------------------------------------------------------

def get_health_certificates(employee_id=None, status=None):
    conditions = ['1=1']
    params = []
    if employee_id:
        conditions.append('hc.employee_id = %s')
        params.append(employee_id)
    if status:
        conditions.append('hc.status = %s')
        params.append(status)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT hc.*,
                   e.first_name || ' ' || e.last_name AS employee_name,
                   d.name AS department_name,
                   CASE WHEN hc.expiry_date IS NOT NULL
                        THEN hc.expiry_date - CURRENT_DATE ELSE NULL END AS days_until_expiry
            FROM health.health_certificates hc
            JOIN core.employees e ON e.id = hc.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            WHERE {' AND '.join(conditions)}
            ORDER BY hc.expiry_date NULLS LAST
        """, params)
        return cur.fetchall()


def get_expiring_certificates(company_id, days=60):
    with get_cursor() as cur:
        cur.execute("""
            SELECT hc.*, e.first_name || ' ' || e.last_name AS employee_name,
                   d.name AS department_name,
                   hc.expiry_date - CURRENT_DATE AS days_until_expiry
            FROM health.health_certificates hc
            JOIN core.employees e ON e.id = hc.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            WHERE hc.status = 'ACTIVE' AND e.company_id = %s
              AND hc.expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + %s
            ORDER BY hc.expiry_date
        """, (company_id, days))
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Incidents
# ---------------------------------------------------------------------------

def get_incidents(company_id, status=None, incident_type=None):
    conditions = ['i.company_id = %s']
    params = [company_id]
    if status:
        conditions.append('i.status = %s')
        params.append(status)
    if incident_type:
        conditions.append('i.incident_type = %s')
        params.append(incident_type)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT i.*, u.display_name AS reported_by_name,
                   COUNT(ip.id) AS persons_involved
            FROM health.incidents i
            JOIN core.users u ON u.id = i.reported_by
            LEFT JOIN health.incident_persons ip ON ip.incident_id = i.id
            WHERE {' AND '.join(conditions)}
            GROUP BY i.id, u.display_name
            ORDER BY i.incident_date DESC
        """, params)
        return cur.fetchall()


def get_incident(incident_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT i.*, u.display_name AS reported_by_name
            FROM health.incidents i
            JOIN core.users u ON u.id = i.reported_by
            WHERE i.id = %s
        """, (incident_id,))
        incident = cur.fetchone()
        if not incident:
            return None

        cur.execute("""
            SELECT ip.*, e.first_name || ' ' || e.last_name AS employee_name
            FROM health.incident_persons ip
            LEFT JOIN core.employees e ON e.id = ip.employee_id
            WHERE ip.incident_id = %s
        """, (incident_id,))
        persons = cur.fetchall()

        cur.execute("""
            SELECT inv.*, u.display_name AS investigator_name
            FROM health.incident_investigations inv
            JOIN core.users u ON u.id = inv.investigator_id
            WHERE inv.incident_id = %s
            ORDER BY inv.investigation_date
        """, (incident_id,))
        investigations = cur.fetchall()

        return {'incident': incident, 'persons': persons, 'investigations': investigations}


def report_incident(company_id, incident_date, location, incident_type, severity,
                    description, action_taken, reported_by, dole_reportable=False):
    with get_cursor(commit=True) as cur:
        incident_no = _generate_incident_no(cur, company_id)
        cur.execute("""
            INSERT INTO health.incidents
                (company_id, incident_no, incident_date, location, incident_type,
                 severity, description, immediate_action_taken, reported_by, dole_reportable)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id, incident_no
        """, (company_id, incident_no, incident_date, location, incident_type,
              severity, description, action_taken, reported_by, dole_reportable))
        return cur.fetchone()


# ---------------------------------------------------------------------------
# Wellness Programs
# ---------------------------------------------------------------------------

def get_wellness_programs(company_id, status=None):
    conditions = ['wp.company_id = %s']
    params = [company_id]
    if status:
        conditions.append('wp.status = %s')
        params.append(status)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT wp.*,
                   COUNT(we.id)                                    AS enrolled_count,
                   COUNT(we.id) FILTER (WHERE we.attended_at IS NOT NULL) AS attended_count,
                   COUNT(we.id) FILTER (WHERE we.feedback IS NOT NULL AND we.feedback <> '') AS feedback_count,
                   ROUND(AVG(we.feedback_rating)::numeric, 1)      AS avg_rating
            FROM health.wellness_programs wp
            LEFT JOIN health.wellness_enrollments we ON we.program_id = wp.id
            WHERE {' AND '.join(conditions)}
            GROUP BY wp.id
            ORDER BY wp.start_date DESC NULLS LAST
        """, params)
        return cur.fetchall()


def get_wellness_program(program_id):
    """Detail view: program + enrollments list with employee names."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT wp.*, u.display_name AS created_by_name
              FROM health.wellness_programs wp
              LEFT JOIN core.users u ON u.id = wp.created_by
             WHERE wp.id = %s
        """, (program_id,))
        program = cur.fetchone()
        if not program:
            return None
        cur.execute("""
            SELECT we.id AS enrollment_id, we.employee_id, we.status,
                   we.enrolled_at, we.attended_at, we.completed_at,
                   we.feedback, we.feedback_rating,
                   e.employee_no,
                   TRIM(e.first_name || ' ' || COALESCE(e.middle_name || ' ','') || e.last_name) AS name,
                   d.name AS department,
                   ab.display_name AS enrolled_by_name
              FROM health.wellness_enrollments we
              JOIN core.employees e          ON e.id = we.employee_id
              LEFT JOIN core.departments d   ON d.id = e.department_id
              LEFT JOIN core.users ab        ON ab.id = we.enrolled_by
             WHERE we.program_id = %s
             ORDER BY e.last_name, e.first_name
        """, (program_id,))
        enrollments = cur.fetchall()
    return {'program': program, 'enrollments': enrollments}


def enroll_employee(program_id, employee_id, enrolled_by=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO health.wellness_enrollments
                (program_id, employee_id, status, enrolled_by)
            VALUES (%s, %s, 'ENROLLED', %s)
            ON CONFLICT (program_id, employee_id) DO NOTHING
            RETURNING id
        """, (program_id, employee_id, enrolled_by))
        return cur.fetchone()


def enroll_many(program_id, employee_ids, enrolled_by=None):
    """Bulk enrollment — used by the admin 'Assign Attendees' flow."""
    if not employee_ids:
        return 0
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO health.wellness_enrollments
                (program_id, employee_id, status, enrolled_by)
            SELECT %s, unnest(%s::bigint[]), 'ENROLLED', %s
            ON CONFLICT (program_id, employee_id) DO NOTHING
        """, (program_id, list(employee_ids), enrolled_by))
        return cur.rowcount


def mark_attendance(enrollment_id, attended: bool):
    """Flip attended_at between NOW() and NULL."""
    with get_cursor(commit=True) as cur:
        if attended:
            cur.execute("""
                UPDATE health.wellness_enrollments
                   SET attended_at = NOW(),
                       status = CASE WHEN status = 'ENROLLED' THEN 'COMPLETED' ELSE status END
                 WHERE id = %s
            """, (enrollment_id,))
        else:
            cur.execute("""
                UPDATE health.wellness_enrollments
                   SET attended_at = NULL
                 WHERE id = %s
            """, (enrollment_id,))


def mark_no_show(enrollment_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE health.wellness_enrollments
               SET status = 'NO_SHOW', attended_at = NULL
             WHERE id = %s
        """, (enrollment_id,))


def submit_feedback(program_id, employee_id, rating, feedback):
    """Employee submits rating (1-5) + free-text feedback for their enrollment."""
    if rating is not None:
        rating = max(1, min(5, int(rating)))
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE health.wellness_enrollments
               SET feedback_rating = %s,
                   feedback = %s,
                   completed_at = COALESCE(completed_at, NOW())
             WHERE program_id = %s AND employee_id = %s
        """, (rating, feedback, program_id, employee_id))
        return cur.rowcount


def create_pe_schedule(data, created_by=None):
    with get_cursor(commit=True) as cur:
        cur.execute("SELECT id FROM core.companies LIMIT 1")
        co_id = cur.fetchone()['id']
        cur.execute("""
            INSERT INTO health.pe_schedules
                (company_id, year, title, provider_name, scheduled_from, scheduled_to, status, created_by)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id
        """, (co_id, int(data['year']), data['title'], data.get('provider_name',''),
              data['scheduled_from'], data['scheduled_to'], data.get('status','SCHEDULED'), created_by))
        return cur.fetchone()['id']


def create_wellness_program(data, created_by=None):
    with get_cursor(commit=True) as cur:
        cur.execute("SELECT id FROM core.companies LIMIT 1")
        co_id = cur.fetchone()['id']
        cur.execute("""
            INSERT INTO health.wellness_programs
                (company_id, name, description, program_type, start_date, end_date,
                 status, location, schedule_notes, max_participants, provider, created_by)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id
        """, (co_id, data['name'], data.get('description','') or None,
              data.get('program_type') or 'FITNESS',
              data.get('start_date') or None, data.get('end_date') or None,
              data.get('status','PLANNED'),
              data.get('location') or None,
              data.get('schedule_notes') or None,
              int(data['max_participants']) if data.get('max_participants') else None,
              data.get('provider') or None,
              created_by))
        return cur.fetchone()['id']


def update_wellness_program(program_id, data):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE health.wellness_programs SET
                name = %s, description = %s, program_type = %s,
                start_date = %s, end_date = %s, status = %s,
                location = %s, schedule_notes = %s,
                max_participants = %s, provider = %s,
                updated_at = NOW()
             WHERE id = %s
        """, (
            data['name'], data.get('description') or None,
            data.get('program_type') or 'FITNESS',
            data.get('start_date') or None, data.get('end_date') or None,
            data.get('status','PLANNED'),
            data.get('location') or None,
            data.get('schedule_notes') or None,
            int(data['max_participants']) if data.get('max_participants') else None,
            data.get('provider') or None,
            program_id,
        ))
