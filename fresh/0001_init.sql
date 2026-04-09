-- 0001_init.sql — Bootstrap migration tracker
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS _migrations (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  filename  TEXT    NOT NULL UNIQUE,
  applied_at TEXT   NOT NULL DEFAULT (datetime('now'))
);

INSERT INTO _migrations (filename) VALUES ('0001_init.sql');
