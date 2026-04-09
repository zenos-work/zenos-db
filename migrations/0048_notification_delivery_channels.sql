-- Migration: 0048_notification_delivery_channels
-- Extends the notifications table with multi-channel delivery tracking.
-- Currently notifications are in-app only; this adds email, push, and webhook channels.
-- Also adds notification preferences granularity per notification type.

-- New delivery columns on existing notifications table
ALTER TABLE notifications ADD COLUMN channel TEXT NOT NULL DEFAULT 'in_app'
  CHECK(channel IN ('in_app','email','push','webhook'));
ALTER TABLE notifications ADD COLUMN delivery_status TEXT NOT NULL DEFAULT 'delivered'
  CHECK(delivery_status IN ('pending','delivered','failed','bounced'));
ALTER TABLE notifications ADD COLUMN delivered_at TEXT;
ALTER TABLE notifications ADD COLUMN external_ref TEXT;  -- email message-id, push receipt, etc.

-- Group related notifications (e.g. "5 people liked your article")
ALTER TABLE notifications ADD COLUMN group_key TEXT;  -- NULL = standalone, else grouped by this key

-- ── NOTIFICATION PREFERENCES (per-type granularity) ──────────────────────────
-- Overrides the global email_notifs toggle with per-type channel preferences.
CREATE TABLE IF NOT EXISTS notification_preferences (
  user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  notification_type TEXT NOT NULL,   -- matches notifications.type values
  channel           TEXT NOT NULL
                    CHECK(channel IN ('in_app','email','push')),
  is_enabled        INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (user_id, notification_type, channel)
);

CREATE INDEX IF NOT EXISTS idx_notif_prefs_user_id ON notification_preferences(user_id);

-- ── PUSH SUBSCRIPTION TOKENS ─────────────────────────────────────────────────
-- Stores web-push or mobile push subscription info per device.
CREATE TABLE IF NOT EXISTS push_subscriptions (
  id              TEXT PRIMARY KEY,
  user_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  endpoint        TEXT NOT NULL,       -- push service endpoint URL
  auth_key        TEXT NOT NULL,       -- p256dh key (encrypted at app layer)
  p256dh_key      TEXT NOT NULL,
  device_name     TEXT,                -- e.g. "Chrome on MacBook"
  platform        TEXT NOT NULL DEFAULT 'web'
                  CHECK(platform IN ('web','ios','android')),
  is_active       INTEGER NOT NULL DEFAULT 1,
  last_used_at    TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(user_id, endpoint)
);

CREATE INDEX IF NOT EXISTS idx_push_subs_user_id ON push_subscriptions(user_id, is_active);
