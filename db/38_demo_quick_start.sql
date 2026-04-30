-- ================================================================
-- HCM360 DEMO — PROFILE A: QUICK START
-- Fresh go-live, 20 employees, minimal history
-- ================================================================

-- ── Fix supervisor hierarchy for org chart ──────────────────────
UPDATE core.employees SET immediate_supervisor_id = NULL WHERE employee_no = 'EMP-016';
UPDATE core.employees SET immediate_supervisor_id = (SELECT id FROM core.employees WHERE employee_no = 'EMP-016')
WHERE employee_no IN ('EMP-001','EMP-005','EMP-008','EMP-011','EMP-014');
UPDATE core.employees SET immediate_supervisor_id = (SELECT id FROM core.employees WHERE employee_no = 'EMP-001')
WHERE employee_no IN ('EMP-002','EMP-003','EMP-004','EMP-017');
UPDATE core.employees SET immediate_supervisor_id = (SELECT id FROM core.employees WHERE employee_no = 'EMP-005')
WHERE employee_no IN ('EMP-006','EMP-007','EMP-018');
UPDATE core.employees SET immediate_supervisor_id = (SELECT id FROM core.employees WHERE employee_no = 'EMP-008')
WHERE employee_no IN ('EMP-009','EMP-010','EMP-019');
UPDATE core.employees SET immediate_supervisor_id = (SELECT id FROM core.employees WHERE employee_no = 'EMP-011')
WHERE employee_no IN ('EMP-012','EMP-013','EMP-020');
UPDATE core.employees SET immediate_supervisor_id = (SELECT id FROM core.employees WHERE employee_no = 'EMP-014')
WHERE employee_no = 'EMP-015';

-- ── Attendance: 10 working days ─────────────────────────────────
DO $$
DECLARE
    emp RECORD;
    d DATE;
    work_days DATE[] := ARRAY[
        '2026-03-23','2026-03-24','2026-03-25','2026-03-26','2026-03-27',
        '2026-03-16','2026-03-17','2026-03-18','2026-03-19','2026-03-20'
    ];
    shift_id BIGINT;
BEGIN
    SELECT id INTO shift_id FROM attendance.att_shifts WHERE code = 'REG-8-5' LIMIT 1;
    IF shift_id IS NULL THEN RETURN; END IF;
    FOR emp IN SELECT id, employee_no FROM core.employees WHERE is_active = TRUE LOOP
        FOREACH d IN ARRAY work_days LOOP
            INSERT INTO attendance.att_daily
                (employee_id, work_date, shift_id, time_in, time_out,
                 hours_worked, hours_late, hours_undertime, status)
            VALUES (
                emp.id, d, shift_id,
                (d + TIME '07:55' + (random() * INTERVAL '10 minutes'))::TIMESTAMP,
                (d + TIME '17:00' + (random() * INTERVAL '15 minutes'))::TIMESTAMP,
                8.0 + round((random() * 1)::numeric, 2),
                CASE WHEN emp.employee_no IN ('EMP-010','EMP-015') AND random() < 0.4
                     THEN round((random() * 0.5)::numeric, 2) ELSE 0 END,
                0,
                CASE WHEN emp.employee_no IN ('EMP-010','EMP-015') AND random() < 0.4
                     THEN 'LATE' ELSE 'PRESENT' END
            ) ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;
END $$;

-- ── Leave Balances ──────────────────────────────────────────────
INSERT INTO leave_mgmt.lv_balances (employee_id, leave_type_id, year, entitled_days, accrued_days, used_days, pending_days)
SELECT e.id, lt.id, 2026,
    CASE lt.code WHEN 'VL' THEN 15 WHEN 'SL' THEN 15 WHEN 'SIL' THEN 5 ELSE 0 END,
    CASE lt.code WHEN 'VL' THEN 15 WHEN 'SL' THEN 15 WHEN 'SIL' THEN 5 ELSE 0 END,
    0, 0
FROM core.employees e CROSS JOIN leave_mgmt.lv_types lt
WHERE e.is_active = TRUE AND lt.code IN ('VL','SL','SIL')
ON CONFLICT DO NOTHING;

-- ── Leave Requests ──────────────────────────────────────────────
INSERT INTO leave_mgmt.lv_requests (reference_no, employee_id, leave_type_id, date_from, date_to, days_requested, reason, status, filed_at)
SELECT 'LV-2026-' || LPAD(ROW_NUMBER() OVER ()::text, 4, '0'),
       e.id, lt.id, v.df, v.dt, v.days, v.reason, v.status, NOW() - INTERVAL '2 days'
FROM (VALUES
    ('EMP-010','VL','2026-04-07'::date,'2026-04-08'::date,2.0,'Family event','PENDING'),
    ('EMP-015','VL','2026-04-14'::date,'2026-04-16'::date,3.0,'Personal matters','PENDING'),
    ('EMP-006','SL','2026-03-25'::date,'2026-03-26'::date,2.0,'Medical checkup','APPROVED')
) AS v(emp_no, lt_code, df, dt, days, reason, status)
JOIN core.employees e ON e.employee_no = v.emp_no
JOIN leave_mgmt.lv_types lt ON lt.code = v.lt_code;

-- ── Payroll: 1 open period ──────────────────────────────────────
INSERT INTO payroll.pay_periods (company_id, period_code, period_type, date_from, date_to, payment_date, status)
SELECT c.id, '2026-04-1ST', 'SEMI_MONTHLY', '2026-04-01', '2026-04-15', '2026-04-15', 'OPEN'
FROM core.companies c LIMIT 1
ON CONFLICT DO NOTHING;

-- ── RSP: 3 vacant plantilla items ───────────────────────────────
INSERT INTO recruitment.rec_plantilla_items
    (company_id, department_id, item_number, salary_grade, step_no, status)
SELECT c.id, d.id, v.item_no, v.sg, 1, 'VACANT'
FROM core.companies c,
(VALUES ('IT','IT-ITEM-021',11), ('HR','HR-ITEM-022',6), ('OPS','OPS-ITEM-023',3))
AS v(dept_code, item_no, sg)
JOIN core.departments d ON d.code = v.dept_code
WHERE c.id = (SELECT id FROM core.companies LIMIT 1)
ON CONFLICT DO NOTHING;

-- ── PM: 1 cycle in PLANNING ────────────────────────────────────
INSERT INTO performance.perf_cycles (company_id, name, cycle_type, period_from, period_to, status)
SELECT c.id, '2026 Annual Performance Review', 'ANNUAL', '2026-01-01', '2026-12-31', 'PLANNING'
FROM core.companies c LIMIT 1;

-- ── L&D: 2 programs, 1 session, 5 enrollments ──────────────────
INSERT INTO learning.lrn_programs (company_id, code, title, description, category, delivery_mode, duration_hours, is_mandatory)
SELECT c.id, v.code, v.title, v.descr, v.cat, v.mode, v.hrs, v.mand
FROM core.companies c,
(VALUES
    ('DPA-101','Data Privacy Act Compliance Training','Mandatory RA 10173','Compliance','IN_PERSON',8.0,TRUE),
    ('LEAD-201','Leadership Fundamentals','For government supervisors','Leadership','IN_PERSON',16.0,FALSE)
) AS v(code, title, descr, cat, mode, hrs, mand)
WHERE c.id = (SELECT id FROM core.companies LIMIT 1)
ON CONFLICT DO NOTHING;

INSERT INTO learning.lrn_sessions (program_id, session_date, session_end, venue, facilitator, max_participants, status)
SELECT p.id, '2026-04-21', '2026-04-21', 'Training Room A', 'Atty. Maria Cruz', 30, 'SCHEDULED'
FROM learning.lrn_programs p WHERE p.code = 'DPA-101' LIMIT 1;

INSERT INTO learning.lrn_enrollments (session_id, employee_id, status)
SELECT s.id, e.id, 'ENROLLED'
FROM learning.lrn_sessions s
CROSS JOIN core.employees e
WHERE s.status = 'SCHEDULED' AND e.employee_no IN ('EMP-001','EMP-002','EMP-005','EMP-008','EMP-011')
ON CONFLICT DO NOTHING;

-- ── R&R: Step increments ────────────────────────────────────────
INSERT INTO rewards.rwd_step_increments
    (employee_id, current_sg, current_step, next_step, last_increment_date, eligibility_status)
SELECT e.id, COALESCE(jg.grade_level, 1), 1, 2, e.date_hired, 'PENDING_RATING'
FROM core.employees e
LEFT JOIN core.job_grades jg ON jg.id = e.job_grade_id
WHERE e.is_active = TRUE AND e.date_hired IS NOT NULL;

-- ── Health: 1 PE schedule ───────────────────────────────────────
INSERT INTO health.pe_schedules (company_id, year, title, scheduled_from, scheduled_to, status, created_by)
SELECT c.id, 2026, '2026 Annual Physical Examination', '2026-05-01', '2026-05-31', 'SCHEDULED',
       (SELECT id FROM core.users WHERE username IN ('hradmin','superadmin') ORDER BY username LIMIT 1)
FROM core.companies c LIMIT 1
ON CONFLICT DO NOTHING;

-- ── Recruitment: 1 requisition, 1 job posting, 2 applicants ────
DO $$
DECLARE
    co_id BIGINT; it_dept BIGINT; dev_jr_pos BIGINT;
    req_id BIGINT; posting_id BIGINT; hr_user BIGINT;
BEGIN
    SELECT id INTO co_id FROM core.companies LIMIT 1;
    SELECT id INTO it_dept FROM core.departments WHERE code = 'IT';
    SELECT id INTO dev_jr_pos FROM core.positions WHERE code = 'DEV-JR';
    SELECT id INTO hr_user FROM core.users WHERE username IN ('hradmin','superadmin') ORDER BY username LIMIT 1;

    INSERT INTO recruitment.rec_requisitions
        (company_id, reference_no, department_id, position_id, headcount, justification, status, requested_by, target_hire_date)
    VALUES (co_id, 'REQ-2026-001', it_dept, dev_jr_pos, 1,
            'Replacement for retiring IT staff. Approved by Department Head.',
            'APPROVED', hr_user, '2026-06-01')
    ON CONFLICT DO NOTHING
    RETURNING id INTO req_id;

    IF req_id IS NULL THEN
        SELECT id INTO req_id FROM recruitment.rec_requisitions WHERE reference_no = 'REQ-2026-001';
    END IF;

    INSERT INTO recruitment.rec_job_postings
        (requisition_id, title, description, requirements, employment_type, salary_range,
         location, posted_on, status, is_internal)
    VALUES (req_id, 'Junior Developer (IT Department)',
            'The agency is looking for a Junior Developer to support internal systems development and maintenance.',
            'BS in Computer Science or IT; CSC Professional or Sub-Professional eligibility; 1 year relevant experience',
            'PERMANENT', 'SG-11 (Php 27,000 - 30,000)',
            'Main Office, Metro Manila', '2026-03-25', 'OPEN', FALSE)
    RETURNING id INTO posting_id;

    INSERT INTO recruitment.rec_applicants (posting_id, first_name, last_name, email, mobile_no, stage, source)
    VALUES
        (posting_id, 'Rafael', 'Magbanua', 'rafael.magbanua@gmail.com', '09175550101', 'APPLIED', 'CSC_POSTING'),
        (posting_id, 'Karen', 'Tiu', 'karen.tiu@yahoo.com', '09185550102', 'APPLIED', 'AGENCY_WEBSITE');
END $$;

-- ── DMS: 201 File checklist at ~60% completion ─────────────────
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

    FOR emp IN SELECT id FROM core.employees WHERE is_active = TRUE AND employee_no <= 'EMP-020' LOOP
        idx := 0;
        FOREACH dt IN ARRAY doc_types LOOP
            idx := idx + 1;
            INSERT INTO dms.document_requests
                (company_id, employee_id, document_type, purpose, requested_by, due_date, status)
            SELECT co_id, emp.id, dt, '201 File compliance', hr_user, '2026-06-30',
                CASE WHEN idx <= 10 THEN 'SUBMITTED' ELSE 'PENDING' END
            WHERE NOT EXISTS (
                SELECT 1 FROM dms.document_requests dr
                WHERE dr.employee_id = emp.id AND dr.document_type = dt
            );
        END LOOP;
    END LOOP;
END $$;
