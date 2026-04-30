"""
Guided Tour service — manages tour definitions, role filtering, and
per-user completion tracking.
"""
import json

from services.db import get_cursor


# ══════════════════════════════════════════════════════════════════════
# Read
# ══════════════════════════════════════════════════════════════════════
def list_tours(only_active: bool = True):
    with get_cursor() as cur:
        sql = """
            SELECT t.id, t.tour_key, t.title, t.description, t.module,
                   t.version, t.allowed_roles, t.url_pattern, t.auto_start,
                   t.is_active, t.updated_at,
                   (SELECT COUNT(*) FROM core.tour_completions c
                      WHERE c.tour_key = t.tour_key) AS completion_count
            FROM core.tours t
        """
        if only_active:
            sql += ' WHERE t.is_active = TRUE'
        sql += ' ORDER BY t.module, t.tour_key'
        cur.execute(sql)
        return cur.fetchall()


def get_tour(tour_key: str):
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM core.tours WHERE tour_key = %s
        """, (tour_key,))
        return cur.fetchone()


def tour_visible_to(user_id: int, role_code: str, tour) -> bool:
    """Role filtering — SUPER_ADMIN sees everything."""
    if role_code == 'SUPER_ADMIN':
        return True
    return role_code in (tour.get('allowed_roles') or [])


def completions_for_user(user_id: int):
    with get_cursor() as cur:
        cur.execute("""
            SELECT tour_key, version, completed_at, skipped, step_reached
            FROM core.tour_completions
            WHERE user_id = %s
        """, (user_id,))
        return {r['tour_key']: dict(r) for r in cur.fetchall()}


def tours_for_url(user_id: int, role_code: str, url_path: str):
    """
    Return the list of active tours that apply to the given URL path
    and are visible to the user's role. Each tour is annotated with
    the user's completion status (completed / not).
    """
    if not url_path:
        url_path = '/'
    completions = completions_for_user(user_id) if user_id else {}
    with get_cursor() as cur:
        cur.execute("""
            SELECT tour_key, title, description, module, version,
                   allowed_roles, url_pattern, auto_start, steps
            FROM core.tours
            WHERE is_active = TRUE
              AND (url_pattern IS NULL
                   OR %s LIKE url_pattern
                   OR %s LIKE (url_pattern || '/%%')
                   OR %s = url_pattern)
            ORDER BY module, tour_key
        """, (url_path, url_path, url_path))
        rows = cur.fetchall()

    result = []
    for t in rows:
        if not tour_visible_to(user_id, role_code, t):
            continue
        done = completions.get(t['tour_key'])
        t_dict = dict(t)
        t_dict['is_completed'] = bool(done) and (not done.get('skipped', False))
        t_dict['is_skipped']   = bool(done) and done.get('skipped', False)
        # Steps — ensure list
        steps = t_dict['steps']
        if isinstance(steps, str):
            steps = json.loads(steps)
        t_dict['steps'] = steps
        result.append(t_dict)
    return result


# ══════════════════════════════════════════════════════════════════════
# Completion tracking
# ══════════════════════════════════════════════════════════════════════
def mark_completed(user_id: int, tour_key: str, version: int = 1,
                   skipped: bool = False, step_reached: int = 0):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO core.tour_completions
                (user_id, tour_key, version, completed_at, skipped, step_reached)
            VALUES (%s, %s, %s, NOW(), %s, %s)
            ON CONFLICT (user_id, tour_key, version) DO UPDATE SET
                completed_at = NOW(),
                skipped      = EXCLUDED.skipped,
                step_reached = GREATEST(core.tour_completions.step_reached,
                                        EXCLUDED.step_reached)
        """, (user_id, tour_key, version, skipped, step_reached))


def reset_completion(user_id: int, tour_key: str):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            DELETE FROM core.tour_completions
            WHERE user_id = %s AND tour_key = %s
        """, (user_id, tour_key))


def reset_for_role(role_code: str, tour_key: str = None):
    """Admin: reset completions for all users in a role."""
    with get_cursor(commit=True) as cur:
        if tour_key:
            cur.execute("""
                DELETE FROM core.tour_completions c
                USING core.users u
                WHERE c.user_id = u.id
                  AND u.role_code = %s
                  AND c.tour_key = %s
            """, (role_code, tour_key))
        else:
            cur.execute("""
                DELETE FROM core.tour_completions c
                USING core.users u
                WHERE c.user_id = u.id AND u.role_code = %s
            """, (role_code,))
        return cur.rowcount


# ══════════════════════════════════════════════════════════════════════
# Write (admin)
# ══════════════════════════════════════════════════════════════════════
def upsert_tour(payload: dict, user_id: int):
    with get_cursor(commit=True) as cur:
        steps = payload.get('steps')
        if isinstance(steps, str):
            try:
                steps_json = steps
                json.loads(steps)  # validate
            except Exception:
                raise ValueError('steps must be valid JSON')
        else:
            steps_json = json.dumps(steps or [])

        roles = payload.get('allowed_roles') or ['SUPER_ADMIN','HR_ADMIN',
                                                  'MANAGER','EMPLOYEE','EXECUTIVE']
        if isinstance(roles, str):
            roles = [r.strip() for r in roles.split(',') if r.strip()]

        cur.execute("""
            INSERT INTO core.tours
                (tour_key, title, description, module, version,
                 allowed_roles, url_pattern, auto_start, steps,
                 is_active, updated_by, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW())
            ON CONFLICT (tour_key) DO UPDATE SET
                title         = EXCLUDED.title,
                description   = EXCLUDED.description,
                module        = EXCLUDED.module,
                version       = EXCLUDED.version,
                allowed_roles = EXCLUDED.allowed_roles,
                url_pattern   = EXCLUDED.url_pattern,
                auto_start    = EXCLUDED.auto_start,
                steps         = EXCLUDED.steps,
                is_active     = EXCLUDED.is_active,
                updated_by    = EXCLUDED.updated_by,
                updated_at    = NOW()
            RETURNING id, tour_key
        """, (
            payload['tour_key'],
            payload['title'],
            payload.get('description'),
            payload.get('module'),
            int(payload.get('version') or 1),
            roles,
            payload.get('url_pattern'),
            bool(payload.get('auto_start', True)),
            steps_json,
            bool(payload.get('is_active', True)),
            user_id,
        ))
        return cur.fetchone()


def deactivate_tour(tour_key: str):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE core.tours SET is_active = FALSE, updated_at = NOW()
            WHERE tour_key = %s
        """, (tour_key,))


# ══════════════════════════════════════════════════════════════════════
# Summary for admin dashboard
# ══════════════════════════════════════════════════════════════════════
def summary():
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                COUNT(*) FILTER (WHERE is_active)                AS active_count,
                COUNT(*) FILTER (WHERE NOT is_active)            AS inactive_count,
                COUNT(*)                                          AS total_count,
                (SELECT COUNT(*) FROM core.tour_completions)      AS total_completions,
                (SELECT COUNT(DISTINCT user_id)
                 FROM core.tour_completions)                      AS users_reached
            FROM core.tours
        """)
        return dict(cur.fetchone())
