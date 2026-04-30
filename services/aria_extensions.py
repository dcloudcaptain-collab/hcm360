"""
ARIA AI Extensions — cross-module tools powered by the report builder.

Registers the following tools on import:
  * list_data_sources   — enumerate what ARIA can query (sources + fields)
  * query_data_source   — run a filtered/grouped query against any source
  * hr_leader_dashboard — pre-baked summary for HR leaders
  * explain_kpi         — natural-language explanation of a KPI card
  * predict_attrition_risk — (existing, de-duplicated here)

This exposes every module automatically via the 30 data sources in
`analytics.report_data_sources`. HR leaders (and SUPER_ADMIN like
capsanchez) can ask questions like:
  "How many employees are at HIGH attrition risk by department?"
  "Which employees are retiring in the next 6 months?"
  "Show me SALN filings that are still DRAFT for 2026"
  "Top 10 net pay earners this year"
  "Training attendance rate by shift"
"""
import json
from services import ai_service
from services import report_builder_service as rb_svc
from services.db import get_cursor


# ══════════════════════════════════════════════════════════════════════
# Tool definitions
# ══════════════════════════════════════════════════════════════════════
_NEW_TOOLS = [
    {
        "name": "list_data_sources",
        "description": (
            "Returns every data source registered in the Report Builder, "
            "organized by module, with field names + types. Use this FIRST "
            "when the user asks a question that could span modules and "
            "you need to figure out which source has the right data. "
            "Covers 30 sources across 12 modules: core (employees, "
            "departments, positions, step increments, signatures, LGU "
            "contracts, travel orders, locator slips, retirement, PDS), "
            "attendance (DTR, face check-ins), leave management (requests, "
            "balances, types, CS Form 6), payroll (runs, payslips, loans), "
            "recruitment (appointments, CSC eligibilities, plantilla), "
            "learning (training records, attendance geotag, narrative "
            "reports), rewards (loyalty awards), DMS (SALN filings), "
            "performance (IPCR ratings), analytics (workforce scenarios, "
            "headcount plans), AI (attrition risk), admin (role access)."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "module": {
                    "type": "string",
                    "description": "Optional filter — return only sources in this module "
                                   "(e.g. 'payroll', 'learning', 'core'). Omit for all."
                },
                "include_fields": {
                    "type": "boolean",
                    "description": "Include the field registry per source (default true)."
                }
            }
        }
    },
    {
        "name": "query_data_source",
        "description": (
            "Runs a filtered/grouped query against any data source in the "
            "Report Builder and returns rows. This is your primary tool for "
            "answering HR-data questions that go beyond the pre-baked summaries. "
            "\n\n"
            "Workflow: 1) call list_data_sources to pick a source and learn "
            "its fields, 2) call this tool with source_code + columns + "
            "optional filters/group_by/order_by. Row limit is capped at 200. "
            "\n\n"
            "Supported operators: =, !=, >, <, >=, <=, LIKE, ILIKE, IN, "
            "NOT IN, IS NULL, IS NOT NULL. Grouped queries auto-aggregate "
            "non-grouped numeric columns (SUM by default)."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "source_code": {
                    "type": "string",
                    "description": "Source code like 'ATTRITION_RISK', 'LOYALTY_AWARDS', "
                                   "'PAYSLIPS', 'RETIREMENT', 'SALN_FILINGS', etc."
                },
                "columns": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Field codes to include. Omit for all."
                },
                "filters": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "field": {"type": "string"},
                            "op":    {"type": "string"},
                            "value": {}
                        }
                    },
                    "description": "Filter criteria. Example: "
                                   "[{\"field\":\"risk_level\",\"op\":\"=\",\"value\":\"HIGH\"}]"
                },
                "group_by": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Group rows by these field codes."
                },
                "order_by": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "field": {"type": "string"},
                            "dir":   {"type": "string", "enum": ["ASC", "DESC"]}
                        }
                    }
                },
                "limit": {
                    "type": "integer",
                    "description": "Max rows to return (default 25, capped 200)."
                }
            },
            "required": ["source_code"]
        }
    },
    {
        "name": "hr_leader_dashboard",
        "description": (
            "Pre-computed executive summary for HR leaders covering the "
            "whole organization. Returns 8 headline numbers: active "
            "headcount, attrition risk buckets, leaves pending, payroll "
            "gross/net YTD, loyalty awards eligible, retirements upcoming, "
            "CSC eligibility levels, and training participation. Use this "
            "when the user asks for a 'state of HR' / 'everything I need to "
            "know' overview."
        ),
        "input_schema": {"type": "object", "properties": {}, "required": []}
    },
    {
        "name": "explain_kpi",
        "description": (
            "Explain what a specific KPI means, how it's calculated, and "
            "how to interpret it. Use for questions like 'what is attrition "
            "risk?', 'how do you compute SSS contribution?', 'what counts "
            "as a loyalty milestone?'. Returns the definition plus the "
            "current live value."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "kpi_code": {
                    "type": "string",
                    "description": "KPI code (e.g. 'attrition_high_risk', "
                                   "'headcount_active', 'loyalty_eligible')."
                }
            },
            "required": ["kpi_code"]
        }
    },
]


# ══════════════════════════════════════════════════════════════════════
# Executor helpers
# ══════════════════════════════════════════════════════════════════════
def _serialize(obj):
    """Make JSON-friendly: stringify dates, decimals, etc."""
    if isinstance(obj, dict):
        return {k: _serialize(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_serialize(v) for v in obj]
    try:
        from datetime import date, datetime
        if isinstance(obj, (date, datetime)):
            return obj.isoformat()
    except Exception:
        pass
    try:
        from decimal import Decimal
        if isinstance(obj, Decimal):
            return float(obj)
    except Exception:
        pass
    return obj


def _current_user_context():
    """Best-effort read of session role/user for ARIA tool dispatch."""
    try:
        from flask import session, has_request_context
        if has_request_context():
            return session.get('role_code'), session.get('user_id')
    except Exception:
        pass
    return None, None


def _exec_list_data_sources(inputs: dict) -> str:
    module_filter = inputs.get('module')
    include_fields = inputs.get('include_fields', True)
    role, uid = _current_user_context()
    allowed_ids = None
    if role:
        try:
            from services.access_service import get_allowed_source_ids
            allowed_ids = get_allowed_source_ids(role, uid)
        except Exception:
            allowed_ids = None
    with get_cursor() as cur:
        if module_filter:
            cur.execute("""
                SELECT id, source_code, source_label, module, description
                FROM analytics.report_data_sources
                WHERE is_active = TRUE AND module = %s
                ORDER BY sort_order
            """, (module_filter,))
        else:
            cur.execute("""
                SELECT id, source_code, source_label, module, description
                FROM analytics.report_data_sources
                WHERE is_active = TRUE
                ORDER BY module, sort_order
            """)
        sources = cur.fetchall()
        if allowed_ids is not None:
            sources = [s for s in sources if s['id'] in allowed_ids]

        result = {'source_count': len(sources), 'sources': []}
        for s in sources:
            item = {
                'code': s['source_code'],
                'label': s['source_label'],
                'module': s['module'],
                'description': s.get('description'),
            }
            if include_fields:
                cur.execute("""
                    SELECT field_code, field_label, field_type,
                           is_aggregatable, default_aggregate
                    FROM analytics.report_field_registry
                    WHERE source_id = %s
                    ORDER BY sort_order, field_code
                """, (s['id'],))
                item['fields'] = [
                    {'code': f['field_code'], 'label': f['field_label'],
                     'type': f['field_type']}
                    for f in cur.fetchall()
                ]
            result['sources'].append(item)
    return json.dumps(_serialize(result))


def _exec_query_data_source(inputs: dict) -> str:
    code = (inputs.get('source_code') or '').strip().upper()
    if not code:
        return json.dumps({'error': 'source_code required'})

    with get_cursor() as cur:
        cur.execute("""
            SELECT id FROM analytics.report_data_sources
            WHERE source_code = %s AND is_active = TRUE
        """, (code,))
        row = cur.fetchone()
    if not row:
        return json.dumps({'error': f'source {code} not found or inactive'})

    # Access gate — respect role/user grants set in Access Matrix
    role, uid = _current_user_context()
    if role:
        try:
            from services.access_service import get_allowed_source_ids
            allowed = get_allowed_source_ids(role, uid)
            if row['id'] not in allowed:
                return json.dumps({'error': f'access denied to data source {code}'})
        except Exception:
            pass

    config = {
        'columns':   inputs.get('columns') or [],
        'filters':   inputs.get('filters') or [],
        'group_by':  inputs.get('group_by') or [],
        'order_by':  inputs.get('order_by') or [],
        'limit':     min(int(inputs.get('limit') or 25), 200),
    }

    try:
        rows, col_order = rb_svc.execute_report(row['id'], config)
    except Exception as ex:
        return json.dumps({'error': f'query failed: {ex}'})

    return json.dumps(_serialize({
        'source': code,
        'columns': col_order,
        'row_count': len(rows),
        'rows': rows[:200],  # hard cap for AI token budget
    }))


def _exec_hr_leader_dashboard(_inputs: dict) -> str:
    """Collect 8 headline figures from across the platform."""
    with get_cursor() as cur:
        result = {}
        queries = {
            'active_headcount': """
                SELECT COUNT(*) AS n FROM core.employees
                WHERE status = 'ACTIVE'
            """,
            'attrition_high_risk': """
                SELECT COUNT(*) AS n FROM ai.ai_risk_scores
                WHERE risk_type='ATTRITION' AND risk_level='HIGH'
            """,
            'attrition_medium_risk': """
                SELECT COUNT(*) AS n FROM ai.ai_risk_scores
                WHERE risk_type='ATTRITION' AND risk_level='MEDIUM'
            """,
            'leaves_pending': """
                SELECT COUNT(*) AS n FROM leave_mgmt.lv_requests
                WHERE status = 'PENDING'
            """,
            'loyalty_eligible': """
                SELECT COUNT(*) AS n FROM rewards.rwd_loyalty_milestones
                WHERE status = 'ELIGIBLE'
            """,
            'retirement_upcoming': """
                SELECT COUNT(*) AS n FROM core.retirement_tracking
                WHERE status IN ('UPCOMING','NOTICE_SENT')
            """,
            'step_increment_due': """
                SELECT COUNT(*) AS n FROM core.step_increment_history
                WHERE status='DUE' AND due_date <= CURRENT_DATE + INTERVAL '90 days'
            """,
            'saln_submitted_ytd': """
                SELECT COUNT(*) AS n FROM dms.saln_filings
                WHERE filing_year = EXTRACT(YEAR FROM CURRENT_DATE)::int
                  AND status IN ('SUBMITTED','VERIFIED')
            """,
            'training_attendances_90d': """
                SELECT COUNT(*) AS n FROM learning.lrn_attendance_logs
                WHERE checked_in_at > CURRENT_DATE - INTERVAL '90 days'
            """,
            'csc_1st_level': """
                SELECT COUNT(DISTINCT e.id) AS n
                FROM core.employees e
                JOIN recruitment.rec_employee_eligibilities ee ON ee.employee_id=e.id
                JOIN recruitment.rec_csc_eligibilities ce ON ce.id=ee.eligibility_id
                WHERE ce.level = '1ST_LEVEL' AND e.status='ACTIVE'
            """,
            'csc_2nd_level': """
                SELECT COUNT(DISTINCT e.id) AS n
                FROM core.employees e
                JOIN recruitment.rec_employee_eligibilities ee ON ee.employee_id=e.id
                JOIN recruitment.rec_csc_eligibilities ce ON ce.id=ee.eligibility_id
                WHERE ce.level = '2ND_LEVEL' AND e.status='ACTIVE'
            """,
            'payroll_net_ytd': """
                SELECT COALESCE(SUM(ep.net_pay), 0) AS n
                FROM payroll.pay_employee_payroll ep
                JOIN payroll.pay_runs pr ON pr.id = ep.run_id
                JOIN payroll.pay_periods p ON p.id = pr.period_id
                WHERE EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM CURRENT_DATE)
                  AND pr.status = 'POSTED'
            """,
            'active_contracts': """
                SELECT COUNT(*) AS n FROM core.lgu_contracts
                WHERE status = 'ACTIVE'
            """,
            'signatures_30d': """
                SELECT COUNT(*) AS n FROM core.document_signatures
                WHERE created_at > CURRENT_DATE - INTERVAL '30 days'
            """,
        }
        for key, sql in queries.items():
            try:
                cur.execute(sql)
                r = cur.fetchone()
                result[key] = float(r['n']) if r and r.get('n') is not None else 0
            except Exception:
                result[key] = None  # table missing or query failed

    # Also include gender split for attrition HIGH
    try:
        with get_cursor() as cur:
            cur.execute("""
                SELECT
                    COUNT(*) FILTER (WHERE UPPER(e.gender)='MALE')   AS male,
                    COUNT(*) FILTER (WHERE UPPER(e.gender)='FEMALE') AS female
                FROM ai.ai_risk_scores p
                JOIN core.employees e ON e.id = p.employee_id
                WHERE p.risk_type='ATTRITION' AND p.risk_level='HIGH'
            """)
            g = cur.fetchone()
            result['attrition_high_male']   = int(g['male']) if g else 0
            result['attrition_high_female'] = int(g['female']) if g else 0
    except Exception:
        pass

    return json.dumps(_serialize(result))


def _exec_explain_kpi(inputs: dict) -> str:
    code = (inputs.get('kpi_code') or '').strip()
    if not code:
        return json.dumps({'error': 'kpi_code required'})
    with get_cursor() as cur:
        cur.execute("""
            SELECT code, label, icon, module, sql_query, filter_url, roles
            FROM core.dashboard_metrics
            WHERE code = %s AND is_active = TRUE
        """, (code,))
        m = cur.fetchone()
        if not m:
            return json.dumps({'error': f'kpi {code} not found'})
        val = None
        try:
            cur.execute(m['sql_query'])
            r = cur.fetchone()
            if r:
                val = next(iter(r.values()), None)
        except Exception as ex:
            val = f'(calc error: {ex})'
    return json.dumps(_serialize({
        'code':        m['code'],
        'label':       m['label'],
        'module':      m['module'],
        'definition':  m['sql_query'],
        'filter_url':  m['filter_url'],
        'visible_to':  list(m['roles'] or []),
        'current_value': val,
    }))


# ══════════════════════════════════════════════════════════════════════
# Registration (idempotent)
# ══════════════════════════════════════════════════════════════════════
_HANDLERS = {
    'list_data_sources':     _exec_list_data_sources,
    'query_data_source':     _exec_query_data_source,
    'hr_leader_dashboard':   _exec_hr_leader_dashboard,
    'explain_kpi':           _exec_explain_kpi,
}


def register():
    """Append the new tools to ai_service.HRIS_TOOLS and wrap _execute_tool.
    Safe to call multiple times."""
    existing = {t['name'] for t in ai_service.HRIS_TOOLS}
    for tool in _NEW_TOOLS:
        if tool['name'] not in existing:
            ai_service.HRIS_TOOLS.append(tool)

    # Wrap _execute_tool to dispatch to our new handlers
    if not getattr(ai_service, '_aria_ext_patched', False):
        original = ai_service._execute_tool

        def wrapped(name, inputs):
            if name in _HANDLERS:
                try:
                    return _HANDLERS[name](inputs or {})
                except Exception as ex:
                    return json.dumps({'error': f'tool {name} failed: {ex}'})
            return original(name, inputs)

        ai_service._execute_tool = wrapped
        ai_service._aria_ext_patched = True

    # Augment the system prompt with data-source awareness
    if not getattr(ai_service, '_aria_prompt_patched', False):
        original_prompt = ai_service._build_system_prompt

        def augmented(company_name, user_name, role):
            base = original_prompt(company_name, user_name, role)
            hr_hint = ''
            if role in ('SUPER_ADMIN', 'HR_ADMIN', 'EXECUTIVE'):
                hr_hint = (
                    "\n\nHR LEADER MODE:\n"
                    "You have access to 30 data sources spanning every module "
                    "(core, attendance, leave, payroll, recruitment, "
                    "performance, learning, rewards, DMS, analytics, AI, "
                    "admin). For any cross-module question:\n"
                    "  1. Call list_data_sources to discover what is available.\n"
                    "  2. Call query_data_source with the appropriate source + "
                    "filters/group_by.\n"
                    "  3. For quick overviews, call hr_leader_dashboard for "
                    "14 headline numbers.\n"
                    "  4. For KPI definitions, call explain_kpi.\n"
                    "Prefer query_data_source over free-form guessing — it "
                    "runs through a validated SQL builder so results are "
                    "always accurate and traceable."
                )
            return base + hr_hint

        ai_service._build_system_prompt = augmented
        ai_service._aria_prompt_patched = True


# Register on import
register()
