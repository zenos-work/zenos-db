-- 0035_workflow_enterprise.sql — Content bindings, permissions, messages, policies,
-- plan limits, folders, schedules, audit log
-- (merged: 0051 — tables only; node types and article/workflow column ALTERs already in 0028/0008)

-- ═══ CONTENT–WORKFLOW BINDING ════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS workflow_content_bindings (
  id              TEXT PRIMARY KEY,
  workflow_id     TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  org_id          TEXT REFERENCES organizations(id) ON DELETE CASCADE,

  bind_type       TEXT NOT NULL DEFAULT 'all_org_content'
                  CHECK(bind_type IN (
                    'all_org_content','by_tag','by_content_type','by_author',
                    'by_team','by_security_level','by_premium_status',
                    'by_regex_title','manual_selection'
                  )),
  bind_criteria   TEXT NOT NULL DEFAULT '{}',

  trigger_event   TEXT NOT NULL DEFAULT 'on_submit'
                  CHECK(trigger_event IN (
                    'on_create','on_submit','on_approve','on_publish',
                    'on_update','on_unpublish','on_schedule','on_expire'
                  )),

  priority        INTEGER NOT NULL DEFAULT 100,
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

-- ═══ WORKFLOW ROLE-BASED ACCESS CONTROL ══════════════════════════════════════
CREATE TABLE IF NOT EXISTS workflow_permissions (
  id              TEXT PRIMARY KEY,
  workflow_id     TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  grantee_type    TEXT NOT NULL
                  CHECK(grantee_type IN ('user','team','org_role')),
  grantee_id      TEXT NOT NULL,
  permission      TEXT NOT NULL
                  CHECK(permission IN (
                    'view','edit','run','approve','manage','review_tasks'
                  )),
  granted_by      TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(workflow_id, grantee_type, grantee_id, permission)
);

CREATE INDEX IF NOT EXISTS idx_wf_perms_workflow_id ON workflow_permissions(workflow_id);
CREATE INDEX IF NOT EXISTS idx_wf_perms_grantee     ON workflow_permissions(grantee_type, grantee_id);

-- ═══ WORKFLOW RUN MESSAGES ═══════════════════════════════════════════════════
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

  attachment_url  TEXT,
  attachment_type TEXT,
  is_internal     INTEGER NOT NULL DEFAULT 0,

  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_wf_messages_run_id     ON workflow_run_messages(run_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_wf_messages_workflow_id ON workflow_run_messages(workflow_id);
CREATE INDEX IF NOT EXISTS idx_wf_messages_sender_id  ON workflow_run_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_wf_messages_task_id    ON workflow_run_messages(task_id);

-- ═══ WORKFLOW SECURITY POLICIES ══════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS workflow_policies (
  id              TEXT PRIMARY KEY,
  org_id          TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  policy_type     TEXT NOT NULL
                  CHECK(policy_type IN (
                    'max_workflows','max_runs_per_hour','max_run_duration_sec',
                    'max_cost_per_run','max_cost_per_month','require_approval',
                    'allowed_node_types','blocked_node_types','ip_allowlist',
                    'allowed_integrations','data_retention_days',
                    'require_2fa_for_edit','audit_all_runs'
                  )),
  policy_value    TEXT NOT NULL DEFAULT '{}',
  is_active       INTEGER NOT NULL DEFAULT 1,
  enforced_by     TEXT NOT NULL DEFAULT 'system'
                  CHECK(enforced_by IN ('system','superadmin','org_admin')),
  created_by      TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(org_id, policy_type)
);

CREATE INDEX IF NOT EXISTS idx_wf_policies_org_id ON workflow_policies(org_id, is_active);

-- ═══ PLAN-TIER WORKFLOW LIMITS ═══════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS plan_workflow_limits (
  id                      TEXT PRIMARY KEY,
  plan_tier               TEXT NOT NULL UNIQUE,
  max_active_workflows    INTEGER NOT NULL DEFAULT 3,
  max_runs_per_month      INTEGER NOT NULL DEFAULT 100,
  max_nodes_per_workflow  INTEGER NOT NULL DEFAULT 20,
  max_run_duration_sec    INTEGER NOT NULL DEFAULT 300,
  allowed_node_categories TEXT NOT NULL DEFAULT '["trigger","action","condition","transform","delay"]',
  enterprise_nodes_enabled INTEGER NOT NULL DEFAULT 0,
  hitl_tasks_enabled      INTEGER NOT NULL DEFAULT 0,
  cost_ledger_enabled     INTEGER NOT NULL DEFAULT 0,
  connector_limit         INTEGER NOT NULL DEFAULT 5,
  created_at              TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at              TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO plan_workflow_limits
  (id, plan_tier, max_active_workflows, max_runs_per_month, max_nodes_per_workflow,
   max_run_duration_sec, enterprise_nodes_enabled, hitl_tasks_enabled,
   cost_ledger_enabled, connector_limit)
VALUES
  ('plan_free',       'free',       1,    50,    10,   120, 0, 0, 0, 2),
  ('plan_starter',    'starter',    5,   500,    25,   300, 0, 0, 0, 5),
  ('plan_business',   'business',  25,  5000,    50,   600, 1, 1, 1, 20),
  ('plan_enterprise', 'enterprise', -1, -1,     -1,    -1, 1, 1, 1, -1);

-- ═══ WORKFLOW FOLDERS ════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS workflow_folders (
  id              TEXT PRIMARY KEY,
  org_id          TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  parent_id       TEXT REFERENCES workflow_folders(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  description     TEXT,
  icon            TEXT,
  sort_order      INTEGER NOT NULL DEFAULT 0,
  created_by      TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(org_id, parent_id, name)
);

CREATE INDEX IF NOT EXISTS idx_wf_folders_org_id ON workflow_folders(org_id);

-- ═══ WORKFLOW SCHEDULES ══════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS workflow_schedules (
  id              TEXT PRIMARY KEY,
  org_id          TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  workflow_id     TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  cron_expression TEXT NOT NULL,
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

-- ═══ WORKFLOW EXECUTION AUDIT LOG ════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS workflow_audit_log (
  id              TEXT PRIMARY KEY,
  org_id          TEXT REFERENCES organizations(id) ON DELETE SET NULL,
  workflow_id     TEXT REFERENCES workflows(id) ON DELETE SET NULL,
  run_id          TEXT REFERENCES workflow_runs(id) ON DELETE SET NULL,
  actor_id        TEXT REFERENCES users(id) ON DELETE SET NULL,
  action          TEXT NOT NULL,
  resource_type   TEXT,
  resource_id     TEXT,
  detail          TEXT NOT NULL DEFAULT '{}',
  ip_hash         TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_wf_audit_org_id       ON workflow_audit_log(org_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wf_audit_workflow_id  ON workflow_audit_log(workflow_id);
CREATE INDEX IF NOT EXISTS idx_wf_audit_run_id       ON workflow_audit_log(run_id);
CREATE INDEX IF NOT EXISTS idx_wf_audit_actor_id     ON workflow_audit_log(actor_id);
CREATE INDEX IF NOT EXISTS idx_wf_audit_action       ON workflow_audit_log(action);

-- ═══ WORKFLOW ENVIRONMENT PROMOTIONS ═════════════════════════════════════════
CREATE TABLE IF NOT EXISTS workflow_promotions (
  id                TEXT PRIMARY KEY,
  workflow_id       TEXT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  org_id            TEXT REFERENCES organizations(id) ON DELETE CASCADE,
  from_environment  TEXT NOT NULL CHECK(from_environment IN ('dev','staging','production')),
  to_environment    TEXT NOT NULL CHECK(to_environment IN ('dev','staging','production')),
  version_number    INTEGER NOT NULL,
  promoted_by       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  approval_id       TEXT REFERENCES workflow_approvals(id) ON DELETE SET NULL,
  status            TEXT NOT NULL DEFAULT 'pending'
                    CHECK(status IN ('pending','approved','promoted','rejected','rolled_back')),
  rollback_version  INTEGER,
  promotion_note    TEXT,
  promoted_at       TEXT,
  created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_wf_promotions_workflow_id ON workflow_promotions(workflow_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wf_promotions_org_id      ON workflow_promotions(org_id);
CREATE INDEX IF NOT EXISTS idx_wf_promotions_status      ON workflow_promotions(status);

INSERT INTO _migrations (filename) VALUES ('0035_workflow_enterprise.sql');
