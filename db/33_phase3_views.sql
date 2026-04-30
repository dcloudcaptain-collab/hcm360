-- ================================================================
-- HCM360 HRIS — 33: PHASE 3 VIEWS
-- ================================================================

-- ----------------------------------------------------------------
-- DMS: Document completeness per employee
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW dms.v_document_completeness AS
SELECT
    e.id AS employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    d.name AS department_name,
    COUNT(DISTINCT ci.id) AS required_count,
    COUNT(DISTINCT doc.id) AS submitted_count,
    CASE WHEN COUNT(DISTINCT ci.id) > 0
         THEN ROUND(COUNT(DISTINCT doc.id)::NUMERIC / COUNT(DISTINCT ci.id) * 100, 0)
         ELSE 0 END AS pct_complete
FROM core.employees e
LEFT JOIN core.departments d ON d.id = e.department_id
LEFT JOIN dms.checklist_templates ct
    ON ct.company_id = e.company_id
    AND (ct.employment_type_id IS NULL OR ct.employment_type_id = e.employment_type_id)
    AND ct.is_active = TRUE
LEFT JOIN dms.checklist_items ci ON ci.template_id = ct.id
LEFT JOIN core.documents doc
    ON doc.employee_id = e.id
    AND doc.document_type = ci.document_type
    AND doc.status != 'REJECTED'
WHERE e.is_active = TRUE
GROUP BY e.id, e.first_name, e.last_name, d.name;

-- ----------------------------------------------------------------
-- DMS: Documents approaching retention deadline
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW dms.v_retention_due AS
SELECT
    doc.id AS document_id,
    doc.employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    doc.document_name,
    doc.document_type,
    doc.retention_until,
    doc.retention_until - CURRENT_DATE AS days_remaining,
    rp.disposal_method
FROM core.documents doc
JOIN core.employees e ON e.id = doc.employee_id
LEFT JOIN dms.document_categories dc ON dc.id = doc.category_id
LEFT JOIN dms.retention_policies rp ON rp.category_id = dc.id
WHERE doc.retention_until IS NOT NULL
  AND doc.is_archived = FALSE
  AND doc.retention_until <= CURRENT_DATE + INTERVAL '90 days';

-- ----------------------------------------------------------------
-- Discipline: Case summary
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW discipline.v_case_summary AS
SELECT
    c.id, c.case_no, c.status, c.date_filed, c.is_confidential,
    c.offense_description,
    ct.name AS offense_type, ct.gravity,
    e.first_name || ' ' || e.last_name AS respondent_name,
    d.name AS department_name,
    CURRENT_DATE - c.date_filed AS days_since_filed,
    c.assigned_to,
    u_assigned.display_name AS assigned_to_name
FROM discipline.cases c
JOIN discipline.case_types ct ON ct.id = c.case_type_id
JOIN core.employees e ON e.id = c.respondent_id
LEFT JOIN core.departments d ON d.id = e.department_id
LEFT JOIN core.users u_assigned ON u_assigned.id = c.assigned_to;

-- ----------------------------------------------------------------
-- Discipline: Active preventive suspensions
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW discipline.v_active_suspensions AS
SELECT
    ps.*,
    e.first_name || ' ' || e.last_name AS employee_name,
    c.case_no,
    ps.end_date - CURRENT_DATE AS days_remaining
FROM discipline.preventive_suspensions ps
JOIN core.employees e ON e.id = ps.employee_id
JOIN discipline.cases c ON c.id = ps.case_id
WHERE ps.is_active = TRUE AND ps.end_date >= CURRENT_DATE;

-- ----------------------------------------------------------------
-- Health: PE compliance by department
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW health.v_pe_compliance AS
SELECT
    ps.id AS schedule_id, ps.year, ps.title,
    d.id AS department_id, d.name AS department_name,
    COUNT(e.id) AS total_employees,
    COUNT(pr.id) FILTER (WHERE pr.overall_result != 'PENDING' AND pr.overall_result != 'NO_SHOW') AS examined_count,
    COUNT(pr.id) FILTER (WHERE pr.overall_result = 'NO_SHOW') AS no_show_count,
    CASE WHEN COUNT(e.id) > 0
         THEN ROUND(COUNT(pr.id) FILTER (WHERE pr.overall_result NOT IN ('PENDING', 'NO_SHOW'))::NUMERIC / COUNT(e.id) * 100, 0)
         ELSE 0 END AS compliance_pct
FROM health.pe_schedules ps
CROSS JOIN core.departments d
JOIN core.employees e ON e.department_id = d.id AND e.is_active = TRUE AND e.company_id = ps.company_id
LEFT JOIN health.pe_results pr ON pr.schedule_id = ps.id AND pr.employee_id = e.id
GROUP BY ps.id, ps.year, ps.title, d.id, d.name;

-- ----------------------------------------------------------------
-- Health: Expiring certificates within 60 days
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW health.v_expiring_certificates AS
SELECT
    hc.id, hc.employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    d.name AS department_name,
    hc.certificate_type,
    hc.expiry_date,
    hc.expiry_date - CURRENT_DATE AS days_until_expiry
FROM health.health_certificates hc
JOIN core.employees e ON e.id = hc.employee_id
LEFT JOIN core.departments d ON d.id = e.department_id
WHERE hc.status = 'ACTIVE'
  AND hc.expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 60;

-- ----------------------------------------------------------------
-- Health: Incident summary for dashboard
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW health.v_incident_summary AS
SELECT
    i.company_id,
    EXTRACT(YEAR FROM i.incident_date) AS year,
    EXTRACT(MONTH FROM i.incident_date) AS month,
    i.incident_type,
    i.severity,
    COUNT(*) AS incident_count,
    SUM(ip.days_lost) AS total_days_lost
FROM health.incidents i
LEFT JOIN health.incident_persons ip ON ip.incident_id = i.id
GROUP BY i.company_id, EXTRACT(YEAR FROM i.incident_date), EXTRACT(MONTH FROM i.incident_date),
         i.incident_type, i.severity;
