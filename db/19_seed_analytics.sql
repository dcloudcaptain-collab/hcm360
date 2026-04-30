-- ================================================================
-- HCM360 HRIS — 19: SEED DATA — ANALYTICS
-- Populates: dim_employee, dim_department, dim_position,
--            kpi_snapshots, fact_attendance, fact_leave
-- ================================================================

SET search_path TO analytics, core, attendance, leave_mgmt, payroll, public;

-- ── Dimension: Department ─────────────────────────────────────────

INSERT INTO analytics.dim_department (department_id, code, name, company_id, is_current)
SELECT d.id, d.code, d.name, d.company_id, TRUE
FROM core.departments d
WHERE d.is_active = TRUE
ON CONFLICT DO NOTHING;

-- ── Dimension: Position ───────────────────────────────────────────

INSERT INTO analytics.dim_position (position_id, code, title, is_managerial, is_current)
SELECT p.id, p.code, p.title, p.is_managerial, TRUE
FROM core.positions p
WHERE p.is_active = TRUE
ON CONFLICT DO NOTHING;

-- ── Dimension: Employee (current snapshot) ────────────────────────

INSERT INTO analytics.dim_employee (
    employee_id, employee_no, full_name, gender,
    department_id, department_name, position_id, position_title,
    employment_type, work_arrangement, date_hired, status,
    tenure_months, effective_from, is_current
)
SELECT
    e.id, e.employee_no,
    e.last_name || ', ' || e.first_name AS full_name,
    e.gender,
    e.department_id, d.name AS department_name,
    e.position_id, p.title AS position_title,
    et.name AS employment_type, e.work_arrangement,
    e.date_hired, e.status,
    COALESCE(
        EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.date_hired))::INTEGER * 12 +
        EXTRACT(MONTH FROM AGE(CURRENT_DATE, e.date_hired))::INTEGER, 0
    ) AS tenure_months,
    CURRENT_DATE AS effective_from,
    TRUE AS is_current
FROM core.employees e
LEFT JOIN core.departments d ON d.id = e.department_id
LEFT JOIN core.positions p ON p.id = e.position_id
LEFT JOIN core.employment_types et ON et.id = e.employment_type_id
WHERE e.is_active = TRUE;

-- ── Fact: Attendance (from att_daily seed data) ───────────────────

INSERT INTO analytics.fact_attendance (date_key, employee_key, department_key,
    hours_worked, hours_late, hours_overtime, is_present, is_absent, attendance_status)
SELECT
    TO_CHAR(ad.work_date, 'YYYYMMDD')::INTEGER AS date_key,
    de.surrogate_key AS employee_key,
    dd.surrogate_key AS department_key,
    ad.hours_worked, ad.hours_late, ad.hours_overtime,
    ad.status IN ('PRESENT','LATE') AS is_present,
    ad.status = 'ABSENT' AS is_absent,
    ad.status
FROM attendance.att_daily ad
JOIN analytics.dim_employee de ON de.employee_id = ad.employee_id AND de.is_current = TRUE
LEFT JOIN analytics.dim_department dd ON dd.department_id = (
    SELECT department_id FROM core.employees WHERE id = ad.employee_id
) AND dd.is_current = TRUE
ON CONFLICT (date_key, employee_key) DO NOTHING;

-- ── Fact: Leave (from lv_requests seed data) ──────────────────────

INSERT INTO analytics.fact_leave (date_key, employee_key, leave_request_id,
    leave_type_code, leave_type_name, days_approved, days_pending, status)
SELECT
    TO_CHAR(lr.date_from, 'YYYYMMDD')::INTEGER AS date_key,
    de.surrogate_key AS employee_key,
    lr.id AS leave_request_id,
    lt.code AS leave_type_code, lt.name AS leave_type_name,
    CASE WHEN lr.status = 'APPROVED' THEN lr.days_requested ELSE 0 END AS days_approved,
    CASE WHEN lr.status = 'PENDING'  THEN lr.days_requested ELSE 0 END AS days_pending,
    lr.status
FROM leave_mgmt.lv_requests lr
JOIN analytics.dim_employee de ON de.employee_id = lr.employee_id AND de.is_current = TRUE
JOIN leave_mgmt.lv_types lt ON lt.id = lr.leave_type_id
ON CONFLICT (leave_request_id) DO NOTHING;

-- ── KPI Snapshots (today's initial snapshot) ──────────────────────

-- Headcount KPIs
INSERT INTO analytics.kpi_snapshots (module, kpi_code, kpi_value, kpi_label, snapshot_date)
SELECT 'core', 'HEADCOUNT_TOTAL',
    (SELECT COUNT(*) FROM core.employees WHERE is_active=TRUE AND status NOT IN ('RESIGNED','TERMINATED','RETIRED','DECEASED')),
    'Total Headcount', CURRENT_DATE;

INSERT INTO analytics.kpi_snapshots (module, kpi_code, kpi_value, kpi_label, snapshot_date)
SELECT 'core', 'HEADCOUNT_ACTIVE',
    (SELECT COUNT(*) FROM core.employees WHERE is_active=TRUE AND status='ACTIVE'),
    'Active Employees', CURRENT_DATE;

INSERT INTO analytics.kpi_snapshots (module, kpi_code, kpi_value, kpi_label, snapshot_date)
SELECT 'core', 'HEADCOUNT_PROBATIONARY',
    (SELECT COUNT(*) FROM core.employees WHERE is_active=TRUE AND status='PROBATIONARY'),
    'Probationary Employees', CURRENT_DATE;

-- Attendance KPIs
INSERT INTO analytics.kpi_snapshots (module, kpi_code, kpi_value, kpi_label, snapshot_date)
SELECT 'attendance', 'PRESENT_TODAY',
    (SELECT COUNT(*) FROM attendance.att_daily WHERE work_date=CURRENT_DATE AND status IN ('PRESENT','LATE')),
    'Present Today', CURRENT_DATE;

INSERT INTO analytics.kpi_snapshots (module, kpi_code, kpi_value, kpi_label, snapshot_date)
SELECT 'attendance', 'LATE_TODAY',
    (SELECT COUNT(*) FROM attendance.att_daily WHERE work_date=CURRENT_DATE AND status='LATE'),
    'Late Today', CURRENT_DATE;

-- Leave KPIs
INSERT INTO analytics.kpi_snapshots (module, kpi_code, kpi_value, kpi_label, snapshot_date)
SELECT 'leave_mgmt', 'LEAVE_PENDING',
    (SELECT COUNT(*) FROM leave_mgmt.lv_requests WHERE status='PENDING'),
    'Pending Leave Requests', CURRENT_DATE;

INSERT INTO analytics.kpi_snapshots (module, kpi_code, kpi_value, kpi_label, snapshot_date)
SELECT 'leave_mgmt', 'ON_LEAVE_TODAY',
    (SELECT COUNT(*) FROM leave_mgmt.lv_requests WHERE status='APPROVED' AND date_from<=CURRENT_DATE AND date_to>=CURRENT_DATE),
    'On Leave Today', CURRENT_DATE;

-- Attendance rate (30-day)
INSERT INTO analytics.kpi_snapshots (module, kpi_code, kpi_value, kpi_label, snapshot_date)
SELECT 'attendance', 'ATTENDANCE_RATE_30D',
    ROUND(
        COUNT(*) FILTER (WHERE status IN ('PRESENT','LATE'))::NUMERIC /
        NULLIF(COUNT(*) FILTER (WHERE is_holiday=FALSE AND is_restday=FALSE), 0) * 100, 1
    ),
    'Attendance Rate % (30d)', CURRENT_DATE
FROM attendance.att_daily
WHERE work_date >= CURRENT_DATE - 30;
