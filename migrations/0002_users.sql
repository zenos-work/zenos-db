CREATE TABLE IF NOT EXISTS users (
id TEXT PRIMARY KEY,
email TEXT NOT NULL UNIQUE,
name TEXT NOT NULL,
avatar_url TEXT,
google_id TEXT UNIQUE,
role TEXT NOT NULL DEFAULT 'READER'
CHECK(role IN
('SUPERADMIN','APPROVER','AUTHOR','READER')),
is_active INTEGER NOT NULL DEFAULT 1,
created_at TEXT NOT NULL DEFAULT (datetime('now')),
updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_users_email
ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_google_id
ON users(google_id);
INSERT INTO _migrations (filename)
VALUES ('0002_users.sql');
