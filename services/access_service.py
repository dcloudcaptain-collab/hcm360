from services.db import get_cursor


# ─────────────────────────────────────────────────────────────────────────────
# Navigation
# ─────────────────────────────────────────────────────────────────────────────

def get_nav_links(role_code=None):
    with get_cursor() as cur:
        if role_code:
            cur.execute("""
                SELECT p.path AS route_url, p.title,
                       p.nav_label AS label, p.nav_group,
                       p.nav_icon, p.nav_order, p.requires_feature
                FROM core.page_registry p
                JOIN core.role_page_access rpa ON rpa.page_id = p.id
                WHERE p.is_visible = TRUE
                  AND rpa.role_code = %s
                  AND rpa.can_access = TRUE
                  AND (p.requires_feature IS NULL
                       OR EXISTS (
                           SELECT 1 FROM core.feature_registry fr
                           LEFT JOIN core.role_feature_access rfa
                               ON rfa.feature_id = fr.id AND rfa.role_code = %s
                           WHERE fr.code = p.requires_feature
                             AND COALESCE(rfa.can_access, fr.is_enabled) = TRUE
                       ))
                ORDER BY p.nav_order, p.title
            """, (role_code, role_code))
        else:
            cur.execute("""
                SELECT path AS route_url, title,
                       nav_label AS label, nav_group, nav_icon,
                       nav_order, requires_feature
                FROM core.page_registry
                WHERE is_visible = TRUE
                ORDER BY nav_order, title
            """)
        return cur.fetchall()


# ─────────────────────────────────────────────────────────────────────────────
# Page access — user-level overrides role-level; SUPER_ADMIN always passes
# ─────────────────────────────────────────────────────────────────────────────

def can_access_page(role_code, path, user_id=None):
    if role_code == 'SUPER_ADMIN':
        return True
    with get_cursor() as cur:
        # Path matching: exact OR prefix (for pattern entries ending with '/')
        path_clause = "(p.path = %s OR (p.path LIKE '%%/' AND %s LIKE p.path || '%%'))"

        # 1. User-level override (most specific)
        if user_id:
            cur.execute(f"""
                SELECT upa.can_access
                FROM core.user_page_access upa
                JOIN core.page_registry p ON p.id = upa.page_id
                WHERE upa.user_id = %s AND {path_clause}
                ORDER BY LENGTH(p.path) DESC
                LIMIT 1
            """, (user_id, path, path))
            row = cur.fetchone()
            if row is not None:
                return bool(row['can_access'])
        # 2. Role-level (most specific match wins — longer path wins over shorter prefix)
        cur.execute(f"""
            SELECT COALESCE(rpa.can_access, FALSE) AS can_access
            FROM core.page_registry p
            LEFT JOIN core.role_page_access rpa
                ON rpa.page_id = p.id AND rpa.role_code = %s
            WHERE {path_clause}
            ORDER BY LENGTH(p.path) DESC
            LIMIT 1
        """, (role_code, path, path))
        row = cur.fetchone()
        return True if row is None else bool(row['can_access'])


# ─────────────────────────────────────────────────────────────────────────────
# Feature access — user-level overrides role-level; SUPER_ADMIN always passes
# ─────────────────────────────────────────────────────────────────────────────

def can_access_feature(role_code, feature_code, user_id=None):
    if role_code == 'SUPER_ADMIN':
        return True
    with get_cursor() as cur:
        # 1. User-level override
        if user_id:
            cur.execute("""
                SELECT ufa.can_access
                FROM core.user_feature_access ufa
                JOIN core.feature_registry fr ON fr.id = ufa.feature_id
                WHERE ufa.user_id = %s AND fr.code = %s
                LIMIT 1
            """, (user_id, feature_code))
            row = cur.fetchone()
            if row is not None:
                return bool(row['can_access'])
        # 2. Role-level
        cur.execute("""
            SELECT fr.is_enabled, COALESCE(rfa.can_access, fr.is_enabled) AS allowed
            FROM core.feature_registry fr
            LEFT JOIN core.role_feature_access rfa
                ON rfa.feature_id = fr.id AND rfa.role_code = %s
            WHERE fr.code = %s
            LIMIT 1
        """, (role_code, feature_code))
        row = cur.fetchone()
        return bool(row and row['allowed'])


def get_feature_flags(role_code, user_id=None):
    """Return {code: bool} for all features, applying user-level overrides."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT fr.code,
                   COALESCE(rfa.can_access, fr.is_enabled) AS is_allowed
            FROM core.feature_registry fr
            LEFT JOIN core.role_feature_access rfa
                ON rfa.feature_id = fr.id AND rfa.role_code = %s
            ORDER BY fr.code
        """, (role_code,))
        flags = {row['code']: row['is_allowed'] for row in cur.fetchall()}

        if user_id:
            cur.execute("""
                SELECT fr.code, ufa.can_access
                FROM core.user_feature_access ufa
                JOIN core.feature_registry fr ON fr.id = ufa.feature_id
                WHERE ufa.user_id = %s
            """, (user_id,))
            for row in cur.fetchall():
                flags[row['code']] = row['can_access']

    return flags


# ─────────────────────────────────────────────────────────────────────────────
# Modification access (module-level write permissions)
# ─────────────────────────────────────────────────────────────────────────────

def can_modify(role_code, module_code, user_id=None):
    if role_code == 'SUPER_ADMIN':
        return True
    with get_cursor() as cur:
        if user_id:
            cur.execute("""
                SELECT can_modify FROM core.mod_permissions
                WHERE module_code = %s AND grantee_type = 'USER'
                  AND grantee_user_id = %s
                LIMIT 1
            """, (module_code, user_id))
            row = cur.fetchone()
            if row is not None:
                return bool(row['can_modify'])
        cur.execute("""
            SELECT can_modify FROM core.mod_permissions
            WHERE module_code = %s AND grantee_type = 'ROLE'
              AND grantee_role = %s
            LIMIT 1
        """, (module_code, role_code))
        row = cur.fetchone()
        return bool(row and row['can_modify'])


def get_mod_permissions():
    with get_cursor() as cur:
        cur.execute("""
            SELECT mp.id, mp.module_code, mp.grantee_type,
                   mp.grantee_role, mp.grantee_user_id,
                   u.display_name AS grantee_name,
                   mp.can_modify, mp.granted_at,
                   g.display_name AS granted_by_name
            FROM core.mod_permissions mp
            LEFT JOIN core.users u ON u.id = mp.grantee_user_id
            LEFT JOIN core.users g ON g.id = mp.granted_by
            ORDER BY mp.module_code, mp.grantee_type,
                     COALESCE(mp.grantee_role, u.display_name)
        """)
        return cur.fetchall()


# ─────────────────────────────────────────────────────────────────────────────
# Access Matrix — full data for admin UI
# ─────────────────────────────────────────────────────────────────────────────

def get_access_matrix():
    """Legacy: used by the old matrix view; kept for compatibility."""
    with get_cursor() as cur:
        cur.execute('SELECT DISTINCT role_code FROM core.users ORDER BY role_code')
        roles = [r['role_code'] for r in cur.fetchall()]
        cur.execute('SELECT id, path, title, nav_group, module FROM core.page_registry ORDER BY nav_order, title')
        pages = cur.fetchall()
        cur.execute('SELECT id, code, name, module, feature_type, action_type FROM core.feature_registry ORDER BY code')
        features = cur.fetchall()
        cur.execute('SELECT role_code, page_id, can_access FROM core.role_page_access')
        page_access = {(r['role_code'], r['page_id']): r['can_access'] for r in cur.fetchall()}
        cur.execute('SELECT role_code, feature_id, can_access FROM core.role_feature_access')
        feature_access = {(r['role_code'], r['feature_id']): r['can_access'] for r in cur.fetchall()}
        return roles, pages, features, page_access, feature_access


def get_module_access_detail(module_code, grantee_type, grantee_role=None, grantee_user_id=None):
    """
    Return all pages + their action features for a module,
    annotated with the current access state for the given grantee.
    """
    with get_cursor() as cur:
        # Pages in this module
        cur.execute("""
            SELECT p.id AS page_id, p.path, p.title, p.nav_label, p.nav_order
            FROM core.page_registry p
            WHERE p.module = %s
            ORDER BY p.nav_order, p.title
        """, (module_code,))
        pages = cur.fetchall()

        if not pages:
            return []

        page_ids  = [p['page_id'] for p in pages]
        page_paths = [p['path'] for p in pages]

        # Fetch page-level access for this grantee
        if grantee_type == 'ROLE' and grantee_role:
            cur.execute("""
                SELECT page_id, can_access FROM core.role_page_access
                WHERE role_code = %s AND page_id = ANY(%s)
            """, (grantee_role, page_ids))
            page_access = {r['page_id']: r['can_access'] for r in cur.fetchall()}

            # Action features on these pages
            cur.execute("""
                SELECT fr.id, fr.code, fr.name, fr.action_type, fr.page_path,
                       COALESCE(rfa.can_access, fr.is_enabled) AS granted
                FROM core.feature_registry fr
                LEFT JOIN core.role_feature_access rfa
                    ON rfa.feature_id = fr.id AND rfa.role_code = %s
                WHERE fr.feature_type = 'ACTION' AND fr.module = %s
                ORDER BY fr.page_path, fr.action_type, fr.name
            """, (grantee_role, module_code))

        else:  # USER
            cur.execute("""
                SELECT page_id, can_access FROM core.user_page_access
                WHERE user_id = %s AND page_id = ANY(%s)
            """, (grantee_user_id, page_ids))
            page_access = {r['page_id']: r['can_access'] for r in cur.fetchall()}

            cur.execute("""
                SELECT fr.id, fr.code, fr.name, fr.action_type, fr.page_path,
                       COALESCE(ufa.can_access, fr.is_enabled) AS granted
                FROM core.feature_registry fr
                LEFT JOIN core.user_feature_access ufa
                    ON ufa.feature_id = fr.id AND ufa.user_id = %s
                WHERE fr.feature_type = 'ACTION' AND fr.module = %s
                ORDER BY fr.page_path, fr.action_type, fr.name
            """, (grantee_user_id, module_code))

        features = cur.fetchall()

    # Group features by page_path
    features_by_path = {}
    for f in features:
        features_by_path.setdefault(f['page_path'], []).append(f)

    result = []
    for page in pages:
        result.append({
            'page_id':    page['page_id'],
            'path':       page['path'],
            'title':      page['title'],
            'nav_label':  page['nav_label'],
            'can_access': page_access.get(page['page_id'], True),
            'features':   features_by_path.get(page['path'], []),
        })
    return result


def save_page_access(page_id, can_access, granted_by,
                     role_code=None, user_id=None):
    """Upsert page access for a role or user, then cascade to all features on that page."""
    with get_cursor(commit=True) as cur:
        # 1. Save page-level access
        if role_code:
            cur.execute("""
                INSERT INTO core.role_page_access (role_code, page_id, can_access)
                VALUES (%s, %s, %s)
                ON CONFLICT (role_code, page_id) DO UPDATE SET can_access = EXCLUDED.can_access
            """, (role_code, page_id, can_access))
        elif user_id:
            cur.execute("""
                INSERT INTO core.user_page_access (user_id, page_id, can_access, granted_by)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (user_id, page_id) DO UPDATE
                    SET can_access = EXCLUDED.can_access, granted_by = EXCLUDED.granted_by, granted_at = NOW()
            """, (user_id, page_id, can_access, granted_by))

        # 2. Resolve page path from page_id
        cur.execute("SELECT path FROM core.page_registry WHERE id = %s", (page_id,))
        row = cur.fetchone()
        if not row:
            return

        page_path = row['path']

        # 3. Find all action features linked to this page
        cur.execute("""
            SELECT id FROM core.feature_registry
            WHERE page_path = %s AND feature_type = 'ACTION'
        """, (page_path,))
        feature_ids = [r['id'] for r in cur.fetchall()]

        if not feature_ids:
            return

        # 4. Cascade: bulk-upsert feature access to match page state
        if role_code:
            for fid in feature_ids:
                cur.execute("""
                    INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
                    VALUES (%s, %s, %s)
                    ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = EXCLUDED.can_access
                """, (role_code, fid, can_access))
        elif user_id:
            for fid in feature_ids:
                cur.execute("""
                    INSERT INTO core.user_feature_access (user_id, feature_id, can_access, granted_by)
                    VALUES (%s, %s, %s, %s)
                    ON CONFLICT (user_id, feature_id) DO UPDATE
                        SET can_access = EXCLUDED.can_access, granted_by = EXCLUDED.granted_by, granted_at = NOW()
                """, (user_id, fid, can_access, granted_by))

        return feature_ids   # return so route can pass IDs back to JS


def save_feature_access(feature_id, can_access, granted_by,
                        role_code=None, user_id=None):
    """Upsert feature/action access for a role or user."""
    with get_cursor(commit=True) as cur:
        if role_code:
            cur.execute("""
                INSERT INTO core.role_feature_access (role_code, feature_id, can_access)
                VALUES (%s, %s, %s)
                ON CONFLICT (role_code, feature_id) DO UPDATE SET can_access = EXCLUDED.can_access
            """, (role_code, feature_id, can_access))
        elif user_id:
            cur.execute("""
                INSERT INTO core.user_feature_access (user_id, feature_id, can_access, granted_by)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (user_id, feature_id) DO UPDATE
                    SET can_access = EXCLUDED.can_access, granted_by = EXCLUDED.granted_by, granted_at = NOW()
            """, (user_id, feature_id, can_access, granted_by))


def get_all_roles():
    with get_cursor() as cur:
        cur.execute("""
            SELECT DISTINCT code FROM (
                SELECT role_code AS code FROM core.users WHERE role_code IS NOT NULL
                UNION
                SELECT code FROM core.roles WHERE is_active = TRUE
            ) combined
            ORDER BY code
        """)
        return [r['code'] for r in cur.fetchall()]


def create_role(code, name, description=None):
    """Create a new role in core.roles. Returns the new role row."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO core.roles (company_id, code, name, description, is_system_role)
            VALUES ((SELECT id FROM core.companies LIMIT 1), %s, %s, %s, FALSE)
            RETURNING id, code, name
        """, (code.upper().strip(), name.strip(), description or None))
        return cur.fetchone()


def get_all_users_for_access():
    with get_cursor() as cur:
        cur.execute("""
            SELECT id, display_name, email, role_code
            FROM core.users
            WHERE is_active = TRUE
            ORDER BY display_name
        """)
        return cur.fetchall()


MODULES = [
    {'code': 'core',        'label': 'Core / Employees'},
    {'code': 'attendance',  'label': 'Attendance & DTR'},
    {'code': 'leave_mgmt',  'label': 'Leave Management'},
    {'code': 'payroll',     'label': 'Payroll'},
    {'code': 'rsp',         'label': 'RSP / Recruitment'},
    {'code': 'pm',          'label': 'Performance Management'},
    {'code': 'ld',          'label': 'Learning & Development'},
    {'code': 'rr',          'label': 'Rewards & Recognition'},
    {'code': 'dms',         'label': 'Employee 201 File'},
    {'code': 'discipline',  'label': 'Discipline'},
    {'code': 'health',      'label': 'Health & Safety'},
    {'code': 'analytics',   'label': 'Analytics & Reports'},
    {'code': 'data_sources','label': 'Report Data Sources'},
    {'code': 'ess_mss',          'label': 'ESS / MSS (Self-Service)'},
    {'code': 'workforce_planning', 'label': 'Workforce Planning'},
    {'code': 'orgchart',    'label': 'Organization Chart'},
    {'code': 'ai',          'label': 'AI / ARIA'},
    {'code': 'workflow',    'label': 'Workflows'},
    {'code': 'admin',       'label': 'Administration'},
]


# ══════════════════════════════════════════════════════════════════════
# Data Source Grants — Report Builder + ARIA access
# ══════════════════════════════════════════════════════════════════════
def get_data_source_access_detail(grantee_type, grantee_role=None, grantee_user_id=None):
    """
    Return all report data sources annotated with the current access state
    for the given grantee. Each source becomes a "virtual page" in the
    matrix view so the existing toggle UI works unchanged.
    """
    with get_cursor() as cur:
        cur.execute("""
            SELECT id, source_code, source_label, module, description
            FROM analytics.report_data_sources
            WHERE is_active = TRUE
            ORDER BY module, sort_order, source_label
        """)
        sources = cur.fetchall()

        if not sources:
            return []

        source_ids = [s['id'] for s in sources]

        if grantee_type == 'ROLE' and grantee_role:
            cur.execute("""
                SELECT source_id, can_access FROM analytics.report_source_role_access
                WHERE role_code = %s AND source_id = ANY(%s)
            """, (grantee_role, source_ids))
            access = {r['source_id']: r['can_access'] for r in cur.fetchall()}
        elif grantee_type == 'USER' and grantee_user_id:
            cur.execute("""
                SELECT source_id, can_access FROM analytics.report_source_user_access
                WHERE user_id = %s AND source_id = ANY(%s)
            """, (grantee_user_id, source_ids))
            access = {r['source_id']: r['can_access'] for r in cur.fetchall()}
        else:
            access = {}

    result = []
    for s in sources:
        result.append({
            'page_id':    s['id'],          # reuse page_id key so template works
            'path':       f"/reports/builder?source={s['source_code']}",
            'title':      s['source_label'],
            'nav_label':  s['source_code'],
            'can_access': access.get(s['id'], grantee_role == 'SUPER_ADMIN'),
            'description': s.get('description') or '',
            'module':     s['module'],
            'features':   [],               # sources have no sub-actions
        })
    return result


def save_data_source_access(source_id, can_access, granted_by,
                             role_code=None, user_id=None):
    """Upsert grant row; returns empty list (no cascaded features)."""
    with get_cursor(commit=True) as cur:
        if role_code:
            cur.execute("""
                INSERT INTO analytics.report_source_role_access
                    (role_code, source_id, can_access, granted_by)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (role_code, source_id) DO UPDATE
                    SET can_access = EXCLUDED.can_access,
                        granted_by = EXCLUDED.granted_by,
                        granted_at = NOW()
            """, (role_code, source_id, can_access, granted_by))
        elif user_id:
            cur.execute("""
                INSERT INTO analytics.report_source_user_access
                    (user_id, source_id, can_access, granted_by)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (user_id, source_id) DO UPDATE
                    SET can_access = EXCLUDED.can_access,
                        granted_by = EXCLUDED.granted_by,
                        granted_at = NOW()
            """, (user_id, source_id, can_access, granted_by))
    return []


def get_allowed_source_ids(role_code, user_id=None):
    """Return source_ids the (role, optional user-override) is allowed to query."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT id FROM analytics.report_data_sources WHERE is_active = TRUE
        """)
        all_ids = {r['id'] for r in cur.fetchall()}

        # User-level overrides take precedence
        user_allowed = set()
        user_blocked = set()
        if user_id:
            cur.execute("""
                SELECT source_id, can_access FROM analytics.report_source_user_access
                WHERE user_id = %s
            """, (user_id,))
            for r in cur.fetchall():
                (user_allowed if r['can_access'] else user_blocked).add(r['source_id'])

        # Role grants
        role_allowed = set()
        if role_code:
            if role_code == 'SUPER_ADMIN':
                # SUPER_ADMIN always sees everything unless user-level blocked
                role_allowed = all_ids.copy()
            else:
                cur.execute("""
                    SELECT source_id FROM analytics.report_source_role_access
                    WHERE role_code = %s AND can_access = TRUE
                """, (role_code,))
                role_allowed = {r['source_id'] for r in cur.fetchall()}

        effective = (role_allowed | user_allowed) - user_blocked
        return effective
