-- Migration: 0023_article_shares_linkedin
-- Adds article share persistence and aggregate counters for SR-024 (LinkedIn first).

ALTER TABLE articles
ADD COLUMN shares_count INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS article_shares (
    id TEXT PRIMARY KEY,
    article_id TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider TEXT NOT NULL DEFAULT 'linkedin' CHECK(provider IN ('linkedin')),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_article_shares_article_id
ON article_shares(article_id);

CREATE INDEX IF NOT EXISTS idx_article_shares_user_id
ON article_shares(user_id);

CREATE INDEX IF NOT EXISTS idx_article_shares_provider
ON article_shares(provider);

CREATE INDEX IF NOT EXISTS idx_article_shares_article_time
ON article_shares(article_id, created_at);

INSERT INTO _migrations (filename)
VALUES ('0023_article_shares_linkedin.sql');
