-- 0046_p4_feature_flags_superadmin.sql
-- Seed/normalize Phase P4 feature flags with SUPERADMIN-scoped admin controls.

INSERT OR IGNORE INTO feature_flags (
  id,
  flag_key,
  name,
  description,
  category,
  is_active,
  target_type,
  targets,
  rollout_pct,
  metadata,
  created_by
) VALUES
  (
    'ff_p4_podcasts',
    'podcasts',
    'Podcasts',
    'Podcast shows and episode management.',
    'community',
    0,
    'global',
    '[]',
    0,
    '{"channels":["in_app"]}',
    'system'
  ),
  (
    'ff_p4_publications',
    'publications',
    'Publications',
    'Curated publication subscriptions and issues.',
    'newsletter',
    0,
    'global',
    '[]',
    0,
    '{"channels":["in_app"]}',
    'system'
  ),
  (
    'ff_p4_marketing_tools',
    'marketing_tools',
    'Marketing Tools',
    'Marketing channels, scheduling, and A/B testing.',
    'enterprise',
    0,
    'global',
    '[]',
    0,
    '{"channels":["in_app"]}',
    'system'
  ),
  (
    'ff_p4_leads',
    'leads',
    'Leads and CRM',
    'Lead capture forms, scoring rules, and CRM workflows.',
    'enterprise',
    0,
    'global',
    '[]',
    0,
    '{"channels":["in_app"]}',
    'system'
  ),
  (
    'ff_p4_referrals',
    'referrals',
    'Referrals',
    'Referral code generation, tracking, and stats.',
    'marketplace',
    0,
    'global',
    '[]',
    0,
    '{"channels":["in_app"]}',
    'system'
  ),
  (
    'ff_p4_usage_alerts',
    'usage_alerts',
    'Usage Alerts and Quota',
    'Usage quota views, export, and alert-rule management.',
    'analytics',
    0,
    'global',
    '[]',
    0,
    '{"channels":["in_app"]}',
    'system'
  ),
  (
    'ff_p4_workflow_costs',
    'workflow_costs',
    'Workflow Costs',
    'Workflow run cost tracking, rollups, and budget controls.',
    'workflow',
    0,
    'global',
    '[]',
    0,
    '{"channels":["in_app"]}',
    'system'
  ),
  (
    'ff_p4_admin_earnings',
    'admin_earnings',
    'Admin Earnings',
    'SUPERADMIN earnings calculation and period report controls.',
    'billing',
    0,
    'user_roles',
    '["SUPERADMIN"]',
    0,
    '{"channels":["in_app"]}',
    'system'
  ),
  (
    'ff_p4_admin_billing',
    'admin_billing',
    'Admin Billing Reconciliation',
    'SUPERADMIN billing reconciliation controls.',
    'billing',
    0,
    'user_roles',
    '["SUPERADMIN"]',
    0,
    '{"channels":["in_app"]}',
    'system'
  ),
  (
    'ff_p4_admin_compliance',
    'admin_compliance',
    'Admin Compliance',
    'SUPERADMIN erasure queue review and execution controls.',
    'enterprise',
    0,
    'user_roles',
    '["SUPERADMIN"]',
    0,
    '{"channels":["in_app"]}',
    'system'
  );

INSERT OR IGNORE INTO _migrations (filename) VALUES ('0046_p4_feature_flags_superadmin.sql');
