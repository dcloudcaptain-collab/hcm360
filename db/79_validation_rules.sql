-- ================================================================
-- HCM360 — 79: HR VALIDATION RULES (industry-standard, bypassable)
--
-- Two-level bypass model (Workday/SAP-style):
--   1. Master switch  core.validation_settings.master_enforce
--      • TRUE  → individual rule's is_enforced is honoured
--      • FALSE → ALL rules degrade to WARN; nothing blocks save
--   2. Per-rule        core.validation_rules.is_enforced
--      • TRUE  → rule blocks save when its check fails (severity = ERROR)
--      • FALSE → rule still runs but only emits a WARN (save proceeds)
--
-- The toggle UI at /admin/validations is restricted to SUPER_ADMIN
-- and IT_ADMIN.
--
-- Idempotent: safe to re-run.
-- ================================================================
BEGIN;

-- ── Settings (single-row) ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS core.validation_settings (
  id                INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  master_enforce    BOOLEAN  NOT NULL DEFAULT TRUE,
  updated_by        BIGINT   REFERENCES core.users(id),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
INSERT INTO core.validation_settings (id, master_enforce)
VALUES (1, TRUE)
ON CONFLICT (id) DO NOTHING;

-- ── Rules registry ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS core.validation_rules (
  id                BIGSERIAL PRIMARY KEY,
  rule_code         VARCHAR(20) NOT NULL UNIQUE,
  category          VARCHAR(40) NOT NULL,            -- EMPLOYEE, LEAVE, DTR, COMPENSATION
  label             VARCHAR(120) NOT NULL,           -- short admin-UI label
  description       TEXT,                            -- longer admin-UI explanation
  severity          VARCHAR(10) NOT NULL DEFAULT 'ERROR' CHECK (severity IN ('ERROR','WARN')),
  is_enforced       BOOLEAN NOT NULL DEFAULT TRUE,   -- if FALSE, severity becomes WARN
  fail_message      VARCHAR(300) NOT NULL,           -- shown to user when rule fails
  sort_order        INT NOT NULL DEFAULT 100,
  updated_by        BIGINT   REFERENCES core.users(id),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS validation_rules_category_idx ON core.validation_rules(category, sort_order);

-- ── Seed: 23 industry-standard HR validation rules ────────────────
INSERT INTO core.validation_rules (rule_code, category, label, description, severity, is_enforced, fail_message, sort_order) VALUES
-- Employee record
('E001','EMPLOYEE','First name required',     'Personnel record must carry a given name.',                       'ERROR', TRUE,  'First name is required.',                       10),
('E002','EMPLOYEE','Last name required',      'Personnel record must carry a surname.',                          'ERROR', TRUE,  'Last name is required.',                        20),
('E003','EMPLOYEE','Employee number required','Each employee must have a unique organisational number.',         'ERROR', TRUE,  'Employee number is required.',                  30),
('E004','EMPLOYEE','Employee number unique',  'Employee numbers must be unique within the company.',             'ERROR', TRUE,  'This employee number already exists.',          40),
('E005','EMPLOYEE','Hire date required',      'A hire/appointment date is required for tenure calculations.',    'ERROR', TRUE,  'Hire date is required.',                        50),
('E006','EMPLOYEE','Hire date not in future', 'Hire date should not be in the future (unless onboarding-pending).', 'ERROR', TRUE,  'Hire date cannot be in the future.',          60),
('E007','EMPLOYEE','DOB not in future',       'Date of birth must be a past date.',                              'ERROR', TRUE,  'Date of birth cannot be in the future.',        70),
('E008','EMPLOYEE','Minimum age 15',          'Philippine Labor Code minimum age for employment is 15.',         'ERROR', TRUE,  'Employee must be at least 15 years old.',       80),
('E009','EMPLOYEE','Email format valid',      'Work email must follow standard email format.',                   'ERROR', TRUE,  'Work email is not a valid email address.',      90),
('E010','EMPLOYEE','Mobile format valid',     'Mobile number should match Philippine format (+63… or 09…).',     'WARN',  TRUE,  'Mobile number does not match PH format (+63XXXXXXXXXX or 09XXXXXXXXX).', 100),
('E011','EMPLOYEE','Manager not self',        'An employee cannot be their own immediate supervisor.',           'ERROR', TRUE,  'Immediate supervisor cannot be the employee themselves.', 110),
('E012','EMPLOYEE','Termination ≥ hire',      'Termination date must be on or after the hire date.',             'ERROR', TRUE,  'Termination date cannot precede the hire date.',120),
-- Leave request
('L001','LEAVE',   'Start ≤ end',             'Leave start date must be on or before the end date.',             'ERROR', TRUE,  'Leave start date must be on or before end date.', 10),
('L002','LEAVE',   'Sufficient balance',      'Requested days cannot exceed the employee''s available leave balance.', 'ERROR', TRUE,  'Insufficient leave balance for this request.',     20),
('L003','LEAVE',   'No overlap',              'Leave dates cannot overlap an already-approved leave.',           'ERROR', TRUE,  'These dates overlap an existing approved leave.',  30),
('L004','LEAVE',   'Not retroactive',         'Leave must be filed on or before the start date (unless emergency).', 'WARN',  TRUE,  'Leave start date is in the past (retroactive filing).', 40),
('L005','LEAVE',   'Includes a working day',  'At least one of the requested days must be a working day.',       'WARN',  TRUE,  'No working days within the requested range.',   50),
-- DTR / Attendance
('T001','DTR',     'Time-in < Time-out',      'A DTR entry''s clock-out must be after its clock-in.',            'ERROR', TRUE,  'Time-in must be earlier than time-out.',        10),
('T002','DTR',     'Total hours ≤ 24',        'A single DTR entry cannot exceed 24 hours.',                      'ERROR', TRUE,  'Total worked hours cannot exceed 24.',          20),
('T003','DTR',     'Pay period open',         'DTR can only be edited within an active (un-locked) pay period.', 'ERROR', TRUE,  'This pay period is locked.',                    30),
('T004','DTR',     'No shift overlap',        'Shift assignments must not overlap for the same employee.',       'ERROR', TRUE,  'This shift overlaps another assigned shift.',   40),
-- Compensation
('C001','COMPENSATION','Step-inc tenure 3y',  'Step increment requires 3 years tenure since last increment.',    'ERROR', TRUE,  'Step increment requires 3 years of continuous service.', 10),
('C002','COMPENSATION','Salary within band',  'Proposed salary must fall within the assigned job grade band.',   'ERROR', TRUE,  'Salary is outside the job grade pay band.',     20),
('C003','COMPENSATION','Loan ≤ max',          'Loan amount cannot exceed the configured maximum (default: 6× monthly salary).', 'ERROR', TRUE,  'Loan amount exceeds the allowed maximum.',  30),
('C004','COMPENSATION','Effective date',      'Effective date should not be backdated (unless retroactive flag is set).', 'WARN',  TRUE,  'Effective date is in the past (retroactive change).', 40)
ON CONFLICT (rule_code) DO UPDATE SET
  category    = EXCLUDED.category,
  label       = EXCLUDED.label,
  description = EXCLUDED.description,
  severity    = EXCLUDED.severity,
  fail_message= EXCLUDED.fail_message,
  sort_order  = EXCLUDED.sort_order;
-- Note: is_enforced is NOT overwritten on conflict — preserves admin overrides.

-- ── Register the admin page ───────────────────────────────────────
INSERT INTO core.page_registry (path, title, module, nav_group, nav_label, nav_icon, nav_order, is_visible)
VALUES ('/admin/validations', 'Validation Rules', 'admin', 'Administration', 'Validation Rules', '✅', 75, TRUE)
ON CONFLICT (path) DO UPDATE SET
  title      = EXCLUDED.title,
  module     = EXCLUDED.module,
  nav_group  = EXCLUDED.nav_group,
  nav_label  = EXCLUDED.nav_label,
  nav_icon   = EXCLUDED.nav_icon,
  is_visible = EXCLUDED.is_visible;

-- Grant access: SUPER_ADMIN, IT_ADMIN — view + write (toggle).
-- HR_MANAGER gets read-only via the existing 'admin' module read grant.
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r, p.id, TRUE
FROM unnest(ARRAY['SUPER_ADMIN','IT_ADMIN']) AS r,
     core.page_registry p
WHERE p.path = '/admin/validations'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = TRUE;

-- Explicit deny for every other current role
INSERT INTO core.role_page_access (role_code, page_id, can_access)
SELECT r, p.id, FALSE
FROM unnest(ARRAY['EMPLOYEE','MANAGER','EXECUTIVE',
                  'HR_RECRUITER','HR_TIME_OFFICER','HR_COMP_OFFICER',
                  'HR_LEARNING_OFFICER','HR_PERFORMANCE_OFFICER',
                  'HR_RELATIONS_OFFICER','HR_RECORDS_OFFICER',
                  'HR_MANAGER','HR_ADMIN','PAYROLL_OFFICER']) AS r,
     core.page_registry p
WHERE p.path = '/admin/validations'
ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = FALSE;

COMMIT;
