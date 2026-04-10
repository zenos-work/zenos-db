-- 0039_job_queue.sql — D1-backed durable execution queue
-- Replaces need for Cloudflare Queues / Durable Objects (not available on free tier).
-- Polled by a cron-triggered Worker every 1 minute.

-- ─── JOB QUEUE ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS job_queue (
  id              TEXT PRIMARY KEY,
  job_type        TEXT NOT NULL
                  CHECK(job_type IN (
                    'workflow_run',
                    'content_distribute',
                    'newsletter_send',
                    'data_export',
                    'data_erasure',
                    'billing_reconcile',
                    'payout_calculate',
                    'metric_rollup',
                    'ai_content_scan',
                    'publication_generate',
                    'connector_sync',
                    'cache_purge'
                  )),
  payload         TEXT NOT NULL DEFAULT '{}',
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK(status IN ('pending','processing','completed','failed','dead')),
  org_id          TEXT REFERENCES organizations(id) ON DELETE SET NULL,
  user_id         TEXT REFERENCES users(id) ON DELETE SET NULL,
  priority        INTEGER NOT NULL DEFAULT 0,
  idempotency_key TEXT UNIQUE,
  attempt_count   INTEGER NOT NULL DEFAULT 0,
  max_attempts    INTEGER NOT NULL DEFAULT 3,
  next_retry_at   TEXT,
  locked_by       TEXT,
  locked_at       TEXT,
  completed_at    TEXT,
  error_message   TEXT,
  result          TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Primary polling index: grab next pending job efficiently
CREATE INDEX IF NOT EXISTS idx_job_queue_poll
  ON job_queue(status, priority DESC, next_retry_at, created_at ASC);

-- Status monitoring
CREATE INDEX IF NOT EXISTS idx_job_queue_status
  ON job_queue(status, created_at DESC);

-- Per-org job listing
CREATE INDEX IF NOT EXISTS idx_job_queue_org_id
  ON job_queue(org_id, status);

-- Job type filtering
CREATE INDEX IF NOT EXISTS idx_job_queue_type
  ON job_queue(job_type, status);

-- Idempotency lookups
CREATE INDEX IF NOT EXISTS idx_job_queue_idempotency
  ON job_queue(idempotency_key);

-- Stale lock detection (jobs stuck in 'processing' too long)
CREATE INDEX IF NOT EXISTS idx_job_queue_locked
  ON job_queue(status, locked_at)
  WHERE status = 'processing';

-- Dead letter queue monitoring
CREATE INDEX IF NOT EXISTS idx_job_queue_dead
  ON job_queue(status, job_type)
  WHERE status = 'dead';

-- ─── JOB EXECUTION LOG ───────────────────────────────────────────────────────
-- Tracks each attempt for debugging and audit
CREATE TABLE IF NOT EXISTS job_execution_log (
  id             TEXT PRIMARY KEY,
  job_id         TEXT NOT NULL REFERENCES job_queue(id) ON DELETE CASCADE,
  attempt_number INTEGER NOT NULL,
  status         TEXT NOT NULL CHECK(status IN ('started','completed','failed')),
  worker_id      TEXT,
  started_at     TEXT NOT NULL DEFAULT (datetime('now')),
  finished_at    TEXT,
  duration_ms    INTEGER,
  error_message  TEXT,
  error_stack    TEXT,
  output_summary TEXT
);

CREATE INDEX IF NOT EXISTS idx_job_exec_log_job_id
  ON job_execution_log(job_id, attempt_number DESC);

CREATE INDEX IF NOT EXISTS idx_job_exec_log_status
  ON job_execution_log(status, started_at DESC);

INSERT INTO _migrations (filename) VALUES ('0039_job_queue.sql');
