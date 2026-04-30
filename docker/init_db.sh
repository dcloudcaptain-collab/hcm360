#!/usr/bin/env bash
# =============================================================================
# HCM360 — Database auto-initialisation script
#
# Executed by PostgreSQL on first container start (when the data directory is
# empty). On subsequent starts the data directory is already populated so
# PostgreSQL skips this script entirely — existing data is NEVER touched.
#
# Data truncation is handled exclusively through the HCM360 admin panel by
# capsanchez / SUPER_ADMIN users.
# =============================================================================
set -euo pipefail

SQL_DIR="/docker-entrypoint-initdb.d/sql"

run() {
    echo "[init_db] Running $1 ..."
    psql -v ON_ERROR_STOP=0 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$SQL_DIR/$1"
}

# ── Schema & extensions ───────────────────────────────────────────
run 00_extensions.sql
run 01_core.sql
run 02_workflow.sql
run 03_notifications.sql
run 04_audit_logs.sql
run 05_attendance.sql
run 06_leave_mgmt.sql
run 07_recruitment.sql
run 08_onboarding.sql
run 09_performance.sql
run 10_learning.sql
run 11_rewards.sql
run 12_payroll.sql
run 13_analytics.sql
run 14_ai.sql
run 15_triggers.sql
run 16_views.sql

# ── Reference & seed data ─────────────────────────────────────────
run 17_seed_core.sql
run 18_seed_modules.sql
run 19_seed_analytics.sql

# ── Module extensions ─────────────────────────────────────────────
run 20_rsp_extensions.sql
run 21_pm_extensions.sql
run 22_ld_extensions.sql
run 23_rr_extensions.sql
run 24_payroll_gov_extensions.sql
run 25_phase2_triggers.sql
run 26_phase2_views.sql
run 27_phase2_seeds.sql
run 29_dms_extensions.sql
run 30_discipline.sql
run 31_health_safety.sql
run 32_phase3_triggers.sql
run 33_phase3_views.sql
run 34_phase3_seeds.sql
run 35_phase4_extensions.sql
run 36_report_builder.sql

# ── Demo profiles (structure only — no transactional data loaded) ─
run 37_demo_profiles.sql

# ── Access matrix ─────────────────────────────────────────────────
run 41_modification_access.sql
run 42_access_matrix_v2.sql
run 43_access_matrix_features_v2.sql
run 44_fix_employee_page_access.sql

# ── Schema patches ────────────────────────────────────────────────
run 45_patch_schema.sql
run 46_access_matrix_final.sql

# ── Phase-5 / module enhancements (50-series) ─────────────────────
run 10a_benefits.sql
run 50_field_privacy.sql
run 51_workforce_planning_access.sql
run 52_face_checkin.sql
run 53_step_increment_retirement.sql
run 54_lgu_critical_gaps.sql
run 55_remaining_gaps.sql
run 56_wfp_schema.sql
run 57_tour_system.sql
run 58_report_builder_sources.sql
run 60_requisitions_feature.sql
run 61_data_source_access.sql
run 61_task_management.sql
run 62_employee_groups.sql
run 63_retirement_rule_profiles.sql
run 64_wellness_enhancements.sql
run 65_new_module_tours.sql
run 66_access_requests.sql
run 67_analytics_library.sql
run 68_login_branding.sql
run 69_dashboard_library.sql
run 70_reminder_log.sql
run 71_green_theme.sql
run 72_emerald_mint_theme.sql
run 73_dashboard_widgets.sql
run 74_ipcr_csc_templates.sql
run 75_portal_landing.sql

# ── Menu realignment (must run after all page_registry inserts) ───
run 76_menu_realignment.sql
run 77_access_matrix_realignment.sql
run 78_role_taxonomy.sql

echo "[init_db] Initialisation complete."
