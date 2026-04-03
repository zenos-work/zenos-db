-- Migration: 0029_workflow_orchestrator
-- n8n-style visual workflow builder for enterprise content lead-gen routing.
--
-- ARCHITECTURE DECISION (Hybrid SQL + NoSQL):
--  • D1 (this file)   → Relational metadata: ownership, status, versioning, audit, run history summary
--  • Cloudflare KV    → Workflow definition JSON blobs + node credentials (encrypted) — keyed by workflow_id
--  • Durable Objects  → Live workflow execution state machine for real-time orchestration
--
-- A "workflow" is a directed acyclic graph (DAG) of typed nodes connected by edges.
-- Node types: TRIGGER | ACTION | CONDITION | TRANSFORM | DELAY | SUBFLOW
-- Trigger subtypes: article_published, lead_captured, form_submitted, webhook, schedule, manual
-- Action subtypes:  send_email, post_webhook, create_lead, tag_lead, add_to_sequence,
--                   push_to_crm, send_slack, post_social, update_article_status, notify_team

-- ─── WORKFLOW NODE TYPE REGISTRY ──────────────────────────────────────────────
-- Static catalog of available node types & their JSON config schema.
CREATE TABLE IF NOT EXISTS workflow_node_types (
  id              TEXT PRIMARY KEY,   -- e.g. 'trigger.article_published'
  category        TEXT NOT NULL       -- 'trigger','action','condition','transform','delay','subflow'
                  CHECK(category IN ('trigger','action','condition','transform','delay','subflow')),
  name            TEXT NOT NULL,      -- display name
  description     TEXT,
  icon            TEXT,               -- icon slug for UI
  config_schema   TEXT NOT NULL DEFAULT '{}',  -- JSON Schema for node configuration
  output_schema   TEXT NOT NULL DEFAULT '{}',  -- JSON Schema for data emitted by this node
  is_enterprise   INTEGER NOT NULL DEFAULT 0,  -- 1 = enterprise plan only
  is_active       INTEGER NOT NULL DEFAULT 1,
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Seed built-in node types
INSERT OR IGNORE INTO workflow_node_types (id, category, name, description, is_enterprise) VALUES
  ('trigger.article_published',    'trigger',   'Article Published',       'Fires when an article is published',                0),
  ('trigger.article_submitted',    'trigger',   'Article Submitted',       'Fires when article enters review queue',             0),
  ('trigger.lead_captured',        'trigger',   'Lead Captured',           'Fires when a lead form is submitted',                0),
  ('trigger.form_submitted',       'trigger',   'Form Submitted',          'Fires on any custom form submission',                0),
  ('trigger.webhook_inbound',      'trigger',   'Inbound Webhook',         'Fires when the workflow webhook URL is called',      1),
  ('trigger.schedule_cron',        'trigger',   'Schedule (Cron)',         'Fires on a cron schedule',                          1),
  ('trigger.manual',               'trigger',   'Manual Trigger',          'Triggered manually from dashboard',                  0),
  ('trigger.new_follower',         'trigger',   'New Follower',            'Fires when user gains a follower',                   0),
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
  ('condition.if_else',            'condition', 'If / Else',               'Branch based on field comparison',                  0),
  ('condition.switch',             'condition', 'Switch',                  'Multi-branch on an enum value',                    0),
  ('condition.has_tag',            'condition', 'Has Tag',                 'Branch if lead/article has a tag',                  0),
  ('condition.membership_tier',    'condition', 'Membership Tier',         'Branch on user membership tier',                    0),
  ('transform.set_variable',       'transform', 'Set Variable',            'Assign a computed value to a variable',             0),
  ('transform.merge',              'transform', 'Merge',                   'Merge data from multiple branches',                 0),
  ('transform.format',             'transform', 'Format / Template',       'Build a string from template + variables',          0),
  ('delay.wait_duration',          'delay',     'Wait',                    'Pause execution for N seconds/minutes/hours/days',  0),
  ('delay.wait_until',             'delay',     'Wait Until',              'Pause until a specific datetime',                   0),
  ('subflow.call_workflow',        'subflow',   'Call Sub-Workflow',       'Execute another workflow as a step',                1);

-- ─── WORKFLOWS ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS workflows (
  id            TEXT PRIMARY KEY,
  org_id        TEXT REFERENCES organizations(id) ON DELETE CASCADE,
  owner_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  name          TEXT NOT NULL,
  description   TEXT,
  status        TEXT NOT NULL DEFAULT 'draft'
                CHECK(status IN ('draft','active','paused','archived','error')),

  -- Trigger configuration
  trigger_type  TEXT NOT NULL,  -- FK into workflow_node_types.id (category='trigger')

  -- The full DAG definition is stored as a JSON blob in Cloudflare KV under key:
  --   "workflow_def:{id}:{version}"
  -- We keep only the version pointer here for consistency checks.
  definition_version INTEGER NOT NULL DEFAULT 1,

  -- Quick stats (denormalized)
  total_runs    INTEGER NOT NULL DEFAULT 0,
  success_runs  INTEGER NOT NULL DEFAULT 0,
  failed_runs   INTEGER NOT NULL DEFAULT 0,
  last_run_at   TEXT,
  last_run_status TEXT CHECK(last_run_status IN ('success','failed','running',NULL)),

  -- Template / sharing
  is_template   INTEGER NOT NULL DEFAULT 0,
  template_category TEXT,  -- 'lead_gen','content_routing','engagement','onboarding'
  cloned_from   TEXT REFERENCES workflows(id) ON DELETE SET NULL,

  tags          TEXT NOT NULL DEFAULT '[]',  -- JSON array of tag strings

  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_workflows_org_id       ON workflows(org_id);
CREATE INDEX IF NOT EXISTS idx_workflows_owner_id     ON workflows(owner_id);
CREATE INDEX IF NOT EXISTS idx_workflows_status       ON workflows(status);
CREATE INDEX IF NOT EXISTS idx_workflows_trigger_type ON workflows(trigger_type);
CREATE INDEX IF NOT EXISTS idx_workflows_template     ON workflows(is_template);

-- ─── WORKFLOW DEFINITION SNAPSHOTS (version history in D1) ───────────────────
-- Each save creates a new version row. Latest version = highest version_number.
-- Full serialized DAG (nodes + edges + config) lives here AND synced to KV.
CREATE TABLE IF NOT EXISTS workflow_versions (
  id              TEXT PRIMARY KEY,
  workflow_id     TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  version_number  INTEGER NOT NULL,
  definition      TEXT NOT NULL DEFAULT '{}',  -- Full DAG JSON: {nodes:[...], edges:[...]}
  changelog       TEXT,          -- human description of changes
  created_by      TEXT NOT NULL REFERENCES users(id),
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(workflow_id, version_number)
);

CREATE INDEX IF NOT EXISTS idx_wf_versions_workflow_id ON workflow_versions(workflow_id, version_number DESC);

-- ─── WORKFLOW NODES (relational mirror for querying) ─────────────────────────
-- For fast-path queries (e.g. "all email-send actions across org") without
-- deserializing the full definition blob.
CREATE TABLE IF NOT EXISTS workflow_nodes (
  id            TEXT PRIMARY KEY,
  workflow_id   TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  node_type_id  TEXT NOT NULL REFERENCES workflow_node_types(id),
  label         TEXT,
  position_x    REAL NOT NULL DEFAULT 0,  -- canvas coordinates
  position_y    REAL NOT NULL DEFAULT 0,
  -- Encrypted config stored in KV under "wf_node_cfg:{id}"
  -- Non-sensitive display config stored here as JSON
  display_config TEXT NOT NULL DEFAULT '{}',
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_wf_nodes_workflow_id  ON workflow_nodes(workflow_id);
CREATE INDEX IF NOT EXISTS idx_wf_nodes_type         ON workflow_nodes(node_type_id);

-- ─── WORKFLOW EDGES ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS workflow_edges (
  id              TEXT PRIMARY KEY,
  workflow_id     TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  source_node_id  TEXT NOT NULL REFERENCES workflow_nodes(id) ON DELETE CASCADE,
  target_node_id  TEXT NOT NULL REFERENCES workflow_nodes(id) ON DELETE CASCADE,
  -- For condition nodes the edge carries a branch label e.g. 'true','false','default'
  condition_label TEXT,
  UNIQUE(source_node_id, target_node_id, condition_label)
);

CREATE INDEX IF NOT EXISTS idx_wf_edges_workflow_id   ON workflow_edges(workflow_id);
CREATE INDEX IF NOT EXISTS idx_wf_edges_source_node   ON workflow_edges(source_node_id);
CREATE INDEX IF NOT EXISTS idx_wf_edges_target_node   ON workflow_edges(target_node_id);

-- ─── WORKFLOW WEBHOOKS (inbound trigger endpoints) ────────────────────────────
CREATE TABLE IF NOT EXISTS workflow_webhooks (
  id           TEXT PRIMARY KEY,
  workflow_id  TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  node_id      TEXT REFERENCES workflow_nodes(id) ON DELETE SET NULL,
  token        TEXT NOT NULL UNIQUE,   -- random secret in URL path
  method       TEXT NOT NULL DEFAULT 'POST',
  is_active    INTEGER NOT NULL DEFAULT 1,
  last_hit_at  TEXT,
  hit_count    INTEGER NOT NULL DEFAULT 0,
  created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_wf_webhooks_workflow_id ON workflow_webhooks(workflow_id);
CREATE INDEX IF NOT EXISTS idx_wf_webhooks_token       ON workflow_webhooks(token);

-- ─── WORKFLOW RUNS (execution history) ────────────────────────────────────────
-- The live-execution state machine runs inside a Cloudflare Durable Object.
-- Once a run completes (success/failed/cancelled) the summary is written here.
CREATE TABLE IF NOT EXISTS workflow_runs (
  id               TEXT PRIMARY KEY,
  workflow_id      TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  triggered_by     TEXT CHECK(triggered_by IN
                     ('article_published','article_submitted','lead_captured',
                      'form_submitted','webhook','schedule','manual','subflow')),
  trigger_payload  TEXT NOT NULL DEFAULT '{}',  -- JSON snapshot of trigger data
  status           TEXT NOT NULL DEFAULT 'running'
                   CHECK(status IN ('running','success','failed','cancelled','timed_out')),
  started_at       TEXT NOT NULL DEFAULT (datetime('now')),
  finished_at      TEXT,
  duration_ms      INTEGER,    -- total wall-clock time
  steps_total      INTEGER NOT NULL DEFAULT 0,
  steps_succeeded  INTEGER NOT NULL DEFAULT 0,
  steps_failed     INTEGER NOT NULL DEFAULT 0,
  error_message    TEXT,
  -- Context variables available at end of run (for debugging/resume)
  final_context    TEXT NOT NULL DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_wf_runs_workflow_id ON workflow_runs(workflow_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_wf_runs_status      ON workflow_runs(status);
CREATE INDEX IF NOT EXISTS idx_wf_runs_started_at  ON workflow_runs(started_at DESC);

-- ─── WORKFLOW RUN STEPS (per-node execution trace) ───────────────────────────
CREATE TABLE IF NOT EXISTS workflow_run_steps (
  id            TEXT PRIMARY KEY,
  run_id        TEXT NOT NULL REFERENCES workflow_runs(id) ON DELETE CASCADE,
  node_id       TEXT NOT NULL REFERENCES workflow_nodes(id) ON DELETE CASCADE,
  node_type_id  TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'pending'
                CHECK(status IN ('pending','running','success','failed','skipped','retrying')),
  attempt       INTEGER NOT NULL DEFAULT 1,
  input_data    TEXT NOT NULL DEFAULT '{}',   -- JSON: data passed in
  output_data   TEXT NOT NULL DEFAULT '{}',   -- JSON: data emitted
  error_message TEXT,
  started_at    TEXT,
  finished_at   TEXT,
  duration_ms   INTEGER
);

CREATE INDEX IF NOT EXISTS idx_wf_run_steps_run_id  ON workflow_run_steps(run_id);
CREATE INDEX IF NOT EXISTS idx_wf_run_steps_node_id ON workflow_run_steps(node_id);
CREATE INDEX IF NOT EXISTS idx_wf_run_steps_status  ON workflow_run_steps(status);

-- ─── WORKFLOW INTEGRATIONS (per-org credential store references) ──────────────
-- Actual credentials are stored encrypted in Cloudflare KV / Secrets Store.
-- This table is the catalog / metadata layer.
CREATE TABLE IF NOT EXISTS workflow_integrations (
  id            TEXT PRIMARY KEY,
  org_id        TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  integration_type TEXT NOT NULL,  -- 'smtp','sendgrid','mailchimp','hubspot','salesforce',
                                   -- 'slack','zapier','webhook_generic','stripe','custom'
  name          TEXT NOT NULL,     -- user-given label e.g. "Company Mailchimp"
  kv_secret_key TEXT NOT NULL,     -- KV key where encrypted credentials are stored
  is_active     INTEGER NOT NULL DEFAULT 1,
  last_tested_at TEXT,
  created_by    TEXT NOT NULL REFERENCES users(id),
  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_wf_integrations_org_id ON workflow_integrations(org_id);

-- ─── WORKFLOW TEMPLATES MARKETPLACE ───────────────────────────────────────────
-- When is_template=1 on a workflow, it can optionally be listed here for discovery.
CREATE TABLE IF NOT EXISTS workflow_template_listings (
  id            TEXT PRIMARY KEY,
  workflow_id   TEXT NOT NULL UNIQUE REFERENCES workflows(id) ON DELETE CASCADE,
  title         TEXT NOT NULL,
  short_desc    TEXT NOT NULL,
  category      TEXT NOT NULL,   -- 'lead_gen','content_routing','engagement','newsletter','seo'
  use_case_tags TEXT NOT NULL DEFAULT '[]',  -- JSON array
  preview_image TEXT,
  is_public     INTEGER NOT NULL DEFAULT 1,
  download_count INTEGER NOT NULL DEFAULT 0,
  rating_avg    REAL NOT NULL DEFAULT 0,
  rating_count  INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_wf_templates_category ON workflow_template_listings(category);
CREATE INDEX IF NOT EXISTS idx_wf_templates_public   ON workflow_template_listings(is_public);

INSERT INTO _migrations (filename) VALUES ('0029_workflow_orchestrator.sql');
