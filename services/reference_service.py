from services.db import get_cursor

REFERENCE_TABLES = {
    'statuses': {
        'table': 'status_definitions',
        'pk': 'id',
        'fields': ['status_group', 'status_code', 'status_label', 'badge_color', 'is_terminal', 'sort_order']
    },
    'departments': {
        'table': 'departments',
        'pk': 'id',
        'fields': ['name']
    },
    'positions': {
        'table': 'positions',
        'pk': 'id',
        'fields': ['title']
    },
    'pages': {
        'table': 'page_registry',
        'pk': 'id',
        'fields': ['page_code', 'label', 'route_url', 'sort_order', 'is_active']
    },
    'features': {
        'table': 'feature_registry',
        'pk': 'id',
        'fields': ['feature_code', 'feature_label', 'feature_type', 'sort_order', 'is_active']
    },
    'themes': {
        'table': 'ui_themes',
        'pk': 'id',
        'fields': ['code', 'name', 'properties', 'is_active']
    },
    'metrics': {
        'table': 'dashboard_metrics',
        'pk': 'id',
        'fields': ['metric_code', 'metric_label', 'formula_text', 'drilldown_url', 'sort_order', 'is_active']
    },
    'forms': {
        'table': 'dynamic_forms',
        'pk': 'id',
        'fields': ['form_name', 'module_code', 'description']
    },
    'kpisql': {
        'table': 'kpi_query_registry',
        'pk': 'id',
        'fields': ['kpi_code', 'kpi_label', 'sql_key', 'description']
    },
    'orchestrations': {
        'table': 'orchestration_flows',
        'pk': 'id',
        'fields': ['flow_name', 'trigger_module', 'flow_status']
    },
    # ── Core reference tables ────────────────────────────────────
    'job_grades': {
        'table': 'job_grades',
        'pk': 'id',
        'fields': ['code', 'name', 'grade_level', 'salary_min', 'salary_max', 'is_active'],
        'schema': 'core',
    },
    'employment_types': {
        'table': 'employment_types',
        'pk': 'id',
        'fields': ['code', 'name', 'description', 'is_entitled_benefits', 'probation_days', 'is_active'],
        'schema': 'core',
    },
    'roles': {
        'table': 'roles',
        'pk': 'id',
        'fields': ['code', 'name', 'description', 'is_system_role', 'is_active'],
        'schema': 'core',
    },
    # ── Leave reference tables ───────────────────────────────────
    'leave_types': {
        'table': 'lv_types',
        'pk': 'id',
        'fields': ['code', 'name', 'category', 'legal_basis', 'color', 'icon', 'description', 'is_paid', 'requires_document', 'min_days', 'max_days_per_filing', 'notice_days_required', 'gender_restriction', 'is_active'],
        'schema': 'leave_mgmt',
    },
    'leave_policies': {
        'table': 'lv_policies',
        'pk': 'id',
        'fields': ['leave_type_id', 'employment_type_id', 'annual_days', 'accrual_type', 'carry_over_allowed', 'carry_over_max_days', 'monetization_allowed', 'months_before_entitled', 'effective_from', 'effective_to'],
        'schema': 'leave_mgmt',
    },
    # ── Attendance reference tables ──────────────────────────────
    'holiday_types': {
        'table': 'att_holiday_types',
        'pk': 'id',
        'fields': ['code', 'name', 'pay_multiplier', 'description'],
        'schema': 'attendance',
    },
    'holidays': {
        'table': 'att_holidays',
        'pk': 'id',
        'fields': ['holiday_type_id', 'holiday_date', 'name', 'description', 'is_recurring', 'month_day'],
        'schema': 'attendance',
    },
    # ── Discipline reference tables ──────────────────────────────
    'case_types': {
        'table': 'case_types',
        'pk': 'id',
        'fields': ['code', 'name', 'gravity', 'description', 'legal_basis', 'default_penalty', 'is_active'],
        'schema': 'discipline',
    },
    # ── DMS reference tables ─────────────────────────────────────
    'document_categories': {
        'table': 'document_categories',
        'pk': 'id',
        'fields': ['code', 'name', 'parent_id', 'description', 'sort_order', 'is_active'],
        'schema': 'dms',
    },
    'checklist_templates': {
        'table': 'checklist_templates',
        'pk': 'id',
        'fields': ['employment_type_id', 'name', 'is_active'],
        'schema': 'dms',
    },
    'certificate_types': {
        'table': 'certificate_types',
        'pk': 'id',
        'fields': ['code', 'name', 'description', 'processing_days', 'requires_approval', 'is_active'],
        'schema': 'dms',
    },
    'retention_policies': {
        'table': 'retention_policies',
        'pk': 'id',
        'fields': ['category_id', 'retention_years', 'retention_basis', 'disposal_method', 'legal_basis', 'is_active'],
        'schema': 'dms',
    },
    # ── Recruitment reference tables ─────────────────────────────
    'csc_eligibilities': {
        'table': 'rec_csc_eligibilities',
        'pk': 'id',
        'fields': ['code', 'name', 'category', 'is_active'],
        'schema': 'recruitment',
    },
    'qualification_standards': {
        'table': 'rec_qualification_standards',
        'pk': 'id',
        'fields': ['position_id', 'education', 'experience', 'training', 'eligibility', 'competencies', 'is_active'],
        'schema': 'recruitment',
    },
    # ── Rewards reference tables ─────────────────────────────────
    'reward_categories': {
        'table': 'rwd_categories',
        'pk': 'id',
        'fields': ['code', 'name', 'description', 'award_type', 'is_active'],
        'schema': 'rewards',
    },
    'praise_config': {
        'table': 'rwd_praise_config',
        'pk': 'id',
        'fields': ['award_type', 'criteria_description', 'monetary_equivalent', 'non_monetary_description', 'is_active'],
        'schema': 'rewards',
    },
    # ── Notification reference tables ────────────────────────────
    'notification_templates': {
        'table': 'ntf_templates',
        'pk': 'id',
        'fields': ['template_code', 'module', 'event_type', 'subject_template', 'body_template', 'is_active'],
        'schema': 'notifications',
    },
    # ── Payroll reference tables ─────────────────────────────────
    'pay_periods': {
        'table': 'pay_periods',
        'pk': 'id',
        'fields': ['period_code', 'period_type', 'date_from', 'date_to', 'payment_date', 'status'],
        'schema': 'payroll',
        'label': 'Pay Periods',
        'defaults': {'company_id': 1},  # single-tenant LGU build
    },
    # ── Milestones reference tables ──────────────────────────────
    'retirement_rules': {
        'table': 'retirement_rule_profiles',
        'pk': 'id',
        'fields': ['name', 'mandatory_age', 'early_age', 'notice_lead_months', 'is_default', 'is_active'],
        'schema': 'core',
        'label': 'Retirement Rule Profiles',
    },
}


def get_reference_config(key):
    return REFERENCE_TABLES.get(key)


def _fqn(cfg):
    """Fully qualified table name with schema prefix."""
    schema = cfg.get('schema', 'core')
    return f"{schema}.{cfg['table']}"


class UnknownReferenceKey(KeyError):
    """Raised when a reference-data key isn't registered.
    Routes should catch this and 404 instead of 500."""


def _require_cfg(key):
    cfg = get_reference_config(key)
    if cfg is None:
        raise UnknownReferenceKey(key)
    return cfg


def list_rows(key):
    cfg = _require_cfg(key)
    with get_cursor() as cur:
        cur.execute(f"SELECT * FROM {_fqn(cfg)} ORDER BY {cfg['pk']}")
        return cur.fetchall(), cfg


def get_row(key, row_id):
    cfg = _require_cfg(key)
    with get_cursor() as cur:
        cur.execute(f"SELECT * FROM {_fqn(cfg)} WHERE {cfg['pk']}=%s", (row_id,))
        return cur.fetchone(), cfg


def create_row(key, data):
    cfg = _require_cfg(key)
    fields = list(cfg['fields'])
    values = [normalize_value(data.get(f)) for f in fields]
    # Fold in static defaults (e.g. company_id for single-tenant tables)
    for col, val in (cfg.get('defaults') or {}).items():
        if col in fields:
            continue
        fields.append(col)
        values.append(val)
    cols = ', '.join(fields)
    placeholders = ', '.join(['%s'] * len(fields))
    with get_cursor(commit=True) as cur:
        cur.execute(f"INSERT INTO {_fqn(cfg)} ({cols}) VALUES ({placeholders})", values)


def update_row(key, row_id, data):
    cfg = _require_cfg(key)
    fields = cfg['fields']
    assignments = ', '.join([f"{f}=%s" for f in fields])
    values = [normalize_value(data.get(f)) for f in fields] + [row_id]
    with get_cursor(commit=True) as cur:
        cur.execute(f"UPDATE {_fqn(cfg)} SET {assignments} WHERE {cfg['pk']}=%s", values)


def delete_row(key, row_id):
    cfg = _require_cfg(key)
    with get_cursor(commit=True) as cur:
        cur.execute(f"DELETE FROM {_fqn(cfg)} WHERE {cfg['pk']}=%s", (row_id,))


def normalize_value(v):
    if v in (None, ''):
        return None
    if isinstance(v, str) and v.lower() in ('true', 'false'):
        return v.lower() == 'true'
    return v
