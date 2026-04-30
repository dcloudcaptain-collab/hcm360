"""
Field-level data privacy service — RA 10173 compliance.

Roles absent from field_privacy_rules default to VISIBLE.
SUPER_ADMIN and HR_ADMIN bypass all masking (no rows inserted for them).
"""
from services.db import get_cursor

# ---------------------------------------------------------------------------
# Sensitive fields by section (single source of truth used by admin UI + masking)
# ---------------------------------------------------------------------------
SENSITIVE_FIELDS: dict[str, list[dict]] = {
    'employee': [
        {'name': 'date_of_birth',  'label': 'Date of Birth'},
        {'name': 'mobile_no',      'label': 'Mobile No'},
        {'name': 'basic_salary',   'label': 'Basic Salary'},
        {'name': 'daily_rate',     'label': 'Daily Rate'},
        {'name': 'hourly_rate',    'label': 'Hourly Rate'},
        {'name': 'salary_grade',   'label': 'Salary Grade'},
    ],
    'address': [
        {'name': 'line1',     'label': 'Street / Line 1'},
        {'name': 'city',      'label': 'City'},
        {'name': 'province',  'label': 'Province'},
        {'name': 'zip_code',  'label': 'ZIP Code'},
    ],
    'emergency_contact': [
        {'name': 'mobile_no', 'label': 'Mobile No'},
    ],
    'government_id': [
        {'name': 'id_number', 'label': 'ID Number'},
    ],
    'bank_account': [
        {'name': 'account_number', 'label': 'Account Number'},
    ],
    'dependent': [
        {'name': 'date_of_birth', 'label': 'Date of Birth'},
    ],
}

# Map URL sub_key → section name used in SENSITIVE_FIELDS / privacy rules
SECTION_MAP: dict[str, str] = {
    'addresses':          'address',
    'emergency-contacts': 'emergency_contact',
    'government-ids':     'government_id',
    'bank-accounts':      'bank_account',
    'dependents':         'dependent',
}

# Roles that always see everything (bypass masking entirely)
_BYPASS_ROLES = {'SUPER_ADMIN', 'HR_ADMIN'}


# ---------------------------------------------------------------------------
# Data access
# ---------------------------------------------------------------------------

def get_privacy_rules() -> dict[tuple, dict]:
    """
    Load all rules from DB.
    Returns {(section, field_name, role_code): {'visibility': str, 'mask_char': str}}
    """
    with get_cursor() as cur:
        cur.execute(
            "SELECT section, field_name, role_code, visibility, mask_char "
            "FROM core.field_privacy_rules"
        )
        rows = cur.fetchall()
    return {
        (r['section'], r['field_name'], r['role_code']): {
            'visibility': r['visibility'],
            'mask_char':  r['mask_char'] or '***',
        }
        for r in rows
    }


def get_rules_for_role(role_code: str) -> dict[tuple, dict]:
    """Rules for a single role: {(section, field_name): {'visibility', 'mask_char'}}"""
    with get_cursor() as cur:
        cur.execute(
            "SELECT section, field_name, visibility, mask_char "
            "FROM core.field_privacy_rules WHERE role_code = %s",
            (role_code,)
        )
        rows = cur.fetchall()
    return {
        (r['section'], r['field_name']): {
            'visibility': r['visibility'],
            'mask_char':  r['mask_char'] or '***',
        }
        for r in rows
    }


def save_privacy_rule(section: str, field_name: str, role_code: str,
                      visibility: str, updated_by: int) -> None:
    """UPSERT a single rule."""
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO core.field_privacy_rules
                (section, field_name, role_code, visibility, updated_by, updated_at)
            VALUES (%s, %s, %s, %s, %s, NOW())
            ON CONFLICT (section, field_name, role_code)
            DO UPDATE SET visibility  = EXCLUDED.visibility,
                          updated_by  = EXCLUDED.updated_by,
                          updated_at  = NOW()
        """, (section, field_name, role_code, visibility, updated_by))


# ---------------------------------------------------------------------------
# Masking engine
# ---------------------------------------------------------------------------

def apply_privacy(
    data,
    role_code: str,
    section: str,
    is_own_record: bool = False,
):
    """
    Apply field-level masking to a record (dict) or list of records.

    Args:
        data:          dict or list[dict] — employee / sub-table record(s)
        role_code:     the viewer's role
        section:       section key matching SENSITIVE_FIELDS
        is_own_record: True when the viewer is the data-subject (ESS self-view).
                       MASKED fields become VISIBLE for own-record;
                       HIDDEN fields remain HIDDEN even for own-record.

    Returns the same type as input (dict or list) with values masked/removed.
    """
    if role_code in _BYPASS_ROLES:
        return data  # SUPER_ADMIN / HR_ADMIN see everything

    rules = get_rules_for_role(role_code)

    def _mask_record(record: dict) -> dict:
        if not record:
            return record
        result = dict(record)
        for field in SENSITIVE_FIELDS.get(section, []):
            fname = field['name']
            if fname not in result:
                continue
            rule = rules.get((section, fname))
            if rule is None:
                continue  # no rule → VISIBLE
            vis = rule['visibility']
            if vis == 'HIDDEN':
                result.pop(fname, None)
            elif vis == 'MASKED' and not is_own_record:
                result[fname] = rule['mask_char']
            # VISIBLE or is_own_record+MASKED → leave as-is
        return result

    if isinstance(data, list):
        return [_mask_record(r) for r in data]
    return _mask_record(data)
