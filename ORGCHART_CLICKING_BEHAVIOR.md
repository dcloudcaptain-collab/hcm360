# Organization Chart Clicking Behavior

## Summary

| Node Type | Style | Clickable | Destination |
|---|---|---|---|
| **Ancestors** (CEO → Manager) | Gray with 🔒 | ❌ No | — |
| **Self** (You) | Amber with "YOU" | ✅ Yes | `/me/profile` |
| **Team Members** (Your Reports) | Blue | ✅ Yes | `/employees/<id>` |
| **Other Departments** | Not shown | N/A | N/A |

---

## Detailed Behavior

### 1. Ancestor Nodes → ❌ Disabled (Gray, Locked)

**Visual:**
```
[CEO Alice]  ← Gray card, 🔒 lock badge, non-clickable
     ↓
[VP Bob]     ← Gray card, 🔒 lock badge, non-clickable
     ↓
```

**Clicking behavior:** No link, cursor stays normal, nothing happens
**Purpose:** Show reporting chain for context, prevent access to senior management details

---

### 2. Self Node → ✅ Enabled (Amber, "YOU" Badge)

**Visual:**
```
[Manager James]  ← Amber border, "YOU" badge, blue text, CLICKABLE
  📊 2 reports
```

**Clicking behavior:** Opens `/me/profile`
**Purpose:** Quick link to your own profile/dashboard
**Data shown on profile:** Full employee data (name, position, department, contact info)
**Data hidden:** Salary, salary grade (even on own profile)

**Template logic:**
```jinja2
{% if is_self %}
  <a href="/me/profile" class="oc-card self-card oc-clickable">
{% endif %}
```

---

### 3. Team Member Nodes → ✅ Enabled (Blue)

**Visual:**
```
├─ [Sarah - Dev Lead]    ← Blue card, CLICKABLE
│  📊 2 reports
├─ [Tom - Junior Dev]    ← Blue card, CLICKABLE
│  📊 0 reports
└─ [Chris - QA Lead]     ← Blue card, CLICKABLE
   📊 1 report
```

**Clicking behavior:** Opens `/employees/<id>`
**Purpose:** View team member details with privacy controls applied
**Data shown on detail page:**
- ✅ Name, position, department, photo
- ✅ Contact info (email, mobile)
- ✅ Direct reports count
- ❌ Salary grade (HIDDEN)
- ❌ Date of birth (MASKED)
- ❌ Bank account numbers (MASKED)

**Template logic:**
```jinja2
{% if not is_ancestor %}
  <a href="/employees/{{ person.id }}" class="oc-card oc-clickable">
{% endif %}
```

---

## Complete Decision Tree

```
Employee views /orgchart/
├─ Can they VIEW this node?
│  └─ YES → Continue to next check
│  └─ NO → Don't render node
│
└─ Is this node an ANCESTOR?
   ├─ YES → Render as gray <div> (NON-CLICKABLE)
   │
   └─ NO → Render as colored <a> link (CLICKABLE)
      ├─ If is_self → href="/me/profile"
      └─ Else → href="/employees/<id>"
```

**Template Implementation:**
```jinja2
{% set can_view = (viewable_ids is none) or (person.id in viewable_ids) %}
{% set can_click = can_view and (not is_ancestor) %}

{% if can_click %}
  <a href="{% if is_self %}/me/profile{% else %}/employees/{{ person.id }}{% endif %}"
     class="oc-card oc-clickable">
{% else %}
  <div class="oc-card">
{% endif %}
```

---

## Privacy Controls

Even when employees can click to view details, privacy masking applies:

### Self Profile (`/me/profile`)
- ✅ Visible: All personal data (name, address, contacts, documents)
- ❌ Hidden: Salary, salary grade, compensation data

### Team Member Profile (`/employees/<id>`)
- ✅ Visible: Name, position, department, photo
- ❌ Hidden: Salary grade (always hidden from non-admins)
- ❌ Masked: Date of birth → `****-**-**`
- ❌ Masked: Bank account numbers → `****-****-****`
- ❌ Masked: Government ID numbers → `***-****-***`

**Privacy rules** are configured in `core.field_privacy_rules` per role:
```sql
SELECT section, field_name, role_code, visibility 
FROM core.field_privacy_rules 
WHERE role_code = 'EMPLOYEE'
ORDER BY section;

-- Example results:
-- employee | date_of_birth | EMPLOYEE | MASKED
-- employee | basic_salary  | EMPLOYEE | HIDDEN
-- government_id | id_number | EMPLOYEE | MASKED
-- bank_account | account_number | EMPLOYEE | MASKED
```

---

## Examples

### Example 1: Manager Viewing Team

**Login:** Manager Sarah (ID: 50)
**Action:** View org chart at `/orgchart/`

**Sarah's org chart shows:**
```
[CEO] 🔒 LOCKED
  ↓
[VP Eng] 🔒 LOCKED
  ↓
[YOU - Sarah] ✅ CLICKABLE → /me/profile
  ├─ [Dev Lead Tom] ✅ CLICKABLE → /employees/51
  │  ├─ [Junior John] ✅ CLICKABLE → /employees/52
  │  └─ [Junior Jane] ✅ CLICKABLE → /employees/53
  └─ [QA Lead Chris] ✅ CLICKABLE → /employees/54
     └─ [QA Eng Dave] ✅ CLICKABLE → /employees/55
```

**When Sarah clicks:**
- CEO or VP Eng → ❌ Nothing happens (locked)
- "YOU" (Sarah) → ✅ Opens `/me/profile` showing her full profile
- Tom, John, Jane, Chris, Dave → ✅ Opens their `/employees/<id>` with masked sensitive data

### Example 2: Individual Contributor (No Team)

**Login:** Developer John (ID: 52, no direct reports)
**Action:** View org chart at `/orgchart/`

**John's org chart shows:**
```
[CEO] 🔒 LOCKED
  ↓
[VP Eng] 🔒 LOCKED
  ↓
[Manager Sarah] 🔒 LOCKED
  ↓
[Dev Lead Tom] 🔒 LOCKED
  ↓
[YOU - John] ✅ CLICKABLE → /me/profile
```

**When John clicks:**
- All ancestors → ❌ Locked (CEO, VP, Manager, Lead)
- John (self) → ✅ Opens `/me/profile`
- No team members shown (John has no direct reports)

### Example 3: Admin View

**Login:** SUPER_ADMIN
**Action:** View org chart at `/orgchart/`

**Admin sees:**
```
[CEO] ✅ CLICKABLE → /employees/1
  ├─ [VP Eng] ✅ CLICKABLE → /employees/25
  │  └─ [Manager] ✅ CLICKABLE → /employees/50
  │     └─ [Dev Lead] ✅ CLICKABLE → /employees/51
  │        └─ [Junior] ✅ CLICKABLE → /employees/52
  ├─ [VP HR] ✅ CLICKABLE → /employees/26
  └─ [VP Fin] ✅ CLICKABLE → /employees/27
```

**When admin clicks:**
- **ANY node** → ✅ Opens `/employees/<id>` with **all fields unmasked** (including salary, salary grade, DOB, etc.)

---

## Technical Implementation

### File: `templates/orgchart/chart.html` (Line 183-197)

```jinja2
{% macro render_person(person, is_root, is_ancestor) %}
{% set is_self = person.get('is_self', false) %}
{% set can_view = (viewable_ids is none) or (person.id in viewable_ids) %}
{# Self node and team members are clickable; ancestors are never clickable #}
{% set can_click = can_view and (not is_ancestor) %}

<div class="oc-level" data-person-id="{{ person.id }}">
  {# Card wrapper — clickable if viewable AND not ancestor #}
  {% if can_click %}
  <a href="{% if is_self %}/me/profile{% else %}/employees/{{ person.id }}{% endif %}"
     class="oc-card {% if is_self %}self-card{% elif is_ancestor %}ancestor-card{% elif is_root %}root-card{% endif %} oc-clickable">
  {% else %}
  <div class="oc-card {% if is_self %}self-card{% elif is_ancestor %}ancestor-card{% elif is_root %}root-card{% endif %}">
  {% endif %}
    {# ... card content ... #}
  {% if can_click %}</a>{% else %}</div>{% endif %}
```

### CSS Styling (Line 20-36)

```css
/* SELF — the logged-in employee's card */
.oc-card.self-card {
  border:2px solid #f59e0b;
  background:linear-gradient(135deg,#fffbeb,#fff);
  box-shadow:0 0 0 4px rgba(245,158,11,.15);
}

/* ANCESTOR — nodes above the logged-in employee */
.oc-card.ancestor-card {
  background:#f8fafc;
  border-color:#cbd5e1;
  opacity:.85;
  cursor:default; /* No pointer cursor */
}

/* Clickable card hover state */
.oc-clickable:hover {
  box-shadow:0 4px 16px rgba(59,130,246,.18);
  transform:translateY(-2px);
  border-color:#3b82f6;
}

.oc-card.ancestor-card.oc-clickable:hover {
  /* Ancestors don't get hover effects — they're not clickable */
}
```

---

## Testing Checklist

- [ ] **Employee Self**: Click amber "YOU" card → Opens `/me/profile`
- [ ] **Employee Team**: Click blue team member card → Opens `/employees/<id>` with masked salary
- [ ] **Employee Ancestors**: Try clicking gray ancestor card → Nothing happens, cursor unchanged
- [ ] **Manager View**: All direct reports clickable, ancestors locked
- [ ] **Admin View**: All nodes clickable, all fields unmasked
- [ ] **Salary Grades**: Hidden from employee/manager views, visible to admin
- [ ] **Ancestor Lock Badge**: 🔒 visible and styled on ancestor cards
- [ ] **Hover States**: Blue cards show hover effect, gray cards don't

---

## Summary Table

| User Action | Before Fix | After Fix |
|---|---|---|
| Employee clicks "YOU" | N/A (not clickable) | ✅ Opens `/me/profile` |
| Employee clicks team member | ❌ 403 Forbidden | ✅ Opens `/employees/<id>` |
| Employee clicks ancestor | N/A (not clickable) | ❌ Still locked (correct) |
| Admin clicks any node | ✅ Works, unmasked | ✅ Works, unmasked (no change) |
