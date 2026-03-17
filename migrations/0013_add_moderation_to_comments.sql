-- Add moderation and spam flagging columns to comments table
ALTER TABLE comments ADD COLUMN is_hidden INTEGER NOT NULL DEFAULT 0;
ALTER TABLE comments ADD COLUMN moderation_reason TEXT;
ALTER TABLE comments ADD COLUMN moderated_by TEXT REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE comments ADD COLUMN moderated_at TEXT;
ALTER TABLE comments ADD COLUMN flag_count INTEGER NOT NULL DEFAULT 0;

-- Create index for moderation queries
CREATE INDEX IF NOT EXISTS idx_comments_is_hidden ON comments(is_hidden);
CREATE INDEX IF NOT EXISTS idx_comments_flag_count ON comments(flag_count);

INSERT INTO _migrations (filename)
VALUES ('0013_add_moderation_to_comments.sql');
