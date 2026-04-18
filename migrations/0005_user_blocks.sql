-- 0005_user_blocks.sql — User safety: block/mute (from 0044)
CREATE TABLE IF NOT EXISTS user_blocks (
  blocker_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  block_type    TEXT NOT NULL DEFAULT 'block'
                CHECK(block_type IN ('block','mute')),
  reason        TEXT,
  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (blocker_id, blocked_id),
  CHECK (blocker_id != blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked_id ON user_blocks(blocked_id);

INSERT INTO _migrations (filename) VALUES ('0005_user_blocks.sql');
