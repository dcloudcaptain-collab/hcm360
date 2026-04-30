# HCM360 — Role Authority Matrix

Industry-standard role taxonomy with no overlapping ownership. Each HR-Operations role owns a single vertical so two officers can never collide on the same activity.

## Role taxonomy

| Tier | Role code | Display name | Data scope | Owns |
|------|-----------|--------------|-----------:|------|
| 1 — Workforce | `EMPLOYEE` | Employee | **Self + own department (read-only directory)** | Own profile, own requests (leave, OT, certificates, exit), own DTR, own payslips, own learning |
| 1 — Workforce | `MANAGER` | Line Manager | **Direct + indirect reports** | Approve team requests, team analytics, team performance reviews |
| 1 — Workforce | `EXECUTIVE` | Department/Division Head | **Department-wide** | Read department data, sign-off on dept-level decisions, dept-scoped analytics |
| 2 — HR Operations | `HR_RECRUITER` | HR — Recruitment Officer | All employees | RSP (Plantilla, Vacancies, Applicants, PSB, Requisitions, Appointments, Next-in-Rank, Onboarding, Offboarding) |
| 2 — HR Operations | `HR_TIME_OFFICER` | HR — Time & Attendance Officer | All employees | Time & Attendance (DTR, Overtime, Shifts, Alerts, Check-in), Leave & Absence (requests, balances, CTO, locator, travel orders, CS Form 6) |
| 2 — HR Operations | `HR_COMP_OFFICER` | HR — Compensation Officer | All employees | Compensation & Rewards (SSL, Step Increments, Loyalty, PBB, Retirement, Nominations) |
| 2 — HR Operations | `HR_LEARNING_OFFICER` | HR — Learning Officer | All employees | L&D (Programs, Sessions, TNA, Scholarships, NRF, Attendance) |
| 2 — HR Operations | `HR_PERFORMANCE_OFFICER` | HR — Performance Officer | All employees | Performance (Cycles, OPCR, IPCR, Ratings, Succession, IPCR Templates) |
| 2 — HR Operations | `HR_RELATIONS_OFFICER` | HR — Employee Relations Officer | All employees | Discipline (cases) + Health & Safety (PE, certificates, incidents, wellness) |
| 2 — HR Operations | `HR_RECORDS_OFFICER` | HR — Records Officer | All employees | Employee Records (PDS, SALN admin, Contracts, DMS checklist, retention, certificate queue) |
| 3 — HR Leadership | `HR_MANAGER` (alias `HR_ADMIN`) | HR Manager / HR Director | All employees | Everything Tier 2 covers + Analytics admin + Insights Library; **read-only** view of Access Matrix |
| 4 — Finance | `PAYROLL_OFFICER` | Payroll Officer | All employees | Payroll runs, Loans (read T&A and Comp; **no** HR module write) |
| 5 — System | `IT_ADMIN` | IT / System Administrator | N/A — config only | All `/admin/*`, branding, themes, workflow engine, access matrix toggle, demo data; **NO** employee data write |
| 5 — System | `SUPER_ADMIN` | Super Admin | All | Unrestricted |

## RACI principle: each HR vertical has exactly one owner

| Vertical | Owner role | Backup (read-only) |
|----------|-----------|---------------------|
| Recruitment & Onboarding | HR_RECRUITER | HR_MANAGER |
| Time & Attendance | HR_TIME_OFFICER | HR_MANAGER, PAYROLL_OFFICER (read) |
| Leave & Absence | HR_TIME_OFFICER | HR_MANAGER, PAYROLL_OFFICER (read) |
| Compensation & Rewards | HR_COMP_OFFICER | HR_MANAGER, PAYROLL_OFFICER (read) |
| Learning & Development | HR_LEARNING_OFFICER | HR_MANAGER |
| Performance | HR_PERFORMANCE_OFFICER | HR_MANAGER, MANAGER (own team only) |
| Employee Relations (Discipline + Health) | HR_RELATIONS_OFFICER | HR_MANAGER |
| Employee Records (201 File) | HR_RECORDS_OFFICER | HR_MANAGER |
| Payroll | PAYROLL_OFFICER | (none) |
| System Administration | IT_ADMIN | SUPER_ADMIN |
| Analytics & Reports | HR_MANAGER | All HR-Ops roles get module-scoped read |

## Data-scope rules (row-level visibility)

`core.roles.data_scope` ∈ `{SELF, DEPARTMENT, REPORTS, ALL}`:

- `SELF` — only the user's own employee record (`/me/*` is fine; `/employees` shows just the user + own-department directory).
- `DEPARTMENT` — all employees in the user's `department_id` (via `core.employees.department_id`). EXECUTIVE, EMPLOYEE-on-/employees.
- `REPORTS` — recursive direct reports via `immediate_supervisor_id`. MANAGER.
- `ALL` — no row filter. HR-Ops, HR_MANAGER, PAYROLL_OFFICER, IT_ADMIN, SUPER_ADMIN.

The helper `services.access_service.get_employee_scope_filter(role_code, user_id)` returns either:
- `(allowed_emp_ids: list[int])` — restrict the query, or
- `None` — no filter (full access).

It's applied at the route level for any list/search of employees (`/employees`, `/api/employees/search`, `/employees/<id>` detail page when accessed via list).

## Module × Role matrix (CAN_ACCESS)

✓ = full access · ◐ = read-only · ✗ = no access

| Module | EMP | MGR | EXEC | RECR | TIME | COMP | LRN | PERF | RELN | RCDS | HRMGR | PAYR | ITAD | SUPER |
|--------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Home & Core | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| My Workspace (ESS/MSS) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Employee Records (DMS) | ◐ | ◐ | ◐ | ◐ | ✗ | ◐ | ✗ | ◐ | ✗ | ✓ | ✓ | ◐ | ✗ | ✓ |
| Time & Attendance | ◐ | ✓ | ◐ | ✗ | ✓ | ◐ | ✗ | ✗ | ✗ | ✗ | ✓ | ◐ | ✗ | ✓ |
| Leave & Absence | ◐ | ✓ | ◐ | ✗ | ✓ | ◐ | ✗ | ✗ | ✗ | ✗ | ✓ | ◐ | ✗ | ✓ |
| Recruitment & Onboarding | ✗ | ✗ | ◐ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ | ✓ |
| Performance | ◐ | ◐ | ◐ | ✗ | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ | ✓ | ✗ | ✗ | ✓ |
| Learning & Development | ◐ | ✓ | ◐ | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ | ✓ |
| Compensation & Rewards | ✗ | ◐ | ◐ | ✗ | ✗ | ✓ | ✗ | ✗ | ✗ | ✗ | ✓ | ◐ | ✗ | ✓ |
| Payroll | ✗ | ◐ | ◐ | ✗ | ✗ | ◐ | ✗ | ✗ | ✗ | ✗ | ◐ | ✓ | ✗ | ✓ |
| Health & Safety | ◐ | ◐ | ◐ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ | ✗ | ✓ | ✗ | ✗ | ✓ |
| Employee Relations (Discipline) | ✗ | ◐ | ◐ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ | ✗ | ✓ | ✗ | ✗ | ✓ |
| Workforce Planning | ✗ | ◐ | ◐ | ◐ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ | ✓ |
| Analytics & Reports | ◐ | ◐ | ◐ | ◐ | ◐ | ◐ | ◐ | ◐ | ◐ | ◐ | ✓ | ◐ | ✗ | ✓ |
| AI Assistants | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Administration | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ◐ | ✓ | ✓ | ✓ |

Read-only (◐) is enforced at the feature/action level — page is visible, write actions disabled.

## Migration & verification

- `db/78_role_taxonomy.sql` — defines the 9 new roles, adds `core.roles.data_scope` column, populates `core.role_page_access` for each new role per the matrix above.
- `services/access_service.py` — adds `get_employee_scope_filter(role_code, user_id)`.
- `modules/employees/routes.py` — applies the scope filter to the main `/employees` query.
- Smoke tests:
  - Log in as `HR_RECRUITER`: only RSP module pages return 200; T&A/Compensation/Discipline return 403.
  - Log in as `EMPLOYEE`: `/employees` returns 200 but list contains only employees in own department (+ self).
  - Log in as `MANAGER`: `/employees` returns 200 with direct + indirect reports.
