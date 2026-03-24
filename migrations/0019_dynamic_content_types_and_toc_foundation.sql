-- Migration: 0019_dynamic_content_types_and_toc_foundation
-- Adds dynamic content-type registry and removes static CHECK constraint from articles.content_type.

PRAGMA foreign_keys = OFF;

CREATE TABLE IF NOT EXISTS content_types (
    id TEXT PRIMARY KEY,
    slug TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    is_active INTEGER NOT NULL DEFAULT 1,
    is_system INTEGER NOT NULL DEFAULT 0,
    sort_order INTEGER NOT NULL DEFAULT 100,
    created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_content_types_active ON content_types(is_active);
CREATE INDEX IF NOT EXISTS idx_content_types_sort ON content_types(sort_order, name);

INSERT OR IGNORE INTO content_types (id, slug, name, description, is_active, is_system, sort_order)
VALUES
    ('ct-article', 'article', 'Article', 'General long-form editorial content', 1, 1, 10),
    ('ct-how-to', 'how-to', 'How-to', 'Instructional or tutorial-driven content', 1, 1, 20),
    ('ct-case-study', 'case-study', 'Case Study', 'Experience-backed implementation stories', 1, 1, 30),
    ('ct-research', 'research', 'Research', 'Evidence-driven analysis and findings', 1, 1, 40);

DROP TRIGGER IF EXISTS trg_articles_fts_insert;
DROP TRIGGER IF EXISTS trg_articles_fts_update;
DROP TRIGGER IF EXISTS trg_articles_fts_delete;

CREATE TABLE articles_new (
    id TEXT PRIMARY KEY,
    author_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    approved_by TEXT REFERENCES users(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    subtitle TEXT,
    content_type TEXT NOT NULL DEFAULT 'article',
    content TEXT NOT NULL,
    cover_image_url TEXT,
    read_time_minutes INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'DRAFT' CHECK(status IN ('DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED', 'ARCHIVED', 'PUBLISHED')),
    rejection_note TEXT,
    views_count INTEGER NOT NULL DEFAULT 0,
    likes_count INTEGER NOT NULL DEFAULT 0,
    comments_count INTEGER NOT NULL DEFAULT 0,
    is_featured INTEGER NOT NULL DEFAULT 0,
    published_at TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    last_verified_at TEXT,
    expires_at TEXT,
    moderation_state TEXT NOT NULL DEFAULT 'NOT_REVIEWED',
    moderation_note TEXT,
    seo_title TEXT,
    seo_description TEXT,
    canonical_url TEXT,
    og_image_url TEXT,
    seo_schema_type TEXT NOT NULL DEFAULT 'Article'
);

INSERT INTO articles_new (
    id,
    author_id,
    approved_by,
    title,
    slug,
    subtitle,
    content_type,
    content,
    cover_image_url,
    read_time_minutes,
    status,
    rejection_note,
    views_count,
    likes_count,
    comments_count,
    is_featured,
    published_at,
    created_at,
    updated_at,
    last_verified_at,
    expires_at,
    moderation_state,
    moderation_note,
    seo_title,
    seo_description,
    canonical_url,
    og_image_url,
    seo_schema_type
)
SELECT
    id,
    author_id,
    approved_by,
    title,
    slug,
    subtitle,
    COALESCE(NULLIF(content_type, ''), 'article') AS content_type,
    content,
    cover_image_url,
    read_time_minutes,
    status,
    rejection_note,
    views_count,
    likes_count,
    comments_count,
    is_featured,
    published_at,
    created_at,
    updated_at,
    last_verified_at,
    expires_at,
    moderation_state,
    moderation_note,
    seo_title,
    seo_description,
    canonical_url,
    og_image_url,
    seo_schema_type
FROM articles;

DROP TABLE articles;
ALTER TABLE articles_new RENAME TO articles;

CREATE INDEX IF NOT EXISTS idx_articles_author_id ON articles(author_id);
CREATE INDEX IF NOT EXISTS idx_articles_approved_by ON articles(approved_by);
CREATE INDEX IF NOT EXISTS idx_articles_status ON articles(status);
CREATE INDEX IF NOT EXISTS idx_articles_slug ON articles(slug);
CREATE INDEX IF NOT EXISTS idx_articles_featured ON articles(is_featured, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_articles_expires_at ON articles(expires_at);
CREATE INDEX IF NOT EXISTS idx_articles_last_verified_at ON articles(last_verified_at);
CREATE INDEX IF NOT EXISTS idx_articles_moderation_state ON articles(moderation_state);
CREATE INDEX IF NOT EXISTS idx_articles_content_type ON articles(content_type);

DELETE FROM articles_fts;
INSERT INTO articles_fts (article_id, title, subtitle, content)
SELECT
    id,
    COALESCE(title, ''),
    COALESCE(subtitle, ''),
    COALESCE(content, '')
FROM articles;

CREATE TRIGGER IF NOT EXISTS trg_articles_fts_insert
AFTER INSERT ON articles
BEGIN
    INSERT INTO articles_fts (article_id, title, subtitle, content)
    VALUES (
        NEW.id,
        COALESCE(NEW.title, ''),
        COALESCE(NEW.subtitle, ''),
        COALESCE(NEW.content, '')
    );
END;

CREATE TRIGGER IF NOT EXISTS trg_articles_fts_update
AFTER UPDATE OF title, subtitle, content ON articles
BEGIN
    DELETE FROM articles_fts WHERE article_id = OLD.id;
    INSERT INTO articles_fts (article_id, title, subtitle, content)
    VALUES (
        NEW.id,
        COALESCE(NEW.title, ''),
        COALESCE(NEW.subtitle, ''),
        COALESCE(NEW.content, '')
    );
END;

CREATE TRIGGER IF NOT EXISTS trg_articles_fts_delete
AFTER DELETE ON articles
BEGIN
    DELETE FROM articles_fts WHERE article_id = OLD.id;
END;

PRAGMA foreign_keys = ON;

INSERT INTO _migrations (filename)
VALUES ('0019_dynamic_content_types_and_toc_foundation.sql');
