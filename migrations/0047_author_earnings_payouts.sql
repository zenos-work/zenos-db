-- Migration: 0047_author_earnings_payouts
-- Revenue sharing and tipping model for authors.
-- Membership revenue is split between platform and authors based on read-time share.
-- Direct tips are a separate voluntary model.

-- ── AUTHOR EARNINGS (computed per period) ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS author_earnings (
  id                TEXT PRIMARY KEY,
  author_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  org_id            TEXT REFERENCES organizations(id) ON DELETE SET NULL,

  period_type       TEXT NOT NULL DEFAULT 'monthly'
                    CHECK(period_type IN ('daily','weekly','monthly')),
  period_start      TEXT NOT NULL,   -- ISO date of period start
  period_end        TEXT NOT NULL,   -- ISO date of period end

  -- Revenue sources
  premium_read_revenue_cents  INTEGER NOT NULL DEFAULT 0,  -- share from membership pool
  tip_revenue_cents           INTEGER NOT NULL DEFAULT 0,  -- direct tips received
  course_revenue_cents        INTEGER NOT NULL DEFAULT 0,  -- course sales share
  marketplace_revenue_cents   INTEGER NOT NULL DEFAULT 0,  -- marketplace item sales

  total_earnings_cents        INTEGER NOT NULL DEFAULT 0,  -- sum of all sources
  platform_fee_cents          INTEGER NOT NULL DEFAULT 0,  -- platform cut
  net_earnings_cents          INTEGER NOT NULL DEFAULT 0,  -- total - platform_fee

  -- Metrics that drove the earnings
  premium_reads_count         INTEGER NOT NULL DEFAULT 0,
  total_read_time_seconds     INTEGER NOT NULL DEFAULT 0,
  articles_contributing       INTEGER NOT NULL DEFAULT 0,

  status            TEXT NOT NULL DEFAULT 'pending'
                    CHECK(status IN ('pending','confirmed','paid','disputed')),

  created_at        TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at        TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(author_id, period_type, period_start)
);

CREATE INDEX IF NOT EXISTS idx_author_earnings_author_id  ON author_earnings(author_id, period_start DESC);
CREATE INDEX IF NOT EXISTS idx_author_earnings_status     ON author_earnings(status);
CREATE INDEX IF NOT EXISTS idx_author_earnings_org_id     ON author_earnings(org_id);

-- ── AUTHOR PAYOUTS ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS author_payouts (
  id                TEXT PRIMARY KEY,
  author_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  amount_cents      INTEGER NOT NULL,
  currency          TEXT NOT NULL DEFAULT 'USD',

  -- Payment method / processor
  payout_method     TEXT NOT NULL DEFAULT 'stripe'
                    CHECK(payout_method IN ('stripe','paypal','bank_transfer','manual')),
  stripe_transfer_id   TEXT,     -- Stripe Transfer or Payout ID
  external_reference   TEXT,     -- for non-Stripe methods

  status            TEXT NOT NULL DEFAULT 'pending'
                    CHECK(status IN ('pending','processing','completed','failed','cancelled')),
  failure_reason    TEXT,

  -- Period covered
  period_start      TEXT,
  period_end        TEXT,

  requested_at      TEXT NOT NULL DEFAULT (datetime('now')),
  processed_at      TEXT,
  completed_at      TEXT,
  created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_author_payouts_author_id ON author_payouts(author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_author_payouts_status    ON author_payouts(status);

-- ── TIP TRANSACTIONS ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tip_transactions (
  id                TEXT PRIMARY KEY,
  tipper_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  author_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  article_id        TEXT REFERENCES articles(id) ON DELETE SET NULL,

  amount_cents      INTEGER NOT NULL CHECK(amount_cents > 0),
  currency          TEXT NOT NULL DEFAULT 'USD',
  platform_fee_cents INTEGER NOT NULL DEFAULT 0,
  net_amount_cents  INTEGER NOT NULL DEFAULT 0,

  -- Payment processor
  stripe_payment_intent_id TEXT,
  status            TEXT NOT NULL DEFAULT 'completed'
                    CHECK(status IN ('pending','completed','refunded','failed')),

  message           TEXT,         -- optional thank-you message from tipper
  is_anonymous      INTEGER NOT NULL DEFAULT 0,

  created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_tips_tipper_id   ON tip_transactions(tipper_id);
CREATE INDEX IF NOT EXISTS idx_tips_author_id   ON tip_transactions(author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tips_article_id  ON tip_transactions(article_id);
CREATE INDEX IF NOT EXISTS idx_tips_status      ON tip_transactions(status);

-- ── PAYOUT SETTINGS (author's payment preferences) ───────────────────────────
ALTER TABLE users ADD COLUMN payout_method TEXT DEFAULT 'stripe'
  CHECK(payout_method IS NULL OR payout_method IN ('stripe','paypal','bank_transfer'));
ALTER TABLE users ADD COLUMN payout_email TEXT;          -- PayPal email or bank contact
ALTER TABLE users ADD COLUMN payout_min_cents INTEGER NOT NULL DEFAULT 5000;  -- min payout threshold ($50)
ALTER TABLE users ADD COLUMN stripe_connect_id TEXT;     -- Stripe Connect account ID
