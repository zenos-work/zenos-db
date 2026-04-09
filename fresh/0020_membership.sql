-- 0020_membership.sql — Plans, user memberships, premium reads, funnel events + seed data
-- (merged: 0027 — user columns already in 0002_users.sql, article columns in 0008_articles.sql)

CREATE TABLE IF NOT EXISTS membership_plans (
  id                TEXT PRIMARY KEY,
  name              TEXT NOT NULL,
  tier              TEXT NOT NULL UNIQUE,
  price_monthly     INTEGER DEFAULT 0,
  description       TEXT,
  max_articles      INTEGER DEFAULT 999999,
  max_premium_reads INTEGER DEFAULT 999999,
  features          TEXT,
  created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_memberships (
  id                      TEXT PRIMARY KEY,
  user_id                 TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  membership_tier         TEXT NOT NULL,
  status                  TEXT NOT NULL CHECK(status IN ('active','cancelled','expired','pending')),
  started_at              TIMESTAMP NOT NULL,
  expires_at              TIMESTAMP,
  stripe_subscription_id  TEXT,
  auto_renew              INTEGER DEFAULT 1,
  created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_user_memberships_user_id ON user_memberships(user_id);
CREATE INDEX IF NOT EXISTS idx_user_memberships_status  ON user_memberships(status);

CREATE TABLE IF NOT EXISTS premium_article_reads (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  article_id        TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  accessed_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  scroll_depth      FLOAT DEFAULT 0,
  duration_seconds  INTEGER DEFAULT 0,
  conversion_event  TEXT
);

CREATE INDEX IF NOT EXISTS idx_premium_reads_user_id    ON premium_article_reads(user_id);
CREATE INDEX IF NOT EXISTS idx_premium_reads_article_id ON premium_article_reads(article_id);
CREATE INDEX IF NOT EXISTS idx_premium_reads_created_at ON premium_article_reads(accessed_at);

CREATE TABLE IF NOT EXISTS premium_funnel_events (
  id          TEXT PRIMARY KEY,
  user_id     TEXT,
  article_id  TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  event_type  TEXT NOT NULL,
  device_type TEXT,
  referrer    TEXT,
  ip_hash     TEXT,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_premium_funnel_user_id     ON premium_funnel_events(user_id);
CREATE INDEX IF NOT EXISTS idx_premium_funnel_article_id  ON premium_funnel_events(article_id);
CREATE INDEX IF NOT EXISTS idx_premium_funnel_event_type  ON premium_funnel_events(event_type);

-- Seed membership plans
INSERT OR IGNORE INTO membership_plans (id, name, tier, price_monthly, description, max_articles, max_premium_reads, features)
VALUES
  ('plan_free_001',        'Starter',     'free',        0,     'For individual writers exploring Zenos.',                        999999, 10,     '["Rich editor", "Draft management", "Basic media uploads"]'),
  ('plan_creator_pro_001', 'Creator Pro', 'creator_pro', 0,     'For creators publishing frequently with approval workflows.',    999999, 999999, '["Everything in Starter", "Approval workflows", "Priority support", "Advanced publishing controls", "Premium article access"]'),
  ('plan_team_suite_001',  'Team Suite',  'team_suite',  99999, 'For editorial teams with governance and compliance needs.',       999999, 999999, '["Role-based governance", "Admin analytics", "Custom onboarding", "Dedicated success partner", "Priority support"]');

INSERT INTO _migrations (filename) VALUES ('0020_membership.sql');
