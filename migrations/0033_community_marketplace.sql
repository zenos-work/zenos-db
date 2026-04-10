-- 0033_community_marketplace.sql — Spaces, posts, marketplace, referrals, podcasts
-- (merged: 0035)

CREATE TABLE IF NOT EXISTS community_spaces (
  id              TEXT PRIMARY KEY,
  org_id          TEXT REFERENCES organizations(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  slug            TEXT NOT NULL UNIQUE,
  description     TEXT,
  cover_image_url TEXT,
  icon            TEXT,
  space_type      TEXT NOT NULL DEFAULT 'open'
                  CHECK(space_type IN ('open','closed','secret')),
  membership_tier TEXT,
  member_count    INTEGER NOT NULL DEFAULT 0,
  post_count      INTEGER NOT NULL DEFAULT 0,
  created_by      TEXT NOT NULL REFERENCES users(id),
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_spaces_org_id ON community_spaces(org_id);
CREATE INDEX IF NOT EXISTS idx_spaces_slug   ON community_spaces(slug);

CREATE TABLE IF NOT EXISTS space_members (
  space_id  TEXT NOT NULL REFERENCES community_spaces(id) ON DELETE CASCADE,
  user_id   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role      TEXT NOT NULL DEFAULT 'member' CHECK(role IN ('owner','moderator','member')),
  joined_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (space_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_space_members_user_id ON space_members(user_id);

CREATE TABLE IF NOT EXISTS community_posts (
  id          TEXT PRIMARY KEY,
  space_id    TEXT NOT NULL REFERENCES community_spaces(id) ON DELETE CASCADE,
  author_id   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  parent_id   TEXT REFERENCES community_posts(id) ON DELETE CASCADE,
  title       TEXT,
  body        TEXT NOT NULL,
  post_type   TEXT NOT NULL DEFAULT 'discussion'
              CHECK(post_type IN ('discussion','question','announcement','poll','article_share')),
  article_id  TEXT REFERENCES articles(id) ON DELETE SET NULL,
  status      TEXT NOT NULL DEFAULT 'published'
              CHECK(status IN ('published','hidden','removed')),
  pinned      INTEGER NOT NULL DEFAULT 0,
  reply_count INTEGER NOT NULL DEFAULT 0,
  like_count  INTEGER NOT NULL DEFAULT 0,
  view_count  INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_comm_posts_space_id   ON community_posts(space_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comm_posts_author_id  ON community_posts(author_id);
CREATE INDEX IF NOT EXISTS idx_comm_posts_parent_id  ON community_posts(parent_id);
CREATE INDEX IF NOT EXISTS idx_comm_posts_article_id ON community_posts(article_id);

CREATE TABLE IF NOT EXISTS marketplace_items (
  id             TEXT PRIMARY KEY,
  seller_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  org_id         TEXT REFERENCES organizations(id) ON DELETE SET NULL,
  name           TEXT NOT NULL,
  slug           TEXT NOT NULL UNIQUE,
  short_desc     TEXT NOT NULL,
  long_desc      TEXT,
  item_type      TEXT NOT NULL
                 CHECK(item_type IN ('workflow_template','article_template','theme',
                                      'integration','plugin','dataset','course')),
  category       TEXT NOT NULL,
  price_cents    INTEGER NOT NULL DEFAULT 0,
  currency       TEXT NOT NULL DEFAULT 'USD',
  pricing_model  TEXT NOT NULL DEFAULT 'one_time'
                 CHECK(pricing_model IN ('one_time','subscription','free')),
  preview_images TEXT NOT NULL DEFAULT '[]',
  asset_url      TEXT,
  workflow_id    TEXT REFERENCES workflows(id) ON DELETE SET NULL,
  status         TEXT NOT NULL DEFAULT 'draft'
                 CHECK(status IN ('draft','pending_review','published','rejected','archived')),
  is_featured    INTEGER NOT NULL DEFAULT 0,
  download_count INTEGER NOT NULL DEFAULT 0,
  purchase_count INTEGER NOT NULL DEFAULT 0,
  rating_avg     REAL NOT NULL DEFAULT 0,
  rating_count   INTEGER NOT NULL DEFAULT 0,
  published_at   TEXT,
  created_at     TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at     TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_marketplace_seller_id ON marketplace_items(seller_id);
CREATE INDEX IF NOT EXISTS idx_marketplace_item_type ON marketplace_items(item_type);
CREATE INDEX IF NOT EXISTS idx_marketplace_status    ON marketplace_items(status);
CREATE INDEX IF NOT EXISTS idx_marketplace_featured  ON marketplace_items(is_featured, published_at DESC);

CREATE TABLE IF NOT EXISTS marketplace_purchases (
  id               TEXT PRIMARY KEY,
  item_id          TEXT NOT NULL REFERENCES marketplace_items(id) ON DELETE CASCADE,
  buyer_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  org_id           TEXT REFERENCES organizations(id) ON DELETE SET NULL,
  payment_id       TEXT,
  price_paid_cents INTEGER NOT NULL DEFAULT 0,
  currency         TEXT NOT NULL DEFAULT 'USD',
  status           TEXT NOT NULL DEFAULT 'completed'
                   CHECK(status IN ('pending','completed','refunded','disputed')),
  purchased_at     TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(item_id, buyer_id)
);

CREATE INDEX IF NOT EXISTS idx_purchases_item_id  ON marketplace_purchases(item_id);
CREATE INDEX IF NOT EXISTS idx_purchases_buyer_id ON marketplace_purchases(buyer_id);

CREATE TABLE IF NOT EXISTS marketplace_reviews (
  id          TEXT PRIMARY KEY,
  item_id     TEXT NOT NULL REFERENCES marketplace_items(id) ON DELETE CASCADE,
  reviewer_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating      INTEGER NOT NULL CHECK(rating BETWEEN 1 AND 5),
  body        TEXT,
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(item_id, reviewer_id)
);

CREATE INDEX IF NOT EXISTS idx_reviews_item_id ON marketplace_reviews(item_id);

CREATE TABLE IF NOT EXISTS referral_codes (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  code              TEXT NOT NULL UNIQUE,
  total_clicks      INTEGER NOT NULL DEFAULT 0,
  total_signups     INTEGER NOT NULL DEFAULT 0,
  total_conversions INTEGER NOT NULL DEFAULT 0,
  reward_credits    INTEGER NOT NULL DEFAULT 0,
  created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_referral_codes_code ON referral_codes(code);

CREATE TABLE IF NOT EXISTS referral_events (
  id               TEXT PRIMARY KEY,
  referral_code_id TEXT NOT NULL REFERENCES referral_codes(id) ON DELETE CASCADE,
  event_type       TEXT NOT NULL CHECK(event_type IN ('click','signup','conversion')),
  referred_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  metadata         TEXT NOT NULL DEFAULT '{}',
  created_at       TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_referral_events_code_id ON referral_events(referral_code_id);

CREATE TABLE IF NOT EXISTS podcast_shows (
  id              TEXT PRIMARY KEY,
  owner_id        TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  org_id          TEXT REFERENCES organizations(id) ON DELETE SET NULL,
  title           TEXT NOT NULL,
  slug            TEXT NOT NULL UNIQUE,
  description     TEXT,
  cover_image_url TEXT,
  rss_feed_url    TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_podcasts_owner_id ON podcast_shows(owner_id);

CREATE TABLE IF NOT EXISTS podcast_episodes (
  id                    TEXT PRIMARY KEY,
  show_id               TEXT NOT NULL REFERENCES podcast_shows(id) ON DELETE CASCADE,
  title                 TEXT NOT NULL,
  description           TEXT,
  audio_url             TEXT NOT NULL,
  duration_seconds      INTEGER NOT NULL DEFAULT 0,
  episode_number        INTEGER,
  transcript_article_id TEXT REFERENCES articles(id) ON DELETE SET NULL,
  published_at          TEXT,
  created_at            TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_episodes_show_id ON podcast_episodes(show_id);

INSERT INTO _migrations (filename) VALUES ('0033_community_marketplace.sql');
