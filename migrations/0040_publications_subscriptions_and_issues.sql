-- 0040_publications_subscriptions_and_issues.sql
-- Future-ready publication model for weekly newsletters and monthly magazine/e-book.

CREATE TABLE IF NOT EXISTS newsletter_subscriptions (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'subscribed', -- subscribed | unsubscribed | bounced
  source TEXT NOT NULL DEFAULT 'web',
  confirmed_at TEXT,
  unsubscribed_at TEXT,
  metadata_json TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  CHECK (status IN ('subscribed', 'unsubscribed', 'bounced'))
);

CREATE INDEX IF NOT EXISTS idx_newsletter_subscriptions_status ON newsletter_subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_newsletter_subscriptions_created_at ON newsletter_subscriptions(created_at);

CREATE TABLE IF NOT EXISTS publication_issues (
  id TEXT PRIMARY KEY,
  issue_type TEXT NOT NULL, -- newsletter | magazine | ebook
  title TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  period_start TEXT,
  period_end TEXT,
  status TEXT NOT NULL DEFAULT 'draft', -- draft | pending_review | approved | published | failed
  editorial_preface TEXT,
  toc_json TEXT,
  cover_article_id TEXT,
  total_pages INTEGER,
  pdf_r2_key TEXT,
  pdf_url TEXT,
  metadata_json TEXT,
  created_by_user_id TEXT,
  approved_by_user_id TEXT,
  approved_at TEXT,
  published_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  CHECK (issue_type IN ('newsletter', 'magazine', 'ebook')),
  CHECK (status IN ('draft', 'pending_review', 'approved', 'published', 'failed'))
);

CREATE INDEX IF NOT EXISTS idx_publication_issues_type_status ON publication_issues(issue_type, status);
CREATE INDEX IF NOT EXISTS idx_publication_issues_period ON publication_issues(period_start, period_end);

CREATE TABLE IF NOT EXISTS publication_issue_items (
  id TEXT PRIMARY KEY,
  issue_id TEXT NOT NULL,
  article_id TEXT,
  section TEXT NOT NULL DEFAULT 'features',
  position INTEGER NOT NULL DEFAULT 0,
  item_type TEXT NOT NULL DEFAULT 'article', -- article | editorial | index | ad | appendix
  title TEXT,
  excerpt TEXT,
  include_full_content INTEGER NOT NULL DEFAULT 1,
  metadata_json TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  FOREIGN KEY(issue_id) REFERENCES publication_issues(id) ON DELETE CASCADE,
  CHECK (item_type IN ('article', 'editorial', 'index', 'ad', 'appendix'))
);

CREATE INDEX IF NOT EXISTS idx_publication_issue_items_issue ON publication_issue_items(issue_id, position);

CREATE TABLE IF NOT EXISTS publication_generation_runs (
  id TEXT PRIMARY KEY,
  issue_id TEXT,
  job_name TEXT NOT NULL, -- weekly-newsletter | monthly-magazine
  trigger_source TEXT NOT NULL DEFAULT 'scheduled', -- scheduled | manual | replay
  status TEXT NOT NULL DEFAULT 'running', -- running | completed | failed
  started_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  finished_at TEXT,
  error_text TEXT,
  metrics_json TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  FOREIGN KEY(issue_id) REFERENCES publication_issues(id) ON DELETE SET NULL,
  CHECK (status IN ('running', 'completed', 'failed'))
);

CREATE INDEX IF NOT EXISTS idx_publication_generation_runs_job ON publication_generation_runs(job_name, status);

CREATE TABLE IF NOT EXISTS publication_deliveries (
  id TEXT PRIMARY KEY,
  issue_id TEXT NOT NULL,
  email TEXT NOT NULL,
  channel TEXT NOT NULL DEFAULT 'email',
  status TEXT NOT NULL DEFAULT 'queued', -- queued | sent | failed | bounced
  provider TEXT,
  provider_message_id TEXT,
  error_text TEXT,
  sent_at TEXT,
  last_attempt_at TEXT,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  FOREIGN KEY(issue_id) REFERENCES publication_issues(id) ON DELETE CASCADE,
  CHECK (status IN ('queued', 'sent', 'failed', 'bounced'))
);

CREATE INDEX IF NOT EXISTS idx_publication_deliveries_issue_status ON publication_deliveries(issue_id, status);
CREATE INDEX IF NOT EXISTS idx_publication_deliveries_email ON publication_deliveries(email);
