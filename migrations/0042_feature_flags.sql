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
  ('ff_pdf_export',           'pdf_export',              'PDF Export',                  'Article PDF/Word/Markdown export',                     'export',      1, 'global',            '[]',                        'system'),
  ('ff_data_export',          'data_export',             'User Data Export',            'GDPR data export and account export package',          'export',      0, 'global',            '[]',                        'system'),
  ('ff_workflow_builder',     'workflow_builder',        'Workflow Builder',            'Visual workflow orchestrator',                         'workflow',    0, 'org_tiers',         '["enterprise"]',            'system'),
  ('ff_workflow_costs',       'workflow_cost_controls',  'Workflow Cost Controls',      'Workflow rates, budgets, and run-cost tracking',       'workflow',    0, 'org_tiers',         '["enterprise"]',            'system'),
  ('ff_connector_suite',      'connector_suite',         'Connector Suite',             '3rd-party integrations and connector marketplace',     'enterprise',  0, 'org_tiers',         '["enterprise"]',            'system'),
  ('ff_digital_marketing',    'digital_marketing',       'Digital Marketing',           'Campaign scheduling and content distribution',         'enterprise',  0, 'org_tiers',         '["enterprise"]',            'system'),
  ('ff_advanced_analytics',   'advanced_analytics',      'Advanced Analytics',          'Funnels, A/B tests, attribution, and metering',       'analytics',   0, 'org_tiers',         '["enterprise"]',            'system'),
  ('ff_lead_generation',      'lead_generation',         'Lead Generation',             'CRM-lite, forms, and lead pipelines',                  'enterprise',  0, 'org_tiers',         '["enterprise"]',            'system'),
  ('ff_custom_domains',       'custom_domains',          'Custom Domains',              'Vanity domain mapping and verification',               'enterprise',  0, 'membership_tiers',  '["creator_pro","team_suite"]', 'system'),
  ('ff_org_management',       'organization_management', 'Organization Management',     'Organizations, teams, invitations, and memberships',   'enterprise',  1, 'global',            '[]',                        'system'),
  ('ff_org_api_keys',         'org_infra_api_keys',      'Org API Keys',                'Organization API key and audit-log management',        'enterprise',  0, 'org_tiers',         '["enterprise"]',            'system'),
  ('ff_subdomain',            'subdomain_provisioning',  'Subdomain Provisioning',      'Provision and resolve tenant subdomains',              'enterprise',  0, 'org_tiers',         '["enterprise"]',            'system'),
  ('ff_sso',                  'sso_authentication',      'SSO Authentication',          'SAML/OIDC SSO configuration and login',                'enterprise',  0, 'org_tiers',         '["enterprise"]',            'system'),
  ('ff_vault',                'secret_vault',            'Secret Vault',                'Tenant-scoped secret storage and rotation',            'enterprise',  0, 'org_tiers',         '["enterprise"]',            'system'),
  ('ff_newsletter',           'newsletter_mgmt',         'Newsletter Management',       'Newsletter creation, segmentation, and sends',         'newsletter',  0, 'global',            '[]',                        'system'),
  ('ff_publications',         'publications',            'Publications',                'Issue generation, approvals, and publication delivery', 'newsletter',  0, 'org_tiers',         '["enterprise"]',            'system'),
  ('ff_course_builder',       'course_builder',          'Course Builder',              'Legacy course builder rollout key',                    'course',      0, 'global',            '[]',                        'system'),
  ('ff_courses',              'courses',                 'Courses',                     'Courses, lessons, quizzes, and certificates',          'course',      0, 'global',            '[]',                        'system'),
  ('ff_community_spaces',     'community_spaces',        'Community Spaces',            'Discussion spaces and member conversations',           'community',   0, 'global',            '[]',                        'system'),
  ('ff_community_marketplace','community_marketplace',   'Community Marketplace',       'Community monetization and marketplace enablement',    'marketplace', 0, 'org_tiers',         '["enterprise"]',            'system'),
  ('ff_marketplace',          'marketplace',             'Marketplace',                 'Template and plugin marketplace',                      'marketplace', 0, 'global',            '[]',                        'system'),
  ('ff_referrals',            'referral_program',        'Referral Program',            'Referral links, tracking, and growth rewards',         'marketplace', 0, 'global',            '[]',                        'system'),
  ('ff_podcasts',             'podcasts',                'Podcasts',                    'Podcast shows and episode publishing',                 'community',   0, 'global',            '[]',                        'system'),
  ('ff_reports',              'content_reports',         'Content Reports',             'Moderation reports and superadmin review workflows',   'enterprise',  0, 'global',            '[]',                        'system'),
  ('ff_earnings',             'author_earnings',         'Author Earnings',             'Revenue share, payout, and earnings reports',          'billing',     0, 'global',            '[]',                        'system'),
  ('ff_billing',              'billing_engine',          'Billing Engine',              'Billing, reconciliation, and invoicing controls',      'billing',     0, 'org_tiers',         '["enterprise"]',            'system'),
  ('ff_compliance',           'compliance_center',       'Compliance Center',           'GDPR export/erase workflows and compliance controls',  'enterprise',  0, 'global',            '[]',                        'system'),
  ('ff_usage_alerts',         'usage_alerts',            'Usage Alerts',                'Quota enforcement and usage threshold alerting',       'analytics',   0, 'org_tiers',         '["enterprise"]',            'system'),
  ('ff_notifications',        'notification_channels',   'Notification Channels',       'Expanded notification preferences and channel control', 'general',     1, 'global',            '[]',                        'system'),
  ('ff_reading_lists',        'reading_lists',           'Reading Lists',               'Saved collections and curation lists',                 'community',   1, 'global',            '[]',                        'system'),
  ('ff_reading_history',      'reading_history',         'Reading History',             'Per-user reading history and progress tracking',       'community',   1, 'global',            '[]',                        'system'),
  ('ff_article_revisions',    'article_revisions',       'Article Revisions',           'Editorial revisions and version timeline',             'workflow',    1, 'global',            '[]',                        'system'),
  ('ff_collaboration',        'collaboration_coauthor',  'Collaboration Coauthor',      'Controlled SUPERADMIN collaboration override for article ownership workflows', 'workflow',    0, 'global',            '[]',                        'system'),
  ('ff_series',               'series_publishing',       'Series Publishing',           'Series management and serialized publishing',          'general',     1, 'global',            '[]',                        'system'),
  ('ff_search_advanced',      'advanced_search',         'Advanced Search',             'Search facets, ranking controls, and discovery tuning', 'general',     1, 'global',            '[]',                        'system'),
  ('ff_social_graph',         'social_graph',            'Social Graph',                'Follows, bookmarks, likes, and social feed graph',     'community',   1, 'global',            '[]',                        'system');

INSERT OR IGNORE INTO _migrations (filename) VALUES ('0042_feature_flags.sql');
