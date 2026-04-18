-- 0045_vault_provider_abstraction.sql
-- Cloudflare-first secret provider metadata with D1 encrypted fallback payloads.

ALTER TABLE vault_secrets ADD COLUMN provider TEXT NOT NULL DEFAULT 'cloudflare';
ALTER TABLE vault_secrets ADD COLUMN key_ref TEXT;

CREATE INDEX IF NOT EXISTS idx_vault_secrets_provider ON vault_secrets(provider);
CREATE INDEX IF NOT EXISTS idx_vault_secrets_key_ref ON vault_secrets(key_ref);

CREATE TABLE IF NOT EXISTS vault_secret_payloads (
  secret_id    TEXT PRIMARY KEY REFERENCES vault_secrets(id) ON DELETE CASCADE,
  cipher_text  TEXT NOT NULL,
  created_at   TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_vault_payloads_updated_at ON vault_secret_payloads(updated_at);

INSERT INTO _migrations (filename) VALUES ('0045_vault_provider_abstraction.sql');
