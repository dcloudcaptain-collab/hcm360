"""Workforce Planning Service — scenarios, headcount modeling, cost projections, skill gaps."""
import json
from datetime import date, timedelta
from services.db import get_cursor


def _add_months(d, months):
    """Add months to a date without dateutil."""
    month = d.month - 1 + months
    year = d.year + month // 12
    month = month % 12 + 1
    day = min(d.day, [31,29 if year%4==0 and (year%100!=0 or year%400==0) else 28,31,30,31,30,31,31,30,31,30,31][month-1])
    return date(year, month, day)


# ---------------------------------------------------------------------------
# Scenarios
# ---------------------------------------------------------------------------

def get_scenarios(status=None):
    conditions = []
    params = []
    if status:
        conditions.append('s.status = %s')
        params.append(status)
    where = 'WHERE ' + ' AND '.join(conditions) if conditions else ''
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT s.*, u.display_name AS created_by_name,
                   (SELECT COUNT(*) FROM analytics.wfp_headcount_plans hp WHERE hp.scenario_id = s.id) AS plan_lines,
                   (SELECT COALESCE(SUM(total_cost),0) FROM analytics.wfp_cost_projections cp WHERE cp.scenario_id = s.id) AS projected_cost
            FROM analytics.wfp_scenarios s
            LEFT JOIN core.users u ON u.id = s.created_by
            {where}
            ORDER BY s.updated_at DESC
        """, params)
        return cur.fetchall()


def get_scenario(scenario_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT s.*, u.display_name AS created_by_name
            FROM analytics.wfp_scenarios s
            LEFT JOIN core.users u ON u.id = s.created_by
            WHERE s.id = %s
        """, (scenario_id,))
        scenario = cur.fetchone()
        if not scenario:
            return None

        cur.execute("""
            SELECT hp.*, d.name AS department_name, p.title AS position_title,
                   jg.grade_level AS salary_grade
            FROM analytics.wfp_headcount_plans hp
            LEFT JOIN core.departments d ON d.id = hp.department_id
            LEFT JOIN core.positions p ON p.id = hp.position_id
            LEFT JOIN core.job_grades jg ON jg.id = hp.job_grade_id
            WHERE hp.scenario_id = %s
            ORDER BY hp.period_start, d.name
        """, (scenario_id,))
        headcount_plans = cur.fetchall()

        cur.execute("""
            SELECT * FROM analytics.wfp_cost_projections
            WHERE scenario_id = %s ORDER BY period_start
        """, (scenario_id,))
        cost_projections = cur.fetchall()

        cur.execute("""
            SELECT * FROM analytics.wfp_skill_demands
            WHERE scenario_id = %s ORDER BY priority DESC, skill_name
        """, (scenario_id,))
        skill_demands = cur.fetchall()

    return {
        'scenario': scenario,
        'headcount_plans': headcount_plans,
        'cost_projections': cost_projections,
        'skill_demands': skill_demands,
    }


def create_scenario(company_id, name, description, scenario_type, horizon_months,
                    assumptions=None, created_by=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO analytics.wfp_scenarios
                (company_id, name, description, scenario_type, horizon_months, assumptions, created_by)
            VALUES (%s,%s,%s,%s,%s,%s,%s) RETURNING id
        """, (company_id, name, description, scenario_type, horizon_months,
              json.dumps(assumptions or {}), created_by))
        return cur.fetchone()['id']


def update_scenario_status(scenario_id, status):
    with get_cursor(commit=True) as cur:
        cur.execute("UPDATE analytics.wfp_scenarios SET status = %s, updated_at = NOW() WHERE id = %s",
                    (status, scenario_id))


# ---------------------------------------------------------------------------
# Auto-generate headcount plan from current state
# ---------------------------------------------------------------------------

def generate_headcount_plan(scenario_id):
    with get_cursor(commit=True) as cur:
        cur.execute("SELECT * FROM analytics.wfp_scenarios WHERE id = %s", (scenario_id,))
        scenario = cur.fetchone()
        if not scenario:
            return

        assumptions = scenario['assumptions'] or {}
        attrition_pct = float(assumptions.get('attrition_pct', 5)) / 100
        growth_pct = float(assumptions.get('growth_pct', 3)) / 100
        avg_salary_increase = float(assumptions.get('avg_salary_increase', 5)) / 100

        cur.execute("""
            SELECT d.id AS department_id, d.name AS dept_name,
                   COUNT(e.id) AS current_hc,
                   COALESCE(AVG(e.basic_salary), 0) AS avg_salary
            FROM core.departments d
            LEFT JOIN core.employees e ON e.department_id = d.id AND e.is_active = TRUE
            WHERE d.is_active = TRUE
            GROUP BY d.id, d.name ORDER BY d.name
        """)
        depts = cur.fetchall()

        cur.execute("DELETE FROM analytics.wfp_headcount_plans WHERE scenario_id = %s", (scenario_id,))
        cur.execute("DELETE FROM analytics.wfp_cost_projections WHERE scenario_id = %s", (scenario_id,))

        base = scenario['base_date']
        months = scenario['horizon_months']
        quarters = max(1, months // 3)

        for q in range(quarters):
            period_start = _add_months(base, q * 3)
            period_label = f"Q{(period_start.month - 1) // 3 + 1}-{period_start.year}"
            total_salary = 0
            total_hc = 0

            for dept in depts:
                hc = dept['current_hc'] or 0
                quarter_factor = (1 + growth_pct / 4) ** (q + 1)
                attrition_factor = (1 - attrition_pct / 4) ** (q + 1)
                planned_hc = max(0, round(hc * quarter_factor))
                exits = max(0, round(hc * attrition_pct / 4))
                hires = max(0, planned_hc - round(hc * attrition_factor) + exits)
                avg_cost = float(dept['avg_salary'] or 0) * (1 + avg_salary_increase * q / 4)

                cur.execute("""
                    INSERT INTO analytics.wfp_headcount_plans
                        (scenario_id, department_id, period_label, period_start,
                         current_hc, planned_hc, planned_hires, planned_exits,
                         avg_cost, total_cost)
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                    ON CONFLICT (scenario_id, department_id, period_start)
                    DO UPDATE SET planned_hc=EXCLUDED.planned_hc, planned_hires=EXCLUDED.planned_hires,
                                  planned_exits=EXCLUDED.planned_exits, avg_cost=EXCLUDED.avg_cost,
                                  total_cost=EXCLUDED.total_cost
                """, (scenario_id, dept['department_id'], period_label, period_start,
                      hc, planned_hc, hires, exits, round(avg_cost, 2),
                      round(planned_hc * avg_cost, 2)))

                total_salary += planned_hc * avg_cost
                total_hc += planned_hc

            benefits_pct = float(assumptions.get('benefits_pct', 25)) / 100
            training_pct = float(assumptions.get('training_pct', 2)) / 100
            recruitment_cost_per_hire = float(assumptions.get('recruitment_cost_per_hire', 15000))
            total_hires_q = sum(max(0, round(d['current_hc'] * attrition_pct / 4)) for d in depts)

            cur.execute("""
                INSERT INTO analytics.wfp_cost_projections
                    (scenario_id, period_label, period_start, salary_cost, benefits_cost,
                     training_cost, recruitment_cost, total_cost, headcount, cost_per_head)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT (scenario_id, period_start)
                DO UPDATE SET salary_cost=EXCLUDED.salary_cost, benefits_cost=EXCLUDED.benefits_cost,
                              training_cost=EXCLUDED.training_cost, recruitment_cost=EXCLUDED.recruitment_cost,
                              total_cost=EXCLUDED.total_cost, headcount=EXCLUDED.headcount,
                              cost_per_head=EXCLUDED.cost_per_head
            """, (scenario_id, period_label, period_start,
                  round(total_salary, 2),
                  round(total_salary * benefits_pct, 2),
                  round(total_salary * training_pct, 2),
                  round(total_hires_q * recruitment_cost_per_hire, 2),
                  round(total_salary * (1 + benefits_pct + training_pct) + total_hires_q * recruitment_cost_per_hire, 2),
                  total_hc,
                  round((total_salary * (1 + benefits_pct + training_pct)) / max(1, total_hc), 2)))


# ---------------------------------------------------------------------------
# Skill Demand
# ---------------------------------------------------------------------------

def add_skill_demand(scenario_id, skill_name, current_supply, future_demand,
                     priority='MEDIUM', mitigation=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO analytics.wfp_skill_demands
                (scenario_id, skill_name, current_supply, future_demand, priority, mitigation)
            VALUES (%s,%s,%s,%s,%s,%s) RETURNING id
        """, (scenario_id, skill_name, current_supply, future_demand, priority, mitigation))
        return cur.fetchone()['id']


# ---------------------------------------------------------------------------
# Dashboard Stats
# ---------------------------------------------------------------------------

def get_wfp_stats():
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                (SELECT COUNT(*) FROM analytics.wfp_scenarios) AS total_scenarios,
                (SELECT COUNT(*) FROM analytics.wfp_scenarios WHERE status = 'ACTIVE') AS active_scenarios,
                (SELECT COUNT(*) FROM analytics.wfp_scenarios WHERE status = 'DRAFT') AS draft_scenarios,
                (SELECT COALESCE(SUM(total_cost), 0) FROM analytics.wfp_cost_projections cp
                 JOIN analytics.wfp_scenarios s ON s.id = cp.scenario_id
                 WHERE s.status = 'ACTIVE') AS active_projected_cost,
                (SELECT COUNT(*) FROM analytics.wfp_skill_demands sd
                 JOIN analytics.wfp_scenarios s ON s.id = sd.scenario_id
                 WHERE s.status = 'ACTIVE' AND sd.gap > 0) AS skill_gaps
        """)
        return cur.fetchone()


def get_current_vs_planned():
    """Compare current headcount against active scenario planned headcount."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT d.name AS department,
                   COUNT(e.id) AS current_hc,
                   COALESCE(hp.planned_hc, 0) AS planned_hc,
                   COALESCE(hp.planned_hc, 0) - COUNT(e.id) AS variance
            FROM core.departments d
            LEFT JOIN core.employees e ON e.department_id = d.id AND e.is_active = TRUE
            LEFT JOIN (
                SELECT hp.department_id, hp.planned_hc
                FROM analytics.wfp_headcount_plans hp
                JOIN analytics.wfp_scenarios s ON s.id = hp.scenario_id AND s.status = 'ACTIVE'
                WHERE hp.period_start = (
                    SELECT MIN(period_start) FROM analytics.wfp_headcount_plans
                    WHERE scenario_id = s.id AND period_start >= CURRENT_DATE
                )
            ) hp ON hp.department_id = d.id
            WHERE d.is_active = TRUE
            GROUP BY d.name, hp.planned_hc
            ORDER BY d.name
        """)
        return cur.fetchall()
