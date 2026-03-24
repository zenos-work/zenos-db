-- Migration: 0020_sr011_success_signal_events
-- Adds lightweight SR-011 event tracking and hourly aggregated success metrics.

CREATE TABLE IF NOT EXISTS article_events (
    id TEXT PRIMARY KEY,
    article_id TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
    actor_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL CHECK(event_type IN ('VIEW', 'LIKE', 'COMMENT', 'OUTCOME')),
    event_value INTEGER NOT NULL DEFAULT 1,
    event_source TEXT NOT NULL DEFAULT 'api',
    metadata_json TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_article_events_article_id ON article_events(article_id);
CREATE INDEX IF NOT EXISTS idx_article_events_event_type ON article_events(event_type);
CREATE INDEX IF NOT EXISTS idx_article_events_created_at ON article_events(created_at);
CREATE INDEX IF NOT EXISTS idx_article_events_article_time ON article_events(article_id, created_at);

CREATE TABLE IF NOT EXISTS article_success_hourly (
    article_id TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
    bucket_hour TEXT NOT NULL,
    views_count INTEGER NOT NULL DEFAULT 0,
    likes_count INTEGER NOT NULL DEFAULT 0,
    comments_count INTEGER NOT NULL DEFAULT 0,
    outcome_events_count INTEGER NOT NULL DEFAULT 0,
    outcome_tag_count INTEGER NOT NULL DEFAULT 0,
    engagement_score REAL NOT NULL DEFAULT 0,
    success_rate REAL NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (article_id, bucket_hour)
);

CREATE INDEX IF NOT EXISTS idx_article_success_hourly_bucket ON article_success_hourly(bucket_hour);
CREATE INDEX IF NOT EXISTS idx_article_success_hourly_rate ON article_success_hourly(success_rate DESC);

INSERT INTO _migrations (filename)
VALUES ('0020_sr011_success_signal_events.sql');
