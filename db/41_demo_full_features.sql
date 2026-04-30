-- ================================================================
-- HCM360 DEMO — PROFILE D: FULL FEATURES LGU
-- Complete municipal LGU with 2 years of data across every module.
-- Builds on Year-End (38+39+40) which seeds 45 employees.
-- This file adds 15 more (EMP-046 to EMP-060) + 2 years of history.
-- ================================================================

-- ══════════════════════════════════════════════════════════════════
-- 1. CORE: 15 More Employees + Role-varied Users
-- ══════════════════════════════════════════════════════════════════
DO $$
DECLARE
    co_id BIGINT; hr_id BIGINT; it_id BIGINT; fin_id BIGINT; ops_id BIGINT;
    mkt_id BIGINT; adm_id BIGINT; exe_id BIGINT;
    jg1 BIGINT; jg2 BIGINT; jg3 BIGINT; jg4 BIGINT; jg5 BIGINT;
    et_reg BIGINT; et_cas BIGINT;
    sup_hr BIGINT; sup_it BIGINT; sup_fin BIGINT; sup_ops BIGINT; sup_mkt BIGINT;
BEGIN
    SELECT id INTO co_id FROM core.companies LIMIT 1;
    SELECT id INTO hr_id FROM core.departments WHERE code = 'HR';
    SELECT id INTO it_id FROM core.departments WHERE code = 'IT';
    SELECT id INTO fin_id FROM core.departments WHERE code = 'FIN';
    SELECT id INTO ops_id FROM core.departments WHERE code = 'OPS';
    SELECT id INTO mkt_id FROM core.departments WHERE code = 'MKT';
    SELECT id INTO adm_id FROM core.departments WHERE code = 'ADM';
    SELECT id INTO exe_id FROM core.departments WHERE code = 'EXE';
    SELECT id INTO jg1 FROM core.job_grades WHERE code = 'JG1';
    SELECT id INTO jg2 FROM core.job_grades WHERE code = 'JG2';
    SELECT id INTO jg3 FROM core.job_grades WHERE code = 'JG3';
    SELECT id INTO jg4 FROM core.job_grades WHERE code = 'JG4';
    SELECT id INTO jg5 FROM core.job_grades WHERE code = 'JG5';
    SELECT id INTO et_reg FROM core.employment_types WHERE code = 'REGULAR';
    SELECT id INTO et_cas FROM core.employment_types WHERE code = 'CASUAL';
    SELECT id INTO sup_hr FROM core.employees WHERE employee_no = 'EMP-001';
    SELECT id INTO sup_it FROM core.employees WHERE employee_no = 'EMP-005';
    SELECT id INTO sup_fin FROM core.employees WHERE employee_no = 'EMP-011';
    SELECT id INTO sup_ops FROM core.employees WHERE employee_no = 'EMP-008';
    SELECT id INTO sup_mkt FROM core.employees WHERE employee_no = 'EMP-014';

    IF exe_id IS NULL THEN exe_id := adm_id; END IF;
    IF jg3 IS NULL THEN jg3 := jg2; END IF;
    IF jg4 IS NULL THEN jg4 := jg2; END IF;
    IF jg5 IS NULL THEN jg5 := jg2; END IF;

    INSERT INTO core.employees
        (company_id, employee_no, first_name, last_name, middle_name, gender, date_of_birth,
         date_hired, department_id, job_grade_id, employment_type_id,
         immediate_supervisor_id, status, is_active, work_email, mobile_no, civil_status, nationality)
    VALUES
        (co_id,'EMP-046','Patricia','Mendoza','L.','FEMALE','1990-05-12','2023-03-01',hr_id,jg3,et_reg,sup_hr,'ACTIVE',TRUE,'patricia.mendoza@agency.gov.ph','09171000046','MARRIED','Filipino'),
        (co_id,'EMP-047','Ricardo','Santos','M.','MALE','1985-11-25','2022-06-15',hr_id,jg4,et_reg,sup_hr,'ACTIVE',TRUE,'ricardo.santos@agency.gov.ph','09171000047','MARRIED','Filipino'),
        (co_id,'EMP-048','Maria Clara','Fernandez','A.','FEMALE','1993-07-18','2023-04-01',it_id,jg3,et_reg,sup_it,'ACTIVE',TRUE,'clara.fernandez@agency.gov.ph','09171000048','SINGLE','Filipino'),
        (co_id,'EMP-049','Roberto','Villanueva','C.','MALE','1988-02-28','2022-01-10',it_id,jg4,et_reg,sup_it,'ACTIVE',TRUE,'roberto.villanueva@agency.gov.ph','09171000049','MARRIED','Filipino'),
        (co_id,'EMP-050','Carmela','Dizon','R.','FEMALE','1991-09-14','2023-05-15',fin_id,jg3,et_reg,sup_fin,'ACTIVE',TRUE,'carmela.dizon@agency.gov.ph','09171000050','SINGLE','Filipino'),
        (co_id,'EMP-051','Emmanuel','Garcia','S.','MALE','1987-03-07','2022-08-01',fin_id,jg4,et_reg,sup_fin,'ACTIVE',TRUE,'emmanuel.garcia@agency.gov.ph','09171000051','MARRIED','Filipino'),
        (co_id,'EMP-052','Rosalinda','Bernal','T.','FEMALE','1992-12-01','2023-07-01',ops_id,jg2,et_reg,sup_ops,'ACTIVE',TRUE,'rosalinda.bernal@agency.gov.ph','09171000052','SINGLE','Filipino'),
        (co_id,'EMP-053','Danilo','Magtibay','V.','MALE','1984-06-20','2021-03-15',ops_id,jg4,et_reg,sup_ops,'ACTIVE',TRUE,'danilo.magtibay@agency.gov.ph','09171000053','MARRIED','Filipino'),
        (co_id,'EMP-054','Jennifer','Lacsamana','P.','FEMALE','1995-01-30','2024-01-15',mkt_id,jg2,et_reg,sup_mkt,'ACTIVE',TRUE,'jennifer.lacsamana@agency.gov.ph','09171000054','SINGLE','Filipino'),
        (co_id,'EMP-055','Fernando','Reyes','G.','MALE','1980-08-10','2019-01-02',exe_id,jg5,et_reg,NULL,'ACTIVE',TRUE,'fernando.reyes@agency.gov.ph','09171000055','MARRIED','Filipino'),
        (co_id,'EMP-056','Lourdes','Aquino','H.','FEMALE','1982-04-22','2019-06-01',exe_id,jg5,et_reg,NULL,'ACTIVE',TRUE,'lourdes.aquino@agency.gov.ph','09171000056','MARRIED','Filipino'),
        (co_id,'EMP-057','Michael','Tolentino','J.','MALE','1998-10-05','2025-01-15',ops_id,jg1,et_cas,sup_ops,'ACTIVE',TRUE,'michael.tolentino@agency.gov.ph','09171000057','SINGLE','Filipino'),
        (co_id,'EMP-058','Angelina','Cruz','K.','FEMALE','1999-03-12','2025-02-01',hr_id,jg1,et_cas,sup_hr,'ACTIVE',TRUE,'angelina.cruz@agency.gov.ph','09171000058','SINGLE','Filipino'),
        (co_id,'EMP-059','Rodolfo','Manansala','B.','MALE','1963-08-15','2010-01-10',adm_id,jg4,et_reg,NULL,'ACTIVE',TRUE,'rodolfo.manansala@agency.gov.ph','09171000059','MARRIED','Filipino'),
        (co_id,'EMP-060','Ana Maria','Villareal','D.','FEMALE','1991-06-28','2022-03-01',mkt_id,jg2,et_reg,sup_mkt,'SEPARATED',FALSE,'ana.villareal@agency.gov.ph','09171000060','SINGLE','Filipino')
    ON CONFLICT DO NOTHING;

    INSERT INTO core.users (company_id, username, email, display_name, role_code, employee_id, is_active)
    SELECT co_id, LOWER(e.first_name || '.' || e.last_name), e.work_email,
           e.first_name || ' ' || e.last_name, 'EMPLOYEE', e.id, e.is_active
    FROM core.employees e WHERE e.employee_no >= 'EMP-046' AND e.employee_no <= 'EMP-060'
    ON CONFLICT DO NOTHING;

    -- Assign varied roles
    UPDATE core.users SET role_code = 'HR_ADMIN'  WHERE employee_id = (SELECT id FROM core.employees WHERE employee_no = 'EMP-047');
    UPDATE core.users SET role_code = 'MANAGER'   WHERE employee_id = (SELECT id FROM core.employees WHERE employee_no = 'EMP-049');
    UPDATE core.users SET role_code = 'EXECUTIVE' WHERE employee_id IN (SELECT id FROM core.employees WHERE employee_no IN ('EMP-055','EMP-056'));
    UPDATE core.users SET role_code = 'MANAGER'   WHERE employee_id IN (SELECT id FROM core.employees WHERE employee_no IN ('EMP-001','EMP-005','EMP-008','EMP-011','EMP-014'));
    UPDATE core.users SET role_code = 'HR_ADMIN'  WHERE employee_id = (SELECT id FROM core.employees WHERE employee_no = 'EMP-016');
END $$;


-- ══════════════════════════════════════════════════════════════════
-- 2. ATTENDANCE: 2 years (Apr 2024 – Mar 2026)
-- ══════════════════════════════════════════════════════════════════
DO $$
DECLARE emp RECORD; d DATE; shift_id BIGINT; is_late BOOLEAN;
BEGIN
    SELECT id INTO shift_id FROM attendance.att_shifts WHERE code = 'REG-8-5' LIMIT 1;
    IF shift_id IS NULL THEN RETURN; END IF;
    FOR emp IN SELECT id, employee_no, date_hired FROM core.employees WHERE is_active = TRUE LOOP
        FOR d IN SELECT generate_series('2024-04-01'::date, '2026-03-31'::date, '1 day')::date LOOP
            IF EXTRACT(DOW FROM d) IN (0, 6) THEN CONTINUE; END IF;
            IF d < emp.date_hired THEN CONTINUE; END IF;
            is_late := (emp.employee_no IN ('EMP-010','EMP-024','EMP-027','EMP-057') AND random() < 0.30);
            IF random() < 0.02 THEN CONTINUE; END IF; -- 2% absence
            INSERT INTO attendance.att_daily
                (employee_id, work_date, shift_id, time_in, time_out,
                 hours_worked, hours_late, hours_undertime, hours_overtime, status)
            VALUES (emp.id, d, shift_id,
                CASE WHEN is_late THEN (d + TIME '08:10' + (random() * INTERVAL '45 min'))::TIMESTAMP
                     ELSE (d + TIME '07:45' + (random() * INTERVAL '15 min'))::TIMESTAMP END,
                (d + TIME '17:00' + (random() * INTERVAL '30 min'))::TIMESTAMP,
                8.0 + round((random())::numeric, 2),
                CASE WHEN is_late THEN round((random() * 0.75)::numeric, 2) ELSE 0 END,
                0,
                CASE WHEN random() < 0.08 THEN round((random() * 2)::numeric, 2) ELSE 0 END,
                CASE WHEN is_late THEN 'LATE' ELSE 'PRESENT' END
            ) ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;
END $$;

-- Overtime requests (correct columns: request_date, expected_ot_hours)
DO $$
DECLARE emp RECORD; i INT;
BEGIN
    FOR emp IN SELECT id FROM core.employees WHERE is_active = TRUE ORDER BY random() LIMIT 20 LOOP
        FOR i IN 1..3 LOOP
            INSERT INTO attendance.att_overtime_requests
                (employee_id, request_date, expected_ot_hours, reason, status)
            VALUES (emp.id,
                '2025-01-01'::date + (random() * 365)::int,
                2.0,
                (ARRAY['Quarter-end reports','System maintenance','Event preparation','Deadline compliance'])[ceil(random()*4)],
                (ARRAY['APPROVED','PENDING','APPROVED','APPROVED'])[ceil(random()*4)]
            ) ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;
END $$;


-- ══════════════════════════════════════════════════════════════════
-- 3. LEAVE: balances + 80+ requests
-- ══════════════════════════════════════════════════════════════════
DO $$
DECLARE emp RECORD; yr INT; lt RECORD;
BEGIN
    FOR emp IN SELECT id FROM core.employees WHERE is_active = TRUE LOOP
        FOR yr IN 2024..2026 LOOP
            FOR lt IN SELECT id, code FROM leave_mgmt.lv_types LOOP
                INSERT INTO leave_mgmt.lv_balances
                    (employee_id, leave_type_id, year, entitled_days, accrued_days, used_days, pending_days)
                VALUES (emp.id, lt.id, yr,
                    CASE lt.code WHEN 'VL' THEN 15 WHEN 'SL' THEN 15 WHEN 'SIL' THEN 5
                                 WHEN 'ML' THEN 105 WHEN 'PL' THEN 7 WHEN 'SPL' THEN 3 ELSE 0 END,
                    CASE lt.code WHEN 'VL' THEN 15 WHEN 'SL' THEN 15 WHEN 'SIL' THEN 5 ELSE 0 END,
                    CASE WHEN yr < 2026 AND lt.code IN ('VL','SL') THEN floor(random()*8)::int ELSE 0 END, 0
                ) ON CONFLICT DO NOTHING;
            END LOOP;
        END LOOP;
    END LOOP;
END $$;

-- Leave requests
DO $$
DECLARE emp RECORD; vl_id BIGINT; sl_id BIGINT; ml_id BIGINT; pl_id BIGINT; spl_id BIGINT;
BEGIN
    SELECT id INTO vl_id FROM leave_mgmt.lv_types WHERE code = 'VL';
    SELECT id INTO sl_id FROM leave_mgmt.lv_types WHERE code = 'SL';
    SELECT id INTO ml_id FROM leave_mgmt.lv_types WHERE code = 'ML';
    SELECT id INTO pl_id FROM leave_mgmt.lv_types WHERE code = 'PL';
    SELECT id INTO spl_id FROM leave_mgmt.lv_types WHERE code = 'SPL';

    FOR emp IN SELECT id FROM core.employees WHERE is_active = TRUE ORDER BY random() LIMIT 40 LOOP
        INSERT INTO leave_mgmt.lv_requests
            (reference_no, employee_id, leave_type_id, date_from, date_to, days_requested, reason, status, filed_at)
        VALUES
            ('LR-' || emp.id || '-VL-' || floor(random()*9999)::text, emp.id, vl_id,
             '2025-03-01'::date + (random()*200)::int,
             '2025-03-01'::date + (random()*200)::int + ceil(random()*3)::int,
             ceil(random()*3), 'Personal matters', 'APPROVED', NOW() - (random() * INTERVAL '300 days')),
            ('LR-' || emp.id || '-SL-' || floor(random()*9999)::text, emp.id, sl_id,
             '2024-06-01'::date + (random()*300)::int,
             '2024-06-01'::date + (random()*300)::int + 1,
             1, 'Medical checkup', 'APPROVED', NOW() - (random() * INTERVAL '400 days'))
        ON CONFLICT DO NOTHING;
    END LOOP;

    -- Maternity
    IF ml_id IS NOT NULL THEN
        INSERT INTO leave_mgmt.lv_requests (reference_no, employee_id, leave_type_id, date_from, date_to, days_requested, reason, status, filed_at)
        SELECT 'LR-ML-2025-022', e.id, ml_id, '2025-06-01', '2025-09-13', 105, 'Maternity Leave under RA 11210', 'APPROVED', '2025-05-15'::timestamp
        FROM core.employees e WHERE e.employee_no = 'EMP-022' ON CONFLICT DO NOTHING;
    END IF;
    -- Paternity
    IF pl_id IS NOT NULL THEN
        INSERT INTO leave_mgmt.lv_requests (reference_no, employee_id, leave_type_id, date_from, date_to, days_requested, reason, status, filed_at)
        SELECT 'LR-PL-2025-025', e.id, pl_id, '2025-06-01', '2025-06-07', 7, 'Paternity Leave', 'APPROVED', '2025-05-28'::timestamp
        FROM core.employees e WHERE e.employee_no = 'EMP-025' ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- Travel orders (correct columns: date_from, date_to)
INSERT INTO leave_mgmt.lv_travel_orders
    (reference_no, employee_id, destination, purpose, date_from, date_to, status, approved_by)
SELECT 'TO-' || e.employee_no || '-' || floor(random()*999)::text, e.id,
    (ARRAY['Manila','Quezon City','Baguio','Cebu','Davao'])[ceil(random()*5)],
    (ARRAY['Training','Conference','Official Business','Site Visit'])[ceil(random()*4)],
    '2025-06-01'::date + (random()*180)::int,
    '2025-06-01'::date + (random()*180)::int + 2,
    'APPROVED',
    (SELECT id FROM core.users WHERE username = 'capsanchez')
FROM core.employees e WHERE e.employee_no IN ('EMP-003','EMP-006','EMP-023','EMP-031','EMP-048')
ON CONFLICT DO NOTHING;


-- ══════════════════════════════════════════════════════════════════
-- 4. PAYROLL: 24 months
-- ══════════════════════════════════════════════════════════════════
DO $$
DECLARE
    co_id BIGINT; period_id BIGINT; run_id BIGINT;
    yr INT; m INT; half INT;
    p_start DATE; p_end DATE; p_label TEXT;
    emp RECORD;
    basic NUMERIC; gross NUMERIC; sss NUMERIC; phil NUMERIC; pag NUMERIC; tax NUMERIC;
BEGIN
    SELECT id INTO co_id FROM core.companies LIMIT 1;
    FOR yr IN 2024..2025 LOOP
        FOR m IN 1..12 LOOP
            FOR half IN 1..2 LOOP
                IF half = 1 THEN
                    p_start := make_date(yr, m, 1); p_end := make_date(yr, m, 15);
                    p_label := yr || '-' || LPAD(m::text, 2, '0') || '-1ST';
                ELSE
                    p_start := make_date(yr, m, 16);
                    p_end := (make_date(yr, m, 1) + INTERVAL '1 month' - INTERVAL '1 day')::date;
                    p_label := yr || '-' || LPAD(m::text, 2, '0') || '-2ND';
                END IF;
                INSERT INTO payroll.pay_periods (company_id, period_code, period_type, date_from, date_to, status)
                VALUES (co_id, p_label, 'SEMI_MONTHLY', p_start, p_end, 'CLOSED')
                ON CONFLICT DO NOTHING RETURNING id INTO period_id;
                IF period_id IS NULL THEN SELECT id INTO period_id FROM payroll.pay_periods WHERE period_code = p_label; END IF;
                IF period_id IS NULL THEN CONTINUE; END IF;

                INSERT INTO payroll.pay_runs (period_id, status, approved_by, approved_at)
                VALUES (period_id, 'COMPLETED',
                    (SELECT id FROM core.users WHERE username = 'capsanchez'), (p_end + TIME '10:00')::timestamp)
                ON CONFLICT DO NOTHING RETURNING id INTO run_id;
                IF run_id IS NULL THEN CONTINUE; END IF;

                FOR emp IN SELECT e.id FROM core.employees e WHERE e.is_active = TRUE AND e.date_hired <= p_end LOOP
                    basic := 15000 + round((random() * 20000)::numeric, 2);
                    sss := round((basic * 0.045)::numeric, 2);
                    phil := round((basic * 0.025)::numeric, 2);
                    pag := round(LEAST(basic * 0.02, 200)::numeric, 2);
                    tax := round(GREATEST((basic - 10417) * 0.15, 0)::numeric, 2);
                    gross := basic;
                    INSERT INTO payroll.pay_employee_payroll
                        (run_id, employee_id, basic_pay, allowances_total, gross_pay,
                         sss_ee, philhealth_ee, pagibig_ee, tax_withheld,
                         loan_deductions, other_deductions, total_deductions, net_pay)
                    VALUES (run_id, emp.id, basic, 0, gross, sss, phil, pag, tax,
                        0, 0, sss+phil+pag+tax, gross-(sss+phil+pag+tax))
                    ON CONFLICT DO NOTHING;
                END LOOP;
            END LOOP;
        END LOOP;
    END LOOP;
END $$;

-- Government remittances (correct columns: total_ee, total_er, total_amount)
INSERT INTO payroll.pay_government_remittances (run_id, agency, total_ee, total_er, total_amount, status)
SELECT pr.id, agency,
    round((random()*50000+10000)::numeric, 2), round((random()*30000+5000)::numeric, 2), round((random()*80000+15000)::numeric, 2), 'REMITTED'
FROM payroll.pay_runs pr
CROSS JOIN (VALUES ('GSIS'),('PAGIBIG'),('BIR'),('PHILHEALTH')) AS a(agency)
WHERE pr.status = 'COMPLETED'
ON CONFLICT DO NOTHING;

-- 13th month (correct columns: total_basic_pay, gross_13th, net_13th)
INSERT INTO payroll.pay_13th_month (employee_id, year, total_basic_pay, months_worked, gross_13th, net_13th)
SELECT e.id, yr, 360000 + round((random()*120000)::numeric, 2), 12,
       (360000 + round((random()*120000)::numeric, 2)) / 12, (360000 + round((random()*120000)::numeric, 2)) / 12
FROM core.employees e CROSS JOIN (VALUES (2024),(2025)) AS y(yr)
WHERE e.is_active = TRUE AND e.date_hired <= make_date(yr, 12, 31)
ON CONFLICT DO NOTHING;

-- Loans (correct columns: principal_amount, outstanding_balance, monthly_deduction, start_date)
DO $$
DECLARE emp RECORD;
BEGIN
    FOR emp IN SELECT id FROM core.employees WHERE is_active = TRUE ORDER BY random() LIMIT 15 LOOP
        INSERT INTO payroll.pay_loans
            (employee_id, loan_type, reference_no, principal_amount, outstanding_balance, monthly_deduction,
             total_months, start_date, status)
        VALUES (emp.id,
            (ARRAY['SALARY','GSIS_POLICY','PAGIBIG_CALAMITY','GSIS_CONSO'])[ceil(random()*4)],
            'LN-' || emp.id || '-' || floor(random()*9999)::text,
            round((20000+random()*80000)::numeric, 2), round((10000+random()*40000)::numeric, 2), round((2000+random()*5000)::numeric, 2),
            24,
            '2025-01-01'::date + (random()*180)::int,
            (ARRAY['ACTIVE','ACTIVE','COMPLETED','ACTIVE'])[ceil(random()*4)]
        ) ON CONFLICT DO NOTHING;
    END LOOP;
END $$;


-- ══════════════════════════════════════════════════════════════════
-- 5. PERFORMANCE: cycles, IPCRs, IDP, succession
-- ══════════════════════════════════════════════════════════════════
DO $$
DECLARE co_id BIGINT; c24_id BIGINT; c25_id BIGINT; c26_id BIGINT; emp RECORD; score NUMERIC; rating TEXT;
BEGIN
    SELECT id INTO co_id FROM core.companies LIMIT 1;

    INSERT INTO performance.perf_cycles (company_id, name, cycle_type, period_from, period_to, status)
    VALUES
        (co_id, '2024 Year-End Review', 'ANNUAL', '2024-01-01', '2024-12-31', 'COMPLETED'),
        (co_id, '2025 Year-End Review', 'ANNUAL', '2025-01-01', '2025-12-31', 'COMPLETED'),
        (co_id, '2026 Mid-Year Review', 'SEMI_ANNUAL', '2026-01-01', '2026-06-30', 'ACTIVE')
    ON CONFLICT DO NOTHING;

    SELECT id INTO c24_id FROM performance.perf_cycles WHERE name = '2024 Year-End Review';
    SELECT id INTO c25_id FROM performance.perf_cycles WHERE name = '2025 Year-End Review';
    SELECT id INTO c26_id FROM performance.perf_cycles WHERE name = '2026 Mid-Year Review';
    IF c24_id IS NULL OR c25_id IS NULL THEN RETURN; END IF;

    -- IPCRs (correct columns: quality_rating, efficiency_rating, timeliness_rating, average_rating)
    FOR emp IN SELECT e.id, e.date_hired FROM core.employees e WHERE e.is_active = TRUE LOOP
        IF emp.date_hired <= '2024-12-31' THEN
            score := 3.0 + round((random() * 2)::numeric, 2);
            rating := CASE WHEN score >= 4.5 THEN 'OUTSTANDING' WHEN score >= 3.5 THEN 'VERY_SATISFACTORY'
                           WHEN score >= 2.5 THEN 'SATISFACTORY' ELSE 'UNSATISFACTORY' END;
            INSERT INTO performance.perf_ipcr (cycle_id, employee_id, performance_indicator, target, quality_rating, efficiency_rating, timeliness_rating, status)
            VALUES (c24_id, emp.id, 'Core functions and deliverables', 'Satisfactory completion', score, score+round((random()*0.3)::numeric,2), score-0.1+round((random()*0.2)::numeric,2), 'APPROVED')
            ON CONFLICT DO NOTHING;
            INSERT INTO performance.perf_ipcr_summary (cycle_id, employee_id, final_numerical_rating, adjectival_rating, pbb_eligible, step_increment_eligible)
            VALUES (c24_id, emp.id, score, rating, score >= 3.5, score >= 3.0)
            ON CONFLICT DO NOTHING;
        END IF;

        IF emp.date_hired <= '2025-12-31' THEN
            score := 3.0 + round((random() * 2)::numeric, 2);
            rating := CASE WHEN score >= 4.5 THEN 'OUTSTANDING' WHEN score >= 3.5 THEN 'VERY_SATISFACTORY'
                           WHEN score >= 2.5 THEN 'SATISFACTORY' ELSE 'UNSATISFACTORY' END;
            INSERT INTO performance.perf_ipcr (cycle_id, employee_id, performance_indicator, target, quality_rating, efficiency_rating, timeliness_rating, status)
            VALUES (c25_id, emp.id, 'Core functions and deliverables', 'Satisfactory completion', score, score+round((random()*0.3)::numeric,2), score-0.1+round((random()*0.2)::numeric,2), 'APPROVED')
            ON CONFLICT DO NOTHING;
            INSERT INTO performance.perf_ipcr_summary (cycle_id, employee_id, final_numerical_rating, adjectival_rating, pbb_eligible, step_increment_eligible)
            VALUES (c25_id, emp.id, score, rating, score >= 3.5, score >= 3.0)
            ON CONFLICT DO NOTHING;
        END IF;

        IF c26_id IS NOT NULL THEN
            INSERT INTO performance.perf_ipcr (cycle_id, employee_id, performance_indicator, target, status)
            VALUES (c26_id, emp.id, 'Core functions and deliverables', 'To be assessed', 'DRAFT') ON CONFLICT DO NOTHING;
        END IF;
    END LOOP;

    -- Succession matrix (correct columns: key_position_id, successor_employee_id, readiness, development_needs)
    INSERT INTO performance.perf_succession_matrix (key_position_id, successor_employee_id, readiness, development_needs, cycle_id)
    SELECT pos_id, suc_id, ready, note, c25_id
    FROM (
        SELECT
            (SELECT position_id FROM core.employees WHERE employee_no = inc LIMIT 1) AS pos_id,
            (SELECT id FROM core.employees WHERE employee_no = suc) AS suc_id,
            ready, note
        FROM (VALUES
            ('EMP-016','EMP-047','READY_NOW','Leadership training'),
            ('EMP-005','EMP-049','READY_1_2YR','Technical certification'),
            ('EMP-011','EMP-051','READY_1_2YR','CPA exam preparation'),
            ('EMP-008','EMP-053','READY_NOW','Operations management course')
        ) AS s(inc, suc, ready, note)
    ) sub
    WHERE pos_id IS NOT NULL AND suc_id IS NOT NULL
    ON CONFLICT DO NOTHING;

    -- IDP plans (correct columns: development_goal, action_steps, target_date)
    INSERT INTO performance.perf_idp_plans (employee_id, cycle_id, development_goal, action_steps, target_date, status)
    SELECT e.id, c25_id,
        (ARRAY['Leadership Skills','Technical Competency','Communication','Project Management'])[ceil(random()*4)],
        'Complete relevant training and apply in daily work',
        '2026-06-30',
        (ARRAY['IN_PROGRESS','COMPLETED','IN_PROGRESS','NOT_STARTED'])[ceil(random()*4)]
    FROM core.employees e WHERE e.is_active = TRUE ORDER BY random() LIMIT 25
    ON CONFLICT DO NOTHING;
END $$;


-- ══════════════════════════════════════════════════════════════════
-- 6. LEARNING: programs, skills, scholarships
-- ══════════════════════════════════════════════════════════════════
DO $$
DECLARE co_id BIGINT;
BEGIN
    SELECT id INTO co_id FROM core.companies LIMIT 1;
    INSERT INTO learning.lrn_programs (company_id, code, title, description, category, delivery_mode, provider, duration_hours, is_mandatory)
    VALUES
        (co_id,'ARTA-101','ARTA Orientation','RA 11032 Anti-Red Tape Act','SEMINAR','CLASSROOM','CSC',8,TRUE),
        (co_id,'GAD-201','GAD Sensitivity Training','Gender and Development awareness','WORKSHOP','CLASSROOM','PCW',16,TRUE),
        (co_id,'PFM-301','Public Financial Management','Government accounting standards','TRAINING','CLASSROOM','COA',40,FALSE),
        (co_id,'CYBER-101','Cybersecurity Awareness','Information security for government','SEMINAR','ONLINE','DICT',8,TRUE),
        (co_id,'ETHICS-101','Public Service Ethics','Code of Conduct for Government','SEMINAR','CLASSROOM','CSC',4,TRUE),
        (co_id,'STRAT-201','Strategic Planning Workshop','Organizational development','WORKSHOP','CLASSROOM','NEDA',24,FALSE),
        (co_id,'EXCEL-201','Advanced Excel for Government','Data analysis and reporting','TRAINING','ONLINE','TESDA',16,FALSE),
        (co_id,'PM-301','Project Management Fundamentals','PM methodology for LGUs','TRAINING','CLASSROOM','DILG',32,FALSE),
        (co_id,'LEAD-401','Leadership Development Program','Supervisory skills','TRAINING','CLASSROOM','DAP',40,FALSE),
        (co_id,'REC-101','Records Management','Document control and archiving','SEMINAR','CLASSROOM','NAP',8,FALSE),
        (co_id,'EMRG-201','Emergency Response Training','Disaster risk reduction','TRAINING','CLASSROOM','OCD',16,TRUE),
        (co_id,'CUST-101','Customer Service Excellence','Frontline service delivery','WORKSHOP','CLASSROOM','CSC',8,TRUE),
        (co_id,'PROC-201','Philippine Bidding Law','Government procurement RA 9184','SEMINAR','CLASSROOM','GPPB',16,FALSE),
        (co_id,'PRIV-101','Data Privacy Act','RA 10173 compliance','SEMINAR','ONLINE','NPC',8,TRUE),
        (co_id,'DIGI-301','Digital Transformation','E-governance strategies','CONFERENCE','ONLINE','DICT',24,FALSE)
    ON CONFLICT DO NOTHING;
END $$;

INSERT INTO learning.lrn_sessions (program_id, session_date, venue, facilitator, max_participants, status)
SELECT p.id, '2024-06-01'::date + (row_number() OVER () * 30)::int,
    (ARRAY['Training Room A','Conference Hall','Online (Zoom)','Municipal Hall'])[ceil(random()*4)],
    (ARRAY['Dir. Santos','Atty. Reyes','Prof. Garcia','Engr. Cruz'])[ceil(random()*4)],
    30, CASE WHEN p.is_active THEN 'COMPLETED' ELSE 'SCHEDULED' END
FROM learning.lrn_programs p ON CONFLICT DO NOTHING;

INSERT INTO learning.lrn_enrollments (session_id, employee_id, status, score)
SELECT s.id, e.id,
    CASE WHEN s.status = 'COMPLETED' THEN 'COMPLETED' ELSE 'ENROLLED' END,
    CASE WHEN s.status = 'COMPLETED' THEN 80+floor(random()*20)::int ELSE NULL END
FROM learning.lrn_sessions s CROSS JOIN core.employees e
WHERE e.is_active = TRUE AND random() < 0.25
ON CONFLICT DO NOTHING;

DO $$
DECLARE co_id BIGINT;
BEGIN
    SELECT id INTO co_id FROM core.companies LIMIT 1;
    INSERT INTO learning.lrn_skills (company_id, code, name, category)
    VALUES
        (co_id,'LEAD','Leadership','MANAGEMENT'), (co_id,'COMM','Communication','SOFT'),
        (co_id,'ANAL','Data Analysis','TECHNICAL'), (co_id,'PROJ','Project Mgmt','MANAGEMENT'),
        (co_id,'ACCT','Gov Accounting','TECHNICAL'), (co_id,'PROC','Procurement','TECHNICAL'),
        (co_id,'ITSK','IT Skills','TECHNICAL'), (co_id,'CUST','Customer Service','SOFT'),
        (co_id,'WRIT','Technical Writing','SOFT'), (co_id,'PLAN','Strategic Planning','MANAGEMENT'),
        (co_id,'BUDG','Budget Mgmt','TECHNICAL'), (co_id,'HRMS','HR Management','TECHNICAL'),
        (co_id,'LGOV','Local Governance','DOMAIN'), (co_id,'EMRG','Emergency Response','TECHNICAL'),
        (co_id,'GAD_S','Gender Sensitivity','SOFT'), (co_id,'PRIV','Data Privacy','TECHNICAL'),
        (co_id,'DIGI','Digital Literacy','TECHNICAL'), (co_id,'NEGO','Negotiation','SOFT'),
        (co_id,'PRES','Presentation','SOFT'), (co_id,'RSCH','Research','TECHNICAL')
    ON CONFLICT DO NOTHING;
END $$;

INSERT INTO learning.lrn_employee_skills (employee_id, skill_id, proficiency, assessed_on)
SELECT e.id, s.id, (ARRAY['BEGINNER','INTERMEDIATE','ADVANCED','EXPERT'])[ceil(random()*4)],
    '2025-01-01'::date + (random()*365)::int
FROM core.employees e CROSS JOIN learning.lrn_skills s
WHERE e.is_active = TRUE AND random() < 0.25
ON CONFLICT DO NOTHING;

-- Scholarships (correct columns: grant_type, course, coverage_details, bond_required_months, return_of_service_date)
INSERT INTO learning.lrn_scholarships (employee_id, program_name, grant_type, institution, course, start_date, end_date, bond_required_months, status)
VALUES
    ((SELECT id FROM core.employees WHERE employee_no = 'EMP-046'), 'MPA Program', 'LOCAL', 'UP NCPAG', 'Master in Public Administration', '2024-06-01', '2026-05-31', 24, 'ACTIVE'),
    ((SELECT id FROM core.employees WHERE employee_no = 'EMP-048'), 'MSIT Program', 'CSC_SPONSORED', 'PUP', 'MS Information Technology', '2025-01-15', '2026-12-31', 18, 'ACTIVE'),
    ((SELECT id FROM core.employees WHERE employee_no = 'EMP-033'), 'DLG Program', 'LOCAL', 'CLSU', 'Diploma in Local Governance', '2023-06-01', '2024-05-31', 12, 'COMPLETED')
ON CONFLICT DO NOTHING;


-- ══════════════════════════════════════════════════════════════════
-- 7. REWARDS
-- ══════════════════════════════════════════════════════════════════

-- Step increments (correct columns: current_sg, current_step, next_step, last_increment_date, next_increment_due, eligibility_status)
INSERT INTO rewards.rwd_step_increments (employee_id, current_sg, current_step, next_step, last_increment_date, eligibility_status)
SELECT e.id, (10+floor(random()*10))::int,
    floor(random()*4+1)::int, floor(random()*4+2)::int,
    make_date(yr, 1, 1),
    'ELIGIBLE'
FROM core.employees e CROSS JOIN (VALUES (2024),(2025)) AS y(yr)
WHERE e.is_active = TRUE AND e.date_hired <= make_date(yr, 1, 1) AND random() < 0.5
ON CONFLICT DO NOTHING;

-- Loyalty milestones (correct columns: service_years, award_type, eligibility_date, status)
INSERT INTO rewards.rwd_loyalty_milestones (employee_id, service_years, award_type, eligibility_date, status)
VALUES
    ((SELECT id FROM core.employees WHERE employee_no = 'EMP-059'), 15, 'PLAQUE', '2025-01-10', 'AWARDED'),
    ((SELECT id FROM core.employees WHERE employee_no = 'EMP-053'), 5, 'CASH_GIFT', '2026-03-15', 'AWARDED'),
    ((SELECT id FROM core.employees WHERE employee_no = 'EMP-047'), 5, 'COMBINATION', '2024-06-01', 'AWARDED'),
    ((SELECT id FROM core.employees WHERE employee_no = 'EMP-049'), 5, 'PLAQUE', '2024-08-15', 'AWARDED')
ON CONFLICT DO NOTHING;

-- PBB records (correct columns: ipcr_adjectival, pbb_tier, pbb_amount)
INSERT INTO rewards.rwd_pbb_records (employee_id, year, ipcr_summary_id, ipcr_adjectival, pbb_tier, pbb_amount, status)
SELECT e.id, EXTRACT(YEAR FROM pc.period_from)::int, ips.id, ips.adjectival_rating,
    CASE WHEN ips.final_numerical_rating >= 4.5 THEN 'TIER_1' WHEN ips.final_numerical_rating >= 3.5 THEN 'TIER_2' ELSE 'TIER_3' END,
    CASE WHEN ips.final_numerical_rating >= 4.5 THEN 65000 WHEN ips.final_numerical_rating >= 3.5 THEN 57500 ELSE 50000 END,
    'RELEASED'
FROM core.employees e
JOIN performance.perf_ipcr_summary ips ON ips.employee_id = e.id
JOIN performance.perf_cycles pc ON pc.id = ips.cycle_id
WHERE EXTRACT(YEAR FROM pc.period_from) IN (2024, 2025)
ON CONFLICT DO NOTHING;

-- Retirement alerts (correct columns: retirement_age, projected_retirement_date, alert_type)
INSERT INTO rewards.rwd_retirement_alerts (employee_id, retirement_age, projected_retirement_date, alert_type, scheduled_send_date)
VALUES
    ((SELECT id FROM core.employees WHERE employee_no = 'EMP-045'), 60, '2026-04-30', '6MO_NOTICE', '2025-10-30'),
    ((SELECT id FROM core.employees WHERE employee_no = 'EMP-059'), 65, '2028-08-15', 'AGE_65_NOTICE', '2028-02-15')
ON CONFLICT DO NOTHING;

-- PRAISE nominations (correct columns: category_id, nominee_employee_id, nominated_by, period_year, period_quarter, justification)
DO $$
DECLARE cat_id BIGINT;
BEGIN
    SELECT id INTO cat_id FROM rewards.rwd_categories LIMIT 1;
    IF cat_id IS NULL THEN RETURN; END IF;
    INSERT INTO rewards.rwd_nominations (category_id, nominee_employee_id, nominated_by, period_year, period_quarter, justification, status)
    SELECT cat_id, e.id, (SELECT id FROM core.employees WHERE employee_no = 'EMP-016'),
        (ARRAY[2024,2025])[ceil(random()*2)], ceil(random()*4)::int,
        'Demonstrated exceptional performance.', 'APPROVED'
    FROM core.employees e WHERE e.is_active = TRUE ORDER BY random() LIMIT 15
    ON CONFLICT DO NOTHING;
END $$;


-- ══════════════════════════════════════════════════════════════════
-- 8. RECRUITMENT
-- ══════════════════════════════════════════════════════════════════
DO $$
DECLARE co_id BIGINT;
BEGIN
    SELECT id INTO co_id FROM core.companies LIMIT 1;
    -- Plantilla items
    INSERT INTO recruitment.rec_plantilla_items (company_id, department_id, position_id, item_number, salary_grade, status)
    SELECT co_id, e.department_id, e.position_id,
        'PI-' || LPAD(e.id::text, 4, '0'), (10+floor(random()*15))::int,
        CASE WHEN e.is_active THEN 'FILLED' ELSE 'VACANT' END
    FROM core.employees e WHERE e.position_id IS NOT NULL
    ON CONFLICT DO NOTHING;

    -- Requisitions (correct columns: reference_no, headcount, justification, target_hire_date)
    INSERT INTO recruitment.rec_requisitions (company_id, reference_no, department_id, position_id, headcount, justification, status, requested_by, target_hire_date)
    SELECT co_id, 'REQ-2025-' || LPAD(row_number() OVER ()::text, 3, '0'),
        d.id, p.id, 1, 'Position vacancy due to expansion',
        (ARRAY['APPROVED','POSTED','FILLED'])[ceil(random()*3)],
        (SELECT id FROM core.users WHERE username = 'capsanchez'),
        '2025-06-01'::date + (random()*180)::int
    FROM core.departments d CROSS JOIN core.positions p
    WHERE random() < 0.1
    ON CONFLICT DO NOTHING;

    -- Job postings (correct columns: requisition_id, title, description, posted_on, closed_on)
    INSERT INTO recruitment.rec_job_postings (requisition_id, title, description, posted_on, closed_on, status)
    SELECT r.id, 'Hiring: ' || p.title, 'We are looking for a qualified ' || p.title,
        '2025-03-01'::date + (random()*200)::int,
        '2025-03-01'::date + (random()*200)::int + 30,
        (ARRAY['OPEN','CLOSED','FILLED'])[ceil(random()*3)]
    FROM recruitment.rec_requisitions r
    JOIN core.positions p ON p.id = r.position_id
    WHERE r.status IN ('APPROVED','POSTED','FILLED')
    ON CONFLICT DO NOTHING;

    -- PSB members (correct columns: company_id, member_employee_id, role, effective_from)
    INSERT INTO recruitment.rec_psb_members (company_id, member_employee_id, role, effective_from)
    SELECT co_id, e.id,
        (ARRAY['CHAIR','MEMBER','MEMBER','HR_REP','OBSERVER'])[row_number() OVER ()],
        '2024-01-01'
    FROM core.employees e WHERE e.employee_no IN ('EMP-016','EMP-001','EMP-005','EMP-047','EMP-021')
    ON CONFLICT DO NOTHING;
END $$;

-- Applicants (correct columns: stage)
INSERT INTO recruitment.rec_applicants (posting_id, first_name, last_name, email, mobile_no, stage, source)
SELECT jp.id,
    (ARRAY['Juan','Pedro','Maria','Jose','Anna','Carlo','Diana','Miguel','Sofia','Luis',
           'Rosa','Andres','Elena','Marco','Teresa','Ramon','Grace','Felix','Linda','Oscar'])[i],
    (ARRAY['Dela Cruz','Reyes','Santos','Garcia','Mendoza','Bautista','Aquino','Torres','Rivera','Flores',
           'Gonzales','Castro','Lopez','Pascual','Ramos','Diaz','Navarro','Romero','Morales','Herrera'])[i],
    'applicant' || i || '@email.com', '0917100' || LPAD(i::text, 4, '0'),
    (ARRAY['NEW','SCREENING','SHORTLISTED','INTERVIEWED','OFFERED','HIRED','REJECTED'])[ceil(random()*7)],
    (ARRAY['CSC_WEBSITE','REFERRAL','WALK_IN','ONLINE'])[ceil(random()*4)]
FROM (SELECT id FROM recruitment.rec_job_postings ORDER BY random() LIMIT 1) jp
CROSS JOIN generate_series(1, 20) AS i
ON CONFLICT DO NOTHING;


-- ══════════════════════════════════════════════════════════════════
-- 9. DISCIPLINE: 6 cases
-- ══════════════════════════════════════════════════════════════════
DO $$
DECLARE co_id BIGINT; case_id BIGINT; ct_id BIGINT; cap_id BIGINT; dec_id BIGINT;
BEGIN
    SELECT id INTO co_id FROM core.companies LIMIT 1;
    SELECT id INTO cap_id FROM core.users WHERE username = 'capsanchez';
    SELECT id INTO ct_id FROM discipline.case_types LIMIT 1;

    -- Case 1: DECIDED (Reprimand)
    INSERT INTO discipline.cases (company_id, case_no, respondent_id, case_type_id, offense_description, date_filed, gravity, status, created_by)
    VALUES (co_id, 'DISC-2024-001', (SELECT id FROM core.employees WHERE employee_no = 'EMP-010'),
        ct_id, 'Habitual Tardiness - 10 instances in Q2 2024', '2024-08-15', 'LIGHT', 'DECISION', cap_id)
    ON CONFLICT DO NOTHING RETURNING id INTO case_id;
    IF case_id IS NOT NULL THEN
        INSERT INTO discipline.investigations (case_id, investigator_id, findings, started_at, completed_at, recommendation)
        VALUES (case_id, cap_id, 'Pattern confirmed by DTR records.', '2024-08-20', '2024-09-05', 'PROCEED_FORMAL_CHARGE') ON CONFLICT DO NOTHING;
        INSERT INTO discipline.formal_charges (case_id, charge_text, charge_date, answer_deadline, issued_by)
        VALUES (case_id, 'Habitual Tardiness per CSC MC No. 23', '2024-09-10', '2024-09-25', cap_id) ON CONFLICT DO NOTHING;
        INSERT INTO discipline.decisions (case_id, verdict, penalty, decision_date, decided_by, decision_text)
        VALUES (case_id, 'GUILTY', 'REPRIMAND', '2024-10-15', cap_id, 'First offense. Written reprimand with warning.') ON CONFLICT DO NOTHING;
    END IF;

    -- Case 2: DECIDED (15-day suspension)
    INSERT INTO discipline.cases (company_id, case_no, respondent_id, case_type_id, offense_description, date_filed, gravity, status, created_by)
    VALUES (co_id, 'DISC-2025-001', (SELECT id FROM core.employees WHERE employee_no = 'EMP-027'),
        ct_id, 'Insubordination - Refused lawful order from supervisor', '2025-03-01', 'LESS_GRAVE', 'DECISION', cap_id)
    ON CONFLICT DO NOTHING RETURNING id INTO case_id;
    IF case_id IS NOT NULL THEN
        INSERT INTO discipline.investigations (case_id, investigator_id, findings, started_at, completed_at, recommendation)
        VALUES (case_id, cap_id, 'Witness statements corroborate refusal.', '2025-03-05', '2025-03-25', 'PROCEED_FORMAL_CHARGE') ON CONFLICT DO NOTHING;
        INSERT INTO discipline.formal_charges (case_id, charge_text, charge_date, answer_deadline, issued_by)
        VALUES (case_id, 'Insubordination - Refusal to follow lawful order', '2025-04-01', '2025-04-16', cap_id) ON CONFLICT DO NOTHING;
        INSERT INTO discipline.hearings (case_id, hearing_type, scheduled_date, venue, status)
        VALUES (case_id, 'FORMAL', '2025-04-20', 'Municipal Hall', 'COMPLETED') ON CONFLICT DO NOTHING;
        INSERT INTO discipline.decisions (case_id, verdict, penalty, suspension_days, decision_date, decided_by, effectivity_date, decision_text)
        VALUES (case_id, 'GUILTY', '15_DAY_SUSPENSION', 15, '2025-05-15', cap_id, '2025-06-01', '15-day suspension without pay. Second offense.') ON CONFLICT DO NOTHING;
    END IF;

    -- Case 3: Under HEARING (Grave)
    INSERT INTO discipline.cases (company_id, case_no, respondent_id, case_type_id, offense_description, date_filed, gravity, status, created_by)
    VALUES (co_id, 'DISC-2025-002', (SELECT id FROM core.employees WHERE employee_no = 'EMP-033'),
        ct_id, 'Dishonesty - Falsification of official document', '2025-07-10', 'GRAVE', 'HEARING', cap_id)
    ON CONFLICT DO NOTHING RETURNING id INTO case_id;
    IF case_id IS NOT NULL THEN
        INSERT INTO discipline.investigations (case_id, investigator_id, findings, started_at, completed_at, recommendation)
        VALUES (case_id, cap_id, 'Discrepancy found in submitted documents.', '2025-07-15', '2025-08-15', 'PROCEED_FORMAL_CHARGE') ON CONFLICT DO NOTHING;
        INSERT INTO discipline.formal_charges (case_id, charge_text, charge_date, answer_deadline, issued_by)
        VALUES (case_id, 'Dishonesty - Falsification of official document', '2025-08-20', '2025-09-05', cap_id) ON CONFLICT DO NOTHING;
        INSERT INTO discipline.hearings (case_id, hearing_type, scheduled_date, venue, status)
        VALUES (case_id, 'FORMAL', '2025-09-15', 'Municipal Hall', 'SCHEDULED') ON CONFLICT DO NOTHING;
    END IF;

    -- Case 4: Under INVESTIGATION
    INSERT INTO discipline.cases (company_id, case_no, respondent_id, case_type_id, offense_description, date_filed, gravity, status, created_by)
    VALUES (co_id, 'DISC-2025-003', (SELECT id FROM core.employees WHERE employee_no = 'EMP-057'),
        ct_id, 'Frequent unauthorized absences', '2025-11-01', 'LESS_GRAVE', 'PRELIMINARY_INVESTIGATION', cap_id)
    ON CONFLICT DO NOTHING RETURNING id INTO case_id;
    IF case_id IS NOT NULL THEN
        INSERT INTO discipline.investigations (case_id, investigator_id, started_at)
        VALUES (case_id, cap_id, '2025-11-05') ON CONFLICT DO NOTHING;
    END IF;

    -- Case 5: DISMISSED
    INSERT INTO discipline.cases (company_id, case_no, respondent_id, case_type_id, offense_description, date_filed, gravity, status, created_by)
    VALUES (co_id, 'DISC-2024-002', (SELECT id FROM core.employees WHERE employee_no = 'EMP-003'),
        ct_id, 'Discourtesy - insufficient evidence', '2024-05-10', 'LIGHT', 'DISMISSED', cap_id)
    ON CONFLICT DO NOTHING RETURNING id INTO case_id;
    IF case_id IS NOT NULL THEN
        INSERT INTO discipline.decisions (case_id, verdict, decision_date, decided_by, decision_text)
        VALUES (case_id, 'DISMISSED', '2024-06-30', cap_id, 'Case dismissed for lack of substantial evidence.') ON CONFLICT DO NOTHING;
    END IF;

    -- Case 6: With APPEAL
    INSERT INTO discipline.cases (company_id, case_no, respondent_id, case_type_id, offense_description, date_filed, gravity, status, created_by)
    VALUES (co_id, 'DISC-2024-003', (SELECT id FROM core.employees WHERE employee_no = 'EMP-015'),
        ct_id, 'Simple Neglect of Duty', '2024-09-01', 'LESS_GRAVE', 'APPEAL', cap_id)
    ON CONFLICT DO NOTHING RETURNING id INTO case_id;
    IF case_id IS NOT NULL THEN
        INSERT INTO discipline.decisions (case_id, verdict, penalty, suspension_days, decision_date, decided_by, effectivity_date, decision_text)
        VALUES (case_id, 'GUILTY', '30_DAY_SUSPENSION', 30, '2024-11-30', cap_id, '2025-01-02', 'Simple Neglect of Duty. 30-day suspension.')
        ON CONFLICT DO NOTHING RETURNING id INTO dec_id;
        IF dec_id IS NOT NULL THEN
            INSERT INTO discipline.appeals (case_id, decision_id, appeal_date, appeal_body, grounds, status, filed_by)
            VALUES (case_id, dec_id, '2024-12-15', 'CSC_REGIONAL', 'Penalty is disproportionate.', 'FILED', cap_id) ON CONFLICT DO NOTHING;
        END IF;
    END IF;
END $$;


-- ══════════════════════════════════════════════════════════════════
-- 10. HEALTH: PE, incidents, certificates, wellness
-- ══════════════════════════════════════════════════════════════════
DO $$
DECLARE co_id BIGINT; cap_id BIGINT;
BEGIN
    SELECT id INTO co_id FROM core.companies LIMIT 1;
    SELECT id INTO cap_id FROM core.users WHERE username = 'capsanchez';

    -- PE schedules (correct columns: scheduled_from, scheduled_to, provider_name)
    INSERT INTO health.pe_schedules (company_id, year, title, provider_name, scheduled_from, scheduled_to, status, created_by)
    VALUES
        (co_id, 2024, '2024 Annual PE', 'Municipal Health Office', '2024-03-01', '2024-03-31', 'COMPLETED', cap_id),
        (co_id, 2025, '2025 Annual PE', 'Municipal Health Office', '2025-03-01', '2025-03-31', 'COMPLETED', cap_id),
        (co_id, 2026, '2026 Annual PE', 'Municipal Health Office', '2026-03-01', '2026-03-31', 'SCHEDULED', cap_id)
    ON CONFLICT DO NOTHING;

    -- PE results (correct columns: overall_result, findings, examining_physician)
    INSERT INTO health.pe_results (schedule_id, employee_id, exam_date, overall_result, findings, examining_physician)
    SELECT ps.id, e.id, ps.scheduled_from + (random()*28)::int,
        (ARRAY['FIT','FIT','FIT','CONDITIONAL','UNFIT'])[ceil(random()*5)],
        CASE WHEN random() < 0.2 THEN 'Follow-up recommended' ELSE 'No significant findings' END,
        'Dr. Santos'
    FROM health.pe_schedules ps CROSS JOIN core.employees e
    WHERE e.is_active = TRUE AND e.date_hired <= ps.scheduled_to AND ps.status = 'COMPLETED'
    ON CONFLICT DO NOTHING;

    -- Incidents (correct columns: company_id, incident_no, reported_by, reported_at)
    INSERT INTO health.incidents (company_id, incident_no, incident_date, location, incident_type, severity, description, reported_by, reported_at, status)
    VALUES
        (co_id, 'INC-2024-001', '2024-07-15', 'Ground Floor', 'INJURY', 'MINOR', 'Employee slipped on wet floor.', cap_id, '2024-07-15 09:00', 'CLOSED'),
        (co_id, 'INC-2024-002', '2024-11-20', 'IT Server Room', 'PROPERTY_DAMAGE', 'MODERATE', 'Minor electric shock from faulty outlet.', cap_id, '2024-11-20 14:00', 'CLOSED'),
        (co_id, 'INC-2025-001', '2025-02-10', 'Parking Area', 'PROPERTY_DAMAGE', 'MINOR', 'Fender bender. No injuries.', cap_id, '2025-02-10 08:00', 'CLOSED'),
        (co_id, 'INC-2025-002', '2025-08-05', 'Workshop', 'INJURY', 'MAJOR', 'Paper cutter incident. Required stitches.', cap_id, '2025-08-05 11:00', 'CLOSED'),
        (co_id, 'INC-2026-001', '2026-01-22', '2nd Floor', 'ILLNESS', 'MINOR', 'Repetitive strain from data encoding.', cap_id, '2026-01-22 15:00', 'REPORTED')
    ON CONFLICT DO NOTHING;

    -- Wellness programs (correct columns: company_id, name, provider)
    INSERT INTO health.wellness_programs (company_id, name, description, program_type, start_date, end_date, status, created_by)
    VALUES
        (co_id, 'Stress Management Workshop', 'Managing workplace stress', 'MENTAL_HEALTH', '2025-05-01', '2025-05-02', 'COMPLETED', cap_id),
        (co_id, 'Fitness Challenge 2025', '30-day fitness tracking', 'FITNESS', '2025-09-01', '2025-09-30', 'COMPLETED', cap_id)
    ON CONFLICT DO NOTHING;
END $$;

-- Health certificates
INSERT INTO health.health_certificates (employee_id, certificate_type, issued_date, expiry_date, issuing_authority, status)
SELECT e.id, (ARRAY['MEDICAL_CLEARANCE','DRUG_TEST','FITNESS_CERTIFICATE','MENTAL_HEALTH'])[ceil(random()*4)],
    '2024-06-01'::date + (random()*365)::int,
    '2024-06-01'::date + (random()*365)::int + 365,
    'Municipal Health Office',
    CASE WHEN random() < 0.3 THEN 'EXPIRED' ELSE 'ACTIVE' END
FROM core.employees e WHERE e.is_active = TRUE ORDER BY random() LIMIT 20
ON CONFLICT DO NOTHING;

-- Wellness enrollments
INSERT INTO health.wellness_enrollments (program_id, employee_id, status)
SELECT wp.id, e.id, 'COMPLETED'
FROM health.wellness_programs wp CROSS JOIN core.employees e
WHERE e.is_active = TRUE AND random() < 0.35
ON CONFLICT DO NOTHING;


-- ══════════════════════════════════════════════════════════════════
-- 11. DMS: documents, certificates
-- ══════════════════════════════════════════════════════════════════
DO $$
DECLARE co_id BIGINT;
BEGIN
    SELECT id INTO co_id FROM core.companies LIMIT 1;
    INSERT INTO dms.document_requests (company_id, employee_id, document_type, status, requested_by)
    SELECT co_id, e.id, dc.name, 'SUBMITTED', (SELECT id FROM core.users WHERE username = 'capsanchez')
    FROM core.employees e CROSS JOIN dms.document_categories dc
    WHERE e.is_active = TRUE
    ON CONFLICT DO NOTHING;
END $$;

INSERT INTO dms.certificate_requests (employee_id, cert_type_id, purpose, status, requested_at, processed_by, processed_at)
SELECT e.id, ct.id,
    (ARRAY['Employment','Bank loan','Visa application','Government transaction'])[ceil(random()*4)],
    (ARRAY['RELEASED','RELEASED','PROCESSING'])[ceil(random()*3)],
    NOW() - (random() * INTERVAL '180 days'),
    (SELECT id FROM core.users WHERE username = 'capsanchez'),
    NOW() - (random() * INTERVAL '90 days')
FROM core.employees e CROSS JOIN dms.certificate_types ct
WHERE e.is_active = TRUE AND random() < 0.12
ON CONFLICT DO NOTHING;


-- ══════════════════════════════════════════════════════════════════
-- 12. ONBOARDING
-- ══════════════════════════════════════════════════════════════════
INSERT INTO onboarding.onb_checklists (employee_id, type, status, target_date, completed_at)
SELECT e.id, 'ONBOARDING',
    CASE WHEN e.date_hired < '2025-06-01' THEN 'COMPLETED' ELSE 'IN_PROGRESS' END,
    (e.date_hired + 30)::date,
    CASE WHEN e.date_hired < '2025-06-01' THEN (e.date_hired + 30)::timestamp ELSE NULL END
FROM core.employees e WHERE e.date_hired >= '2024-01-01'
ON CONFLICT DO NOTHING;

INSERT INTO onboarding.onb_pre_employment_reqs (employee_id, requirement_type, submitted_at, document_path)
SELECT e.id, req,
    CASE WHEN e.date_hired < '2025-06-01' THEN (e.date_hired + floor(random()*20)::int)::timestamp ELSE NULL END,
    CASE WHEN e.date_hired < '2025-06-01' THEN '/uploads/201/' || e.employee_no || '/' || req || '.pdf' ELSE NULL END
FROM core.employees e
CROSS JOIN (VALUES ('NBI_CLEARANCE'),('MEDICAL_CERT'),('BIRTH_CERT'),('TOR'),('PDS_CS9'),('OATHS')) AS r(req)
WHERE e.date_hired >= '2024-01-01'
ON CONFLICT DO NOTHING;

INSERT INTO onboarding.onb_buddy_assignments (employee_id, buddy_id, assigned_from)
SELECT (SELECT id FROM core.employees WHERE employee_no = new_emp),
       (SELECT id FROM core.employees WHERE employee_no = buddy),
       (SELECT date_hired FROM core.employees WHERE employee_no = new_emp)
FROM (VALUES ('EMP-046','EMP-001'),('EMP-048','EMP-005'),('EMP-050','EMP-011'),
             ('EMP-052','EMP-008'),('EMP-054','EMP-014'),('EMP-057','EMP-035')) AS b(new_emp, buddy)
ON CONFLICT DO NOTHING;


-- ══════════════════════════════════════════════════════════════════
-- 13. NOTIFICATIONS
-- ══════════════════════════════════════════════════════════════════
INSERT INTO notifications.ntf_in_app (user_id, title, body, action_url, is_read, created_at)
SELECT u.id, title, msg, lnk, random() < 0.6, NOW() - (random() * INTERVAL '90 days')
FROM core.users u
CROSS JOIN (VALUES
    ('Leave Approved','Your vacation leave has been approved.','/me/leaves'),
    ('Payslip Available','Your payslip for the latest cutoff is ready.','/me/payslips'),
    ('Training Reminder','You are enrolled in ARTA Orientation tomorrow.','/ld/programs'),
    ('IPCR Due','Please submit your IPCR for the current cycle.','/pm/ipcr'),
    ('Document Ready','Your employment certificate is ready.','/me/certificates')
) AS n(title, msg, lnk)
WHERE u.is_active = TRUE AND random() < 0.3
ON CONFLICT DO NOTHING;


-- ══════════════════════════════════════════════════════════════════
-- 14. ACCESS MATRIX: Grant page access for all roles
-- ══════════════════════════════════════════════════════════════════
DO $$
DECLARE p TEXT;
BEGIN
    -- EMPLOYEE self-service pages
    FOR p IN SELECT unnest(ARRAY[
        '/me','/me/attendance','/me/leaves','/me/payslips','/me/certificates',
        '/','/search',
        '/leave','/leave/requests','/leave/balances','/leave/locator','/leave/travel-orders',
        '/attendance/overtime','/payroll/loans','/workflow','/orgchart/',
        '/dms/','/dms/checklist','/dms/requests',
        '/health/','/health/wellness',
        '/ld/programs','/ld/sessions',
        '/rr/nominations','/ai/assistant','/pm/ipcr'
    ]) LOOP
        UPDATE core.role_page_access SET can_access = TRUE
        WHERE role_code = 'EMPLOYEE'
          AND page_id = (SELECT id FROM core.page_registry WHERE path = p);
    END LOOP;

    -- HR_ADMIN + MANAGER: all operational pages
    FOR p IN SELECT unnest(ARRAY[
        '/me','/me/attendance','/me/leaves','/me/payslips','/me/certificates',
        '/','/employees','/search',
        '/leave','/leave/requests','/leave/balances','/leave/locator','/leave/travel-orders','/leave/cto',
        '/attendance/dtr','/attendance/overtime','/attendance/alerts','/attendance/shifts','/attendance/shift-assignments',
        '/payroll','/payroll/loans','/workflow','/orgchart/','/my-team','/employees/',
        '/dms/','/dms/certificate-requests','/dms/checklist','/dms/requests','/dms/retention',
        '/health/','/health/certificates','/health/incidents','/health/pe','/health/wellness',
        '/ld/attendance','/ld/narrative-reports','/ld/programs','/ld/scholarships','/ld/sessions','/ld/tna',
        '/pm/cycles','/pm/ipcr','/pm/opcr','/pm/ratings','/pm/succession',
        '/rr/loyalty','/rr/nominations','/rr/pbb','/rr/retirement-notices','/rr/ssl-table','/rr/step-increments',
        '/rsp/applicants','/rsp/appointments','/rsp/next-in-rank','/rsp/offboarding','/rsp/onboarding',
        '/rsp/plantilla','/rsp/psb','/rsp/vacancies',
        '/discipline/','/discipline/cases/new',
        '/reports','/reports/builder','/reports/demographics','/reports/headcount','/reports/saved','/reports/scheduled',
        '/ai/assistant','/ai/executive'
    ]) LOOP
        UPDATE core.role_page_access SET can_access = TRUE
        WHERE role_code IN ('HR_ADMIN','MANAGER')
          AND page_id = (SELECT id FROM core.page_registry WHERE path = p);
    END LOOP;

    -- EXECUTIVE: read-only dashboards + self-service
    FOR p IN SELECT unnest(ARRAY[
        '/','/employees','/search','/me','/me/attendance','/me/leaves','/me/payslips','/me/certificates',
        '/leave','/leave/requests','/leave/balances','/leave/locator','/leave/travel-orders',
        '/attendance/dtr','/attendance/overtime','/attendance/alerts',
        '/workflow','/orgchart/','/my-team','/dms/','/dms/checklist','/dms/requests',
        '/health/','/health/wellness','/ld/programs','/ld/sessions',
        '/pm/cycles','/pm/ipcr','/pm/opcr','/pm/ratings',
        '/rr/nominations','/rr/loyalty','/rr/pbb',
        '/reports','/reports/demographics','/reports/headcount',
        '/ai/assistant','/ai/executive'
    ]) LOOP
        UPDATE core.role_page_access SET can_access = TRUE
        WHERE role_code = 'EXECUTIVE'
          AND page_id = (SELECT id FROM core.page_registry WHERE path = p);
    END LOOP;
END $$;
