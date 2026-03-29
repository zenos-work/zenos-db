-- Migration: 0024_article_ranking_weights_and_dislikes
-- Adds dislikes persistence and superadmin-configurable ranking weights.

ALTER TABLE articles
ADD COLUMN dislikes_count INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS article_dislikes (
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    article_id TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (user_id, article_id)
);

CREATE INDEX IF NOT EXISTS idx_article_dislikes_article_id
ON article_dislikes(article_id);

CREATE INDEX IF NOT EXISTS idx_article_dislikes_created_at
ON article_dislikes(created_at);

CREATE TABLE IF NOT EXISTS ranking_weights (
    id INTEGER PRIMARY KEY CHECK(id = 1),
    likes_weight REAL NOT NULL DEFAULT 1.0,
    shares_weight REAL NOT NULL DEFAULT 2.0,
    comments_weight REAL NOT NULL DEFAULT 1.5,
    dislikes_weight REAL NOT NULL DEFAULT -1.0,
    views_weight REAL NOT NULL DEFAULT 0.1,
    recency_weight REAL NOT NULL DEFAULT 0.25,
    updated_by TEXT REFERENCES users(id),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO ranking_weights (
    id,
    likes_weight,
    shares_weight,
    comments_weight,
    dislikes_weight,
    views_weight,
    recency_weight
)
VALUES (1, 1.0, 2.0, 1.5, -1.0, 0.1, 0.25);

INSERT INTO _migrations (filename)
VALUES ('0024_article_ranking_weights_and_dislikes.sql');
