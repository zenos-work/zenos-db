-- Migration: 0036_workflow_hitl_approval_costs
-- Fills the four gaps identified for the human-in-the-loop keyword→Facebook pipeline:
--
--  GAP-1  HITL task queue     → workflow_human_tasks
--  GAP-2  Workflow approval   → workflow_approvals + ALTER workflows (approval_* cols + scope)
--  GAP-3  Cost ledger         → workflow_run_costs + workflow_node_cost_rates
--  GAP-4  Missing node types  → INSERT into workflow_node_types:
--           action.extract_keywords, action.human_review,
--           action.facebook_ads_create, action.facebook_ads_estimate_cost,
--           action.facebook_ads_boost_post, transform.keyword_filter,
--           condition.keywords_changed, condition.cost_within_budget
--
-- Described pipeline this enables:
--   TRIGGER article_published
--     → extract_keywords  (AI → CF Workers AI / external NLP)
--     → human_review      (PAUSE: reviewer edits keyword list)
--     ← resume with approved_keywords
--     → keyword_filter    (transform: rank / deduplicate)
--     → facebook_ads_estimate_cost  (returns projected spend)
--     → condition: cost_within_budget?  YES → facebook_ads_create
--                                        NO  → notify_team (cost alert)
--     → notify_team       (share result with author)
--
-- Workflow definition approval flow:
--   Author builds workflow (approval_status='pending_approval')
--   → Lead reviews in approval queue
--   → Approves/rejects (approval_status='approved'|'rejected')
--   → Once approved, scope_type drives auto-trigger on all author content

-- ─── GAP-4: NEW NODE TYPES ────────────────────────────────────────────────────
INSERT OR IGNORE INTO workflow_node_types
  (id, category, name, description, is_enterprise, config_schema, output_schema)
VALUES
  -- AI / NLP
  ('action.extract_keywords',
   'action', 'Extract Keywords',
   'Run AI/NLP keyword extraction on the article body. Outputs a ranked keyword list.',
   0,
   '{"properties":{"model":{"type":"string","enum":["cf-workers-ai","openai","custom_api"],"default":"cf-workers-ai"},"max_keywords":{"type":"integer","default":20},"include_phrases":{"type":"boolean","default":true},"language":{"type":"string","default":"en"}}}',
   '{"properties":{"keywords":{"type":"array","items":{"type":"object","properties":{"term":{"type":"string"},"score":{"type":"number"},"frequency":{"type":"integer"}}}},"article_id":{"type":"string"}}}'
  ),

  -- Human-in-the-loop review gate
  ('action.human_review',
   'action', 'Human Review',
   'Pause the workflow and assign a review task to a team member. Execution resumes when the reviewer submits their decision.',
   0,
   '{"properties":{"assignee_type":{"type":"string","enum":["specific_user","team","role","workflow_owner"],"default":"workflow_owner"},"assignee_id":{"type":"string","description":"User/team/role id; omit for workflow_owner"},"task_title":{"type":"string"},"instruction_text":{"type":"string","description":"Instructions shown to reviewer in the task UI"},"editable_fields":{"type":"array","items":{"type":"string"},"description":"Variable names the reviewer can edit e.g. [\"keywords\"]"},"timeout_hours":{"type":"integer","default":48,"description":"Auto-skip/fail task after this many hours"},"on_timeout":{"type":"string","enum":["skip","fail","auto_approve"],"default":"fail"}}}',
   '{"properties":{"decision":{"type":"string","enum":["approved","rejected","modified"]},"reviewer_id":{"type":"string"},"reviewed_at":{"type":"string"},"edited_fields":{"type":"object","description":"Map of field_name → new_value set by reviewer"}}}'
  ),

  -- Keyword transform
  ('transform.keyword_filter',
   'transform', 'Filter & Rank Keywords',
   'Remove duplicates, apply blocklist, rank by score. Outputs clean keyword list.',
   0,
   '{"properties":{"max_output":{"type":"integer","default":10},"blocklist_terms":{"type":"array","items":{"type":"string"}},"min_score":{"type":"number","default":0.3},"deduplicate":{"type":"boolean","default":true}}}',
   '{"properties":{"keywords":{"type":"array","items":{"type":"string"}},"removed_count":{"type":"integer"}}}'
  ),

  -- Condition: did the reviewer change the keyword list?
  ('condition.keywords_changed',
   'condition', 'Keywords Changed?',
   'Branch YES if the human reviewer modified the keyword list, NO if unchanged.',
   0,
   '{}',
   '{"properties":{"changed":{"type":"boolean"},"added":{"type":"array"},"removed":{"type":"array"}}}'
  ),

  -- Facebook Ads — cost estimate (read-only, no budget spent)
  ('action.facebook_ads_estimate_cost',
   'action', 'Facebook Ads — Estimate Cost',
   'Call Facebook Marketing API to get a projected reach and cost for the given keywords and budget. No campaign created.',
   1,
   '{"properties":{"integration_id":{"type":"string","description":"workflow_integrations.id for Facebook App credentials"},"ad_account_id":{"type":"string"},"targeting_keywords":{"type":"array","items":{"type":"string"}},"budget_daily_cents":{"type":"integer","description":"Proposed daily budget in cents"},"campaign_objective":{"type":"string","enum":["LINK_CLICKS","REACH","LEAD_GENERATION","CONVERSIONS"],"default":"LINK_CLICKS"},"duration_days":{"type":"integer","default":7}}}',
   '{"properties":{"estimated_reach_min":{"type":"integer"},"estimated_reach_max":{"type":"integer"},"estimated_total_spend_cents":{"type":"integer"},"cpc_estimate_cents":{"type":"integer"},"cpm_estimate_cents":{"type":"integer"},"currency":{"type":"string"}}}'
  ),

  -- Condition: is the estimated cost within the configured budget cap?
  ('condition.cost_within_budget',
   'condition', 'Cost Within Budget?',
   'Branch YES if estimated_total_spend_cents ≤ configured budget cap.',
   0,
   '{"properties":{"budget_cap_cents":{"type":"integer","description":"Maximum acceptable spend in cents"}}}',
   '{"properties":{"within_budget":{"type":"boolean"},"estimated_cents":{"type":"integer"},"cap_cents":{"type":"integer"}}}'
  ),

  -- Facebook Ads — create campaign
  ('action.facebook_ads_create',
   'action', 'Facebook Ads — Create Campaign',
   'Create an ad campaign in Facebook Ads Manager using article content + approved keywords as targeting.',
   1,
   '{"properties":{"integration_id":{"type":"string"},"ad_account_id":{"type":"string"},"campaign_name_template":{"type":"string","default":"{{article.title}} - {{date}}"},"campaign_objective":{"type":"string","enum":["LINK_CLICKS","REACH","LEAD_GENERATION","CONVERSIONS"],"default":"LINK_CLICKS"},"targeting_keywords":{"type":"array","items":{"type":"string"}},"budget_daily_cents":{"type":"integer"},"start_time":{"type":"string","description":"ISO 8601; omit for immediate"},"end_time":{"type":"string"},"ad_creative_source":{"type":"string","enum":["article_meta","custom"],"default":"article_meta"},"custom_headline":{"type":"string"},"custom_body":{"type":"string"},"custom_image_url":{"type":"string"}}}',
   '{"properties":{"campaign_id":{"type":"string"},"adset_id":{"type":"string"},"ad_id":{"type":"string"},"campaign_url":{"type":"string"},"status":{"type":"string"},"budget_daily_cents":{"type":"integer"},"currency":{"type":"string"}}}'
  ),

  -- Facebook Ads — boost an existing post
  ('action.facebook_ads_boost_post',
   'action', 'Facebook Ads — Boost Post',
   'Boost an existing Facebook page post with a budget and audience.',
   1,
   '{"properties":{"integration_id":{"type":"string"},"page_post_id":{"type":"string"},"budget_total_cents":{"type":"integer"},"duration_days":{"type":"integer","default":3},"targeting_keywords":{"type":"array"}}}',
   '{"properties":{"boost_id":{"type":"string"},"spend_cap_cents":{"type":"integer"},"status":{"type":"string"}}}'
  ),

  -- Google Ads equivalent (future, keeps schema consistent)
  ('action.google_ads_create',
   'action', 'Google Ads — Create Campaign',
   'Create a Google Ads search/display campaign using article keywords.',
   1,
   '{"properties":{"integration_id":{"type":"string"},"customer_id":{"type":"string"},"campaign_name_template":{"type":"string"},"keywords":{"type":"array"},"budget_daily_cents":{"type":"integer"},"campaign_type":{"type":"string","enum":["SEARCH","DISPLAY","SMART"],"default":"SEARCH"}}}',
   '{"properties":{"campaign_id":{"type":"string"},"status":{"type":"string"},"budget_daily_cents":{"type":"integer"}}}'
  );

-- ─── GAP-2: WORKFLOW APPROVAL FLOW ───────────────────────────────────────────
-- Add approval lifecycle and content-scope columns to workflows.
-- Scope controls whether the workflow auto-triggers on all author content
-- or only when manually invoked.

ALTER TABLE workflows ADD COLUMN approval_status TEXT DEFAULT 'not_required'
  CHECK(approval_status IN ('not_required','pending_approval','approved','rejected','changes_requested'));
ALTER TABLE workflows ADD COLUMN approval_required INTEGER NOT NULL DEFAULT 0;
ALTER TABLE workflows ADD COLUMN approved_by   TEXT REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE workflows ADD COLUMN approved_at   TEXT;
ALTER TABLE workflows ADD COLUMN approval_note TEXT;  -- reviewer's comment

-- Scope: who/what does this workflow auto-trigger for?
ALTER TABLE workflows ADD COLUMN scope_type TEXT NOT NULL DEFAULT 'manual'
  CHECK(scope_type IN (
    'manual',               -- only runs when explicitly triggered from UI
    'all_author_content',   -- auto-runs for every article published by owner
    'org_wide',             -- auto-runs for every article published in the org
    'tagged_content',       -- auto-runs for articles matching scope_filter tags
    'team_content'          -- auto-runs for all members of a specific team
  ));
ALTER TABLE workflows ADD COLUMN scope_filter TEXT NOT NULL DEFAULT '{}';
-- scope_filter examples:
--   tagged_content:    {"tags": ["marketing","product"]}
--   team_content:      {"team_id": "team_abc"}
--   all_author_content: {} (no filter needed)

CREATE INDEX IF NOT EXISTS idx_workflows_approval_status ON workflows(approval_status);
CREATE INDEX IF NOT EXISTS idx_workflows_scope_type      ON workflows(scope_type, owner_id);

-- ─── WORKFLOW APPROVAL REQUESTS ───────────────────────────────────────────────
-- Formal approval requests submitted by workflow owners to their lead/org admin.
CREATE TABLE IF NOT EXISTS workflow_approvals (
  id              TEXT PRIMARY KEY,
  workflow_id     TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  version_number  INTEGER NOT NULL,    -- which version is being approved
  requested_by    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  assigned_to     TEXT REFERENCES users(id) ON DELETE SET NULL,  -- specific lead assigned; NULL = org admins
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK(status IN ('pending','approved','rejected','changes_requested','expired')),
  request_note    TEXT,    -- submitter's description of what the workflow does and why
  review_note     TEXT,    -- reviewer's decision comment
  reviewed_by     TEXT REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at     TEXT,
  expires_at      TEXT,    -- auto-expire if no action taken
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(workflow_id, version_number)   -- one open request per version
);

CREATE INDEX IF NOT EXISTS idx_wf_approvals_workflow_id  ON workflow_approvals(workflow_id);
CREATE INDEX IF NOT EXISTS idx_wf_approvals_assigned_to  ON workflow_approvals(assigned_to, status);
CREATE INDEX IF NOT EXISTS idx_wf_approvals_requested_by ON workflow_approvals(requested_by);
CREATE INDEX IF NOT EXISTS idx_wf_approvals_status       ON workflow_approvals(status, created_at DESC);

-- ─── GAP-1: HUMAN-IN-THE-LOOP TASK QUEUE ─────────────────────────────────────
-- When a workflow run hits an `action.human_review` node, the Durable Object
-- inserts a row here and suspends execution (sets run status to 'waiting_for_human').
-- Reviewer finds the task in their dashboard, edits the data, and submits.
-- The Worker then calls DO.resume(run_id, task_id, outcome) to continue execution.
CREATE TABLE IF NOT EXISTS workflow_human_tasks (
  id              TEXT PRIMARY KEY,
  run_id          TEXT NOT NULL REFERENCES workflow_runs(id) ON DELETE CASCADE,
  step_id         TEXT REFERENCES workflow_run_steps(id) ON DELETE SET NULL,
  workflow_id     TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  org_id          TEXT REFERENCES organizations(id) ON DELETE SET NULL,

  -- Assignment
  assigned_to     TEXT REFERENCES users(id) ON DELETE SET NULL,  -- specific user
  assigned_role   TEXT,   -- fallback: any user with this org_role can action
  assigned_team_id TEXT REFERENCES teams(id) ON DELETE SET NULL,

  -- Task content (what the reviewer sees)
  task_title      TEXT NOT NULL,
  instruction_text TEXT,
  -- The data the reviewer can inspect and optionally edit (JSON)
  input_data      TEXT NOT NULL DEFAULT '{}',
  -- The editable fields and their current values
  editable_data   TEXT NOT NULL DEFAULT '{}',
  -- Context snapshot: article_id, title, etc. for display in task UI
  context_snapshot TEXT NOT NULL DEFAULT '{}',

  -- Status
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK(status IN ('pending','in_review','completed','rejected','skipped','timed_out')),
  -- Reviewer's decision
  decision        TEXT CHECK(decision IN ('approved','rejected','modified',NULL)),
  reviewer_id     TEXT REFERENCES users(id) ON DELETE SET NULL,
  reviewer_note   TEXT,
  -- What the reviewer submitted (merged back into workflow context on resume)
  output_data     TEXT NOT NULL DEFAULT '{}',

  priority        TEXT NOT NULL DEFAULT 'normal'
                  CHECK(priority IN ('low','normal','high','urgent')),

  deadline_at     TEXT,    -- NULL = no hard deadline
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

-- Extend workflow_runs to hold the waiting state
-- (SQLite does not support modifying CHECK constraints; add a separate flag column)
ALTER TABLE workflow_runs ADD COLUMN waiting_for_task_id TEXT
  REFERENCES workflow_human_tasks(id) ON DELETE SET NULL;
-- waiting_for_task_id NOT NULL   ↔   run is paused at a human_review node

CREATE INDEX IF NOT EXISTS idx_wf_runs_waiting ON workflow_runs(waiting_for_task_id);

-- ─── GAP-3: COST LEDGER ───────────────────────────────────────────────────────
-- Per-node cost rates (configurable by org admin or superadmin defaults).
-- Supports: API call costs, AI token costs, ad platform spend, email send costs.
CREATE TABLE IF NOT EXISTS workflow_node_cost_rates (
  id              TEXT PRIMARY KEY,
  org_id          TEXT REFERENCES organizations(id) ON DELETE CASCADE,  -- NULL = global default
  node_type_id    TEXT NOT NULL REFERENCES workflow_node_types(id),
  cost_model      TEXT NOT NULL DEFAULT 'per_execution'
                  CHECK(cost_model IN ('per_execution','per_token','per_unit','actual')),
  -- 'actual'     = cost is determined at runtime from API response (e.g. ad spend)
  -- 'per_token'  = cost = tokens_used * rate_per_token_microcents
  -- 'per_unit'   = cost = units * rate_per_unit_microcents
  -- 'per_execution' = flat cost per node execution
  rate_microcents INTEGER NOT NULL DEFAULT 0,  -- cost in microcents (1 cent = 1000 microcents)
  unit_label      TEXT,    -- e.g. 'token', 'email', 'api_call', 'impression'
  currency        TEXT NOT NULL DEFAULT 'USD',
  notes           TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_cost_rates_org_id       ON workflow_node_cost_rates(org_id);
CREATE INDEX IF NOT EXISTS idx_cost_rates_node_type_id ON workflow_node_cost_rates(node_type_id);

-- Per-step cost entries recorded during/after execution.
CREATE TABLE IF NOT EXISTS workflow_run_costs (
  id              TEXT PRIMARY KEY,
  run_id          TEXT NOT NULL REFERENCES workflow_runs(id) ON DELETE CASCADE,
  step_id         TEXT REFERENCES workflow_run_steps(id) ON DELETE SET NULL,
  workflow_id     TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  org_id          TEXT REFERENCES organizations(id) ON DELETE SET NULL,
  node_type_id    TEXT NOT NULL,

  cost_model      TEXT NOT NULL,
  -- Raw usage quantities
  units_consumed  REAL,        -- tokens, emails, API calls, impressions
  unit_label      TEXT,
  -- Calculated costs
  cost_microcents INTEGER NOT NULL DEFAULT 0,  -- computed: units * rate OR actual from API
  cost_actual_microcents INTEGER,              -- if 'actual' model: real spend from platform
  currency        TEXT NOT NULL DEFAULT 'USD',

  -- External cost reference (e.g. Facebook campaign budget)
  external_ref    TEXT,    -- Facebook campaign_id, Stripe charge_id, etc.
  notes           TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_run_costs_run_id      ON workflow_run_costs(run_id);
CREATE INDEX IF NOT EXISTS idx_run_costs_workflow_id ON workflow_run_costs(workflow_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_run_costs_org_id      ON workflow_run_costs(org_id, created_at DESC);

-- Per-workflow cost aggregate (updated after each run via background task).
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

-- Monthly cost rollup per org (powers billing and cost dashboard).
CREATE TABLE IF NOT EXISTS org_cost_monthly_rollup (
  id              TEXT PRIMARY KEY,
  org_id          TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  year_month      TEXT NOT NULL,  -- 'YYYY-MM' e.g. '2026-03'
  workflow_runs   INTEGER NOT NULL DEFAULT 0,
  total_cost_microcents       INTEGER NOT NULL DEFAULT 0,
  ad_spend_microcents         INTEGER NOT NULL DEFAULT 0,
  ai_cost_microcents          INTEGER NOT NULL DEFAULT 0,
  email_cost_microcents       INTEGER NOT NULL DEFAULT 0,
  other_cost_microcents       INTEGER NOT NULL DEFAULT 0,
  budget_cap_microcents       INTEGER,  -- org's configured monthly budget
  updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(org_id, year_month)
);

CREATE INDEX IF NOT EXISTS idx_cost_rollup_org_id ON org_cost_monthly_rollup(org_id, year_month DESC);

-- Default global cost rates for new node types seeded above
INSERT OR IGNORE INTO workflow_node_cost_rates
  (id, org_id, node_type_id, cost_model, rate_microcents, unit_label, notes)
VALUES
  ('rate_extract_keywords_default',  NULL, 'action.extract_keywords',           'per_token',     0, 'token',     'Free when using CF Workers AI; rate set if using OpenAI'),
  ('rate_human_review_default',       NULL, 'action.human_review',               'per_execution', 0, 'task',      'No platform cost; human time is tracked via completed_at delta'),
  ('rate_kw_filter_default',          NULL, 'transform.keyword_filter',          'per_execution', 0, 'execution', 'Pure compute — no external API cost'),
  ('rate_fb_ads_estimate_default',    NULL, 'action.facebook_ads_estimate_cost', 'per_execution', 0, 'api_call',  'Meta API read call — no spend'),
  ('rate_fb_ads_create_default',      NULL, 'action.facebook_ads_create',        'actual',        0, 'USD',       'Actual spend recorded from Facebook Ads API response'),
  ('rate_fb_ads_boost_default',       NULL, 'action.facebook_ads_boost_post',    'actual',        0, 'USD',       'Actual spend recorded from Facebook Ads API response'),
  ('rate_google_ads_default',         NULL, 'action.google_ads_create',          'actual',        0, 'USD',       'Actual spend recorded from Google Ads API response');

INSERT INTO _migrations (filename) VALUES ('0036_workflow_hitl_approval_costs.sql');
