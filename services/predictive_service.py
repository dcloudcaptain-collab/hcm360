"""AI Predictive Analytics Service — placeholder logic using SQL aggregates."""
import json
from services.db import get_cursor


# ---------------------------------------------------------------------------
# Seed ML model (call once during setup)
# ---------------------------------------------------------------------------

def seed_attrition_model():
    """Create/seed one ml_model row for attrition with accuracy 0.82."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO ai.ml_models (name, model_type, version, accuracy, parameters, status)
            VALUES ('Employee Attrition Predictor', 'CLASSIFICATION', '1.0', 0.82,
                    '{"features": ["tenure", "leave_balance", "training_hours", "performance_rating"], "algorithm": "logistic_regression"}'::jsonb,
                    'ACTIVE')
            ON CONFLICT DO NOTHING
        """)


# ---------------------------------------------------------------------------
# Attrition Risk
# ---------------------------------------------------------------------------

def predict_attrition_risk(employee_id=None):
    """Compute attrition risk score (0-1) based on heuristics.

    Factors: tenure < 1yr, low leave balance, no recent training, low performance.
    Results stored in ai.ml_predictions.
    """
    conditions = []
    params = []
    if employee_id:
        conditions.append('emp.id = %s')
        params.append(employee_id)
    where = 'WHERE ' + ' AND '.join(conditions) if conditions else ''

    with get_cursor(commit=True) as cur:
        # Get model id
        cur.execute("SELECT id FROM ai.ml_models WHERE name = 'Employee Attrition Predictor' LIMIT 1")
        model_row = cur.fetchone()
        model_id = model_row['id'] if model_row else None

        cur.execute(f"""
            SELECT emp.id AS employee_id,
                   emp.hire_date,
                   EXTRACT(YEAR FROM AGE(CURRENT_DATE, emp.hire_date)) AS tenure_years,
                   COALESCE(lb.balance, 0) AS leave_balance,
                   COALESCE(te.training_count, 0) AS recent_trainings,
                   COALESCE(pr.overall_rating, 3) AS perf_rating
            FROM core.employees emp
            LEFT JOIN LATERAL (
                SELECT SUM(balance) AS balance FROM leave_mgmt.leave_balances
                WHERE employee_id = emp.id
            ) lb ON TRUE
            LEFT JOIN LATERAL (
                SELECT COUNT(*) AS training_count FROM learning.enrollments le
                WHERE le.employee_id = emp.id AND le.enrolled_at > CURRENT_DATE - INTERVAL '1 year'
            ) te ON TRUE
            LEFT JOIN LATERAL (
                SELECT overall_rating FROM performance.review_cycles rc
                JOIN performance.reviews r ON r.cycle_id = rc.id
                WHERE r.employee_id = emp.id
                ORDER BY rc.end_date DESC LIMIT 1
            ) pr ON TRUE
            {where}
        """, params)
        employees = cur.fetchall()

        predictions = []
        for emp in employees:
            score = 0.0
            factors = []

            # Tenure < 1 year -> +0.25
            tenure = emp['tenure_years'] or 0
            if tenure < 1:
                score += 0.25
                factors.append('Short tenure (<1yr)')

            # Low leave balance -> +0.20
            if (emp['leave_balance'] or 0) <= 2:
                score += 0.20
                factors.append('Low leave balance')

            # No recent training -> +0.20
            if (emp['recent_trainings'] or 0) == 0:
                score += 0.20
                factors.append('No recent training')

            # Low performance rating -> +0.35
            perf = emp['perf_rating'] or 3
            if perf <= 2:
                score += 0.35
                factors.append('Low performance rating')
            elif perf <= 3:
                score += 0.15
                factors.append('Average performance')

            score = min(score, 1.0)
            risk_level = 'HIGH' if score >= 0.6 else ('MEDIUM' if score >= 0.3 else 'LOW')

            cur.execute("""
                INSERT INTO ai.ml_predictions
                    (model_id, employee_id, prediction_type, risk_score, risk_level, factors, predicted_at)
                VALUES (%s, %s, 'ATTRITION', %s, %s, %s, NOW())
                ON CONFLICT (employee_id, prediction_type) WHERE prediction_type = 'ATTRITION'
                DO UPDATE SET risk_score = EXCLUDED.risk_score, risk_level = EXCLUDED.risk_level,
                              factors = EXCLUDED.factors, predicted_at = NOW()
                RETURNING id
            """, (model_id, emp['employee_id'], round(score, 3), risk_level,
                  json.dumps(factors)))
            predictions.append({
                'employee_id': emp['employee_id'],
                'risk_score': round(score, 3),
                'risk_level': risk_level,
                'factors': factors
            })

        return predictions


# ---------------------------------------------------------------------------
# Absence Risk
# ---------------------------------------------------------------------------

def predict_absence_risk(employee_id=None):
    """Compute absence risk based on recent absence patterns."""
    conditions = []
    params = []
    if employee_id:
        conditions.append('emp.id = %s')
        params.append(employee_id)
    where = 'WHERE ' + ' AND '.join(conditions) if conditions else ''

    with get_cursor(commit=True) as cur:
        cur.execute("SELECT id FROM ai.ml_models WHERE model_type = 'CLASSIFICATION' LIMIT 1")
        model_row = cur.fetchone()
        model_id = model_row['id'] if model_row else None

        cur.execute(f"""
            SELECT emp.id AS employee_id,
                   COALESCE(abs_count.cnt, 0) AS recent_absences,
                   COALESCE(late.cnt, 0) AS recent_lates
            FROM core.employees emp
            LEFT JOIN LATERAL (
                SELECT COUNT(*) AS cnt FROM leave_mgmt.leave_requests lr
                WHERE lr.employee_id = emp.id
                  AND lr.start_date > CURRENT_DATE - INTERVAL '3 months'
                  AND lr.leave_type_id IN (SELECT id FROM leave_mgmt.leave_types WHERE code = 'SL')
            ) abs_count ON TRUE
            LEFT JOIN LATERAL (
                SELECT COUNT(*) AS cnt FROM attendance.daily_logs dl
                WHERE dl.employee_id = emp.id
                  AND dl.log_date > CURRENT_DATE - INTERVAL '1 month'
                  AND dl.status = 'LATE'
            ) late ON TRUE
            {where}
        """, params)
        employees = cur.fetchall()

        predictions = []
        for emp in employees:
            score = 0.0
            factors = []
            if (emp['recent_absences'] or 0) >= 3:
                score += 0.4
                factors.append('Frequent sick leaves')
            elif (emp['recent_absences'] or 0) >= 1:
                score += 0.15
                factors.append('Some recent absences')
            if (emp['recent_lates'] or 0) >= 5:
                score += 0.35
                factors.append('Frequent tardiness')
            elif (emp['recent_lates'] or 0) >= 2:
                score += 0.15
                factors.append('Occasional tardiness')

            score = min(score, 1.0)
            risk_level = 'HIGH' if score >= 0.6 else ('MEDIUM' if score >= 0.3 else 'LOW')

            cur.execute("""
                INSERT INTO ai.ml_predictions
                    (model_id, employee_id, prediction_type, risk_score, risk_level, factors, predicted_at)
                VALUES (%s, %s, 'ABSENCE', %s, %s, %s, NOW())
                ON CONFLICT (employee_id, prediction_type) WHERE prediction_type = 'ABSENCE'
                DO UPDATE SET risk_score = EXCLUDED.risk_score, risk_level = EXCLUDED.risk_level,
                              factors = EXCLUDED.factors, predicted_at = NOW()
            """, (model_id, emp['employee_id'], round(score, 3), risk_level,
                  json.dumps(factors)))
            predictions.append({
                'employee_id': emp['employee_id'],
                'risk_score': round(score, 3),
                'risk_level': risk_level,
                'factors': factors
            })

        return predictions


# ---------------------------------------------------------------------------
# Query Predictions
# ---------------------------------------------------------------------------

def get_predictions(prediction_type=None, risk_level=None):
    """List predictions with optional filters."""
    conditions = []
    params = []
    if prediction_type:
        conditions.append('p.prediction_type = %s')
        params.append(prediction_type)
    if risk_level:
        conditions.append('p.risk_level = %s')
        params.append(risk_level)
    where = 'WHERE ' + ' AND '.join(conditions) if conditions else ''
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT p.*,
                   emp.first_name || ' ' || emp.last_name AS employee_name,
                   emp.employee_code,
                   d.name AS department_name
            FROM ai.ml_predictions p
            JOIN core.employees emp ON emp.id = p.employee_id
            LEFT JOIN core.departments d ON d.id = emp.department_id
            {where}
            ORDER BY p.risk_score DESC
        """, params)
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Risk Dashboard
# ---------------------------------------------------------------------------

def get_risk_dashboard():
    """Stats: high risk count, avg score by dept, top risk factors."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                COUNT(*) FILTER (WHERE risk_level = 'HIGH') AS high_risk_count,
                COUNT(*) FILTER (WHERE risk_level = 'MEDIUM') AS medium_risk_count,
                COUNT(*) FILTER (WHERE risk_level = 'LOW') AS low_risk_count,
                ROUND(AVG(risk_score)::numeric, 3) AS avg_risk_score
            FROM ai.ml_predictions
            WHERE prediction_type = 'ATTRITION'
        """)
        summary = cur.fetchone()

        cur.execute("""
            SELECT d.name AS department_name,
                   ROUND(AVG(p.risk_score)::numeric, 3) AS avg_score,
                   COUNT(*) FILTER (WHERE p.risk_level = 'HIGH') AS high_count
            FROM ai.ml_predictions p
            JOIN core.employees emp ON emp.id = p.employee_id
            JOIN core.departments d ON d.id = emp.department_id
            WHERE p.prediction_type = 'ATTRITION'
            GROUP BY d.name
            ORDER BY AVG(p.risk_score) DESC
        """)
        by_dept = cur.fetchall()

    return summary, by_dept


# ---------------------------------------------------------------------------
# Refresh All
# ---------------------------------------------------------------------------

def refresh_all_predictions():
    """Run all prediction types for all employees."""
    attrition = predict_attrition_risk()
    absence = predict_absence_risk()
    return {
        'attrition': len(attrition),
        'absence': len(absence),
    }


# ---------------------------------------------------------------------------
# Model Info
# ---------------------------------------------------------------------------

def get_model_info():
    """List ml_models with accuracy."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM ai.ml_models ORDER BY created_at DESC
        """)
        return cur.fetchall()
