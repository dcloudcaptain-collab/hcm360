"""Config service — CRUD for payroll configuration tables."""
from services.db import get_cursor


# ── Pay Config (key-value settings) ─────────────────────────────

def get_config(company_id, key):
    with get_cursor() as cur:
        cur.execute("""
            SELECT config_value FROM payroll.pay_config
            WHERE company_id = %s AND config_key = %s
        """, (company_id, key))
        row = cur.fetchone()
    return row['config_value'] if row else None


def get_all_config(company_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT config_key, config_value, description, updated_at
            FROM payroll.pay_config
            WHERE company_id = %s
            ORDER BY config_key
        """, (company_id,))
        return cur.fetchall()


def set_config(company_id, key, value, updated_by=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO payroll.pay_config (company_id, config_key, config_value, updated_by, updated_at)
            VALUES (%s, %s, %s, %s, NOW())
            ON CONFLICT (company_id, config_key) DO UPDATE
            SET config_value = EXCLUDED.config_value,
                updated_by = EXCLUDED.updated_by,
                updated_at = NOW()
        """, (company_id, key, str(value), updated_by))


def get_config_dict(company_id):
    """Return all config as a simple {key: value} dict."""
    rows = get_all_config(company_id)
    return {r['config_key']: r['config_value'] for r in rows}


# ── Rate Tables ─────────────────────────────────────────────────

def get_rate_tables(company_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM payroll.pay_rate_tables
            WHERE company_id = %s
            ORDER BY rate_code
        """, (company_id,))
        return cur.fetchall()


def get_rate(company_id, rate_code):
    with get_cursor() as cur:
        cur.execute("""
            SELECT multiplier FROM payroll.pay_rate_tables
            WHERE company_id = %s AND rate_code = %s AND is_active = TRUE
        """, (company_id, rate_code))
        row = cur.fetchone()
    return float(row['multiplier']) if row else 1.0


def upsert_rate(company_id, rate_code, rate_name, multiplier, description=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO payroll.pay_rate_tables
                (company_id, rate_code, rate_name, multiplier, description)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (company_id, rate_code) DO UPDATE
            SET rate_name = EXCLUDED.rate_name,
                multiplier = EXCLUDED.multiplier,
                description = EXCLUDED.description
        """, (company_id, rate_code, rate_name, multiplier, description))


def delete_rate(rate_id):
    with get_cursor(commit=True) as cur:
        cur.execute("DELETE FROM payroll.pay_rate_tables WHERE id = %s", (rate_id,))


# ── SSS Schedule ────────────────────────────────────────────────

def get_sss_schedule():
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM payroll.pay_sss_schedule
            WHERE is_current = TRUE
            ORDER BY salary_bracket_from
        """)
        return cur.fetchall()


def upsert_sss_bracket(bracket_id, effective_date, bracket_from, bracket_to,
                        monthly_salary_credit, ee_contribution, er_contribution,
                        ec_contribution=10.0):
    with get_cursor(commit=True) as cur:
        if bracket_id:
            cur.execute("""
                UPDATE payroll.pay_sss_schedule
                SET effective_date = %s, salary_bracket_from = %s,
                    salary_bracket_to = %s, monthly_salary_credit = %s,
                    ee_contribution = %s, er_contribution = %s,
                    ec_contribution = %s
                WHERE id = %s
            """, (effective_date, bracket_from, bracket_to, monthly_salary_credit,
                  ee_contribution, er_contribution, ec_contribution, bracket_id))
        else:
            cur.execute("""
                INSERT INTO payroll.pay_sss_schedule
                    (effective_date, salary_bracket_from, salary_bracket_to,
                     monthly_salary_credit, ee_contribution, er_contribution,
                     ec_contribution, is_current)
                VALUES (%s, %s, %s, %s, %s, %s, %s, TRUE)
            """, (effective_date, bracket_from, bracket_to, monthly_salary_credit,
                  ee_contribution, er_contribution, ec_contribution))


def delete_sss_bracket(bracket_id):
    with get_cursor(commit=True) as cur:
        cur.execute("DELETE FROM payroll.pay_sss_schedule WHERE id = %s", (bracket_id,))


# ── GSIS Schedule ───────────────────────────────────────────────

def get_gsis_schedule():
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM payroll.pay_gsis_schedule
            WHERE is_current = TRUE
            ORDER BY salary_bracket_from
        """)
        return cur.fetchall()


def upsert_gsis_bracket(bracket_id, effective_date, bracket_from, bracket_to,
                         ee_pct, er_pct, life_insurance_pct=0):
    with get_cursor(commit=True) as cur:
        if bracket_id:
            cur.execute("""
                UPDATE payroll.pay_gsis_schedule
                SET effective_date = %s, salary_bracket_from = %s,
                    salary_bracket_to = %s, ee_personal_share_pct = %s,
                    er_government_share_pct = %s, life_insurance_pct = %s
                WHERE id = %s
            """, (effective_date, bracket_from, bracket_to, ee_pct, er_pct,
                  life_insurance_pct, bracket_id))
        else:
            cur.execute("""
                INSERT INTO payroll.pay_gsis_schedule
                    (effective_date, salary_bracket_from, salary_bracket_to,
                     ee_personal_share_pct, er_government_share_pct,
                     life_insurance_pct, is_current)
                VALUES (%s, %s, %s, %s, %s, %s, TRUE)
            """, (effective_date, bracket_from, bracket_to, ee_pct, er_pct,
                  life_insurance_pct))


def delete_gsis_bracket(bracket_id):
    with get_cursor(commit=True) as cur:
        cur.execute("DELETE FROM payroll.pay_gsis_schedule WHERE id = %s", (bracket_id,))


# ── PhilHealth Schedule ─────────────────────────────────────────

def get_philhealth_schedule():
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM payroll.pay_philhealth_schedule
            WHERE is_current = TRUE
            ORDER BY salary_bracket_from
        """)
        return cur.fetchall()


def upsert_philhealth_bracket(bracket_id, effective_date, bracket_from, bracket_to,
                                premium_rate, ee_share, er_share,
                                min_premium=500, max_premium=5000):
    with get_cursor(commit=True) as cur:
        if bracket_id:
            cur.execute("""
                UPDATE payroll.pay_philhealth_schedule
                SET effective_date = %s, salary_bracket_from = %s,
                    salary_bracket_to = %s, premium_rate = %s,
                    ee_share = %s, er_share = %s,
                    min_premium = %s, max_premium = %s
                WHERE id = %s
            """, (effective_date, bracket_from, bracket_to, premium_rate,
                  ee_share, er_share, min_premium, max_premium, bracket_id))
        else:
            cur.execute("""
                INSERT INTO payroll.pay_philhealth_schedule
                    (effective_date, salary_bracket_from, salary_bracket_to,
                     premium_rate, ee_share, er_share, min_premium, max_premium, is_current)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, TRUE)
            """, (effective_date, bracket_from, bracket_to, premium_rate,
                  ee_share, er_share, min_premium, max_premium))


def delete_philhealth_bracket(bracket_id):
    with get_cursor(commit=True) as cur:
        cur.execute("DELETE FROM payroll.pay_philhealth_schedule WHERE id = %s", (bracket_id,))


# ── Pag-IBIG Schedule ──────────────────────────────────────────

def get_pagibig_schedule():
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM payroll.pay_pagibig_schedule
            WHERE is_current = TRUE
            ORDER BY salary_bracket_from
        """)
        return cur.fetchall()


def upsert_pagibig_bracket(bracket_id, effective_date, bracket_from, bracket_to,
                            ee_pct, er_pct):
    with get_cursor(commit=True) as cur:
        if bracket_id:
            cur.execute("""
                UPDATE payroll.pay_pagibig_schedule
                SET effective_date = %s, salary_bracket_from = %s,
                    salary_bracket_to = %s, ee_contribution_pct = %s,
                    er_contribution_pct = %s
                WHERE id = %s
            """, (effective_date, bracket_from, bracket_to, ee_pct, er_pct, bracket_id))
        else:
            cur.execute("""
                INSERT INTO payroll.pay_pagibig_schedule
                    (effective_date, salary_bracket_from, salary_bracket_to,
                     ee_contribution_pct, er_contribution_pct, is_current)
                VALUES (%s, %s, %s, %s, %s, TRUE)
            """, (effective_date, bracket_from, bracket_to, ee_pct, er_pct))


def delete_pagibig_bracket(bracket_id):
    with get_cursor(commit=True) as cur:
        cur.execute("DELETE FROM payroll.pay_pagibig_schedule WHERE id = %s", (bracket_id,))


# ── BIR Tax Tables ──────────────────────────────────────────────

def get_tax_tables(frequency='MONTHLY'):
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM payroll.pay_bir_tax_table
            WHERE is_current = TRUE AND frequency = %s
            ORDER BY bracket_from
        """, (frequency,))
        return cur.fetchall()


def get_all_tax_tables():
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM payroll.pay_bir_tax_table
            WHERE is_current = TRUE
            ORDER BY frequency, bracket_from
        """)
        return cur.fetchall()


def upsert_tax_bracket(bracket_id, effective_date, frequency, bracket_from,
                        bracket_to, base_tax, excess_pct):
    with get_cursor(commit=True) as cur:
        if bracket_id:
            cur.execute("""
                UPDATE payroll.pay_bir_tax_table
                SET effective_date = %s, frequency = %s,
                    bracket_from = %s, bracket_to = %s,
                    base_tax = %s, excess_pct = %s
                WHERE id = %s
            """, (effective_date, frequency, bracket_from, bracket_to,
                  base_tax, excess_pct, bracket_id))
        else:
            cur.execute("""
                INSERT INTO payroll.pay_bir_tax_table
                    (effective_date, frequency, bracket_from, bracket_to,
                     base_tax, excess_pct, is_current)
                VALUES (%s, %s, %s, %s, %s, %s, TRUE)
            """, (effective_date, frequency, bracket_from, bracket_to,
                  base_tax, excess_pct))


def delete_tax_bracket(bracket_id):
    with get_cursor(commit=True) as cur:
        cur.execute("DELETE FROM payroll.pay_bir_tax_table WHERE id = %s", (bracket_id,))
