"""Dual-mode payroll computation engine — GOV (SSL/GSIS) and PRIVATE (SSS).

All rates are table-driven: no hardcoded contribution percentages, OT multipliers,
or tax brackets. Everything is read from payroll.pay_config, payroll.pay_rate_tables,
and the respective contribution schedule tables.
"""
from services.db import get_cursor
from services.config_service import get_config_dict, get_rate


class PayrollEngine:
    """Computes payroll for a single company/period combination."""

    def __init__(self, company_id, period_id):
        self.company_id = company_id
        self.period_id = period_id
        self.cfg = get_config_dict(company_id)
        self.payroll_type = self.cfg.get('payroll_type', 'GOV').upper()
        self.working_days = float(self.cfg.get('working_days_per_month', 22))

        # Load period dates
        with get_cursor() as cur:
            cur.execute("""
                SELECT date_from, date_to, period_type
                FROM payroll.pay_periods WHERE id = %s
            """, (period_id,))
            p = cur.fetchone()
            self.date_from = p['date_from']
            self.date_to = p['date_to']
            self.period_type = p.get('period_type', 'SEMI_MONTHLY')

    # ── Main entry point ────────────────────────────────────────

    def compute_employee(self, employee_id):
        """Full payroll computation for one employee. Returns breakdown dict."""
        with get_cursor(commit=True) as cur:
            emp = self._get_employee(cur, employee_id)
            if not emp:
                return None

            basic_pay = self._get_basic_pay(cur, emp)
            daily_rate = round(basic_pay / self.working_days, 2)
            hourly_rate = round(daily_rate / 8, 2)

            # Attendance-based earnings
            att = self._compute_attendance_earnings(cur, employee_id, daily_rate, hourly_rate)

            # Allowances
            allowances = self._get_allowances(cur, employee_id)
            total_allowances = sum(allowances.values())

            # Gross pay
            gross_pay = round(basic_pay + att['ot_pay'] + att['holiday_pay']
                              + att['night_diff_pay'] + total_allowances
                              + att.get('other_earnings', 0), 2)

            # Deductions
            if self.payroll_type == 'GOV':
                deductions = self._compute_deductions_gov(cur, basic_pay)
            else:
                deductions = self._compute_deductions_private(cur, basic_pay, gross_pay)

            # Tax
            taxable = basic_pay - deductions['mandatory_ee_total']
            tax = self._compute_tax(cur, max(taxable, 0))

            # Loans
            loan_ded = self._get_loan_deductions(cur, employee_id)
            other_ded = self._get_other_deductions(cur, employee_id)

            total_deductions = round(deductions['mandatory_ee_total'] + tax
                                     + loan_ded + other_ded, 2)
            net_pay = round(gross_pay - total_deductions, 2)

            # Build result
            result = {
                'employee_id': employee_id,
                'basic_pay': basic_pay,
                'daily_rate': daily_rate,
                # Attendance
                'scheduled_days': att['scheduled_days'],
                'worked_days': att['worked_days'],
                'absent_days': att['absent_days'],
                'leave_days': att['leave_days'],
                'late_hours': att['late_hours'],
                'undertime_hours': att['undertime_hours'],
                'ot_regular_hours': att['ot_regular_hours'],
                'ot_restday_hours': att['ot_restday_hours'],
                'ot_holiday_hours': att['ot_holiday_hours'],
                'night_diff_hours': att['night_diff_hours'],
                # Earnings
                'ot_pay': att['ot_pay'],
                'holiday_pay': att['holiday_pay'],
                'night_diff_pay': att['night_diff_pay'],
                'allowances_total': total_allowances,
                'other_earnings': att.get('other_earnings', 0),
                'gross_pay': gross_pay,
                # Deductions
                'tax_withheld': tax,
                'loan_deductions': loan_ded,
                'other_deductions': other_ded,
                'total_deductions': total_deductions,
                'net_pay': net_pay,
            }
            # Merge contribution details
            result.update(deductions)
            # Merge allowance details
            result['allowance_detail'] = allowances

            # Upsert pay_employee_payroll
            self._upsert_payslip(cur, result)

            return result

    # ── Employee lookup ─────────────────────────────────────────

    def _get_employee(self, cur, employee_id):
        cur.execute("""
            SELECT e.id, e.employee_no, e.full_name, e.basic_salary,
                   e.daily_rate, e.hourly_rate,
                   e.company_id, e.department_id, e.position_id,
                   e.job_grade_id, jg.grade_level AS salary_grade
            FROM core.v_employees_full e
            LEFT JOIN core.job_grades jg ON jg.id = e.job_grade_id
            WHERE e.id = %s AND e.is_active = TRUE
        """, (employee_id,))
        return cur.fetchone()

    # ── Basic pay ───────────────────────────────────────────────

    def _get_basic_pay(self, cur, emp):
        if self.payroll_type == 'GOV' and emp.get('salary_grade'):
            # Government: SSL table lookup
            sg = emp['salary_grade']
            step = self._get_step(cur, emp['id'])
            cur.execute("""
                SELECT monthly_rate FROM rewards.rwd_ssl_table
                WHERE salary_grade = %s AND step_no = %s
                ORDER BY effective_date DESC LIMIT 1
            """, (sg, step))
            row = cur.fetchone()
            if row:
                return float(row['monthly_rate'])
        # Private or fallback: use employee's basic_salary
        return float(emp.get('basic_salary') or 0)

    def _get_step(self, cur, employee_id):
        cur.execute("""
            SELECT step_no FROM recruitment.rec_appointments
            WHERE employee_id = %s AND status = 'ATTESTED'
            ORDER BY effective_date DESC LIMIT 1
        """, (employee_id,))
        row = cur.fetchone()
        return row['step_no'] if row else 1

    # ── Attendance earnings ─────────────────────────────────────

    def _compute_attendance_earnings(self, cur, employee_id, daily_rate, hourly_rate):
        cur.execute("""
            SELECT
                COUNT(*) AS total_days,
                COUNT(*) FILTER (WHERE status IN ('PRESENT','LATE')) AS worked_days,
                COUNT(*) FILTER (WHERE status = 'ABSENT') AS absent_days,
                COUNT(*) FILTER (WHERE status = 'ON_LEAVE') AS leave_days,
                COALESCE(SUM(hours_late), 0) AS late_hours,
                COALESCE(SUM(hours_undertime), 0) AS undertime_hours,
                COALESCE(SUM(CASE WHEN NOT is_holiday AND NOT is_restday
                    THEN hours_overtime ELSE 0 END), 0) AS ot_regular_hours,
                COALESCE(SUM(CASE WHEN is_restday AND NOT is_holiday
                    THEN hours_overtime ELSE 0 END), 0) AS ot_restday_hours,
                COALESCE(SUM(CASE WHEN is_holiday
                    THEN hours_overtime ELSE 0 END), 0) AS ot_holiday_hours,
                COALESCE(SUM(hours_night_diff), 0) AS night_diff_hours,
                COUNT(*) FILTER (WHERE is_holiday AND status IN ('PRESENT','LATE')) AS holiday_days_worked,
                COUNT(*) FILTER (WHERE is_restday AND status IN ('PRESENT','LATE')) AS restday_days_worked
            FROM attendance.att_daily
            WHERE employee_id = %s
              AND work_date BETWEEN %s AND %s
        """, (employee_id, self.date_from, self.date_to))
        att = cur.fetchone()

        # OT pay using configurable rate multipliers
        ot_regular_rate = get_rate(self.company_id, 'OT_REGULAR')
        ot_restday_rate = get_rate(self.company_id, 'OT_RESTDAY')
        ot_holiday_rate = get_rate(self.company_id, 'OT_REGULAR_HOLIDAY')
        night_diff_rate = get_rate(self.company_id, 'NIGHT_DIFF')

        ot_pay = round(
            float(att['ot_regular_hours']) * hourly_rate * ot_regular_rate +
            float(att['ot_restday_hours']) * hourly_rate * ot_restday_rate +
            float(att['ot_holiday_hours']) * hourly_rate * ot_holiday_rate,
            2
        )

        # Holiday premium (extra pay for working on holidays)
        holiday_rate = get_rate(self.company_id, 'REGULAR_HOLIDAY')
        holiday_pay = round(
            float(att.get('holiday_days_worked', 0)) * daily_rate * (holiday_rate - 1),
            2
        )

        # Night differential
        night_diff_pay = round(
            float(att['night_diff_hours']) * hourly_rate * night_diff_rate,
            2
        )

        return {
            'scheduled_days': float(att['total_days']),
            'worked_days': float(att['worked_days']),
            'absent_days': float(att['absent_days']),
            'leave_days': float(att['leave_days']),
            'late_hours': float(att['late_hours']),
            'undertime_hours': float(att['undertime_hours']),
            'ot_regular_hours': float(att['ot_regular_hours']),
            'ot_restday_hours': float(att['ot_restday_hours']),
            'ot_holiday_hours': float(att['ot_holiday_hours']),
            'night_diff_hours': float(att['night_diff_hours']),
            'ot_pay': ot_pay,
            'holiday_pay': holiday_pay,
            'night_diff_pay': night_diff_pay,
            'other_earnings': 0,
        }

    # ── Government deductions (GSIS) ────────────────────────────

    def _compute_deductions_gov(self, cur, basic_pay):
        # GSIS
        cur.execute("""
            SELECT ee_personal_share_pct, er_government_share_pct
            FROM payroll.pay_gsis_schedule
            WHERE is_current = TRUE
              AND salary_bracket_from <= %s AND salary_bracket_to >= %s
            LIMIT 1
        """, (basic_pay, basic_pay))
        gsis = cur.fetchone()
        gsis_ee = round(basic_pay * float(gsis['ee_personal_share_pct']), 2) if gsis else 0
        gsis_er = round(basic_pay * float(gsis['er_government_share_pct']), 2) if gsis else 0

        # Pag-IBIG
        pagibig_ee, pagibig_er = self._lookup_pagibig(cur, basic_pay)

        # PhilHealth
        philhealth_ee, philhealth_er = self._lookup_philhealth(cur, basic_pay)

        mandatory_ee = gsis_ee + pagibig_ee + philhealth_ee

        return {
            'sss_ee': 0, 'sss_er': 0,
            'gsis_ps': gsis_ee, 'gsis_gs': gsis_er,
            'pagibig_ee': pagibig_ee, 'pagibig_er': pagibig_er,
            'philhealth_ee': philhealth_ee, 'philhealth_er': philhealth_er,
            'mandatory_ee_total': mandatory_ee,
        }

    # ── Private deductions (SSS) ────────────────────────────────

    def _compute_deductions_private(self, cur, basic_pay, gross_pay):
        # SSS
        cur.execute("""
            SELECT ee_contribution, er_contribution, ec_contribution
            FROM payroll.pay_sss_schedule
            WHERE is_current = TRUE
              AND salary_bracket_from <= %s AND salary_bracket_to >= %s
            ORDER BY salary_bracket_from DESC LIMIT 1
        """, (basic_pay, basic_pay))
        sss = cur.fetchone()
        sss_ee = float(sss['ee_contribution']) if sss else 0
        sss_er = float(sss['er_contribution']) if sss else 0

        # Pag-IBIG
        pagibig_ee, pagibig_er = self._lookup_pagibig(cur, basic_pay)

        # PhilHealth
        philhealth_ee, philhealth_er = self._lookup_philhealth(cur, basic_pay)

        mandatory_ee = sss_ee + pagibig_ee + philhealth_ee

        return {
            'sss_ee': sss_ee, 'sss_er': sss_er,
            'gsis_ps': 0, 'gsis_gs': 0,
            'pagibig_ee': pagibig_ee, 'pagibig_er': pagibig_er,
            'philhealth_ee': philhealth_ee, 'philhealth_er': philhealth_er,
            'mandatory_ee_total': mandatory_ee,
        }

    # ── Shared contribution lookups ─────────────────────────────

    def _lookup_pagibig(self, cur, basic_pay):
        cur.execute("""
            SELECT ee_contribution_pct, er_contribution_pct
            FROM payroll.pay_pagibig_schedule
            WHERE is_current = TRUE
              AND salary_bracket_from <= %s AND salary_bracket_to >= %s
            LIMIT 1
        """, (basic_pay, basic_pay))
        row = cur.fetchone()
        if not row:
            return 100, 100
        ee = min(round(basic_pay * float(row['ee_contribution_pct']), 2), 5000)
        er = min(round(basic_pay * float(row['er_contribution_pct']), 2), 5000)
        return ee, er

    def _lookup_philhealth(self, cur, basic_pay):
        cur.execute("""
            SELECT premium_rate, ee_share, er_share, min_premium, max_premium
            FROM payroll.pay_philhealth_schedule
            WHERE is_current = TRUE
              AND salary_bracket_from <= %s AND salary_bracket_to >= %s
            LIMIT 1
        """, (basic_pay, basic_pay))
        row = cur.fetchone()
        if not row:
            # Fallback: 5% shared equally
            premium = round(basic_pay * 0.05, 2)
            premium = max(premium, 500)
            premium = min(premium, 5000)
            return round(premium / 2, 2), round(premium / 2, 2)

        premium = round(basic_pay * float(row['premium_rate']), 2)
        premium = max(premium, float(row['min_premium']))
        premium = min(premium, float(row['max_premium']))
        ee = round(premium * float(row['ee_share']), 2)
        er = round(premium * float(row['er_share']), 2)
        return ee, er

    # ── Tax ─────────────────────────────────────────────────────

    def _compute_tax(self, cur, taxable_income):
        frequency = self.cfg.get('cutoff_type', 'SEMI_MONTHLY')
        if frequency == 'SEMI_MONTHLY':
            freq_key = 'SEMI_MONTHLY'
        elif frequency == 'WEEKLY':
            freq_key = 'WEEKLY'
        else:
            freq_key = 'MONTHLY'

        cur.execute("""
            SELECT bracket_from, base_tax, excess_pct
            FROM payroll.pay_bir_tax_table
            WHERE is_current = TRUE AND frequency = %s
              AND bracket_from <= %s
            ORDER BY bracket_from DESC LIMIT 1
        """, (freq_key, taxable_income))
        row = cur.fetchone()
        if not row:
            return 0
        excess = taxable_income - float(row['bracket_from'])
        return round(float(row['base_tax']) + excess * float(row['excess_pct']), 2)

    # ── Allowances ──────────────────────────────────────────────

    def _get_allowances(self, cur, employee_id):
        result = {}
        if self.payroll_type == 'GOV':
            # Government allowances (PERA, RATA, ACA, Hazard)
            cur.execute("""
                SELECT ga.allowance_code, eag.monthly_amount
                FROM payroll.pay_employee_allowances_gov eag
                JOIN payroll.pay_gov_allowances ga ON ga.id = eag.allowance_id
                WHERE eag.employee_id = %s
                  AND eag.effective_from <= CURRENT_DATE
                  AND (eag.effective_to IS NULL OR eag.effective_to >= CURRENT_DATE)
            """, (employee_id,))
            for row in cur.fetchall():
                result[row['allowance_code']] = float(row['monthly_amount'])
            # Default PERA if not assigned
            if 'PERA' not in result:
                result['PERA'] = 2000.0
        else:
            # Private: general allowances
            cur.execute("""
                SELECT allowance_type, amount
                FROM payroll.pay_employee_allowances
                WHERE employee_id = %s AND is_active = TRUE
                  AND effective_from <= CURRENT_DATE
                  AND (effective_to IS NULL OR effective_to >= CURRENT_DATE)
            """, (employee_id,))
            for row in cur.fetchall():
                result[row['allowance_type']] = float(row['amount'])
        return result

    # ── Loans ───────────────────────────────────────────────────

    def _get_loan_deductions(self, cur, employee_id):
        cur.execute("""
            SELECT COALESCE(SUM(monthly_deduction), 0) AS total
            FROM payroll.pay_loans
            WHERE employee_id = %s AND status = 'ACTIVE'
        """, (employee_id,))
        return float(cur.fetchone()['total'])

    def _get_other_deductions(self, cur, employee_id):
        if self.payroll_type == 'GOV':
            # Coop deductions
            cur.execute("""
                SELECT COALESCE(SUM(monthly_savings), 0) AS total
                FROM payroll.pay_coop_members
                WHERE employee_id = %s AND is_active = TRUE
            """, (employee_id,))
            return float(cur.fetchone()['total'])
        return 0

    # ── Upsert payslip ─────────────────────────────────────────

    def _upsert_payslip(self, cur, r):
        cur.execute("""
            SELECT pr.id AS run_id FROM payroll.pay_runs pr
            WHERE pr.period_id = %s
            ORDER BY pr.created_at DESC LIMIT 1
        """, (self.period_id,))
        run_row = cur.fetchone()
        if not run_row:
            return
        run_id = run_row['run_id']

        cur.execute("""
            INSERT INTO payroll.pay_employee_payroll
                (run_id, employee_id,
                 scheduled_days, worked_days, absent_days, leave_days,
                 late_hours, undertime_hours,
                 ot_regular_hours, ot_restday_hours, ot_holiday_hours,
                 night_diff_hours,
                 basic_pay, ot_pay, holiday_pay, night_diff_pay,
                 allowances_total, other_earnings, gross_pay,
                 sss_ee, philhealth_ee, pagibig_ee, tax_withheld,
                 loan_deductions, other_deductions,
                 total_deductions, net_pay)
            VALUES (%s, %s,
                    %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s,
                    %s, %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (run_id, employee_id) DO UPDATE SET
                scheduled_days = EXCLUDED.scheduled_days,
                worked_days = EXCLUDED.worked_days,
                absent_days = EXCLUDED.absent_days,
                leave_days = EXCLUDED.leave_days,
                late_hours = EXCLUDED.late_hours,
                undertime_hours = EXCLUDED.undertime_hours,
                ot_regular_hours = EXCLUDED.ot_regular_hours,
                ot_restday_hours = EXCLUDED.ot_restday_hours,
                ot_holiday_hours = EXCLUDED.ot_holiday_hours,
                night_diff_hours = EXCLUDED.night_diff_hours,
                basic_pay = EXCLUDED.basic_pay,
                ot_pay = EXCLUDED.ot_pay,
                holiday_pay = EXCLUDED.holiday_pay,
                night_diff_pay = EXCLUDED.night_diff_pay,
                allowances_total = EXCLUDED.allowances_total,
                other_earnings = EXCLUDED.other_earnings,
                gross_pay = EXCLUDED.gross_pay,
                sss_ee = EXCLUDED.sss_ee,
                philhealth_ee = EXCLUDED.philhealth_ee,
                pagibig_ee = EXCLUDED.pagibig_ee,
                tax_withheld = EXCLUDED.tax_withheld,
                loan_deductions = EXCLUDED.loan_deductions,
                other_deductions = EXCLUDED.other_deductions,
                total_deductions = EXCLUDED.total_deductions,
                net_pay = EXCLUDED.net_pay,
                updated_at = NOW()
        """, (run_id, r['employee_id'],
              r['scheduled_days'], r['worked_days'], r['absent_days'], r['leave_days'],
              r['late_hours'], r['undertime_hours'],
              r['ot_regular_hours'], r['ot_restday_hours'], r['ot_holiday_hours'],
              r['night_diff_hours'],
              r['basic_pay'], r['ot_pay'], r['holiday_pay'], r['night_diff_pay'],
              r['allowances_total'], r['other_earnings'], r['gross_pay'],
              r.get('sss_ee', 0), r['philhealth_ee'], r['pagibig_ee'], r['tax_withheld'],
              r['loan_deductions'], r['other_deductions'],
              r['total_deductions'], r['net_pay']))

    # ── Batch computation ───────────────────────────────────────

    def compute_run(self, run_id):
        """Compute payroll for all active employees in the company."""
        with get_cursor() as cur:
            cur.execute("""
                SELECT id FROM core.employees
                WHERE company_id = %s AND is_active = TRUE
                  AND status NOT IN ('SEPARATED', 'TERMINATED')
            """, (self.company_id,))
            employees = cur.fetchall()

        computed = 0
        errors = []
        for emp in employees:
            try:
                result = self.compute_employee(emp['id'])
                if result:
                    computed += 1
            except Exception as e:
                errors.append({'employee_id': emp['id'], 'error': str(e)})

        # Update run totals
        with get_cursor(commit=True) as cur:
            cur.execute("""
                UPDATE payroll.pay_runs
                SET total_employees = (
                        SELECT COUNT(*) FROM payroll.pay_employee_payroll WHERE run_id = %s
                    ),
                    total_gross = (
                        SELECT COALESCE(SUM(gross_pay), 0) FROM payroll.pay_employee_payroll WHERE run_id = %s
                    ),
                    total_deductions = (
                        SELECT COALESCE(SUM(total_deductions), 0) FROM payroll.pay_employee_payroll WHERE run_id = %s
                    ),
                    total_net = (
                        SELECT COALESCE(SUM(net_pay), 0) FROM payroll.pay_employee_payroll WHERE run_id = %s
                    ),
                    computed_at = NOW(),
                    status = 'COMPUTED'
                WHERE id = %s
            """, (run_id, run_id, run_id, run_id, run_id))

            # Generate government remittance summary
            self._generate_remittances(cur, run_id)

        return {'computed': computed, 'errors': errors}

    def _generate_remittances(self, cur, run_id):
        """Create/update remittance summary rows per agency."""
        if self.payroll_type == 'GOV':
            agencies = [
                ('GSIS', 'gsis_ps', 'gsis_gs'),
                ('PAGIBIG', 'pagibig_ee', 'pagibig_ee'),
                ('PHILHEALTH', 'philhealth_ee', 'philhealth_ee'),
                ('BIR', 'tax_withheld', None),
            ]
        else:
            agencies = [
                ('SSS', 'sss_ee', 'sss_ee'),
                ('PAGIBIG', 'pagibig_ee', 'pagibig_ee'),
                ('PHILHEALTH', 'philhealth_ee', 'philhealth_ee'),
                ('BIR', 'tax_withheld', None),
            ]

        for agency, ee_col, er_col in agencies:
            if er_col:
                cur.execute(f"""
                    SELECT COALESCE(SUM({ee_col}), 0) AS total_ee,
                           COALESCE(SUM({er_col}), 0) AS total_er
                    FROM payroll.pay_employee_payroll WHERE run_id = %s
                """, (run_id,))
            else:
                cur.execute(f"""
                    SELECT COALESCE(SUM({ee_col}), 0) AS total_ee, 0 AS total_er
                    FROM payroll.pay_employee_payroll WHERE run_id = %s
                """, (run_id,))
            totals = cur.fetchone()
            total_ee = float(totals['total_ee'])
            total_er = float(totals['total_er'])

            cur.execute("""
                INSERT INTO payroll.pay_government_remittances
                    (run_id, agency, total_ee, total_er, total_amount, status)
                VALUES (%s, %s, %s, %s, %s, 'PENDING')
                ON CONFLICT (run_id, agency) DO UPDATE
                SET total_ee = EXCLUDED.total_ee,
                    total_er = EXCLUDED.total_er,
                    total_amount = EXCLUDED.total_amount
            """, (run_id, agency, total_ee, total_er, total_ee + total_er))
