from services.db import get_cursor


def get_workflows():
    with get_cursor() as cur:
        cur.execute("""
            SELECT id, code, name, module, description, is_active
            FROM workflow.workflow_definitions
            ORDER BY module, name
        """)
        return cur.fetchall()


def get_workflow_detail(workflow_id):
    with get_cursor() as cur:
        cur.execute('SELECT * FROM workflow.workflow_definitions WHERE id=%s', (workflow_id,))
        workflow = cur.fetchone()
        cur.execute("""
            SELECT id, step_order, code, name, role_required, is_final, sla_hours
            FROM workflow.workflow_steps
            WHERE workflow_id=%s ORDER BY step_order
        """, (workflow_id,))
        steps = cur.fetchall()
        cur.execute("""
            SELECT r.id, fs.name AS from_step, r.action_code,
                   ts.name AS to_step, r.label
            FROM workflow.workflow_routes r
            JOIN workflow.workflow_steps fs ON fs.id = r.step_id
            LEFT JOIN workflow.workflow_steps ts ON ts.id = r.next_step_id
            WHERE fs.workflow_id=%s
            ORDER BY fs.step_order, r.id
        """, (workflow_id,))
        routes = cur.fetchall()
        return workflow, steps, routes


def get_instances(status=None):
    with get_cursor() as cur:
        query = """
            SELECT wi.id, wi.reference_no, wd.name AS workflow_name,
                   wd.module, wi.status, wi.entity_type, wi.entity_id,
                   ws.name AS current_step, wi.created_at,
                   u.display_name AS initiated_by_name,
                   EXTRACT(EPOCH FROM (NOW()-wi.created_at))/3600 AS hours_pending
            FROM workflow.workflow_instances wi
            JOIN workflow.workflow_definitions wd ON wd.id = wi.definition_id
            LEFT JOIN workflow.workflow_steps ws ON ws.id = wi.current_step_id
            LEFT JOIN core.users u ON u.id = wi.initiated_by
        """
        if status:
            cur.execute(query + ' WHERE wi.status=%s ORDER BY wi.created_at DESC', (status,))
        else:
            cur.execute(query + ' ORDER BY wi.created_at DESC')
        return cur.fetchall()


def get_instance_detail(instance_id):
    with get_cursor() as cur:
        cur.execute("""
            SELECT wi.*, wd.name AS workflow_name, wd.module,
                   ws.name AS step_name, ws.role_required,
                   u.display_name AS initiated_by_name
            FROM workflow.workflow_instances wi
            JOIN workflow.workflow_definitions wd ON wd.id = wi.definition_id
            LEFT JOIN workflow.workflow_steps ws ON ws.id = wi.current_step_id
            LEFT JOIN core.users u ON u.id = wi.initiated_by
            WHERE wi.id=%s
        """, (instance_id,))
        instance = cur.fetchone()
        if not instance:
            return None, [], [], []
        cur.execute("""
            SELECT ici.id, wc.name AS item_label, wc.is_gate,
                   wc.description, ici.is_completed, wc.sort_order
            FROM workflow.instance_checklist_items ici
            JOIN workflow.workflow_checklists wc ON wc.id = ici.checklist_id
            WHERE ici.instance_id=%s
            ORDER BY wc.sort_order
        """, (instance_id,))
        checklist = cur.fetchall()
        cur.execute("""
            SELECT action_code, next_step_id, label
            FROM workflow.workflow_routes
            WHERE step_id=%s ORDER BY id
        """, (instance['current_step_id'],))
        routes = cur.fetchall()
        cur.execute("""
            SELECT wal.action_code, wal.comments, wal.created_at,
                   u.display_name AS performed_by
            FROM workflow.workflow_action_logs wal
            LEFT JOIN core.users u ON u.id = wal.performed_by
            WHERE wal.instance_id=%s ORDER BY wal.created_at
        """, (instance_id,))
        logs = cur.fetchall()
        return instance, checklist, routes, logs


def create_instance(definition_code, module, entity_type, entity_id,
                    initiated_by, reference_no=None, metadata=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            SELECT wd.id, ws.id AS first_step_id
            FROM workflow.workflow_definitions wd
            JOIN workflow.workflow_steps ws ON ws.workflow_id = wd.id
            WHERE wd.code = %s AND wd.is_active = TRUE
            ORDER BY ws.step_order
            LIMIT 1
        """, (definition_code,))
        row = cur.fetchone()
        if not row:
            return None
        import json
        cur.execute("""
            INSERT INTO workflow.workflow_instances
                (definition_id, current_step_id, module, entity_type, entity_id,
                 reference_no, initiated_by, status, metadata)
            VALUES (%s, %s, %s, %s, %s, %s, %s, 'IN_PROGRESS', %s)
            RETURNING id
        """, (row['id'], row['first_step_id'], module, entity_type, entity_id,
              reference_no, initiated_by, json.dumps(metadata or {})))
        instance_id = cur.fetchone()['id']
        # Create checklist items for the first step
        cur.execute("""
            INSERT INTO workflow.instance_checklist_items (instance_id, checklist_id)
            SELECT %s, wc.id FROM workflow.workflow_checklists wc
            WHERE wc.step_id = %s
        """, (instance_id, row['first_step_id']))
        return instance_id


def toggle_checklist(item_id, user_id):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            UPDATE workflow.instance_checklist_items
            SET is_completed = NOT is_completed,
                completed_by = CASE WHEN is_completed THEN NULL ELSE %s END,
                completed_at = CASE WHEN is_completed THEN NULL ELSE NOW() END
            WHERE id=%s RETURNING instance_id
        """, (user_id, item_id))
        return cur.fetchone()['instance_id']


def execute_action(instance_id, action_code, performed_by=None, comments=None):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            SELECT current_step_id, status FROM workflow.workflow_instances WHERE id=%s
        """, (instance_id,))
        current = cur.fetchone()
        if not current or current['status'] != 'IN_PROGRESS':
            return {'ok': False, 'message': 'Workflow is not in progress.'}

        # Gate check for APPROVE
        if action_code == 'APPROVE':
            cur.execute("""
                SELECT COUNT(*) AS pending_gate
                FROM workflow.instance_checklist_items ici
                JOIN workflow.workflow_checklists wc ON wc.id = ici.checklist_id
                WHERE ici.instance_id=%s AND wc.is_gate=TRUE AND ici.is_completed=FALSE
            """, (instance_id,))
            if cur.fetchone()['pending_gate'] > 0:
                return {'ok': False, 'message': 'Complete all gate checklist items before approval.'}

        # Find route
        cur.execute("""
            SELECT next_step_id, label FROM workflow.workflow_routes
            WHERE step_id=%s AND action_code=%s LIMIT 1
        """, (current['current_step_id'], action_code))
        route = cur.fetchone()
        if not route:
            return {'ok': False, 'message': f'No route configured for action: {action_code}'}

        from_status = current['status']

        if route['next_step_id'] is None:
            # Terminal step — complete or reject
            new_status = 'REJECTED' if action_code == 'REJECT' else 'COMPLETED'
            cur.execute("""
                UPDATE workflow.workflow_instances
                SET status=%s, current_step_id=NULL, completed_at=NOW()
                WHERE id=%s
            """, (new_status, instance_id))
        else:
            # Advance to next step
            cur.execute("""
                UPDATE workflow.workflow_instances
                SET current_step_id=%s, updated_at=NOW()
                WHERE id=%s
            """, (route['next_step_id'], instance_id))
            new_status = 'IN_PROGRESS'
            # Create checklist items for next step
            cur.execute("""
                INSERT INTO workflow.instance_checklist_items (instance_id, checklist_id)
                SELECT %s, wc.id FROM workflow.workflow_checklists wc
                WHERE wc.step_id = %s
                ON CONFLICT DO NOTHING
            """, (instance_id, route['next_step_id']))

        # Log the action
        cur.execute("""
            INSERT INTO workflow.workflow_action_logs
                (instance_id, step_id, action_code, performed_by, comments, from_status, to_status)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (instance_id, current['current_step_id'], action_code,
              performed_by, comments, from_status, new_status))

        return {'ok': True, 'message': f'Action {action_code} executed successfully.'}
