"""Analytics module service — thin wrapper delegating to services/analytics_service.py."""
# All heavy lifting is in services/analytics_service.py.
# This module-level file re-exports what routes.py needs so imports stay local.
from services.analytics_service import (
    get_dashboard_widgets,
    get_kpi_trend,
    get_headcount_by_dept,
    get_headcount_trend,
    get_attrition_summary,
    get_attendance_rate_trend,
    get_late_analysis,
    get_ot_summary,
    get_leave_utilization_ytd,
    get_leave_trend,
    get_payroll_cost_mtd,
    get_payroll_trend,
    refresh_kpi_snapshot,
)
from services.kpi_service import get_kpi_snapshot
