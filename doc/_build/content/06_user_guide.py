TITLE = 'User Guide'
SUBTITLE = 'Step-by-step walkthroughs for everyday HCM360 tasks'
FOLDER = 'user'

BLOCKS = [
    ('H1', '1. Getting Started'),
    ('P', 'This guide walks you through the most common tasks in HCM360 HRIS. Screens are organized by the role that typically performs each task: Employee (self-service), Manager (team oversight), and HR Administrator (system-wide actions). Every task assumes you are already logged in.'),

    ('H2', '1.1 Logging In'),
    ('OL', [
        'Open your browser and go to the URL provided by IT (for example http://localhost:8093)',
        'On the login page, choose your name from the dropdown',
        'Click Sign In',
        'You will land on your dashboard (the home page differs by role)',
     ]),

    ('H2', '1.2 Navigating the App'),
    ('UL', [
        'The left sidebar lists every module you are allowed to access',
        'Hover over a group label (e.g., Self-Service, Workforce) to expand its sub-items',
        'Click your name in the top-right corner to open the user menu (switch user, log out)',
        'The top bar shows your current role and any urgent notifications',
     ]),

    ('H1', '2. For Employees'),

    ('H2', '2.1 Viewing Your Profile'),
    ('OL', [
        'Click Self-Service → My Profile (or go to /me/profile)',
        'Your details are organized in collapsible cards: Personal Information, Addresses, Emergency Contacts, Government IDs, Bank Accounts, Dependents',
        'Click any card header to expand or collapse it',
        'Counts in blue badges show how many records are in each section',
     ]),
    ('NOTE', 'You always see your own personal details but salary and rate fields are hidden by design.'),

    ('H2', '2.2 Adding Missing Information'),
    ('OL', [
        'If a section says "No records on file", click the + Add one link next to it',
        'Fill out the form that appears',
        'Click Save — you return to the list view and see your new record',
        'You can add multiple addresses, emergency contacts, bank accounts, etc.',
     ]),

    ('H2', '2.3 Filing a Leave Request'),
    ('OL', [
        'Click Self-Service → My Leaves',
        'Click File Leave in the top right',
        'Pick a leave type from the dropdown (Vacation, Sick, Solo Parent, etc.)',
        'Choose the date range — the system calculates days automatically',
        'Type a reason in the notes field',
        'Attach a document if the leave type requires one (e.g., medical certificate for Sick Leave above 2 days)',
        'Click Submit — your supervisor gets an inbox task',
        'Track status on the same page: PENDING → APPROVED or REJECTED',
     ]),

    ('H2', '2.4 Viewing Attendance (DTR)'),
    ('OL', [
        'Click Self-Service → My Attendance',
        'You see the current month by default; use the date filter to change',
        'Each row shows: Date, Time In, Time Out, Worked Hours, Status (Present / Late / Absent)',
        'Totals appear at the top: present days, late days, absent days, total hours',
     ]),

    ('H2', '2.5 Downloading Your Payslip'),
    ('OL', [
        'Click Self-Service → My Payslips',
        'The list shows every posted payslip in reverse chronological order',
        'Click View to open the payslip on screen',
        'Click PDF to download the printable version',
     ]),

    ('H2', '2.6 Requesting a Certificate'),
    ('OL', [
        'Click Self-Service → My Certificates',
        'Click Request New in the top right',
        'Pick a certificate type (Employment, COE + Compensation, Leave Balance)',
        'Add purpose (where you will submit it)',
        'Click Submit — HR processes the request',
        'Once approved, the PDF appears on the same page with a Download link',
     ]),

    ('H2', '2.7 Checking the Org Chart'),
    ('OL', [
        'Click Workforce → Org Chart',
        'You see your position in the hierarchy — your supervisor(s) above, your team below',
        'Ancestors are shown with a locked gray style (for context only)',
        'Your own card is highlighted in blue — click to jump to your profile',
        'Team member cards are clickable — opens their employee page (with privacy masking)',
     ]),

    ('H1', '3. For Managers'),

    ('H2', '3.1 Reviewing Team Attendance'),
    ('OL', [
        'Click Team → Team Attendance',
        'Pick a date range',
        'Rows: one per direct report; columns: present, late, absent, OT',
        'Click any employee name to drill into their DTR',
     ]),

    ('H2', '3.2 Approving a Leave Request'),
    ('OL', [
        'Open your Inbox (top-right bell icon, or /me/inbox)',
        'Click a leave request task',
        'Review: employee, dates, reason, current balance after approval',
        'Click Approve or Reject',
        'Optionally add a note — the employee sees it in their notification',
     ]),

    ('H2', '3.3 Approving Overtime'),
    ('OL', [
        'Open your Inbox',
        'Click an OT request',
        'Confirm the hours and date — the system shows the expected pay impact',
        'Click Approve or Reject',
     ]),

    ('H2', '3.4 Running a One-on-One'),
    ('OL', [
        'Click Team → My Team → [employee name]',
        'The profile opens with manager-level privacy (DOB masked, salary hidden)',
        'Click the Performance tab to see their open KPIs, last review rating, and feedback history',
        'Use the Log 1:1 button to record your conversation',
     ]),

    ('H1', '4. For HR Administrators'),

    ('H2', '4.1 Onboarding a New Employee'),
    ('OL', [
        'Click Core HR → Employees → New Employee',
        'Fill in basics: employee number, full name, date of birth, gender, civil status',
        'Pick department and position — the job grade auto-fills from the position',
        'Set date hired and employment type (REGULAR, PROBATIONARY, CONTRACTUAL)',
        'Click Save — the record is created',
        'From the detail page, use the section cards to add addresses, government IDs, bank accounts, dependents',
        'Go to Admin → Users to create a login for the employee',
     ]),

    ('H2', '4.2 Regularizing an Employee'),
    ('OL', [
        'Open the employee detail page',
        'Click Employment → Regularize',
        'Set date_regularized (usually last day of probation)',
        'Status flips from PROBATIONARY → ACTIVE',
        'Leave balances recalculate to reflect regularization benefits',
     ]),

    ('H2', '4.3 Processing a Resignation'),
    ('OL', [
        'Employee submits resignation via Self-Service → Resignation (or HR does this on their behalf)',
        'HR receives a task in the inbox',
        'Validate last day, clearance, final pay computation',
        'Change status to RESIGNED on the effective date',
        'Generate Certificate of Employment at DMS → Certificates',
        'Generate final pay run in Payroll → Runs (Final Pay type)',
     ]),

    ('H2', '4.4 Creating a Payroll Run'),
    ('OL', [
        'Click Payroll → Pay Periods → Select or create a period',
        'Click New Pay Run',
        'Pick run type (Regular, 13th Month, Final Pay, Bonus)',
        'Click Compute — the run moves from DRAFT → COMPUTING → COMPUTED',
        'Review the summary page: gross, deductions, net, variances',
        'Click Approve to move to APPROVED, then Post to lock and make payslips visible',
     ]),

    ('H2', '4.5 Adjusting a Posted Payroll'),
    ('OL', [
        'Navigate to the employee’s pay record in the run',
        'Click Add Adjustment',
        'Pick type (add-on earning or extra deduction), amount, reason',
        'The adjustment is appended to pay_adjustments (never modifies the original)',
        'Employee sees the updated net pay on their payslip',
     ]),

    ('H1', '5. Working with Documents'),

    ('H2', '5.1 Uploading a 201 File Document'),
    ('OL', [
        'Open the employee detail page → Documents tab',
        'Click Upload',
        'Pick a category (Contract, Clearance, Medical, etc.)',
        'Drag-drop the PDF or image',
        'Add a description and expiration date (if applicable)',
        'Click Save',
     ]),

    ('H2', '5.2 Processing a Certificate Request'),
    ('OL', [
        'Go to DMS → Certificate Queue',
        'Click a pending request',
        'Review the employee’s details and the purpose',
        'Click Generate PDF — the template fills in automatically',
        'Click Release to mark complete; the employee is notified',
     ]),

    ('H1', '6. Tips & Shortcuts'),
    ('UL', [
        'Press / from any page to focus the global search bar',
        'Click the HCM360 logo to return to your dashboard',
        'The Inbox icon flashes red when you have new approval tasks',
        'Expand/collapse section cards on the profile by clicking their headers',
        'Monospace numbers (employee no, account no, ID no) are selectable for copy-paste',
     ]),
]
