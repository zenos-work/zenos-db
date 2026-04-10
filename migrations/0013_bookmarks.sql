-- 0013_bookmarks.sql — Bookmarks table (from 0007)
CREATE TABLE IF NOT EXISTS bookmarks (
  user_id    TEXT NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  article_id TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (user_id, article_id)
);

CREATE INDEX IF NOT EXISTS idx_bookmarks_user_id     ON bookmarks(user_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_article_id  ON bookmarks(article_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_created ON bookmarks(user_id, created_at DESC);

INSERT INTO _migrations (filename) VALUES ('0013_bookmarks.sql');
