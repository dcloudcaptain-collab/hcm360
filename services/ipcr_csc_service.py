"""
IPCR / OPCR — CSC compliant.

Provides:
  * Template library access (list_templates / get_template)
  * One-click spawn — instantiate a complete IPCR for an employee
    by copying a template's item list into performance.perf_ipcr
  * Adjectival-rating helper
  * CSC-format IPCR + OPCR PDF generators (ReportLab)

Reuses the helper pattern from services/lgu_g11_g16_g17_service.py.
"""
import io
from datetime import date, datetime

from reportlab.lib.pagesizes import LETTER, landscape
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch, mm
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer,
                                Table, TableStyle, PageBreak, KeepTogether)

from services.db import get_cursor


# ── Adjectival rating per CSC scale ─────────────────────────────────
def adjectival_rating(score):
    if score is None:
        return 'Not Rated'
    s = float(score)
    if s >= 4.5:
        return 'Outstanding'
    if s >= 3.5:
        return 'Very Satisfactory'
    if s >= 2.5:
        return 'Satisfactory'
    if s >= 1.5:
        return 'Unsatisfactory'
    return 'Poor'


# ── Template library ────────────────────────────────────────────────
def list_templates():
    with get_cursor() as cur:
        cur.execute("""
            SELECT id, code, title, description, target_position,
                   department_hint, items, is_active, sort_order,
                   jsonb_array_length(items) AS item_count
              FROM performance.perf_ipcr_templates
             WHERE is_active = TRUE
             ORDER BY sort_order, title
        """)
        return cur.fetchall()


def get_template(code):
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM performance.perf_ipcr_templates
             WHERE code = %s AND is_active = TRUE
        """, (code,))
        return cur.fetchone()


def spawn_from_template(template_code, employee_id, cycle_id,
                        evaluator_id=None, period_start=None, period_end=None,
                        replace_existing=False):
    """Instantiate every item in the template as a perf_ipcr row.

    If `replace_existing` is True, deletes existing rows for this
    (employee_id, cycle_id) first. Returns the count inserted.
    """
    tpl = get_template(template_code)
    if not tpl:
        return 0
    items = tpl['items'] or []
    if not items:
        return 0

    with get_cursor(commit=True) as cur:
        if replace_existing:
            cur.execute("""
                DELETE FROM performance.perf_ipcr
                 WHERE employee_id = %s AND cycle_id = %s
            """, (employee_id, cycle_id))
        for item in items:
            cur.execute("""
                INSERT INTO performance.perf_ipcr
                    (employee_id, cycle_id, function_type,
                     performance_indicator, target, target_value, weight,
                     means_of_verification, evaluator_id,
                     period_start, period_end, status)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'DRAFT')
            """, (
                employee_id, cycle_id,
                item.get('function_type', 'CORE'),
                item.get('performance_indicator'),
                item.get('target'),
                item.get('target_value'),
                item.get('weight') or 1.0,
                item.get('means_of_verification'),
                evaluator_id,  # already an employee_id (resolved by caller)
                period_start, period_end,
            ))
    return len(items)


# ══════════════════════════════════════════════════════════════════
# CSC IPCR PDF
# ══════════════════════════════════════════════════════════════════
BRAND = colors.HexColor('#1E40AF')
GRAY  = colors.HexColor('#6B7280')
DARK  = colors.HexColor('#111827')
LIGHT = colors.HexColor('#F3F4F6')


def _doc(out, title, page=LETTER):
    return SimpleDocTemplate(out, pagesize=page,
                             leftMargin=15 * mm, rightMargin=15 * mm,
                             topMargin=15 * mm, bottomMargin=15 * mm,
                             title=title, author='HCM360')


def _header_block(title, subtitle, period_label):
    title_s = ParagraphStyle('t', fontName='Helvetica-Bold', fontSize=12,
                             alignment=TA_CENTER, textColor=DARK, leading=15)
    sub_s   = ParagraphStyle('s', fontName='Helvetica', fontSize=9,
                             alignment=TA_CENTER, textColor=GRAY,
                             leading=11, spaceAfter=4)
    period_s = ParagraphStyle('p', fontName='Helvetica-Oblique', fontSize=9,
                              alignment=TA_CENTER, textColor=DARK, spaceAfter=8)
    return [
        Paragraph(title, title_s),
        Paragraph(subtitle, sub_s),
        Paragraph(period_label, period_s),
    ]


def _kv_table(rows, col1_w=1.3 * inch, col2_w=2.4 * inch):
    t = Table(rows, colWidths=[col1_w, col2_w, col1_w, col2_w])
    t.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTNAME', (2, 0), (2, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 8.5),
        ('TEXTCOLOR', (0, 0), (0, -1), GRAY),
        ('TEXTCOLOR', (2, 0), (2, -1), GRAY),
        ('TEXTCOLOR', (1, 0), (1, -1), DARK),
        ('TEXTCOLOR', (3, 0), (3, -1), DARK),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
        ('TOPPADDING', (0, 0), (-1, -1), 2),
    ]))
    return t


def _ipcr_items_table(rows):
    """The big MFO grid — Function | Indicator | Target | Wt | Q | E | T | Avg
    """
    p = ParagraphStyle('cell', fontName='Helvetica', fontSize=8,
                       textColor=DARK, leading=10)
    p_b = ParagraphStyle('cellb', fontName='Helvetica-Bold', fontSize=8,
                         textColor=DARK, leading=10, alignment=TA_CENTER)
    p_c = ParagraphStyle('cellc', fontName='Helvetica', fontSize=8,
                         textColor=DARK, leading=10, alignment=TA_CENTER)

    headers = [
        Paragraph('Type', p_b),
        Paragraph('Performance Indicator / Major Final Output', p_b),
        Paragraph('Target', p_b),
        Paragraph('Wt', p_b),
        Paragraph('Q', p_b),
        Paragraph('E', p_b),
        Paragraph('T', p_b),
        Paragraph('Avg', p_b),
    ]
    data = [headers]
    weighted_sum = 0.0
    weight_total = 0.0
    for r in rows:
        wt = float(r.get('weight') or 0)
        avg = r.get('average_rating')
        avg_f = float(avg) if avg is not None else None
        if avg_f is not None and wt > 0:
            weighted_sum += avg_f * wt
            weight_total += wt
        data.append([
            Paragraph(r.get('function_type') or 'CORE', p_c),
            Paragraph((r.get('performance_indicator') or '—'), p),
            Paragraph((r.get('target') or '—'), p),
            Paragraph(f'{wt:.2f}', p_c),
            Paragraph(_fmt_score(r.get('quality_rating')), p_c),
            Paragraph(_fmt_score(r.get('efficiency_rating')), p_c),
            Paragraph(_fmt_score(r.get('timeliness_rating')), p_c),
            Paragraph(f'{avg_f:.2f}' if avg_f is not None else '—', p_c),
        ])

    # Footer row — weighted average
    final_score = (weighted_sum / weight_total) if weight_total > 0 else None
    foot_style = ParagraphStyle('foot', fontName='Helvetica-Bold', fontSize=9,
                                textColor=DARK, alignment=TA_CENTER)
    data.append([
        Paragraph('FINAL', foot_style),
        Paragraph(
            'Weighted Average Rating &nbsp;&mdash;&nbsp; ' +
            (adjectival_rating(final_score) if final_score is not None else 'Not Rated'),
            ParagraphStyle('foot2', fontName='Helvetica-Bold', fontSize=9,
                           textColor=BRAND, alignment=TA_LEFT)),
        '', '', '', '', '',
        Paragraph(f'{final_score:.2f}' if final_score is not None else '—', foot_style),
    ])

    t = Table(data, colWidths=[
        0.55 * inch, 3.0 * inch, 1.7 * inch,
        0.40 * inch, 0.30 * inch, 0.30 * inch, 0.30 * inch, 0.45 * inch,
    ], repeatRows=1)
    t.setStyle(TableStyle([
        ('GRID', (0, 0), (-1, -1), 0.4, GRAY),
        ('BACKGROUND', (0, 0), (-1, 0), LIGHT),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 4),
        ('RIGHTPADDING', (0, 0), (-1, -1), 4),
        ('TOPPADDING', (0, 0), (-1, -1), 3),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
        ('BACKGROUND', (0, -1), (-1, -1), colors.HexColor('#FEF3C7')),
        ('SPAN', (1, -1), (6, -1)),
    ]))
    return t, final_score


def _fmt_score(v):
    if v is None:
        return '—'
    try:
        return f'{float(v):.1f}'
    except Exception:
        return '—'


def _sig_block(rater_name, ratee_name, approver_name):
    s_label = ParagraphStyle('lbl', fontName='Helvetica', fontSize=8,
                             alignment=TA_CENTER, textColor=GRAY)
    s_name  = ParagraphStyle('nm', fontName='Helvetica-Bold', fontSize=9,
                             alignment=TA_CENTER, textColor=DARK)
    s_sub   = ParagraphStyle('sub', fontName='Helvetica', fontSize=8,
                             alignment=TA_CENTER, textColor=GRAY,
                             leading=10)

    block = Table([
        [Paragraph(' ', s_label),
         Paragraph(' ', s_label),
         Paragraph(' ', s_label)],
        [Paragraph('_____________________', s_label),
         Paragraph('_____________________', s_label),
         Paragraph('_____________________', s_label)],
        [Paragraph(ratee_name or '(Ratee)', s_name),
         Paragraph(rater_name or '(Rater)', s_name),
         Paragraph(approver_name or '(Approving Authority)', s_name)],
        [Paragraph('Ratee — Signature & Date', s_sub),
         Paragraph('Rater — Signature & Date', s_sub),
         Paragraph('Head of Office / Approving Authority', s_sub)],
    ], colWidths=[2.4 * inch, 2.4 * inch, 2.5 * inch])
    block.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
    ]))
    return block


def render_ipcr_pdf(employee_id, cycle_id):
    """Generate a CSC-format IPCR PDF for a single employee + cycle.
    Returns (filename, BytesIO)."""
    with get_cursor() as cur:
        # Employee + position + dept
        cur.execute("""
            SELECT e.id, e.employee_no,
                   TRIM(COALESCE(e.first_name,'') || ' ' || COALESCE(e.middle_name,'') || ' ' || COALESCE(e.last_name,'')) AS full_name,
                   e.first_name, e.last_name,
                   p.title  AS position_title,
                   d.name   AS department_name,
                   sup.first_name || ' ' || sup.last_name AS supervisor_name,
                   sup_p.title AS supervisor_position
              FROM core.employees e
              LEFT JOIN core.positions p   ON p.id = e.position_id
              LEFT JOIN core.departments d ON d.id = e.department_id
              LEFT JOIN core.employees sup ON sup.id = e.immediate_supervisor_id
              LEFT JOIN core.positions sup_p ON sup_p.id = sup.position_id
             WHERE e.id = %s
        """, (employee_id,))
        emp = cur.fetchone()

        cur.execute("""
            SELECT c.*, comp.name AS company_name
              FROM performance.perf_cycles c
              LEFT JOIN core.companies comp ON comp.id = c.company_id
             WHERE c.id = %s
        """, (cycle_id,))
        cyc = cur.fetchone()

        cur.execute("""
            SELECT * FROM performance.perf_ipcr
             WHERE employee_id = %s AND cycle_id = %s
             ORDER BY function_type, id
        """, (employee_id, cycle_id))
        items = cur.fetchall()

        cur.execute("""
            SELECT * FROM performance.perf_ipcr_summary
             WHERE employee_id = %s AND cycle_id = %s
             ORDER BY id DESC LIMIT 1
        """, (employee_id, cycle_id))
        summ = cur.fetchone()

    out = io.BytesIO()
    company = (cyc and cyc['company_name']) or 'Municipality of Mariveles'
    period_label = (
        f"Rating Period: {cyc['period_from'].strftime('%b %d, %Y')} – "
        f"{cyc['period_to'].strftime('%b %d, %Y')}"
        if cyc else 'Rating Period: —'
    )

    doc = _doc(out,
               title=f"IPCR — {emp['full_name'] if emp else ''}",
               page=LETTER)
    story = []
    story += _header_block(
        'INDIVIDUAL PERFORMANCE COMMITMENT AND REVIEW (IPCR)',
        f'{company}',
        period_label,
    )

    # Identification block (4 columns: label/value/label/value)
    if emp:
        ident = [
            ['Name:', emp['full_name'] or '—',
             'Employee No:', emp['employee_no'] or '—'],
            ['Position:', emp['position_title'] or '—',
             'Office / Department:', emp['department_name'] or '—'],
            ['Rater:', emp['supervisor_name'] or '—',
             "Rater's Position:", emp['supervisor_position'] or '—'],
            ['Cycle:', (cyc['name'] if cyc else '—'),
             'Cycle Type:', (cyc['cycle_type'] if cyc else '—')],
        ]
        story.append(_kv_table(ident))
        story.append(Spacer(1, 6))

    # MFO items table
    items_t, final_score = _ipcr_items_table(items or [])
    story.append(items_t)
    story.append(Spacer(1, 8))

    # Comments block
    comm_p = ParagraphStyle('cm', fontName='Helvetica', fontSize=8.5,
                            textColor=DARK, leading=11)
    comm_h = ParagraphStyle('cmh', fontName='Helvetica-Bold', fontSize=8.5,
                            textColor=GRAY, leading=11)
    if summ:
        story.append(Paragraph("RATER'S COMMENTS:", comm_h))
        story.append(Paragraph(summ['evaluator_comments'] or '<i>—</i>', comm_p))
        story.append(Spacer(1, 4))
        story.append(Paragraph("RATEE'S COMMENTS:", comm_h))
        story.append(Paragraph(summ['employee_comments'] or '<i>—</i>', comm_p))
        story.append(Spacer(1, 4))
        if summ.get('recommendations'):
            story.append(Paragraph("RECOMMENDATIONS:", comm_h))
            story.append(Paragraph(summ['recommendations'], comm_p))
            story.append(Spacer(1, 4))

    # Signature block
    story.append(Spacer(1, 14))
    story.append(_sig_block(
        emp['supervisor_name'] if emp else None,
        emp['full_name'] if emp else None,
        None,
    ))

    # Adjectival scale legend
    story.append(Spacer(1, 10))
    legend_style = ParagraphStyle('lg', fontName='Helvetica-Oblique', fontSize=7.5,
                                  textColor=GRAY, alignment=TA_CENTER, leading=9)
    story.append(Paragraph(
        '<b>CSC Adjectival Rating Scale:</b>&nbsp;&nbsp; '
        'Outstanding (4.50 – 5.00) &nbsp;·&nbsp; Very Satisfactory (3.50 – 4.49) &nbsp;·&nbsp; '
        'Satisfactory (2.50 – 3.49) &nbsp;·&nbsp; Unsatisfactory (1.50 – 2.49) &nbsp;·&nbsp; Poor (below 1.50)',
        legend_style,
    ))

    doc.build(story)
    out.seek(0)
    fname = (
        f'IPCR_{(emp["last_name"] or "Employee").replace(" ", "")}_'
        f'{(emp["first_name"] or "").replace(" ", "")}_'
        f'cycle{cycle_id}.pdf'
        if emp else f'IPCR_cycle{cycle_id}.pdf'
    )
    return fname, out


# ══════════════════════════════════════════════════════════════════
# CSC OPCR PDF
# ══════════════════════════════════════════════════════════════════
def render_opcr_pdf(department_id, cycle_id):
    """CSC-format OPCR PDF for a department + cycle."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT d.id, d.name AS department_name, comp.name AS company_name,
                   h.first_name || ' ' || h.last_name AS head_name,
                   hp.title AS head_position
              FROM core.departments d
              LEFT JOIN core.companies comp ON comp.id = d.company_id
              LEFT JOIN core.employees h    ON h.id = d.head_employee_id
              LEFT JOIN core.positions hp   ON hp.id = h.position_id
             WHERE d.id = %s
        """, (department_id,))
        dept = cur.fetchone()

        cur.execute("""
            SELECT * FROM performance.perf_cycles WHERE id = %s
        """, (cycle_id,))
        cyc = cur.fetchone()

        cur.execute("""
            SELECT * FROM performance.perf_opcr
             WHERE department_id = %s AND cycle_id = %s
             ORDER BY mfo_code, id
        """, (department_id, cycle_id))
        items = cur.fetchall()

    out = io.BytesIO()
    company = (dept and dept['company_name']) or 'Municipality of Mariveles'
    period_label = (
        f"Rating Period: {cyc['period_from'].strftime('%b %d, %Y')} – "
        f"{cyc['period_to'].strftime('%b %d, %Y')}"
        if cyc else 'Rating Period: —'
    )

    doc = _doc(out,
               title=f"OPCR — {dept['department_name'] if dept else ''}",
               page=landscape(LETTER))
    story = []
    story += _header_block(
        'OFFICE PERFORMANCE COMMITMENT AND REVIEW (OPCR)',
        f'{company}',
        period_label,
    )

    if dept:
        ident = [
            ['Office / Department:', dept['department_name'] or '—',
             'Office Head:', dept['head_name'] or '—'],
            ['Cycle:', (cyc['name'] if cyc else '—'),
             "Head's Position:", dept['head_position'] or '—'],
        ]
        story.append(_kv_table(ident, col1_w=1.5 * inch, col2_w=3.5 * inch))
        story.append(Spacer(1, 6))

    # Items table — wider in landscape
    p = ParagraphStyle('cell', fontName='Helvetica', fontSize=8,
                       textColor=DARK, leading=10)
    p_b = ParagraphStyle('cellb', fontName='Helvetica-Bold', fontSize=8,
                         textColor=DARK, leading=10, alignment=TA_CENTER)
    p_c = ParagraphStyle('cellc', fontName='Helvetica', fontSize=8,
                         textColor=DARK, leading=10, alignment=TA_CENTER)
    headers = [
        Paragraph('MFO', p_b),
        Paragraph('Performance Indicator', p_b),
        Paragraph('Target', p_b),
        Paragraph('Wt', p_b),
        Paragraph('Self', p_b),
        Paragraph('Validated', p_b),
        Paragraph('Adjectival', p_b),
        Paragraph('Responsible Office', p_b),
    ]
    data = [headers]
    wsum = 0.0
    wtot = 0.0
    for r in items or []:
        wt = float(r.get('weight') or 0)
        v = r.get('validated_rating')
        if v is not None and wt > 0:
            wsum += float(v) * wt
            wtot += wt
        data.append([
            Paragraph(r.get('mfo_code') or '—', p_c),
            Paragraph(r.get('performance_indicator') or '—', p),
            Paragraph(r.get('target') or '—', p),
            Paragraph(f'{wt:.2f}', p_c),
            Paragraph(_fmt_score(r.get('self_rating')), p_c),
            Paragraph(_fmt_score(r.get('validated_rating')), p_c),
            Paragraph(r.get('adjectival_rating') or '—', p_c),
            Paragraph(r.get('responsible_office') or '—', p),
        ])
    final = (wsum / wtot) if wtot > 0 else None
    foot_style = ParagraphStyle('foot', fontName='Helvetica-Bold', fontSize=9,
                                textColor=DARK, alignment=TA_CENTER)
    data.append([
        Paragraph('FINAL', foot_style),
        Paragraph(
            'Weighted Average Rating &nbsp;&mdash;&nbsp; ' +
            (adjectival_rating(final) if final is not None else 'Not Rated'),
            ParagraphStyle('foot2', fontName='Helvetica-Bold', fontSize=9,
                           textColor=BRAND, alignment=TA_LEFT)),
        '', '', '', '',
        Paragraph(f'{final:.2f}' if final is not None else '—', foot_style),
        '',
    ])
    t = Table(data, colWidths=[
        0.7 * inch, 2.6 * inch, 2.0 * inch,
        0.4 * inch, 0.55 * inch, 0.75 * inch, 1.05 * inch, 1.25 * inch,
    ], repeatRows=1)
    t.setStyle(TableStyle([
        ('GRID', (0, 0), (-1, -1), 0.4, GRAY),
        ('BACKGROUND', (0, 0), (-1, 0), LIGHT),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 4),
        ('RIGHTPADDING', (0, 0), (-1, -1), 4),
        ('TOPPADDING', (0, 0), (-1, -1), 3),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
        ('BACKGROUND', (0, -1), (-1, -1), colors.HexColor('#FEF3C7')),
        ('SPAN', (1, -1), (5, -1)),
    ]))
    story.append(t)
    story.append(Spacer(1, 14))
    story.append(_sig_block(
        dept['head_name'] if dept else None,
        '(Office Designate)',
        '(Approving Authority)',
    ))

    doc.build(story)
    out.seek(0)
    fname = (
        f'OPCR_{(dept["department_name"] or "Office").replace(" ", "_")}_'
        f'cycle{cycle_id}.pdf' if dept else f'OPCR_cycle{cycle_id}.pdf'
    )
    return fname, out
