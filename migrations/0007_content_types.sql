-- 0007_content_types.sql — Dynamic content type registry (from 0019)
CREATE TABLE IF NOT EXISTS content_types (
  id          TEXT PRIMARY KEY,
  slug        TEXT NOT NULL UNIQUE,
  name        TEXT NOT NULL,
  description TEXT,
  is_active   INTEGER NOT NULL DEFAULT 1,
  is_system   INTEGER NOT NULL DEFAULT 0,
  sort_order  INTEGER NOT NULL DEFAULT 100,
  created_by  TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_content_types_active ON content_types(is_active);
CREATE INDEX IF NOT EXISTS idx_content_types_sort   ON content_types(sort_order, name);

INSERT INTO _migrations (filename) VALUES ('0007_content_types.sql');
