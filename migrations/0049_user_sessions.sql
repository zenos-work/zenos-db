-- Migration: 0049_user_sessions
-- Tracks active login sessions for the "active sessions" security view.
-- Auth uses KV for session tokens; this table provides the auditable record
-- and supports "revoke all sessions" / "revoke this device" flows.

CREATE TABLE IF NOT EXISTS user_sessions (
  id              TEXT PRIMARY KEY,   -- matches the KV session token ID
  user_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- Device / environment info
  device_info     TEXT,               -- user-agent derived: "Chrome 125 on macOS"
  ip_hash         TEXT,               -- SHA-256 of IP (privacy-safe)
  country_code    TEXT,               -- GeoIP resolved
  login_method    TEXT NOT NULL DEFAULT 'google_oauth'
                  CHECK(login_method IN ('google_oauth','email_magic_link','api_key','sso')),

  -- Lifecycle
  last_active_at  TEXT NOT NULL DEFAULT (datetime('now')),
  expires_at      TEXT NOT NULL,
  is_revoked      INTEGER NOT NULL DEFAULT 0,
  revoked_at      TEXT,
  revoked_reason  TEXT,               -- 'user_logout', 'password_change', 'admin_revoke', 'expiry'

  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_sessions_user_id     ON user_sessions(user_id, is_revoked);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at  ON user_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_sessions_active      ON user_sessions(user_id, last_active_at DESC);
