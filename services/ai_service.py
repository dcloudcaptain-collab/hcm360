"""
ARIA — Advanced HRIS AI Executive Assistant
Integrates Anthropic Claude with tool use to answer HR questions
from live database data. No hallucination: every number comes
from a direct DB query executed by the tool engine.
"""
import json
import os
import time
from datetime import datetime

from services.db import get_cursor

try:
    import anthropic
    _SDK_AVAILABLE = True
except ImportError:
    _SDK_AVAILABLE = False

MODEL = "claude-sonnet-4-6"

# ── Tool definitions ─────────────────────────────────────────────
HRIS_TOOLS = [
    {
        "name": "get_workforce_overview",
        "description": (
            "Returns current headcount broken down by employment status and department. "
            "Use this for any question about how many employees exist, "
            "headcount by department, or workforce composition."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "group_by": {
                    "type": "string",
                    "enum": ["status", "department", "position", "both"],
                    "description": "How to group the headcount results"
                }
            },
            "required": []
        }
    },
    {
        "name": "get_workflow_status",
        "description": (
            "Returns status of all workflow instances (onboarding, movement approvals, etc.). "
            "Use for questions about pending approvals, workflow progress, or transaction status."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "status_filter": {
                    "type": "string",
                    "enum": ["all", "pending", "in_progress", "approved", "rejected"],
                    "description": "Filter by workflow status"
                }
            },
            "required": []
        }
    },
    {
        "name": "get_document_alerts",
        "description": (
            "Returns employees with missing or incomplete documents. "
            "Use for compliance and document readiness questions."
        ),
        "input_schema": {"type": "object", "properties": {}, "required": []}
    },
    {
        "name": "get_employee_roster",
        "description": (
            "Returns the list of all employees with their department, "
            "position, and current status. Use for questions about "
            "specific employees or to search by name."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "search_name": {
                    "type": "string",
                    "description": "Optional partial name to filter results"
                },
                "status_filter": {
                    "type": "string",
                    "description": "Optional status code to filter (e.g. ACTIVE, ONBOARDING)"
                }
            },
            "required": []
        }
    },
    {
        "name": "get_kpi_metrics",
        "description": (
            "Returns all configured KPI metrics with their current computed values "
            "from the dashboard. Use for questions about organizational performance indicators."
        ),
        "input_schema": {"type": "object", "properties": {}, "required": []}
    },
    {
        "name": "get_department_summary",
        "description": (
            "Returns a per-department breakdown: headcount, open workflows, "
            "missing documents. Use for department-level analysis."
        ),
        "input_schema": {"type": "object", "properties": {}, "required": []}
    },
    {
        "name": "get_recent_activity",
        "description": (
            "Returns the most recent workflow actions, transactions, and "
            "system events. Use for questions like 'what happened recently' "
            "or 'what was approved today'."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "limit": {
                    "type": "integer",
                    "description": "Number of recent events to return (default 10, max 25)"
                }
            },
            "required": []
        }
    },
    {
        "name": "get_onboarding_pipeline",
        "description": (
            "Returns all active onboarding workflows with their current step, "
            "checklist completion, and blockers. Use for onboarding status questions."
        ),
        "input_schema": {"type": "object", "properties": {}, "required": []}
    }
]


# ── Tool executor ────────────────────────────────────────────────
def _execute_tool(name: str, inputs: dict) -> str:
    """Execute a named HRIS tool and return a JSON string result."""
    try:
        with get_cursor() as cur:
            if name == "get_workforce_overview":
                group_by = inputs.get("group_by", "both")
                result = {}

                cur.execute("""
                    SELECT e.status AS status_label, COUNT(e.id) AS count
                    FROM core.employees e
                    GROUP BY e.status ORDER BY count DESC
                """)
                result["by_status"] = [dict(r) for r in cur.fetchall()]

                if group_by in ("department", "both"):
                    cur.execute("""
                        SELECT d.name AS department, COUNT(e.id) AS headcount
                        FROM core.departments d
                        LEFT JOIN core.employees e ON d.id = e.department_id
                        GROUP BY d.name ORDER BY headcount DESC
                    """)
                    result["by_department"] = [dict(r) for r in cur.fetchall()]

                cur.execute("SELECT COUNT(*) AS total FROM core.employees")
                result["total_employees"] = cur.fetchone()["total"]
                return json.dumps(result)

            elif name == "get_workflow_status":
                status_filter = inputs.get("status_filter", "all")
                where = ""
                if status_filter != "all":
                    where = f"AND UPPER(wi.status) = '{status_filter.upper()}'"
                cur.execute(f"""
                    SELECT
                        wi.reference_no,
                        wd.name AS workflow_name,
                        wi.status,
                        ws.name AS current_step
                    FROM workflow.workflow_instances wi
                    JOIN workflow.workflow_definitions wd ON wd.id = wi.definition_id
                    LEFT JOIN workflow.workflow_steps ws ON ws.id = wi.current_step_id
                    WHERE 1=1 {where}
                    ORDER BY wi.id DESC
                    LIMIT 50
                """)
                rows = [dict(r) for r in cur.fetchall()]

                cur.execute("""
                    SELECT wi.status, COUNT(*) AS count
                    FROM workflow.workflow_instances wi
                    GROUP BY wi.status
                    ORDER BY count DESC
                """)
                summary = [dict(r) for r in cur.fetchall()]
                return json.dumps({"instances": rows, "summary": summary})

            elif name == "get_document_alerts":
                cur.execute("""
                    SELECT
                        e.employee_no,
                        e.first_name || ' ' || e.last_name AS full_name,
                        d.name AS department,
                        COUNT(ed.id) FILTER (WHERE ed.is_missing = TRUE) AS missing_count,
                        COUNT(ed.id) AS total_docs,
                        ARRAY_AGG(ed.document_name) FILTER (WHERE ed.is_missing = TRUE) AS missing_docs
                    FROM core.employees e
                    LEFT JOIN core.documents ed ON ed.employee_id = e.id
                    LEFT JOIN core.departments d ON e.department_id = d.id
                    GROUP BY e.id, e.employee_no, e.first_name, e.last_name, d.name
                    HAVING COUNT(ed.id) FILTER (WHERE ed.is_missing = TRUE) > 0
                    ORDER BY missing_count DESC
                """)
                rows = [dict(r) for r in cur.fetchall()]
                cur.execute("SELECT COUNT(*) AS total FROM core.documents WHERE is_missing = TRUE")
                total_missing = cur.fetchone()["total"]
                return json.dumps({"employees_with_missing_docs": rows, "total_missing_documents": total_missing})

            elif name == "get_employee_roster":
                search = inputs.get("search_name", "")
                status_f = inputs.get("status_filter", "")
                params = []
                conditions = []
                if search:
                    conditions.append(
                        "(LOWER(e.first_name) LIKE %s OR LOWER(e.last_name) LIKE %s "
                        "OR LOWER(e.first_name || ' ' || e.last_name) LIKE %s)"
                    )
                    term = f"%{search.lower()}%"
                    params += [term, term, term]
                if status_f:
                    conditions.append("UPPER(e.status) = %s")
                    params.append(status_f.upper())
                where = ("WHERE " + " AND ".join(conditions)) if conditions else ""
                cur.execute(f"""
                    SELECT
                        e.employee_no,
                        e.first_name || ' ' || e.last_name AS full_name,
                        d.name AS department,
                        p.title AS position,
                        e.status
                    FROM core.employees e
                    LEFT JOIN core.departments d ON e.department_id = d.id
                    LEFT JOIN core.positions p ON e.position_id = p.id
                    {where}
                    ORDER BY e.last_name, e.first_name
                    LIMIT 50
                """, params)
                return json.dumps([dict(r) for r in cur.fetchall()])

            elif name == "get_kpi_metrics":
                cur.execute("""
                    SELECT code, label, module, filter_url, sort_order
                    FROM core.dashboard_metrics
                    WHERE is_active = TRUE
                    ORDER BY sort_order, code
                """)
                metrics = [dict(r) for r in cur.fetchall()]
                cur.execute("SELECT COUNT(*) AS count FROM core.employees WHERE is_active = TRUE")
                emp_count = cur.fetchone()["count"]
                cur.execute("""
                    SELECT COUNT(*) AS count FROM workflow.workflow_instances
                    WHERE status = 'PENDING'
                """)
                pending_count = cur.fetchone()["count"]
                cur.execute("SELECT COUNT(*) AS count FROM core.documents WHERE is_missing = TRUE")
                missing_docs = cur.fetchone()["count"]
                return json.dumps({
                    "configured_metrics": metrics,
                    "live_values": {
                        "total_active_employees": emp_count,
                        "pending_workflows": pending_count,
                        "missing_documents": missing_docs
                    }
                })

            elif name == "get_department_summary":
                cur.execute("""
                    SELECT
                        d.name AS department,
                        COUNT(DISTINCT e.id) AS headcount,
                        COUNT(DISTINCT ed.id) FILTER (WHERE ed.is_missing = TRUE) AS missing_docs
                    FROM core.departments d
                    LEFT JOIN core.employees e ON e.department_id = d.id
                    LEFT JOIN core.documents ed ON ed.employee_id = e.id
                    GROUP BY d.name ORDER BY headcount DESC
                """)
                return json.dumps([dict(r) for r in cur.fetchall()])

            elif name == "get_recent_activity":
                limit = min(int(inputs.get("limit", 10)), 25)
                cur.execute("""
                    SELECT
                        wal.created_at AS event_time,
                        wal.action_code AS event_text,
                        wd.module AS module_code,
                        wi.reference_no,
                        wi.status AS current_status,
                        u.display_name AS performed_by
                    FROM workflow.workflow_action_logs wal
                    JOIN workflow.workflow_instances wi ON wi.id = wal.instance_id
                    JOIN workflow.workflow_definitions wd ON wd.id = wi.definition_id
                    LEFT JOIN core.users u ON u.id = wal.performed_by
                    ORDER BY wal.created_at DESC
                    LIMIT %s
                """, (limit,))
                actions = [dict(r) for r in cur.fetchall()]
                # Also include recently filed leave requests
                cur.execute("""
                    SELECT
                        lr.created_at AS event_time,
                        'Leave request: ' || lt.name AS event_text,
                        'leave_mgmt' AS module_code,
                        e.first_name || ' ' || e.last_name AS employee_name,
                        lr.status AS current_status
                    FROM leave_mgmt.lv_requests lr
                    JOIN leave_mgmt.lv_types lt ON lt.id = lr.leave_type_id
                    JOIN core.employees e ON e.id = lr.employee_id
                    ORDER BY lr.created_at DESC
                    LIMIT %s
                """, (limit,))
                leave_events = [dict(r) for r in cur.fetchall()]
                return json.dumps({"workflow_actions": actions, "leave_requests": leave_events})

            elif name == "get_onboarding_pipeline":
                cur.execute("""
                    SELECT
                        wi.reference_no,
                        ws.name AS current_step,
                        ws.role_required,
                        wi.status,
                        COUNT(ici.id) AS total_checklist_items,
                        COUNT(ici.id) FILTER (WHERE ici.is_completed) AS completed_items,
                        COUNT(ici.id) FILTER (
                            WHERE NOT ici.is_completed AND wc.is_gate
                        ) AS blocking_items
                    FROM workflow.workflow_instances wi
                    JOIN workflow.workflow_definitions wd ON wd.id = wi.definition_id
                    JOIN workflow.workflow_steps ws ON ws.id = wi.current_step_id
                    LEFT JOIN workflow.instance_checklist_items ici ON ici.instance_id = wi.id
                    LEFT JOIN workflow.workflow_checklists wc ON wc.id = ici.checklist_id
                    WHERE UPPER(wd.module) = 'ONBOARDING'
                      AND wi.status != 'APPROVED'
                    GROUP BY wi.reference_no, ws.name, ws.role_required, wi.status
                """)
                return json.dumps([dict(r) for r in cur.fetchall()])

            else:
                return json.dumps({"error": f"Unknown tool: {name}"})

    except Exception as exc:
        return json.dumps({"error": str(exc)})


# ── Core AI engine ───────────────────────────────────────────────
def _get_client():
    if not _SDK_AVAILABLE:
        return None
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    return anthropic.Anthropic(api_key=api_key) if api_key else None


def _build_system_prompt(company_name: str, user_name: str, role: str) -> str:
    now = datetime.now()
    time_of_day = (
        "morning" if now.hour < 12
        else "afternoon" if now.hour < 17
        else "evening"
    )
    date_str = now.strftime("%A, %B %d, %Y at %I:%M %p")
    return f"""You are ARIA — the Advanced HRIS AI Executive Assistant for {company_name}.
You are currently assisting {user_name} ({role}).
Current date and time: {date_str}.

Your mandate:
- Provide data-driven, accurate insights by always calling tools for live data.
- Never invent or estimate numbers — every figure must come from a tool result.
- Be concise and executive-level: lead with the key finding, then support it.
- Proactively surface risks, anomalies, and action items.
- Format responses cleanly: use bullet points and short paragraphs.
- When presenting numbers, always give context (e.g. "3 of 10 employees").

Communication style: confident, direct, professional. No filler phrases."""


def _run_tool_loop(messages: list, system: str, client, max_turns: int = 6) -> list:
    """Run the agentic tool-use loop. Returns updated messages list."""
    for _ in range(max_turns):
        response = client.messages.create(
            model=MODEL,
            max_tokens=2048,
            system=system,
            tools=HRIS_TOOLS,
            messages=messages
        )
        if response.stop_reason != "tool_use":
            return messages  # ready for final streaming pass
        tool_results = []
        for block in response.content:
            if block.type == "tool_use":
                result = _execute_tool(block.name, block.input)
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": block.id,
                    "content": result
                })
        messages = messages + [
            {"role": "assistant", "content": response.content},
            {"role": "user",      "content": tool_results}
        ]
    return messages


# ── Public API ───────────────────────────────────────────────────
def stream_chat(conversation_history: list, user_message: str,
                company_name: str, user_name: str, role: str):
    """
    Generator — yields Server-Sent Event strings.
    Phase 1: tool-use loop (yields 'tool' events with tool name).
    Phase 2: streams the final text response chunk by chunk.
    """
    client = _get_client()
    if not client:
        yield _sse("error", {"text": "ARIA is offline. Set ANTHROPIC_API_KEY to activate."})
        return

    system = _build_system_prompt(company_name, user_name, role)
    messages = list(conversation_history) + [{"role": "user", "content": user_message}]

    # ── Phase 1: collect tool results ───────────────────────────
    for _ in range(6):
        response = client.messages.create(
            model=MODEL,
            max_tokens=1024,
            system=system,
            tools=HRIS_TOOLS,
            messages=messages
        )
        if response.stop_reason != "tool_use":
            break
        tool_results = []
        for block in response.content:
            if block.type == "tool_use":
                # Signal UI that a tool is running
                yield _sse("tool", {"name": block.name})
                result = _execute_tool(block.name, block.input)
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": block.id,
                    "content": result
                })
        messages = messages + [
            {"role": "assistant", "content": response.content},
            {"role": "user",      "content": tool_results}
        ]

    # ── Phase 2: stream the final answer ────────────────────────
    yield _sse("status", {"text": "Composing response..."})
    try:
        with client.messages.stream(
            model=MODEL,
            max_tokens=2048,
            system=system,
            tools=HRIS_TOOLS,
            messages=messages
        ) as stream:
            for text in stream.text_stream:
                yield _sse("text", {"text": text})
    except Exception as exc:
        yield _sse("error", {"text": str(exc)})

    yield _sse("done", {})


def generate_briefing(company_name: str, user_name: str, role: str) -> dict:
    """
    Generate a full executive HR briefing.
    Returns {"content": str, "metrics_snapshot": dict, "generation_ms": int}
    """
    client = _get_client()
    if not client:
        return {
            "content": "ARIA is offline. Please configure ANTHROPIC_API_KEY.",
            "metrics_snapshot": {},
            "generation_ms": 0
        }

    start = time.time()
    today = datetime.now().strftime("%A, %B %d, %Y")
    time_of_day = "morning" if datetime.now().hour < 12 else "afternoon" if datetime.now().hour < 17 else "evening"

    system = f"""You are ARIA — the AI Executive HR Assistant for {company_name}.
Today is {today}. You are preparing a {time_of_day} briefing for {user_name} ({role}).

Call the available tools to gather fresh data, then generate a structured executive briefing.

Format your briefing exactly as follows:

## Good {time_of_day.capitalize()}, {user_name}

**Executive Summary**
[2–3 sentence overall state of the workforce]

**Workforce at a Glance**
[Bullet-point metrics table: total headcount, by status, by department]

**Alerts & Action Required**
[Any pending approvals, missing docs, risks — or "No critical alerts"]

**Workflow Pipeline**
[Status of active workflows]

**Data Quality**
[Document completeness status]

**Recommended Actions**
[3 bullet points: most important things the executive should act on today]

Be data-driven. Every number must come from a tool. Do not estimate."""

    messages = [{"role": "user", "content": f"Generate my executive HR briefing for {today}."}]
    messages = _run_tool_loop(messages, system, client, max_turns=8)

    # Final generation (non-streaming for briefing storage)
    response = client.messages.create(
        model=MODEL,
        max_tokens=3000,
        system=system,
        tools=HRIS_TOOLS,
        messages=messages
    )
    content = response.content[0].text if response.content else "Unable to generate briefing."

    # Snapshot key metrics
    metrics_snapshot = {}
    try:
        with get_cursor() as cur:
            cur.execute("SELECT COUNT(*) AS total FROM core.employees WHERE is_active = TRUE")
            metrics_snapshot["total_employees"] = cur.fetchone()["total"]
            cur.execute("""
                SELECT COUNT(*) AS count FROM workflow.workflow_instances
                WHERE status = 'PENDING'
            """)
            metrics_snapshot["pending_workflows"] = cur.fetchone()["count"]
            cur.execute("SELECT COUNT(*) AS count FROM core.documents WHERE is_missing = TRUE")
            metrics_snapshot["missing_docs"] = cur.fetchone()["count"]
    except Exception:
        pass

    return {
        "content": content,
        "metrics_snapshot": metrics_snapshot,
        "generation_ms": int((time.time() - start) * 1000)
    }


def _sse(event_type: str, data: dict) -> str:
    return f"data: {json.dumps({'type': event_type, **data})}\n\n"


def is_available() -> bool:
    return _SDK_AVAILABLE and bool(os.environ.get("ANTHROPIC_API_KEY"))
