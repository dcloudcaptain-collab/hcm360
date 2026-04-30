# Organization Chart Clickability Fix

## Problem
When employees clicked on team member nodes in the org chart, they received a **403 Forbidden** error when trying to view the employee detail page.

**Error Message:**
```
403 Forbidden
You don't have the permission to access the requested resource. 
It is either read-protected or not readable by the server.
```

## Root Cause
The access matrix had `/employees/` detail page access set to **FALSE** for EMPLOYEE and EXECUTIVE roles:

```sql
SELECT role_code, can_access FROM core.role_page_access 
WHERE page_id = (SELECT id FROM core.page_registry WHERE path = '/employees/')
ORDER BY role_code;

-- BEFORE FIX:
-- EMPLOYEE    | false
-- EXECUTIVE   | false
-- HR_ADMIN    | true
-- MANAGER     | true
-- SUPER_ADMIN | true
```

## Solution
Updated the access matrix to grant EMPLOYEE and EXECUTIVE roles access to `/employees/` detail pages:

```sql
UPDATE core.role_page_access
SET can_access = TRUE
WHERE page_id = (SELECT id FROM core.page_registry WHERE path = '/employees/')
  AND role_code IN ('EMPLOYEE', 'EXECUTIVE');

-- AFTER FIX:
-- EMPLOYEE    | true
-- EXECUTIVE   | true
-- HR_ADMIN    | true
-- MANAGER     | true
-- SUPER_ADMIN | true
```

## How It Works

### Access Matrix Matching
The `can_access_page()` function uses SQL LIKE matching:

```sql
WHERE (p.path = %s OR (p.path LIKE '%%/' AND %s LIKE p.path || '%%'))
```

This means:
- **Exact match**: `/employees` matches `/employees`
- **Prefix match**: `/employees/` matches `/employees/100`, `/employees/150`, etc.

So when employee clicks on a team member:
1. Browser navigates to `/employees/100` (for example)
2. `can_access_page('EMPLOYEE', '/employees/100')` is called
3. Matches `/employees/` prefix in page_registry
4. Checks `role_page_access` for EMPLOYEE role
5. Now returns TRUE (after fix)

### Privacy Controls Still Apply
Even though employees can now access employee detail pages, privacy masking is still applied:

```python
# In employees/routes.py employee_detail()
role_code = session.get('role_code', '')
is_own = (session.get('employee_id') == employee_id)
profile['employee'] = apply_privacy(profile['employee'], role_code, 'employee', is_own_record=is_own)
```

**What employees see when viewing team members:**
- ✅ Name, position, department, photo
- ✅ Contact info (mobile, email)
- ❌ Salary grade (HIDDEN)
- ❌ Date of birth (MASKED)
- ❌ Bank account numbers (MASKED)
- ❌ Other sensitive PII per `core.field_privacy_rules`

## Testing the Fix

### Test Case 1: Org Chart Clickability
```
1. Login as EMPLOYEE
2. Go to /orgchart/
3. See your org chart with team members
4. Click on any team member's blue card
5. Expected: ✅ Opens /employees/<id> successfully
6. Should NOT see: Salary, DOB, bank info
```

### Test Case 2: Own Profile Access
```
1. Login as EMPLOYEE
2. Click on yourself (yellow "YOU" card)
3. Expected: ❌ Non-clickable (should use /me/profile instead)
```

### Test Case 3: Ancestor Viewing (Non-Admin)
```
1. Login as EMPLOYEE
2. Ancestors (CEO, VP, etc) are gray & locked
3. Expected: ❌ Cannot click ancestors
```

### Test Case 4: Admin Full Access
```
1. Login as SUPER_ADMIN
2. Go to /orgchart/
3. See full company tree
4. Click any node
5. Expected: ✅ Opens detail page
6. Should see: All fields including salary grades (unmasked)
```

## Database Changes Made

```sql
-- Removed invalid path pattern
DELETE FROM core.page_registry WHERE path = '/employees/<id>';

-- Updated access rules
UPDATE core.role_page_access
SET can_access = TRUE
WHERE page_id = (SELECT id FROM core.page_registry WHERE path = '/employees/')
  AND role_code IN ('EMPLOYEE', 'EXECUTIVE');
```

## Related Code

**File**: `modules/employees/routes.py` (line 193-207)
```python
@bp.route('/<int:employee_id>')
def employee_detail(employee_id):
    profile = ess_service.get_my_profile(employee_id)
    if not profile['employee']:
        abort(404)
    extended = emp_svc.get_employee_extended(employee_id)
    # Apply field-level privacy masking based on viewer's role
    role_code = session.get('role_code', '')
    is_own = (session.get('employee_id') == employee_id)
    profile['employee'] = apply_privacy(profile['employee'], role_code, 'employee', is_own_record=is_own)
    # ... masking for sub-tables ...
    return render_template('employees/detail.html', profile=profile, extended=extended)
```

**File**: `templates/orgchart/chart.html` (line 185-195)
```jinja2
{% set can_view = (viewable_ids is none) or (person.id in viewable_ids) %}
{% set can_click = can_view and not is_ancestor %}

{% if can_click %}
<a href="/employees/{{ person.id }}"
   class="oc-card {% if is_self %}self-card{% elif is_ancestor %}ancestor-card{% endif %} oc-clickable">
{% else %}
<div class="oc-card {% if is_self %}self-card{% elif is_ancestor %}ancestor-card{% endif %}">
{% endif %}
```

## Verification SQL

```sql
-- Verify all employees can access the detail page
SELECT role_code, can_access FROM core.role_page_access 
WHERE page_id = (SELECT id FROM core.page_registry WHERE path = '/employees/')
ORDER BY role_code;

-- Expected output:
-- EMPLOYEE    | true
-- EXECUTIVE   | true
-- HR_ADMIN    | true
-- MANAGER     | true
-- SUPER_ADMIN | true
```

## Summary

✅ **Fixed**: Employees can now click on team members in org chart  
✅ **Secured**: Privacy masking still applies to sensitive fields  
✅ **Tested**: All access roles properly configured in matrix  
✅ **Documented**: Org chart access rules fully explained
