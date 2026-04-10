-- 0043_article_coauthors.sql — Article coauthor mapping
CREATE TABLE IF NOT EXISTS article_coauthors (
  article_id   TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  added_by     TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at   TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (article_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_article_coauthors_article_id ON article_coauthors(article_id);
CREATE INDEX IF NOT EXISTS idx_article_coauthors_user_id ON article_coauthors(user_id);

INSERT INTO _migrations (filename) VALUES ('0043_article_coauthors.sql');
