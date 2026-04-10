-- 0041_alert_rules.sql — Org-level alert subscriptions for usage & system events
-- Covers: budget thresholds, workflow failure alerts, quota approach warnings

INSERT INTO _migrations (filename) VALUES ('0041_alert_rules.sql');

-- ─── ALERT RULES ───────────────────────────────────────────────────────────────
-- Org admins subscribe to alerts; cron workers evaluate and fire notifications
CREATE TABLE IF NOT EXISTS alert_rules (
  id              TEXT PRIMARY KEY,
  org_id          TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  created_by      TEXT NOT NULL REFERENCES users(id),
  name            TEXT NOT NULL,
  alert_type      TEXT NOT NULL CHECK(alert_type IN (
    'budget_threshold',
    'workflow_failure',
    'workflow_failure_rate',
    'quota_approach',
    'quota_exhausted',
    'connector_error',
    'billing_discrepancy',
    'custom'
  )),
  config          TEXT NOT NULL DEFAULT '{}',
  threshold_value REAL,
  comparison      TEXT CHECK(comparison IN ('gt','gte','lt','lte','eq',NULL)),
  notify_channels TEXT NOT NULL DEFAULT '["in_app"]',
  notify_user_ids TEXT NOT NULL DEFAULT '[]',
  cooldown_minutes INTEGER NOT NULL DEFAULT 60,
  is_active       INTEGER NOT NULL DEFAULT 1,
  last_triggered_at TEXT,
  trigger_count   INTEGER NOT NULL DEFAULT 0,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_alert_rules_org_id     ON alert_rules(org_id);
CREATE INDEX IF NOT EXISTS idx_alert_rules_type       ON alert_rules(alert_type);
CREATE INDEX IF NOT EXISTS idx_alert_rules_active     ON alert_rules(org_id, is_active) WHERE is_active = 1;
