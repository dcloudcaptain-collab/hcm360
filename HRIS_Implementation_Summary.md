# HRIS DATABASE DESIGN & IMPLEMENTATION ROADMAP

**Municipality of Mariveles, Bataan**  
**PRIME-HRM Level 2 Compliant System**  
**PostgreSQL 14+ Architecture**

---

## 📊 Current Infrastructure Status

✅ **Database Deployed**
- **Host**: localhost (dev) / hris_db (Docker)
- **Port**: 5440 (host-mapped to 5432)
- **Database**: hris_db
- **User**: hris_admin
- **Connection**: `postgresql://hris_admin:hris_secure_pw@localhost:5440/hris_db`

---

## 🎯 System Scope: 14 Functional Areas

### Core HR Systems (4 Pillars)
1. **Recruitment, Selection & Placement (RSP)**
   - Job posting management
   - Applicant tracking
   - Offer processing
   - Data retention: 5 years

2. **Performance Management (PM)**
   - Goal setting & tracking
   - Performance ratings
   - Review cycles
   - Succession planning

3. **Learning & Development (L&D)**
   - Training catalog
   - Training attendance tracking
   - Certification management
   - Skill gap analysis

4. **Rewards & Recognition (R&R)**
   - Loyalty awards (10, 15, 20, 25, 30-year milestones)
   - Step increment tracking (every 3 years)
   - Retirement monitoring
   - Awards memos

### Additional Requirements
5. **Attendance Monitoring**
6. **Payroll System**
7. **Security & Compliance**
8. **Employee Records Management**
9. **Reporting, Analytics & Dashboards**
10. **Self-Service & Mobile Access**
11. **AI/Modern Add-ons**
12. **Integration & Ecosystem**

---

## 📈 Core Data Entities Overview

### Tier 1: Foundational (Foundation of All Data)
```
departments (dept_id, dept_code, dept_name, parent_dept_id, head_id)
positions (pos_id, pos_code, pos_title, department_id, salary_grade, rank_classification)
employees (emp_id, emp_number, names, email, gender, hire_date, birthdate, status, dept_id, pos_id)
```

### Tier 2: Employment History
```
appointment_history (apt_id, emp_id, pos_id, appointment_type, start_date, end_date)
promotion_history (prom_id, emp_id, from_pos_id, to_pos_id, promotion_date)
transfer_history (trans_id, emp_id, from_dept_id, to_dept_id, transfer_date)
```

### Tier 3: Attendance & Leave
```
attendance (att_id, emp_id, attendance_date, time_in, time_out, status)
leave_requests (leave_id, emp_id, leave_type, start_date, end_date, approval_status)
leave_balances (balance_id, emp_id, fiscal_year, leave_type, days_balance)
```

### Tier 4: Compensation & Payroll
```
compensation (comp_id, emp_id, effective_date, base_salary, allowances, deductions)
payroll_runs (payroll_id, payroll_period, pay_date, payroll_type, status)
payroll_details (detail_id, payroll_id, emp_id, gross_pay, deductions, net_pay)
```

### Tier 5: Performance & Development
```
performance_goals (goal_id, emp_id, fiscal_year, goal_text, achievement_status)
training_records (train_id, emp_id, training_name, training_date, hours, certificate)
skills_inventory (skill_id, emp_id, skill_name, proficiency_level, verified_date)
```

### Tier 6: Recruitment & Onboarding
```
job_postings (posting_id, position_id, posting_date, closing_date, posting_status)
applicants (applicant_id, posting_id, first_name, email, application_status, qualifications_met)
onboarding_tasks (task_id, emp_id, task_name, assigned_to, due_date, status)
```

### Tier 7: Audit & Compliance
```
audit_logs (log_id, table_name, record_id, action, old_values, new_values, changed_by, changed_at)
user_access_logs (access_id, user_id, accessed_table, access_type, accessed_at)
compliance_logs (comp_log_id, compliance_type, checked_by, checked_date, status)
document_storage (doc_id, emp_id, document_type, file_path, upload_date, expiry_date)
```

---

## 📊 Analytics & KPI Strategy

### Real-Time Dashboards (Direct Query)

**1. Executive Dashboard**
- Total headcount (active employees)
- Turnover trend (3-month rolling)
- Open positions count
- Payroll processing status
- Employees approaching retirement (60+, 65+)

**2. Department Manager Dashboard**
- Team headcount & composition
- Daily attendance rate
- Pending leave approvals
- Team training coverage
- Performance review completion %

**3. HR Analytics Dashboard**
- Recruitment pipeline (application → offer → hire)
- Candidate pool by position
- Time-to-hire metrics
- Turnover analysis by department
- Compensation benchmarking
- Compliance status

**4. Payroll Dashboard**
- Payroll cycle status (draft → processed → approved → posted)
- Budget vs. actual comparison
- Deduction summary (GSIS, SSS, BIR, Pag-IBIG, loans)
- Pay slip generation status

### Materialized Views (Refreshed Hourly)

| View Name | Purpose | Refresh | Users |
|-----------|---------|---------|-------|
| `mv_workforce_demographics` | Gender, age, tenure distributions | Hourly | HR, Executive |
| `mv_attendance_metrics` | Attendance, tardiness, absenteeism | Daily | Managers, HR |
| `mv_leave_utilization` | Leave balance & usage by type | Real-time | Employees, HR |
| `mv_turnover_analysis` | Separations, reasons, by dept | Monthly | HR Leadership |
| `mv_payroll_summary` | Gross by dept, deductions, net | Monthly | Finance, Payroll |
| `mv_retirement_eligible` | Age 60+ and 65+ employees | Monthly | HR Leadership |
| `mv_training_coverage` | Training hours/employee, cert %  | Quarterly | L&D, HR |

### Key Performance Indicators (KPIs)

**Workforce Metrics**
- Total Headcount (daily)
- Headcount by Gender, Position, Department (weekly)
- Average Tenure (monthly)
- Employment Status Distribution (daily)

**Recruitment Metrics**
- Time-to-Hire (avg days from posting to appointment)
- Applications Received (monthly)
- Offer Acceptance Rate (quarterly)
- Candidates in Pipeline (daily)

**Attendance Metrics**
- Attendance Rate % = Present ÷ Total × 100 (daily)
- Absenteeism Rate % = Absent ÷ Total × 100 (weekly)
- Tardiness Incidents (weekly)
- Chronic Absences (>10 days/month)

**Leave Metrics**
- Leave Days Used/Remaining (real-time)
- Leave by Type breakdown (monthly)
- Forfeited Leave analysis (annual)
- Pending Approvals (daily)

**Payroll Metrics**
- Payroll Processing Time (days to post)
- Payroll Accuracy % (errors ÷ transactions)
- Budget Variance (actual vs. budgeted)
- Salary Grade Distribution

**Performance Metrics**
- Goal Achievement Rate (%)
- Performance Rating Distribution
- Employees with Active Goals (%)
- Review Completion Rate (%)

**Training Metrics**
- Training Hours per Employee (annual)
- Training Completion Rate (%)
- Certification Compliance Rate (%)
- Training ROI (performance improvement correlation)

**Retention & Turnover**
- Turnover Rate % = (Separations ÷ Avg Headcount) × 100 (monthly)
- Turnover by Department, Position, Tenure Group
- Top Reasons for Leaving
- Regrettable vs. Non-Regrettable Turnover

**Retirement Metrics**
- Employees Approaching Early Retirement (Age 60+)
- Employees at Mandatory Retirement (Age 65+)
- Projected Retirement Timeline (6-month, 1-year outlook)
- Critical Position Succession Readiness (%)

---

## 🤖 AI/ML Opportunities

### Phase 1: Immediate (Weeks 15-20)

#### 1. **Retention Risk Scoring**
**Goal**: Predict which employees are likely to leave  
**Model**: Logistic Regression or Random Forest  
**Input Features**:
- Tenure (years employed)
- Department & position
- Promotion history
- Training participation (hours/year)
- Performance rating trend
- Leave pattern (spikes = risk indicator)
- Salary competitiveness vs. market

**Output**: Risk Score (0-100)
- 0-30: Low risk → No action needed
- 31-60: Medium risk → Monitor
- 61-100: High risk → HR intervention

**Action**: HR notified of high-risk employees
- Offer career development plan
- Schedule salary review
- Recommend promotion opportunity
- Assign mentor/coaching

#### 2. **Skill Gap Identification**
**Goal**: Identify missing competencies per employee/position  
**Input**:
- Job requirements (from position master)
- Training history (skills gained)
- Certifications held & expiry dates
- Performance ratings by competency

**Output**:
- Missing critical skills per employee
- Recommended training programs
- Timeline to fill gap (3-month, 6-month)
- Training priority ranking

#### 3. **Succession Planning**
**Goal**: Identify internal talent ready for leadership roles  
**Input**:
- Performance ratings (top quartile)
- Readiness assessment
- Leadership training completion
- Promotion frequency & trajectory
- Critical position definition

**Output**: Succession candidates ranked by readiness
- Ready Now (0-6 months)
- Ready Soon (6-12 months)
- Development Needed (1-2 years)
- High-flight-risk (high performer + approaching retirement)

### Phase 2: Short Term (Weeks 1-4 Post-Launch)

#### 4. **Chatbot / AI Assistant**
**Natural Language Interface** for employees:
- "How many vacation days do I have left?" → Query leave_balance table
- "What's my current salary?" → Query compensation (with privacy checks)
- "When is my next training scheduled?" → Query training_records
- "How do I request leave?" → Guided workflow
- "What's my promotion timeline?" → Query succession plan data

**Benefits**: Reduce HR support tickets by 30-40%

#### 5. **Anomaly Detection**
**Monitor for unusual patterns**:
- Unusually high overtime in a department
- Sudden spike in sick leave requests
- Salary adjustments outside normal range
- Unauthorized access to sensitive records
- High absenteeism spike

**Alert**: HR/Compliance for manual review

#### 6. **Workload Forecasting**
**Goal**: Predict staffing needs for next 6-12 months  
**Input**:
- Historical turnover rates
- Retirement eligibility timeline
- Department growth forecasts
- Seasonal hiring patterns

**Output**: Recruitment plan with timelines

---

## 🔐 Security & Compliance

### PostgreSQL Security Features

**✓ Row-Level Security (RLS) Policies**
- Employees: Can view only own records
- Managers: Can view team data
- HR: Can view all (with audit trail)
- No cross-department data access

**✓ Encryption**
- Sensitive fields encrypted: SSN, GSIS#, Pag-IBIG#, SSS#, TIN, Banking info
- SSL/TLS: All connections encrypted in transit
- Backup encryption: At-rest encryption

**✓ Audit Trail (Append-Only)**
- `audit_logs` table: Immutable change history
- Every INSERT, UPDATE, DELETE logged
- Captured: Who, What, When, Why, IP address
- No ability to delete audit logs

**✓ Access Control**
- Database roles: `hr_read`, `hr_write`, `hr_admin`, `manager_read`, `employee_read`
- Role-based permissions enforced at DB level
- Application-level access control (additional layer)

### Data Governance

**✓ CSC PRIME-HRM Level 2 Compliance**
- Gender breakdown in all reports
- Appointment records per CSC Form No. 6 (Revised 2020)
- Plantilla positions tracked & reported
- Eligibility certifications (1st/2nd level) managed
- Leave compliance per labor laws (RA 11363, etc.)

**✓ Data Privacy**
- PII masking in non-prod environments
- 5-year retention for active employees (then archive)
- 2-year retention for terminated employees (then delete)
- GDPR-ready: Data export, right-to-be-forgotten workflows
- Soft deletes: `deleted_at` timestamp, no hard deletions

**✓ Archival & Retention**
- Off-boarded employees → archive schema (read-only)
- Historical data preserved for compliance/audit
- Quarterly compliance audit execution
- Quarterly backup verification

---

## 📅 Implementation Roadmap

### Phase 1: Foundation (Weeks 1-4)
**Focus**: Deploy core infrastructure, establish data foundation

- [ ] PostgreSQL cluster setup (HA, replication, automated backups)
- [ ] Core tables created: departments, positions, employees
- [ ] Appointment history table
- [ ] Audit logging infrastructure
- [ ] User authentication & RLS policies
- [ ] Data migration from legacy system (employees, positions, departments)
- [ ] SSL/TLS certificates installed
- [ ] Backup & recovery procedures tested
- [ ] Database roles created (hr_admin, hr_read, hr_write, manager_read, employee_read)

**Deliverable**: Operational database with core employee data, audit trail, and basic access control

### Phase 2: Operational Features (Weeks 5-10)
**Focus**: Implement day-to-day HR operations

- [ ] Attendance table + biometric integration
- [ ] Leave management system (requests, approvals, balance tracking)
- [ ] Compensation & payroll tables
- [ ] Performance management (goals, reviews, ratings)
- [ ] Training tracking system
- [ ] Data validation rules & constraints
- [ ] Automated calculations (hours worked, leave balance, gross/net pay)
- [ ] Trigger functions for automatic change tracking

**Deliverable**: Fully functional operational database supporting all 14 functional areas

### Phase 3: Analytics (Weeks 11-14)
**Focus**: Enable data-driven decision making

- [ ] Materialized views created (all 7 views)
- [ ] Dashboard queries optimized for performance
- [ ] Real-time KPI calculations
- [ ] Historical tracking for trends
- [ ] Workforce demographics reports
- [ ] Monthly reporting automated
- [ ] Performance benchmarking views

**Deliverable**: Real-time dashboards, KPI tracking, and automated reporting

### Phase 4: AI & Advanced Features (Weeks 15-20)
**Focus**: Intelligent automation and insights

- [ ] Retention risk model trained & deployed
- [ ] Skill gap analysis running automatically
- [ ] Succession planning rankings generated
- [ ] Chatbot backend queries implemented
- [ ] Anomaly detection pipeline operational
- [ ] Workload forecasting model trained
- [ ] User acceptance testing (UAT) completed
- [ ] Staff training program executed
- [ ] Go-live approval from stakeholders

**Deliverable**: AI-powered insights, predictive analytics, employee self-service chatbot

---

## ✅ Pre-Launch Deployment Checklist

**Database & Infrastructure**
- [ ] PostgreSQL cluster verified (3-node HA setup)
- [ ] Backup & recovery procedures tested (successful restore)
- [ ] Failover tested (switchover completes in <5 min)
- [ ] SSL certificates installed & validated
- [ ] Connection pooling configured (pgBouncer or similar)
- [ ] Monitoring alerts configured (CPU, disk, connections)

**Security & Access**
- [ ] User roles created & tested
- [ ] Row-level security policies enforced
- [ ] Encryption enabled for sensitive fields
- [ ] Network security rules applied (only app servers can access)
- [ ] Firewall rules tested (port 5440 accessible from app only)
- [ ] Audit logging enabled & validated

**Data Quality**
- [ ] Data migration from legacy system complete
- [ ] Data validation rules applied
- [ ] Duplicate detection & resolution
- [ ] Missing value handling
- [ ] Data integrity constraints verified

**Testing & Validation**
- [ ] Unit tests passed (core functions)
- [ ] Integration tests passed (end-to-end workflows)
- [ ] Performance tests passed (response times < 2 sec for dashboards)
- [ ] Load testing passed (1000 concurrent users)
- [ ] Security penetration testing completed
- [ ] User acceptance testing (UAT) passed

**Operations & Documentation**
- [ ] Runbook for common maintenance tasks
- [ ] Disaster recovery plan documented
- [ ] Escalation procedures defined
- [ ] Staff training completed (DBA, support team)
- [ ] User training completed (HR staff, managers, employees)
- [ ] Documentation updated (schema, procedures, troubleshooting)

**Compliance & Audit**
- [ ] PRIME-HRM compliance verified
- [ ] CSC Form No. 6 requirements checked
- [ ] Gender breakdown reports validated
- [ ] Audit trail validation (sample transactions logged)
- [ ] Compliance documentation prepared
- [ ] Go-live approval signature

---

## 📞 Support & Maintenance

### Ongoing Maintenance
- **Daily**: Monitor database health, backup verification
- **Weekly**: Performance metrics review, user access audit
- **Monthly**: Index maintenance, statistics refresh, compliance audit
- **Quarterly**: Capacity planning, security assessment, retention policy execution

### Contacts
- **Database Administrator**: [Contact info]
- **HR System Owner**: [Contact info]
- **Technical Support**: [Contact info]

---

## 📦 Deliverables

✅ **Design Documents**
- HRIS_Database_Design_Analysis.txt - Comprehensive 27KB design specification
- HRIS_Schema_Specification.xlsx - Table definitions with column details
- This README - Implementation roadmap & summary

✅ **Connection Info**
- Host: localhost:5440
- Database: hris_db
- User: hris_admin
- Connection String: `postgresql://hris_admin:hris_secure_pw@localhost:5440/hris_db`

---

## 🚀 Next Steps

1. **Review & Approve Design**
   - Share design documents with stakeholders
   - Address any questions or concerns
   - Get sign-off from HR Leadership & IT

2. **Establish Project Team**
   - Database Administrator (1)
   - Backend Developer (2-3)
   - HR Business Analyst (1)
   - QA/Tester (1)

3. **Procurement & Setup**
   - Procure production infrastructure (if not cloud)
   - Set up development & staging environments
   - Prepare data migration plan

4. **Begin Phase 1**
   - Start with core infrastructure setup
   - Establish monitoring & alerting
   - Plan data migration from legacy system

5. **Schedule Kickoff Meeting**
   - Review timeline & deliverables
   - Define communication plan
   - Establish governance & approval process

---

**Document Version**: 1.0  
**Last Updated**: 2026-03-31  
**Status**: Ready for Implementation

