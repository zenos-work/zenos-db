-- 0028_workflow_orchestrator.sql — Core workflow engine tables + seed node types
-- (merged: 0029 + columns from 0036, 0037, 0051)
-- NOTE: workflows references organizations(id); organizations created in 0021.
--       workflow_human_tasks referenced by workflow_runs.waiting_for_task_id is
--       created in 0030_workflow_hitl.sql — deferred FK, safe at runtime.

-- ─── WORKFLOW NODE TYPE REGISTRY ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS workflow_node_types (
  id                      TEXT PRIMARY KEY,
  category                TEXT NOT NULL
                          CHECK(category IN ('trigger','action','condition','transform','delay','subflow')),
  name                    TEXT NOT NULL,
  description             TEXT,
  icon                    TEXT,
  config_schema           TEXT NOT NULL DEFAULT '{}',
  output_schema           TEXT NOT NULL DEFAULT '{}',
  is_enterprise           INTEGER NOT NULL DEFAULT 0,
  is_active               INTEGER NOT NULL DEFAULT 1,
  -- Connector bridge (from 0037)
  connector_definition_id TEXT,   -- REFERENCES connector_definitions(id) — deferred
  connector_action_id     TEXT,   -- REFERENCES connector_actions(id)     — deferred
  created_at              TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ─── WORKFLOWS ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS workflows (
  id                   TEXT PRIMARY KEY,
  org_id               TEXT REFERENCES organizations(id) ON DELETE CASCADE,
  owner_id             TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name                 TEXT NOT NULL,
  description          TEXT,
  status               TEXT NOT NULL DEFAULT 'draft'
                       CHECK(status IN ('draft','active','paused','archived','error')),
  trigger_type         TEXT NOT NULL,
  definition_version   INTEGER NOT NULL DEFAULT 1,
  total_runs           INTEGER NOT NULL DEFAULT 0,
  success_runs         INTEGER NOT NULL DEFAULT 0,
  failed_runs          INTEGER NOT NULL DEFAULT 0,
  last_run_at          TEXT,
  last_run_status      TEXT CHECK(last_run_status IN ('success','failed','running',NULL)),
  is_template          INTEGER NOT NULL DEFAULT 0,
  template_category    TEXT,
  cloned_from          TEXT REFERENCES workflows(id) ON DELETE SET NULL,
  tags                 TEXT NOT NULL DEFAULT '[]',
  -- Approval flow (from 0036)
  approval_status      TEXT DEFAULT 'not_required'
                       CHECK(approval_status IN ('not_required','pending_approval','approved','rejected','changes_requested')),
  approval_required    INTEGER NOT NULL DEFAULT 0,
  approved_by          TEXT REFERENCES users(id) ON DELETE SET NULL,
  approved_at          TEXT,
  approval_note        TEXT,
  -- Scope (from 0036)
  scope_type           TEXT NOT NULL DEFAULT 'manual'
                       CHECK(scope_type IN ('manual','all_author_content','org_wide','tagged_content','team_content')),
  scope_filter         TEXT NOT NULL DEFAULT '{}',
  -- Folder (from 0051)
  folder_id            TEXT,  -- REFERENCES workflow_folders(id) — deferred
  created_at           TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at           TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_workflows_org_id          ON workflows(org_id);
CREATE INDEX IF NOT EXISTS idx_workflows_owner_id        ON workflows(owner_id);
CREATE INDEX IF NOT EXISTS idx_workflows_status          ON workflows(status);
CREATE INDEX IF NOT EXISTS idx_workflows_trigger_type    ON workflows(trigger_type);
CREATE INDEX IF NOT EXISTS idx_workflows_template        ON workflows(is_template);
CREATE INDEX IF NOT EXISTS idx_workflows_approval_status ON workflows(approval_status);
CREATE INDEX IF NOT EXISTS idx_workflows_scope_type      ON workflows(scope_type, owner_id);
CREATE INDEX IF NOT EXISTS idx_workflows_folder_id       ON workflows(folder_id);

-- ─── WORKFLOW VERSIONS ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS workflow_versions (
  id             TEXT PRIMARY KEY,
  workflow_id    TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  version_number INTEGER NOT NULL,
  definition     TEXT NOT NULL DEFAULT '{}',
  changelog      TEXT,
  created_by     TEXT NOT NULL REFERENCES users(id),
  created_at     TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(workflow_id, version_number)
);

CREATE INDEX IF NOT EXISTS idx_wf_versions_workflow_id ON workflow_versions(workflow_id, version_number DESC);

-- ─── WORKFLOW NODES ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS workflow_nodes (
  id                   TEXT PRIMARY KEY,
  workflow_id          TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  node_type_id         TEXT NOT NULL REFERENCES workflow_node_types(id),
  label                TEXT,
  position_x           REAL NOT NULL DEFAULT 0,
  position_y           REAL NOT NULL DEFAULT 0,
  display_config       TEXT NOT NULL DEFAULT '{}',
  -- Connector binding shortcut (from 0037)
  connector_binding_id TEXT,  -- REFERENCES workflow_node_connector_bindings(id) — deferred
  created_at           TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_wf_nodes_workflow_id ON workflow_nodes(workflow_id);
CREATE INDEX IF NOT EXISTS idx_wf_nodes_type        ON workflow_nodes(node_type_id);

-- ─── WORKFLOW EDGES ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS workflow_edges (
  id              TEXT PRIMARY KEY,
  workflow_id     TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  source_node_id  TEXT NOT NULL REFERENCES workflow_nodes(id) ON DELETE CASCADE,
  target_node_id  TEXT NOT NULL REFERENCES workflow_nodes(id) ON DELETE CASCADE,
  condition_label TEXT,
  UNIQUE(source_node_id, target_node_id, condition_label)
);

CREATE INDEX IF NOT EXISTS idx_wf_edges_workflow_id  ON workflow_edges(workflow_id);
CREATE INDEX IF NOT EXISTS idx_wf_edges_source_node  ON workflow_edges(source_node_id);
CREATE INDEX IF NOT EXISTS idx_wf_edges_target_node  ON workflow_edges(target_node_id);

-- ─── WORKFLOW WEBHOOKS ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS workflow_webhooks (
  id          TEXT PRIMARY KEY,
  workflow_id TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  node_id     TEXT REFERENCES workflow_nodes(id) ON DELETE SET NULL,
  token       TEXT NOT NULL UNIQUE,
  method      TEXT NOT NULL DEFAULT 'POST',
  is_active   INTEGER NOT NULL DEFAULT 1,
  last_hit_at TEXT,
  hit_count   INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_wf_webhooks_workflow_id ON workflow_webhooks(workflow_id);
CREATE INDEX IF NOT EXISTS idx_wf_webhooks_token       ON workflow_webhooks(token);

-- ─── WORKFLOW RUNS ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS workflow_runs (
  id                 TEXT PRIMARY KEY,
  workflow_id        TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  triggered_by       TEXT CHECK(triggered_by IN
                       ('article_published','article_submitted','lead_captured',
                        'form_submitted','webhook','schedule','manual','subflow')),
  trigger_payload    TEXT NOT NULL DEFAULT '{}',
  status             TEXT NOT NULL DEFAULT 'running'
                     CHECK(status IN ('running','success','failed','cancelled','timed_out')),
  started_at         TEXT NOT NULL DEFAULT (datetime('now')),
  finished_at        TEXT,
  duration_ms        INTEGER,
  steps_total        INTEGER NOT NULL DEFAULT 0,
  steps_succeeded    INTEGER NOT NULL DEFAULT 0,
  steps_failed       INTEGER NOT NULL DEFAULT 0,
  error_message      TEXT,
  final_context      TEXT NOT NULL DEFAULT '{}',
  -- HITL pause (from 0036)
  waiting_for_task_id TEXT,  -- REFERENCES workflow_human_tasks(id) — deferred
  created_at         TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_wf_runs_workflow_id ON workflow_runs(workflow_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_wf_runs_status      ON workflow_runs(status);
CREATE INDEX IF NOT EXISTS idx_wf_runs_started_at  ON workflow_runs(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_wf_runs_waiting     ON workflow_runs(waiting_for_task_id);

-- ─── WORKFLOW RUN STEPS ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS workflow_run_steps (
  id            TEXT PRIMARY KEY,
  run_id        TEXT NOT NULL REFERENCES workflow_runs(id) ON DELETE CASCADE,
  node_id       TEXT NOT NULL REFERENCES workflow_nodes(id) ON DELETE CASCADE,
  node_type_id  TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'pending'
                CHECK(status IN ('pending','running','success','failed','skipped','retrying')),
  attempt       INTEGER NOT NULL DEFAULT 1,
  input_data    TEXT NOT NULL DEFAULT '{}',
  output_data   TEXT NOT NULL DEFAULT '{}',
  error_message TEXT,
  started_at    TEXT,
  finished_at   TEXT,
  duration_ms   INTEGER
);

CREATE INDEX IF NOT EXISTS idx_wf_run_steps_run_id  ON workflow_run_steps(run_id);
CREATE INDEX IF NOT EXISTS idx_wf_run_steps_node_id ON workflow_run_steps(node_id);
CREATE INDEX IF NOT EXISTS idx_wf_run_steps_status  ON workflow_run_steps(status);

-- ─── WORKFLOW INTEGRATIONS ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS workflow_integrations (
  id                    TEXT PRIMARY KEY,
  org_id                TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  integration_type      TEXT NOT NULL,
  name                  TEXT NOT NULL,
  kv_secret_key         TEXT NOT NULL,
  is_active             INTEGER NOT NULL DEFAULT 1,
  last_tested_at        TEXT,
  created_by            TEXT NOT NULL REFERENCES users(id),
  -- Connector bridge (from 0037)
  connector_instance_id TEXT,  -- REFERENCES connector_instances(id) — deferred
  created_at            TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at            TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_wf_integrations_org_id ON workflow_integrations(org_id);

-- ─── WORKFLOW TEMPLATE LISTINGS ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS workflow_template_listings (
  id             TEXT PRIMARY KEY,
  workflow_id    TEXT NOT NULL UNIQUE REFERENCES workflows(id) ON DELETE CASCADE,
  title          TEXT NOT NULL,
  short_desc     TEXT NOT NULL,
  category       TEXT NOT NULL,
  use_case_tags  TEXT NOT NULL DEFAULT '[]',
  preview_image  TEXT,
  is_public      INTEGER NOT NULL DEFAULT 1,
  download_count INTEGER NOT NULL DEFAULT 0,
  rating_avg     REAL NOT NULL DEFAULT 0,
  rating_count   INTEGER NOT NULL DEFAULT 0,
  created_at     TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_wf_templates_category ON workflow_template_listings(category);
CREATE INDEX IF NOT EXISTS idx_wf_templates_public   ON workflow_template_listings(is_public);

-- ─── WORKFLOW APPROVALS ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS workflow_approvals (
  id             TEXT PRIMARY KEY,
  workflow_id    TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  version_number INTEGER NOT NULL,
  requested_by   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  assigned_to    TEXT REFERENCES users(id) ON DELETE SET NULL,
  status         TEXT NOT NULL DEFAULT 'pending'
                 CHECK(status IN ('pending','approved','rejected','changes_requested','expired')),
  request_note   TEXT,
  review_note    TEXT,
  reviewed_by    TEXT REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at    TEXT,
  expires_at     TEXT,
  created_at     TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at     TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(workflow_id, version_number)
);

CREATE INDEX IF NOT EXISTS idx_wf_approvals_workflow_id  ON workflow_approvals(workflow_id);
CREATE INDEX IF NOT EXISTS idx_wf_approvals_assigned_to  ON workflow_approvals(assigned_to, status);
CREATE INDEX IF NOT EXISTS idx_wf_approvals_requested_by ON workflow_approvals(requested_by);
CREATE INDEX IF NOT EXISTS idx_wf_approvals_status       ON workflow_approvals(status, created_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════════
-- SEED: Built-in node types (from 0029 + 0036 + 0051)
-- ═══════════════════════════════════════════════════════════════════════════════

INSERT OR IGNORE INTO workflow_node_types (id, category, name, description, is_enterprise) VALUES
  -- TRIGGERS (0029)
  ('trigger.article_published',    'trigger',   'Article Published',       'Fires when an article is published',                0),
  ('trigger.article_submitted',    'trigger',   'Article Submitted',       'Fires when article enters review queue',             0),
  ('trigger.lead_captured',        'trigger',   'Lead Captured',           'Fires when a lead form is submitted',                0),
  ('trigger.form_submitted',       'trigger',   'Form Submitted',          'Fires on any custom form submission',                0),
  ('trigger.webhook_inbound',      'trigger',   'Inbound Webhook',         'Fires when the workflow webhook URL is called',      1),
  ('trigger.schedule_cron',        'trigger',   'Schedule (Cron)',         'Fires on a cron schedule',                          1),
  ('trigger.manual',               'trigger',   'Manual Trigger',          'Triggered manually from dashboard',                  0),
  ('trigger.new_follower',         'trigger',   'New Follower',            'Fires when user gains a follower',                   0),
  -- ACTIONS (0029)
  ('action.send_email',            'action',    'Send Email',              'Send a templated email via ESP',                    0),
  ('action.post_webhook',          'action',    'POST Webhook',            'Send HTTP POST to an external URL',                 1),
  ('action.create_lead',           'action',    'Create Lead',             'Add a new lead to lead pipeline',                   0),
  ('action.update_lead',           'action',    'Update Lead',             'Update lead fields or stage',                       0),
  ('action.tag_lead',              'action',    'Tag Lead',                'Apply tags to a lead record',                       0),
  ('action.add_to_sequence',       'action',    'Add to Email Sequence',   'Enrol lead in a drip email sequence',               1),
  ('action.push_to_crm',           'action',    'Push to CRM',             'Sync lead data to external CRM via webhook/API',    1),
  ('action.send_slack',            'action',    'Send Slack Message',      'Post a message to a Slack channel',                 1),
  ('action.post_social',           'action',    'Post to Social',          'Schedule a social post on article publish',         1),
  ('action.notify_team',           'action',    'Notify Team Member',      'Send in-app notification to team',                  0),
  ('action.update_article_status', 'action',    'Update Article Status',   'Change article workflow state programmatically',    1),
  ('action.distribute_content',    'action',    'Distribute Content',      'Push content to distribution channels',             1),
  -- CONDITIONS (0029)
  ('condition.if_else',            'condition', 'If / Else',               'Branch based on field comparison',                  0),
  ('condition.switch',             'condition', 'Switch',                  'Multi-branch on an enum value',                    0),
  ('condition.has_tag',            'condition', 'Has Tag',                 'Branch if lead/article has a tag',                  0),
  ('condition.membership_tier',    'condition', 'Membership Tier',         'Branch on user membership tier',                    0),
  -- TRANSFORMS (0029)
  ('transform.set_variable',       'transform', 'Set Variable',            'Assign a computed value to a variable',             0),
  ('transform.merge',              'transform', 'Merge',                   'Merge data from multiple branches',                 0),
  ('transform.format',             'transform', 'Format / Template',       'Build a string from template + variables',          0),
  -- DELAYS (0029)
  ('delay.wait_duration',          'delay',     'Wait',                    'Pause execution for N seconds/minutes/hours/days',  0),
  ('delay.wait_until',             'delay',     'Wait Until',              'Pause until a specific datetime',                   0),
  -- SUBFLOW (0029)
  ('subflow.call_workflow',        'subflow',   'Call Sub-Workflow',       'Execute another workflow as a step',                1);

-- HITL + Facebook Ads node types (from 0036) with full config_schema
INSERT OR IGNORE INTO workflow_node_types (id, category, name, description, is_enterprise, config_schema, output_schema) VALUES
  ('action.extract_keywords',         'action',    'Extract Keywords',              'Run AI/NLP keyword extraction on the article body.',                     0, '{"properties":{"model":{"type":"string","enum":["cf-workers-ai","openai","custom_api"],"default":"cf-workers-ai"},"max_keywords":{"type":"integer","default":20}}}', '{"properties":{"keywords":{"type":"array"},"article_id":{"type":"string"}}}'),
  ('action.human_review',             'action',    'Human Review',                  'Pause workflow and assign a review task to a team member.',               0, '{"properties":{"assignee_type":{"type":"string","enum":["specific_user","team","role","workflow_owner"],"default":"workflow_owner"},"timeout_hours":{"type":"integer","default":48}}}', '{"properties":{"decision":{"type":"string","enum":["approved","rejected","modified"]},"reviewer_id":{"type":"string"}}}'),
  ('transform.keyword_filter',        'transform', 'Filter & Rank Keywords',        'Remove duplicates, apply blocklist, rank by score.',                     0, '{"properties":{"max_output":{"type":"integer","default":10},"min_score":{"type":"number","default":0.3}}}', '{"properties":{"keywords":{"type":"array"},"removed_count":{"type":"integer"}}}'),
  ('condition.keywords_changed',      'condition', 'Keywords Changed?',             'Branch YES if human reviewer modified the keyword list.',                0, '{}', '{"properties":{"changed":{"type":"boolean"}}}'),
  ('action.facebook_ads_estimate_cost','action',   'Facebook Ads — Estimate Cost',  'Call Facebook Marketing API for projected reach and cost.',              1, '{"properties":{"integration_id":{"type":"string"},"budget_daily_cents":{"type":"integer"}}}', '{"properties":{"estimated_reach_min":{"type":"integer"},"estimated_total_spend_cents":{"type":"integer"}}}'),
  ('condition.cost_within_budget',    'condition', 'Cost Within Budget?',           'Branch YES if estimated spend ≤ budget cap.',                            0, '{"properties":{"budget_cap_cents":{"type":"integer"}}}', '{"properties":{"within_budget":{"type":"boolean"}}}'),
  ('action.facebook_ads_create',      'action',    'Facebook Ads — Create Campaign','Create an ad campaign in Facebook Ads Manager.',                        1, '{"properties":{"integration_id":{"type":"string"},"campaign_objective":{"type":"string"},"budget_daily_cents":{"type":"integer"}}}', '{"properties":{"campaign_id":{"type":"string"},"status":{"type":"string"}}}'),
  ('action.facebook_ads_boost_post',  'action',    'Facebook Ads — Boost Post',    'Boost an existing Facebook page post.',                                 1, '{"properties":{"integration_id":{"type":"string"},"page_post_id":{"type":"string"},"budget_total_cents":{"type":"integer"}}}', '{"properties":{"boost_id":{"type":"string"}}}'),
  ('action.google_ads_create',        'action',    'Google Ads — Create Campaign', 'Create a Google Ads search/display campaign.',                          1, '{"properties":{"integration_id":{"type":"string"},"keywords":{"type":"array"},"budget_daily_cents":{"type":"integer"}}}', '{"properties":{"campaign_id":{"type":"string"},"status":{"type":"string"}}}');

-- Enterprise node types (from 0051)
INSERT OR IGNORE INTO workflow_node_types (id, category, name, description, is_enterprise, config_schema, output_schema) VALUES
  ('action.escalate',            'action',    'Escalate',                'Escalate to higher-authority reviewer.',                        0, '{"properties":{"escalate_to":{"type":"string","enum":["superadmin","org_owner","specific_user","specific_team"]},"priority":{"type":"string","enum":["high","urgent"]}}}', '{"properties":{"task_id":{"type":"string"}}}'),
  ('action.auto_publish',        'action',    'Auto-Publish',            'Automatically publish the triggering article.',                 0, '{"properties":{"set_featured":{"type":"boolean","default":false}}}', '{"properties":{"article_id":{"type":"string"},"published_at":{"type":"string"}}}'),
  ('action.auto_reject',         'action',    'Auto-Reject',             'Automatically reject content and notify author.',               1, '{"properties":{"reason_template":{"type":"string"},"notify_author":{"type":"boolean","default":true}}}', '{"properties":{"article_id":{"type":"string"}}}'),
  ('condition.security_level',   'condition', 'Security Level Check',    'Branch based on article security classification.',              1, '{"properties":{"levels":{"type":"array"}}}', '{"properties":{"matched":{"type":"boolean"}}}'),
  ('condition.content_type',     'condition', 'Content Type Check',      'Branch based on article content type.',                         0, '{"properties":{"accepted_types":{"type":"array"}}}', '{"properties":{"matched":{"type":"boolean"}}}'),
  ('condition.is_premium',       'condition', 'Is Premium Content?',     'Branch YES if article.premium_only = 1.',                       0, '{}', '{"properties":{"is_premium":{"type":"boolean"}}}'),
  ('condition.author_is_new',    'condition', 'Author Is New?',          'Branch YES if author created within N days.',                   0, '{"properties":{"days_threshold":{"type":"integer","default":30}}}', '{"properties":{"is_new":{"type":"boolean"}}}'),
  ('condition.topic_sensitive',  'condition', 'Topic Is Sensitive?',     'Branch YES if tags match sensitive-topics.',                    0, '{"properties":{"sensitive_topics":{"type":"array"}}}', '{"properties":{"is_sensitive":{"type":"boolean"}}}'),
  ('transform.parallel_split',   'transform', 'Parallel Split',          'Fan out to multiple branches simultaneously.',                 1, '{"properties":{"branch_count":{"type":"integer","default":2}}}', '{"properties":{"branch_index":{"type":"integer"}}}'),
  ('transform.parallel_join',    'transform', 'Parallel Join',           'Wait for all upstream parallel branches.',                     1, '{"properties":{"merge_strategy":{"type":"string","enum":["all","first","majority"]}}}', '{"properties":{"branches_completed":{"type":"integer"}}}'),
  ('transform.loop',             'transform', 'Loop / For-Each',         'Iterate over an array and execute children per item.',         1, '{"properties":{"source_variable":{"type":"string"},"max_iterations":{"type":"integer","default":100}}}', '{"properties":{"total_iterations":{"type":"integer"}}}'),
  ('action.error_handler',       'action',    'Error Handler / Catch',   'Catch errors from upstream nodes.',                            1, '{"properties":{"retry_count":{"type":"integer","default":3},"on_exhausted":{"type":"string","enum":["fail","skip","notify","fallback_node"]}}}', '{"properties":{"recovered":{"type":"boolean"}}}'),
  ('delay.business_hours',       'delay',     'Wait (Business Hours)',   'Pause for N business hours, skipping weekends.',               1, '{"properties":{"hours":{"type":"integer","default":8},"timezone":{"type":"string","default":"UTC"}}}', '{"properties":{"resumed_at":{"type":"string"}}}');

INSERT INTO _migrations (filename) VALUES ('0028_workflow_orchestrator.sql');
