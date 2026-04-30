from datetime import datetime
from flask import (Blueprint, jsonify, redirect, render_template, request,
                   session, url_for, flash)
from services.db import get_cursor
from services.kpi_service import (
    get_dashboard_metrics,
    list_dashboard_library,
    toggle_dashboard_pin,
    dashboard_pin_count,
)
from services import widget_service
from services import preference_service
from services import task_inbox_service
from services.access_service import get_nav_links

bp = Blueprint('dashboard', __name__)


@bp.route('/')
def index():
    role_code   = session.get('role_code', '')
    user_id     = session.get('user_id')

    # Pin-aware: user's pinned tiles if any, else all role-appropriate tiles
    metrics = get_dashboard_metrics(role_code=role_code, user_id=user_id)
    pin_count = dashboard_pin_count(user_id) if user_id else 0

    # Widget grid — renders user's pinned widgets (fallback: default-pinned)
    if user_id and role_code:
        pinned_widgets = widget_service.get_pinned(user_id, role_code)
        widgets = widget_service.run_many(pinned_widgets)
        widget_pin_count = widget_service.pinned_count(user_id)
    else:
        widgets = []
        widget_pin_count = 0

    return render_template(
        'dashboard/index.html',
        metrics=metrics,
        pin_count=pin_count,
        widgets=widgets,
        widget_pin_count=widget_pin_count,
        now=datetime.now(),
    )


# ── Manage KPI-tiles library ────────────────────────────────────
@bp.route('/dashboard/manage')
def manage():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    role_code = session.get('role_code') or 'EMPLOYEE'
    user_id   = session['user_id']
    tiles = list_dashboard_library(role_code, user_id)
    categories, seen = [], set()
    for t in tiles:
        if t['category'] not in seen:
            categories.append(t['category'])
            seen.add(t['category'])
    return render_template(
        'dashboard/manage.html',
        tiles=tiles, categories=categories,
        pinned_count=sum(1 for t in tiles if t['is_pinned']),
    )


@bp.route('/dashboard/manage/toggle', methods=['POST'])
def manage_toggle():
    if 'user_id' not in session:
        return jsonify({'ok': False, 'error': 'not signed in'}), 401
    code = (request.form.get('code') or '').strip()
    enabled = (request.form.get('enabled') or '').lower() in ('1', 'true', 'on', 'yes')
    if not code:
        return jsonify({'ok': False, 'error': 'code is required'}), 400
    ok = toggle_dashboard_pin(session['user_id'], code, enabled)
    return jsonify({
        'ok':           bool(ok),
        'code':         code,
        'enabled':      enabled,
        'pinned_count': dashboard_pin_count(session['user_id']),
    })


# ── Manage WIDGETS library ──────────────────────────────────────
@bp.route('/dashboard/widgets')
def widgets():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    role_code = session.get('role_code') or 'EMPLOYEE'
    user_id   = session['user_id']
    widgets = widget_service.list_library(role_code, user_id)
    categories, seen = [], set()
    for w in widgets:
        if w['category'] not in seen:
            categories.append(w['category'])
            seen.add(w['category'])
    return render_template(
        'dashboard/widgets.html',
        widgets=widgets, categories=categories,
        pinned_count=sum(1 for w in widgets if w['is_pinned']),
    )


@bp.route('/dashboard/widgets/toggle', methods=['POST'])
def widgets_toggle():
    if 'user_id' not in session:
        return jsonify({'ok': False, 'error': 'not signed in'}), 401
    code = (request.form.get('code') or '').strip()
    enabled = (request.form.get('enabled') or '').lower() in ('1', 'true', 'on', 'yes')
    if not code:
        return jsonify({'ok': False, 'error': 'code is required'}), 400
    ok = widget_service.toggle(session['user_id'], code, enabled)
    return jsonify({
        'ok':           bool(ok),
        'code':         code,
        'enabled':      enabled,
        'pinned_count': widget_service.pinned_count(session['user_id']),
    })


# ══════════════════════════════════════════════════════════════════
# PORTAL — alternate tile-grid landing page
# ══════════════════════════════════════════════════════════════════
@bp.route('/portal')
def portal():
    """Tile-grid launcher: every page the user can access, plus an
    inbox rail. Theme-token-driven so it follows the active UI theme."""
    if 'user_id' not in session:
        return redirect(url_for('login'))

    user_id     = session['user_id']
    role_code   = session.get('role_code') or 'EMPLOYEE'
    employee_id = session.get('employee_id')

    # 1. Source of tiles — every nav link the role can see, PLUS user-
    #    level grants for pages the role wouldn't normally see.
    nav_pages = list(get_nav_links(role_code) or [])
    seen_paths = {p['route_url'] for p in nav_pages}

    with get_cursor() as cur:
        # User-level overrides — pull pages explicitly granted to this
        # user that aren't already in the role-derived list.
        cur.execute("""
            SELECT p.path AS route_url, p.title,
                   p.nav_label AS label, p.nav_group,
                   p.nav_icon, p.nav_order, p.module
              FROM core.user_page_access upa
              JOIN core.page_registry p ON p.id = upa.page_id
             WHERE upa.user_id = %s
               AND upa.can_access = TRUE
               AND p.is_visible = TRUE
        """, (user_id,))
        for r in cur.fetchall():
            if r['route_url'] not in seen_paths:
                nav_pages.append(r)
                seen_paths.add(r['route_url'])

    # Re-fetch `module` for the role-derived rows (get_nav_links omits it)
    if nav_pages:
        paths = [p['route_url'] for p in nav_pages]
        with get_cursor() as cur:
            cur.execute("""
                SELECT path, module FROM core.page_registry
                 WHERE path = ANY(%s)
            """, (paths,))
            mod_by_path = {r['path']: r['module'] for r in cur.fetchall()}
        nav_pages = [
            {**(dict(p) if not isinstance(p, dict) else p),
             'module': (dict(p) if not isinstance(p, dict) else p).get('module')
                       or mod_by_path.get(p['route_url'])}
            for p in nav_pages
        ]

    # 2. Group + sort
    groups = {}
    for p in nav_pages:
        g = p.get('nav_group') or 'Other'
        groups.setdefault(g, []).append(p)
    for g in groups:
        groups[g].sort(key=lambda r: ((r.get('nav_order') or 999), (r.get('title') or '')))
    GROUP_PRIORITY = [
        'Self-Service', 'Core', 'Employee Management',
        'Performance', 'Recruitment', 'Learning', 'Awards',
        '201 File', 'Discipline', 'Health', 'Payroll',
        'Analytics', 'AI', 'Administration', 'Admin', 'System',
    ]
    ordered_groups = []
    seen = set()
    for g in GROUP_PRIORITY:
        if g in groups:
            ordered_groups.append((g, groups[g]))
            seen.add(g)
    for g, items in groups.items():
        if g not in seen:
            ordered_groups.append((g, items))

    # 3. Inbox rail (top 8) + count
    inbox_items = []
    inbox_counts = {'total': 0, 'unread': 0, 'urgent': 0}
    if employee_id or user_id:
        try:
            inbox_items = list(task_inbox_service.get_inbox(
                employee_id=employee_id, user_id=user_id, status='PENDING'
            ) or [])[:8]
            inbox_counts = dict(task_inbox_service.get_inbox_count(
                employee_id=employee_id, user_id=user_id
            ) or inbox_counts)
        except Exception:
            pass

    # 4. Compute "age in days" for each inbox item (for the badge)
    today = datetime.now().date()
    enriched_inbox = []
    for it in inbox_items:
        d = dict(it)
        created = d.get('created_at')
        if created:
            d['age_days'] = (today - (created.date() if hasattr(created, 'date') else created)).days
        else:
            d['age_days'] = 0
        enriched_inbox.append(d)

    return render_template(
        'dashboard/portal.html',
        groups=ordered_groups,
        total_pages=len(nav_pages),
        inbox=enriched_inbox,
        inbox_counts=inbox_counts,
        now=datetime.now(),
    )


# ── Landing preference toggle ──────────────────────────────────
@bp.route('/me/preferences/landing', methods=['POST'])
def set_landing_pref():
    if 'user_id' not in session:
        return jsonify({'ok': False, 'error': 'not signed in'}), 401
    layout = (request.form.get('layout') or '').strip().lower()
    if layout not in preference_service.LANDING_VALUES and layout != '':
        flash('Invalid landing mode.', 'error')
        return redirect(request.referrer or url_for('dashboard.index'))
    preference_service.set_landing_layout(session['user_id'], layout)

    # Redirect to the chosen landing immediately
    if layout == 'portal':
        flash('Switched to Portal mode. This is now your landing page.', 'success')
        return redirect(url_for('dashboard.portal'))
    if layout == 'dashboard':
        flash('Switched to Dashboard mode.', 'success')
        return redirect(url_for('dashboard.index'))
    if layout == 'profile':
        flash('Switched to Profile mode.', 'success')
        return redirect(url_for('ess.my_profile'))
    flash('Landing preference cleared — using role default.', 'success')
    return redirect(request.referrer or url_for('dashboard.index'))


# ── JSON: inbox summary refresh (used by AJAX from portal) ─────
@bp.route('/api/portal/inbox-summary')
def portal_inbox_summary():
    if 'user_id' not in session:
        return jsonify({'ok': False, 'error': 'not signed in'}), 401
    user_id     = session['user_id']
    employee_id = session.get('employee_id')
    items = list(task_inbox_service.get_inbox(
        employee_id=employee_id, user_id=user_id, status='PENDING'
    ) or [])[:8]
    counts = dict(task_inbox_service.get_inbox_count(
        employee_id=employee_id, user_id=user_id
    ) or {'total': 0, 'unread': 0, 'urgent': 0})
    today = datetime.now().date()
    out = []
    for it in items:
        d = dict(it)
        c = d.get('created_at')
        d['age_days'] = (today - (c.date() if c and hasattr(c, 'date') else (c or today))).days if c else 0
        # Strip non-JSON-safe fields
        for k in ('created_at', 'completed_at', 'updated_at', 'due_date'):
            if d.get(k) is not None:
                d[k] = d[k].isoformat() if hasattr(d[k], 'isoformat') else str(d[k])
        out.append({
            'id':        d.get('id'),
            'title':     d.get('title'),
            'task_type': d.get('task_type'),
            'priority':  d.get('priority'),
            'status':    d.get('status'),
            'action_url': d.get('action_url'),
            'age_days':  d.get('age_days'),
            'is_read':   d.get('is_read'),
        })
    return jsonify({'ok': True, 'counts': counts, 'items': out})
