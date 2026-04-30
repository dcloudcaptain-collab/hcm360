# HCM360 HRIS Changelog

## v1.0.0 — 2026-04-12 (Frozen Build)

### Core HR
- Employee master with 20+ demo profiles
- Department and position hierarchy
- Job grades and employment types
- Multi-company (tenant) architecture

### Self-Service (ESS/MSS)
- My Portal dashboard with KPI cards (attendance, leave, compensation, inbox, benefits)
- My Profile page with beautified card layout, section badges, quick-nav pills
- Self-service sub-forms: addresses, emergency contacts, government IDs, bank accounts, dependents
- Empty-state "Add one" links for missing records
- Manager self-service: team view, team attendance, team approvals

### Attendance & DTR
- Daily time records with clock in/out
- Late, absent, overtime tracking
- Shift schedules and shift assignments
- Attendance alerts
- Admin overrides with audit trail

### Leave Management
- 10+ leave types (RA 11210, RA 8187, RA 8972, RA 9262, RA 9710 compliant)
- Leave request workflow with approval chain
- Leave balance tracking with accrual and carry-over
- Holiday calendar (Philippine holidays)

### Payroll
- Pay period and pay run management
- Government deductions: SSS, PhilHealth, Pag-IBIG, withholding tax
- Allowances: PERA, RATA, ACA, hazard pay
- Payslip generation and PDF export
- Loan management
- Standalone payroll microservice (port 8095)

### Recruitment (RSP)
- Requisition management
- Candidate tracking
- CSC eligibilities and qualification standards

### Performance Management
- KPI and competency-based evaluations
- Review cycles and calibration

### Learning & Development
- Training management and certifications tracking

### Rewards & Recognition
- Award categories and praise configuration

### Document Management (201 File)
- Employee document uploads
- Certificate requests and generation
- Retention policies
- Document categories

### Discipline
- Case management with gravity levels
- Legal basis tracking (Philippine labor law)

### Health & Safety
- Incident tracking and reporting

### Organization Chart
- Interactive person-centric org chart
- Privacy-controlled node visibility
- Department-scoped access for non-admin roles
- Clickable nodes: self -> /me/profile, team -> /employees/<id>, ancestors locked

### Data Privacy (RA 10173)
- Field-level privacy masking: VISIBLE / MASKED / HIDDEN
- Role-based visibility rules per section
- Admin UI at /admin/privacy for SUPER_ADMIN
- Sensitive fields: salary, DOB, government IDs, bank accounts
- Own-record relaxation (employees see own contact info, never own salary)

### Workforce Planning
- Scenario modeling (headcount, cost projections)
- Skill demand/supply gap analysis
- Access matrix registered for SUPER_ADMIN, HR_ADMIN, EXECUTIVE

### Analytics & Reports
- Dashboard metrics with drill-down
- HR demographics reports
- Report builder
- KPI SQL query registry

### AI / ARIA
- AI-powered HR assistant integration

### Administration
- Access matrix (page-level + feature-level + modification-level)
- Role management with custom role creation
- User management
- Reference data CRUD (29+ tables)
- UI theme activation
- Status definitions per module
- Demo data profiles
- Reminder rules
- Service monitoring

### Security & Access Control
- Session-based authentication with user selector (POC mode)
- SSO token support (JWT)
- Three-tier RBAC: page -> feature/action -> modification access
- SUPER_ADMIN bypass, HR_ADMIN operational access
- LIKE-based path matching for dynamic routes

### Infrastructure
- Docker Compose: hris_web (8093), payroll_web (8095), hris_db (5440)
- Named volumes for DB and uploads (survive rebuilds)
- PostgreSQL 15 with optimized settings
- Python 3.11 / Flask
- Jinja2 templates with inline CSS design system

---

### Backup
- Full dump: `backups/hcm360_v1.0_20260412.dump`
- Schema only: `backups/hcm360_v1.0_schema.sql`
- Restore: `pg_restore -U hris_admin -d hris_db backups/hcm360_v1.0_20260412.dump`
