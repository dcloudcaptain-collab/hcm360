# Add Role Creation to Access Matrix

## Context
- `core.roles` table exists (id, company_id, code, name, description, is_system_role, is_active)
- Current RBAC uses `role_code` VARCHAR strings in `role_page_access` / `role_feature_access`
- `get_all_roles()` only pulls from `core.users.role_code` — misses roles with no users yet

## Changes

### 1. `services/access_service.py`
- Update `get_all_roles()` to UNION `core.roles.code` with `core.users.role_code` so newly created roles appear even before any user is assigned
- Add `create_role(code, name, description, company_id)` — INSERT into `core.roles`

### 2. `modules/admin/routes.py`
- Add `POST /admin/access-matrix/create-role` endpoint — validates code uniqueness, calls `create_role()`, redirects back to matrix with the new role selected

### 3. `templates/admin/access_matrix.html`
- Add a "+" button next to the role dropdown
- Add a modal: Role Code (auto-uppercased), Display Name, Description (optional)
- On submit POST to the new endpoint
- Modal uses existing card/form styling, no new dependencies
