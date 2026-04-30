"""Standalone Attendance & Payroll application."""
from flask import Flask, g, redirect, render_template, request, session, url_for
from config import Config
from services.db import get_cursor


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    # Register blueprints
    from routes.attendance import attendance_bp
    from routes.payroll import payroll_bp
    from routes.config import config_bp

    app.register_blueprint(attendance_bp)
    app.register_blueprint(payroll_bp)
    app.register_blueprint(config_bp)

    # ── Login / Logout ─────────────────────────────────────────────
    @app.route('/login', methods=['GET', 'POST'])
    def login():
        if request.method == 'POST':
            user_id = request.form.get('user_id', type=int)
            if user_id:
                session['user_id'] = user_id
                return redirect('/')
        with get_cursor() as cur:
            cur.execute("""
                SELECT u.id, u.display_name, u.role_code
                FROM core.users u
                WHERE u.is_active = TRUE
                ORDER BY u.display_name
            """)
            users = cur.fetchall()
        return render_template('login.html', users=users)

    @app.route('/logout', methods=['POST'])
    def logout():
        session.clear()
        return redirect('/login')

    @app.route('/switch-user', methods=['POST'])
    def switch_user():
        uid = request.form.get('user_id', type=int)
        if uid:
            session['user_id'] = uid
        return redirect(request.referrer or '/')

    # ── Dashboard redirect ─────────────────────────────────────────
    @app.route('/')
    def index():
        if 'user_id' not in session:
            return redirect('/login')
        return redirect('/payroll/')

    # ── Before request: load user context ──────────────────────────
    @app.before_request
    def load_context():
        g.current_user = None
        g.company_id = 1

        # Skip auth for login, static assets, and device API endpoints
        if request.endpoint in ('login', 'static'):
            return
        if request.path.startswith('/attendance/api/'):
            return

        user_id = session.get('user_id')
        if not user_id:
            if request.endpoint not in ('login', 'logout'):
                return redirect('/login')
            return

        try:
            with get_cursor() as cur:
                cur.execute("""
                    SELECT u.id, u.display_name, u.email, u.role_code,
                           u.employee_id
                    FROM core.users u
                    WHERE u.id = %s AND u.is_active = TRUE
                """, (user_id,))
                user = cur.fetchone()
        except Exception:
            user = None

        if not user:
            session.clear()
            return redirect('/login')

        g.current_user = user
        session['employee_id'] = user.get('employee_id')
        session['role_code'] = user.get('role_code')

        # Determine company_id from employee
        if user.get('employee_id'):
            try:
                with get_cursor() as cur:
                    cur.execute("""
                        SELECT company_id FROM core.employees WHERE id = %s
                    """, (user['employee_id'],))
                    emp = cur.fetchone()
                    if emp:
                        g.company_id = emp['company_id']
            except Exception:
                pass

    # ── Context processor ──────────────────────────────────────────
    @app.context_processor
    def inject_globals():
        users = []
        try:
            with get_cursor() as cur:
                cur.execute("""
                    SELECT id, display_name, role_code
                    FROM core.users WHERE is_active = TRUE
                    ORDER BY display_name
                """)
                users = cur.fetchall()
        except Exception:
            pass

        return {
            'current_user': g.get('current_user'),
            'users': users,
        }

    return app


if __name__ == '__main__':
    app = create_app()
    app.run(debug=True, port=Config.PORT, host='0.0.0.0')
