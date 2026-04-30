-- ================================================================
-- HCM360 HRIS — 32: PHASE 3 AUDIT TRIGGER INSTALLATION
-- ================================================================
SET search_path TO audit_logs, public;

-- DMS
SELECT audit_logs.fn_install_change_trigger('dms', 'document_categories');
SELECT audit_logs.fn_install_change_trigger('dms', 'retention_policies');
SELECT audit_logs.fn_install_change_trigger('dms', 'document_requests');
SELECT audit_logs.fn_install_change_trigger('dms', 'service_record_snapshots');

-- Discipline
SELECT audit_logs.fn_install_change_trigger('discipline', 'cases');
SELECT audit_logs.fn_install_change_trigger('discipline', 'complaints');
SELECT audit_logs.fn_install_change_trigger('discipline', 'investigations');
SELECT audit_logs.fn_install_change_trigger('discipline', 'formal_charges');
SELECT audit_logs.fn_install_change_trigger('discipline', 'preventive_suspensions');
SELECT audit_logs.fn_install_change_trigger('discipline', 'hearings');
SELECT audit_logs.fn_install_change_trigger('discipline', 'decisions');
SELECT audit_logs.fn_install_change_trigger('discipline', 'appeals');

-- Health
SELECT audit_logs.fn_install_change_trigger('health', 'medical_records');
SELECT audit_logs.fn_install_change_trigger('health', 'pe_results');
SELECT audit_logs.fn_install_change_trigger('health', 'incidents');
SELECT audit_logs.fn_install_change_trigger('health', 'incident_investigations');
SELECT audit_logs.fn_install_change_trigger('health', 'health_certificates');
SELECT audit_logs.fn_install_change_trigger('health', 'wellness_programs');
