
ALTER TABLE users
  ADD COLUMN terms_accepted_at TEXT DEFAULT NULL;

-- Index for fast lookup in AuthContext terms check
CREATE INDEX IF NOT EXISTS idx_users_terms
  ON users(id, terms_accepted_at);

INSERT INTO _migrations (filename)
VALUES ('0012_add_terms_acceptance.sql');
