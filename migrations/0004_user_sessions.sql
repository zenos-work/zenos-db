-- 0004_user_sessions.sql — Auditable session tracking (from 0049)
CREATE TABLE IF NOT EXISTS user_sessions (
  id              TEXT PRIMARY KEY,
  user_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_info     TEXT,
  ip_hash         TEXT,
  country_code    TEXT,
  login_method    TEXT NOT NULL DEFAULT 'google_oauth'
                  CHECK(login_method IN ('google_oauth','email_magic_link','sso_saml','sso_oidc','api_key','impersonation')),
  last_active_at  TEXT NOT NULL DEFAULT (datetime('now')),
  expires_at      TEXT,
  is_revoked      INTEGER NOT NULL DEFAULT 0,
  revoked_at      TEXT,
  revoked_reason  TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id    ON user_sessions(user_id, is_revoked, last_active_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_sessions_expires    ON user_sessions(expires_at)
  WHERE is_revoked = 0;

INSERT INTO _migrations (filename) VALUES ('0004_user_sessions.sql');
