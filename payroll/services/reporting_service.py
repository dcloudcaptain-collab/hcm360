"""Reporting service — CSV, XLSX, PDF exports."""
import csv
import io
from datetime import date


def to_csv(rows, columns=None):
    """Export rows (list of dicts) to CSV bytes."""
    output = io.StringIO()
    if not rows:
        return b''

    if columns:
        headers = [c[1] for c in columns]
        keys = [c[0] for c in columns]
    else:
        keys = list(rows[0].keys())
        headers = keys

    writer = csv.writer(output)
    writer.writerow(headers)
    for row in rows:
        writer.writerow([row.get(k, '') for k in keys])

    return output.getvalue().encode('utf-8-sig')


def to_xlsx(rows, sheet_name='Sheet1', columns=None, title=None):
    """Export rows to XLSX bytes using openpyxl."""
    try:
        from openpyxl import Workbook
        from openpyxl.styles import Font, Alignment, Border, Side, PatternFill
    except ImportError:
        # Fallback to CSV if openpyxl not installed
        return to_csv(rows, columns)

    wb = Workbook()
    ws = wb.active
    ws.title = sheet_name

    if columns:
        headers = [c[1] for c in columns]
        keys = [c[0] for c in columns]
    elif rows:
        keys = list(rows[0].keys())
        headers = keys
    else:
        return b''

    start_row = 1

    # Title row
    if title:
        ws.cell(row=1, column=1, value=title)
        ws.cell(row=1, column=1).font = Font(bold=True, size=14)
        ws.cell(row=2, column=1, value=f'Generated: {date.today().isoformat()}')
        ws.cell(row=2, column=1).font = Font(size=9, color='808080')
        start_row = 4

    # Header row
    header_fill = PatternFill(start_color='4F46E5', end_color='4F46E5', fill_type='solid')
    header_font = Font(bold=True, color='FFFFFF', size=10)
    thin_border = Border(
        bottom=Side(style='thin', color='D1D5DB')
    )

    for col_idx, header in enumerate(headers, 1):
        cell = ws.cell(row=start_row, column=col_idx, value=header)
        cell.font = header_font
        cell.fill = header_fill
        cell.alignment = Alignment(horizontal='center')

    # Data rows
    for row_idx, row in enumerate(rows, start_row + 1):
        for col_idx, key in enumerate(keys, 1):
            val = row.get(key, '')
            cell = ws.cell(row=row_idx, column=col_idx, value=val)
            cell.border = thin_border

            # Right-align numeric columns
            if isinstance(val, (int, float)):
                cell.alignment = Alignment(horizontal='right')
                cell.number_format = '#,##0.00'

    # Auto-width columns
    for col_idx, key in enumerate(keys, 1):
        max_len = len(headers[col_idx - 1])
        for row in rows[:50]:  # Sample first 50 rows
            val = str(row.get(key, ''))
            if len(val) > max_len:
                max_len = len(val)
        ws.column_dimensions[chr(64 + col_idx) if col_idx <= 26 else 'A'].width = min(max_len + 4, 30)

    output = io.BytesIO()
    wb.save(output)
    return output.getvalue()


def render_payslip_pdf(employee_id, run_id):
    """Generate a simple PDF payslip. Falls back to empty bytes if reportlab unavailable."""
    try:
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.units import mm
        from reportlab.pdfgen import canvas as pdf_canvas
    except ImportError:
        return b'%PDF-1.4 reportlab not installed'

    from services.db import get_cursor

    with get_cursor() as cur:
        cur.execute("""
            SELECT ep.*, e.employee_no, e.full_name,
                   d.name AS department, p.title AS position_title,
                   pp.date_from AS cutoff_start, pp.date_to AS cutoff_end,
                   pp.payment_date, pp.period_type
            FROM payroll.pay_employee_payroll ep
            JOIN core.v_employees_full e ON e.id = ep.employee_id
            JOIN core.departments d ON d.id = e.department_id
            LEFT JOIN core.positions p ON p.id = e.position_id
            JOIN payroll.pay_runs pr ON pr.id = ep.run_id
            JOIN payroll.pay_periods pp ON pp.id = pr.period_id
            WHERE ep.employee_id = %s AND ep.run_id = %s
        """, (employee_id, run_id))
        detail = cur.fetchone()

    if not detail:
        return b''

    buf = io.BytesIO()
    c = pdf_canvas.Canvas(buf, pagesize=A4)
    w, h = A4
    y = h - 30 * mm

    # Header
    c.setFont('Helvetica-Bold', 16)
    c.drawString(20 * mm, y, 'PAYSLIP')
    y -= 8 * mm

    c.setFont('Helvetica', 9)
    c.drawString(20 * mm, y, f"{detail['cutoff_start']} to {detail['cutoff_end']} | {detail['period_type']}")
    y -= 12 * mm

    # Employee info
    c.setFont('Helvetica-Bold', 11)
    c.drawString(20 * mm, y, detail['full_name'])
    y -= 5 * mm
    c.setFont('Helvetica', 9)
    c.drawString(20 * mm, y, f"{detail['employee_no']} | {detail['department']}")
    if detail.get('position_title'):
        y -= 4 * mm
        c.drawString(20 * mm, y, detail['position_title'])
    y -= 10 * mm

    # Line
    c.setStrokeColorRGB(0.31, 0.27, 0.90)
    c.setLineWidth(1.5)
    c.line(20 * mm, y, w - 20 * mm, y)
    y -= 8 * mm

    def draw_row(label, value, bold=False):
        nonlocal y
        font = 'Helvetica-Bold' if bold else 'Helvetica'
        c.setFont(font, 9)
        c.drawString(20 * mm, y, label)
        c.drawRightString(w - 20 * mm, y, f'{value:,.2f}' if isinstance(value, (int, float)) else str(value))
        y -= 5 * mm

    # Earnings
    c.setFont('Helvetica-Bold', 10)
    c.drawString(20 * mm, y, 'EARNINGS')
    y -= 6 * mm

    draw_row('Basic Pay', float(detail.get('basic_pay', 0)))
    draw_row('OT Pay', float(detail.get('ot_pay', 0)))
    draw_row('Holiday Pay', float(detail.get('holiday_pay', 0)))
    draw_row('Night Diff Pay', float(detail.get('night_diff_pay', 0)))
    draw_row('Allowances', float(detail.get('allowances_total', 0)))
    draw_row('Gross Pay', float(detail.get('gross_pay', 0)), bold=True)
    y -= 5 * mm

    # Deductions
    c.setFont('Helvetica-Bold', 10)
    c.drawString(20 * mm, y, 'DEDUCTIONS')
    y -= 6 * mm

    if detail.get('sss_ee') and float(detail['sss_ee']) > 0:
        draw_row('SSS', float(detail['sss_ee']))
    if detail.get('gsis_ps') and float(detail.get('gsis_ps', 0)) > 0:
        draw_row('GSIS', float(detail['gsis_ps']))
    draw_row('PhilHealth', float(detail.get('philhealth_ee', 0)))
    draw_row('Pag-IBIG', float(detail.get('pagibig_ee', 0)))
    draw_row('Withholding Tax', float(detail.get('tax_withheld', 0)))
    draw_row('Loans', float(detail.get('loan_deductions', 0)))
    draw_row('Other', float(detail.get('other_deductions', 0)))
    draw_row('Total Deductions', float(detail.get('total_deductions', 0)), bold=True)
    y -= 8 * mm

    # Net pay
    c.setStrokeColorRGB(0.09, 0.40, 0.20)
    c.setLineWidth(2)
    c.line(20 * mm, y, w - 20 * mm, y)
    y -= 8 * mm
    c.setFont('Helvetica-Bold', 14)
    c.drawString(20 * mm, y, 'NET PAY')
    c.drawRightString(w - 20 * mm, y, f"PHP {float(detail.get('net_pay', 0)):,.2f}")

    c.save()
    return buf.getvalue()
