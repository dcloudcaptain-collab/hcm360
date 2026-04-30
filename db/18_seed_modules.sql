-- ================================================================
-- HCM360 HRIS — 18: SEED DATA — MODULES
-- Populates: holidays, leave types, leave balances,
--            attendance daily records, payroll periods,
--            sample leave requests, OT requests, loans
-- ================================================================

SET search_path TO core, attendance, leave_mgmt, payroll, public;

-- ── Philippine Holidays (company 1) ──────────────────────────────

INSERT INTO leave_mgmt.lv_holidays (company_id, hdate, name, htype, is_recurring, month_day)
SELECT c.id, h.hdate, h.name, h.htype, h.is_recurring, h.month_day
FROM core.companies c,
(VALUES
    ('2026-01-01'::date,'New Year''s Day',               'REGULAR',             TRUE,  '01-01'),
    ('2026-04-01','Maundy Thursday',               'REGULAR',             FALSE, NULL),
    ('2026-04-02','Good Friday',                   'REGULAR',             FALSE, NULL),
    ('2026-04-03','Black Saturday',                'SPECIAL_NON_WORKING', FALSE, NULL),
    ('2026-04-09','Araw ng Kagitingan',             'REGULAR',             TRUE,  '04-09'),
    ('2026-05-01','Labor Day',                     'REGULAR',             TRUE,  '05-01'),
    ('2026-06-12','Independence Day',              'REGULAR',             TRUE,  '06-12'),
    ('2026-08-31','National Heroes Day',           'REGULAR',             FALSE, NULL),
    ('2026-11-01','All Saints'' Day',              'SPECIAL_NON_WORKING', FALSE, NULL),
    ('2026-11-30','Bonifacio Day',                 'REGULAR',             TRUE,  '11-30'),
    ('2026-12-08','Feast of Immaculate Conception','SPECIAL_NON_WORKING', TRUE,  '12-08'),
    ('2026-12-25','Christmas Day',                 'REGULAR',             TRUE,  '12-25'),
    ('2026-12-30','Rizal Day',                     'REGULAR',             TRUE,  '12-30'),
    ('2026-12-31','New Year''s Eve',               'SPECIAL_NON_WORKING', TRUE,  '12-31')
) AS h(hdate, name, htype, is_recurring, month_day)
WHERE c.code = 'DEMO';

-- ── Leave Types ───────────────────────────────────────────────────

INSERT INTO leave_mgmt.lv_types (company_id, code, name, category, legal_basis, color, icon,
    is_paid, requires_document, min_days, max_days_per_filing, gender_restriction, is_active)
SELECT c.id, l.code, l.name, l.category, l.legal_basis, l.color, l.icon,
    l.is_paid, l.req_docs, 1, l.max_days, l.gender, TRUE
FROM core.companies c,
(VALUES
    ('VL',   'Vacation Leave',           'COMPANY',   NULL,        '#3b82f6','🏖️', TRUE,  FALSE, 15, NULL),
    ('SL',   'Sick Leave',               'COMPANY',   NULL,        '#f59e0b','🤒', TRUE,  FALSE, 15, NULL),
    ('SIL',  'Service Incentive Leave',  'STATUTORY', 'RA 6727',   '#10b981','⭐', TRUE,  FALSE,  5, NULL),
    ('ML',   'Maternity Leave',          'STATUTORY', 'RA 11210',  '#ec4899','🤰', TRUE,  TRUE, 105, 'FEMALE'),
    ('PL',   'Paternity Leave',          'STATUTORY', 'RA 8187',   '#6366f1','👨', TRUE,  FALSE,  7, 'MALE'),
    ('SPL',  'Solo Parent Leave',        'STATUTORY', 'RA 8972',   '#8b5cf6','👨‍👧', TRUE, TRUE,   7, NULL),
    ('VAWC', 'VAWC Leave',               'STATUTORY', 'RA 9262',   '#ef4444','🛡️', TRUE,  TRUE,  10, 'FEMALE'),
    ('MCL',  'Magna Carta Leave',        'STATUTORY', 'RA 9710',   '#f43f5e','⚕️', TRUE,  TRUE,  60, 'FEMALE'),
    ('EL',   'Emergency Leave',          'COMPANY',   NULL,        '#f97316','🆘', TRUE,  FALSE,  5, NULL),
    ('BL',   'Bereavement Leave',        'COMPANY',   NULL,        '#64748b','🕊️', TRUE,  FALSE,  5, NULL),
    ('BDL',  'Birthday Leave',           'COMPANY',   NULL,        '#a855f7','🎂', TRUE,  FALSE,  1, NULL),
    ('OL',   'Offsetting Leave',         'COMPANY',   NULL,        '#14b8a6','🔄', TRUE,  FALSE, 30, NULL),
    ('STL',  'Study Leave',              'COMPANY',   NULL,        '#0ea5e9','📚', TRUE,  TRUE,   5, NULL),
    ('LWOP', 'Leave Without Pay',        'COMPANY',   NULL,        '#94a3b8','⏸️', FALSE, FALSE,365, NULL),
    ('APL',  'Adoptive Parent Leave',    'STATUTORY', 'RA 8552',   '#c084fc','👶', TRUE,  TRUE,  10, NULL)
) AS l(code, name, category, legal_basis, color, icon, is_paid, req_docs, max_days, gender)
WHERE c.code = 'DEMO';

-- ── Leave Policies ────────────────────────────────────────────────

INSERT INTO leave_mgmt.lv_policies (company_id, leave_type_id, annual_days, accrual_type, carry_over_allowed, carry_over_max_days)
SELECT c.id, lt.id, p.days, p.accrual, p.carry_over, p.co_max
FROM core.companies c
JOIN leave_mgmt.lv_types lt ON lt.company_id = c.id,
(VALUES
    ('VL',  15, 'MONTHLY', TRUE,  5),
    ('SL',  15, 'MONTHLY', FALSE, 0),
    ('SIL',  5, 'ANNUAL',  TRUE,  5),
    ('EL',   5, 'ANNUAL',  FALSE, 0),
    ('BL',   5, 'ANNUAL',  FALSE, 0),
    ('BDL',  1, 'ANNUAL',  FALSE, 0),
    ('STL',  5, 'ANNUAL',  FALSE, 0)
) AS p(code, days, accrual, carry_over, co_max)
WHERE lt.code = p.code AND c.code = 'DEMO';

-- ── Leave Balances (current year) ─────────────────────────────────

INSERT INTO leave_mgmt.lv_balances (employee_id, leave_type_id, year, entitled_days, accrued_days, used_days, pending_days, carried_over)
SELECT e.id, lt.id, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER,
    CASE lt.code WHEN 'VL' THEN 15 WHEN 'SL' THEN 15 WHEN 'SIL' THEN 5 ELSE 5 END AS entitled,
    CASE lt.code WHEN 'VL' THEN 12 WHEN 'SL' THEN 14 WHEN 'SIL' THEN 5 ELSE 3 END AS accrued,
    CASE lt.code WHEN 'VL' THEN FLOOR(RANDOM()*5)::NUMERIC(5,1) WHEN 'SL' THEN FLOOR(RANDOM()*3)::NUMERIC(5,1) ELSE 0 END AS used,
    0 AS pending,
    CASE lt.code WHEN 'VL' THEN 3 ELSE 0 END AS carried_over
FROM core.employees e
CROSS JOIN leave_mgmt.lv_types lt
WHERE e.is_active = TRUE
  AND lt.company_id = e.company_id
  AND lt.code IN ('VL','SL','SIL','BDL','EL','BL')
ON CONFLICT (employee_id, leave_type_id, year) DO NOTHING;

-- ── Sample Leave Requests ──────────────────────────────────────────

DO $$
DECLARE
    v_comp BIGINT; v_vl BIGINT; v_sl BIGINT; v_el BIGINT;
    e1 BIGINT; e2 BIGINT; e3 BIGINT; e8 BIGINT; e10 BIGINT;
BEGIN
    SELECT id INTO v_comp FROM core.companies WHERE code='DEMO';
    SELECT id INTO v_vl  FROM leave_mgmt.lv_types WHERE code='VL'  AND company_id=v_comp;
    SELECT id INTO v_sl  FROM leave_mgmt.lv_types WHERE code='SL'  AND company_id=v_comp;
    SELECT id INTO v_el  FROM leave_mgmt.lv_types WHERE code='EL'  AND company_id=v_comp;
    SELECT id INTO e1  FROM core.employees WHERE employee_no='EMP-002';
    SELECT id INTO e2  FROM core.employees WHERE employee_no='EMP-003';
    SELECT id INTO e3  FROM core.employees WHERE employee_no='EMP-010';
    SELECT id INTO e8  FROM core.employees WHERE employee_no='EMP-015';
    SELECT id INTO e10 FROM core.employees WHERE employee_no='EMP-012';

    INSERT INTO leave_mgmt.lv_requests (reference_no, employee_id, leave_type_id, date_from, date_to, days_requested, reason, status, filed_at) VALUES
        ('LV-2026-001', e1,  v_vl, CURRENT_DATE + 7,  CURRENT_DATE + 11, 5, 'Family vacation',     'PENDING',  NOW() - INTERVAL '1 day'),
        ('LV-2026-002', e2,  v_sl, CURRENT_DATE + 1,  CURRENT_DATE + 2,  2, 'Medical appointment', 'PENDING',  NOW() - INTERVAL '2 hours'),
        ('LV-2026-003', e3,  v_el, CURRENT_DATE + 3,  CURRENT_DATE + 3,  1, 'Family emergency',    'PENDING',  NOW() - INTERVAL '30 minutes'),
        ('LV-2026-004', e8,  v_vl, CURRENT_DATE - 10, CURRENT_DATE - 8,  3, 'Personal leave',      'APPROVED', NOW() - INTERVAL '15 days'),
        ('LV-2026-005', e10, v_sl, CURRENT_DATE - 5,  CURRENT_DATE - 5,  1, 'Fever and flu',       'APPROVED', NOW() - INTERVAL '7 days'),
        ('LV-2026-006', e1,  v_vl, CURRENT_DATE - 30, CURRENT_DATE - 28, 3, 'Rest and relaxation', 'APPROVED', NOW() - INTERVAL '35 days');
END
$$;

-- ── Attendance (last 7 working days for all employees) ─────────────

DO $$
DECLARE
    v_date DATE;
    v_emp  RECORD;
    v_status VARCHAR;
    v_tin TIMESTAMPTZ; v_tout TIMESTAMPTZ;
    v_hrs_worked NUMERIC; v_hrs_late NUMERIC;
    v_shift BIGINT;
BEGIN
    SELECT id INTO v_shift FROM attendance.att_shifts WHERE code='REG-8-5' LIMIT 1;

    FOR v_date IN SELECT generate_series(CURRENT_DATE - 7, CURRENT_DATE, '1 day'::INTERVAL)::DATE LOOP
        -- Skip weekends
        CONTINUE WHEN EXTRACT(DOW FROM v_date) IN (0, 6);

        FOR v_emp IN SELECT id FROM core.employees WHERE is_active=TRUE LOOP
            -- 85% present, 5% absent, 10% late
            v_status := CASE (FLOOR(RANDOM()*20)::INTEGER)
                WHEN 0 THEN 'ABSENT'
                WHEN 1 THEN 'LATE'
                WHEN 2 THEN 'LATE'
                ELSE 'PRESENT'
            END;

            IF v_status IN ('PRESENT','LATE') THEN
                v_tin := (v_date::TIMESTAMP + INTERVAL '8 hours' +
                    CASE v_status WHEN 'LATE' THEN (FLOOR(RANDOM()*60)+10)::TEXT::INTERVAL
                    ELSE INTERVAL '0' END);
                v_tout := v_date::TIMESTAMP + INTERVAL '17 hours' + (FLOOR(RANDOM()*30))::TEXT::INTERVAL;
                v_hrs_worked := ROUND(EXTRACT(EPOCH FROM (v_tout - v_tin)) / 3600, 2);
                v_hrs_late := CASE v_status WHEN 'LATE' THEN ROUND((EXTRACT(EPOCH FROM (v_tin - (v_date::TIMESTAMP + INTERVAL '8 hours')))) / 3600, 2) ELSE 0 END;
            ELSE
                v_tin := NULL; v_tout := NULL; v_hrs_worked := 0; v_hrs_late := 0;
            END IF;

            INSERT INTO attendance.att_daily (employee_id, work_date, shift_id, time_in, time_out,
                hours_worked, hours_late, status)
            VALUES (v_emp.id, v_date, v_shift, v_tin, v_tout, v_hrs_worked, v_hrs_late, v_status)
            ON CONFLICT (employee_id, work_date) DO NOTHING;
        END LOOP;
    END LOOP;
END
$$;

-- ── OT Requests ───────────────────────────────────────────────────

DO $$
DECLARE e1 BIGINT; e2 BIGINT; e3 BIGINT;
BEGIN
    SELECT id INTO e1 FROM core.employees WHERE employee_no='EMP-005';
    SELECT id INTO e2 FROM core.employees WHERE employee_no='EMP-009';
    SELECT id INTO e3 FROM core.employees WHERE employee_no='EMP-006';
    INSERT INTO attendance.att_overtime_requests (employee_id, request_date, expected_ot_hours, reason, status) VALUES
        (e1, CURRENT_DATE - 1, 3, 'Project deadline - system deployment', 'PENDING'),
        (e2, CURRENT_DATE - 2, 2, 'Month-end operations coverage',        'APPROVED'),
        (e3, CURRENT_DATE - 3, 4, 'Critical bug fix - production issue',  'PENDING');
END
$$;

-- ── Payroll Periods ────────────────────────────────────────────────

DO $$
DECLARE v_comp BIGINT;
BEGIN
    SELECT id INTO v_comp FROM core.companies WHERE code='DEMO';
    INSERT INTO payroll.pay_periods (company_id, period_code, period_type, date_from, date_to, payment_date, status) VALUES
        (v_comp, '2026-03-1ST', 'SEMI_MONTHLY', '2026-03-01', '2026-03-15', '2026-03-20', 'CLOSED'),
        (v_comp, '2026-03-2ND', 'SEMI_MONTHLY', '2026-03-16', '2026-03-31', '2026-04-05', 'PROCESSING'),
        (v_comp, '2026-04-1ST', 'SEMI_MONTHLY', '2026-04-01', '2026-04-15', '2026-04-20', 'OPEN');
END
$$;

-- ── Sample Loans ──────────────────────────────────────────────────

DO $$
DECLARE e1 BIGINT; e2 BIGINT;
BEGIN
    SELECT id INTO e1 FROM core.employees WHERE employee_no='EMP-010';
    SELECT id INTO e2 FROM core.employees WHERE employee_no='EMP-003';
    INSERT INTO payroll.pay_loans (employee_id, loan_type, reference_no, principal_amount, outstanding_balance,
        monthly_deduction, interest_rate, total_months, months_paid, start_date, status) VALUES
    (e1, 'SSS_SALARY_LOAN', 'LOAN-001', 18000, 14400, 1500, 0.0, 12, 3, '2026-01-01', 'ACTIVE'),
    (e2, 'COMPANY_CALAMITY', 'LOAN-002', 10000,  8000, 1000, 0.0, 10, 2, '2026-02-01', 'ACTIVE');
END
$$;

-- ── Locator entries today ─────────────────────────────────────────

INSERT INTO leave_mgmt.lv_locator_entries (employee_id, log_date, location_type)
SELECT e.id, CURRENT_DATE,
    CASE (ROW_NUMBER() OVER (ORDER BY e.id) % 4)
        WHEN 0 THEN 'WFH'
        WHEN 1 THEN 'FIELD'
        WHEN 2 THEN 'ON_LEAVE'
        ELSE 'IN_OFFICE'
    END
FROM core.employees e
WHERE e.is_active = TRUE
LIMIT 10
ON CONFLICT (employee_id, log_date) DO NOTHING;
