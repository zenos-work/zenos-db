-- Rename notifications_enabled to email_notifs in user_preferences
ALTER TABLE user_preferences RENAME COLUMN notifications_enabled TO email_notifs;

INSERT INTO _migrations (filename)
VALUES ('0022_rename_notifications_enabled_to_email_notifs.sql');
