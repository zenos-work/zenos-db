-- Migration: 0031_content_distribution_scheduling
-- Multi-channel content distribution, scheduled publishing, syndication, and social queuing.
-- Powers the 'distribute_content' and 'post_social' workflow action nodes.

-- ─── DISTRIBUTION CHANNELS (per-org channel registry) ────────────────────────
CREATE TABLE IF NOT EXISTS distribution_channels (
  id            TEXT PRIMARY KEY,
  org_id        TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,          -- user label: "Company Twitter"
  channel_type  TEXT NOT NULL
                CHECK(channel_type IN (
                  'email','rss','webhook','slack','twitter_x','linkedin',
                  'facebook','medium_import','dev_to','hashnode','custom'
                )),
  config        TEXT NOT NULL DEFAULT '{}',  -- JSON: channel-specific config (endpoint, credentials ref)
  kv_secret_key TEXT,                        -- KV key for encrypted credentials
  is_active     INTEGER NOT NULL DEFAULT 1,
  last_used_at  TEXT,
  created_by    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_dist_channels_org_id  ON distribution_channels(org_id);
CREATE INDEX IF NOT EXISTS idx_dist_channels_type    ON distribution_channels(channel_type);

-- ─── SCHEDULED PUBLICATIONS ───────────────────────────────────────────────────
-- Future-dated article publishes. A scheduler worker reads this table and fires
-- the article_published workflow trigger at the right time.
CREATE TABLE IF NOT EXISTS scheduled_publications (
  id            TEXT PRIMARY KEY,
  article_id    TEXT NOT NULL UNIQUE REFERENCES articles(id) ON DELETE CASCADE,
  scheduled_by  TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  scheduled_at  TEXT NOT NULL,    -- ISO 8601 datetime for publish
  timezone      TEXT NOT NULL DEFAULT 'UTC',
  status        TEXT NOT NULL DEFAULT 'pending'
                CHECK(status IN ('pending','published','cancelled','failed')),
  published_at  TEXT,
  error_message TEXT,
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_sched_pubs_status       ON scheduled_publications(status, scheduled_at ASC);
CREATE INDEX IF NOT EXISTS idx_sched_pubs_article_id   ON scheduled_publications(article_id);
CREATE INDEX IF NOT EXISTS idx_sched_pubs_scheduled_at ON scheduled_publications(scheduled_at ASC);

-- ─── CONTENT DISTRIBUTION JOBS ────────────────────────────────────────────────
-- A job distributes one article to one channel. Created by workflow dispatcher
-- or manually from admin UI.
CREATE TABLE IF NOT EXISTS content_distribution_jobs (
  id            TEXT PRIMARY KEY,
  org_id        TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  article_id    TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  channel_id    TEXT NOT NULL REFERENCES distribution_channels(id) ON DELETE CASCADE,

  -- Scheduling
  distribute_at TEXT,          -- NULL = immediate
  status        TEXT NOT NULL DEFAULT 'pending'
                CHECK(status IN ('pending','running','success','failed','cancelled')),

  -- Result tracking
  external_id   TEXT,          -- ID returned by target channel (tweet id, etc.)
  external_url  TEXT,          -- Public URL of the distributed content
  error_message TEXT,
  attempt_count INTEGER NOT NULL DEFAULT 0,

  -- Source
  triggered_by_run_id TEXT REFERENCES workflow_runs(id) ON DELETE SET NULL,

  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  finished_at   TEXT
);

CREATE INDEX IF NOT EXISTS idx_dist_jobs_org_id        ON content_distribution_jobs(org_id);
CREATE INDEX IF NOT EXISTS idx_dist_jobs_article_id    ON content_distribution_jobs(article_id);
CREATE INDEX IF NOT EXISTS idx_dist_jobs_channel_id    ON content_distribution_jobs(channel_id);
CREATE INDEX IF NOT EXISTS idx_dist_jobs_status        ON content_distribution_jobs(status, distribute_at ASC);
CREATE INDEX IF NOT EXISTS idx_dist_jobs_distribute_at ON content_distribution_jobs(distribute_at ASC);

-- ─── CONTENT SYNDICATION RECORDS ─────────────────────────────────────────────
-- Tracks articles that have been syndicated to external platforms with canonical links.
CREATE TABLE IF NOT EXISTS content_syndication (
  id              TEXT PRIMARY KEY,
  article_id      TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  platform        TEXT NOT NULL,   -- 'dev_to','hashnode','medium','substack','custom'
  external_url    TEXT NOT NULL,
  canonical_back_link TEXT,        -- the canonical tag pointing back to Zenos article
  syndicated_at   TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(article_id, platform)
);

CREATE INDEX IF NOT EXISTS idx_syndication_article_id ON content_syndication(article_id);
CREATE INDEX IF NOT EXISTS idx_syndication_platform   ON content_syndication(platform);

-- ─── RSS FEEDS (org-level custom RSS) ─────────────────────────────────────────
-- Each org can expose topic/author-filtered RSS feeds to embed or distribute via Feedly.
CREATE TABLE IF NOT EXISTS rss_feeds (
  id             TEXT PRIMARY KEY,
  org_id         TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name           TEXT NOT NULL,
  slug           TEXT NOT NULL,            -- URL segment: /feeds/{slug}
  description    TEXT,
  filter_tags    TEXT NOT NULL DEFAULT '[]',    -- JSON: only include articles with these tags
  filter_authors TEXT NOT NULL DEFAULT '[]',    -- JSON: only include these author IDs
  max_items      INTEGER NOT NULL DEFAULT 20,
  include_premium INTEGER NOT NULL DEFAULT 0,  -- 0 = free articles only
  is_active      INTEGER NOT NULL DEFAULT 1,
  created_at     TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(org_id, slug)
);

CREATE INDEX IF NOT EXISTS idx_rss_feeds_org_id ON rss_feeds(org_id);

-- ─── CONTENT REPURPOSING JOBS ─────────────────────────────────────────────────
-- AI-assisted repurposing: full article → tweet thread, LinkedIn post, email digest, etc.
CREATE TABLE IF NOT EXISTS content_repurposing_jobs (
  id              TEXT PRIMARY KEY,
  org_id          TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  article_id      TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  format          TEXT NOT NULL
                  CHECK(format IN ('tweet_thread','linkedin_post','email_summary',
                                   'short_form_blog','podcast_script','youtube_script')),
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK(status IN ('pending','processing','completed','failed')),
  input_options   TEXT NOT NULL DEFAULT '{}',  -- JSON: tone, length, keywords
  output_content  TEXT,                         -- generated text result
  created_by      TEXT NOT NULL REFERENCES users(id),
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  finished_at     TEXT
);

CREATE INDEX IF NOT EXISTS idx_repurpose_org_id     ON content_repurposing_jobs(org_id);
CREATE INDEX IF NOT EXISTS idx_repurpose_article_id ON content_repurposing_jobs(article_id);
CREATE INDEX IF NOT EXISTS idx_repurpose_status     ON content_repurposing_jobs(status);

INSERT INTO _migrations (filename) VALUES ('0031_content_distribution_scheduling.sql');
