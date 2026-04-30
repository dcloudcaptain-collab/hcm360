# HCM360 — HR Validation Rules

Industry-standard, two-level bypassable validation framework patterned after Workday and SAP SuccessFactors.

## How the bypass works

1. **Master switch** — `core.validation_settings.master_enforce`
   - `TRUE` (default): each rule's individual `is_enforced` toggle decides whether failures block the save.
   - `FALSE`: every rule degrades to a **warning**. Forms accept invalid data with a soft notice instead of blocking the save.
2. **Per-rule toggle** — `core.validation_rules.is_enforced`
   - `TRUE` (default): rule blocks save when its check fails (severity = `ERROR`).
   - `FALSE`: rule still runs but emits a warning only (save proceeds).

## Who can change it

The toggle UI at **`/admin/validations`** is restricted to `SUPER_ADMIN` and `IT_ADMIN`.
`HR_MANAGER` and `HR_ADMIN` get a read-only view.

## How to invoke from any form

```python
from services import validation_service

result = validation_service.validate('EMPLOYEE', form_data)   # category-driven
if validation_service.has_blockers(result):
    # result['errors'] is a list of {rule_code, label, message, severity}
    # — forms typically flash each, OR raise to the route handler.
    raise validation_service.ValidationBlocked(result)        # employee_service style
```

For inline / client-side checks: POST `/api/v1/validations/check` with body
`{"category": "EMPLOYEE", "payload": {...}}`. Response: `{"errors":[...], "warnings":[...], "master_enforce": bool}`.

## Currently wired forms

| Form / write path | Category | Enforced at |
|---|---|---|
| `POST /employees/new` | EMPLOYEE | `services/employee_service.create_employee()` |
| `POST /employees/<id>/edit` | EMPLOYEE | `services/employee_service.update_employee()` |
| `POST /leave/requests/new` | LEAVE | `modules/leave/leave_service.submit_request()` |
| Admin DTR override | DTR | `modules/attendance/attendance_service.admin_override_dtr()` |
| Compensation forms | COMPENSATION | (infrastructure ready — wire per route) |

## Rule catalogue (25 rules)

### EMPLOYEE — 12 rules

| Code | Severity | Rule |
|------|----------|------|
| E001 | ERROR | First name required |
| E002 | ERROR | Last name required |
| E003 | ERROR | Employee number required |
| E004 | ERROR | Employee number unique within company |
| E005 | ERROR | Hire date required |
| E006 | ERROR | Hire date not in the future |
| E007 | ERROR | Date of birth not in the future |
| E008 | ERROR | Minimum age 15 (PH Labor Code) |
| E009 | ERROR | Email format valid |
| E010 | WARN  | Mobile number matches PH format (`+63XXXXXXXXXX` or `09XXXXXXXXX`) |
| E011 | ERROR | Immediate supervisor cannot be self |
| E012 | ERROR | Termination date ≥ hire date |

### LEAVE — 5 rules

| Code | Severity | Rule |
|------|----------|------|
| L001 | ERROR | Start date ≤ end date |
| L002 | ERROR | Sufficient leave balance |
| L003 | ERROR | No overlap with already-approved leave |
| L004 | WARN  | Not retroactive (start date ≥ today) |
| L005 | WARN  | Range includes at least one working day |

### DTR — 4 rules

| Code | Severity | Rule |
|------|----------|------|
| T001 | ERROR | Time-in earlier than time-out |
| T002 | ERROR | Total worked hours ≤ 24 |
| T003 | ERROR | Pay period must be open (un-locked) |
| T004 | ERROR | Shift assignments must not overlap |

### COMPENSATION — 4 rules

| Code | Severity | Rule |
|------|----------|------|
| C001 | ERROR | Step increment requires 3 years tenure |
| C002 | ERROR | Salary within job-grade band |
| C003 | ERROR | Loan amount ≤ allowable maximum (default 6× monthly salary) |
| C004 | WARN  | Effective date not in the past (unless retroactive) |

## Adding a new rule

1. Insert a row into `core.validation_rules` (or extend `db/79_validation_rules.sql`).
2. Add a `_check_<rule_code>` function in `services/validation_service.py` and register it in the `_CHECKS` dict.
3. Done — every form using `validation_service.validate('<CATEGORY>', payload)` automatically picks it up.
