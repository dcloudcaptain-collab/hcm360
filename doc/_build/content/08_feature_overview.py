TITLE = 'Feature Overview'
SUBTITLE = 'What each HCM360 module does and who it serves'
FOLDER = 'user'

BLOCKS = [
    ('H1', '1. Platform at a Glance'),
    ('P', 'HCM360 is organized into sixteen modules. Each one addresses a specific HR domain while sharing the same employee master, access matrix, and privacy rules. Modules can be toggled on or off via environment flags at deployment time.'),

    ('H1', '2. Module Catalog'),
    ('TABLE', ['Module', 'Primary Users', 'Purpose'],
     [
        ['Core HR', 'HR Admin', '201 file, org structure, employment records'],
        ['Attendance', 'HR Admin, Manager, Employee', 'Daily time records, shifts, overtime'],
        ['Leave Management', 'HR Admin, Manager, Employee', 'Leave types, balances, approvals'],
        ['Payroll', 'HR Admin, Payroll Officer', 'Pay runs, payslips, statutory deductions, loans'],
        ['Self-Service (ESS)', 'Employee', 'Personal profile, DTR, payslips, certificates'],
        ['Manager Service (MSS)', 'Manager', 'Team DTR, approvals, 1:1 tracking'],
        ['Organization Chart', 'All roles', 'Hierarchy visualization with privacy controls'],
        ['Workforce Planning', 'HR Admin, Executive', 'Headcount scenarios, skill gaps'],
        ['Recruitment (RSP)', 'HR Admin, Recruiter, Hiring Manager', 'Requisitions, candidates, offers'],
        ['Performance (PM)', 'HR Admin, Manager, Employee', 'Review cycles, KPIs, 360 feedback'],
        ['Learning (L&D)', 'HR Admin, Employee', 'Training catalog, enrollments, certifications'],
        ['Rewards & Recognition', 'HR Admin, Employee', 'Awards, praise wall'],
        ['Document Management (DMS)', 'HR Admin, Employee', '201 file uploads, certificates'],
        ['Discipline', 'HR Admin', 'Case tracking, investigations, sanctions'],
        ['Health & Safety', 'HR Admin, Employee', 'Incident reports, safety records'],
        ['Analytics & Reports', 'HR Admin, Executive', 'Dashboards, KPIs, report builder'],
        ['AI (ARIA)', 'All roles', 'Natural-language query assistant'],
        ['Admin', 'SUPER_ADMIN, HR Admin', 'Access matrix, reference data, privacy, themes'],
     ]),

    ('H1', '3. Core HR'),
    ('P', 'The foundation of every other module. Maintains employee master data (the 201 file), organizational structure (departments, positions, job grades), and employment history.'),
    ('H3', 'Key capabilities'),
    ('UL', [
        'Employee master with 40+ fields plus sub-records (addresses, contacts, IDs, banks, dependents)',
        'Department and position hierarchy with head-of-department tracking',
        'Employment type, job grade, salary band management',
        'Transfer and promotion records with historical view',
        'Bulk import and export',
     ]),

    ('H1', '4. Attendance & DTR'),
    ('UL', [
        'Daily time records with clock in/out',
        'Shift schedules (fixed, rotating, flexible) and assignments',
        'Overtime, late, absent, undertime tracking',
        'Holiday calendar with Philippine statutory holidays seeded',
        'Admin overrides with immutable audit trail',
        'Attendance alerts (excessive late, consecutive absent)',
        'Biometric integration hooks',
     ]),

    ('H1', '5. Leave Management'),
    ('UL', [
        '10+ statutory leave types: VL, SL, Maternity (RA 11210), Paternity (RA 8187), Solo Parent (RA 8972), VAWC (RA 9262), Magna Carta (RA 9710), Emergency, Bereavement',
        'Per-employment-type leave policies: accrual rules, carry-over, monetization',
        'Balance tracking with year-end rollover',
        'Approval workflows with cascade rules (supervisor → HR)',
        'Document attachments for leaves that require proof',
     ]),

    ('H1', '6. Payroll'),
    ('UL', [
        'Pay periods and runs with full lifecycle (DRAFT → COMPUTED → APPROVED → POSTED)',
        'Government deductions: SSS (EE + ER), PhilHealth, HDMF, BIR withholding tax',
        'Allowances: PERA, RATA, ACA, hazard pay, representation, clothing',
        'Loans and amortizations (SSS, Pag-IBIG, company)',
        'Government remittance reports: R3, RF1, MCRF, 1601-C, 2316, Alphalist',
        'Adjustments after posting (non-destructive)',
        'Standalone microservice on port 8095 for heavyweight computations',
     ]),

    ('H1', '7. Self-Service (ESS) & Manager Service (MSS)'),
    ('P', 'One stop for employees to view their own data and act on personal transactions without HR intervention.'),
    ('UL', [
        'My Portal dashboard with KPI cards (attendance, leave, compensation, inbox, benefits)',
        'Profile editing for addresses, emergency contacts, government IDs, bank accounts, dependents',
        'File leaves, view balances, request certificates',
        'View DTR, payslips, compensation breakdown, loans, benefits enrollment',
        'Manager view: team DTR, approvals, 1:1 history',
     ]),

    ('H1', '8. Organization Chart'),
    ('UL', [
        'Interactive person-centric tree visualization',
        'Shows ancestors above you (locked — gray style)',
        'Your own card is highlighted and clickable to /me/profile',
        'Team members are clickable to /employees/<id> with privacy masking applied',
        'Admin view: full organization; non-admin view: department-scoped only',
        'Privacy banner clearly communicates visibility rules',
     ]),

    ('H1', '9. Workforce Planning'),
    ('UL', [
        'Scenario modeling for headcount, cost, skills',
        'Assumptions: attrition %, growth %, salary increase %, benefits %, training cost',
        'Auto-generated month-by-month projections',
        'Skill demand vs. supply gap analysis with priority and mitigation plans',
        'Compare current vs. planned state at a glance',
     ]),

    ('H1', '10. Recruitment (RSP)'),
    ('UL', [
        'Requisition workflow with budget and headcount checks',
        'Candidate pipeline with source tracking',
        'Interview scheduling and panelist coordination',
        'CSC Eligibilities and Qualification Standards (for government entities)',
        'Offer letters and acceptance tracking',
     ]),

    ('H1', '11. Performance Management (PM)'),
    ('UL', [
        'Multi-cycle reviews: annual, mid-year, probationary, project-based',
        'KPI and competency-based rating matrices',
        'Self-review, manager review, 360 feedback',
        'Calibration sessions to align ratings across departments',
        'Historical rating trendlines per employee',
     ]),

    ('H1', '12. Learning & Development (L&D)'),
    ('UL', [
        'Training catalog with categories and prerequisites',
        'Enrollment workflows and attendance tracking',
        'Certificate issuance with expiration tracking',
        'Compliance training calendar',
        'Budget and completion dashboards',
     ]),

    ('H1', '13. Rewards & Recognition (R&R)'),
    ('UL', [
        'Award categories with monetary equivalents (e.g., Employee of the Month)',
        'Praise wall — peer-to-peer recognition feed',
        'Nomination and approval workflows',
        'Year-end recognition summaries',
     ]),

    ('H1', '14. Document Management (DMS)'),
    ('UL', [
        '201 file with hierarchical document categories',
        'Document upload with category, expiration, retention policy',
        'Certificate request queue for HR',
        'Automatic certificate generation (COE, COE+Comp, Leave Balance)',
        'Retention policies per category with expiry alerts',
     ]),

    ('H1', '15. Discipline'),
    ('UL', [
        'Case types by gravity (minor, moderate, major, grave) with default penalties',
        'Legal basis tracking (DOLE, Civil Service, company policy)',
        'Investigation workflow with witness and evidence capture',
        'Administrative hearing scheduling',
        'Sanction imposition with appeal tracking',
        'Records appended to employee 201 file',
     ]),

    ('H1', '16. Health & Safety'),
    ('UL', [
        'Incident reports with categorization and severity',
        'Workplace safety records',
        'Follow-up action tracking',
        'Regulatory reporting support (DOLE, PhilHealth)',
     ]),

    ('H1', '17. Analytics & Reports'),
    ('UL', [
        'Admin dashboard with real-time KPI cards (configurable per role)',
        'HR demographics reports (gender, tenure, age distribution)',
        'Attendance and leave heatmaps',
        'Payroll cost analysis',
        'Report builder — saved queries with parameters and role-scoped execution',
     ]),

    ('H1', '18. AI (ARIA)'),
    ('UL', [
        'Natural-language queries about employee data and reports',
        'Document summarization for 201 files',
        'Powered by Anthropic Claude — configured via ANTHROPIC_API_KEY',
        'Every AI query is logged with prompt + response for compliance',
     ]),

    ('H1', '19. Administration'),
    ('P', 'A central console for SUPER_ADMIN and HR_ADMIN to configure the platform. Detailed coverage is in the Admin Guide.'),
    ('UL', [
        'Access Matrix — roles, pages, features, modifications',
        'Reference Data — 29+ editable tables (leave types, job grades, etc.)',
        'Field Privacy — RA 10173 masking rules',
        'UI Themes — per-company branding',
        'User Management — create, deactivate, role assignment',
        'Demo Data — activate/reset demo profiles for training',
        'System Health — service monitoring and log access',
     ]),
]
