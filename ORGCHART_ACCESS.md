# Organization Chart Access & Clickability Rules

## Overview
The organization chart (`/orgchart/`) shows employees their position in the organizational hierarchy with full privacy controls and click restrictions.

---

## Access Rules

### Who Can Access the Org Chart?

| Role | Access | View |
|------|--------|------|
| **SUPER_ADMIN** | ✅ Full | Full company-wide tree |
| **HR_ADMIN** | ✅ Full | Full company-wide tree |
| **MANAGER** | ✅ Limited | Own org + ancestor chain + team |
| **EMPLOYEE** | ✅ Limited | Own org + ancestor chain + team |
| **Not logged in** | ❌ Denied | Redirected to `/login` |

---

## Node Types & Clickability

### 1. **Ancestor Nodes** (CEO → Your Manager)
- **Style**: Gray card with 🔒 lock badge
- **Visibility**: Name, position, department only
- **Salary Grade**: Hidden
- **Clickable**: ❌ **Disabled** — Locked, non-interactive
- **Purpose**: Show reporting chain for context only

### 2. **Self Node** (You)
- **Style**: Amber card with "YOU" badge
- **Visibility**: Full data (name, position, department, photo)
- **Salary Grade**: Hidden (never visible to self)
- **Clickable**: ✅ **YES** — Click to open `/me/profile`
- **Direct Reports Badge**: Shows count of subordinates

### 3. **Team Member Nodes** (Your Direct Reports & Their Subordinates)
- **Style**: Blue card (standard)
- **Visibility**: Full data (name, position, department, photo, direct reports count)
- **Salary Grade**: Hidden (privacy masked)
- **Clickable**: ✅ **Enabled** — Click to view employee detail
- **Navigation**: Takes you to `/employees/<employee_id>`

### 4. **Other Department Members** (Non-Admin Users)
- **Visibility**: ❌ Not shown in scoped tree
- **Clickable**: N/A
- **To View**: Non-admins must request access or contact HR for other departments

---

## Example Scenario

**Login as Manager James (ID: 50, Engineering Dept)**

Organization Structure:
```
CEO Alice (ID: 1)
└─ VP Engineering Bob (ID: 25)
   └─ Manager James (ID: 50)    ← You are here
      ├─ Dev Lead Sarah (ID: 51)
      │  ├─ Junior Dev Tom (ID: 52)
      │  └─ Junior Dev Maya (ID: 53)
      └─ QA Lead Chris (ID: 54)
         └─ QA Engineer Dave (ID: 55)
```

**What James sees on `/orgchart/`:**

```
[ANCESTOR] Alice (Gray Card, 🔒 Locked)
    ↓
[ANCESTOR] Bob (Gray Card, 🔒 Locked)
    ↓
[SELF] James (Amber Card, "YOU", Shows 2 direct reports)
    ├─ [CLICKABLE] Sarah (Blue Card, Shows 2 direct reports) ← Can click
    │  ├─ [CLICKABLE] Tom (Blue Card) ← Can click
    │  └─ [CLICKABLE] Maya (Blue Card) ← Can click
    └─ [CLICKABLE] Chris (Blue Card, Shows 1 direct report) ← Can click
       └─ [CLICKABLE] Dave (Blue Card) ← Can click
```

**Interaction Rules for James:**
- Click Alice → ❌ Disabled (ancestor lock)
- Click Bob → ❌ Disabled (ancestor lock)
- Click James (self) → ✅ Opens `/me/profile`
- Click Sarah → ✅ Opens `/employees/51`
- Click Tom → ✅ Opens `/employees/52`
- Click anyone in team → ✅ Opens their profile

---

## Privacy Masking on Team Members

Even though team members are clickable and fully visible, certain fields are masked:

| Field | Visible to Team Members | Notes |
|-------|---|---|
| Name | ✅ Yes | Required for org chart |
| Position | ✅ Yes | Required for org chart |
| Department | ✅ Yes | Required for org chart |
| Photo | ✅ Yes | Avatar in org chart |
| Direct Reports Count | ✅ Yes | Badge shown |
| Salary Grade | ❌ No | Always hidden from non-admins |
| Basic Salary | ❌ No | Privacy rule: HIDDEN for EMPLOYEE role |
| Date of Birth | ❌ No | Privacy rule: MASKED for EMPLOYEE role |

---

## Technical Implementation

### Clickability Logic (Jinja2 Template)

```jinja2
{% set can_view = (viewable_ids is none) or (person.id in viewable_ids) %}
{% set can_click = can_view and not is_ancestor %}

{% if can_click %}
  <a href="/employees/{{ person.id }}" class="oc-card oc-clickable">
{% else %}
  <div class="oc-card">
{% endif %}
```

**Decision Tree:**
1. **can_view**: Is this node in the viewer's scope? (admins can view all, employees can view ancestors + self + team)
2. **can_click**: Can we click it? = can_view AND NOT ancestor
3. **Result**:
   - `can_click=true` → Render as `<a>` link
   - `can_click=false` → Render as `<div>` (non-interactive)

### viewable_ids Set

Built by the route handler:
```python
# For non-admin employees
viewable_ids = get_subordinate_ids(my_emp_id) | {my_emp_id}

# For admins
viewable_ids = None  # (None means "all are viewable")
```

**get_subordinate_ids()**: PostgreSQL recursive CTE that returns all descendants (full downline)

---

## Department-Scoped Org Chart

**New route:** `GET /orgchart/department/<id>/chart`

### Access Rules:
- **SUPER_ADMIN / HR_ADMIN**: Can view any department's org chart
- **EMPLOYEE**: Can only view their own department's org chart
- **Attempting other department**: Returns 403 Forbidden + error message

### Example:
- As employee in Marketing, try `/orgchart/department/5/chart` (Engineering) → 403
- As employee in Engineering, try `/orgchart/department/5/chart` (Engineering) → ✅ Allowed

---

## Privacy Controls Applied

1. **Ancestor Nodes**: Non-clickable, name/position only
2. **Salary Grades**: Hidden from all non-admin users (even for own record)
3. **Sensitive Fields**: Masked per `core.field_privacy_rules` (date_of_birth, bank accounts, etc.)
4. **Department Scope**: Non-admins restricted to own department only
5. **Visual Lock Badge**: 🔒 indicator on restricted ancestor cards

---

## Testing Access & Clickability

### Test Case 1: Employee Self-Service View
```
Login as EMPLOYEE (e.g., John, ID: 100)
Navigate to /orgchart/
Expected:
  - See CEO, VP, Manager, Self, Team
  - Ancestors are gray & locked
  - Self is amber & not clickable
  - Team members are blue & clickable
```

### Test Case 2: Manager View
```
Login as MANAGER (e.g., Sarah, ID: 50)
Navigate to /orgchart/
Expected:
  - See full ancestor chain above
  - Self highlighted in amber
  - All direct reports and their teams clickable
  - Salary grades hidden from all nodes
```

### Test Case 3: Admin Full Access
```
Login as SUPER_ADMIN
Navigate to /orgchart/
Expected:
  - Full company tree visible
  - All non-root nodes clickable
  - All fields unmasked (salary grades visible)
  - No ancestor locks (no one is truly an "ancestor" in admin view)
```

### Test Case 4: Department Scope Denial
```
Login as EMPLOYEE in Engineering
Navigate to /orgchart/department/3/chart (HR department)
Expected:
  - 403 Forbidden error
  - Flash message: "Access denied. You can only view your own department's org chart."
  - Redirect to /orgchart/
```

---

## Common Issues & Fixes

### Issue: Ancestor nodes are clickable
**Cause**: Template uses `can_view` instead of `can_click`
**Fix**: Ensure template uses:
```jinja2
{% set can_click = can_view and not is_ancestor %}
{% if can_click %}<a ...>{% else %}<div>{% endif %}
```

### Issue: Salary grades visible to employees
**Cause**: Privacy rules not applied or field not masked
**Fix**: Check `field_privacy_rules` table has EMPLOYEE salary_grade rules set to HIDDEN

### Issue: Employee can see other departments
**Cause**: No department scope validation on routes
**Fix**: Use `get_department_org_tree()` with role validation

### Issue: Self node is clickable
**Cause**: `can_click` is checking `can_view` but not `is_self`
**Fix**: Modify template: `{% set can_click = can_view and not is_ancestor and not is_self %}`

---

## Related Resources

- **File**: `/templates/orgchart/chart.html` — Card rendering with clickability logic
- **File**: `/modules/orgchart/routes.py` — Route handlers with access control
- **File**: `/modules/orgchart/orgchart_service.py` — Privacy-aware tree builders
- **Table**: `core.field_privacy_rules` — Field masking configuration
- **Table**: `core.employees` — `immediate_supervisor_id` FK (reporting chain)
- **Table**: `core.departments` — `parent_id` FK (org structure)
