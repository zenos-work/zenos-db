-- 0019_series.sql — Article series/collections
-- (merged: 0026 + org_id from 0028)

CREATE TABLE IF NOT EXISTS series (
  id              TEXT PRIMARY KEY,
  author_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  org_id          TEXT REFERENCES organizations(id) ON DELETE SET NULL,
  name            TEXT NOT NULL,
  description     TEXT,
  cover_image_url TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_series_author_id ON series(author_id);
CREATE INDEX IF NOT EXISTS idx_series_org_id    ON series(org_id);

CREATE TABLE IF NOT EXISTS article_series (
  id          TEXT PRIMARY KEY,
  article_id  TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  series_id   TEXT NOT NULL REFERENCES series(id) ON DELETE CASCADE,
  part_number INTEGER NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at  TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(article_id, series_id)
);

CREATE INDEX IF NOT EXISTS idx_article_series_article_id  ON article_series(article_id);
CREATE INDEX IF NOT EXISTS idx_article_series_series_id   ON article_series(series_id);
CREATE INDEX IF NOT EXISTS idx_article_series_part_number ON article_series(series_id, part_number);

INSERT INTO _migrations (filename) VALUES ('0019_series.sql');
