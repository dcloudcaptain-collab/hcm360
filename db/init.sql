CREATE EXTENSION IF NOT EXISTS pgcrypto;
DROP TABLE IF EXISTS orchestration_steps, orchestration_flows, kpi_query_registry, form_fields, dynamic_forms, role_feature_access, feature_registry, workflow_action_logs, instance_checklist_items, role_page_access, transaction_timeline, transaction_qr_tokens, transaction_registry, search_index, dashboard_metrics,page_registry, ui_themes, company_branding, workflow_instances, workflow_routes, workflow_steps, workflow_definitions,workflow_checklist_items, workflow_checklists, employee_documents, employees, positions, departments, users, status_definitions CASCADE;

CREATE TABLE status_definitions (id SERIAL PRIMARY KEY,status_group VARCHAR(60) NOT NULL,status_code VARCHAR(60) NOT NULL,status_label VARCHAR(120) NOT NULL,badge_color VARCHAR(30),is_terminal BOOLEAN DEFAULT FALSE,sort_order INT DEFAULT 0);
CREATE TABLE users (id SERIAL PRIMARY KEY,display_name VARCHAR(120) NOT NULL,email VARCHAR(120) NOT NULL,role_code VARCHAR(50) NOT NULL,is_active BOOLEAN DEFAULT TRUE);
CREATE TABLE departments (id SERIAL PRIMARY KEY,name VARCHAR(120) NOT NULL);
CREATE TABLE positions (id SERIAL PRIMARY KEY,title VARCHAR(120) NOT NULL);
CREATE TABLE employees (id SERIAL PRIMARY KEY,employee_no VARCHAR(30) UNIQUE NOT NULL,first_name VARCHAR(100) NOT NULL,last_name VARCHAR(100) NOT NULL,department_id INT REFERENCES departments(id),position_id INT REFERENCES positions(id),status_id INT REFERENCES status_definitions(id));
CREATE TABLE employee_documents (id SERIAL PRIMARY KEY,employee_id INT REFERENCES employees(id),document_name VARCHAR(120) NOT NULL,is_missing BOOLEAN DEFAULT FALSE);
CREATE TABLE workflow_definitions (id SERIAL PRIMARY KEY,workflow_code VARCHAR(60) UNIQUE NOT NULL,workflow_name VARCHAR(120) NOT NULL,module_code VARCHAR(60) NOT NULL);
CREATE TABLE workflow_steps (id SERIAL PRIMARY KEY,workflow_definition_id INT REFERENCES workflow_definitions(id),step_order INT NOT NULL,step_name VARCHAR(120) NOT NULL,approver_role_code VARCHAR(50) NOT NULL,is_gate BOOLEAN DEFAULT FALSE);
CREATE TABLE workflow_routes (id SERIAL PRIMARY KEY,from_step_id INT REFERENCES workflow_steps(id),action_code VARCHAR(40) NOT NULL,to_step_id INT REFERENCES workflow_steps(id),route_type VARCHAR(40) NOT NULL);
CREATE TABLE workflow_checklists (id SERIAL PRIMARY KEY,workflow_step_id INT REFERENCES workflow_steps(id),checklist_name VARCHAR(120) NOT NULL);
CREATE TABLE workflow_checklist_items (id SERIAL PRIMARY KEY,workflow_checklist_id INT REFERENCES workflow_checklists(id),item_label VARCHAR(120) NOT NULL,is_required BOOLEAN DEFAULT TRUE,is_gate BOOLEAN DEFAULT FALSE);
CREATE TABLE workflow_instances (id SERIAL PRIMARY KEY,workflow_definition_id INT REFERENCES workflow_definitions(id),reference_no VARCHAR(40) UNIQUE NOT NULL,status_id INT REFERENCES status_definitions(id),current_step_id INT REFERENCES workflow_steps(id));
CREATE TABLE instance_checklist_items (id SERIAL PRIMARY KEY,instance_id INT REFERENCES workflow_instances(id),workflow_checklist_item_id INT REFERENCES workflow_checklist_items(id),is_completed BOOLEAN DEFAULT FALSE);
CREATE TABLE workflow_action_logs (id SERIAL PRIMARY KEY,instance_id INT REFERENCES workflow_instances(id),action_code VARCHAR(40) NOT NULL,action_note TEXT,action_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE company_branding (id SERIAL PRIMARY KEY,company_name VARCHAR(120) NOT NULL,logo_url TEXT,favicon_url TEXT);
CREATE TABLE ui_themes (id SERIAL PRIMARY KEY,code VARCHAR(40) UNIQUE NOT NULL,name VARCHAR(120) NOT NULL,properties JSONB NOT NULL,is_active BOOLEAN DEFAULT FALSE);
CREATE TABLE page_registry (id SERIAL PRIMARY KEY,page_code VARCHAR(60) UNIQUE NOT NULL,label VARCHAR(120) NOT NULL,route_url VARCHAR(255) NOT NULL,sort_order INT DEFAULT 0,is_active BOOLEAN DEFAULT TRUE);
CREATE TABLE role_page_access (id SERIAL PRIMARY KEY,role_code VARCHAR(50) NOT NULL,page_code VARCHAR(60) NOT NULL,can_view BOOLEAN DEFAULT TRUE);
CREATE TABLE feature_registry (id SERIAL PRIMARY KEY,feature_code VARCHAR(60) UNIQUE NOT NULL,feature_label VARCHAR(120) NOT NULL,feature_type VARCHAR(40) NOT NULL,sort_order INT DEFAULT 0,is_active BOOLEAN DEFAULT TRUE);
CREATE TABLE role_feature_access (id SERIAL PRIMARY KEY,role_code VARCHAR(50) NOT NULL,feature_code VARCHAR(60) NOT NULL,is_allowed BOOLEAN DEFAULT FALSE);
CREATE TABLE dashboard_metrics (id SERIAL PRIMARY KEY,metric_code VARCHAR(60) UNIQUE NOT NULL,metric_label VARCHAR(120) NOT NULL,formula_text TEXT NOT NULL,drilldown_url VARCHAR(255) NOT NULL,sort_order INT DEFAULT 0,is_active BOOLEAN DEFAULT TRUE);
CREATE TABLE search_index (id SERIAL PRIMARY KEY,entity_type VARCHAR(60) NOT NULL,entity_id INT NOT NULL,title VARCHAR(255) NOT NULL,subtitle VARCHAR(255),target_url VARCHAR(255) NOT NULL,keywords TEXT);
CREATE TABLE transaction_registry (id SERIAL PRIMARY KEY,module_code VARCHAR(60) NOT NULL,reference_no VARCHAR(40) UNIQUE NOT NULL,status_id INT REFERENCES status_definitions(id),current_step_id INT REFERENCES workflow_steps(id),summary_text TEXT);
CREATE TABLE transaction_qr_tokens (id SERIAL PRIMARY KEY,transaction_id INT REFERENCES transaction_registry(id),public_token VARCHAR(80) UNIQUE NOT NULL);
CREATE TABLE transaction_timeline (id SERIAL PRIMARY KEY,transaction_id INT REFERENCES transaction_registry(id),event_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,event_text TEXT NOT NULL);
CREATE TABLE dynamic_forms (id SERIAL PRIMARY KEY,form_name VARCHAR(120) NOT NULL,module_code VARCHAR(60) NOT NULL,description TEXT);
CREATE TABLE form_fields (id SERIAL PRIMARY KEY,dynamic_form_id INT REFERENCES dynamic_forms(id),field_label VARCHAR(120) NOT NULL,field_name VARCHAR(80) NOT NULL,field_type VARCHAR(40) NOT NULL,field_order INT DEFAULT 0,is_required BOOLEAN DEFAULT FALSE,data_source VARCHAR(120));
CREATE TABLE kpi_query_registry (id SERIAL PRIMARY KEY,kpi_code VARCHAR(60) UNIQUE NOT NULL,kpi_label VARCHAR(120) NOT NULL,sql_key VARCHAR(80) NOT NULL,description TEXT);
CREATE TABLE orchestration_flows (id SERIAL PRIMARY KEY,flow_name VARCHAR(120) NOT NULL,trigger_module VARCHAR(60) NOT NULL,flow_status VARCHAR(40) NOT NULL);
CREATE TABLE orchestration_steps (id SERIAL PRIMARY KEY,orchestration_flow_id INT REFERENCES orchestration_flows(id),step_order INT NOT NULL,target_module VARCHAR(60) NOT NULL,action_type VARCHAR(60) NOT NULL);

INSERT INTO status_definitions(status_group,status_code,status_label,badge_color,is_terminal,sort_order) VALUES
('EMPLOYEE','ACTIVE','Active','#16a34a',FALSE,1),('EMPLOYEE','ONBOARDING','Onboarding','#2563eb',FALSE,2),('EMPLOYEE','INACTIVE','Inactive','#64748b',TRUE,3),('WORKFLOW','PENDING','Pending','#f59e0b',FALSE,1),('WORKFLOW','IN_PROGRESS','In Progress','#3b82f6',FALSE,2),('WORKFLOW','APPROVED','Approved','#16a34a',TRUE,3),('WORKFLOW','REJECTED','Rejected','#dc2626',TRUE,4);
INSERT INTO users(display_name,email,role_code) VALUES ('Super Admin','superadmin@demo.local','SUPER_ADMIN'),('HR Admin','hradmin@demo.local','HR_ADMIN'),('Manager View','manager@demo.local','MANAGER'),('Employee View','employee@demo.local','EMPLOYEE'),('Admin','admin@hcm360.local','SUPER_ADMIN'),('Carlos Sanchez','capsanchez@hcm360.local','SUPER_ADMIN');
INSERT INTO departments(name) VALUES ('Human Resources'),('Information Technology'),('Finance'),('Operations');
INSERT INTO positions(title) VALUES ('HR Manager'),('Systems Analyst'),('Accountant'),('Operations Specialist'),('IT Manager'),('Finance Manager'),('Senior Developer'),('HR Officer'),('Payroll Specialist'),('Operations Manager');
INSERT INTO employees(employee_no,first_name,last_name,department_id,position_id,status_id) VALUES
('EMP-1001','Maria','Santos',1,1,(SELECT id FROM status_definitions WHERE status_code='ACTIVE' AND status_group='EMPLOYEE')),
('EMP-1002','Lara','Cruz',2,2,(SELECT id FROM status_definitions WHERE status_code='ACTIVE' AND status_group='EMPLOYEE')),
('EMP-1003','Noel','Ramos',4,4,(SELECT id FROM status_definitions WHERE status_code='ONBOARDING' AND status_group='EMPLOYEE')),
('EMP-1004','Juan','dela Cruz',3,3,(SELECT id FROM status_definitions WHERE status_code='ACTIVE' AND status_group='EMPLOYEE')),
('EMP-1005','Ana','Reyes',1,8,(SELECT id FROM status_definitions WHERE status_code='ACTIVE' AND status_group='EMPLOYEE')),
('EMP-1006','Miguel','Santos',2,7,(SELECT id FROM status_definitions WHERE status_code='ACTIVE' AND status_group='EMPLOYEE')),
('EMP-1007','Isabel','Garcia',3,9,(SELECT id FROM status_definitions WHERE status_code='ACTIVE' AND status_group='EMPLOYEE')),
('EMP-1008','Roberto','Mendoza',4,10,(SELECT id FROM status_definitions WHERE status_code='ACTIVE' AND status_group='EMPLOYEE')),
('EMP-1009','Patricia','Villanueva',1,8,(SELECT id FROM status_definitions WHERE status_code='ONBOARDING' AND status_group='EMPLOYEE')),
('EMP-1010','Carlo','Ramos',2,7,(SELECT id FROM status_definitions WHERE status_code='ACTIVE' AND status_group='EMPLOYEE')),
('EMP-1011','Diana','Flores',3,3,(SELECT id FROM status_definitions WHERE status_code='INACTIVE' AND status_group='EMPLOYEE')),
('EMP-1012','Jose','Bautista',4,4,(SELECT id FROM status_definitions WHERE status_code='ACTIVE' AND status_group='EMPLOYEE')),
('EMP-1013','Carlos','Sanchez',2,5,(SELECT id FROM status_definitions WHERE status_code='ACTIVE' AND status_group='EMPLOYEE')),
('EMP-1014','Grace','Aquino',1,1,(SELECT id FROM status_definitions WHERE status_code='ACTIVE' AND status_group='EMPLOYEE')),
('EMP-1015','Mark','Torres',3,6,(SELECT id FROM status_definitions WHERE status_code='ONBOARDING' AND status_group='EMPLOYEE'));
INSERT INTO employee_documents(employee_id,document_name,is_missing) VALUES
(1,'Employment Contract',FALSE),(1,'Government ID',FALSE),(1,'Medical Clearance',FALSE),(1,'NBI Clearance',FALSE),
(2,'Employment Contract',FALSE),(2,'Government ID',TRUE),(2,'Medical Clearance',FALSE),(2,'NBI Clearance',FALSE),
(3,'Employment Contract',FALSE),(3,'Government ID',TRUE),(3,'Medical Clearance',TRUE),(3,'NBI Clearance',TRUE),
(4,'Employment Contract',FALSE),(4,'Government ID',FALSE),(4,'Medical Clearance',TRUE),
(5,'Employment Contract',FALSE),(5,'Government ID',FALSE),(5,'Medical Clearance',FALSE),
(6,'Employment Contract',FALSE),(6,'Government ID',FALSE),(6,'Medical Clearance',FALSE),(6,'NBI Clearance',TRUE),
(7,'Employment Contract',FALSE),(7,'Government ID',FALSE),(7,'Medical Clearance',FALSE),
(8,'Employment Contract',FALSE),(8,'Government ID',FALSE),(8,'Medical Clearance',FALSE),(8,'NBI Clearance',FALSE),
(9,'Employment Contract',TRUE),(9,'Government ID',TRUE),(9,'Medical Clearance',TRUE),
(10,'Employment Contract',FALSE),(10,'Government ID',FALSE),(10,'Medical Clearance',FALSE),
(11,'Employment Contract',FALSE),(11,'Government ID',FALSE),
(12,'Employment Contract',FALSE),(12,'Government ID',FALSE),(12,'Medical Clearance',FALSE),
(13,'Employment Contract',FALSE),(13,'Government ID',FALSE),(13,'Medical Clearance',FALSE),(13,'NBI Clearance',FALSE),
(14,'Employment Contract',FALSE),(14,'Government ID',FALSE),(14,'Medical Clearance',FALSE),
(15,'Employment Contract',TRUE),(15,'Government ID',FALSE),(15,'Medical Clearance',TRUE);
INSERT INTO workflow_definitions(workflow_code,workflow_name,module_code) VALUES ('ONBOARDING_FLOW','New Hire Onboarding','ONBOARDING'),('MOVEMENT_FLOW','Employee Movement Approval','MOVEMENTS');
INSERT INTO workflow_steps(workflow_definition_id,step_order,step_name,approver_role_code,is_gate) VALUES (1,1,'HR Review','HR_ADMIN',TRUE),(1,2,'IT Provisioning','MANAGER',FALSE),(1,3,'Final Confirmation','HR_ADMIN',TRUE),(2,1,'HR Review','HR_ADMIN',TRUE),(2,2,'Manager Approval','MANAGER',TRUE),(2,3,'Final Approval','SUPER_ADMIN',TRUE);
INSERT INTO workflow_routes(from_step_id,action_code,to_step_id,route_type) VALUES (1,'APPROVE',2,'FORWARD'),(1,'REJECT',1,'RETURN_TO_SAME'),(2,'APPROVE',3,'FORWARD'),(2,'REJECT',1,'SEND_BACK'),(3,'APPROVE',NULL,'COMPLETE'),(3,'REJECT',1,'SEND_BACK'),(4,'APPROVE',5,'FORWARD'),(4,'REJECT',4,'RETURN_TO_SAME'),(5,'APPROVE',6,'FORWARD'),(5,'REJECT',4,'SEND_BACK'),(6,'APPROVE',NULL,'COMPLETE'),(6,'REJECT',4,'SEND_BACK');
INSERT INTO workflow_checklists(workflow_step_id,checklist_name) VALUES (1,'Onboarding HR Checklist'),(2,'IT Readiness Checklist'),(4,'Movement Validation Checklist');
INSERT INTO workflow_checklist_items(workflow_checklist_id,item_label,is_required,is_gate) VALUES (1,'Signed contract uploaded',TRUE,TRUE),(1,'Government ID uploaded',TRUE,TRUE),(1,'Welcome email prepared',FALSE,FALSE),(2,'Email account provisioned',TRUE,FALSE),(2,'Laptop assigned',FALSE,FALSE),(3,'Updated org placement validated',TRUE,TRUE);
INSERT INTO workflow_instances(workflow_definition_id,reference_no,status_id,current_step_id) VALUES
(1,'ONB-2026-0001',(SELECT id FROM status_definitions WHERE status_code='PENDING' AND status_group='WORKFLOW'),1),
(1,'ONB-2026-0002',(SELECT id FROM status_definitions WHERE status_code='PENDING' AND status_group='WORKFLOW'),1),
(1,'ONB-2026-0003',(SELECT id FROM status_definitions WHERE status_code='IN_PROGRESS' AND status_group='WORKFLOW'),2),
(1,'ONB-2026-0004',(SELECT id FROM status_definitions WHERE status_code='IN_PROGRESS' AND status_group='WORKFLOW'),3),
(2,'MOV-2026-0001',(SELECT id FROM status_definitions WHERE status_code='IN_PROGRESS' AND status_group='WORKFLOW'),5),
(2,'MOV-2026-0002',(SELECT id FROM status_definitions WHERE status_code='PENDING' AND status_group='WORKFLOW'),4);
INSERT INTO instance_checklist_items(instance_id,workflow_checklist_item_id,is_completed) VALUES
(1,1,FALSE),(1,2,FALSE),(1,3,FALSE),
(2,1,FALSE),(2,2,FALSE),(2,3,FALSE),
(3,1,TRUE),(3,2,TRUE),(3,3,TRUE),(3,4,FALSE),(3,5,FALSE),
(4,1,TRUE),(4,2,TRUE),(4,3,TRUE),(4,4,TRUE),(4,5,TRUE),
(5,6,TRUE),
(6,6,FALSE);
INSERT INTO workflow_action_logs(instance_id,action_code,action_note,action_time) VALUES
(3,'APPROVE','HR Review completed. Signed contract and Government ID verified.',CURRENT_TIMESTAMP - INTERVAL '3 days'),
(4,'APPROVE','HR Review completed. All onboarding documents in order.',CURRENT_TIMESTAMP - INTERVAL '5 days'),
(4,'APPROVE','IT Provisioning done. Email account and laptop assigned.',CURRENT_TIMESTAMP - INTERVAL '2 days'),
(5,'APPROVE','HR Review approved. Movement to Senior position fully justified by performance record.',CURRENT_TIMESTAMP - INTERVAL '1 day'),
(6,'REJECT','Missing updated position details and reporting line. Returned for correction.',CURRENT_TIMESTAMP - INTERVAL '4 hours');
INSERT INTO company_branding(company_name,logo_url,favicon_url) VALUES ('CX Digital HCM','/static/img/logo.png','/static/img/favicon.ico');
INSERT INTO ui_themes(code,name,properties,is_active) VALUES ('enterprise_light','Enterprise Light','{"primary_color":"#1d4ed8","secondary_color":"#0f172a","accent_color":"#14b8a6","body_background":"#f8fafc","card_background":"#ffffff","sidebar_background":"#0f172a","sidebar_text_color":"#f8fafc","border_radius":"18px","font_family":"Inter, Arial, sans-serif"}'::jsonb,TRUE),('executive_dark','Executive Dark','{"primary_color":"#38bdf8","secondary_color":"#e2e8f0","accent_color":"#a78bfa","body_background":"#020617","card_background":"#0f172a","sidebar_background":"#000814","sidebar_text_color":"#e2e8f0","border_radius":"18px","font_family":"Inter, Arial, sans-serif"}'::jsonb,FALSE),('modern_slate','Modern Slate','{"primary_color":"#475569","secondary_color":"#111827","accent_color":"#0ea5e9","body_background":"#f1f5f9","card_background":"#ffffff","sidebar_background":"#1e293b","sidebar_text_color":"#f8fafc","border_radius":"14px","font_family":"Inter, Arial, sans-serif"}'::jsonb,FALSE);
INSERT INTO page_registry(page_code,label,route_url,sort_order) VALUES ('DASHBOARD','Dashboard','/',1),('EMPLOYEES','Employees','/employees',2),('WORKFLOW','Workflow Engine','/workflow',3),('THEMES','Themes','/admin/themes',4),('STATUSES','Statuses','/admin/statuses',5),('USERS','Users','/admin/users',6),('ACCESS_MATRIX','Access Matrix','/admin/access-matrix',7),('VISUAL_BUILDER','Visual Builder','/admin/visual-builder',8),('FORM_BUILDER','Form Builder','/admin/form-builder',9),('KPI_BUILDER','KPI Builder','/admin/kpi-builder',10),('ORCHESTRATION','Orchestration','/admin/orchestration',11),('REFERENCE_DATA','Reference Data','/admin/reference-data',12);
INSERT INTO role_page_access(role_code,page_code,can_view) VALUES ('SUPER_ADMIN','DASHBOARD',TRUE),('SUPER_ADMIN','EMPLOYEES',TRUE),('SUPER_ADMIN','WORKFLOW',TRUE),('SUPER_ADMIN','THEMES',TRUE),('SUPER_ADMIN','STATUSES',TRUE),('SUPER_ADMIN','USERS',TRUE),('SUPER_ADMIN','ACCESS_MATRIX',TRUE),('SUPER_ADMIN','VISUAL_BUILDER',TRUE),('SUPER_ADMIN','FORM_BUILDER',TRUE),('SUPER_ADMIN','KPI_BUILDER',TRUE),('SUPER_ADMIN','ORCHESTRATION',TRUE),('SUPER_ADMIN','REFERENCE_DATA',TRUE),('HR_ADMIN','DASHBOARD',TRUE),('HR_ADMIN','EMPLOYEES',TRUE),('HR_ADMIN','WORKFLOW',TRUE),('HR_ADMIN','THEMES',FALSE),('HR_ADMIN','STATUSES',TRUE),('HR_ADMIN','USERS',FALSE),('HR_ADMIN','ACCESS_MATRIX',FALSE),('HR_ADMIN','VISUAL_BUILDER',FALSE),('HR_ADMIN','FORM_BUILDER',FALSE),('HR_ADMIN','KPI_BUILDER',FALSE),('HR_ADMIN','ORCHESTRATION',FALSE),('HR_ADMIN','REFERENCE_DATA',FALSE),('MANAGER','DASHBOARD',TRUE),('MANAGER','EMPLOYEES',TRUE),('MANAGER','WORKFLOW',TRUE),('MANAGER','THEMES',FALSE),('MANAGER','STATUSES',FALSE),('MANAGER','USERS',FALSE),('MANAGER','ACCESS_MATRIX',FALSE),('MANAGER','VISUAL_BUILDER',FALSE),('MANAGER','FORM_BUILDER',FALSE),('MANAGER','KPI_BUILDER',FALSE),('MANAGER','ORCHESTRATION',FALSE),('MANAGER','REFERENCE_DATA',FALSE),('EMPLOYEE','DASHBOARD',TRUE),('EMPLOYEE','EMPLOYEES',FALSE),('EMPLOYEE','WORKFLOW',FALSE),('EMPLOYEE','THEMES',FALSE),('EMPLOYEE','STATUSES',FALSE),('EMPLOYEE','USERS',FALSE),('EMPLOYEE','ACCESS_MATRIX',FALSE),('EMPLOYEE','VISUAL_BUILDER',FALSE),('EMPLOYEE','FORM_BUILDER',FALSE),('EMPLOYEE','KPI_BUILDER',FALSE),('EMPLOYEE','ORCHESTRATION',FALSE),('EMPLOYEE','REFERENCE_DATA',FALSE);
INSERT INTO feature_registry(feature_code,feature_label,feature_type,sort_order) VALUES ('BTN_WORKFLOW_ACTION','Workflow Action Buttons','BUTTON',1),('BTN_CHECKLIST_TOGGLE','Checklist Toggle Button','BUTTON',2),('LNK_SCENARIOS','Scenario Launcher Link','LINK',3),('FUNNEL_WORKFLOW','Workflow Funnel Visibility','FUNNEL',4),('BTN_PRINT','Print Button','BUTTON',5),('LNK_VISUAL_BUILDER','Visual Builder Link','LINK',6),('LNK_FORM_BUILDER','Form Builder Link','LINK',7),('LNK_KPI_BUILDER','KPI Builder Link','LINK',8),('LNK_ORCHESTRATION','Orchestration Link','LINK',9),('LNK_REFERENCE_DATA','Reference Data Link','LINK',10);
INSERT INTO role_feature_access(role_code,feature_code,is_allowed) VALUES ('SUPER_ADMIN','BTN_WORKFLOW_ACTION',TRUE),('SUPER_ADMIN','BTN_CHECKLIST_TOGGLE',TRUE),('SUPER_ADMIN','LNK_SCENARIOS',TRUE),('SUPER_ADMIN','FUNNEL_WORKFLOW',TRUE),('SUPER_ADMIN','BTN_PRINT',TRUE),('SUPER_ADMIN','LNK_VISUAL_BUILDER',TRUE),('SUPER_ADMIN','LNK_FORM_BUILDER',TRUE),('SUPER_ADMIN','LNK_KPI_BUILDER',TRUE),('SUPER_ADMIN','LNK_ORCHESTRATION',TRUE),('SUPER_ADMIN','LNK_REFERENCE_DATA',TRUE),('HR_ADMIN','BTN_WORKFLOW_ACTION',TRUE),('HR_ADMIN','BTN_CHECKLIST_TOGGLE',TRUE),('HR_ADMIN','LNK_SCENARIOS',FALSE),('HR_ADMIN','FUNNEL_WORKFLOW',TRUE),('HR_ADMIN','BTN_PRINT',TRUE),('HR_ADMIN','LNK_VISUAL_BUILDER',FALSE),('HR_ADMIN','LNK_FORM_BUILDER',FALSE),('HR_ADMIN','LNK_KPI_BUILDER',FALSE),('HR_ADMIN','LNK_ORCHESTRATION',FALSE),('HR_ADMIN','LNK_REFERENCE_DATA',FALSE),('MANAGER','BTN_WORKFLOW_ACTION',TRUE),('MANAGER','BTN_CHECKLIST_TOGGLE',FALSE),('MANAGER','LNK_SCENARIOS',FALSE),('MANAGER','FUNNEL_WORKFLOW',TRUE),('MANAGER','BTN_PRINT',FALSE),('MANAGER','LNK_VISUAL_BUILDER',FALSE),('MANAGER','LNK_FORM_BUILDER',FALSE),('MANAGER','LNK_KPI_BUILDER',FALSE),('MANAGER','LNK_ORCHESTRATION',FALSE),('MANAGER','LNK_REFERENCE_DATA',FALSE),('EMPLOYEE','BTN_WORKFLOW_ACTION',FALSE),('EMPLOYEE','BTN_CHECKLIST_TOGGLE',FALSE),('EMPLOYEE','LNK_SCENARIOS',FALSE),('EMPLOYEE','FUNNEL_WORKFLOW',FALSE),('EMPLOYEE','BTN_PRINT',FALSE),('EMPLOYEE','LNK_VISUAL_BUILDER',FALSE),('EMPLOYEE','LNK_FORM_BUILDER',FALSE),('EMPLOYEE','LNK_KPI_BUILDER',FALSE),('EMPLOYEE','LNK_ORCHESTRATION',FALSE),('EMPLOYEE','LNK_REFERENCE_DATA',FALSE);
INSERT INTO dashboard_metrics(metric_code,metric_label,formula_text,drilldown_url,sort_order) VALUES ('TOTAL_HEADCOUNT','Total Headcount','Count of all employee records in employees table.','/employees',1),('ACTIVE_EMPLOYEES','Active Employees','Employees whose status metadata is ACTIVE.','/employees',2),('PENDING_WORKFLOW_ITEMS','Pending Workflow Items','Workflow instances currently in pending status.','/workflow',3),('MISSING_DOCUMENTS','Missing Documents','Employee document rows tagged as missing.','/employees',4);
INSERT INTO transaction_registry(module_code,reference_no,status_id,current_step_id,summary_text) VALUES
('ONBOARDING','ONB-2026-0001',(SELECT id FROM status_definitions WHERE status_code='PENDING' AND status_group='WORKFLOW'),1,'New hire onboarding for Noel Ramos — pending HR Review'),
('ONBOARDING','ONB-2026-0003',(SELECT id FROM status_definitions WHERE status_code='IN_PROGRESS' AND status_group='WORKFLOW'),2,'New hire onboarding for Carlos Sanchez — IT Provisioning in progress'),
('MOVEMENTS','MOV-2026-0001',(SELECT id FROM status_definitions WHERE status_code='IN_PROGRESS' AND status_group='WORKFLOW'),5,'Employee movement request for Carlo Ramos — pending Manager Approval'),
('ONBOARDING','ONB-2026-0002',(SELECT id FROM status_definitions WHERE status_code='PENDING' AND status_group='WORKFLOW'),1,'New hire onboarding for Patricia Villanueva — pending HR Review');
INSERT INTO transaction_qr_tokens(transaction_id,public_token) VALUES
(1,'demo-onb-2026-0001'),
(2,'demo-onb-2026-0003'),
(3,'demo-mov-2026-0001'),
(4,'demo-onb-2026-0002');
INSERT INTO transaction_timeline(transaction_id,event_text) VALUES
(1,'Transaction created — Noel Ramos onboarding initiated by HR Admin'),
(1,'HR Review step assigned. Awaiting signed employment contract and Government ID.'),
(1,'Reminder sent to HR Admin: 2 required documents still missing.'),
(2,'Transaction created — Carlos Sanchez onboarding initiated'),
(2,'HR Review completed. All documents verified and approved.'),
(2,'IT Provisioning step started. Email account and laptop provisioning underway.'),
(2,'Email account created: csanchez@company.local'),
(3,'Transaction created — Carlo Ramos promotion/movement request submitted'),
(3,'HR Review completed and approved. Performance justification accepted.'),
(3,'Manager Approval step assigned to direct reporting manager.'),
(3,'Pending manager sign-off to proceed to final approval.'),
(4,'Transaction created — Patricia Villanueva onboarding initiated'),
(4,'HR Review step assigned. All 3 required documents are missing.'),
(4,'Document checklist sent to Patricia Villanueva via email.');
INSERT INTO dynamic_forms(form_name,module_code,description) VALUES ('Onboarding Intake Form','ONBOARDING','Collects new hire inputs before workflow starts'),('Movement Request Form','MOVEMENTS','Captures promotion or transfer requests');
INSERT INTO form_fields(dynamic_form_id,field_label,field_name,field_type,field_order,is_required,data_source) VALUES (1,'Employee Full Name','employee_full_name','text',1,TRUE,NULL),(1,'Department','department_id','select',2,TRUE,'departments'),(1,'Start Date','start_date','date',3,TRUE,NULL),(2,'Movement Type','movement_type','select',1,TRUE,'lookup'),(2,'Reason','reason','textarea',2,TRUE,NULL),(2,'Effective Date','effective_date','date',3,TRUE,NULL);
INSERT INTO kpi_query_registry(kpi_code,kpi_label,sql_key,description) VALUES ('HC_TOTAL','Headcount Total','kpi_total_headcount','Registry entry for total headcount KPI'),('WF_PENDING','Pending Workflow Count','kpi_pending_workflow','Registry entry for workflow pending KPI');
INSERT INTO orchestration_flows(flow_name,trigger_module,flow_status) VALUES ('Onboarding to Provisioning','ONBOARDING','ACTIVE'),('Movement to Org Update','MOVEMENTS','ACTIVE');
INSERT INTO orchestration_steps(orchestration_flow_id,step_order,target_module,action_type) VALUES (1,1,'ONBOARDING','CREATE_WORKFLOW'),(1,2,'ITSM','TRIGGER_TICKET'),(1,3,'DOCUMENTS','REQUEST_REQUIREMENTS'),(2,1,'MOVEMENTS','APPROVAL_WORKFLOW'),(2,2,'ORGCHART','UPDATE_NODE');
INSERT INTO page_registry(page_code,label,route_url,sort_order) VALUES ('AI_BRIEFING','ARIA Executive Briefing','/ai/executive',20),('AI_ASSISTANT','ARIA AI Assistant','/ai/assistant',21),('DEMO_DATA','Demo Data Manager','/admin/demo-data',22);
INSERT INTO role_page_access(role_code,page_code,can_view) VALUES ('SUPER_ADMIN','AI_BRIEFING',TRUE),('SUPER_ADMIN','AI_ASSISTANT',TRUE),('SUPER_ADMIN','DEMO_DATA',TRUE),('HR_ADMIN','AI_BRIEFING',TRUE),('HR_ADMIN','AI_ASSISTANT',TRUE),('HR_ADMIN','DEMO_DATA',FALSE),('MANAGER','AI_BRIEFING',FALSE),('MANAGER','AI_ASSISTANT',TRUE),('MANAGER','DEMO_DATA',FALSE),('EMPLOYEE','AI_BRIEFING',FALSE),('EMPLOYEE','AI_ASSISTANT',FALSE),('EMPLOYEE','DEMO_DATA',FALSE);
INSERT INTO feature_registry(feature_code,feature_label,feature_type,sort_order) VALUES ('LNK_AI_BRIEFING','ARIA Executive Briefing','LINK',11),('LNK_AI_ASSISTANT','ARIA AI Assistant','LINK',12),('LNK_DEMO_DATA','Demo Data Manager','LINK',13);
INSERT INTO role_feature_access(role_code,feature_code,is_allowed) VALUES ('SUPER_ADMIN','LNK_AI_BRIEFING',TRUE),('SUPER_ADMIN','LNK_AI_ASSISTANT',TRUE),('SUPER_ADMIN','LNK_DEMO_DATA',TRUE),('HR_ADMIN','LNK_AI_BRIEFING',TRUE),('HR_ADMIN','LNK_AI_ASSISTANT',TRUE),('HR_ADMIN','LNK_DEMO_DATA',FALSE),('MANAGER','LNK_AI_BRIEFING',FALSE),('MANAGER','LNK_AI_ASSISTANT',TRUE),('MANAGER','LNK_DEMO_DATA',FALSE),('EMPLOYEE','LNK_AI_BRIEFING',FALSE),('EMPLOYEE','LNK_AI_ASSISTANT',FALSE),('EMPLOYEE','LNK_DEMO_DATA',FALSE);
INSERT INTO search_index(entity_type,entity_id,title,subtitle,target_url,keywords) VALUES
('employee',1,'Maria Santos','HR Manager · Human Resources','/employees','Maria Santos HR Manager employee active'),
('employee',2,'Lara Cruz','Systems Analyst · IT','/employees','Lara Cruz IT systems analyst employee active'),
('employee',3,'Noel Ramos','Operations Specialist · Operations','/employees','Noel Ramos operations specialist onboarding'),
('employee',4,'Juan dela Cruz','Accountant · Finance','/employees','Juan dela Cruz accountant finance employee active'),
('employee',5,'Ana Reyes','HR Officer · Human Resources','/employees','Ana Reyes HR officer employee active'),
('employee',6,'Miguel Santos','Senior Developer · IT','/employees','Miguel Santos senior developer IT employee active'),
('employee',7,'Isabel Garcia','Payroll Specialist · Finance','/employees','Isabel Garcia payroll specialist finance employee active'),
('employee',8,'Roberto Mendoza','Operations Manager · Operations','/employees','Roberto Mendoza operations manager employee active'),
('employee',9,'Patricia Villanueva','HR Officer · Human Resources','/employees','Patricia Villanueva HR officer onboarding'),
('employee',10,'Carlo Ramos','Senior Developer · IT','/employees','Carlo Ramos senior developer IT employee active'),
('employee',11,'Diana Flores','Accountant · Finance','/employees','Diana Flores accountant finance inactive'),
('employee',12,'Jose Bautista','Operations Specialist · Operations','/employees','Jose Bautista operations specialist employee active'),
('employee',13,'Carlos Sanchez','IT Manager · Information Technology','/employees','Carlos Sanchez IT manager capsanchez employee active'),
('employee',14,'Grace Aquino','HR Manager · Human Resources','/employees','Grace Aquino HR manager employee active'),
('employee',15,'Mark Torres','Finance Manager · Finance','/employees','Mark Torres finance manager onboarding'),
('workflow',1,'ONB-2026-0001','New Hire Onboarding · Pending','/workflow/1','onboarding workflow Noel Ramos HR review pending'),
('workflow',2,'ONB-2026-0002','New Hire Onboarding · Pending','/workflow/2','onboarding workflow Patricia Villanueva HR review pending'),
('workflow',3,'ONB-2026-0003','New Hire Onboarding · In Progress','/workflow/3','onboarding workflow IT provisioning Carlos Sanchez in progress'),
('workflow',4,'ONB-2026-0004','New Hire Onboarding · In Progress','/workflow/4','onboarding workflow final confirmation Mark Torres'),
('workflow',5,'MOV-2026-0001','Employee Movement · In Progress','/workflow/5','movement workflow manager approval Carlo Ramos promotion'),
('workflow',6,'MOV-2026-0002','Employee Movement · Pending','/workflow/6','movement workflow HR review pending rejected'),
('transaction',1,'ONB-2026-0001','New hire onboarding — Noel Ramos','/inquiry/demo-onb-2026-0001','transaction inquiry onboarding Noel Ramos'),
('transaction',2,'ONB-2026-0003','New hire onboarding — Carlos Sanchez','/inquiry/demo-onb-2026-0003','transaction inquiry onboarding Carlos Sanchez IT provisioning'),
('transaction',3,'MOV-2026-0001','Employee movement — Carlo Ramos','/inquiry/demo-mov-2026-0001','transaction inquiry movement promotion Carlo Ramos'),
('transaction',4,'ONB-2026-0002','New hire onboarding — Patricia Villanueva','/inquiry/demo-onb-2026-0002','transaction inquiry onboarding Patricia Villanueva documents missing'),
('page',1,'Theme Settings','Admin page','/admin/themes','theme settings branding colors'),
('page',2,'Status Metadata','Admin page','/admin/statuses','status metadata labels colors'),
('page',3,'Access Matrix','Super admin config page','/admin/access-matrix','page access feature access role matrix'),
('page',4,'Visual Builder','Workflow canvas admin page','/admin/visual-builder','visual workflow builder canvas'),
('page',5,'Form Builder','Dynamic form admin page','/admin/form-builder','dynamic forms field builder'),
('page',6,'KPI Builder','KPI query admin page','/admin/kpi-builder','kpi sql registry builder'),
('page',7,'Orchestration','Cross-module flow admin page','/admin/orchestration','orchestration cross module'),
('page',8,'Reference Data','Reference master maintenance page','/admin/reference-data','reference tables add edit delete');
