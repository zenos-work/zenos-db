-- 0021_organizations.sql — Enterprise multi-tenancy (8 tables)
-- (merged: 0028)

-- ─── ORGANIZATIONS ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS organizations (
  id                      TEXT PRIMARY KEY,
  name                    TEXT NOT NULL,
  slug                    TEXT NOT NULL UNIQUE,
  logo_url                TEXT,
  website                 TEXT,
  description             TEXT,
  plan_tier               TEXT NOT NULL DEFAULT 'free'
                          CHECK(plan_tier IN ('free','starter','business','enterprise')),
  plan_status             TEXT NOT NULL DEFAULT 'active'
                          CHECK(plan_status IN ('active','past_due','cancelled','trialing')),
  trial_ends_at           TEXT,
  plan_started_at         TEXT,
  stripe_customer_id      TEXT,
  stripe_subscription_id  TEXT,
  max_members             INTEGER NOT NULL DEFAULT 5,
  max_workflows           INTEGER NOT NULL DEFAULT 3,
  max_leads               INTEGER NOT NULL DEFAULT 1000,
  settings                TEXT NOT NULL DEFAULT '{}',
  created_by              TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at              TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at              TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_orgs_slug       ON organizations(slug);
CREATE INDEX IF NOT EXISTS idx_orgs_plan_tier  ON organizations(plan_tier);
CREATE INDEX IF NOT EXISTS idx_orgs_created_by ON organizations(created_by);

-- ─── ORG MEMBERS ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS org_members (
  id         TEXT PRIMARY KEY,
  org_id     TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  org_role   TEXT NOT NULL DEFAULT 'member'
             CHECK(org_role IN ('owner','admin','editor','member','viewer')),
  joined_at  TEXT NOT NULL DEFAULT (datetime('now')),
  invited_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE(org_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_org_members_org_id  ON org_members(org_id);
CREATE INDEX IF NOT EXISTS idx_org_members_user_id ON org_members(user_id);
CREATE INDEX IF NOT EXISTS idx_org_members_role    ON org_members(org_id, org_role);

-- ─── TEAMS ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS teams (
  id          TEXT PRIMARY KEY,
  org_id      TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  description TEXT,
  created_by  TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at  TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(org_id, name)
);

CREATE INDEX IF NOT EXISTS idx_teams_org_id ON teams(org_id);

CREATE TABLE IF NOT EXISTS team_members (
  team_id  TEXT NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  user_id  TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  added_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (team_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_team_members_user_id ON team_members(user_id);

-- ─── INVITATIONS ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS org_invitations (
  id          TEXT PRIMARY KEY,
  org_id      TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  team_id     TEXT REFERENCES teams(id) ON DELETE SET NULL,
  email       TEXT NOT NULL,
  org_role    TEXT NOT NULL DEFAULT 'member',
  token       TEXT NOT NULL UNIQUE,
  status      TEXT NOT NULL DEFAULT 'pending'
              CHECK(status IN ('pending','accepted','expired','revoked')),
  invited_by  TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at  TEXT NOT NULL,
  accepted_at TEXT,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_invitations_org_id ON org_invitations(org_id);
CREATE INDEX IF NOT EXISTS idx_invitations_email  ON org_invitations(email);
CREATE INDEX IF NOT EXISTS idx_invitations_token  ON org_invitations(token);

-- ─── API KEYS ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS api_keys (
  id          TEXT PRIMARY KEY,
  org_id      TEXT REFERENCES organizations(id) ON DELETE CASCADE,
  user_id     TEXT REFERENCES users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  key_hash    TEXT NOT NULL UNIQUE,
  key_prefix  TEXT NOT NULL,
  scopes      TEXT NOT NULL DEFAULT '["read"]',
  last_used_at TEXT,
  expires_at  TEXT,
  revoked_at  TEXT,
  created_by  TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_api_keys_org_id   ON api_keys(org_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_user_id  ON api_keys(user_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_key_hash ON api_keys(key_hash);

-- ─── SSO CONFIGS ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sso_configs (
  id         TEXT PRIMARY KEY,
  org_id     TEXT NOT NULL UNIQUE REFERENCES organizations(id) ON DELETE CASCADE,
  provider   TEXT NOT NULL CHECK(provider IN ('saml','oidc','google_workspace','microsoft_entra')),
  metadata   TEXT NOT NULL DEFAULT '{}',
  is_enabled INTEGER NOT NULL DEFAULT 0,
  created_by TEXT NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ─── AUDIT LOG ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_log (
  id          TEXT PRIMARY KEY,
  org_id      TEXT REFERENCES organizations(id) ON DELETE SET NULL,
  actor_id    TEXT REFERENCES users(id) ON DELETE SET NULL,
  actor_ip    TEXT,
  action      TEXT NOT NULL,
  resource    TEXT,
  resource_id TEXT,
  payload     TEXT NOT NULL DEFAULT '{}',
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_audit_log_org_id   ON audit_log(org_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_actor_id ON audit_log(actor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_action   ON audit_log(action);
CREATE INDEX IF NOT EXISTS idx_audit_log_resource ON audit_log(resource, resource_id);

INSERT INTO _migrations (filename) VALUES ('0021_organizations.sql');
