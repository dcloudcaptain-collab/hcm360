"""Demographics service — HR workforce profile reports with Male/Female breakdown.
All 10 categories required by CSC PRIME-HRM Level 2."""
from services.db import get_cursor


def gender_profile(company_id):
    """Total Male/Female overall and by department."""
    with get_cursor() as cur:
        # Overall
        cur.execute("""
            SELECT 'Overall' AS category,
                   COUNT(*) FILTER (WHERE e.gender = 'Male') AS male_count,
                   COUNT(*) FILTER (WHERE e.gender = 'Female') AS female_count,
                   COUNT(*) AS total
            FROM core.employees e
            WHERE e.company_id = %s AND e.is_active = TRUE
        """, (company_id,))
        overall = cur.fetchall()

        # By department
        cur.execute("""
            SELECT d.name AS category,
                   COUNT(*) FILTER (WHERE e.gender = 'Male') AS male_count,
                   COUNT(*) FILTER (WHERE e.gender = 'Female') AS female_count,
                   COUNT(*) AS total
            FROM core.employees e
            LEFT JOIN core.departments d ON d.id = e.department_id
            WHERE e.company_id = %s AND e.is_active = TRUE
            GROUP BY d.name ORDER BY d.name
        """, (company_id,))
        by_dept = cur.fetchall()
        return list(overall) + list(by_dept)


def age_profile(company_id):
    """Age distribution by gender in 10-year brackets."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                CASE
                    WHEN age < 20 THEN 'Under 20'
                    WHEN age BETWEEN 20 AND 29 THEN '20-29'
                    WHEN age BETWEEN 30 AND 39 THEN '30-39'
                    WHEN age BETWEEN 40 AND 49 THEN '40-49'
                    WHEN age BETWEEN 50 AND 59 THEN '50-59'
                    ELSE '60 and above'
                END AS category,
                COUNT(*) FILTER (WHERE gender = 'Male') AS male_count,
                COUNT(*) FILTER (WHERE gender = 'Female') AS female_count,
                COUNT(*) AS total
            FROM (
                SELECT gender, EXTRACT(YEAR FROM AGE(date_of_birth))::INT AS age
                FROM core.employees
                WHERE company_id = %s AND is_active = TRUE AND date_of_birth IS NOT NULL
            ) sub
            GROUP BY 1
            ORDER BY MIN(age)
        """, (company_id,))
        return cur.fetchall()


def appointment_status(company_id):
    """Number by employment status/type (Permanent, Casual, etc.) by gender."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT COALESCE(et.name, e.status, 'Unspecified') AS category,
                   COUNT(*) FILTER (WHERE e.gender = 'Male') AS male_count,
                   COUNT(*) FILTER (WHERE e.gender = 'Female') AS female_count,
                   COUNT(*) AS total
            FROM core.employees e
            LEFT JOIN core.employment_types et ON et.id = e.employment_type_id
            WHERE e.company_id = %s AND e.is_active = TRUE
            GROUP BY 1 ORDER BY total DESC
        """, (company_id,))
        return cur.fetchall()


def rank_classification(company_id):
    """Rank-and-File vs Officer/Supervisory by gender."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                CASE
                    WHEN jg.grade_level >= 24 THEN 'Executive / Managerial'
                    WHEN jg.grade_level >= 18 THEN 'Officer / Supervisory'
                    ELSE 'Rank-and-File'
                END AS category,
                COUNT(*) FILTER (WHERE e.gender = 'Male') AS male_count,
                COUNT(*) FILTER (WHERE e.gender = 'Female') AS female_count,
                COUNT(*) AS total
            FROM core.employees e
            LEFT JOIN core.job_grades jg ON jg.id = e.job_grade_id
            WHERE e.company_id = %s AND e.is_active = TRUE
            GROUP BY 1 ORDER BY MIN(COALESCE(jg.grade_level, 0))
        """, (company_id,))
        return cur.fetchall()


def educational_attainment(company_id):
    """Highest education level by gender."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                COALESCE(ed.level, 'Not Specified') AS category,
                COUNT(*) FILTER (WHERE e.gender = 'Male') AS male_count,
                COUNT(*) FILTER (WHERE e.gender = 'Female') AS female_count,
                COUNT(*) AS total
            FROM core.employees e
            LEFT JOIN (
                SELECT DISTINCT ON (employee_id) employee_id, level
                FROM core.emp_education
                ORDER BY employee_id, is_highest DESC NULLS LAST, year_to DESC NULLS LAST
            ) ed ON ed.employee_id = e.id
            WHERE e.company_id = %s AND e.is_active = TRUE
            GROUP BY 1
            ORDER BY total DESC
        """, (company_id,))
        return cur.fetchall()


def eligibility_profile(company_id):
    """CSC eligibility level distribution by gender."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                CASE
                    WHEN ce.code IN ('CS-PROF', 'RA1080', 'BOARD') THEN '2nd Level (Professional)'
                    WHEN ce.code IN ('CS-SUBPRO', 'PD907') THEN '1st Level (Sub-Professional)'
                    WHEN ce.code = 'HONOR' THEN 'Honor Graduate'
                    ELSE COALESCE(ce.name, 'No Eligibility')
                END AS category,
                COUNT(DISTINCT e.id) FILTER (WHERE e.gender = 'Male') AS male_count,
                COUNT(DISTINCT e.id) FILTER (WHERE e.gender = 'Female') AS female_count,
                COUNT(DISTINCT e.id) AS total
            FROM core.employees e
            LEFT JOIN recruitment.rec_employee_eligibilities ee ON ee.employee_id = e.id
            LEFT JOIN recruitment.rec_csc_eligibilities ce ON ce.id = ee.eligibility_id
            WHERE e.company_id = %s AND e.is_active = TRUE
            GROUP BY 1 ORDER BY total DESC
        """, (company_id,))
        return cur.fetchall()


def plantilla_summary(company_id):
    """Filled vs Vacant plantilla positions with gender of incumbent."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                CASE WHEN pi.status = 'FILLED' THEN 'Filled' ELSE 'Vacant' END AS category,
                COUNT(*) FILTER (WHERE e.gender = 'Male') AS male_count,
                COUNT(*) FILTER (WHERE e.gender = 'Female') AS female_count,
                COUNT(*) AS total
            FROM recruitment.rec_plantilla_items pi
            LEFT JOIN core.employees e ON e.position_id = pi.position_id AND e.is_active = TRUE
            WHERE pi.company_id = %s
            GROUP BY 1 ORDER BY 1
        """, (company_id,))
        return cur.fetchall()


def salary_grade_distribution(company_id):
    """Personnel count per salary grade level by gender."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT 'SG ' || jg.grade_level AS category,
                   COUNT(*) FILTER (WHERE e.gender = 'Male') AS male_count,
                   COUNT(*) FILTER (WHERE e.gender = 'Female') AS female_count,
                   COUNT(*) AS total
            FROM core.employees e
            JOIN core.job_grades jg ON jg.id = e.job_grade_id
            WHERE e.company_id = %s AND e.is_active = TRUE
            GROUP BY jg.grade_level ORDER BY jg.grade_level
        """, (company_id,))
        return cur.fetchall()


def training_participation(company_id, year=None):
    """Training history count by gender."""
    yr_condition = "AND EXTRACT(YEAR FROM s.session_date) = %s" if year else ""
    params = [company_id, year] if year else [company_id]
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT COALESCE(p.category, 'General') AS category,
                   COUNT(DISTINCT en.id) FILTER (WHERE e.gender = 'Male') AS male_count,
                   COUNT(DISTINCT en.id) FILTER (WHERE e.gender = 'Female') AS female_count,
                   COUNT(DISTINCT en.id) AS total
            FROM learning.lrn_enrollments en
            JOIN learning.lrn_sessions s ON s.id = en.session_id
            JOIN learning.lrn_programs p ON p.id = s.program_id
            JOIN core.employees e ON e.id = en.employee_id
            WHERE e.company_id = %s {yr_condition}
            GROUP BY p.category ORDER BY total DESC
        """, params)
        return cur.fetchall()
