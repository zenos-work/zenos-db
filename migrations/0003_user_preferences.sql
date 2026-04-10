-- 0003_user_preferences.sql — (merged: 0011, 0022 rename, 0042)
CREATE TABLE IF NOT EXISTS user_preferences (
  user_id           TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  topics            TEXT NOT NULL DEFAULT '[]',
  theme             TEXT NOT NULL DEFAULT 'light'
                    CHECK(theme IN ('light','dark','system')),
  email_notifs      INTEGER NOT NULL DEFAULT 1,

  -- Reading preferences (0042)
  font_family       TEXT NOT NULL DEFAULT 'serif'
                    CHECK(font_family IN ('serif','sans')),
  font_size         INTEGER NOT NULL DEFAULT 20
                    CHECK(font_size BETWEEN 12 AND 32),
  content_width     TEXT NOT NULL DEFAULT 'wide'
                    CHECK(content_width IN ('wide','medium','narrow')),
  line_height       TEXT NOT NULL DEFAULT 'normal'
                    CHECK(line_height IN ('compact','normal','relaxed')),
  code_theme        TEXT NOT NULL DEFAULT 'auto'
                    CHECK(code_theme IN ('auto','light','dark')),

  created_at        TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_user_preferences_user_id ON user_preferences(user_id);

INSERT INTO _migrations (filename) VALUES ('0003_user_preferences.sql');
