-- ══════════════════════════════════════════════════════════════════════
-- 64 · Wellness Program enhancements
-- ══════════════════════════════════════════════════════════════════════
-- Adds attendance tracking + feedback rating on top of the existing
-- wellness_enrollments table. Also extends wellness_programs with
-- location + schedule_notes so admin can communicate "where / when".
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE health.wellness_enrollments
    ADD COLUMN IF NOT EXISTS attended_at      TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS feedback_rating  SMALLINT
        CHECK (feedback_rating IS NULL OR feedback_rating BETWEEN 1 AND 5),
    ADD COLUMN IF NOT EXISTS enrolled_by      BIGINT REFERENCES core.users(id);

CREATE INDEX IF NOT EXISTS idx_wellness_enroll_program
    ON health.wellness_enrollments(program_id);
CREATE INDEX IF NOT EXISTS idx_wellness_enroll_emp
    ON health.wellness_enrollments(employee_id);

ALTER TABLE health.wellness_programs
    ADD COLUMN IF NOT EXISTS location        VARCHAR(300),
    ADD COLUMN IF NOT EXISTS schedule_notes  TEXT,
    ADD COLUMN IF NOT EXISTS updated_at      TIMESTAMPTZ DEFAULT NOW();

-- Uniqueness for safe re-enroll
DO $$
BEGIN
  BEGIN
    ALTER TABLE health.wellness_enrollments
      ADD CONSTRAINT wellness_enrollments_program_employee_key
      UNIQUE (program_id, employee_id);
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;

-- Feature registry for admin capabilities
INSERT INTO core.feature_registry (code, name, description, module, is_enabled, feature_type, action_type, page_path)
VALUES
    ('WELLNESS_CREATE',       'Create Wellness Program', 'Create a new wellness program',
        'health', TRUE, 'ACTION', 'CREATE', '/health/wellness/new'),
    ('WELLNESS_ASSIGN',       'Assign Attendees', 'Bulk-assign employees/departments/groups to a program',
        'health', TRUE, 'ACTION', 'EDIT',   '/health/wellness'),
    ('WELLNESS_ATTENDANCE',   'Mark Attendance', 'Record attendance for wellness program enrollees',
        'health', TRUE, 'ACTION', 'EDIT',   '/health/wellness'),
    ('WELLNESS_FEEDBACK_VIEW','View Feedback', 'View aggregated feedback + ratings per program',
        'health', TRUE, 'ACTION', 'VIEW',   '/health/wellness')
ON CONFLICT (code) DO UPDATE SET
    name=EXCLUDED.name, description=EXCLUDED.description, is_enabled=TRUE;

-- Grant to SUPER_ADMIN + HR_ADMIN
INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.role_code, f.id, TRUE
FROM core.feature_registry f
CROSS JOIN (VALUES ('SUPER_ADMIN'),('HR_ADMIN')) AS r(role_code)
WHERE f.code IN ('WELLNESS_CREATE','WELLNESS_ASSIGN','WELLNESS_ATTENDANCE','WELLNESS_FEEDBACK_VIEW')
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = TRUE;

-- All employees can submit feedback
INSERT INTO core.feature_registry (code, name, description, module, is_enabled, feature_type, action_type, page_path)
VALUES
    ('WELLNESS_FEEDBACK_SUBMIT', 'Submit Feedback', 'Submit feedback on a wellness program you attended',
        'health', TRUE, 'ACTION', 'CREATE', '/health/wellness')
ON CONFLICT (code) DO UPDATE SET is_enabled = TRUE;

INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
SELECT r.role_code, f.id, TRUE
FROM core.feature_registry f
CROSS JOIN (VALUES ('SUPER_ADMIN'),('HR_ADMIN'),('EXECUTIVE'),('MANAGER'),('EMPLOYEE')) AS r(role_code)
WHERE f.code = 'WELLNESS_FEEDBACK_SUBMIT'
ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = TRUE;
