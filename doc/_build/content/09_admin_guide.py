TITLE = 'Admin Guide'
SUBTITLE = 'Configuring and managing HCM360 as a system administrator'
FOLDER = 'user'

BLOCKS = [
    ('H1', '1. Who Is This For?'),
    ('P', 'This guide is for SUPER_ADMIN and HR_ADMIN users who configure HCM360 for their organization. It covers user management, access controls, reference data, privacy rules, themes, demo data, and day-to-day administrative tasks. Every admin page lives under /admin.'),

    ('H2', '1.1 Admin Home'),
    ('OL', [
        'Click Admin in the sidebar (only visible to admin roles)',
        'You see a grid of admin sub-modules with descriptions',
        'Click any tile to go to that page',
     ]),

    ('H1', '2. User Management'),

    ('H2', '2.1 Creating a User'),
    ('OL', [
        'Go to Admin → Users',
        'Click New User',
        'Enter username, email, display name',
        'Pick a role — if you need something other than the five built-ins, create a custom role first (section 3)',
        'Link to an employee record (optional, but required for self-service access)',
        'Set is_active = true',
        'Click Save — the user can now log in (or SSO in) immediately',
     ]),

    ('H2', '2.2 Deactivating a User'),
    ('OL', [
        'Open the user record',
        'Uncheck is_active',
        'Click Save — they lose login immediately',
     ]),

    ('H2', '2.3 Assigning Multiple Roles'),
    ('P', 'Although each user has a default role_code, additional roles can be granted via core.user_roles. An HR Officer can also carry MANAGER if they have direct reports. The highest-privilege role wins for page access.'),

    ('H1', '3. Access Matrix'),
    ('P', 'The single most important admin page. Controls what every role can see and do. Go to Admin → Access Matrix (SUPER_ADMIN only).'),

    ('H2', '3.1 Page Tab'),
    ('OL', [
        'Pick a module from the dropdown (e.g., Payroll)',
        'The grid lists all pages in that module with columns for each role',
        'Toggle checkboxes — save is automatic (AJAX)',
        'A confirmation flash appears on success',
     ]),

    ('H2', '3.2 Feature Tab'),
    ('P', 'Below the page grid you see action-level features (CREATE, EDIT, DELETE, APPROVE, EXPORT, etc.). Toggle per role to enable or hide the corresponding button in the UI.'),

    ('H2', '3.3 Modification Access'),
    ('P', 'Separate page at /admin/modification-access. Grants module-level write capability, independent of page access. Useful for read-only roles.'),

    ('H2', '3.4 Creating Custom Roles'),
    ('OL', [
        'On the Access Matrix, click Create Role',
        'Enter code (UPPER_SNAKE) and name',
        'Click Save — the role appears as a new column on the grid',
        'Assign permissions by toggling',
     ]),

    ('H1', '4. Reference Data'),
    ('P', 'Reference Data is the engine room — 29+ editable tables that seed every dropdown in the app. Go to Admin → Reference Data.'),

    ('H2', '4.1 Editing a Reference Table'),
    ('OL', [
        'Pick a key from the list (e.g., Job Grades, Leave Types, Document Categories)',
        'The table shows all current rows',
        'Click New to add, or click a row to edit',
        'Changes take effect immediately system-wide',
     ]),

    ('H2', '4.2 Key Reference Tables'),
    ('TABLE', ['Key', 'Used By', 'Typical Maintenance'],
     [
        ['job_grades', 'Core HR, Payroll', 'Annual salary band review'],
        ['employment_types', 'Core HR, Leave', 'Rare — only when policy changes'],
        ['lv_types', 'Leave Management', 'When statutory changes or new company leave introduced'],
        ['att_holidays', 'Attendance, Payroll', 'Annually — update calendar for the year'],
        ['document_categories', 'DMS', 'When new document types are introduced'],
        ['certificate_types', 'DMS', 'When new COE templates needed'],
        ['case_types', 'Discipline', 'When policy code of conduct updates'],
        ['reward_categories', 'R&R', 'When new awards created'],
        ['status_definitions', 'System-wide', 'Rarely — define new workflow statuses'],
     ]),

    ('H1', '5. Field Privacy (RA 10173)'),
    ('P', 'Control exactly which fields each role can see for personally identifiable information. Go to Admin → Field Privacy (SUPER_ADMIN only).'),

    ('H2', '5.1 The Grid'),
    ('P', 'Rows are sensitive fields grouped by section (employee, address, emergency_contact, government_id, bank_account, dependent). Columns are roles. Each cell is a dropdown with VISIBLE / MASKED / HIDDEN.'),

    ('H2', '5.2 Visibility States'),
    ('UL', [
        'VISIBLE — field value shown in full',
        'MASKED — value replaced by *** but label still visible',
        'HIDDEN — field removed entirely (label and value disappear)',
     ]),

    ('H2', '5.3 Typical Settings'),
    ('TABLE', ['Field', 'Recommendation'],
     [
        ['employee.basic_salary / daily_rate', 'HIDDEN for EMPLOYEE, MANAGER, EXECUTIVE; VISIBLE for HR_ADMIN'],
        ['employee.date_of_birth', 'MASKED (except own record)'],
        ['government_id.id_number', 'MASKED for EMPLOYEE and MANAGER'],
        ['bank_account.account_number', 'MASKED for MANAGER; VISIBLE for HR_ADMIN'],
        ['dependent.date_of_birth', 'MASKED for EMPLOYEE'],
     ]),
    ('NOTE', 'Self-record exception: when an employee views their own profile, MASKED becomes VISIBLE but HIDDEN stays HIDDEN. Employees can see their own DOB but never their own salary.'),

    ('H1', '6. UI Themes'),
    ('P', 'Customize the platform look per company. Go to Admin → Themes.'),
    ('OL', [
        'Click New Theme or edit an existing one',
        'Pick primary, accent, sidebar, and text colors (hex codes)',
        'Choose font family',
        'Save — click Activate to make it the company default',
        'Users can override with their personal preference at Self-Service → My Theme',
     ]),

    ('H1', '7. System Configuration'),

    ('H2', '7.1 Status Definitions'),
    ('P', 'Admin → Statuses. Defines per-module status codes with colors and badge styles. Rarely changed but you might add new workflow statuses for custom processes.'),

    ('H2', '7.2 Reminder Rules'),
    ('P', 'Admin → Reminders. Configures automated reminder emails (pending approvals over X days, probation ending, certification expiring, etc.). Each rule has a frequency, target audience, and template.'),

    ('H2', '7.3 Feature Flags'),
    ('P', 'At deployment time, modules can be switched on/off via .env variables (ENABLE_PAYROLL, ENABLE_ORGCHART, etc.). Restart hris_web to apply changes.'),

    ('H1', '8. Demo Data'),
    ('P', 'Admin → Demo Data lets you activate pre-built demo profiles for training and demos.'),
    ('UL', [
        'Demo profiles — activate a scenario (mid-year, year-end, full features)',
        'Reset — wipe and re-seed from the baseline',
        'Add-on events — inject ad-hoc transactions (promotions, disciplinary cases)',
     ]),
    ('NOTE', 'Only available to SUPER_ADMIN. Always back up before running Reset on a production system.'),

    ('H1', '9. Services Dashboard'),
    ('P', 'Admin → Services shows the live state of integrations and background services (payroll microservice, AI, SMTP, etc.). Use this as a first-stop diagnostic.'),

    ('H1', '10. Daily Admin Checklist'),
    ('UL', [
        'Review Inbox for pending admin tasks (clearance, approvals)',
        'Check Admin → Services — all green?',
        'Scan audit_logs.access_log for unexpected 403s or failed logins',
        'Verify last night’s backup exists in backups/',
        'Review any pending certificate requests at /dms/certificate-requests',
        'Address any flagged attendance alerts',
     ]),

    ('H1', '11. Monthly Admin Tasks'),
    ('UL', [
        'Reconcile payroll runs with BIR, SSS, PhilHealth, HDMF remittances',
        'Generate and distribute payroll reports to Finance',
        'Review access matrix for new hires and leavers',
        'Run headcount report from Workforce Planning',
        'Validate reminder rules are firing correctly',
     ]),

    ('H1', '12. Annual Admin Tasks'),
    ('UL', [
        'Update lv_holidays with new year calendar',
        'Roll over leave balances (or apply policy-driven reset)',
        'Recompute 13th month and year-end bonuses',
        'Generate BIR 2316 for each employee',
        'Produce Alphalist for BIR submission',
        'Review and rotate SECRET_KEY and DB password',
        'Verify DR drill with scripts/restore_v1.sh',
     ]),
]
