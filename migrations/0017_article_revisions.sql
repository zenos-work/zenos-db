-- 0017_article_revisions.sql — Version history for article edits
-- (merged: 0046)

CREATE TABLE IF NOT EXISTS article_revisions (
  id              TEXT PRIMARY KEY,
  article_id      TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  version_number  INTEGER NOT NULL,

  -- Snapshot
  title           TEXT NOT NULL,
  subtitle        TEXT,
  content         TEXT NOT NULL,
  cover_image_url TEXT,
  reading_level   TEXT,
  tags_snapshot   TEXT NOT NULL DEFAULT '[]',

  -- Who made the edit
  editor_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  change_summary  TEXT,
  edit_type       TEXT NOT NULL DEFAULT 'manual'
                  CHECK(edit_type IN ('manual','autosave','publish','revert','ai_suggestion')),

  -- Size delta
  word_count      INTEGER NOT NULL DEFAULT 0,
  char_diff       INTEGER NOT NULL DEFAULT 0,

  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(article_id, version_number)
);

CREATE INDEX IF NOT EXISTS idx_article_revisions_article_id
  ON article_revisions(article_id, version_number DESC);
CREATE INDEX IF NOT EXISTS idx_article_revisions_editor_id
  ON article_revisions(editor_id);

INSERT INTO _migrations (filename) VALUES ('0017_article_revisions.sql');
