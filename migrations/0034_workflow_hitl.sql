-- 0034_workflow_hitl.sql — Human-in-the-loop tasks, cost ledger, cost rollups
-- (merged: 0036 — tables only; node types and workflow column ALTERs already in 0028)

-- ─── HUMAN-IN-THE-LOOP TASK QUEUE ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS workflow_human_tasks (
  id              TEXT PRIMARY KEY,
  run_id          TEXT NOT NULL REFERENCES workflow_runs(id) ON DELETE CASCADE,
  step_id         TEXT REFERENCES workflow_run_steps(id) ON DELETE SET NULL,
  workflow_id     TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  org_id          TEXT REFERENCES organizations(id) ON DELETE SET NULL,

  -- Assignment
  assigned_to     TEXT REFERENCES users(id) ON DELETE SET NULL,
  assigned_role   TEXT,
  assigned_team_id TEXT REFERENCES teams(id) ON DELETE SET NULL,

  -- Task content
  task_title      TEXT NOT NULL,
  instruction_text TEXT,
  input_data      TEXT NOT NULL DEFAULT '{}',
  editable_data   TEXT NOT NULL DEFAULT '{}',
  context_snapshot TEXT NOT NULL DEFAULT '{}',

  -- Status
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK(status IN ('pending','in_review','completed','rejected','skipped','timed_out')),
  decision        TEXT CHECK(decision IN ('approved','rejected','modified',NULL)),
  reviewer_id     TEXT REFERENCES users(id) ON DELETE SET NULL,
  reviewer_note   TEXT,
  output_data     TEXT NOT NULL DEFAULT '{}',

  priority        TEXT NOT NULL DEFAULT 'normal'
                  CHECK(priority IN ('low','normal','high','urgent')),

  deadline_at     TEXT,
  started_review_at TEXT,
  completed_at    TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_hitl_tasks_run_id       ON workflow_human_tasks(run_id);
CREATE INDEX IF NOT EXISTS idx_hitl_tasks_assigned_to  ON workflow_human_tasks(assigned_to, status);
CREATE INDEX IF NOT EXISTS idx_hitl_tasks_workflow_id  ON workflow_human_tasks(workflow_id);
CREATE INDEX IF NOT EXISTS idx_hitl_tasks_status       ON workflow_human_tasks(status, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_hitl_tasks_org_id       ON workflow_human_tasks(org_id, status);
CREATE INDEX IF NOT EXISTS idx_hitl_tasks_deadline     ON workflow_human_tasks(deadline_at ASC);

-- ─── COST RATES ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS workflow_node_cost_rates (
  id              TEXT PRIMARY KEY,
  org_id          TEXT REFERENCES organizations(id) ON DELETE CASCADE,
  node_type_id    TEXT NOT NULL REFERENCES workflow_node_types(id),
  cost_model      TEXT NOT NULL DEFAULT 'per_execution'
                  CHECK(cost_model IN ('per_execution','per_token','per_unit','actual')),
  rate_microcents INTEGER NOT NULL DEFAULT 0,
  unit_label      TEXT,
  currency        TEXT NOT NULL DEFAULT 'USD',
  notes           TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_cost_rates_org_id       ON workflow_node_cost_rates(org_id);
CREATE INDEX IF NOT EXISTS idx_cost_rates_node_type_id ON workflow_node_cost_rates(node_type_id);

-- ─── PER-STEP COST ENTRIES ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS workflow_run_costs (
  id              TEXT PRIMARY KEY,
  run_id          TEXT NOT NULL REFERENCES workflow_runs(id) ON DELETE CASCADE,
  step_id         TEXT REFERENCES workflow_run_steps(id) ON DELETE SET NULL,
  workflow_id     TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  org_id          TEXT REFERENCES organizations(id) ON DELETE SET NULL,
  node_type_id    TEXT NOT NULL,

  cost_model      TEXT NOT NULL,
  units_consumed  REAL,
  unit_label      TEXT,
  cost_microcents INTEGER NOT NULL DEFAULT 0,
  cost_actual_microcents INTEGER,
  currency        TEXT NOT NULL DEFAULT 'USD',

  external_ref    TEXT,
  notes           TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_run_costs_run_id      ON workflow_run_costs(run_id);
CREATE INDEX IF NOT EXISTS idx_run_costs_workflow_id ON workflow_run_costs(workflow_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_run_costs_org_id      ON workflow_run_costs(org_id, created_at DESC);

-- ─── PER-WORKFLOW COST SUMMARY ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS workflow_cost_summary (
  workflow_id               TEXT PRIMARY KEY REFERENCES workflows(id) ON DELETE CASCADE,
  org_id                    TEXT REFERENCES organizations(id) ON DELETE SET NULL,
  total_runs_costed         INTEGER NOT NULL DEFAULT 0,
  total_cost_microcents     INTEGER NOT NULL DEFAULT 0,
  total_ad_spend_microcents INTEGER NOT NULL DEFAULT 0,
  total_ai_cost_microcents  INTEGER NOT NULL DEFAULT 0,
  total_email_cost_microcents INTEGER NOT NULL DEFAULT 0,
  last_run_cost_microcents  INTEGER NOT NULL DEFAULT 0,
  avg_run_cost_microcents   INTEGER NOT NULL DEFAULT 0,
  currency                  TEXT NOT NULL DEFAULT 'USD',
  updated_at                TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ─── MONTHLY ORG COST ROLLUP ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS org_cost_monthly_rollup (
  id              TEXT PRIMARY KEY,
  org_id          TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  year_month      TEXT NOT NULL,
  workflow_runs   INTEGER NOT NULL DEFAULT 0,
  total_cost_microcents       INTEGER NOT NULL DEFAULT 0,
  ad_spend_microcents         INTEGER NOT NULL DEFAULT 0,
  ai_cost_microcents          INTEGER NOT NULL DEFAULT 0,
  email_cost_microcents       INTEGER NOT NULL DEFAULT 0,
  other_cost_microcents       INTEGER NOT NULL DEFAULT 0,
  budget_cap_microcents       INTEGER,
  updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(org_id, year_month)
);

CREATE INDEX IF NOT EXISTS idx_cost_rollup_org_id ON org_cost_monthly_rollup(org_id, year_month DESC);

-- ─── SEED DEFAULT COST RATES ─────────────────────────────────────────────────
INSERT OR IGNORE INTO workflow_node_cost_rates
  (id, org_id, node_type_id, cost_model, rate_microcents, unit_label, notes)
VALUES
  ('rate_extract_keywords_default',  NULL, 'action.extract_keywords',           'per_token',     0, 'token',     'Free when using CF Workers AI; rate set if using OpenAI'),
  ('rate_human_review_default',       NULL, 'action.human_review',               'per_execution', 0, 'task',      'No platform cost; human time tracked via completed_at delta'),
  ('rate_kw_filter_default',          NULL, 'transform.keyword_filter',          'per_execution', 0, 'execution', 'Pure compute — no external API cost'),
  ('rate_fb_ads_estimate_default',    NULL, 'action.facebook_ads_estimate_cost', 'per_execution', 0, 'api_call',  'Meta API read call — no spend'),
  ('rate_fb_ads_create_default',      NULL, 'action.facebook_ads_create',        'actual',        0, 'USD',       'Actual spend from Facebook Ads API response'),
  ('rate_fb_ads_boost_default',       NULL, 'action.facebook_ads_boost_post',    'actual',        0, 'USD',       'Actual spend from Facebook Ads API response'),
  ('rate_google_ads_default',         NULL, 'action.google_ads_create',          'actual',        0, 'USD',       'Actual spend from Google Ads API response');

INSERT INTO _migrations (filename) VALUES ('0034_workflow_hitl.sql');
