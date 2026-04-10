-- 0027_content_distribution.sql — Multi-channel distribution, scheduling, syndication, RSS, repurposing
-- (merged: 0031)

CREATE TABLE IF NOT EXISTS distribution_channels (
  id            TEXT PRIMARY KEY,
  org_id        TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  channel_type  TEXT NOT NULL
                CHECK(channel_type IN (
                  'email','rss','webhook','slack','twitter_x','linkedin',
                  'facebook','medium_import','dev_to','hashnode','custom'
                )),
  config        TEXT NOT NULL DEFAULT '{}',
  kv_secret_key TEXT,
  is_active     INTEGER NOT NULL DEFAULT 1,
  last_used_at  TEXT,
  created_by    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_dist_channels_org_id ON distribution_channels(org_id);
CREATE INDEX IF NOT EXISTS idx_dist_channels_type   ON distribution_channels(channel_type);

CREATE TABLE IF NOT EXISTS scheduled_publications (
  id            TEXT PRIMARY KEY,
  article_id    TEXT NOT NULL UNIQUE REFERENCES articles(id) ON DELETE CASCADE,
  scheduled_by  TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  scheduled_at  TEXT NOT NULL,
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

CREATE TABLE IF NOT EXISTS content_distribution_jobs (
  id                  TEXT PRIMARY KEY,
  org_id              TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  article_id          TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  channel_id          TEXT NOT NULL REFERENCES distribution_channels(id) ON DELETE CASCADE,
  distribute_at       TEXT,
  status              TEXT NOT NULL DEFAULT 'pending'
                      CHECK(status IN ('pending','running','success','failed','cancelled')),
  external_id         TEXT,
  external_url        TEXT,
  error_message       TEXT,
  attempt_count       INTEGER NOT NULL DEFAULT 0,
  triggered_by_run_id TEXT REFERENCES workflow_runs(id) ON DELETE SET NULL,
  created_at          TEXT NOT NULL DEFAULT (datetime('now')),
  finished_at         TEXT
);

CREATE INDEX IF NOT EXISTS idx_dist_jobs_org_id        ON content_distribution_jobs(org_id);
CREATE INDEX IF NOT EXISTS idx_dist_jobs_article_id    ON content_distribution_jobs(article_id);
CREATE INDEX IF NOT EXISTS idx_dist_jobs_channel_id    ON content_distribution_jobs(channel_id);
CREATE INDEX IF NOT EXISTS idx_dist_jobs_status        ON content_distribution_jobs(status, distribute_at ASC);
CREATE INDEX IF NOT EXISTS idx_dist_jobs_distribute_at ON content_distribution_jobs(distribute_at ASC);

CREATE TABLE IF NOT EXISTS content_syndication (
  id                  TEXT PRIMARY KEY,
  article_id          TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  platform            TEXT NOT NULL,
  external_url        TEXT NOT NULL,
  canonical_back_link TEXT,
  syndicated_at       TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(article_id, platform)
);

CREATE INDEX IF NOT EXISTS idx_syndication_article_id ON content_syndication(article_id);
CREATE INDEX IF NOT EXISTS idx_syndication_platform   ON content_syndication(platform);

CREATE TABLE IF NOT EXISTS rss_feeds (
  id              TEXT PRIMARY KEY,
  org_id          TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  slug            TEXT NOT NULL,
  description     TEXT,
  filter_tags     TEXT NOT NULL DEFAULT '[]',
  filter_authors  TEXT NOT NULL DEFAULT '[]',
  max_items       INTEGER NOT NULL DEFAULT 20,
  include_premium INTEGER NOT NULL DEFAULT 0,
  is_active       INTEGER NOT NULL DEFAULT 1,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(org_id, slug)
);

CREATE INDEX IF NOT EXISTS idx_rss_feeds_org_id ON rss_feeds(org_id);

CREATE TABLE IF NOT EXISTS content_repurposing_jobs (
  id             TEXT PRIMARY KEY,
  org_id         TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  article_id     TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  format         TEXT NOT NULL
                 CHECK(format IN ('tweet_thread','linkedin_post','email_summary',
                                  'short_form_blog','podcast_script','youtube_script')),
  status         TEXT NOT NULL DEFAULT 'pending'
                 CHECK(status IN ('pending','processing','completed','failed')),
  input_options  TEXT NOT NULL DEFAULT '{}',
  output_content TEXT,
  created_by     TEXT NOT NULL REFERENCES users(id),
  created_at     TEXT NOT NULL DEFAULT (datetime('now')),
  finished_at    TEXT
);

CREATE INDEX IF NOT EXISTS idx_repurpose_org_id     ON content_repurposing_jobs(org_id);
CREATE INDEX IF NOT EXISTS idx_repurpose_article_id ON content_repurposing_jobs(article_id);
CREATE INDEX IF NOT EXISTS idx_repurpose_status     ON content_repurposing_jobs(status);

INSERT INTO _migrations (filename) VALUES ('0027_content_distribution.sql');
