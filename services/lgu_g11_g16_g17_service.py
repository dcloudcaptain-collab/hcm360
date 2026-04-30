"""
G11 — Loyalty Award Memo Generator (builds on rewards.rwd_loyalty_milestones)
G16 — SALN Filings (3-mode configurable)
G17 — Appointment PDF (CSC Form 33)

PDF generation shares the ReportLab pattern from services/reporting_service.render_payslip_pdf.
"""
import io
import json
import os
from datetime import date as Date

from reportlab.lib.pagesizes import LETTER
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch, mm
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer,
                                Table, TableStyle, PageBreak, KeepTogether)

from services.db import get_cursor


# ══════════════════════════════════════════════════════════════════════
# Shared ReportLab setup
# ══════════════════════════════════════════════════════════════════════
BRAND = colors.HexColor('#1E40AF')
GRAY = colors.HexColor('#6B7280')
DARK = colors.HexColor('#111827')
LIGHT = colors.HexColor('#F3F4F6')


def _doc(out, title):
    return SimpleDocTemplate(out, pagesize=LETTER,
                             leftMargin=20 * mm, rightMargin=20 * mm,
                             topMargin=20 * mm, bottomMargin=20 * mm,
                             title=title, author='HCM360')


def _header(title, subtitle=None):
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle('t', fontName='Helvetica-Bold', fontSize=14,
                                  alignment=TA_CENTER, textColor=DARK)
    sub_style = ParagraphStyle('s', fontName='Helvetica', fontSize=10,
                               alignment=TA_CENTER, textColor=GRAY, spaceAfter=12)
    story = [Paragraph(title, title_style)]
    if subtitle:
        story.append(Paragraph(subtitle, sub_style))
    return story


def _kv_table(rows, col1_w=2.0 * inch, col2_w=4.2 * inch):
    t = Table(rows, colWidths=[col1_w, col2_w])
    t.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9.5),
        ('TEXTCOLOR', (0, 0), (0, -1), GRAY),
        ('TEXTCOLOR', (1, 0), (1, -1), DARK),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('TOPPADDING', (0, 0), (-1, -1), 3),
    ]))
    return t


def _sig_block():
    styles = getSampleStyleSheet()
    small = ParagraphStyle('sm', fontName='Helvetica', fontSize=9,
                           alignment=TA_CENTER, textColor=DARK)
    t = Table([
        [Paragraph('_________________________', small),
         Paragraph('_________________________', small)],
        [Paragraph('Signature of Declarant / Signatory', small),
         Paragraph('HR / Approver', small)],
    ], colWidths=[3.0 * inch, 3.0 * inch])
    t.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('TOPPADDING', (0, 0), (-1, -1), 20),
    ]))
    return t


# ══════════════════════════════════════════════════════════════════════
# G11 · Loyalty Award
# ══════════════════════════════════════════════════════════════════════
def loyalty_scan(company_id: int):
    """Scan for 10/15/20/25/30-year anniversaries within 180 days ahead."""
    inserted = 0
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO rewards.rwd_loyalty_milestones
                (employee_id, service_years, eligibility_date,
                 award_type, award_value, status)
            SELECT e.id, m.years,
                   (e.date_hired + (m.years || ' years')::interval)::date AS eligibility_date,
                   CASE
                       WHEN m.years = 10 THEN 'PLAQUE'
                       WHEN m.years IN (15, 20) THEN 'CASH_GIFT'
                       ELSE 'COMBINATION'
                   END AS award_type,
                   CASE
                       WHEN m.years = 10 THEN 5000
                       WHEN m.years = 15 THEN 10000
                       WHEN m.years = 20 THEN 15000
                       WHEN m.years = 25 THEN 20000
                       WHEN m.years = 30 THEN 30000
                       ELSE NULL
                   END AS award_value,
                   CASE
                       WHEN (e.date_hired + (m.years || ' years')::interval)::date <= CURRENT_DATE
                         THEN 'ELIGIBLE'
                       ELSE 'UPCOMING'
                   END AS status
            FROM core.employees e
            CROSS JOIN (VALUES (10), (15), (20), (25), (30), (35), (40)) AS m(years)
            WHERE e.company_id = %s
              AND e.status = 'ACTIVE'
              AND e.date_hired IS NOT NULL
              AND (e.date_hired + (m.years || ' years')::interval)::date
                   BETWEEN CURRENT_DATE - INTERVAL '365 days'
                       AND CURRENT_DATE + INTERVAL '180 days'
            ON CONFLICT (employee_id, service_years) DO NOTHING
            RETURNING id
        """, (company_id,))
        inserted = cur.rowcount
    return {'inserted': inserted}


def loyalty_list(company_id: int, status: str = None):
    with get_cursor() as cur:
        sql = """
            SELECT m.id, m.employee_id, m.service_years, m.award_type, m.award_value,
                   m.eligibility_date, m.status, m.awarded_at, m.memo_no,
                   m.memo_generated_at, m.notified_at,
                   e.employee_no, e.date_hired,
                   CONCAT_WS(' ', e.first_name, e.middle_name, e.last_name) AS full_name,
                   d.name AS department_name,
                   p.title AS position_title
            FROM rewards.rwd_loyalty_milestones m
            JOIN core.employees e ON e.id = m.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.positions p   ON p.id = e.position_id
            WHERE e.company_id = %s
        """
        params = [company_id]
        if status:
            sql += ' AND m.status = %s'
            params.append(status)
        sql += ' ORDER BY m.eligibility_date DESC LIMIT 500'
        cur.execute(sql, tuple(params))
        return cur.fetchall()


def loyalty_summary(company_id: int):
    with get_cursor() as cur:
        cur.execute("""
            SELECT
                COUNT(*) FILTER (WHERE m.status = 'UPCOMING') AS upcoming,
                COUNT(*) FILTER (WHERE m.status = 'ELIGIBLE') AS eligible,
                COUNT(*) FILTER (WHERE m.status = 'AWARDED'
                                 AND m.awarded_at > CURRENT_DATE - INTERVAL '365 days') AS awarded_ytd,
                SUM(m.award_value) FILTER (WHERE m.status = 'ELIGIBLE') AS eligible_value
            FROM rewards.rwd_loyalty_milestones m
            JOIN core.employees e ON e.id = m.employee_id
            WHERE e.company_id = %s
        """, (company_id,))
        return dict(cur.fetchone())


def loyalty_generate_memo(milestone_id: int, user_id: int) -> bytes:
    """Generate the loyalty memo PDF + update the milestone record."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT m.*, e.employee_no,
                   CONCAT_WS(' ', e.first_name, e.middle_name, e.last_name) AS full_name,
                   e.date_hired,
                   d.name AS department_name,
                   p.title AS position_title,
                   c.name AS company_name
            FROM rewards.rwd_loyalty_milestones m
            JOIN core.employees e ON e.id = m.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.positions p   ON p.id = e.position_id
            JOIN core.companies c ON c.id = e.company_id
            WHERE m.id = %s
        """, (milestone_id,))
        m = cur.fetchone()
        if not m:
            raise ValueError('Milestone not found')

    buf = io.BytesIO()
    doc = _doc(buf, f'Loyalty Award Memo - {m["full_name"]}')
    styles = getSampleStyleSheet()
    body = ParagraphStyle('b', fontName='Helvetica', fontSize=10.5,
                          leading=14, textColor=DARK, spaceAfter=8)
    small = ParagraphStyle('s', fontName='Helvetica', fontSize=9,
                           textColor=GRAY, spaceAfter=10)

    memo_no = f'LOY-{Date.today().year}-{m["id"]:05d}'
    story = []
    story.extend(_header(m['company_name'] or 'Company',
                         'LOYALTY SERVICE AWARD MEMORANDUM'))
    story.append(Spacer(1, 10))
    story.append(Paragraph(
        f'<b>Memo No.</b> {memo_no} &nbsp;&nbsp;&nbsp; '
        f'<b>Date</b> {Date.today().strftime("%B %d, %Y")}', small))
    story.append(Spacer(1, 6))

    story.append(Paragraph(
        f'TO: <b>{m["full_name"]}</b>, {m["position_title"] or "Employee"}',
        body))
    story.append(Paragraph(
        f'SUBJECT: <b>{m["service_years"]} Years of Service Loyalty Award</b>',
        body))
    story.append(Spacer(1, 10))

    service_yrs = m['service_years']
    body_text = (
        f'In recognition of your <b>{service_yrs} years of continuous and '
        f'dedicated service</b> with {m["company_name"]}, please be advised '
        f'that you are hereby conferred the Loyalty Service Award effective '
        f'{m["eligibility_date"].strftime("%B %d, %Y")}.'
    )
    story.append(Paragraph(body_text, body))

    value = f'₱{m["award_value"]:,.2f}' if m['award_value'] else '—'
    details = [
        ['Award Type', m['award_type'] or '—'],
        ['Award Value', value],
        ['Department', m['department_name'] or '—'],
        ['Date Hired', m['date_hired'].strftime('%B %d, %Y') if m['date_hired'] else '—'],
        ['Years of Service', f'{service_yrs} years'],
    ]
    story.append(_kv_table(details))
    story.append(Spacer(1, 14))
    story.append(Paragraph(
        'Your dedication and commitment exemplify the values of public service. '
        'On behalf of the entire organization, we extend our heartfelt gratitude.',
        body))
    story.append(Spacer(1, 40))
    story.append(_sig_block())

    doc.build(story)

    # Update milestone record
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE rewards.rwd_loyalty_milestones
            SET memo_no = %s,
                memo_generated_at = NOW(),
                memo_by = %s,
                notified_at = NOW()
            WHERE id = %s
        """, (memo_no, user_id, milestone_id))

    return buf.getvalue()


def loyalty_mark_awarded(milestone_id: int, user_id: int):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE rewards.rwd_loyalty_milestones
            SET status = 'AWARDED',
                awarded_at = NOW(),
                awarded_by = %s
            WHERE id = %s AND status = 'ELIGIBLE'
            RETURNING id
        """, (user_id, milestone_id))
        return cur.fetchone()


# ══════════════════════════════════════════════════════════════════════
# G16 · SALN
# ══════════════════════════════════════════════════════════════════════
def saln_get_settings(company_id: int):
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM dms.saln_settings WHERE company_id = %s
        """, (company_id,))
        return dict(cur.fetchone() or {'company_id': company_id,
                                       'mode': 'SIMPLE_FORM',
                                       'filing_month': 4,
                                       'reminder_days': 30})


def saln_save_settings(company_id: int, settings: dict, user_id: int):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO dms.saln_settings (company_id, mode, filing_month, reminder_days, updated_by, updated_at)
            VALUES (%s, %s, %s, %s, %s, NOW())
            ON CONFLICT (company_id) DO UPDATE SET
                mode = EXCLUDED.mode,
                filing_month = EXCLUDED.filing_month,
                reminder_days = EXCLUDED.reminder_days,
                updated_by = EXCLUDED.updated_by,
                updated_at = NOW()
        """, (company_id, settings.get('mode', 'SIMPLE_FORM'),
              int(settings.get('filing_month', 4) or 4),
              int(settings.get('reminder_days', 30) or 30),
              user_id))


def saln_get_current(employee_id: int, year: int = None):
    year = year or Date.today().year
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM dms.saln_filings
            WHERE employee_id = %s AND filing_year = %s
            ORDER BY updated_at DESC LIMIT 1
        """, (employee_id, year))
        return cur.fetchone()


def saln_upsert(employee_id: int, year: int, mode: str, data: dict,
                submit: bool = False):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO dms.saln_filings
                (employee_id, filing_year, mode, data, status, filed_at)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (employee_id, filing_year) DO UPDATE SET
                mode = EXCLUDED.mode,
                data = EXCLUDED.data,
                status = CASE WHEN %s THEN 'SUBMITTED' ELSE dms.saln_filings.status END,
                filed_at = CASE WHEN %s THEN NOW() ELSE dms.saln_filings.filed_at END,
                updated_at = NOW()
            RETURNING id
        """, (employee_id, year, mode, json.dumps(data),
              'SUBMITTED' if submit else 'DRAFT',
              Date.today() if submit else None,
              submit, submit))
        return cur.fetchone()['id']


def saln_list(company_id: int, status: str = None, year: int = None):
    with get_cursor() as cur:
        sql = """
            SELECT f.id, f.employee_id, f.filing_year, f.mode, f.status,
                   f.filed_at, f.verified_at, f.updated_at,
                   e.employee_no,
                   CONCAT_WS(' ', e.first_name, e.last_name) AS full_name,
                   d.name AS department_name
            FROM dms.saln_filings f
            JOIN core.employees e ON e.id = f.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            WHERE e.company_id = %s
        """
        params = [company_id]
        if status:
            sql += ' AND f.status = %s'
            params.append(status)
        if year:
            sql += ' AND f.filing_year = %s'
            params.append(year)
        sql += ' ORDER BY f.filing_year DESC, f.updated_at DESC LIMIT 300'
        cur.execute(sql, tuple(params))
        return cur.fetchall()


def saln_verify(filing_id: int, user_id: int):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE dms.saln_filings
            SET status = 'VERIFIED', verified_by = %s, verified_at = NOW(),
                updated_at = NOW()
            WHERE id = %s AND status = 'SUBMITTED'
            RETURNING id
        """, (user_id, filing_id))
        return cur.fetchone()


def saln_render_pdf(filing_id: int) -> bytes:
    with get_cursor() as cur:
        cur.execute("""
            SELECT f.*, e.employee_no,
                   CONCAT_WS(' ', e.first_name, e.middle_name, e.last_name) AS full_name,
                   e.date_of_birth, e.civil_status, e.gender,
                   d.name AS department_name,
                   p.title AS position_title,
                   c.name AS company_name
            FROM dms.saln_filings f
            JOIN core.employees e ON e.id = f.employee_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.positions p   ON p.id = e.position_id
            JOIN core.companies c ON c.id = e.company_id
            WHERE f.id = %s
        """, (filing_id,))
        f = cur.fetchone()
    if not f:
        raise ValueError('Filing not found')

    data = f['data'] if isinstance(f['data'], dict) else json.loads(f['data'] or '{}')
    mode = f['mode']

    buf = io.BytesIO()
    doc = _doc(buf, f'SALN {f["filing_year"]} - {f["full_name"]}')
    styles = getSampleStyleSheet()
    body = ParagraphStyle('b', fontName='Helvetica', fontSize=10,
                          leading=13, textColor=DARK, spaceAfter=6)
    sec = ParagraphStyle('sec', fontName='Helvetica-Bold', fontSize=11,
                         textColor=BRAND, spaceBefore=10, spaceAfter=6,
                         backColor=LIGHT, leftIndent=6, borderPadding=4)
    story = []
    story.extend(_header('SWORN STATEMENT OF ASSETS, LIABILITIES AND NET WORTH',
                          f'Filing Year {f["filing_year"]} · {f["company_name"]}'))
    story.append(Spacer(1, 8))

    story.append(Paragraph('I. DECLARANT INFORMATION', sec))
    story.append(_kv_table([
        ['Full Name', f['full_name']],
        ['Employee No.', f['employee_no']],
        ['Position', f['position_title'] or '—'],
        ['Department', f['department_name'] or '—'],
        ['Filing Year', str(f['filing_year'])],
        ['Mode', mode],
    ]))

    if mode == 'UPLOAD_ONLY':
        story.append(Spacer(1, 12))
        story.append(Paragraph(
            f'This SALN was filed under <b>UPLOAD_ONLY</b> mode. '
            f'The original document {"is attached" if f["uploaded_doc_id"] else "is pending upload"}.',
            body))
    else:
        # Simple or Full — both use JSON data
        story.append(Paragraph('II. ASSETS (TOTAL)', sec))
        story.append(_kv_table([
            ['Real Property', f'₱{float(data.get("real_property", 0)):,.2f}'],
            ['Personal Property', f'₱{float(data.get("personal_property", 0)):,.2f}'],
            ['Cash on Hand / In Bank', f'₱{float(data.get("cash", 0)):,.2f}'],
            ['Investments & Securities', f'₱{float(data.get("investments", 0)):,.2f}'],
            ['Other Assets', f'₱{float(data.get("other_assets", 0)):,.2f}'],
            ['<b>TOTAL ASSETS</b>', f'<b>₱{float(data.get("total_assets", 0)):,.2f}</b>'],
        ]))

        story.append(Paragraph('III. LIABILITIES', sec))
        story.append(_kv_table([
            ['Loans (GSIS/SSS/Pag-IBIG)', f'₱{float(data.get("loans", 0)):,.2f}'],
            ['Other Liabilities', f'₱{float(data.get("other_liabilities", 0)):,.2f}'],
            ['<b>TOTAL LIABILITIES</b>', f'<b>₱{float(data.get("total_liabilities", 0)):,.2f}</b>'],
        ]))

        net = float(data.get('total_assets', 0)) - float(data.get('total_liabilities', 0))
        story.append(Paragraph('IV. NET WORTH', sec))
        story.append(_kv_table([
            ['Net Worth (Assets − Liabilities)', f'<b>₱{net:,.2f}</b>'],
            ['Net Worth Last Year', f'₱{float(data.get("prior_net_worth", 0)):,.2f}'],
        ]))

        story.append(Paragraph('V. SPOUSE & RELATIVES', sec))
        spouse = data.get('spouse') or {}
        story.append(_kv_table([
            ['Spouse Name', spouse.get('name', '—')],
            ['Spouse Occupation', spouse.get('occupation', '—')],
            ['Spouse Employer', spouse.get('employer', '—')],
            ['Relatives in Gov.', data.get('relatives_in_gov', '—')],
        ]))

        if mode == 'FULL_CSC_210':
            story.append(PageBreak())
            story.append(Paragraph('VI. BUSINESS INTERESTS & FINANCIAL CONNECTIONS', sec))
            bi = data.get('business_interests') or []
            if bi:
                for i, it in enumerate(bi, 1):
                    story.append(Paragraph(
                        f'{i}. <b>{it.get("name", "—")}</b> — {it.get("nature", "")} '
                        f'(since {it.get("since", "—")})', body))
            else:
                story.append(Paragraph('None declared.', body))

            story.append(Paragraph('VII. REAL PROPERTY DETAIL', sec))
            rp = data.get('real_property_detail') or []
            if rp:
                rows = [['#', 'Description', 'Location', 'Year Acquired', 'Assessed Value']]
                for i, it in enumerate(rp, 1):
                    rows.append([str(i), it.get('description', ''),
                                 it.get('location', ''),
                                 str(it.get('year_acquired', '')),
                                 f'₱{float(it.get("assessed_value", 0)):,.2f}'])
                t = Table(rows, colWidths=[0.4 * inch, 2.0 * inch, 1.8 * inch, 1.0 * inch, 1.4 * inch])
                t.setStyle(TableStyle([
                    ('BACKGROUND', (0, 0), (-1, 0), BRAND),
                    ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
                    ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                    ('FONTSIZE', (0, 0), (-1, -1), 8.5),
                    ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#E5E7EB')),
                    ('VALIGN', (0, 0), (-1, -1), 'TOP'),
                ]))
                story.append(t)
            else:
                story.append(Paragraph('None declared.', body))

    story.append(Spacer(1, 20))
    story.append(_sig_block())
    doc.build(story)
    return buf.getvalue()


# ══════════════════════════════════════════════════════════════════════
# G17 · Appointment PDF (CSC Form 33)
# ══════════════════════════════════════════════════════════════════════
def appointment_render_pdf(appointment_id: int) -> bytes:
    with get_cursor() as cur:
        cur.execute("""
            SELECT a.*, e.employee_no,
                   CONCAT_WS(' ', e.first_name, e.middle_name, e.last_name) AS full_name,
                   e.date_of_birth, e.gender, e.civil_status,
                   p.title AS position_title,
                   d.name AS department_name,
                   c.name AS company_name
            FROM recruitment.rec_appointments a
            JOIN core.employees e   ON e.id = a.employee_id
            LEFT JOIN core.positions p ON p.id = a.position_id
            LEFT JOIN core.departments d ON d.id = e.department_id
            JOIN core.companies c   ON c.id = e.company_id
            WHERE a.id = %s
        """, (appointment_id,))
        a = cur.fetchone()
    if not a:
        raise ValueError('Appointment not found')

    buf = io.BytesIO()
    doc = _doc(buf, f'Appointment {a["appointment_no"]}')
    styles = getSampleStyleSheet()
    body = ParagraphStyle('b', fontName='Helvetica', fontSize=10.5,
                          leading=14, textColor=DARK, spaceAfter=8)
    sec = ParagraphStyle('sec', fontName='Helvetica-Bold', fontSize=11,
                         textColor=BRAND, spaceBefore=10, spaceAfter=6,
                         backColor=LIGHT, leftIndent=6, borderPadding=4)
    story = []
    story.extend(_header(a['company_name'] or 'Civil Service Commission',
                          'APPOINTMENT  (CSC Form No. 33-B, Revised 2018)'))
    story.append(Spacer(1, 6))

    story.append(Paragraph(
        f'<b>Appointment No.</b> {a["appointment_no"]} &nbsp;&nbsp;&nbsp;'
        f'<b>Type</b> {a["appointment_type"]}', body))

    story.append(Paragraph('DETAILS', sec))
    story.append(_kv_table([
        ['Employee', a['full_name']],
        ['Employee No.', a['employee_no']],
        ['Position', a['position_title'] or '—'],
        ['Department', a['department_name'] or '—'],
        ['Salary Grade', str(a['salary_grade'])],
        ['Step', str(a['step_no'])],
        ['Monthly Salary', f'₱{float(a["monthly_salary"]):,.2f}'],
        ['Effective Date', a['effective_date'].strftime('%B %d, %Y')],
        ['End Date', a['end_date'].strftime('%B %d, %Y') if a['end_date'] else '—'],
        ['Status', a['status']],
    ]))

    if a.get('remarks'):
        story.append(Paragraph('REMARKS', sec))
        story.append(Paragraph(a['remarks'], body))

    story.append(Paragraph('CSC ATTESTATION', sec))
    story.append(_kv_table([
        ['Attested At',
         a['csc_attested_at'].strftime('%B %d, %Y') if a['csc_attested_at'] else '— (pending)'],
    ]))

    story.append(Spacer(1, 30))
    story.append(_sig_block())
    doc.build(story)
    return buf.getvalue()
