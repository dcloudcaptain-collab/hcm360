"""Org Chart Blueprint — Organization visualization."""
from flask import Blueprint, render_template, request, redirect, url_for, session, jsonify, flash, abort
from functools import wraps
from modules.orgchart import orgchart_service as svc
from services.db import get_cursor

orgchart_bp = Blueprint('orgchart', __name__,
                        url_prefix='/orgchart',
                        template_folder='../../templates/orgchart')


def _login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated


def _get_company_id():
    with get_cursor() as cur:
        cur.execute("SELECT id FROM core.companies LIMIT 1")
        row = cur.fetchone()
        return row['id'] if row else None


@orgchart_bp.route('/')
@_login_required
def chart():
    company_id = _get_company_id()
    my_emp_id  = session.get('employee_id')
    role_code  = session.get('role_code')

    if role_code in ('SUPER_ADMIN', 'HR_ADMIN'):
        # Admin view: full company-wide org tree + org-wide stats
        stats        = svc.get_stats(company_id) if company_id else {}
        person_tree  = svc.get_person_tree(company_id) if company_id else []
        scoped_tree  = None
        viewable_ids = None          # can view + link everyone
    elif my_emp_id and company_id:
        # Non-admin view: scoped tree (ancestors → self → team) + DEPT-only stats
        # Figures show only the current user's department, not the whole company.
        dept_stats   = svc.get_dept_stats_for_employee(my_emp_id, company_id)
        stats        = dept_stats if dept_stats else svc.get_stats(company_id)
        person_tree  = None
        scoped_tree  = svc.get_employee_scoped_tree_private(my_emp_id, company_id, role_code)
        viewable_ids = svc.get_subordinate_ids(my_emp_id) | {my_emp_id}
    else:
        stats        = {}
        person_tree  = []
        scoped_tree  = None
        viewable_ids = set()

    # Department tree kept as fallback if no supervisor data exists
    tree = svc.get_org_tree_json(company_id) if company_id else []

    return render_template('orgchart/chart.html',
                           tree=tree,
                           person_tree=person_tree,
                           scoped_tree=scoped_tree,
                           stats=stats,
                           viewable_ids=viewable_ids,
                           my_emp_id=my_emp_id)


@orgchart_bp.route('/tree.json')
@_login_required
def tree_json():
    company_id = _get_company_id()
    tree = svc.get_org_tree_json(company_id) if company_id else []
    # Serialize for JSON (remove non-serializable)
    import json
    return jsonify(json.loads(json.dumps(tree, default=str)))


@orgchart_bp.route('/department/<int:department_id>')
@_login_required
def department_detail(department_id):
    data = svc.get_department_detail(department_id)
    return render_template('orgchart/department.html', **data)


@orgchart_bp.route('/department/<int:department_id>/chart')
@_login_required
def department_chart(department_id):
    """Department-scoped org chart with privacy restrictions."""
    company_id = _get_company_id()
    my_emp_id  = session.get('employee_id')
    role_code  = session.get('role_code')

    # Check access
    if not role_code in ('SUPER_ADMIN', 'HR_ADMIN'):
        # Non-admins can only view their own department's chart
        if my_emp_id:
            with get_cursor() as cur:
                cur.execute(
                    "SELECT department_id FROM core.employees WHERE id = %s",
                    (my_emp_id,)
                )
                emp = cur.fetchone()
                if not emp or emp['department_id'] != department_id:
                    flash('Access denied. You can only view your own department\'s org chart.', 'error')
                    return redirect(url_for('orgchart.chart'))
        else:
            flash('Access denied.', 'error')
            return redirect(url_for('orgchart.chart'))

    # Get department info
    with get_cursor() as cur:
        cur.execute(
            "SELECT id, name FROM core.departments WHERE id = %s AND company_id = %s",
            (department_id, company_id)
        )
        dept = cur.fetchone()
        if not dept:
            abort(404)

    # Get dept tree
    dept_trees = svc.get_department_org_tree(department_id, company_id, role_code, my_emp_id)
    stats = svc.get_stats(company_id) if company_id else {}

    return render_template('orgchart/chart.html',
                           tree=[],
                           person_tree=dept_trees if role_code in ('SUPER_ADMIN', 'HR_ADMIN') else None,
                           scoped_tree=dept_trees if role_code not in ('SUPER_ADMIN', 'HR_ADMIN') else None,
                           stats=stats,
                           viewable_ids=None if role_code in ('SUPER_ADMIN', 'HR_ADMIN') else (svc.get_subordinate_ids(my_emp_id) | {my_emp_id} if my_emp_id else set()),
                           my_emp_id=my_emp_id,
                           dept_name=dept['name'])
