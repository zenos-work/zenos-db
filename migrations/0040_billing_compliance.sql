-- 0040_billing_compliance.sql — Stripe billing, reconciliation, and GDPR compliance
-- Covers: billing webhook idempotency, discrepancy tracking, data export requests

-- ─── STRIPE WEBHOOK EVENTS (idempotency) ──────────────────────────────────────
-- Prevents double-processing of Stripe webhook deliveries
CREATE TABLE IF NOT EXISTS stripe_webhook_events (
  id              TEXT PRIMARY KEY,
  event_id        TEXT NOT NULL UNIQUE,
  event_type      TEXT NOT NULL,
  api_version     TEXT,
  livemode        INTEGER NOT NULL DEFAULT 1,
  payload_hash    TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'received'
                  CHECK(status IN ('received','processing','processed','failed','ignored')),
  error_message   TEXT,
  processed_at    TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_stripe_wh_event_id   ON stripe_webhook_events(event_id);
CREATE INDEX IF NOT EXISTS idx_stripe_wh_type       ON stripe_webhook_events(event_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stripe_wh_status     ON stripe_webhook_events(status);

-- ─── BILLING DISCREPANCIES ────────────────────────────────────────────────────
-- Flagged during monthly reconciliation when Stripe records don't match local state
CREATE TABLE IF NOT EXISTS billing_discrepancies (
  id                TEXT PRIMARY KEY,
  period            TEXT NOT NULL,
  discrepancy_type  TEXT NOT NULL
                    CHECK(discrepancy_type IN (
                      'subscription_mismatch',
                      'amount_mismatch',
                      'missing_local_record',
                      'missing_stripe_record',
                      'status_mismatch',
                      'payout_mismatch',
                      'add_on_mismatch',
                      'other'
                    )),
  severity          TEXT NOT NULL DEFAULT 'warning'
                    CHECK(severity IN ('info','warning','critical')),
  entity_type       TEXT NOT NULL
                    CHECK(entity_type IN ('user_membership','org_add_on','author_payout','tip_transaction')),
  entity_id         TEXT NOT NULL,
  org_id            TEXT REFERENCES organizations(id) ON DELETE SET NULL,
  user_id           TEXT REFERENCES users(id) ON DELETE SET NULL,
  stripe_record     TEXT NOT NULL DEFAULT '{}',
  local_record      TEXT NOT NULL DEFAULT '{}',
  difference_detail TEXT NOT NULL DEFAULT '{}',
  resolution_status TEXT NOT NULL DEFAULT 'open'
                    CHECK(resolution_status IN ('open','investigating','resolved','ignored')),
  resolved_by       TEXT REFERENCES users(id) ON DELETE SET NULL,
  resolved_at       TEXT,
  resolution_note   TEXT,
  created_at        TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_billing_disc_period   ON billing_discrepancies(period);
CREATE INDEX IF NOT EXISTS idx_billing_disc_type     ON billing_discrepancies(discrepancy_type);
CREATE INDEX IF NOT EXISTS idx_billing_disc_severity ON billing_discrepancies(severity, resolution_status);
CREATE INDEX IF NOT EXISTS idx_billing_disc_entity   ON billing_discrepancies(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_billing_disc_org_id   ON billing_discrepancies(org_id);
CREATE INDEX IF NOT EXISTS idx_billing_disc_status   ON billing_discrepancies(resolution_status);

-- ─── DATA EXPORT REQUESTS (GDPR Art. 15) ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS data_export_requests (
  id             TEXT PRIMARY KEY,
  user_id        TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  request_type   TEXT NOT NULL DEFAULT 'full_export'
                 CHECK(request_type IN ('full_export','articles_only','profile_only','activity_only')),
  status         TEXT NOT NULL DEFAULT 'pending'
                 CHECK(status IN ('pending','processing','completed','failed','expired','downloaded')),
  job_id         TEXT REFERENCES job_queue(id) ON DELETE SET NULL,
  file_r2_key    TEXT,
  file_url       TEXT,
  file_size_bytes INTEGER,
  file_expires_at TEXT,
  error_message  TEXT,
  requested_at   TEXT NOT NULL DEFAULT (datetime('now')),
  processing_at  TEXT,
  completed_at   TEXT,
  downloaded_at  TEXT,
  created_at     TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_data_export_user_id ON data_export_requests(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_data_export_status  ON data_export_requests(status);
CREATE INDEX IF NOT EXISTS idx_data_export_expires ON data_export_requests(file_expires_at)
  WHERE status = 'completed';

-- ─── DATA ERASURE REQUESTS (GDPR Art. 17) ────────────────────────────────────
CREATE TABLE IF NOT EXISTS data_erasure_requests (
  id               TEXT PRIMARY KEY,
  user_id          TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status           TEXT NOT NULL DEFAULT 'pending'
                   CHECK(status IN (
                     'pending',
                     'cooling_off',
                     'processing',
                     'completed',
                     'cancelled',
                     'failed'
                   )),
  job_id           TEXT REFERENCES job_queue(id) ON DELETE SET NULL,
  reason           TEXT,
  cooling_off_ends TEXT,
  anonymized_id    TEXT,
  articles_action  TEXT NOT NULL DEFAULT 'anonymize'
                   CHECK(articles_action IN ('anonymize','delete_drafts_only','delete_all')),
  media_deleted    INTEGER NOT NULL DEFAULT 0,
  kv_secrets_deleted INTEGER NOT NULL DEFAULT 0,
  tables_processed TEXT NOT NULL DEFAULT '[]',
  error_message    TEXT,
  requested_at     TEXT NOT NULL DEFAULT (datetime('now')),
  confirmed_at     TEXT,
  processing_at    TEXT,
  completed_at     TEXT,
  executed_by      TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at       TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at       TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_data_erasure_user_id  ON data_erasure_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_data_erasure_status   ON data_erasure_requests(status);
CREATE INDEX IF NOT EXISTS idx_data_erasure_cooling  ON data_erasure_requests(cooling_off_ends)
  WHERE status = 'cooling_off';

-- ─── PAYOUT PERIODS (monthly payout tracking) ────────────────────────────────
CREATE TABLE IF NOT EXISTS payout_periods (
  id                   TEXT PRIMARY KEY,
  period               TEXT NOT NULL UNIQUE,
  status               TEXT NOT NULL DEFAULT 'pending'
                       CHECK(status IN ('pending','calculating','calculated','paying','paid','failed')),
  total_pool_cents     INTEGER NOT NULL DEFAULT 0,
  platform_share_cents INTEGER NOT NULL DEFAULT 0,
  author_share_cents   INTEGER NOT NULL DEFAULT 0,
  total_subscribers    INTEGER NOT NULL DEFAULT 0,
  total_authors        INTEGER NOT NULL DEFAULT 0,
  total_read_time_sec  INTEGER NOT NULL DEFAULT 0,
  payout_ratio         REAL NOT NULL DEFAULT 0.70,
  calculation_job_id   TEXT REFERENCES job_queue(id) ON DELETE SET NULL,
  calculated_at        TEXT,
  paid_at              TEXT,
  error_message        TEXT,
  created_at           TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at           TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_payout_periods_status ON payout_periods(status);

INSERT INTO _migrations (filename) VALUES ('0040_billing_compliance.sql');
