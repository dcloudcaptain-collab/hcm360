"""
Analytics Service
Queries the analytics schema (star schema / kpi_snapshots).
Never writes to transactional schemas — analytics reads only.
"""
from datetime import date, timedelta
from services.db import get_cursor


# ---------------------------------------------------------------------------
# KPI Snapshots
# ---------------------------------------------------------------------------

def refresh_kpi_snapshot(module=None):
    """
    Re-compute KPI values and upsert into analytics.kpi_snapshots.
    Called nightly by a cron job or manually by HR Admin.
    If module is given, only refreshes that module's KPIs.
    """
    ETL_QUERIES = {
        'attendance': [
            ("PRESENT_TODAY", "Present Today", """
                SELECT COUNT(*) FROM attendance.att_daily
                WHERE work_date = CURRENT_DATE AND status = 'PRESENT'
            """),
            ("LATE_TODAY", "Late Today", """
                SELECT COUNT(*) FROM attendance.att_daily
                WHERE work_date = CURRENT_DATE AND status = 'LATE'
            """),
            ("ABSENT_TODAY", "Absent Today", """
                SELECT COUNT(*) FROM attendance.att_daily
                WHERE work_date = CURRENT_DATE AND status = 'ABSENT'
            """),
            ("ATTENDANCE_RATE_30D", "Attendance Rate 30d %", """
                SELECT ROUND(
                    COUNT(*) FILTER (WHERE status IN ('PRESENT', 'LATE'))::NUMERIC
                    / NULLIF(COUNT(*), 0) * 100, 2
                )
                FROM attendance.att_daily
                WHERE work_date >= CURRENT_DATE - 29
            """),
            ("PENDING_OT", "Pending OT Approvals", """
                SELECT COUNT(*) FROM attendance.att_overtime_requests
                WHERE status = 'PENDING'
            """),
        ],
        'leave': [
            ("LEAVE_PENDING", "Pending Leave Requests", """
                SELECT COUNT(*) FROM leave_mgmt.lv_requests
                WHERE status = 'PENDING'
            """),
            ("ON_LEAVE_TODAY", "On Leave Today", """
                SELECT COUNT(*) FROM leave_mgmt.lv_locator_entries
                WHERE log_date = CURRENT_DATE AND location_type = 'ON_LEAVE'
            """),
        ],
        'payroll': [
            ("PAYROLL_CURRENT_HEADCOUNT", "Current Cutoff Headcount", """
                SELECT COUNT(*) FROM payroll.pay_employee_payroll ep
                JOIN payroll.pay_runs pr ON pr.id = ep.run_id
                WHERE pr.status IN ('PROCESSING', 'SUBMITTED')
            """),
            ("PAYROLL_NET_TOTAL", "Current Cutoff Net Pay", """
                SELECT COALESCE(SUM(ep.net_pay), 0)
                FROM payroll.pay_employee_payroll ep
                JOIN payroll.pay_runs pr ON pr.id = ep.run_id
                WHERE pr.status IN ('PROCESSING', 'SUBMITTED')
            """),
        ],
        'core': [
            ("HEADCOUNT_ACTIVE", "Active Headcount", """
                SELECT COUNT(*) FROM core.employees
                WHERE is_active = TRUE
            """),
            ("MISSING_DOCS", "Employees Missing Documents", """
                SELECT COUNT(DISTINCT e.id)
                FROM core.v_employees_full e
                WHERE e.is_active = TRUE
                  AND (
                    SELECT COUNT(*) FROM core.documents d
                    WHERE d.employee_id = e.id
                  ) < 5
            """),
        ],
    }

    modules_to_run = [module] if module else list(ETL_QUERIES.keys())

    with get_cursor(commit=True) as cur:
        today = date.today()
        for mod in modules_to_run:
            for kpi_code, kpi_label, sql in ETL_QUERIES.get(mod, []):
                try:
                    cur.execute(sql)
                    row = cur.fetchone()
                    val = list(row.values())[0] if row else 0
                except Exception:
                    val = None
                    continue

                cur.execute("""
                    INSERT INTO analytics.kpi_snapshots
                        (module, kpi_code, kpi_label, kpi_value, snapshot_date)
                    VALUES (%s, %s, %s, %s, %s)
                    ON CONFLICT (module, kpi_code, snapshot_date)
                    DO UPDATE SET kpi_value = EXCLUDED.kpi_value,
                                  kpi_label = EXCLUDED.kpi_label,
                                  created_at = NOW()
                """, (mod, kpi_code, kpi_label, val, today))


# ---------------------------------------------------------------------------
# Dashboard widgets
# ---------------------------------------------------------------------------

def get_dashboard_widgets(role_code=None):
    """
    Returns role-filtered KPI card definitions with live values.
    Delegates live SQL execution to kpi_service.get_dashboard_metrics().
    """
    from services.kpi_service import get_dashboard_metrics
    return get_dashboard_metrics(role_code=role_code)


def get_kpi_trend(module, kpi_code, days=30):
    """Return daily kpi_value trend for a specific KPI over last N days."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT snapshot_date, kpi_value, kpi_label
            FROM analytics.kpi_snapshots
            WHERE module = %s
              AND kpi_code = %s
              AND snapshot_date >= CURRENT_DATE - %s
            ORDER BY snapshot_date
        """, (module, kpi_code, days - 1))
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Headcount analytics
# ---------------------------------------------------------------------------

def get_headcount_by_dept(as_of=None):
    with get_cursor() as cur:
        if as_of:
            cur.execute("""
                SELECT * FROM analytics.v_headcount_by_dept
            """)
        else:
            cur.execute("SELECT * FROM analytics.v_headcount_by_dept")
        return cur.fetchall()


def get_headcount_trend(months=6):
    """Monthly headcount snapshots over the last N months."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                DATE_TRUNC('month', snapshot_date)::DATE AS month,
                kpi_value AS headcount
            FROM analytics.kpi_snapshots
            WHERE kpi_code = 'HEADCOUNT_ACTIVE'
              AND snapshot_date >= CURRENT_DATE - (%s * INTERVAL '1 month')
            ORDER BY month
        """, (months,))
        return cur.fetchall()


def get_attrition_summary(year=None):
    year = year or date.today().year
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                TO_CHAR(DATE_TRUNC('month', esh.created_at), 'Mon YYYY') AS month,
                DATE_TRUNC('month', esh.created_at)::DATE                 AS month_date,
                COUNT(*) AS separations
            FROM core.emp_status_history esh
            WHERE esh.to_status IN ('RESIGNED', 'TERMINATED', 'RETIRED')
              AND EXTRACT(YEAR FROM esh.created_at) = %s
            GROUP BY DATE_TRUNC('month', esh.created_at)
            ORDER BY month_date
        """, (year,))
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Attendance analytics
# ---------------------------------------------------------------------------

def get_attendance_rate_trend(days=30):
    with get_cursor() as cur:
        cur.execute("SELECT * FROM analytics.v_attendance_rate_30d")
        return cur.fetchall()


def get_late_analysis(date_from=None, date_to=None):
    """Late arrivals by department for a date range."""
    date_from = date_from or (date.today() - timedelta(days=29))
    date_to   = date_to   or date.today()
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                d.name AS department,
                COUNT(*) FILTER (WHERE ad.status = 'LATE')                     AS late_count,
                COUNT(*) FILTER (WHERE ad.status IN ('PRESENT', 'LATE'))       AS present_count,
                ROUND(
                    COUNT(*) FILTER (WHERE ad.status = 'LATE')::NUMERIC
                    / NULLIF(COUNT(*) FILTER (WHERE ad.status IN ('PRESENT', 'LATE')), 0) * 100, 1
                ) AS late_rate_pct,
                ROUND(AVG(ad.hours_late * 60) FILTER (WHERE ad.status = 'LATE'), 0) AS avg_late_min
            FROM attendance.att_daily ad
            JOIN core.v_employees_full e ON e.id = ad.employee_id
            JOIN core.departments d ON d.id = e.department_id
            WHERE ad.work_date BETWEEN %s AND %s
            GROUP BY d.name
            ORDER BY late_rate_pct DESC
        """, (date_from, date_to))
        return cur.fetchall()


def get_ot_summary(date_from=None, date_to=None):
    date_from = date_from or (date.today() - timedelta(days=29))
    date_to   = date_to   or date.today()
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                d.name AS department,
                COUNT(aor.id)   AS ot_requests,
                SUM(aor.expected_ot_hours) AS total_ot_hours,
                COUNT(*) FILTER (WHERE aor.status = 'APPROVED') AS approved
            FROM attendance.att_overtime_requests aor
            JOIN core.v_employees_full e ON e.id = aor.employee_id
            JOIN core.departments d ON d.id = e.department_id
            WHERE aor.request_date BETWEEN %s AND %s
            GROUP BY d.name
            ORDER BY total_ot_hours DESC NULLS LAST
        """, (date_from, date_to))
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Leave analytics
# ---------------------------------------------------------------------------

def get_leave_utilization_ytd():
    with get_cursor() as cur:
        cur.execute("SELECT * FROM analytics.v_leave_utilization_ytd")
        return cur.fetchall()


def get_leave_trend(months=6):
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                DATE_TRUNC('month', lr.date_from)::DATE AS month,
                lt.code AS leave_type,
                COUNT(lr.id) AS requests,
                SUM(lr.days_requested) AS total_days
            FROM leave_mgmt.lv_requests lr
            JOIN leave_mgmt.lv_types lt ON lt.id = lr.leave_type_id
            WHERE lr.status = 'APPROVED'
              AND lr.date_from >= DATE_TRUNC('month', CURRENT_DATE)
                               - (%s - 1) * INTERVAL '1 month'
            GROUP BY DATE_TRUNC('month', lr.date_from), lt.code
            ORDER BY month, lt.code
        """, (months,))
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Payroll analytics
# ---------------------------------------------------------------------------

def get_payroll_cost_mtd():
    with get_cursor() as cur:
        cur.execute("SELECT * FROM analytics.v_payroll_cost_mtd")
        return cur.fetchall()


def get_payroll_trend(months=6):
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                DATE_TRUNC('month', prd.date_from)::DATE AS month,
                SUM(pp.gross_pay)          AS total_gross,
                SUM(pp.net_pay)            AS total_net,
                SUM(pp.total_deductions)   AS total_deductions,
                COUNT(DISTINCT pp.employee_id) AS headcount
            FROM payroll.pay_employee_payroll pp
            JOIN payroll.pay_runs pr ON pr.id = pp.run_id
            JOIN payroll.pay_periods prd ON prd.id = pr.period_id
            WHERE pr.status = 'COMPLETED'
              AND prd.date_from >= DATE_TRUNC('month', CURRENT_DATE)
                                   - (%s - 1) * INTERVAL '1 month'
            GROUP BY DATE_TRUNC('month', prd.date_from)
            ORDER BY month
        """, (months,))
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Fact table refresh helpers
# ---------------------------------------------------------------------------

def refresh_fact_attendance(work_date=None):
    """
    Upsert fact_attendance from att_daily for a given date (default: today).
    """
    work_date = work_date or date.today()
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO analytics.fact_attendance
                (date_key, employee_dim_id, shift_id,
                 time_in, time_out, worked_hours,
                 late_minutes, ot_hours,
                 is_present, is_late, is_absent, is_holiday, is_restday)
            SELECT
                TO_CHAR(ad.work_date, 'YYYYMMDD')::INTEGER,
                de.id,
                ad.shift_id,
                ad.time_in, ad.time_out, ad.worked_hours,
                ad.late_minutes, ad.ot_hours,
                ad.is_present, ad.is_late, ad.is_absent,
                ad.is_holiday, ad.is_restday
            FROM attendance.att_daily ad
            JOIN analytics.dim_employee de ON de.employee_id = ad.employee_id
            WHERE ad.work_date = %s
            ON CONFLICT (date_key, employee_dim_id)
            DO UPDATE SET
                time_in      = EXCLUDED.time_in,
                time_out     = EXCLUDED.time_out,
                worked_hours = EXCLUDED.worked_hours,
                late_minutes = EXCLUDED.late_minutes,
                ot_hours     = EXCLUDED.ot_hours,
                is_present   = EXCLUDED.is_present,
                is_late      = EXCLUDED.is_late,
                is_absent    = EXCLUDED.is_absent
        """, (work_date,))


def refresh_fact_leave(leave_request_id=None):
    """
    Upsert fact_leave for approved leave requests.
    If leave_request_id given, refresh only that one row.
    """
    with get_cursor(commit=True) as cur:
        if leave_request_id:
            cur.execute("""
                INSERT INTO analytics.fact_leave
                    (leave_request_id, employee_dim_id,
                     leave_type_id, date_from, date_to, total_days, status)
                SELECT
                    lr.id,
                    de.id,
                    lr.leave_type_id,
                    lr.date_from, lr.date_to, lr.days_requested, lr.status
                FROM leave_mgmt.lv_requests lr
                JOIN analytics.dim_employee de ON de.employee_id = lr.employee_id
                WHERE lr.id = %s
                ON CONFLICT (leave_request_id)
                DO UPDATE SET status = EXCLUDED.status,
                              total_days = EXCLUDED.total_days
            """, (leave_request_id,))
        else:
            cur.execute("""
                INSERT INTO analytics.fact_leave
                    (leave_request_id, employee_dim_id,
                     leave_type_id, date_from, date_to, total_days, status)
                SELECT
                    lr.id,
                    de.id,
                    lr.leave_type_id,
                    lr.date_from, lr.date_to, lr.days_requested, lr.status
                FROM leave_mgmt.lv_requests lr
                JOIN analytics.dim_employee de ON de.employee_id = lr.employee_id
                WHERE lr.status = 'APPROVED'
                ON CONFLICT (leave_request_id)
                DO UPDATE SET status = EXCLUDED.status
            """)
