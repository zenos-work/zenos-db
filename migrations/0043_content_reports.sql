-- Migration: 0043_content_reports
-- Trust & safety: structured content reporting with moderation resolution tracking.
-- Comments already have flag_count but no table tracks who reported, why, or outcome.

CREATE TABLE IF NOT EXISTS content_reports (
  id              TEXT PRIMARY KEY,
  reporter_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  org_id          TEXT REFERENCES organizations(id) ON DELETE SET NULL,

  -- What was reported
  resource_type   TEXT NOT NULL
                  CHECK(resource_type IN ('article','comment','user','community_post','marketplace_item')),
  resource_id     TEXT NOT NULL,

  -- Reason classification + free-text detail
  reason          TEXT NOT NULL
                  CHECK(reason IN (
                    'spam','harassment','hate_speech','misinformation',
                    'copyright','nsfw','self_harm','impersonation',
                    'off_topic','other'
                  )),
  detail_text     TEXT,          -- reporter's own description

  -- Moderation resolution
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK(status IN ('pending','under_review','dismissed','actioned','escalated')),
  reviewed_by     TEXT REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at     TEXT,
  action_taken    TEXT           -- free text: 'content removed', 'user warned', etc.
                  CHECK(action_taken IS NULL OR action_taken IN (
                    'no_action','content_removed','content_hidden','user_warned',
                    'user_suspended','user_banned','escalated_to_legal','other'
                  )),
  action_note     TEXT,          -- internal moderator notes (not shown to reporter)

  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ── INDEXES ──────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_reports_reporter_id    ON content_reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reports_resource       ON content_reports(resource_type, resource_id);
CREATE INDEX IF NOT EXISTS idx_reports_status         ON content_reports(status, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_reports_org_id         ON content_reports(org_id, status);
CREATE INDEX IF NOT EXISTS idx_reports_reason         ON content_reports(reason);

-- Prevent duplicate reports from same user on same resource
CREATE UNIQUE INDEX IF NOT EXISTS idx_reports_unique_per_user
  ON content_reports(reporter_id, resource_type, resource_id);
