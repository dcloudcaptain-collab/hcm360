"""Goals Blueprint — cascading goals and OKR management."""
from flask import Blueprint, render_template, request, redirect, url_for, flash, session
from functools import wraps
from modules.goals import goals_service as svc
from services.db import get_cursor

goals_bp = Blueprint('goals', __name__,
                     url_prefix='/goals',
                     template_folder='../../templates/goals')


def _login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated


# ---------------------------------------------------------------------------
# Goal Dashboard
# ---------------------------------------------------------------------------

@goals_bp.route('/')
@_login_required
def index():
    cycle_id = request.args.get('cycle_id', type=int)
    stats = svc.get_goal_stats(cycle_id)
    tree = svc.get_goal_tree(cycle_id)

    with get_cursor() as cur:
        cur.execute("SELECT id, name FROM performance.perf_cycles ORDER BY period_from DESC")
        cycles = cur.fetchall()
        cur.execute("SELECT id, name FROM core.departments ORDER BY name")
        departments = cur.fetchall()
        cur.execute("""
            SELECT id, full_name FROM core.v_employees_full
            WHERE is_active = true ORDER BY full_name
        """)
        employees = cur.fetchall()
        cur.execute("""
            SELECT id, title FROM performance.goals
            ORDER BY title
        """)
        all_goals = cur.fetchall()

    return render_template('goals/index.html',
                           stats=stats, tree=tree, cycles=cycles,
                           departments=departments, employees=employees,
                           all_goals=all_goals, cycle_id=cycle_id)


# ---------------------------------------------------------------------------
# Create Goal
# ---------------------------------------------------------------------------

@goals_bp.route('/create', methods=['POST'])
@_login_required
def create():
    role = session.get('role_code', '')
    if role not in ('HR_ADMIN', 'SUPER_ADMIN', 'MANAGER'):
        flash('Access denied.', 'error')
        return redirect(url_for('goals.index'))

    cycle_id = request.form.get('cycle_id', type=int)
    parent_goal_id = request.form.get('parent_goal_id', type=int) or None
    owner_type = request.form.get('owner_type', 'EMPLOYEE')
    owner_id = request.form.get('owner_id', type=int)
    title = request.form.get('title', '').strip()
    description = request.form.get('description', '')
    metric = request.form.get('metric', '')
    target_value = request.form.get('target_value', type=float) or 0
    weight = request.form.get('weight', type=float) or 1.0
    due_date = request.form.get('due_date') or None

    if not title or not owner_id:
        flash('Title and owner are required.', 'error')
        return redirect(url_for('goals.index'))

    goal_id = svc.create_goal(cycle_id, parent_goal_id, owner_type, owner_id,
                              title, description, metric, target_value, weight, due_date)
    flash('Goal created.', 'success')
    return redirect(url_for('goals.detail', goal_id=goal_id))


# ---------------------------------------------------------------------------
# Goal Detail
# ---------------------------------------------------------------------------

@goals_bp.route('/<int:goal_id>')
@_login_required
def detail(goal_id):
    goal = svc.get_goal(goal_id)
    if not goal:
        flash('Goal not found.', 'error')
        return redirect(url_for('goals.index'))

    root, children = svc.get_cascading_view(goal_id)

    return render_template('goals/detail.html',
                           goal=goal, children=children)


# ---------------------------------------------------------------------------
# Update Progress
# ---------------------------------------------------------------------------

@goals_bp.route('/<int:goal_id>/progress', methods=['POST'])
@_login_required
def update_progress(goal_id):
    current_value = request.form.get('current_value', type=float) or 0
    progress_pct = request.form.get('progress_pct', type=float) or 0

    svc.update_progress(goal_id, current_value, progress_pct)
    flash('Progress updated.', 'success')

    referer = request.form.get('referer', '')
    if referer == 'my':
        return redirect(url_for('goals.my_goals'))
    return redirect(url_for('goals.detail', goal_id=goal_id))


# ---------------------------------------------------------------------------
# My Goals
# ---------------------------------------------------------------------------

@goals_bp.route('/my')
@_login_required
def my_goals():
    emp_id = session.get('employee_id')
    if not emp_id:
        flash('No employee profile linked.', 'error')
        return redirect(url_for('goals.index'))

    cycle_id = request.args.get('cycle_id', type=int)
    goals = svc.get_goals_for_employee(emp_id, cycle_id)

    with get_cursor() as cur:
        cur.execute("SELECT id, name FROM performance.perf_cycles ORDER BY period_from DESC")
        cycles = cur.fetchall()

    return render_template('goals/my_goals.html',
                           goals=goals, cycles=cycles, cycle_id=cycle_id)
