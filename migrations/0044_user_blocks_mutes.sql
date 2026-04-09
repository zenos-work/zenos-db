-- Migration: 0044_user_blocks_mutes
-- User safety: block/mute other users.
-- Blocked users cannot follow, comment, or see content.
-- Muted users' content is hidden from the muter's feed but social interactions remain intact.

CREATE TABLE IF NOT EXISTS user_blocks (
  blocker_id   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  block_type   TEXT NOT NULL DEFAULT 'block'
               CHECK(block_type IN ('block', 'mute')),
  reason       TEXT,          -- optional: why user is blocked/muted
  created_at   TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (blocker_id, blocked_id)
);

-- ── INDEXES ──────────────────────────────────────────────────────────────────
-- "Who have I blocked?" — powers the settings page list
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON user_blocks(blocker_id, block_type);
-- "Am I blocked by this person?" — checked during follow/comment operations
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON user_blocks(blocked_id, blocker_id);
