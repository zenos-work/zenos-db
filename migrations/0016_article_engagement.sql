-- 0016_article_engagement.sql — Events, success hourly, shares, dislikes, reactions + triggers
-- (merged: 0020 events, 0023 shares, 0024 dislikes+ranking_weights, 0025 reactions)

-- Article events (0020)
CREATE TABLE IF NOT EXISTS article_events (
  id              TEXT PRIMARY KEY,
  article_id      TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  actor_user_id   TEXT REFERENCES users(id) ON DELETE SET NULL,
  event_type      TEXT NOT NULL CHECK(event_type IN ('VIEW','LIKE','COMMENT','OUTCOME')),
  event_value     INTEGER NOT NULL DEFAULT 1,
  event_source    TEXT NOT NULL DEFAULT 'api',
  metadata_json   TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_article_events_article_id   ON article_events(article_id);
CREATE INDEX IF NOT EXISTS idx_article_events_event_type   ON article_events(event_type);
CREATE INDEX IF NOT EXISTS idx_article_events_created_at   ON article_events(created_at);
CREATE INDEX IF NOT EXISTS idx_article_events_article_time ON article_events(article_id, created_at);

-- Hourly success roll-up (0020)
CREATE TABLE IF NOT EXISTS article_success_hourly (
  article_id           TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  bucket_hour          TEXT NOT NULL,
  views_count          INTEGER NOT NULL DEFAULT 0,
  likes_count          INTEGER NOT NULL DEFAULT 0,
  comments_count       INTEGER NOT NULL DEFAULT 0,
  outcome_events_count INTEGER NOT NULL DEFAULT 0,
  outcome_tag_count    INTEGER NOT NULL DEFAULT 0,
  engagement_score     REAL NOT NULL DEFAULT 0,
  success_rate         REAL NOT NULL DEFAULT 0,
  created_at           TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at           TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (article_id, bucket_hour)
);

CREATE INDEX IF NOT EXISTS idx_article_success_hourly_bucket ON article_success_hourly(bucket_hour);
CREATE INDEX IF NOT EXISTS idx_article_success_hourly_rate   ON article_success_hourly(success_rate DESC);

-- Article shares (0023)
CREATE TABLE IF NOT EXISTS article_shares (
  id          TEXT PRIMARY KEY,
  article_id  TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  user_id     TEXT NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  provider    TEXT NOT NULL DEFAULT 'linkedin' CHECK(provider IN ('linkedin')),
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_article_shares_article_id    ON article_shares(article_id);
CREATE INDEX IF NOT EXISTS idx_article_shares_user_id       ON article_shares(user_id);
CREATE INDEX IF NOT EXISTS idx_article_shares_provider      ON article_shares(provider);
CREATE INDEX IF NOT EXISTS idx_article_shares_article_time  ON article_shares(article_id, created_at);

-- Article dislikes (0024)
CREATE TABLE IF NOT EXISTS article_dislikes (
  user_id    TEXT NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  article_id TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (user_id, article_id)
);

CREATE INDEX IF NOT EXISTS idx_article_dislikes_article_id  ON article_dislikes(article_id);
CREATE INDEX IF NOT EXISTS idx_article_dislikes_created_at  ON article_dislikes(created_at);

-- Ranking weights (0024)
CREATE TABLE IF NOT EXISTS ranking_weights (
  id              INTEGER PRIMARY KEY CHECK(id = 1),
  likes_weight    REAL NOT NULL DEFAULT 1.0,
  shares_weight   REAL NOT NULL DEFAULT 2.0,
  comments_weight REAL NOT NULL DEFAULT 1.5,
  dislikes_weight REAL NOT NULL DEFAULT -1.0,
  views_weight    REAL NOT NULL DEFAULT 0.1,
  recency_weight  REAL NOT NULL DEFAULT 0.25,
  updated_by      TEXT REFERENCES users(id),
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Article reactions (0025)
CREATE TABLE IF NOT EXISTS article_reactions (
  id            TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(12)))),
  article_id    TEXT NOT NULL,
  user_id       TEXT NOT NULL,
  reaction_type TEXT NOT NULL CHECK(reaction_type IN ('fire','lightbulb','heart','brain')),
  created_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(article_id, user_id, reaction_type),
  FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id)    REFERENCES users(id)    ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_article_reactions_article_id ON article_reactions(article_id);
CREATE INDEX IF NOT EXISTS idx_article_reactions_user_id    ON article_reactions(user_id);
CREATE INDEX IF NOT EXISTS idx_article_reactions_type       ON article_reactions(reaction_type);
-- Composite (0052)
CREATE INDEX IF NOT EXISTS idx_reactions_user_target  ON article_reactions(user_id, reaction_type, article_id);
CREATE INDEX IF NOT EXISTS idx_reactions_target_type  ON article_reactions(article_id, reaction_type);

-- Reaction count triggers (0025)
CREATE TRIGGER IF NOT EXISTS update_fire_reactions_count_insert
AFTER INSERT ON article_reactions WHEN NEW.reaction_type = 'fire'
BEGIN
  UPDATE articles SET fire_reactions_count = fire_reactions_count + 1, total_reactions_count = total_reactions_count + 1 WHERE id = NEW.article_id;
END;
CREATE TRIGGER IF NOT EXISTS update_fire_reactions_count_delete
AFTER DELETE ON article_reactions WHEN OLD.reaction_type = 'fire'
BEGIN
  UPDATE articles SET fire_reactions_count = MAX(0, fire_reactions_count - 1), total_reactions_count = MAX(0, total_reactions_count - 1) WHERE id = OLD.article_id;
END;

CREATE TRIGGER IF NOT EXISTS update_lightbulb_reactions_count_insert
AFTER INSERT ON article_reactions WHEN NEW.reaction_type = 'lightbulb'
BEGIN
  UPDATE articles SET lightbulb_reactions_count = lightbulb_reactions_count + 1, total_reactions_count = total_reactions_count + 1 WHERE id = NEW.article_id;
END;
CREATE TRIGGER IF NOT EXISTS update_lightbulb_reactions_count_delete
AFTER DELETE ON article_reactions WHEN OLD.reaction_type = 'lightbulb'
BEGIN
  UPDATE articles SET lightbulb_reactions_count = MAX(0, lightbulb_reactions_count - 1), total_reactions_count = MAX(0, total_reactions_count - 1) WHERE id = OLD.article_id;
END;

CREATE TRIGGER IF NOT EXISTS update_heart_reactions_count_insert
AFTER INSERT ON article_reactions WHEN NEW.reaction_type = 'heart'
BEGIN
  UPDATE articles SET heart_reactions_count = heart_reactions_count + 1, total_reactions_count = total_reactions_count + 1 WHERE id = NEW.article_id;
END;
CREATE TRIGGER IF NOT EXISTS update_heart_reactions_count_delete
AFTER DELETE ON article_reactions WHEN OLD.reaction_type = 'heart'
BEGIN
  UPDATE articles SET heart_reactions_count = MAX(0, heart_reactions_count - 1), total_reactions_count = MAX(0, total_reactions_count - 1) WHERE id = OLD.article_id;
END;

CREATE TRIGGER IF NOT EXISTS update_brain_reactions_count_insert
AFTER INSERT ON article_reactions WHEN NEW.reaction_type = 'brain'
BEGIN
  UPDATE articles SET brain_reactions_count = brain_reactions_count + 1, total_reactions_count = total_reactions_count + 1 WHERE id = NEW.article_id;
END;
CREATE TRIGGER IF NOT EXISTS update_brain_reactions_count_delete
AFTER DELETE ON article_reactions WHEN OLD.reaction_type = 'brain'
BEGIN
  UPDATE articles SET brain_reactions_count = MAX(0, brain_reactions_count - 1), total_reactions_count = MAX(0, total_reactions_count - 1) WHERE id = OLD.article_id;
END;

INSERT INTO _migrations (filename) VALUES ('0016_article_engagement.sql');
