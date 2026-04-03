-- Migration: 0020_article_reading_level
-- Adds reading_level field to articles for reader experience parity
-- Reading levels: 'Beginner', 'Intermediate', 'Advanced' or NULL for unspecified

ALTER TABLE articles
  ADD COLUMN reading_level TEXT
  CHECK(reading_level IS NULL OR reading_level IN ('Beginner', 'Intermediate', 'Advanced'));

CREATE INDEX IF NOT EXISTS idx_articles_reading_level
ON articles(reading_level);

INSERT INTO _migrations (filename)
VALUES ('0020_article_reading_level.sql');
