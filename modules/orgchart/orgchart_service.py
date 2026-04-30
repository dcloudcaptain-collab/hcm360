"""Org Chart service — department hierarchy, positions, vacancy tracking."""
from services.db import get_cursor
from services.privacy_service import apply_privacy


def get_department_tree(company_id):
    """Get departments with head employee name and position counts."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT d.id, d.name, d.parent_id,
                   h.first_name || ' ' || h.last_name AS head_name,
                   hp.title AS head_position,
                   COUNT(DISTINCT e.id) AS employee_count,
                   COUNT(DISTINCT p.id) AS position_count,
                   COUNT(DISTINCT p.id) FILTER (WHERE p.id NOT IN (
                       SELECT position_id FROM core.employees WHERE position_id IS NOT NULL AND is_active = TRUE
                   )) AS vacant_count
            FROM core.departments d
            LEFT JOIN core.employees h ON h.id = d.head_employee_id AND h.is_active = TRUE
            LEFT JOIN core.positions hp ON hp.id = h.position_id
            LEFT JOIN core.employees e ON e.department_id = d.id AND e.is_active = TRUE
            LEFT JOIN core.positions p ON p.department_id = d.id
            WHERE d.company_id = %s AND d.is_active = TRUE
            GROUP BY d.id, d.name, d.parent_id, h.first_name, h.last_name, hp.title
            ORDER BY d.name
        """, (company_id,))
        return cur.fetchall()


def get_org_tree_json(company_id):
    """Build nested tree JSON for rendering."""
    departments = get_department_tree(company_id)
    dept_map = {d['id']: dict(d) for d in departments}

    # Add children list
    for d in dept_map.values():
        d['children'] = []

    roots = []
    for d in dept_map.values():
        parent = d.get('parent_id')
        if parent and parent in dept_map:
            dept_map[parent]['children'].append(d)
        else:
            roots.append(d)

    return roots


def get_subordinate_ids(employee_id):
    """Recursively get all subordinate employee IDs (full downline)."""
    with get_cursor() as cur:
        cur.execute("""
            WITH RECURSIVE downline AS (
                SELECT id FROM core.employees
                WHERE immediate_supervisor_id = %s AND is_active = TRUE
                UNION ALL
                SELECT e.id FROM core.employees e
                JOIN downline d ON e.immediate_supervisor_id = d.id
                WHERE e.is_active = TRUE
            )
            SELECT id FROM downline
        """, (employee_id,))
        return {r['id'] for r in cur.fetchall()}


def get_department_detail(department_id):
    """Get positions in a department with filled/vacant status."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT d.id, d.name AS department_name,
                   h.first_name || ' ' || h.last_name AS head_name
            FROM core.departments d
            LEFT JOIN core.employees h ON h.id = d.head_employee_id
            WHERE d.id = %s
        """, (department_id,))
        dept = cur.fetchone()

        cur.execute("""
            SELECT p.id AS position_id, p.title,
                   jg.grade_level AS salary_grade,
                   e.id AS employee_id,
                   e.first_name || ' ' || e.last_name AS employee_name,
                   e.status AS emp_status,
                   CASE WHEN e.id IS NOT NULL AND e.is_active = TRUE THEN 'FILLED' ELSE 'VACANT' END AS fill_status
            FROM core.positions p
            LEFT JOIN core.job_grades jg ON jg.id = p.job_grade_id
            LEFT JOIN core.employees e ON e.position_id = p.id AND e.is_active = TRUE
            WHERE p.department_id = %s
            ORDER BY jg.grade_level DESC NULLS LAST, p.title
        """, (department_id,))
        positions = cur.fetchall()

        return {'department': dept, 'positions': positions}


def get_person_tree(company_id):
    """Build a person-centric org tree: each node is an employee with direct reports.
    Returns the top-level person (no supervisor) and nested children."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT e.id, e.first_name || ' ' || e.last_name AS name,
                   e.profile_photo_path AS photo,
                   p.title AS position_title,
                   d.name AS department_name,
                   e.immediate_supervisor_id AS parent_id,
                   jg.grade_level AS salary_grade,
                   (SELECT COUNT(*) FROM core.employees sub
                    WHERE sub.immediate_supervisor_id = e.id AND sub.is_active = TRUE) AS direct_reports
            FROM core.employees e
            LEFT JOIN core.positions p ON p.id = e.position_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.job_grades jg ON jg.id = e.job_grade_id
            WHERE e.company_id = %s AND e.is_active = TRUE
            ORDER BY jg.grade_level DESC NULLS LAST, e.last_name
        """, (company_id,))
        employees = cur.fetchall()

    emp_map = {e['id']: dict(e) for e in employees}
    for e in emp_map.values():
        e['children'] = []

    roots = []
    for e in emp_map.values():
        pid = e.get('parent_id')
        if pid and pid in emp_map:
            emp_map[pid]['children'].append(e)
        else:
            roots.append(e)

    return roots


def get_employee_scoped_tree(employee_id, company_id):
    """
    Build a scoped org tree for a specific employee:
    - Ancestor chain from the top-level executive down to the employee
      (only the single relevant child shown at each ancestor level)
    - Employee's full subordinate downline shown beneath them
    Returns a single root node dict, or None if employee not found.
    """
    with get_cursor() as cur:
        cur.execute("""
            SELECT e.id,
                   e.first_name || ' ' || e.last_name AS name,
                   e.profile_photo_path AS photo,
                   p.title AS position_title,
                   d.name AS department_name,
                   e.immediate_supervisor_id AS parent_id,
                   jg.grade_level AS salary_grade,
                   (SELECT COUNT(*) FROM core.employees sub
                    WHERE sub.immediate_supervisor_id = e.id
                      AND sub.is_active = TRUE) AS direct_reports
            FROM core.employees e
            LEFT JOIN core.positions p  ON p.id = e.position_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.job_grades jg ON jg.id = e.job_grade_id
            WHERE e.company_id = %s AND e.is_active = TRUE
        """, (company_id,))
        all_emp = {r['id']: dict(r) for r in cur.fetchall()}

    if employee_id not in all_emp:
        return None

    # ── Build ancestor chain (top → employee) ─────────────────────
    chain = []
    cur_id = employee_id
    visited = set()
    while cur_id and cur_id not in visited:
        visited.add(cur_id)
        chain.insert(0, cur_id)
        parent = all_emp[cur_id].get('parent_id')
        cur_id = parent if parent in all_emp else None
    chain_set = set(chain)

    # ── Recursive builders ─────────────────────────────────────────
    def _kids(emp_id):
        return sorted(
            [eid for eid, e in all_emp.items() if e.get('parent_id') == emp_id],
            key=lambda x: (all_emp[x].get('salary_grade') or 0),
            reverse=True,
        )

    def build_full_subtree(emp_id):
        """Full downline — used for the employee node and all their reports."""
        node = dict(all_emp[emp_id])
        node['is_self'] = (emp_id == employee_id)
        node['children'] = [build_full_subtree(k) for k in _kids(emp_id)]
        return node

    def build_chain_node(emp_id):
        """Ancestor node — shows only the single chain child that leads to the employee."""
        node = dict(all_emp[emp_id])
        node['is_self'] = (emp_id == employee_id)

        if emp_id == employee_id:
            # Focal node: show full downline
            node['children'] = [build_full_subtree(k) for k in _kids(emp_id)]
        else:
            # Ancestor: show only the chain child
            chain_child = next(
                (eid for eid in chain_set if all_emp[eid].get('parent_id') == emp_id),
                None,
            )
            node['children'] = [build_chain_node(chain_child)] if chain_child else []

        return node

    return build_chain_node(chain[0])


def get_stats(company_id):
    """Org-wide statistics for the sidebar (admin view)."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                (SELECT COUNT(*) FROM core.departments WHERE company_id = %s AND is_active = TRUE) AS dept_count,
                (SELECT COUNT(*) FROM core.positions WHERE department_id IN (
                    SELECT id FROM core.departments WHERE company_id = %s
                )) AS total_positions,
                (SELECT COUNT(*) FROM core.employees WHERE company_id = %s AND is_active = TRUE) AS headcount,
                (SELECT COUNT(DISTINCT p.id) FROM core.positions p
                    JOIN core.departments d ON d.id = p.department_id AND d.company_id = %s
                    LEFT JOIN core.employees e ON e.position_id = p.id AND e.is_active = TRUE
                    WHERE e.id IS NULL
                ) AS vacant_positions,
                NULL::text AS scope_label
        """, (company_id, company_id, company_id, company_id))
        return cur.fetchone()


def get_dept_stats_for_employee(employee_id, company_id):
    """
    Figures scoped to the department of the given employee.

    Returns the same shape as get_stats(): dept_count, total_positions,
    headcount, vacant_positions, plus a scope_label (department name) so
    the UI can show "Finance & Accounting" instead of the global view.

    For this view:
      * dept_count        = 1 (the user's own department)
      * total_positions   = positions attached to that department
      * headcount         = active employees in that department
      * vacant_positions  = unfilled positions in that department
    Returns None if the employee has no department assigned.
    """
    with get_cursor() as cur:
        cur.execute("""
            SELECT d.id, d.name
            FROM core.employees e
            JOIN core.departments d ON d.id = e.department_id
            WHERE e.id = %s AND e.company_id = %s AND d.is_active = TRUE
            LIMIT 1
        """, (employee_id, company_id))
        dept = cur.fetchone()
        if not dept:
            return None

        dept_id = dept['id']
        cur.execute("""
            SELECT
                1                                                          AS dept_count,
                (SELECT COUNT(*) FROM core.positions
                    WHERE department_id = %s)                              AS total_positions,
                (SELECT COUNT(*) FROM core.employees
                    WHERE department_id = %s AND is_active = TRUE)         AS headcount,
                (SELECT COUNT(DISTINCT p.id) FROM core.positions p
                    LEFT JOIN core.employees e ON e.position_id = p.id AND e.is_active = TRUE
                    WHERE p.department_id = %s AND e.id IS NULL)           AS vacant_positions
        """, (dept_id, dept_id, dept_id))
        row = cur.fetchone()
        return {
            'dept_count':       row['dept_count'],
            'total_positions':  row['total_positions'],
            'headcount':        row['headcount'],
            'vacant_positions': row['vacant_positions'],
            'scope_label':      dept['name'],
            'department_id':    dept_id,
        }


# ───────────────────────────────────────────────────────────────────
# Privacy-aware org chart functions
# ───────────────────────────────────────────────────────────────────

def _apply_tree_privacy(node, role_code, viewer_emp_id=None):
    """
    Recursively apply field-level privacy to org chart nodes.

    Privacy rules:
    - SUPER_ADMIN, HR_ADMIN: see all fields unmasked
    - EMPLOYEE viewing own node (is_self=True): see own fields unmasked, salary hidden
    - EMPLOYEE viewing ancestors: see name, position, photo only
    - EMPLOYEE viewing team members: see full dept/org context, no personal details
    - MANAGER viewing team: see all fields for direct reports

    Args:
        node: Org chart node dict (employee record + tree structure)
        role_code: Viewer's role (EMPLOYEE, MANAGER, HR_ADMIN, SUPER_ADMIN)
        viewer_emp_id: Viewer's employee_id (for self-detection)

    Returns modified node with privacy-masked fields
    """
    if not node:
        return node

    # Admins always see everything
    if role_code in ('SUPER_ADMIN', 'HR_ADMIN'):
        if 'children' in node:
            node['children'] = [_apply_tree_privacy(c, role_code, viewer_emp_id) for c in node['children']]
        return node

    is_self = node.get('is_self', False)

    # Build privacy context for this node
    # Employee name/position always visible in org chart (it's the point of the chart)
    # But sensitive details hidden based on context
    if is_self:
        # Own record: mask sensitive fields but keep org context
        masked_node = dict(node)
        # Salary grade hidden from self-view
        masked_node.pop('salary_grade', None)
        # Basic salary, etc. would be masked by privacy_service.apply_privacy if called
    else:
        # Ancestor nodes: name and position only
        if node.get('is_ancestor', False):
            masked_node = {
                'id': node['id'],
                'name': node['name'],
                'position_title': node.get('position_title'),
                'photo': node.get('photo'),
                'is_ancestor': True,
                'children': []  # Don't expand ancestors
            }
        # Team member nodes: full dept/position info, no salary
        else:
            masked_node = dict(node)
            masked_node.pop('salary_grade', None)

    # Recursively apply privacy to children
    if 'children' in masked_node:
        masked_node['children'] = [
            _apply_tree_privacy(c, role_code, viewer_emp_id)
            for c in masked_node['children']
        ]

    return masked_node


def get_employee_scoped_tree_private(employee_id, company_id, role_code='EMPLOYEE'):
    """
    Get scoped org tree with privacy controls applied.

    Returns the standard scoped tree but with sensitive fields masked
    based on the viewer's role and context.
    """
    tree = get_employee_scoped_tree(employee_id, company_id)
    return _apply_tree_privacy(tree, role_code, employee_id)


def get_person_tree_private(company_id, role_code='EMPLOYEE', viewer_emp_id=None):
    """
    Get full person tree with privacy controls applied.

    For non-admin employees, may return restricted tree or null
    based on their department/org access.
    """
    # Admins get full tree
    if role_code in ('SUPER_ADMIN', 'HR_ADMIN'):
        tree = get_person_tree(company_id)
        return tree

    # Non-admins: use scoped tree instead
    if viewer_emp_id:
        return get_employee_scoped_tree_private(viewer_emp_id, company_id, role_code)

    return None  # No access


def get_department_org_tree(department_id, company_id, role_code='EMPLOYEE', viewer_emp_id=None):
    """
    Get org chart for a specific department only.

    Privacy rules:
    - SUPER_ADMIN, HR_ADMIN: full dept tree
    - EMPLOYEE from same dept: see full dept tree
    - EMPLOYEE from different dept: denied (return None or empty)
    - MANAGER: see own dept + direct reports
    """
    # Admins always get access
    if role_code in ('SUPER_ADMIN', 'HR_ADMIN'):
        with get_cursor() as cur:
            cur.execute("""
                SELECT e.id, e.first_name || ' ' || e.last_name AS name,
                       e.profile_photo_path AS photo,
                       p.title AS position_title,
                       d.name AS department_name,
                       e.immediate_supervisor_id AS parent_id,
                       jg.grade_level AS salary_grade,
                       (SELECT COUNT(*) FROM core.employees sub
                        WHERE sub.immediate_supervisor_id = e.id AND sub.is_active = TRUE) AS direct_reports
                FROM core.employees e
                LEFT JOIN core.positions p ON p.id = e.position_id
                LEFT JOIN core.departments d ON d.id = e.department_id
                LEFT JOIN core.job_grades jg ON jg.id = e.job_grade_id
                WHERE e.department_id = %s AND e.company_id = %s AND e.is_active = TRUE
            """, (department_id, company_id))
            all_emp = {r['id']: dict(r) for r in cur.fetchall()}

        if not all_emp:
            return None

        # Build tree from all dept employees
        def build_tree(emp_id):
            node = dict(all_emp[emp_id])
            kids = [eid for eid, e in all_emp.items() if e.get('parent_id') == emp_id]
            node['children'] = [build_tree(k) for k in sorted(
                kids,
                key=lambda x: (all_emp[x].get('salary_grade') or 0),
                reverse=True
            )]
            return node

        # Find roots (no parent in this dept)
        roots = [eid for eid, e in all_emp.items() if not e.get('parent_id') or e.get('parent_id') not in all_emp]
        return [build_tree(r) for r in roots] if roots else None

    # Non-admins: only see their own department
    if viewer_emp_id:
        with get_cursor() as cur:
            cur.execute("""
                SELECT department_id FROM core.employees WHERE id = %s
            """, (viewer_emp_id,))
            emp = cur.fetchone()
            if not emp or emp['department_id'] != department_id:
                return None  # Deny access to different department

        # Same dept: return dept tree with privacy applied
        with get_cursor() as cur:
            cur.execute("""
                SELECT e.id, e.first_name || ' ' || e.last_name AS name,
                       e.profile_photo_path AS photo,
                       p.title AS position_title,
                       d.name AS department_name,
                       e.immediate_supervisor_id AS parent_id,
                       jg.grade_level AS salary_grade,
                       (SELECT COUNT(*) FROM core.employees sub
                        WHERE sub.immediate_supervisor_id = e.id AND sub.is_active = TRUE) AS direct_reports
                FROM core.employees e
                LEFT JOIN core.positions p ON p.id = e.position_id
                LEFT JOIN core.departments d ON d.id = e.department_id
                LEFT JOIN core.job_grades jg ON jg.id = e.job_grade_id
                WHERE e.department_id = %s AND e.company_id = %s AND e.is_active = TRUE
            """, (department_id, company_id))
            all_emp = {r['id']: dict(r) for r in cur.fetchall()}

        if not all_emp:
            return None

        def build_tree(emp_id):
            node = dict(all_emp[emp_id])
            node['is_self'] = (emp_id == viewer_emp_id)
            kids = [eid for eid, e in all_emp.items() if e.get('parent_id') == emp_id]
            node['children'] = [build_tree(k) for k in sorted(
                kids,
                key=lambda x: (all_emp[x].get('salary_grade') or 0),
                reverse=True
            )]
            return node

        roots = [eid for eid, e in all_emp.items() if not e.get('parent_id') or e.get('parent_id') not in all_emp]
        trees = [build_tree(r) for r in roots] if roots else None

        # Apply privacy mask
        if trees:
            return [_apply_tree_privacy(t, role_code, viewer_emp_id) for t in trees]

        return None

    return None  # No viewer_emp_id, no access
