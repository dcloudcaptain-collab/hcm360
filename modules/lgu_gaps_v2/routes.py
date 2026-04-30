"""
LGU Gaps v2 Blueprint — consolidates G08, G09, G10, G11, G15, G16, G17, G18.

Routes:
  G15 · /reports/eligibility            — CSC Eligibility Level × Gender
  G18 · /reports/attrition-risk         — Attrition Risk Dashboard
       · /reports/attrition-risk/scan   (POST) — re-run risk scoring
  G11 · /rewards/loyalty                — Loyalty Award Dashboard
       · /rewards/loyalty/scan          (POST)
       · /rewards/loyalty/<id>/memo.pdf (GET)
       · /rewards/loyalty/<id>/awarded  (POST)
  G16 · /admin/saln-settings
       · /me/saln                        — Employee SALN form
       · /dms/saln                       — HR list
       · /dms/saln/<id>.pdf              — Download
       · /dms/saln/<id>/verify           (POST)
  G17 · /rsp/appointments/<id>/pdf       — CSC Form 33 download
  G09 · /learning/sessions/<id>/checkin  — Mobile training attendance UI
       · /learning/sessions/<id>/checkin/api (POST)
  G10 · /learning/nrf                    — NRF list
       · /learning/nrf/new/<enrollment_id>
       · /learning/nrf/<id>
  G08 · /admin/esignature-settings
       · /esign/<entity_kind>/<entity_id>/sign        — Sign page
       · /esign/<entity_kind>/<entity_id>/canvas      (POST)
       · /esign/<entity_kind>/<entity_id>/docusign    (POST)
       · /esign/webhook/docusign                       (POST - no auth)
"""
import io
import json
from functools import wraps
from datetime import date as Date

from flask import (Blueprint, flash, jsonify, redirect, render_template,
                   request, send_file, session, url_for, abort)

from services import lgu_g15_g18_service as g15g18
from services import lgu_g11_g16_g17_service as g11g16g17
from services import lgu_g08_g09_service as g08g09
from services import ai_service as ai_svc
from services.db import get_cursor


lgu_gaps_v2_bp = Blueprint('lgu_gaps_v2', __name__,
                            template_folder='../../templates/lgu_gaps_v2')


def _login_required(f):
    @wraps(f)
    def decorated(*a, **kw):
        if 'user_id' not in session:
            return redirect(url_for('login'))
        return f(*a, **kw)
    return decorated


def _admin_required(f):
    @wraps(f)
    def decorated(*a, **kw):
        if session.get('role_code') not in ('SUPER_ADMIN', 'HR_ADMIN'):
            flash('Admin access required.', 'error')
            return redirect(url_for('dashboard.index'))
        return f(*a, **kw)
    return decorated


def _company_id():
    with get_cursor() as cur:
        cur.execute('SELECT id FROM core.companies ORDER BY id LIMIT 1')
        row = cur.fetchone()
    return row['id'] if row else 1


def _emp_name(user_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT u.display_name,
                   CONCAT_WS(' ', e.first_name, e.last_name) AS emp_name
            FROM core.users u
            LEFT JOIN core.employees e ON e.id = u.employee_id
            WHERE u.id = %s
        """, (user_id,))
        r = cur.fetchone()
    if not r:
        return 'User'
    return r.get('emp_name') or r.get('display_name') or 'User'


# ══════════════════════════════════════════════════════════════════════
# G15 · CSC Eligibility Report
# ══════════════════════════════════════════════════════════════════════
@lgu_gaps_v2_bp.route('/reports/eligibility')
@_login_required
def eligibility_report():
    cid = _company_id()
    level_gender = g15g18.eligibility_by_level_gender(cid)
    dept_level = g15g18.eligibility_by_dept_level(cid)
    employees = g15g18.eligibility_detail_list(cid,
                                               request.args.get('level'))
    return render_template('lgu_gaps_v2/eligibility_report.html',
                           level_gender=level_gender,
                           dept_level=dept_level,
                           employees=employees,
                           level_filter=request.args.get('level'))


# ══════════════════════════════════════════════════════════════════════
# G18 · Attrition Risk Dashboard
# ══════════════════════════════════════════════════════════════════════
@lgu_gaps_v2_bp.route('/reports/attrition-risk')
@_login_required
def attrition_dashboard():
    cid = _company_id()
    summary = g15g18.attrition_summary(cid)
    risk_filter = request.args.get('risk')
    rows = g15g18.attrition_list(cid, risk_level=risk_filter)
    return render_template('lgu_gaps_v2/attrition_risk.html',
                           rows=rows, summary=summary,
                           risk_filter=risk_filter)


@lgu_gaps_v2_bp.route('/reports/attrition-risk/scan', methods=['POST'])
@_login_required
@_admin_required
def attrition_scan():
    cid = _company_id()
    result = g15g18.predict_batch(cid)
    return jsonify({'ok': True, 'scored': result['scored'],
                    'inserted': result['inserted']})


# ══════════════════════════════════════════════════════════════════════
# G11 · Loyalty Awards
# ══════════════════════════════════════════════════════════════════════
@lgu_gaps_v2_bp.route('/rewards/loyalty')
@_login_required
@_admin_required
def loyalty_dashboard():
    cid = _company_id()
    status = request.args.get('status')
    rows = g11g16g17.loyalty_list(cid, status=status)
    summary = g11g16g17.loyalty_summary(cid)
    return render_template('lgu_gaps_v2/loyalty.html',
                           rows=rows, summary=summary,
                           status_filter=status)


@lgu_gaps_v2_bp.route('/rewards/loyalty/scan', methods=['POST'])
@_login_required
@_admin_required
def loyalty_scan():
    cid = _company_id()
    result = g11g16g17.loyalty_scan(cid)
    return jsonify({'ok': True, **result})


@lgu_gaps_v2_bp.route('/rewards/loyalty/<int:mid>/memo.pdf')
@_login_required
@_admin_required
def loyalty_memo(mid):
    try:
        pdf = g11g16g17.loyalty_generate_memo(mid, session.get('user_id'))
    except Exception as ex:
        flash(f'Failed to generate memo: {ex}', 'error')
        return redirect(url_for('lgu_gaps_v2.loyalty_dashboard'))
    return send_file(io.BytesIO(pdf), mimetype='application/pdf',
                     as_attachment=True,
                     download_name=f'loyalty_memo_{mid}.pdf')


@lgu_gaps_v2_bp.route('/rewards/loyalty/<int:mid>/awarded', methods=['POST'])
@_login_required
@_admin_required
def loyalty_awarded(mid):
    row = g11g16g17.loyalty_mark_awarded(mid, session.get('user_id'))
    return jsonify({'ok': bool(row)})


# ══════════════════════════════════════════════════════════════════════
# G16 · SALN (3-mode)
# ══════════════════════════════════════════════════════════════════════
@lgu_gaps_v2_bp.route('/admin/saln-settings', methods=['GET', 'POST'])
@_login_required
@_admin_required
def saln_settings():
    cid = _company_id()
    if request.method == 'POST':
        data = request.get_json(silent=True) or request.form.to_dict()
        g11g16g17.saln_save_settings(cid, data, session.get('user_id'))
        if request.headers.get('Content-Type', '').startswith('application/json'):
            return jsonify({'ok': True})
        flash('SALN settings saved.', 'success')
        return redirect(url_for('lgu_gaps_v2.saln_settings'))
    settings = g11g16g17.saln_get_settings(cid)
    return render_template('lgu_gaps_v2/saln_settings.html', settings=settings)


@lgu_gaps_v2_bp.route('/me/saln', methods=['GET', 'POST'])
@_login_required
def saln_me():
    emp_id = session.get('employee_id')
    if not emp_id:
        flash('No employee record linked.', 'error')
        return redirect(url_for('dashboard.index'))
    cid = _company_id()
    settings = g11g16g17.saln_get_settings(cid)
    year = int(request.args.get('year') or Date.today().year)

    if request.method == 'POST':
        data = request.get_json(silent=True) or {}
        mode = data.get('mode') or settings['mode']
        payload = data.get('data') or {}
        submit = bool(data.get('submit', False))
        fid = g11g16g17.saln_upsert(emp_id, year, mode, payload, submit=submit)
        return jsonify({'ok': True, 'id': fid, 'submitted': submit})

    current = g11g16g17.saln_get_current(emp_id, year)
    existing_data = {}
    if current and current.get('data'):
        d = current['data']
        existing_data = d if isinstance(d, dict) else json.loads(d or '{}')
    return render_template('lgu_gaps_v2/saln_me.html',
                           settings=settings, current=current,
                           data=existing_data, year=year)


@lgu_gaps_v2_bp.route('/dms/saln')
@_login_required
@_admin_required
def saln_list():
    cid = _company_id()
    year = request.args.get('year', type=int)
    status = request.args.get('status')
    rows = g11g16g17.saln_list(cid, status=status, year=year)
    return render_template('lgu_gaps_v2/saln_list.html',
                           rows=rows, year_filter=year, status_filter=status)


@lgu_gaps_v2_bp.route('/dms/saln/<int:fid>.pdf')
@_login_required
def saln_pdf(fid):
    try:
        pdf = g11g16g17.saln_render_pdf(fid)
    except Exception as ex:
        flash(f'Failed to render SALN: {ex}', 'error')
        return redirect(url_for('lgu_gaps_v2.saln_list'))
    return send_file(io.BytesIO(pdf), mimetype='application/pdf',
                     as_attachment=True,
                     download_name=f'saln_{fid}.pdf')


@lgu_gaps_v2_bp.route('/dms/saln/<int:fid>/verify', methods=['POST'])
@_login_required
@_admin_required
def saln_verify(fid):
    row = g11g16g17.saln_verify(fid, session.get('user_id'))
    return jsonify({'ok': bool(row)})


# ══════════════════════════════════════════════════════════════════════
# G17 · Appointment PDF
# ══════════════════════════════════════════════════════════════════════
@lgu_gaps_v2_bp.route('/rsp/appointments/<int:aid>/pdf')
@_login_required
def appointment_pdf(aid):
    try:
        pdf = g11g16g17.appointment_render_pdf(aid)
    except Exception as ex:
        flash(f'Failed to render appointment: {ex}', 'error')
        return redirect(url_for('dashboard.index'))
    return send_file(io.BytesIO(pdf), mimetype='application/pdf',
                     as_attachment=True,
                     download_name=f'appointment_{aid}.pdf')


# ══════════════════════════════════════════════════════════════════════
# G09 · Training Attendance Mobile Check-In
# ══════════════════════════════════════════════════════════════════════
@lgu_gaps_v2_bp.route('/learning/sessions/<int:sid>/checkin')
@_login_required
def training_checkin_page(sid):
    emp_id = session.get('employee_id')
    if not emp_id:
        flash('No employee record linked.', 'error')
        return redirect(url_for('dashboard.index'))
    sess = g08g09.training_session_info(sid)
    if not sess:
        abort(404)
    enrollment_id = g08g09.training_find_enrollment(emp_id, sid)
    return render_template('lgu_gaps_v2/training_checkin.html',
                           sess=sess, enrollment_id=enrollment_id,
                           session_id=sid)


@lgu_gaps_v2_bp.route('/learning/sessions/<int:sid>/checkin/api',
                       methods=['POST'])
@_login_required
def training_checkin_api(sid):
    emp_id = session.get('employee_id')
    if not emp_id:
        return jsonify({'ok': False, 'message': 'No employee record.'}), 400
    enrollment_id = g08g09.training_find_enrollment(emp_id, sid)
    if not enrollment_id:
        return jsonify({'ok': False,
                        'message': 'You are not enrolled in this session.'}), 400
    data = request.get_json(silent=True) or {}
    result = g08g09.training_checkin(enrollment_id, emp_id, sid, data,
                                      ip_address=request.remote_addr)
    status = 200 if result.get('ok') else 400
    return jsonify(result), status


# ══════════════════════════════════════════════════════════════════════
# G10 · Narrative Report Form
# ══════════════════════════════════════════════════════════════════════
@lgu_gaps_v2_bp.route('/learning/nrf')
@_login_required
def nrf_list():
    from modules.ld import ld_service as ld_svc
    emp_id = session.get('employee_id')
    is_admin = session.get('role_code') in ('SUPER_ADMIN', 'HR_ADMIN')
    rows = ld_svc.get_narrative_reports(
        employee_id=None if is_admin else emp_id)
    return render_template('lgu_gaps_v2/nrf_list.html',
                           rows=rows, is_admin=is_admin)


@lgu_gaps_v2_bp.route('/learning/nrf/new/<int:enrollment_id>',
                       methods=['GET', 'POST'])
@_login_required
def nrf_new(enrollment_id):
    from modules.ld import ld_service as ld_svc
    emp_id = session.get('employee_id')
    if not emp_id:
        flash('No employee record linked.', 'error')
        return redirect(url_for('dashboard.index'))

    # Look up enrollment context
    with get_cursor() as cur:
        cur.execute("""
            SELECT en.id AS enrollment_id, en.employee_id,
                   p.title AS training_title,
                   s.session_date, s.session_end, s.venue, s.facilitator
            FROM learning.lrn_enrollments en
            JOIN learning.lrn_sessions s ON s.id = en.session_id
            JOIN learning.lrn_programs p ON p.id = s.program_id
            WHERE en.id = %s
        """, (enrollment_id,))
        ctx = cur.fetchone()
    if not ctx:
        abort(404)
    if ctx['employee_id'] != emp_id and \
       session.get('role_code') not in ('SUPER_ADMIN', 'HR_ADMIN'):
        abort(403)

    if request.method == 'POST':
        form = request.form.to_dict()
        form.setdefault('training_title', ctx['training_title'])
        form.setdefault('training_dates',
                         str(ctx['session_date']) +
                         ((' to ' + str(ctx['session_end']))
                          if ctx['session_end'] else ''))
        form.setdefault('venue', ctx['venue'] or '')
        form.setdefault('facilitator', ctx['facilitator'] or '')
        form['evaluation_rating'] = (
            float(form['evaluation_rating']) if form.get('evaluation_rating')
            else None)
        nrf = ld_svc.submit_narrative_report(enrollment_id,
                                              ctx['employee_id'], form)
        flash('Narrative Report submitted.', 'success')
        return redirect(url_for('lgu_gaps_v2.nrf_view', nid=nrf['id']))

    return render_template('lgu_gaps_v2/nrf_new.html', ctx=ctx)


@lgu_gaps_v2_bp.route('/learning/nrf/<int:nid>')
@_login_required
def nrf_view(nid):
    with get_cursor() as cur:
        cur.execute("""
            SELECT nr.*,
                   CONCAT_WS(' ', e.first_name, e.last_name) AS employee_name,
                   e.employee_no
            FROM learning.lrn_narrative_reports nr
            JOIN core.employees e ON e.id = nr.employee_id
            WHERE nr.id = %s
        """, (nid,))
        r = cur.fetchone()
    if not r:
        abort(404)
    return render_template('lgu_gaps_v2/nrf_view.html', r=r)


# ══════════════════════════════════════════════════════════════════════
# G08 · Electronic Signature
# ══════════════════════════════════════════════════════════════════════
@lgu_gaps_v2_bp.route('/admin/esignature-settings', methods=['GET', 'POST'])
@_login_required
@_admin_required
def esig_settings():
    cid = _company_id()
    if request.method == 'POST':
        data = request.get_json(silent=True) or request.form.to_dict()
        g08g09.esig_save_settings(cid, data, session.get('user_id'))
        if request.headers.get('Content-Type', '').startswith('application/json'):
            return jsonify({'ok': True})
        flash('E-Signature settings saved.', 'success')
        return redirect(url_for('lgu_gaps_v2.esig_settings'))
    settings = g08g09.esig_get_settings(cid)
    recent = g08g09.esig_list_recent(cid, limit=50)
    return render_template('lgu_gaps_v2/esig_settings.html',
                           settings=settings, recent=recent)


@lgu_gaps_v2_bp.route('/esign/<entity_kind>/<int:entity_id>/sign')
@_login_required
def esig_sign_page(entity_kind, entity_id):
    cid = _company_id()
    settings = g08g09.esig_get_settings(cid)
    existing = g08g09.esig_list_for_entity(entity_kind, entity_id)
    signer_name = _emp_name(session.get('user_id'))
    return render_template('lgu_gaps_v2/esig_sign.html',
                           entity_kind=entity_kind, entity_id=entity_id,
                           settings=settings, existing=existing,
                           signer_name=signer_name)


@lgu_gaps_v2_bp.route('/esign/<entity_kind>/<int:entity_id>/canvas',
                       methods=['POST'])
@_login_required
def esig_canvas(entity_kind, entity_id):
    data = request.get_json(silent=True) or {}
    img = data.get('signature_image_b64')
    if not img or len(img) < 100:
        return jsonify({'ok': False, 'message': 'Signature image required.'}), 400
    signer_name = data.get('signer_name') or _emp_name(session.get('user_id'))
    signer_role = data.get('signer_role') or 'Signatory'
    result = g08g09.esig_capture_canvas(
        entity_kind=entity_kind, entity_id=entity_id,
        signer_user_id=session.get('user_id'),
        signer_name=signer_name, signer_role=signer_role,
        signature_image_b64=img,
        ip_address=request.remote_addr,
        user_agent=request.headers.get('User-Agent'))
    return jsonify({'ok': True, **result})


@lgu_gaps_v2_bp.route('/esign/<entity_kind>/<int:entity_id>/docusign',
                       methods=['POST'])
@_login_required
def esig_docusign(entity_kind, entity_id):
    data = request.get_json(silent=True) or request.form.to_dict()
    email = data.get('signer_email')
    if not email:
        return jsonify({'ok': False, 'message': 'signer_email required.'}), 400
    result = g08g09.esig_send_docusign(
        entity_kind=entity_kind, entity_id=entity_id,
        signer_email=email,
        signer_name=data.get('signer_name') or email,
        subject=data.get('subject', 'Please sign'))
    return jsonify({'ok': True, **result})


@lgu_gaps_v2_bp.route('/esign/webhook/docusign', methods=['POST'])
def esig_docusign_webhook():
    # Simplified: accept JSON with envelope_id and status
    data = request.get_json(silent=True) or request.form.to_dict()
    eid = data.get('envelope_id')
    status = data.get('status', 'completed')
    if not eid:
        return jsonify({'ok': False, 'message': 'envelope_id required.'}), 400
    g08g09.esig_handle_docusign_webhook(eid, status)
    return jsonify({'ok': True})


# ══════════════════════════════════════════════════════════════════════
# AI Tool integration — add predict_attrition_risk to ARIA
# ══════════════════════════════════════════════════════════════════════
# Register a new tool on import if ai_service.HRIS_TOOLS exists.
try:
    if hasattr(ai_svc, 'HRIS_TOOLS') and not any(
            t['name'] == 'predict_attrition_risk' for t in ai_svc.HRIS_TOOLS):
        ai_svc.HRIS_TOOLS.append({
            'name': 'predict_attrition_risk',
            'description': (
                'Returns the top-N employees at highest risk of leaving the '
                'organization, with risk scores and contributing factors. '
                'Use for questions like "who might resign soon?" or '
                '"which employees should I focus on for retention?"'
            ),
            'input_schema': {
                'type': 'object',
                'properties': {
                    'top_n': {
                        'type': 'integer',
                        'description': 'Number of highest-risk employees to return (default 10, max 50)'
                    },
                    'risk_level': {
                        'type': 'string',
                        'enum': ['HIGH', 'MEDIUM', 'LOW'],
                        'description': 'Optional filter by risk level'
                    }
                }
            }
        })
    # Hook the tool executor
    if hasattr(ai_svc, '_execute_tool'):
        _orig = ai_svc._execute_tool

        def _patched(name, inputs):
            if name == 'predict_attrition_risk':
                cid = _company_id() if False else 1
                rows = g15g18.attrition_list(
                    cid, risk_level=inputs.get('risk_level'),
                    limit=min(int(inputs.get('top_n') or 10), 50))
                return json.dumps({
                    'employees': [
                        {
                            'employee_id': r['employee_id'],
                            'name': r['full_name'],
                            'department': r.get('department_name'),
                            'tenure_years': r.get('tenure_years'),
                            'risk_score': float(r['risk_score'] or 0),
                            'risk_level': r['risk_level'],
                            'factors': r.get('factors'),
                        } for r in rows
                    ]
                }, default=str)
            return _orig(name, inputs)

        ai_svc._execute_tool = _patched
except Exception:
    pass
