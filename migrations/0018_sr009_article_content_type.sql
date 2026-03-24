ALTER TABLE articles
  ADD COLUMN content_type TEXT NOT NULL DEFAULT 'article'
  CHECK(content_type IN ('article', 'how-to', 'case-study', 'research'));

CREATE INDEX IF NOT EXISTS idx_articles_content_type
ON articles(content_type);

INSERT INTO _migrations (filename)
VALUES ('0018_sr009_article_content_type.sql');
