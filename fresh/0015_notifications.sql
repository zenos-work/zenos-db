-- 0015_notifications.sql — Notifications + preferences + push subs (merged: 0010, 0015, 0048)
CREATE TABLE IF NOT EXISTS notifications (
  id              TEXT PRIMARY KEY,
  user_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  actor_id        TEXT REFERENCES users(id) ON DELETE SET NULL,
  type            TEXT NOT NULL
                  CHECK(type IN ('LIKE','COMMENT','FOLLOW','APPROVED','REJECTED',
                                 'PUBLISHED','MODERATION_PENDING','MODERATION_REJECTED')),
  article_id      TEXT REFERENCES articles(id)  ON DELETE CASCADE,
  comment_id      TEXT REFERENCES comments(id)  ON DELETE CASCADE,
  message         TEXT NOT NULL,
  is_read         INTEGER NOT NULL DEFAULT 0,

  -- Delivery (0048)
  channel         TEXT NOT NULL DEFAULT 'in_app'
                  CHECK(channel IN ('in_app','email','push','webhook')),
  delivery_status TEXT NOT NULL DEFAULT 'delivered'
                  CHECK(delivery_status IN ('pending','delivered','failed','bounced')),
  delivered_at    TEXT,
  external_ref    TEXT,
  group_key       TEXT,

  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id    ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_actor_id   ON notifications(actor_id);
CREATE INDEX IF NOT EXISTS idx_notifications_article_id ON notifications(article_id);
CREATE INDEX IF NOT EXISTS idx_notifications_comment_id ON notifications(comment_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created    ON notifications(created_at DESC);
-- Composite (0052)
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, is_read, created_at DESC) WHERE is_read = 0;
CREATE INDEX IF NOT EXISTS idx_notifications_group_key   ON notifications(group_key, created_at DESC) WHERE group_key IS NOT NULL;

-- Notification preferences per type x channel (0048)
CREATE TABLE IF NOT EXISTS notification_preferences (
  user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  notification_type TEXT NOT NULL,
  channel           TEXT NOT NULL
                    CHECK(channel IN ('in_app','email','push')),
  is_enabled        INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (user_id, notification_type, channel)
);

CREATE INDEX IF NOT EXISTS idx_notif_prefs_user_id ON notification_preferences(user_id);

-- Push subscription tokens (0048)
CREATE TABLE IF NOT EXISTS push_subscriptions (
  id              TEXT PRIMARY KEY,
  user_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform        TEXT NOT NULL
                  CHECK(platform IN ('web','ios','android')),
  endpoint        TEXT NOT NULL,
  p256dh_key      TEXT NOT NULL,
  auth_key        TEXT NOT NULL,
  device_name     TEXT,
  is_active       INTEGER NOT NULL DEFAULT 1,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  last_used_at    TEXT,
  UNIQUE(user_id, endpoint)
);

CREATE INDEX IF NOT EXISTS idx_push_subs_user_id ON push_subscriptions(user_id, is_active);

INSERT INTO _migrations (filename) VALUES ('0015_notifications.sql');
