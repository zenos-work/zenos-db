-- Persist per-user reading progress snapshots for history/continue-reading surfaces.
CREATE TABLE IF NOT EXISTS user_reading_history (
  user_id TEXT NOT NULL,
  article_id TEXT NOT NULL,
  slug TEXT NOT NULL,
  title TEXT NOT NULL,
  subtitle TEXT,
  author_name TEXT,
  cover_image_url TEXT,
  read_time_minutes INTEGER NOT NULL DEFAULT 0,
  progress INTEGER NOT NULL DEFAULT 0,
  last_read_at TEXT NOT NULL DEFAULT (datetime('now')),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (user_id, article_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_user_reading_history_user_last_read
  ON user_reading_history(user_id, last_read_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_reading_history_article
  ON user_reading_history(article_id);
