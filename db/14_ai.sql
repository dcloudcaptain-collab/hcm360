-- ================================================================
-- HCM360 HRIS — 14: AI SCHEMA (Phase 3 foundation)
-- Schema    : ai
-- Contains  : feature store, risk scores, recommendations,
--             insight results, ARIA session logs
-- NOTE: Populated by Phase 3 ML pipeline.
--       ARIA queries analytics schema, not raw transactional data.
-- ================================================================

SET search_path TO ai, core, analytics, public;

-- ── Feature Store (employee snapshot for ML) ──────────────────────

CREATE TABLE ai.ai_feature_store (
    id                      BIGSERIAL    PRIMARY KEY,
    employee_id             BIGINT       NOT NULL REFERENCES core.employees(id),
    snapshot_date           DATE         NOT NULL,
    avg_hours_worked_30d    NUMERIC(5,2) NOT NULL DEFAULT 0,
    late_count_30d          INTEGER      NOT NULL DEFAULT 0,
    absent_count_30d        INTEGER      NOT NULL DEFAULT 0,
    ot_hours_30d            NUMERIC(5,2) NOT NULL DEFAULT 0,
    leave_balance_vl        NUMERIC(5,2) NOT NULL DEFAULT 0,
    leave_taken_ytd         NUMERIC(5,2) NOT NULL DEFAULT 0,
    last_review_score       NUMERIC(4,2),
    training_hours_ytd      NUMERIC(6,2) NOT NULL DEFAULT 0,
    tenure_months           INTEGER      NOT NULL DEFAULT 0,
    salary_grade_level      INTEGER,
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (employee_id, snapshot_date)
);

-- ── Risk Scores ───────────────────────────────────────────────────

CREATE TABLE ai.ai_risk_scores (
    id              BIGSERIAL    PRIMARY KEY,
    employee_id     BIGINT       NOT NULL REFERENCES core.employees(id),
    score_date      DATE         NOT NULL DEFAULT CURRENT_DATE,
    risk_type       VARCHAR(50)  NOT NULL,
    risk_score      NUMERIC(5,4) NOT NULL CHECK (risk_score BETWEEN 0 AND 1) DEFAULT 0,
    risk_level      VARCHAR(20)  NOT NULL DEFAULT 'LOW',
    confidence      NUMERIC(5,4) NOT NULL DEFAULT 0,
    model_version   VARCHAR(30)  NOT NULL DEFAULT 'v0-placeholder',
    factors         JSONB        NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (employee_id, score_date, risk_type)
);

CREATE INDEX idx_ai_risk_type  ON ai.ai_risk_scores(risk_type, score_date, risk_level);
CREATE INDEX idx_ai_risk_emp   ON ai.ai_risk_scores(employee_id, score_date);

-- ── Recommendations ───────────────────────────────────────────────

CREATE TABLE ai.ai_recommendations (
    id                      BIGSERIAL    PRIMARY KEY,
    target_user_id          BIGINT       REFERENCES core.users(id),
    target_employee_id      BIGINT       REFERENCES core.employees(id),
    module                  VARCHAR(50)  NOT NULL,
    recommendation_type     VARCHAR(60)  NOT NULL,
    title                   VARCHAR(200) NOT NULL,
    body                    TEXT         NOT NULL,
    action_url              VARCHAR(500),
    priority                INTEGER      NOT NULL DEFAULT 5,
    is_dismissed            BOOLEAN      NOT NULL DEFAULT FALSE,
    expires_at              DATE,
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── Insight Results (stored AI analysis outputs) ──────────────────

CREATE TABLE ai.ai_insight_results (
    id              BIGSERIAL    PRIMARY KEY,
    insight_type    VARCHAR(60)  NOT NULL,
    module          VARCHAR(50)  NOT NULL,
    scope           VARCHAR(50)  NOT NULL DEFAULT 'COMPANY',
    entity_id       BIGINT,
    title           VARCHAR(200) NOT NULL,
    summary         TEXT         NOT NULL,
    data_payload    JSONB        NOT NULL DEFAULT '{}',
    generated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    valid_until     TIMESTAMPTZ
);

-- ── ARIA Session Logs ─────────────────────────────────────────────

CREATE TABLE ai.ai_sessions (
    id              BIGSERIAL    PRIMARY KEY,
    user_id         BIGINT       NOT NULL REFERENCES core.users(id),
    session_token   VARCHAR(100) NOT NULL UNIQUE,
    started_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    ended_at        TIMESTAMPTZ,
    message_count   INTEGER      NOT NULL DEFAULT 0
);

CREATE TABLE ai.ai_messages (
    id              BIGSERIAL    PRIMARY KEY,
    session_id      BIGINT       NOT NULL REFERENCES ai.ai_sessions(id),
    role            VARCHAR(20)  NOT NULL,
    content         TEXT         NOT NULL,
    tool_calls      JSONB,
    tokens_used     INTEGER,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE ai.ai_tool_call_logs (
    id              BIGSERIAL    PRIMARY KEY,
    message_id      BIGINT       REFERENCES ai.ai_messages(id),
    tool_name       VARCHAR(100) NOT NULL,
    input_params    JSONB        NOT NULL DEFAULT '{}',
    output_result   JSONB        NOT NULL DEFAULT '{}',
    execution_ms    INTEGER,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── Persona / Config ──────────────────────────────────────────────

CREATE TABLE ai.ai_persona_configs (
    id              BIGSERIAL    PRIMARY KEY,
    persona_code    VARCHAR(30)  NOT NULL UNIQUE,
    name            VARCHAR(100) NOT NULL,
    system_prompt   TEXT         NOT NULL,
    model           VARCHAR(60)  NOT NULL DEFAULT 'claude-sonnet-4-6',
    max_tokens      INTEGER      NOT NULL DEFAULT 4096,
    tools_enabled   TEXT[]       NOT NULL DEFAULT '{}',
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

INSERT INTO ai.ai_persona_configs (persona_code, name, system_prompt, tools_enabled) VALUES
('ARIA_ASSISTANT', 'ARIA - HR Assistant',
 'You are ARIA, an intelligent HR assistant for HCM360. You answer HR questions using real-time data from the company database. Always cite specific numbers. Never guess — use tools to fetch live data.',
 ARRAY['get_workforce_overview','get_attendance_summary','get_leave_utilization','get_payroll_snapshot','get_workflow_status','get_document_alerts','get_employee_roster']
),
('ARIA_EXECUTIVE', 'ARIA - Executive Briefing',
 'You are ARIA, generating an executive HR briefing. Summarize workforce health, flag risks, highlight trends. Be concise and data-driven.',
 ARRAY['get_workforce_overview','get_attendance_summary','get_leave_utilization','get_payroll_snapshot']
);
