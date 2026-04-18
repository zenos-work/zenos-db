-- 0010_articles_fts.sql — Full-text search virtual table + sync triggers (from 0014, 0019)
CREATE VIRTUAL TABLE IF NOT EXISTS articles_fts USING fts5(
  article_id UNINDEXED,
  title,
  subtitle,
  content,
  tokenize = 'unicode61 remove_diacritics 2'
);

-- Keep FTS in sync
CREATE TRIGGER IF NOT EXISTS trg_articles_fts_insert
AFTER INSERT ON articles
BEGIN
  INSERT INTO articles_fts (article_id, title, subtitle, content)
  VALUES (NEW.id, COALESCE(NEW.title,''), COALESCE(NEW.subtitle,''), COALESCE(NEW.content,''));
END;

CREATE TRIGGER IF NOT EXISTS trg_articles_fts_update
AFTER UPDATE OF title, subtitle, content ON articles
BEGIN
  DELETE FROM articles_fts WHERE article_id = OLD.id;
  INSERT INTO articles_fts (article_id, title, subtitle, content)
  VALUES (NEW.id, COALESCE(NEW.title,''), COALESCE(NEW.subtitle,''), COALESCE(NEW.content,''));
END;

CREATE TRIGGER IF NOT EXISTS trg_articles_fts_delete
AFTER DELETE ON articles
BEGIN
  DELETE FROM articles_fts WHERE article_id = OLD.id;
END;

INSERT INTO _migrations (filename) VALUES ('0010_articles_fts.sql');
