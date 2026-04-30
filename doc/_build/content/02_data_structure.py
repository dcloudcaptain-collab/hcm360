TITLE = 'Data Structure'
SUBTITLE = 'Schemas, tables, and data flow across the HCM360 HRIS'
FOLDER = 'technical'

BLOCKS = [
    ('H1', '1. Database Overview'),
    ('P', 'HCM360 uses PostgreSQL 15 with schema-based partitioning. Every functional module owns its schema to keep concerns isolated. Cross-module references use foreign keys; reporting uses views and materialized views to denormalize for performance.'),
    ('P', 'Primary tenant isolation is through core.companies.id. Every employee-scoped table carries either employee_id or company_id so queries naturally filter by tenant. Row-level security is not enforced; access is filtered at the application layer through role and company context.'),

    ('H1', '2. Core Schema'),
    ('P', 'The core schema holds master data shared across the platform: companies, users, roles, employees, organizational structure, and system configuration.'),

    ('H2', '2.1 Tenant & Company'),
    ('TABLE', ['Table', 'Key Columns', 'Notes'],
     [
        ['core.companies', 'id, code, name, legal_name, industry, size_bracket, tin, sss_employer_id, phic_employer_id, hdmf_employer_id, fiscal_year_start, payroll_cycle, is_active', 'One row per subscriber/tenant'],
        ['core.company_branding', 'id, company_id, key UNIQUE, value', 'Key/value settings: short_name, tagline, primary_color, logo_text'],
     ]),

    ('H2', '2.2 Users & Roles'),
    ('TABLE', ['Table', 'Key Columns', 'Notes'],
     [
        ['core.users', 'id, company_id, username UNIQUE, email, password_hash, display_name, role_code, employee_id, is_active, last_login_at, failed_attempts, locked_until, mfa_enabled', 'System login accounts'],
        ['core.roles', 'id, code UNIQUE, name, description, is_system_role, is_active', 'Built-ins: SUPER_ADMIN, HR_ADMIN, MANAGER, EMPLOYEE, EXECUTIVE'],
        ['core.user_roles', 'user_id, role_id, granted_by, granted_at', 'Many-to-many (user can hold multiple roles)'],
     ]),

    ('H2', '2.3 Employees & Organization'),
    ('TABLE', ['Table', 'Key Columns'],
     [
        ['core.employees', 'id, company_id, employee_no UNIQUE, full_name, gender, civil_status, date_of_birth, mobile_no, work_email, position_id, department_id, employment_type_id, job_grade_id, date_hired, date_regularized, status, immediate_supervisor_id, basic_salary, daily_rate, hourly_rate'],
        ['core.departments', 'id, company_id, code, name, parent_id, head_employee_id'],
        ['core.positions', 'id, company_id, code, title, department_id, job_grade_id'],
        ['core.job_grades', 'id, code, name, grade_level, salary_min, salary_max'],
        ['core.employment_types', 'id, code, name, probation_days, is_entitled_benefits'],
        ['core.business_units', 'id, company_id, code, name, parent_id'],
     ]),

    ('H2', '2.4 Employee Sub-Records'),
    ('TABLE', ['Table', 'Purpose'],
     [
        ['core.employee_addresses', 'Permanent / current addresses'],
        ['core.employee_emergency_contacts', 'Named contacts with relationship + mobile'],
        ['core.employee_government_ids', 'SSS, TIN, PhilHealth, HDMF, TIN, driver license'],
        ['core.employee_bank_accounts', 'Bank, account number, primary flag'],
        ['core.employee_dependents', 'Spouse, children, beneficiary flag'],
     ]),

    ('H2', '2.5 Access Control'),
    ('TABLE', ['Table', 'Purpose'],
     [
        ['core.page_registry', 'Every UI route registered with module, nav_group, icon, title'],
        ['core.role_page_access', 'Role → page access grant (can_access boolean)'],
        ['core.user_page_access', 'User-level override (takes precedence over role)'],
        ['core.feature_registry', 'Action-level features (CREATE, EDIT, DELETE, EXPORT, APPROVE)'],
        ['core.role_feature_access', 'Role → feature grant'],
        ['core.user_feature_access', 'User-level feature override'],
        ['core.mod_permissions', 'Module-level write permissions (separate from page access)'],
        ['core.field_privacy_rules', 'RA 10173 field visibility rules per (section, field, role)'],
     ]),

    ('H2', '2.6 Reference & Configuration'),
    ('TABLE', ['Table', 'Purpose'],
     [
        ['core.status_definitions', 'Per-module status codes with color/badge'],
        ['core.ui_themes', 'UI color palettes, one active per company'],
        ['core.dashboard_metrics', 'KPI definitions with SQL, filter URL, allowed roles'],
        ['core.dynamic_forms + core.form_fields', 'Dynamic form definitions with is_required flag'],
        ['core.transaction_registry', 'Links modules to workflow definitions'],
     ]),

    ('H1', '3. Attendance Schema'),
    ('TABLE', ['Table', 'Key Columns'],
     [
        ['attendance.att_daily', 'id, employee_id, work_date, time_in, time_out, worked_hours, is_late, is_absent, late_minutes'],
        ['attendance.att_shifts', 'id, company_id, code, name, start_time, end_time, days_of_week'],
        ['attendance.att_shift_assignments', 'id, employee_id, shift_id, effective_from, effective_to'],
        ['attendance.att_holiday_types', 'REGULAR, SPECIAL_NON_WORKING, etc. with pay multipliers'],
        ['attendance.att_admin_overrides', 'Audit log of manual edits (employee_id, work_date, before, after, reason, by_user_id)'],
        ['attendance.att_alerts', 'Generated alerts for late / absent patterns'],
     ]),

    ('H1', '4. Leave Management Schema'),
    ('TABLE', ['Table', 'Key Columns'],
     [
        ['leave_mgmt.lv_types', 'id, code, name, category, legal_basis, color, icon, is_paid, max_days_per_filing, gender_restriction'],
        ['leave_mgmt.lv_balances', 'id, employee_id, leave_type_id, year, entitled, used, balance'],
        ['leave_mgmt.lv_requests', 'id, employee_id, leave_type_id, date_from, date_to, days, reason, status'],
        ['leave_mgmt.lv_holidays', 'id, company_id, hdate, name, htype, is_recurring, month_day'],
        ['leave_mgmt.lv_policies', 'Per employment type: accrual_type, carry_over, monetization'],
        ['leave_mgmt.lv_balance_adjustments', 'Non-destructive manual adjustments with audit trail'],
     ]),

    ('H1', '5. Payroll Schema'),
    ('TABLE', ['Table', 'Key Columns'],
     [
        ['payroll.pay_periods', 'id, company_id, period_code, date_from, date_to, payment_date, period_type'],
        ['payroll.pay_runs', 'id, period_id, status (DRAFT/COMPUTING/COMPUTED/APPROVED/POSTED), run_type'],
        ['payroll.pay_employee_payroll', 'id, run_id, employee_id, basic_pay, gross_pay, SSS/PhilHealth/HDMF/tax deductions, net_pay, allowances (PERA/RATA/ACA), government schemes (GSIS, coop)'],
        ['payroll.pay_loans', 'id, employee_id, loan_type, principal, balance, amortization, start_date, end_date'],
        ['payroll.pay_adjustments', 'Non-destructive adjustments (add-on or deduction) with reason + approver'],
        ['payroll.v_payslip', 'VIEW joining employee payroll with run, period, department, position for printing'],
     ]),

    ('H1', '6. ESS / MSS Schema'),
    ('P', 'Self-service and manager-service do not introduce new tables. They consume existing data via session.employee_id and apply privacy masking for own-record access.'),

    ('H1', '7. Recruitment, PM, L&D, R&R Schemas'),
    ('TABLE', ['Schema', 'Representative Tables'],
     [
        ['rsp', 'requisitions, candidates, interviews, offers, csc_eligibilities, qualification_standards'],
        ['pm', 'review_cycles, kpis, competencies, evaluations, calibrations, 360_feedback'],
        ['ld', 'training_catalog, enrollments, certifications, training_sessions, attendance'],
        ['rr', 'award_categories, awards, praise_wall, praise_config'],
     ]),

    ('H1', '8. DMS, Discipline, Health Schemas'),
    ('TABLE', ['Schema', 'Key Tables'],
     [
        ['dms', 'documents, document_categories (hierarchical), certificate_requests, certificate_types, retention_policies'],
        ['discipline', 'cases, case_types, investigations, sanctions, hearings (with case_types keyed by gravity + legal_basis)'],
        ['health', 'incidents, safety_reports, incident_types'],
     ]),

    ('H1', '9. Workforce Planning & Analytics'),
    ('TABLE', ['Schema / Feature', 'Tables'],
     [
        ['workforce_planning', 'scenarios (name, type, horizon_months, assumptions JSONB), headcount_projections, skill_demands'],
        ['Analytics', 'Materialized views built on core/payroll/attendance; dashboard_metrics drives the admin dashboard'],
        ['Report Builder', 'Per-user saved queries with role-scoped execution'],
     ]),

    ('H1', '10. Audit & Change Tracking'),
    ('P', 'Every mutation on business-critical tables fires the audit_logs.fn_capture_change() trigger which writes a before/after snapshot into audit_logs.change_log. The trigger also captures app.current_user_id and app.current_company_id passed via SET LOCAL from the application.'),

    ('H1', '11. Data Flow Examples'),

    ('H2', '11.1 Filing a Leave Request'),
    ('OL', [
        'Employee submits POST /leave/requests/new (form data)',
        'leave_mgmt.routes calls svc.create_request() which inserts into lv_requests with status=PENDING',
        'Trigger writes audit_logs.change_log entry',
        'Workflow engine picks up the record and creates inbox task for supervisor',
        'Supervisor approves → status changes to APPROVED → trigger debits lv_balances.used',
        'HR finalizes (optional) → status = COMPLETED',
     ]),

    ('H2', '11.2 Running Payroll'),
    ('OL', [
        'Admin creates pay_period and pay_run (DRAFT)',
        'Run triggers computation: for each employee, compute attendance, OT, leave days, allowances, then deductions (SSS, PhilHealth, HDMF, BIR tax) and net pay',
        'Results written to pay_employee_payroll (run_id, employee_id)',
        'Status flows: DRAFT → COMPUTING → COMPUTED → APPROVED → POSTED',
        'Once POSTED, payslip_generated=true and employees see payslips in /me/payslips',
        'Adjustments after posting go to pay_adjustments (non-destructive)',
     ]),

    ('H1', '12. Data Retention'),
    ('UL', [
        'Employee records: retained for the life of the company record (soft-delete via status)',
        'Payroll: retained 10 years per BIR requirements',
        'Attendance logs: retained 5 years',
        'Audit logs: retained 3 years (partitionable by month)',
        'Document retention: driven by dms.retention_policies per category',
     ]),
]
