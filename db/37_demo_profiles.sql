-- ================================================================
-- HCM360 HRIS — 37: DEMO PROFILE SYSTEM
-- Toggleable demo scenarios for all modules
-- ================================================================
SET search_path TO core, public;

CREATE TABLE IF NOT EXISTS core.demo_profiles (
    id              BIGSERIAL    PRIMARY KEY,
    code            VARCHAR(30)  NOT NULL UNIQUE,
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    employee_count  INTEGER      NOT NULL DEFAULT 20,
    color           VARCHAR(10)  NOT NULL DEFAULT '#4f46e5',
    icon            VARCHAR(10)  NOT NULL DEFAULT '📋',
    scenario_notes  JSONB        NOT NULL DEFAULT '[]',
    is_active       BOOLEAN      NOT NULL DEFAULT FALSE,
    loaded_at       TIMESTAMPTZ,
    loaded_by       BIGINT       REFERENCES core.users(id),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Ensure only one profile active at a time
CREATE UNIQUE INDEX IF NOT EXISTS idx_demo_profiles_active
    ON core.demo_profiles (is_active) WHERE is_active = TRUE;

INSERT INTO core.demo_profiles (code, name, description, employee_count, color, icon, scenario_notes) VALUES
('QUICK_START',
 'Quick Start',
 'Fresh go-live scenario — minimal history, a few pending items. Ideal for first-time demo.',
 20, '#16a34a', '🚀',
 '[
   "20 base employees across 7 departments",
   "10 days attendance data, 2 late arrivals",
   "3 leave requests (2 pending, 1 approved)",
   "1 open pay period, no completed runs",
   "3 vacant plantilla items, 1 job posting, 2 applicants",
   "1 PM cycle in PLANNING stage",
   "2 training programs, 1 session, 5 enrollments",
   "Step increment schedule generated",
   "201 file document requests at ~60% completion (10/16 items submitted)",
   "No discipline cases (clean start)",
   "1 PE schedule created, no results yet"
 ]'::jsonb),

('MID_CYCLE',
 'Mid-Cycle Operations',
 'Active operations — mixed statuses, approvals in progress, 6 months of history. Best for feature showcase.',
 30, '#2563eb', '⚡',
 '[
   "30 employees (+10 new hires since go-live)",
   "60 working days attendance with lateness patterns",
   "15+ leave requests across all statuses + maternity (RA 11210)",
   "6 pay periods, 5 completed runs with payslips + GSIS/PagIBIG remittances",
   "8 plantilla items, 3 job postings, 8 applicants in pipeline",
   "2 PM cycles: 2025 Year-End COMPLETED + 2026 Mid-Year",
   "8 IPCRs rated with Q/E/T scores",
   "5 training programs with sessions, TNA linked to IPCR gaps",
   "Step-inc eligible, PBB computed for 8 employees",
   "2 discipline cases (LIGHT + LESS_GRAVE)",
   "PE completed for 15 employees, 1 incident"
 ]'::jsonb),

('YEAR_END',
 'Year-End Audit Ready',
 'Full annual cycle — comprehensive history for CSC/COA audit readiness. Complete data across all modules.',
 45, '#d97706', '🏆',
 '[
   "45 employees (full municipal LGU complement)",
   "12+ months attendance history (~300 working days)",
   "40+ leave requests with carry-over, maternity, paternity, SPL",
   "24 pay periods for 2025, payslips, 13th-month pay, GSIS/PagIBIG/BIR remittances",
   "Full plantilla (45 filled), 14 applicants, 2 hired, PSB deliberation + appointment",
   "3 PM cycles, succession matrix, 6 IDP plans",
   "10 training programs, 14-skill matrix, scholarships, IDP actions linked to TNA",
   "Full step-inc history, loyalty awards, PBB released, retirement alerts",
   "4 discipline cases spanning full CSC lifecycle (decided + hearing)",
   "2 PE schedules, 3 incidents, 12 health certificates (6 expired)",
   "~95% document completion (SALN pending), onboarding checklists for 15 new hires"
 ]'::jsonb)
('FULL_FEATURES',
 'Full Features LGU',
 'Complete municipal LGU with 2 years of data across every module. Onboarding to retirement, full payroll history, discipline cases, recruitment pipeline, and more.',
 60, '#dc2626', '🏛️',
 '[
   "60 employees (full municipal LGU with 7 departments + executive office)",
   "2 years attendance history (Apr 2024 – Mar 2026, ~500 working days)",
   "80+ leave requests across all 15 leave types including Maternity/Paternity/VAWC",
   "48 pay periods (24 months), completed runs, 13th-month, gov remittances, loans",
   "3 completed PM cycles + 1 active, IPCRs with ratings, IDP plans, succession matrix",
   "15 training programs, 20-skill matrix, 3 scholarships, IDP→TNA linking",
   "Full step-increment history, loyalty awards (5/10/15/20yr), PBB 2024+2025, retirement alerts",
   "60-position plantilla, 20 applicants, 4 hired, PSB deliberations, next-in-rank",
   "6 discipline cases (Light/Less Grave/Grave), full CSC lifecycle including appeal",
   "3 PE schedules, 5 incidents, 20 health certificates, 2 wellness programs",
   "100% 201-file completion, certificate requests, service record snapshots",
   "15 completed + 5 in-progress onboarding checklists, buddy assignments",
   "HR_ADMIN, MANAGER, EXECUTIVE demo users for role-based testing"
 ]'::jsonb)

ON CONFLICT (code) DO UPDATE SET
    scenario_notes = EXCLUDED.scenario_notes,
    description = EXCLUDED.description,
    employee_count = EXCLUDED.employee_count,
    color = EXCLUDED.color,
    icon = EXCLUDED.icon;
