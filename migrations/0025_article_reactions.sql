-- Migration 0025: Add article reactions support
-- Adds support for multi-reaction system (Fire, Lightbulb, Heart, Brain)

-- Create reactions table
CREATE TABLE IF NOT EXISTS article_reactions (
  id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(12)))),
  article_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  reaction_type TEXT NOT NULL CHECK(reaction_type IN ('fire', 'lightbulb', 'heart', 'brain')),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,

  UNIQUE(article_id, user_id, reaction_type),
  FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_article_reactions_article_id ON article_reactions(article_id);
CREATE INDEX IF NOT EXISTS idx_article_reactions_user_id ON article_reactions(user_id);
CREATE INDEX IF NOT EXISTS idx_article_reactions_type ON article_reactions(reaction_type);

-- Add reaction count columns to articles table
ALTER TABLE articles ADD COLUMN fire_reactions_count INTEGER DEFAULT 0;
ALTER TABLE articles ADD COLUMN lightbulb_reactions_count INTEGER DEFAULT 0;
ALTER TABLE articles ADD COLUMN heart_reactions_count INTEGER DEFAULT 0;
ALTER TABLE articles ADD COLUMN brain_reactions_count INTEGER DEFAULT 0;
ALTER TABLE articles ADD COLUMN total_reactions_count INTEGER DEFAULT 0;

-- Create trigger to update fire_reactions_count
CREATE TRIGGER IF NOT EXISTS update_fire_reactions_count_insert
AFTER INSERT ON article_reactions
WHEN NEW.reaction_type = 'fire'
BEGIN
  UPDATE articles SET fire_reactions_count = fire_reactions_count + 1, total_reactions_count = total_reactions_count + 1 WHERE id = NEW.article_id;
END;

CREATE TRIGGER IF NOT EXISTS update_fire_reactions_count_delete
AFTER DELETE ON article_reactions
WHEN OLD.reaction_type = 'fire'
BEGIN
  UPDATE articles SET fire_reactions_count = MAX(0, fire_reactions_count - 1), total_reactions_count = MAX(0, total_reactions_count - 1) WHERE id = OLD.article_id;
END;

-- Create trigger for lightbulb_reactions_count
CREATE TRIGGER IF NOT EXISTS update_lightbulb_reactions_count_insert
AFTER INSERT ON article_reactions
WHEN NEW.reaction_type = 'lightbulb'
BEGIN
  UPDATE articles SET lightbulb_reactions_count = lightbulb_reactions_count + 1, total_reactions_count = total_reactions_count + 1 WHERE id = NEW.article_id;
END;

CREATE TRIGGER IF NOT EXISTS update_lightbulb_reactions_count_delete
AFTER DELETE ON article_reactions
WHEN OLD.reaction_type = 'lightbulb'
BEGIN
  UPDATE articles SET lightbulb_reactions_count = MAX(0, lightbulb_reactions_count - 1), total_reactions_count = MAX(0, total_reactions_count - 1) WHERE id = OLD.article_id;
END;

-- Create trigger for heart_reactions_count
CREATE TRIGGER IF NOT EXISTS update_heart_reactions_count_insert
AFTER INSERT ON article_reactions
WHEN NEW.reaction_type = 'heart'
BEGIN
  UPDATE articles SET heart_reactions_count = heart_reactions_count + 1, total_reactions_count = total_reactions_count + 1 WHERE id = NEW.article_id;
END;

CREATE TRIGGER IF NOT EXISTS update_heart_reactions_count_delete
AFTER DELETE ON article_reactions
WHEN OLD.reaction_type = 'heart'
BEGIN
  UPDATE articles SET heart_reactions_count = MAX(0, heart_reactions_count - 1), total_reactions_count = MAX(0, total_reactions_count - 1) WHERE id = OLD.article_id;
END;

-- Create trigger for brain_reactions_count
CREATE TRIGGER IF NOT EXISTS update_brain_reactions_count_insert
AFTER INSERT ON article_reactions
WHEN NEW.reaction_type = 'brain'
BEGIN
  UPDATE articles SET brain_reactions_count = brain_reactions_count + 1, total_reactions_count = total_reactions_count + 1 WHERE id = NEW.article_id;
END;

CREATE TRIGGER IF NOT EXISTS update_brain_reactions_count_delete
AFTER DELETE ON article_reactions
WHEN OLD.reaction_type = 'brain'
BEGIN
  UPDATE articles SET brain_reactions_count = MAX(0, brain_reactions_count - 1), total_reactions_count = MAX(0, total_reactions_count - 1) WHERE id = OLD.article_id;
END;
