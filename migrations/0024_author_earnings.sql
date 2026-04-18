-- 0024_author_earnings.sql — Revenue sharing, payouts, and tipping
-- (merged: 0047 — payout columns already in 0002_users.sql)

CREATE TABLE IF NOT EXISTS author_earnings (
  id                          TEXT PRIMARY KEY,
  author_id                   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  org_id                      TEXT REFERENCES organizations(id) ON DELETE SET NULL,
  period_type                 TEXT NOT NULL DEFAULT 'monthly'
                              CHECK(period_type IN ('daily','weekly','monthly')),
  period_start                TEXT NOT NULL,
  period_end                  TEXT NOT NULL,
  premium_read_revenue_cents  INTEGER NOT NULL DEFAULT 0,
  tip_revenue_cents           INTEGER NOT NULL DEFAULT 0,
  course_revenue_cents        INTEGER NOT NULL DEFAULT 0,
  marketplace_revenue_cents   INTEGER NOT NULL DEFAULT 0,
  total_earnings_cents        INTEGER NOT NULL DEFAULT 0,
  platform_fee_cents          INTEGER NOT NULL DEFAULT 0,
  net_earnings_cents          INTEGER NOT NULL DEFAULT 0,
  premium_reads_count         INTEGER NOT NULL DEFAULT 0,
  total_read_time_seconds     INTEGER NOT NULL DEFAULT 0,
  articles_contributing       INTEGER NOT NULL DEFAULT 0,
  status                      TEXT NOT NULL DEFAULT 'pending'
                              CHECK(status IN ('pending','confirmed','paid','disputed')),
  created_at                  TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at                  TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(author_id, period_type, period_start)
);

CREATE INDEX IF NOT EXISTS idx_author_earnings_author_id ON author_earnings(author_id, period_start DESC);
CREATE INDEX IF NOT EXISTS idx_author_earnings_status    ON author_earnings(status);
CREATE INDEX IF NOT EXISTS idx_author_earnings_org_id    ON author_earnings(org_id);

CREATE TABLE IF NOT EXISTS author_payouts (
  id                   TEXT PRIMARY KEY,
  author_id            TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount_cents         INTEGER NOT NULL,
  currency             TEXT NOT NULL DEFAULT 'USD',
  payout_method        TEXT NOT NULL DEFAULT 'stripe'
                       CHECK(payout_method IN ('stripe','paypal','bank_transfer','manual')),
  stripe_transfer_id   TEXT,
  external_reference   TEXT,
  status               TEXT NOT NULL DEFAULT 'pending'
                       CHECK(status IN ('pending','processing','completed','failed','cancelled')),
  failure_reason       TEXT,
  period_start         TEXT,
  period_end           TEXT,
  requested_at         TEXT NOT NULL DEFAULT (datetime('now')),
  processed_at         TEXT,
  completed_at         TEXT,
  created_at           TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_author_payouts_author_id ON author_payouts(author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_author_payouts_status    ON author_payouts(status);

CREATE TABLE IF NOT EXISTS tip_transactions (
  id                        TEXT PRIMARY KEY,
  tipper_id                 TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  author_id                 TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  article_id                TEXT REFERENCES articles(id) ON DELETE SET NULL,
  amount_cents              INTEGER NOT NULL CHECK(amount_cents > 0),
  currency                  TEXT NOT NULL DEFAULT 'USD',
  platform_fee_cents        INTEGER NOT NULL DEFAULT 0,
  net_amount_cents          INTEGER NOT NULL DEFAULT 0,
  stripe_payment_intent_id  TEXT,
  status                    TEXT NOT NULL DEFAULT 'completed'
                            CHECK(status IN ('pending','completed','refunded','failed')),
  message                   TEXT,
  is_anonymous              INTEGER NOT NULL DEFAULT 0,
  created_at                TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_tips_tipper_id  ON tip_transactions(tipper_id);
CREATE INDEX IF NOT EXISTS idx_tips_author_id  ON tip_transactions(author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tips_article_id ON tip_transactions(article_id);
CREATE INDEX IF NOT EXISTS idx_tips_status     ON tip_transactions(status);

INSERT INTO _migrations (filename) VALUES ('0024_author_earnings.sql');
