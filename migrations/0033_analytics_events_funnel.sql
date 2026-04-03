-- Migration: 0033_analytics_events_funnel
-- Full analytics event stream, custom conversion funnels, UTM/attribution tracking,
-- A/B experiments, and campaign management.
-- Complements the existing premium_funnel_events (0027) and success_signal_events (0020).

-- ─── ANALYTICS EVENTS (generic event stream) ─────────────────────────────────
-- Single unified event table. Partitioned logically by event_category.
-- For very high volumes, Cloudflare Workers Analytics Engine is the preferred
-- hot path; this table holds enriched/processed events for funnel analysis.
CREATE TABLE IF NOT EXISTS analytics_events (
  id             TEXT PRIMARY KEY,
  org_id         TEXT REFERENCES organizations(id) ON DELETE SET NULL,
  user_id        TEXT REFERENCES users(id) ON DELETE SET NULL,
  session_id     TEXT,             -- anonymous session identifier
  anonymous_id   TEXT,             -- persistent anonymous device ID

  -- Event taxonomy
  event_category TEXT NOT NULL,
  -- 'page_view','article','engagement','workflow','lead','conversion','email','search'
  event_action   TEXT NOT NULL,
  -- 'viewed','read_completed','reacted','shared','followed','subscribed',
  -- 'form_submitted','paywall_shown','plan_upgraded','workflow_triggered',
  -- 'email_opened','email_clicked','search_performed', etc.

  -- Resource context
  resource_type  TEXT,             -- 'article','workflow','newsletter','form','course'
  resource_id    TEXT,             -- UUID of the resource

  -- Attribution
  utm_source     TEXT,
  utm_medium     TEXT,
  utm_campaign   TEXT,
  utm_content    TEXT,
  utm_term       TEXT,
  referrer_url   TEXT,
  landing_page   TEXT,

  -- Properties stored as JSON for flexibility
  properties     TEXT NOT NULL DEFAULT '{}',

  -- Device context
  device_type    TEXT CHECK(device_type IN ('desktop','mobile','tablet','bot',NULL)),
  country_code   TEXT,
  ip_hash        TEXT,    -- hashed for GDPR compliance

  created_at     TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_ae_org_id        ON analytics_events(org_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ae_user_id       ON analytics_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ae_session_id    ON analytics_events(session_id);
CREATE INDEX IF NOT EXISTS idx_ae_category      ON analytics_events(event_category, event_action);
CREATE INDEX IF NOT EXISTS idx_ae_resource      ON analytics_events(resource_type, resource_id);
CREATE INDEX IF NOT EXISTS idx_ae_created_at    ON analytics_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ae_anonymous_id  ON analytics_events(anonymous_id);

-- ─── CONVERSION GOALS ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS conversion_goals (
  id             TEXT PRIMARY KEY,
  org_id         TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name           TEXT NOT NULL,
  description    TEXT,
  goal_type      TEXT NOT NULL
                 CHECK(goal_type IN ('membership_signup','lead_captured','article_read',
                                      'email_subscription','form_submitted','custom_event',
                                      'workflow_completed')),
  target_event_category TEXT,
  target_event_action   TEXT,
  target_resource_id    TEXT,   -- NULL = any resource
  -- Optional: numeric value for revenue impact calculation
  value_cents    INTEGER NOT NULL DEFAULT 0,
  is_active      INTEGER NOT NULL DEFAULT 1,
  created_at     TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_conv_goals_org_id ON conversion_goals(org_id);

-- ─── CONVERSION EVENTS (goal completions) ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS conversion_events (
  id             TEXT PRIMARY KEY,
  goal_id        TEXT NOT NULL REFERENCES conversion_goals(id) ON DELETE CASCADE,
  org_id         TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id        TEXT REFERENCES users(id) ON DELETE SET NULL,
  anonymous_id   TEXT,
  session_id     TEXT,
  event_id       TEXT REFERENCES analytics_events(id) ON DELETE SET NULL,
  value_cents    INTEGER NOT NULL DEFAULT 0,   -- actual revenue value captured
  created_at     TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_conv_events_goal_id    ON conversion_events(goal_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_conv_events_org_id     ON conversion_events(org_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_conv_events_user_id    ON conversion_events(user_id);

-- ─── ATTRIBUTION TOUCHPOINTS (multi-touch attribution) ───────────────────────
-- Records every marketing touchpoint before a conversion.
CREATE TABLE IF NOT EXISTS attribution_touchpoints (
  id              TEXT PRIMARY KEY,
  conversion_id   TEXT REFERENCES conversion_events(id) ON DELETE CASCADE,
  org_id          TEXT REFERENCES organizations(id) ON DELETE SET NULL,
  user_id         TEXT REFERENCES users(id) ON DELETE SET NULL,
  anonymous_id    TEXT,
  touchpoint_type TEXT NOT NULL,   -- 'organic_search','social','email','referral','direct','paid'
  channel         TEXT,            -- 'twitter','google','newsletter','linkedin'
  utm_source      TEXT,
  utm_medium      TEXT,
  utm_campaign    TEXT,
  resource_type   TEXT,
  resource_id     TEXT,
  position        INTEGER,         -- 0=first, -1=last, or sequence number
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_attr_touch_conversion_id ON attribution_touchpoints(conversion_id);
CREATE INDEX IF NOT EXISTS idx_attr_touch_user_id       ON attribution_touchpoints(user_id);
CREATE INDEX IF NOT EXISTS idx_attr_touch_campaign      ON attribution_touchpoints(utm_campaign);

-- ─── CUSTOM FUNNEL DEFINITIONS ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS funnel_definitions (
  id          TEXT PRIMARY KEY,
  org_id      TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  description TEXT,
  is_active   INTEGER NOT NULL DEFAULT 1,
  created_by  TEXT NOT NULL REFERENCES users(id),
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_funnels_org_id ON funnel_definitions(org_id);

CREATE TABLE IF NOT EXISTS funnel_steps (
  id               TEXT PRIMARY KEY,
  funnel_id        TEXT NOT NULL REFERENCES funnel_definitions(id) ON DELETE CASCADE,
  step_number      INTEGER NOT NULL,
  name             TEXT NOT NULL,
  event_category   TEXT NOT NULL,
  event_action     TEXT NOT NULL,
  resource_type    TEXT,
  resource_id      TEXT,
  UNIQUE(funnel_id, step_number)
);

CREATE INDEX IF NOT EXISTS idx_funnel_steps_funnel_id ON funnel_steps(funnel_id);

-- ─── A/B EXPERIMENTS ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ab_experiments (
  id              TEXT PRIMARY KEY,
  org_id          TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  hypothesis      TEXT,
  status          TEXT NOT NULL DEFAULT 'draft'
                  CHECK(status IN ('draft','running','paused','completed','archived')),
  traffic_split   TEXT NOT NULL DEFAULT '{}',  -- JSON: {"control":50,"variant_a":50}
  success_goal_id TEXT REFERENCES conversion_goals(id) ON DELETE SET NULL,
  started_at      TEXT,
  ended_at        TEXT,
  winner_variant  TEXT,
  created_by      TEXT NOT NULL REFERENCES users(id),
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_experiments_org_id ON ab_experiments(org_id);
CREATE INDEX IF NOT EXISTS idx_experiments_status ON ab_experiments(status);

CREATE TABLE IF NOT EXISTS ab_experiment_variants (
  id             TEXT PRIMARY KEY,
  experiment_id  TEXT NOT NULL REFERENCES ab_experiments(id) ON DELETE CASCADE,
  name           TEXT NOT NULL,         -- 'control','variant_a','variant_b'
  description    TEXT,
  changes        TEXT NOT NULL DEFAULT '{}',   -- JSON describing what's different
  impressions    INTEGER NOT NULL DEFAULT 0,
  conversions    INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_ab_variants_experiment_id ON ab_experiment_variants(experiment_id);

CREATE TABLE IF NOT EXISTS ab_experiment_assignments (
  experiment_id  TEXT NOT NULL REFERENCES ab_experiments(id) ON DELETE CASCADE,
  anonymous_id   TEXT NOT NULL,   -- device-level bucket assignment
  variant_id     TEXT NOT NULL REFERENCES ab_experiment_variants(id) ON DELETE CASCADE,
  assigned_at    TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (experiment_id, anonymous_id)
);

CREATE INDEX IF NOT EXISTS idx_ab_assignments_variant ON ab_experiment_assignments(variant_id);

-- ─── CAMPAIGN TRACKING ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS campaigns (
  id            TEXT PRIMARY KEY,
  org_id        TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  description   TEXT,
  type          TEXT NOT NULL DEFAULT 'content'
                CHECK(type IN ('content','email','social','paid','referral','event')),
  status        TEXT NOT NULL DEFAULT 'active'
                CHECK(status IN ('planning','active','paused','completed','archived')),
  start_date    TEXT,
  end_date      TEXT,
  budget_cents  INTEGER,
  goal_id       TEXT REFERENCES conversion_goals(id) ON DELETE SET NULL,
  -- Aggregate stats (updated asynchronously)
  impressions   INTEGER NOT NULL DEFAULT 0,
  clicks        INTEGER NOT NULL DEFAULT 0,
  conversions   INTEGER NOT NULL DEFAULT 0,
  revenue_cents INTEGER NOT NULL DEFAULT 0,
  created_by    TEXT NOT NULL REFERENCES users(id),
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_campaigns_org_id ON campaigns(org_id);
CREATE INDEX IF NOT EXISTS idx_campaigns_status ON campaigns(status);

CREATE TABLE IF NOT EXISTS campaign_articles (
  campaign_id  TEXT NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  article_id   TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  PRIMARY KEY (campaign_id, article_id)
);

INSERT INTO _migrations (filename) VALUES ('0033_analytics_events_funnel.sql');
