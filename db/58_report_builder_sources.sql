-- ================================================================
-- HCM360 — 58: REPORT BUILDER — Additional Data Sources
--
-- Expands analytics.report_data_sources + report_field_registry to
-- cover every module with reporting-worthy data:
--   • core: departments, positions
--   • attendance: face check-ins
--   • leave_mgmt: leave types
--   • payroll: pay adjustments
--   • recruitment: appointments, eligibilities
--   • learning: training attendance, NRFs
--   • rewards: loyalty milestones, step increments
--   • dms: SALN filings, document signatures
--   • core: LGU contracts, travel orders, locator slips, PDS
--   • core: retirement tracking
--   • analytics: workforce scenarios, attrition risk
--   • ai: risk scores
--   • access: role access audit
--
-- Plus a guided tour for /reports/builder.
-- ================================================================
SET search_path TO analytics, core, public;


-- ══════════════════════════════════════════════════════════════════════
-- 1. NEW DATA SOURCES
-- ══════════════════════════════════════════════════════════════════════
INSERT INTO analytics.report_data_sources
    (source_code, source_label, module, description, base_sql, is_active, sort_order)
VALUES
    -- CORE
    ('DEPARTMENTS', 'Departments', 'core',
     'Organizational departments with head and parent hierarchy',
     'SELECT d.id, d.code, d.name AS dept_name, d.cost_center_code, d.is_active,
             p.name AS parent_dept, u.first_name || '' '' || u.last_name AS head_name,
             (SELECT COUNT(*) FROM core.employees e WHERE e.department_id = d.id AND e.status=''ACTIVE'') AS headcount
      FROM core.departments d
      LEFT JOIN core.departments p ON p.id = d.parent_id
      LEFT JOIN core.employees u ON u.id = d.head_employee_id',
     TRUE, 10),

    ('POSITIONS', 'Positions', 'core',
     'Positions with job grade and department linkage',
     'SELECT p.id, p.code, p.title, p.is_plantilla,
             d.name AS department, jg.code AS salary_grade, jg.salary_min, jg.salary_max,
             (SELECT COUNT(*) FROM core.employees e WHERE e.position_id = p.id AND e.status=''ACTIVE'') AS filled
      FROM core.positions p
      LEFT JOIN core.departments d ON d.id = p.department_id
      LEFT JOIN core.job_grades jg ON jg.id = p.job_grade_id',
     TRUE, 11),

    -- ATTENDANCE
    ('FACE_CHECKINS', 'Face Check-Ins', 'attendance',
     'Camera + GPS check-in events (G05/G06)',
     'SELECT c.id, c.check_type, c.checked_at, c.latitude, c.longitude, c.accuracy_m,
             c.face_match_score, c.face_verified, c.geo_verified, c.device_kind, c.activity,
             e.employee_no, e.first_name || '' '' || e.last_name AS employee_name,
             d.name AS department
      FROM attendance.att_checkins c
      JOIN core.employees e ON e.id = c.employee_id
      LEFT JOIN core.departments d ON d.id = e.department_id',
     TRUE, 20),

    -- LEAVE
    ('LEAVE_TYPES', 'Leave Types', 'leave_mgmt',
     'Master list of leave types with legal basis',
     'SELECT id, code, name, category, legal_basis, color, is_paid, requires_document,
             max_days_per_filing, gender_restriction, is_active
      FROM leave_mgmt.lv_types',
     TRUE, 30),

    -- PAYROLL
    ('PAYSLIPS', 'Payslips Detail', 'payroll',
     'Individual payslip line items per pay run',
     'SELECT ep.id, e.employee_no, e.first_name || '' '' || e.last_name AS employee_name,
             d.name AS department, p.period_code, p.period_type,
             p.date_from AS cutoff_from, p.date_to AS cutoff_to, p.payment_date,
             ep.basic_pay, ep.gross_pay, ep.sss_ee AS sss, ep.philhealth_ee AS philhealth,
             ep.pagibig_ee AS pagibig, ep.tax_withheld, ep.total_deductions, ep.net_pay
      FROM payroll.pay_employee_payroll ep
      JOIN core.employees e ON e.id = ep.employee_id
      LEFT JOIN core.departments d ON d.id = e.department_id
      JOIN payroll.pay_runs r ON r.id = ep.run_id
      JOIN payroll.pay_periods p ON p.id = r.period_id',
     TRUE, 40),

    -- RECRUITMENT
    ('APPOINTMENTS', 'Appointments (CSC Form 33)', 'recruitment',
     'Employee appointments with attestation status',
     'SELECT a.id, a.appointment_no, a.appointment_type, a.effective_date, a.end_date,
             a.salary_grade, a.step_no, a.monthly_salary, a.status,
             a.csc_attested_at, e.employee_no,
             e.first_name || '' '' || e.last_name AS employee_name,
             p.title AS position_title, d.name AS department
      FROM recruitment.rec_appointments a
      JOIN core.employees e ON e.id = a.employee_id
      LEFT JOIN core.positions p ON p.id = a.position_id
      LEFT JOIN core.departments d ON d.id = e.department_id',
     TRUE, 50),

    ('CSC_ELIGIBILITIES', 'CSC Eligibilities (Employee)', 'recruitment',
     'Employee civil-service eligibility records with 1st/2nd level classification',
     'SELECT ee.id, e.employee_no, e.first_name || '' '' || e.last_name AS employee_name,
             e.gender, d.name AS department,
             ce.code AS eligibility_code, ce.name AS eligibility_name,
             ce.level AS eligibility_level, ce.category,
             ee.rating, ee.exam_date, ee.exam_place, ee.license_no, ee.is_verified
      FROM recruitment.rec_employee_eligibilities ee
      JOIN recruitment.rec_csc_eligibilities ce ON ce.id = ee.eligibility_id
      JOIN core.employees e ON e.id = ee.employee_id
      LEFT JOIN core.departments d ON d.id = e.department_id',
     TRUE, 51),

    -- LEARNING
    ('TRAINING_ATTENDANCE', 'Training Attendance (Geotag)', 'learning',
     'Individual geotagged training attendance events (G09)',
     'SELECT al.id, al.checked_in_at, al.shift_period, al.session_date,
             al.checkin_lat, al.checkin_lng, al.checkin_accuracy_m, al.is_valid,
             e.employee_no, e.first_name || '' '' || e.last_name AS employee_name,
             pr.title AS training_title, s.venue, s.facilitator
      FROM learning.lrn_attendance_logs al
      JOIN core.employees e ON e.id = al.employee_id
      JOIN learning.lrn_sessions s ON s.id = al.session_id
      JOIN learning.lrn_programs pr ON pr.id = s.program_id',
     TRUE, 60),

    ('NARRATIVE_REPORTS', 'Narrative Reports (NRF)', 'learning',
     'Post-training narrative reports with ratings',
     'SELECT nr.id, nr.training_title, nr.training_dates, nr.venue, nr.facilitator,
             nr.evaluation_rating, nr.status, nr.submitted_at, nr.approved_at,
             e.employee_no, e.first_name || '' '' || e.last_name AS employee_name,
             d.name AS department
      FROM learning.lrn_narrative_reports nr
      JOIN core.employees e ON e.id = nr.employee_id
      LEFT JOIN core.departments d ON d.id = e.department_id',
     TRUE, 61),

    -- REWARDS
    ('LOYALTY_AWARDS', 'Loyalty Service Awards', 'rewards',
     'Loyalty milestones (10/15/20/25/30 years) with memos',
     'SELECT m.id, m.service_years, m.eligibility_date, m.status, m.award_type,
             m.award_value, m.memo_no, m.awarded_at,
             e.employee_no, e.first_name || '' '' || e.last_name AS employee_name,
             e.date_hired, d.name AS department, p.title AS position
      FROM rewards.rwd_loyalty_milestones m
      JOIN core.employees e ON e.id = m.employee_id
      LEFT JOIN core.departments d ON d.id = e.department_id
      LEFT JOIN core.positions p ON p.id = e.position_id',
     TRUE, 70),

    ('STEP_INCREMENTS', 'Step Increments', 'core',
     '3-year step increments with current status (G12)',
     'SELECT h.id, h.increment_no, h.due_date, h.effective_date, h.status,
             h.from_salary_grade, h.to_salary_grade, h.notice_sent_at, h.approved_at,
             e.employee_no, e.first_name || '' '' || e.last_name AS employee_name,
             d.name AS department, p.title AS position
      FROM core.step_increment_history h
      JOIN core.employees e ON e.id = h.employee_id
      LEFT JOIN core.departments d ON d.id = e.department_id
      LEFT JOIN core.positions p ON p.id = e.position_id',
     TRUE, 71),

    -- DMS
    ('SALN_FILINGS', 'SALN Filings', 'dms',
     'Statement of Assets, Liabilities & Net Worth submissions (G16)',
     'SELECT f.id, f.filing_year, f.mode, f.status, f.filed_at, f.verified_at,
             e.employee_no, e.first_name || '' '' || e.last_name AS employee_name,
             d.name AS department
      FROM dms.saln_filings f
      JOIN core.employees e ON e.id = f.employee_id
      LEFT JOIN core.departments d ON d.id = e.department_id',
     TRUE, 80),

    ('SIGNATURES', 'Document Signatures', 'core',
     'E-signatures captured (canvas + DocuSign) across documents (G08)',
     'SELECT s.id, s.entity_kind, s.entity_id, s.signer_name, s.signer_role,
             s.signature_mode, s.status, s.signed_at, s.created_at
      FROM core.document_signatures s',
     TRUE, 81),

    -- CORE: LGU-specific
    ('LGU_CONTRACTS', 'LGU Contracts (JO/LSB/BHW/NS)', 'core',
     'Job Order, LSB, BHW, Nutritionist Scholar contracts (G07)',
     'SELECT c.id, c.contract_no, ct.code AS type_code, ct.name AS contract_type,
             c.full_name, c.position_title, d.name AS department,
             c.barangay, c.school, c.date_from, c.date_to, c.rate, c.rate_type,
             c.funds_source, c.status, c.approved_at
      FROM core.lgu_contracts c
      JOIN core.lgu_contract_types ct ON ct.id = c.contract_type_id
      LEFT JOIN core.departments d ON d.id = c.department_id',
     TRUE, 90),

    ('TRAVEL_ORDERS', 'Travel Orders', 'core',
     'Travel order requests with approval chain (G03)',
     'SELECT t.id, t.control_no, t.purpose, t.destination,
             t.date_from, t.date_to, t.mode_of_transport, t.funds_source,
             t.estimated_cost, t.status, t.submitted_at,
             e.employee_no, e.first_name || '' '' || e.last_name AS employee_name,
             d.name AS department
      FROM core.travel_orders t
      JOIN core.employees e ON e.id = t.employee_id
      LEFT JOIN core.departments d ON d.id = e.department_id',
     TRUE, 91),

    ('LOCATOR_SLIPS', 'Locator Slips', 'core',
     'Brief out-of-office notifications (G04)',
     'SELECT ls.id, ls.slip_date, ls.purpose, ls.destination,
             ls.time_out, ls.expected_return, ls.actual_return, ls.status,
             e.employee_no, e.first_name || '' '' || e.last_name AS employee_name,
             d.name AS department
      FROM core.locator_slips ls
      JOIN core.employees e ON e.id = ls.employee_id
      LEFT JOIN core.departments d ON d.id = e.department_id',
     TRUE, 92),

    ('RETIREMENT', 'Retirement Tracking', 'core',
     'Upcoming retirements (age 60 early / 65 mandatory) (G13)',
     'SELECT t.id, t.eligibility_type, t.eligible_date, t.retirement_date, t.status,
             t.notice_sent_at, e.employee_no,
             e.first_name || '' '' || e.last_name AS employee_name,
             e.gender, e.date_of_birth,
             EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.date_of_birth))::int AS age_now,
             d.name AS department
      FROM core.retirement_tracking t
      JOIN core.employees e ON e.id = t.employee_id
      LEFT JOIN core.departments d ON d.id = e.department_id',
     TRUE, 93),

    ('CS_FORM_6', 'CS Form No. 6 Leave Applications', 'leave_mgmt',
     'Leave requests filed under CSC compliance mode (G01)',
     'SELECT r.id, r.reference_no, r.date_from, r.date_to, r.days_requested,
             r.whereabouts, r.whereabouts_detail, r.commutation, r.date_of_filing,
             r.status, r.recommend_action, r.head_action,
             lt.code AS leave_code, lt.name AS leave_type,
             e.employee_no, e.first_name || '' '' || e.last_name AS employee_name,
             d.name AS department
      FROM leave_mgmt.lv_requests r
      JOIN leave_mgmt.lv_types lt ON lt.id = r.leave_type_id
      JOIN core.employees e ON e.id = r.employee_id
      LEFT JOIN core.departments d ON d.id = e.department_id
      WHERE r.cs_form6_mode = TRUE',
     TRUE, 94),

    -- ANALYTICS / WORKFORCE PLANNING
    ('WFP_SCENARIOS', 'Workforce Planning Scenarios', 'analytics',
     'Headcount & cost scenarios',
     'SELECT s.id, s.name, s.description, s.scenario_type, s.status,
             s.base_date, s.horizon_months, s.created_at,
             u.display_name AS created_by_name,
             (SELECT COUNT(*) FROM analytics.wfp_headcount_plans hp WHERE hp.scenario_id=s.id) AS plan_lines,
             (SELECT COALESCE(SUM(total_cost),0) FROM analytics.wfp_cost_projections cp WHERE cp.scenario_id=s.id) AS projected_cost
      FROM analytics.wfp_scenarios s
      LEFT JOIN core.users u ON u.id = s.created_by',
     TRUE, 100),

    ('WFP_HEADCOUNT', 'Workforce Headcount Plans', 'analytics',
     'Quarterly headcount plan lines per department',
     'SELECT hp.id, s.name AS scenario_name, s.status AS scenario_status,
             hp.period_label, hp.period_start, d.name AS department,
             hp.current_hc, hp.planned_hc, hp.planned_hires, hp.planned_exits,
             hp.avg_cost, hp.total_cost
      FROM analytics.wfp_headcount_plans hp
      JOIN analytics.wfp_scenarios s ON s.id = hp.scenario_id
      LEFT JOIN core.departments d ON d.id = hp.department_id',
     TRUE, 101),

    -- AI / ATTRITION
    ('ATTRITION_RISK', 'Attrition Risk Scores', 'ai',
     'AI-scored retention risk per employee (G18)',
     'SELECT p.id, p.score_date, p.risk_score, p.risk_level, p.confidence,
             p.model_version, e.employee_no,
             e.first_name || '' '' || e.last_name AS employee_name,
             e.gender, e.date_hired,
             EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.date_hired))::int AS tenure_years,
             d.name AS department, pos.title AS position
      FROM ai.ai_risk_scores p
      JOIN core.employees e ON e.id = p.employee_id
      LEFT JOIN core.departments d ON d.id = e.department_id
      LEFT JOIN core.positions pos ON pos.id = e.position_id
      WHERE p.risk_type = ''ATTRITION''',
     TRUE, 110),

    -- ADMIN / AUDIT
    ('ROLE_ACCESS', 'Role Page Access Audit', 'admin',
     'Which roles can access which pages',
     'SELECT pg.path, pg.title, pg.module, pg.nav_group,
             rpa.role_code, rpa.can_access, pg.is_visible
      FROM core.page_registry pg
      LEFT JOIN core.role_page_access rpa ON rpa.page_id = pg.id',
     TRUE, 120)
ON CONFLICT (source_code) DO UPDATE SET
    source_label = EXCLUDED.source_label,
    module       = EXCLUDED.module,
    description  = EXCLUDED.description,
    base_sql     = EXCLUDED.base_sql,
    is_active    = EXCLUDED.is_active,
    sort_order   = EXCLUDED.sort_order;


-- ══════════════════════════════════════════════════════════════════════
-- 2. FIELD REGISTRY — per data source
-- (Helper: build field rows using unnest)
-- ══════════════════════════════════════════════════════════════════════
DO $$
DECLARE
    rec RECORD;
    field_def RECORD;
    src_id BIGINT;
BEGIN
    -- DEPARTMENTS
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='DEPARTMENTS';
    FOR field_def IN SELECT * FROM (VALUES
        ('code',           'Code',            'TEXT',     'd.code',           TRUE, TRUE, TRUE, FALSE, NULL),
        ('dept_name',      'Department Name', 'TEXT',     'd.name',           TRUE, TRUE, TRUE, FALSE, NULL),
        ('cost_center_code','Cost Center',    'TEXT',     'd.cost_center_code', TRUE, TRUE, TRUE, FALSE, NULL),
        ('parent_dept',    'Parent Department','TEXT',    'p.name',           TRUE, TRUE, TRUE, FALSE, NULL),
        ('head_name',      'Head of Dept.',   'TEXT',     'u.first_name || '' '' || u.last_name', TRUE, TRUE, TRUE, FALSE, NULL),
        ('headcount',      'Active Headcount','NUMBER',   'NULL',              FALSE, TRUE, TRUE, TRUE,  'SUM'),
        ('is_active',      'Active?',         'BOOLEAN',  'd.is_active',       TRUE, TRUE, TRUE, FALSE, NULL)
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;

    -- POSITIONS
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='POSITIONS';
    FOR field_def IN SELECT * FROM (VALUES
        ('code',         'Code',          'TEXT',   'p.code',  TRUE, TRUE, TRUE, FALSE, NULL),
        ('title',        'Title',         'TEXT',   'p.title', TRUE, TRUE, TRUE, FALSE, NULL),
        ('department',   'Department',    'TEXT',   'd.name',  TRUE, TRUE, TRUE, FALSE, NULL),
        ('salary_grade', 'Salary Grade',  'TEXT',   'jg.code', TRUE, TRUE, TRUE, FALSE, NULL),
        ('salary_min',   'Min Salary',    'CURRENCY','jg.salary_min', FALSE, TRUE, TRUE, TRUE, 'AVG'),
        ('salary_max',   'Max Salary',    'CURRENCY','jg.salary_max', FALSE, TRUE, TRUE, TRUE, 'AVG'),
        ('is_plantilla', 'Is Plantilla?', 'BOOLEAN','p.is_plantilla', TRUE, TRUE, TRUE, FALSE, NULL),
        ('filled',       'Filled Count',  'NUMBER', 'NULL',    FALSE, TRUE, TRUE, TRUE, 'SUM')
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;

    -- FACE_CHECKINS
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='FACE_CHECKINS';
    FOR field_def IN SELECT * FROM (VALUES
        ('check_type',   'Check Type',    'TEXT', 'c.check_type', TRUE,TRUE,TRUE,FALSE,NULL),
        ('checked_at',   'Checked At',    'DATE', 'c.checked_at', TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_no',  'Employee No',   'TEXT', 'e.employee_no',TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_name','Employee',      'TEXT', 'e.first_name || '' '' || e.last_name',TRUE,TRUE,TRUE,FALSE,NULL),
        ('department',   'Department',    'TEXT', 'd.name',       TRUE,TRUE,TRUE,FALSE,NULL),
        ('face_verified','Face Verified', 'BOOLEAN','c.face_verified',TRUE,TRUE,TRUE,FALSE,NULL),
        ('geo_verified', 'Geo Verified',  'BOOLEAN','c.geo_verified', TRUE,TRUE,TRUE,FALSE,NULL),
        ('face_match_score','Face Score', 'NUMBER','c.face_match_score',FALSE,TRUE,TRUE,TRUE,'AVG'),
        ('accuracy_m',   'GPS Accuracy(m)','NUMBER','c.accuracy_m',FALSE,TRUE,TRUE,TRUE,'AVG'),
        ('device_kind',  'Device',        'TEXT', 'c.device_kind',TRUE,TRUE,TRUE,FALSE,NULL),
        ('activity',     'Activity',      'TEXT', 'c.activity',   TRUE,TRUE,TRUE,FALSE,NULL)
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;

    -- LEAVE_TYPES
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='LEAVE_TYPES';
    FOR field_def IN SELECT * FROM (VALUES
        ('code',     'Code',       'TEXT',   'code',       TRUE,TRUE,TRUE,FALSE,NULL),
        ('name',     'Name',       'TEXT',   'name',       TRUE,TRUE,TRUE,FALSE,NULL),
        ('category', 'Category',   'TEXT',   'category',   TRUE,TRUE,TRUE,FALSE,NULL),
        ('legal_basis','Legal Basis','TEXT', 'legal_basis',TRUE,TRUE,TRUE,FALSE,NULL),
        ('is_paid',  'Paid?',      'BOOLEAN','is_paid',    TRUE,TRUE,TRUE,FALSE,NULL),
        ('max_days_per_filing','Max Days','NUMBER','max_days_per_filing',FALSE,TRUE,TRUE,TRUE,'MAX'),
        ('gender_restriction','Gender','TEXT','gender_restriction',TRUE,TRUE,TRUE,FALSE,NULL)
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;

    -- PAYSLIPS
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='PAYSLIPS';
    FOR field_def IN SELECT * FROM (VALUES
        ('employee_no',    'Employee No',    'TEXT', 'e.employee_no',TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_name',  'Employee',       'TEXT', 'e.first_name || '' '' || e.last_name',TRUE,TRUE,TRUE,FALSE,NULL),
        ('department',     'Department',     'TEXT', 'd.name',       TRUE,TRUE,TRUE,FALSE,NULL),
        ('period_code',    'Period',         'TEXT', 'p.code',       TRUE,TRUE,TRUE,FALSE,NULL),
        ('payment_date',   'Pay Date',       'DATE', 'p.payment_date',TRUE,TRUE,TRUE,FALSE,NULL),
        ('basic_pay',      'Basic Pay',      'CURRENCY','ep.basic_pay',FALSE,TRUE,TRUE,TRUE,'SUM'),
        ('gross_pay',      'Gross Pay',      'CURRENCY','ep.gross_pay',FALSE,TRUE,TRUE,TRUE,'SUM'),
        ('sss',            'SSS EE',         'CURRENCY','ep.sss_ee',  FALSE,TRUE,TRUE,TRUE,'SUM'),
        ('philhealth',     'PhilHealth EE',  'CURRENCY','ep.philhealth_ee',FALSE,TRUE,TRUE,TRUE,'SUM'),
        ('pagibig',        'Pag-IBIG EE',    'CURRENCY','ep.pagibig_ee',FALSE,TRUE,TRUE,TRUE,'SUM'),
        ('tax_withheld',   'Tax Withheld',   'CURRENCY','ep.tax_withheld',FALSE,TRUE,TRUE,TRUE,'SUM'),
        ('total_deductions','Total Deductions','CURRENCY','ep.total_deductions',FALSE,TRUE,TRUE,TRUE,'SUM'),
        ('net_pay',        'Net Pay',        'CURRENCY','ep.net_pay', FALSE,TRUE,TRUE,TRUE,'SUM')
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;

    -- APPOINTMENTS
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='APPOINTMENTS';
    FOR field_def IN SELECT * FROM (VALUES
        ('appointment_no',  'Appt No.',     'TEXT',    'a.appointment_no',TRUE,TRUE,TRUE,FALSE,NULL),
        ('appointment_type','Type',         'TEXT',    'a.appointment_type',TRUE,TRUE,TRUE,FALSE,NULL),
        ('effective_date',  'Effective',    'DATE',    'a.effective_date',TRUE,TRUE,TRUE,FALSE,NULL),
        ('end_date',        'End Date',     'DATE',    'a.end_date',   TRUE,TRUE,TRUE,FALSE,NULL),
        ('salary_grade',    'Salary Grade', 'NUMBER',  'a.salary_grade',TRUE,TRUE,TRUE,FALSE,NULL),
        ('step_no',         'Step',         'NUMBER',  'a.step_no',    TRUE,TRUE,TRUE,FALSE,NULL),
        ('monthly_salary',  'Monthly Salary','CURRENCY','a.monthly_salary',FALSE,TRUE,TRUE,TRUE,'SUM'),
        ('status',          'Status',       'TEXT',    'a.status',     TRUE,TRUE,TRUE,FALSE,NULL),
        ('csc_attested_at', 'CSC Attested', 'DATE',    'a.csc_attested_at',TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_no',     'Employee No',  'TEXT',    'e.employee_no',TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_name',   'Employee',     'TEXT',    'e.first_name || '' '' || e.last_name',TRUE,TRUE,TRUE,FALSE,NULL),
        ('position_title',  'Position',     'TEXT',    'p.title',      TRUE,TRUE,TRUE,FALSE,NULL),
        ('department',      'Department',   'TEXT',    'd.name',       TRUE,TRUE,TRUE,FALSE,NULL)
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;

    -- CSC_ELIGIBILITIES
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='CSC_ELIGIBILITIES';
    FOR field_def IN SELECT * FROM (VALUES
        ('employee_no',       'Employee No','TEXT',   'e.employee_no',TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_name',     'Employee',  'TEXT',    'e.first_name || '' '' || e.last_name',TRUE,TRUE,TRUE,FALSE,NULL),
        ('gender',            'Gender',    'TEXT',    'e.gender',     TRUE,TRUE,TRUE,FALSE,NULL),
        ('department',        'Department','TEXT',    'd.name',       TRUE,TRUE,TRUE,FALSE,NULL),
        ('eligibility_code',  'Code',      'TEXT',    'ce.code',      TRUE,TRUE,TRUE,FALSE,NULL),
        ('eligibility_name',  'Eligibility','TEXT',   'ce.name',      TRUE,TRUE,TRUE,FALSE,NULL),
        ('eligibility_level', 'Level',     'TEXT',    'ce.level',     TRUE,TRUE,TRUE,FALSE,NULL),
        ('category',          'Category',  'TEXT',    'ce.category',  TRUE,TRUE,TRUE,FALSE,NULL),
        ('rating',            'Rating',    'NUMBER',  'ee.rating',    FALSE,TRUE,TRUE,TRUE,'AVG'),
        ('exam_date',         'Exam Date', 'DATE',    'ee.exam_date', TRUE,TRUE,TRUE,FALSE,NULL),
        ('is_verified',       'Verified',  'BOOLEAN', 'ee.is_verified',TRUE,TRUE,TRUE,FALSE,NULL)
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;

    -- TRAINING_ATTENDANCE
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='TRAINING_ATTENDANCE';
    FOR field_def IN SELECT * FROM (VALUES
        ('checked_in_at',  'Checked In',     'DATE',    'al.checked_in_at',  TRUE,TRUE,TRUE,FALSE,NULL),
        ('shift_period',   'Shift',          'TEXT',    'al.shift_period',    TRUE,TRUE,TRUE,FALSE,NULL),
        ('session_date',   'Session Date',   'DATE',    'al.session_date',    TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_no',    'Employee No',    'TEXT',    'e.employee_no',      TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_name',  'Employee',       'TEXT',    'e.first_name || '' '' || e.last_name',TRUE,TRUE,TRUE,FALSE,NULL),
        ('training_title', 'Training',       'TEXT',    'pr.title',           TRUE,TRUE,TRUE,FALSE,NULL),
        ('venue',          'Venue',          'TEXT',    's.venue',            TRUE,TRUE,TRUE,FALSE,NULL),
        ('facilitator',    'Facilitator',    'TEXT',    's.facilitator',      TRUE,TRUE,TRUE,FALSE,NULL),
        ('is_valid',       'Valid?',         'BOOLEAN', 'al.is_valid',        TRUE,TRUE,TRUE,FALSE,NULL),
        ('accuracy_m',     'GPS Accuracy(m)','NUMBER',  'al.checkin_accuracy_m',FALSE,TRUE,TRUE,TRUE,'AVG')
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;

    -- NARRATIVE_REPORTS
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='NARRATIVE_REPORTS';
    FOR field_def IN SELECT * FROM (VALUES
        ('training_title',    'Training',       'TEXT',   'nr.training_title',    TRUE,TRUE,TRUE,FALSE,NULL),
        ('training_dates',    'Dates',          'TEXT',   'nr.training_dates',    TRUE,TRUE,TRUE,FALSE,NULL),
        ('venue',             'Venue',          'TEXT',   'nr.venue',             TRUE,TRUE,TRUE,FALSE,NULL),
        ('facilitator',       'Facilitator',    'TEXT',   'nr.facilitator',       TRUE,TRUE,TRUE,FALSE,NULL),
        ('evaluation_rating', 'Rating',         'NUMBER', 'nr.evaluation_rating', FALSE,TRUE,TRUE,TRUE,'AVG'),
        ('status',            'Status',         'TEXT',   'nr.status',            TRUE,TRUE,TRUE,FALSE,NULL),
        ('submitted_at',      'Submitted',      'DATE',   'nr.submitted_at',      TRUE,TRUE,TRUE,FALSE,NULL),
        ('approved_at',       'Approved',       'DATE',   'nr.approved_at',       TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_no',       'Employee No',    'TEXT',   'e.employee_no',        TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_name',     'Employee',       'TEXT',   'e.first_name || '' '' || e.last_name',TRUE,TRUE,TRUE,FALSE,NULL),
        ('department',        'Department',     'TEXT',   'd.name',               TRUE,TRUE,TRUE,FALSE,NULL)
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;

    -- LOYALTY_AWARDS
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='LOYALTY_AWARDS';
    FOR field_def IN SELECT * FROM (VALUES
        ('service_years',   'Service Years',  'NUMBER',  'm.service_years', TRUE,TRUE,TRUE,FALSE,NULL),
        ('eligibility_date','Eligibility Date','DATE',   'm.eligibility_date',TRUE,TRUE,TRUE,FALSE,NULL),
        ('status',          'Status',         'TEXT',    'm.status',        TRUE,TRUE,TRUE,FALSE,NULL),
        ('award_type',      'Award Type',     'TEXT',    'm.award_type',    TRUE,TRUE,TRUE,FALSE,NULL),
        ('award_value',     'Award Value',    'CURRENCY','m.award_value',   FALSE,TRUE,TRUE,TRUE,'SUM'),
        ('memo_no',         'Memo No',        'TEXT',    'm.memo_no',       TRUE,TRUE,TRUE,FALSE,NULL),
        ('awarded_at',      'Awarded At',     'DATE',    'm.awarded_at',    TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_no',     'Employee No',    'TEXT',    'e.employee_no',   TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_name',   'Employee',       'TEXT',    'e.first_name || '' '' || e.last_name',TRUE,TRUE,TRUE,FALSE,NULL),
        ('date_hired',      'Date Hired',     'DATE',    'e.date_hired',    TRUE,TRUE,TRUE,FALSE,NULL),
        ('department',      'Department',     'TEXT',    'd.name',          TRUE,TRUE,TRUE,FALSE,NULL),
        ('position',        'Position',       'TEXT',    'p.title',         TRUE,TRUE,TRUE,FALSE,NULL)
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;

    -- STEP_INCREMENTS
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='STEP_INCREMENTS';
    FOR field_def IN SELECT * FROM (VALUES
        ('increment_no',   'Inc #',      'NUMBER','h.increment_no', TRUE,TRUE,TRUE,FALSE,NULL),
        ('due_date',       'Due Date',   'DATE',  'h.due_date',     TRUE,TRUE,TRUE,FALSE,NULL),
        ('effective_date', 'Effective',  'DATE',  'h.effective_date',TRUE,TRUE,TRUE,FALSE,NULL),
        ('status',         'Status',     'TEXT',  'h.status',       TRUE,TRUE,TRUE,FALSE,NULL),
        ('from_salary_grade','From Grade','TEXT', 'h.from_salary_grade',TRUE,TRUE,TRUE,FALSE,NULL),
        ('to_salary_grade','To Grade',   'TEXT',  'h.to_salary_grade',TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_no',    'Employee No','TEXT',  'e.employee_no',  TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_name',  'Employee',   'TEXT',  'e.first_name || '' '' || e.last_name',TRUE,TRUE,TRUE,FALSE,NULL),
        ('department',     'Department', 'TEXT',  'd.name',         TRUE,TRUE,TRUE,FALSE,NULL),
        ('position',       'Position',   'TEXT',  'p.title',        TRUE,TRUE,TRUE,FALSE,NULL)
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;

    -- SALN_FILINGS
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='SALN_FILINGS';
    FOR field_def IN SELECT * FROM (VALUES
        ('filing_year',   'Year',       'NUMBER','f.filing_year', TRUE,TRUE,TRUE,FALSE,NULL),
        ('mode',          'Mode',       'TEXT',  'f.mode',        TRUE,TRUE,TRUE,FALSE,NULL),
        ('status',        'Status',     'TEXT',  'f.status',      TRUE,TRUE,TRUE,FALSE,NULL),
        ('filed_at',      'Filed At',   'DATE',  'f.filed_at',    TRUE,TRUE,TRUE,FALSE,NULL),
        ('verified_at',   'Verified',   'DATE',  'f.verified_at', TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_no',   'Employee No','TEXT',  'e.employee_no', TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_name', 'Employee',   'TEXT',  'e.first_name || '' '' || e.last_name',TRUE,TRUE,TRUE,FALSE,NULL),
        ('department',    'Department', 'TEXT',  'd.name',        TRUE,TRUE,TRUE,FALSE,NULL)
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;

    -- SIGNATURES
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='SIGNATURES';
    FOR field_def IN SELECT * FROM (VALUES
        ('entity_kind',    'Entity Kind',   'TEXT','s.entity_kind',   TRUE,TRUE,TRUE,FALSE,NULL),
        ('entity_id',      'Entity ID',     'NUMBER','s.entity_id',   TRUE,TRUE,TRUE,FALSE,NULL),
        ('signer_name',    'Signer',        'TEXT','s.signer_name',   TRUE,TRUE,TRUE,FALSE,NULL),
        ('signer_role',    'Role',          'TEXT','s.signer_role',   TRUE,TRUE,TRUE,FALSE,NULL),
        ('signature_mode', 'Mode',          'TEXT','s.signature_mode',TRUE,TRUE,TRUE,FALSE,NULL),
        ('status',         'Status',        'TEXT','s.status',        TRUE,TRUE,TRUE,FALSE,NULL),
        ('signed_at',      'Signed At',     'DATE','s.signed_at',     TRUE,TRUE,TRUE,FALSE,NULL),
        ('created_at',     'Created At',    'DATE','s.created_at',    TRUE,TRUE,TRUE,FALSE,NULL)
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;

    -- LGU_CONTRACTS
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='LGU_CONTRACTS';
    FOR field_def IN SELECT * FROM (VALUES
        ('contract_no',   'Contract No',   'TEXT',   'c.contract_no',   TRUE,TRUE,TRUE,FALSE,NULL),
        ('type_code',     'Type',          'TEXT',   'ct.code',         TRUE,TRUE,TRUE,FALSE,NULL),
        ('contract_type', 'Contract Type', 'TEXT',   'ct.name',         TRUE,TRUE,TRUE,FALSE,NULL),
        ('full_name',     'Contractor',    'TEXT',   'c.full_name',     TRUE,TRUE,TRUE,FALSE,NULL),
        ('position_title','Position',      'TEXT',   'c.position_title',TRUE,TRUE,TRUE,FALSE,NULL),
        ('department',    'Department',    'TEXT',   'd.name',          TRUE,TRUE,TRUE,FALSE,NULL),
        ('barangay',      'Barangay',      'TEXT',   'c.barangay',      TRUE,TRUE,TRUE,FALSE,NULL),
        ('school',        'School',        'TEXT',   'c.school',        TRUE,TRUE,TRUE,FALSE,NULL),
        ('date_from',     'From',          'DATE',   'c.date_from',     TRUE,TRUE,TRUE,FALSE,NULL),
        ('date_to',       'To',            'DATE',   'c.date_to',       TRUE,TRUE,TRUE,FALSE,NULL),
        ('rate',          'Rate',          'CURRENCY','c.rate',         FALSE,TRUE,TRUE,TRUE,'AVG'),
        ('rate_type',     'Rate Type',     'TEXT',   'c.rate_type',     TRUE,TRUE,TRUE,FALSE,NULL),
        ('funds_source',  'Funds Source',  'TEXT',   'c.funds_source',  TRUE,TRUE,TRUE,FALSE,NULL),
        ('status',        'Status',        'TEXT',   'c.status',        TRUE,TRUE,TRUE,FALSE,NULL)
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;

    -- TRAVEL_ORDERS
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='TRAVEL_ORDERS';
    FOR field_def IN SELECT * FROM (VALUES
        ('control_no',     'Control No',      'TEXT',    't.control_no',   TRUE,TRUE,TRUE,FALSE,NULL),
        ('purpose',        'Purpose',         'TEXT',    't.purpose',      FALSE,TRUE,TRUE,FALSE,NULL),
        ('destination',    'Destination',     'TEXT',    't.destination',  TRUE,TRUE,TRUE,FALSE,NULL),
        ('date_from',      'From',            'DATE',    't.date_from',    TRUE,TRUE,TRUE,FALSE,NULL),
        ('date_to',        'To',              'DATE',    't.date_to',      TRUE,TRUE,TRUE,FALSE,NULL),
        ('mode_of_transport','Transport',     'TEXT',    't.mode_of_transport',TRUE,TRUE,TRUE,FALSE,NULL),
        ('estimated_cost', 'Est. Cost',       'CURRENCY','t.estimated_cost',FALSE,TRUE,TRUE,TRUE,'SUM'),
        ('funds_source',   'Funds Source',    'TEXT',    't.funds_source', TRUE,TRUE,TRUE,FALSE,NULL),
        ('status',         'Status',          'TEXT',    't.status',       TRUE,TRUE,TRUE,FALSE,NULL),
        ('submitted_at',   'Submitted',       'DATE',    't.submitted_at', TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_no',    'Employee No',     'TEXT',    'e.employee_no',  TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_name',  'Employee',        'TEXT',    'e.first_name || '' '' || e.last_name',TRUE,TRUE,TRUE,FALSE,NULL),
        ('department',     'Department',      'TEXT',    'd.name',         TRUE,TRUE,TRUE,FALSE,NULL)
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;

    -- LOCATOR_SLIPS
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='LOCATOR_SLIPS';
    FOR field_def IN SELECT * FROM (VALUES
        ('slip_date',       'Date',           'DATE','ls.slip_date',       TRUE,TRUE,TRUE,FALSE,NULL),
        ('purpose',         'Purpose',        'TEXT','ls.purpose',         FALSE,TRUE,TRUE,FALSE,NULL),
        ('destination',     'Destination',    'TEXT','ls.destination',     TRUE,TRUE,TRUE,FALSE,NULL),
        ('time_out',        'Out',            'TEXT','ls.time_out::text',  FALSE,TRUE,TRUE,FALSE,NULL),
        ('expected_return', 'Expected Return','TEXT','ls.expected_return::text',FALSE,TRUE,TRUE,FALSE,NULL),
        ('actual_return',   'Actual Return',  'TEXT','ls.actual_return::text',FALSE,TRUE,TRUE,FALSE,NULL),
        ('status',          'Status',         'TEXT','ls.status',          TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_no',     'Employee No',    'TEXT','e.employee_no',      TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_name',   'Employee',       'TEXT','e.first_name || '' '' || e.last_name',TRUE,TRUE,TRUE,FALSE,NULL),
        ('department',      'Department',     'TEXT','d.name',             TRUE,TRUE,TRUE,FALSE,NULL)
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;

    -- RETIREMENT
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='RETIREMENT';
    FOR field_def IN SELECT * FROM (VALUES
        ('eligibility_type','Type',          'TEXT','t.eligibility_type',TRUE,TRUE,TRUE,FALSE,NULL),
        ('eligible_date',   'Eligible Date', 'DATE','t.eligible_date',   TRUE,TRUE,TRUE,FALSE,NULL),
        ('retirement_date', 'Retirement Date','DATE','t.retirement_date',TRUE,TRUE,TRUE,FALSE,NULL),
        ('status',          'Status',        'TEXT','t.status',          TRUE,TRUE,TRUE,FALSE,NULL),
        ('notice_sent_at',  'Notice Sent',   'DATE','t.notice_sent_at',  TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_no',     'Employee No',   'TEXT','e.employee_no',     TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_name',   'Employee',      'TEXT','e.first_name || '' '' || e.last_name',TRUE,TRUE,TRUE,FALSE,NULL),
        ('gender',          'Gender',        'TEXT','e.gender',          TRUE,TRUE,TRUE,FALSE,NULL),
        ('date_of_birth',   'Date of Birth', 'DATE','e.date_of_birth',   TRUE,TRUE,TRUE,FALSE,NULL),
        ('age_now',         'Age Now',       'NUMBER','NULL',            FALSE,TRUE,TRUE,TRUE,'AVG'),
        ('department',      'Department',    'TEXT','d.name',            TRUE,TRUE,TRUE,FALSE,NULL)
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;

    -- CS_FORM_6
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='CS_FORM_6';
    FOR field_def IN SELECT * FROM (VALUES
        ('reference_no',   'Ref No',        'TEXT',  'r.reference_no',   TRUE,TRUE,TRUE,FALSE,NULL),
        ('date_from',      'From',          'DATE',  'r.date_from',      TRUE,TRUE,TRUE,FALSE,NULL),
        ('date_to',        'To',            'DATE',  'r.date_to',        TRUE,TRUE,TRUE,FALSE,NULL),
        ('days_requested', 'Days',          'NUMBER','r.days_requested', FALSE,TRUE,TRUE,TRUE,'SUM'),
        ('whereabouts',    'Whereabouts',   'TEXT',  'r.whereabouts',    TRUE,TRUE,TRUE,FALSE,NULL),
        ('commutation',    'Commutation',   'TEXT',  'r.commutation',    TRUE,TRUE,TRUE,FALSE,NULL),
        ('status',         'Status',        'TEXT',  'r.status',         TRUE,TRUE,TRUE,FALSE,NULL),
        ('date_of_filing', 'Filed',         'DATE',  'r.date_of_filing', TRUE,TRUE,TRUE,FALSE,NULL),
        ('leave_code',     'Leave Code',    'TEXT',  'lt.code',          TRUE,TRUE,TRUE,FALSE,NULL),
        ('leave_type',     'Leave Type',    'TEXT',  'lt.name',          TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_no',    'Employee No',   'TEXT',  'e.employee_no',    TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_name',  'Employee',      'TEXT',  'e.first_name || '' '' || e.last_name',TRUE,TRUE,TRUE,FALSE,NULL),
        ('department',     'Department',    'TEXT',  'd.name',           TRUE,TRUE,TRUE,FALSE,NULL)
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;

    -- WFP_SCENARIOS
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='WFP_SCENARIOS';
    FOR field_def IN SELECT * FROM (VALUES
        ('name',            'Name',          'TEXT',    's.name',             TRUE,TRUE,TRUE,FALSE,NULL),
        ('scenario_type',   'Type',          'TEXT',    's.scenario_type',    TRUE,TRUE,TRUE,FALSE,NULL),
        ('status',          'Status',        'TEXT',    's.status',           TRUE,TRUE,TRUE,FALSE,NULL),
        ('base_date',       'Base Date',     'DATE',    's.base_date',        TRUE,TRUE,TRUE,FALSE,NULL),
        ('horizon_months',  'Horizon (mo)',  'NUMBER',  's.horizon_months',   FALSE,TRUE,TRUE,TRUE,'AVG'),
        ('created_at',      'Created',       'DATE',    's.created_at',       TRUE,TRUE,TRUE,FALSE,NULL),
        ('created_by_name', 'Created By',    'TEXT',    'u.display_name',     TRUE,TRUE,TRUE,FALSE,NULL),
        ('plan_lines',      'Plan Lines',    'NUMBER',  'NULL',               FALSE,TRUE,TRUE,TRUE,'SUM'),
        ('projected_cost',  'Projected Cost','CURRENCY','NULL',               FALSE,TRUE,TRUE,TRUE,'SUM')
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;

    -- WFP_HEADCOUNT
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='WFP_HEADCOUNT';
    FOR field_def IN SELECT * FROM (VALUES
        ('scenario_name',  'Scenario',       'TEXT',    's.name',            TRUE,TRUE,TRUE,FALSE,NULL),
        ('scenario_status','Scenario Status','TEXT',    's.status',          TRUE,TRUE,TRUE,FALSE,NULL),
        ('period_label',   'Period',         'TEXT',    'hp.period_label',   TRUE,TRUE,TRUE,FALSE,NULL),
        ('period_start',   'Period Start',   'DATE',    'hp.period_start',   TRUE,TRUE,TRUE,FALSE,NULL),
        ('department',     'Department',     'TEXT',    'd.name',            TRUE,TRUE,TRUE,FALSE,NULL),
        ('current_hc',     'Current HC',     'NUMBER',  'hp.current_hc',     FALSE,TRUE,TRUE,TRUE,'SUM'),
        ('planned_hc',     'Planned HC',     'NUMBER',  'hp.planned_hc',     FALSE,TRUE,TRUE,TRUE,'SUM'),
        ('planned_hires',  'Hires',          'NUMBER',  'hp.planned_hires',  FALSE,TRUE,TRUE,TRUE,'SUM'),
        ('planned_exits',  'Exits',          'NUMBER',  'hp.planned_exits',  FALSE,TRUE,TRUE,TRUE,'SUM'),
        ('avg_cost',       'Avg Cost',       'CURRENCY','hp.avg_cost',       FALSE,TRUE,TRUE,TRUE,'AVG'),
        ('total_cost',     'Total Cost',     'CURRENCY','hp.total_cost',     FALSE,TRUE,TRUE,TRUE,'SUM')
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;

    -- ATTRITION_RISK
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='ATTRITION_RISK';
    FOR field_def IN SELECT * FROM (VALUES
        ('score_date',     'Score Date',   'DATE',  'p.score_date',     TRUE,TRUE,TRUE,FALSE,NULL),
        ('risk_score',     'Risk Score',   'NUMBER','p.risk_score',     FALSE,TRUE,TRUE,TRUE,'AVG'),
        ('risk_level',     'Level',        'TEXT',  'p.risk_level',     TRUE,TRUE,TRUE,FALSE,NULL),
        ('confidence',     'Confidence',   'NUMBER','p.confidence',     FALSE,TRUE,TRUE,TRUE,'AVG'),
        ('model_version',  'Model',        'TEXT',  'p.model_version',  TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_no',    'Employee No',  'TEXT',  'e.employee_no',    TRUE,TRUE,TRUE,FALSE,NULL),
        ('employee_name',  'Employee',     'TEXT',  'e.first_name || '' '' || e.last_name',TRUE,TRUE,TRUE,FALSE,NULL),
        ('gender',         'Gender',       'TEXT',  'e.gender',         TRUE,TRUE,TRUE,FALSE,NULL),
        ('tenure_years',   'Tenure (yr)',  'NUMBER','NULL',              FALSE,TRUE,TRUE,TRUE,'AVG'),
        ('department',     'Department',   'TEXT',  'd.name',           TRUE,TRUE,TRUE,FALSE,NULL),
        ('position',       'Position',     'TEXT',  'pos.title',        TRUE,TRUE,TRUE,FALSE,NULL)
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;

    -- ROLE_ACCESS
    SELECT id INTO src_id FROM analytics.report_data_sources WHERE source_code='ROLE_ACCESS';
    FOR field_def IN SELECT * FROM (VALUES
        ('path',       'Path',       'TEXT',   'pg.path',     TRUE,TRUE,TRUE,FALSE,NULL),
        ('title',      'Title',      'TEXT',   'pg.title',    TRUE,TRUE,TRUE,FALSE,NULL),
        ('module',     'Module',     'TEXT',   'pg.module',   TRUE,TRUE,TRUE,FALSE,NULL),
        ('nav_group',  'Nav Group',  'TEXT',   'pg.nav_group',TRUE,TRUE,TRUE,FALSE,NULL),
        ('role_code',  'Role',       'TEXT',   'rpa.role_code',TRUE,TRUE,TRUE,FALSE,NULL),
        ('can_access', 'Has Access?','BOOLEAN','rpa.can_access',TRUE,TRUE,TRUE,FALSE,NULL),
        ('is_visible', 'In Nav?',    'BOOLEAN','pg.is_visible',TRUE,TRUE,TRUE,FALSE,NULL)
    ) AS t(c,l,ty,sx,gr,fl,so,ag,da) LOOP
        INSERT INTO analytics.report_field_registry
            (source_id, field_code, field_label, field_type, sql_expression,
             is_groupable, is_filterable, is_sortable, is_aggregatable, default_aggregate)
        VALUES (src_id, field_def.c, field_def.l, field_def.ty, field_def.sx,
                field_def.gr, field_def.fl, field_def.so, field_def.ag, field_def.da)
        ON CONFLICT (source_id, field_code) DO NOTHING;
    END LOOP;

END $$;


-- ══════════════════════════════════════════════════════════════════════
-- 2b. Ensure every sql_expression references the output alias
--     (base_sql already aliases columns to match field_code names)
-- ══════════════════════════════════════════════════════════════════════
UPDATE analytics.report_field_registry f
SET sql_expression = f.field_code
FROM analytics.report_data_sources s
WHERE f.source_id = s.id
  AND s.source_code IN (
    'DEPARTMENTS','POSITIONS','FACE_CHECKINS','LEAVE_TYPES','PAYSLIPS',
    'APPOINTMENTS','CSC_ELIGIBILITIES','TRAINING_ATTENDANCE','NARRATIVE_REPORTS',
    'LOYALTY_AWARDS','STEP_INCREMENTS','SALN_FILINGS','SIGNATURES',
    'LGU_CONTRACTS','TRAVEL_ORDERS','LOCATOR_SLIPS','RETIREMENT','CS_FORM_6',
    'WFP_SCENARIOS','WFP_HEADCOUNT','ATTRITION_RISK','ROLE_ACCESS'
  );


-- ══════════════════════════════════════════════════════════════════════
-- 3. GUIDED TOUR for /reports/builder
-- ══════════════════════════════════════════════════════════════════════
INSERT INTO core.tours (tour_key, title, description, module, allowed_roles, url_pattern, steps)
VALUES
    ('report-builder-v1',
     'Report Builder Tour',
     'Build custom reports by dragging fields from the palette',
     'analytics',
     ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE'],
     '/reports/builder',
     '[
        {"title":"Welcome to the Report Builder","body":"Create ad-hoc cross-module reports without writing SQL. We''ll walk you through in 7 steps.","position":"center"},
        {"selector":"#sourceSelect, select[name*=source]","title":"1. Pick a Data Source","body":"Choose from 23+ sources spanning every module — employees, attendance, payroll, leave, training, SALN, signatures, workforce planning, AI risk scores, and more.","position":"bottom"},
        {"selector":".rb-palette","title":"2. Available Fields","body":"Once a source is selected, its fields appear here. Each field shows its type (TEXT / NUMBER / DATE / CURRENCY / BOOLEAN).","position":"right"},
        {"selector":"#zoneColumns","title":"3. Drag to Columns","body":"Pick which fields show in your output. Drag them from the left palette into this zone. Order in the zone = column order in the report.","position":"top"},
        {"selector":"#zoneFilters","title":"4. Add Filters","body":"Drag a field here (or click + Add) to filter the result set. Supports =, !=, >, <, LIKE, IS NULL, IN etc.","position":"top"},
        {"selector":"#zoneGroup","title":"5. Group By (optional)","body":"Grouped columns are kept as-is; non-grouped numeric columns auto-aggregate (SUM by default). Drop a field here to switch the report into summary mode.","position":"top"},
        {"selector":"#previewBtn","title":"6. Preview","body":"Click to run the first 50 rows. Inspect the output before exporting or saving.","position":"top"},
        {"selector":"form[action*=export]","title":"7. Export / Save","body":"Download as CSV / XLSX / PDF — or save the configuration for re-use. Saved reports can also be scheduled to email recipients.","position":"top"}
     ]'::jsonb)
ON CONFLICT (tour_key) DO UPDATE SET
    title         = EXCLUDED.title,
    description   = EXCLUDED.description,
    module        = EXCLUDED.module,
    allowed_roles = EXCLUDED.allowed_roles,
    url_pattern   = EXCLUDED.url_pattern,
    steps         = EXCLUDED.steps,
    updated_at    = NOW();
