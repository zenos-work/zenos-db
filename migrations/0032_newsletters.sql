-- Migration: 0032_newsletters
-- Newsletter management: definitions, issues, subscriber lists, sends, and engagement events.
-- Newsletters are distinct from email sequences (0030) — they are broadcast publications.

-- ─── NEWSLETTERS ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS newsletters (
  id              TEXT PRIMARY KEY,
  org_id          TEXT REFERENCES organizations(id) ON DELETE CASCADE,
  owner_id        TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  name            TEXT NOT NULL,
  slug            TEXT NOT NULL UNIQUE,   -- public subscribe URL path
  description     TEXT,
  logo_url        TEXT,
  cover_url       TEXT,

  -- Subscriber permission / branding
  from_name       TEXT NOT NULL,
  from_email      TEXT NOT NULL,
  reply_to_email  TEXT,

  -- Sending config
  esp_integration_id TEXT REFERENCES workflow_integrations(id) ON DELETE SET NULL,  -- which ESP to use

  -- Paywall
  is_premium_only  INTEGER NOT NULL DEFAULT 0,  -- paid subscribers only
  membership_tier  TEXT,                         -- minimum tier required

  status          TEXT NOT NULL DEFAULT 'active'
                  CHECK(status IN ('active','paused','archived')),
  subscriber_count INTEGER NOT NULL DEFAULT 0,

  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_newsletters_org_id   ON newsletters(org_id);
CREATE INDEX IF NOT EXISTS idx_newsletters_owner_id ON newsletters(owner_id);
CREATE INDEX IF NOT EXISTS idx_newsletters_slug     ON newsletters(slug);

-- ─── NEWSLETTER SUBSCRIBERS ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS newsletter_subscribers (
  id              TEXT PRIMARY KEY,
  newsletter_id   TEXT NOT NULL REFERENCES newsletters(id) ON DELETE CASCADE,
  email           TEXT NOT NULL,
  first_name      TEXT,
  last_name       TEXT,

  -- Link to lead or Zenos user if known
  lead_id         TEXT REFERENCES leads(id) ON DELETE SET NULL,
  user_id         TEXT REFERENCES users(id) ON DELETE SET NULL,

  status          TEXT NOT NULL DEFAULT 'subscribed'
                  CHECK(status IN ('subscribed','unsubscribed','bounced','complained','pending_confirmation')),

  -- Consent
  consent_at      TEXT,
  confirmation_token TEXT UNIQUE,   -- for double opt-in
  confirmed_at    TEXT,

  -- Engagement scores
  open_count      INTEGER NOT NULL DEFAULT 0,
  click_count     INTEGER NOT NULL DEFAULT 0,
  last_opened_at  TEXT,
  last_clicked_at TEXT,

  subscribed_at   TEXT NOT NULL DEFAULT (datetime('now')),
  unsubscribed_at TEXT,

  source          TEXT,  -- 'form','import','api','workflow','manual'
  UNIQUE(newsletter_id, email)
);

CREATE INDEX IF NOT EXISTS idx_newsletter_subs_newsletter_id ON newsletter_subscribers(newsletter_id);
CREATE INDEX IF NOT EXISTS idx_newsletter_subs_email         ON newsletter_subscribers(email);
CREATE INDEX IF NOT EXISTS idx_newsletter_subs_status        ON newsletter_subscribers(newsletter_id, status);
CREATE INDEX IF NOT EXISTS idx_newsletter_subs_lead_id       ON newsletter_subscribers(lead_id);
CREATE INDEX IF NOT EXISTS idx_newsletter_subs_user_id       ON newsletter_subscribers(user_id);

-- ─── NEWSLETTER ISSUES ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS newsletter_issues (
  id              TEXT PRIMARY KEY,
  newsletter_id   TEXT NOT NULL REFERENCES newsletters(id) ON DELETE CASCADE,

  subject         TEXT NOT NULL,
  preview_text    TEXT,         -- email preview/snippet line
  body_html       TEXT,         -- custom HTML body (if not auto-generated from articles)
  body_text       TEXT,

  -- Issue type
  issue_type      TEXT NOT NULL DEFAULT 'digest'
                  CHECK(issue_type IN ('digest','announcement','curated','automated')),

  -- If automated, generate from these articles
  article_ids     TEXT NOT NULL DEFAULT '[]',  -- JSON array of article IDs

  status          TEXT NOT NULL DEFAULT 'draft'
                  CHECK(status IN ('draft','scheduled','sending','sent','cancelled')),

  scheduled_at    TEXT,
  sent_at         TEXT,

  -- Engagement stats (populated after send)
  send_count      INTEGER NOT NULL DEFAULT 0,
  open_count      INTEGER NOT NULL DEFAULT 0,
  unique_opens    INTEGER NOT NULL DEFAULT 0,
  click_count     INTEGER NOT NULL DEFAULT 0,
  unique_clicks   INTEGER NOT NULL DEFAULT 0,
  unsub_count     INTEGER NOT NULL DEFAULT 0,
  bounce_count    INTEGER NOT NULL DEFAULT 0,

  created_by      TEXT NOT NULL REFERENCES users(id),
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_newsletter_issues_newsletter_id ON newsletter_issues(newsletter_id);
CREATE INDEX IF NOT EXISTS idx_newsletter_issues_status        ON newsletter_issues(status, scheduled_at ASC);

-- ─── NEWSLETTER ISSUE ARTICLES ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS newsletter_issue_articles (
  issue_id    TEXT NOT NULL REFERENCES newsletter_issues(id) ON DELETE CASCADE,
  article_id  TEXT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  blurb       TEXT,     -- optional override teaser for this issue
  PRIMARY KEY (issue_id, article_id)
);

CREATE INDEX IF NOT EXISTS idx_issue_articles_article_id ON newsletter_issue_articles(article_id);

-- ─── NEWSLETTER SEND EVENTS (per-subscriber engagement) ──────────────────────
CREATE TABLE IF NOT EXISTS newsletter_send_events (
  id              TEXT PRIMARY KEY,
  issue_id        TEXT NOT NULL REFERENCES newsletter_issues(id) ON DELETE CASCADE,
  subscriber_id   TEXT NOT NULL REFERENCES newsletter_subscribers(id) ON DELETE CASCADE,
  event_type      TEXT NOT NULL
                  CHECK(event_type IN ('delivered','opened','clicked','bounced','complained','unsubscribed')),
  link_url        TEXT,      -- for 'clicked' events
  metadata        TEXT NOT NULL DEFAULT '{}',  -- JSON: IP hash, client, etc.
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_send_events_issue_id       ON newsletter_send_events(issue_id);
CREATE INDEX IF NOT EXISTS idx_send_events_subscriber_id  ON newsletter_send_events(subscriber_id);
CREATE INDEX IF NOT EXISTS idx_send_events_type           ON newsletter_send_events(event_type);
CREATE INDEX IF NOT EXISTS idx_send_events_created_at     ON newsletter_send_events(created_at DESC);

-- ─── NEWSLETTER SEGMENTS ──────────────────────────────────────────────────────
-- Limit sends to a filtered subset of subscribers.
CREATE TABLE IF NOT EXISTS newsletter_segments (
  id             TEXT PRIMARY KEY,
  newsletter_id  TEXT NOT NULL REFERENCES newsletters(id) ON DELETE CASCADE,
  name           TEXT NOT NULL,
  filter_rules   TEXT NOT NULL DEFAULT '{}',  -- JSON: {membership_tier, tag_includes, subscribed_after, ...}
  created_at     TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_segments_newsletter_id ON newsletter_segments(newsletter_id);

INSERT INTO _migrations (filename) VALUES ('0032_newsletters.sql');
