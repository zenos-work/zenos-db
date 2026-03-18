-- Migration: 0014_articles_fts
-- Creates FTS5 virtual table and sync triggers for article full-text search.
-- Tokeniser: unicode61 with diacritic stripping for multi-language resilience.

-- ── Virtual table ────────────────────────────────────────────────────────────
-- article_id is UNINDEXED — stored but not tokenised by the FTS engine so
-- it can be used for JOIN without affecting relevance scoring.
CREATE VIRTUAL TABLE IF NOT EXISTS articles_fts USING fts5(
    article_id UNINDEXED,
    title,
    subtitle,
    content,
    tokenize = "unicode61 remove_diacritics 2"
);

-- ── Backfill existing articles ────────────────────────────────────────────────
-- All statuses are indexed; status-based filtering happens at query time so
-- the index stays accurate across article lifecycle transitions.
INSERT INTO articles_fts (article_id, title, subtitle, content)
SELECT
    id,
    COALESCE(title, ''),
    COALESCE(subtitle, ''),
    COALESCE(content, '')
FROM articles;

-- ── Triggers: keep FTS in sync with articles table ───────────────────────────

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
