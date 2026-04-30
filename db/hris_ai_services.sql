-- ================================================================
-- HCM360 AI SERVICES SCHEMA
-- Loaded after: 03_hris_analytics_ai.sql
-- Stores AI sessions, messages, briefings, tool logs, and feedback.
-- ================================================================

-- AI chat sessions
CREATE TABLE ai_sessions (
    id              BIGSERIAL    PRIMARY KEY,
    session_uuid    UUID         NOT NULL DEFAULT uuid_generate_v4() UNIQUE,
    company_id      BIGINT       REFERENCES companies(id),
    user_id         BIGINT       REFERENCES users(id),
    persona         VARCHAR(50)  NOT NULL DEFAULT 'EXECUTIVE',
    -- EXECUTIVE | HR_ADMIN | MANAGER | ANALYST
    title           VARCHAR(300),              -- auto-summarized from first message
    model_used      VARCHAR(100) NOT NULL DEFAULT 'claude-sonnet-4-6',
    message_count   INTEGER      NOT NULL DEFAULT 0,
    token_count_in  INTEGER      NOT NULL DEFAULT 0,
    token_count_out INTEGER      NOT NULL DEFAULT 0,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ai_session_user ON ai_sessions (user_id, created_at DESC);

-- Messages within a session
CREATE TABLE ai_messages (
    id              BIGSERIAL    PRIMARY KEY,
    session_id      BIGINT       NOT NULL REFERENCES ai_sessions(id) ON DELETE CASCADE,
    role            VARCHAR(20)  NOT NULL,     -- user | assistant | tool_result
    content         TEXT         NOT NULL,
    tool_calls      JSONB,                     -- tool invocations by the assistant
    tool_results    JSONB,                     -- results returned to the assistant
    tokens_in       INTEGER,
    tokens_out      INTEGER,
    latency_ms      INTEGER,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ai_msg_session ON ai_messages (session_id, created_at);

-- Tool call audit log (what data the AI accessed)
CREATE TABLE ai_tool_call_logs (
    id              BIGSERIAL    PRIMARY KEY,
    session_id      BIGINT       REFERENCES ai_sessions(id),
    message_id      BIGINT       REFERENCES ai_messages(id),
    user_id         BIGINT       REFERENCES users(id),
    tool_name       VARCHAR(100) NOT NULL,
    tool_inputs     JSONB        NOT NULL DEFAULT '{}',
    result_summary  TEXT,        -- first 500 chars of result
    row_count       INTEGER,
    latency_ms      INTEGER,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tool_log_session ON ai_tool_call_logs (session_id);
CREATE INDEX idx_tool_log_tool    ON ai_tool_call_logs (tool_name, created_at);

-- Executive briefings (scheduled or on-demand AI reports)
CREATE TABLE ai_briefings (
    id              BIGSERIAL    PRIMARY KEY,
    company_id      BIGINT       REFERENCES companies(id),
    user_id         BIGINT       REFERENCES users(id),
    briefing_type   VARCHAR(30)  NOT NULL DEFAULT 'DAILY',
    -- DAILY | WEEKLY | MONTHLY | ON_DEMAND
    briefing_date   DATE         NOT NULL DEFAULT CURRENT_DATE,
    content         TEXT         NOT NULL,     -- full AI-generated briefing text
    content_html    TEXT,                      -- optional rendered HTML
    metrics_snapshot JSONB       NOT NULL DEFAULT '{}',  -- DB values at time of generation
    model_used      VARCHAR(100) NOT NULL DEFAULT 'claude-sonnet-4-6',
    token_count     INTEGER,
    generation_ms   INTEGER,
    status          VARCHAR(20)  NOT NULL DEFAULT 'GENERATED',
    -- GENERATED | DELIVERED | READ | ARCHIVED
    read_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, user_id, briefing_type, briefing_date)
);

CREATE INDEX idx_briefing_user   ON ai_briefings (user_id, briefing_date DESC);
CREATE INDEX idx_briefing_unread ON ai_briefings (user_id, status) WHERE status = 'GENERATED';

-- User feedback on AI responses
CREATE TABLE ai_feedback (
    id              BIGSERIAL    PRIMARY KEY,
    session_id      BIGINT       REFERENCES ai_sessions(id),
    message_id      BIGINT       REFERENCES ai_messages(id),
    user_id         BIGINT       REFERENCES users(id),
    rating          SMALLINT     CHECK (rating IN (1, -1)),  -- 1=thumbs up, -1=thumbs down
    comment         TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- AI persona configuration per role
CREATE TABLE ai_persona_configs (
    id              BIGSERIAL    PRIMARY KEY,
    role_code       VARCHAR(50)  NOT NULL UNIQUE,
    persona_name    VARCHAR(100) NOT NULL,
    system_prompt_addendum TEXT,               -- role-specific additions to system prompt
    available_tools TEXT[]       NOT NULL DEFAULT '{}',  -- restricted tool list
    max_turns       INTEGER      NOT NULL DEFAULT 6,
    max_tokens      INTEGER      NOT NULL DEFAULT 2048,
    greeting_template TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

INSERT INTO ai_persona_configs (role_code, persona_name, greeting_template, max_turns, max_tokens) VALUES
    ('SUPER_ADMIN', 'ARIA — Executive Suite',   'Good {time_of_day}, {name}. Your workforce is ready for review.', 8, 4096),
    ('HR_ADMIN',    'ARIA — HR Operations Hub', 'Hello {name}. Here is your HR operations summary.', 8, 3000),
    ('MANAGER',     'ARIA — Team Intelligence', 'Hi {name}. Here is an overview of your team.', 6, 2048),
    ('EMPLOYEE',    'ARIA — Self Service',      'Hello {name}. How can I help you today?', 4, 1024);
