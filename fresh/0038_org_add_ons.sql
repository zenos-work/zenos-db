-- 0038_org_add_ons.sql — Organization add-on packages
-- SUPERADMIN enables add-ons per org; each add-on unlocks a feature domain.

-- ─── ORG ADD-ONS ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS org_add_ons (
  id                     TEXT PRIMARY KEY,
  org_id                 TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  add_on_type            TEXT NOT NULL
                         CHECK(add_on_type IN (
                           'workflow_builder',
                           'connector_suite',
                           'digital_marketing',
                           'advanced_analytics',
                           'lead_generation',
                           'custom_domains',
                           'courses',
                           'community_marketplace'
                         )),
  tier                   TEXT NOT NULL DEFAULT 'standard'
                         CHECK(tier IN ('standard','premium','unlimited')),
  is_active              INTEGER NOT NULL DEFAULT 1,
  enabled_by             TEXT NOT NULL REFERENCES users(id),
  limits                 TEXT NOT NULL DEFAULT '{}',
  stripe_subscription_id TEXT,
  trial_ends_at          TEXT,
  started_at             TEXT NOT NULL DEFAULT (datetime('now')),
  expires_at             TEXT,
  created_at             TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at             TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(org_id, add_on_type)
);

CREATE INDEX IF NOT EXISTS idx_org_add_ons_org_id      ON org_add_ons(org_id, is_active);
CREATE INDEX IF NOT EXISTS idx_org_add_ons_type        ON org_add_ons(add_on_type);
CREATE INDEX IF NOT EXISTS idx_org_add_ons_enabled_by  ON org_add_ons(enabled_by);
CREATE INDEX IF NOT EXISTS idx_org_add_ons_expires     ON org_add_ons(expires_at);

-- ─── ADD-ON TIER LIMITS (reference defaults per add-on × tier) ────────────────
-- Stored in 'limits' JSON column per org_add_on. These are the default templates.
CREATE TABLE IF NOT EXISTS add_on_tier_defaults (
  id             TEXT PRIMARY KEY,
  add_on_type    TEXT NOT NULL,
  tier           TEXT NOT NULL,
  default_limits TEXT NOT NULL DEFAULT '{}',
  description    TEXT,
  price_cents    INTEGER NOT NULL DEFAULT 0,
  created_at     TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(add_on_type, tier)
);

-- ─── SEED: Default tier limits ────────────────────────────────────────────────
INSERT OR IGNORE INTO add_on_tier_defaults (id, add_on_type, tier, default_limits, description, price_cents) VALUES
  -- Workflow Builder
  ('addon_wf_standard',    'workflow_builder',       'standard',  '{"max_active_workflows":3,"max_runs_per_month":100,"max_nodes_per_workflow":15,"enterprise_nodes":false,"hitl":false,"cost_ledger":false,"max_connectors":2}', 'Basic workflow automation', 4900),
  ('addon_wf_premium',     'workflow_builder',       'premium',   '{"max_active_workflows":25,"max_runs_per_month":5000,"max_nodes_per_workflow":50,"enterprise_nodes":true,"hitl":true,"cost_ledger":true,"max_connectors":20}', 'Advanced workflow with HITL & cost tracking', 14900),
  ('addon_wf_unlimited',   'workflow_builder',       'unlimited', '{"max_active_workflows":-1,"max_runs_per_month":-1,"max_nodes_per_workflow":-1,"enterprise_nodes":true,"hitl":true,"cost_ledger":true,"max_connectors":-1}', 'Unlimited workflow automation', 49900),
  -- Connector Suite
  ('addon_conn_standard',  'connector_suite',        'standard',  '{"max_connectors":5,"builtin_only":true,"mcp_servers":0,"custom_agents":0}', 'Built-in connectors only', 2900),
  ('addon_conn_premium',   'connector_suite',        'premium',   '{"max_connectors":50,"builtin_only":false,"mcp_servers":10,"custom_agents":5}', 'Custom connectors, MCP, AI agents', 9900),
  -- Digital Marketing
  ('addon_mkt_standard',   'digital_marketing',      'standard',  '{"distribution_channels":3,"scheduled_publications":10,"repurposing_jobs_per_month":20,"campaigns":0,"ad_integrations":false}', 'Content distribution & scheduling', 3900),
  ('addon_mkt_premium',    'digital_marketing',      'premium',   '{"distribution_channels":-1,"scheduled_publications":-1,"repurposing_jobs_per_month":-1,"campaigns":-1,"ad_integrations":true}', 'Full marketing suite with campaigns & ads', 12900),
  -- Advanced Analytics
  ('addon_ana_standard',   'advanced_analytics',     'standard',  '{"dashboards":true,"funnels":0,"ab_experiments":0,"attribution":false}', 'Basic analytics dashboards', 1900),
  ('addon_ana_premium',    'advanced_analytics',     'premium',   '{"dashboards":true,"funnels":-1,"ab_experiments":-1,"attribution":true}', 'Funnels, A/B testing, attribution', 7900),
  -- Lead Generation
  ('addon_lead_standard',  'lead_generation',        'standard',  '{"max_forms":1,"max_leads":100,"pipelines":1,"email_sequences":0}', 'Single form, basic lead capture', 2900),
  ('addon_lead_premium',   'lead_generation',        'premium',   '{"max_forms":-1,"max_leads":-1,"pipelines":-1,"email_sequences":-1}', 'Unlimited forms, pipelines, email drips', 9900),
  -- Custom Domains
  ('addon_dom_standard',   'custom_domains',         'standard',  '{"max_domains":1}', 'Single custom domain', 900),
  ('addon_dom_premium',    'custom_domains',         'premium',   '{"max_domains":-1}', 'Unlimited custom domains', 2900),
  -- Courses
  ('addon_course_standard','courses',                'standard',  '{"max_courses":3,"max_enrollments_per_course":100,"certificates":false}', 'Basic course creation', 3900),
  ('addon_course_premium', 'courses',                'premium',   '{"max_courses":-1,"max_enrollments_per_course":-1,"certificates":true}', 'Unlimited courses with certificates', 9900),
  -- Community & Marketplace
  ('addon_comm_standard',  'community_marketplace',  'standard',  '{"max_spaces":1,"marketplace_selling":false,"referrals":false}', 'Single community space', 1900),
  ('addon_comm_premium',   'community_marketplace',  'premium',   '{"max_spaces":-1,"marketplace_selling":true,"referrals":true}', 'Unlimited spaces, marketplace, referrals', 7900);

INSERT INTO _migrations (filename) VALUES ('0038_org_add_ons.sql');
