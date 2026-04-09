-- 0006_tags.sql — Tags table + seed data (merged: 0004, 0015, 0021)
CREATE TABLE IF NOT EXISTS tags (
  id                    TEXT PRIMARY KEY,
  name                  TEXT NOT NULL UNIQUE,
  slug                  TEXT NOT NULL UNIQUE,
  tag_type              TEXT NOT NULL DEFAULT 'topic'
                        CHECK(tag_type IN ('topic','outcome')),
  category_slug         TEXT,
  is_onboarding_category INTEGER NOT NULL DEFAULT 0,
  created_at            TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_tags_name               ON tags(name);
CREATE INDEX IF NOT EXISTS idx_tags_slug               ON tags(slug);
CREATE INDEX IF NOT EXISTS idx_tags_tag_type            ON tags(tag_type);
CREATE INDEX IF NOT EXISTS idx_tags_category_slug       ON tags(category_slug);
CREATE INDEX IF NOT EXISTS idx_tags_onboarding_category ON tags(is_onboarding_category);

INSERT INTO _migrations (filename) VALUES ('0006_tags.sql');
