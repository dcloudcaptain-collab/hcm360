"""Skills & Career Development Blueprint."""
from flask import Blueprint, render_template, request, redirect, url_for, flash, session

from modules.skills_career import skills_service as svc

skills_bp = Blueprint('skills', __name__,
                      url_prefix='/skills',
                      template_folder='../../templates/skills_career')


# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------

@skills_bp.route('/')
def index():
    stats, top_gaps = svc.get_skill_stats()
    heatmap = svc.get_org_skill_heatmap()
    return render_template('skills_career/index.html',
                           stats=stats, top_gaps=top_gaps, heatmap=heatmap)


# ---------------------------------------------------------------------------
# Skill Catalog
# ---------------------------------------------------------------------------

@skills_bp.route('/catalog')
def catalog():
    categories = svc.get_skill_categories()
    skills = svc.get_skill_definitions()
    return render_template('skills_career/catalog.html',
                           categories=categories, skills=skills)


# ---------------------------------------------------------------------------
# My Skills (ESS)
# ---------------------------------------------------------------------------

@skills_bp.route('/my')
def my_skills():
    emp_id = session.get('employee_id')
    if not emp_id:
        flash('No employee record linked to your account.', 'warning')
        return redirect(url_for('dashboard.index'))
    skills = svc.get_employee_skills(emp_id)
    return render_template('skills_career/my_skills.html', skills=skills)


@skills_bp.route('/my/rate', methods=['POST'])
def my_rate():
    emp_id = session.get('employee_id')
    if not emp_id:
        flash('No employee record linked.', 'warning')
        return redirect(url_for('skills.my_skills'))
    skill_id = request.form.get('skill_id', type=int)
    rating = request.form.get('self_rating', type=int)
    if skill_id and rating:
        svc.rate_skill(emp_id, skill_id, self_rating=rating)
        flash('Skill rating saved.', 'success')
    return redirect(url_for('skills.my_skills'))


# ---------------------------------------------------------------------------
# Employee Skill Profile (Manager/HR)
# ---------------------------------------------------------------------------

@skills_bp.route('/employee/<int:employee_id>')
def employee_skills(employee_id):
    skills = svc.get_employee_skills(employee_id)
    return render_template('skills_career/my_skills.html',
                           skills=skills, employee_id=employee_id, manager_view=True)


@skills_bp.route('/employee/<int:employee_id>/rate', methods=['POST'])
def manager_rate(employee_id):
    skill_id = request.form.get('skill_id', type=int)
    rating = request.form.get('manager_rating', type=int)
    if skill_id and rating:
        svc.rate_skill(employee_id, skill_id, manager_rating=rating)
        flash('Manager rating saved.', 'success')
    return redirect(url_for('skills.employee_skills', employee_id=employee_id))


# ---------------------------------------------------------------------------
# Skill Gap Report
# ---------------------------------------------------------------------------

@skills_bp.route('/gaps')
def gaps():
    with __import__('services.db', fromlist=['get_cursor']).get_cursor() as cur:
        cur.execute("""
            SELECT sga.*, emp.first_name || ' ' || emp.last_name AS employee_name
            FROM skills.skill_gap_analysis sga
            JOIN core.employees emp ON emp.id = sga.employee_id
            WHERE sga.gap > 0
            ORDER BY sga.gap DESC
        """)
        gap_rows = cur.fetchall()
    return render_template('skills_career/gaps.html', gaps=gap_rows)


# ---------------------------------------------------------------------------
# Career Paths
# ---------------------------------------------------------------------------

@skills_bp.route('/career-paths')
def career_paths():
    paths = svc.get_career_paths()
    return render_template('skills_career/career_paths.html', paths=paths)


@skills_bp.route('/career-paths/new', methods=['POST'])
def add_career_path():
    from services.db import get_cursor
    from_pos = request.form.get('from_position_id', type=int)
    to_pos = request.form.get('to_position_id', type=int)
    path_type = request.form.get('path_type', 'PROMOTION')
    avg_years = request.form.get('avg_years', type=float)
    required_skills = request.form.get('required_skills', '')
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO skills.career_paths
                (from_position_id, to_position_id, path_type, avg_years, required_skills)
            VALUES (%s, %s, %s, %s, %s)
        """, (from_pos, to_pos, path_type, avg_years, required_skills))
    flash('Career path added.', 'success')
    return redirect(url_for('skills.career_paths'))
