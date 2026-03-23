-- Migration: 0015_sr012_016_article_moderation_seo_tags
-- Adds article verification/expiry, moderation metadata, SEO fields,
-- and outcome tag classification.

ALTER TABLE articles ADD COLUMN last_verified_at TEXT;
ALTER TABLE articles ADD COLUMN expires_at TEXT;
ALTER TABLE articles ADD COLUMN moderation_state TEXT NOT NULL DEFAULT 'NOT_REVIEWED';
ALTER TABLE articles ADD COLUMN moderation_note TEXT;
ALTER TABLE articles ADD COLUMN seo_title TEXT;
ALTER TABLE articles ADD COLUMN seo_description TEXT;
ALTER TABLE articles ADD COLUMN canonical_url TEXT;
ALTER TABLE articles ADD COLUMN og_image_url TEXT;
ALTER TABLE articles ADD COLUMN seo_schema_type TEXT NOT NULL DEFAULT 'Article';

ALTER TABLE tags ADD COLUMN tag_type TEXT NOT NULL DEFAULT 'topic'
CHECK(tag_type IN ('topic', 'outcome'));

CREATE INDEX IF NOT EXISTS idx_articles_expires_at ON articles(expires_at);
CREATE INDEX IF NOT EXISTS idx_articles_last_verified_at ON articles(last_verified_at);
CREATE INDEX IF NOT EXISTS idx_articles_moderation_state ON articles(moderation_state);
CREATE INDEX IF NOT EXISTS idx_tags_tag_type ON tags(tag_type);

CREATE TABLE IF NOT EXISTS notifications_new (
	id TEXT PRIMARY KEY,
	user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
	actor_id TEXT REFERENCES users(id) ON DELETE SET NULL,
	type TEXT NOT NULL CHECK (
		type IN (
			'LIKE',
			'COMMENT',
			'FOLLOW',
			'APPROVED',
			'REJECTED',
			'PUBLISHED',
			'MODERATION_PENDING',
			'MODERATION_REJECTED'
		)
	),
	article_id TEXT REFERENCES articles(id) ON DELETE CASCADE,
	comment_id TEXT REFERENCES comments(id) ON DELETE CASCADE,
	message TEXT NOT NULL,
	is_read INTEGER NOT NULL DEFAULT 0,
	created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT INTO notifications_new (id, user_id, actor_id, type, article_id, comment_id, message, is_read, created_at)
SELECT id, user_id, actor_id, type, article_id, comment_id, message, is_read, created_at
FROM notifications;

DROP TABLE notifications;
ALTER TABLE notifications_new RENAME TO notifications;

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_actor_id ON notifications(actor_id);
CREATE INDEX IF NOT EXISTS idx_notifications_article_id ON notifications(article_id);
CREATE INDEX IF NOT EXISTS idx_notifications_comment_id ON notifications(comment_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(created_at DESC);

INSERT INTO _migrations (filename)
VALUES ('0015_sr012_016_article_moderation_seo_tags.sql');
