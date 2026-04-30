-- ================================================================
-- HCM360 HRIS — 26: PHASE 2 VIEWS
-- Convenience views for reporting and dashboards
-- ================================================================

-- ----------------------------------------------------------------
-- IPCR Summary with employee details
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW performance.v_ipcr_summary AS
SELECT
    s.id, s.employee_id, s.cycle_id,
    s.final_numerical_rating, s.adjectival_rating,
    s.pbb_eligible, s.step_increment_eligible,
    s.approved_at,
    e.first_name || ' ' || e.last_name AS employee_name,
    e.employee_no,
    d.name AS department_name,
    p.title AS position_title,
    c.name AS cycle_name,
    c.period_from, c.period_to
FROM performance.perf_ipcr_summary s
JOIN core.employees e ON e.id = s.employee_id
LEFT JOIN core.departments d ON d.id = e.department_id
LEFT JOIN core.positions p ON p.id = e.position_id
JOIN performance.perf_cycles c ON c.id = s.cycle_id;

-- ----------------------------------------------------------------
-- Next-in-Rank with qualifications
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW recruitment.v_next_in_rank AS
SELECT
    nir.id, nir.position_id, nir.employee_id,
    nir.qualification_met, nir.rank,
    nir.assessed_on, nir.notified_at,
    pos.title AS position_title,
    jg_pos.grade_level AS target_sg,
    e.first_name || ' ' || e.last_name AS employee_name,
    jg_emp.grade_level AS current_sg,
    et.code AS employment_type,
    d.name AS department_name
FROM recruitment.rec_next_in_rank_list nir
JOIN core.positions pos ON pos.id = nir.position_id
JOIN core.employees e ON e.id = nir.employee_id
LEFT JOIN core.departments d ON d.id = e.department_id
LEFT JOIN core.job_grades jg_pos ON jg_pos.id = pos.job_grade_id
LEFT JOIN core.job_grades jg_emp ON jg_emp.id = e.job_grade_id
LEFT JOIN core.employment_types et ON et.id = e.employment_type_id
WHERE nir.is_active = TRUE;

-- ----------------------------------------------------------------
-- Step Increment Due list
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW rewards.v_step_increment_due AS
SELECT
    si.id, si.employee_id,
    si.current_sg, si.current_step, si.next_step,
    si.last_increment_date, si.next_increment_due,
    si.eligibility_status,
    e.first_name || ' ' || e.last_name AS employee_name,
    d.name AS department_name,
    ssl_curr.monthly_rate AS current_rate,
    ssl_next.monthly_rate AS next_rate,
    COALESCE(ssl_next.monthly_rate, 0) - COALESCE(ssl_curr.monthly_rate, 0) AS increment_amount
FROM rewards.rwd_step_increments si
JOIN core.employees e ON e.id = si.employee_id
LEFT JOIN core.departments d ON d.id = e.department_id
LEFT JOIN rewards.rwd_ssl_table ssl_curr
    ON ssl_curr.salary_grade = si.current_sg AND ssl_curr.step_no = si.current_step
LEFT JOIN rewards.rwd_ssl_table ssl_next
    ON ssl_next.salary_grade = si.current_sg AND ssl_next.step_no = si.next_step
WHERE si.eligibility_status IN ('ELIGIBLE', 'PENDING_RATING');

-- ----------------------------------------------------------------
-- Retirement Notices with employee details
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW rewards.v_retirement_notices AS
SELECT
    ra.id, ra.employee_id,
    ra.retirement_age, ra.projected_retirement_date,
    ra.alert_type, ra.scheduled_send_date, ra.sent_at,
    e.first_name || ' ' || e.last_name AS employee_name,
    e.date_of_birth AS birth_date,
    d.name AS department_name,
    pos.title AS position_title,
    ra.projected_retirement_date - CURRENT_DATE AS days_until_retirement
FROM rewards.rwd_retirement_alerts ra
JOIN core.employees e ON e.id = ra.employee_id
LEFT JOIN core.departments d ON d.id = e.department_id
LEFT JOIN core.positions pos ON pos.id = e.position_id;

-- ----------------------------------------------------------------
-- Government Payroll Summary per run
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW payroll.v_gov_payroll_summary AS
SELECT
    ep.run_id,
    COUNT(ep.id) AS employee_count,
    SUM(ep.basic_pay) AS total_basic,
    SUM(ep.pera) AS total_pera,
    SUM(ep.rata) AS total_rata,
    SUM(ep.gross_pay) AS total_gross,
    SUM(ep.gsis_ps) AS total_gsis_ee,
    SUM(ep.gsis_gs) AS total_gsis_er,
    SUM(ep.pagibig_ps) AS total_pagibig_ee,
    SUM(ep.pagibig_gs) AS total_pagibig_er,
    SUM(ep.philhealth_ee) AS total_philhealth,
    SUM(ep.tax_withheld) AS total_tax,
    SUM(ep.loan_deductions) AS total_loans,
    SUM(ep.total_deductions) AS total_deductions,
    SUM(ep.net_pay) AS total_net
FROM payroll.pay_employee_payroll ep
GROUP BY ep.run_id;
