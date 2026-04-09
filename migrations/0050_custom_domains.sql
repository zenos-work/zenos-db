-- Migration: 0050_custom_domains
-- Custom domain mapping for publications, newsletters, and org blogs.
-- Enables vanity domains like blog.acme.com → org's content on Zenos.

CREATE TABLE IF NOT EXISTS custom_domains (
  id                    TEXT PRIMARY KEY,
  org_id                TEXT REFERENCES organizations(id) ON DELETE CASCADE,
  user_id               TEXT REFERENCES users(id) ON DELETE SET NULL,  -- for personal domains

  domain                TEXT NOT NULL UNIQUE,    -- e.g. "blog.acme.com"
  resource_type         TEXT NOT NULL
                        CHECK(resource_type IN ('newsletter','publication','blog','landing_page')),
  resource_id           TEXT,                    -- e.g. newsletter.id or null for org blog root

  -- DNS verification
  verification_status   TEXT NOT NULL DEFAULT 'pending'
                        CHECK(verification_status IN ('pending','verified','failed','expired')),
  verification_method   TEXT NOT NULL DEFAULT 'cname'
                        CHECK(verification_method IN ('cname','txt')),
  verification_token    TEXT NOT NULL,            -- TXT record value or CNAME target
  verified_at           TEXT,

  -- SSL / TLS
  ssl_status            TEXT NOT NULL DEFAULT 'pending'
                        CHECK(ssl_status IN ('pending','active','failed','expired')),
  ssl_issued_at         TEXT,
  ssl_expires_at        TEXT,

  -- Routing
  is_active             INTEGER NOT NULL DEFAULT 0,
  redirect_to           TEXT,                    -- fallback URL if domain is removed

  created_at            TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at            TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_custom_domains_org_id   ON custom_domains(org_id);
CREATE INDEX IF NOT EXISTS idx_custom_domains_user_id  ON custom_domains(user_id);
CREATE INDEX IF NOT EXISTS idx_custom_domains_domain   ON custom_domains(domain);
CREATE INDEX IF NOT EXISTS idx_custom_domains_resource ON custom_domains(resource_type, resource_id);
