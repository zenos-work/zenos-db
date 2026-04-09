-- 0002_users.sql — Users table (merged: 0002, 0012, 0027, 0041, 0047)
CREATE TABLE IF NOT EXISTS users (
  id                     TEXT PRIMARY KEY,
  email                  TEXT NOT NULL UNIQUE,
  name                   TEXT NOT NULL,
  avatar_url             TEXT,
  google_id              TEXT UNIQUE,
  role                   TEXT NOT NULL DEFAULT 'READER'
                         CHECK(role IN ('SUPERADMIN','APPROVER','AUTHOR','READER')),
  is_active              INTEGER NOT NULL DEFAULT 1,

  -- Terms acceptance (0012)
  terms_accepted_at      TEXT DEFAULT NULL,

  -- Membership & billing (0027)
  membership_tier        TEXT DEFAULT 'free',
  membership_status      TEXT DEFAULT 'inactive',
  subscription_started_at TIMESTAMP DEFAULT NULL,
  subscription_expires_at TIMESTAMP DEFAULT NULL,
  stripe_customer_id     TEXT DEFAULT NULL,
  stripe_subscription_id TEXT DEFAULT NULL,
  premium_read_count     INT DEFAULT 0,
  last_premium_read_at   TIMESTAMP DEFAULT NULL,

  -- Profile (0041)
  handle                 TEXT UNIQUE,
  bio                    TEXT,
  website_url            TEXT,
  social_links           TEXT NOT NULL DEFAULT '{}',
  location               TEXT,
  cover_image_url        TEXT,
  pronouns               TEXT,
  tagline                TEXT,

  -- Payout (0047)
  payout_method          TEXT DEFAULT 'stripe'
                         CHECK(payout_method IN ('stripe','paypal','bank_transfer')),
  payout_email           TEXT,
  payout_min_cents       INTEGER NOT NULL DEFAULT 5000,
  stripe_connect_id      TEXT,

  created_at             TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at             TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_users_email             ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_google_id         ON users(google_id);
CREATE INDEX IF NOT EXISTS idx_users_terms             ON users(id, terms_accepted_at);
CREATE INDEX IF NOT EXISTS idx_users_membership_tier   ON users(membership_tier);
CREATE INDEX IF NOT EXISTS idx_users_membership_status ON users(membership_status);
CREATE INDEX IF NOT EXISTS idx_users_handle            ON users(handle);

INSERT INTO _migrations (filename) VALUES ('0002_users.sql');
