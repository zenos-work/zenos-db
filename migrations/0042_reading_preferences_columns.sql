-- Migration: 0042_reading_preferences_columns
-- Adds server-persisted reading preference columns to user_preferences.
-- The frontend useReadingPreferences hook currently stores these in localStorage;
-- these columns enable cross-device sync via the backend API.

ALTER TABLE user_preferences ADD COLUMN font_family TEXT NOT NULL DEFAULT 'serif'
  CHECK(font_family IN ('serif', 'sans'));

ALTER TABLE user_preferences ADD COLUMN font_size INTEGER NOT NULL DEFAULT 20
  CHECK(font_size BETWEEN 12 AND 32);

ALTER TABLE user_preferences ADD COLUMN content_width TEXT NOT NULL DEFAULT 'wide'
  CHECK(content_width IN ('wide', 'medium', 'narrow'));

-- Line height preference (future scope for accessibility)
ALTER TABLE user_preferences ADD COLUMN line_height TEXT NOT NULL DEFAULT 'normal'
  CHECK(line_height IN ('compact', 'normal', 'relaxed'));

-- Code block theme preference (for technical articles)
ALTER TABLE user_preferences ADD COLUMN code_theme TEXT NOT NULL DEFAULT 'auto'
  CHECK(code_theme IN ('auto', 'light', 'dark'));
