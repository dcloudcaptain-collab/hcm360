"""
HR Validation Service — industry-standard, bypassable.

Two-level enforcement:
  1. Master switch  core.validation_settings.master_enforce
       FALSE → every rule degrades to WARN (no save is blocked).
  2. Per-rule       core.validation_rules.is_enforced
       FALSE → that rule degrades to WARN.

Public API
----------
  is_master_enforced()                  -> bool
  set_master_enforce(value, user_id)    -> None
  get_rules(category=None)              -> list of rule rows
  set_rule_enforce(rule_code, v, uid)   -> None
  validate(category, payload, **ctx)    -> {'errors': [...], 'warnings': [...]}

Each result item is `{'rule_code', 'label', 'message', 'severity'}`.

Severity is the resolved severity at runtime — i.e. with master+rule
enforcement applied. A rule whose definition says `severity=ERROR` will
appear as a WARNING when the master switch is off OR when the per-rule
toggle is off.
"""
import re
from datetime import date, datetime, timedelta
from services.db import get_cursor


# ─── Settings ───────────────────────────────────────────────────────────────

def is_master_enforced():
    with get_cursor() as cur:
        cur.execute("SELECT master_enforce FROM core.validation_settings WHERE id = 1")
        row = cur.fetchone()
        return bool(row and row['master_enforce'])


def set_master_enforce(value: bool, user_id):
    with get_cursor(commit=True) as cur:
        cur.execute(
            "UPDATE core.validation_settings SET master_enforce = %s, updated_by = %s, updated_at = NOW() WHERE id = 1",
            (bool(value), user_id),
        )


def get_rules(category=None):
    with get_cursor() as cur:
        if category:
            cur.execute("""
                SELECT id, rule_code, category, label, description,
                       severity, is_enforced, fail_message, sort_order
                FROM core.validation_rules
                WHERE category = %s
                ORDER BY sort_order, rule_code
            """, (category,))
        else:
            cur.execute("""
                SELECT id, rule_code, category, label, description,
                       severity, is_enforced, fail_message, sort_order
                FROM core.validation_rules
                ORDER BY category, sort_order, rule_code
            """)
        return cur.fetchall()


def set_rule_enforce(rule_code: str, is_enforced: bool, user_id):
    with get_cursor(commit=True) as cur:
        cur.execute(
            "UPDATE core.validation_rules SET is_enforced = %s, updated_by = %s, updated_at = NOW() WHERE rule_code = %s",
            (bool(is_enforced), user_id, rule_code),
        )


# ─── Helpers ────────────────────────────────────────────────────────────────

_EMAIL_RE  = re.compile(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
_PH_PHONE  = re.compile(r'^(?:\+63|0)9\d{9}$')


def _to_date(v):
    if not v:
        return None
    if isinstance(v, date):
        return v
    if isinstance(v, datetime):
        return v.date()
    try:
        return datetime.strptime(str(v).strip()[:10], '%Y-%m-%d').date()
    except (ValueError, TypeError):
        return None


def _resolve_severity(rule, master_on):
    """Return the runtime severity. ERROR only when master AND rule are enforced."""
    if not master_on:
        return 'WARN'
    return rule['severity'] if rule['is_enforced'] else 'WARN'


def _emit(rule, results, master_on, message=None):
    sev = _resolve_severity(rule, master_on)
    bucket = 'errors' if sev == 'ERROR' else 'warnings'
    results[bucket].append({
        'rule_code': rule['rule_code'],
        'label':     rule['label'],
        'severity':  sev,
        'message':   message or rule['fail_message'],
    })


# ─── Per-rule check functions ───────────────────────────────────────────────
# Each takes (payload: dict, ctx: dict) and returns True (PASS) or False (FAIL).
# Adding a rule = (1) seed the row in 79_validation_rules.sql and (2) add a
# function below keyed by rule_code.

def _ck_required(payload, key):
    v = payload.get(key)
    return v is not None and str(v).strip() != ''

def _check_E001(p, ctx): return _ck_required(p, 'first_name')
def _check_E002(p, ctx): return _ck_required(p, 'last_name')
def _check_E003(p, ctx): return _ck_required(p, 'employee_no')

def _check_E004(p, ctx):
    """Employee number unique within company."""
    emp_no = (p.get('employee_no') or '').strip()
    if not emp_no:
        return True   # E003 handles required
    exclude_id = p.get('id') or ctx.get('id')
    with get_cursor() as cur:
        if exclude_id:
            cur.execute("SELECT 1 FROM core.employees WHERE employee_no = %s AND id <> %s LIMIT 1",
                        (emp_no, exclude_id))
        else:
            cur.execute("SELECT 1 FROM core.employees WHERE employee_no = %s LIMIT 1", (emp_no,))
        return cur.fetchone() is None

def _check_E005(p, ctx): return _ck_required(p, 'date_hired')

def _check_E006(p, ctx):
    d = _to_date(p.get('date_hired'))
    return d is None or d <= date.today()

def _check_E007(p, ctx):
    d = _to_date(p.get('date_of_birth'))
    return d is None or d <= date.today()

def _check_E008(p, ctx):
    d = _to_date(p.get('date_of_birth'))
    if d is None:
        return True
    age = (date.today() - d).days // 365
    return age >= 15

def _check_E009(p, ctx):
    e = (p.get('work_email') or '').strip()
    return e == '' or bool(_EMAIL_RE.match(e))

def _check_E010(p, ctx):
    e = (p.get('mobile_no') or p.get('contact_no') or '').strip()
    return e == '' or bool(_PH_PHONE.match(e.replace(' ', '').replace('-', '')))

def _check_E011(p, ctx):
    sup = p.get('immediate_supervisor_id')
    me  = p.get('id') or ctx.get('id')
    if sup is None or me is None:
        return True
    try:
        return int(sup) != int(me)
    except (TypeError, ValueError):
        return True

def _check_E012(p, ctx):
    h = _to_date(p.get('date_hired'))
    t = _to_date(p.get('termination_date') or p.get('date_terminated'))
    if h is None or t is None:
        return True
    return t >= h

# Leave
def _check_L001(p, ctx):
    s = _to_date(p.get('start_date')); e = _to_date(p.get('end_date'))
    return s is None or e is None or s <= e

def _check_L002(p, ctx):
    """Sufficient balance — payload must carry `requested_days` and `available_balance`."""
    try:
        req  = float(p.get('requested_days') or 0)
        bal  = float(p.get('available_balance') if p.get('available_balance') is not None else ctx.get('available_balance', 0))
        return req <= bal
    except (TypeError, ValueError):
        return True

def _check_L003(p, ctx):
    """No overlap with already-approved leave for the same employee."""
    emp_id = p.get('employee_id') or ctx.get('employee_id')
    s = _to_date(p.get('start_date')); e = _to_date(p.get('end_date'))
    if not (emp_id and s and e):
        return True
    exclude_id = p.get('id')
    with get_cursor() as cur:
        if exclude_id:
            cur.execute("""
                SELECT 1 FROM core.leave_requests
                WHERE employee_id = %s AND status = 'APPROVED' AND id <> %s
                  AND start_date <= %s AND end_date >= %s
                LIMIT 1
            """, (emp_id, exclude_id, e, s))
        else:
            cur.execute("""
                SELECT 1 FROM core.leave_requests
                WHERE employee_id = %s AND status = 'APPROVED'
                  AND start_date <= %s AND end_date >= %s
                LIMIT 1
            """, (emp_id, e, s))
        return cur.fetchone() is None

def _check_L004(p, ctx):
    s = _to_date(p.get('start_date'))
    return s is None or s >= date.today()

def _check_L005(p, ctx):
    s = _to_date(p.get('start_date')); e = _to_date(p.get('end_date'))
    if not (s and e): return True
    cur_d = s
    while cur_d <= e:
        if cur_d.weekday() < 5:
            return True
        cur_d += timedelta(days=1)
    return False

# DTR
def _check_T001(p, ctx):
    ti = p.get('time_in'); to = p.get('time_out')
    return not (ti and to) or str(ti) < str(to)

def _check_T002(p, ctx):
    try:
        return float(p.get('hours_worked') or 0) <= 24
    except (TypeError, ValueError):
        return True

def _check_T003(p, ctx):
    """Pay period open — caller passes payload['pay_period_locked'] (bool)."""
    return not bool(p.get('pay_period_locked'))

def _check_T004(p, ctx):
    """No shift overlap — caller passes payload['shift_overlap'] (bool)."""
    return not bool(p.get('shift_overlap'))

# Compensation
def _check_C001(p, ctx):
    """3-year tenure since last increment. Caller passes `years_since_last_increment`."""
    try:
        return float(p.get('years_since_last_increment') or 0) >= 3.0
    except (TypeError, ValueError):
        return True

def _check_C002(p, ctx):
    """Salary within job grade band. Caller passes `band_min` and `band_max`."""
    try:
        s = float(p.get('salary') or 0); lo = float(p.get('band_min') or 0); hi = float(p.get('band_max') or 0)
        if lo == 0 and hi == 0: return True
        return lo <= s <= hi
    except (TypeError, ValueError):
        return True

def _check_C003(p, ctx):
    """Loan amount ≤ allowable maximum. Caller passes `loan_max`."""
    try:
        amt = float(p.get('amount') or 0)
        mx  = float(p.get('loan_max') or (float(p.get('monthly_salary') or 0) * 6))
        return mx == 0 or amt <= mx
    except (TypeError, ValueError):
        return True

def _check_C004(p, ctx):
    d = _to_date(p.get('effective_date'))
    return d is None or d >= date.today()


_CHECKS = {
    'E001': _check_E001, 'E002': _check_E002, 'E003': _check_E003, 'E004': _check_E004,
    'E005': _check_E005, 'E006': _check_E006, 'E007': _check_E007, 'E008': _check_E008,
    'E009': _check_E009, 'E010': _check_E010, 'E011': _check_E011, 'E012': _check_E012,
    'L001': _check_L001, 'L002': _check_L002, 'L003': _check_L003, 'L004': _check_L004,
    'L005': _check_L005,
    'T001': _check_T001, 'T002': _check_T002, 'T003': _check_T003, 'T004': _check_T004,
    'C001': _check_C001, 'C002': _check_C002, 'C003': _check_C003, 'C004': _check_C004,
}


# ─── Public entry point ─────────────────────────────────────────────────────

def validate(category, payload, **ctx):
    """Run every rule in `category` against `payload`.
    Returns {'errors': [...], 'warnings': [...]} where each item carries
    rule_code, label, message, severity.

    `payload` is a flat dict of the form fields. `ctx` is extra context
    (e.g. existing record id when editing) that some rules need.
    """
    results = {'errors': [], 'warnings': []}
    master_on = is_master_enforced()
    rules = get_rules(category=category.upper())
    for rule in rules:
        check = _CHECKS.get(rule['rule_code'])
        if not check:
            continue
        try:
            ok = check(payload, ctx)
        except Exception as e:
            # A buggy check should never block a save — emit a warning instead.
            results['warnings'].append({
                'rule_code': rule['rule_code'],
                'label':     rule['label'],
                'severity':  'WARN',
                'message':   f'(internal) check failed: {e}',
            })
            continue
        if not ok:
            _emit(rule, results, master_on)
    return results


def has_blockers(result):
    """True if `validate(...)` returned any ERROR-severity entries."""
    return bool(result.get('errors'))
