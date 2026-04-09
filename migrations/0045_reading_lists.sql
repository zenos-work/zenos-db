-- Migration: 0045_reading_lists
-- Named bookmark collections (Medium-style "Lists").
-- The existing flat bookmarks table (0007) is preserved; reading lists are an upgrade.

CREATE TABLE IF NOT EXISTS reading_lists (
  id            TEXT PRIMARY KEY,
  user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  description   TEXT,
  cover_image_url TEXT,        -- optional custom cover
  is_public     INTEGER NOT NULL DEFAULT 0,   -- 1 = visible on author profile
  is_default    INTEGER NOT NULL DEFAULT 0,   -- 1 = the "Saved" / main list
  article_count INTEGER NOT NULL DEFAULT 0,   -- denormalized count
  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_reading_lists_user_id ON reading_lists(user_id);
CREATE INDEX IF NOT EXISTS idx_reading_lists_public  ON reading_lists(user_id, is_public);

CREATE TABLE IF NOT EXISTS reading_list_items (
  id            TEXT PRIMARY KEY,
  list_id       TEXT NOT NULL REFERENCES reading_lists(id) ON DELETE CASCADE,
  article_id    TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  note          TEXT,           -- user's personal note about why they saved it
  sort_order    INTEGER NOT NULL DEFAULT 0,
  added_at      TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(list_id, article_id)
);

CREATE INDEX IF NOT EXISTS idx_reading_list_items_list_id    ON reading_list_items(list_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_reading_list_items_article_id ON reading_list_items(article_id);

-- ── TRIGGERS ─────────────────────────────────────────────────────────────────
-- Keep article_count in sync automatically
CREATE TRIGGER IF NOT EXISTS trg_reading_list_item_insert
  AFTER INSERT ON reading_list_items
BEGIN
  UPDATE reading_lists SET article_count = article_count + 1, updated_at = datetime('now')
  WHERE id = NEW.list_id;
END;

CREATE TRIGGER IF NOT EXISTS trg_reading_list_item_delete
  AFTER DELETE ON reading_list_items
BEGIN
  UPDATE reading_lists SET article_count = article_count - 1, updated_at = datetime('now')
  WHERE id = OLD.list_id;
END;
