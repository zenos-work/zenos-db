-- 0014_follows.sql — Follows table (from 0009)
CREATE TABLE IF NOT EXISTS follows (
  follower_id  TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  following_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  following_type TEXT NOT NULL DEFAULT 'user',
  created_at   TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (follower_id, following_id),
  CHECK (follower_id != following_id)
);

CREATE INDEX IF NOT EXISTS idx_follows_follower_id     ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following_id    ON follows(following_id);
-- Composite (0052)
CREATE INDEX IF NOT EXISTS idx_follows_following_type  ON follows(following_id, following_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_follows_follower_type   ON follows(follower_id, following_type, created_at DESC);

INSERT INTO _migrations (filename) VALUES ('0014_follows.sql');
