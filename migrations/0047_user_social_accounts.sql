-- 0047_user_social_accounts.sql
-- SR-024: Connected social network accounts for cross-posting integrations.

CREATE TABLE IF NOT EXISTS user_social_accounts (
  id            TEXT PRIMARY KEY,
  user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider      TEXT NOT NULL CHECK(provider IN ('linkedin','x','facebook','instagram','mastodon')),
  provider_uid  TEXT NOT NULL,
  handle        TEXT,
  display_name  TEXT,
  access_token  TEXT,
  refresh_token TEXT,
  token_expires_at  INTEGER,
  scopes        TEXT NOT NULL DEFAULT '[]',
  connected_at  INTEGER NOT NULL DEFAULT (unixepoch()),
  last_used_at  INTEGER,
  is_active     INTEGER NOT NULL DEFAULT 1,
  UNIQUE(user_id, provider)
);

CREATE INDEX IF NOT EXISTS idx_social_accounts_user ON user_social_accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_social_accounts_provider ON user_social_accounts(provider);
