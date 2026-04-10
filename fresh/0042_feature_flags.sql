-- 0042_feature_flags.sql — Platform-wide feature gating
-- Phase 3.5: SUPERADMIN can enable/disable features globally,
-- per user, per role, per org, per tier, or via percentage rollout.

CREATE TABLE IF NOT EXISTS feature_flags (
  id              TEXT PRIMARY KEY,
  flag_key        TEXT NOT NULL UNIQUE,
  name            TEXT NOT NULL,
  description     TEXT,
  category        TEXT NOT NULL DEFAULT 'general'
                  CHECK(category IN (
                    'general','export','workflow','community','marketplace',
                    'analytics','newsletter','course','billing','enterprise'
                  )),
  is_active       INTEGER NOT NULL DEFAULT 0,
  target_type     TEXT NOT NULL DEFAULT 'global'
                  CHECK(target_type IN (
                    'global','user_ids','user_roles','org_ids',
                    'org_tiers','membership_tiers','percentage'
                  )),
  targets         TEXT NOT NULL DEFAULT '[]',
  rollout_pct     INTEGER NOT NULL DEFAULT 0
                  CHECK(rollout_pct BETWEEN 0 AND 100),
  metadata        TEXT NOT NULL DEFAULT '{}',
  created_by      TEXT NOT NULL,
  updated_by      TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_feature_flags_key      ON feature_flags(flag_key);
CREATE INDEX IF NOT EXISTS idx_feature_flags_category ON feature_flags(category);
CREATE INDEX IF NOT EXISTS idx_feature_flags_active   ON feature_flags(is_active);

-- ─── SEED: Initial feature flags ────────────────────────────────────────────
INSERT OR IGNORE INTO feature_flags
  (id, flag_key, name, description, category, is_active, target_type, targets, created_by)
VALUES
  ('ff_pdf_export',    'pdf_export',         'PDF Export',            'Article PDF/Word/Markdown export',      'export',      1, 'global',           '[]',            'system'),
  ('ff_workflow',      'workflow_builder',    'Workflow Builder',      'Visual workflow orchestrator',           'workflow',    0, 'org_tiers',        '["enterprise"]','system'),
  ('ff_community',     'community_spaces',   'Community Spaces',      'Discussion spaces and forums',          'community',   0, 'global',           '[]',            'system'),
  ('ff_marketplace',   'marketplace',        'Marketplace',           'Template and plugin marketplace',       'marketplace', 0, 'global',           '[]',            'system'),
  ('ff_newsletter',    'newsletter_mgmt',    'Newsletter Management', 'Newsletter creation and sending',       'newsletter',  0, 'global',           '[]',            'system'),
  ('ff_courses',       'course_builder',     'Course Builder',        'Online course creation platform',       'course',      0, 'global',           '[]',            'system'),
  ('ff_analytics',     'advanced_analytics', 'Advanced Analytics',    'Funnels, A/B tests, attribution',       'analytics',   0, 'org_tiers',        '["enterprise"]','system'),
  ('ff_lead_gen',      'lead_generation',    'Lead Generation',       'CRM-lite, forms, pipelines',            'enterprise',  0, 'org_tiers',        '["enterprise"]','system'),
  ('ff_connectors',    'connector_suite',    'Connector Suite',       '3rd-party integrations',                'enterprise',  0, 'org_tiers',        '["enterprise"]','system'),
  ('ff_custom_domain', 'custom_domains',     'Custom Domains',        'Vanity domain mapping',                 'enterprise',  0, 'membership_tiers', '["creator_pro","team_suite"]', 'system');

INSERT OR IGNORE INTO _migrations (filename) VALUES ('0042_feature_flags.sql');
