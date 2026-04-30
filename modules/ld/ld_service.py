"""Learning & Development service — programs, TNA, geo-attendance, NRF, scholarships."""
from services.db import get_cursor
from services import workflow_service, notification_service
from math import radians, cos, sin, asin, sqrt


# ---------------------------------------------------------------------------
# Programs / Catalog
# ---------------------------------------------------------------------------

def get_programs(company_id, csc_only=False, category=None):
    conditions = ['p.company_id = %s', 'p.is_active = TRUE']
    params = [company_id]
    if csc_only:
        conditions.append('p.csc_accredited = TRUE')
    if category:
        conditions.append('p.category = %s')
        params.append(category)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT p.*, lsp.name AS lsp_name, lsp.is_csc_accredited AS lsp_accredited,
                   COUNT(DISTINCT s.id) AS session_count,
                   COUNT(DISTINCT e.id) AS enrollment_count
            FROM learning.lrn_programs p
            LEFT JOIN learning.lrn_lsp_registry lsp ON lsp.id = p.lsp_id
            LEFT JOIN learning.lrn_sessions s ON s.program_id = p.id
            LEFT JOIN learning.lrn_enrollments e ON e.session_id = s.id
            WHERE {' AND '.join(conditions)}
            GROUP BY p.id, lsp.name, lsp.is_csc_accredited
            ORDER BY p.title
        """, params)
        return cur.fetchall()


def get_program(program_id):
    with get_cursor() as cur:
        cur.execute("SELECT * FROM learning.lrn_programs WHERE id = %s", (program_id,))
        return cur.fetchone()


def create_program(data):
    with get_cursor(commit=True) as cur:
        cur.execute("SELECT id FROM core.companies LIMIT 1")
        co_id = cur.fetchone()['id']
        cur.execute("""
            INSERT INTO learning.lrn_programs
                (company_id, code, title, description, category, delivery_mode, provider, duration_hours, is_mandatory)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id
        """, (co_id, data['code'], data['title'], data.get('description',''),
              data.get('category','TRAINING'), data.get('delivery_mode','CLASSROOM'),
              data.get('provider',''), int(data.get('duration_hours',0) or 0),
              data.get('is_mandatory') == 'on'))
        return cur.fetchone()['id']


def update_program(program_id, data):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE learning.lrn_programs SET
                code=%s, title=%s, description=%s, category=%s, delivery_mode=%s,
                provider=%s, duration_hours=%s, is_mandatory=%s
            WHERE id=%s
        """, (data['code'], data['title'], data.get('description',''),
              data.get('category','TRAINING'), data.get('delivery_mode','CLASSROOM'),
              data.get('provider',''), int(data.get('duration_hours',0) or 0),
              data.get('is_mandatory') == 'on', program_id))


# ---------------------------------------------------------------------------
# Sessions
# ---------------------------------------------------------------------------

def get_sessions(program_id=None, status=None):
    conditions = ['1=1']
    params = []
    if program_id:
        conditions.append('s.program_id = %s')
        params.append(program_id)
    if status:
        conditions.append('s.status = %s')
        params.append(status)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT s.*, p.title AS program_title, p.category,
                   COUNT(e.id) AS enrolled_count
            FROM learning.lrn_sessions s
            JOIN learning.lrn_programs p ON p.id = s.program_id
            LEFT JOIN learning.lrn_enrollments e ON e.session_id = s.id
            WHERE {' AND '.join(conditions)}
            GROUP BY s.id, p.title, p.category
            ORDER BY s.session_date DESC
        """, params)
        return cur.fetchall()


# ---------------------------------------------------------------------------
# TNA (Training Needs Analysis)
# ---------------------------------------------------------------------------

def get_tna_entries(employee_id=None, cycle_id=None, department_id=None):
    conditions = ['1=1']
    params = []
    if employee_id:
        conditions.append('t.employee_id = %s')
        params.append(employee_id)
    if cycle_id:
        conditions.append('t.cycle_id = %s')
        params.append(cycle_id)
    if department_id:
        conditions.append('emp.department_id = %s')
        params.append(department_id)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT t.*,
                   emp.first_name || ' ' || emp.last_name AS employee_name,
                   d.name AS department_name,
                   c.name AS cycle_name
            FROM learning.lrn_tna_entries t
            JOIN core.employees emp ON emp.id = t.employee_id
            LEFT JOIN core.departments d ON d.id = emp.department_id
            LEFT JOIN performance.perf_cycles c ON c.id = t.cycle_id
            WHERE {' AND '.join(conditions)}
            ORDER BY t.priority, t.created_at DESC
        """, params)
        return cur.fetchall()


def generate_tna_from_ipcr(employee_id, cycle_id):
    """Auto-create TNA entries from IPCR gaps (entries with average_rating < 3.0)."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            SELECT i.performance_indicator, i.average_rating, i.function_type
            FROM performance.perf_ipcr i
            WHERE i.employee_id = %s AND i.cycle_id = %s
              AND i.average_rating IS NOT NULL AND i.average_rating < 3.0
        """, (employee_id, cycle_id))
        gaps = cur.fetchall()

        created = 0
        for g in gaps:
            cur.execute("""
                INSERT INTO learning.lrn_tna_entries
                    (employee_id, cycle_id, competency_gap, recommended_training,
                     priority, source)
                VALUES (%s, %s, %s, %s, %s, 'IPCR')
            """, (
                employee_id, cycle_id,
                f"{g['function_type']}: {g['performance_indicator']} (Rating: {g['average_rating']})",
                f"Training on: {g['performance_indicator'][:100]}",
                'HIGH' if float(g['average_rating']) < 2.0 else 'MEDIUM'
            ))
            created += 1
        return created


# ---------------------------------------------------------------------------
# Scholarships
# ---------------------------------------------------------------------------

def get_scholarships(employee_id=None, status=None):
    conditions = ['1=1']
    params = []
    if employee_id:
        conditions.append('s.employee_id = %s')
        params.append(employee_id)
    if status:
        conditions.append('s.status = %s')
        params.append(status)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT s.*,
                   e.first_name || ' ' || e.last_name AS employee_name,
                   d.name AS department_name
            FROM learning.lrn_scholarships s
            JOIN core.employees e ON e.id = s.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            WHERE {' AND '.join(conditions)}
            ORDER BY s.start_date DESC NULLS LAST
        """, params)
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Geo-tagged Attendance
# ---------------------------------------------------------------------------

def _haversine(lat1, lng1, lat2, lng2):
    """Distance in meters between two lat/lng points."""
    R = 6371000  # Earth radius in meters
    lat1, lng1, lat2, lng2 = map(radians, [lat1, lng1, lat2, lng2])
    dlat = lat2 - lat1
    dlng = lng2 - lng1
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlng/2)**2
    return 2 * R * asin(sqrt(a))


def validate_geo_attendance(enrollment_id, lat, lng, accuracy, device_id=None, ip_address=None):
    """Check-in for training attendance with geo-fencing validation."""
    with get_cursor(commit=True) as cur:
        # Get session venue coordinates (if stored, otherwise just record)
        cur.execute("""
            SELECT e.session_id, e.employee_id, s.venue
            FROM learning.lrn_enrollments e
            JOIN learning.lrn_sessions s ON s.id = e.session_id
            WHERE e.id = %s
        """, (enrollment_id,))
        enrollment = cur.fetchone()
        if not enrollment:
            return None

        is_valid = True
        reason = None
        # If accuracy > 500m, flag as potentially unreliable
        if accuracy and float(accuracy) > 500:
            is_valid = False
            reason = f'GPS accuracy too low: {accuracy}m'

        cur.execute("""
            INSERT INTO learning.lrn_attendance_logs
                (enrollment_id, employee_id, session_id, checkin_lat, checkin_lng,
                 checkin_accuracy_m, device_id, ip_address, is_valid, invalidated_reason)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (enrollment_id, enrollment['employee_id'], enrollment['session_id'],
              lat, lng, accuracy, device_id, ip_address, is_valid, reason))
        return cur.fetchone()


def get_attendance_logs(session_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT al.*, e.first_name || ' ' || e.last_name AS employee_name
            FROM learning.lrn_attendance_logs al
            JOIN core.employees e ON e.id = al.employee_id
            WHERE al.session_id = %s
            ORDER BY al.checked_in_at DESC
        """, (session_id,))
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Narrative Report Form (NRF)
# ---------------------------------------------------------------------------

def get_narrative_reports(employee_id=None, status=None):
    conditions = ['1=1']
    params = []
    if employee_id:
        conditions.append('nr.employee_id = %s')
        params.append(employee_id)
    if status:
        conditions.append('nr.status = %s')
        params.append(status)
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT nr.*,
                   e.first_name || ' ' || e.last_name AS employee_name
            FROM learning.lrn_narrative_reports nr
            JOIN core.employees e ON e.id = nr.employee_id
            WHERE {' AND '.join(conditions)}
            ORDER BY nr.created_at DESC
        """, params)
        return cur.fetchall()


def submit_narrative_report(enrollment_id, employee_id, form_data):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO learning.lrn_narrative_reports
                (enrollment_id, employee_id, training_title, training_dates,
                 venue, facilitator, learning_objectives, key_learnings,
                 application_plans, challenges, recommendations,
                 evaluation_rating, status, submitted_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'SUBMITTED', NOW())
            RETURNING id
        """, (
            enrollment_id, employee_id,
            form_data.get('training_title'), form_data.get('training_dates'),
            form_data.get('venue'), form_data.get('facilitator'),
            form_data.get('learning_objectives'), form_data.get('key_learnings'),
            form_data.get('application_plans'), form_data.get('challenges'),
            form_data.get('recommendations'), form_data.get('evaluation_rating')
        ))
        nrf = cur.fetchone()
        # Link NRF to enrollment
        cur.execute("""
            UPDATE learning.lrn_enrollments
            SET narrative_report_id = %s WHERE id = %s
        """, (nrf['id'], enrollment_id))
        return nrf


def compute_training_hours(employee_id, year):
    """Total training hours per category for compliance reporting."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT p.category,
                   SUM(p.duration_hours) AS total_hours,
                   COUNT(e.id) AS sessions_attended
            FROM learning.lrn_enrollments e
            JOIN learning.lrn_sessions s ON s.id = e.session_id
            JOIN learning.lrn_programs p ON p.id = s.program_id
            WHERE e.employee_id = %s
              AND EXTRACT(YEAR FROM s.session_date) = %s
              AND e.status IN ('COMPLETED', 'ENROLLED')
            GROUP BY p.category
            ORDER BY total_hours DESC
        """, (employee_id, year))
        return cur.fetchall()
