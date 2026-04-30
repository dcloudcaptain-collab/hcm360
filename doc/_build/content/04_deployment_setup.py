TITLE = 'Deployment Setup'
SUBTITLE = 'Run, deploy, and operate HCM360 HRIS v1.0'
FOLDER = 'technical'

BLOCKS = [
    ('H1', '1. System Requirements'),
    ('P', 'HCM360 is delivered as a Docker Compose stack. All dependencies run in containers — the host only needs Docker Engine.'),
    ('TABLE', ['Component', 'Minimum', 'Recommended'],
     [
        ['CPU', '2 cores', '4+ cores'],
        ['RAM', '4 GB', '8+ GB'],
        ['Disk', '20 GB', '50+ GB (for uploads + backups)'],
        ['Docker Engine', '20.10+', '24+ with Compose v2'],
        ['OS', 'Linux / macOS / Windows WSL2', 'Linux (Ubuntu 22.04 LTS)'],
     ]),

    ('H1', '2. Repository Layout'),
    ('CODE',
     'hcm360/\n'
     '├── app.py                   # Flask entry point\n'
     '├── config.py                # Feature flags from env\n'
     '├── requirements.txt         # pip deps\n'
     '├── Dockerfile               # Web container build\n'
     '├── docker-compose.yml       # 3-service orchestration\n'
     '├── docker/init_db.sh        # First-run DB initializer\n'
     '├── .env                     # API keys (not committed)\n'
     '├── db/                      # Versioned SQL migrations (00–51)\n'
     '├── modules/                 # Blueprints per domain\n'
     '├── services/                # Shared services\n'
     '├── templates/               # Jinja2 templates\n'
     '├── uploads/                 # File uploads (bind-mounted)\n'
     '├── backups/                 # pg_dump files\n'
     '├── scripts/restore_v1.sh    # Restore helper\n'
     '├── payroll/                 # Standalone payroll microservice\n'
     '├── VERSION                  # 1.0.0\n'
     '└── CHANGELOG.md             # Release notes'),

    ('H1', '3. First-Time Setup'),

    ('H2', '3.1 Clone and Configure'),
    ('OL', [
        'Clone the repository to /opt/hcm360 (or any path)',
        'Copy .env.example to .env and set ANTHROPIC_API_KEY for ARIA AI (optional)',
        'Review docker-compose.yml — port mappings default to 8093 (web), 8095 (payroll), 5440 (DB)',
        'Build and start: docker compose up -d --build',
        'Watch initial DB seed: docker compose logs -f hris_db',
        'Once hris_db is healthy, web starts automatically',
        'Open http://localhost:8093 and pick a demo user',
     ]),

    ('H2', '3.2 First-Run DB Initialization'),
    ('P', 'The db/ folder is bind-mounted into /docker-entrypoint-initdb.d/sql on the PostgreSQL container. docker/init_db.sh runs every .sql file in numeric order (00_extensions through 51_workforce_planning_access). This happens only on first start when the data volume is empty.'),

    ('H1', '4. docker-compose.yml'),
    ('P', 'Three services share a default network. The DB uses a named volume so data survives docker compose down and rebuilds.'),
    ('CODE',
     'services:\n'
     '  hris_db:\n'
     '    image: postgres:15\n'
     '    restart: unless-stopped\n'
     '    environment:\n'
     '      POSTGRES_DB: hris_db\n'
     '      POSTGRES_USER: hris_admin\n'
     '      POSTGRES_PASSWORD: hris_secure_pw\n'
     '    ports: ["5440:5432"]\n'
     '    volumes:\n'
     '      - hris_db_data:/var/lib/postgresql/data\n'
     '      - hris_uploads:/uploads\n'
     '      - ./db:/docker-entrypoint-initdb.d/sql:ro\n'
     '      - ./docker/init_db.sh:/docker-entrypoint-initdb.d/init_db.sh:ro\n'
     '    healthcheck:\n'
     '      test: ["CMD-SHELL", "pg_isready -U hris_admin -d hris_db"]\n'
     '\n'
     '  hris_web:\n'
     '    build: .\n'
     '    image: hcm360-hris_web:v1.0\n'
     '    restart: unless-stopped\n'
     '    depends_on:\n'
     '      hris_db: {condition: service_healthy}\n'
     '    environment:\n'
     '      DATABASE_URL: postgresql://hris_admin:hris_secure_pw@hris_db:5432/hris_db\n'
     '    volumes:\n'
     '      - .:/app\n'
     '      - hris_uploads:/uploads\n'
     '    ports: ["8093:5000"]\n'
     '\n'
     '  payroll_web:\n'
     '    build: ./payroll\n'
     '    image: hcm360-payroll_web:v1.0\n'
     '    restart: unless-stopped\n'
     '    depends_on:\n'
     '      hris_db: {condition: service_healthy}\n'
     '    ports: ["8095:5001"]\n'
     '\n'
     'volumes:\n'
     '  hris_db_data:\n'
     '    name: hcm360_hris_db_data\n'
     '  hris_uploads:\n'
     '    name: hcm360_hris_uploads'),

    ('H1', '5. Environment Variables'),
    ('TABLE', ['Variable', 'Default', 'Purpose'],
     [
        ['DATABASE_URL', 'postgresql://hris_admin:...@hris_db:5432/hris_db', 'PostgreSQL connection URL'],
        ['SECRET_KEY', 'changeme-hris-prod', 'Flask session signing key — CHANGE in production'],
        ['UPLOAD_FOLDER', '/uploads', 'Bind-mounted folder for document uploads'],
        ['ANTHROPIC_API_KEY', '(empty)', 'Enables ARIA AI features when set'],
        ['ENABLE_ATTENDANCE', 'true', 'Register attendance blueprint'],
        ['ENABLE_LEAVE', 'true', 'Register leave blueprint'],
        ['ENABLE_PAYROLL', 'true', 'Register payroll blueprint'],
        ['ENABLE_RSP / PM / LD / RR', 'true', 'Register recruitment, performance, learning, rewards'],
        ['ENABLE_DMS / DISCIPLINE / HEALTH', 'true', 'Register document management, discipline, health & safety'],
        ['ENABLE_ORGCHART', 'true', 'Register org chart blueprint'],
        ['ENABLE_AI / ANALYTICS', 'true', 'Register AI and analytics modules'],
     ]),

    ('H1', '6. Deploying Updates'),
    ('H2', '6.1 Code Changes Only'),
    ('P', 'The web container bind-mounts the project root at /app. Edit files locally and restart the container to pick up Python changes:'),
    ('CODE',
     '# Restart web only\n'
     'docker compose restart hris_web\n'
     '\n'
     '# Or kill and start fresh (keeps DB data)\n'
     'docker compose down hris_web && docker compose up -d hris_web'),

    ('H2', '6.2 Schema Changes'),
    ('P', 'Add a new numbered SQL file under db/ (e.g., db/52_my_feature.sql). For existing deployments, apply manually since db/ only runs on empty volumes:'),
    ('CODE',
     'docker exec -i hris_db psql -U hris_admin -d hris_db < db/52_my_feature.sql'),

    ('H2', '6.3 Dockerfile / Dependency Changes'),
    ('CODE',
     'docker compose build --no-cache hris_web\n'
     'docker compose up -d hris_web'),

    ('H1', '7. Data Persistence'),
    ('P', 'Two named Docker volumes ensure data survives container rebuilds:'),
    ('TABLE', ['Volume', 'Mount', 'Contents'],
     [
        ['hcm360_hris_db_data', '/var/lib/postgresql/data', 'All PostgreSQL data files'],
        ['hcm360_hris_uploads', '/uploads', 'Document uploads, logos, certificates'],
     ]),
    ('NOTE', 'docker compose down by itself does NOT remove volumes. Only docker compose down -v will delete them. Always use docker compose down (without -v) unless you intend a clean wipe.'),

    ('H1', '8. Backups & Restore'),

    ('H2', '8.1 Manual Backup'),
    ('CODE',
     'docker exec hris_db pg_dump -U hris_admin -d hris_db --format=custom \\\n'
     '  --file=/tmp/hcm360_backup.dump\n'
     'docker cp hris_db:/tmp/hcm360_backup.dump ./backups/hcm360_$(date +%Y%m%d).dump'),

    ('H2', '8.2 Scheduled Backup (cron)'),
    ('CODE',
     '# Add to host crontab\n'
     '0 2 * * * cd /opt/hcm360 && docker exec hris_db pg_dump -U hris_admin \\\n'
     '         -d hris_db --format=custom --file=/tmp/backup.dump \\\n'
     '         && docker cp hris_db:/tmp/backup.dump \\\n'
     '            /opt/hcm360/backups/hcm360_$(date +\\%Y\\%m\\%d).dump'),

    ('H2', '8.3 Restore'),
    ('CODE',
     './scripts/restore_v1.sh backups/hcm360_v1.0_20260412.dump'),

    ('H1', '9. Monitoring & Logs'),
    ('TABLE', ['Command', 'Purpose'],
     [
        ['docker compose ps', 'Show container status'],
        ['docker compose logs -f hris_web', 'Tail web logs'],
        ['docker compose logs -f hris_db', 'Tail DB logs'],
        ['docker exec hris_db psql -U hris_admin -d hris_db', 'Interactive psql shell'],
        ['docker stats', 'Live CPU/memory per container'],
     ]),

    ('H1', '10. Production Hardening Checklist'),
    ('UL', [
        'Change POSTGRES_PASSWORD and SECRET_KEY to strong unique values',
        'Put the web behind a reverse proxy (nginx / Caddy) with TLS',
        'Restrict 5440 (DB port) to localhost only — do not expose publicly',
        'Enable automated off-site backups (daily pg_dump + S3 sync)',
        'Set up log shipping (Loki / CloudWatch / Datadog)',
        'Configure SMTP for notification emails',
        'Review and tighten access matrix at /admin/access-matrix',
        'Review field privacy rules at /admin/privacy',
        'Audit user list and disable default demo users (superadmin, hradmin, etc.)',
        'Replace ANTHROPIC_API_KEY with a production key if AI features are enabled',
     ]),

    ('H1', '11. Troubleshooting'),
    ('TABLE', ['Symptom', 'Likely Cause', 'Resolution'],
     [
        ['403 Forbidden on valid URL', 'Access matrix denies role', 'Add role to core.role_page_access for the page'],
        ['Login page loops', 'Session cookie domain mismatch', 'Check SECRET_KEY is stable and domain matches'],
        ['Empty dropdowns', 'Reference data missing', 'Run seed files 17_seed_core.sql and 18_seed_modules.sql'],
        ['PDF download fails', 'reporting_service missing font', 'Verify ReportLab install in hris_web container'],
        ['DB container won’t start', 'Volume corrupted', 'Restore from latest backup using scripts/restore_v1.sh'],
        ['Slow pages', 'Missing index', 'EXPLAIN ANALYZE the slow query and add index'],
     ]),

    ('H1', '12. Uninstalling'),
    ('P', 'To completely remove HCM360 including all data:'),
    ('CODE',
     'docker compose down -v                      # stop + remove volumes\n'
     'docker image rm hcm360-hris_web:v1.0 \\\n'
     '                 hcm360-payroll_web:v1.0 \\\n'
     '                 postgres:15\n'
     'rm -rf /opt/hcm360'),
]
