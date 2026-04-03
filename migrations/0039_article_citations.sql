-- Add optional citations array field for research-style source references.
-- Stored as JSON text (array of URLs), nullable.

ALTER TABLE articles ADD COLUMN citations TEXT;

INSERT INTO _migrations (filename) VALUES ('0039_article_citations.sql');
