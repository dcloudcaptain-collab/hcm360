TITLE = 'Process Flows'
SUBTITLE = 'How transactions move through HCM360'
FOLDER = 'user'

BLOCKS = [
    ('H1', '1. Employee Lifecycle'),
    ('P', 'The employee lifecycle spans recruitment to offboarding. Each stage produces records in the database and, where approvals are required, generates workflow tasks in the involved party’s inbox.'),

    ('H2', '1.1 Lifecycle Diagram'),
    ('CODE',
     'Recruitment --> Offer --> Onboarding --> Probation --> Regular --> Transfer/Promotion\n'
     '                                                      |\n'
     '                                                      +----> Resignation --> Clearance --> Final Pay --> COE'),

    ('H2', '1.2 Hiring Flow'),
    ('TABLE', ['Step', 'Actor', 'System Action'],
     [
        ['1. Create requisition', 'Hiring Manager', 'rsp.requisitions INSERT, workflow spawned'],
        ['2. Approve requisition', 'Department Head + HR', 'Status → APPROVED'],
        ['3. Post job and screen', 'Recruiter', 'Candidates recorded in rsp.candidates'],
        ['4. Schedule interviews', 'Recruiter', 'rsp.interviews with panelists'],
        ['5. Extend offer', 'HR', 'rsp.offers with terms; candidate accepts/declines'],
        ['6. Create employee', 'HR Admin', 'core.employees INSERT, login created'],
        ['7. Onboarding checklist', 'HR + new hire', 'Tasks auto-created; employee does self-service setup'],
        ['8. Start work', 'Employee', 'Attendance begins; probation timer starts'],
     ]),

    ('H1', '2. Leave Request Flow'),

    ('H2', '2.1 Process Diagram'),
    ('CODE',
     'Employee                Supervisor              HR (optional)\n'
     '   |                        |                        |\n'
     '   |--File Leave-->          |                        |\n'
     '   |                        |                        |\n'
     '   |     <---Inbox Task------|                        |\n'
     '   |                        |                        |\n'
     '   |                        |--Approve/Reject--->     |\n'
     '   |                        |                        |\n'
     '   |<---Notification---------|                        |\n'
     '   |                        |                        |\n'
     '   |                        |----(cascade)----------->|\n'
     '   |                        |                        |\n'
     '   |<---Balance debited------|<---Approved--------------|'),

    ('H2', '2.2 Steps'),
    ('OL', [
        'Employee submits request at /me/leaves/new',
        'lv_requests row created with status=PENDING',
        'Workflow engine spawns inbox task for immediate_supervisor_id',
        'Supervisor opens inbox, reviews, clicks Approve or Reject',
        'On Approve: status=APPROVED, trigger debits lv_balances.used',
        'On Reject: status=REJECTED, employee notified with reason',
        'Optional: HR final review for policy compliance (configurable)',
        'Employee sees updated balance on /me/leaves',
     ]),

    ('H1', '3. Overtime Approval Flow'),
    ('OL', [
        'Employee or manager files OT request at /attendance/ot/new',
        'Task lands in supervisor inbox with computed pay impact',
        'Supervisor approves → OT recorded on attendance.att_daily for the work date',
        'When payroll runs, OT hours multiply by the applicable rate (regular, rest day, holiday)',
        'Employee sees OT pay on payslip',
     ]),

    ('H1', '4. Payroll Run Lifecycle'),

    ('H2', '4.1 Status Transitions'),
    ('CODE',
     'DRAFT --> COMPUTING --> COMPUTED --> APPROVED --> POSTED --> (Payslips visible)\n'
     '   |         |                                               |\n'
     '   |         |                                               |\n'
     '   +- edit --┘                                               +--> Adjustment (pay_adjustments)'),

    ('H2', '4.2 Detailed Steps'),
    ('OL', [
        'HR creates pay_run linked to a pay_period (status=DRAFT)',
        'HR clicks Compute — background process iterates employees',
        'For each employee, system aggregates attendance, OT, leave days, allowances',
        'Computes gross_pay then statutory deductions (SSS, PhilHealth, HDMF, BIR tax)',
        'Writes pay_employee_payroll rows (status=COMPUTED)',
        'HR reviews variance report; resolves discrepancies by re-checking inputs',
        'HR clicks Approve (status=APPROVED)',
        'HR clicks Post — locks the run, payslips become visible to employees',
        'Post-posting adjustments use pay_adjustments (never modify the original)',
     ]),

    ('H1', '5. Certificate Request Flow'),
    ('OL', [
        'Employee submits at /me/certificates/new, picks type (Employment, COE + Comp, Leave)',
        'Task enters dms.certificate_requests queue with status=PENDING',
        'HR officer opens queue at /dms/certificate-requests',
        'HR reviews, clicks Generate — PDF rendered from template (certificate_types)',
        'Status → GENERATED, employee receives notification with download link',
        'Employee downloads and uses the certificate',
     ]),

    ('H1', '6. Performance Review Cycle'),
    ('OL', [
        'HR opens a cycle in Performance Management with window dates',
        'Employees receive self-review forms in inbox',
        'Managers receive evaluation forms for each direct report',
        'Both complete and submit; calibration session (optional) adjusts scores',
        'Final ratings published to employees',
        'HR exports results for compensation planning',
     ]),

    ('H1', '7. Disciplinary Case Flow'),
    ('OL', [
        'HR creates a case in discipline.cases with case_type and gravity',
        'Investigation phase records notes, witnesses, evidence uploads',
        'Administrative hearing scheduled (if required by gravity)',
        'Sanction imposed per case_types.default_penalty (written warning, suspension, termination)',
        'Record appended to employee 201 file; audit log captures every step',
     ]),

    ('H1', '8. Offboarding Flow'),
    ('OL', [
        'Employee files resignation with last_day via self-service',
        'HR receives task; validates notice period policy',
        'Clearance checklist spawned (return laptop, ID, keys; clear loans)',
        'Final pay run created in Payroll (Final Pay type)',
        'All pro-rated items computed: unused leaves, 13th month balance, tax recon',
        'COE generated via DMS Certificate Queue',
        'Employee status = RESIGNED on last day; login deactivated',
     ]),

    ('H1', '9. Audit Trail — How Changes Are Recorded'),
    ('P', 'Every mutation on a core.* or business table fires the audit_logs.fn_capture_change trigger. The trigger records:'),
    ('UL', [
        'table_name, action (INSERT/UPDATE/DELETE)',
        'record_id, before_json, after_json',
        'user_id and company_id (from session via SET LOCAL)',
        'occurred_at timestamp',
     ]),
    ('P', 'Auditors can reconstruct the history of any record by filtering change_log by table + record_id.'),

    ('H1', '10. Inbox & Task Routing'),
    ('P', 'Approval tasks land in the recipient’s inbox at /me/inbox. Each task includes the title, module, priority (URGENT/HIGH/NORMAL), and a direct link to the action page. Badges on the nav icon show unread count.'),
]
