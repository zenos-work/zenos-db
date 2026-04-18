-- 0011_comments.sql — Comments table (merged: 0006, 0013)
CREATE TABLE IF NOT EXISTS comments (
  id               TEXT PRIMARY KEY,
  article_id       TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  author_id        TEXT NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  parent_id        TEXT REFERENCES comments(id)          ON DELETE CASCADE,
  content          TEXT NOT NULL,
  is_deleted       INTEGER NOT NULL DEFAULT 0,
  -- Moderation (0013)
  is_hidden        INTEGER NOT NULL DEFAULT 0,
  moderation_reason TEXT,
  moderated_by     TEXT REFERENCES users(id) ON DELETE SET NULL,
  moderated_at     TEXT,
  flag_count       INTEGER NOT NULL DEFAULT 0,
  created_at       TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at       TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_comments_article_id    ON comments(article_id);
CREATE INDEX IF NOT EXISTS idx_comments_author_id     ON comments(author_id);
CREATE INDEX IF NOT EXISTS idx_comments_parent_id     ON comments(parent_id);
CREATE INDEX IF NOT EXISTS idx_comments_is_hidden     ON comments(is_hidden);
CREATE INDEX IF NOT EXISTS idx_comments_flag_count    ON comments(flag_count);
-- Composite (0052)
CREATE INDEX IF NOT EXISTS idx_comments_article_parent ON comments(article_id, parent_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_comments_flagged        ON comments(flag_count DESC, created_at DESC) WHERE flag_count > 0;

INSERT INTO _migrations (filename) VALUES ('0011_comments.sql');
