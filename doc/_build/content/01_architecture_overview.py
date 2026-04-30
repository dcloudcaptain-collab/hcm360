TITLE = 'Architecture Overview'
SUBTITLE = 'How the HCM360 HRIS components fit together'
FOLDER = 'technical'

BLOCKS = [
    ('H1', '1. System Overview'),
    ('P', 'HCM360 is a multi-tenant Human Capital Management system built for Philippine SMEs and enterprises. It is a modular, web-based HRIS with sixteen functional modules spanning core HR, attendance, leave management, payroll, recruitment, performance, learning, rewards, document management, discipline, health and safety, organization charts, workforce planning, analytics, AI assistance, and system administration.'),
    ('P', 'The platform follows a three-tier architecture: a Flask-based web application handling UI and business logic, a PostgreSQL database as the system of record, and a standalone payroll microservice for heavyweight calculations. Containerization via Docker Compose simplifies deployment and keeps all services isolated.'),

    ('H2', '1.1 High-Level Topology'),
    ('TABLE', ['Layer', 'Technology', 'Port', 'Purpose'],
     [
        ['Presentation', 'Jinja2 + HTML5 + inline CSS', '8093', 'Server-rendered UI delivered by Flask'],
        ['Application (Main)', 'Python 3.11 / Flask', '8093 → 5000', 'Business logic, auth, request routing'],
        ['Application (Payroll)', 'Python 3.11 / Flask', '8095 → 5001', 'Payroll calculations & PDF generation'],
        ['Data', 'PostgreSQL 15', '5440 → 5432', 'System of record, audit logs, analytics'],
        ['Storage', 'Named Docker volume', 'n/a', 'File uploads, documents, certificates'],
     ]),

    ('H2', '1.2 Component Diagram (Logical)'),
    ('CODE',
     '+-------------------------------------------------------------------+\n'
     '|                         Web Browser (User)                        |\n'
     '+-------------------------------+-----------------------------------+\n'
     '                                | HTTPS / HTTP 8093\n'
     '+-------------------------------v-----------------------------------+\n'
     '|                      hris_web (Flask Monolith)                    |\n'
     '|  +-----------+-----------+-----------+-----------+-----------+    |\n'
     '|  |  Core HR  | Attendance|   Leave   |    ESS    |   Admin   |    |\n'
     '|  +-----------+-----------+-----------+-----------+-----------+    |\n'
     '|  |  Orgchart |    DMS    |    RSP    |    PM     |    L&D    |    |\n'
     '|  +-----------+-----------+-----------+-----------+-----------+    |\n'
     '|  | Discipline|  Health   | Workforce | Analytics |     AI    |    |\n'
     '|  +-----------+-----------+-----------+-----------+-----------+    |\n'
     '|           Services: access - privacy - theme - reporting          |\n'
     '+-------------------------------+-----------------------------------+\n'
     '                                | psycopg2 pool\n'
     '+-------------------------------v-----------------------------------+\n'
     '|                    hris_db (PostgreSQL 15)                        |\n'
     '|   Schemas: core - attendance - leave_mgmt - payroll - rsp - pm    |\n'
     '|            ld - rr - dms - discipline - health - audit_logs       |\n'
     '+-------------------------------^-----------------------------------+\n'
     '                                | shared DB\n'
     '+-------------------------------+-----------------------------------+\n'
     '|            payroll_web (Standalone microservice :8095)            |\n'
     '+-------------------------------------------------------------------+'),

    ('H1', '2. Frontend'),
    ('P', 'The frontend uses server-side rendered Jinja2 templates with inline CSS for a zero-build, dependency-free UI. This keeps the deployment footprint small and makes every page cacheable in isolation. A base template provides the navigation shell, theme variables, branding, and session-aware context.'),
    ('H2', '2.1 Template Structure'),
    ('UL', [
        'templates/base.html — shell, sidebar, theme CSS variables, flash messages',
        'templates/<module>/*.html — per-module page templates (employees, attendance, leave, payroll, ess_mss, etc.)',
        'templates/admin/*.html — access matrix, reference data, privacy rules, themes',
        'Inline CSS using brand color tokens (primary, accent, surface) exposed via g.theme context processor',
     ]),
    ('H2', '2.2 Design System Tokens'),
    ('TABLE', ['Token', 'Default', 'Usage'],
     [
        ['--primary', '#4F46E5 (indigo)', 'Buttons, links, highlights, active nav'],
        ['--accent', '#1E40AF (blue)', 'Brand stripe, cover banners, focus rings'],
        ['--surface', '#FFFFFF', 'Cards, table rows, modal backgrounds'],
        ['--text', '#111827', 'Body text, headings'],
        ['--muted', '#6B7280', 'Labels, captions, placeholder'],
        ['--border', '#E5E7EB', 'Dividers, card edges, table gridlines'],
     ]),

    ('H1', '3. Backend Application'),
    ('P', 'The backend is a modular Flask application. Each functional domain lives under `modules/<name>/` with its own blueprint, service layer, and templates. Shared concerns (database access, authentication, navigation, theming, reporting, privacy, AI) live under `services/`.'),

    ('H2', '3.1 Module Layout'),
    ('CODE',
     'hcm360/\n'
     '├── app.py                    # Entry point: app factory, login, before_request\n'
     '├── config.py                 # Config + feature flags from .env\n'
     '├── requirements.txt          # Python deps\n'
     '├── Dockerfile                # Web container build\n'
     '├── docker-compose.yml        # 3-service orchestration\n'
     '├── services/                 # Cross-cutting services\n'
     '│   ├── db.py                 # Connection pool, cursor context manager\n'
     '│   ├── access_service.py     # RBAC: page + feature + mod access\n'
     '│   ├── privacy_service.py    # Field-level RA 10173 masking\n'
     '│   ├── reference_service.py  # 29+ reference tables\n'
     '│   ├── theme_service.py      # UI theming per company/user\n'
     '│   ├── reporting_service.py  # PDF + Excel generation\n'
     '│   └── nav_service.py        # Role-filtered navigation tree\n'
     '├── modules/\n'
     '│   ├── employees/            # Core HR (master data, 201 file)\n'
     '│   ├── attendance/           # DTR, shifts, overtime\n'
     '│   ├── leave_mgmt/           # Leave types, balances, requests\n'
     '│   ├── payroll/              # Runs, payslips, loans\n'
     '│   ├── ess_mss/              # Self & manager service\n'
     '│   ├── orgchart/             # Org hierarchy visualization\n'
     '│   ├── workforce_planning/   # Headcount scenarios\n'
     '│   ├── dms/                  # 201 documents, certificates\n'
     '│   ├── rsp/                  # Recruitment\n'
     '│   ├── pm/                   # Performance management\n'
     '│   ├── ld/                   # Learning & development\n'
     '│   ├── rr/                   # Rewards & recognition\n'
     '│   ├── discipline/           # Cases, investigations, sanctions\n'
     '│   ├── health/               # Incidents, safety reports\n'
     '│   ├── analytics/            # Dashboards, reports\n'
     '│   ├── ai/                   # AI assistant (ARIA)\n'
     '│   └── admin/                # System configuration\n'
     '├── templates/                # Jinja2 templates mirrored by module\n'
     '├── db/                       # Versioned SQL migrations (00–51)\n'
     '├── uploads/                  # Bind mount for documents\n'
     '└── payroll/                  # Standalone payroll microservice'),

    ('H2', '3.2 Request Lifecycle'),
    ('OL', [
        'Browser issues request to /path. Flask matches blueprint route.',
        'before_request hook loads g.theme, g.branding, g.users, g.current_user.',
        'If no user_id in session, redirects to /login (except for public paths).',
        'can_access_page() checks core.role_page_access and core.user_page_access; returns 403 on miss.',
        'Blueprint handler calls its service layer (e.g., employees.services.get_employee_detail).',
        'Service uses get_cursor() context manager from services/db.py to query PostgreSQL.',
        'Raw data passes through privacy_service.apply_privacy() for field masking.',
        'Template renders with role-filtered nav, branding, and masked data.',
        'Response returned with flash messages and session cookie.',
     ]),

    ('H1', '4. Data Layer'),
    ('P', 'PostgreSQL 15 hosts all system data. Schemas partition the database by functional domain. Migrations live in db/ and run automatically on first container start via the docker-entrypoint-initdb.d pattern.'),

    ('H2', '4.1 Schema Map'),
    ('TABLE', ['Schema', 'Purpose', 'Key Tables'],
     [
        ['core', 'Master data, users, access, reference', 'companies, users, employees, departments, page_registry'],
        ['attendance', 'DTR, shifts, biometrics', 'att_daily, att_shifts, att_overrides'],
        ['leave_mgmt', 'Leave types, balances, requests', 'lv_types, lv_balances, lv_requests, lv_holidays'],
        ['payroll', 'Runs, payslips, deductions', 'pay_runs, pay_employee_payroll, pay_loans, v_payslip'],
        ['rsp', 'Recruitment pipeline', 'candidates, requisitions, interviews'],
        ['pm', 'Performance reviews', 'review_cycles, evaluations, kpis'],
        ['ld', 'Training & certifications', 'trainings, certifications, enrollments'],
        ['rr', 'Awards & praise', 'awards, praise_wall'],
        ['dms', 'Documents & certificates', 'documents, document_categories, certificate_requests'],
        ['discipline', 'Cases & sanctions', 'cases, sanctions, case_types'],
        ['health', 'Incidents & safety', 'incidents, safety_reports'],
        ['audit_logs', 'Change tracking', 'change_log, access_log'],
     ]),

    ('H1', '5. Integrations'),
    ('P', 'HCM360 is designed to operate as a system of record but can integrate with external systems via standard patterns:'),
    ('UL', [
        'SSO: JWT token parsing in /login flow (username claim resolution)',
        'Payroll microservice: shares the same database; communicates via DB state',
        'AI (ARIA): configurable Anthropic API key via .env for document summaries and query assistance',
        'Email: optional SMTP configuration for notifications and certificates',
        'File storage: bind-mounted /uploads volume for persistence across rebuilds',
     ]),

    ('H1', '6. Scalability Considerations'),
    ('UL', [
        'Connection pooling: psycopg2 pool via services/db.py (default max 10 connections)',
        'Stateless web containers: session in server-signed cookies, easy horizontal scaling',
        'Read-heavy workloads: materialized views (e.g., payroll.v_payslip) for reporting',
        'Indexes: every FK + hot query path indexed (employee_id, run_id, date ranges)',
        'Audit log volume: partitionable by month via pg_partman if needed',
        'Payroll batch processing: isolated into its own container to avoid blocking the web tier',
     ]),

    ('H1', '7. Non-Functional Guarantees'),
    ('TABLE', ['Attribute', 'Design Decision'],
     [
        ['Data persistence', 'Named Docker volumes survive rebuilds; full pg_dump backup in backups/'],
        ['Privacy compliance', 'RA 10173 field-level masking with VISIBLE/MASKED/HIDDEN visibility'],
        ['Audit trail', 'Triggers on every mutation write to audit_logs.change_log'],
        ['Auth', 'Session-based with role-driven page/feature/mod access matrix'],
        ['Restartability', 'restart: unless-stopped for all containers'],
        ['Upgradability', 'Versioned SQL migrations; each change adds a new numbered file'],
     ]),
]
