-- ================================================================
-- HCM360 HRIS — 17: SEED DATA — CORE
-- Populates: company, departments, positions, employment_types,
--            users, employees, RBAC pages/features, themes,
--            branding, dashboard_metrics, workflow definitions
-- ================================================================

SET search_path TO core, workflow, public;

-- ── Company ───────────────────────────────────────────────────────

INSERT INTO core.companies (code, name, legal_name, industry, size_bracket,
    address_line1, city, province, country,
    phone, email, website,
    sss_employer_id, phic_employer_id, hdmf_employer_id,
    payroll_cycle, fiscal_year_start)
VALUES ('DEMO', 'HCM360 Demo Company, Inc.', 'HCM360 Demo Company, Incorporated',
    'Technology', 'MSME',
    '123 HRIS Tower, Makati Ave', 'Makati City', 'Metro Manila', 'Philippines',
    '+632-8888-0000', 'hr@hcm360.demo', 'https://hcm360.demo',
    '03-1234567-8', '12-345678901-2', '1234-5678-9',
    'SEMI_MONTHLY', 1);

-- ── Employment Types ──────────────────────────────────────────────

INSERT INTO core.employment_types (code, name, is_entitled_benefits, probation_days) VALUES
    ('REGULAR',        'Regular / Permanent',  TRUE,  0),
    ('PROBATIONARY',   'Probationary',          FALSE, 180),
    ('CONTRACTUAL',    'Contractual / Project', FALSE, 0),
    ('CASUAL',         'Casual',                FALSE, 0),
    ('PART_TIME',      'Part-Time',             FALSE, 0);

-- ── Job Grades ────────────────────────────────────────────────────

INSERT INTO core.job_grades (company_id, code, name, grade_level, salary_min, salary_max)
SELECT id, g.code, g.name, g.level, g.smin, g.smax FROM core.companies,
(VALUES
    ('JG1','Staff / Associate',        1,  15000,  25000),
    ('JG2','Senior Staff',             2,  25001,  40000),
    ('JG3','Supervisor / Team Lead',   3,  40001,  60000),
    ('JG4','Manager',                  4,  60001,  90000),
    ('JG5','Senior Manager / Director',5,  90001, 150000),
    ('JG6','VP / Executive',           6, 150001, 300000)
) AS g(code, name, level, smin, smax);

-- ── Departments ───────────────────────────────────────────────────

INSERT INTO core.departments (company_id, code, name)
SELECT c.id, d.code, d.name FROM core.companies c,
(VALUES
    ('HR',  'Human Resources'),
    ('IT',  'Information Technology'),
    ('FIN', 'Finance & Accounting'),
    ('OPS', 'Operations'),
    ('MKT', 'Marketing & Sales'),
    ('ADM', 'Administration'),
    ('EXE', 'Executive')
) AS d(code, name);

-- ── Positions ─────────────────────────────────────────────────────

INSERT INTO core.positions (company_id, department_id, job_grade_id, code, title, is_managerial)
SELECT
    c.id,
    (SELECT id FROM core.departments WHERE company_id = c.id AND code = p.dept_code LIMIT 1),
    (SELECT id FROM core.job_grades WHERE company_id = c.id AND code = p.grade LIMIT 1),
    p.code, p.title, p.is_mgr
FROM core.companies c,
(VALUES
    ('HR',  'JG4', 'HR-MGR',    'HR Manager',              TRUE),
    ('HR',  'JG3', 'HRBP',      'HR Business Partner',     FALSE),
    ('HR',  'JG2', 'HR-SPEC',   'HR Specialist',           FALSE),
    ('HR',  'JG1', 'HR-ASST',   'HR Assistant',            FALSE),
    ('IT',  'JG4', 'IT-MGR',    'IT Manager',              TRUE),
    ('IT',  'JG2', 'DEV-SR',    'Senior Developer',        FALSE),
    ('IT',  'JG1', 'DEV-JR',    'Junior Developer',        FALSE),
    ('FIN', 'JG4', 'FIN-MGR',   'Finance Manager',         TRUE),
    ('FIN', 'JG2', 'ACCT-SR',   'Senior Accountant',       FALSE),
    ('FIN', 'JG1', 'ACCT-JR',   'Junior Accountant',       FALSE),
    ('OPS', 'JG4', 'OPS-MGR',   'Operations Manager',      TRUE),
    ('OPS', 'JG2', 'OPS-SUPR',  'Operations Supervisor',   FALSE),
    ('OPS', 'JG1', 'OPS-ASST',  'Operations Assistant',    FALSE),
    ('MKT', 'JG4', 'MKT-MGR',   'Marketing Manager',       TRUE),
    ('MKT', 'JG2', 'MKT-SPEC',  'Marketing Specialist',    FALSE),
    ('ADM', 'JG2', 'ADMIN-OFF',  'Administrative Officer',  FALSE),
    ('EXE', 'JG6', 'CEO',       'Chief Executive Officer', TRUE),
    ('EXE', 'JG5', 'COO',       'Chief Operations Officer',TRUE),
    ('EXE', 'JG5', 'CFO',       'Chief Finance Officer',   TRUE)
) AS p(dept_code, grade, code, title, is_mgr);

-- ── Users ─────────────────────────────────────────────────────────

INSERT INTO core.users (company_id, username, email, display_name, role_code, is_active)
SELECT c.id, u.username, u.email, u.display_name, u.role_code, TRUE
FROM core.companies c,
(VALUES
    ('superadmin',  'superadmin@hcm360.demo',   'Super Admin',       'SUPER_ADMIN'),
    ('hradmin',     'hradmin@hcm360.demo',       'HR Admin',          'HR_ADMIN'),
    ('manager',     'manager@hcm360.demo',       'Manager View',      'MANAGER'),
    ('employee',    'employee@hcm360.demo',       'Employee View',    'EMPLOYEE'),
    ('executive',   'executive@hcm360.demo',     'Executive View',   'EXECUTIVE'),
    ('capsanchez',  'capsanchez@hcm360.local',   'Carlos Sanchez',   'SUPER_ADMIN'),
    ('maria',       'maria.santos@hcm360.demo',  'Maria Santos',      'HR_ADMIN'),
    ('roberto',     'roberto.m@hcm360.demo',     'Roberto Mendoza',  'MANAGER'),
    ('lara',        'lara.cruz@hcm360.demo',     'Lara Cruz',         'EMPLOYEE'),
    ('juan',        'juan.dela@hcm360.demo',     'Juan Dela Cruz',    'EMPLOYEE'),
    ('ana',         'ana.r@hcm360.demo',         'Ana Reyes',         'EMPLOYEE')
) AS u(username, email, display_name, role_code);

-- ── Employees (20 sample employees) ──────────────────────────────

DO $$
DECLARE
    v_company_id BIGINT;
    v_hr_dept    BIGINT; v_it_dept  BIGINT; v_fin_dept  BIGINT;
    v_ops_dept   BIGINT; v_mkt_dept BIGINT; v_adm_dept  BIGINT;
    v_hr_mgr     BIGINT; v_hrbp     BIGINT; v_hr_spec   BIGINT; v_hr_asst BIGINT;
    v_it_mgr     BIGINT; v_dev_sr   BIGINT; v_dev_jr    BIGINT;
    v_fin_mgr    BIGINT; v_acct_sr  BIGINT; v_acct_jr   BIGINT;
    v_ops_mgr    BIGINT; v_ops_supr BIGINT; v_ops_asst  BIGINT;
    v_mkt_mgr    BIGINT; v_mkt_spec BIGINT;
    v_regular    BIGINT; v_prob     BIGINT;
    v_jg1 BIGINT; v_jg2 BIGINT; v_jg3 BIGINT; v_jg4 BIGINT;
BEGIN
    SELECT id INTO v_company_id FROM core.companies WHERE code='DEMO';
    SELECT id INTO v_hr_dept FROM core.departments WHERE code='HR' AND company_id=v_company_id;
    SELECT id INTO v_it_dept FROM core.departments WHERE code='IT' AND company_id=v_company_id;
    SELECT id INTO v_fin_dept FROM core.departments WHERE code='FIN' AND company_id=v_company_id;
    SELECT id INTO v_ops_dept FROM core.departments WHERE code='OPS' AND company_id=v_company_id;
    SELECT id INTO v_mkt_dept FROM core.departments WHERE code='MKT' AND company_id=v_company_id;
    SELECT id INTO v_adm_dept FROM core.departments WHERE code='ADM' AND company_id=v_company_id;
    SELECT id INTO v_hr_mgr FROM core.positions WHERE code='HR-MGR' AND company_id=v_company_id;
    SELECT id INTO v_hrbp FROM core.positions WHERE code='HRBP' AND company_id=v_company_id;
    SELECT id INTO v_hr_spec FROM core.positions WHERE code='HR-SPEC' AND company_id=v_company_id;
    SELECT id INTO v_hr_asst FROM core.positions WHERE code='HR-ASST' AND company_id=v_company_id;
    SELECT id INTO v_it_mgr FROM core.positions WHERE code='IT-MGR' AND company_id=v_company_id;
    SELECT id INTO v_dev_sr FROM core.positions WHERE code='DEV-SR' AND company_id=v_company_id;
    SELECT id INTO v_dev_jr FROM core.positions WHERE code='DEV-JR' AND company_id=v_company_id;
    SELECT id INTO v_fin_mgr FROM core.positions WHERE code='FIN-MGR' AND company_id=v_company_id;
    SELECT id INTO v_acct_sr FROM core.positions WHERE code='ACCT-SR' AND company_id=v_company_id;
    SELECT id INTO v_acct_jr FROM core.positions WHERE code='ACCT-JR' AND company_id=v_company_id;
    SELECT id INTO v_ops_mgr FROM core.positions WHERE code='OPS-MGR' AND company_id=v_company_id;
    SELECT id INTO v_ops_supr FROM core.positions WHERE code='OPS-SUPR' AND company_id=v_company_id;
    SELECT id INTO v_ops_asst FROM core.positions WHERE code='OPS-ASST' AND company_id=v_company_id;
    SELECT id INTO v_mkt_mgr FROM core.positions WHERE code='MKT-MGR' AND company_id=v_company_id;
    SELECT id INTO v_mkt_spec FROM core.positions WHERE code='MKT-SPEC' AND company_id=v_company_id;
    SELECT id INTO v_regular FROM core.employment_types WHERE code='REGULAR';
    SELECT id INTO v_prob FROM core.employment_types WHERE code='PROBATIONARY';
    SELECT id INTO v_jg1 FROM core.job_grades WHERE code='JG1' AND company_id=v_company_id;
    SELECT id INTO v_jg2 FROM core.job_grades WHERE code='JG2' AND company_id=v_company_id;
    SELECT id INTO v_jg3 FROM core.job_grades WHERE code='JG3' AND company_id=v_company_id;
    SELECT id INTO v_jg4 FROM core.job_grades WHERE code='JG4' AND company_id=v_company_id;

    INSERT INTO core.employees (company_id, employee_no, last_name, first_name, middle_name,
        gender, civil_status, date_of_birth, work_email, mobile_no,
        department_id, position_id, job_grade_id, employment_type_id,
        date_hired, date_regularized, status, basic_salary, work_arrangement) VALUES
    (v_company_id,'EMP-001','Santos','Maria','G.','FEMALE','MARRIED','1985-03-15','maria.santos@hcm360.demo','09171234501',v_hr_dept,v_hr_mgr,v_jg4,v_regular,'2015-01-10','2015-07-10','ACTIVE',75000,'ONSITE'),
    (v_company_id,'EMP-002','Cruz','Lara','P.','FEMALE','SINGLE','1993-07-22','lara.cruz@hcm360.demo','09171234502',v_hr_dept,v_hrbp,v_jg3,v_regular,'2018-06-01','2018-12-01','ACTIVE',52000,'HYBRID'),
    (v_company_id,'EMP-003','Reyes','Ana','M.','FEMALE','SINGLE','1996-11-05','ana.r@hcm360.demo','09171234503',v_hr_dept,v_hr_spec,v_jg2,v_regular,'2020-03-15','2020-09-15','ACTIVE',38000,'ONSITE'),
    (v_company_id,'EMP-004','Garcia','Pedro','B.','MALE','MARRIED','1990-04-20','pedro.g@hcm360.demo','09171234504',v_hr_dept,v_hr_asst,v_jg1,v_prob,'2025-10-01',NULL,'PROBATIONARY',22000,'ONSITE'),
    (v_company_id,'EMP-005','Torres','Miguel','R.','MALE','SINGLE','1987-09-12','miguel.t@hcm360.demo','09171234505',v_it_dept,v_it_mgr,v_jg4,v_regular,'2014-05-20','2014-11-20','ACTIVE',85000,'HYBRID'),
    (v_company_id,'EMP-006','Villanueva','Jose','C.','MALE','MARRIED','1991-02-28','jose.v@hcm360.demo','09171234506',v_it_dept,v_dev_sr,v_jg2,v_regular,'2019-09-01','2020-03-01','ACTIVE',42000,'REMOTE'),
    (v_company_id,'EMP-007','Ramos','Carmen','L.','FEMALE','SINGLE','1997-06-14','carmen.r@hcm360.demo','09171234507',v_it_dept,v_dev_jr,v_jg1,v_prob,'2025-08-15',NULL,'PROBATIONARY',25000,'HYBRID'),
    (v_company_id,'EMP-008','Mendoza','Roberto','A.','MALE','MARRIED','1982-12-03','roberto.m@hcm360.demo','09171234508',v_ops_dept,v_ops_mgr,v_jg4,v_regular,'2012-03-01','2012-09-01','ACTIVE',80000,'ONSITE'),
    (v_company_id,'EMP-009','Bautista','Elena','T.','FEMALE','MARRIED','1988-08-30','elena.b@hcm360.demo','09171234509',v_ops_dept,v_ops_supr,v_jg3,v_regular,'2016-07-11','2017-01-11','ACTIVE',55000,'ONSITE'),
    (v_company_id,'EMP-010','Dela Cruz','Juan','S.','MALE','SINGLE','1995-05-17','juan.dela@hcm360.demo','09171234510',v_ops_dept,v_ops_asst,v_jg1,v_regular,'2021-01-15','2021-07-15','ACTIVE',24000,'ONSITE'),
    (v_company_id,'EMP-011','Aquino','Rosario','D.','FEMALE','MARRIED','1984-10-08','rosario.a@hcm360.demo','09171234511',v_fin_dept,v_fin_mgr,v_jg4,v_regular,'2013-11-01','2014-05-01','ACTIVE',78000,'ONSITE'),
    (v_company_id,'EMP-012','Flores','Benjamin','E.','MALE','SINGLE','1992-03-25','ben.f@hcm360.demo','09171234512',v_fin_dept,v_acct_sr,v_jg2,v_regular,'2018-02-01','2018-08-01','ACTIVE',40000,'ONSITE'),
    (v_company_id,'EMP-013','Castillo','Jennifer','N.','FEMALE','SINGLE','1998-01-11','jennifer.c@hcm360.demo','09171234513',v_fin_dept,v_acct_jr,v_jg1,v_prob,'2025-09-01',NULL,'PROBATIONARY',22000,'ONSITE'),
    (v_company_id,'EMP-014','Navarro','Antonio','F.','MALE','MARRIED','1986-07-04','antonio.n@hcm360.demo','09171234514',v_mkt_dept,v_mkt_mgr,v_jg4,v_regular,'2016-04-01','2016-10-01','ACTIVE',72000,'HYBRID'),
    (v_company_id,'EMP-015','Lopez','Patricia','H.','FEMALE','SINGLE','1994-12-19','patricia.l@hcm360.demo','09171234515',v_mkt_dept,v_mkt_spec,v_jg2,v_regular,'2019-11-15','2020-05-15','ACTIVE',36000,'HYBRID'),
    (v_company_id,'EMP-016','Diaz','Ricardo','J.','MALE','MARRIED','1980-05-22','ricardo.d@hcm360.demo','09171234516',v_adm_dept,NULL,v_jg2,v_regular,'2010-08-01','2011-02-01','ACTIVE',35000,'ONSITE'),
    (v_company_id,'EMP-017','Morales','Cynthia','B.','FEMALE','MARRIED','1989-09-09','cynthia.m@hcm360.demo','09171234517',v_hr_dept,v_hr_spec,v_jg2,v_regular,'2017-03-01','2017-09-01','ON_LEAVE',39000,'ONSITE'),
    (v_company_id,'EMP-018','Perez','Daniel','A.','MALE','SINGLE','1999-04-30','daniel.p@hcm360.demo','09171234518',v_it_dept,v_dev_jr,v_jg1,v_prob,'2025-11-01',NULL,'PROBATIONARY',25000,'REMOTE'),
    (v_company_id,'EMP-019','Santiago','Maricel','C.','FEMALE','MARRIED','1987-01-15','maricel.s@hcm360.demo','09171234519',v_ops_dept,v_ops_supr,v_jg3,v_regular,'2015-06-01','2015-12-01','ACTIVE',53000,'ONSITE'),
    (v_company_id,'EMP-020','Fernandez','Carlos','R.','MALE','SINGLE','1993-08-07','carlos.f@hcm360.demo','09171234520',v_fin_dept,v_acct_sr,v_jg2,v_regular,'2020-07-01','2021-01-01','ACTIVE',41000,'ONSITE');

    -- Link users to employees
    UPDATE core.users SET employee_id = (SELECT id FROM core.employees WHERE work_email = 'maria.santos@hcm360.demo' LIMIT 1) WHERE username = 'maria';
    UPDATE core.users SET employee_id = (SELECT id FROM core.employees WHERE work_email = 'roberto.m@hcm360.demo' LIMIT 1) WHERE username = 'roberto';
    UPDATE core.users SET employee_id = (SELECT id FROM core.employees WHERE work_email = 'lara.cruz@hcm360.demo' LIMIT 1) WHERE username = 'lara';
    UPDATE core.users SET employee_id = (SELECT id FROM core.employees WHERE work_email = 'juan.dela@hcm360.demo' LIMIT 1) WHERE username = 'juan';
    UPDATE core.users SET employee_id = (SELECT id FROM core.employees WHERE work_email = 'ana.r@hcm360.demo' LIMIT 1) WHERE username = 'ana';

    -- Set supervisors
    UPDATE core.employees SET immediate_supervisor_id = (SELECT id FROM core.employees WHERE employee_no='EMP-001') WHERE department_id = v_hr_dept AND employee_no != 'EMP-001';
    UPDATE core.employees SET immediate_supervisor_id = (SELECT id FROM core.employees WHERE employee_no='EMP-005') WHERE department_id = v_it_dept AND employee_no != 'EMP-005';
    UPDATE core.employees SET immediate_supervisor_id = (SELECT id FROM core.employees WHERE employee_no='EMP-011') WHERE department_id = v_fin_dept AND employee_no != 'EMP-011';
    UPDATE core.employees SET immediate_supervisor_id = (SELECT id FROM core.employees WHERE employee_no='EMP-008') WHERE department_id = v_ops_dept AND employee_no != 'EMP-008';
    UPDATE core.employees SET immediate_supervisor_id = (SELECT id FROM core.employees WHERE employee_no='EMP-014') WHERE department_id = v_mkt_dept AND employee_no != 'EMP-014';
END
$$;

-- ── Shifts ────────────────────────────────────────────────────────

INSERT INTO attendance.att_shifts (company_id, code, name, shift_type, time_in, time_out, break_minutes, total_work_hours, grace_period_minutes)
SELECT c.id, s.code, s.name, 'FIXED', s.tin::TIME, s.tout::TIME, 60, s.hrs, 5
FROM core.companies c,
(VALUES
    ('REG-8-5', 'Regular 8am-5pm',   '08:00', '17:00', 8.0),
    ('REG-9-6', 'Regular 9am-6pm',   '09:00', '18:00', 8.0),
    ('FLEX',    'Flexi Hours',        '08:00', '17:00', 8.0),
    ('NIGHT',   'Night Shift 10p-7a', '22:00', '07:00', 8.0)
) AS s(code, name, tin, tout, hrs);

-- ── Themes ────────────────────────────────────────────────────────

INSERT INTO core.ui_themes (name, is_active, primary_color, secondary_color, accent_color, bg_color, card_color, sidebar_color, sidebar_text, border_radius, font_family, text_color) VALUES
    ('Enterprise Light', FALSE, '#1e40af','#1e3a8a','#3b82f6','#f1f5f9','#ffffff','#1e3a8a','#e2e8f0','8px', 'Inter, system-ui, sans-serif',           '#0f172a'),
    ('Executive Dark',   FALSE, '#7c3aed','#4c1d95','#a78bfa','#0f172a','#1e293b','#1a0533','#e2e8f0','8px', 'Inter, system-ui, sans-serif',           '#e2e8f0'),
    ('Modern Slate',     FALSE, '#0f766e','#134e4a','#14b8a6','#f8fafc','#ffffff','#134e4a','#f0fdfa','12px','Inter, system-ui, sans-serif',           '#0f172a'),
    ('Coastal Teal',     TRUE,  '#0f6f8f','#5fa8c6','#5fa8c6','#f4f7fb','#ffffff','#0f6f8f','#e2f1f7','8px', 'Inter, "Segoe UI", Arial, sans-serif',   '#173042'),
    ('Royal Maroon',     FALSE, '#9f1239','#be123c','#fb7185','#fef2f2','#ffffff','#7f1d1d','#fee2e2','8px', 'Inter, "Segoe UI", Arial, sans-serif',   '#1f0a0a');

-- ── Company Branding ──────────────────────────────────────────────

INSERT INTO core.company_branding (key, value) VALUES
    ('company_name',    'HCM360 Demo Company, Inc.'),
    ('short_name',      'HCM360'),
    ('tagline',         'Intelligent HR for Growing Companies'),
    ('primary_color',   '#1e40af'),
    ('logo_text',       'HCM360');

-- ── Status Definitions ────────────────────────────────────────────

INSERT INTO core.status_definitions (module, code, label, color, badge_class, sort_order) VALUES
    ('employee', 'ACTIVE',       'Active',        '#10b981','badge-success',  1),
    ('employee', 'PROBATIONARY', 'Probationary',  '#f59e0b','badge-warning',  2),
    ('employee', 'ON_LEAVE',     'On Leave',      '#3b82f6','badge-info',     3),
    ('employee', 'RESIGNED',     'Resigned',      '#6b7280','badge-secondary',4),
    ('employee', 'TERMINATED',   'Terminated',    '#ef4444','badge-danger',   5),
    ('employee', 'RETIRED',      'Retired',       '#8b5cf6','badge-purple',   6),
    ('workflow', 'IN_PROGRESS',  'In Progress',   '#f59e0b','badge-warning',  1),
    ('workflow', 'APPROVED',     'Approved',      '#10b981','badge-success',  2),
    ('workflow', 'REJECTED',     'Rejected',      '#ef4444','badge-danger',   3),
    ('workflow', 'COMPLETED',    'Completed',     '#6366f1','badge-primary',  4),
    ('leave',    'PENDING',      'Pending',       '#f59e0b','badge-warning',  1),
    ('leave',    'APPROVED',     'Approved',      '#10b981','badge-success',  2),
    ('leave',    'REJECTED',     'Rejected',      '#ef4444','badge-danger',   3),
    ('leave',    'CANCELLED',    'Cancelled',     '#6b7280','badge-secondary',4),
    ('payroll',  'DRAFT',        'Draft',         '#94a3b8','badge-secondary',1),
    ('payroll',  'COMPUTING',    'Computing',     '#f59e0b','badge-warning',  2),
    ('payroll',  'COMPUTED',     'Computed',      '#3b82f6','badge-info',     3),
    ('payroll',  'APPROVED',     'Approved',      '#10b981','badge-success',  4),
    ('payroll',  'POSTED',       'Posted',        '#6366f1','badge-primary',  5);

-- ── Feature Registry ──────────────────────────────────────────────

INSERT INTO core.feature_registry (code, name, module, is_enabled) VALUES
    ('enable_recruitment', 'Recruitment Module',      'recruitment', FALSE),
    ('enable_learning',    'Learning & Development',  'learning',    FALSE),
    ('enable_rewards',     'Rewards & Recognition',   'rewards',     FALSE),
    ('enable_performance', 'Performance Management',  'performance', FALSE),
    ('enable_ai',          'ARIA AI Assistant',       'ai',          TRUE),
    ('enable_analytics',   'Analytics & Reporting',   'analytics',   TRUE),
    ('enable_payroll',     'Payroll Module',          'payroll',     TRUE),
    ('enable_leave',       'Leave Management',        'leave_mgmt',  TRUE),
    ('enable_attendance',  'Attendance & DTR',        'attendance',  TRUE);

-- ── Page Registry ─────────────────────────────────────────────────

INSERT INTO core.page_registry (path, title, module, nav_group, nav_label, nav_icon, nav_order, requires_feature) VALUES
    ('/',                   'Dashboard',          'core',       'Core',         'Dashboard',       'grid',       1,  NULL),
    ('/employees',          'Employees',          'core',       'Core',         'Employee Records','users',      2,  NULL),
    ('/attendance/dtr',     'DTR',                'attendance', 'Workforce',    'Attendance/DTR',  'clock',      10, 'enable_attendance'),
    ('/attendance/overtime','Overtime',           'attendance', 'Workforce',    'Overtime',        'clock',      11, 'enable_attendance'),
    ('/leave',              'Leave Dashboard',    'leave_mgmt', 'Workforce',    'Leave',           'calendar',   20, 'enable_leave'),
    ('/leave/requests',     'Leave Requests',     'leave_mgmt', 'Workforce',    'Leave Requests',  'calendar',   21, 'enable_leave'),
    ('/leave/balances',     'Leave Balances',     'leave_mgmt', 'Workforce',    'Leave Balances',  'calendar',   22, 'enable_leave'),
    ('/leave/travel-orders','Travel Orders',      'leave_mgmt', 'Workforce',    'Travel Orders',   'navigation', 23, 'enable_leave'),
    ('/leave/locator',      'Team Locator',       'leave_mgmt', 'Workforce',    'Team Locator',    'map-pin',    24, 'enable_leave'),
    ('/leave/cto',          'CTO Credits',        'leave_mgmt', 'Workforce',    'CTO Credits',     'clock',      25, 'enable_leave'),
    ('/payroll',            'Payroll',            'payroll',    'Payroll',      'Payroll',         'dollar-sign',30, 'enable_payroll'),
    ('/payroll/loans',      'Loans',              'payroll',    'Payroll',      'Loans',           'credit-card',31, 'enable_payroll'),
    ('/me',                 'My Profile',         'ess_mss',    'Self-Service', 'My Profile',      'user',       40, NULL),
    ('/me/leaves',          'My Leaves',          'ess_mss',    'Self-Service', 'My Leaves',       'umbrella',   41, 'enable_leave'),
    ('/me/attendance',      'My Attendance',      'ess_mss',    'Self-Service', 'My Attendance',   'clock',      42, 'enable_attendance'),
    ('/me/payslips',        'My Payslips',        'ess_mss',    'Self-Service', 'My Payslips',     'file-text',  43, 'enable_payroll'),
    ('/my-team',            'My Team',            'ess_mss',    'Self-Service', 'My Team',         'users',      44, NULL),
    ('/reports',            'Reports',            'analytics',  'Analytics',    'Reports',         'bar-chart',  50, 'enable_analytics'),
    ('/reports/headcount',  'Headcount Report',   'analytics',  'Analytics',    'Headcount',       'users',      51, 'enable_analytics'),
    ('/workflow',           'Workflows',          'workflow',   'System',       'Workflows',       'git-branch', 60, NULL),
    ('/ai/executive',       'Executive Briefing', 'ai',         'AI',           'ARIA Executive',  'cpu',        70, 'enable_ai'),
    ('/ai/assistant',       'ARIA Assistant',     'ai',         'AI',           'ARIA Chat',       'message-circle',71,'enable_ai'),
    ('/search',             'Search',             'core',       NULL,           NULL,              NULL,         99, NULL),
    ('/admin/themes',       'Themes',             'admin',      'Admin',        'Themes',          'palette',    80, NULL),
    ('/admin/users',        'Users',              'admin',      'Admin',        'Users',           'user-check', 81, NULL),
    ('/admin/access-matrix','Access Matrix',      'admin',      'Admin',        'Access Matrix',   'shield',     82, NULL),
    ('/admin/reference',    'Reference Data',     'admin',      'Admin',        'Reference Data',  'database',   83, NULL),
    ('/admin/demo-data',    'Demo Data',          'admin',      'Admin',        'Demo Data',       'database',   90, NULL),
    ('/reports/builder',    'Report Builder',     'analytics',  'Admin',        'Report Builder',  'bar-chart-2',91, NULL);

-- Role page access (HR_ADMIN sees everything; MANAGER sees operations; EMPLOYEE sees self-service)
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.code, p.id, TRUE FROM core.page_registry p,
(VALUES ('SUPER_ADMIN'), ('HR_ADMIN')) AS r(code);

-- Manager: exclude admin pages + payroll register
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT 'MANAGER', p.id, TRUE FROM core.page_registry p
WHERE p.nav_group NOT IN ('admin') AND p.path NOT IN ('/payroll/register');

-- Employee: self-service only + leave filing + attendance view
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT 'EMPLOYEE', p.id, TRUE FROM core.page_registry p
WHERE p.path IN ('/','/me','/me/leaves','/me/attendance','/me/payslips','/search',
                 '/leave','/leave/requests','/leave/locator','/ai/assistant');

-- Executive: dashboard + analytics + AI
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT 'EXECUTIVE', p.id, TRUE FROM core.page_registry p
WHERE p.path IN ('/','/reports','/reports/headcount','/ai/executive','/ai/assistant',
                 '/employees','/search');

-- ── Dashboard Metrics ─────────────────────────────────────────────

INSERT INTO core.dashboard_metrics (code, label, icon, module, sql_query, filter_url, roles, sort_order) VALUES
('headcount_total', 'Total Headcount', 'users', 'core',
 'SELECT COUNT(*) FROM core.employees WHERE is_active=TRUE AND status NOT IN (''RESIGNED'',''TERMINATED'',''RETIRED'',''DECEASED'')',
 '/employees', ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE'], 1),

('headcount_active', 'Active Employees', 'user-check', 'core',
 'SELECT COUNT(*) FROM core.employees WHERE is_active=TRUE AND status=''ACTIVE''',
 '/employees?status=ACTIVE', ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE'], 2),

('headcount_probationary', 'Probationary', 'user-plus', 'core',
 'SELECT COUNT(*) FROM core.employees WHERE is_active=TRUE AND status=''PROBATIONARY''',
 '/employees?status=PROBATIONARY', ARRAY['SUPER_ADMIN','HR_ADMIN'], 3),

('present_today', 'Present Today', 'clock', 'attendance',
 'SELECT COUNT(*) FROM attendance.att_daily WHERE work_date=CURRENT_DATE AND status IN (''PRESENT'',''LATE'')',
 '/attendance/dtr?date=today&status=PRESENT', ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER'], 4),

('late_today', 'Late Today', 'alert-circle', 'attendance',
 'SELECT COUNT(*) FROM attendance.att_daily WHERE work_date=CURRENT_DATE AND status=''LATE''',
 '/attendance/dtr?date=today&status=LATE', ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER'], 5),

('on_leave_today', 'On Leave Today', 'umbrella', 'leave_mgmt',
 'SELECT COUNT(*) FROM leave_mgmt.lv_requests WHERE status=''APPROVED'' AND date_from<=CURRENT_DATE AND date_to>=CURRENT_DATE',
 '/leave/locator?filter=ON_LEAVE', ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER'], 6),

('leave_pending', 'Pending Leaves', 'clock', 'leave_mgmt',
 'SELECT COUNT(*) FROM leave_mgmt.lv_requests WHERE status=''PENDING''',
 '/leave/requests?status=PENDING', ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER'], 7),

('ot_pending', 'Pending OT Requests', 'clock', 'attendance',
 'SELECT COUNT(*) FROM attendance.att_overtime_requests WHERE status=''PENDING''',
 '/attendance/overtime?status=PENDING', ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER'], 8),

('missing_docs', 'Missing Documents', 'file-x', 'core',
 'SELECT COUNT(*) FROM core.documents WHERE is_missing=TRUE',
 '/employees?filter=missing_docs', ARRAY['SUPER_ADMIN','HR_ADMIN'], 9),

('workflows_pending', 'Pending Approvals', 'git-branch', 'workflow',
 'SELECT COUNT(*) FROM workflow.workflow_instances WHERE status=''IN_PROGRESS''',
 '/workflow?status=IN_PROGRESS', ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER'], 10);

-- ── Workflow Definitions ──────────────────────────────────────────

INSERT INTO workflow.workflow_definitions (code, name, module, description, is_active) VALUES
    ('LEAVE_APPROVAL',    'Leave Request Approval',     'leave_mgmt', 'Standard leave request approval flow', TRUE),
    ('OT_APPROVAL',       'Overtime Request Approval',  'attendance', 'Overtime approval by manager',         TRUE),
    ('PAYROLL_APPROVAL',  'Payroll Run Approval',       'payroll',    'Payroll cutoff approval chain',        TRUE),
    ('LOAN_APPROVAL',     'Loan Application Approval',  'payroll',    'Employee loan application flow',       TRUE),
    ('TRAVEL_APPROVAL',   'Travel Order Approval',      'leave_mgmt', 'Travel order approval flow',          TRUE),
    ('DTR_CORRECTION',    'DTR Correction Review',      'attendance', 'DTR correction request review',        TRUE);

-- Leave approval steps
DO $$
DECLARE
    v_wd_id BIGINT;
    v_s1 BIGINT; v_s2 BIGINT; v_s3 BIGINT;
BEGIN
    -- ── Leave Approval ────────────────────────────────────────────
    SELECT id INTO v_wd_id FROM workflow.workflow_definitions WHERE code='LEAVE_APPROVAL';
    INSERT INTO workflow.workflow_steps (workflow_id, step_order, code, name, role_required, is_final, sla_hours) VALUES
        (v_wd_id, 1, 'MGR_REVIEW', 'Manager Review',       'MANAGER',  FALSE, 24),
        (v_wd_id, 2, 'HR_REVIEW',  'HR Review & Approval', 'HR_ADMIN', TRUE,  24);
    SELECT id INTO v_s1 FROM workflow.workflow_steps WHERE workflow_id=v_wd_id AND step_order=1;
    SELECT id INTO v_s2 FROM workflow.workflow_steps WHERE workflow_id=v_wd_id AND step_order=2;
    INSERT INTO workflow.workflow_routes (step_id, action_code, next_step_id, label) VALUES
        (v_s1, 'APPROVE', v_s2, 'Approve → HR Review'),
        (v_s1, 'REJECT',  NULL, 'Reject'),
        (v_s2, 'APPROVE', NULL, 'Final Approve'),
        (v_s2, 'REJECT',  NULL, 'Reject');

    -- ── OT Approval ───────────────────────────────────────────────
    SELECT id INTO v_wd_id FROM workflow.workflow_definitions WHERE code='OT_APPROVAL';
    INSERT INTO workflow.workflow_steps (workflow_id, step_order, code, name, role_required, is_final, sla_hours) VALUES
        (v_wd_id, 1, 'MGR_APPROVE', 'Manager Approval', 'MANAGER', FALSE, 4),
        (v_wd_id, 2, 'HR_CONFIRM',  'HR Confirmation',  'HR_ADMIN', TRUE, 8);
    SELECT id INTO v_s1 FROM workflow.workflow_steps WHERE workflow_id=v_wd_id AND step_order=1;
    SELECT id INTO v_s2 FROM workflow.workflow_steps WHERE workflow_id=v_wd_id AND step_order=2;
    INSERT INTO workflow.workflow_routes (step_id, action_code, next_step_id, label) VALUES
        (v_s1, 'APPROVE', v_s2, 'Approve → HR'),
        (v_s1, 'REJECT',  NULL, 'Reject'),
        (v_s2, 'APPROVE', NULL, 'Confirm OT'),
        (v_s2, 'REJECT',  NULL, 'Reject');

    -- ── Payroll Approval ──────────────────────────────────────────
    SELECT id INTO v_wd_id FROM workflow.workflow_definitions WHERE code='PAYROLL_APPROVAL';
    INSERT INTO workflow.workflow_steps (workflow_id, step_order, code, name, role_required, is_final, sla_hours) VALUES
        (v_wd_id, 1, 'HR_SUBMIT',  'HR Submit for Approval', 'HR_ADMIN',  FALSE, 8),
        (v_wd_id, 2, 'MGR_APPROVE','Manager Approval',       'MANAGER',   FALSE, 24),
        (v_wd_id, 3, 'EXEC_POST',  'Executive Sign-off',     'EXECUTIVE', TRUE,  24);
    SELECT id INTO v_s1 FROM workflow.workflow_steps WHERE workflow_id=v_wd_id AND step_order=1;
    SELECT id INTO v_s2 FROM workflow.workflow_steps WHERE workflow_id=v_wd_id AND step_order=2;
    SELECT id INTO v_s3 FROM workflow.workflow_steps WHERE workflow_id=v_wd_id AND step_order=3;
    INSERT INTO workflow.workflow_routes (step_id, action_code, next_step_id, label) VALUES
        (v_s1, 'SUBMIT',  v_s2, 'Submit → Manager'),
        (v_s2, 'APPROVE', v_s3, 'Approve → Executive'),
        (v_s2, 'REJECT',  NULL, 'Reject'),
        (v_s3, 'POST',    NULL, 'Post Payroll'),
        (v_s3, 'REJECT',  NULL, 'Reject');
END
$$;
