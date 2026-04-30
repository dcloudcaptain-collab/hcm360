-- ================================================================
-- HCM360 HRIS — 16: ANALYTICS VIEWS & MATERIALIZED VIEWS
-- Run after all module schemas + triggers
-- ================================================================

SET search_path TO analytics, audit_logs, core, attendance, leave_mgmt,
    payroll, workflow, public;

-- ── Audit: Recent Activity Feed ───────────────────────────────────

CREATE VIEW audit_logs.v_recent_changes AS
SELECT
    cl.id, cl.schema_name, cl.table_name, cl.operation,
    cl.row_id, cl.changed_fields, cl.user_id,
    u.display_name AS changed_by_name,
    cl.app_context, cl.created_at
FROM audit_logs.sys_change_log cl
LEFT JOIN core.users u ON cl.user_id = u.id
ORDER BY cl.created_at DESC
LIMIT 500;

-- ── Audit: Security Events ────────────────────────────────────────

CREATE VIEW audit_logs.v_security_events AS
SELECT event_type, username, client_ip, failure_reason, created_at
FROM audit_logs.sys_login_logs
WHERE event_type IN ('LOGIN_FAILED','ACCOUNT_LOCKED','MFA_FAILED','PASSWORD_RESET')
ORDER BY created_at DESC;

-- ── Audit: User Activity Summary ─────────────────────────────────

CREATE VIEW audit_logs.v_user_activity_summary AS
SELECT
    u.id AS user_id, u.username, u.display_name, u.role_code,
    COUNT(cl.id) AS total_changes,
    COUNT(cl.id) FILTER (WHERE cl.operation='INSERT') AS inserts,
    COUNT(cl.id) FILTER (WHERE cl.operation='UPDATE') AS updates,
    COUNT(cl.id) FILTER (WHERE cl.operation='DELETE') AS deletes,
    MAX(cl.created_at) AS last_activity_at,
    COUNT(ll.id) AS total_logins,
    MAX(ll.created_at) AS last_login_at
FROM core.users u
LEFT JOIN audit_logs.sys_change_log cl ON u.id = cl.user_id
LEFT JOIN audit_logs.sys_login_logs ll ON u.id = ll.user_id AND ll.event_type='LOGIN_SUCCESS'
GROUP BY u.id, u.username, u.display_name, u.role_code;

-- ── Core: Employee 360 View ───────────────────────────────────────

CREATE VIEW core.v_employees_full AS
SELECT
    e.id, e.uuid, e.employee_no,
    e.last_name || ', ' || e.first_name ||
        COALESCE(' ' || e.middle_name, '') AS full_name,
    e.first_name, e.last_name, e.middle_name, e.suffix,
    e.gender, e.civil_status, e.date_of_birth,
    e.work_email, e.mobile_no,
    e.status, e.work_arrangement,
    e.date_hired, e.date_regularized, e.date_separated,
    e.basic_salary, e.daily_rate, e.hourly_rate,
    e.department_id, d.name AS department_name, d.code AS department_code,
    e.position_id, p.title AS position_title, p.code AS position_code,
    p.is_managerial,
    e.job_grade_id, jg.code AS grade_code, jg.name AS grade_name,
    e.employment_type_id, et.name AS employment_type,
    CONCAT(s.first_name, ' ', s.last_name) AS supervisor_name,
    e.is_active,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.date_hired))::INTEGER AS years_of_service,
    EXTRACT(MONTH FROM AGE(CURRENT_DATE, e.date_hired))::INTEGER +
        EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.date_hired))::INTEGER * 12 AS tenure_months,
    e.profile_photo_path,
    e.company_id, e.created_at, e.updated_at
FROM core.employees e
LEFT JOIN core.departments d ON e.department_id = d.id
LEFT JOIN core.positions p ON e.position_id = p.id
LEFT JOIN core.job_grades jg ON e.job_grade_id = jg.id
LEFT JOIN core.employment_types et ON e.employment_type_id = et.id
LEFT JOIN core.employees s ON e.immediate_supervisor_id = s.id;

-- ── Attendance: Daily Summary View ───────────────────────────────

CREATE VIEW attendance.v_attendance_summary AS
SELECT
    ad.work_date,
    ad.employee_id,
    e.last_name || ', ' || e.first_name AS full_name,
    e.employee_no,
    d.name AS department,
    ad.status,
    ad.time_in, ad.time_out,
    ad.hours_worked, ad.hours_late, ad.hours_overtime,
    ad.is_holiday, ad.is_restday, ad.is_locked
FROM attendance.att_daily ad
JOIN core.employees e ON e.id = ad.employee_id
LEFT JOIN core.departments d ON d.id = e.department_id;

-- ── Attendance: Today's Board ─────────────────────────────────────

CREATE VIEW attendance.v_today_board AS
SELECT
    e.id AS employee_id, e.employee_no,
    e.last_name || ', ' || e.first_name AS full_name,
    d.name AS department,
    COALESCE(ad.status, 'NOT_LOGGED') AS status,
    ad.time_in, ad.time_out,
    ad.hours_worked, ad.hours_late
FROM core.employees e
LEFT JOIN core.departments d ON d.id = e.department_id
LEFT JOIN attendance.att_daily ad ON ad.employee_id = e.id AND ad.work_date = CURRENT_DATE
WHERE e.is_active = TRUE AND e.status NOT IN ('RESIGNED','TERMINATED','RETIRED','DECEASED');

-- ── Leave: Request Pipeline View ─────────────────────────────────

CREATE VIEW leave_mgmt.v_leave_requests_full AS
SELECT
    lr.id, lr.reference_no,
    e.last_name || ', ' || e.first_name AS employee_name,
    e.employee_no, d.name AS department,
    lt.name AS leave_type, lt.code AS leave_type_code, lt.color,
    lr.date_from, lr.date_to, lr.days_requested,
    lr.reason, lr.status, lr.is_half_day,
    lr.filed_at, lr.workflow_instance_id,
    lr.employee_id
FROM leave_mgmt.lv_requests lr
JOIN core.employees e ON e.id = lr.employee_id
LEFT JOIN core.departments d ON d.id = e.department_id
JOIN leave_mgmt.lv_types lt ON lt.id = lr.leave_type_id;

-- ── Leave: Balance Matrix ─────────────────────────────────────────

CREATE VIEW leave_mgmt.v_leave_balance_matrix AS
SELECT
    lb.employee_id, lb.year,
    e.last_name || ', ' || e.first_name AS full_name,
    e.employee_no, d.name AS department,
    lt.code AS leave_type_code, lt.name AS leave_type_name,
    lb.entitled_days, lb.accrued_days, lb.used_days,
    lb.pending_days, lb.carried_over, lb.balance
FROM leave_mgmt.lv_balances lb
JOIN core.employees e ON e.id = lb.employee_id
LEFT JOIN core.departments d ON d.id = e.department_id
JOIN leave_mgmt.lv_types lt ON lt.id = lb.leave_type_id;

-- ── Leave: Today's Locator Board ─────────────────────────────────

CREATE VIEW leave_mgmt.v_locator_today AS
SELECT
    e.id AS employee_id, e.employee_no,
    e.last_name || ', ' || e.first_name AS full_name,
    d.name AS department,
    COALESCE(loc.location_type, 'UNKNOWN') AS location_type,
    loc.destination, loc.purpose, loc.contact_no,
    loc.departure_time, loc.return_time
FROM core.employees e
LEFT JOIN core.departments d ON d.id = e.department_id
LEFT JOIN leave_mgmt.lv_locator_entries loc
    ON loc.employee_id = e.id AND loc.log_date = CURRENT_DATE
WHERE e.is_active = TRUE AND e.status NOT IN ('RESIGNED','TERMINATED','RETIRED','DECEASED');

-- ── Payroll: Current Cutoff Summary ──────────────────────────────

CREATE VIEW payroll.v_current_cutoff AS
SELECT
    pp.period_code, pp.date_from, pp.date_to, pp.payment_date,
    pr.id AS run_id, pr.status AS run_status,
    pr.total_employees, pr.total_gross, pr.total_net, pr.total_deductions
FROM payroll.pay_periods pp
LEFT JOIN payroll.pay_runs pr ON pr.period_id = pp.id
WHERE pp.status IN ('OPEN','PROCESSING')
ORDER BY pp.date_from DESC
LIMIT 1;

-- ── Payroll: Payslip View ─────────────────────────────────────────

CREATE VIEW payroll.v_payslip AS
SELECT
    ep.id AS payslip_id, ep.run_id,
    pp.period_code, pp.date_from AS period_from, pp.date_to AS period_to,
    pp.payment_date,
    e.id AS employee_id, e.employee_no,
    e.last_name || ', ' || e.first_name AS full_name,
    d.name AS department, p.title AS position,
    ep.worked_days, ep.absent_days, ep.leave_days,
    ep.ot_regular_hours, ep.ot_restday_hours, ep.ot_holiday_hours,
    ep.basic_pay, ep.ot_pay, ep.holiday_pay, ep.night_diff_pay,
    ep.allowances_total, ep.other_earnings, ep.gross_pay,
    ep.sss_ee, ep.philhealth_ee, ep.pagibig_ee,
    ep.tax_withheld, ep.loan_deductions, ep.other_deductions,
    ep.total_deductions, ep.net_pay
FROM payroll.pay_employee_payroll ep
JOIN payroll.pay_runs pr ON pr.id = ep.run_id
JOIN payroll.pay_periods pp ON pp.id = pr.period_id
JOIN core.employees e ON e.id = ep.employee_id
LEFT JOIN core.departments d ON d.id = e.department_id
LEFT JOIN core.positions p ON p.id = e.position_id;

-- ── Workflow: Pending Approvals ───────────────────────────────────

CREATE VIEW workflow.v_pending_approvals AS
SELECT
    wi.id AS instance_id, wi.reference_no,
    wd.name AS workflow_name, wd.module,
    ws.name AS current_step,
    wi.entity_type, wi.entity_id,
    u.display_name AS initiated_by,
    wi.created_at AS filed_at,
    EXTRACT(EPOCH FROM (NOW() - wi.created_at))/3600 AS hours_pending
FROM workflow.workflow_instances wi
JOIN workflow.workflow_definitions wd ON wd.id = wi.definition_id
LEFT JOIN workflow.workflow_steps ws ON ws.id = wi.current_step_id
LEFT JOIN core.users u ON u.id = wi.initiated_by
WHERE wi.status = 'IN_PROGRESS'
ORDER BY wi.created_at ASC;

-- ── Analytics: Headcount by Department ───────────────────────────

CREATE VIEW analytics.v_headcount_by_dept AS
SELECT
    d.name AS department, d.code,
    COUNT(*) FILTER (WHERE e.status = 'ACTIVE') AS active,
    COUNT(*) FILTER (WHERE e.status = 'PROBATIONARY') AS probationary,
    COUNT(*) FILTER (WHERE e.status = 'ON_LEAVE') AS on_leave,
    COUNT(*) AS total
FROM core.employees e
LEFT JOIN core.departments d ON d.id = e.department_id
WHERE e.is_active = TRUE
  AND e.status NOT IN ('RESIGNED','TERMINATED','RETIRED','DECEASED')
GROUP BY d.name, d.code
ORDER BY total DESC;

-- ── Analytics: Attendance Rate by Department (last 30 days) ──────

CREATE VIEW analytics.v_attendance_rate_30d AS
SELECT
    d.name AS department,
    COUNT(*) AS total_employee_days,
    COUNT(*) FILTER (WHERE ad.status = 'PRESENT') AS present_days,
    COUNT(*) FILTER (WHERE ad.status = 'ABSENT') AS absent_days,
    COUNT(*) FILTER (WHERE ad.status = 'LATE') AS late_days,
    ROUND(COUNT(*) FILTER (WHERE ad.status IN ('PRESENT','LATE'))::NUMERIC /
          NULLIF(COUNT(*), 0) * 100, 1) AS attendance_rate_pct
FROM attendance.att_daily ad
JOIN core.employees e ON e.id = ad.employee_id
LEFT JOIN core.departments d ON d.id = e.department_id
WHERE ad.work_date >= CURRENT_DATE - 30
  AND ad.is_holiday = FALSE
  AND ad.is_restday = FALSE
GROUP BY d.name
ORDER BY attendance_rate_pct DESC;

-- ── Analytics: Leave Utilization by Type (YTD) ───────────────────

CREATE VIEW analytics.v_leave_utilization_ytd AS
SELECT
    lt.code AS leave_type_code, lt.name AS leave_type_name,
    COUNT(lr.id) AS total_requests,
    COUNT(lr.id) FILTER (WHERE lr.status = 'APPROVED') AS approved,
    COUNT(lr.id) FILTER (WHERE lr.status = 'PENDING') AS pending,
    COUNT(lr.id) FILTER (WHERE lr.status = 'REJECTED') AS rejected,
    COALESCE(SUM(lr.days_requested) FILTER (WHERE lr.status = 'APPROVED'), 0) AS total_days_approved
FROM leave_mgmt.lv_types lt
LEFT JOIN leave_mgmt.lv_requests lr ON lr.leave_type_id = lt.id
    AND lr.date_from >= DATE_TRUNC('year', CURRENT_DATE)
GROUP BY lt.code, lt.name
ORDER BY total_days_approved DESC;

-- ── Analytics: Payroll Cost by Department (MTD) ──────────────────

CREATE VIEW analytics.v_payroll_cost_mtd AS
SELECT
    d.name AS department,
    COUNT(ep.id) AS employee_count,
    SUM(ep.gross_pay) AS total_gross,
    SUM(ep.net_pay) AS total_net,
    SUM(ep.total_deductions) AS total_deductions,
    SUM(ep.loan_deductions) AS total_loan_deductions
FROM payroll.pay_employee_payroll ep
JOIN payroll.pay_runs pr ON pr.id = ep.run_id
JOIN payroll.pay_periods pp ON pp.id = pr.period_id
JOIN core.employees e ON e.id = ep.employee_id
LEFT JOIN core.departments d ON d.id = e.department_id
WHERE pr.status = 'POSTED'
  AND pp.date_from >= DATE_TRUNC('month', CURRENT_DATE)
GROUP BY d.name
ORDER BY total_gross DESC;
