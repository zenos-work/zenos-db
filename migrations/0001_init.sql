-- 0001_init.sql — Bootstrap migration tracker
-- NOTE: PRAGMA journal_mode and PRAGMA foreign_keys are intentionally omitted.
-- Wrangler's local D1 emulation (miniflare) blocks these with SQLITE_AUTH.
-- D1 manages WAL mode and foreign key enforcement at the runtime level.

CREATE TABLE IF NOT EXISTS _migrations (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  filename  TEXT    NOT NULL UNIQUE,
  applied_at TEXT   NOT NULL DEFAULT (datetime('now'))
);

INSERT INTO _migrations (filename) VALUES ('0001_init.sql');
