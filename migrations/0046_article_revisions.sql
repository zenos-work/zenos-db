-- Migration: 0046_article_revisions
-- Version history for article edits.
-- Every save/publish creates a snapshot for editorial accountability, undo, and diff.

CREATE TABLE IF NOT EXISTS article_revisions (
  id              TEXT PRIMARY KEY,
  article_id      TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  version_number  INTEGER NOT NULL,

  -- Snapshot of the article at this version
  title           TEXT NOT NULL,
  subtitle        TEXT,
  content         TEXT NOT NULL,
  cover_image_url TEXT,
  reading_level   TEXT,
  tags_snapshot   TEXT NOT NULL DEFAULT '[]',   -- JSON array of tag names at save time

  -- Who made the edit
  editor_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  change_summary  TEXT,          -- brief description of what changed
  edit_type       TEXT NOT NULL DEFAULT 'manual'
                  CHECK(edit_type IN ('manual','autosave','publish','revert','ai_suggestion')),

  -- Size delta for quick stats
  word_count      INTEGER NOT NULL DEFAULT 0,
  char_diff       INTEGER NOT NULL DEFAULT 0,  -- positive = added, negative = removed

  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(article_id, version_number)
);

CREATE INDEX IF NOT EXISTS idx_article_revisions_article_id
  ON article_revisions(article_id, version_number DESC);
CREATE INDEX IF NOT EXISTS idx_article_revisions_editor_id
  ON article_revisions(editor_id);

-- Track current revision pointer on the articles table
ALTER TABLE articles ADD COLUMN current_revision INTEGER NOT NULL DEFAULT 1;
