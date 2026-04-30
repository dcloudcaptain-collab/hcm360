"""Feedback service — continuous feedback and 360 reviews."""
from services.db import get_cursor


# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------

def get_feedback_dashboard(employee_id=None):
    """Return stats: total feedback given/received, avg rating, pending requests."""
    with get_cursor() as cur:
        stats = {}

        if employee_id:
            cur.execute("""
                SELECT COUNT(*) AS total_given
                FROM performance.feedback_responses
                WHERE author_id = %s
            """, (employee_id,))
            stats['total_given'] = cur.fetchone()['total_given']

            cur.execute("""
                SELECT COUNT(*) AS total_received,
                       ROUND(AVG(rating)::numeric, 2) AS avg_rating
                FROM performance.feedback_responses
                WHERE subject_id = %s
            """, (employee_id,))
            row = cur.fetchone()
            stats['total_received'] = row['total_received']
            stats['avg_rating'] = float(row['avg_rating']) if row['avg_rating'] else 0

            cur.execute("""
                SELECT COUNT(*) AS pending
                FROM performance.feedback_requests
                WHERE respondent_id = %s AND status = 'PENDING'
            """, (employee_id,))
            stats['pending_requests'] = cur.fetchone()['pending']
        else:
            cur.execute("SELECT COUNT(*) AS c FROM performance.feedback_responses")
            stats['total_given'] = cur.fetchone()['c']
            stats['total_received'] = stats['total_given']
            cur.execute("""
                SELECT ROUND(AVG(rating)::numeric, 2) AS avg_rating
                FROM performance.feedback_responses
            """)
            row = cur.fetchone()
            stats['avg_rating'] = float(row['avg_rating']) if row['avg_rating'] else 0
            cur.execute("""
                SELECT COUNT(*) AS c
                FROM performance.feedback_requests WHERE status = 'PENDING'
            """)
            stats['pending_requests'] = cur.fetchone()['c']

        return stats


# ---------------------------------------------------------------------------
# Request Feedback
# ---------------------------------------------------------------------------

def request_feedback(requester_id, subject_id, respondent_id, feedback_type, message, due_date, cycle_id=None):
    """Create a feedback request. respondent_id = who should give the feedback."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO performance.feedback_requests
                (requester_id, subject_id, respondent_id, feedback_type, message, due_date, cycle_id, status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, 'PENDING')
            RETURNING id
        """, (requester_id, subject_id, respondent_id, feedback_type, message, due_date, cycle_id))
        return cur.fetchone()['id']


# ---------------------------------------------------------------------------
# Pending Requests
# ---------------------------------------------------------------------------

def get_pending_requests(employee_id):
    """Return requests where the employee is the designated author (responder)."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT fr.*,
                   es.full_name AS subject_name,
                   er.full_name AS requester_name
            FROM performance.feedback_requests fr
            LEFT JOIN core.v_employees_full es ON es.id = fr.subject_id
            LEFT JOIN core.v_employees_full er ON er.id = fr.requester_id
            WHERE fr.respondent_id = %s AND fr.status = 'PENDING'
            ORDER BY fr.due_date ASC NULLS LAST, fr.created_at DESC
        """, (employee_id,))
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Submit Feedback Response
# ---------------------------------------------------------------------------

def submit_feedback(request_id, author_id, subject_id, feedback_type, rating,
                    strengths, improvements, comments, is_anonymous, visibility):
    """Insert into feedback_responses and update the request status."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO performance.feedback_responses
                (request_id, author_id, subject_id, feedback_type, rating,
                 strengths, improvements, comments, is_anonymous, visibility)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (request_id, author_id, subject_id, feedback_type, rating,
              strengths, improvements, comments, is_anonymous, visibility))
        response_id = cur.fetchone()['id']

        if request_id:
            cur.execute("""
                UPDATE performance.feedback_requests
                SET status = 'COMPLETED'
                WHERE id = %s
            """, (request_id,))

        return response_id


# ---------------------------------------------------------------------------
# Feedback Received / Given
# ---------------------------------------------------------------------------

def get_feedback_received(employee_id):
    """All feedback where subject_id = employee_id."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT fr.*,
                   CASE WHEN fr.is_anonymous THEN 'Anonymous' ELSE ea.full_name END AS author_name
            FROM performance.feedback_responses fr
            LEFT JOIN core.v_employees_full ea ON ea.id = fr.author_id
            WHERE fr.subject_id = %s
            ORDER BY fr.created_at DESC
        """, (employee_id,))
        return cur.fetchall()


def get_feedback_given(employee_id):
    """All feedback where author_id = employee_id."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT fr.*,
                   es.full_name AS subject_name
            FROM performance.feedback_responses fr
            LEFT JOIN core.v_employees_full es ON es.id = fr.subject_id
            WHERE fr.author_id = %s
            ORDER BY fr.created_at DESC
        """, (employee_id,))
        return cur.fetchall()


# ---------------------------------------------------------------------------
# 360 Review
# ---------------------------------------------------------------------------

def get_360_review(employee_id, cycle_id):
    """Get or create review_360 row with aggregated stats."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            SELECT * FROM performance.review_360
            WHERE employee_id = %s AND cycle_id = %s
        """, (employee_id, cycle_id))
        review = cur.fetchone()

        # Aggregate from responses
        cur.execute("""
            SELECT COUNT(*) AS total_responses,
                   ROUND(AVG(rating)::numeric, 2) AS avg_rating,
                   COUNT(*) FILTER (WHERE feedback_type = 'PEER') AS peer_count,
                   COUNT(*) FILTER (WHERE feedback_type = 'UPWARD') AS upward_count,
                   COUNT(*) FILTER (WHERE feedback_type = 'DOWNWARD') AS downward_count,
                   ROUND(AVG(rating) FILTER (WHERE feedback_type = 'PEER')::numeric, 2) AS peer_avg,
                   ROUND(AVG(rating) FILTER (WHERE feedback_type = 'UPWARD')::numeric, 2) AS upward_avg,
                   ROUND(AVG(rating) FILTER (WHERE feedback_type = 'DOWNWARD')::numeric, 2) AS downward_avg
            FROM performance.feedback_responses
            WHERE subject_id = %s
              AND (cycle_id = %s OR cycle_id IS NULL)
        """, (employee_id, cycle_id))
        agg = cur.fetchone()

        if review:
            cur.execute("""
                UPDATE performance.review_360
                SET total_responses = %s, avg_rating = %s, updated_at = NOW()
                WHERE id = %s
            """, (agg['total_responses'], agg['avg_rating'], review['id']))
            review.update(dict(agg))
        else:
            cur.execute("""
                INSERT INTO performance.review_360
                    (employee_id, cycle_id, total_responses, avg_rating)
                VALUES (%s, %s, %s, %s)
                RETURNING *
            """, (employee_id, cycle_id, agg['total_responses'], agg['avg_rating']))
            review = cur.fetchone()
            review.update(dict(agg))

        return review


def get_360_summary(employee_id):
    """Latest 360 review with response breakdown by type."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT r.*
            FROM performance.review_360 r
            WHERE r.employee_id = %s
            ORDER BY r.created_at DESC
            LIMIT 1
        """, (employee_id,))
        review = cur.fetchone()
        if not review:
            return None

        cur.execute("""
            SELECT feedback_type,
                   COUNT(*) AS cnt,
                   ROUND(AVG(rating)::numeric, 2) AS avg_rating
            FROM performance.feedback_responses
            WHERE subject_id = %s
            GROUP BY feedback_type
        """, (employee_id,))
        breakdown = cur.fetchall()
        review['breakdown'] = breakdown
        return review


# ---------------------------------------------------------------------------
# Decline Request
# ---------------------------------------------------------------------------

def decline_request(request_id):
    """Set request status to DECLINED."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE performance.feedback_requests
            SET status = 'DECLINED'
            WHERE id = %s
        """, (request_id,))
