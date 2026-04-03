-- Phase 3: Membership and Premium Article Support (GAP-015, GAP-016, GAP-017)
-- Adds subscription/membership tracking to users and premium gating to articles

-- Add membership fields to users table
ALTER TABLE users ADD COLUMN membership_tier TEXT DEFAULT 'free'; -- 'free', 'creator_pro', 'team_suite'
ALTER TABLE users ADD COLUMN membership_status TEXT DEFAULT 'inactive'; -- 'inactive', 'active', 'cancelled', 'expired'
ALTER TABLE users ADD COLUMN subscription_started_at TIMESTAMP DEFAULT NULL;
ALTER TABLE users ADD COLUMN subscription_expires_at TIMESTAMP DEFAULT NULL;
ALTER TABLE users ADD COLUMN stripe_customer_id TEXT DEFAULT NULL;
ALTER TABLE users ADD COLUMN stripe_subscription_id TEXT DEFAULT NULL;
ALTER TABLE users ADD COLUMN premium_read_count INT DEFAULT 0; -- Track premium article reads (limit if applicable)
ALTER TABLE users ADD COLUMN last_premium_read_at TIMESTAMP DEFAULT NULL;

-- Create membership_plans table for plan information
CREATE TABLE IF NOT EXISTS membership_plans (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL, -- 'Starter', 'Creator Pro', 'Team Suite'
  tier TEXT NOT NULL UNIQUE, -- 'free', 'creator_pro', 'team_suite'
  price_monthly INT DEFAULT 0, -- in cents
  description TEXT,
  max_articles INT DEFAULT 999999, -- max articles user can write
  max_premium_reads INT DEFAULT 999999, -- max premium articles per month
  features TEXT, -- JSON array of feature strings
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create user_memberships table for subscription tracking
CREATE TABLE IF NOT EXISTS user_memberships (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  membership_tier TEXT NOT NULL,
  status TEXT NOT NULL, -- 'active', 'cancelled', 'expired', 'pending'
  started_at TIMESTAMP NOT NULL,
  expires_at TIMESTAMP DEFAULT NULL,
  stripe_subscription_id TEXT DEFAULT NULL,
  auto_renew INTEGER DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create premium_article_reads table for tracking and analytics (Phase 3: GAP-017)
CREATE TABLE IF NOT EXISTS premium_article_reads (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  article_id TEXT NOT NULL,
  accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  scroll_depth FLOAT DEFAULT 0, -- 0-100% of article read
  duration_seconds INT DEFAULT 0,
  conversion_event TEXT DEFAULT NULL, -- 'membership_upgrade', 'trial_activated', null
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE
);

-- Add premium_only field to articles table (Phase 3: GAP-015)
ALTER TABLE articles ADD COLUMN premium_only INTEGER DEFAULT 0; -- 1 = premium only, 0 = free to all
ALTER TABLE articles ADD COLUMN premium_teaser_words INT DEFAULT 300; -- words visible to free users

-- Create premium_funnel_events table for tracking conversion funnel (Phase 3: GAP-017)
CREATE TABLE IF NOT EXISTS premium_funnel_events (
  id TEXT PRIMARY KEY,
  user_id TEXT DEFAULT NULL, -- null for anonymous
  article_id TEXT NOT NULL,
  event_type TEXT NOT NULL, -- 'paywall_shown', 'paywall_clicked', 'signup_started', 'signup_completed', 'membership_upgraded'
  device_type TEXT DEFAULT NULL, -- 'mobile', 'desktop', 'tablet'
  referrer TEXT DEFAULT NULL,
  ip_hash TEXT DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE
);

-- Create indexes for common queries
CREATE INDEX idx_users_membership_tier ON users(membership_tier);
CREATE INDEX idx_users_membership_status ON users(membership_status);
CREATE INDEX idx_user_memberships_user_id ON user_memberships(user_id);
CREATE INDEX idx_user_memberships_status ON user_memberships(status);
CREATE INDEX idx_premium_reads_user_id ON premium_article_reads(user_id);
CREATE INDEX idx_premium_reads_article_id ON premium_article_reads(article_id);
CREATE INDEX idx_premium_reads_created_at ON premium_article_reads(accessed_at);
CREATE INDEX idx_articles_premium_only ON articles(premium_only);
CREATE INDEX idx_premium_funnel_user_id ON premium_funnel_events(user_id);
CREATE INDEX idx_premium_funnel_article_id ON premium_funnel_events(article_id);
CREATE INDEX idx_premium_funnel_event_type ON premium_funnel_events(event_type);

-- Seed default membership plans
INSERT INTO membership_plans (id, name, tier, price_monthly, description, max_articles, max_premium_reads, features)
VALUES
  (
    'plan_free_001',
    'Starter',
    'free',
    0,
    'For individual writers exploring Zenos.',
    999999,
    10,
    '["Rich editor", "Draft management", "Basic media uploads"]'
  ),
  (
    'plan_creator_pro_001',
    'Creator Pro',
    'creator_pro',
    0,
    'For creators publishing frequently with approval workflows.',
    999999,
    999999,
    '["Everything in Starter", "Approval workflows", "Priority support", "Advanced publishing controls", "Premium article access"]'
  ),
  (
    'plan_team_suite_001',
    'Team Suite',
    'team_suite',
    99999,
    'For editorial teams with governance and compliance needs.',
    999999,
    999999,
    '["Role-based governance", "Admin analytics", "Custom onboarding", "Dedicated success partner", "Priority support"]'
  );
