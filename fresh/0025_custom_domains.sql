-- 0025_custom_domains.sql — Custom domain mapping for publications/blogs
-- (merged: 0050)

CREATE TABLE IF NOT EXISTS custom_domains (
  id                    TEXT PRIMARY KEY,
  org_id                TEXT REFERENCES organizations(id) ON DELETE CASCADE,
  user_id               TEXT REFERENCES users(id) ON DELETE SET NULL,
  domain                TEXT NOT NULL UNIQUE,
  resource_type         TEXT NOT NULL
                        CHECK(resource_type IN ('newsletter','publication','blog','landing_page')),
  resource_id           TEXT,
  verification_status   TEXT NOT NULL DEFAULT 'pending'
                        CHECK(verification_status IN ('pending','verified','failed','expired')),
  verification_method   TEXT NOT NULL DEFAULT 'cname'
                        CHECK(verification_method IN ('cname','txt')),
  verification_token    TEXT NOT NULL,
  verified_at           TEXT,
  ssl_status            TEXT NOT NULL DEFAULT 'pending'
                        CHECK(ssl_status IN ('pending','active','failed','expired')),
  ssl_issued_at         TEXT,
  ssl_expires_at        TEXT,
  is_active             INTEGER NOT NULL DEFAULT 0,
  redirect_to           TEXT,
  created_at            TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at            TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_custom_domains_org_id   ON custom_domains(org_id);
CREATE INDEX IF NOT EXISTS idx_custom_domains_user_id  ON custom_domains(user_id);
CREATE INDEX IF NOT EXISTS idx_custom_domains_domain   ON custom_domains(domain);
CREATE INDEX IF NOT EXISTS idx_custom_domains_resource ON custom_domains(resource_type, resource_id);

INSERT INTO _migrations (filename) VALUES ('0025_custom_domains.sql');
