"""
Demo Seed Service — manages demo profile activation, clearing, and truncation.
Provides three toggleable scenarios across all HCM360 modules.
"""
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from services.db import get_cursor


def _direct_conn():
    """Get a direct psycopg2 connection (bypasses Flask request context)."""
    from flask import current_app
    return psycopg2.connect(current_app.config['DATABASE_URL'])


# ── Protected entities (never deleted) ──────────────────────────
ADMIN_USERNAMES = ('capsanchez', 'superadmin')

# Reference/config tables to PRESERVE during truncate
PRESERVED_TABLES = [
    'core.companies', 'core.departments', 'core.positions', 'core.job_grades',
    'core.employment_types', 'core.roles', 'core.user_roles',
    'core.page_registry', 'core.role_page_access', 'core.feature_registry',
    'core.dashboard_metrics', 'core.company_branding', 'core.themes',
    'core.demo_profiles', 'core.employee_status_defs',
    'leave_mgmt.lv_types', 'leave_mgmt.lv_policies', 'leave_mgmt.lv_holidays',
    'attendance.att_shifts', 'attendance.att_holiday_types', 'attendance.att_holidays',
    'payroll.pay_gsis_schedule', 'payroll.pay_pagibig_schedule',
    'payroll.pay_bir_tax_table', 'payroll.pay_gov_allowances',
    'payroll.pay_rata_schedule', 'payroll.pay_sss_schedule',
    'payroll.pay_philhealth_schedule', 'payroll.pay_tax_tables',
    'payroll.pay_rate_tables', 'payroll.pay_config',
    'rewards.rwd_ssl_table', 'rewards.rwd_praise_config', 'rewards.rwd_categories',
    'workflow.workflow_definitions', 'workflow.workflow_steps',
    'analytics.report_data_sources', 'analytics.report_field_registry',
    'analytics.dim_date',
    'discipline.case_types',
    'dms.document_categories', 'dms.checklist_templates', 'dms.certificate_types',
    'dms.retention_policies',
    'recruitment.rec_csc_eligibilities', 'recruitment.rec_qualification_standards',
]

# Transactional tables to clear (FK-safe order — children first)
# Key cross-module FK constraints that determine ordering:
#   rewards.rwd_pbb_records.ipcr_summary_id → performance.perf_ipcr_summary
#   learning.lrn_idp_actions.idp_plan_id    → performance.perf_idp_plans
# Therefore: Rewards + Learning must be deleted BEFORE Performance.
CLEAR_ORDER = [
    # Analytics (no FK deps on other transactional tables)
    'analytics.report_run_history', 'analytics.report_schedules', 'analytics.saved_reports',
    'analytics.fact_training', 'analytics.fact_payroll', 'analytics.fact_leave',
    'analytics.fact_attendance', 'analytics.dim_employee', 'analytics.dim_department',
    'analytics.dim_position', 'analytics.kpi_snapshots',
    # Workflow
    'workflow.workflow_action_logs', 'workflow.instance_checklist_items',
    'workflow.workflow_instances',
    # Rewards — rwd_pbb_records.ipcr_summary_id → perf_ipcr_summary (must come before Performance)
    'rewards.rwd_retirement_alerts', 'rewards.rwd_retirement_plans',
    'rewards.rwd_pbb_records', 'rewards.rwd_loyalty_milestones',
    'rewards.rwd_step_increments', 'rewards.rwd_awards',
    'rewards.rwd_nominations',
    # Learning — lrn_idp_actions.idp_plan_id → perf_idp_plans (must come before Performance)
    'learning.lrn_attendance_logs', 'learning.lrn_narrative_reports',
    'learning.lrn_idp_actions', 'learning.lrn_tna_entries',
    'learning.lrn_enrollments', 'learning.lrn_sessions',
    'learning.lrn_scholarships', 'learning.lrn_programs',
    'learning.lrn_employee_skills', 'learning.lrn_skills',
    'learning.lrn_lsp_registry',
    # Performance (after Rewards + Learning)
    'performance.perf_succession_matrix', 'performance.perf_ipcr_summary',
    'performance.perf_ipcr', 'performance.perf_opcr',
    'performance.perf_reviews', 'performance.perf_employee_kpis',
    'performance.perf_idp_plans', 'performance.perf_competencies',
    'performance.perf_strategic_plans', 'performance.perf_cycles',
    # Payroll
    'payroll.pay_loan_payments', 'payroll.pay_loans',
    'payroll.pay_13th_month', 'payroll.pay_annual_bonuses',
    'payroll.pay_government_remittances', 'payroll.pay_employee_payroll',
    'payroll.pay_employee_allowances', 'payroll.pay_employee_allowances_gov',
    'payroll.pay_coop_members', 'payroll.pay_runs', 'payroll.pay_periods',
    # Attendance
    'attendance.att_overtime_requests', 'attendance.att_dtr_corrections',
    'attendance.att_shift_assignments', 'attendance.att_daily',
    # Leave
    'leave_mgmt.lv_approvals', 'leave_mgmt.lv_ledger',
    'leave_mgmt.lv_cto_credits', 'leave_mgmt.lv_travel_orders',
    'leave_mgmt.lv_locator_entries', 'leave_mgmt.lv_requests',
    'leave_mgmt.lv_balances',
    # Recruitment
    'recruitment.rec_next_in_rank_list', 'recruitment.rec_psb_scores',
    'recruitment.rec_psb_deliberations', 'recruitment.rec_psb_members',
    'recruitment.rec_publications', 'recruitment.rec_employee_eligibilities',
    'recruitment.rec_offers', 'recruitment.rec_interview_schedules',
    'recruitment.rec_appointments', 'recruitment.rec_applicants',
    'recruitment.rec_job_postings', 'recruitment.rec_requisitions',
    'recruitment.rec_plantilla_items',
    # Onboarding
    'onboarding.offb_clearance_items', 'onboarding.offb_exit_interviews',
    'onboarding.onb_buddy_assignments', 'onboarding.onb_checklist_items',
    'onboarding.onb_checklists', 'onboarding.onb_pre_employment_reqs',
    # DMS
    'dms.document_requests', 'dms.certificate_requests',
    'dms.service_record_snapshots', 'dms.checklist_items',
    # Discipline
    'discipline.appeals', 'discipline.decisions',
    'discipline.hearings', 'discipline.formal_charges',
    'discipline.investigations', 'discipline.preventive_suspensions',
    'discipline.complaints', 'discipline.cases',
    # Health
    'health.wellness_enrollments', 'health.wellness_programs',
    'health.health_certificates', 'health.pe_results', 'health.pe_schedules',
    'health.incident_investigations', 'health.incident_persons',
    'health.incidents', 'health.medical_records',
    # Notifications
    'notifications.ntf_in_app',
]


def get_profiles():
    """Return all 3 demo profiles with active status."""
    conn = _direct_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("SELECT * FROM core.demo_profiles ORDER BY id")
    rows = cur.fetchall()
    cur.close(); conn.close()
    return rows


def get_active_profile():
    """Return currently active profile or None."""
    conn = _direct_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("SELECT * FROM core.demo_profiles WHERE is_active = TRUE LIMIT 1")
    row = cur.fetchone()
    cur.close(); conn.close()
    return row


def get_record_counts():
    """Quick counts across key tables for the status panel."""
    counts = {}
    conn = _direct_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    for label, table in [
        ('Employees', 'core.employees'),
        ('Users', 'core.users'),
        ('Attendance', 'attendance.att_daily'),
        ('Leave Requests', 'leave_mgmt.lv_requests'),
        ('Pay Runs', 'payroll.pay_runs'),
        ('Plantilla', 'recruitment.rec_plantilla_items'),
        ('PM Cycles', 'performance.perf_cycles'),
        ('IPCRs', 'performance.perf_ipcr'),
        ('Programs', 'learning.lrn_programs'),
        ('Step Inc.', 'rewards.rwd_step_increments'),
        ('Disc. Cases', 'discipline.cases'),
        ('PE Sched.', 'health.pe_schedules'),
    ]:
        try:
            cur.execute(f"SELECT COUNT(*) FROM {table}")
            counts[label] = cur.fetchone()['count']
        except Exception:
            conn.rollback()
            counts[label] = 0
    cur.close(); conn.close()
    return counts


def clear_all_demo_data():
    """
    Clear all transactional/demo data. Preserve base 20 employees + 11 users.
    Delete extra employees (EMP-021+) and their linked users.
    Uses SAVEPOINTs so one table failure doesn't roll back everything.
    """
    conn = _direct_conn()
    conn.autocommit = False
    cur = conn.cursor()
    try:
        for table in CLEAR_ORDER:
            try:
                cur.execute(f"SAVEPOINT sp_{table.replace('.','_')}")
                cur.execute(f"DELETE FROM {table}")
            except Exception:
                cur.execute(f"ROLLBACK TO SAVEPOINT sp_{table.replace('.','_')}")

        cur.execute("""
            DELETE FROM core.users
            WHERE employee_id IN (
                SELECT id FROM core.employees WHERE employee_no > 'EMP-020'
            )
        """)
        cur.execute("DELETE FROM core.employees WHERE employee_no > 'EMP-020'")
        cur.execute("UPDATE core.demo_profiles SET is_active = FALSE, loaded_at = NULL, loaded_by = NULL")
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        cur.close(); conn.close()


def truncate_all_transactional():
    """
    Nuclear reset — delete ALL employees, non-admin users, and every transactional
    record. Preserves ONLY app metadata/config/reference tables and admin users.
    Uses SAVEPOINTs so one table failure does not roll back prior successful deletes.
    """
    conn = _direct_conn()
    conn.autocommit = False
    cur = conn.cursor()
    try:
        for table in CLEAR_ORDER:
            sp = f"sp_{table.replace('.', '_')}"
            try:
                cur.execute(f"SAVEPOINT {sp}")
                cur.execute(f"DELETE FROM {table}")
            except Exception:
                cur.execute(f"ROLLBACK TO SAVEPOINT {sp}")

        # Remove non-admin users and all employees
        cur.execute("""
            DELETE FROM core.user_roles
            WHERE user_id NOT IN (
                SELECT id FROM core.users WHERE username IN %s
            )
        """, (ADMIN_USERNAMES,))
        cur.execute("DELETE FROM core.users WHERE username NOT IN %s", (ADMIN_USERNAMES,))
        cur.execute("DELETE FROM core.employees")
        cur.execute("UPDATE core.demo_profiles SET is_active = FALSE, loaded_at = NULL, loaded_by = NULL")
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        cur.close(); conn.close()


def activate_profile(code, user_id):
    """Clear existing demo data then load the selected profile."""
    # Verify profile exists
    conn = _direct_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("SELECT id FROM core.demo_profiles WHERE code = %s", (code,))
    profile = cur.fetchone()
    cur.close(); conn.close()
    if not profile:
        return False

    # Step 1: Clear
    clear_all_demo_data()

    # Step 2: Execute seed SQL
    # YEAR_END depends on data created by MID_CYCLE (REQ-2026-001/002, EMP-031/034)
    # so run MID_CYCLE first when activating YEAR_END.
    seed_files = {
        'QUICK_START':   ['38_demo_quick_start.sql'],
        'MID_CYCLE':     ['39_demo_mid_cycle.sql'],
        'YEAR_END':      ['39_demo_mid_cycle.sql', '40_demo_year_end.sql'],
        'FULL_FEATURES': ['39_demo_mid_cycle.sql', '40_demo_year_end.sql', '41_demo_full_features.sql'],
    }
    for filename in seed_files.get(code, []):
        _execute_seed_file(filename)

    # Step 3: Mark active
    conn = _direct_conn()
    cur = conn.cursor()
    cur.execute("UPDATE core.demo_profiles SET is_active = FALSE")
    cur.execute("""
        UPDATE core.demo_profiles
        SET is_active = TRUE, loaded_at = NOW(), loaded_by = %s
        WHERE code = %s
    """, (user_id, code))
    conn.commit()
    cur.close(); conn.close()

    return True


def _execute_seed_file(filename):
    """Execute a SQL seed file from the db/ directory using direct psycopg2 connection."""
    import psycopg2
    from flask import current_app

    db_dir = os.path.join(current_app.config.get('PROJECT_ROOT', '.'), 'db')
    filepath = os.path.join(db_dir, filename)

    if not os.path.isfile(filepath):
        raise FileNotFoundError(f"Seed file not found: {filepath}")

    with open(filepath, 'r') as f:
        sql = f.read()

    # Remove \i directives (psycopg2 doesn't support them) — inline the referenced files
    import re
    def resolve_includes(sql_text, base_dir):
        pattern = r'\\i\s+(/app/db/|)(\S+\.sql)'
        while re.search(pattern, sql_text):
            match = re.search(pattern, sql_text)
            inc_file = os.path.join(base_dir, match.group(2))
            if os.path.isfile(inc_file):
                with open(inc_file, 'r') as inc:
                    inc_sql = inc.read()
                # Recursively resolve includes in the included file
                inc_sql = resolve_includes(inc_sql, base_dir)
                sql_text = sql_text[:match.start()] + inc_sql + sql_text[match.end():]
            else:
                raise FileNotFoundError(f"Included file not found: {inc_file}")
        return sql_text

    sql = resolve_includes(sql, db_dir)

    # Set search path and execute
    conn = psycopg2.connect(current_app.config['DATABASE_URL'])
    try:
        cur = conn.cursor()
        cur.execute("""SET search_path TO core, workflow, notifications, audit_logs,
                       attendance, leave_mgmt, recruitment, onboarding,
                       performance, learning, rewards, payroll,
                       analytics, ai, dms, discipline, health, public""")
        cur.execute(sql)
        conn.commit()
        cur.close()
    except Exception as e:
        conn.rollback()
        import logging
        logging.getLogger(__name__).error(f"Seed file {filename} failed: {e}")
        raise
    finally:
        conn.close()
