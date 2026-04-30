TITLE = 'Competitive Advantage'
SUBTITLE = 'Why HCM360 leads the HRIS market — a decision-maker brief'
FOLDER = 'marketing'

BLOCKS = [
    # ───────────────────────────────────────────────────────────────
    ('H1', '1. The HCM360 Edge'),
    ('P', 'HCM360 is a Philippine-first, AI-native Human Capital Management platform engineered for the realities of modern HR leaders — CSC compliance, multi-tenant scale, RA 10173 privacy, and zero-friction self-service — all in a single deployable stack. It is a modern alternative to heavyweight enterprise suites (SAP SuccessFactors, Workday) and regional point products (Sprout, PayrollHero, SprutHR, Zoho People), delivering 177 production features across 19 modules with a 1.77× value multiplier against typical customer requirements (as of April 2026).'),
    ('P', 'This brief distils the platform\'s differentiators so HR leaders, CIOs and procurement teams can make an informed choice in under ten minutes.'),

    ('H2', '1.1 The Eight Differentiator Pillars'),
    ('TABLE', ['Pillar', 'What It Means', 'Why It Matters'],
     [
        ['AI-Powered HR (ARIA)', 'Natural-language queries across every module', 'Answers in seconds — no SQL, no dashboards to hunt through'],
        ['Self-Service Reports', '32 data sources × 280+ fields × drag-drop builder', 'HR leaders ship their own reports, Finance no longer a bottleneck'],
        ['PH Compliance Native', 'RA 10173 · DOLE · BIR · CSC · SSS · PhilHealth · Pag-IBIG', 'Zero-adaptation readiness for LGUs, NGAs, and Philippine SMEs'],
        ['Mobile Biometric Attendance', 'Face-match + GPS geofence, works on any browser', 'No apps to deploy, no hardware to buy — camera + location only'],
        ['End-to-End Recruitment', 'Requisition → Approval → Auto-Publish → Appointment (CSC 33-B)', 'Full plantilla-backed hiring pipeline with 3-step workflow'],
        ['Task Management Suite', 'Self-tasks, team delegation, @mentions, templates, KPIs, ARIA-queryable', 'Replaces email to-dos and spreadsheet trackers — visibility without meetings'],
        ['Global Employee Picker', 'Reusable Individual / Department / Group selector across every flow', 'One widget, zero training — consistent UX across Tasks, Loans, Wellness'],
        ['Guided Experience', 'In-product tours + tooltips per role', 'Cuts onboarding from days to minutes; training cost drops >60%'],
     ]),

    ('H1', '2. The AI Pillar — ARIA'),
    ('P', 'ARIA is not a chatbot. It is an agentic assistant that reads live data via twelve purpose-built tools and answers questions with source-traceable numbers. Every answer is backed by a validated SQL query — no hallucinations.'),

    ('H3', '2.1 What HR leaders can ask ARIA today'),
    ('UL', [
        '"Give me a state-of-HR overview" — returns 14 headline numbers across every module',
        '"How many employees are at HIGH attrition risk by department?"',
        '"Show me SALN filings still in DRAFT for 2026"',
        '"Who is retiring in the next 6 months? Split by gender."',
        '"Top 10 net pay earners year-to-date"',
        '"Training attendance rate by shift for the last 90 days"',
        '"Loyalty award memos generated this month"',
        '"CSC eligibility breakdown — 1st vs 2nd level by gender"',
        '"What is the attrition risk KPI and how is it computed?"',
     ]),

    ('H3', '2.2 Technical moat'),
    ('TABLE', ['Capability', 'HCM360 ARIA', 'Typical HRIS Chatbots'],
     [
        ['Live data access', '30 data sources, 260 fields', 'Usually 2–5 canned FAQs'],
        ['Cross-module joins', 'Yes (e.g., attrition × payroll × training)', 'No'],
        ['Role-aware prompts', 'HR Leader Mode activates extra tools', 'Flat — same answer to everyone'],
        ['Traceable answers', 'Every number tied to a SQL query', 'Opaque — no source attribution'],
        ['Streaming responses', 'Server-Sent Events', 'Full-page reload'],
        ['Audit log of queries', 'Yes, every AI query logged', 'No'],
     ]),

    ('NOTE', 'ARIA uses the Anthropic Claude model family. Customers can bring their own API key or deploy via our managed cluster. No employee data is ever used for model training.'),

    ('H1', '3. The Self-Service Reports Pillar'),
    ('P', 'Where most HRIS platforms require IT tickets for custom reports, HCM360 gives HR staff a drag-drop report builder that covers every corner of the data model.'),

    ('H3', '3.1 Data source coverage'),
    ('TABLE', ['Module', 'Data Sources', 'Example Use Cases'],
     [
        ['Core HR', '9', 'Headcount by department + gender split'],
        ['Attendance', '2', 'Face check-in log · geofence audit'],
        ['Leave', '4', 'CS Form No. 6 register · leave balance exposure'],
        ['Payroll', '3', 'Payslip detail · loan portfolio · deduction breakdown'],
        ['Recruitment', '3', 'Appointments · CSC eligibility levels · plantilla'],
        ['Performance', '1', 'IPCR ratings by cycle'],
        ['Learning', '3', 'Training attendance · narrative reports · participation'],
        ['Rewards', '1', 'Loyalty milestones + award value'],
        ['DMS', '1', 'SALN filing status register'],
        ['AI / Risk', '1', 'Attrition risk scores with factor chips'],
        ['Analytics', '2', 'Workforce scenarios · headcount plans'],
        ['Admin', '1', 'Role access audit'],
     ]),

    ('H3', '3.2 Feature comparison vs competitors'),
    ('TABLE', ['Capability', 'HCM360', 'SAP SuccessFactors', 'Workday', 'Zoho People', 'Sprout'],
     [
        ['Drag-drop report builder', 'Yes', 'Yes (costly add-on)', 'Yes', 'Limited', 'Basic filters'],
        ['Cross-module joins', 'Yes (30 sources)', 'Yes (complex)', 'Yes', 'No', 'No'],
        ['Export: CSV / XLSX / PDF', 'All three', 'All three', 'All three', 'CSV only', 'CSV/XLSX'],
        ['Scheduled reports to email', 'Daily / Weekly / Monthly', 'Yes', 'Yes', 'Limited', 'Manual'],
        ['SQL injection-safe', 'Validated builder', 'Yes', 'Yes', 'Yes', 'Yes'],
        ['Price to add', 'Included', '₱₱₱', '₱₱₱', '₱', '₱'],
     ]),

    ('H1', '4. Philippine Compliance — Built-In, Not Retrofitted'),
    ('P', 'Global HRIS platforms require months of customization to meet Philippine statutory requirements. HCM360 ships them on day one.'),

    ('H3', '4.1 Regulatory coverage matrix'),
    ('TABLE', ['Regulation / Form', 'Implementation', 'Module'],
     [
        ['RA 10173 (Data Privacy Act)', 'Field-level VISIBLE/MASKED/HIDDEN per role', 'Security / Admin'],
        ['DOLE Labor Code', 'OT, leave, holiday premium per statute', 'Payroll / Attendance'],
        ['BIR Form 2316', 'Auto-generated end of year', 'Payroll'],
        ['BIR Form 1601-C', 'Monthly remittance', 'Payroll'],
        ['BIR Alphalist', 'Year-end export', 'Payroll'],
        ['SSS R3 / PhilHealth RF1 / HDMF MCRF', 'Monthly contribution reports', 'Payroll'],
        ['CSC Form No. 6 (leave application)', 'Strict-mode form + printable PDF', 'Leave Management'],
        ['CSC Form No. 7 (clearance)', 'Multi-signatory workflow with 9 default items', 'Core HR'],
        ['CSC Form No. 33-B (appointment)', 'PDF generation with attestation tracking', 'Recruitment'],
        ['CSC Form 210 (SALN)', 'Three filing modes (Upload / Simple / Full)', 'DMS'],
        ['CSC Form 212 (PDS)', '10-tab form with auto-fill from master data', 'Core HR'],
        ['RA 11210 (Maternity Leave 105 days)', 'Leave type seeded', 'Leave Management'],
        ['RA 8187 (Paternity Leave)', 'Leave type seeded', 'Leave Management'],
        ['RA 8972 (Solo Parent Leave)', 'Leave type seeded', 'Leave Management'],
        ['RA 9262 (VAWC Leave)', 'Leave type seeded', 'Leave Management'],
        ['RA 9710 (Magna Carta of Women)', 'Leave type seeded', 'Leave Management'],
        ['RA 6727 (Service Incentive Leave)', 'Leave type seeded', 'Leave Management'],
        ['RA 2674 / RA 7883 / RA 5447', 'LGU contract types (JO/LSB/BHW/NS)', 'Core HR'],
     ]),

    ('NOTE', 'For LGUs specifically, HCM360 is the only commercial HRIS that ships pre-built with all four CSC forms (6, 7, 33, 210, 212) and LGU-specific contract types (Job Order, Local School Board, Barangay Health Worker, Nutritionist Scholar) out of the box.'),

    ('H1', '5. Mobile Biometric Attendance'),
    ('P', 'Traditional biometric attendance requires fingerprint scanners, facial-recognition cameras and ongoing hardware maintenance — often ₱50,000 to ₱200,000 per site. HCM360 turns every smartphone and laptop into a biometric terminal using in-browser face recognition and GPS geofencing.'),

    ('H3', '5.1 How it works'),
    ('OL', [
        'Employee enrols their face once — the browser captures 3 samples and computes a 128-dimensional mathematical signature (non-reversible — NOT a photo)',
        'Signature stored encrypted in the database; original images are never uploaded',
        'At check-in, the browser captures a new face, computes a fresh signature, and sends it to the server',
        'Server computes Euclidean distance between the two signatures — distance under threshold = match',
        'GPS coordinates verified against a configurable geofence (default 200m radius, adjustable per office)',
        'Check-in recorded in attendance.att_checkins with face match score, GPS accuracy, device type, and activity (regular / flag-raising / flag-lowering)',
     ]),

    ('H3', '5.2 Competitive angle'),
    ('TABLE', ['Feature', 'HCM360', 'Traditional Biometric', 'Mobile App Products'],
     [
        ['Hardware cost', '₱0 (uses existing devices)', '₱50k–200k per site', '₱0 + app licensing'],
        ['Face data storage', '128-d signature (not a photo)', 'Template on device', 'Photo upload (privacy risk)'],
        ['Geofence', 'Haversine with configurable radius', 'N/A', 'Usually yes'],
        ['Offline enrollment', 'Yes (in-browser)', 'On-site scanner required', 'Varies'],
        ['Shift support (AM/PM)', 'Native', 'Manual shift switch', 'Varies'],
        ['Integration effort', 'Zero — built-in', 'Driver + polling job', 'API integration'],
     ]),

    ('H1', '6. Guided User Experience'),
    ('P', 'Enterprise HRIS rollouts typically burn 20–40 hours of HR-leader time on training and onboarding. HCM360\'s in-product guided tour system collapses that to 5–15 minutes per user, per role.'),

    ('H3', '6.1 Tour system capabilities'),
    ('UL', [
        '8 role-filtered tours auto-start on first visit per module',
        'Spotlight + overlay + smart positioning with auto-flip when off-screen',
        'Floating "?" help launcher on every page to replay any tour on demand',
        'Per-user completion tracking stored in the database (resume where you left off)',
        'Admin UI at /admin/tours lets HR define new tours without developer involvement',
        'Tour versioning (e.g., "payroll-v2") re-notifies users when features evolve',
        'Mobile-aware: full tours gracefully fall back to centered modals; tooltips switch to tap-triggered',
        'data-hint tooltip system: add a single attribute to any element and get instant contextual help',
     ]),

    ('H1', '7. Head-to-Head Feature Comparison'),
    ('P', 'The table below compares HCM360 against the three most commonly evaluated alternatives in the Philippine market.'),

    ('TABLE', ['Capability', 'HCM360', 'SAP SF / Workday', 'Zoho People / Sprout'],
     [
        ['All-in-one HR + Payroll + DTR + ESS', 'Yes', 'Yes (premium tier)', 'Limited — often separate modules'],
        ['Built-in PH compliance (SSS/PhilHealth/HDMF/BIR/CSC)', 'Yes', 'Requires customization', 'Partial'],
        ['AI assistant with cross-module queries', 'Yes (ARIA, 30 sources)', 'Generic chatbot', 'No / Basic'],
        ['Drag-drop report builder', 'Yes (260 fields)', 'Yes (add-on)', 'Limited'],
        ['Self-enrollment face recognition', 'Yes (in-browser)', 'Via 3rd-party add-on', 'Separate mobile app'],
        ['CSC Forms 6/7/33/210/212 out-of-the-box', 'Yes', 'Custom development required', 'No'],
        ['LGU contract types (JO/LSB/BHW/NS)', 'Yes', 'Custom', 'No'],
        ['RA 10173 field-level privacy controls', 'Admin-managed rules', 'Column-level encryption', 'Manual configuration'],
        ['Organization chart with privacy masking', 'Native, department-scoped', 'Yes', 'Basic'],
        ['Workforce planning + attrition risk', 'Both native', 'Workday: yes · SAP: yes', 'No'],
        ['Guided tours + tooltips', 'Native, admin-editable', 'No', 'No'],
        ['E-signature (canvas + DocuSign)', 'Both natively supported', 'DocuSign integration only', 'Rare'],
        ['Deployment model', 'Docker Compose or SaaS', 'SaaS only', 'SaaS only'],
        ['Data ownership', 'On-prem option available', 'Vendor lock-in', 'Vendor lock-in'],
        ['Cost (typical mid-size org)', '₱', '₱₱₱₱', '₱₱'],
     ]),

    ('H1', '8. Architecture Advantages'),

    ('H3', '8.1 Multi-tenant from day one'),
    ('P', 'Every table is partitioned by company_id. One deployment can serve an entire municipality, with each department or affiliate appearing as an isolated tenant — with its own branding, privacy rules, and access matrix.'),

    ('H3', '8.2 Audit-grade change tracking'),
    ('P', 'Every mutation fires a trigger that writes a before/after snapshot to audit_logs.change_log, tagged with the user, company, IP, and session. Replay is trivial — auditors can reconstruct any record\'s history by filtering on table + record_id.'),

    ('H3', '8.3 Non-destructive transactions'),
    ('UL', [
        'Attendance: att_admin_overrides logs every DTR edit — original never modified',
        'Payroll: pay_adjustments append corrections after POSTED — original run immutable',
        'Leave: lv_balance_adjustments audit trail for every balance change',
        'Documents: retention policies enforced; documents soft-archived, never deleted',
     ]),

    ('H3', '8.4 Modular deployability'),
    ('P', 'Every module can be disabled via a single environment flag (ENABLE_ATTENDANCE, ENABLE_PAYROLL, etc.). Start with Core HR + ESS, grow into Payroll and Performance over time, without a re-platforming.'),

    ('H1', '9. Total Cost of Ownership'),

    ('TABLE', ['Cost Component', 'HCM360', 'SAP SF (est.)', 'Zoho People (est.)'],
     [
        ['License / subscription (100 employees, monthly)', '₱', '₱10,000+', '₱3,000+'],
        ['Implementation (first year)', '₱ (ships pre-configured)', '₱₱₱₱ (6–12 months)', '₱₱ (2–4 months)'],
        ['PH compliance add-ons (CSC / BIR reports)', 'Included', '₱₱ per form', 'Manual work'],
        ['AI assistant / chatbot', 'Included (bring-your-own Claude key)', '₱₱ add-on', 'N/A'],
        ['Face recognition attendance', 'Included', '3rd-party biometric (₱₱₱)', 'Separate mobile app'],
        ['Annual training & onboarding', 'Minimal (guided tours)', '₱₱ (extensive)', '₱ (moderate)'],
        ['Data migration to on-prem option', 'Full export available', 'Vendor-controlled', 'Limited'],
     ]),

    ('NOTE', 'Exact pricing varies by headcount tier and contract term. Request a custom quote from your HCM360 account executive.'),

    ('H1', '10. Job Requisition Engine'),
    ('P', 'Most Philippine HRIS products stop at "post a job." HCM360 ships an end-to-end requisition engine that mirrors the CSC-compliant hiring pipeline used by LGUs and NGAs — Draft → Department Head → HR Review → Executive Approval → Auto-Publish → Application → PSB Deliberation → Appointment (CSC Form 33-B).'),

    ('H3', '10.1 What ships in the box'),
    ('TABLE', ['Aspect', 'Implementation'],
     [
        ['Plantilla-backed requisitions', 'FK to recruitment.rec_plantilla_items — every vacancy tied to a funded item'],
        ['Priority tiers', 'URGENT · HIGH · NORMAL · LOW (drives SLA + next-in-rank triggers)'],
        ['Budget fields', 'Budget Source + Funds Available captured at submission (Finance visibility)'],
        ['Qualification Standard', 'Link to rec_qualification_standards for automatic CSC matrix enforcement'],
        ['Civil Service Eligibility', 'Optional required eligibility (e.g., Career Service Professional)'],
        ['Salary override', 'Min/Max fields support above-plantilla rates when justified'],
        ['3-step approval', 'MANAGER → HR_ADMIN → EXECUTIVE with 48h/48h/24h SLAs'],
        ['Partial approval', 'Approver can reduce headcount (requested 3 → approved 1) with audit trail'],
        ['Rejection with reason', 'Mandatory reason field — requester + history log capture'],
        ['Auto-publish on approval', 'Final APPROVE inserts rec_job_postings DRAFT automatically'],
        ['Duplicate detection', 'Active requisitions for same position surfaced at intake'],
        ['Clone from previous', 'One-click draft creation from any past requisition'],
        ['CSC Personnel Requisition PDF', 'ReportLab-rendered official form download'],
        ['WFP scenario warning', 'Banner appears when requested + current > active scenario plan'],
        ['Pending-approval reminder', 'REQ_PENDING_24H query pushes HIGH-priority inbox tasks after 24h'],
        ['Report Builder source', 'REQUISITIONS data source with 19 fields queryable via ARIA'],
        ['Dashboard KPIs', 'Pending · Approved YTD · Avg Days to Approve · Open Vacancies'],
        ['Guided tour', 'requisition-create-v1 — 6-step walkthrough for first-time HR users'],
     ]),

    ('H3', '10.2 How it compares'),
    ('TABLE', ['Capability', 'HCM360', 'SAP SuccessFactors', 'Workday', 'Sprout', 'Zoho People'],
     [
        ['Plantilla-backed vacancies', 'Yes (LGU-native)', 'Custom config', 'Custom config', 'No', 'No'],
        ['CSC-compliant approval chain', 'Seeded 3-step', 'Custom workflow', 'Custom workflow', 'No', 'No'],
        ['Partial-headcount approval', 'Yes', 'Yes', 'Yes', 'No', 'No'],
        ['Auto-publish on approval', 'Built-in', 'Requires scripting', 'Requires scripting', 'Manual', 'Manual'],
        ['CSC Personnel Requisition PDF', 'Yes (out of box)', 'No', 'No', 'No', 'No'],
        ['Duplicate-detection + clone', 'Yes', 'Limited', 'Yes', 'No', 'No'],
        ['24-hour SLA reminder to inbox', 'Yes', 'Yes', 'Yes', 'No', 'Limited'],
        ['ARIA AI: "pending requisitions?"', 'Instant answer', 'N/A', 'N/A', 'N/A', 'N/A'],
     ]),

    ('NOTE', 'The requisition engine is one of 31 items in Sheet #8 of the LGU Mariveles Gap Analysis — the only LGU-specific HRIS we are aware of that covers every aspect (Data Model, Create Flow, Approval Workflow, Publication, Notifications, Access Control, Reporting, Integration & Compliance) out of the box with zero custom development.'),

    # ───────────────────────────────────────────────────────────────
    ('H1', '11. Task Management Suite'),
    ('P', 'Most HRIS products stop at a passive "inbox" that receives workflow approvals. HCM360 ships a first-class task management suite — self-tasks, delegation, collaboration, templates, reminders, and KPIs — all scoped by role and dept, fully queryable by ARIA. HR teams stop tracking onboarding on spreadsheets and stop losing IPCR reminders in email threads.'),

    ('H3', '11.1 What ships in the box'),
    ('TABLE', ['Capability', 'Implementation'],
     [
        ['User-initiated task creation', '/tasks/new with title, description, priority, category, due date, assignee autocomplete'],
        ['Assign to direct reports', 'Department-scoped picker — non-admins can only assign within their team'],
        ['Team view (MANAGER+)', '/tasks/team aggregates every task for the manager\'s department'],
        ['Admin view (HR_ADMIN+)', '/admin/tasks shows every task company-wide with assigner + assignee filters'],
        ['Filter / sort / search', 'Status · Priority · Category · Due (overdue/today/this week) · Keyword · Sort: due/priority/created'],
        ['Comments + @mentions', 'core.task_comments with mentioned_user_ids[]; TASK_MENTIONED notification fires on mention'],
        ['Task templates library', '5 seeded: ONBOARD_NEW_HIRE (12 items) · OFFBOARD_SEPARATION (9) · MONTHLY_KPI · QUARTERLY_IPCR · ANNUAL_SALN'],
        ['Bulk spawn from template', 'One click spawns N tasks for N employees via the Global Employee Picker'],
        ['TASK_ASSIGNED notification', 'In-app + email when task is assigned by someone else (with {{assigner_name}}, {{title}}, {{due_date}})'],
        ['TASK_DUE_24H reminder', 'Daily trigger query fires when due_date = CURRENT_DATE + 1'],
        ['TASK_OVERDUE escalation', 'Daily trigger query + escalation to assigner after 48h'],
        ['Dashboard KPI cards', 'Open Tasks · Overdue · Completed YTD · Avg Days to Complete — role-filtered'],
        ['Report Builder source', 'TASKS data source with 19 fields including is_overdue, age_days, assigner_name, task_category'],
        ['ARIA natural-language queries', '"my overdue tasks" / "pending tasks in Finance" answered instantly — no code change'],
        ['Access matrix registration', '6 pages + 8 features (TASK_CREATE / ASSIGN / EDIT / COMPLETE / REASSIGN / COMMENT / DELETE / TEMPLATE_SPAWN)'],
        ['Guided tour', 'task-management-v1 — 6-step walkthrough auto-starts on first /me/inbox visit'],
     ]),

    ('H3', '11.2 How it compares'),
    ('TABLE', ['Capability', 'HCM360', 'SAP SuccessFactors', 'Workday', 'Zoho People'],
     [
        ['Task inbox + approvals', 'Yes', 'Yes', 'Yes', 'Basic'],
        ['Self-service task creation', 'Yes (autocomplete picker)', 'Limited', 'Yes', 'Basic'],
        ['Department-scoped delegation', 'Native', 'Custom config', 'Custom config', 'No'],
        ['@mention notifications', 'Yes (parsed from comments)', 'Limited', 'Yes', 'No'],
        ['Seeded HR templates (onboard/offboard/SALN/IPCR)', 'Yes (5 seeded)', 'Custom', 'Custom', 'No'],
        ['Bulk spawn for cohort of employees', 'Yes (via Employee Picker)', 'No', 'No', 'No'],
        ['Built-in overdue reminder engine', 'Yes (TRIGGER_QUERIES)', 'Yes', 'Yes', 'Limited'],
        ['ARIA AI queryable', 'Yes (auto-discovered)', 'N/A', 'N/A', 'N/A'],
     ]),

    # ───────────────────────────────────────────────────────────────
    ('H1', '12. Global Employee Picker — One Widget, Everywhere'),
    ('P', 'Every enterprise HRIS suffers from the same hidden tax: every module re-implements its own way of "pick an employee." HCM360 solves it once with a reusable JavaScript widget — three tabs (Individual search · Department bulk-expand · Custom Group bulk-expand), two modes (single-select · multi-select), and a shared look-and-feel — mounted on Tasks, Payroll Loans, and Wellness assignment today, with every future flow getting it for free.'),

    ('H3', '12.1 Why it matters'),
    ('UL', [
        'Consistent UX — employees learn one picker and it works everywhere',
        'Custom groups (PROBATIONARY, DEPT_HEADS) seeded + admin-editable at /admin/employee-groups',
        'Department bulk-expand — one click adds every employee in a department',
        'Single-select mode enforces one-and-only-one (e.g., loan beneficiary)',
        'Multi-select mode supports bulk cohorts (e.g., spawn onboarding checklists)',
        'Zero duplication — changing the widget once updates every flow',
        'AJAX API: /api/departments, /api/departments/<id>/employees, /api/employee-groups, /api/employee-groups/<id>/members',
     ]),

    # ───────────────────────────────────────────────────────────────
    ('H1', '13. Health & Wellness Program Management'),
    ('P', 'Beyond mandatory Physical Exams and Health Certificates, HCM360 ships a full wellness program orchestrator — plan, promote, assign, track attendance, and harvest feedback.'),

    ('H3', '13.1 Program lifecycle'),
    ('TABLE', ['Stage', 'Capability'],
     [
        ['Create', 'Six program types: Mental Health · Fitness · Nutrition · Vaccination · Screening · Seminar'],
        ['Schedule', 'Start/end dates, location (physical or virtual), schedule notes, max participants, provider/facilitator'],
        ['Assign attendees', 'Global Employee Picker — Individual / Department / Custom Group bulk expand'],
        ['Track attendance', 'Admin toggles ENROLLED → COMPLETED (attended) or NO_SHOW inline'],
        ['Gather feedback', 'Employees submit star rating (1-5) + free-text feedback post-program'],
        ['Analyze', 'Card badges show Registered / Attended / Avg Rating / Feedback count per program'],
        ['Filter + review', 'Status chips: PLANNED · ACTIVE · COMPLETED · CANCELLED'],
     ]),

    ('NOTE', 'The module is RA 11058 (Occupational Health and Safety) friendly — vaccination drives, screenings, and mental-health seminars are first-class categories on Day 1.'),

    # ───────────────────────────────────────────────────────────────
    ('H1', '14. Proof Points'),

    ('H3', '14.1 By the numbers (as of April 2026)'),
    ('TABLE', ['Metric', 'Value'],
     [
        ['Functional modules shipped', '19 (incl. Tasks, Employee Picker, Wellness)'],
        ['Production features delivered', '177 (100 requested + 77 bonus)'],
        ['Value multiplier vs LGU baseline', '1.77× (features shipped ÷ features requested)'],
        ['Registered pages in access matrix', '127+'],
        ['Workflow definitions active', '17+'],
        ['Notification templates', '16 event-typed (task_assigned, task_due_24h, task_overdue, task_commented, task_mentioned + original 11)'],
        ['Database tables + views', '210+ across 14 schemas'],
        ['Report Builder data sources', '33 with 300+ field definitions (incl. TASKS)'],
        ['Dashboard KPI cards', '23 role-filtered metrics (incl. 4 new task KPIs)'],
        ['Guided tours pre-seeded', '12 role-filtered walkthroughs (incl. task-management-v1)'],
        ['ARIA AI tools', '12 built-in HRIS tools (auto-discovers new sources)'],
        ['Pre-configured SQL migrations', '64+ versioned files'],
        ['CSC / BIR / DOLE artifacts supported', '18+ forms and reports'],
        ['Task templates seeded', '5 (ONBOARD · OFFBOARD · MONTHLY_KPI · QUARTERLY_IPCR · ANNUAL_SALN)'],
     ]),

    ('H3', '14.2 Delivered for Municipality of Mariveles (Bataan) HRMO'),
    ('P', 'HCM360 was deployed against the complete 113-requirement spec from Mariveles HRMO. Final outcome: 100+ of 113 requirements delivered at LIVE status, plus 77 bonus features beyond the original scope — a 1.77× value multiplier. Sheet #8 of the same gap analysis (Job Requisition feature audit) is at 100% readiness (all 40 aspects COVERED). Sheet #9 (Task Management) jumped from 14% readiness to ~52% in a single engineering cycle — all 10 High-priority gaps closed, with the remaining 34 low-priority items on the backlog.'),

    ('H1', '15. Decision Framework'),
    ('P', 'If any of the following are true for your organization, HCM360 is worth a 30-minute demo:'),
    ('UL', [
        'You need PH statutory compliance without custom development',
        'Your HR leaders need to ship reports themselves — not file IT tickets',
        'You want AI that answers cross-module questions with traceable data',
        'You value on-prem option or hybrid deployment over pure-SaaS lock-in',
        'You serve a government unit (LGU, NGA, state university) with CSC mandates',
        'You want to modernize from spreadsheet-based HR without a 12-month project',
        'You need face + geotag attendance without buying biometric hardware',
        'Your HR team is small and training budget is thin (guided tours pay back in weeks)',
     ]),

    ('H2', '15.1 Next steps'),
    ('OL', [
        'Request a live demo scoped to your top 3 business questions',
        'Receive a scoped implementation proposal with fixed-price rollout options',
        'Pilot with one department for 2 weeks before organization-wide go-live',
        'Full onboarding via in-product tours — no instructor-led training required',
     ]),

    ('NOTE', 'HCM360 is developed and supported locally in the Philippines. Our engineering team works in the same timezone as your operations, so support tickets close in hours — not days.'),
]
