-- ================================================================
-- HCM360 HRIS — 36: REPORT BUILDER & SCHEDULED REPORTS
-- Schema    : analytics
-- Features  : saved report definitions, scheduled runs, distribution
-- ================================================================
SET search_path TO analytics, core, public;

-- ----------------------------------------------------------------
-- REPORT CATALOG — field registry for the builder UI
-- ----------------------------------------------------------------
CREATE TABLE analytics.report_data_sources (
    id              BIGSERIAL    PRIMARY KEY,
    source_code     VARCHAR(30)  NOT NULL UNIQUE,
    source_label    VARCHAR(100) NOT NULL,
    base_sql        TEXT         NOT NULL,
    module          VARCHAR(30)  NOT NULL,
    description     TEXT,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    sort_order      INTEGER      NOT NULL DEFAULT 0
);

CREATE TABLE analytics.report_field_registry (
    id              BIGSERIAL    PRIMARY KEY,
    source_id       BIGINT       NOT NULL REFERENCES analytics.report_data_sources(id),
    field_code      VARCHAR(60)  NOT NULL,
    field_label     VARCHAR(100) NOT NULL,
    field_type      VARCHAR(20)  NOT NULL DEFAULT 'TEXT'
                        CHECK (field_type IN ('TEXT','NUMBER','DATE','BOOLEAN','CURRENCY')),
    sql_expression  VARCHAR(300) NOT NULL,
    is_groupable    BOOLEAN      NOT NULL DEFAULT TRUE,
    is_filterable   BOOLEAN      NOT NULL DEFAULT TRUE,
    is_sortable     BOOLEAN      NOT NULL DEFAULT TRUE,
    is_aggregatable BOOLEAN      NOT NULL DEFAULT FALSE,
    default_aggregate VARCHAR(10) CHECK (default_aggregate IN ('COUNT','SUM','AVG','MIN','MAX')),
    sort_order      INTEGER      NOT NULL DEFAULT 0,
    UNIQUE (source_id, field_code)
);

-- ----------------------------------------------------------------
-- SAVED REPORTS — user-defined report configurations
-- ----------------------------------------------------------------
CREATE TABLE analytics.saved_reports (
    id              BIGSERIAL    PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    source_id       BIGINT       NOT NULL REFERENCES analytics.report_data_sources(id),
    config          JSONB        NOT NULL DEFAULT '{}',
    -- config structure:
    -- { "columns": ["field_code",...],
    --   "filters": [{"field":"x","op":"=","value":"v"},...],
    --   "group_by": ["field_code",...],
    --   "order_by": [{"field":"x","dir":"asc"},...],
    --   "aggregates": [{"field":"x","fn":"SUM"},...],
    --   "limit": 500 }
    created_by      BIGINT       REFERENCES core.users(id),
    is_shared       BOOLEAN      NOT NULL DEFAULT FALSE,
    is_system       BOOLEAN      NOT NULL DEFAULT FALSE,
    last_run_at     TIMESTAMPTZ,
    run_count       INTEGER      NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_saved_reports_user ON analytics.saved_reports(created_by);

-- ----------------------------------------------------------------
-- SCHEDULED REPORTS — auto-triggered generation
-- ----------------------------------------------------------------
CREATE TABLE analytics.report_schedules (
    id              BIGSERIAL    PRIMARY KEY,
    report_id       BIGINT       NOT NULL REFERENCES analytics.saved_reports(id) ON DELETE CASCADE,
    schedule_type   VARCHAR(20)  NOT NULL DEFAULT 'WEEKLY'
                        CHECK (schedule_type IN ('DAILY','WEEKLY','MONTHLY','QUARTERLY','YEARLY')),
    day_of_week     INTEGER,     -- 0=Mon ... 6=Sun (for WEEKLY)
    day_of_month    INTEGER,     -- 1-28 (for MONTHLY)
    run_time        TIME         NOT NULL DEFAULT '07:00',
    output_format   VARCHAR(10)  NOT NULL DEFAULT 'XLSX'
                        CHECK (output_format IN ('XLSX','CSV','PDF')),
    recipients      JSONB        NOT NULL DEFAULT '[]',
    -- [{"user_id": 1, "email": "x@y.com"}, ...]
    is_enabled      BOOLEAN      NOT NULL DEFAULT TRUE,
    last_run_at     TIMESTAMPTZ,
    next_run_at     TIMESTAMPTZ,
    created_by      BIGINT       REFERENCES core.users(id),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------
-- REPORT RUN HISTORY — audit trail of generated reports
-- ----------------------------------------------------------------
CREATE TABLE analytics.report_run_history (
    id              BIGSERIAL    PRIMARY KEY,
    report_id       BIGINT       REFERENCES analytics.saved_reports(id),
    schedule_id     BIGINT       REFERENCES analytics.report_schedules(id),
    triggered_by    VARCHAR(20)  NOT NULL DEFAULT 'MANUAL'
                        CHECK (triggered_by IN ('MANUAL','SCHEDULED','API')),
    output_format   VARCHAR(10)  NOT NULL,
    row_count       INTEGER,
    file_path       VARCHAR(500),
    file_size_bytes BIGINT,
    status          VARCHAR(20)  NOT NULL DEFAULT 'RUNNING'
                        CHECK (status IN ('RUNNING','COMPLETED','FAILED')),
    error_message   TEXT,
    run_by          BIGINT       REFERENCES core.users(id),
    started_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    completed_at    TIMESTAMPTZ,
    distributed_to  JSONB        DEFAULT '[]'
);

CREATE INDEX idx_report_runs_report ON analytics.report_run_history(report_id);
CREATE INDEX idx_report_runs_status ON analytics.report_run_history(status);

-- ================================================================
-- SEED: DATA SOURCES
-- ================================================================
INSERT INTO analytics.report_data_sources (source_code, source_label, base_sql, module, description, sort_order) VALUES
('EMPLOYEES', 'Employee Master List',
 'SELECT e.id, e.employee_no, e.first_name, e.last_name, e.first_name || '' '' || e.last_name AS full_name, e.gender, e.date_of_birth, e.date_hired, e.is_active, d.name AS department, pos.title AS position, jg.grade_level AS salary_grade, et.name AS employment_type, e.work_email, e.mobile_no FROM core.employees e LEFT JOIN core.departments d ON d.id = e.department_id LEFT JOIN core.positions pos ON pos.id = e.position_id LEFT JOIN core.job_grades jg ON jg.id = e.job_grade_id LEFT JOIN core.employment_types et ON et.id = e.employment_type_id WHERE e.is_active = TRUE',
 'core', 'Active employee records with department, position, salary grade', 10),

('ATTENDANCE', 'Attendance Records',
 'SELECT a.id, a.work_date, e.employee_no, e.first_name || '' '' || e.last_name AS employee_name, d.name AS department, a.time_in::text AS time_in, a.time_out::text AS time_out, a.hours_worked, a.hours_late, a.hours_undertime, a.hours_overtime, a.status FROM attendance.att_daily a JOIN core.employees e ON e.id = a.employee_id LEFT JOIN core.departments d ON d.id = e.department_id',
 'attendance', 'Daily attendance records with time-in/out and status', 20),

('LEAVE_REQUESTS', 'Leave Requests',
 'SELECT lr.id, e.employee_no, e.first_name || '' '' || e.last_name AS employee_name, d.name AS department, lt.name AS leave_type, lr.date_from, lr.date_to, lr.days_applied, lr.status, lr.created_at AS filed_date FROM leave_mgmt.lv_requests lr JOIN core.employees e ON e.id = lr.employee_id LEFT JOIN core.departments d ON d.id = e.department_id LEFT JOIN leave_mgmt.lv_leave_types lt ON lt.id = lr.leave_type_id',
 'leave_mgmt', 'Leave requests with type, dates, status', 30),

('LEAVE_BALANCES', 'Leave Balances',
 'SELECT lb.id, e.employee_no, e.first_name || '' '' || e.last_name AS employee_name, d.name AS department, lt.name AS leave_type, lb.accrued_days, lb.used_days, lb.pending_days, lb.accrued_days - lb.used_days - lb.pending_days AS available FROM leave_mgmt.lv_balances lb JOIN core.employees e ON e.id = lb.employee_id LEFT JOIN core.departments d ON d.id = e.department_id LEFT JOIN leave_mgmt.lv_leave_types lt ON lt.id = lb.leave_type_id',
 'leave_mgmt', 'Current leave balance by employee and type', 35),

('PAYROLL', 'Payroll Register',
 'SELECT ep.id, pr.id AS run_id, pp.period_code, e.employee_no, e.first_name || '' '' || e.last_name AS employee_name, d.name AS department, ep.basic_pay, ep.allowances_total, ep.gross_pay, ep.gsis_ps, ep.pagibig_ps, ep.philhealth_ee, ep.tax_withheld, ep.loan_deductions, ep.total_deductions, ep.net_pay FROM payroll.pay_employee_payroll ep JOIN payroll.pay_runs pr ON pr.id = ep.run_id JOIN payroll.pay_periods pp ON pp.id = pr.period_id JOIN core.employees e ON e.id = ep.employee_id LEFT JOIN core.departments d ON d.id = e.department_id',
 'payroll', 'Payroll register with earnings, deductions, net pay', 40),

('LOANS', 'Employee Loans',
 'SELECT l.id, e.employee_no, e.first_name || '' '' || e.last_name AS employee_name, d.name AS department, l.loan_type, l.reference_no, l.principal_amount, l.outstanding_balance, l.monthly_deduction, l.total_months, l.months_paid, l.start_date, l.status FROM payroll.pay_loans l JOIN core.employees e ON e.id = l.employee_id LEFT JOIN core.departments d ON d.id = e.department_id',
 'payroll', 'Loan records with balance and payment status', 45),

('TRAINING', 'Training Records',
 'SELECT en.id, e.employee_no, e.first_name || '' '' || e.last_name AS employee_name, d.name AS department, p.title AS program, p.category, p.duration_hours, s.session_date, s.venue, en.status, en.score, en.completion_date FROM learning.lrn_enrollments en JOIN core.employees e ON e.id = en.employee_id LEFT JOIN core.departments d ON d.id = e.department_id JOIN learning.lrn_sessions s ON s.id = en.session_id JOIN learning.lrn_programs p ON p.id = s.program_id',
 'learning', 'Training enrollment records with scores and completion', 50),

('IPCR_RATINGS', 'IPCR Performance Ratings',
 'SELECT s.id, e.employee_no, e.first_name || '' '' || e.last_name AS employee_name, d.name AS department, c.name AS cycle_name, s.final_numerical_rating, s.adjectival_rating, s.pbb_eligible, s.step_increment_eligible, s.approved_at FROM performance.perf_ipcr_summary s JOIN core.employees e ON e.id = s.employee_id LEFT JOIN core.departments d ON d.id = e.department_id JOIN performance.perf_cycles c ON c.id = s.cycle_id',
 'performance', 'IPCR summary ratings with PBB/step increment eligibility', 55),

('PLANTILLA', 'Plantilla of Personnel',
 'SELECT pi.id, pi.item_number, pi.position_title, pi.salary_grade, pi.step_no, d.name AS department, pi.status, e.first_name || '' '' || e.last_name AS incumbent_name FROM recruitment.rec_plantilla_items pi LEFT JOIN core.departments d ON d.id = pi.department_id LEFT JOIN core.employees e ON e.id = pi.incumbent_employee_id',
 'recruitment', 'Authorized positions with incumbents and vacancies', 60)
ON CONFLICT (source_code) DO NOTHING;

-- ================================================================
-- SEED: FIELD REGISTRY (auto-populate from data sources)
-- ================================================================
-- Employee fields
INSERT INTO analytics.report_field_registry (source_id, field_code, field_label, field_type, sql_expression, is_groupable, is_aggregatable, default_aggregate, sort_order)
SELECT s.id, f.code, f.label, f.ftype, f.expr, f.grp, f.agg, f.dagg, f.srt
FROM analytics.report_data_sources s,
(VALUES
  ('employee_no',     'Employee No.',     'TEXT',     'employee_no',     TRUE,  FALSE, NULL,    10),
  ('full_name',       'Full Name',        'TEXT',     'full_name',       FALSE, FALSE, NULL,    20),
  ('gender',          'Gender',           'TEXT',     'gender',          TRUE,  TRUE,  'COUNT', 30),
  ('date_of_birth',   'Date of Birth',    'DATE',     'date_of_birth',   FALSE, FALSE, NULL,    40),
  ('date_hired',      'Date Hired',       'DATE',     'date_hired',      FALSE, FALSE, NULL,    50),
  ('department',      'Department',       'TEXT',     'department',      TRUE,  TRUE,  'COUNT', 60),
  ('position',        'Position',         'TEXT',     'position',        TRUE,  TRUE,  'COUNT', 70),
  ('salary_grade',    'Salary Grade',     'NUMBER',   'salary_grade',    TRUE,  TRUE,  'COUNT', 80),
  ('employment_type', 'Employment Type',  'TEXT',     'employment_type', TRUE,  TRUE,  'COUNT', 90),
  ('work_email',      'Work Email',       'TEXT',     'work_email',      FALSE, FALSE, NULL,    100),
  ('mobile_no',       'Mobile No.',     'TEXT',     'mobile_no',       FALSE, FALSE, NULL,    110)
) AS f(code, label, ftype, expr, grp, agg, dagg, srt)
WHERE s.source_code = 'EMPLOYEES'
ON CONFLICT (source_id, field_code) DO NOTHING;

-- Attendance fields
INSERT INTO analytics.report_field_registry (source_id, field_code, field_label, field_type, sql_expression, is_groupable, is_aggregatable, default_aggregate, sort_order)
SELECT s.id, f.code, f.label, f.ftype, f.expr, f.grp, f.agg, f.dagg, f.srt
FROM analytics.report_data_sources s,
(VALUES
  ('work_date',       'Work Date',        'DATE',     'work_date',       TRUE,  FALSE, NULL,    10),
  ('employee_name',   'Employee',         'TEXT',     'employee_name',   TRUE,  FALSE, NULL,    20),
  ('department',      'Department',       'TEXT',     'department',      TRUE,  TRUE,  'COUNT', 30),
  ('time_in',         'Time In',          'TEXT',     'time_in',         FALSE, FALSE, NULL,    40),
  ('time_out',        'Time Out',         'TEXT',     'time_out',        FALSE, FALSE, NULL,    50),
  ('hours_worked',    'Hours Worked',     'NUMBER',   'hours_worked',    FALSE, TRUE,  'SUM',   60),
  ('hours_late',      'Late (hrs)',       'NUMBER',   'hours_late',      FALSE, TRUE,  'SUM',   70),
  ('hours_undertime', 'Undertime (hrs)',  'NUMBER',   'hours_undertime', FALSE, TRUE,  'SUM',   75),
  ('hours_overtime',  'Overtime (hrs)',   'NUMBER',   'hours_overtime',  FALSE, TRUE,  'SUM',   76),
  ('status',          'Status',           'TEXT',     'status',          TRUE,  TRUE,  'COUNT', 80)
) AS f(code, label, ftype, expr, grp, agg, dagg, srt)
WHERE s.source_code = 'ATTENDANCE'
ON CONFLICT (source_id, field_code) DO NOTHING;

-- Payroll fields
INSERT INTO analytics.report_field_registry (source_id, field_code, field_label, field_type, sql_expression, is_groupable, is_aggregatable, default_aggregate, sort_order)
SELECT s.id, f.code, f.label, f.ftype, f.expr, f.grp, f.agg, f.dagg, f.srt
FROM analytics.report_data_sources s,
(VALUES
  ('employee_name',      'Employee',         'TEXT',     'employee_name',      TRUE,  FALSE, NULL,    10),
  ('department',         'Department',       'TEXT',     'department',         TRUE,  TRUE,  'COUNT', 20),
  ('basic_pay',          'Basic Pay',        'CURRENCY','basic_pay',          FALSE, TRUE,  'SUM',   30),
  ('allowances_total',   'Allowances',       'CURRENCY','allowances_total',   FALSE, TRUE,  'SUM',   40),
  ('gross_pay',          'Gross Pay',        'CURRENCY','gross_pay',          FALSE, TRUE,  'SUM',   50),
  ('gsis_ps',            'GSIS (EE)',        'CURRENCY','gsis_ps',            FALSE, TRUE,  'SUM',   60),
  ('pagibig_ps',         'Pag-IBIG (EE)',    'CURRENCY','pagibig_ps',         FALSE, TRUE,  'SUM',   70),
  ('philhealth_ee',      'PhilHealth (EE)',  'CURRENCY','philhealth_ee',      FALSE, TRUE,  'SUM',   80),
  ('tax_withheld',       'Tax Withheld',     'CURRENCY','tax_withheld',       FALSE, TRUE,  'SUM',   90),
  ('total_deductions',   'Total Deductions', 'CURRENCY','total_deductions',   FALSE, TRUE,  'SUM',   100),
  ('net_pay',            'Net Pay',          'CURRENCY','net_pay',            FALSE, TRUE,  'SUM',   110)
) AS f(code, label, ftype, expr, grp, agg, dagg, srt)
WHERE s.source_code = 'PAYROLL'
ON CONFLICT (source_id, field_code) DO NOTHING;

-- ================================================================
-- SEED: PAGE REGISTRY
-- ================================================================
INSERT INTO core.page_registry
    (path, title, nav_group, nav_label, module, nav_icon, nav_order, requires_feature)
VALUES
    ('/reports/builder',   'Report Builder',     'Analytics', 'Builder',   'analytics', '🛠️', 15, NULL),
    ('/reports/saved',     'My Reports',         'Analytics', 'My Reports','analytics', '📁', 16, NULL),
    ('/reports/scheduled', 'Scheduled Reports',  'Analytics', 'Scheduled', 'analytics', '⏰', 17, NULL)
ON CONFLICT (path) DO NOTHING;

-- Grant access
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r.code, p.id, TRUE
FROM core.page_registry p
CROSS JOIN (VALUES ('SUPER_ADMIN'), ('HR_ADMIN'), ('MANAGER'), ('EXECUTIVE')) AS r(code)
WHERE p.path IN ('/reports/builder', '/reports/saved', '/reports/scheduled')
ON CONFLICT DO NOTHING;
