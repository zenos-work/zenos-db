-- 0008_articles.sql — Articles table (merged: 0003, 0015, 0018, 0019, 0020, 0023, 0024, 0025, 0027, 0028, 0039, 0046, 0051)
-- NOTE: org_id FK to organizations defined here but organizations table comes later (0023).
--       SQLite does not enforce FK constraints at CREATE time; use PRAGMA foreign_keys=ON at connect.
CREATE TABLE IF NOT EXISTS articles (
  id                          TEXT PRIMARY KEY,
  author_id                   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  approved_by                 TEXT REFERENCES users(id) ON DELETE SET NULL,
  org_id                      TEXT,  -- FK to organizations(id), created in 0023

  title                       TEXT NOT NULL,
  slug                        TEXT NOT NULL UNIQUE,
  subtitle                    TEXT,
  content_type                TEXT NOT NULL DEFAULT 'article',
  content                     TEXT NOT NULL,
  cover_image_url             TEXT,
  read_time_minutes           INTEGER NOT NULL DEFAULT 0,

  status                      TEXT NOT NULL DEFAULT 'DRAFT'
                              CHECK(status IN ('DRAFT','SUBMITTED','APPROVED','REJECTED','ARCHIVED','PUBLISHED')),
  rejection_note              TEXT,

  -- Counts (denormalized)
  views_count                 INTEGER NOT NULL DEFAULT 0,
  likes_count                 INTEGER NOT NULL DEFAULT 0,
  comments_count              INTEGER NOT NULL DEFAULT 0,
  shares_count                INTEGER NOT NULL DEFAULT 0,
  dislikes_count              INTEGER NOT NULL DEFAULT 0,

  -- Reaction counts (0025)
  fire_reactions_count        INTEGER DEFAULT 0,
  lightbulb_reactions_count   INTEGER DEFAULT 0,
  heart_reactions_count       INTEGER DEFAULT 0,
  brain_reactions_count       INTEGER DEFAULT 0,
  total_reactions_count       INTEGER DEFAULT 0,

  is_featured                 INTEGER NOT NULL DEFAULT 0,
  published_at                TEXT,

  -- Moderation & verification (0015)
  last_verified_at            TEXT,
  expires_at                  TEXT,
  moderation_state            TEXT NOT NULL DEFAULT 'NOT_REVIEWED',
  moderation_note             TEXT,

  -- SEO (0015)
  seo_title                   TEXT,
  seo_description             TEXT,
  canonical_url               TEXT,
  og_image_url                TEXT,
  seo_schema_type             TEXT NOT NULL DEFAULT 'Article',

  -- Reading level (0020)
  reading_level               TEXT
                              CHECK(reading_level IS NULL OR reading_level IN ('Beginner','Intermediate','Advanced')),

  -- Premium (0027)
  premium_only                INTEGER DEFAULT 0,
  premium_teaser_words        INT DEFAULT 300,

  -- Citations (0039)
  citations                   TEXT,

  -- Revision tracking (0046)
  current_revision            INTEGER NOT NULL DEFAULT 1,

  -- Enterprise security classification (0051)
  security_level              TEXT NOT NULL DEFAULT 'public'
                              CHECK(security_level IN ('public','internal','confidential','restricted')),

  -- Scheduling
  scheduled_publish_date      TEXT,

  created_at                  TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at                  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_articles_author_id         ON articles(author_id);
CREATE INDEX IF NOT EXISTS idx_articles_approved_by       ON articles(approved_by);
CREATE INDEX IF NOT EXISTS idx_articles_status            ON articles(status);
CREATE INDEX IF NOT EXISTS idx_articles_slug              ON articles(slug);
CREATE INDEX IF NOT EXISTS idx_articles_featured          ON articles(is_featured, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_articles_expires_at        ON articles(expires_at);
CREATE INDEX IF NOT EXISTS idx_articles_last_verified_at  ON articles(last_verified_at);
CREATE INDEX IF NOT EXISTS idx_articles_moderation_state  ON articles(moderation_state);
CREATE INDEX IF NOT EXISTS idx_articles_content_type      ON articles(content_type);
CREATE INDEX IF NOT EXISTS idx_articles_reading_level     ON articles(reading_level);
CREATE INDEX IF NOT EXISTS idx_articles_premium_only      ON articles(premium_only);
CREATE INDEX IF NOT EXISTS idx_articles_org_id            ON articles(org_id);
CREATE INDEX IF NOT EXISTS idx_articles_security_level    ON articles(security_level);
-- Composite indexes (from 0052)
CREATE INDEX IF NOT EXISTS idx_articles_author_status_pub    ON articles(author_id, status, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_articles_org_status           ON articles(org_id, status, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_articles_content_type_status  ON articles(content_type, status, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_articles_org_security         ON articles(org_id, security_level);
CREATE INDEX IF NOT EXISTS idx_articles_scheduled            ON articles(status, scheduled_publish_date) WHERE status = 'scheduled';

INSERT INTO _migrations (filename) VALUES ('0008_articles.sql');
