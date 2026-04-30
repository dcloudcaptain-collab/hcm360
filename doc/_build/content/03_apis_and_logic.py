TITLE = 'APIs and Logic'
SUBTITLE = 'Request routing, business rules, and inter-module communication'
FOLDER = 'technical'

BLOCKS = [
    ('H1', '1. Overview'),
    ('P', 'HCM360 exposes its functionality through HTTP routes defined as Flask blueprints. Each functional module is an independent blueprint with its own URL prefix, templates, and service layer. Routes are protected by the access matrix (page + feature + modification tiers) and data is filtered through the privacy service.'),
    ('P', 'The system is primarily server-rendered. A small set of AJAX endpoints return JSON for live editing patterns (access matrix toggles, privacy rules, inline edits). All mutations require a valid CSRF-protected session.'),

    ('H1', '2. Blueprint Map'),
    ('TABLE', ['Blueprint', 'URL Prefix', 'Module'],
     [
        ['dashboard', '/', 'Landing dashboard with KPIs'],
        ['employees', '/employees', 'Core HR + 201 file management'],
        ['attendance', '/attendance', 'DTR, shifts, overtime'],
        ['leave', '/leave', 'Leave requests + balances'],
        ['payroll', '/payroll', 'Runs, payslips, loans'],
        ['ess', '/me', 'Employee self-service'],
        ['mss', '/team', 'Manager self-service'],
        ['orgchart', '/orgchart', 'Org hierarchy visualization'],
        ['wfp', '/workforce-planning', 'Scenario modeling'],
        ['dms', '/dms', '201 documents, certificate queue'],
        ['rsp', '/recruitment', 'Requisitions & candidates'],
        ['pm', '/performance', 'Reviews & evaluations'],
        ['ld', '/learning', 'Trainings & certifications'],
        ['rr', '/rewards', 'Awards & praise'],
        ['discipline', '/discipline', 'Cases & sanctions'],
        ['health', '/health', 'Incidents & safety reports'],
        ['analytics', '/reports', 'Dashboards & report builder'],
        ['ai', '/ai', 'ARIA AI assistant'],
        ['admin', '/admin', 'System configuration'],
        ['workflow', '/workflow', 'Task inbox & approvals'],
     ]),

    ('H1', '3. Request Routing Pattern'),
    ('P', 'Every blueprint follows the same layering convention. The routes file handles HTTP concerns (form parsing, redirects, flashes); the service module handles DB access and business logic.'),

    ('H2', '3.1 Example: Employee Detail Route'),
    ('CODE',
     '@employees_bp.route("/<int:employee_id>")\n'
     '@_login_required\n'
     'def employee_detail(employee_id):\n'
     '    profile = svc.get_employee_profile(employee_id)\n'
     '    if not profile:\n'
     '        abort(404)\n'
     '\n'
     '    role_code = session.get("role_code", "")\n'
     '    is_own = (session.get("employee_id") == employee_id)\n'
     '\n'
     '    # Field-level privacy masking\n'
     '    profile["employee"]   = apply_privacy(profile["employee"],\n'
     '                               role_code, "employee", is_own_record=is_own)\n'
     '    profile["gov_ids"]    = apply_privacy(profile.get("gov_ids", []),\n'
     '                               role_code, "government_id", is_own_record=is_own)\n'
     '    profile["banks"]      = apply_privacy(profile.get("banks", []),\n'
     '                               role_code, "bank_account",  is_own_record=is_own)\n'
     '    profile["dependents"] = apply_privacy(profile.get("dependents", []),\n'
     '                               role_code, "dependent",     is_own_record=is_own)\n'
     '\n'
     '    return render_template("employees/detail.html", profile=profile)'),

    ('H1', '4. Service Layer Conventions'),
    ('P', 'Service modules accept primitives (IDs, strings) and return plain dicts or lists-of-dicts. They use the shared get_cursor() context manager which yields a psycopg2 DictCursor, ensures transaction commit/rollback, and returns the connection to the pool.'),

    ('H2', '4.1 Database Access Pattern'),
    ('CODE',
     'from services.db import get_cursor\n'
     '\n'
     'def get_employee_profile(employee_id):\n'
     '    with get_cursor() as cur:\n'
     '        cur.execute("""\n'
     '            SELECT e.*, d.name AS department_name, p.title AS position_title,\n'
     '                   s.full_name AS supervisor_name\n'
     '            FROM core.v_employees_full e\n'
     '            LEFT JOIN core.departments d ON d.id = e.department_id\n'
     '            LEFT JOIN core.positions p   ON p.id = e.position_id\n'
     '            LEFT JOIN core.employees s   ON s.id = e.immediate_supervisor_id\n'
     '            WHERE e.id = %s\n'
     '        """, (employee_id,))\n'
     '        emp = cur.fetchone()\n'
     '        if not emp:\n'
     '            return None\n'
     '        # ... fetch addresses, gov_ids, banks, dependents\n'
     '        return {"employee": emp, "addresses": addrs, ...}'),

    ('H1', '5. Authentication & Session'),
    ('P', 'Login is currently a user-selector dropdown (POC mode). The POST /login/select endpoint sets session["user_id"]. A before_request hook re-derives role_code and employee_id from the DB on every request, so role changes take effect immediately.'),

    ('H2', '5.1 Key Session Variables'),
    ('TABLE', ['Key', 'Type', 'Description'],
     [
        ['user_id', 'int', 'Primary identifier (maps to core.users.id)'],
        ['role_code', 'str', 'Derived on each request from core.user_roles + core.roles'],
        ['employee_id', 'int|None', 'core.employees.id if user is linked to an employee'],
        ['_csrf_token', 'str', 'Random token regenerated per session'],
     ]),

    ('H2', '5.2 SSO Token Support'),
    ('P', 'A JWT token can be passed as ?sso_token= query parameter. The token is decoded without signature verification (POC mode), and the username claim is matched against email local-part or display_name to resolve user_id.'),

    ('H1', '6. Access Matrix Logic'),
    ('P', 'Three-tier RBAC enforced in services/access_service.py:'),

    ('H2', '6.1 Page Access'),
    ('P', 'can_access_page(role_code, path, user_id=None) looks up the path in core.page_registry using LIKE matching (so /employees/ matches /employees/123). User-level overrides take precedence; SUPER_ADMIN always passes.'),

    ('H2', '6.2 Feature/Action Access'),
    ('P', 'can_access_feature(role_code, feature_code, user_id=None) checks fine-grained actions like PAY_RUN_APPROVE, LV_BALANCE_ADJUST, EMP_PRIVACY_ADMIN. Used for conditional button rendering in templates and final checks in POST handlers.'),

    ('H2', '6.3 Modification Access'),
    ('P', 'can_modify(module_code, role_code, user_id=None) controls whether a role can mutate data in a module. Separate from page access so an EXECUTIVE can view Payroll but not change anything. Configured at /admin/modification-access.'),

    ('H1', '7. Privacy Service'),
    ('P', 'privacy_service.apply_privacy(data, role_code, section, is_own_record=False) masks sensitive fields per core.field_privacy_rules. Masking states:'),
    ('UL', [
        'VISIBLE — pass-through unchanged',
        'MASKED — replaces value with mask_char (default "***")',
        'HIDDEN — removes the key from the dict entirely',
        'is_own_record=True + EMPLOYEE: MASKED→VISIBLE, HIDDEN stays HIDDEN (own contact info visible, own salary never)',
     ]),
    ('P', 'HR_ADMIN and SUPER_ADMIN bypass all masking by default.'),

    ('H1', '8. Workflow Engine'),
    ('P', 'Cross-module workflows (leave approvals, OT approvals, discipline cases) use a lightweight engine:'),
    ('UL', [
        'workflow_definitions — named workflows with steps and approver rules',
        'workflow_instances — one row per transaction going through a workflow',
        'workflow_steps — current + history of steps per instance',
        'inbox_items — generated when an approver action is needed',
     ]),
    ('P', 'The workflow blueprint at /workflow/* lets approvers act on their inbox without leaving the site.'),

    ('H1', '9. Reporting & PDF Generation'),
    ('P', 'services/reporting_service.py produces PDFs using ReportLab. It consumes views (e.g., payroll.v_payslip) and renders standardized templates. The payslip PDF is generated on demand by GET /payroll/payslips/<id>/pdf.'),

    ('H1', '10. AJAX Endpoints (JSON)'),
    ('TABLE', ['Endpoint', 'Method', 'Purpose'],
     [
        ['/admin/access-matrix/toggle', 'POST', 'Toggle a single page/feature grant for a role or user'],
        ['/admin/privacy/save', 'POST', 'Upsert a field privacy rule'],
        ['/admin/modification-access/grant', 'POST', 'Grant/revoke module-level write access'],
        ['/api/search?q=', 'GET', 'Global search across employees, documents, tasks'],
        ['/ai/ask', 'POST', 'Submit question to ARIA AI assistant'],
        ['/orgchart/api/tree', 'GET', 'Org tree JSON for dynamic rendering'],
     ]),

    ('H1', '11. Error Handling'),
    ('UL', [
        '400 Bad Request — form validation failures (re-render form with flash)',
        '403 Forbidden — access denied by page, feature, or mod permission',
        '404 Not Found — requested resource does not exist',
        '500 Internal Server Error — rendered via error template with a request ID for log correlation',
     ]),
    ('P', 'All non-200 responses write to audit_logs.access_log for forensic review.'),

    ('H1', '12. Business Logic Highlights'),

    ('H2', '12.1 Philippine Statutory Leave Eligibility'),
    ('P', 'Leave types seeded with legal_basis (e.g., RA 11210 Maternity, RA 8187 Paternity, RA 8972 Solo Parent, RA 9262 VAWC, RA 9710 Magna Carta, RA 6727 SIL). Rules encoded in leave service: gender_restriction, max_days_per_filing, requires_document.'),

    ('H2', '12.2 Statutory Deductions (SSS/PhilHealth/HDMF/BIR)'),
    ('P', 'Payroll service loads active schedules from ref tables and applies them per bracket. Tables updatable without code changes through /admin/reference.'),

    ('H2', '12.3 Holiday Premium Pay'),
    ('P', 'attendance service classifies dates against lv_holidays; payroll applies multipliers per htype (REGULAR 200%, SPECIAL_NON_WORKING 130%, etc.) from attendance.att_holiday_types.'),
]
