"""
G15 — CSC Eligibility (1st/2nd Level × Gender) reporting
G18 — Attrition Risk Scoring (heuristic + ARIA tool)
"""
import json

from services.db import get_cursor


# ══════════════════════════════════════════════════════════════════════
# G15 · CSC Eligibility Reporting
# ══════════════════════════════════════════════════════════════════════
def eligibility_by_level_gender(company_id: int):
    """Return Level × Gender cross-tab with totals."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                COALESCE(ce.level, 'NO_ELIGIBILITY') AS level,
                COUNT(DISTINCT e.id) FILTER (WHERE UPPER(e.gender) = 'MALE')   AS male_count,
                COUNT(DISTINCT e.id) FILTER (WHERE UPPER(e.gender) = 'FEMALE') AS female_count,
                COUNT(DISTINCT e.id) AS total
            FROM core.employees e
            LEFT JOIN recruitment.rec_employee_eligibilities ee ON ee.employee_id = e.id
            LEFT JOIN recruitment.rec_csc_eligibilities ce       ON ce.id = ee.eligibility_id
            WHERE e.company_id = %s
              AND e.status = 'ACTIVE'
            GROUP BY COALESCE(ce.level, 'NO_ELIGIBILITY')
            ORDER BY CASE COALESCE(ce.level, 'NO_ELIGIBILITY')
                WHEN '2ND_LEVEL' THEN 1
                WHEN '1ST_LEVEL' THEN 2
                WHEN 'HONOR_GRAD' THEN 3
                WHEN 'OTHER' THEN 4
                ELSE 5
            END
        """, (company_id,))
        return cur.fetchall()


def eligibility_by_dept_level(company_id: int):
    """Return Department × Level cross-tab."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                d.name AS department,
                COUNT(DISTINCT e.id) FILTER (WHERE ce.level = '1ST_LEVEL') AS first_level,
                COUNT(DISTINCT e.id) FILTER (WHERE ce.level = '2ND_LEVEL') AS second_level,
                COUNT(DISTINCT e.id) FILTER (WHERE ce.level = 'HONOR_GRAD') AS honor_grad,
                COUNT(DISTINCT e.id) AS total
            FROM core.employees e
            LEFT JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN recruitment.rec_employee_eligibilities ee ON ee.employee_id = e.id
            LEFT JOIN recruitment.rec_csc_eligibilities ce       ON ce.id = ee.eligibility_id
            WHERE e.company_id = %s AND e.status = 'ACTIVE'
            GROUP BY d.name
            ORDER BY total DESC NULLS LAST
        """, (company_id,))
        return cur.fetchall()


def eligibility_detail_list(company_id: int, level_filter: str = None):
    """List of individual employees with their highest eligibility."""
    with get_cursor() as cur:
        sql = """
            SELECT e.id, e.employee_no,
                   CONCAT_WS(' ', e.first_name, e.middle_name, e.last_name) AS full_name,
                   e.gender,
                   d.name AS department_name,
                   p.title AS position_title,
                   STRING_AGG(DISTINCT ce.name, ', ' ORDER BY ce.name) AS eligibilities,
                   STRING_AGG(DISTINCT ce.level, ', ' ORDER BY ce.level) AS levels
            FROM core.employees e
            LEFT JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.positions p   ON p.id = e.position_id
            LEFT JOIN recruitment.rec_employee_eligibilities ee ON ee.employee_id = e.id
            LEFT JOIN recruitment.rec_csc_eligibilities ce       ON ce.id = ee.eligibility_id
            WHERE e.company_id = %s AND e.status = 'ACTIVE'
        """
        params = [company_id]
        if level_filter:
            sql += " AND ce.level = %s"
            params.append(level_filter)
        sql += """
            GROUP BY e.id, e.employee_no, e.first_name, e.middle_name, e.last_name,
                     e.gender, d.name, p.title
            ORDER BY full_name
            LIMIT 500
        """
        cur.execute(sql, tuple(params))
        return cur.fetchall()


# ══════════════════════════════════════════════════════════════════════
# G18 · Attrition Risk Scoring
# ══════════════════════════════════════════════════════════════════════
# Corrected heuristic that uses real column names (date_hired, not hire_date)
# and tolerates missing leave_mgmt.leave_balances / performance.reviews tables.
def predict_batch(company_id: int) -> dict:
    """
    Score all active employees for attrition risk using a 5-factor heuristic.
    Writes to ai.ml_predictions with prediction_type='ATTRITION'.
    """
    inserted = 0
    scored = []
    with get_cursor(commit=True) as cur:
        cur.execute("""
            SELECT e.id AS employee_id,
                   e.first_name || ' ' || e.last_name AS full_name,
                   EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.date_hired))::int AS tenure_years,
                   e.date_hired,
                   e.status,
                   COALESCE(
                     (SELECT SUM(lb.balance) FROM leave_mgmt.lv_balances lb
                      WHERE lb.employee_id = e.id), 0) AS leave_balance,
                   COALESCE(
                     (SELECT COUNT(*) FROM learning.lrn_enrollments le
                      WHERE le.employee_id = e.id
                        AND le.created_at > CURRENT_DATE - INTERVAL '365 days'), 0)
                   AS recent_trainings,
                   (SELECT COUNT(*) FROM attendance.att_daily ad
                    WHERE ad.employee_id = e.id
                      AND ad.work_date > CURRENT_DATE - INTERVAL '90 days'
                      AND ad.hours_late > 0) AS recent_late_days,
                   (SELECT COUNT(*) FROM leave_mgmt.lv_requests lr
                    WHERE lr.employee_id = e.id
                      AND lr.date_from > CURRENT_DATE - INTERVAL '180 days'
                      AND lr.status = 'APPROVED') AS recent_leaves
            FROM core.employees e
            WHERE e.company_id = %s AND e.status = 'ACTIVE'
        """, (company_id,))
        rows = cur.fetchall()

        for r in rows:
            score = 0.0
            factors = []
            tenure = r.get('tenure_years') or 0

            if tenure < 1:
                score += 0.25
                factors.append(f'Short tenure ({tenure} yr)')
            elif tenure > 10:
                score += 0.10
                factors.append('Long tenure (retirement risk)')

            if (r.get('leave_balance') or 0) <= 2:
                score += 0.15
                factors.append('Low leave balance')

            if (r.get('recent_trainings') or 0) == 0:
                score += 0.20
                factors.append('No recent training')

            if (r.get('recent_late_days') or 0) > 10:
                score += 0.20
                factors.append(f'Frequent tardiness ({r["recent_late_days"]} late days / 90d)')

            if (r.get('recent_leaves') or 0) > 8:
                score += 0.15
                factors.append(f'Frequent leaves ({r["recent_leaves"]} in 6mo)')

            score = min(score, 1.0)
            if score >= 0.6:
                risk_level = 'HIGH'
            elif score >= 0.3:
                risk_level = 'MEDIUM'
            else:
                risk_level = 'LOW'

            try:
                cur.execute("""
                    INSERT INTO ai.ai_risk_scores
                        (employee_id, score_date, risk_type, risk_score,
                         risk_level, confidence, model_version, factors)
                    VALUES (%s, CURRENT_DATE, 'ATTRITION', %s, %s,
                            0.75, 'heuristic-v2', %s)
                    ON CONFLICT (employee_id, score_date, risk_type) DO UPDATE
                        SET risk_score  = EXCLUDED.risk_score,
                            risk_level  = EXCLUDED.risk_level,
                            factors     = EXCLUDED.factors,
                            created_at  = NOW()
                """, (r['employee_id'], round(score, 3),
                      risk_level, json.dumps({'factors': factors,
                                              'tenure_years': tenure})))
                inserted += 1
            except Exception:
                pass

            scored.append({
                'employee_id': r['employee_id'],
                'full_name': r['full_name'],
                'tenure_years': tenure,
                'risk_score': round(score, 3),
                'risk_level': risk_level,
                'factors': factors,
            })
    return {'scored': len(scored), 'inserted': inserted, 'results': scored}


def attrition_list(company_id: int, risk_level: str = None, limit: int = 200):
    """Return employees with their current attrition prediction."""
    with get_cursor() as cur:
        sql = """
            SELECT p.employee_id, p.risk_score, p.risk_level, p.factors,
                   p.created_at AS predicted_at,
                   e.employee_no,
                   CONCAT_WS(' ', e.first_name, e.middle_name, e.last_name) AS full_name,
                   e.gender, e.date_hired,
                   d.name AS department_name,
                   pos.title AS position_title,
                   EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.date_hired))::int AS tenure_years
            FROM ai.ai_risk_scores p
            JOIN core.employees e ON e.id = p.employee_id
            LEFT JOIN core.departments d  ON d.id = e.department_id
            LEFT JOIN core.positions pos  ON pos.id = e.position_id
            WHERE p.risk_type = 'ATTRITION'
              AND p.score_date = (SELECT MAX(score_date) FROM ai.ai_risk_scores
                                   WHERE risk_type = 'ATTRITION'
                                     AND employee_id = p.employee_id)
              AND e.company_id = %s
        """
        params = [company_id]
        if risk_level:
            sql += " AND p.risk_level = %s"
            params.append(risk_level)
        sql += """
            ORDER BY p.risk_score DESC NULLS LAST, e.last_name
            LIMIT %s
        """
        params.append(limit)
        try:
            cur.execute(sql, tuple(params))
            rows = cur.fetchall()
            # Normalize factors JSONB -> list for template
            for r in rows:
                f = r.get('factors')
                if isinstance(f, str):
                    try:
                        f = json.loads(f)
                    except Exception:
                        f = {}
                if isinstance(f, dict) and 'factors' in f:
                    r['factors'] = f['factors']
                elif isinstance(f, list):
                    r['factors'] = f
                else:
                    r['factors'] = []
            return rows
        except Exception:
            return []


def attrition_summary(company_id: int):
    """KPI summary: high/medium/low counts + gender split."""
    with get_cursor() as cur:
        try:
            cur.execute("""
                SELECT
                    COUNT(*) FILTER (WHERE risk_level = 'HIGH')   AS high_count,
                    COUNT(*) FILTER (WHERE risk_level = 'MEDIUM') AS medium_count,
                    COUNT(*) FILTER (WHERE risk_level = 'LOW')    AS low_count,
                    COUNT(*) FILTER (WHERE risk_level = 'HIGH' AND UPPER(e.gender) = 'MALE')   AS high_male,
                    COUNT(*) FILTER (WHERE risk_level = 'HIGH' AND UPPER(e.gender) = 'FEMALE') AS high_female,
                    MAX(p.created_at) AS last_scan
                FROM ai.ai_risk_scores p
                JOIN core.employees e ON e.id = p.employee_id
                WHERE p.risk_type = 'ATTRITION'
                  AND e.company_id = %s
            """, (company_id,))
            return dict(cur.fetchone())
        except Exception:
            return {'high_count': 0, 'medium_count': 0, 'low_count': 0,
                    'high_male': 0, 'high_female': 0, 'last_scan': None}
