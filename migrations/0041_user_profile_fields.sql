-- Migration: 0041_user_profile_fields
-- Adds missing author-profile columns to the users table.
-- Frontend WriterOnboardingPage and ProfilePage already collect handle/bio
-- but currently store them only in localStorage — this migration persists them.

-- Unique @handle for profile URLs (/profile/:handle)
ALTER TABLE users ADD COLUMN handle TEXT UNIQUE;

-- Author bio (shown on profile, article byline, discovery sidebar)
ALTER TABLE users ADD COLUMN bio TEXT;

-- External website URL
ALTER TABLE users ADD COLUMN website_url TEXT;

-- JSON object: {"twitter":"","github":"","linkedin":"","instagram":"","youtube":""}
ALTER TABLE users ADD COLUMN social_links TEXT NOT NULL DEFAULT '{}';

-- Author geographic location (free text)
ALTER TABLE users ADD COLUMN location TEXT;

-- Profile banner/header image (R2 URL)
ALTER TABLE users ADD COLUMN cover_image_url TEXT;

-- Pronouns (free text, e.g. "he/him", "she/her", "they/them")
ALTER TABLE users ADD COLUMN pronouns TEXT;

-- Short tagline shown below name on cards
ALTER TABLE users ADD COLUMN tagline TEXT;

-- ── INDEXES ──────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_users_handle ON users(handle);
