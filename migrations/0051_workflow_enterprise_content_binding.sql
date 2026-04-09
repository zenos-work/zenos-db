-- Migration: 0051_workflow_enterprise_content_binding
--
-- Bridges the gap between the existing workflow orchestrator (0029/0036/0037) and
-- the Medium Maker Pro visual builder + n8n / Oracle SOA orchestration requirements:
--
--  1. CONTENT BINDING    — bind workflows to articles/org content by pattern, tag, security
--  2. WORKFLOW ROLES/ACL — granular permission on who can build/run/approve workflows
--  3. WORKFLOW MESSAGES  — integrated reviewer↔author communication thread per run
--  4. WORKFLOW POLICIES  — enterprise security policies (rate limits, audit, IP allow-list)
--  5. ADDITIONAL NODES   — review, escalation, auto_publish, delay (Medium-style)
--  6. PRICING TIER GATE  — workflows provisioned by org plan tier
--  7. WORKFLOW FOLDERS    — organize workflows into folders/categories
--  8. WORKFLOW SCHEDULES  — detached from cron trigger; reusable schedule definitions

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. CONTENT–WORKFLOW BINDING
-- ═══════════════════════════════════════════════════════════════════════════════
-- Maps which workflows apply to which content.  A single article can match
-- multiple workflows (e.g. a content-review workflow AND a distribution workflow).
-- The binding is resolved at trigger time using priority ordering.

CREATE TABLE IF NOT EXISTS workflow_content_bindings (
  id              TEXT PRIMARY KEY,
  workflow_id     TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  org_id          TEXT REFERENCES organizations(id) ON DELETE CASCADE,

  -- Binding method (how do we match content to this workflow?)
  bind_type       TEXT NOT NULL DEFAULT 'all_org_content'
                  CHECK(bind_type IN (
                    'all_org_content',     -- every article in the org goes through this
                    'by_tag',              -- articles with specific tags
                    'by_content_type',     -- articles of a specific content_type slug
                    'by_author',           -- articles by specific author(s)
                    'by_team',             -- articles by members of a team
                    'by_security_level',   -- articles marked with a sensitivity/classification
                    'by_premium_status',   -- premium-only vs free articles
                    'by_regex_title',      -- regex match on article title
                    'manual_selection'     -- manually assigned per article
                  )),

  -- The matching criteria (JSON, shape depends on bind_type)
  -- Examples:
  --   by_tag:            {"tags":["marketing","product-launch"]}
  --   by_content_type:   {"content_types":["tutorial","case_study"]}
  --   by_author:         {"author_ids":["user_abc","user_def"]}
  --   by_team:           {"team_id":"team_xyz"}
  --   by_security_level: {"levels":["confidential","internal"]}
  --   by_premium_status: {"premium_only":true}
  --   by_regex_title:    {"pattern":"^\\[RELEASE\\].*"}
  bind_criteria   TEXT NOT NULL DEFAULT '{}',

  -- Trigger event (when in the content lifecycle does this workflow fire?)
  trigger_event   TEXT NOT NULL DEFAULT 'on_submit'
                  CHECK(trigger_event IN (
                    'on_create',           -- draft created
                    'on_submit',           -- submitted for review
                    'on_approve',          -- approved by reviewer
                    'on_publish',          -- published
                    'on_update',           -- content updated after publish
                    'on_unpublish',        -- taken down
                    'on_schedule',         -- scheduled for future publish
                    'on_expire'            -- content reached expiry date
                  )),

  -- Priority: lower number = higher priority (evaluated first)
  priority        INTEGER NOT NULL DEFAULT 100,

  -- Is this binding active?
  is_active       INTEGER NOT NULL DEFAULT 1,

  created_by      TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(workflow_id, bind_type, trigger_event)
);

CREATE INDEX IF NOT EXISTS idx_wf_bindings_workflow_id ON workflow_content_bindings(workflow_id);
CREATE INDEX IF NOT EXISTS idx_wf_bindings_org_id      ON workflow_content_bindings(org_id, is_active);
CREATE INDEX IF NOT EXISTS idx_wf_bindings_bind_type   ON workflow_content_bindings(bind_type);
CREATE INDEX IF NOT EXISTS idx_wf_bindings_trigger     ON workflow_content_bindings(trigger_event, is_active);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. WORKFLOW ROLE-BASED ACCESS CONTROL
-- ═══════════════════════════════════════════════════════════════════════════════
-- Fine-grained permissions per workflow. Supplements org_members.org_role with
-- workflow-specific grants (like Oracle SOA "lane assignments").

CREATE TABLE IF NOT EXISTS workflow_permissions (
  id              TEXT PRIMARY KEY,
  workflow_id     TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  grantee_type    TEXT NOT NULL
                  CHECK(grantee_type IN ('user','team','org_role')),
  grantee_id      TEXT NOT NULL,       -- user.id, team.id, or role name
  permission      TEXT NOT NULL
                  CHECK(permission IN (
                    'view',            -- can see the workflow definition
                    'edit',            -- can modify the DAG
                    'run',             -- can trigger manually
                    'approve',         -- can approve workflow definition changes
                    'manage',          -- can delete, change permissions
                    'review_tasks'     -- can handle HITL tasks from this workflow
                  )),
  granted_by      TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(workflow_id, grantee_type, grantee_id, permission)
);

CREATE INDEX IF NOT EXISTS idx_wf_perms_workflow_id ON workflow_permissions(workflow_id);
CREATE INDEX IF NOT EXISTS idx_wf_perms_grantee     ON workflow_permissions(grantee_type, grantee_id);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. WORKFLOW RUN MESSAGES (reviewer ↔ author communication)
-- ═══════════════════════════════════════════════════════════════════════════════
-- Medium Maker Pro WorkflowView has integrated messaging within the review flow.
-- Messages are tied to a workflow run (and optionally a specific step/task).

CREATE TABLE IF NOT EXISTS workflow_run_messages (
  id              TEXT PRIMARY KEY,
  run_id          TEXT NOT NULL REFERENCES workflow_runs(id) ON DELETE CASCADE,
  workflow_id     TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  step_id         TEXT REFERENCES workflow_run_steps(id) ON DELETE SET NULL,
  task_id         TEXT REFERENCES workflow_human_tasks(id) ON DELETE SET NULL,

  sender_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sender_role     TEXT NOT NULL DEFAULT 'author'
                  CHECK(sender_role IN ('author','reviewer','admin','superadmin','system')),
  content         TEXT NOT NULL,
  message_type    TEXT NOT NULL DEFAULT 'comment'
                  CHECK(message_type IN ('comment','approval','rejection','escalation','system_note','revision_request')),

  -- Optional attachment (e.g. screenshot of issue)
  attachment_url  TEXT,
  attachment_type TEXT,

  is_internal     INTEGER NOT NULL DEFAULT 0,  -- 1 = visible only to reviewers, not author

  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_wf_messages_run_id     ON workflow_run_messages(run_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_wf_messages_workflow_id ON workflow_run_messages(workflow_id);
CREATE INDEX IF NOT EXISTS idx_wf_messages_sender_id  ON workflow_run_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_wf_messages_task_id    ON workflow_run_messages(task_id);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. WORKFLOW SECURITY POLICIES (enterprise governance)
-- ═══════════════════════════════════════════════════════════════════════════════
-- Org-level policies that constrain workflow behavior.
-- These act as guardrails even when individual workflow configs are permissive.

CREATE TABLE IF NOT EXISTS workflow_policies (
  id              TEXT PRIMARY KEY,
  org_id          TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  policy_type     TEXT NOT NULL
                  CHECK(policy_type IN (
                    'max_workflows',        -- limit total active workflows
                    'max_runs_per_hour',    -- rate limit execution
                    'max_run_duration_sec', -- timeout ceiling
                    'max_cost_per_run',     -- cost cap in microcents
                    'max_cost_per_month',   -- monthly spend ceiling
                    'require_approval',     -- all workflows require lead approval
                    'allowed_node_types',   -- whitelist of node types
                    'blocked_node_types',   -- blacklist of node types
                    'ip_allowlist',         -- restrict webhook triggers to IPs
                    'allowed_integrations', -- restrict which connectors can be used
                    'data_retention_days',  -- auto-purge run history after N days
                    'require_2fa_for_edit', -- editors must have 2FA to modify workflows
                    'audit_all_runs'        -- force full step-level audit logging
                  )),
  policy_value    TEXT NOT NULL DEFAULT '{}',  -- JSON value, shape depends on policy_type
  -- Examples:
  --   max_workflows:       {"limit": 10}
  --   allowed_node_types:  {"types":["trigger.*","action.send_email","condition.*"]}
  --   ip_allowlist:        {"cidrs":["10.0.0.0/8","192.168.1.0/24"]}
  --   max_cost_per_month:  {"limit_microcents": 50000000}  (= $50)

  is_active       INTEGER NOT NULL DEFAULT 1,
  enforced_by     TEXT NOT NULL DEFAULT 'system'
                  CHECK(enforced_by IN ('system','superadmin','org_admin')),
  created_by      TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(org_id, policy_type)
);

CREATE INDEX IF NOT EXISTS idx_wf_policies_org_id ON workflow_policies(org_id, is_active);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. ADDITIONAL NODE TYPES (Medium Maker Pro parity)
-- ═══════════════════════════════════════════════════════════════════════════════
-- Medium builder has: review, approval, notification, delay, auto_publish,
-- escalation, conditional.  Most already exist; add the missing ones.

INSERT OR IGNORE INTO workflow_node_types
  (id, category, name, description, is_enterprise, config_schema, output_schema)
VALUES
  -- Escalation: bump a stuck/rejected item to a higher authority
  ('action.escalate',
   'action', 'Escalate',
   'Escalate to a higher-authority reviewer (superadmin, org owner, or named user). Creates a new HITL task with elevated priority.',
   0,
   '{"properties":{"escalate_to":{"type":"string","enum":["superadmin","org_owner","specific_user","specific_team"],"default":"superadmin"},"escalate_to_id":{"type":"string"},"reason_template":{"type":"string","default":"Escalated: requires senior review"},"priority":{"type":"string","enum":["high","urgent"],"default":"urgent"}}}',
   '{"properties":{"task_id":{"type":"string"},"assigned_to":{"type":"string"}}}'
  ),

  -- Auto-publish: automatically transition article to PUBLISHED
  ('action.auto_publish',
   'action', 'Auto-Publish',
   'Automatically publish the triggering article. Updates article status to PUBLISHED and sets published_at.',
   0,
   '{"properties":{"set_featured":{"type":"boolean","default":false},"schedule_at":{"type":"string","description":"ISO 8601 datetime; omit for immediate"}}}',
   '{"properties":{"article_id":{"type":"string"},"published_at":{"type":"string"}}}'
  ),

  -- Auto-reject: automatically reject content that fails policy checks
  ('action.auto_reject',
   'action', 'Auto-Reject',
   'Automatically reject content and notify the author with a reason.',
   1,
   '{"properties":{"reason_template":{"type":"string","default":"Content does not meet publication standards."},"notify_author":{"type":"boolean","default":true}}}',
   '{"properties":{"article_id":{"type":"string"},"rejection_note":{"type":"string"}}}'
  ),

  -- Content classification / sensitivity check
  ('condition.security_level',
   'condition', 'Security Level Check',
   'Branch based on article security classification. Integrates with enterprise content policies.',
   1,
   '{"properties":{"levels":{"type":"array","items":{"type":"string","enum":["public","internal","confidential","restricted"]},"description":"Accepted levels for the YES branch"}}}',
   '{"properties":{"matched":{"type":"boolean"},"article_level":{"type":"string"}}}'
  ),

  -- Content type condition
  ('condition.content_type',
   'condition', 'Content Type Check',
   'Branch based on article content type (tutorial, case_study, news, opinion, etc.).',
   0,
   '{"properties":{"accepted_types":{"type":"array","items":{"type":"string"},"description":"Content type slugs that pass"}}}',
   '{"properties":{"matched":{"type":"boolean"},"article_content_type":{"type":"string"}}}'
  ),

  -- Premium/paid content check
  ('condition.is_premium',
   'condition', 'Is Premium Content?',
   'Branch YES if article.premium_only = 1.',
   0,
   '{}',
   '{"properties":{"is_premium":{"type":"boolean"}}}'
  ),

  -- Author tenure check (is author new?)
  ('condition.author_is_new',
   'condition', 'Author Is New?',
   'Branch YES if the author account was created within the configured number of days.',
   0,
   '{"properties":{"days_threshold":{"type":"integer","default":30}}}',
   '{"properties":{"is_new":{"type":"boolean"},"account_age_days":{"type":"integer"}}}'
  ),

  -- Topic sensitivity check
  ('condition.topic_sensitive',
   'condition', 'Topic Is Sensitive?',
   'Branch YES if any article tag matches the configured sensitive-topics list.',
   0,
   '{"properties":{"sensitive_topics":{"type":"array","items":{"type":"string"},"default":["politics","health","finance"]}}}',
   '{"properties":{"is_sensitive":{"type":"boolean"},"matched_topics":{"type":"array"}}}'
  ),

  -- Parallel split (fan-out to multiple lanes simultaneously)
  ('transform.parallel_split',
   'transform', 'Parallel Split',
   'Fan out execution to multiple downstream branches simultaneously. All branches run in parallel.',
   1,
   '{"properties":{"branch_count":{"type":"integer","default":2}}}',
   '{"properties":{"branch_index":{"type":"integer"}}}'
  ),

  -- Parallel join (wait for all branches)
  ('transform.parallel_join',
   'transform', 'Parallel Join / Synchronize',
   'Wait for all upstream parallel branches to complete before continuing. Merges context variables.',
   1,
   '{"properties":{"merge_strategy":{"type":"string","enum":["all","first","majority"],"default":"all"}}}',
   '{"properties":{"branches_completed":{"type":"integer"},"merged_context":{"type":"object"}}}'
  ),

  -- Loop / iterator (run a sub-section for each item in a list)
  ('transform.loop',
   'transform', 'Loop / For-Each',
   'Iterate over an array variable and execute children once per item. Outputs collected results.',
   1,
   '{"properties":{"source_variable":{"type":"string","description":"Context variable name containing the array"},"max_iterations":{"type":"integer","default":100}}}',
   '{"properties":{"iteration_results":{"type":"array"},"total_iterations":{"type":"integer"}}}'
  ),

  -- Error handler / catch (Oracle BPEL-style fault handlers)
  ('action.error_handler',
   'action', 'Error Handler / Catch',
   'Catch errors from upstream nodes. Define retry policy or fallback actions.',
   1,
   '{"properties":{"retry_count":{"type":"integer","default":3},"retry_delay_seconds":{"type":"integer","default":60},"on_exhausted":{"type":"string","enum":["fail","skip","notify","fallback_node"],"default":"fail"},"fallback_node_id":{"type":"string"}}}',
   '{"properties":{"error_message":{"type":"string"},"retry_attempt":{"type":"integer"},"recovered":{"type":"boolean"}}}'
  ),

  -- Timer / scheduled delay (Medium-style delay node)
  ('delay.business_hours',
   'delay', 'Wait (Business Hours Only)',
   'Pause execution for N business hours (skips weekends and configured holidays).',
   1,
   '{"properties":{"hours":{"type":"integer","default":8},"timezone":{"type":"string","default":"UTC"},"skip_weekends":{"type":"boolean","default":true},"holiday_calendar":{"type":"string","description":"Optional holiday calendar ID"}}}',
   '{"properties":{"resumed_at":{"type":"string"}}}'
  );

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. PLAN-TIER WORKFLOW LIMITS (pricing gate)
-- ═══════════════════════════════════════════════════════════════════════════════
-- Defines how many workflows, runs, and which node types are available per plan.
-- Enforced at API layer; stored here for admin configurability.

CREATE TABLE IF NOT EXISTS plan_workflow_limits (
  id                      TEXT PRIMARY KEY,
  plan_tier               TEXT NOT NULL UNIQUE,   -- matches organizations.plan_tier
  max_active_workflows    INTEGER NOT NULL DEFAULT 3,
  max_runs_per_month      INTEGER NOT NULL DEFAULT 100,
  max_nodes_per_workflow  INTEGER NOT NULL DEFAULT 20,
  max_run_duration_sec    INTEGER NOT NULL DEFAULT 300,
  allowed_node_categories TEXT NOT NULL DEFAULT '["trigger","action","condition","transform","delay"]',
  -- JSON array; 'subflow' only for enterprise
  enterprise_nodes_enabled INTEGER NOT NULL DEFAULT 0,  -- 1 = can use is_enterprise=1 nodes
  hitl_tasks_enabled      INTEGER NOT NULL DEFAULT 0,
  cost_ledger_enabled     INTEGER NOT NULL DEFAULT 0,
  connector_limit         INTEGER NOT NULL DEFAULT 5,    -- max connector instances
  created_at              TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at              TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Seed default plan limits
INSERT OR IGNORE INTO plan_workflow_limits
  (id, plan_tier, max_active_workflows, max_runs_per_month, max_nodes_per_workflow,
   max_run_duration_sec, enterprise_nodes_enabled, hitl_tasks_enabled,
   cost_ledger_enabled, connector_limit)
VALUES
  ('plan_free',       'free',       1,    50,    10,   120, 0, 0, 0, 2),
  ('plan_starter',    'starter',    5,   500,    25,   300, 0, 0, 0, 5),
  ('plan_business',   'business',  25,  5000,    50,   600, 1, 1, 1, 20),
  ('plan_enterprise', 'enterprise', -1, -1,     -1,    -1, 1, 1, 1, -1);
  -- -1 = unlimited

-- ═══════════════════════════════════════════════════════════════════════════════
-- 7. WORKFLOW FOLDERS / CATEGORIES
-- ═══════════════════════════════════════════════════════════════════════════════
-- Organize workflows into folders, like Oracle SOA composite folders or n8n tags.

CREATE TABLE IF NOT EXISTS workflow_folders (
  id              TEXT PRIMARY KEY,
  org_id          TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  parent_id       TEXT REFERENCES workflow_folders(id) ON DELETE CASCADE,  -- nested folders
  name            TEXT NOT NULL,
  description     TEXT,
  icon            TEXT,
  sort_order      INTEGER NOT NULL DEFAULT 0,
  created_by      TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(org_id, parent_id, name)
);

CREATE INDEX IF NOT EXISTS idx_wf_folders_org_id ON workflow_folders(org_id);

-- Add folder reference to workflows
ALTER TABLE workflows ADD COLUMN folder_id TEXT REFERENCES workflow_folders(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_workflows_folder_id ON workflows(folder_id);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 8. WORKFLOW SCHEDULES (reusable schedule definitions)
-- ═══════════════════════════════════════════════════════════════════════════════
-- Decouples schedule definitions from the trigger node config.
-- A schedule can be shared across workflows or reused.

CREATE TABLE IF NOT EXISTS workflow_schedules (
  id              TEXT PRIMARY KEY,
  org_id          TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  workflow_id     TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  cron_expression TEXT NOT NULL,       -- standard 5-field cron
  timezone        TEXT NOT NULL DEFAULT 'UTC',
  is_active       INTEGER NOT NULL DEFAULT 1,
  last_fired_at   TEXT,
  next_fire_at    TEXT,
  fire_count      INTEGER NOT NULL DEFAULT 0,
  created_by      TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_wf_schedules_org_id       ON workflow_schedules(org_id);
CREATE INDEX IF NOT EXISTS idx_wf_schedules_workflow_id  ON workflow_schedules(workflow_id);
CREATE INDEX IF NOT EXISTS idx_wf_schedules_next_fire    ON workflow_schedules(next_fire_at, is_active);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 9. ARTICLE SECURITY CLASSIFICATION (enables security-based workflow binding)
-- ═══════════════════════════════════════════════════════════════════════════════
ALTER TABLE articles ADD COLUMN security_level TEXT NOT NULL DEFAULT 'public'
  CHECK(security_level IN ('public','internal','confidential','restricted'));

CREATE INDEX IF NOT EXISTS idx_articles_security_level ON articles(security_level);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 10. WORKFLOW EXECUTION AUDIT LOG (append-only, complements audit_log)
-- ═══════════════════════════════════════════════════════════════════════════════
-- Detailed audit trail for regulatory compliance (SOX, GDPR data processing).
-- Separate from the generic audit_log for performance (workflow runs are high-volume).

CREATE TABLE IF NOT EXISTS workflow_audit_log (
  id              TEXT PRIMARY KEY,
  org_id          TEXT REFERENCES organizations(id) ON DELETE SET NULL,
  workflow_id     TEXT REFERENCES workflows(id) ON DELETE SET NULL,
  run_id          TEXT REFERENCES workflow_runs(id) ON DELETE SET NULL,
  actor_id        TEXT REFERENCES users(id) ON DELETE SET NULL,
  action          TEXT NOT NULL,
  -- e.g. 'workflow.created','workflow.published','workflow.approved',
  --      'run.started','run.completed','run.failed',
  --      'task.assigned','task.completed','policy.violated',
  --      'connector.invoked','data.exported'
  resource_type   TEXT,          -- 'workflow','run','step','task','connector'
  resource_id     TEXT,
  detail          TEXT NOT NULL DEFAULT '{}',  -- JSON payload with before/after state
  ip_hash         TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_wf_audit_org_id       ON workflow_audit_log(org_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wf_audit_workflow_id  ON workflow_audit_log(workflow_id);
CREATE INDEX IF NOT EXISTS idx_wf_audit_run_id       ON workflow_audit_log(run_id);
CREATE INDEX IF NOT EXISTS idx_wf_audit_actor_id     ON workflow_audit_log(actor_id);
CREATE INDEX IF NOT EXISTS idx_wf_audit_action       ON workflow_audit_log(action);
