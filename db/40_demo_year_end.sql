-- ================================================================
-- HCM360 DEMO — PROFILE C: YEAR-END AUDIT READY
-- Full annual cycle, 45 employees, comprehensive history
-- ================================================================

-- Load Mid-Cycle as base
-- Mid-Cycle (39) already runs before this via docker-entrypoint-initdb.d ordering

-- ── 15 More Employees (EMP-031 to EMP-045) ─────────────────────
DO $$
DECLARE
    co_id BIGINT; hr_id BIGINT; it_id BIGINT; fin_id BIGINT; ops_id BIGINT; mkt_id BIGINT; adm_id BIGINT;
    jg1 BIGINT; jg2 BIGINT; et_reg BIGINT;
    sup_hr BIGINT; sup_it BIGINT; sup_fin BIGINT; sup_ops BIGINT; sup_mkt BIGINT;
BEGIN
    SELECT id INTO co_id FROM core.companies LIMIT 1;
    SELECT id INTO hr_id FROM core.departments WHERE code = 'HR';
    SELECT id INTO it_id FROM core.departments WHERE code = 'IT';
    SELECT id INTO fin_id FROM core.departments WHERE code = 'FIN';
    SELECT id INTO ops_id FROM core.departments WHERE code = 'OPS';
    SELECT id INTO mkt_id FROM core.departments WHERE code = 'MKT';
    SELECT id INTO adm_id FROM core.departments WHERE code = 'ADM';
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
        (co_id,'EMP-031','Ryan','De Guzman','V.','MALE','1994-03-10','2024-01-15',it_id,jg1,et_reg,sup_it,'ACTIVE',TRUE,'ryan.deguzman@agency.gov.ph','09171000031','SINGLE','Filipino'),
        (co_id,'EMP-032','Marjorie','Santos','C.','FEMALE','1996-08-22','2024-02-01',hr_id,jg1,et_reg,sup_hr,'ACTIVE',TRUE,'marjorie.santos@agency.gov.ph','09171000032','SINGLE','Filipino'),
        (co_id,'EMP-033','Dennis','Cruz','A.','MALE','1987-05-17','2023-06-01',ops_id,jg2,et_reg,sup_ops,'ACTIVE',TRUE,'dennis.cruz@agency.gov.ph','09171000033','MARRIED','Filipino'),
        (co_id,'EMP-034','Cherry Ann','Mercado','B.','FEMALE','1998-11-28','2024-03-15',fin_id,jg1,et_reg,sup_fin,'ACTIVE',TRUE,'cherry.mercado@agency.gov.ph','09171000034','SINGLE','Filipino'),
        (co_id,'EMP-035','Ariel','Pascual','N.','MALE','1985-01-05','2022-01-10',ops_id,jg2,et_reg,sup_ops,'ACTIVE',TRUE,'ariel.pascual@agency.gov.ph','09171000035','MARRIED','Filipino'),
        (co_id,'EMP-036','Rowena','Lagman','E.','FEMALE','1993-06-14','2024-04-01',mkt_id,jg1,et_reg,sup_mkt,'ACTIVE',TRUE,'rowena.lagman@agency.gov.ph','09171000036','SINGLE','Filipino'),
        (co_id,'EMP-037','Reynaldo','Torres','J.','MALE','1990-09-30','2023-07-15',adm_id,jg1,et_reg,NULL,'ACTIVE',TRUE,'reynaldo.torres@agency.gov.ph','09171000037','MARRIED','Filipino'),
        (co_id,'EMP-038','Lea','Dimaculangan','S.','FEMALE','1997-04-08','2024-05-01',hr_id,jg1,et_reg,sup_hr,'ACTIVE',TRUE,'lea.dimaculangan@agency.gov.ph','09171000038','SINGLE','Filipino'),
        (co_id,'EMP-039','Jayson','Ramos','D.','MALE','1991-12-19','2024-06-15',it_id,jg1,et_reg,sup_it,'ACTIVE',TRUE,'jayson.ramos@agency.gov.ph','09171000039','SINGLE','Filipino'),
        (co_id,'EMP-040','Princess','Aquino','M.','FEMALE','1995-02-26','2024-07-01',fin_id,jg1,et_reg,sup_fin,'ACTIVE',TRUE,'princess.aquino@agency.gov.ph','09171000040','SINGLE','Filipino'),
        (co_id,'EMP-041','Erwin','Gutierrez','L.','MALE','1986-07-11','2021-08-01',ops_id,jg2,et_reg,sup_ops,'ACTIVE',TRUE,'erwin.gutierrez@agency.gov.ph','09171000041','MARRIED','Filipino'),
        (co_id,'EMP-042','Maricel','Rivera','P.','FEMALE','1994-10-03','2024-09-01',hr_id,jg1,et_reg,sup_hr,'ACTIVE',TRUE,'maricel.rivera@agency.gov.ph','09171000042','SINGLE','Filipino'),
        (co_id,'EMP-043','Francis','Salazar','R.','MALE','1992-01-22','2024-10-15',mkt_id,jg1,et_reg,sup_mkt,'ACTIVE',TRUE,'francis.salazar@agency.gov.ph','09171000043','SINGLE','Filipino'),
        (co_id,'EMP-044','Aileen','Manalo','G.','FEMALE','1988-08-15','2023-11-01',fin_id,jg2,et_reg,sup_fin,'ACTIVE',TRUE,'aileen.manalo@agency.gov.ph','09171000044','MARRIED','Filipino'),
        (co_id,'EMP-045','Edwin','Tolentino','H.','MALE','1966-04-30','2020-01-15',adm_id,jg2,et_reg,NULL,'ACTIVE',TRUE,'edwin.tolentino@agency.gov.ph','09171000045','MARRIED','Filipino')
    ON CONFLICT DO NOTHING;

    INSERT INTO core.users (company_id, username, email, display_name, role_code, employee_id, is_active)
    SELECT co_id, LOWER(e.first_name || '.' || e.last_name), e.work_email,
           e.first_name || ' ' || e.last_name, 'EMPLOYEE', e.id, TRUE
    FROM core.employees e WHERE e.employee_no >= 'EMP-031' AND e.employee_no <= 'EMP-045'
    ON CONFLICT DO NOTHING;
END $$;

-- ── Attendance: Extend with 2025 full year for base 20 employees
DO $$
DECLARE emp RECORD; d DATE; shift_id BIGINT;
BEGIN
    SELECT id INTO shift_id FROM attendance.att_shifts WHERE code = 'REG-8-5' LIMIT 1;
    IF shift_id IS NULL THEN RETURN; END IF;
    FOR emp IN SELECT id FROM core.employees WHERE is_active = TRUE AND employee_no <= 'EMP-020' LOOP
        FOR d IN SELECT generate_series('2025-01-06'::date, '2025-12-31'::date, '1 day')::date LOOP
            IF EXTRACT(DOW FROM d) IN (0, 6) THEN CONTINUE; END IF;
            INSERT INTO attendance.att_daily
                (employee_id, work_date, shift_id, time_in, time_out, hours_worked, hours_late, hours_undertime, status)
            VALUES (emp.id, d, shift_id,
                (d + TIME '07:50' + (random() * INTERVAL '15 min'))::TIMESTAMP,
                (d + TIME '17:00' + (random() * INTERVAL '20 min'))::TIMESTAMP,
                8.0 + round((random() * 0.8)::numeric, 2),
                CASE WHEN random() < 0.08 THEN round((random() * 0.5)::numeric, 2) ELSE 0 END, 0,
                CASE WHEN random() < 0.08 THEN 'LATE' WHEN random() < 0.02 THEN 'ABSENT' ELSE 'PRESENT' END
            ) ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;
END $$;

-- ── PM: 2025 Mid-Year + succession matrix ──────────────────────
INSERT INTO performance.perf_cycles (company_id, name, cycle_type, period_from, period_to, status, cycle_subtype)
SELECT c.id, '2025 Mid-Year Review', 'ANNUAL', '2025-01-01', '2025-06-30', 'COMPLETED', 'MID_YEAR'
FROM core.companies c LIMIT 1;

-- Succession matrix
INSERT INTO performance.perf_succession_matrix
    (key_position_id, successor_employee_id, readiness, development_needs, assessed_on)
SELECT p.id, e.id, v.readiness, v.needs, '2026-01-15'::date
FROM (VALUES
    ('HR Manager',      'EMP-002', 'READY_1_2YR', 'Complete leadership certification'),
    ('IT Manager',      'EMP-006', 'READY_NOW',    'Strong technical, needs management training'),
    ('Finance Manager', 'EMP-012', 'READY_1_2YR', 'CPA license, needs supervisory experience'),
    ('Operations Manager','EMP-009','READY_3_5YR','Good field experience, needs strategic planning')
) AS v(pos_title, emp_no, readiness, needs)
JOIN core.positions p ON p.title ILIKE '%' || split_part(v.pos_title, ' ', 1) || '%'
JOIN core.employees e ON e.employee_no = v.emp_no
ON CONFLICT (key_position_id, successor_employee_id) DO NOTHING;

-- ── L&D: More programs + scholarship ────────────────────────────
INSERT INTO learning.lrn_programs (company_id, code, title, category, delivery_mode, duration_hours, is_mandatory, csc_accredited)
SELECT c.id, v.code, v.title, v.cat, v.mode, v.hrs, v.mand, v.csc
FROM core.companies c,
(VALUES
    ('GOV-ACC','Government Accounting','Finance','IN_PERSON',24.0,FALSE,TRUE),
    ('IT-SEC','Cybersecurity for Government','Technical','ONLINE',8.0,TRUE,FALSE),
    ('PUB-ETH','Public Service Ethics','Compliance','IN_PERSON',4.0,TRUE,TRUE),
    ('STRAT-PLN','Strategic Planning for LGUs','Leadership','IN_PERSON',16.0,FALSE,TRUE),
    ('GEN-AWARE','Gender Awareness','Compliance','IN_PERSON',4.0,TRUE,FALSE)
) AS v(code, title, cat, mode, hrs, mand, csc)
WHERE c.id = (SELECT id FROM core.companies LIMIT 1)
ON CONFLICT DO NOTHING;

INSERT INTO learning.lrn_scholarships
    (employee_id, program_name, grant_type, institution, course, start_date, end_date, bond_required_months, status)
SELECT e.id, 'Master in Public Administration', 'LOCAL', 'University of the Philippines',
       'MPA', '2025-06-01', '2027-03-31', 24, 'ACTIVE'
FROM core.employees e WHERE e.employee_no = 'EMP-006';

-- ── R&R: More loyalty + retirement alerts ───────────────────────
INSERT INTO rewards.rwd_loyalty_milestones (employee_id, service_years, eligibility_date, status, award_type, awarded_at)
SELECT e.id, v.yrs, e.date_hired + (v.yrs || ' years')::interval, v.status, 'COMBINATION', v.awarded
FROM (VALUES
    ('EMP-035', 5, 'AWARDED', NOW() - INTERVAL '30 days'),
    ('EMP-041', 5, 'ELIGIBLE', NULL)
) AS v(emp_no, yrs, status, awarded)
JOIN core.employees e ON e.employee_no = v.emp_no
ON CONFLICT (employee_id, service_years) DO NOTHING;

-- Retirement alert for Edwin Tolentino (DOB 1966 → turning 60 in 2026)
INSERT INTO rewards.rwd_retirement_alerts
    (employee_id, retirement_age, projected_retirement_date, alert_type, scheduled_send_date)
SELECT e.id, 60, '2026-04-30', '6MO_NOTICE', '2025-10-30'
FROM core.employees e WHERE e.employee_no = 'EMP-045';

-- ── Discipline: 2 more cases ────────────────────────────────────
INSERT INTO discipline.cases
    (company_id, case_no, respondent_id, case_type_id, offense_description, gravity, status, date_filed, created_by)
SELECT c.id, v.case_no, e.id, ct.id, v.descr, v.gravity, v.status, v.filed,
       (SELECT id FROM core.users WHERE username IN ('hradmin','superadmin') ORDER BY username LIMIT 1)
FROM core.companies c,
(VALUES
    ('EMP-033','DISC-2025-001','INSUBORDINATION','Refused lawful order regarding overtime duty','LESS_GRAVE','DECISION',NOW()-INTERVAL '180 days'),
    ('EMP-037','DISC-2025-002','FREQ_UNAUTH_ABSENCE','AWOL for 3 consecutive days without notice','LESS_GRAVE','HEARING',NOW()-INTERVAL '45 days')
) AS v(emp_no, case_no, ct_code, descr, gravity, status, filed)
JOIN core.employees e ON e.employee_no = v.emp_no
JOIN discipline.case_types ct ON ct.code = v.ct_code
WHERE c.id = (SELECT id FROM core.companies LIMIT 1)
ON CONFLICT (case_no) DO NOTHING;

-- Decision for the decided case
INSERT INTO discipline.decisions
    (case_id, verdict, penalty, effectivity_date, decision_date, decided_by, decision_text)
SELECT c.id, 'GUILTY', 'SUSPENSION_15_DAYS', '2025-11-01', '2025-10-15',
       (SELECT id FROM core.users WHERE username IN ('hradmin','superadmin') ORDER BY username LIMIT 1),
       'Respondent found guilty of insubordination — Less Grave Offense. Penalty: 15-day suspension without pay per CSC RRACA.'
FROM discipline.cases c WHERE c.case_no = 'DISC-2025-001';

-- ── Health: 2025 PE + more incidents ────────────────────────────
INSERT INTO health.pe_schedules (company_id, year, title, scheduled_from, scheduled_to, status, created_by)
SELECT c.id, 2025, '2025 Annual Physical Examination', '2025-06-01', '2025-06-30', 'COMPLETED',
       (SELECT id FROM core.users WHERE username IN ('hradmin','superadmin') ORDER BY username LIMIT 1)
FROM core.companies c LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO health.pe_results (schedule_id, employee_id, exam_date, overall_result, findings)
SELECT ps.id, e.id, '2025-06-15',
    CASE WHEN random() < 0.7 THEN 'FIT' WHEN random() < 0.9 THEN 'CONDITIONAL' ELSE 'UNFIT' END,
    CASE WHEN random() < 0.2 THEN 'Elevated cholesterol, follow-up needed' ELSE NULL END
FROM health.pe_schedules ps CROSS JOIN core.employees e
WHERE ps.year = 2025 AND e.employee_no <= 'EMP-020'
ON CONFLICT DO NOTHING;

INSERT INTO health.incidents
    (company_id, incident_no, incident_date, location, incident_type, severity, description, reported_by, status)
SELECT c.id, v.ino, v.idate, v.loc, v.itype, v.sev, v.descr,
       (SELECT id FROM core.users WHERE username IN ('manager','superadmin') ORDER BY username LIMIT 1), v.status
FROM core.companies c,
(VALUES
    ('INC-2025-001','2025-09-15'::date,'Motor pool area','INJURY','MODERATE','Vehicle accident during official travel. Driver sustained minor injuries.','CLOSED'),
    ('INC-2026-002','2026-01-22'::date,'Finance Office','PROPERTY_DAMAGE','MINOR','Electrical short circuit in power outlet. No injuries. Wiring replaced.','CLOSED')
) AS v(ino, idate, loc, itype, sev, descr, status)
WHERE c.id = (SELECT id FROM core.companies LIMIT 1)
ON CONFLICT (incident_no) DO NOTHING;

-- ── Payroll: 2025 full year (24 periods) ────────────────────────
INSERT INTO payroll.pay_periods (company_id, period_code, period_type, date_from, date_to, payment_date, status)
SELECT c.id, v.code, 'SEMI_MONTHLY', v.df, v.dt, v.dt, 'CLOSED'
FROM core.companies c,
(VALUES
    ('2025-01-1ST','2025-01-01'::date,'2025-01-15'::date),('2025-01-2ND','2025-01-16'::date,'2025-01-31'::date),
    ('2025-02-1ST','2025-02-01'::date,'2025-02-15'::date),('2025-02-2ND','2025-02-16'::date,'2025-02-28'::date),
    ('2025-03-1ST','2025-03-01'::date,'2025-03-15'::date),('2025-03-2ND','2025-03-16'::date,'2025-03-31'::date),
    ('2025-04-1ST','2025-04-01'::date,'2025-04-15'::date),('2025-04-2ND','2025-04-16'::date,'2025-04-30'::date),
    ('2025-05-1ST','2025-05-01'::date,'2025-05-15'::date),('2025-05-2ND','2025-05-16'::date,'2025-05-31'::date),
    ('2025-06-1ST','2025-06-01'::date,'2025-06-15'::date),('2025-06-2ND','2025-06-16'::date,'2025-06-30'::date),
    ('2025-07-1ST','2025-07-01'::date,'2025-07-15'::date),('2025-07-2ND','2025-07-16'::date,'2025-07-31'::date),
    ('2025-08-1ST','2025-08-01'::date,'2025-08-15'::date),('2025-08-2ND','2025-08-16'::date,'2025-08-31'::date),
    ('2025-09-1ST','2025-09-01'::date,'2025-09-15'::date),('2025-09-2ND','2025-09-16'::date,'2025-09-30'::date),
    ('2025-10-1ST','2025-10-01'::date,'2025-10-15'::date),('2025-10-2ND','2025-10-16'::date,'2025-10-31'::date),
    ('2025-11-1ST','2025-11-01'::date,'2025-11-15'::date),('2025-11-2ND','2025-11-16'::date,'2025-11-30'::date),
    ('2025-12-1ST','2025-12-01'::date,'2025-12-15'::date),('2025-12-2ND','2025-12-16'::date,'2025-12-31'::date)
) AS v(code, df, dt)
WHERE c.id = (SELECT id FROM core.companies LIMIT 1)
ON CONFLICT DO NOTHING;

INSERT INTO payroll.pay_runs (period_id, run_number, status, total_employees, computed_at)
SELECT pp.id, 1, 'COMPLETED', 20, pp.date_to
FROM payroll.pay_periods pp WHERE pp.status = 'CLOSED' AND pp.period_code LIKE '2025%'
ON CONFLICT DO NOTHING;

-- ================================================================
-- YEAR-END ADDITIONAL DATA (Gaps 9-18)
-- ================================================================

-- ── Gap 9: 2025 Leave Balances + 25 More Leave Requests ────────
INSERT INTO leave_mgmt.lv_balances (employee_id, leave_type_id, year, entitled_days, accrued_days, used_days, pending_days, carried_over)
SELECT e.id, lt.id, 2025,
    CASE lt.code WHEN 'VL' THEN 15 WHEN 'SL' THEN 15 WHEN 'SIL' THEN 5 ELSE 0 END,
    CASE lt.code WHEN 'VL' THEN 15 WHEN 'SL' THEN 15 WHEN 'SIL' THEN 5 ELSE 0 END,
    CASE lt.code WHEN 'VL' THEN FLOOR(random()*5+2) WHEN 'SL' THEN FLOOR(random()*4+1) ELSE 0 END,
    0, 0
FROM core.employees e CROSS JOIN leave_mgmt.lv_types lt
WHERE e.employee_no <= 'EMP-020' AND e.is_active = TRUE AND lt.code IN ('VL','SL','SIL')
ON CONFLICT (employee_id, leave_type_id, year) DO NOTHING;

-- Update 2026 VL balances with carry-over from 2025
UPDATE leave_mgmt.lv_balances b2026
SET carried_over = GREATEST(0, b2025.accrued_days - b2025.used_days - 5)
FROM leave_mgmt.lv_balances b2025
JOIN leave_mgmt.lv_types lt ON lt.id = b2025.leave_type_id AND lt.code = 'VL'
WHERE b2026.employee_id = b2025.employee_id
  AND b2026.leave_type_id = b2025.leave_type_id
  AND b2025.year = 2025 AND b2026.year = 2026;

-- 25 leave requests spanning 2025-2026
INSERT INTO leave_mgmt.lv_requests
    (reference_no, employee_id, leave_type_id, date_from, date_to, days_requested, reason, status, filed_at)
SELECT 'LV-YE-' || LPAD(ROW_NUMBER() OVER ()::text, 4, '0'),
       e.id, lt.id, v.df, v.dt, v.days, v.reason, v.status, v.filed
FROM (VALUES
    ('EMP-001','VL','2025-04-14'::date,'2025-04-18'::date,5.0,'Annual vacation','APPROVED',NOW()-INTERVAL '350 days'),
    ('EMP-001','SL','2025-08-11'::date,'2025-08-12'::date,2.0,'Medical checkup','APPROVED',NOW()-INTERVAL '230 days'),
    ('EMP-003','VL','2025-06-02'::date,'2025-06-03'::date,2.0,'Personal business','APPROVED',NOW()-INTERVAL '300 days'),
    ('EMP-005','VL','2025-09-22'::date,'2025-09-26'::date,5.0,'Family reunion','APPROVED',NOW()-INTERVAL '190 days'),
    ('EMP-005','SL','2025-12-15'::date,'2025-12-16'::date,2.0,'Dental appointment','APPROVED',NOW()-INTERVAL '105 days'),
    ('EMP-008','SL','2025-07-07'::date,'2025-07-08'::date,2.0,'Medical procedure','APPROVED',NOW()-INTERVAL '265 days'),
    ('EMP-009','VL','2025-10-06'::date,'2025-10-10'::date,5.0,'Out of town','APPROVED',NOW()-INTERVAL '175 days'),
    ('EMP-011','VL','2025-05-19'::date,'2025-05-20'::date,2.0,'Personal errand','APPROVED',NOW()-INTERVAL '315 days'),
    ('EMP-012','SL','2025-11-03'::date,'2025-11-04'::date,2.0,'Flu','APPROVED',NOW()-INTERVAL '148 days'),
    ('EMP-014','VL','2025-08-04'::date,'2025-08-08'::date,5.0,'Family vacation','APPROVED',NOW()-INTERVAL '238 days'),
    ('EMP-016','SL','2025-03-10'::date,'2025-03-12'::date,3.0,'Back pain','APPROVED',NOW()-INTERVAL '385 days'),
    ('EMP-019','VL','2025-12-22'::date,'2025-12-24'::date,3.0,'Christmas break','APPROVED',NOW()-INTERVAL '98 days'),
    ('EMP-020','SL','2025-06-16'::date,'2025-06-17'::date,2.0,'Eye checkup','APPROVED',NOW()-INTERVAL '288 days'),
    ('EMP-031','VL','2026-02-16'::date,'2026-02-18'::date,3.0,'Personal matters','APPROVED',NOW()-INTERVAL '42 days'),
    ('EMP-033','SL','2026-01-19'::date,'2026-01-20'::date,2.0,'Cold and flu','APPROVED',NOW()-INTERVAL '70 days'),
    ('EMP-035','VL','2025-11-17'::date,'2025-11-21'::date,5.0,'Province visit','APPROVED',NOW()-INTERVAL '133 days'),
    ('EMP-037','SL','2025-09-08'::date,'2025-09-09'::date,2.0,'Migraine','APPROVED',NOW()-INTERVAL '204 days'),
    ('EMP-039','VL','2026-03-09'::date,'2026-03-10'::date,2.0,'Personal business','APPROVED',NOW()-INTERVAL '21 days'),
    ('EMP-041','VL','2025-10-27'::date,'2025-10-31'::date,5.0,'Wedding preparation','APPROVED',NOW()-INTERVAL '154 days'),
    ('EMP-042','SL','2026-02-02'::date,'2026-02-03'::date,2.0,'Dental','APPROVED',NOW()-INTERVAL '56 days'),
    ('EMP-044','VL','2025-12-01'::date,'2025-12-05'::date,5.0,'Year-end leave','APPROVED',NOW()-INTERVAL '120 days'),
    ('EMP-002','PL','2025-07-28'::date,'2025-07-31'::date,4.0,'Paternity leave','APPROVED',NOW()-INTERVAL '245 days'),
    ('EMP-015','SIL','2025-11-10'::date,'2025-11-14'::date,5.0,'Solo parent duties','APPROVED',NOW()-INTERVAL '140 days'),
    ('EMP-009','SPL','2025-05-05'::date,'2025-05-07'::date,3.0,'Special privilege leave','APPROVED',NOW()-INTERVAL '328 days'),
    ('EMP-032','VL','2026-04-07'::date,'2026-04-09'::date,3.0,'Holy Week travel','PENDING',NOW()-INTERVAL '3 days')
) AS v(emp_no, lt_code, df, dt, days, reason, status, filed)
JOIN core.employees e ON e.employee_no = v.emp_no
JOIN leave_mgmt.lv_types lt ON lt.code = v.lt_code
ON CONFLICT (reference_no) DO NOTHING;

-- Leave balances for EMP-031+ (2026)
INSERT INTO leave_mgmt.lv_balances (employee_id, leave_type_id, year, entitled_days, accrued_days, used_days, pending_days)
SELECT e.id, lt.id, 2026,
    CASE lt.code WHEN 'VL' THEN 15 WHEN 'SL' THEN 15 WHEN 'SIL' THEN 5 ELSE 0 END,
    CASE lt.code WHEN 'VL' THEN 15 WHEN 'SL' THEN 15 WHEN 'SIL' THEN 5 ELSE 0 END,
    0, 0
FROM core.employees e CROSS JOIN leave_mgmt.lv_types lt
WHERE e.employee_no >= 'EMP-031' AND e.employee_no <= 'EMP-045' AND lt.code IN ('VL','SL','SIL')
ON CONFLICT (employee_id, leave_type_id, year) DO NOTHING;

-- ── Gap 10: 13th Month Pay for 2025 ───────────────────────────
INSERT INTO payroll.pay_13th_month
    (employee_id, year, total_basic_pay, months_worked, gross_13th, tax_exempt_amt, taxable_amt, net_13th, paid_at)
SELECT e.id, 2025, COALESCE(e.basic_salary, 25000) * 12, 12,
       COALESCE(e.basic_salary, 25000),
       90000,
       GREATEST(0, COALESCE(e.basic_salary, 25000) - 90000),
       COALESCE(e.basic_salary, 25000),
       '2025-12-20'::timestamptz
FROM core.employees e
WHERE e.employee_no <= 'EMP-020' AND e.is_active = TRUE
ON CONFLICT (employee_id, year) DO NOTHING;

-- ── Gap 11: Employee Payroll 2025 + Remittances ────────────────
DO $$
DECLARE
    r RECORD; emp RECORD;
    bp NUMERIC; gsis_p NUMERIC; gsis_g NUMERIC; pera_amt NUMERIC := 1000;
    pagibig_p NUMERIC := 100; pagibig_g NUMERIC := 100;
    tax NUMERIC; gross NUMERIC; total_ded NUMERIC; net NUMERIC;
BEGIN
    FOR r IN SELECT pr.id AS run_id FROM payroll.pay_runs pr
             JOIN payroll.pay_periods pp ON pp.id = pr.period_id
             WHERE pr.status = 'COMPLETED' AND pp.period_code LIKE '2025%' LOOP
        FOR emp IN SELECT e.id, e.basic_salary FROM core.employees e
                   WHERE e.is_active = TRUE AND e.employee_no <= 'EMP-020' LOOP
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

INSERT INTO payroll.pay_government_remittances (run_id, agency, remittance_date, total_ee, total_er, total_amount, status)
SELECT pr.id, v.agency, pp.date_to + 5, v.ee_rate * 20, v.er_rate * 20, (v.ee_rate + v.er_rate) * 20, 'REMITTED'
FROM payroll.pay_runs pr
JOIN payroll.pay_periods pp ON pp.id = pr.period_id
CROSS JOIN (VALUES
    ('GSIS',    1500.00, 2000.00),
    ('PAGIBIG',  100.00,  100.00),
    ('BIR',     2500.00,    0.00)
) AS v(agency, ee_rate, er_rate)
WHERE pr.status = 'COMPLETED' AND pp.period_code LIKE '2025%'
ON CONFLICT (run_id, agency) DO NOTHING;

-- ── Gap 12: Full Plantilla + More Applicants + PSB + Appointments
DO $$
DECLARE
    co_id BIGINT; hr_user BIGINT; emp RECORD;
    it_req BIGINT; hr_req BIGINT;
    it_post BIGINT; hr_post BIGINT;
    delib_id BIGINT; app_id BIGINT;
    emp31 BIGINT; emp34 BIGINT;
    pos_dev_jr BIGINT;
BEGIN
    SELECT id INTO co_id FROM core.companies LIMIT 1;
    SELECT id INTO hr_user FROM core.users WHERE username = 'hradmin';
    SELECT id INTO pos_dev_jr FROM core.positions WHERE code = 'DEV-JR';

    -- FILLED plantilla items for all 45 employees
    FOR emp IN SELECT e.id, e.employee_no, e.department_id,
                      COALESCE(jg.grade_level, 1) AS sg
              FROM core.employees e
              LEFT JOIN core.job_grades jg ON jg.id = e.job_grade_id
              WHERE e.is_active = TRUE
    LOOP
        INSERT INTO recruitment.rec_plantilla_items
            (company_id, department_id, item_number, salary_grade, step_no, filled_by, status)
        VALUES (co_id, emp.department_id,
                'ITEM-E' || LPAD(REPLACE(emp.employee_no, 'EMP-', ''), 3, '0'),
                emp.sg, 1, emp.id, 'FILLED')
        ON CONFLICT DO NOTHING;
    END LOOP;

    -- Get existing requisition/posting IDs
    SELECT id INTO it_req FROM recruitment.rec_requisitions WHERE reference_no = 'REQ-2026-001';
    SELECT id INTO hr_req FROM recruitment.rec_requisitions WHERE reference_no = 'REQ-2026-002';
    SELECT id INTO it_post FROM recruitment.rec_job_postings WHERE requisition_id = it_req LIMIT 1;
    SELECT id INTO hr_post FROM recruitment.rec_job_postings WHERE requisition_id = hr_req LIMIT 1;
    SELECT id INTO emp31 FROM core.employees WHERE employee_no = 'EMP-031';
    SELECT id INTO emp34 FROM core.employees WHERE employee_no = 'EMP-034';

    -- 6 more applicants across existing postings (guard: only if postings exist)
    IF it_post IS NOT NULL AND hr_post IS NOT NULL THEN
        INSERT INTO recruitment.rec_applicants
            (posting_id, first_name, last_name, email, mobile_no, stage, source, score, hired_as_employee_id)
        VALUES
            (it_post, 'Ryan', 'De Guzman', 'ryan.deguz@gmail.com', '09175550301', 'HIRED', 'CSC_POSTING', 92.00, emp31),
            (it_post, 'Paolo', 'Villanueva', 'paolo.v@yahoo.com', '09185550302', 'INTERVIEWED', 'PHILJOBNET', 75.50, NULL),
            (it_post, 'Diana', 'Santos', 'diana.s@gmail.com', '09195550303', 'REJECTED', 'AGENCY_WEBSITE', 60.00, NULL),
            (hr_post, 'Cherry Ann', 'Mercado', 'cherry.m@gmail.com', '09175550304', 'HIRED', 'CSC_POSTING', 88.75, emp34),
            (hr_post, 'Gemma', 'Tolentino', 'gemma.t@yahoo.com', '09185550305', 'SHORTLISTED', 'PHILJOBNET', 81.00, NULL),
            (hr_post, 'Mark', 'Aguilar', 'mark.agu@gmail.com', '09195550306', 'SCREENED', 'AGENCY_WEBSITE', NULL, NULL);
    END IF;

    -- PSB Deliberation for IT requisition (guard: skip if requisition not found)
    IF it_req IS NOT NULL THEN
        INSERT INTO recruitment.rec_psb_deliberations
            (requisition_id, deliberation_date, chairperson_id, status, resolution, created_by)
        VALUES (it_req, '2023-12-15',
                (SELECT id FROM core.employees WHERE employee_no = 'EMP-016'),
                'COMPLETED',
                'Deliberation completed. Ryan De Guzman recommended for appointment.',
                hr_user)
        RETURNING id INTO delib_id;
    END IF;

    -- PSB Scores (for IT posting applicants)
    INSERT INTO recruitment.rec_psb_scores
        (deliberation_id, applicant_id, education_score, experience_score,
         training_score, performance_score, interview_score, rank, is_next_in_rank)
    SELECT delib_id, a.id, v.edu, v.exp, v.trn, v.perf, v.intv, v.rnk, v.nir
    FROM (VALUES
        ('ryan.deguz@gmail.com',   25.00, 20.00, 15.00, 18.00, 14.00, 1, TRUE),
        ('rafael.magbanua@gmail.com',22.00,17.00,12.00,15.00,12.00, 2, FALSE),
        ('karen.tiu@yahoo.com',     20.00, 15.00, 10.00, 14.00, 11.00, 3, FALSE),
        ('paolo.v@yahoo.com',       18.00, 14.00, 11.00, 13.00, 10.00, 4, FALSE)
    ) AS v(email, edu, exp, trn, perf, intv, rnk, nir)
    JOIN recruitment.rec_applicants a ON a.email = v.email
    ON CONFLICT (deliberation_id, applicant_id) DO NOTHING;

    -- Appointment for EMP-031
    INSERT INTO recruitment.rec_appointments
        (employee_id, position_id, appointment_type, appointment_no,
         effective_date, salary_grade, step_no, monthly_salary,
         issued_by, approved_by, status)
    VALUES (emp31, pos_dev_jr, 'PERMANENT', 'APT-2024-001',
            '2024-01-15', 11, 1, 27000, hr_user, hr_user, 'ATTESTED')
    ON CONFLICT DO NOTHING;
END $$;

-- ── Gap 13: IDP Plans ──────────────────────────────────────────
INSERT INTO performance.perf_idp_plans
    (employee_id, cycle_id, development_goal, action_steps, target_date, status)
SELECT e.id, c.id, v.goal, v.steps, v.target, v.status
FROM performance.perf_cycles c,
(VALUES
    ('EMP-002','Complete Leadership Certification Program',
     '1. Enroll in Leadership Fundamentals. 2. Complete coaching sessions. 3. Submit portfolio.',
     '2026-12-31'::date, 'IN_PROGRESS'),
    ('EMP-006','Obtain PMP Certification',
     '1. Attend PM-201 training. 2. Complete 35 PDUs. 3. Take PMP exam.',
     '2026-09-30'::date, 'IN_PROGRESS'),
    ('EMP-008','Develop strategic planning capabilities',
     '1. Attend Strategic Planning for LGUs. 2. Lead a department planning exercise. 3. Present to executive team.',
     '2026-12-31'::date, 'IN_PROGRESS'),
    ('EMP-009','Strengthen safety compliance expertise',
     '1. Complete DOLE safety officer training. 2. Conduct 2 safety audits. 3. Update SOPs.',
     '2026-10-31'::date, 'IN_PROGRESS'),
    ('EMP-012','Prepare for CPA licensure',
     '1. Enroll in CPA review. 2. Complete Government Accounting course. 3. Take CPA board exam.',
     '2026-12-31'::date, 'IN_PROGRESS'),
    ('EMP-031','Build IT project management skills',
     '1. Shadow senior developers on 2 projects. 2. Attend PM-201. 3. Lead a small project independently.',
     '2026-11-30'::date, 'IN_PROGRESS')
) AS v(emp_no, goal, steps, target, status)
JOIN core.employees e ON e.employee_no = v.emp_no
WHERE c.name = '2026 Mid-Year Review';

-- ── Gap 14: Skills Matrix ──────────────────────────────────────
INSERT INTO learning.lrn_skills (company_id, code, name, category)
SELECT c.id, v.code, v.name, v.cat
FROM core.companies c,
(VALUES
    ('LEADERSHIP','Leadership & Management','Management'),
    ('PROJ-MGMT','Project Management','Management'),
    ('HR-ADMIN','HR Administration','HR'),
    ('RECRUITMENT','Recruitment & Selection','HR'),
    ('GOV-ACCT','Government Accounting','Finance'),
    ('BUDGETING','Budget Management','Finance'),
    ('PYTHON','Python Programming','Technical'),
    ('SQL-DB','SQL & Database Admin','Technical'),
    ('WEB-DEV','Web Development','Technical'),
    ('PUB-ADMIN','Public Administration','Government'),
    ('CSC-RULES','CSC Rules & Regulations','Government'),
    ('COMM','Communication Skills','Soft Skills'),
    ('RECORDS-MGMT','Records Management','Administrative'),
    ('DATA-ANALYSIS','Data Analysis','Technical')
) AS v(code, name, cat)
WHERE c.id = (SELECT id FROM core.companies LIMIT 1)
ON CONFLICT DO NOTHING;

INSERT INTO learning.lrn_employee_skills (employee_id, skill_id, proficiency, assessed_on)
SELECT e.id, s.id, v.prof, '2026-01-15'::date
FROM (VALUES
    ('EMP-001','LEADERSHIP','EXPERT'),('EMP-001','HR-ADMIN','EXPERT'),('EMP-001','RECRUITMENT','ADVANCED'),
    ('EMP-002','HR-ADMIN','ADVANCED'),('EMP-002','RECRUITMENT','INTERMEDIATE'),('EMP-002','COMM','ADVANCED'),
    ('EMP-005','PROJ-MGMT','EXPERT'),('EMP-005','PYTHON','ADVANCED'),('EMP-005','SQL-DB','EXPERT'),
    ('EMP-006','WEB-DEV','ADVANCED'),('EMP-006','PYTHON','INTERMEDIATE'),('EMP-006','SQL-DB','ADVANCED'),
    ('EMP-008','LEADERSHIP','ADVANCED'),('EMP-008','PUB-ADMIN','ADVANCED'),
    ('EMP-009','PUB-ADMIN','INTERMEDIATE'),('EMP-009','CSC-RULES','ADVANCED'),
    ('EMP-011','GOV-ACCT','EXPERT'),('EMP-011','BUDGETING','EXPERT'),('EMP-011','DATA-ANALYSIS','ADVANCED'),
    ('EMP-012','GOV-ACCT','ADVANCED'),('EMP-012','BUDGETING','INTERMEDIATE'),
    ('EMP-014','COMM','EXPERT'),('EMP-014','LEADERSHIP','ADVANCED'),
    ('EMP-016','RECORDS-MGMT','EXPERT'),('EMP-016','PUB-ADMIN','ADVANCED'),
    ('EMP-019','CSC-RULES','INTERMEDIATE'),('EMP-019','PUB-ADMIN','INTERMEDIATE'),
    ('EMP-031','WEB-DEV','BEGINNER'),('EMP-031','PYTHON','BEGINNER'),('EMP-031','SQL-DB','BEGINNER'),
    ('EMP-033','PUB-ADMIN','INTERMEDIATE'),('EMP-034','GOV-ACCT','BEGINNER'),
    ('EMP-035','LEADERSHIP','INTERMEDIATE'),('EMP-039','WEB-DEV','INTERMEDIATE'),
    ('EMP-044','GOV-ACCT','ADVANCED'),('EMP-044','BUDGETING','ADVANCED'),('EMP-044','DATA-ANALYSIS','INTERMEDIATE'),
    ('EMP-045','PUB-ADMIN','EXPERT'),('EMP-045','RECORDS-MGMT','EXPERT'),('EMP-045','CSC-RULES','EXPERT')
) AS v(emp_no, skill_code, prof)
JOIN core.employees e ON e.employee_no = v.emp_no
JOIN learning.lrn_skills s ON s.code = v.skill_code
ON CONFLICT (employee_id, skill_id) DO NOTHING;

-- ── Gap 15: IDP Actions linked to TNA ──────────────────────────
DO $$
DECLARE
    idp RECORD; tna RECORD;
BEGIN
    -- EMP-002 IDP → TNA (recruitment processing timeliness)
    FOR idp IN SELECT id FROM performance.perf_idp_plans
               WHERE employee_id = (SELECT id FROM core.employees WHERE employee_no = 'EMP-002')
               LIMIT 1
    LOOP
        FOR tna IN SELECT id FROM learning.lrn_tna_entries
                   WHERE employee_id = (SELECT id FROM core.employees WHERE employee_no = 'EMP-002')
                   LIMIT 1
        LOOP
            INSERT INTO learning.lrn_idp_actions
                (idp_plan_id, tna_entry_id, action_type, target_completion_date, status)
            VALUES (idp.id, tna.id, 'TRAINING', '2026-06-30', 'IN_PROGRESS');
        END LOOP;
    END LOOP;

    -- EMP-006 IDP → TNA (project delivery efficiency)
    FOR idp IN SELECT id FROM performance.perf_idp_plans
               WHERE employee_id = (SELECT id FROM core.employees WHERE employee_no = 'EMP-006')
               LIMIT 1
    LOOP
        FOR tna IN SELECT id FROM learning.lrn_tna_entries
                   WHERE employee_id = (SELECT id FROM core.employees WHERE employee_no = 'EMP-006')
                   AND competency_gap LIKE '%delivery%'
                   LIMIT 1
        LOOP
            INSERT INTO learning.lrn_idp_actions
                (idp_plan_id, tna_entry_id, action_type, target_completion_date, status)
            VALUES (idp.id, tna.id, 'TRAINING', '2026-09-30', 'PLANNED');
        END LOOP;
        -- Also link scholarship
        INSERT INTO learning.lrn_idp_actions
            (idp_plan_id, action_type, target_completion_date, status)
        VALUES (idp.id, 'SCHOLARSHIP', '2027-03-31', 'IN_PROGRESS');
    END LOOP;

    -- EMP-008 IDP → TNA (quality in operations)
    FOR idp IN SELECT id FROM performance.perf_idp_plans
               WHERE employee_id = (SELECT id FROM core.employees WHERE employee_no = 'EMP-008')
               LIMIT 1
    LOOP
        FOR tna IN SELECT id FROM learning.lrn_tna_entries
                   WHERE employee_id = (SELECT id FROM core.employees WHERE employee_no = 'EMP-008')
                   LIMIT 1
        LOOP
            INSERT INTO learning.lrn_idp_actions
                (idp_plan_id, tna_entry_id, action_type, target_completion_date, status)
            VALUES (idp.id, tna.id, 'COACHING', '2026-12-31', 'PLANNED');
        END LOOP;
    END LOOP;
END $$;

-- ── Gap 16: Health Certificates (Active + Expired) ─────────────
INSERT INTO health.health_certificates
    (employee_id, certificate_type, issued_date, expiry_date, issuing_authority, status)
SELECT e.id, v.cert_type, v.issued, v.expiry, v.authority, v.status
FROM (VALUES
    -- Active certificates (2025 annual medicals)
    ('EMP-001','DRUG_FREE_CERT','2025-06-15'::date,'2026-06-15'::date,'City Health Office','ACTIVE'),
    ('EMP-005','DRUG_FREE_CERT','2025-06-15'::date,'2026-06-15'::date,'City Health Office','ACTIVE'),
    ('EMP-008','FITNESS_TO_WORK','2025-06-20'::date,'2026-06-20'::date,'Government Hospital','ACTIVE'),
    ('EMP-011','DRUG_FREE_CERT','2025-06-15'::date,'2026-06-15'::date,'City Health Office','ACTIVE'),
    ('EMP-014','FITNESS_TO_WORK','2025-06-20'::date,'2026-06-20'::date,'Government Hospital','ACTIVE'),
    ('EMP-019','DRUG_FREE_CERT','2025-06-15'::date,'2026-06-15'::date,'City Health Office','ACTIVE'),
    -- Expired certificates (2024 medicals — not renewed)
    ('EMP-010','DRUG_FREE_CERT','2024-05-10'::date,'2025-05-10'::date,'City Health Office','EXPIRED'),
    ('EMP-015','FITNESS_TO_WORK','2024-06-01'::date,'2025-06-01'::date,'Government Hospital','EXPIRED'),
    ('EMP-016','DRUG_FREE_CERT','2024-05-10'::date,'2025-05-10'::date,'City Health Office','EXPIRED'),
    ('EMP-033','FITNESS_TO_WORK','2024-07-15'::date,'2025-07-15'::date,'Government Hospital','EXPIRED'),
    ('EMP-045','DRUG_FREE_CERT','2024-05-10'::date,'2025-05-10'::date,'City Health Office','EXPIRED'),
    ('EMP-045','FITNESS_TO_WORK','2024-06-01'::date,'2025-06-01'::date,'Government Hospital','EXPIRED')
) AS v(emp_no, cert_type, issued, expiry, authority, status)
JOIN core.employees e ON e.employee_no = v.emp_no;

-- ── Gap 17: DMS 95% completion + SALN reminders ────────────────
-- Upgrade QS base-20 from 60% → ~95%: flip most PENDING to SUBMITTED
UPDATE dms.document_requests
SET status = 'SUBMITTED', updated_at = NOW()
WHERE status = 'PENDING'
  AND document_type NOT IN ('SALN')
  AND employee_id IN (SELECT id FROM core.employees WHERE employee_no <= 'EMP-020');

-- DMS for new employees (EMP-021 to EMP-045): 15/16 items SUBMITTED
DO $$
DECLARE
    emp RECORD; co_id BIGINT; hr_user BIGINT;
    doc_types TEXT[] := ARRAY[
        'PDS_CS212','OATH_OF_OFFICE','APPOINTMENT_PAPER','CSC_ELIGIBILITY',
        'BIRTH_CERTIFICATE','MARRIAGE_CERT','DIPLOMA_TOR','NBI_CLEARANCE',
        'MEDICAL_CERT','SALN','BIR_TIN','GSIS_ID','PAGIBIG_ID','PHILHEALTH_ID',
        'SSS_ID','PHOTO_2X2'
    ];
    dt TEXT; idx INT;
BEGIN
    SELECT id INTO co_id FROM core.companies LIMIT 1;
    SELECT id INTO hr_user FROM core.users WHERE username IN ('hradmin','superadmin') ORDER BY username LIMIT 1;

    FOR emp IN SELECT id FROM core.employees
               WHERE employee_no >= 'EMP-021' AND employee_no <= 'EMP-045' LOOP
        idx := 0;
        FOREACH dt IN ARRAY doc_types LOOP
            idx := idx + 1;
            INSERT INTO dms.document_requests
                (company_id, employee_id, document_type, purpose, requested_by, due_date, status)
            SELECT co_id, emp.id, dt, '201 File compliance', hr_user, '2026-06-30',
                -- SALN stays PENDING; everything else SUBMITTED
                CASE WHEN dt = 'SALN' THEN 'PENDING' ELSE 'SUBMITTED' END
            WHERE NOT EXISTS (
                SELECT 1 FROM dms.document_requests dr
                WHERE dr.employee_id = emp.id AND dr.document_type = dt
            );
        END LOOP;
    END LOOP;
END $$;

-- ── Gap 18: Onboarding checklists for EMP-031 to EMP-045 ──────
DO $$
DECLARE
    emp RECORD; cl_id BIGINT; buddy BIGINT;
    items TEXT[][] := ARRAY[
        ARRAY['Documents','Submit PDS (CS Form 212)'],
        ARRAY['Documents','Submit authenticated birth certificate'],
        ARRAY['Documents','Submit NBI clearance'],
        ARRAY['Documents','Submit medical certificate'],
        ARRAY['Documents','Submit certificate of eligibility'],
        ARRAY['IT Setup','Create email account'],
        ARRAY['IT Setup','Issue laptop/workstation'],
        ARRAY['IT Setup','Grant HCM360 system access'],
        ARRAY['Orientation','Complete agency orientation'],
        ARRAY['Orientation','Meet department head and team']
    ];
    item TEXT[];
    i INT; total_items INT := 10;
    completed_count INT;
    hire_age_months INT;
BEGIN
    FOR emp IN SELECT e.id, e.employee_no, e.department_id, e.date_hired,
                      e.immediate_supervisor_id
              FROM core.employees e
              WHERE e.employee_no >= 'EMP-031' AND e.employee_no <= 'EMP-045'
    LOOP
        hire_age_months := EXTRACT(EPOCH FROM (NOW() - emp.date_hired)) / 2592000;

        -- Determine checklist status: >6 months old = COMPLETED
        INSERT INTO onboarding.onb_checklists (employee_id, type, status, target_date, completed_at)
        VALUES (emp.id, 'ONBOARDING',
                CASE WHEN hire_age_months > 6 THEN 'COMPLETED' ELSE 'IN_PROGRESS' END,
                emp.date_hired + INTERVAL '30 days',
                CASE WHEN hire_age_months > 6 THEN emp.date_hired + INTERVAL '28 days' ELSE NULL END)
        RETURNING id INTO cl_id;

        -- Items: all completed if hire > 6 months, partial for recent hires
        completed_count := CASE WHEN hire_age_months > 6 THEN total_items ELSE 6 END;
        i := 0;
        FOREACH item SLICE 1 IN ARRAY items LOOP
            i := i + 1;
            INSERT INTO onboarding.onb_checklist_items
                (checklist_id, category, item_name, is_required, is_completed, sort_order)
            VALUES (cl_id, item[1], item[2], TRUE, i <= completed_count, i);
        END LOOP;

        -- Buddy assignment: supervisor or senior in same department
        SELECT id INTO buddy FROM core.employees
        WHERE department_id = emp.department_id
          AND id != emp.id AND is_active = TRUE
          AND date_hired < emp.date_hired
        ORDER BY date_hired LIMIT 1;

        IF buddy IS NOT NULL THEN
            INSERT INTO onboarding.onb_buddy_assignments (employee_id, buddy_id, assigned_from, assigned_to)
            VALUES (emp.id, buddy, emp.date_hired, emp.date_hired + INTERVAL '90 days');
        END IF;

        -- Pre-employment requirements
        INSERT INTO onboarding.onb_pre_employment_reqs
            (employee_id, requirement_type, submitted_at)
        VALUES
            (emp.id, 'MEDICAL_CERT',  emp.date_hired - INTERVAL '10 days'),
            (emp.id, 'NBI_CLEARANCE', emp.date_hired - INTERVAL '7 days'),
            (emp.id, 'BIRTH_CERT',    emp.date_hired - INTERVAL '14 days'),
            (emp.id, 'TOR',           emp.date_hired - INTERVAL '14 days'),
            (emp.id, 'PDS_CS9',       emp.date_hired - INTERVAL '3 days'),
            (emp.id, 'OATHS',         emp.date_hired);
    END LOOP;
END $$;

-- ================================================================
-- ── Org Chart: supervisor hierarchy for EMP-021 to EMP-045 ──────
-- Gabriel Soriano (EMP-021) is the top-level executive.
-- Direct reports to Gabriel: Angelica, Aira Mae, Rodel, Kristine Joy,
--   John Carlo, + 5 staff roles (Erwin, Maricel, Francis, Aileen, Edwin)
-- Second-level managers: Angelica, Rodel, John Carlo, Kristine Joy, Aira Mae
-- ================================================================
UPDATE core.employees SET immediate_supervisor_id = NULL
  WHERE employee_no = 'EMP-021';

UPDATE core.employees SET immediate_supervisor_id = (SELECT id FROM core.employees WHERE employee_no = 'EMP-021')
  WHERE employee_no IN ('EMP-022','EMP-026','EMP-027','EMP-028','EMP-029',
                        'EMP-041','EMP-042','EMP-043','EMP-044','EMP-045');

-- Angelica Pangilinan's team
UPDATE core.employees SET immediate_supervisor_id = (SELECT id FROM core.employees WHERE employee_no = 'EMP-022')
  WHERE employee_no IN ('EMP-025','EMP-031','EMP-032');

-- Rodel Magat's team
UPDATE core.employees SET immediate_supervisor_id = (SELECT id FROM core.employees WHERE employee_no = 'EMP-027')
  WHERE employee_no IN ('EMP-024','EMP-030','EMP-033','EMP-034');

-- John Carlo Mendez's team
UPDATE core.employees SET immediate_supervisor_id = (SELECT id FROM core.employees WHERE employee_no = 'EMP-029')
  WHERE employee_no IN ('EMP-023','EMP-035','EMP-036');

-- Kristine Joy Dela Pena's team
UPDATE core.employees SET immediate_supervisor_id = (SELECT id FROM core.employees WHERE employee_no = 'EMP-028')
  WHERE employee_no IN ('EMP-037','EMP-038');

-- Aira Mae Cortez's team
UPDATE core.employees SET immediate_supervisor_id = (SELECT id FROM core.employees WHERE employee_no = 'EMP-026')
  WHERE employee_no IN ('EMP-039','EMP-040');
