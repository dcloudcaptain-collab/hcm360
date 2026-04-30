TITLE = 'KPI Explanation'
SUBTITLE = 'What every dashboard metric means and how it is computed'
FOLDER = 'user'

BLOCKS = [
    ('H1', '1. Where KPIs Live'),
    ('P', 'HCM360 displays KPIs in several places. Each one draws from the same underlying data so numbers are consistent across the platform. Where definitions could differ (e.g., "active" headcount), the system uses the same rule everywhere.'),
    ('TABLE', ['Location', 'Audience'],
     [
        ['/ (main dashboard)', 'All roles — role-filtered card set'],
        ['/me/ (My Portal)', 'Employee — personal metrics'],
        ['/reports/demographics', 'HR Admin, Executive — org-wide demographics'],
        ['/reports (report builder)', 'HR Admin — custom saved queries'],
        ['/workforce-planning/', 'HR Admin, Executive — scenario comparisons'],
     ]),

    ('H1', '2. Core HR KPIs'),

    ('H2', '2.1 Total Headcount'),
    ('P', 'Count of all employee records regardless of status. Includes probationary, regular, on-leave, and any non-terminated statuses.'),
    ('CODE', 'SELECT COUNT(*) FROM core.employees WHERE company_id = :company'),

    ('H2', '2.2 Active Headcount'),
    ('P', 'Count of employees with status = ACTIVE only. Excludes probationary, resigned, retired, terminated.'),
    ('CODE', 'SELECT COUNT(*) FROM core.employees\n'
     'WHERE company_id = :company AND status = \'ACTIVE\''),

    ('H2', '2.3 Regularization Rate'),
    ('P', 'Percentage of probationary employees regularized within the probation window.'),
    ('CODE', 'regularized / (regularized + terminated_during_probation) × 100'),

    ('H2', '2.4 Attrition Rate (rolling 12 months)'),
    ('CODE', '(employees_who_left_last_12mo / avg_headcount_last_12mo) × 100'),

    ('H1', '3. Attendance KPIs'),

    ('H2', '3.1 Present Today'),
    ('CODE', 'SELECT COUNT(*) FROM attendance.att_daily\n'
     'WHERE work_date = CURRENT_DATE\n'
     '  AND time_in IS NOT NULL AND NOT is_absent'),

    ('H2', '3.2 Late Today'),
    ('CODE', 'SELECT COUNT(*) FROM attendance.att_daily\n'
     'WHERE work_date = CURRENT_DATE AND is_late = TRUE'),

    ('H2', '3.3 On Leave Today'),
    ('CODE', 'SELECT COUNT(DISTINCT employee_id) FROM leave_mgmt.lv_requests\n'
     'WHERE CURRENT_DATE BETWEEN date_from AND date_to\n'
     '  AND status = \'APPROVED\''),

    ('H2', '3.4 Average Monthly Tardiness'),
    ('P', 'Average late minutes per employee per month. High values indicate schedule or commute issues.'),

    ('H2', '3.5 Overtime Hours (MTD)'),
    ('P', 'Sum of ot_regular_hours + ot_restday_hours + ot_holiday_hours for the current month.'),

    ('H1', '4. Leave KPIs'),

    ('H2', '4.1 Pending Leave Requests'),
    ('CODE', 'SELECT COUNT(*) FROM leave_mgmt.lv_requests WHERE status = \'PENDING\''),

    ('H2', '4.2 Leave Utilization Rate'),
    ('P', 'Total days used divided by total entitlement for the year. Typical healthy range: 70–85%.'),

    ('H2', '4.3 Top Leave Types'),
    ('P', 'Breakdown of approved leave days by type. Useful for identifying wellness trends (spikes in sick leave) or policy review (low SIL usage).'),

    ('H1', '5. Payroll KPIs'),

    ('H2', '5.1 Total Payroll Cost (MTD)'),
    ('P', 'Sum of gross_pay for all posted runs in the current month.'),

    ('H2', '5.2 Employer Statutory Cost'),
    ('P', 'Total SSS ER + PhilHealth ER + HDMF ER contributions. Plan benchmark: typically 8–12% of gross.'),

    ('H2', '5.3 Net Pay per Employee'),
    ('CODE', 'SELECT AVG(net_pay) FROM payroll.pay_employee_payroll ep\n'
     'JOIN payroll.pay_runs pr ON pr.id = ep.run_id\n'
     'WHERE pr.status = \'POSTED\' AND pr.run_date >= CURRENT_DATE - INTERVAL \'30 days\''),

    ('H2', '5.4 Loan Balance (outstanding)'),
    ('P', 'Sum of balance on active loans. Tracked across SSS salary loan, Pag-IBIG, and company loans.'),

    ('H1', '6. Recruitment KPIs'),

    ('H2', '6.1 Open Requisitions'),
    ('P', 'Requisitions with status OPEN or APPROVED but unfilled.'),

    ('H2', '6.2 Time to Fill'),
    ('P', 'Average days between requisition APPROVED date and offer ACCEPTED date.'),

    ('H2', '6.3 Offer Acceptance Rate'),
    ('CODE', 'accepted_offers / total_offers × 100'),

    ('H1', '7. Performance KPIs'),

    ('H2', '7.1 Review Completion Rate'),
    ('P', 'Percentage of evaluations submitted before cycle deadline. Drops indicate engagement or workload issues.'),

    ('H2', '7.2 Rating Distribution'),
    ('P', 'Histogram of final ratings across cycle. A healthy bell curve clusters around the middle rating with thinner tails.'),

    ('H1', '8. Learning & Development KPIs'),

    ('H2', '8.1 Training Hours per Employee (YTD)'),
    ('P', 'Sum of training hours completed per employee year-to-date.'),

    ('H2', '8.2 Certification Expiry in 90 Days'),
    ('P', 'Number of employee certifications expiring in the next 90 days. Triggers renewal reminders.'),

    ('H1', '9. Inbox & Workflow KPIs'),

    ('H2', '9.1 Action Items (Pending)'),
    ('P', 'Total inbox items with status unread + read-but-not-actioned.'),

    ('H2', '9.2 Unread'),
    ('P', 'Items never opened. Red badge on the bell indicates this count.'),

    ('H2', '9.3 Urgent'),
    ('P', 'Items flagged URGENT priority. Left-border of their card goes red.'),

    ('H1', '10. Workforce Planning KPIs'),

    ('H2', '10.1 Current vs. Planned Headcount'),
    ('P', 'For each department, shows current active headcount next to scenario-targeted headcount for the end of horizon. Gap = target − current.'),

    ('H2', '10.2 Projected Cost (scenario)'),
    ('P', 'Monthly salary + benefits + training + recruitment cost projected from scenario assumptions.'),

    ('H2', '10.3 Skill Gap'),
    ('P', 'For each skill: future_demand − current_supply. Positive = need to hire/train; negative = surplus.'),

    ('H1', '11. Privacy & Access KPIs'),

    ('H2', '11.1 Masked Field Access Count'),
    ('P', 'Number of times masked fields were fetched (for audit). Supports privacy impact assessments.'),

    ('H2', '11.2 Access Matrix Changes (last 30 days)'),
    ('P', 'Count of changes in role_page_access / role_feature_access from audit_logs.change_log. Anomalies warrant review.'),

    ('H1', '12. Color Coding Conventions'),
    ('P', 'Numbers across the dashboard use consistent colors so your eye can pattern-match quickly.'),
    ('TABLE', ['Color', 'Meaning'],
     [
        ['Green', 'Within target; healthy'],
        ['Amber / Yellow', 'Approaching threshold; monitor'],
        ['Red', 'Off target; requires action'],
        ['Indigo (primary)', 'Neutral — informational only'],
        ['Gray', 'No data / N/A'],
     ]),

    ('H1', '13. Drilling Into KPIs'),
    ('P', 'Every KPI card on the main dashboard is clickable. Following a KPI opens the underlying list or report so you can see the individual records that contributed to the number. Filters at the top of the drill-in view let you slice by department, employment type, or date range.'),

    ('H1', '14. Adding New KPIs'),
    ('P', 'Administrators can add KPIs at Admin → Reference Data → Dashboard Metrics. Each metric has:'),
    ('UL', [
        'code — unique identifier',
        'label — display name',
        'sql_query — the count/sum expression',
        'filter_url — where to drill in (e.g., /employees?status=ACTIVE)',
        'roles — array of role codes that see the metric',
        'icon, module, sort_order — presentation',
     ]),
    ('P', 'Save the metric and it appears on the dashboard immediately for the allowed roles.'),
]
