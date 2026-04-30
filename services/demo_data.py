"""
Demo data service — loads HR scenario presets for admin/capsanchez accounts.
Three periods: 'week' (7 days), 'month' (30 days), '6months' (180 days).
Each preset is cumulative: month includes week, 6months includes month.
"""
from datetime import datetime, timedelta
from services.db import get_cursor


def _ago(days=0, hours=0):
    return datetime.now() - timedelta(days=days, hours=hours)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

DEMO_USERS = ('admin@hcm360.local', 'capsanchez@hcm360.local')

PRESETS = {
    'week': {
        'label': '1 Week',
        'badge': 'Recent activity — last 7 days',
        'color': '#2563eb',
        'scenarios': [
            '2 active onboardings (HR review & IT provisioning stages)',
            '2 movement requests (1 approved → manager, 1 returned)',
            'NBI clearance expiry alert for 3 employees',
            'March payroll cutoff in progress',
        ],
        'counts': {'workflows': 10, 'transactions': 10},
    },
    'month': {
        'label': '1 Month',
        'badge': 'Full monthly HR cycle — 30 days',
        'color': '#7c3aed',
        'scenarios': [
            'All 1-week scenarios included',
            '1 completed onboarding (APPROVED) + 1 cancelled',
            '1 completed promotion + Q1 performance review cycle',
            'Annual/sick leave approvals and DPA compliance training',
        ],
        'counts': {'workflows': 16, 'transactions': 18},
    },
    '6months': {
        'label': '6 Months',
        'badge': 'Enterprise history — Oct 2025 to Mar 2026',
        'color': '#059669',
        'scenarios': [
            'All 1-month scenarios included',
            'Q4 2025 hiring wave, Nov merit increases, Dec 13th-month payroll',
            'January resignation, replacement recruitment pipeline',
            'February promotions, payroll, maternity leave, appraisals',
        ],
        'counts': {'workflows': 30, 'transactions': 36},
    },
}


def truncate_demo_data():
    """Remove all dynamic workflow/transaction data (preserves base employees, definitions)."""
    with get_cursor(commit=True) as cur:
        cur.execute("DELETE FROM workflow_action_logs")
        cur.execute("DELETE FROM instance_checklist_items")
        cur.execute("DELETE FROM workflow_instances")
        cur.execute("DELETE FROM transaction_timeline")
        cur.execute("DELETE FROM transaction_qr_tokens")
        cur.execute("DELETE FROM transaction_registry")


def load_preset(period, do_truncate=True):
    """Load demo data for the given period. Truncates first by default."""
    if period not in ('week', 'month', '6months'):
        raise ValueError(f"Unknown period: {period}")

    if do_truncate:
        truncate_demo_data()

    with get_cursor(commit=True) as cur:
        ctx = _build_ctx(cur)
        _load_base(cur, ctx)
        if period in ('week', 'month', '6months'):
            _load_week(cur, ctx)
        if period in ('month', '6months'):
            _load_month(cur, ctx)
        if period == '6months':
            _load_6months(cur, ctx)


def get_current_counts():
    """Return counts of dynamic records for the status panel."""
    with get_cursor() as cur:
        cur.execute("SELECT COUNT(*) AS n FROM workflow_instances")
        wf = cur.fetchone()['n']
        cur.execute("SELECT COUNT(*) AS n FROM transaction_registry")
        tx = cur.fetchone()['n']
        cur.execute("SELECT COUNT(*) AS n FROM workflow_action_logs")
        al = cur.fetchone()['n']
    return {'workflows': wf, 'transactions': tx, 'action_logs': al}


# ---------------------------------------------------------------------------
# Context builder
# ---------------------------------------------------------------------------

def _build_ctx(cur):
    cur.execute("SELECT status_code, status_group, id FROM status_definitions")
    sid = {(r['status_code'], r['status_group']): r['id'] for r in cur.fetchall()}

    cur.execute("""
        SELECT wd.workflow_code, ws.step_order, ws.id AS step_id
        FROM workflow_steps ws
        JOIN workflow_definitions wd ON ws.workflow_definition_id = wd.id
    """)
    step = {(r['workflow_code'], r['step_order']): r['step_id'] for r in cur.fetchall()}

    cur.execute("""
        SELECT wci.id, wci.item_label, ws.step_order, wd.workflow_code
        FROM workflow_checklist_items wci
        JOIN workflow_checklists wc ON wci.workflow_checklist_id = wc.id
        JOIN workflow_steps ws ON wc.workflow_step_id = ws.id
        JOIN workflow_definitions wd ON ws.workflow_definition_id = wd.id
    """)
    ci = {(r['workflow_code'], r['step_order'], r['item_label']): r['id'] for r in cur.fetchall()}

    ONB = 'ONBOARDING_FLOW'
    MOV = 'MOVEMENT_FLOW'

    return {
        'WP': sid[('PENDING', 'WORKFLOW')],
        'WI': sid[('IN_PROGRESS', 'WORKFLOW')],
        'WA': sid[('APPROVED', 'WORKFLOW')],
        'WR': sid[('REJECTED', 'WORKFLOW')],
        'ONB1': step[(ONB, 1)],
        'ONB2': step[(ONB, 2)],
        'ONB3': step[(ONB, 3)],
        'MOV1': step[(MOV, 1)],
        'MOV2': step[(MOV, 2)],
        'MOV3': step[(MOV, 3)],
        'CI_CONTRACT': ci.get((ONB, 1, 'Signed contract uploaded')),
        'CI_GOVID':    ci.get((ONB, 1, 'Government ID uploaded')),
        'CI_WELCOME':  ci.get((ONB, 1, 'Welcome email prepared')),
        'CI_EMAIL':    ci.get((ONB, 2, 'Email account provisioned')),
        'CI_LAPTOP':   ci.get((ONB, 2, 'Laptop assigned')),
        'CI_ORG':      ci.get((MOV, 1, 'Updated org placement validated')),
    }


# ---------------------------------------------------------------------------
# Insert helpers
# ---------------------------------------------------------------------------

def _inst(cur, wf_code, ref_no, status_id, step_id):
    cur.execute("""
        INSERT INTO workflow_instances(workflow_definition_id, reference_no, status_id, current_step_id)
        SELECT id, %s, %s, %s FROM workflow_definitions WHERE workflow_code=%s
        ON CONFLICT (reference_no) DO NOTHING RETURNING id
    """, (ref_no, status_id, step_id, wf_code))
    r = cur.fetchone()
    return r['id'] if r else None


def _chk(cur, inst_id, ci_id, done):
    if inst_id and ci_id:
        cur.execute(
            "INSERT INTO instance_checklist_items(instance_id, workflow_checklist_item_id, is_completed) VALUES (%s,%s,%s)",
            (inst_id, ci_id, done)
        )


def _act(cur, inst_id, code, note, when):
    if inst_id:
        cur.execute(
            "INSERT INTO workflow_action_logs(instance_id, action_code, action_note, action_time) VALUES (%s,%s,%s,%s)",
            (inst_id, code, note, when)
        )


def _tx(cur, module, ref_no, status_id, step_id, summary):
    cur.execute("""
        INSERT INTO transaction_registry(module_code, reference_no, status_id, current_step_id, summary_text)
        VALUES (%s,%s,%s,%s,%s) ON CONFLICT (reference_no) DO NOTHING RETURNING id
    """, (module, ref_no, status_id, step_id, summary))
    r = cur.fetchone()
    return r['id'] if r else None


def _tok(cur, tx_id, token):
    if tx_id:
        cur.execute(
            "INSERT INTO transaction_qr_tokens(transaction_id, public_token) VALUES (%s,%s) ON CONFLICT (public_token) DO NOTHING",
            (tx_id, token)
        )


def _tl(cur, tx_id, text, when=None):
    if tx_id:
        if when:
            cur.execute(
                "INSERT INTO transaction_timeline(transaction_id, event_text, event_time) VALUES (%s,%s,%s)",
                (tx_id, text, when)
            )
        else:
            cur.execute(
                "INSERT INTO transaction_timeline(transaction_id, event_text) VALUES (%s,%s)",
                (tx_id, text)
            )


def _onb_all_done(cur, inst_id, c):
    """Mark all onboarding checklist items as completed."""
    for ci_id in [c['CI_CONTRACT'], c['CI_GOVID'], c['CI_WELCOME'], c['CI_EMAIL'], c['CI_LAPTOP']]:
        _chk(cur, inst_id, ci_id, True)


# ---------------------------------------------------------------------------
# BASE — recreates the 6 init.sql instances (always loaded after truncate)
# ---------------------------------------------------------------------------

def _load_base(cur, c):
    # ONB-2026-0001: Noel Ramos — PENDING HR Review
    i = _inst(cur, 'ONBOARDING_FLOW', 'ONB-2026-0001', c['WP'], c['ONB1'])
    _chk(cur, i, c['CI_CONTRACT'], False); _chk(cur, i, c['CI_GOVID'], False); _chk(cur, i, c['CI_WELCOME'], False)
    t = _tx(cur, 'ONBOARDING', 'ONB-2026-0001', c['WP'], c['ONB1'], 'New hire onboarding — Noel Ramos (pending HR Review)')
    _tok(cur, t, 'demo-onb-2026-0001')
    _tl(cur, t, 'Onboarding initiated for Noel Ramos, Operations Specialist.', _ago(7))
    _tl(cur, t, 'HR Review assigned. Document checklist sent to employee.', _ago(7))
    _tl(cur, t, 'Reminder: 3 required documents still outstanding.', _ago(3))

    # ONB-2026-0002: Patricia Villanueva — PENDING HR Review
    i = _inst(cur, 'ONBOARDING_FLOW', 'ONB-2026-0002', c['WP'], c['ONB1'])
    _chk(cur, i, c['CI_CONTRACT'], False); _chk(cur, i, c['CI_GOVID'], False); _chk(cur, i, c['CI_WELCOME'], False)
    t = _tx(cur, 'ONBOARDING', 'ONB-2026-0002', c['WP'], c['ONB1'], 'New hire onboarding — Patricia Villanueva (pending HR Review)')
    _tok(cur, t, 'demo-onb-2026-0002')
    _tl(cur, t, 'Onboarding initiated for Patricia Villanueva, HR Officer.', _ago(5))
    _tl(cur, t, 'HR Review step assigned. All 3 documents missing.', _ago(5))
    _tl(cur, t, 'Document checklist emailed to Patricia Villanueva.', _ago(4))

    # ONB-2026-0003: Carlos Sanchez — IN PROGRESS IT Provisioning
    i = _inst(cur, 'ONBOARDING_FLOW', 'ONB-2026-0003', c['WI'], c['ONB2'])
    _chk(cur, i, c['CI_CONTRACT'], True); _chk(cur, i, c['CI_GOVID'], True); _chk(cur, i, c['CI_WELCOME'], True)
    _chk(cur, i, c['CI_EMAIL'], False); _chk(cur, i, c['CI_LAPTOP'], False)
    _act(cur, i, 'APPROVE', 'HR Review completed. Signed contract and Government ID verified.', _ago(3))
    t = _tx(cur, 'ONBOARDING', 'ONB-2026-0003', c['WI'], c['ONB2'], 'New hire onboarding — Carlos Sanchez (IT Provisioning in progress)')
    _tok(cur, t, 'demo-onb-2026-0003')
    _tl(cur, t, 'Onboarding initiated for Carlos Sanchez, IT Manager.', _ago(6))
    _tl(cur, t, 'HR Review approved. All documents verified.', _ago(3))
    _tl(cur, t, 'IT Provisioning started. Email account being set up.', _ago(3))
    _tl(cur, t, 'Email account created: csanchez@company.local', _ago(2))

    # ONB-2026-0004: Mark Torres — IN PROGRESS Final Confirmation
    i = _inst(cur, 'ONBOARDING_FLOW', 'ONB-2026-0004', c['WI'], c['ONB3'])
    _onb_all_done(cur, i, c)
    _act(cur, i, 'APPROVE', 'HR Review completed. All onboarding documents in order.', _ago(5))
    _act(cur, i, 'APPROVE', 'IT Provisioning done. Email account and laptop assigned.', _ago(2))
    t = _tx(cur, 'ONBOARDING', 'ONB-2026-0004', c['WI'], c['ONB3'], 'New hire onboarding — Mark Torres (Final Confirmation pending)')
    _tok(cur, t, 'demo-onb-2026-0004')
    _tl(cur, t, 'Onboarding initiated for Mark Torres, Finance Manager.', _ago(8))
    _tl(cur, t, 'HR Review completed and approved.', _ago(5))
    _tl(cur, t, 'IT provisioning complete. Laptop and email issued.', _ago(2))
    _tl(cur, t, 'Awaiting final HR sign-off to close onboarding.', _ago(1))

    # MOV-2026-0001: Carlo Ramos — IN PROGRESS Manager Approval
    i = _inst(cur, 'MOVEMENT_FLOW', 'MOV-2026-0001', c['WI'], c['MOV2'])
    _chk(cur, i, c['CI_ORG'], True)
    _act(cur, i, 'APPROVE', 'HR Review approved. Promotion to Senior Developer fully justified.', _ago(1))
    t = _tx(cur, 'MOVEMENTS', 'MOV-2026-0001', c['WI'], c['MOV2'], 'Promotion request — Carlo Ramos to Senior Developer (pending Manager Approval)')
    _tok(cur, t, 'demo-mov-2026-0001')
    _tl(cur, t, 'Promotion request submitted for Carlo Ramos.', _ago(3))
    _tl(cur, t, 'HR Review approved. Strong performance record cited.', _ago(1))
    _tl(cur, t, 'Pending manager endorsement to proceed to final approval.', _ago(1))

    # MOV-2026-0002: Unnamed — PENDING HR Review (returned)
    i = _inst(cur, 'MOVEMENT_FLOW', 'MOV-2026-0002', c['WP'], c['MOV1'])
    _chk(cur, i, c['CI_ORG'], False)
    _act(cur, i, 'REJECT', 'Missing updated position details and reporting line. Returned for correction.', _ago(0, 4))
    t = _tx(cur, 'MOVEMENTS', 'MOV-2026-0002', c['WP'], c['MOV1'], 'Movement request — returned for correction (incomplete details)')
    _tok(cur, t, 'demo-mov-2026-0002')
    _tl(cur, t, 'Movement request submitted.', _ago(2))
    _tl(cur, t, 'HR Review returned: incomplete position details and org placement.', _ago(0, 4))


# ---------------------------------------------------------------------------
# WEEK — 7-day HR scenarios layered on base
# ---------------------------------------------------------------------------

def _load_week(cur, c):
    # New onboarding: Grace Aquino — PENDING HR Review
    i = _inst(cur, 'ONBOARDING_FLOW', 'ONB-2026-W01', c['WP'], c['ONB1'])
    _chk(cur, i, c['CI_CONTRACT'], False); _chk(cur, i, c['CI_GOVID'], True); _chk(cur, i, c['CI_WELCOME'], False)
    t = _tx(cur, 'ONBOARDING', 'ONB-2026-W01', c['WP'], c['ONB1'], 'New hire onboarding — Grace Aquino, HR Manager (HR Review pending)')
    _tok(cur, t, 'demo-onb-2026-w01')
    _tl(cur, t, 'Onboarding initiated for Grace Aquino, HR Manager role.', _ago(5))
    _tl(cur, t, 'HR Review step assigned. Document checklist distributed.', _ago(5))
    _tl(cur, t, 'Grace Aquino uploaded Government ID. Signed contract still missing.', _ago(3))

    # New onboarding: IT Support hire — IN PROGRESS IT Provisioning
    i = _inst(cur, 'ONBOARDING_FLOW', 'ONB-2026-W02', c['WI'], c['ONB2'])
    _chk(cur, i, c['CI_CONTRACT'], True); _chk(cur, i, c['CI_GOVID'], True); _chk(cur, i, c['CI_WELCOME'], True)
    _chk(cur, i, c['CI_EMAIL'], True); _chk(cur, i, c['CI_LAPTOP'], False)
    _act(cur, i, 'APPROVE', 'HR Review passed. All pre-employment documents complete and verified.', _ago(2))
    t = _tx(cur, 'ONBOARDING', 'ONB-2026-W02', c['WI'], c['ONB2'], 'New hire onboarding — IT Support Analyst (IT Provisioning in progress)')
    _tok(cur, t, 'demo-onb-2026-w02')
    _tl(cur, t, 'IT Support Analyst onboarding initiated.', _ago(4))
    _tl(cur, t, 'HR Review approved. Documents verified.', _ago(2))
    _tl(cur, t, 'Email account provisioned: itsupport@company.local', _ago(1))
    _tl(cur, t, 'Laptop assignment in IT queue. Estimated 1 business day.', _ago(0, 12))

    # Movement: Ana Reyes lateral transfer — IN PROGRESS Manager Approval
    i = _inst(cur, 'MOVEMENT_FLOW', 'MOV-2026-W01', c['WI'], c['MOV2'])
    _chk(cur, i, c['CI_ORG'], True)
    _act(cur, i, 'APPROVE', 'HR validated lateral transfer request. No salary change. Org chart updated.', _ago(1))
    t = _tx(cur, 'MOVEMENTS', 'MOV-2026-W01', c['WI'], c['MOV2'], 'Lateral transfer — Ana Reyes, HR → Operations Support (Manager Approval pending)')
    _tok(cur, t, 'demo-mov-2026-w01')
    _tl(cur, t, 'Lateral transfer request submitted by Ana Reyes.', _ago(3))
    _tl(cur, t, 'HR review completed. No compensation change. Org placement confirmed.', _ago(1))
    _tl(cur, t, 'Awaiting manager approval to finalize transfer.', _ago(1))

    # Movement: Roberto Mendoza dept transfer — RETURNED (insufficient justification)
    i = _inst(cur, 'MOVEMENT_FLOW', 'MOV-2026-W02', c['WP'], c['MOV1'])
    _chk(cur, i, c['CI_ORG'], False)
    _act(cur, i, 'REJECT', 'Transfer request lacks adequate business justification. Returned to requestor for revision.', _ago(0, 6))
    t = _tx(cur, 'MOVEMENTS', 'MOV-2026-W02', c['WP'], c['MOV1'], 'Dept transfer — Roberto Mendoza (returned: business justification required)')
    _tok(cur, t, 'demo-mov-2026-w02')
    _tl(cur, t, 'Department transfer request submitted by Roberto Mendoza.', _ago(2))
    _tl(cur, t, 'HR Review returned: transfer justification insufficient. Revision required.', _ago(0, 6))

    # Compliance: NBI clearance expiry alerts
    t = _tx(cur, 'COMPLIANCE', 'CMP-2026-W01', c['WP'], c['ONB1'],
            'NBI Clearance expiry alert — 3 employees expiring within 30 days')
    _tok(cur, t, 'demo-cmp-2026-w01')
    _tl(cur, t, 'Automated compliance scan completed — NBI Clearance audit.', _ago(1))
    _tl(cur, t, 'Expiry detected: Lara Cruz (Apr 5), Miguel Santos (Apr 12), Carlo Ramos (Apr 18).', _ago(1))
    _tl(cur, t, 'Renewal reminders sent to 3 employees and HR Admin.', _ago(1))
    _tl(cur, t, 'Employees have 30 days to submit renewed NBI Clearance.', _ago(1))

    # Payroll: March 2026 cutoff
    t = _tx(cur, 'PAYROLL', 'PAY-2026-MAR', c['WP'], c['ONB1'],
            'March 2026 payroll — cutoff initiated, 13 active employees')
    _tok(cur, t, 'demo-pay-2026-mar')
    _tl(cur, t, 'March 2026 payroll cutoff initiated by Payroll Admin.', _ago(3))
    _tl(cur, t, '13 active employees included. 2 on ONBOARDING status excluded from this cycle.', _ago(3))
    _tl(cur, t, 'Attendance data pulled. Overtime and deductions being computed.', _ago(2))
    _tl(cur, t, 'Payroll computation in progress. Pending final approval.', _ago(1))


# ---------------------------------------------------------------------------
# MONTH — additional 30-day scenarios (day -8 to day -30)
# ---------------------------------------------------------------------------

def _load_month(cur, c):
    # Completed onboarding: Jose Bautista (3 weeks ago)
    i = _inst(cur, 'ONBOARDING_FLOW', 'ONB-2026-M01', c['WA'], c['ONB3'])
    _onb_all_done(cur, i, c)
    _act(cur, i, 'APPROVE', 'HR Review passed. All documents verified.', _ago(22))
    _act(cur, i, 'APPROVE', 'IT Provisioning complete. Email and laptop issued.', _ago(19))
    _act(cur, i, 'APPROVE', 'Final confirmation approved. Employee set to ACTIVE.', _ago(16))
    t = _tx(cur, 'ONBOARDING', 'ONB-2026-M01', c['WA'], c['ONB3'],
            'Onboarding completed — Jose Bautista, Operations Specialist (APPROVED)')
    _tok(cur, t, 'demo-onb-2026-m01')
    _tl(cur, t, 'Onboarding initiated for Jose Bautista, Operations Specialist.', _ago(24))
    _tl(cur, t, 'HR Review approved. All pre-employment checks cleared.', _ago(22))
    _tl(cur, t, 'IT provisioning completed. All tools and access granted.', _ago(19))
    _tl(cur, t, 'Onboarding approved and closed. Employee status: ACTIVE.', _ago(16))

    # Cancelled onboarding: Finance Analyst candidate withdrew
    i = _inst(cur, 'ONBOARDING_FLOW', 'ONB-2026-M02', c['WR'], c['ONB1'])
    _chk(cur, i, c['CI_CONTRACT'], False); _chk(cur, i, c['CI_GOVID'], False); _chk(cur, i, c['CI_WELCOME'], False)
    _act(cur, i, 'REJECT', 'Candidate failed to submit documents within 48 hours. Offer rescinded.', _ago(18))
    t = _tx(cur, 'ONBOARDING', 'ONB-2026-M02', c['WR'], c['ONB1'],
            'Onboarding voided — Finance Analyst candidate withdrew (March 2026)')
    _tok(cur, t, 'demo-onb-2026-m02')
    _tl(cur, t, 'Onboarding initiated for Finance Analyst candidate.', _ago(20))
    _tl(cur, t, 'Candidate failed to upload required documents within 48-hour window.', _ago(19))
    _tl(cur, t, 'HR notified. Candidate confirmed withdrawal of acceptance.', _ago(18))
    _tl(cur, t, 'Onboarding voided. Position re-posted for hiring.', _ago(18))

    # Completed promotion: Lara Cruz to Senior Systems Analyst
    i = _inst(cur, 'MOVEMENT_FLOW', 'MOV-2026-M01', c['WA'], c['MOV3'])
    _chk(cur, i, c['CI_ORG'], True)
    _act(cur, i, 'APPROVE', 'HR Review approved. Promotion rationale confirmed by performance data.', _ago(18))
    _act(cur, i, 'APPROVE', 'Manager endorsed. Exceptional Q4 2025 performance cited.', _ago(16))
    _act(cur, i, 'APPROVE', 'Senior Management approved. Promotion effective March 1, 2026.', _ago(15))
    t = _tx(cur, 'MOVEMENTS', 'MOV-2026-M01', c['WA'], c['MOV3'],
            'Promotion approved — Lara Cruz to Senior Systems Analyst (effective Mar 1, 2026)')
    _tok(cur, t, 'demo-mov-2026-m01')
    _tl(cur, t, 'Promotion request filed for Lara Cruz — Systems Analyst → Senior level.', _ago(20))
    _tl(cur, t, 'HR Review approved. 3-year track record and strong Q4 results cited.', _ago(18))
    _tl(cur, t, 'Manager and senior management approvals obtained.', _ago(15))
    _tl(cur, t, 'Salary adjustment applied effective March 1, 2026.', _ago(27))

    # Pending promotion: Miguel Santos, IN PROGRESS at final approval
    i = _inst(cur, 'MOVEMENT_FLOW', 'MOV-2026-M02', c['WI'], c['MOV3'])
    _chk(cur, i, c['CI_ORG'], True)
    _act(cur, i, 'APPROVE', 'HR approved. Strong technical leadership demonstrated.', _ago(10))
    _act(cur, i, 'APPROVE', 'Manager endorsed. Leads the IT architecture review.', _ago(8))
    t = _tx(cur, 'MOVEMENTS', 'MOV-2026-M02', c['WI'], c['MOV3'],
            'Promotion — Miguel Santos to Lead Developer (pending Senior Management approval)')
    _tok(cur, t, 'demo-mov-2026-m02')
    _tl(cur, t, 'Promotion request submitted for Miguel Santos.', _ago(12))
    _tl(cur, t, 'HR and Manager approvals obtained. Awaiting COO sign-off.', _ago(8))

    # Leave: Maria Santos annual leave (approved, completed)
    t = _tx(cur, 'LEAVE', 'LV-2026-M01', c['WA'], c['ONB1'],
            'Annual leave — Maria Santos, 10 days (Mar 3–14, 2026) — APPROVED')
    _tok(cur, t, 'demo-lv-2026-m01')
    _tl(cur, t, 'Annual leave request filed by Maria Santos (10 working days, Mar 3–14).', _ago(25))
    _tl(cur, t, 'Leave approved by HR Manager. Leave credits deducted.', _ago(23))
    _tl(cur, t, 'Leave period started: March 3, 2026.', _ago(25))
    _tl(cur, t, 'Leave completed. Maria Santos returned March 17, 2026.', _ago(11))

    # Leave: Isabel Garcia sick leave (pending)
    t = _tx(cur, 'LEAVE', 'LV-2026-M02', c['WP'], c['ONB1'],
            'Sick leave — Isabel Garcia, 3 days (pending approval)')
    _tok(cur, t, 'demo-lv-2026-m02')
    _tl(cur, t, 'Sick leave request filed by Isabel Garcia (3 days).', _ago(8))
    _tl(cur, t, 'Medical certificate uploaded and attached to request.', _ago(8))
    _tl(cur, t, 'Pending review and approval by HR Admin.', _ago(8))

    # Performance: Q1 2026 review cycle
    t = _tx(cur, 'PERFORMANCE', 'PERF-2026-M01', c['WI'], c['ONB1'],
            'Q1 2026 performance review cycle — 10 active employees')
    _tok(cur, t, 'demo-perf-2026-m01')
    _tl(cur, t, 'Q1 2026 performance review cycle initiated by HR Admin.', _ago(14))
    _tl(cur, t, '10 employees included in the review cycle. KPIs loaded from Q4 2025 targets.', _ago(14))
    _tl(cur, t, 'Self-assessment forms distributed to all employees.', _ago(12))
    _tl(cur, t, '6 of 10 employees have submitted self-assessments.', _ago(5))
    _tl(cur, t, 'Deadline: March 31, 2026. 4 submissions still outstanding.', _ago(1))

    # Training: DPA compliance
    t = _tx(cur, 'TRAINING', 'TRN-2026-M01', c['WI'], c['ONB1'],
            'Data Privacy Act compliance training — 8 employees enrolled')
    _tok(cur, t, 'demo-trn-2026-m01')
    _tl(cur, t, 'Mandatory DPA compliance training scheduled for March 2026.', _ago(20))
    _tl(cur, t, '8 employees enrolled. Training modules assigned in LMS.', _ago(18))
    _tl(cur, t, '5 of 8 employees completed the DPA training module.', _ago(8))
    _tl(cur, t, 'Remaining 3 employees reminded. Deadline: March 31, 2026.', _ago(1))


# ---------------------------------------------------------------------------
# 6 MONTHS — historical scenarios Oct 2025 → Feb 2026
# ---------------------------------------------------------------------------

def _load_6months(cur, c):
    # === OCTOBER 2025: Q4 hiring wave ===

    i = _inst(cur, 'ONBOARDING_FLOW', 'ONB-2025-Q4-01', c['WA'], c['ONB3'])
    _onb_all_done(cur, i, c)
    _act(cur, i, 'APPROVE', 'HR Review complete.', _ago(175))
    _act(cur, i, 'APPROVE', 'IT provisioned.', _ago(172))
    _act(cur, i, 'APPROVE', 'Onboarding closed.', _ago(170))
    t = _tx(cur, 'ONBOARDING', 'ONB-2025-Q4-01', c['WA'], c['ONB3'],
            'Onboarding completed — Operations Specialist hire (Oct 2025 Q4 batch)')
    _tok(cur, t, 'demo-onb-2025-q4-01')
    _tl(cur, t, 'Q4 2025 hiring wave initiated — Operations team expansion.', _ago(178))
    _tl(cur, t, 'Onboarding completed. Employee ACTIVE since October 2025.', _ago(170))

    i = _inst(cur, 'ONBOARDING_FLOW', 'ONB-2025-Q4-02', c['WA'], c['ONB3'])
    _onb_all_done(cur, i, c)
    _act(cur, i, 'APPROVE', 'Full approval chain completed.', _ago(165))
    t = _tx(cur, 'ONBOARDING', 'ONB-2025-Q4-02', c['WA'], c['ONB3'],
            'Onboarding completed — Finance Accountant hire (Oct 2025)')
    _tok(cur, t, 'demo-onb-2025-q4-02')
    _tl(cur, t, 'Finance team expansion — new Accountant onboarding.', _ago(170))
    _tl(cur, t, 'Onboarding completed successfully. Employee ACTIVE.', _ago(165))

    i = _inst(cur, 'ONBOARDING_FLOW', 'ONB-2025-Q4-03', c['WR'], c['ONB1'])
    _chk(cur, i, c['CI_CONTRACT'], False); _chk(cur, i, c['CI_GOVID'], False); _chk(cur, i, c['CI_WELCOME'], False)
    _act(cur, i, 'REJECT', 'Pre-employment medical clearance failed. Offer rescinded per HR policy.', _ago(163))
    t = _tx(cur, 'ONBOARDING', 'ONB-2025-Q4-03', c['WR'], c['ONB1'],
            'Onboarding rejected — pre-employment medical failed (Oct 2025)')
    _tok(cur, t, 'demo-onb-2025-q4-03')
    _tl(cur, t, 'Candidate onboarding initiated. Pre-employment checks in progress.', _ago(166))
    _tl(cur, t, 'Medical clearance: FAILED. Candidate informed and offer rescinded.', _ago(163))
    _tl(cur, t, 'Position re-posted. Replacement recruitment initiated.', _ago(162))

    # October payroll
    t = _tx(cur, 'PAYROLL', 'PAY-2025-OCT', c['WA'], c['ONB1'],
            'October 2025 payroll completed — 10 employees, 2 mid-month joiners pro-rated')
    _tok(cur, t, 'demo-pay-2025-oct')
    _tl(cur, t, 'October 2025 payroll processing initiated.', _ago(180))
    _tl(cur, t, '10 employees processed. 2 Q4 hires pro-rated from start date.', _ago(178))
    _tl(cur, t, 'Payroll approved and disbursed.', _ago(175))

    # === NOVEMBER 2025: Merit increases ===

    i = _inst(cur, 'MOVEMENT_FLOW', 'MOV-2025-NOV-01', c['WA'], c['MOV3'])
    _chk(cur, i, c['CI_ORG'], True)
    _act(cur, i, 'APPROVE', 'HR approved merit increase based on 2025 annual performance rating.', _ago(145))
    _act(cur, i, 'APPROVE', 'Manager endorsed. Exceptional performance in system architecture.', _ago(143))
    _act(cur, i, 'APPROVE', 'COO approved. Effective December 1, 2025.', _ago(140))
    t = _tx(cur, 'MOVEMENTS', 'MOV-2025-NOV-01', c['WA'], c['MOV3'],
            'Merit increase approved — Miguel Santos (2025 annual review, effective Dec 1)')
    _tok(cur, t, 'demo-mov-2025-nov-01')
    _tl(cur, t, 'Annual performance merit increase submitted — Miguel Santos.', _ago(148))
    _tl(cur, t, 'All approvals obtained. 12% salary increase effective Dec 1, 2025.', _ago(140))

    i = _inst(cur, 'MOVEMENT_FLOW', 'MOV-2025-NOV-02', c['WA'], c['MOV3'])
    _chk(cur, i, c['CI_ORG'], True)
    _act(cur, i, 'APPROVE', 'HR approved.', _ago(142))
    _act(cur, i, 'APPROVE', 'Manager confirmed strong Q3 sales operations results.', _ago(140))
    _act(cur, i, 'APPROVE', 'Approved. 10% increase effective Dec 1, 2025.', _ago(138))
    t = _tx(cur, 'MOVEMENTS', 'MOV-2025-NOV-02', c['WA'], c['MOV3'],
            'Merit increase approved — Roberto Mendoza (2025 annual review, effective Dec 1)')
    _tok(cur, t, 'demo-mov-2025-nov-02')
    _tl(cur, t, 'Merit increase request for Roberto Mendoza filed.', _ago(145))
    _tl(cur, t, 'Fully approved. 10% salary increase effective December 1, 2025.', _ago(138))

    # November payroll
    t = _tx(cur, 'PAYROLL', 'PAY-2025-NOV', c['WA'], c['ONB1'],
            'November 2025 payroll completed — 11 employees, merit increase adjustments applied')
    _tok(cur, t, 'demo-pay-2025-nov')
    _tl(cur, t, 'November 2025 payroll initiated.', _ago(150))
    _tl(cur, t, '11 employees processed. 2 merit increase salary adjustments applied.', _ago(148))
    _tl(cur, t, 'Payroll approved and disbursed on November 30, 2025.', _ago(145))

    # === DECEMBER 2025: Year-end ===

    t = _tx(cur, 'COMPLIANCE', 'CMP-2025-YE', c['WA'], c['ONB1'],
            'Year-end 201 file compliance audit completed — 12 employees reviewed')
    _tok(cur, t, 'demo-cmp-2025-ye')
    _tl(cur, t, 'Annual 201 file compliance audit initiated by HR Admin.', _ago(118))
    _tl(cur, t, '12 employee 201 files reviewed. 3 files had missing or expired documents.', _ago(115))
    _tl(cur, t, 'Missing docs collected from 2 of 3 employees (Lara Cruz, Miguel Santos).', _ago(112))
    _tl(cur, t, 'Audit closed. 1 minor deficiency noted: Diana Flores (inactive — exempt).', _ago(108))

    t = _tx(cur, 'TRAINING', 'TRN-2025-DEC', c['WA'], c['ONB1'],
            'Year-end mandatory training completed — Fire Safety & DPA Refresher (Dec 2025)')
    _tok(cur, t, 'demo-trn-2025-dec')
    _tl(cur, t, 'Year-end mandatory training assigned to all 12 active employees.', _ago(120))
    _tl(cur, t, 'Fire Safety & Emergency Response Training: 12/12 completed.', _ago(115))
    _tl(cur, t, 'DPA Compliance Refresher: 11/12 completed (Diana Flores — inactive, exempt).', _ago(110))
    _tl(cur, t, 'Training records archived. Certificates issued.', _ago(105))

    t = _tx(cur, 'PAYROLL', 'PAY-2025-DEC', c['WA'], c['ONB1'],
            'December 2025 payroll + 13th month pay — 12 employees, FY2025 closed')
    _tok(cur, t, 'demo-pay-2025-dec')
    _tl(cur, t, 'December payroll with 13th month pay computation initiated.', _ago(118))
    _tl(cur, t, '12 employees processed. 13th month pay disbursed.', _ago(115))
    _tl(cur, t, 'Year-end bonuses computed and finalized.', _ago(113))
    _tl(cur, t, 'Payroll closed for FY2025. All statutory remittances filed.', _ago(110))

    # === JANUARY 2026: New year hiring + resignation ===

    i = _inst(cur, 'ONBOARDING_FLOW', 'ONB-2026-JAN-01', c['WA'], c['ONB3'])
    _onb_all_done(cur, i, c)
    _act(cur, i, 'APPROVE', 'HR Review complete.', _ago(85))
    _act(cur, i, 'APPROVE', 'IT provisioned.', _ago(82))
    _act(cur, i, 'APPROVE', 'Onboarding closed.', _ago(80))
    t = _tx(cur, 'ONBOARDING', 'ONB-2026-JAN-01', c['WA'], c['ONB3'],
            'Onboarding completed — IT hire (January 2026 expansion batch)')
    _tok(cur, t, 'demo-onb-2026-jan-01')
    _tl(cur, t, 'January 2026 IT team expansion — new hire onboarding started.', _ago(88))
    _tl(cur, t, 'Onboarding completed. Employee ACTIVE since January 2026.', _ago(80))

    i = _inst(cur, 'ONBOARDING_FLOW', 'ONB-2026-JAN-02', c['WA'], c['ONB3'])
    _onb_all_done(cur, i, c)
    _act(cur, i, 'APPROVE', 'All steps approved.', _ago(78))
    t = _tx(cur, 'ONBOARDING', 'ONB-2026-JAN-02', c['WA'], c['ONB3'],
            'Onboarding completed — Finance hire (January 2026)')
    _tok(cur, t, 'demo-onb-2026-jan-02')
    _tl(cur, t, 'Finance Department expansion — January 2026 hire.', _ago(82))
    _tl(cur, t, 'Onboarding completed. Employee ACTIVE.', _ago(78))

    i = _inst(cur, 'ONBOARDING_FLOW', 'ONB-2026-JAN-03', c['WA'], c['ONB3'])
    _onb_all_done(cur, i, c)
    _act(cur, i, 'APPROVE', 'Completed.', _ago(75))
    t = _tx(cur, 'ONBOARDING', 'ONB-2026-JAN-03', c['WA'], c['ONB3'],
            'Onboarding completed — Operations hire (January 2026)')
    _tok(cur, t, 'demo-onb-2026-jan-03')
    _tl(cur, t, 'Operations team expansion — January batch.', _ago(80))
    _tl(cur, t, 'Onboarding completed. Employee ACTIVE.', _ago(75))

    # Resignation: Diana Flores
    t = _tx(cur, 'MOVEMENTS', 'MOV-2026-JAN-RES', c['WA'], c['MOV3'],
            'Resignation processed — Diana Flores, Accountant (effective Jan 15, 2026)')
    _tok(cur, t, 'demo-mov-2026-jan-res')
    _tl(cur, t, 'Resignation letter received from Diana Flores, Finance Accountant.', _ago(80))
    _tl(cur, t, 'Exit interview conducted. Reason: better opportunity abroad.', _ago(77))
    _tl(cur, t, 'Final pay computation initiated. Clearance process started.', _ago(76))
    _tl(cur, t, 'Final pay released. Employee status set to INACTIVE.', _ago(73))
    _tl(cur, t, 'Replacement Finance Accountant position opened. Recruitment initiated.', _ago(72))

    # January payroll
    t = _tx(cur, 'PAYROLL', 'PAY-2026-JAN', c['WA'], c['ONB1'],
            'January 2026 payroll completed — 13 employees (3 new, 1 final pay)')
    _tok(cur, t, 'demo-pay-2026-jan')
    _tl(cur, t, 'January 2026 payroll initiated. 3 new employees added.', _ago(88))
    _tl(cur, t, 'Pro-rated salaries computed for January joiners.', _ago(86))
    _tl(cur, t, 'Final pay for Diana Flores processed and included.', _ago(76))
    _tl(cur, t, 'Payroll approved and disbursed.', _ago(85))

    # === FEBRUARY 2026: Promotions + performance ===

    i = _inst(cur, 'MOVEMENT_FLOW', 'MOV-2026-FEB-01', c['WA'], c['MOV3'])
    _chk(cur, i, c['CI_ORG'], True)
    _act(cur, i, 'APPROVE', 'HR approved promotion based on outstanding Q4 2025 performance.', _ago(58))
    _act(cur, i, 'APPROVE', 'Manager confirmed readiness. Exceptional payroll accuracy record.', _ago(56))
    _act(cur, i, 'APPROVE', 'COO approved. Effective March 1, 2026.', _ago(55))
    t = _tx(cur, 'MOVEMENTS', 'MOV-2026-FEB-01', c['WA'], c['MOV3'],
            'Promotion approved — Isabel Garcia to Senior Payroll Specialist (effective Mar 1, 2026)')
    _tok(cur, t, 'demo-mov-2026-feb-01')
    _tl(cur, t, 'Promotion request submitted for Isabel Garcia — Payroll → Senior Payroll.', _ago(62))
    _tl(cur, t, 'All approval levels obtained. Salary adjustment processed.', _ago(55))
    _tl(cur, t, 'Promotion effective March 1, 2026. Updated employment contract issued.', _ago(55))

    i = _inst(cur, 'MOVEMENT_FLOW', 'MOV-2026-FEB-02', c['WR'], c['MOV2'])
    _chk(cur, i, c['CI_ORG'], True)
    _act(cur, i, 'APPROVE', 'HR approved the request.', _ago(56))
    _act(cur, i, 'REJECT', 'Manager denied: Q4 2025 performance targets not fully met. Re-evaluate Q2 2026.', _ago(54))
    t = _tx(cur, 'MOVEMENTS', 'MOV-2026-FEB-02', c['WR'], c['MOV2'],
            'Promotion rejected — Jose Bautista (Q4 2025 targets not met, re-evaluate Q2 2026)')
    _tok(cur, t, 'demo-mov-2026-feb-02')
    _tl(cur, t, 'Promotion request submitted for Jose Bautista.', _ago(58))
    _tl(cur, t, 'HR approved. Escalated to direct manager.', _ago(56))
    _tl(cur, t, 'Manager rejected: performance targets not fully met in Q4 2025.', _ago(54))
    _tl(cur, t, 'Jose Bautista notified. PIP initiated. Re-evaluation set for Q2 2026 review.', _ago(53))

    # February leaves
    t = _tx(cur, 'LEAVE', 'LV-2026-FEB-01', c['WA'], c['ONB1'],
            'Vacation leave approved — Roberto Mendoza, 5 days (Feb 10–14, 2026)')
    _tok(cur, t, 'demo-lv-2026-feb-01')
    _tl(cur, t, 'Vacation leave filed — Roberto Mendoza (Feb 10–14, 5 working days).', _ago(60))
    _tl(cur, t, 'Approved by HR Admin. Leave credits deducted.', _ago(59))
    _tl(cur, t, 'Leave completed. Roberto Mendoza returned February 17, 2026.', _ago(39))

    t = _tx(cur, 'LEAVE', 'LV-2026-FEB-02', c['WA'], c['ONB1'],
            'Maternity leave filed — Ana Reyes, 60 days (starting March 1, 2026)')
    _tok(cur, t, 'demo-lv-2026-feb-02')
    _tl(cur, t, 'Maternity leave notice filed by Ana Reyes.', _ago(55))
    _tl(cur, t, 'Medical certificate attached, OB clearance verified.', _ago(54))
    _tl(cur, t, 'HR approved 60-day maternity leave effective March 1, 2026.', _ago(53))
    _tl(cur, t, 'Temporary coverage arrangement made with HR Admin.', _ago(52))

    # February payroll
    t = _tx(cur, 'PAYROLL', 'PAY-2026-FEB', c['WA'], c['ONB1'],
            'February 2026 payroll completed — 14 active employees, promotion adjustments applied')
    _tok(cur, t, 'demo-pay-2026-feb')
    _tl(cur, t, 'February 2026 payroll processing initiated.', _ago(60))
    _tl(cur, t, '14 employees processed. Isabel Garcia promotion adjustment included.', _ago(58))
    _tl(cur, t, 'Payroll approved and disbursed on February 28, 2026.', _ago(56))

    # Recruitment: replacement for Diana Flores
    t = _tx(cur, 'RECRUITMENT', 'REC-2026-FEB-01', c['WI'], c['ONB1'],
            'Recruitment in progress — Finance Accountant (replacement for Diana Flores)')
    _tok(cur, t, 'demo-rec-2026-feb-01')
    _tl(cur, t, 'Job posting published for Finance Accountant role (replacement).', _ago(70))
    _tl(cur, t, '14 applications received. Initial HR screening completed.', _ago(62))
    _tl(cur, t, '3 candidates shortlisted for panel interview.', _ago(55))
    _tl(cur, t, 'Final interviews conducted. Reference checks initiated.', _ago(45))
    _tl(cur, t, 'Reference check completed. Top candidate identified. Offer pending approval.', _ago(20))
    _tl(cur, t, 'Offer letter prepared. Awaiting candidate response.', _ago(12))

    # Quarterly compliance: SSS / PhilHealth / Pag-IBIG
    t = _tx(cur, 'COMPLIANCE', 'CMP-2026-Q1', c['WI'], c['ONB1'],
            'Q1 2026 statutory compliance audit — SSS, PhilHealth, Pag-IBIG reconciliation')
    _tok(cur, t, 'demo-cmp-2026-q1')
    _tl(cur, t, 'Q1 2026 government reportorial compliance audit initiated.', _ago(15))
    _tl(cur, t, 'Payroll data extracted for SSS, PhilHealth, and Pag-IBIG computation.', _ago(12))
    _tl(cur, t, 'SSS contributions reconciled — 14 employees, Jan–Mar 2026.', _ago(10))
    _tl(cur, t, 'PhilHealth and Pag-IBIG remittances computation in progress.', _ago(5))
    _tl(cur, t, 'Filing deadline: April 10, 2026. On track.', _ago(1))
