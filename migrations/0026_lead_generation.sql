-- 0026_lead_generation.sql — Full CRM-lite: forms, leads, tags, events, scoring, pipelines, sequences
-- (merged: 0030)

-- ─── LEAD CAPTURE FORMS ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS lead_capture_forms (
  id               TEXT PRIMARY KEY,
  org_id           TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  owner_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name             TEXT NOT NULL,
  title            TEXT,
  description      TEXT,
  cta_text         TEXT NOT NULL DEFAULT 'Subscribe',
  success_message  TEXT NOT NULL DEFAULT 'Thank you! We''ll be in touch.',
  article_id       TEXT REFERENCES articles(id) ON DELETE SET NULL,
  placement        TEXT NOT NULL DEFAULT 'inline'
                   CHECK(placement IN ('inline','popup','slide_in','sticky_bar','exit_intent')),
  show_after_words INTEGER,
  workflow_id      TEXT REFERENCES workflows(id) ON DELETE SET NULL,
  fields_schema    TEXT NOT NULL DEFAULT '[]',
  is_active        INTEGER NOT NULL DEFAULT 1,
  submission_count INTEGER NOT NULL DEFAULT 0,
  created_at       TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at       TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_lead_forms_org_id      ON lead_capture_forms(org_id);
CREATE INDEX IF NOT EXISTS idx_lead_forms_owner_id    ON lead_capture_forms(owner_id);
CREATE INDEX IF NOT EXISTS idx_lead_forms_article_id  ON lead_capture_forms(article_id);
CREATE INDEX IF NOT EXISTS idx_lead_forms_workflow_id  ON lead_capture_forms(workflow_id);

-- ─── LEADS ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS leads (
  id                TEXT PRIMARY KEY,
  org_id            TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  email             TEXT NOT NULL,
  first_name        TEXT,
  last_name         TEXT,
  phone             TEXT,
  company           TEXT,
  job_title         TEXT,
  custom_fields     TEXT NOT NULL DEFAULT '{}',
  source_type       TEXT NOT NULL DEFAULT 'form'
                    CHECK(source_type IN ('form','import','api','workflow','manual','oauth')),
  source_form_id    TEXT REFERENCES lead_capture_forms(id) ON DELETE SET NULL,
  source_article_id TEXT REFERENCES articles(id) ON DELETE SET NULL,
  utm_source        TEXT,
  utm_medium        TEXT,
  utm_campaign      TEXT,
  utm_content       TEXT,
  utm_term          TEXT,
  referrer_url      TEXT,
  user_id           TEXT REFERENCES users(id) ON DELETE SET NULL,
  score             INTEGER NOT NULL DEFAULT 0,
  status            TEXT NOT NULL DEFAULT 'new'
                    CHECK(status IN ('new','contacted','qualified','unqualified','converted','unsubscribed','bounced')),
  crm_id            TEXT,
  crm_synced_at     TEXT,
  consent_given     INTEGER NOT NULL DEFAULT 0,
  consent_text      TEXT,
  consent_at        TEXT,
  is_unsubscribed   INTEGER NOT NULL DEFAULT 0,
  unsubscribed_at   TEXT,
  first_seen_at     TEXT NOT NULL DEFAULT (datetime('now')),
  last_activity_at  TEXT NOT NULL DEFAULT (datetime('now')),
  created_at        TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at        TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(org_id, email)
);

CREATE INDEX IF NOT EXISTS idx_leads_org_id         ON leads(org_id);
CREATE INDEX IF NOT EXISTS idx_leads_email          ON leads(email);
CREATE INDEX IF NOT EXISTS idx_leads_status         ON leads(org_id, status);
CREATE INDEX IF NOT EXISTS idx_leads_score          ON leads(org_id, score DESC);
CREATE INDEX IF NOT EXISTS idx_leads_source_form    ON leads(source_form_id);
CREATE INDEX IF NOT EXISTS idx_leads_source_article ON leads(source_article_id);
CREATE INDEX IF NOT EXISTS idx_leads_user_id        ON leads(user_id);
CREATE INDEX IF NOT EXISTS idx_leads_created_at     ON leads(org_id, created_at DESC);

-- ─── LEAD TAGS ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS lead_tags (
  org_id   TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  lead_id  TEXT NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
  tag      TEXT NOT NULL,
  added_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  added_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (org_id, lead_id, tag)
);

CREATE INDEX IF NOT EXISTS idx_lead_tags_org_tag ON lead_tags(org_id, tag);

-- ─── LEAD EVENTS ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS lead_events (
  id         TEXT PRIMARY KEY,
  lead_id    TEXT NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
  org_id     TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  metadata   TEXT NOT NULL DEFAULT '{}',
  actor_id   TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_lead_events_lead_id    ON lead_events(lead_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_lead_events_org_id     ON lead_events(org_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_lead_events_event_type ON lead_events(event_type);

-- ─── LEAD SCORE RULES ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS lead_score_rules (
  id            TEXT PRIMARY KEY,
  org_id        TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  trigger_event TEXT NOT NULL,
  condition     TEXT NOT NULL DEFAULT '{}',
  score_delta   INTEGER NOT NULL,
  is_active     INTEGER NOT NULL DEFAULT 1,
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_score_rules_org_id ON lead_score_rules(org_id);

-- ─── LEAD PIPELINES ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS lead_pipelines (
  id          TEXT PRIMARY KEY,
  org_id      TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  description TEXT,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_pipelines_org_id ON lead_pipelines(org_id);

CREATE TABLE IF NOT EXISTS pipeline_stages (
  id          TEXT PRIMARY KEY,
  pipeline_id TEXT NOT NULL REFERENCES lead_pipelines(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  stage_type  TEXT NOT NULL DEFAULT 'open'
              CHECK(stage_type IN ('open','won','lost')),
  color       TEXT
);

CREATE INDEX IF NOT EXISTS idx_stages_pipeline_id ON pipeline_stages(pipeline_id);

CREATE TABLE IF NOT EXISTS lead_pipeline_entries (
  id          TEXT PRIMARY KEY,
  lead_id     TEXT NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
  pipeline_id TEXT NOT NULL REFERENCES lead_pipelines(id) ON DELETE CASCADE,
  stage_id    TEXT NOT NULL REFERENCES pipeline_stages(id) ON DELETE CASCADE,
  assigned_to TEXT REFERENCES users(id) ON DELETE SET NULL,
  deal_value  INTEGER,
  notes       TEXT,
  entered_at  TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at  TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(lead_id, pipeline_id)
);

CREATE INDEX IF NOT EXISTS idx_pipeline_entries_lead_id     ON lead_pipeline_entries(lead_id);
CREATE INDEX IF NOT EXISTS idx_pipeline_entries_pipeline_id ON lead_pipeline_entries(pipeline_id);
CREATE INDEX IF NOT EXISTS idx_pipeline_entries_stage_id    ON lead_pipeline_entries(stage_id);
CREATE INDEX IF NOT EXISTS idx_pipeline_entries_assigned_to ON lead_pipeline_entries(assigned_to);

-- ─── EMAIL SEQUENCES ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS email_sequences (
  id           TEXT PRIMARY KEY,
  org_id       TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name         TEXT NOT NULL,
  description  TEXT,
  trigger_type TEXT NOT NULL DEFAULT 'manual',
  status       TEXT NOT NULL DEFAULT 'draft'
               CHECK(status IN ('draft','active','paused','archived')),
  created_by   TEXT NOT NULL REFERENCES users(id),
  created_at   TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_sequences_org_id ON email_sequences(org_id);

CREATE TABLE IF NOT EXISTS email_sequence_steps (
  id          TEXT PRIMARY KEY,
  sequence_id TEXT NOT NULL REFERENCES email_sequences(id) ON DELETE CASCADE,
  step_number INTEGER NOT NULL,
  delay_days  INTEGER NOT NULL DEFAULT 0,
  subject     TEXT NOT NULL,
  body_html   TEXT NOT NULL,
  body_text   TEXT,
  from_name   TEXT,
  from_email  TEXT,
  UNIQUE(sequence_id, step_number)
);

CREATE INDEX IF NOT EXISTS idx_seq_steps_sequence_id ON email_sequence_steps(sequence_id);

CREATE TABLE IF NOT EXISTS lead_sequence_enrollments (
  id           TEXT PRIMARY KEY,
  lead_id      TEXT NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
  sequence_id  TEXT NOT NULL REFERENCES email_sequences(id) ON DELETE CASCADE,
  current_step INTEGER NOT NULL DEFAULT 0,
  status       TEXT NOT NULL DEFAULT 'active'
               CHECK(status IN ('active','completed','unenrolled','bounced')),
  enrolled_at  TEXT NOT NULL DEFAULT (datetime('now')),
  completed_at TEXT,
  UNIQUE(lead_id, sequence_id)
);

CREATE INDEX IF NOT EXISTS idx_enrollments_lead_id     ON lead_sequence_enrollments(lead_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_sequence_id ON lead_sequence_enrollments(sequence_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_status      ON lead_sequence_enrollments(status);

INSERT INTO _migrations (filename) VALUES ('0026_lead_generation.sql');
