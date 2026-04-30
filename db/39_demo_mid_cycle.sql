-- ================================================================
-- HCM360 DEMO — PROFILE B: MID-CYCLE OPERATIONS
-- 6 months of history, 30 employees, mixed statuses
-- ================================================================

-- Quick Start (38) already runs before this via docker-entrypoint-initdb.d ordering

-- ── 10 New Employees (EMP-021 to EMP-030) ──────────────────────
DO $$
DECLARE
    co_id BIGINT; hr_id BIGINT; it_id BIGINT; fin_id BIGINT; ops_id BIGINT; mkt_id BIGINT;
    jg1 BIGINT; jg2 BIGINT; et_reg BIGINT;
    sup_hr BIGINT; sup_it BIGINT; sup_fin BIGINT; sup_ops BIGINT; sup_mkt BIGINT;
BEGIN
    SELECT id INTO co_id FROM core.companies LIMIT 1;
    SELECT id INTO hr_id FROM core.departments WHERE code = 'HR';
    SELECT id INTO it_id FROM core.departments WHERE code = 'IT';
    SELECT id INTO fin_id FROM core.departments WHERE code = 'FIN';
    SELECT id INTO ops_id FROM core.departments WHERE code = 'OPS';
    SELECT id INTO mkt_id FROM core.departments WHERE code = 'MKT';
    SELECT id INTO jg1 FROM core.job_grades WHERE code = 'JG1';
    SELECT id INTO jg2 FROM core.job_grades WHERE code = 'JG2';
    SELECT id INTO et_reg FROM core.employment_types WHERE code = 'REGULAR';
    SELECT id INTO sup_hr FROM core.employees WHERE employee_no = 'EMP-001';
    SELECT id INTO sup_it FROM core.employees WHERE employee_no = 'EMP-005';
    SELECT id INTO sup_fin FROM core.employees WHERE employee_no = 'EMP-011';
    SELECT id INTO sup_ops FROM core.employees WHERE employee_no = 'EMP-008';
    SELECT id INTO sup_mkt FROM core.employees WHERE employee_no = 'EMP-014';

    INSERT INTO core.employees
        (company_id, employee_no, first_name, last_name, middle_name, gender, date_of_birth,
         date_hired, department_id, job_grade_id, employment_type_id,
         immediate_supervisor_id, status, is_active, work_email, mobile_no, civil_status, nationality)
    VALUES
        (co_id,'EMP-021','Gabriel','Soriano','M.','MALE','1995-06-15','2025-07-01',hr_id,jg1,et_reg,sup_hr,'ACTIVE',TRUE,'gabriel.soriano@agency.gov.ph','09171000021','SINGLE','Filipino'),
        (co_id,'EMP-022','Angelica','Pangilinan','R.','FEMALE','1993-03-22','2025-07-15',it_id,jg2,et_reg,sup_it,'ACTIVE',TRUE,'angelica.pangilinan@agency.gov.ph','09171000022','MARRIED','Filipino'),
        (co_id,'EMP-023','Mark Anthony','Bautista','D.','MALE','1990-11-08','2025-08-01',fin_id,jg1,et_reg,sup_fin,'ACTIVE',TRUE,'mark.bautista@agency.gov.ph','09171000023','SINGLE','Filipino'),
        (co_id,'EMP-024','Jasmine','Reyes','L.','FEMALE','1997-01-30','2025-08-15',ops_id,jg1,et_reg,sup_ops,'ACTIVE',TRUE,'jasmine.reyes@agency.gov.ph','09171000024','SINGLE','Filipino'),
        (co_id,'EMP-025','Jerome','Villanueva','S.','MALE','1988-09-12','2025-09-01',it_id,jg1,et_reg,sup_it,'ACTIVE',TRUE,'jerome.villanueva@agency.gov.ph','09171000025','MARRIED','Filipino'),
        (co_id,'EMP-026','Aira Mae','Cortez','P.','FEMALE','1996-04-18','2025-09-15',mkt_id,jg1,et_reg,sup_mkt,'ACTIVE',TRUE,'aira.cortez@agency.gov.ph','09171000026','SINGLE','Filipino'),
        (co_id,'EMP-027','Rodel','Magat','T.','MALE','1991-12-03','2025-10-01',ops_id,jg2,et_reg,sup_ops,'ACTIVE',TRUE,'rodel.magat@agency.gov.ph','09171000027','MARRIED','Filipino'),
        (co_id,'EMP-028','Kristine Joy','Dela Pena','A.','FEMALE','1994-07-25','2025-10-15',hr_id,jg1,et_reg,sup_hr,'ACTIVE',TRUE,'kristine.delapena@agency.gov.ph','09171000028','SINGLE','Filipino'),
        (co_id,'EMP-029','John Carlo','Mendez','G.','MALE','1992-02-14','2025-11-01',fin_id,jg2,et_reg,sup_fin,'ACTIVE',TRUE,'john.mendez@agency.gov.ph','09171000029','SINGLE','Filipino'),
        (co_id,'EMP-030','Ma. Theresa','Aguilar','B.','FEMALE','1989-10-20','2025-11-15',ops_id,jg1,et_reg,sup_ops,'ACTIVE',TRUE,'theresa.aguilar@agency.gov.ph','09171000030','MARRIED','Filipino')
    ON CONFLICT DO NOTHING;

    INSERT INTO core.users (company_id, username, email, display_name, role_code, employee_id, is_active)
    SELECT co_id, LOWER(e.first_name || '.' || e.last_name), e.work_email,
           e.first_name || ' ' || e.last_name, 'EMPLOYEE', e.id, TRUE
    FROM core.employees e
    WHERE e.employee_no >= 'EMP-021' AND e.employee_no <= 'EMP-030'
    ON CONFLICT DO NOTHING;
END $$;

-- ── Attendance: 60 working days (Jan–Mar 2026) for ALL employees
DO $$
DECLARE emp RECORD; d DATE; shift_id BIGINT; is_late BOOLEAN;
BEGIN
    SELECT id INTO shift_id FROM attendance.att_shifts WHERE code = 'REG-8-5' LIMIT 1;
    IF shift_id IS NULL THEN RETURN; END IF;
    FOR emp IN SELECT id, employee_no FROM core.employees WHERE is_active = TRUE LOOP
        FOR d IN SELECT generate_series('2026-01-05'::date, '2026-03-31'::date, '1 day')::date LOOP
            IF EXTRACT(DOW FROM d) IN (0, 6) THEN CONTINUE; END IF;
            is_late := (emp.employee_no IN ('EMP-010','EMP-024','EMP-027') AND random() < 0.35);
            INSERT INTO attendance.att_daily
                (employee_id, work_date, shift_id, time_in, time_out,
                 hours_worked, hours_late, hours_undertime, hours_overtime, status)
            VALUES (emp.id, d, shift_id,
                CASE WHEN is_late THEN (d + TIME '08:15' + (random() * INTERVAL '40 min'))::TIMESTAMP
                     ELSE (d + TIME '07:50' + (random() * INTERVAL '10 min'))::TIMESTAMP END,
                (d + TIME '17:00' + (random() * INTERVAL '30 min'))::TIMESTAMP,
                8.0 + round((random())::numeric, 2),
                CASE WHEN is_late THEN round((random() * 0.75)::numeric, 2) ELSE 0 END,
                0,
                CASE WHEN random() < 0.1 THEN round((random() * 2)::numeric, 2) ELSE 0 END,
                CASE WHEN is_late THEN 'LATE' WHEN random() < 0.03 THEN 'ABSENT' ELSE 'PRESENT' END
            ) ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;
END $$;

-- ── Leave balances for new employees ────────────────────────────
INSERT INTO leave_mgmt.lv_balances (employee_id, leave_type_id, year, entitled_days, accrued_days, used_days, pending_days)
SELECT e.id, lt.id, 2026,
    CASE lt.code WHEN 'VL' THEN 15 WHEN 'SL' THEN 15 WHEN 'SIL' THEN 5 ELSE 0 END,
    CASE lt.code WHEN 'VL' THEN 15 WHEN 'SL' THEN 15 WHEN 'SIL' THEN 5 ELSE 0 END, 0, 0
FROM core.employees e CROSS JOIN leave_mgmt.lv_types lt
WHERE e.employee_no >= 'EMP-021' AND lt.code IN ('VL','SL','SIL')
ON CONFLICT DO NOTHING;

-- ── More leave requests ─────────────────────────────────────────
INSERT INTO leave_mgmt.lv_requests (reference_no, employee_id, leave_type_id, date_from, date_to, days_requested, reason, status, filed_at)
SELECT 'LV-2026-' || LPAD((100 + ROW_NUMBER() OVER ())::text, 4, '0'),
       e.id, lt.id, v.df, v.dt, v.days, v.reason, v.status, v.filed
FROM (VALUES
    ('EMP-021','VL','2026-03-02'::date,'2026-03-03'::date,2.0,'Personal','APPROVED',NOW()-INTERVAL '30 days'),
    ('EMP-022','SL','2026-02-10'::date,'2026-02-12'::date,3.0,'Dental','APPROVED',NOW()-INTERVAL '50 days'),
    ('EMP-023','VL','2026-04-07'::date,'2026-04-09'::date,3.0,'Vacation','PENDING',NOW()-INTERVAL '3 days'),
    ('EMP-024','SL','2026-03-28'::date,'2026-03-28'::date,1.0,'Flu','PENDING',NOW()-INTERVAL '2 days'),
    ('EMP-025','VL','2026-01-20'::date,'2026-01-21'::date,2.0,'Family reunion','APPROVED',NOW()-INTERVAL '70 days'),
    ('EMP-028','VL','2026-04-14'::date,'2026-04-16'::date,3.0,'Holy Week','PENDING',NOW()-INTERVAL '1 day')
) AS v(emp_no, lt_code, df, dt, days, reason, status, filed)
JOIN core.employees e ON e.employee_no = v.emp_no
JOIN leave_mgmt.lv_types lt ON lt.code = v.lt_code
ON CONFLICT (reference_no) DO NOTHING;

-- ── Payroll: 6 periods, 5 completed runs ────────────────────────
INSERT INTO payroll.pay_periods (company_id, period_code, period_type, date_from, date_to, payment_date, status)
SELECT c.id, v.code, 'SEMI_MONTHLY', v.df, v.dt, v.dt, v.status
FROM core.companies c,
(VALUES
    ('2026-01-1ST','2026-01-01'::date,'2026-01-15'::date,'CLOSED'),
    ('2026-01-2ND','2026-01-16'::date,'2026-01-31'::date,'CLOSED'),
    ('2026-02-1ST','2026-02-01'::date,'2026-02-15'::date,'CLOSED'),
    ('2026-02-2ND','2026-02-16'::date,'2026-02-28'::date,'CLOSED'),
    ('2026-03-1ST','2026-03-01'::date,'2026-03-15'::date,'CLOSED'),
    ('2026-03-2ND','2026-03-16'::date,'2026-03-31'::date,'PROCESSING')
) AS v(code, df, dt, status)
WHERE c.id = (SELECT id FROM core.companies LIMIT 1)
ON CONFLICT DO NOTHING;

INSERT INTO payroll.pay_runs (period_id, run_number, status, total_employees, computed_at)
SELECT pp.id, 1, 'COMPLETED', 30, NOW()
FROM payroll.pay_periods pp WHERE pp.status = 'CLOSED' AND pp.period_code LIKE '2026%'
ON CONFLICT (period_id, run_number) DO NOTHING;

-- ── PM: 2025 Year-End (COMPLETED) + 2026 Mid-Year ──────────────
INSERT INTO performance.perf_cycles (company_id, name, cycle_type, period_from, period_to, status, cycle_subtype)
SELECT c.id, v.name, 'ANNUAL', v.pf, v.pt, v.status, v.sub
FROM core.companies c,
(VALUES
    ('2025 Year-End Review','2025-07-01'::date,'2025-12-31'::date,'COMPLETED','YEAR_END'),
    ('2026 Mid-Year Review','2026-01-01'::date,'2026-06-30'::date,'ACTIVE','MID_YEAR')
) AS v(name, pf, pt, status, sub)
WHERE c.id = (SELECT id FROM core.companies LIMIT 1);

-- 8 IPCRs for 2025 cycle
INSERT INTO performance.perf_ipcr
    (employee_id, cycle_id, function_type, performance_indicator, target,
     quality_rating, efficiency_rating, timeliness_rating, weight, status)
SELECT e.id, c.id, 'CORE', v.indicator, v.target, v.q, v.e_r, v.t, 1.0, 'APPROVED'
FROM performance.perf_cycles c,
(VALUES
    ('EMP-001','Process HR transactions within SLA','100% compliance',4.8,4.5,4.7),
    ('EMP-005','Maintain 99% system uptime','99% uptime',4.5,4.2,4.6),
    ('EMP-008','Complete operational targets','100% completion',4.0,3.8,4.2),
    ('EMP-011','Submit financial reports on time','Timely submission',4.7,4.9,5.0),
    ('EMP-002','Process recruitment within 30 days','30-day turnaround',3.5,3.8,3.2),
    ('EMP-006','Deliver IT projects on schedule','On-time delivery',3.8,3.5,3.0),
    ('EMP-009','Zero workplace incidents','Safety compliance',4.0,4.0,4.5),
    ('EMP-012','Monthly financial statements','Monthly submission',4.5,4.3,4.8)
) AS v(emp_no, indicator, target, q, e_r, t)
JOIN core.employees e ON e.employee_no = v.emp_no
WHERE c.name = '2025 Year-End Review';

-- IPCR summaries
INSERT INTO performance.perf_ipcr_summary
    (employee_id, cycle_id, final_numerical_rating, adjectival_rating, pbb_eligible, step_increment_eligible, approved_at)
SELECT i.employee_id, i.cycle_id,
    ROUND((i.quality_rating + i.efficiency_rating + i.timeliness_rating) / 3.0, 2),
    CASE WHEN (i.quality_rating + i.efficiency_rating + i.timeliness_rating)/3.0 >= 4.5 THEN 'Outstanding'
         WHEN (i.quality_rating + i.efficiency_rating + i.timeliness_rating)/3.0 >= 3.5 THEN 'Very Satisfactory'
         ELSE 'Satisfactory' END,
    (i.quality_rating + i.efficiency_rating + i.timeliness_rating)/3.0 >= 3.5,
    (i.quality_rating + i.efficiency_rating + i.timeliness_rating)/3.0 >= 2.5,
    NOW() - INTERVAL '60 days'
FROM performance.perf_ipcr i
JOIN performance.perf_cycles c ON c.id = i.cycle_id WHERE c.name = '2025 Year-End Review'
ON CONFLICT (employee_id, cycle_id) DO NOTHING;

-- ── L&D: 3 more programs ───────────────────────────────────────
INSERT INTO learning.lrn_programs (company_id, code, title, category, delivery_mode, duration_hours, is_mandatory)
SELECT c.id, v.code, v.title, v.cat, v.mode, v.hrs, v.mand
FROM core.companies c,
(VALUES
    ('ARTA-101','Anti-Red Tape Act Training','Compliance','IN_PERSON',4.0,TRUE),
    ('PM-201','Project Management for Government','Skills','IN_PERSON',16.0,FALSE),
    ('EXCEL-301','Advanced Excel for Finance','Technical','IN_PERSON',8.0,FALSE)
) AS v(code, title, cat, mode, hrs, mand)
WHERE c.id = (SELECT id FROM core.companies LIMIT 1)
ON CONFLICT DO NOTHING;

-- ── R&R: PBB for 2025 ──────────────────────────────────────────
INSERT INTO rewards.rwd_pbb_records
    (employee_id, year, ipcr_summary_id, ipcr_adjectival, pbb_tier, pbb_amount, status)
SELECT s.employee_id, 2025, s.id, s.adjectival_rating,
    CASE WHEN s.final_numerical_rating >= 4.5 THEN 'TIER_1'
         WHEN s.final_numerical_rating >= 3.5 THEN 'TIER_2' ELSE 'TIER_3' END,
    CASE WHEN s.final_numerical_rating >= 4.5 THEN 65000
         WHEN s.final_numerical_rating >= 3.5 THEN 57500 ELSE 50000 END,
    'APPROVED'
FROM performance.perf_ipcr_summary s
ON CONFLICT (employee_id, year) DO NOTHING;

-- Loyalty milestones
INSERT INTO rewards.rwd_loyalty_milestones (employee_id, service_years, eligibility_date, status, award_type)
SELECT e.id, v.yrs, e.date_hired + (v.yrs || ' years')::interval, v.status, 'COMBINATION'
FROM (VALUES ('EMP-016',10,'ELIGIBLE'), ('EMP-001',15,'AWARDED'))
AS v(emp_no, yrs, status)
JOIN core.employees e ON e.employee_no = v.emp_no
ON CONFLICT (employee_id, service_years) DO NOTHING;

-- ── Discipline: 2 cases ─────────────────────────────────────────
INSERT INTO discipline.cases
    (company_id, case_no, respondent_id, case_type_id, offense_description, gravity, status, date_filed, created_by)
SELECT c.id, v.case_no, e.id, ct.id, v.descr, v.gravity, v.status, v.filed,
       (SELECT id FROM core.users WHERE username IN ('hradmin','superadmin') ORDER BY username LIMIT 1)
FROM core.companies c,
(VALUES
    ('EMP-010','DISC-2026-001','VIOLATION_OFFICE_HRS','Habitual tardiness — 8 instances in March 2026','LIGHT','PRELIMINARY_INVESTIGATION',NOW()-INTERVAL '5 days'),
    ('EMP-027','DISC-2026-002','SIMPLE_MISCONDUCT','Unauthorized use of government vehicle','LESS_GRAVE','FORMAL_CHARGE',NOW()-INTERVAL '20 days')
) AS v(emp_no, case_no, ct_code, descr, gravity, status, filed)
JOIN core.employees e ON e.employee_no = v.emp_no
JOIN discipline.case_types ct ON ct.code = v.ct_code
WHERE c.id = (SELECT id FROM core.companies LIMIT 1)
ON CONFLICT (case_no) DO NOTHING;

-- ── Health: PE results + incident ───────────────────────────────
INSERT INTO health.pe_results (schedule_id, employee_id, exam_date, overall_result, findings)
SELECT ps.id, e.id, '2026-03-15',
    CASE WHEN random() < 0.65 THEN 'FIT' WHEN random() < 0.85 THEN 'CONDITIONAL' ELSE 'UNFIT' END,
    CASE WHEN random() < 0.3 THEN 'Elevated BP, recommend follow-up' ELSE NULL END
FROM health.pe_schedules ps CROSS JOIN core.employees e
WHERE ps.year = 2026 AND e.employee_no <= 'EMP-015'
ON CONFLICT DO NOTHING;

INSERT INTO health.incidents
    (company_id, incident_no, incident_date, location, incident_type, severity, description, reported_by, status)
SELECT c.id, 'INC-2026-001', '2026-02-20', 'Operations Building', 'INJURY', 'MINOR',
       'Employee slipped on wet floor. Minor bruise. First aid administered.',
       (SELECT id FROM core.users WHERE username IN ('manager','superadmin') ORDER BY username LIMIT 1), 'CLOSED'
FROM core.companies c LIMIT 1
ON CONFLICT (incident_no) DO NOTHING;

-- ── Recruitment Expanded: 5 more plantilla + 2 requisitions + 6 applicants
DO $$
DECLARE
    co_id BIGINT; hr_user BIGINT;
    hr_dept BIGINT; fin_dept BIGINT; ops_dept BIGINT; mkt_dept BIGINT; adm_dept BIGINT;
    hr_asst_pos BIGINT; ops_asst_pos BIGINT;
    req_hr BIGINT; req_ops BIGINT; post_hr BIGINT; post_ops BIGINT;
BEGIN
    SELECT id INTO co_id FROM core.companies LIMIT 1;
    SELECT id INTO hr_user FROM core.users WHERE username IN ('hradmin','superadmin') ORDER BY username LIMIT 1;
    SELECT id INTO hr_dept FROM core.departments WHERE code = 'HR';
    SELECT id INTO fin_dept FROM core.departments WHERE code = 'FIN';
    SELECT id INTO ops_dept FROM core.departments WHERE code = 'OPS';
    SELECT id INTO mkt_dept FROM core.departments WHERE code = 'MKT';
    SELECT id INTO adm_dept FROM core.departments WHERE code = 'ADM';
    SELECT id INTO hr_asst_pos FROM core.positions WHERE code = 'HR-ASST';
    SELECT id INTO ops_asst_pos FROM core.positions WHERE code = 'OPS-ASST';

    -- 5 more plantilla items
    INSERT INTO recruitment.rec_plantilla_items (company_id, department_id, item_number, salary_grade, step_no, status)
    VALUES
        (co_id, hr_dept,  'HR-ITEM-024',  8, 1, 'VACANT'),
        (co_id, fin_dept, 'FIN-ITEM-025', 9, 1, 'VACANT'),
        (co_id, ops_dept, 'OPS-ITEM-026', 4, 1, 'VACANT'),
        (co_id, mkt_dept, 'MKT-ITEM-027', 7, 1, 'VACANT'),
        (co_id, adm_dept, 'ADM-ITEM-028', 5, 1, 'VACANT')
    ON CONFLICT DO NOTHING;

    -- 2 approved requisitions
    INSERT INTO recruitment.rec_requisitions
        (company_id, reference_no, department_id, position_id, headcount, justification, status, requested_by, target_hire_date)
    VALUES
        (co_id, 'REQ-2026-002', hr_dept, hr_asst_pos, 1,
         'Additional HR Assistant needed for expanded employee services.',
         'APPROVED', hr_user, '2026-05-15'),
        (co_id, 'REQ-2026-003', ops_dept, ops_asst_pos, 1,
         'Operations support staff for field office expansion.',
         'APPROVED', hr_user, '2026-06-01')
    ON CONFLICT DO NOTHING;

    SELECT id INTO req_hr FROM recruitment.rec_requisitions WHERE reference_no = 'REQ-2026-002';
    SELECT id INTO req_ops FROM recruitment.rec_requisitions WHERE reference_no = 'REQ-2026-003';

    INSERT INTO recruitment.rec_job_postings
        (requisition_id, title, description, requirements, employment_type, salary_range,
         location, posted_on, status, is_internal)
    VALUES
        (req_hr, 'HR Assistant',
         'Support the HR Division in recruitment, benefits administration, and records management.',
         'BS in Psychology, Public Administration, or related; CSC Sub-Professional; no experience required',
         'PERMANENT', 'SG-8 (Php 22,000 - 25,000)', 'Main Office', '2026-03-01', 'OPEN', FALSE),
        (req_ops, 'Operations Assistant',
         'Assist in daily operations coordination and field office logistics.',
         'BS in any course; CSC Sub-Professional; 1 year relevant experience preferred',
         'PERMANENT', 'SG-4 (Php 18,000 - 20,000)', 'Field Office', '2026-03-10', 'OPEN', FALSE);

    SELECT id INTO post_hr FROM recruitment.rec_job_postings WHERE title = 'HR Assistant' LIMIT 1;
    SELECT id INTO post_ops FROM recruitment.rec_job_postings WHERE title = 'Operations Assistant' LIMIT 1;

    INSERT INTO recruitment.rec_applicants (posting_id, first_name, last_name, email, mobile_no, stage, source, score)
    VALUES
        (post_hr, 'Michelle', 'Tan',       'michelle.tan@gmail.com',   '09175550201', 'SHORTLISTED', 'CSC_POSTING', 85.50),
        (post_hr, 'Jerome',   'Lim',       'jerome.lim@yahoo.com',     '09185550202', 'INTERVIEWED', 'AGENCY_WEBSITE', 78.00),
        (post_hr, 'Daisy',    'Soriano',   'daisy.soriano@gmail.com',  '09195550203', 'SCREENED', 'PHILJOBNET', NULL),
        (post_ops, 'Arnold',  'De Leon',   'arnold.deleon@gmail.com',  '09175550204', 'SHORTLISTED', 'CSC_POSTING', 82.25),
        (post_ops, 'Rosalie', 'Manansala', 'rosalie.m@yahoo.com',      '09185550205', 'SCREENED', 'AGENCY_WEBSITE', NULL),
        (post_ops, 'Kevin',   'Pangilinan','kevin.pang@gmail.com',     '09195550206', 'APPLIED', 'PHILJOBNET', NULL);
END $$;

-- ── Maternity Leave for EMP-022 (Angelica Pangilinan) ──────────
INSERT INTO leave_mgmt.lv_balances (employee_id, leave_type_id, year, entitled_days, accrued_days, used_days, pending_days)
SELECT e.id, lt.id, 2026, 105, 105, 105, 0
FROM core.employees e JOIN leave_mgmt.lv_types lt ON lt.code = 'ML'
WHERE e.employee_no = 'EMP-022'
ON CONFLICT DO NOTHING;

INSERT INTO leave_mgmt.lv_requests
    (reference_no, employee_id, leave_type_id, date_from, date_to, days_requested, reason, status, filed_at)
SELECT 'LV-2026-0200', e.id, lt.id, '2026-01-15', '2026-05-05', 105,
       'Maternity Leave under RA 11210 (Expanded Maternity Leave)', 'APPROVED', NOW() - INTERVAL '80 days'
FROM core.employees e JOIN leave_mgmt.lv_types lt ON lt.code = 'ML'
WHERE e.employee_no = 'EMP-022'
ON CONFLICT (reference_no) DO NOTHING;

-- ── Employee Payroll Detail (payslips) for 5 completed 2026 runs
DO $$
DECLARE
    r RECORD; emp RECORD;
    bp NUMERIC; gsis_p NUMERIC; gsis_g NUMERIC; pera_amt NUMERIC := 1000;
    pagibig_p NUMERIC := 100; pagibig_g NUMERIC := 100;
    tax NUMERIC; gross NUMERIC; total_ded NUMERIC; net NUMERIC;
BEGIN
    FOR r IN SELECT pr.id AS run_id FROM payroll.pay_runs pr
             JOIN payroll.pay_periods pp ON pp.id = pr.period_id
             WHERE pr.status = 'COMPLETED' AND pp.period_code LIKE '2026%' LOOP
        FOR emp IN SELECT e.id, e.basic_salary FROM core.employees e WHERE e.is_active = TRUE LOOP
            bp := COALESCE(emp.basic_salary, 25000) / 2.0;
            gsis_p := ROUND(bp * 0.09, 2);
            gsis_g := ROUND(bp * 0.12, 2);
            tax := GREATEST(0, ROUND((bp - 10417) * 0.15, 2));
            gross := bp + pera_amt;
            total_ded := gsis_p + pagibig_p + tax;
            net := gross - total_ded;

            INSERT INTO payroll.pay_employee_payroll
                (run_id, employee_id, scheduled_days, worked_days, basic_pay,
                 gsis_ps, gsis_gs, pagibig_ps, pagibig_gs, pera,
                 allowances_total, gross_pay, tax_withheld, total_deductions, net_pay)
            VALUES (r.run_id, emp.id, 11, 11, bp,
                    gsis_p, gsis_g, pagibig_p, pagibig_g, pera_amt,
                    pera_amt, gross, tax, total_ded, net)
            ON CONFLICT (run_id, employee_id) DO NOTHING;
        END LOOP;
    END LOOP;
END $$;

-- ── Government Remittances for completed 2026 runs ─────────────
INSERT INTO payroll.pay_government_remittances (run_id, agency, remittance_date, total_ee, total_er, total_amount, status)
SELECT pr.id, v.agency, pp.date_to + 5, v.ee_rate * 30, v.er_rate * 30, (v.ee_rate + v.er_rate) * 30, 'REMITTED'
FROM payroll.pay_runs pr
JOIN payroll.pay_periods pp ON pp.id = pr.period_id
CROSS JOIN (VALUES
    ('GSIS',   1500.00, 2000.00),
    ('PAGIBIG', 100.00,  100.00),
    ('BIR',    2500.00,    0.00)
) AS v(agency, ee_rate, er_rate)
WHERE pr.status = 'COMPLETED' AND pp.period_code LIKE '2026%'
ON CONFLICT (run_id, agency) DO NOTHING;

-- ── TNA Entries linked to IPCR gaps ────────────────────────────
DO $$
DECLARE co_id BIGINT; v_cycle_id BIGINT;
BEGIN
    SELECT id INTO co_id FROM core.companies LIMIT 1;
    SELECT id INTO v_cycle_id FROM performance.perf_cycles WHERE name = '2025 Year-End Review' LIMIT 1;

    INSERT INTO learning.lrn_tna_entries
        (employee_id, cycle_id, competency_gap, recommended_training, priority, source, status)
    SELECT e.id, v_cycle_id, v.gap, v.training, v.prio, 'IPCR', v.status
    FROM (VALUES
        ('EMP-002','Timeliness in recruitment processing','Project Management for Government','HIGH','ENROLLED'),
        ('EMP-006','Project delivery efficiency','Advanced Project Management','HIGH','ENROLLED'),
        ('EMP-006','Stakeholder communication','Leadership Fundamentals','MEDIUM','PENDING'),
        ('EMP-008','Quality assurance in operations','Operations Excellence Training','MEDIUM','DEFERRED'),
        ('EMP-009','Strategic planning skills','Strategic Planning for LGUs','LOW','PENDING')
    ) AS v(emp_no, gap, training, prio, status)
    JOIN core.employees e ON e.employee_no = v.emp_no
    WHERE NOT EXISTS (
        SELECT 1 FROM learning.lrn_tna_entries t
        WHERE t.employee_id = e.id AND t.cycle_id = v_cycle_id AND t.competency_gap = v.gap
    );
END $$;

-- ── L&D: Sessions and enrollments for ARTA-101, PM-201, EXCEL-301
DO $$
DECLARE
    arta_prog BIGINT; pm_prog BIGINT; excel_prog BIGINT;
    arta_sess BIGINT; pm_sess BIGINT; excel_sess BIGINT;
BEGIN
    SELECT id INTO arta_prog FROM learning.lrn_programs WHERE code = 'ARTA-101' LIMIT 1;
    SELECT id INTO pm_prog FROM learning.lrn_programs WHERE code = 'PM-201' LIMIT 1;
    SELECT id INTO excel_prog FROM learning.lrn_programs WHERE code = 'EXCEL-301' LIMIT 1;

    -- ARTA-101: completed session
    INSERT INTO learning.lrn_sessions (program_id, session_date, session_end, venue, facilitator, max_participants, status)
    VALUES (arta_prog, '2026-03-10', '2026-03-10', 'Multi-Purpose Hall', 'Dir. Ramon Sta. Ana', 40, 'COMPLETED')
    RETURNING id INTO arta_sess;

    INSERT INTO learning.lrn_enrollments (session_id, employee_id, status)
    SELECT arta_sess, e.id, 'COMPLETED'
    FROM core.employees e
    WHERE e.employee_no IN ('EMP-001','EMP-002','EMP-005','EMP-008','EMP-011','EMP-014','EMP-021','EMP-022','EMP-023')
    ON CONFLICT DO NOTHING;

    -- PM-201: scheduled session
    INSERT INTO learning.lrn_sessions (program_id, session_date, session_end, venue, facilitator, max_participants, status)
    VALUES (pm_prog, '2026-04-28', '2026-04-29', 'Training Room B', 'Prof. Ana Lim', 20, 'SCHEDULED')
    RETURNING id INTO pm_sess;

    INSERT INTO learning.lrn_enrollments (session_id, employee_id, status)
    SELECT pm_sess, e.id, 'ENROLLED'
    FROM core.employees e
    WHERE e.employee_no IN ('EMP-002','EMP-006','EMP-009','EMP-012')
    ON CONFLICT DO NOTHING;

    -- EXCEL-301: completed session
    INSERT INTO learning.lrn_sessions (program_id, session_date, session_end, venue, facilitator, max_participants, status)
    VALUES (excel_prog, '2026-02-18', '2026-02-18', 'Computer Lab', 'Mr. Eric Tan', 15, 'COMPLETED')
    RETURNING id INTO excel_sess;

    INSERT INTO learning.lrn_enrollments (session_id, employee_id, status)
    SELECT excel_sess, e.id, 'COMPLETED'
    FROM core.employees e
    WHERE e.employee_no IN ('EMP-011','EMP-012','EMP-020','EMP-023','EMP-029')
    ON CONFLICT DO NOTHING;
END $$;
