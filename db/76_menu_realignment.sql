-- ================================================================
-- HCM360 — 76: MENU REALIGNMENT
--
-- Reorganises core.page_registry into 16 industry-standard nav_groups
-- (Workday / SAP SuccessFactors / Oracle HCM / BambooHR taxonomy)
-- while keeping LGU/CSC labels at the page level (PDS, SALN, PBB,
-- IPCR, OPCR, Plantilla, etc.).
--
-- Idempotent: every UPDATE is keyed on `path`, so re-running this
-- migration leaves the table in the same state.
--
-- Final group set (render order):
--   Home, My Workspace, Employee Records, Time & Attendance,
--   Leave & Absence, Recruitment & Onboarding, Performance,
--   Learning & Development, Compensation & Rewards, Payroll,
--   Health & Safety, Employee Relations, Workforce Planning,
--   Analytics & Reports, AI Assistants, Administration.
-- ================================================================
BEGIN;

-- ── Group reassignments ───────────────────────────────────────────
UPDATE core.page_registry SET nav_group = 'Home'
 WHERE path IN ('/', '/portal');

UPDATE core.page_registry SET nav_group = 'My Workspace'
 WHERE path IN (
   '/me','/me/inbox','/tasks/','/tasks/team','/my-team',
   '/me/leaves','/me/attendance','/me/payslips','/me/certificates',
   '/me/pds','/me/saln',
   '/offboarding/exit-interview','/offboarding/clearance'
 );

UPDATE core.page_registry SET nav_group = 'Employee Records'
 WHERE path IN (
   '/employees','/pds/','/lgu-contracts/',
   '/dms/','/dms/checklist','/dms/requests','/dms/retention',
   '/dms/certificate-requests','/dms/saln'
 );

UPDATE core.page_registry SET nav_group = 'Time & Attendance'
 WHERE path IN (
   '/attendance/dtr','/attendance/overtime','/attendance/alerts',
   '/attendance/shifts','/attendance/shift-assignments','/checkin/'
 );

UPDATE core.page_registry SET nav_group = 'Leave & Absence'
 WHERE path IN (
   '/leave','/leave/requests','/leave/balances',
   '/leave/travel-orders','/leave/locator','/leave/cto',
   '/leave/cs-form-6','/travel-orders/','/locator-slips/'
 );

UPDATE core.page_registry SET nav_group = 'Recruitment & Onboarding'
 WHERE path LIKE '/rsp/%';

UPDATE core.page_registry SET nav_group = 'Performance'
 WHERE path LIKE '/pm/%';

UPDATE core.page_registry SET nav_group = 'Learning & Development'
 WHERE path LIKE '/ld/%' OR path = '/learning/nrf';

UPDATE core.page_registry SET nav_group = 'Compensation & Rewards'
 WHERE path LIKE '/rr/%'
    OR path IN ('/step-increments/','/retirement/','/rewards/loyalty');

UPDATE core.page_registry SET nav_group = 'Payroll'
 WHERE path LIKE '/payroll%';

UPDATE core.page_registry SET nav_group = 'Health & Safety'
 WHERE path LIKE '/health/%';

UPDATE core.page_registry SET nav_group = 'Employee Relations'
 WHERE path LIKE '/discipline/%';

UPDATE core.page_registry SET nav_group = 'Workforce Planning'
 WHERE path IN ('/workforce-planning/','/orgchart/');

UPDATE core.page_registry SET nav_group = 'Analytics & Reports'
 WHERE path IN (
   '/analytics','/reports','/reports/headcount','/reports/demographics',
   '/reports/eligibility','/reports/attrition-risk',
   '/reports/saved','/reports/scheduled','/reports/builder',
   '/admin/insights-library'
 );

UPDATE core.page_registry SET nav_group = 'AI Assistants'
 WHERE path LIKE '/ai/%';

UPDATE core.page_registry SET nav_group = 'Administration'
 WHERE path IN (
   '/admin/users','/admin/access-matrix','/admin/employee-groups',
   '/admin/tasks','/admin/task-templates','/admin/themes',
   '/admin/branding','/admin/reference','/admin/demo-data',
   '/admin/privacy','/admin/tours','/admin/access-requests',
   '/admin/checkin-settings','/admin/retirement-rules',
   '/admin/saln-settings','/admin/esignature-settings',
   '/workflow'
 );

-- ── Module-tag fixes (sibling pages used inconsistent module codes) ─
UPDATE core.page_registry SET module = 'pm'    WHERE path = '/pm/ipcr/templates';
UPDATE core.page_registry SET module = 'rr'    WHERE path = '/rewards/loyalty';
UPDATE core.page_registry SET module = 'admin' WHERE path IN (
   '/admin/tasks','/admin/task-templates','/admin/employee-groups'
);

COMMIT;
