-- ================================================================
-- HCM360 HRIS — 25: PHASE 2 AUDIT TRIGGER INSTALLATION
-- Installs change-capture triggers on all Phase 2 tables
-- ================================================================
SET search_path TO audit_logs, public;

-- RSP
SELECT audit_logs.fn_install_change_trigger('recruitment', 'rec_appointments');
SELECT audit_logs.fn_install_change_trigger('recruitment', 'rec_applicants');
SELECT audit_logs.fn_install_change_trigger('recruitment', 'rec_psb_scores');
SELECT audit_logs.fn_install_change_trigger('recruitment', 'rec_plantilla_items');
SELECT audit_logs.fn_install_change_trigger('recruitment', 'rec_next_in_rank_list');

-- Onboarding
SELECT audit_logs.fn_install_change_trigger('onboarding', 'onb_pre_employment_reqs');
SELECT audit_logs.fn_install_change_trigger('onboarding', 'offb_clearance_items');

-- Performance
SELECT audit_logs.fn_install_change_trigger('performance', 'perf_ipcr');
SELECT audit_logs.fn_install_change_trigger('performance', 'perf_ipcr_summary');
SELECT audit_logs.fn_install_change_trigger('performance', 'perf_opcr');
SELECT audit_logs.fn_install_change_trigger('performance', 'perf_succession_matrix');

-- Learning
SELECT audit_logs.fn_install_change_trigger('learning', 'lrn_scholarships');
SELECT audit_logs.fn_install_change_trigger('learning', 'lrn_attendance_logs');
SELECT audit_logs.fn_install_change_trigger('learning', 'lrn_narrative_reports');

-- Rewards
SELECT audit_logs.fn_install_change_trigger('rewards', 'rwd_step_increments');
SELECT audit_logs.fn_install_change_trigger('rewards', 'rwd_pbb_records');
SELECT audit_logs.fn_install_change_trigger('rewards', 'rwd_loyalty_milestones');
SELECT audit_logs.fn_install_change_trigger('rewards', 'rwd_retirement_alerts');

-- Payroll (government extensions)
SELECT audit_logs.fn_install_change_trigger('payroll', 'pay_employee_payroll');
SELECT audit_logs.fn_install_change_trigger('payroll', 'pay_annual_bonuses');
SELECT audit_logs.fn_install_change_trigger('payroll', 'pay_coop_members');
