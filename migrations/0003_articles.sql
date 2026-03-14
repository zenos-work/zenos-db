CREATE TABLE IF NOT EXISTS articles (
id TEXT PRIMARY KEY,
author_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
approved_by TEXT REFERENCES users(id) ON DELETE SET NULL,
title TEXT NOT NULL,
slug TEXT NOT NULL UNIQUE,
subtitle TEXT,
content TEXT NOT NULL,
cover_image_url TEXT,
read_time_minutes INTEGER NOT NULL DEFAULT 0,
status TEXT NOT NULL DEFAULT 'DRAFT'
CHECK(status IN ('DRAFT','SUBMITTED','APPROVED','REJECTED', 'ARCHIVED', 'PUBLISHED')),
rejection_note TEXT,
views_count INTEGER NOT NULL DEFAULT 0,
likes_count INTEGER NOT NULL DEFAULT 0,
comments_count INTEGER NOT NULL DEFAULT 0,
is_featured INTEGER NOT NULL DEFAULT 0,
published_at TEXT,
created_at TEXT NOT NULL DEFAULT (datetime('now')),
updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_articles_author_id
ON articles(author_id);
CREATE INDEX IF NOT EXISTS idx_articles_approved_by
ON articles(approved_by);
CREATE INDEX IF NOT EXISTS idx_articles_status
ON articles(status);
CREATE INDEX IF NOT EXISTS idx_articles_slug
ON articles(slug);
CREATE INDEX IF NOT EXISTS idx_articles_featured
ON articles(is_featured, published_at DESC);

INSERT INTO _migrations (filename)
VALUES ('0003_articles.sql');
