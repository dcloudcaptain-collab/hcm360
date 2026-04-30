#!/usr/bin/env python3
"""
LGU Mariveles Gap Analysis — Excel Generator (canonical source of truth)

Run:
    python3 doc/lgu/generate.py

Output:
    doc/lgu/LGU_Mariveles_Gap_Analysis_AsOf_<YYYY-MM-DD>.xlsx

Behavior:
  * Each run is dated. Today's file is the "current" snapshot.
  * Any prior-dated snapshots in doc/lgu/ are automatically moved to
    doc/lgu/archive/ so you always have a full history.
  * To UPDATE the analysis: edit the MATRIX, GAP_BACKLOG, and
    PARTIAL_BACKLOG lists below — they are the single source of truth.
    Re-run this script to produce a freshly dated snapshot.
"""
import shutil
from datetime import date
from pathlib import Path
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

HERE = Path(__file__).parent
ARCHIVE = HERE / 'archive'
TODAY = date.today()
FNAME = f'LGU_Mariveles_Gap_Analysis_AsOf_{TODAY.isoformat()}.xlsx'
OUT = HERE / FNAME

# ── Styles ────────────────────────────────────────────────────────────
BLUE = 'FF1E40AF'
INDIGO = 'FF4F46E5'
WHITE = 'FFFFFFFF'
LIGHT_GRAY = 'FFF3F4F6'
BORDER_GRAY = 'FFE5E7EB'

GREEN_FILL = PatternFill('solid', start_color='FFDCFCE7')   # COVERED bg
AMBER_FILL = PatternFill('solid', start_color='FFFEF3C7')   # PARTIAL bg
RED_FILL = PatternFill('solid', start_color='FFFEE2E2')     # GAP bg
GREEN_FONT = Font(name='Arial', size=10, color='FF166534', bold=True)
AMBER_FONT = Font(name='Arial', size=10, color='FF92400E', bold=True)
RED_FONT = Font(name='Arial', size=10, color='FF991B1B', bold=True)

HEADER_FILL = PatternFill('solid', start_color=BLUE)
HEADER_FONT = Font(name='Arial', size=11, bold=True, color=WHITE)
TITLE_FONT = Font(name='Arial', size=16, bold=True, color=BLUE)
SUB_FONT = Font(name='Arial', size=10, italic=True, color='FF6B7280')
NORMAL_FONT = Font(name='Arial', size=10)
BOLD_FONT = Font(name='Arial', size=10, bold=True)

THIN = Side(border_style='thin', color=BORDER_GRAY)
BORDER = Border(left=THIN, right=THIN, top=THIN, bottom=THIN)

CENTER = Alignment(horizontal='center', vertical='center', wrap_text=True)
LEFT = Alignment(horizontal='left', vertical='top', wrap_text=True)
LEFT_CTR = Alignment(horizontal='left', vertical='center', wrap_text=True)


# ── Data: Full gap matrix ────────────────────────────────────────────
# Format: (Section, Requirement, Status, Module, Page/Route, Gap/Notes, Priority)
MATRIX = [
    # Section 1 — CSC PRIME-HRM Level 2
    ('1. CSC PRIME-HRM Level 2', 'Recruitment, Selection, Placement (RSP)', 'COVERED',
     'Recruitment', '/recruitment',
     'Requisitions, candidates, CSC eligibilities, qualification standards', 'Low'),
    ('1. CSC PRIME-HRM Level 2', 'Performance Management (PM)', 'COVERED',
     'Performance Management', '/performance',
     'Review cycles, KPIs, competency-based evaluation', 'Low'),
    ('1. CSC PRIME-HRM Level 2', 'Learning and Development (L&D)', 'COVERED',
     'Learning & Development', '/learning',
     'Training catalog, enrollments, certifications', 'Low'),
    ('1. CSC PRIME-HRM Level 2', 'Rewards and Recognition (R&R)', 'COVERED',
     'Rewards & Recognition', '/rewards',
     'Awards, praise wall, nominations', 'Low'),
    ('1. CSC PRIME-HRM Level 2', 'CSC PRIME-HRM Level 2 certification alignment', 'PARTIAL',
     'All four modules', '/admin/reference',
     'Modules present; formal CSC audit alignment pending', 'High'),

    # Section 2 — Report Generating System (Functional)
    ('2. Report Generating (Functional)', 'Data sources — pull from multiple DBs/systems', 'COVERED',
     'Services', 'services/db.py + reporting_service',
     'Centralized psycopg2 pool with view-based aggregation', 'Low'),
    ('2. Report Generating (Functional)', 'Report design (drag-drop / designer)', 'PARTIAL',
     'Analytics', '/reports (report builder)',
     'Saved queries + parameters; drag-drop UI would enhance', 'Medium'),
    ('2. Report Generating (Functional)', 'Data analysis (query, analyze, summarize)', 'COVERED',
     'Analytics', '/reports/demographics, /reports',
     'Materialized views + SQL-driven metrics', 'Low'),
    ('2. Report Generating (Functional)', 'Manual + automated report generation', 'COVERED',
     'Analytics + Reminders', '/admin/reminders, /reports',
     'Reminder rules can trigger scheduled reports', 'Low'),
    ('2. Report Generating (Functional)', 'Output: screen, PDF, spreadsheet, print', 'COVERED',
     'Reporting Service', 'services/reporting_service.py',
     'PDF via ReportLab; CSV/Excel export available', 'Low'),
    ('2. Report Generating (Functional)', 'Output: email distribution', 'PARTIAL',
     'Reminders', '/admin/reminders',
     'Reminder engine exists; SMTP config must be wired in .env', 'Medium'),
    ('2. Report Generating (Functional)', 'Security — authentication & authorization', 'COVERED',
     'Access Service', '/admin/access-matrix',
     '3-tier RBAC (page, feature, modification)', 'Low'),

    # Section 2 (Non-functional)
    ('2. Report Generating (Non-Functional)', 'Performance (speed, load response)', 'COVERED',
     'Infrastructure', 'docker-compose.yml',
     'PG tuned (shared_buffers 256MB, max_connections 200)', 'Low'),
    ('2. Report Generating (Non-Functional)', 'Scalability (data volume, user growth)', 'COVERED',
     'Infrastructure', 'docker-compose.yml',
     'Stateless web tier, pool-based DB access, volume-backed', 'Low'),
    ('2. Report Generating (Non-Functional)', 'Reliability (error handling, integrity, audit)', 'COVERED',
     'Audit Logs', 'audit_logs schema',
     'Trigger-based change capture on all mutations', 'Low'),

    # Section 3 — Attendance Monitoring
    ('3. Attendance Monitoring', 'Online leave application & approval', 'COVERED',
     'Leave Management', '/leave/requests, /me/leaves',
     'Full workflow: PENDING → APPROVED → balance debit', 'Low'),
    ('3. Attendance Monitoring', 'Compensatory Time Off (CTO) workflow', 'PARTIAL',
     'Leave Management', '/leave/types',
     'Add CTO to lv_types with accrual rules tied to OT', 'Medium'),
    ('3. Attendance Monitoring', 'Travel Order — online application & pre-approval', 'COVERED',
     'Core HR', '/travel-orders/, /travel-orders/new',
     'core.travel_orders with 2-level approval (supervisor → head); printable TO form', 'Low'),
    ('3. Attendance Monitoring', 'Request for Training / Office Order', 'PARTIAL',
     'L&D + Workflow', '/learning/enrollments',
     'Enrollments exist; office-order form template needed', 'Medium'),
    ('3. Attendance Monitoring', 'Locator Slip with pre-approval', 'COVERED',
     'Core HR', '/locator-slips/, /locator-slips/new',
     'core.locator_slips with supervisor approve/reject + time-out/return tracking', 'Low'),
    ('3. Attendance Monitoring', 'Pre-approved items auto-reflect on DTR + invalidate overlaps', 'COVERED',
     'Attendance', '/attendance/daily',
     'Leave requests already block DTR-day conflicts', 'Low'),
    ('3. Attendance Monitoring', 'Mobile / desktop time-tracking with OT + remote check-in', 'PARTIAL',
     'Attendance', '/me/attendance',
     'Web time-in/out exists; native mobile + remote check-in need build', 'High'),
    ('3. Attendance Monitoring', 'Online DTR check, acknowledge, approve', 'COVERED',
     'Attendance', '/attendance/daily, /me/attendance',
     'Approval workflow wired to supervisor', 'Low'),
    ('3. Attendance Monitoring', 'Civil Service Form No. 6 (revised 2020) — strict implementation', 'COVERED',
     'Leave Management', '/leave/cs-form-6, /leave/cs-form-6/new',
     'Extended lv_requests with CSC fields (whereabouts, commutation, recommend, head action); printable CSC form', 'Low'),
    ('3. Attendance Monitoring', 'Travel Order + Locator Slip pre-approval & monitoring', 'COVERED',
     'Core HR', '/travel-orders/, /locator-slips/',
     'Dedicated modules for both with pre-approval workflow and DTR linkage', 'Low'),
    ('3. Attendance Monitoring', 'Monitor habitual tardiness & AWOL', 'COVERED',
     'Attendance', '/attendance/alerts',
     'att_alerts generates alerts on thresholds', 'Low'),
    ('3. Attendance Monitoring', 'Auto-alert when VL < 5 days or tardiness reaches 7x', 'PARTIAL',
     'Reminders', '/admin/reminders',
     'Threshold rules configurable; specific LGU thresholds to be seeded', 'Medium'),
    ('3. Attendance Monitoring', 'Face-recognition attendance / automated record', 'COVERED',
     'Attendance', '/checkin/, /checkin/enroll',
     'Browser face-api.js 128-d descriptor match; threshold configurable at /admin/checkin-settings', 'Low'),
    ('3. Attendance Monitoring', 'Shift schedule mgmt (security, rescue, medical, on-call)', 'COVERED',
     'Attendance', '/attendance/shifts, /attendance/shift-assignments',
     'Shift types + per-employee assignments', 'Low'),
    ('3. Attendance Monitoring', 'Flag raising / lowering mobile check-in with photo', 'COVERED',
     'Attendance', '/checkin/ (activity=flag_raising|flag_lowering)',
     'Geolocation + face check-in with activity selector; configurable activity types', 'Low'),

    # Section 4 — Recruitment
    ('4. Recruitment', 'Auto-notify qualified next-in-rank of posted vacancy', 'PARTIAL',
     'Recruitment + Reminders', '/recruitment/requisitions',
     'Requisition posting exists; next-in-rank ranking rule needs logic', 'Medium'),
    ('4. Recruitment', 'Pre-assess online applications vs CSC qualification standards', 'COVERED',
     'Recruitment', '/recruitment/candidates',
     'rsp.qualification_standards + rsp.csc_eligibilities', 'Low'),
    ('4. Recruitment', 'Retain applications for 5 years', 'PARTIAL',
     'DMS + Retention', '/admin/reference-data/retention_policies',
     'Set retention policy to 5 years for recruitment docs', 'Medium'),
    ('4. Recruitment', 'Source candidates — internal/external + 3 conspicuous places + job portals', 'PARTIAL',
     'Recruitment', '/recruitment/requisitions',
     'Internal + external tracked; job-portal API integration additional', 'Medium'),
    ('4. Recruitment', 'Online approval — JO, LSB, Barangay Health Worker/Nutritionist Scholar contracts', 'COVERED',
     'Core HR', '/lgu-contracts/, /lgu-contracts/new',
     'core.lgu_contract_types seeded with JO/LSB/BHW/NS; core.lgu_contracts with approval workflow & printable contract', 'Low'),

    # Section 4.1 — Onboarding/Offboarding
    ('4.1 Onboarding / Offboarding', 'Digital onboarding — forms, checklists, policy ack, equipment, training', 'COVERED',
     'Onboarding', '/me/onboarding',
     'Checklist with stages (ACTIVATED, etc.)', 'Low'),
    ('4.1 Onboarding / Offboarding', 'Electronic signature on documents', 'COVERED',
     'Core', '/admin/esignature-settings, /esign/<kind>/<id>/sign',
     'Canvas pad (in-browser) + DocuSign adapter (stub); core.document_signatures + core.esignature_settings', 'Low'),
    ('4.1 Onboarding / Offboarding', 'Offboarding — exit interview, CS Form No. 7, transition, asset return, access removal, archive', 'COVERED',
     'Core HR', '/offboarding/exit-interview, /offboarding/clearance',
     'Exit interview form with ratings; CS Form 7 clearance with 9 default signatory items + auto-CLEARED status', 'Low'),

    # Section 5 — Performance Management
    ('5. Performance Management', 'Goal-setting & progress tracking for employees, dept heads, PM team', 'COVERED',
     'Performance Management', '/performance/goals',
     'KPIs + competencies per cycle', 'Low'),
    ('5. Performance Management', 'IPCR & OPCR periodic review', 'PARTIAL',
     'Performance Management', '/performance/reviews',
     'Review engine exists; IPCR/OPCR CSC templates to be added', 'High'),
    ('5. Performance Management', 'Succession planning — critical roles + internal candidates', 'PARTIAL',
     'Performance + Workforce Planning', '/workforce-planning, /performance',
     'Scenarios exist; succession slate UI needs dedicated page', 'Medium'),

    # Section 6 — L&D
    ('6. Learning and Development', 'Post available trainings/seminars; track needs', 'COVERED',
     'L&D', '/learning/catalog, /learning/enrollments',
     'Catalog with prerequisites, needs-based flagging', 'Low'),
    ('6. Learning and Development', 'Training attendance via mobile with geotag + AM/PM + date', 'COVERED',
     'L&D', '/learning/sessions/<id>/checkin',
     'Mobile camera + GPS check-in with AM/PM shift_period column on lrn_attendance_logs', 'Low'),
    ('6. Learning and Development', 'Online Narrative Report Form before acknowledgment', 'COVERED',
     'L&D', '/learning/nrf, /learning/nrf/new/<enrollment_id>',
     'Form + backend tied to enrollment via lrn_narrative_reports; LD_NRF_APPROVAL workflow', 'Low'),

    # Section 7 — R&R (Loyalty)
    ('7.1 Loyalty Service Award', 'Auto-identify employees reaching 10 years continuous service', 'COVERED',
     'R&R', '/rewards/loyalty',
     'Scan creates rwd_loyalty_milestones rows at 10/15/20/25/30 year marks', 'Low'),
    ('7.1 Loyalty Service Award', 'Every 5 years thereafter (15, 20, 25, 30, …)', 'COVERED',
     'R&R', '/rewards/loyalty',
     'Scanner iterates milestones [10,15,20,25,30,35,40] within 180-day horizon', 'Low'),
    ('7.1 Loyalty Service Award', 'Auto Notice / Memo generation for loyalty award', 'COVERED',
     'R&R', '/rewards/loyalty/<id>/memo.pdf',
     'ReportLab memo generator with memo_no sequencing; status transitions ELIGIBLE → AWARDED', 'Low'),

    # Section 7.2 — Step Increment
    ('7.2 Step Increment', 'Auto-track Step Increment eligibility every 3 years', 'COVERED',
     'Core HR', '/step-increments/',
     'core.step_increment_history with /step-increments/scan (DUE/NOTICE_SENT/APPROVED/RECORDED)', 'Low'),
    ('7.2 Step Increment', 'Based on Date of Original Appointment', 'COVERED',
     'Core HR', 'core.employees.date_of_original_appointment',
     'Column added in migration 53; backfilled from date_hired', 'Low'),
    ('7.2 Step Increment', 'Generate Step Increment Due Report', 'COVERED',
     'Core HR', '/step-increments/?status=DUE',
     'Filterable dashboard with due/overdue/coming-soon KPIs', 'Low'),
    ('7.2 Step Increment', 'Generate Step Increment Notice / Memo', 'COVERED',
     'Core HR', '/step-increments/<id>/notice',
     'Notice action transitions DUE → NOTICE_SENT with audit trail', 'Low'),

    # Section 7.3 — Retirement
    ('7.3 Retirement Monitoring', 'Auto-identify approaching retirement with gender breakdown', 'COVERED',
     'Core HR', '/retirement/',
     'core.retirement_tracking + /retirement/scan; KPIs include male/female pending', 'Low'),
    ('7.3 Retirement Monitoring', 'Early Retirement Age 60 / Mandatory 65', 'COVERED',
     'Core HR', '/admin/retirement-rules',
     'core.retirement_rules configurable per company (default 60/65)', 'Low'),
    ('7.3 Retirement Monitoring', 'List of nearing retirement (6 months / 1 year before)', 'COVERED',
     'Core HR', '/retirement/',
     'notice_lead_months setting drives horizon; dashboard lists all UPCOMING rows', 'Low'),
    ('7.3 Retirement Monitoring', 'Retirement Notice / Memo for HR, Employee, Accounting/Budget/Payroll', 'COVERED',
     'Core HR', '/retirement/<id>/notice',
     'Single action generates 3 notice artifacts (HR, Employee, Finance paths)', 'Low'),
    ('7.3 Retirement Monitoring', 'Male/Female breakdown for Age 60+ and 65+', 'COVERED',
     'Analytics', '/reports/demographics, /retirement/',
     'Retirement dashboard KPIs include gender-split pending counts', 'Low'),

    # Section 8 — Payroll
    ('8. Payroll System', 'Payroll automation — salaries, deductions by role/hours', 'COVERED',
     'Payroll', '/payroll/runs',
     'DRAFT → COMPUTING → COMPUTED → APPROVED → POSTED', 'Low'),
    ('8. Payroll System', 'Generate digital payslips', 'COVERED',
     'Payroll', '/payroll/payslips/<id>/pdf, /me/payslips',
     'On-demand PDF via reporting_service', 'Low'),
    ('8. Payroll System', 'Benefits administration portal (integrated with payroll)', 'COVERED',
     'ESS + Payroll', '/me/benefits',
     'Enrollment + employer/employee cost tracking', 'Low'),
    ('8. Payroll System', 'Encode GSIS, Pag-IBIG, Coop, Cash Advance loans', 'COVERED',
     'Payroll', '/payroll/loans',
     'pay_loans with loan_type enum covering all LGU sources', 'Low'),
    ('8. Payroll System', 'Loan details — amount, terms, start date, end date', 'COVERED',
     'Payroll', '/payroll/loans',
     'Standard fields on pay_loans', 'Low'),
    ('8. Payroll System', 'Monthly payment & outstanding balance (manual input)', 'COVERED',
     'Payroll', '/payroll/loans',
     'Amortization schedule + manual override', 'Low'),
    ('8. Payroll System', 'View Employee Loan Profile per personnel', 'COVERED',
     'ESS', '/me/compensation',
     'Active loans shown on compensation page', 'Low'),
    ('8. Payroll System', 'Generate Loan Summary List', 'COVERED',
     'Payroll', '/payroll/loans (export)',
     'CSV/Excel export available', 'Low'),

    # Section 9 — Security
    ('9. Security & Data Governance', 'Role-based permissions (HR, MIS, employees)', 'COVERED',
     'Access Service', '/admin/access-matrix',
     '3-tier: page / feature / modification', 'Low'),
    ('9. Security & Data Governance', 'Audit trails — who edited what, when; access logs', 'COVERED',
     'Audit Logs', 'audit_logs.change_log, audit_logs.access_log',
     'Trigger-based capture', 'Low'),
    ('9. Security & Data Governance', 'Data encryption in transit & at rest + backups / DR', 'PARTIAL',
     'Infrastructure', 'docker-compose.yml + TLS proxy',
     'TLS at reverse proxy; host disk encryption; DR via pg_dump backups/', 'High'),
    ('9. Security & Data Governance', 'Compliance modules — labor laws, tax, data privacy', 'COVERED',
     'Privacy + Payroll', '/admin/privacy, /payroll',
     'RA 10173 field-level privacy; BIR/SSS/PhilHealth/HDMF schedules', 'Low'),
    ('9. Security & Data Governance', 'Archival & retention — auto removal/archiving of old records', 'PARTIAL',
     'DMS', '/admin/reference-data/retention_policies',
     'Policies exist; scheduled archival job to be built', 'Medium'),

    # Section 10 — Employee Records Management
    ('10. Employee Records Management', 'Central searchable employee profile', 'COVERED',
     'Core HR', '/employees, /employees/<id>',
     '201 file with sub-records; global search at /search', 'Low'),
    ('10. Employee Records Management', 'Digital document storage with version control & expiry', 'COVERED',
     'DMS', '/dms, /employees/<id>/documents',
     'document_categories + expiration + retention', 'Low'),
    ('10. Employee Records Management', 'Role / position management; live org chart', 'COVERED',
     'Core HR + Orgchart', '/orgchart, /admin/reference-data/positions',
     'Positions + departments + org chart', 'Low'),
    ('10. Employee Records Management', 'Full lifecycle — recruitment → onboarding → active → transitions → offboarding', 'COVERED',
     'Multiple', '/recruitment, /me/onboarding, /employees, /me/offboarding',
     'End-to-end coverage', 'Low'),
    ('10. Employee Records Management', 'Paperless records with e-signatures, version control, audit', 'PARTIAL',
     'DMS', '/dms',
     'Paperless + audit exists; e-signature integration pending', 'High'),
    ('10. Employee Records Management', 'Employee Masterfile (Personal & Employment)', 'COVERED',
     'Core HR', '/employees/<id>',
     'v_employees_full view exposes everything', 'Low'),
    ('10. Employee Records Management', 'Personal Data Sheet (PDS) storage — CSC template', 'COVERED',
     'Core HR', '/me/pds, /pds/',
     'core.personal_data_sheets (JSONB, versioned); 10-tab form with auto-fill from masterfile; HR verification workflow', 'Low'),
    ('10. Employee Records Management', 'Service Records & Appointment History', 'PARTIAL',
     'Core HR', '/employees/<id>/service-record',
     'Transitions tracked; formal CSC Service Record export pending', 'High'),

    # Section 10.1 — HR Demographics
    ('10.1 HR Demographics (M/F breakdown)', 'Gender Profile — total M/F overall + by dept/office', 'COVERED',
     'Analytics', '/reports/demographics',
     'Demographics dashboard with department split', 'Low'),
    ('10.1 HR Demographics (M/F breakdown)', 'Age Profile — distribution by gender', 'COVERED',
     'Analytics', '/reports/demographics',
     'Age-bucket histogram with gender', 'Low'),
    ('10.1 HR Demographics (M/F breakdown)', 'Status of Appointment — Permanent/Casual/Contractual/JO/COS by sex', 'PARTIAL',
     'Core HR + Analytics', '/admin/reference-data/employment_types',
     'Add JO and COS as employment types; extend report', 'Medium'),
    ('10.1 HR Demographics (M/F breakdown)', 'Rank Classification — Rank-and-File vs Officer/Supervisory M/F', 'PARTIAL',
     'Core HR', 'core.positions',
     'Add rank_classification column to core.positions; feed report', 'Medium'),
    ('10.1 HR Demographics (M/F breakdown)', 'Educational Attainment by gender (Graduate/College/HS/Elementary)', 'PARTIAL',
     'Core HR', 'core.employees.education_level',
     'Field exists; CSC-specific buckets and reporting to add', 'Medium'),
    ('10.1 HR Demographics (M/F breakdown)', 'Eligibility Profile — 1st Level / 2nd Level by gender', 'COVERED',
     'Analytics', '/reports/eligibility',
     'rec_csc_eligibilities.level column + backfill; Level × Gender and Dept × Level cross-tabs', 'Low'),
    ('10.1 HR Demographics (M/F breakdown)', 'Plantilla Summary — filled vs vacant by gender', 'PARTIAL',
     'Workforce Planning', '/workforce-planning',
     'Current vs. planned shown; plantilla report needs gender split', 'Medium'),
    ('10.1 HR Demographics (M/F breakdown)', 'Salary Grade Distribution — count per grade with M/F', 'COVERED',
     'Analytics', '/reports/demographics',
     'Salary grade × gender matrix', 'Low'),
    ('10.1 HR Demographics (M/F breakdown)', 'Training history per employee + summary with gender breakout', 'COVERED',
     'L&D + Analytics', '/reports/training, /learning/attendance',
     'Enrollment & completion data', 'Low'),

    # Section 11 — Reporting / Analytics
    ('11. Reporting, Analytics & Dashboards', 'Real-time dashboards (headcount, turnover, absence, leave trends)', 'COVERED',
     'Analytics', '/ (main), /reports',
     'dashboard_metrics drives role-filtered KPI cards', 'Low'),
    ('11. Reporting, Analytics & Dashboards', 'Pre-built & custom reports; CSV/Excel export', 'COVERED',
     'Analytics', '/reports',
     'Saved queries + parameters; export utilities', 'Low'),
    ('11. Reporting, Analytics & Dashboards', 'Predictive analytics — retention risk, workforce forecast', 'COVERED',
     'Analytics + AI', '/reports/attrition-risk, /workforce-planning, /ai',
     'Attrition scoring v2 heuristic writes to ai.ai_risk_scores; ARIA predict_attrition_risk tool; workforce scenarios', 'Low'),

    # Section 12 — Self-Service & Mobile
    ('12. Self-Service & Mobile', 'All functions accessible on mobile', 'PARTIAL',
     'UI', 'All /me/* pages',
     'Responsive web; native mobile app to enhance', 'High'),
    ('12. Self-Service & Mobile', 'Employee self-service portal', 'COVERED',
     'ESS', '/me, /me/profile, /me/leaves, /me/payslips',
     'Full self-service suite', 'Low'),
    ('12. Self-Service & Mobile', 'Dept head self-service — approve leaves, dashboards, team reports', 'COVERED',
     'MSS', '/team, /team/approvals, /me/inbox',
     'Manager service ready', 'Low'),
    ('12. Self-Service & Mobile', 'Online Request — COE, Service Record, SALN PDF, Appointment PDF', 'COVERED',
     'DMS + Core', '/me/certificates, /me/saln, /rsp/appointments/<id>/pdf',
     'COE + Service Record + SALN (3-mode configurable) + Appointment PDF (CSC Form 33)', 'Low'),

    # Section 13 — Modern / Futuristic
    ('13. Modern / Futuristic Add-Ons', 'Chatbot / self-help assistant', 'COVERED',
     'AI', '/ai/assistant, /ai (redirect)',
     'ARIA streaming chat UI with SSE + 12 built-in tools; /ai redirects to /ai/assistant', 'Low'),
    ('13. Modern / Futuristic Add-Ons', 'AI-driven insights — skill gap, training, attrition risk', 'COVERED',
     'AI', '/reports/attrition-risk, /ai',
     'Attrition heuristic + ARIA natural-language tool; skill gap in workforce planning', 'Low'),
    ('13. Modern / Futuristic Add-Ons', 'Flexible work — hybrid/remote, geolocation clock-in, virtual check-in', 'GAP',
     'Attendance', 'mobile app (to build)',
     'Work arrangement tracked; geolocation clock-in requires mobile', 'High'),
    ('13. Modern / Futuristic Add-Ons', 'Digital org chart — drag-drop, reporting lines, vacancies live', 'PARTIAL',
     'Orgchart', '/orgchart',
     'Tree visualization + privacy; drag-drop editing pending', 'Medium'),

    # Section 13.1 — Task Management (first-class module)
    ('13.1 Task Management', 'User-initiated task creation + assignee autocomplete', 'COVERED',
     'Tasks', '/tasks/new, /api/employees/search',
     'core.task_inbox extended with created_by + task_category; dept-scoped autocomplete picker', 'Low'),
    ('13.1 Task Management', 'Team view (MANAGER+) + admin view (HR_ADMIN+)', 'COVERED',
     'Tasks', '/tasks/team, /admin/tasks',
     'task_service.list_tasks modes: inbox/team/admin with full URL-driven filter set', 'Low'),
    ('13.1 Task Management', 'Comments + @mentions', 'COVERED',
     'Tasks', '/tasks/<id> comments thread',
     'core.task_comments with mentioned_user_ids[]; TASK_MENTIONED in-app notification on mention', 'Low'),
    ('13.1 Task Management', 'Task templates — Onboarding / Offboarding / KPI / IPCR / SALN', 'COVERED',
     'Tasks', '/admin/task-templates',
     'core.task_templates with 5 seeded checklists; one-click spawn for N employees via global picker', 'Low'),
    ('13.1 Task Management', 'TASK_ASSIGNED / TASK_DUE_24H / TASK_OVERDUE reminders', 'COVERED',
     'Reminders + Tasks', 'services/reminder_engine.py',
     '5 ntf_templates + 2 TRIGGER_QUERIES seeded; 24h-before + overdue escalation live', 'Low'),
    ('13.1 Task Management', 'Dashboard KPIs (Open / Overdue / Completed YTD / Avg Days)', 'COVERED',
     'Tasks + Analytics', '/ (home)',
     '4 dashboard_metrics seeded; TASKS Report Builder source auto-discovered by ARIA', 'Low'),

    # Section 13.2 — Global Employee Picker
    ('13.2 Global Employee Picker', 'Reusable picker (Individual / Department / Group)', 'COVERED',
     'Employee Picker', 'static/js/employee-picker.js',
     '3-tab widget shared by Tasks, Payroll Loans, Wellness assignment; single + multi modes', 'Low'),
    ('13.2 Global Employee Picker', 'Custom employee groups + admin CRUD', 'COVERED',
     'Employee Picker', '/admin/employee-groups',
     'core.employee_groups + members; seeds PROBATIONARY + DEPT_HEADS cohorts', 'Low'),

    # Section 13.3 — Health & Wellness Programs
    ('13.3 Health & Wellness', 'Wellness program catalog (mental health / fitness / vaccination / screening / seminar)', 'COVERED',
     'Health', '/health/wellness',
     'health.wellness_programs + filter chips (PLANNED/ACTIVE/COMPLETED/CANCELLED); stat badges per card', 'Low'),
    ('13.3 Health & Wellness', 'Bulk attendee assignment + attendance tracking', 'COVERED',
     'Health', '/health/wellness/<id>',
     'enroll_many() uses global EmployeePicker; ENROLLED → COMPLETED or NO_SHOW with admin toggles', 'Low'),
    ('13.3 Health & Wellness', 'Employee feedback + star rating on completed programs', 'COVERED',
     'Health', '/health/wellness/<id>/feedback',
     'feedback_rating (1-5) + text feedback; avg rating + feedback_count surfaced on list view', 'Low'),

    # Section 13.4 — UX consistency (Quick Actions + Payroll Flow)
    ('13.4 UX Consistency', 'Dashboard Quick Actions bar (role-aware, pinned Report Builder + ARIA)', 'COVERED',
     'Dashboard', '/',
     'Gradient CTA row for MANAGER → SUPER_ADMIN; always includes Report Builder + ARIA chat', 'Low'),
    ('13.4 UX Consistency', 'Payroll end-to-end processing banner', 'COVERED',
     'Payroll', '/payroll/',
     '8-step numbered flow (Employees → Period → Run → Compute → Review → Approve → Post → Payslips)', 'Low'),
    ('13.4 UX Consistency', 'Retirement rules — multi-profile support', 'COVERED',
     'Core HR', '/admin/retirement-rules',
     'core.retirement_rule_profiles with one Default + optional scoping (employment_type / department)', 'Low'),

    # Section 14 — Integration
    ('14. Integration & Ecosystem', 'API / connectors — payroll, ERP/finance, SSO, time-clock', 'PARTIAL',
     'Multiple', 'payroll_web service, SSO JWT flow',
     'Payroll microservice + JWT SSO; formal REST API + ERP/biometric connectors to document', 'Medium'),
    ('14. Integration & Ecosystem', 'Data import/export — migration, bulk updates', 'COVERED',
     'Admin', '/admin/reference, /admin/demo-data',
     'CSV import tools + Demo Data profiles', 'Low'),
]

# ── Gap backlog (only GAP items + estimates) ──────────────────────────
GAP_BACKLOG = [
    # G01 — CS Form No. 6        ✓ DELIVERED  (/leave/cs-form-6)
    # G02 — CS Form No. 7         ✓ DELIVERED  (/offboarding/clearance, /offboarding/exit-interview)
    # G03 — Travel Order          ✓ DELIVERED  (/travel-orders/)
    # G04 — Locator Slip          ✓ DELIVERED  (/locator-slips/)
    # G05 — Face-recognition      ✓ DELIVERED  (services/checkin_service.py, /checkin/)
    # G06 — Mobile geotag check-in ✓ DELIVERED (/checkin/ with activity=flag_raising|flag_lowering)
    # G07 — LGU Contracts         ✓ DELIVERED  (/lgu-contracts/)
    # G08 — Electronic signature (canvas + DocuSign) ✓ DELIVERED
    # G09 — Mobile training attendance (AM/PM)        ✓ DELIVERED  (/learning/sessions/<id>/checkin)
    # G10 — Training Narrative Report Form            ✓ DELIVERED  (/learning/nrf)
    # G11 — Loyalty Award auto-memo generator         ✓ DELIVERED  (/rewards/loyalty)
    # G12 — Step Increment tracking                   ✓ DELIVERED  (/step-increments/)
    # G13 — Retirement monitoring                     ✓ DELIVERED  (/retirement/)
    # G14 — PDS (CSC Form 212)                        ✓ DELIVERED  (/me/pds, /pds/)
    # G15 — CSC Eligibility 1st/2nd Level report      ✓ DELIVERED  (/reports/eligibility)
    # G16 — SALN PDF (3-mode configurable)            ✓ DELIVERED  (/me/saln, /dms/saln/<id>.pdf)
    # G17 — Appointment PDF (CSC Form 33)             ✓ DELIVERED  (/rsp/appointments/<id>/pdf)
    # G18 — Attrition risk scoring model              ✓ DELIVERED  (/reports/attrition-risk + ARIA tool)
]

PARTIAL_BACKLOG = [
    ('P01', 'Seed CTO as leave type', 'Leave', 'Admin → Reference → lv_types → add CTO with OT accrual'),
    ('P02', 'IPCR / OPCR templates', 'PM', 'Add templates to performance review cycles'),
    ('P03', 'Job Portal posting integration', 'RSP', 'Add posting webhooks to 3rd-party job portals'),
    ('P04', 'Successor slate UI', 'PM', 'New tab on /performance showing critical roles + slate'),
    ('P05', 'CSC-specific employment types (JO, COS)', 'Core HR', 'Reference → employment_types → add JO, COS'),
    ('P06', 'Rank classification on positions', 'Core HR', 'Add rank_classification column to core.positions'),
    ('P07', 'Education bucket config per CSC', 'Core HR', 'Normalize education_level values; add report buckets'),
    ('P08', 'Plantilla Summary by gender', 'Workforce Planning', 'Extend existing scenario report with gender split'),
    ('P09', 'Next-in-rank auto notification on vacancy', 'RSP + Reminders', 'Add rank-based rule to reminder engine'),
    ('P10', 'Retention policy: 5 years for recruitment docs', 'DMS', 'Set retention_policies for Recruitment category'),
    ('P11', 'SMTP email delivery for reports/reminders', 'Reminders', 'Configure SMTP_HOST, SMTP_USER, SMTP_PASS in .env'),
    ('P12', 'Disk encryption + TLS proxy', 'Infrastructure', 'Deploy behind nginx/Caddy with LE certs; LUKS on host'),
    ('P13', 'Scheduled archival of off-boarded employees', 'DMS', 'Cron job for retention_policies execution'),
    ('P14', 'Drag-drop report builder UI', 'Analytics', 'Upgrade /reports with drag-drop canvas'),
    # P15 ✓ DELIVERED — /ai/assistant streaming chat UI + /ai redirect (Apr 2026)
    ('P16', 'Drag-drop org chart editing', 'Orgchart', 'Enable node-drop reassignment on /orgchart'),
    ('P17', 'Next-of-kin/rank notification for vacancies', 'RSP', 'Configure reminder rule'),
    ('P18', 'Mobile responsive enhancements', 'UI', 'Audit each /me page for <640px viewports'),
    ('P19', 'COE and Service Record HTML-to-PDF templates', 'DMS', 'Add CSC-aligned certificate templates'),
    ('P20', 'Retirement rules seeding (60 early, 65 mandatory)', 'Core HR', 'New reference table + age check on demographics'),
]


# ──────────────────────────────────────────────────────────────────────
# BUILD_FEATURE_CATALOG — every feature currently delivered in HCM360
#   (module, feature, in_mariveles_request, status_in_build)
#
# status_in_build : 'LIVE' (fully working) / 'PARTIAL' (minimum viable)
# in_mariveles_request : True if this feature appeared in the original
#   Municipality of Mariveles HRMO requirements list; False = bonus/
#   beyond-scope value-add built above and beyond what was asked for.
# ──────────────────────────────────────────────────────────────────────
BUILD_FEATURE_CATALOG = [
    # ── Core HR ────────────────────────────────────────────────────
    ('Core HR', 'Employee master (201 file) — 40+ fields',                  True,  'LIVE'),
    ('Core HR', 'Sub-records: addresses, contacts, IDs, banks, dependents', True,  'LIVE'),
    ('Core HR', 'Department hierarchy with head tracking',                   True,  'LIVE'),
    ('Core HR', 'Position hierarchy + job grades',                           True,  'LIVE'),
    ('Core HR', 'Employment type with probation + benefits flags',           True,  'LIVE'),
    ('Core HR', 'Employee status lifecycle (ACTIVE→REGULAR→RESIGNED…)',      True,  'LIVE'),
    ('Core HR', 'Transfer & promotion historical records',                   True,  'LIVE'),
    ('Core HR', 'Bulk import / export (CSV)',                                False, 'LIVE'),
    ('Core HR', 'Multi-tenant (per-company isolation)',                      False, 'LIVE'),
    ('Core HR', 'Retirement Tracking (age 60 early / 65 mandatory) — G13',   True,  'LIVE'),
    ('Core HR', 'Step Increment tracking (3-year cadence) — G12',            True,  'LIVE'),
    ('Core HR', 'Personal Data Sheet (CSC Form 212) — 10-tab form — G14',    True,  'LIVE'),
    ('Core HR', 'LGU Contracts (JO/LSB/BHW/NS) with PDF — G07',              True,  'LIVE'),
    ('Core HR', 'Travel Orders with pre-approval — G03',                     True,  'LIVE'),
    ('Core HR', 'Locator Slips with supervisor approval — G04',              True,  'LIVE'),
    ('Core HR', 'Clearance CS Form 7 with 9 signatory items — G02',          True,  'LIVE'),
    ('Core HR', 'Exit Interview form with 4-way ratings — G02',              True,  'LIVE'),

    # ── Attendance ─────────────────────────────────────────────────
    ('Attendance', 'Daily time records (DTR) with clock in/out',             True,  'LIVE'),
    ('Attendance', 'Shift schedules (fixed / rotating / flexible)',          True,  'LIVE'),
    ('Attendance', 'Shift assignments per employee',                         True,  'LIVE'),
    ('Attendance', 'Overtime / late / absent / undertime tracking',          True,  'LIVE'),
    ('Attendance', 'Philippine holiday calendar pre-seeded',                 True,  'LIVE'),
    ('Attendance', 'Holiday premium pay multipliers',                        True,  'LIVE'),
    ('Attendance', 'Admin overrides with immutable audit trail',             True,  'LIVE'),
    ('Attendance', 'Attendance alerts (excessive late/absent patterns)',     True,  'LIVE'),
    ('Attendance', 'Biometric integration hooks',                            False, 'PARTIAL'),
    ('Attendance', 'Face recognition check-in (face-api.js) — G05',          True,  'LIVE'),
    ('Attendance', 'Mobile geotag check-in + photo — G06',                   True,  'LIVE'),
    ('Attendance', 'Face enrollment with 3-sample averaging',                False, 'LIVE'),
    ('Attendance', 'Geofence validation (haversine distance)',               False, 'LIVE'),
    ('Attendance', 'Activity types (flag raising / lowering / regular)',     True,  'LIVE'),
    ('Attendance', 'CS Form No. 6 strict leave compliance — G01',            True,  'LIVE'),

    # ── Leave Management ──────────────────────────────────────────
    ('Leave Mgmt', '10+ statutory leave types (RA 11210/8187/8972/9262/etc)', True,  'LIVE'),
    ('Leave Mgmt', 'Balance tracking with year-end rollover',                True,  'LIVE'),
    ('Leave Mgmt', 'Leave workflow with approval chain',                     True,  'LIVE'),
    ('Leave Mgmt', 'Document attachments for leaves',                        True,  'LIVE'),
    ('Leave Mgmt', 'Per-employment-type leave policies',                     False, 'LIVE'),
    ('Leave Mgmt', 'Non-destructive balance adjustments with audit',         False, 'LIVE'),

    # ── Payroll ────────────────────────────────────────────────────
    ('Payroll', 'Pay periods + runs (DRAFT→COMPUTED→APPROVED→POSTED)',       True,  'LIVE'),
    ('Payroll', 'Government deductions: SSS, PhilHealth, HDMF, BIR',         True,  'LIVE'),
    ('Payroll', 'Allowances: PERA, RATA, ACA, hazard, representation',       True,  'LIVE'),
    ('Payroll', 'Loans and amortization schedules',                          True,  'LIVE'),
    ('Payroll', 'Government remittance reports (R3, RF1, MCRF, 1601-C)',     True,  'LIVE'),
    ('Payroll', '2316 and Alphalist generation',                             True,  'LIVE'),
    ('Payroll', 'Payslip PDF generation + download',                         True,  'LIVE'),
    ('Payroll', 'Non-destructive post-posting adjustments',                  False, 'LIVE'),
    ('Payroll', 'Standalone microservice (port 8095)',                       False, 'LIVE'),
    ('Payroll', '8-step end-to-end processing banner on /payroll/',          False, 'LIVE'),
    ('Payroll', 'Loan creation with global employee picker (single-select)', False, 'LIVE'),

    # ── Recruitment (RSP) ─────────────────────────────────────────
    ('Recruitment', 'Requisition workflow with approvals',                   True,  'LIVE'),
    ('Recruitment', 'Candidate pipeline with source tracking',               True,  'LIVE'),
    ('Recruitment', 'Interview scheduling + panelist coordination',          True,  'LIVE'),
    ('Recruitment', 'CSC eligibilities (with 1st/2nd level column) — G15',   True,  'LIVE'),
    ('Recruitment', 'Qualification standards per position',                  True,  'LIVE'),
    ('Recruitment', 'Appointment (CSC Form 33) PDF — G17',                   True,  'LIVE'),
    ('Recruitment', 'Plantilla filled vs vacant tracking',                   True,  'LIVE'),

    # ── Performance Management ────────────────────────────────────
    ('Performance', 'Multi-cycle reviews (annual / mid-year / probationary)', True,  'LIVE'),
    ('Performance', 'KPI / competency rating matrices',                      True,  'LIVE'),
    ('Performance', 'Self-review + manager review + 360 feedback',           True,  'LIVE'),
    ('Performance', 'Calibration sessions',                                  False, 'LIVE'),

    # ── Learning & Development ────────────────────────────────────
    ('Learning', 'Training catalog with categories',                         True,  'LIVE'),
    ('Learning', 'Enrollment workflows + attendance tracking',               True,  'LIVE'),
    ('Learning', 'Certificate issuance with expiration tracking',            False, 'LIVE'),
    ('Learning', 'Mobile training attendance with AM/PM shift — G09',        True,  'LIVE'),
    ('Learning', 'Narrative Report Form (NRF) workflow — G10',               True,  'LIVE'),
    ('Learning', 'Compliance training calendar',                             False, 'LIVE'),

    # ── Rewards & Recognition ─────────────────────────────────────
    ('Rewards', 'Award categories (Employee of Month, Merit, etc.)',         True,  'LIVE'),
    ('Rewards', 'Peer praise wall',                                          False, 'LIVE'),
    ('Rewards', 'Loyalty Service Awards (10/15/20/25/30 yr) — G11',          True,  'LIVE'),
    ('Rewards', 'Auto-memo generator for loyalty (PDF) — G11',               True,  'LIVE'),

    # ── DMS (201 File) ────────────────────────────────────────────
    ('DMS', '201 file with hierarchical document categories',                True,  'LIVE'),
    ('DMS', 'Document upload with retention policy + expiry alerts',         True,  'LIVE'),
    ('DMS', 'Certificate request queue for HR',                              True,  'LIVE'),
    ('DMS', 'Auto certificate generation (COE, Service Record)',             True,  'LIVE'),
    ('DMS', 'SALN 3-mode filings (UPLOAD_ONLY/SIMPLE/FULL CSC 210) — G16',   True,  'LIVE'),
    ('DMS', 'E-signature: canvas pad + DocuSign adapter — G08',              True,  'LIVE'),

    # ── Discipline ─────────────────────────────────────────────────
    ('Discipline', 'Case types by gravity with default penalties',           True,  'LIVE'),
    ('Discipline', 'Legal basis tracking (DOLE / CSC / company policy)',     True,  'LIVE'),
    ('Discipline', 'Investigation workflow + witness/evidence capture',      True,  'LIVE'),
    ('Discipline', 'Administrative hearing scheduling',                      True,  'LIVE'),
    ('Discipline', 'Sanction imposition with appeal tracking',               True,  'LIVE'),

    # ── Health & Safety ───────────────────────────────────────────
    ('Health', 'Incident reports with categorization + severity',            True,  'LIVE'),
    ('Health', 'Workplace safety records',                                   True,  'LIVE'),
    ('Health', 'Follow-up action tracking',                                  True,  'LIVE'),
    ('Health', 'Physical Exam (PE) schedules + results + compliance KPIs',   True,  'LIVE'),
    ('Health', 'Health certificates with expiry monitoring',                 True,  'LIVE'),
    ('Health', 'Wellness programs (6 types) with enrollment + feedback',     False, 'LIVE'),
    ('Health', 'Wellness bulk attendee assignment + NO_SHOW tracking',       False, 'LIVE'),
    ('Health', 'Wellness star ratings + avg rating + feedback count',        False, 'LIVE'),

    # ── Task Management (new first-class module) ──────────────────
    ('Tasks', 'Task inbox (system + user-initiated tasks)',                  False, 'LIVE'),
    ('Tasks', 'User-initiated task creation with assignee autocomplete',     False, 'LIVE'),
    ('Tasks', 'Team view (MANAGER+) + Admin view (HR_ADMIN+)',               False, 'LIVE'),
    ('Tasks', 'Filter / sort / keyword search on inbox + tasks lists',       False, 'LIVE'),
    ('Tasks', 'Comments thread with @mentions',                              False, 'LIVE'),
    ('Tasks', 'Task templates (5 seeded) + one-click multi-employee spawn',  False, 'LIVE'),
    ('Tasks', 'TASK_ASSIGNED / TASK_DUE_24H / TASK_OVERDUE notifications',   False, 'LIVE'),
    ('Tasks', 'Dashboard KPIs: Open · Overdue · Completed YTD · Avg Days',   False, 'LIVE'),
    ('Tasks', 'TASKS Report Builder source (auto-discovered by ARIA)',       False, 'LIVE'),
    ('Tasks', 'Dept-scoped access + page/feature registry grants',           False, 'LIVE'),

    # ── Global Employee Picker (reusable widget) ──────────────────
    ('Employee Picker', 'Reusable JS widget (Individual / Department / Group tabs)', False, 'LIVE'),
    ('Employee Picker', 'Single-select + multi-select modes',                False, 'LIVE'),
    ('Employee Picker', 'Custom employee groups + admin CRUD UI',            False, 'LIVE'),
    ('Employee Picker', 'Integrated into Tasks, Payroll Loans, Wellness',    False, 'LIVE'),

    # ── Org Chart ──────────────────────────────────────────────────
    ('Org Chart', 'Interactive person-centric tree (ancestors → self → team)', True,  'LIVE'),
    ('Org Chart', 'Privacy-aware nodes with RA 10173 field masking',         True,  'LIVE'),
    ('Org Chart', 'Department-scoped view for non-admin roles',              True,  'LIVE'),
    ('Org Chart', 'Department-scoped KPIs for non-admin viewers',            False, 'LIVE'),
    ('Org Chart', 'Privacy notice banner',                                   False, 'LIVE'),

    # ── Workforce Planning ────────────────────────────────────────
    ('Workforce Planning', 'Scenario modeling (headcount / cost / skills)',  False, 'LIVE'),
    ('Workforce Planning', 'Assumption-driven projections (attrition %, growth %)', False, 'LIVE'),
    ('Workforce Planning', 'Auto-generated quarterly headcount plans',       False, 'LIVE'),
    ('Workforce Planning', 'Skill demand vs supply gap analysis',            False, 'LIVE'),

    # ── Analytics & Reports ───────────────────────────────────────
    ('Analytics', 'Admin dashboard with real-time KPI cards',                True,  'LIVE'),
    ('Analytics', 'HR demographics reports (gender, tenure, age)',           True,  'LIVE'),
    ('Analytics', 'CSC Eligibility 1st/2nd Level × Gender report — G15',    True,  'LIVE'),
    ('Analytics', 'Attendance and leave heatmaps',                           True,  'LIVE'),
    ('Analytics', 'Drag-drop Report Builder with 30 data sources',           False, 'LIVE'),
    ('Analytics', 'Report Builder with 260 field registry entries',          False, 'LIVE'),
    ('Analytics', 'Scheduled reports (DAILY/WEEKLY/MONTHLY) with recipients', False, 'LIVE'),
    ('Analytics', 'Export as CSV / XLSX / PDF',                              False, 'LIVE'),
    ('Analytics', 'KPI SQL registry (configurable via core.dashboard_metrics)', False, 'LIVE'),
    ('Analytics', 'Attrition Risk scoring model with heuristic — G18',       True,  'LIVE'),
    ('Analytics', 'Attrition dashboard with factor chips + gender split',    False, 'LIVE'),

    # ── AI (ARIA) ──────────────────────────────────────────────────
    ('AI (ARIA)', 'AI-powered HR assistant (Anthropic Claude)',              True,  'LIVE'),
    ('AI (ARIA)', 'Natural-language Q&A on employee data',                   True,  'LIVE'),
    ('AI (ARIA)', '12 built-in HRIS tools (workforce, workflow, KPIs, etc)', False, 'LIVE'),
    ('AI (ARIA)', 'Cross-module query_data_source tool (30 sources)',        False, 'LIVE'),
    ('AI (ARIA)', 'hr_leader_dashboard tool (14 headline numbers)',          False, 'LIVE'),
    ('AI (ARIA)', 'explain_kpi tool with live values',                       False, 'LIVE'),
    ('AI (ARIA)', 'predict_attrition_risk tool',                             False, 'LIVE'),
    ('AI (ARIA)', 'Role-aware system prompt (HR LEADER MODE)',               False, 'LIVE'),
    ('AI (ARIA)', 'Server-Sent Events (SSE) streaming responses',            False, 'LIVE'),
    ('AI (ARIA)', 'Audit log of AI queries',                                 False, 'LIVE'),
    ('AI (ARIA)', 'Interactive chat UI at /ai/assistant (streaming SSE)',    True,  'LIVE'),
    ('AI (ARIA)', '/ai redirects to /ai/assistant for a single entry point', False, 'LIVE'),

    # ── Self-Service (ESS/MSS) ────────────────────────────────────
    ('ESS/MSS', 'My Portal dashboard with KPI cards',                        True,  'LIVE'),
    ('ESS/MSS', 'My Profile with section cards + "+ Add" links',             True,  'LIVE'),
    ('ESS/MSS', 'File leaves, view balances, request certificates',          True,  'LIVE'),
    ('ESS/MSS', 'View own DTR, payslips, compensation breakdown, loans',     True,  'LIVE'),
    ('ESS/MSS', 'Benefits enrollment view',                                  False, 'LIVE'),
    ('ESS/MSS', 'Manager service: team DTR, approvals, 1:1 history',         True,  'LIVE'),
    ('ESS/MSS', 'Beautified profile page with icons + badges',               False, 'LIVE'),
    ('ESS/MSS', 'Role-aware Quick Actions bar (MANAGER → SUPER_ADMIN)',      False, 'LIVE'),
    ('ESS/MSS', 'Always-pinned Report Builder + ARIA CTA on dashboard',      False, 'LIVE'),
    ('ESS/MSS', 'Travel-order new form + admin locator-on-behalf picker',    True,  'LIVE'),

    # ── Administration ─────────────────────────────────────────────
    ('Admin', 'Access Matrix (page × feature × modification tiers)',         True,  'LIVE'),
    ('Admin', 'Role management with custom role creation',                   True,  'LIVE'),
    ('Admin', 'User management with inline-edit + role dropdown',            False, 'LIVE'),
    ('Admin', 'Reference data CRUD (29+ tables)',                            True,  'LIVE'),
    ('Admin', 'Field Privacy Rules (RA 10173 — VISIBLE/MASKED/HIDDEN)',      True,  'LIVE'),
    ('Admin', 'UI Theme activation (per-company branding)',                  True,  'LIVE'),
    ('Admin', 'Demo data profile activation',                                False, 'LIVE'),
    ('Admin', 'Reminder rule configuration',                                 True,  'LIVE'),
    ('Admin', 'Service monitoring / health dashboard',                       False, 'LIVE'),
    ('Admin', 'Retirement rule profiles (multi-profile + default flag)',     True,  'LIVE'),
    ('Admin', 'Employee groups CRUD + PROBATIONARY / DEPT_HEADS seeds',      False, 'LIVE'),
    ('Admin', 'Task templates library (HR_ADMIN+ spawner)',                  False, 'LIVE'),

    # ── Security & Compliance ─────────────────────────────────────
    ('Security', 'Session-based authentication with user selector',          True,  'LIVE'),
    ('Security', 'Role-based RBAC (page + feature + modification)',          True,  'LIVE'),
    ('Security', 'RA 10173 (Data Privacy Act) field masking',                True,  'LIVE'),
    ('Security', 'Audit log with trigger-based change capture',              True,  'LIVE'),
    ('Security', 'Self-record privacy relaxation (MASKED→VISIBLE for own)',  False, 'LIVE'),
    ('Security', 'SSO JWT token support (optional)',                         False, 'LIVE'),
    ('Security', 'User access matrix with overrides',                        True,  'LIVE'),

    # ── Guided Tour + Tooltip System (beyond scope) ───────────────
    ('UX', 'Guided Tours (8 seeded tours, role-filtered)',                   False, 'LIVE'),
    ('UX', 'data-hint tooltip system (hover + tap)',                         False, 'LIVE'),
    ('UX', 'Floating "?" help launcher',                                     False, 'LIVE'),
    ('UX', 'Per-user tour completion tracking',                              False, 'LIVE'),
    ('UX', 'Tour versioning for re-notification',                            False, 'LIVE'),
    ('UX', 'Admin UI at /admin/tours to manage tours',                       False, 'LIVE'),

    # ── Infrastructure ────────────────────────────────────────────
    ('Infrastructure', 'Docker Compose 3-service stack',                     False, 'LIVE'),
    ('Infrastructure', 'Named Docker volumes (survives rebuilds)',           False, 'LIVE'),
    ('Infrastructure', 'PostgreSQL 15 with schema-per-module',               False, 'LIVE'),
    ('Infrastructure', 'Versioned SQL migrations (58 files)',                False, 'LIVE'),
    ('Infrastructure', 'Full pg_dump backup + restore script',               False, 'LIVE'),
    ('Infrastructure', 'Docker image tagging (v1.0 frozen build)',           False, 'LIVE'),
    ('Infrastructure', 'Comprehensive tech + user documentation',            False, 'LIVE'),
]


# ──────────────────────────────────────────────────────────────────────
# JOB_REQUISITION_GAP — deep-dive gap analysis for the "Create Job
# Requisition" feature specifically.
#
# Each row: (category, aspect, current_state, gap, status, priority, effort)
#   status   : COVERED / PARTIAL / GAP
#   priority : High / Medium / Low
#   effort   : Small / Medium / Large (S=<1wk, M=1–2wk, L=3+wk)
# ──────────────────────────────────────────────────────────────────────
JOB_REQUISITION_GAP = [
    # ── 1. Data Model ─────────────────────────────────────────────
    ('1. Data Model', 'Core requisition table exists',
     'recruitment.rec_requisitions with id, company_id, reference_no, department_id, position_id, headcount, justification, status, workflow_instance_id, requested_by, approved_by, target_hire_date, created_at',
     'None — fully in place', 'COVERED', 'Low', 'Small'),

    ('1. Data Model', 'Audit trail on requisition changes',
     'Trigger audit_logs.fn_capture_change fires on INSERT/UPDATE/DELETE + rec_requisition_history table records every transition',
     'None — fully in place', 'COVERED', 'Low', 'Small'),

    ('1. Data Model', 'Plantilla item linkage (LGU-specific)',
     'Migration 60: plantilla_item_id FK to rec_plantilla_items added',
     'None — plantilla dropdown in New Requisition form lets user pick any VACANT item',
     'COVERED', 'High', 'Small'),

    ('1. Data Model', 'Salary range on requisition',
     'Migration 60: salary_min_override + salary_max_override columns; PDF falls back to job_grade defaults when not set',
     'None — surfaced on both form and CSC Form PDF',
     'COVERED', 'Medium', 'Small'),

    ('1. Data Model', 'Budget / cost center link',
     'Migration 60: budget_source (TEXT) + funds_available (NUMERIC) columns; captured on form, rendered on CSC Form PDF',
     'None — Finance review fields live',
     'COVERED', 'Medium', 'Small'),

    ('1. Data Model', 'Supporting documents',
     'Migration 60: rec_requisition_attachments table + multipart upload endpoint POST /rsp/requisitions/<id>/attachments; type dropdown covers JUSTIFICATION / BUDGET_APPROVAL / ORG_CHART / ENDORSEMENT / OTHER',
     'None — attachments appear on detail page with size + uploader',
     'COVERED', 'Medium', 'Small'),

    ('1. Data Model', 'Requisition urgency / priority',
     'Migration 60: priority column (URGENT / HIGH / NORMAL / LOW) with CHECK constraint; colored chip on list + detail; URGENT auto-flags postings is_internal=TRUE',
     'None — priority drives inbox task priority + publish behaviour',
     'COVERED', 'Low', 'Small'),

    ('1. Data Model', 'CSC-specific fields (for government hiring)',
     'Migration 60: qualification_standard_id FK + required_eligibility_id FK; both dropdowns on the form; rendered under Section C of the CSC PDF',
     'None — civil service qualification metadata captured',
     'COVERED', 'High', 'Small'),

    # ── 2. Create Flow (UI + Service) ─────────────────────────────
    ('2. Create Flow', 'Route: GET/POST /recruitment/requisitions/new',
     'Blueprint mounted at /rsp/requisitions with alias redirect from /recruitment/requisitions; GET renders form, POST calls create_requisition()',
     'None — form page live',
     'COVERED', 'High', 'Medium'),

    ('2. Create Flow', 'Service function: create_requisition()',
     'services/requisition_service.py:create_requisition(company_id, form, user_id, submit=False) returns (req_id, reference_no)',
     'None — service layer complete',
     'COVERED', 'High', 'Small'),

    ('2. Create Flow', 'Auto-generate reference_no (REQ-YYYY-NNNNNN)',
     '_next_reference_no() generates REQ-YYYY-NNNNNN (zero-padded sequence per year) via MAX(split_part(...)) lookup',
     'None — verified REQ-2026-000005 generated on test submission',
     'COVERED', 'High', 'Small'),

    ('2. Create Flow', 'Draft-save capability',
     'Form has two submit buttons: "Save as Draft" (action=draft) and "Save & Submit for Approval" (action=submit); drafts persist with status=DRAFT',
     'None — draft mode works end-to-end',
     'COVERED', 'Medium', 'Small'),

    ('2. Create Flow', 'Duplicate-detection guard',
     'find_duplicates(position_id) + AJAX endpoint /rsp/requisitions/check-duplicates; banner on new.html fires on position change',
     'None — detects any PENDING_APPROVAL/DRAFT requisition for same position',
     'COVERED', 'Medium', 'Small'),

    ('2. Create Flow', 'Clone-from-previous convenience',
     'POST /rsp/requisitions/<id>/clone duplicates the source row into a fresh DRAFT with new reference_no and cloned-from note in justification',
     'None — clone action on detail page + ?clone=<id> prefill',
     'COVERED', 'Low', 'Small'),

    ('2. Create Flow', 'Detail view (/requisitions/<id>)',
     'view.html shows: form snapshot, approval chain timeline, linked job postings, attachments + upload, history, WFP warning banner, action buttons gated by role/state',
     'None — detail page fully featured',
     'COVERED', 'High', 'Medium'),

    # ── 3. Approval Workflow ──────────────────────────────────────
    ('3. Approval Workflow', 'Workflow engine available',
     'workflow_definitions, workflow_instances, workflow_steps tables exist + are used by leave/travel/requisitions',
     'None — engine is reusable', 'COVERED', 'Low', 'Small'),

    ('3. Approval Workflow', 'REQUISITION_APPROVAL workflow seeded',
     'Migration 60 seeds 3-step chain: REQ_DEPT_HEAD (MANAGER, 48h) → REQ_HR_REVIEW (HR_ADMIN, 48h) → REQ_EXEC_APPROVE (EXECUTIVE, 24h, is_final=TRUE) + APPROVE/REJECT routes per step',
     'None — verified workflow_definition #17 exists',
     'COVERED', 'High', 'Medium'),

    ('3. Approval Workflow', 'Status transition endpoints',
     'POST /rsp/requisitions/<id>/submit, /approve, /reject, /cancel — all mounted, guarded by _can_create/_can_approve role checks',
     'None — 4 transition routes live',
     'COVERED', 'High', 'Small'),

    ('3. Approval Workflow', 'Inbox integration',
     '_submit_workflow() calls task_inbox_service.create_task() for every MANAGER in the requesting department; task has action_url pointing to requisition detail page',
     'None — inbox tasks fire on submit',
     'COVERED', 'High', 'Small'),

    ('3. Approval Workflow', 'Role-level approver routing',
     'workflow_steps.role_required carries MANAGER / HR_ADMIN / EXECUTIVE; view.html only shows Approve/Reject buttons when session.role_code matches current step role (or SUPER_ADMIN override)',
     'None — role-gated approver routing verified',
     'COVERED', 'Medium', 'Small'),

    ('3. Approval Workflow', 'Rejection with reason capture',
     'rejection_reason TEXT column; reject route requires non-empty reason (minlength=5); surfaced in red banner on detail page + notification payload',
     'None — reason required and persisted',
     'COVERED', 'Medium', 'Small'),

    ('3. Approval Workflow', 'Partial approval (headcount split)',
     'approved_headcount INTEGER column; approve form allows reducing headcount (max=requested); audit row written with metadata={"approved_headcount": N}',
     'None — verified via final-approval test with approved_headcount=1',
     'COVERED', 'Low', 'Small'),

    # ── 4. Publication / Downstream ───────────────────────────────
    ('4. Publication', 'Auto-create rec_job_postings on APPROVED',
     '_on_approved() hook fires on final workflow step; auto-inserts rec_job_postings with title from position, salary_range from overrides or job_grade, status=OPEN, then flips requisition to PUBLISHED',
     'None — verified posting #371 auto-created after 3-step approval',
     'COVERED', 'Medium', 'Small'),

    ('4. Publication', 'CSC publication channels',
     'rec_publications + rec_job_postings integration intact; auto-publish uses the existing channel dispatcher',
     'None — channels remain multi-target via rec_publications',
     'COVERED', 'Medium', 'Small'),

    ('4. Publication', 'Next-in-rank auto-notify',
     'URGENT priority sets is_internal=TRUE on the posting, feeding compute_next_in_rank() + notify_next_in_rank() for internal-first hires',
     'None — URGENT → is_internal=TRUE auto-path verified',
     'COVERED', 'Medium', 'Small'),

    ('4. Publication', 'Linked applicant pipeline',
     'rec_applicants with stage tracking continues to feed from posting_id; detail page lists all linked postings',
     'None — pipeline intact + visible on requisition detail',
     'COVERED', 'Low', 'Small'),

    # ── 5. Notifications ──────────────────────────────────────────
    ('5. Notifications', 'In-app inbox notifications',
     '_submit_workflow() creates inbox tasks for MANAGER approvers; reject/approve hooks push notifications to requester via notification_service.notify()',
     'None — bell + inbox integration live',
     'COVERED', 'High', 'Small'),

    ('5. Notifications', 'Email notifications',
     'Migration 60 seeds req_submitted_inapp, req_approved_inapp, req_rejected_inapp templates with {{reference_no}}, {{position_title}}, {{headcount}}, {{approved_headcount}}, {{rejection_reason}} placeholders',
     'None — templates discovered by notify() on each transition',
     'COVERED', 'Medium', 'Small'),

    ('5. Notifications', 'Reminder for idle pending approvals',
     'REQ_PENDING_24H added to services/reminder_engine.py:TRIGGER_QUERIES + seeded as active row in notifications.reminder_rules; escalates to step-1 approver as HIGH priority for URGENT/HIGH requisitions',
     'None — fires on refresh_inbox() via /me page load',
     'COVERED', 'Low', 'Small'),

    # ── 6. Access Control ─────────────────────────────────────────
    ('6. Access Control', 'Page registry for /requisitions',
     'Migration 60 registers /rsp/requisitions, /rsp/requisitions/new, /rsp/requisitions/<id> under module=rsp; all 3 visible in Access Matrix → RSP / Recruitment',
     'None — verified rendering in /admin/access-matrix?module=rsp',
     'COVERED', 'High', 'Small'),

    ('6. Access Control', 'Feature registry for requisition actions',
     'Migration 60 seeds REQ_CREATE, REQ_APPROVE, REQ_REJECT, REQ_CANCEL, REQ_PUBLISH features with action_type CREATE/APPROVE/EDIT; role grants applied to SUPER_ADMIN, HR_ADMIN, MANAGER, EXECUTIVE',
     'None — 5 features visible in Access Matrix for toggling per role or user',
     'COVERED', 'High', 'Small'),

    ('6. Access Control', 'Department-scoped visibility',
     '_apply_role_filter() in requisition_service restricts non-admin roles to r.requested_by = user OR r.department_id = user-department',
     'None — scoping enforced on list + detail views',
     'COVERED', 'Medium', 'Small'),

    # ── 7. Reporting ──────────────────────────────────────────────
    ('7. Reporting', 'Report Builder data source for requisitions',
     'Migration 60 registers REQUISITIONS data source (analytics.report_data_sources) with 19 fields: reference_no, status, priority, position_title, department, salary_grade, headcount, approved_headcount, dates, budget_source, funds_available, requester_name, plantilla_item_no, qualification_standard, required_eligibility, days_pending computed',
     'None — verified "Job Requisitions" appears in /reports/builder',
     'COVERED', 'Medium', 'Small'),

    ('7. Reporting', 'Vacancy dashboard KPI',
     'Migration 60 seeds 4 dashboard_metrics: req_pending_count, req_approved_ytd, req_avg_days_approve, req_open_vacancies — all visible on the homepage for HR roles',
     'None — live KPI cards verified',
     'COVERED', 'Medium', 'Small'),

    ('7. Reporting', 'Time-to-fill metric',
     'get_summary_stats() computes avg_days_approve = AVG(approved_at - submitted_at); also exposed as days_pending field in REQUISITIONS data source',
     'None — time-to-approve computed; time-to-fill derivable via Report Builder join against rec_appointments',
     'COVERED', 'Low', 'Small'),

    # ── 8. Integration & Compliance ───────────────────────────────
    ('8. Integration', 'ARIA AI awareness',
     'ARIA auto-discovers analytics.report_data_sources via aria_extensions.query_data_source — REQUISITIONS source is immediately queryable without code changes',
     'None — "how many pending requisitions?" works out of the box',
     'COVERED', 'Low', 'Small'),

    ('8. Integration', 'Guided tour for creating a requisition',
     'Migration 60 seeds requisition-create-v1 tour (6 steps): intro → department → position → headcount → justification → after-submit explainer; auto-started via url_pattern /rsp/requisitions matching',
     'None — tour plays for HR_ADMIN, MANAGER, SUPER_ADMIN on first visit',
     'COVERED', 'Medium', 'Small'),

    ('8. Integration', 'Tooltips on requisition form fields',
     'Every input/select in new.html carries data-hint attributes covering Department, Position, Plantilla Item, Headcount, Budget Source, Funds Available, Priority, Salary overrides, Target Hire Date, Qualification Standard, Eligibility, Justification',
     'None — tooltip engine hris-tour.js picks up data-hint automatically',
     'COVERED', 'Low', 'Small'),

    ('8. Integration', 'CSC compliance: Form CS 001 / 004',
     'render_csc_form_pdf() generates "Personnel Requisition Form" PDF via ReportLab (reuses _doc/_header/_kv_table/_sig_block helpers) — 5 sections: Position, Budget, Qualifications, Justification, Approval + signature block',
     'None — GET /rsp/requisitions/<id>/csc-form.pdf returns application/pdf (verified 2.8KB PDF-1.4 output)',
     'COVERED', 'Medium', 'Medium'),

    ('8. Integration', 'Integration with Workforce Planning scenarios',
     'wfp_warning() compares current + requested headcount against active WFP scenario planned_hc; amber banner on detail page when exceeded, naming the scenario and over_by delta',
     'None — WFP banner shows on detail page when over-plan',
     'COVERED', 'Low', 'Medium'),
]


# ══════════════════════════════════════════════════════════════════════
# TASK_MANAGEMENT_GAP — deep-dive analysis for a standalone Task
# Management feature (to-dos, assignments, collaboration, reporting).
# Current build has a PASSIVE inbox that receives system-generated tasks
# (from workflow approvals + reminder engine); it lacks user-initiated
# task creation, assignment to others, collaboration surfaces, recurring
# tasks, and reporting.
#
# Same row shape: (category, aspect, current_state, gap, status, priority, effort)
# ══════════════════════════════════════════════════════════════════════
TASK_MANAGEMENT_GAP = [
    # ── 1. Data Model ─────────────────────────────────────────────
    ('1. Data Model', 'Core task table',
     'core.task_inbox with id, employee_id, user_id, task_type, title, description, action_url, priority, due_date, status, is_read, source_table, source_id, created_at, completed_at',
     'None — table exists and is used by workflow/reminder engines',
     'COVERED', 'Low', 'Small'),

    ('1. Data Model', 'Assignee (who the task is FOR)',
     'employee_id column already captures the assignee',
     'None — populated by create_task() helper',
     'COVERED', 'Low', 'Small'),

    ('1. Data Model', 'Assigner (who CREATED the task)',
     'Migration 61: core.task_inbox.created_by BIGINT FK → core.users(id) added and backfilled; task_service.create_task() always sets it to the current user',
     'None — assigner is now audited on every task',
     'COVERED', 'High', 'Small'),

    ('1. Data Model', 'Task categories / tags',
     'task_type is a free-text string (REQUISITION_APPROVAL, LEAVE_APPROVAL, etc.) — not end-user selectable',
     'Add task_category enum (WORK, FOLLOWUP, MEETING, DOC_REVIEW, PERSONAL, SYSTEM) + tags VARCHAR(255) for free-tag; used for list filters and reporting',
     'PARTIAL', 'Medium', 'Small'),

    ('1. Data Model', 'Subtasks / checklist items',
     'None — task_inbox is flat',
     'New table core.task_subitems (id, task_id FK, title, is_completed, sort_order, completed_at) with cascade delete',
     'GAP', 'Medium', 'Small'),

    ('1. Data Model', 'Comments / discussion',
     'None — no comment table',
     'New table core.task_comments (id, task_id FK, user_id FK, body TEXT, created_at, edited_at) for collaboration thread',
     'GAP', 'Medium', 'Small'),

    ('1. Data Model', 'Attachments',
     'None — no attachment linkage',
     'New table core.task_attachments (id, task_id FK, file_name, file_path, mime_type, size_kb, uploaded_by, uploaded_at); reuse /uploads/tasks/<id>/ convention',
     'GAP', 'Medium', 'Small'),

    ('1. Data Model', 'Audit trail / history',
     'Status transitions timestamped via completed_at; no full audit log',
     'New table core.task_history (id, task_id, action, old_value, new_value, user_id, created_at); trigger on UPDATE to log status/priority/due_date/assignee changes',
     'GAP', 'Medium', 'Small'),

    ('1. Data Model', 'Recurring tasks metadata',
     'None — every task is one-shot',
     'Add recurrence_rule JSONB (RFC 5545 RRULE subset: DAILY/WEEKLY/MONTHLY + interval + count/until) + parent_recurrence_id; scheduler spawns the next occurrence on completion',
     'GAP', 'Medium', 'Medium'),

    ('1. Data Model', 'Estimated vs actual effort',
     'None — no time tracking fields',
     'Add estimated_minutes INT + actual_minutes INT; used for capacity planning reports',
     'GAP', 'Low', 'Small'),

    ('1. Data Model', 'Task dependencies / blocking',
     'None',
     'New table core.task_dependencies (task_id, depends_on_task_id, dep_type) — BLOCKS / BLOCKED_BY / RELATES_TO; surfaces as "Waiting on" chip',
     'GAP', 'Low', 'Medium'),

    # ── 2. Create & Edit Flow ─────────────────────────────────────
    ('2. Create Flow', 'System-generated task insertion',
     'task_inbox_service.create_task() called from workflow engine, reminder engine, requisition service — covers REQUISITION_APPROVAL, LEAVE_APPROVAL, REMINDER, etc.',
     'None — system-generated tasks land in inbox correctly',
     'COVERED', 'Low', 'Small'),

    ('2. Create Flow', 'User-initiated task creation (self-task)',
     'GET/POST /tasks/new live — renders form with title, description, priority, category, due date, and assignee autocomplete; modules/tasks/routes.py calls task_service.create_task()',
     'None — personal to-dos and self-tasks fully supported',
     'COVERED', 'High', 'Small'),

    ('2. Create Flow', 'Assign task to another user',
     '/tasks/new includes an AJAX assignee picker (GET /api/employees/search); non-admin roles are scoped to same-department teammates; assignment fires the TASK_ASSIGNED notification',
     'None — assignment flow live with autocomplete + dept scoping',
     'COVERED', 'High', 'Medium'),

    ('2. Create Flow', 'Bulk task creation',
     'None',
     'POST /tasks/bulk accepts CSV or multi-assignee form — create N tasks with the same template; useful for onboarding checklists, org-wide reminders',
     'GAP', 'Low', 'Medium'),

    ('2. Create Flow', 'Edit task in place',
     'None — tasks are immutable after creation (except complete/dismiss)',
     'PATCH /tasks/<id> for title/description/priority/due_date; restricted to assigner + assignee + SUPER_ADMIN; history log captures diff',
     'GAP', 'Medium', 'Small'),

    ('2. Create Flow', 'Quick-add widget on dashboard',
     'None',
     'Floating "+ Task" button on every page (bottom-right) opens a modal — single-line title + optional due date; posts to /tasks/quick-add',
     'GAP', 'Medium', 'Small'),

    ('2. Create Flow', 'Task templates library',
     'None',
     'core.task_templates (code, title, description, category, default_priority, checklist JSONB); one-click spawn from template, e.g. "New Hire Onboarding" → 12 subtasks',
     'GAP', 'Low', 'Medium'),

    # ── 3. Organization & View ────────────────────────────────────
    ('3. Views', 'Personal inbox list',
     'GET /me/inbox shows tasks for current employee with status/priority badges + action_url jump',
     'None — list view operational',
     'COVERED', 'High', 'Small'),

    ('3. Views', 'Mark read / complete / dismiss',
     'POST /me/inbox/<id>/complete + /dismiss + /mark-all-read routes live',
     'None — transitions wired',
     'COVERED', 'High', 'Small'),

    ('3. Views', 'Filter by status / priority / type / due date',
     '/me/inbox and /tasks/ accept ?status=&priority=&category=&due=overdue|today|this_week&q=&sort= query params; filter chips render active state; task_service.list_tasks handles all filters server-side',
     'None — URL-driven filters live on inbox and all tasks views',
     'COVERED', 'High', 'Small'),

    ('3. Views', 'Sort: due date, priority, created',
     'Sort dropdown on /me/inbox and /tasks/ supports due_asc, due_desc, priority, created_asc, created_desc; mapped to SQL ORDER BY in task_service.list_tasks',
     'None — sort dropdown on every tasks list',
     'COVERED', 'Medium', 'Small'),

    ('3. Views', 'Search across title + description',
     'Search input on /me/inbox and /tasks/ posts ?q=; task_service.list_tasks applies ILIKE on title and description',
     'None — full-text keyword search live',
     'COVERED', 'Medium', 'Small'),

    ('3. Views', 'Kanban board (status columns)',
     'None',
     'New /tasks/board view: 4 columns (PENDING, IN_PROGRESS, BLOCKED, COMPLETED); drag-and-drop status updates; inherits list filters',
     'GAP', 'Medium', 'Medium'),

    ('3. Views', 'Calendar view (by due_date)',
     'None',
     'New /tasks/calendar embeds FullCalendar.js — tasks rendered as events by due_date; click opens detail modal',
     'GAP', 'Low', 'Medium'),

    ('3. Views', 'Team / manager view (all my reports\' tasks)',
     'GET /tasks/team (MANAGER+ only); task_service.list_tasks mode=team shows tasks assigned to employees in the manager\'s department; filters reuse the shared list template',
     'None — team aggregated view live with dept scope',
     'COVERED', 'High', 'Medium'),

    ('3. Views', 'Global admin view',
     'GET /admin/tasks (HR_ADMIN+ only); uses task_service mode=admin to surface every task company-wide; same filters + extra assigner_id/assignee_employee_id filters for bulk audits',
     'None — company-wide admin view live',
     'COVERED', 'Medium', 'Medium'),

    ('3. Views', 'Empty-state UX',
     'Shows "No tasks in your inbox" plain message',
     'Replace with illustrated empty state + "Create your first task" CTA + contextual tips (same pattern as /me/profile empty-state)',
     'PARTIAL', 'Low', 'Small'),

    # ── 4. Collaboration ──────────────────────────────────────────
    ('4. Collaboration', 'Comment on a task',
     'POST /tasks/<id>/comments inserts into core.task_comments; detail page renders timeline with author + timestamp; TASK_COMMENTED notification pushed to assignee + assigner',
     'None — comments thread live on every task detail page',
     'COVERED', 'High', 'Small'),

    ('4. Collaboration', '@mention another user',
     'task_service.add_comment() regex-parses @username tokens against core.users.username, stores mentioned_user_ids[] array, fires TASK_MENTIONED in-app notification; mentions highlight on render via render_mentions_html()',
     'None — @mention parsing + notifications live',
     'COVERED', 'Medium', 'Small'),

    ('4. Collaboration', 'Upload attachments',
     'None',
     'POST /tasks/<id>/attachments (multipart); virus-scan hook; display inline previews for images/PDFs',
     'GAP', 'Medium', 'Medium'),

    ('4. Collaboration', 'Reassign / delegate',
     'None — once assigned, it\'s stuck to that user',
     'POST /tasks/<id>/reassign body={"new_assignee_id":N,"reason":"..."}; captured in history; notify both old + new assignee',
     'GAP', 'Medium', 'Small'),

    ('4. Collaboration', 'Watchers / followers',
     'None',
     'New table core.task_watchers (task_id, user_id); watchers get all comment/status notifications without being the assignee',
     'GAP', 'Low', 'Small'),

    # ── 5. Recurrence & Templates ─────────────────────────────────
    ('5. Recurrence', 'Recurring task scheduler',
     'None',
     'Background job (APScheduler or cron) reads task.recurrence_rule daily + spawns next occurrence when parent completed; rec state persisted in parent_recurrence_id',
     'GAP', 'Medium', 'Medium'),

    ('5. Recurrence', 'Onboarding / offboarding templates',
     'Migration 61 created core.task_templates + seeded 5 templates: ONBOARD_NEW_HIRE (12 items, Day 0-Month 1 offsets), OFFBOARD_SEPARATION (9 items), MONTHLY_KPI_REPORT, QUARTERLY_IPCR, ANNUAL_SALN_FILING; HR spawns via /admin/task-templates/<code>/spawn with multi-employee picker',
     'None — full template library with one-click spawning',
     'COVERED', 'High', 'Medium'),

    ('5. Recurrence', 'Smart due date (business-days aware)',
     'due_date is a plain DATE — no holiday awareness',
     'Add helper add_business_days(start, n) that skips weekends + entries in leave_mgmt.holidays; use when spawning recurrences + "Due in 3 business days"',
     'GAP', 'Low', 'Small'),

    # ── 6. Notifications & Reminders ──────────────────────────────
    ('6. Notifications', 'In-app notification on task assignment',
     'task_inbox_service.create_task() now fires TASK_ASSIGNED notification when created_by ≠ user_id; task_service.create_task() does the same on user-initiated assignments; push_in_app() dispatches the in-app bell',
     'None — TASK_ASSIGNED fires automatically on every cross-user assignment',
     'COVERED', 'High', 'Small'),

    ('6. Notifications', 'Email notification on assignment',
     'Migration 61 seeded 5 ntf_templates: task_assigned, task_due_24h, task_overdue, task_commented, task_mentioned; notification_service.notify() renders them for both in-app (channel_id=1) and email (channel_id=2 when available)',
     'None — templates ready for email/in-app dispatch',
     'COVERED', 'High', 'Small'),

    ('6. Notifications', 'Due date reminder (e.g. 24h before)',
     'services/reminder_engine.py TRIGGER_QUERIES has TASK_DUE_24H — fires when due_date = CURRENT_DATE + 1; deduped via source_key=core.task_inbox:<id>; reminder_rules row ensures rule is active',
     'None — 24h-before reminder live',
     'COVERED', 'High', 'Small'),

    ('6. Notifications', 'Overdue escalation',
     'reminder_engine.TRIGGER_QUERIES TASK_OVERDUE fires on due_date < CURRENT_DATE; HIGH priority inbox task created daily while task stays open; dedupe via source_key=core.task_inbox:<id> prevents spam',
     'None — overdue reminder live',
     'COVERED', 'Medium', 'Small'),

    ('6. Notifications', 'Slack / MS Teams webhook',
     'None — in-app + email only',
     'Optional tenant-level webhook URL; on assignment/comment/overdue, POST JSON payload to configured webhook',
     'GAP', 'Low', 'Medium'),

    # ── 7. Access Control & Visibility ────────────────────────────
    ('7. Access Control', 'Pages in core.page_registry',
     'Migration 61 seeded 6 pages: /me/inbox, /tasks/, /tasks/new, /tasks/team, /admin/tasks, /admin/task-templates; role grants via role_page_access',
     'None — all task pages registered in access matrix',
     'COVERED', 'High', 'Small'),

    ('7. Access Control', 'Action features in feature_registry',
     'Migration 61 seeded 8 features: TASK_CREATE, TASK_ASSIGN, TASK_EDIT, TASK_COMPLETE, TASK_REASSIGN, TASK_COMMENT, TASK_DELETE, TASK_TEMPLATE_SPAWN; role_feature_access grants per tier',
     'None — features queryable from the access-matrix search box',
     'COVERED', 'High', 'Small'),

    ('7. Access Control', 'Department-scoped visibility',
     'task_service._apply_scope_filter() restricts non-admin queries to own tasks (assignee/assigner) + team-manager scope to own department; mirrors requisition_service._apply_role_filter pattern',
     'None — dept-scoped visibility live across inbox/team/detail/admin',
     'COVERED', 'High', 'Small'),

    ('7. Access Control', 'Privacy: personal tasks hidden from admin?',
     'None — admins can see everything',
     'Add is_private BOOLEAN DEFAULT FALSE; when TRUE only assignee + assigner can view (even SUPER_ADMIN sees "Private task" placeholder)',
     'GAP', 'Low', 'Small'),

    # ── 8. Reporting & Analytics ──────────────────────────────────
    ('8. Reporting', 'Dashboard KPI: open tasks count',
     'Migration 61 seeded 4 dashboard_metrics: tasks_open, tasks_overdue, tasks_completed_ytd, tasks_avg_completion_days; roles array drives RBAC; templated SQL uses {{user_id}} and {{role_code}} for per-user scope',
     'None — 4 task KPI cards live on dashboard',
     'COVERED', 'High', 'Small'),

    ('8. Reporting', 'Report Builder data source',
     'Migration 61 registered TASKS data source in analytics.report_data_sources with a 19-field report_field_registry (title, category, status, priority, due, age_days, is_overdue, assignee, department, assigner…); ARIA auto-discovers via services/aria_extensions.py',
     'None — TASKS source queryable in /reports/builder and ARIA',
     'COVERED', 'High', 'Medium'),

    ('8. Reporting', 'Task completion rate report',
     'None',
     'Preset report: per-user + per-department completion rate (completed / total), median turnaround, overdue %; weekly cadence',
     'GAP', 'Medium', 'Small'),

    ('8. Reporting', 'Personal productivity chart',
     'None',
     'On /me/inbox header: bar chart "tasks completed per week, last 12 weeks" using Chart.js; motivational streaks',
     'GAP', 'Low', 'Medium'),

    # ── 9. Integrations ───────────────────────────────────────────
    ('9. Integrations', 'ARIA AI query surface',
     'ARIA auto-discovers new report_data_sources — once TASKS is seeded, queries like "my overdue tasks" work instantly',
     'Ships automatically when TASKS data source is registered (no code change)',
     'PARTIAL', 'Medium', 'Small'),

    ('9. Integrations', 'Guided tour for first-time users',
     'None',
     'Seed core.tours tour_key=task-management-v1 — 6 steps: inbox → filters → quick-add → kanban → calendar → team view; auto-starts once at /me/inbox',
     'GAP', 'Medium', 'Small'),

    ('9. Integrations', 'Form field tooltips (data-hint)',
     'None',
     'Add data-hint attributes to every field on the new-task form (title, description, priority, due_date, assignee picker); tour engine auto-binds tooltip popovers',
     'GAP', 'Medium', 'Small'),

    ('9. Integrations', 'Workflow engine hook',
     'Workflow engine already creates tasks via create_task() for every step assignee',
     'None — integration already live',
     'COVERED', 'High', 'Small'),

    ('9. Integrations', 'Performance review / IPCR linkage',
     'No link between tasks and IPCR objectives',
     'Optional tasks.ipcr_objective_id FK → performance.ipcr_objectives; task completion auto-updates objective progress %',
     'GAP', 'Low', 'Medium'),

    ('9. Integrations', 'Calendar export (iCal)',
     'None',
     'GET /tasks/export.ics returns a per-user ICS feed (tasks with due_date) that can be subscribed from Google / Outlook calendars',
     'GAP', 'Low', 'Small'),

    ('9. Integrations', 'Mobile PWA support',
     'Inbox works on mobile browser but not installable as app',
     'Add web app manifest + service worker (offline-first for /me/inbox); install-to-home-screen prompt',
     'GAP', 'Low', 'Medium'),
]


# ── Build workbook ───────────────────────────────────────────────────
wb = Workbook()

# ═════════════════════════════════════════════════════════════════════
# Sheet 1 — Cover & Summary
# ═════════════════════════════════════════════════════════════════════
ws = wb.active
ws.title = 'Summary'

ws['A1'] = 'HCM360 HRIS — LGU Gap Analysis'
ws['A1'].font = TITLE_FONT
ws.merge_cells('A1:F1')

ws['A2'] = 'Municipality of Mariveles, Province of Bataan — Human Resource Management Office'
ws['A2'].font = SUB_FONT
ws.merge_cells('A2:F2')

ws['A3'] = f'As Of {TODAY.strftime("%B %d, %Y")}  ·  HCM360 v1.0.0'
ws['A3'].font = Font(name='Arial', size=10, color='FF9CA3AF')
ws.merge_cells('A3:F3')

# Coverage table
ws['A5'] = 'Coverage Summary'
ws['A5'].font = Font(name='Arial', size=13, bold=True, color=BLUE)
ws.merge_cells('A5:F5')

headers = ['Status', 'Count', '% of Total', 'Meaning']
for i, h in enumerate(headers, start=1):
    cell = ws.cell(row=7, column=i, value=h)
    cell.font = HEADER_FONT
    cell.fill = HEADER_FILL
    cell.alignment = CENTER
    cell.border = BORDER

total_rows = len(MATRIX)
# Use COUNTIF formulas against the Full Matrix sheet so it's dynamic
summary_rows = [
    ('COVERED', 'DCFCE7', '166534', 'Fully implemented — production-ready for LGU use'),
    ('PARTIAL', 'FEF3C7', '92400E', 'Exists; requires LGU-specific tuning, templates, or configuration'),
    ('GAP', 'FEE2E2', '991B1B', 'Needs new development before deployment'),
]
for idx, (status, fill, font_color, meaning) in enumerate(summary_rows):
    r = 8 + idx
    c1 = ws.cell(row=r, column=1, value=status)
    c1.font = Font(name='Arial', size=10, bold=True, color=f'FF{font_color}')
    c1.fill = PatternFill('solid', start_color=f'FF{fill}')
    c1.alignment = CENTER
    c1.border = BORDER
    # Formula-driven counts
    c2 = ws.cell(row=r, column=2,
                 value=f'=COUNTIF(\'Full Matrix\'!C:C,"{status}")')
    c2.alignment = CENTER
    c2.border = BORDER
    c2.font = NORMAL_FONT
    # % of total
    c3 = ws.cell(row=r, column=3, value=f'=B{r}/$B$11')
    c3.number_format = '0.0%'
    c3.alignment = CENTER
    c3.border = BORDER
    c3.font = NORMAL_FONT
    c4 = ws.cell(row=r, column=4, value=meaning)
    c4.alignment = LEFT_CTR
    c4.border = BORDER
    c4.font = NORMAL_FONT
    ws.merge_cells(start_row=r, start_column=4, end_row=r, end_column=6)

# Total row
r = 11
c1 = ws.cell(row=r, column=1, value='TOTAL')
c1.font = BOLD_FONT
c1.fill = PatternFill('solid', start_color=BLUE)
c1.font = Font(name='Arial', size=10, bold=True, color=WHITE)
c1.alignment = CENTER
c1.border = BORDER
c2 = ws.cell(row=r, column=2, value='=SUM(B8:B10)')
c2.alignment = CENTER
c2.border = BORDER
c2.font = BOLD_FONT
c3 = ws.cell(row=r, column=3, value=1.0)
c3.number_format = '0.0%'
c3.alignment = CENTER
c3.border = BORDER
c3.font = BOLD_FONT
c4 = ws.cell(row=r, column=4, value='Requirements mapped from LGU document')
c4.alignment = LEFT_CTR
c4.border = BORDER
c4.font = BOLD_FONT
ws.merge_cells(start_row=r, start_column=4, end_row=r, end_column=6)

# Column widths
ws.column_dimensions['A'].width = 14
ws.column_dimensions['B'].width = 10
ws.column_dimensions['C'].width = 12
ws.column_dimensions['D'].width = 30
ws.column_dimensions['E'].width = 30
ws.column_dimensions['F'].width = 20

# Critical gaps callout
ws['A14'] = 'Critical Gaps — Top Priorities for LGU Deployment'
ws['A14'].font = Font(name='Arial', size=13, bold=True, color=BLUE)
ws.merge_cells('A14:F14')

critical = [
    'CS Form No. 6 (revised 2020) — leave application strict compliance',
    'CS Form No. 7 (s.2017) — Exit Interview',
    'Personal Data Sheet (PDS) — CSC-prescribed template with versioning',
    'IPCR / OPCR performance contract templates',
    'Travel Order + Locator Slip modules (pre-approval + DTR integration)',
    'Face-recognition + mobile geo-tagged check-in (flag raising/lowering)',
    'Step Increment tracking (every 3 years from Date of Original Appointment)',
    'Retirement monitoring (Age 60 early / 65 mandatory) + multi-recipient notice',
    'Job Order / LSB / BHW / Nutritionist Scholar contract workflows',
    'CSC Eligibility reporting split by 1st Level vs 2nd Level by gender',
]
for i, txt in enumerate(critical, start=16):
    ws.cell(row=i, column=1, value=f'• {txt}').font = NORMAL_FONT
    ws.merge_cells(start_row=i, start_column=1, end_row=i, end_column=6)

ws.sheet_view.showGridLines = False


# ═════════════════════════════════════════════════════════════════════
# Sheet 2 — Full Matrix
# ═════════════════════════════════════════════════════════════════════
ws2 = wb.create_sheet('Full Matrix')

cols = ['Section', 'Requirement', 'Status', 'HCM360 Module', 'Page / Route',
        'Gap / Notes', 'Priority']
for i, h in enumerate(cols, start=1):
    c = ws2.cell(row=1, column=i, value=h)
    c.font = HEADER_FONT
    c.fill = HEADER_FILL
    c.alignment = CENTER
    c.border = BORDER

for r_idx, row in enumerate(MATRIX, start=2):
    for c_idx, val in enumerate(row, start=1):
        c = ws2.cell(row=r_idx, column=c_idx, value=val)
        c.font = NORMAL_FONT
        c.alignment = LEFT
        c.border = BORDER
    # Color the Status cell
    status_cell = ws2.cell(row=r_idx, column=3)
    s = row[2]
    if s == 'COVERED':
        status_cell.fill = GREEN_FILL
        status_cell.font = GREEN_FONT
    elif s == 'PARTIAL':
        status_cell.fill = AMBER_FILL
        status_cell.font = AMBER_FONT
    elif s == 'GAP':
        status_cell.fill = RED_FILL
        status_cell.font = RED_FONT
    status_cell.alignment = CENTER

# Column widths + wrap
widths = [32, 55, 11, 28, 38, 55, 10]
for i, w in enumerate(widths, start=1):
    ws2.column_dimensions[get_column_letter(i)].width = w

# Row heights auto-ish by content
for r in range(2, len(MATRIX) + 2):
    ws2.row_dimensions[r].height = 36

# Freeze header + enable autofilter
ws2.freeze_panes = 'A2'
ws2.auto_filter.ref = f'A1:G{len(MATRIX) + 1}'
ws2.sheet_view.showGridLines = False


# ═════════════════════════════════════════════════════════════════════
# Sheet 3 — Gap Backlog (build list)
# ═════════════════════════════════════════════════════════════════════
ws3 = wb.create_sheet('Gap Backlog')
ws3['A1'] = 'Gap Backlog — Items to Build for LGU Deployment'
ws3['A1'].font = TITLE_FONT
ws3.merge_cells('A1:G1')

gap_cols = ['ID', 'Requirement', 'Target Module', 'Target Page / Route',
            'Effort Size', 'Estimate', 'Priority']
for i, h in enumerate(gap_cols, start=1):
    c = ws3.cell(row=3, column=i, value=h)
    c.font = HEADER_FONT
    c.fill = HEADER_FILL
    c.alignment = CENTER
    c.border = BORDER

for r_idx, row in enumerate(GAP_BACKLOG, start=4):
    for c_idx, val in enumerate(row, start=1):
        c = ws3.cell(row=r_idx, column=c_idx, value=val)
        c.font = NORMAL_FONT
        c.alignment = LEFT
        c.border = BORDER
    # Color priority
    prio_cell = ws3.cell(row=r_idx, column=7)
    if row[6] == 'High':
        prio_cell.fill = RED_FILL
        prio_cell.font = RED_FONT
    else:
        prio_cell.fill = AMBER_FILL
        prio_cell.font = AMBER_FONT
    prio_cell.alignment = CENTER

widths = [8, 55, 28, 40, 14, 14, 12]
for i, w in enumerate(widths, start=1):
    ws3.column_dimensions[get_column_letter(i)].width = w

for r in range(4, len(GAP_BACKLOG) + 4):
    ws3.row_dimensions[r].height = 32

# Totals at bottom
total_row = len(GAP_BACKLOG) + 4
ws3.cell(row=total_row, column=1, value='Totals').font = BOLD_FONT
ws3.cell(row=total_row, column=2,
         value=f'=COUNTA(A4:A{total_row-1}) & " items"').font = BOLD_FONT
ws3.cell(row=total_row, column=5,
         value=f'Small: ' + str(sum(1 for r in GAP_BACKLOG if r[4] == 'Small'))
         + ' / Medium: ' + str(sum(1 for r in GAP_BACKLOG if r[4] == 'Medium'))
         + ' / Large: ' + str(sum(1 for r in GAP_BACKLOG if r[4] == 'Large'))
         ).font = BOLD_FONT
ws3.cell(row=total_row, column=7,
         value='High: ' + str(sum(1 for r in GAP_BACKLOG if r[6] == 'High'))
         + ' / Med: ' + str(sum(1 for r in GAP_BACKLOG if r[6] == 'Medium'))
         ).font = BOLD_FONT

ws3.freeze_panes = 'A4'
ws3.auto_filter.ref = f'A3:G{total_row - 1}'
ws3.sheet_view.showGridLines = False


# ═════════════════════════════════════════════════════════════════════
# Sheet 4 — Partial Refinements
# ═════════════════════════════════════════════════════════════════════
ws4 = wb.create_sheet('Partial Refinements')
ws4['A1'] = 'Partial Refinements — Configuration & Minor Build Tasks'
ws4['A1'].font = TITLE_FONT
ws4.merge_cells('A1:D1')

pcols = ['ID', 'Refinement', 'Target Module', 'Action']
for i, h in enumerate(pcols, start=1):
    c = ws4.cell(row=3, column=i, value=h)
    c.font = HEADER_FONT
    c.fill = HEADER_FILL
    c.alignment = CENTER
    c.border = BORDER

for r_idx, row in enumerate(PARTIAL_BACKLOG, start=4):
    for c_idx, val in enumerate(row, start=1):
        c = ws4.cell(row=r_idx, column=c_idx, value=val)
        c.font = NORMAL_FONT
        c.alignment = LEFT
        c.border = BORDER

widths = [8, 55, 28, 70]
for i, w in enumerate(widths, start=1):
    ws4.column_dimensions[get_column_letter(i)].width = w
for r in range(4, len(PARTIAL_BACKLOG) + 4):
    ws4.row_dimensions[r].height = 30

ws4.freeze_panes = 'A4'
ws4.auto_filter.ref = f'A3:D{len(PARTIAL_BACKLOG) + 3}'
ws4.sheet_view.showGridLines = False


# ═════════════════════════════════════════════════════════════════════
# Sheet 5 — Module Coverage (pivot-ish) using formulas
# ═════════════════════════════════════════════════════════════════════
ws5 = wb.create_sheet('Module Coverage')
ws5['A1'] = 'Coverage by HCM360 Module'
ws5['A1'].font = TITLE_FONT
ws5.merge_cells('A1:F1')

modules = [
    'Core HR', 'Attendance', 'Leave Management', 'Payroll', 'Recruitment',
    'Performance Management', 'Learning & Development', 'Rewards & Recognition',
    'DMS', 'Workforce Planning', 'Analytics', 'ESS', 'MSS', 'AI', 'Orgchart',
    'Access Service', 'Audit Logs', 'Infrastructure', 'Reminders', 'Privacy',
    'Services', 'Onboarding', 'Reporting Service', 'Admin', 'UI',
    'Tasks', 'Health', 'Dashboard', 'Employee Picker',
]

mcols = ['Module', 'COVERED', 'PARTIAL', 'GAP', 'Total', 'Coverage %']
for i, h in enumerate(mcols, start=1):
    c = ws5.cell(row=3, column=i, value=h)
    c.font = HEADER_FONT
    c.fill = HEADER_FILL
    c.alignment = CENTER
    c.border = BORDER

for idx, mod in enumerate(modules):
    r = 4 + idx
    c = ws5.cell(row=r, column=1, value=mod)
    c.font = NORMAL_FONT
    c.alignment = LEFT_CTR
    c.border = BORDER
    # Covered count
    for col_idx, status in enumerate(['COVERED', 'PARTIAL', 'GAP'], start=2):
        cell = ws5.cell(
            row=r, column=col_idx,
            value=f'=COUNTIFS(\'Full Matrix\'!D:D,"*"&A{r}&"*",\'Full Matrix\'!C:C,"{status}")'
        )
        cell.alignment = CENTER
        cell.border = BORDER
        cell.font = NORMAL_FONT
        if status == 'COVERED':
            cell.fill = GREEN_FILL
        elif status == 'PARTIAL':
            cell.fill = AMBER_FILL
        elif status == 'GAP':
            cell.fill = RED_FILL
    # Total
    tot = ws5.cell(row=r, column=5, value=f'=SUM(B{r}:D{r})')
    tot.alignment = CENTER
    tot.border = BORDER
    tot.font = BOLD_FONT
    # Coverage %
    cov = ws5.cell(row=r, column=6,
                   value=f'=IF(E{r}=0,0,B{r}/E{r})')
    cov.number_format = '0.0%'
    cov.alignment = CENTER
    cov.border = BORDER
    cov.font = NORMAL_FONT

# Totals row
last_r = 4 + len(modules)
ws5.cell(row=last_r, column=1, value='ALL MODULES').font = Font(
    name='Arial', size=10, bold=True, color=WHITE)
ws5.cell(row=last_r, column=1).fill = HEADER_FILL
ws5.cell(row=last_r, column=1).alignment = CENTER
ws5.cell(row=last_r, column=1).border = BORDER
for col in range(2, 6):
    c = ws5.cell(row=last_r, column=col,
                 value=f'=SUM({get_column_letter(col)}4:{get_column_letter(col)}{last_r-1})')
    c.font = BOLD_FONT
    c.alignment = CENTER
    c.border = BORDER
cov_total = ws5.cell(row=last_r, column=6,
                     value=f'=IF(E{last_r}=0,0,B{last_r}/E{last_r})')
cov_total.number_format = '0.0%'
cov_total.font = BOLD_FONT
cov_total.alignment = CENTER
cov_total.border = BORDER

widths = [30, 11, 11, 11, 11, 14]
for i, w in enumerate(widths, start=1):
    ws5.column_dimensions[get_column_letter(i)].width = w

ws5.freeze_panes = 'A4'
ws5.sheet_view.showGridLines = False


# ═════════════════════════════════════════════════════════════════════
# Sheet 6 — Phased Roadmap
# ═════════════════════════════════════════════════════════════════════
ws6 = wb.create_sheet('Roadmap')
ws6['A1'] = 'Recommended Phasing for LGU Deployment'
ws6['A1'].font = TITLE_FONT
ws6.merge_cells('A1:D1')

phases = [
    ('Phase 1', 'Weeks 1-4', 'LGU Readiness Baseline', 'Configure reference data (CTO, JO, COS, rank classification, retention policies)'),
    ('Phase 1', 'Weeks 1-4', 'LGU Readiness Baseline', 'Wire SMTP for reminders and report delivery'),
    ('Phase 1', 'Weeks 1-4', 'LGU Readiness Baseline', 'Deploy behind TLS reverse proxy with production SECRET_KEY rotation'),
    ('Phase 1', 'Weeks 1-4', 'LGU Readiness Baseline', 'Seed LGU-specific departments, positions, plantilla'),
    ('Phase 1', 'Weeks 1-4', 'LGU Readiness Baseline', 'Train HR administrators on access matrix and privacy rules'),
    ('Phase 2', 'Weeks 5-10', 'Critical CSC Forms', 'CS Form No. 6 leave application (strict)'),
    ('Phase 2', 'Weeks 5-10', 'Critical CSC Forms', 'CS Form No. 7 exit interview'),
    ('Phase 2', 'Weeks 5-10', 'Critical CSC Forms', 'Personal Data Sheet (PDS) with auto-fill'),
    ('Phase 2', 'Weeks 5-10', 'Critical CSC Forms', 'IPCR / OPCR templates for performance reviews'),
    ('Phase 2', 'Weeks 5-10', 'Critical CSC Forms', 'Travel Order + Locator Slip modules'),
    ('Phase 2', 'Weeks 5-10', 'Critical CSC Forms', 'Loyalty Award, Step Increment, Retirement notice workflows'),
    ('Phase 3', 'Weeks 11-16', 'Mobile & Biometrics', 'Native mobile app (Flutter / React Native) for employees'),
    ('Phase 3', 'Weeks 11-16', 'Mobile & Biometrics', 'Geolocation + photo check-in (flag raising/lowering, training)'),
    ('Phase 3', 'Weeks 11-16', 'Mobile & Biometrics', 'Face-recognition biometric attendance integration'),
    ('Phase 3', 'Weeks 11-16', 'Mobile & Biometrics', 'Electronic signature integration (DocuSign or local PKI)'),
    ('Phase 4', 'Weeks 17-20', 'Intelligence', 'Attrition risk scoring model'),
    ('Phase 4', 'Weeks 17-20', 'Intelligence', 'Chatbot conversational UI'),
    ('Phase 4', 'Weeks 17-20', 'Intelligence', 'Drag-drop report builder'),
    ('Phase 4', 'Weeks 17-20', 'Intelligence', 'Drag-drop org-chart editor with vacancy overlay'),
]

rcols = ['Phase', 'Timeline', 'Theme', 'Deliverable']
for i, h in enumerate(rcols, start=1):
    c = ws6.cell(row=3, column=i, value=h)
    c.font = HEADER_FONT
    c.fill = HEADER_FILL
    c.alignment = CENTER
    c.border = BORDER

phase_colors = {
    'Phase 1': 'FFDCFCE7',
    'Phase 2': 'FFFEF3C7',
    'Phase 3': 'FFDBEAFE',
    'Phase 4': 'FFEDE9FE',
}
for r_idx, row in enumerate(phases, start=4):
    for c_idx, val in enumerate(row, start=1):
        c = ws6.cell(row=r_idx, column=c_idx, value=val)
        c.font = NORMAL_FONT
        c.alignment = LEFT_CTR
        c.border = BORDER
    # Color phase column
    ws6.cell(row=r_idx, column=1).fill = PatternFill('solid',
                                                      start_color=phase_colors.get(row[0], 'FFFFFFFF'))

widths = [12, 15, 28, 70]
for i, w in enumerate(widths, start=1):
    ws6.column_dimensions[get_column_letter(i)].width = w
for r in range(4, len(phases) + 4):
    ws6.row_dimensions[r].height = 28

ws6.freeze_panes = 'A4'
ws6.sheet_view.showGridLines = False


# ═════════════════════════════════════════════════════════════════════
# Sheet 7 — Features Built vs Requested  (value-add scoring)
# ═════════════════════════════════════════════════════════════════════
ws7 = wb.create_sheet('Features vs Requested')
ws7['A1'] = 'Features Built vs Requested — Value-Add Scoring'
ws7['A1'].font = TITLE_FONT
ws7.merge_cells('A1:E1')

ws7['A2'] = ('Inventory of every feature currently delivered, flagged against the Municipality '
             'of Mariveles HRMO requirements. "Bonus" rows were built beyond the original '
             'scope as added value.')
ws7['A2'].font = NORMAL_FONT
ws7['A2'].alignment = Alignment(wrap_text=True, vertical='top')
ws7.merge_cells('A2:E2')
ws7.row_dimensions[2].height = 34

# Count scoring numbers
total = len(BUILD_FEATURE_CATALOG)
requested = sum(1 for f in BUILD_FEATURE_CATALOG if f[2])
bonus = total - requested
live_requested = sum(1 for f in BUILD_FEATURE_CATALOG if f[2] and f[3] == 'LIVE')
live_bonus = sum(1 for f in BUILD_FEATURE_CATALOG if not f[2] and f[3] == 'LIVE')
coverage_pct = (live_requested / requested * 100) if requested else 0
value_multiplier = (total / requested) if requested else 0

# Scoring block
ws7['A4'] = 'Scoring Summary'
ws7['A4'].font = Font(name='Arial', size=13, bold=True, color=BLUE)
ws7.merge_cells('A4:E4')

score_rows = [
    ('Features Requested by LGU',        requested,        '100%',                                     'baseline'),
    ('Requested — LIVE in current build', live_requested, f'{coverage_pct:.0f}% of requested',        'green'),
    ('Bonus Features Beyond Request',    bonus,            f'+{bonus / requested * 100:.0f}% extra'   if requested else '—', 'blue'),
    ('Total Features Delivered',         total,            f'{value_multiplier:.2f}x multiplier',      'purple'),
]

score_colors = {
    'baseline': 'FFF3F4F6',
    'green':    'FFDCFCE7',
    'blue':     'FFDBEAFE',
    'purple':   'FFEDE9FE',
}

for i, (label, count, pct, color_key) in enumerate(score_rows, start=6):
    ws7.cell(row=i, column=1, value=label).font = Font(name='Arial', size=11, bold=True)
    ws7.cell(row=i, column=2, value=count).font = Font(name='Arial', size=14, bold=True, color=BLUE)
    ws7.cell(row=i, column=3, value=pct).font = Font(name='Arial', size=11, italic=True, color='FF6B7280')
    for col in range(1, 4):
        c = ws7.cell(row=i, column=col)
        c.fill = PatternFill('solid', start_color=score_colors[color_key])
        c.border = BORDER
        c.alignment = LEFT_CTR

# Feature catalog table
ws7['A11'] = 'Feature Catalog'
ws7['A11'].font = Font(name='Arial', size=13, bold=True, color=BLUE)
ws7.merge_cells('A11:E11')

catalog_cols = ['Module', 'Feature', 'In LGU Request?', 'Status', 'Category']
for i, h in enumerate(catalog_cols, start=1):
    c = ws7.cell(row=13, column=i, value=h)
    c.font = HEADER_FONT
    c.fill = HEADER_FILL
    c.alignment = CENTER
    c.border = BORDER

for r_idx, (module, feature, in_req, status) in enumerate(BUILD_FEATURE_CATALOG, start=14):
    category = 'Requested' if in_req else 'Bonus (Beyond Scope)'
    values = [module, feature, 'YES' if in_req else 'NO', status, category]
    for c_idx, v in enumerate(values, start=1):
        c = ws7.cell(row=r_idx, column=c_idx, value=v)
        c.font = NORMAL_FONT
        c.border = BORDER
        c.alignment = LEFT_CTR if c_idx in (1, 3, 4, 5) else Alignment(wrap_text=True, vertical='center')
    # Color-code "In Request?"
    req_cell = ws7.cell(row=r_idx, column=3)
    req_cell.fill = PatternFill('solid', start_color='FFDCFCE7' if in_req else 'FFDBEAFE')
    req_cell.font = Font(name='Arial', size=10, bold=True,
                         color='FF166534' if in_req else 'FF1E40AF')
    # Category chip
    cat_cell = ws7.cell(row=r_idx, column=5)
    cat_cell.fill = PatternFill('solid', start_color='FFF3F4F6' if in_req else 'FFEDE9FE')
    cat_cell.font = Font(name='Arial', size=9, italic=True,
                         color='FF6B7280' if in_req else 'FF5B21B6')
    # Status chip
    st_cell = ws7.cell(row=r_idx, column=4)
    if status == 'LIVE':
        st_cell.fill = PatternFill('solid', start_color='FFDCFCE7')
        st_cell.font = Font(name='Arial', size=9, bold=True, color='FF166534')
    else:
        st_cell.fill = PatternFill('solid', start_color='FFFEF3C7')
        st_cell.font = Font(name='Arial', size=9, bold=True, color='FF92400E')

# Column widths
ws7.column_dimensions['A'].width = 20
ws7.column_dimensions['B'].width = 62
ws7.column_dimensions['C'].width = 16
ws7.column_dimensions['D'].width = 12
ws7.column_dimensions['E'].width = 24

ws7.freeze_panes = 'A14'
ws7.auto_filter.ref = f'A13:E{13 + len(BUILD_FEATURE_CATALOG)}'
ws7.sheet_view.showGridLines = False


# ═════════════════════════════════════════════════════════════════════
# Sheet 8 — Job Requisition Feature Gap Analysis (focused deep-dive)
# ═════════════════════════════════════════════════════════════════════
ws8 = wb.create_sheet('Job Requisition Gap')
ws8['A1'] = 'Gap Analysis — Create Job Requisition Feature'
ws8['A1'].font = TITLE_FONT
ws8.merge_cells('A1:G1')

ws8['A2'] = ('Focused deep-dive on the "Create Job Requisition" capability. Covers 8 categories: '
             'Data Model, Create Flow, Approval Workflow, Publication, Notifications, Access '
             'Control, Reporting, and Integration & Compliance. Each row shows what''s in place '
             'today, what''s missing, and the priority/effort estimate.')
ws8['A2'].font = NORMAL_FONT
ws8['A2'].alignment = Alignment(wrap_text=True, vertical='top')
ws8.merge_cells('A2:G2')
ws8.row_dimensions[2].height = 50

# ── Scoring summary ───────────────────────────────────────────
total_req = len(JOB_REQUISITION_GAP)
cov_req = sum(1 for r in JOB_REQUISITION_GAP if r[4] == 'COVERED')
par_req = sum(1 for r in JOB_REQUISITION_GAP if r[4] == 'PARTIAL')
gap_req = sum(1 for r in JOB_REQUISITION_GAP if r[4] == 'GAP')
high_pri = sum(1 for r in JOB_REQUISITION_GAP if r[5] == 'High' and r[4] != 'COVERED')
med_pri  = sum(1 for r in JOB_REQUISITION_GAP if r[5] == 'Medium' and r[4] != 'COVERED')
low_pri  = sum(1 for r in JOB_REQUISITION_GAP if r[5] == 'Low' and r[4] != 'COVERED')

ws8['A4'] = 'Scoring Summary'
ws8['A4'].font = Font(name='Arial', size=13, bold=True, color=BLUE)
ws8.merge_cells('A4:G4')

jr_score_rows = [
    ('Total Aspects Analyzed',   total_req, '100% of feature surface'),
    ('Already COVERED',          cov_req,   f'{cov_req/total_req*100:.0f}%'),
    ('PARTIAL (needs refinement)', par_req, f'{par_req/total_req*100:.0f}%'),
    ('GAP (must build)',         gap_req,   f'{gap_req/total_req*100:.0f}%'),
    ('High-priority open items', high_pri,  'build first'),
    ('Medium-priority open items', med_pri, 'build next'),
    ('Low-priority open items',  low_pri,   'nice-to-have'),
]
jr_score_colors = ['FFF3F4F6','FFDCFCE7','FFFEF3C7','FFFEE2E2',
                   'FFFEE2E2','FFFEF3C7','FFDBEAFE']
for i, ((label, count, pct), color) in enumerate(zip(jr_score_rows, jr_score_colors), start=6):
    ws8.cell(row=i, column=1, value=label).font = Font(name='Arial', size=11, bold=True)
    ws8.cell(row=i, column=2, value=count).font = Font(name='Arial', size=14, bold=True, color=BLUE)
    ws8.cell(row=i, column=3, value=pct).font = Font(name='Arial', size=10, italic=True, color='FF6B7280')
    for col in range(1, 4):
        c = ws8.cell(row=i, column=col)
        c.fill = PatternFill('solid', start_color=color)
        c.border = BORDER
        c.alignment = LEFT_CTR

# Readiness verdict
readiness_pct = (cov_req + par_req * 0.5) / total_req * 100
ws8['A14'] = 'Feature Readiness'
ws8['A14'].font = Font(name='Arial', size=13, bold=True, color=BLUE)
ws8.merge_cells('A14:G14')
ws8['A15'] = (f'Current feature readiness: {readiness_pct:.0f}% '
              f'(COVERED counted as 1.0, PARTIAL as 0.5). '
              f'To reach 100%, build the {gap_req} GAP items below, '
              f'starting with the {high_pri} High-priority ones.')
ws8['A15'].font = NORMAL_FONT
ws8['A15'].alignment = Alignment(wrap_text=True, vertical='top')
ws8.merge_cells('A15:G15')
ws8.row_dimensions[15].height = 36

# ── Catalog header ────────────────────────────────────────────
ws8['A17'] = 'Detailed Gap Analysis'
ws8['A17'].font = Font(name='Arial', size=13, bold=True, color=BLUE)
ws8.merge_cells('A17:G17')

req_cols = ['Category', 'Aspect', 'Current State',
            'Gap / Action Needed', 'Status', 'Priority', 'Effort']
for i, h in enumerate(req_cols, start=1):
    c = ws8.cell(row=19, column=i, value=h)
    c.font = HEADER_FONT
    c.fill = HEADER_FILL
    c.alignment = CENTER
    c.border = BORDER

# Rows
status_fill = {
    'COVERED': 'FFDCFCE7',
    'PARTIAL': 'FFFEF3C7',
    'GAP':     'FFFEE2E2',
}
status_color = {
    'COVERED': 'FF166534',
    'PARTIAL': 'FF92400E',
    'GAP':     'FF991B1B',
}
priority_fill = {
    'High':   'FFFEE2E2',
    'Medium': 'FFFEF3C7',
    'Low':    'FFE0E7FF',
}
priority_color = {
    'High':   'FF991B1B',
    'Medium': 'FF92400E',
    'Low':    'FF3730A3',
}
effort_fill = {
    'Small':  'FFDCFCE7',
    'Medium': 'FFDBEAFE',
    'Large':  'FFFCE7F3',
}

for r_idx, (category, aspect, current, gap_txt, status, priority, effort) in \
        enumerate(JOB_REQUISITION_GAP, start=20):
    values = [category, aspect, current, gap_txt, status, priority, effort]
    for c_idx, v in enumerate(values, start=1):
        c = ws8.cell(row=r_idx, column=c_idx, value=v)
        c.font = NORMAL_FONT
        c.border = BORDER
        c.alignment = Alignment(wrap_text=True, vertical='top')

    # Status chip
    sc = ws8.cell(row=r_idx, column=5)
    sc.fill = PatternFill('solid', start_color=status_fill[status])
    sc.font = Font(name='Arial', size=10, bold=True, color=status_color[status])
    sc.alignment = CENTER

    # Priority chip
    pc = ws8.cell(row=r_idx, column=6)
    pc.fill = PatternFill('solid', start_color=priority_fill.get(priority, 'FFFFFFFF'))
    pc.font = Font(name='Arial', size=10, bold=True,
                   color=priority_color.get(priority, 'FF111827'))
    pc.alignment = CENTER

    # Effort chip
    ec = ws8.cell(row=r_idx, column=7)
    ec.fill = PatternFill('solid', start_color=effort_fill.get(effort, 'FFFFFFFF'))
    ec.font = Font(name='Arial', size=10, bold=True)
    ec.alignment = CENTER

    # Row height adjusts for wrapped text
    ws8.row_dimensions[r_idx].height = 42

# Column widths
ws8.column_dimensions['A'].width = 18
ws8.column_dimensions['B'].width = 42
ws8.column_dimensions['C'].width = 48
ws8.column_dimensions['D'].width = 56
ws8.column_dimensions['E'].width = 12
ws8.column_dimensions['F'].width = 11
ws8.column_dimensions['G'].width = 10

ws8.freeze_panes = 'A20'
ws8.auto_filter.ref = f'A19:G{19 + len(JOB_REQUISITION_GAP)}'
ws8.sheet_view.showGridLines = False


# ═════════════════════════════════════════════════════════════════════
# Sheet 9 — Task Management Feature Gap Analysis (focused deep-dive)
# ═════════════════════════════════════════════════════════════════════
ws9 = wb.create_sheet('Task Management Gap')
ws9['A1'] = 'Gap Analysis — Task Management Feature'
ws9['A1'].font = TITLE_FONT
ws9.merge_cells('A1:G1')

ws9['A2'] = ('Focused deep-dive on the Task Management capability. Today the platform has a '
             'PASSIVE inbox (system-generated tasks from workflow approvals and the reminder '
             'engine); it lacks user-initiated creation, assignment to others, collaboration, '
             'recurrence, and reporting. This sheet audits 9 categories: Data Model, Create Flow, '
             'Views, Collaboration, Recurrence, Notifications, Access Control, Reporting, '
             'and Integrations.')
ws9['A2'].font = NORMAL_FONT
ws9['A2'].alignment = Alignment(wrap_text=True, vertical='top')
ws9.merge_cells('A2:G2')
ws9.row_dimensions[2].height = 60

# ── Scoring summary ───────────────────────────────────────────
total_tm = len(TASK_MANAGEMENT_GAP)
cov_tm = sum(1 for r in TASK_MANAGEMENT_GAP if r[4] == 'COVERED')
par_tm = sum(1 for r in TASK_MANAGEMENT_GAP if r[4] == 'PARTIAL')
gap_tm = sum(1 for r in TASK_MANAGEMENT_GAP if r[4] == 'GAP')
high_tm = sum(1 for r in TASK_MANAGEMENT_GAP if r[5] == 'High' and r[4] != 'COVERED')
med_tm  = sum(1 for r in TASK_MANAGEMENT_GAP if r[5] == 'Medium' and r[4] != 'COVERED')
low_tm  = sum(1 for r in TASK_MANAGEMENT_GAP if r[5] == 'Low' and r[4] != 'COVERED')

ws9['A4'] = 'Scoring Summary'
ws9['A4'].font = Font(name='Arial', size=13, bold=True, color=BLUE)
ws9.merge_cells('A4:G4')

tm_score_rows = [
    ('Total Aspects Analyzed',     total_tm, '100% of feature surface'),
    ('Already COVERED',            cov_tm,   f'{cov_tm/total_tm*100:.0f}%'),
    ('PARTIAL (needs refinement)', par_tm,   f'{par_tm/total_tm*100:.0f}%'),
    ('GAP (must build)',           gap_tm,   f'{gap_tm/total_tm*100:.0f}%'),
    ('High-priority open items',   high_tm,  'build first'),
    ('Medium-priority open items', med_tm,   'build next'),
    ('Low-priority open items',    low_tm,   'nice-to-have'),
]
tm_score_colors = ['FFF3F4F6','FFDCFCE7','FFFEF3C7','FFFEE2E2',
                   'FFFEE2E2','FFFEF3C7','FFDBEAFE']
for i, ((label, count, pct), color) in enumerate(zip(tm_score_rows, tm_score_colors), start=6):
    ws9.cell(row=i, column=1, value=label).font = Font(name='Arial', size=11, bold=True)
    ws9.cell(row=i, column=2, value=count).font = Font(name='Arial', size=14, bold=True, color=BLUE)
    ws9.cell(row=i, column=3, value=pct).font = Font(name='Arial', size=10, italic=True, color='FF6B7280')
    for col in range(1, 4):
        c = ws9.cell(row=i, column=col)
        c.fill = PatternFill('solid', start_color=color)
        c.border = BORDER
        c.alignment = LEFT_CTR

# Readiness verdict
tm_readiness_pct = (cov_tm + par_tm * 0.5) / total_tm * 100
ws9['A14'] = 'Feature Readiness'
ws9['A14'].font = Font(name='Arial', size=13, bold=True, color=BLUE)
ws9.merge_cells('A14:G14')
ws9['A15'] = (f'Current feature readiness: {tm_readiness_pct:.0f}% '
              f'(COVERED counted as 1.0, PARTIAL as 0.5). '
              f'Infrastructure (table, inbox page, workflow integration) is in place, '
              f'but user-initiated creation, assignment, collaboration, recurrence, and '
              f'reporting are not yet built. To reach 100%, build the {gap_tm} GAP items below, '
              f'starting with the {high_tm} High-priority ones.')
ws9['A15'].font = NORMAL_FONT
ws9['A15'].alignment = Alignment(wrap_text=True, vertical='top')
ws9.merge_cells('A15:G15')
ws9.row_dimensions[15].height = 54

# ── Catalog header ────────────────────────────────────────────
ws9['A17'] = 'Detailed Gap Analysis'
ws9['A17'].font = Font(name='Arial', size=13, bold=True, color=BLUE)
ws9.merge_cells('A17:G17')

tm_cols = ['Category', 'Aspect', 'Current State',
           'Gap / Action Needed', 'Status', 'Priority', 'Effort']
for i, h in enumerate(tm_cols, start=1):
    c = ws9.cell(row=19, column=i, value=h)
    c.font = HEADER_FONT
    c.fill = HEADER_FILL
    c.alignment = CENTER
    c.border = BORDER

for r_idx, (category, aspect, current, gap_txt, status, priority, effort) in \
        enumerate(TASK_MANAGEMENT_GAP, start=20):
    values = [category, aspect, current, gap_txt, status, priority, effort]
    for c_idx, v in enumerate(values, start=1):
        c = ws9.cell(row=r_idx, column=c_idx, value=v)
        c.font = NORMAL_FONT
        c.border = BORDER
        c.alignment = Alignment(wrap_text=True, vertical='top')

    # Status chip
    sc = ws9.cell(row=r_idx, column=5)
    sc.fill = PatternFill('solid', start_color=status_fill[status])
    sc.font = Font(name='Arial', size=10, bold=True, color=status_color[status])
    sc.alignment = CENTER

    # Priority chip
    pc = ws9.cell(row=r_idx, column=6)
    pc.fill = PatternFill('solid', start_color=priority_fill.get(priority, 'FFFFFFFF'))
    pc.font = Font(name='Arial', size=10, bold=True,
                   color=priority_color.get(priority, 'FF111827'))
    pc.alignment = CENTER

    # Effort chip
    ec = ws9.cell(row=r_idx, column=7)
    ec.fill = PatternFill('solid', start_color=effort_fill.get(effort, 'FFFFFFFF'))
    ec.font = Font(name='Arial', size=10, bold=True)
    ec.alignment = CENTER

    ws9.row_dimensions[r_idx].height = 44

# Column widths
ws9.column_dimensions['A'].width = 18
ws9.column_dimensions['B'].width = 42
ws9.column_dimensions['C'].width = 48
ws9.column_dimensions['D'].width = 56
ws9.column_dimensions['E'].width = 12
ws9.column_dimensions['F'].width = 11
ws9.column_dimensions['G'].width = 10

ws9.freeze_panes = 'A20'
ws9.auto_filter.ref = f'A19:G{19 + len(TASK_MANAGEMENT_GAP)}'
ws9.sheet_view.showGridLines = False


# ═════════════════════════════════════════════════════════════════════
# Archive prior snapshots + Save
# ═════════════════════════════════════════════════════════════════════
OUT.parent.mkdir(parents=True, exist_ok=True)
ARCHIVE.mkdir(parents=True, exist_ok=True)

# Move any existing dated snapshots (that aren't today's) into archive/
archived = 0
for f in HERE.glob('LGU_Mariveles_Gap_Analysis_AsOf_*.xlsx'):
    if f.name == FNAME:
        continue  # today's file will be overwritten below
    if f.name.startswith('~$'):
        continue  # skip Excel lock files
    dest = ARCHIVE / f.name
    if dest.exists():
        dest.unlink()
    shutil.move(str(f), str(dest))
    archived += 1

wb.save(str(OUT))

print(f'Saved:     {OUT}')
print(f'Size:      {OUT.stat().st_size // 1024} KB')
print(f'Sheets:    {wb.sheetnames}')
print(f'Matrix:    {len(MATRIX)} requirements')
print(f'Gaps:      {len(GAP_BACKLOG)} build items')
print(f'Catalog:   {len(BUILD_FEATURE_CATALOG)} features built '
      f'({sum(1 for f in BUILD_FEATURE_CATALOG if f[2])} requested + '
      f'{sum(1 for f in BUILD_FEATURE_CATALOG if not f[2])} bonus)')
print(f'Multiplier:{len(BUILD_FEATURE_CATALOG) / max(sum(1 for f in BUILD_FEATURE_CATALOG if f[2]),1):.2f}x')
print(f'ReqAnalysis:{len(JOB_REQUISITION_GAP)} aspects '
      f'({sum(1 for r in JOB_REQUISITION_GAP if r[4]=="COVERED")} covered, '
      f'{sum(1 for r in JOB_REQUISITION_GAP if r[4]=="PARTIAL")} partial, '
      f'{sum(1 for r in JOB_REQUISITION_GAP if r[4]=="GAP")} gap)')
print(f'TaskMgmt:  {len(TASK_MANAGEMENT_GAP)} aspects '
      f'({sum(1 for r in TASK_MANAGEMENT_GAP if r[4]=="COVERED")} covered, '
      f'{sum(1 for r in TASK_MANAGEMENT_GAP if r[4]=="PARTIAL")} partial, '
      f'{sum(1 for r in TASK_MANAGEMENT_GAP if r[4]=="GAP")} gap)')
print(f'Partials:{len(PARTIAL_BACKLOG)} refinements')
if archived:
    print(f'Archived:{archived} prior snapshot(s) moved to {ARCHIVE}/')
