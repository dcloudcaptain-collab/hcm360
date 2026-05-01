from flask import Blueprint, Response, g, jsonify, redirect, render_template, request, stream_with_context, url_for
from services import ai_service
from services.db import get_cursor

bp = Blueprint('ai', __name__, url_prefix='/ai')


def _company_name() -> str:
    try:
        from services.settings_service import get_branding
        b = get_branding()
        return b.get('company_name', 'Your Company') if b else 'Your Company'
    except Exception:
        return 'Your Company'


def _current_user_info() -> tuple[str, str]:
    """Return (display_name, role_code) for the logged-in user."""
    user = getattr(g, 'current_user', None)
    if user:
        return user.get('display_name', 'Executive'), user.get('role_code', 'SUPER_ADMIN')
    return 'Executive', 'SUPER_ADMIN'


# ── Pages ────────────────────────────────────────────────────────

@bp.route('/')
def index():
    """Redirect /ai → /ai/assistant."""
    return redirect(url_for('ai.assistant'))


@bp.route('/executive')
def executive_briefing():
    """Executive briefing page — generates a fresh briefing on load.

    Anthropic API failures (low credit, rate-limit, network, etc.) are caught
    so the page renders a graceful 'AI unavailable' state instead of a 500.
    """
    available = ai_service.is_available()
    briefing = None
    ai_error = None
    if available:
        name, role = _current_user_info()
        try:
            briefing = ai_service.generate_briefing(_company_name(), name, role)
        except Exception as e:
            ai_error = str(e)
            available = False  # surface as offline for the template
    return render_template(
        'ai/executive_briefing.html',
        briefing=briefing,
        ai_available=available,
        ai_error=ai_error,
    )


@bp.route('/assistant')
def assistant():
    """Interactive AI chat assistant page."""
    return render_template(
        'ai/assistant.html',
        ai_available=ai_service.is_available()
    )


# ── API endpoints ────────────────────────────────────────────────

@bp.route('/api/chat', methods=['POST'])
def chat():
    """
    Streaming chat endpoint using Server-Sent Events.
    Accepts JSON: { "message": str, "history": [...] }
    Streams SSE: data: {"type": "tool"|"text"|"done"|"error", ...}
    """
    if not ai_service.is_available():
        return jsonify({"error": "ARIA is offline. ANTHROPIC_API_KEY not configured."}), 503

    payload = request.get_json(silent=True) or {}
    user_message = (payload.get("message") or "").strip()
    if not user_message:
        return jsonify({"error": "Message is required."}), 400

    history = payload.get("history") or []
    # Sanitise history: keep only role/content keys
    safe_history = [
        {"role": m["role"], "content": m["content"]}
        for m in history
        if m.get("role") in ("user", "assistant") and m.get("content")
    ][-20:]  # keep last 20 turns max

    name, role = _current_user_info()
    company = _company_name()

    def generate():
        yield from ai_service.stream_chat(safe_history, user_message, company, name, role)

    return Response(
        stream_with_context(generate()),
        mimetype='text/event-stream',
        headers={
            'Cache-Control': 'no-cache',
            'X-Accel-Buffering': 'no'
        }
    )


@bp.route('/api/briefing/refresh', methods=['POST'])
def refresh_briefing():
    """Re-generate an executive briefing on demand."""
    if not ai_service.is_available():
        return jsonify({"error": "ARIA offline."}), 503
    name, role = _current_user_info()
    try:
        result = ai_service.generate_briefing(_company_name(), name, role)
    except Exception as e:
        return jsonify({"error": f"ARIA temporarily unavailable: {e}"}), 503
    return jsonify(result)


@bp.route('/api/status')
def status():
    """Health check for ARIA availability."""
    return jsonify({
        "available": ai_service.is_available(),
        "model": "claude-sonnet-4-6"
    })
