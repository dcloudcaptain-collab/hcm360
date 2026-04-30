-- ================================================================
-- HCM360 — 56: WORKFORCE PLANNING SCHEMA (missing tables)
--
-- The blueprint at /workforce-planning/ was registered (db 51) but
-- the underlying tables were never created. This migration creates
-- the 4 tables that wfp_service.py references:
--   analytics.wfp_scenarios
--   analytics.wfp_headcount_plans
--   analytics.wfp_cost_projections
--   analytics.wfp_skill_demands
-- ================================================================
SET search_path TO analytics, core, public;


CREATE TABLE IF NOT EXISTS analytics.wfp_scenarios (
    id              BIGSERIAL   PRIMARY KEY,
    company_id      BIGINT      NOT NULL REFERENCES core.companies(id) ON DELETE CASCADE,
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    scenario_type   VARCHAR(40) NOT NULL DEFAULT 'HEADCOUNT'
                      CHECK (scenario_type IN ('HEADCOUNT','COST','SKILLS','STRATEGIC','MIXED')),
    status          VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
                      CHECK (status IN ('DRAFT','ACTIVE','ARCHIVED','CLOSED')),
    base_date       DATE        NOT NULL DEFAULT CURRENT_DATE,
    horizon_months  INT         NOT NULL DEFAULT 12,
    assumptions     JSONB       NOT NULL DEFAULT '{}'::jsonb,
    created_by      BIGINT      REFERENCES core.users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_wfp_scenario_status
    ON analytics.wfp_scenarios (status, updated_at DESC);


CREATE TABLE IF NOT EXISTS analytics.wfp_headcount_plans (
    id               BIGSERIAL PRIMARY KEY,
    scenario_id      BIGINT NOT NULL REFERENCES analytics.wfp_scenarios(id) ON DELETE CASCADE,
    department_id    BIGINT REFERENCES core.departments(id),
    position_id      BIGINT REFERENCES core.positions(id),
    job_grade_id     BIGINT REFERENCES core.job_grades(id),
    period_label     VARCHAR(30),
    period_start     DATE NOT NULL,
    current_hc       INT     NOT NULL DEFAULT 0,
    planned_hc       INT     NOT NULL DEFAULT 0,
    planned_hires    INT     NOT NULL DEFAULT 0,
    planned_exits    INT     NOT NULL DEFAULT 0,
    avg_cost         NUMERIC(14,2) NOT NULL DEFAULT 0,
    total_cost       NUMERIC(14,2) NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (scenario_id, department_id, period_start)
);
CREATE INDEX IF NOT EXISTS idx_wfp_hc_plan_sc
    ON analytics.wfp_headcount_plans (scenario_id, period_start);


CREATE TABLE IF NOT EXISTS analytics.wfp_cost_projections (
    id                BIGSERIAL PRIMARY KEY,
    scenario_id       BIGINT NOT NULL REFERENCES analytics.wfp_scenarios(id) ON DELETE CASCADE,
    period_label      VARCHAR(30),
    period_start      DATE NOT NULL,
    salary_cost       NUMERIC(16,2) NOT NULL DEFAULT 0,
    benefits_cost     NUMERIC(16,2) NOT NULL DEFAULT 0,
    training_cost     NUMERIC(14,2) NOT NULL DEFAULT 0,
    recruitment_cost  NUMERIC(14,2) NOT NULL DEFAULT 0,
    total_cost        NUMERIC(16,2) NOT NULL DEFAULT 0,
    headcount         INT NOT NULL DEFAULT 0,
    cost_per_head     NUMERIC(14,2) NOT NULL DEFAULT 0,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (scenario_id, period_start)
);
CREATE INDEX IF NOT EXISTS idx_wfp_cost_sc
    ON analytics.wfp_cost_projections (scenario_id, period_start);


CREATE TABLE IF NOT EXISTS analytics.wfp_skill_demands (
    id               BIGSERIAL PRIMARY KEY,
    scenario_id      BIGINT NOT NULL REFERENCES analytics.wfp_scenarios(id) ON DELETE CASCADE,
    skill_name       VARCHAR(200) NOT NULL,
    current_supply   INT NOT NULL DEFAULT 0,
    future_demand    INT NOT NULL DEFAULT 0,
    gap              INT GENERATED ALWAYS AS (future_demand - current_supply) STORED,
    priority         VARCHAR(20) NOT NULL DEFAULT 'MEDIUM'
                       CHECK (priority IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    mitigation       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_wfp_skill_sc
    ON analytics.wfp_skill_demands (scenario_id, priority);
