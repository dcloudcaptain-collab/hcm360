-- ================================================================
-- HCM360 HRIS — 05: ATTENDANCE SCHEMA
-- Schema    : attendance
-- Contains  : shifts, assignments, holiday types, holidays,
--             raw logs (partitioned), daily summary, OT requests,
--             DTR corrections
-- ================================================================

SET search_path TO attendance, core, public;

CREATE TABLE attendance.att_shifts (
    id                   BIGSERIAL    PRIMARY KEY,
    company_id           BIGINT       NOT NULL REFERENCES core.companies(id),
    code                 VARCHAR(20)  NOT NULL,
    name                 VARCHAR(100) NOT NULL,
    shift_type           VARCHAR(20)  NOT NULL DEFAULT 'FIXED',
    time_in              TIME,
    time_out             TIME,
    break_minutes        INTEGER      NOT NULL DEFAULT 60,
    total_work_hours     NUMERIC(4,2),
    grace_period_minutes INTEGER      NOT NULL DEFAULT 0,
    is_night_shift       BOOLEAN      NOT NULL DEFAULT FALSE,
    crosses_midnight     BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active            BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, code)
);

CREATE TABLE attendance.att_shift_assignments (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    shift_id        BIGINT       NOT NULL REFERENCES attendance.att_shifts(id),
    effective_from  DATE         NOT NULL,
    effective_to    DATE,
    created_by      BIGINT       REFERENCES core.users(id),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE attendance.att_holiday_types (
    id              BIGSERIAL    PRIMARY KEY,
    code            VARCHAR(20)  NOT NULL UNIQUE,
    name            VARCHAR(100) NOT NULL,
    pay_multiplier  NUMERIC(4,2) NOT NULL DEFAULT 1.0,
    description     TEXT
);

INSERT INTO attendance.att_holiday_types (code, name, pay_multiplier) VALUES
    ('REGULAR',              'Regular Holiday',            2.0),
    ('SPECIAL_NON_WORKING',  'Special Non-Working Day',    1.3),
    ('SPECIAL_WORKING',      'Special Working Day',        1.0);

CREATE TABLE attendance.att_holidays (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       NOT NULL REFERENCES core.companies(id),
    holiday_type_id BIGINT       NOT NULL REFERENCES attendance.att_holiday_types(id),
    holiday_date    DATE         NOT NULL,
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    is_recurring    BOOLEAN      NOT NULL DEFAULT FALSE,
    month_day       VARCHAR(6),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, holiday_date, name)
);

-- Partitioned raw attendance log (biometric / QR / manual)
CREATE TABLE attendance.att_logs (
    id                    BIGSERIAL    NOT NULL,
    employee_id           BIGINT       NOT NULL REFERENCES core.employees(id),
    log_datetime          TIMESTAMPTZ  NOT NULL,
    log_type              VARCHAR(10)  NOT NULL,
    source                VARCHAR(20)  NOT NULL DEFAULT 'MANUAL',
    device_id             VARCHAR(50),
    location              VARCHAR(200),
    photo_path            TEXT,
    is_valid              BOOLEAN      NOT NULL DEFAULT TRUE,
    invalidated_by        BIGINT       REFERENCES core.users(id),
    invalidation_reason   TEXT,
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, log_datetime)
) PARTITION BY RANGE (log_datetime);

CREATE TABLE attendance.att_logs_2025 PARTITION OF attendance.att_logs
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE attendance.att_logs_2026 PARTITION OF attendance.att_logs
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE attendance.att_logs_2027 PARTITION OF attendance.att_logs
    FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
CREATE TABLE attendance.att_logs_2028 PARTITION OF attendance.att_logs
    FOR VALUES FROM ('2028-01-01') TO ('2029-01-01');

CREATE INDEX idx_att_logs_emp ON attendance.att_logs(employee_id, log_datetime);

-- Computed daily attendance summary
CREATE TABLE attendance.att_daily (
    id                BIGSERIAL    PRIMARY KEY,
    employee_id       BIGINT       NOT NULL REFERENCES core.employees(id),
    work_date         DATE         NOT NULL,
    shift_id          BIGINT       REFERENCES attendance.att_shifts(id),
    time_in           TIMESTAMPTZ,
    time_out          TIMESTAMPTZ,
    hours_worked      NUMERIC(5,2) NOT NULL DEFAULT 0,
    hours_late        NUMERIC(5,2) NOT NULL DEFAULT 0,
    hours_undertime   NUMERIC(5,2) NOT NULL DEFAULT 0,
    hours_overtime    NUMERIC(5,2) NOT NULL DEFAULT 0,
    hours_night_diff  NUMERIC(5,2) NOT NULL DEFAULT 0,
    status            VARCHAR(20)  NOT NULL DEFAULT 'ABSENT',
    is_holiday        BOOLEAN      NOT NULL DEFAULT FALSE,
    holiday_id        BIGINT       REFERENCES attendance.att_holidays(id),
    is_restday        BOOLEAN      NOT NULL DEFAULT FALSE,
    leave_request_id  BIGINT,
    remarks           TEXT,
    is_locked         BOOLEAN      NOT NULL DEFAULT FALSE,
    locked_by         BIGINT       REFERENCES core.users(id),
    locked_at         TIMESTAMPTZ,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (employee_id, work_date)
);

CREATE INDEX idx_att_daily_date   ON attendance.att_daily(work_date, status);
CREATE INDEX idx_att_daily_emp    ON attendance.att_daily(employee_id, work_date);

CREATE TABLE attendance.att_overtime_requests (
    id                BIGSERIAL    PRIMARY KEY,
    employee_id       BIGINT       NOT NULL REFERENCES core.employees(id),
    request_date      DATE         NOT NULL,
    expected_ot_hours NUMERIC(4,2) NOT NULL,
    reason            TEXT         NOT NULL,
    status            VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    workflow_instance_id BIGINT,
    approved_by       BIGINT       REFERENCES core.employees(id),
    approved_at       TIMESTAMPTZ,
    rejection_reason  TEXT,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_att_ot_status  ON attendance.att_overtime_requests(status, request_date);
CREATE INDEX idx_att_ot_emp     ON attendance.att_overtime_requests(employee_id);

-- DTR correction requests
CREATE TABLE attendance.att_dtr_corrections (
    id                BIGSERIAL    PRIMARY KEY,
    employee_id       BIGINT       NOT NULL REFERENCES core.employees(id),
    work_date         DATE         NOT NULL,
    field_to_correct  VARCHAR(30)  NOT NULL,
    original_value    TIMESTAMPTZ,
    corrected_value   TIMESTAMPTZ  NOT NULL,
    reason            TEXT         NOT NULL,
    status            VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    reviewed_by       BIGINT       REFERENCES core.users(id),
    reviewed_at       TIMESTAMPTZ,
    review_remarks    TEXT,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
