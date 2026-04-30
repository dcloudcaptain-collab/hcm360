from flask import Blueprint, abort, redirect, render_template, request, url_for, g
from services.access_service import can_access_feature
from services.workflow_service import execute_action, get_instance_detail, get_instances, get_workflow_detail, get_workflows, toggle_checklist

bp = Blueprint('workflow', __name__, url_prefix='/workflow')


@bp.route('/', strict_slashes=False)
def workflows():
    """Renders at both /workflow and /workflow/."""
    return render_template('workflow/list.html', workflows=get_workflows(), instances=get_instances())


@bp.route('/<int:workflow_id>')
def detail(workflow_id):
    workflow, steps, routes = get_workflow_detail(workflow_id)
    return render_template('workflow/detail.html', workflow=workflow, steps=steps, routes=routes)


@bp.route('/instance/<int:instance_id>')
def instance(instance_id):
    instance, checklist, routes, logs = get_instance_detail(instance_id)
    if not instance:
        abort(404)
    return render_template('workflow/instance.html', instance=instance, checklist=checklist, routes=routes, logs=logs)


@bp.route('/instance/<int:instance_id>/action', methods=['POST'])
def action(instance_id):
    if not can_access_feature(g.current_user['role_code'], 'BTN_WORKFLOW_ACTION'):
        abort(403)
    execute_action(instance_id, request.form['action_code'])
    return redirect(url_for('workflow.instance', instance_id=instance_id))


@bp.route('/checklist/<int:item_id>/toggle', methods=['POST'])
def toggle(item_id):
    if not can_access_feature(g.current_user['role_code'], 'BTN_CHECKLIST_TOGGLE'):
        abort(403)
    instance_id = toggle_checklist(item_id, g.current_user['id'])
    return redirect(url_for('workflow.instance', instance_id=instance_id))
