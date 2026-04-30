"""Certifications Blueprint."""
from flask import Blueprint, render_template, request, redirect, url_for, flash, session

from modules.certifications import cert_service as svc

certifications_bp = Blueprint('certifications', __name__,
                              url_prefix='/certifications',
                              template_folder='../../templates/certifications')


@certifications_bp.route('/')
def index():
    stats = svc.get_compliance_dashboard()
    expiring = svc.get_expiring_soon(days=90)
    return render_template('certifications/index.html',
                           stats=stats, expiring=expiring)


@certifications_bp.route('/add', methods=['POST'])
def add():
    svc.add_certification(
        employee_id=request.form.get('employee_id', type=int),
        cert_name=request.form.get('cert_name', ''),
        cert_type=request.form.get('cert_type', ''),
        issuing_body=request.form.get('issuing_body', ''),
        cert_number=request.form.get('cert_number', ''),
        issued_date=request.form.get('issued_date'),
        expiry_date=request.form.get('expiry_date'),
        is_required=request.form.get('is_required') == 'on',
        document_path=request.form.get('document_path'),
    )
    flash('Certification added.', 'success')
    return redirect(url_for('certifications.index'))


@certifications_bp.route('/employee/<int:employee_id>')
def employee_certs(employee_id):
    certs = svc.get_employee_certs(employee_id)
    return render_template('certifications/employee.html',
                           certs=certs, employee_id=employee_id)


@certifications_bp.route('/<int:cert_id>/renew', methods=['POST'])
def renew(cert_id):
    new_expiry = request.form.get('new_expiry_date')
    if new_expiry:
        svc.renew_certification(cert_id, new_expiry)
        flash('Certification renewed.', 'success')
    else:
        flash('Please provide a new expiry date.', 'error')
    return redirect(request.referrer or url_for('certifications.index'))


@certifications_bp.route('/compliance')
def compliance():
    required_types, rows = svc.get_required_vs_completed()
    return render_template('certifications/compliance.html',
                           required_types=required_types, rows=rows)
