-- 0044_vault_secrets.sql — Organization credential vault metadata + write quotas

CREATE TABLE IF NOT EXISTS vault_secrets (
  id              TEXT PRIMARY KEY,
  org_id          TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  secret_type     TEXT NOT NULL DEFAULT 'generic',
  is_active       INTEGER NOT NULL DEFAULT 1,
  last_rotated_at TEXT,
  expires_at      TEXT,
  created_by      TEXT REFERENCES users(id) ON DELETE SET NULL,
  metadata        TEXT NOT NULL DEFAULT '{}',
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(org_id, name)
);

CREATE INDEX IF NOT EXISTS idx_vault_secrets_org_id ON vault_secrets(org_id);
CREATE INDEX IF NOT EXISTS idx_vault_secrets_active ON vault_secrets(org_id, is_active);

CREATE TABLE IF NOT EXISTS vault_write_quotas (
  org_id      TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  date        TEXT NOT NULL,
  write_count INTEGER NOT NULL DEFAULT 0,
  max_writes  INTEGER NOT NULL DEFAULT 50,
  PRIMARY KEY (org_id, date)
);

INSERT INTO _migrations (filename) VALUES ('0044_vault_secrets.sql');
