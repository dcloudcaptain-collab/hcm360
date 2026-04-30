-- ================================================================
-- HCM360 HRIS — 15: AUDIT TRIGGERS
-- Installs fn_capture_change() on all tracked tables
-- Installs fn_capture_status_change() on status-bearing tables
-- Run after: 04_audit_logs.sql and all module schemas
-- ================================================================

SET search_path TO audit_logs, core, attendance, leave_mgmt, payroll,
    performance, learning, recruitment, workflow, public;

-- ── Helper shorthand ──────────────────────────────────────────────

-- Install change trigger on any schema.table
CREATE OR REPLACE FUNCTION audit_logs.install_trigger(p_schema TEXT, p_table TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    PERFORM audit_logs.fn_install_change_trigger(p_schema, p_table);
END;
$$;

-- ── core schema ───────────────────────────────────────────────────
SELECT audit_logs.install_trigger('core', 'companies');
SELECT audit_logs.install_trigger('core', 'departments');
SELECT audit_logs.install_trigger('core', 'positions');
SELECT audit_logs.install_trigger('core', 'job_grades');
SELECT audit_logs.install_trigger('core', 'employment_types');
SELECT audit_logs.install_trigger('core', 'users');
SELECT audit_logs.install_trigger('core', 'employees');
SELECT audit_logs.install_trigger('core', 'emp_addresses');
SELECT audit_logs.install_trigger('core', 'emp_emergency_contacts');
SELECT audit_logs.install_trigger('core', 'emp_government_ids');
SELECT audit_logs.install_trigger('core', 'emp_bank_accounts');
SELECT audit_logs.install_trigger('core', 'emp_dependents');
SELECT audit_logs.install_trigger('core', 'emp_education');
SELECT audit_logs.install_trigger('core', 'emp_work_history');
SELECT audit_logs.install_trigger('core', 'emp_status_history');
SELECT audit_logs.install_trigger('core', 'documents');

-- ── attendance schema ─────────────────────────────────────────────
SELECT audit_logs.install_trigger('attendance', 'att_shifts');
SELECT audit_logs.install_trigger('attendance', 'att_shift_assignments');
SELECT audit_logs.install_trigger('attendance', 'att_holidays');
SELECT audit_logs.install_trigger('attendance', 'att_daily');
SELECT audit_logs.install_trigger('attendance', 'att_overtime_requests');
SELECT audit_logs.install_trigger('attendance', 'att_dtr_corrections');

-- ── leave_mgmt schema ─────────────────────────────────────────────
SELECT audit_logs.install_trigger('leave_mgmt', 'lv_types');
SELECT audit_logs.install_trigger('leave_mgmt', 'lv_policies');
SELECT audit_logs.install_trigger('leave_mgmt', 'lv_balances');
SELECT audit_logs.install_trigger('leave_mgmt', 'lv_requests');
SELECT audit_logs.install_trigger('leave_mgmt', 'lv_approvals');
SELECT audit_logs.install_trigger('leave_mgmt', 'lv_travel_orders');

-- ── payroll schema ────────────────────────────────────────────────
SELECT audit_logs.install_trigger('payroll', 'pay_periods');
SELECT audit_logs.install_trigger('payroll', 'pay_runs');
SELECT audit_logs.install_trigger('payroll', 'pay_employee_payroll');
SELECT audit_logs.install_trigger('payroll', 'pay_loans');

-- ── workflow schema ───────────────────────────────────────────────
SELECT audit_logs.install_trigger('workflow', 'workflow_instances');
SELECT audit_logs.install_trigger('workflow', 'workflow_action_logs');

-- ── performance schema ────────────────────────────────────────────
SELECT audit_logs.install_trigger('performance', 'perf_reviews');
SELECT audit_logs.install_trigger('performance', 'perf_employee_kpis');

-- ── recruitment schema ────────────────────────────────────────────
SELECT audit_logs.install_trigger('recruitment', 'rec_applicants');
SELECT audit_logs.install_trigger('recruitment', 'rec_requisitions');

-- ── learning schema ───────────────────────────────────────────────
SELECT audit_logs.install_trigger('learning', 'lrn_enrollments');

-- ── Status transition triggers ────────────────────────────────────

CREATE TRIGGER trg_status_transition
AFTER UPDATE OF status ON core.employees
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION audit_logs.fn_capture_status_change();

CREATE TRIGGER trg_status_transition
AFTER UPDATE OF status ON leave_mgmt.lv_requests
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION audit_logs.fn_capture_status_change();

CREATE TRIGGER trg_status_transition
AFTER UPDATE OF status ON payroll.pay_runs
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION audit_logs.fn_capture_status_change();

CREATE TRIGGER trg_status_transition
AFTER UPDATE OF status ON workflow.workflow_instances
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION audit_logs.fn_capture_status_change();

CREATE TRIGGER trg_status_transition
AFTER UPDATE OF status ON attendance.att_overtime_requests
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION audit_logs.fn_capture_status_change();

CREATE TRIGGER trg_status_transition
AFTER UPDATE OF status ON payroll.pay_loans
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION audit_logs.fn_capture_status_change();
