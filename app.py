import base64, json
from flask import Flask, abort, g, redirect, render_template, request, session, url_for
from config import Config
from modules.dashboard.routes import bp as dashboard_bp
from modules.employees.routes import bp as employees_bp
from modules.admin.routes import bp as admin_bp
from modules.workflow.routes import bp as workflow_bp
from modules.search.routes import bp as search_bp
from modules.inquiry.routes import bp as inquiry_bp
from modules.api.routes import bp as api_bp
from modules.ai.routes import bp as ai_bp
# Phase 1 modules
from modules.attendance.routes import attendance_bp
from modules.leave.routes import leave_bp
from modules.payroll.routes import payroll_bp
from modules.ess_mss.routes import ess_bp
from modules.analytics.routes import analytics_bp
# Phase 2 modules
from modules.rsp.routes import rsp_bp
from modules.pm.routes import pm_bp
from modules.ld.routes import ld_bp
from modules.rr.routes import rr_bp
# Phase 3 modules
from modules.dms.routes import dms_bp
from modules.discipline.routes import discipline_bp
from modules.health.routes import health_bp
# Phase 4 modules
from modules.orgchart.routes import orgchart_bp
from modules.onboarding.routes import onboarding_bp
from modules.benefits.routes import benefits_bp
from modules.workforce_planning.routes import wfp_bp
from modules.feedback.routes import feedback_bp
from modules.calibration.routes import calibration_bp
from modules.goals.routes import goals_bp
from modules.skills_career.routes import skills_bp
from modules.comp_review.routes import comp_review_bp
from modules.certifications.routes import certifications_bp
from modules.notifications.routes import bp as notifications_bp
# Face-recognition + geotag check-in
from modules.checkin.routes import checkin_bp
# Step increment + retirement monitoring
from modules.milestones.routes import milestones_bp
# LGU Forms: CS Form 6, Exit Interview/CS7, Travel Orders, Locator Slips, LGU Contracts, PDS
from modules.lgu_forms.routes import lgu_forms_bp
# LGU Gaps v2: G08 E-sig, G09 training attendance, G10 NRF, G11 loyalty,
#              G15 eligibility, G16 SALN, G17 appointment, G18 attrition
from modules.lgu_gaps_v2.routes import lgu_gaps_v2_bp
# Guided Tour + Tooltip system
from modules.tour.routes import tour_bp
from modules.requisitions.routes import requisitions_bp, recruitment_alias_bp
# Task Management (create + assign + comments + templates + team/admin views)
from modules.tasks.routes import tasks_bp
# Global employee picker (shared: departments, custom groups, bulk selection)
from modules.employee_picker.routes import picker_bp
# Self-service access-request queue (handles 403 "request access" flow)
from modules.access_requests.routes import access_req_bp
# Personal analytics dashboard + Insights Library
from modules.insights.routes import insights_bp
# ARIA AI extensions — registers cross-module query tools on import
import services.aria_extensions  # noqa: F401 — side effect only
from services.access_service import can_access_page, get_feature_flags, get_nav_links
from services.db import get_cursor
from services.settings_service import get_branding
from services.theme_service import get_active_theme, get_user_theme
from services import preference_service


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    # Core blueprints
    for bp in [dashboard_bp, employees_bp, admin_bp, workflow_bp,
               search_bp, inquiry_bp, api_bp, ai_bp, notifications_bp]:
        app.register_blueprint(bp)

    # Phase 1 module blueprints (guarded by feature flags)
    if app.config.get('ENABLE_ATTENDANCE', True):
        app.register_blueprint(attendance_bp)
    if app.config.get('ENABLE_LEAVE', True):
        app.register_blueprint(leave_bp)
    if app.config.get('ENABLE_PAYROLL', True):
        app.register_blueprint(payroll_bp)
    # ESS/MSS always on (uses /me and /my-team)
    app.register_blueprint(ess_bp)
    if app.config.get('ENABLE_ANALYTICS', True):
        app.register_blueprint(analytics_bp)

    # Phase 2 module blueprints
    if app.config.get('ENABLE_RSP', True):
        app.register_blueprint(rsp_bp)
    if app.config.get('ENABLE_PM', True):
        app.register_blueprint(pm_bp)
    if app.config.get('ENABLE_LD', True):
        app.register_blueprint(ld_bp)
    if app.config.get('ENABLE_RR', True):
        app.register_blueprint(rr_bp)

    # Phase 3 module blueprints
    if app.config.get('ENABLE_DMS', True):
        app.register_blueprint(dms_bp)
    if app.config.get('ENABLE_DISCIPLINE', True):
        app.register_blueprint(discipline_bp)
    if app.config.get('ENABLE_HEALTH', True):
        app.register_blueprint(health_bp)

    # Phase 4 module blueprints
    if app.config.get('ENABLE_ORGCHART', True):
        app.register_blueprint(orgchart_bp)

    # Onboarding module (always on — ties into RSP and ESS)
    app.register_blueprint(onboarding_bp)

    # Benefits Administration
    app.register_blueprint(benefits_bp)

    # Workforce Planning
    app.register_blueprint(wfp_bp)

    # Phase 5: Gap-closure modules
    app.register_blueprint(feedback_bp)
    app.register_blueprint(calibration_bp)
    app.register_blueprint(goals_bp)
    app.register_blueprint(skills_bp)
    app.register_blueprint(comp_review_bp)
    app.register_blueprint(certifications_bp)

    # Face-recognition + geotag check-in (always on)
    app.register_blueprint(checkin_bp)

    # Step increment + retirement monitoring (always on)
    app.register_blueprint(milestones_bp)

    # LGU Forms: CS Form 6, Exit+CS7, Travel Orders, Locator Slips, Contracts, PDS
    app.register_blueprint(lgu_forms_bp)

    # LGU Gaps v2: G08, G09, G10, G11, G15, G16, G17, G18
    app.register_blueprint(lgu_gaps_v2_bp)

    # Guided Tour + Tooltip system (always on)
    app.register_blueprint(tour_bp)

    # Job Requisitions (LGU Gap Sheet #8)
    app.register_blueprint(requisitions_bp)
    app.register_blueprint(recruitment_alias_bp)

    # Task Management (LGU Gap Sheet #9)
    app.register_blueprint(tasks_bp)

    # Global employee picker (departments + custom groups)
    app.register_blueprint(picker_bp)

    # Access-request queue + 403 "request access" flow
    app.register_blueprint(access_req_bp)

    # Personal Analytics page (/analytics) + Insights Library (/admin/insights-library)
    app.register_blueprint(insights_bp)

    # ── Friendly 403 page with "Request Access" form ──
    @app.errorhandler(403)
    def _handle_forbidden(e):
        path = request.path
        page_title = None
        module = None
        try:
            with get_cursor() as cur:
                cur.execute("""
                    SELECT title, module FROM core.page_registry
                     WHERE path = %s LIMIT 1
                """, (path,))
                row = cur.fetchone()
                if row:
                    page_title = row['title']
                    module = row['module']
        except Exception:
            pass
        return render_template('403.html',
                               requested_path=path,
                               page_title=page_title,
                               module=module), 403

    def _resolve_sso(token):
        """Decode JWT payload (no signature check) and return user_id if username matches."""
        try:
            payload_b64 = token.split('.')[1]
            payload_b64 += '=' * (4 - len(payload_b64) % 4)
            payload = json.loads(base64.urlsafe_b64decode(payload_b64))
            username = payload.get('username', '').lower()
            if not username:
                return None
            with get_cursor() as cur:
                cur.execute(
                    "SELECT id FROM core.users WHERE is_active=TRUE AND (LOWER(SPLIT_PART(email,'@',1))=%s OR LOWER(REPLACE(display_name,' ',''))=%s)",
                    (username, username)
                )
                row = cur.fetchone()
            return row['id'] if row else None
        except Exception:
            return None

    @app.before_request
    def load_context():
        # SSO token auto-login
        sso_token = request.args.get('sso_token')
        if sso_token and not session.get('user_id'):
            uid = _resolve_sso(sso_token)
            if uid:
                session['user_id'] = uid
                return redirect(request.path)

        # Per-user theme preference → fallback to global active theme
        uid = session.get('user_id')
        g.theme = get_user_theme(uid) if uid else get_active_theme()
        g.branding = get_branding()
        with get_cursor() as cur:
            # Simulated-login dropdown order: SUPER_ADMIN first, then by last name.
            # last_name comes from the linked employee; users without an employee
            # fall back to the trailing token of display_name.
            cur.execute("""
                SELECT u.id, u.display_name, u.role_code
                FROM core.users u
                LEFT JOIN core.employees e ON e.id = u.employee_id
                WHERE u.is_active = TRUE
                ORDER BY
                    CASE WHEN u.role_code = 'SUPER_ADMIN' THEN 0 ELSE 1 END,
                    LOWER(COALESCE(
                        NULLIF(e.last_name, ''),
                        NULLIF(split_part(u.display_name, ' ', array_length(string_to_array(u.display_name, ' '), 1)), ''),
                        u.display_name
                    )),
                    LOWER(u.display_name),
                    u.id
            """)
            g.users = cur.fetchall()
            user_id = session.get('user_id')
            if not user_id and request.endpoint not in ('login', 'do_login') and not request.path.startswith('/static') and not request.path.startswith('/inquiry/'):
                return redirect(url_for('login'))
            if user_id:
                cur.execute("""
                    SELECT u.id, u.display_name, u.email,
                           COALESCE(r.code, u.role_code) AS role_code,
                           u.employee_id
                    FROM core.users u
                    LEFT JOIN core.user_roles ur ON ur.user_id = u.id
                    LEFT JOIN core.roles r ON r.id = ur.role_id
                    WHERE u.id = %s
                    LIMIT 1
                """, (user_id,))
                g.current_user = cur.fetchone()
                if g.current_user:
                    session['employee_id'] = g.current_user.get('employee_id')
                    session['role_code']   = g.current_user.get('role_code')
            else:
                g.current_user = None
        role_code = session.get('role_code') or (g.current_user['role_code'] if g.current_user else None)
        g.nav_links = get_nav_links(role_code)
        g.feature_flags = get_feature_flags(role_code, user_id=session.get('user_id')) if role_code else {}
        if request.path.startswith('/static') or request.path.startswith('/uploads/') or request.path.startswith('/api/') or request.endpoint in ('login', 'do_login', 'logout', 'switch_user', 'health'):
            return
        if g.current_user and not can_access_page(role_code, request.path, user_id=session.get('user_id')) and request.path not in ['/search'] and not request.path.startswith('/inquiry/') and not request.path.startswith('/workflow/'):
            abort(403)

    @app.context_processor
    def inject():
        landing_layout = preference_service.get_landing_layout(session.get('user_id')) if session.get('user_id') else None
        return dict(theme=g.theme, branding=g.branding, nav_links=g.nav_links, users=g.users, current_user=g.current_user, feature_flags=g.feature_flags, landing_layout=landing_layout)

    @app.route('/login')
    def login():
        return render_template('login.html')

    def _home_for(user_id):
        """Resolve the right landing page for a freshly-logged-in user.
        Order of precedence:
          1. User's `landing_layout` preference (portal | dashboard | profile)
          2. Role default — EMPLOYEE → /me/profile; everyone else → dashboard.
        """
        try:
            from services import preference_service
            layout = preference_service.get_landing_layout(user_id)
            if layout == 'portal':
                return url_for('dashboard.portal')
            if layout == 'dashboard':
                return url_for('dashboard.index')
            if layout == 'profile':
                return url_for('ess.my_profile')

            # Fallback: existing role-based default
            with get_cursor() as cur:
                cur.execute("""
                    SELECT COALESCE(r.code, u.role_code) AS role_code,
                           u.employee_id
                      FROM core.users u
                      LEFT JOIN core.user_roles ur ON ur.user_id = u.id
                      LEFT JOIN core.roles r       ON r.id = ur.role_id
                     WHERE u.id = %s LIMIT 1
                """, (user_id,))
                row = cur.fetchone()
                if row and row['role_code'] == 'EMPLOYEE' and row.get('employee_id'):
                    return url_for('ess.my_profile')
        except Exception:
            pass
        return url_for('dashboard.index')

    @app.route('/login/select', methods=['POST'])
    def do_login():
        uid = int(request.form['user_id'])
        session['user_id'] = uid
        return redirect(_home_for(uid))

    @app.route('/logout', methods=['POST'])
    def logout():
        session.clear()
        return redirect(url_for('login'))

    @app.route('/switch-user', methods=['POST'])
    def switch_user():
        uid = int(request.form['user_id'])
        session['user_id'] = uid
        # Clear cached role/employee so before_request re-derives from the new user
        session.pop('role_code', None)
        session.pop('employee_id', None)
        return redirect(_home_for(uid))

    @app.route('/health')
    def health():
        return {'status': 'ok', 'app': 'HCM360 HRIS v2.0'}

    # ── Serve uploaded files (profile photos, attachments, etc.) ──
    # Authenticated only — anyone signed in can view; unauthenticated
    # requests bounce to /login via the before_request guard above.
    @app.route('/uploads/<path:filename>')
    def serve_upload(filename):
        from flask import send_from_directory
        upload_root = app.config.get('UPLOAD_FOLDER', '/app/uploads')
        return send_from_directory(upload_root, filename, max_age=3600)

    return app


if __name__ == '__main__':
    create_app().run(host='0.0.0.0', port=5000, debug=True)
