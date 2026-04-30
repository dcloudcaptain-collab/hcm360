-- ================================================================
-- HCM360 — 65: EXPANDED GUIDED TOUR LIBRARY
--
-- Adds 12 new role-aware guided tours covering main modules that
-- did not yet have a walkthrough:
--
--   1.  performance-mgmt-v1       /performance
--   2.  learning-catalog-v1       /learning
--   3.  rewards-hub-v1            /rewards
--   4.  orgchart-v1               /orgchart
--   5.  workforce-planning-v1     /workforce-planning
--   6.  dms-201-v1                /dms
--   7.  health-safety-v1          /health
--   8.  wellness-programs-v1      /health/wellness
--   9.  aria-assistant-v1         /ai/assistant
--   10. retirement-monitoring-v1  /retirement
--   11. step-increments-v1        /step-increments
--   12. reports-hub-v1            /reports
--   13. my-leaves-v1              /me/leaves
--   14. my-payslips-v1            /me/payslips
--
-- Also upgrades the existing dashboard welcome tour to v2 so
-- everyone re-sees it (new Quick Actions bar + Task KPIs).
-- ================================================================
SET search_path TO core, public;

-- ── 1. Performance Management ────────────────────────────────
INSERT INTO core.tours (tour_key, title, description, module, allowed_roles, url_pattern, steps)
VALUES
('performance-mgmt-v1',
 'Performance Management',
 'Review cycles, KPIs, and IPCR ratings',
 'performance',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE'],
 '/performance',
 '[
    {"title":"Performance Management","body":"Run review cycles, track KPIs, and capture IPCR ratings in one place.","position":"center"},
    {"selector":"a[href*=\"cycle\"], .btn-primary","title":"Review Cycles","body":"Create annual, mid-year, or probationary cycles. Each cycle rolls up KPIs + competencies into an IPCR rating.","position":"bottom"},
    {"selector":"a[href*=\"ipcr\"]","title":"IPCR Form","body":"Employees self-rate, managers review, HR calibrates. IPCR summary exposes distribution + outliers per department.","position":"top"},
    {"selector":"table, .cycles-list","title":"Cycle Status","body":"Click any cycle to see per-employee progress. PENDING (red) → IN_PROGRESS (amber) → SUBMITTED (blue) → FINALIZED (green).","position":"top"},
    {"title":"Tip","body":"Need to spawn a Quarterly IPCR task for every employee? Use Admin → Task Templates → QUARTERLY_IPCR → Spawn.","position":"center"}
 ]'::jsonb),

-- ── 2. Learning & Development ────────────────────────────────
('learning-catalog-v1',
 'Learning & Development',
 'Training catalog, enrollments, and attendance',
 'learning',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE'],
 '/learning',
 '[
    {"title":"L&D Catalog","body":"Post trainings, manage enrollments, and track attendance — all mobile-friendly.","position":"center"},
    {"selector":"a[href*=\"new\"], .btn-primary","title":"Add a Program","body":"Create a training or seminar. Prerequisites + target audiences are supported.","position":"bottom"},
    {"selector":"a[href*=\"sessions\"]","title":"Sessions & Attendance","body":"Each program has sessions with AM/PM shift tracking. Mobile + geotag check-in lives here.","position":"top"},
    {"selector":"a[href*=\"nrf\"], a[href*=\"narrative\"]","title":"Narrative Reports","body":"After attending, employees fill the Narrative Report Form (NRF). Approval flows via LD_NRF_APPROVAL workflow.","position":"top"},
    {"selector":"a[href*=\"tna\"]","title":"Training Needs Analysis","body":"Identify skill gaps from performance reviews and target trainings accordingly.","position":"top"}
 ]'::jsonb),

-- ── 3. Rewards & Recognition ─────────────────────────────────
('rewards-hub-v1',
 'Rewards & Recognition',
 'Loyalty, PBB, nominations, and step increments',
 'rewards',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE'],
 '/rewards',
 '[
    {"title":"Rewards Hub","body":"Every CSC/DBM-sanctioned reward lives here — loyalty, PBB, and ad-hoc recognition.","position":"center"},
    {"selector":"a[href*=\"loyalty\"]","title":"Loyalty Service Awards","body":"Scan for employees reaching 10/15/20/25/30 years. One click generates CSC-compliant memo PDFs.","position":"right"},
    {"selector":"a[href*=\"pbb\"]","title":"Performance-Based Bonus (PBB)","body":"Track PBB eligibility + disbursement per DBM cycle. Status flows DRAFT → APPROVED → PAID.","position":"top"},
    {"selector":"a[href*=\"nomination\"]","title":"Nominations & Awards","body":"Employee-of-the-Month nominations, peer praise wall, and committee decisions live here.","position":"top"},
    {"selector":"a[href*=\"step-increment\"]","title":"Step Increments","body":"3-year cadence scanner. Due → Notice Sent → Approved → Recorded.","position":"top"}
 ]'::jsonb),

-- ── 4. Org Chart ─────────────────────────────────────────────
('orgchart-v1',
 'Organization Chart',
 'Navigate hierarchy + department scoping',
 'orgchart',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE'],
 '/orgchart',
 '[
    {"title":"Org Chart","body":"Person-centric view — you see ancestors, peers, and direct reports at a glance.","position":"center"},
    {"selector":".privacy-banner, [data-privacy]","title":"Privacy-Aware","body":"Sensitive fields (salary, contact, birthday) obey RA 10173 rules per role. Your record always shows full detail.","position":"bottom"},
    {"selector":".node, .orgchart-node","title":"Nodes","body":"Click any node to focus the tree around that person. Double-click opens the 201 file.","position":"right"},
    {"selector":"a[href*=\"department\"]","title":"Department Detail","body":"Drill into a department to see its headcount KPIs, open vacancies, and training hours.","position":"top"}
 ]'::jsonb),

-- ── 5. Workforce Planning ────────────────────────────────────
('workforce-planning-v1',
 'Workforce Planning',
 'Scenario modeling + skill gap analysis',
 'workforce_planning',
 ARRAY['SUPER_ADMIN','HR_ADMIN','EXECUTIVE'],
 '/workforce-planning',
 '[
    {"title":"Workforce Planning","body":"Model future headcount, cost, and skills. Scenarios are non-destructive — safe to experiment.","position":"center"},
    {"selector":"a[href*=\"new\"], .btn-primary","title":"New Scenario","body":"Scenarios capture attrition %, growth %, salary increments, and new-hire timing. Quarterly headcount plans auto-generate.","position":"bottom"},
    {"selector":"a[href*=\"scenario\"]","title":"Scenario Detail","body":"Each scenario shows a 4-quarter projection with gap-to-budget and skill-supply-vs-demand charts.","position":"top"},
    {"selector":".req-banner, .wfp-warning","title":"Requisition Guard-Rail","body":"When you submit a requisition over the active plan, a banner appears on its detail page — with the scenario name + over-by count.","position":"top"}
 ]'::jsonb),

-- ── 6. DMS / 201 File ────────────────────────────────────────
('dms-201-v1',
 'Document Management (201)',
 'Upload, categorize, and track expiry',
 'dms',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE'],
 '/dms',
 '[
    {"title":"Document Management","body":"Every 201-file document lives here — contracts, diplomas, clearances, and signed forms.","position":"center"},
    {"selector":"a[href*=\"requests\"], .requests-link","title":"Certificate Requests","body":"HR queue for COE, Service Record, and similar requests. Auto-generated templates cover the common cases.","position":"right"},
    {"selector":"a[href*=\"retention\"]","title":"Retention Policies","body":"CSC-compliant 5-year minimum on recruitment docs, 10-year on 201 files. Archive jobs honor these policies.","position":"top"},
    {"selector":"a[href*=\"saln\"]","title":"SALN Filings","body":"Three filing modes: UPLOAD_ONLY (scan), SIMPLE (web form), FULL (CSC Form 210 builder).","position":"top"},
    {"selector":"a[href*=\"esign\"], .esign-link","title":"E-Signatures","body":"Canvas pad or DocuSign — core.document_signatures audits every signature with IP + timestamp.","position":"top"}
 ]'::jsonb),

-- ── 7. Health & Safety ───────────────────────────────────────
('health-safety-v1',
 'Occupational Health & Safety',
 'PE scans, incidents, certificates, wellness',
 'health',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE'],
 '/health',
 '[
    {"title":"Health & Safety","body":"RA 11058 coverage: physical exams, incident reports, health certificates, and wellness programs.","position":"center"},
    {"selector":"a[href*=\"pe\"]","title":"Physical Exams","body":"Schedule annual PEs per department; track compliance % and outstanding cases.","position":"right"},
    {"selector":"a[href*=\"incident\"]","title":"Incident Reports","body":"File incidents with DOLE-reportable flag; investigations + witness capture are built in.","position":"top"},
    {"selector":"a[href*=\"certificate\"]","title":"Health Certificates","body":"Expiry alerts fire 60 days before. Dashboard KPI shows pending renewals.","position":"top"},
    {"selector":"a[href*=\"wellness\"]","title":"Wellness Programs","body":"Mental health, fitness, vaccination drives, screenings, seminars — six program types out of the box.","position":"top"}
 ]'::jsonb),

-- ── 8. Wellness Programs detail ──────────────────────────────
('wellness-programs-v1',
 'Wellness Programs',
 'Assign attendees, mark attendance, collect feedback',
 'health',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE'],
 '/health/wellness',
 '[
    {"title":"Wellness Programs","body":"Plan, promote, assign, track attendance, and collect ratings — all in one flow.","position":"center"},
    {"selector":".filters, .filter-chip","title":"Filter by Status","body":"Planned · Active · Completed · Cancelled. Stat badges on each card show Registered / Attended / Avg Rating.","position":"bottom"},
    {"selector":"a[href*=\"wellness/new\"], .btn-primary","title":"New Program","body":"Pick a type (Mental Health / Fitness / Vaccination / Screening / Seminar / Nutrition), set dates, location, and max participants.","position":"bottom"},
    {"selector":".prog-card","title":"Open a Program","body":"Click any card for detail: assign attendees via the Global Employee Picker, mark attendance, read feedback.","position":"top"},
    {"title":"Tip","body":"Admins can bulk-assign by Individual, Department, or custom Employee Group (e.g., PROBATIONARY, DEPT_HEADS).","position":"center"}
 ]'::jsonb),

-- ── 9. ARIA Assistant ────────────────────────────────────────
('aria-assistant-v1',
 'ARIA AI Assistant',
 'Ask natural-language questions about your workforce',
 'ai',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE'],
 '/ai/assistant',
 '[
    {"title":"Meet ARIA","body":"Your AI-powered HR assistant. Ask anything — ARIA reads live data and answers with source-traceable numbers.","position":"center"},
    {"selector":"textarea, input[type=text], .chat-input","title":"Ask a Question","body":"Try: \"my overdue tasks\", \"how many retirements in Q3?\", \"top 10 net pay earners YTD\", or \"CSC eligibility by gender\".","position":"top"},
    {"selector":".chat-messages, .aria-history","title":"Streaming Answers","body":"Responses stream live via Server-Sent Events. Every number is backed by a validated SQL query — no hallucinations.","position":"top"},
    {"title":"12 Built-in Tools","body":"ARIA knows 30+ data sources and 12 HRIS tools (workforce, workflow, KPIs, attrition risk, tasks, requisitions…). New data sources auto-register.","position":"center"}
 ]'::jsonb),

-- ── 10. Retirement Monitoring ────────────────────────────────
('retirement-monitoring-v1',
 'Retirement Monitoring',
 'Identify upcoming retirements + generate notices',
 'core_hr',
 ARRAY['SUPER_ADMIN','HR_ADMIN'],
 '/retirement',
 '[
    {"title":"Retirement Monitoring","body":"Auto-identifies employees approaching early (60) or mandatory (65) retirement per active rule profile.","position":"center"},
    {"selector":".kpi, [data-kpi]","title":"KPI Cards","body":"Upcoming · Due This Quarter · Notices Sent · Completed — all broken down by gender for CSC reports.","position":"bottom"},
    {"selector":"a[href*=\"scan\"], .btn-primary","title":"Run Scan","body":"Scans every active employee against the rule profile''s mandatory/early ages + notice lead months.","position":"top"},
    {"selector":"a[href*=\"notice\"]","title":"Generate Notice","body":"One click produces 3 artifacts: HR notice · Employee letter · Finance path — all CSC-formatted PDFs.","position":"top"},
    {"selector":"a[href*=\"retirement-rules\"]","title":"Rule Profiles","body":"Admin → Retirement Rules lets you define multiple profiles (e.g., casual vs permanent) with department scoping.","position":"top"}
 ]'::jsonb),

-- ── 11. Step Increments ──────────────────────────────────────
('step-increments-v1',
 'Step Increment Tracker',
 '3-year cadence scanner + notice generator',
 'core_hr',
 ARRAY['SUPER_ADMIN','HR_ADMIN'],
 '/step-increments',
 '[
    {"title":"Step Increments","body":"Civil Service step increments every 3 years from Date of Original Appointment.","position":"center"},
    {"selector":".kpi, [data-kpi]","title":"Due / Overdue / Coming Soon","body":"KPI cards surface counts so you can triage fastest.","position":"bottom"},
    {"selector":"a[href*=\"scan\"]","title":"Run the Scanner","body":"Scanner creates DUE records for anyone at the 3-year mark; transitions DUE → NOTICE_SENT → APPROVED → RECORDED.","position":"top"},
    {"selector":"table","title":"Action Rows","body":"Each row has inline Notice / Approve buttons. Audit log captures every state change with the acting user.","position":"top"}
 ]'::jsonb),

-- ── 12. Reports & Analytics hub ──────────────────────────────
('reports-hub-v1',
 'Reports & Analytics',
 'Report Builder + pre-built dashboards',
 'analytics',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EXECUTIVE'],
 '/reports',
 '[
    {"title":"Reports & Analytics","body":"Pre-built dashboards + a drag-drop Report Builder with 32 data sources.","position":"center"},
    {"selector":"a[href*=\"builder\"], a[href*=\"report-builder\"]","title":"Report Builder","body":"Pick a data source, choose fields, apply filters, save + schedule. Export as CSV / XLSX / PDF.","position":"right"},
    {"selector":"a[href*=\"demographics\"]","title":"HR Demographics","body":"Gender × age × department × salary grade — all CSC-aligned cross-tabs.","position":"top"},
    {"selector":"a[href*=\"attrition\"]","title":"Attrition Risk","body":"AI-scored retention risk with factor chips + gender split.","position":"top"},
    {"selector":"a[href*=\"scheduled\"]","title":"Scheduled Reports","body":"Daily / Weekly / Monthly cadence with email recipient lists — once SMTP is configured.","position":"top"}
 ]'::jsonb),

-- ── 13. My Leaves (employee) ─────────────────────────────────
('my-leaves-v1',
 'My Leaves',
 'Apply, track, and print CS Form No. 6',
 'ess_mss',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE'],
 '/me/leaves',
 '[
    {"title":"My Leaves","body":"See balances, apply for leave, and track approvals — all from here.","position":"center"},
    {"selector":".balance, [data-balance]","title":"Balances","body":"Vacation, Sick, Special Privilege, Mandatory — current balance and earned YTD.","position":"bottom"},
    {"selector":"a[href*=\"new\"], .btn-primary","title":"File Leave","body":"Full CS Form No. 6 (revised 2020) — strict compliance mode with whereabouts, commutation, and signatories.","position":"top"},
    {"selector":"table","title":"Request History","body":"Status flows PENDING → APPROVED (balance auto-debits) or REJECTED (with reason). Download printable CS Form 6 PDF once approved.","position":"top"}
 ]'::jsonb),

-- ── 14. My Payslips (employee) ───────────────────────────────
('my-payslips-v1',
 'My Payslips',
 'View + download digital payslips',
 'ess_mss',
 ARRAY['SUPER_ADMIN','HR_ADMIN','MANAGER','EMPLOYEE','EXECUTIVE'],
 '/me/payslips',
 '[
    {"title":"My Payslips","body":"Every payroll run posted to you appears here with on-demand PDF download.","position":"center"},
    {"selector":"table","title":"Run History","body":"Regular · 13th Month · Final Pay runs, newest first. Click a row for the full breakdown.","position":"top"},
    {"selector":"a[href*=\"pdf\"], .btn-primary","title":"Download Payslip","body":"Official PDF generated on demand. Loans, benefits, and government deductions are itemized.","position":"top"},
    {"selector":"a[href*=\"compensation\"]","title":"Compensation Summary","body":"/me/compensation shows active loans, SG, step, rate, and YTD gross/net.","position":"top"}
 ]'::jsonb)

ON CONFLICT (tour_key) DO UPDATE SET
    title         = EXCLUDED.title,
    description   = EXCLUDED.description,
    module        = EXCLUDED.module,
    allowed_roles = EXCLUDED.allowed_roles,
    url_pattern   = EXCLUDED.url_pattern,
    steps         = EXCLUDED.steps,
    version       = core.tours.version + 1,
    updated_at    = NOW();


-- ── Upgrade dashboard welcome tour to v2 (Quick Actions + Task KPIs) ──
UPDATE core.tours
   SET version = 2,
       steps = '[
        {"title":"Welcome to HCM360","body":"This is your home dashboard. We''ll show you around in 7 quick steps.","position":"center"},
        {"selector":".nav-primary, nav.sidebar, aside.sidebar","title":"Navigation","body":"Use the left sidebar to jump between modules. Items are filtered to match your role.","position":"right"},
        {"selector":".quick-actions, [data-quick-actions]","title":"Quick Actions","body":"One-click shortcuts to the tasks your role runs most. Report Builder and ARIA are always pinned.","position":"bottom"},
        {"selector":".kpi, .kpi-card, [data-kpi]","title":"KPI Cards","body":"At-a-glance metrics — headcount, present today, leaves pending, tasks open/overdue, and more. Click any card to drill in.","position":"bottom"},
        {"selector":".inbox, [data-inbox], a[href*=\"inbox\"]","title":"Task Inbox","body":"Approvals + assigned tasks land in your inbox. TASK_DUE_24H and TASK_OVERDUE reminders fire automatically.","position":"bottom"},
        {"selector":"a[href*=\"/me/profile\"], a[href=\"/me\"]","title":"My Profile","body":"Update your personal info, addresses, and documents from your profile page.","position":"bottom"},
        {"title":"All set!","body":"Click the ? launcher in the bottom-right any time to replay this tour or explore other tours.","position":"center"}
     ]'::jsonb,
       updated_at = NOW()
 WHERE tour_key = 'dashboard-welcome-v1';


-- ── Make sure new tours are discoverable in /admin/tours ──────
-- (no extra registry needed — /admin/tours reads core.tours directly)
