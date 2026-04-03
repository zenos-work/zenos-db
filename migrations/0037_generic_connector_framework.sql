-- Migration: 0037_generic_connector_framework
--
-- PURPOSE
-- -------
-- Upgrades the workflow engine from a hard-coded integration list to a fully
-- generic, extensible connector framework.  ANY external system can be connected
-- without a code deploy:
--   • Built-in connectors  — seeded below (Instagram, X, LinkedIn, Google Maps, …)
--   • Community connectors — published by other Zenos orgs/users
--   • MCP servers          — Model Context Protocol servers (local or remote)
--   • Custom AI agents     — LLM chains, RAG agents, tool-use agents
--   • Custom HTTP / OpenAPI — bring-your-own REST API via OpenAPI spec URL
--   • Custom Webhooks       — inbound or outbound
--
-- KEY DESIGN DECISIONS
-- --------------------
-- 1. connector_definitions  = the "driver" / template (what the connector IS)
-- 2. connector_actions      = individual operations each connector exposes
-- 3. connector_instances    = per-org auth'd connection (credentials in KV)
-- 4. connector_oauth_providers = OAuth 2.0 endpoints per platform (shared)
-- 5. connector_oauth_tokens = per-instance OAuth token refs (in KV)
-- 6. mcp_server_registry    = MCP-specific registration detail
-- 7. custom_agents          = AI agent definitions that become workflow nodes
-- 8. workflow_node_connector_bindings = links a canvas node → instance + action
--
-- The old workflow_integrations table (0029) is preserved as-is for backwards
-- compat; new code should use connector_instances.  A migration column
-- `connector_instance_id` is back-linked for the transition period.

-- ═══════════════════════════════════════════════════════════════════════════════
-- PART 1 — CONNECTOR DEFINITIONS (the "driver" catalog)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS connector_definitions (
  id                TEXT PRIMARY KEY,
  -- e.g. 'instagram', 'x_twitter', 'linkedin', 'google_maps', 'custom_http', 'mcp'

  name              TEXT NOT NULL,
  slug              TEXT NOT NULL UNIQUE,    -- URL-safe, machine-readable
  description       TEXT,
  logo_url          TEXT,
  documentation_url TEXT,

  -- Who provided this connector?
  source_type       TEXT NOT NULL DEFAULT 'builtin'
                    CHECK(source_type IN (
                      'builtin',         -- shipped with Zenos
                      'community',       -- published by a Zenos user/org
                      'mcp_server',      -- Model Context Protocol server
                      'custom_openapi',  -- user-provided OpenAPI 3.x spec
                      'custom_graphql',  -- user-provided GraphQL schema
                      'custom_agent',    -- AI agent (LLM/RAG/tool-use)
                      'custom_webhook',  -- simple inbound/outbound HTTP hook
                      'custom_http'      -- fully custom HTTP connector
                    )),

  -- Auth method used by this connector (can be overridden per-instance)
  auth_method       TEXT NOT NULL DEFAULT 'none'
                    CHECK(auth_method IN (
                      'none',            -- no auth needed
                      'api_key',         -- static API key (header or query param)
                      'oauth2',          -- OAuth 2.0 authorization code flow
                      'oauth2_pkce',     -- OAuth 2.0 PKCE (for SPAs/mobile)
                      'bearer',          -- static Bearer token
                      'basic',           -- HTTP Basic username:password
                      'jwt',             -- signed JWT per-request
                      'hmac',            -- HMAC-signed requests
                      'mcp_sse',         -- MCP over Server-Sent Events
                      'mcp_stdio',       -- MCP over stdin/stdout
                      'mcp_http',        -- MCP over HTTP
                      'custom'           -- defined in auth_config_schema
                    )),

  -- JSON Schema for the auth-configuration fields shown during setup
  -- e.g. for api_key: {"properties":{"api_key":{"type":"string","title":"API Key"}}}
  auth_config_schema    TEXT NOT NULL DEFAULT '{}',

  -- JSON Schema for additional (non-auth) instance-level configuration
  -- e.g. base URL override, account IDs, default parameters
  instance_config_schema TEXT NOT NULL DEFAULT '{}',

  -- For OpenAPI-backed connectors: point to the spec
  openapi_spec_url  TEXT,

  -- Category shown in connector marketplace / picker
  category          TEXT NOT NULL DEFAULT 'other'
                    CHECK(category IN (
                      'social_media','advertising','email_marketing','crm','ai',
                      'analytics','storage','communication','ecommerce','payments',
                      'developer_tools','productivity','maps_location','custom','other'
                    )),

  -- Plan gating
  is_enterprise     INTEGER NOT NULL DEFAULT 0,
  is_active         INTEGER NOT NULL DEFAULT 1,
  is_verified       INTEGER NOT NULL DEFAULT 0,  -- verified / audited by Zenos team

  -- Community connector metadata
  created_by        TEXT REFERENCES users(id) ON DELETE SET NULL,  -- NULL = Zenos built-in
  org_id            TEXT REFERENCES organizations(id) ON DELETE CASCADE,  -- NULL = global

  version           TEXT NOT NULL DEFAULT '1.0.0',
  created_at        TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_connector_def_slug       ON connector_definitions(slug);
CREATE INDEX IF NOT EXISTS idx_connector_def_category   ON connector_definitions(category);
CREATE INDEX IF NOT EXISTS idx_connector_def_source     ON connector_definitions(source_type);
CREATE INDEX IF NOT EXISTS idx_connector_def_active     ON connector_definitions(is_active);

-- ═══════════════════════════════════════════════════════════════════════════════
-- PART 2 — CONNECTOR ACTIONS (operations each connector exposes to the canvas)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS connector_actions (
  id                    TEXT PRIMARY KEY,
  -- Convention: '{connector_slug}.{action_key}'
  -- e.g. 'instagram.post_image', 'x_twitter.post_tweet', 'google_maps.geocode'

  connector_definition_id TEXT NOT NULL REFERENCES connector_definitions(id) ON DELETE CASCADE,
  action_key            TEXT NOT NULL,   -- machine-readable, unique per connector
  name                  TEXT NOT NULL,   -- display name shown on canvas
  description           TEXT,
  category              TEXT,            -- grouping within the connector's action list

  -- The node category this action appears under in the canvas palette
  node_category         TEXT NOT NULL DEFAULT 'action'
                        CHECK(node_category IN
                          ('trigger','action','condition','transform','delay','subflow')),

  -- JSON Schemas for input validation and output typing (used by canvas and DO executor)
  input_schema          TEXT NOT NULL DEFAULT '{}',
  output_schema         TEXT NOT NULL DEFAULT '{}',

  -- Cost model for this action (overrides default if connector has a cost)
  cost_model            TEXT NOT NULL DEFAULT 'per_execution'
                        CHECK(cost_model IN
                          ('none','per_execution','per_unit','per_token','actual')),
  rate_microcents       INTEGER NOT NULL DEFAULT 0,
  unit_label            TEXT,

  requires_enterprise   INTEGER NOT NULL DEFAULT 0,
  is_active             INTEGER NOT NULL DEFAULT 1,
  sort_order            INTEGER NOT NULL DEFAULT 0,

  UNIQUE(connector_definition_id, action_key)
);

CREATE INDEX IF NOT EXISTS idx_connector_actions_def_id    ON connector_actions(connector_definition_id);
CREATE INDEX IF NOT EXISTS idx_connector_actions_category  ON connector_actions(node_category);

-- ═══════════════════════════════════════════════════════════════════════════════
-- PART 3 — OAUTH 2.0 PROVIDER CONFIGS (one row per OAuth platform)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS connector_oauth_providers (
  id                      TEXT PRIMARY KEY,
  connector_definition_id TEXT NOT NULL UNIQUE REFERENCES connector_definitions(id) ON DELETE CASCADE,
  authorization_url       TEXT NOT NULL,
  token_url               TEXT NOT NULL,
  revoke_url              TEXT,
  userinfo_url            TEXT,
  default_scopes          TEXT NOT NULL DEFAULT '[]',  -- JSON array of scope strings
  pkce_supported          INTEGER NOT NULL DEFAULT 0,
  token_placement         TEXT NOT NULL DEFAULT 'header'
                          CHECK(token_placement IN ('header','query','body')),
  -- Cloudflare Worker Secrets names for client credentials (set via wrangler secret)
  client_id_secret_name   TEXT NOT NULL,    -- e.g. 'INSTAGRAM_CLIENT_ID'
  client_secret_name      TEXT NOT NULL,    -- e.g. 'INSTAGRAM_CLIENT_SECRET'
  extra_auth_params       TEXT NOT NULL DEFAULT '{}'   -- JSON: extra params for auth URL
);

CREATE INDEX IF NOT EXISTS idx_oauth_providers_connector ON connector_oauth_providers(connector_definition_id);

-- Per-instance OAuth token references (actual tokens encrypted in KV)
CREATE TABLE IF NOT EXISTS connector_oauth_tokens (
  id                      TEXT PRIMARY KEY,
  connector_instance_id   TEXT NOT NULL REFERENCES connector_instances(id) ON DELETE CASCADE,
  org_id                  TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  -- KV keys where the encrypted tokens live
  access_token_kv_key     TEXT NOT NULL,
  refresh_token_kv_key    TEXT,
  -- Metadata (no plaintext tokens here)
  scopes_granted          TEXT NOT NULL DEFAULT '[]',  -- JSON array
  expires_at              TEXT,
  refresh_expires_at      TEXT,
  connected_account_id    TEXT,   -- platform account ID (e.g. Instagram user_id)
  connected_account_name  TEXT,   -- display name shown in settings
  created_at              TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at              TEXT NOT NULL DEFAULT (datetime('now'))
);

-- NOTE: connector_oauth_tokens uses connector_instances(id) — that table is
-- created in PART 4 below. In SQLite/D1 the FK constraint is not enforced
-- during CREATE; it resolves correctly at runtime after both tables exist.

-- ═══════════════════════════════════════════════════════════════════════════════
-- PART 4 — CONNECTOR INSTANCES (per-org authenticated connections)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS connector_instances (
  id                      TEXT PRIMARY KEY,
  org_id                  TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  connector_definition_id TEXT NOT NULL REFERENCES connector_definitions(id) ON DELETE CASCADE,

  name                    TEXT NOT NULL,  -- user label: "Marketing Instagram", "Dev Google Maps"

  -- Auth override (inherits from definition if NULL)
  auth_method             TEXT,

  -- KV key holding encrypted credential JSON for non-OAuth connectors
  -- (API keys, bearer tokens, HMAC secrets, etc.)
  kv_secret_key           TEXT,

  -- Additional instance-level config (base URL, account IDs, etc.)
  instance_config         TEXT NOT NULL DEFAULT '{}',  -- JSON

  status                  TEXT NOT NULL DEFAULT 'pending_auth'
                          CHECK(status IN (
                            'pending_auth',   -- credentials not yet provided
                            'active',         -- tested and working
                            'error',          -- last test failed
                            'revoked',        -- auth revoked by user or platform
                            'expired'         -- OAuth token expired and refresh failed
                          )),

  last_tested_at          TEXT,
  last_error              TEXT,
  last_error_at           TEXT,

  -- Link back to legacy workflow_integrations row for transition period
  legacy_integration_id   TEXT REFERENCES workflow_integrations(id) ON DELETE SET NULL,

  created_by              TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at              TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at              TEXT NOT NULL DEFAULT (datetime('now')),

  UNIQUE(org_id, connector_definition_id, name)
);

CREATE INDEX IF NOT EXISTS idx_conn_instances_org_id      ON connector_instances(org_id);
CREATE INDEX IF NOT EXISTS idx_conn_instances_def_id      ON connector_instances(connector_definition_id);
CREATE INDEX IF NOT EXISTS idx_conn_instances_status      ON connector_instances(status);

-- ═══════════════════════════════════════════════════════════════════════════════
-- PART 5 — MCP SERVER REGISTRY
-- Model Context Protocol servers exposed as first-class connectors.
-- Each registered MCP server auto-generates a connector_definition row
-- and one connector_action row per exposed tool.
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS mcp_server_registry (
  id                      TEXT PRIMARY KEY,
  org_id                  TEXT REFERENCES organizations(id) ON DELETE CASCADE,  -- NULL = global/admin
  connector_definition_id TEXT REFERENCES connector_definitions(id) ON DELETE SET NULL,

  name                    TEXT NOT NULL,
  description             TEXT,

  transport               TEXT NOT NULL DEFAULT 'sse'
                          CHECK(transport IN ('stdio','sse','http')),

  -- For SSE / HTTP transports
  endpoint_url            TEXT,

  -- For stdio transport (Cloudflare Workers cannot use stdio directly;
  -- wrap in a Worker proxy or use a self-hosted runner)
  command                 TEXT,   -- e.g. 'npx @modelcontextprotocol/server-filesystem /data'
  args                    TEXT NOT NULL DEFAULT '[]',  -- JSON array of CLI args
  env_vars_kv_key         TEXT,   -- KV key with encrypted env vars JSON

  -- Auth for the MCP server endpoint itself
  auth_method             TEXT DEFAULT 'bearer',
  kv_secret_key           TEXT,   -- encrypted bearer/api_key for the MCP endpoint

  -- Capabilities discovered from the server
  -- Updated automatically when the connector is registered / health-checked
  tools_schema            TEXT NOT NULL DEFAULT '[]',
  -- JSON: array of MCP tool definitions
  -- [{"name":"read_file","description":"...","inputSchema":{"type":"object",...}}, ...]
  resources_schema        TEXT NOT NULL DEFAULT '[]',
  prompts_schema          TEXT NOT NULL DEFAULT '[]',

  last_synced_at          TEXT,   -- when tools_schema was last refreshed
  status                  TEXT NOT NULL DEFAULT 'pending'
                          CHECK(status IN ('pending','active','unreachable','error')),
  last_error              TEXT,

  created_by              TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at              TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at              TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_mcp_registry_org_id         ON mcp_server_registry(org_id);
CREATE INDEX IF NOT EXISTS idx_mcp_registry_connector_def  ON mcp_server_registry(connector_definition_id);
CREATE INDEX IF NOT EXISTS idx_mcp_registry_status         ON mcp_server_registry(status);

-- ═══════════════════════════════════════════════════════════════════════════════
-- PART 6 — CUSTOM AI AGENTS
-- An agent is an AI-powered node that can call tools, chain LLM calls,
-- do RAG retrieval, etc.  Once defined it is auto-registered as a connector
-- and appears in the canvas palette as an `action` node.
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS custom_agents (
  id                      TEXT PRIMARY KEY,
  org_id                  TEXT REFERENCES organizations(id) ON DELETE CASCADE,
  connector_definition_id TEXT REFERENCES connector_definitions(id) ON DELETE SET NULL,

  name                    TEXT NOT NULL,
  description             TEXT,

  agent_type              TEXT NOT NULL DEFAULT 'llm_chain'
                          CHECK(agent_type IN (
                            'llm_chain',      -- simple prompt → response
                            'rag_agent',       -- retrieval-augmented generation
                            'tool_use_agent',  -- LLM with tool-calling loop
                            'mcp_agent',       -- agent that orchestrates MCP tools
                            'custom_http'      -- calls an external agent API endpoint
                          )),

  -- Model configuration
  model_provider          TEXT NOT NULL DEFAULT 'cloudflare_ai',
  -- 'cloudflare_ai','openai','anthropic','google_gemini','custom'
  model_id                TEXT NOT NULL DEFAULT '@cf/meta/llama-3-8b-instruct',
  model_config            TEXT NOT NULL DEFAULT '{}',
  -- JSON: {"temperature":0.7,"max_tokens":1024,"top_p":1.0}

  -- Agent behaviour
  system_prompt           TEXT,
  -- For rag_agent: which knowledge base to query
  knowledge_base_id       TEXT,   -- future: links to vector store / R2 key
  -- For tool_use_agent: which connector_actions are available as tools
  tool_connector_action_ids TEXT NOT NULL DEFAULT '[]',  -- JSON array of connector_actions.id
  -- For mcp_agent: which MCP server to use
  mcp_server_id           TEXT REFERENCES mcp_server_registry(id) ON DELETE SET NULL,
  -- For custom_http: endpoint URL
  endpoint_url            TEXT,
  kv_secret_key           TEXT,   -- encrypted bearer token for endpoint

  -- I/O schemas (exposed to workflow canvas)
  input_schema            TEXT NOT NULL DEFAULT '{}',
  output_schema           TEXT NOT NULL DEFAULT '{}',

  is_active               INTEGER NOT NULL DEFAULT 1,
  created_by              TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at              TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at              TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_custom_agents_org_id    ON custom_agents(org_id);
CREATE INDEX IF NOT EXISTS idx_custom_agents_type      ON custom_agents(agent_type);

-- ═══════════════════════════════════════════════════════════════════════════════
-- PART 7 — WORKFLOW NODE → CONNECTOR BINDING
-- Links a specific canvas node (workflow_nodes) to a connector instance
-- and a specific action.  Also stores the parameter bindings that tell the
-- executor how to map workflow context variables to action input fields.
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS workflow_node_connector_bindings (
  id                      TEXT PRIMARY KEY,
  workflow_node_id        TEXT NOT NULL UNIQUE REFERENCES workflow_nodes(id) ON DELETE CASCADE,
  connector_instance_id   TEXT NOT NULL REFERENCES connector_instances(id) ON DELETE CASCADE,
  connector_action_id     TEXT NOT NULL REFERENCES connector_actions(id) ON DELETE CASCADE,

  -- Parameter bindings: how to map workflow context vars to action input fields
  -- JSON: {"field_name": "{{context.keywords}}", "account_id": "{{config.ad_account_id}}"}
  -- Supports: literal values, context variable refs {{varname}},
  --           expression refs {{expr:upper(context.title)}}
  param_bindings          TEXT NOT NULL DEFAULT '{}',

  -- Output bindings: which action outputs to assign to context variables
  -- JSON: {"campaign_id": "fb_campaign_id", "estimated_spend": "cost_estimate"}
  output_bindings         TEXT NOT NULL DEFAULT '{}',

  -- Retry policy for this node (overrides workflow-level default)
  max_retries             INTEGER NOT NULL DEFAULT 2,
  retry_delay_seconds     INTEGER NOT NULL DEFAULT 30,
  timeout_seconds         INTEGER NOT NULL DEFAULT 120,

  created_at              TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_node_bindings_node_id      ON workflow_node_connector_bindings(workflow_node_id);
CREATE INDEX IF NOT EXISTS idx_node_bindings_instance_id  ON workflow_node_connector_bindings(connector_instance_id);
CREATE INDEX IF NOT EXISTS idx_node_bindings_action_id    ON workflow_node_connector_bindings(connector_action_id);

-- ═══════════════════════════════════════════════════════════════════════════════
-- PART 8 — CONNECTOR COMMUNITY MARKETPLACE
-- Orgs can publish their custom connectors for others to install.
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS connector_marketplace_listings (
  id                      TEXT PRIMARY KEY,
  connector_definition_id TEXT NOT NULL UNIQUE REFERENCES connector_definitions(id) ON DELETE CASCADE,
  publisher_org_id        TEXT REFERENCES organizations(id) ON DELETE SET NULL,
  publisher_user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  listing_title           TEXT NOT NULL,
  short_description       TEXT NOT NULL,
  long_description        TEXT,
  tags                    TEXT NOT NULL DEFAULT '[]',  -- JSON
  screenshot_urls         TEXT NOT NULL DEFAULT '[]',  -- JSON

  is_public               INTEGER NOT NULL DEFAULT 1,
  install_count           INTEGER NOT NULL DEFAULT 0,
  star_count              INTEGER NOT NULL DEFAULT 0,

  published_at            TEXT,
  created_at              TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_connector_listings_public ON connector_marketplace_listings(is_public);
CREATE INDEX IF NOT EXISTS idx_connector_listings_org    ON connector_marketplace_listings(publisher_org_id);

-- Track installs: which org installed which community connector definition
CREATE TABLE IF NOT EXISTS connector_installs (
  org_id                  TEXT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  connector_definition_id TEXT NOT NULL REFERENCES connector_definitions(id) ON DELETE CASCADE,
  installed_by            TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  installed_at            TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (org_id, connector_definition_id)
);

CREATE INDEX IF NOT EXISTS idx_connector_installs_org ON connector_installs(org_id);

-- ═══════════════════════════════════════════════════════════════════════════════
-- PART 9 — EXTEND workflow_integrations AND workflow_node_types FOR TRANSITION
-- ═══════════════════════════════════════════════════════════════════════════════

-- Bridge old workflow_integrations to new connector_instances
ALTER TABLE workflow_integrations
  ADD COLUMN connector_instance_id TEXT
  REFERENCES connector_instances(id) ON DELETE SET NULL;

-- Allow workflow_node_types to be backed by a connector definition
-- (auto-populated when a new connector is installed; NULL for built-in nodes)
ALTER TABLE workflow_node_types
  ADD COLUMN connector_definition_id TEXT
  REFERENCES connector_definitions(id) ON DELETE SET NULL;

ALTER TABLE workflow_node_types
  ADD COLUMN connector_action_id TEXT
  REFERENCES connector_actions(id) ON DELETE SET NULL;

-- Optional: link workflow_nodes directly to their binding for faster executor lookup
ALTER TABLE workflow_nodes
  ADD COLUMN connector_binding_id TEXT
  REFERENCES workflow_node_connector_bindings(id) ON DELETE SET NULL;

-- ═══════════════════════════════════════════════════════════════════════════════
-- PART 10 — SEED: BUILT-IN CONNECTOR DEFINITIONS (20 platforms + generic types)
-- ═══════════════════════════════════════════════════════════════════════════════

INSERT OR IGNORE INTO connector_definitions
  (id, name, slug, description, source_type, auth_method, category, is_enterprise, is_verified,
   auth_config_schema, instance_config_schema)
VALUES

  -- ── SOCIAL MEDIA ──────────────────────────────────────────────────────────
  ('instagram',
   'Instagram', 'instagram',
   'Post images/videos, read insights, manage comments via Meta Graph API.',
   'builtin','oauth2','social_media',1,1,
   '{}',
   '{"properties":{"instagram_account_id":{"type":"string","title":"Instagram Business Account ID"},"facebook_page_id":{"type":"string","title":"Linked Facebook Page ID"}}}'),

  ('x_twitter',
   'X (Twitter)', 'x_twitter',
   'Post tweets/threads, schedule, analyze engagement, run Twitter Ads.',
   'builtin','oauth2','social_media',0,1,
   '{}',
   '{"properties":{"account_id":{"type":"string","title":"X Account ID"}}}'),

  ('linkedin',
   'LinkedIn', 'linkedin',
   'Share posts, manage Company Page, run LinkedIn Ads, export contacts.',
   'builtin','oauth2','social_media',1,1,
   '{}',
   '{"properties":{"organization_id":{"type":"string","title":"LinkedIn Organization URN"},"person_id":{"type":"string","title":"Person URN (for personal posts)"}}}'),

  ('facebook_pages',
   'Facebook Pages', 'facebook_pages',
   'Post to Facebook Page, read analytics, manage ads via Marketing API.',
   'builtin','oauth2','social_media',0,1,
   '{}',
   '{"properties":{"page_id":{"type":"string","title":"Facebook Page ID"},"ad_account_id":{"type":"string","title":"Ad Account ID (for ads actions)"}}}'),

  ('tiktok',
   'TikTok', 'tiktok',
   'Post videos, read TikTok Analytics, run TikTok Ads.',
   'builtin','oauth2','social_media',1,1,
   '{}',
   '{"properties":{"advertiser_id":{"type":"string","title":"TikTok Ads Advertiser ID"}}}'),

  ('pinterest',
   'Pinterest', 'pinterest',
   'Create Pins, manage boards, run Pinterest Ads.',
   'builtin','oauth2','social_media',1,1,
   '{}','{}'),

  ('youtube',
   'YouTube', 'youtube',
   'Publish videos, manage playlists, read YouTube Analytics.',
   'builtin','oauth2','social_media',1,1,
   '{}',
   '{"properties":{"channel_id":{"type":"string","title":"YouTube Channel ID"}}}'),

  -- ── ADVERTISING ───────────────────────────────────────────────────────────
  ('facebook_ads',
   'Facebook Ads', 'facebook_ads',
   'Create/manage campaigns, ad sets, ads; estimate and track spend via Meta Marketing API.',
   'builtin','oauth2','advertising',1,1,
   '{}',
   '{"properties":{"ad_account_id":{"type":"string","title":"Meta Ad Account ID"},"business_manager_id":{"type":"string","title":"Business Manager ID"}}}'),

  ('google_ads',
   'Google Ads', 'google_ads',
   'Create search/display/smart campaigns, manage keywords, track conversions.',
   'builtin','oauth2','advertising',1,1,
   '{}',
   '{"properties":{"customer_id":{"type":"string","title":"Google Ads Customer ID"},"manager_account_id":{"type":"string","title":"Manager Account ID (MCC)"}}}'),

  ('tiktok_ads',
   'TikTok Ads', 'tiktok_ads',
   'Create and manage TikTok Ads campaigns for Reach and Conversion objectives.',
   'builtin','oauth2','advertising',1,1,
   '{}',
   '{"properties":{"advertiser_id":{"type":"string","title":"TikTok Advertiser ID"}}}'),

  -- ── MAPS & LOCATION ───────────────────────────────────────────────────────
  ('google_maps',
   'Google Maps', 'google_maps',
   'Geocoding, reverse geocoding, place search, distance matrix, routes.',
   'builtin','api_key','maps_location',0,1,
   '{"properties":{"api_key":{"type":"string","title":"Google Maps API Key"}}}',
   '{"properties":{"default_region":{"type":"string","title":"Default Region Bias","default":"us"}}}'),

  -- ── EMAIL MARKETING ───────────────────────────────────────────────────────
  ('mailchimp',
   'Mailchimp', 'mailchimp',
   'Manage subscribers, campaigns, audiences, tags; trigger automations.',
   'builtin','oauth2','email_marketing',0,1,
   '{}',
   '{"properties":{"list_id":{"type":"string","title":"Default Audience ID"}}}'),

  ('sendgrid',
   'SendGrid', 'sendgrid',
   'Send transactional and marketing emails; manage contacts and lists.',
   'builtin','api_key','email_marketing',0,1,
   '{"properties":{"api_key":{"type":"string","title":"SendGrid API Key"}}}','{}'),

  ('klaviyo',
   'Klaviyo', 'klaviyo',
   'E-commerce email/SMS marketing: profiles, flows, events, campaigns.',
   'builtin','api_key','email_marketing',1,1,
   '{"properties":{"private_api_key":{"type":"string","title":"Klaviyo Private API Key"}}}','{}'),

  -- ── CRM ───────────────────────────────────────────────────────────────────
  ('hubspot',
   'HubSpot', 'hubspot',
   'Sync contacts, companies, deals; trigger workflows; track engagement.',
   'builtin','oauth2','crm',1,1,
   '{}',
   '{"properties":{"portal_id":{"type":"string","title":"HubSpot Portal ID"}}}'),

  ('salesforce',
   'Salesforce', 'salesforce',
   'Create/update leads, contacts, opportunities; run SOQL queries; trigger Flows.',
   'builtin','oauth2','crm',1,1,
   '{}',
   '{"properties":{"instance_url":{"type":"string","title":"Salesforce Instance URL"},"api_version":{"type":"string","default":"v59.0"}}}'),

  ('pipedrive',
   'Pipedrive', 'pipedrive',
   'Manage deals, contacts, activities in Pipedrive CRM.',
   'builtin','api_key','crm',1,1,
   '{"properties":{"api_token":{"type":"string","title":"Pipedrive API Token"}}}','{}'),

  -- ── COMMUNICATION ─────────────────────────────────────────────────────────
  ('slack',
   'Slack', 'slack',
   'Post messages, create channels, mention users, react to events.',
   'builtin','oauth2','communication',0,1,
   '{}',
   '{"properties":{"default_channel_id":{"type":"string","title":"Default Channel"}}}'),

  ('discord',
   'Discord', 'discord',
   'Post to channels, manage roles, send DMs via Discord Bot API.',
   'builtin','bearer','communication',0,1,
   '{"properties":{"bot_token":{"type":"string","title":"Discord Bot Token"}}}',
   '{"properties":{"guild_id":{"type":"string","title":"Server (Guild) ID"}}}'),

  ('microsoft_teams',
   'Microsoft Teams', 'microsoft_teams',
   'Post to channels, send adaptive cards, trigger Power Automate flows.',
   'builtin','oauth2','communication',1,1,
   '{}',
   '{"properties":{"team_id":{"type":"string"},"channel_id":{"type":"string"}}}'),

  ('whatsapp_business',
   'WhatsApp Business', 'whatsapp_business',
   'Send template messages and notifications via WhatsApp Business API.',
   'builtin','bearer','communication',1,1,
   '{"properties":{"access_token":{"type":"string","title":"WhatsApp Access Token"}}}',
   '{"properties":{"phone_number_id":{"type":"string","title":"Phone Number ID"}}}'),

  -- ── AI PLATFORMS ──────────────────────────────────────────────────────────
  ('openai',
   'OpenAI', 'openai',
   'GPT-4/o models: text generation, embeddings, image generation, moderation.',
   'builtin','api_key','ai',0,1,
   '{"properties":{"api_key":{"type":"string","title":"OpenAI API Key"}}}',
   '{"properties":{"organization_id":{"type":"string","title":"Organization ID (optional)"}}}'),

  ('anthropic',
   'Anthropic Claude', 'anthropic',
   'Claude 3 models: text generation, summarization, classification, analysis.',
   'builtin','api_key','ai',0,1,
   '{"properties":{"api_key":{"type":"string","title":"Anthropic API Key"}}}','{}'),

  ('cloudflare_ai',
   'Cloudflare Workers AI', 'cloudflare_ai',
   'Run open-source ML models at the edge: LLaMA, Whisper, BAAI embeddings, SDXL.',
   'builtin','none','ai',0,1,
   '{}',
   '{"properties":{"account_id":{"type":"string","title":"CF Account ID"}}}'),

  -- ── ANALYTICS ─────────────────────────────────────────────────────────────
  ('google_analytics_4',
   'Google Analytics 4', 'google_analytics_4',
   'Read GA4 reports, event data, audience segments; create audiences.',
   'builtin','oauth2','analytics',0,1,
   '{}',
   '{"properties":{"property_id":{"type":"string","title":"GA4 Property ID"}}}'),

  ('mixpanel',
   'Mixpanel', 'mixpanel',
   'Track events, manage user profiles, export cohorts.',
   'builtin','api_key','analytics',1,1,
   '{"properties":{"service_account_username":{"type":"string"},"service_account_secret":{"type":"string"}}}',
   '{"properties":{"project_id":{"type":"string"}}}'),

  -- ── PRODUCTIVITY / STORAGE ────────────────────────────────────────────────
  ('notion',
   'Notion', 'notion',
   'Read/write Notion pages and databases; manage blocks.',
   'builtin','oauth2','productivity',0,1,
   '{}','{}'),

  ('airtable',
   'Airtable', 'airtable',
   'Read/write records in Airtable bases and tables.',
   'builtin','api_key','developer_tools',0,1,
   '{"properties":{"personal_access_token":{"type":"string","title":"Airtable Personal Access Token"}}}',
   '{"properties":{"base_id":{"type":"string","title":"Default Base ID"}}}'),

  ('google_sheets',
   'Google Sheets', 'google_sheets',
   'Read/write spreadsheet cells, append rows, manage tabs.',
   'builtin','oauth2','productivity',0,1,
   '{}',
   '{"properties":{"spreadsheet_id":{"type":"string","title":"Default Spreadsheet ID"}}}'),

  -- ── E-COMMERCE / PAYMENTS ─────────────────────────────────────────────────
  ('stripe',
   'Stripe', 'stripe',
   'Create payment intents, manage customers/subscriptions, issue refunds, read reports.',
   'builtin','api_key','payments',1,1,
   '{"properties":{"secret_key":{"type":"string","title":"Stripe Secret Key"}}}','{}'),

  ('shopify',
   'Shopify', 'shopify',
   'Manage products, orders, customers, and marketing automations.',
   'builtin','oauth2','ecommerce',1,1,
   '{}',
   '{"properties":{"shop_domain":{"type":"string","title":"Shopify Store Domain (yourstore.myshopify.com)"}}}'),

  -- ── DEVELOPER TOOLS ───────────────────────────────────────────────────────
  ('github',
   'GitHub', 'github',
   'Create issues, PRs, trigger workflows, manage repos via GitHub REST and GraphQL API.',
   'builtin','oauth2','developer_tools',0,1,
   '{}','{}'),

  ('jira',
   'Jira', 'jira',
   'Create/update issues, manage sprints, sync projects.',
   'builtin','oauth2','developer_tools',1,1,
   '{}',
   '{"properties":{"site_url":{"type":"string","title":"Atlassian Site URL"}}}'),

  -- ── GENERIC / CUSTOM ──────────────────────────────────────────────────────
  ('custom_webhook',
   'Custom Webhook', 'custom_webhook',
   'Send data to any URL via HTTP POST (inbound or outbound). No auth required by default.',
   'builtin','none','custom',0,1,
   '{"properties":{"hmac_secret":{"type":"string","title":"HMAC Secret (optional, for signing)"}}}',
   '{"properties":{"default_url":{"type":"string","title":"Default Endpoint URL"},"content_type":{"type":"string","default":"application/json"}}}'),

  ('custom_http',
   'Custom HTTP Connector', 'custom_http',
   'Connect to any REST API by defining requests manually. Supports all auth methods.',
   'builtin','custom','custom',0,1,
   '{"oneOf":[{"title":"API Key","properties":{"api_key":{"type":"string"},"key_header_name":{"type":"string","default":"X-API-Key"}}},{"title":"Bearer Token","properties":{"bearer_token":{"type":"string"}}},{"title":"Basic Auth","properties":{"username":{"type":"string"},"password":{"type":"string"}}},{"title":"OAuth2","properties":{"oauth2":{"type":"object"}}}]}',
   '{"properties":{"base_url":{"type":"string","title":"Base URL"},"default_headers":{"type":"object","title":"Default Headers"}}}'),

  ('custom_openapi',
   'Custom OpenAPI Connector', 'custom_openapi',
   'Point to an OpenAPI 3.x spec URL and automatically generate all actions from its endpoints.',
   'builtin','custom','custom',0,1,
   '{}',
   '{"properties":{"spec_url":{"type":"string","title":"OpenAPI Spec URL (JSON or YAML)"},"base_url":{"type":"string","title":"Base URL override"}}}'),

  ('mcp_server',
   'MCP Server', 'mcp_server',
   'Connect any Model Context Protocol server. Tools become workflow action nodes automatically.',
   'builtin','mcp_http','custom',1,1,
   '{"properties":{"bearer_token":{"type":"string","title":"MCP Server Bearer Token"}}}',
   '{"properties":{"server_url":{"type":"string","title":"MCP Server URL (SSE or HTTP)"}}}'),

  ('custom_ai_agent',
   'Custom AI Agent', 'custom_ai_agent',
   'Define an AI agent (LLM chain, RAG, tool-use) and expose it as a reusable workflow node.',
   'builtin','none','ai',0,1,
   '{}','{}');

-- ═══════════════════════════════════════════════════════════════════════════════
-- PART 11 — SEED: CONNECTOR ACTIONS FOR TOP PLATFORMS
-- ═══════════════════════════════════════════════════════════════════════════════

INSERT OR IGNORE INTO connector_actions
  (id, connector_definition_id, action_key, name, description, node_category,
   input_schema, output_schema, cost_model, rate_microcents, requires_enterprise)
VALUES

  -- ── INSTAGRAM ─────────────────────────────────────────────────────────────
  ('instagram.post_image',       'instagram','post_image',        'Post Image',           'Post a single image to an Instagram Business account.',                  'action','{"properties":{"image_url":{"type":"string"},"caption":{"type":"string"},"location_id":{"type":"string"}}}','{"properties":{"post_id":{"type":"string"},"permalink":{"type":"string"}}}','per_execution',0,1),
  ('instagram.post_carousel',    'instagram','post_carousel',     'Post Carousel',        'Post a multi-image carousel post.',                                      'action','{"properties":{"image_urls":{"type":"array","items":{"type":"string"}},"caption":{"type":"string"}}}','{"properties":{"post_id":{"type":"string"},"permalink":{"type":"string"}}}','per_execution',0,1),
  ('instagram.post_reel',        'instagram','post_reel',         'Post Reel',            'Upload and publish a Reel video.',                                       'action','{"properties":{"video_url":{"type":"string"},"caption":{"type":"string"},"share_to_feed":{"type":"boolean","default":true}}}','{"properties":{"reel_id":{"type":"string"}}}','per_execution',0,1),
  ('instagram.get_insights',     'instagram','get_insights',      'Get Post Insights',    'Fetch reach, impressions, engagement for a post.',                       'action','{"properties":{"post_id":{"type":"string"},"metrics":{"type":"array","items":{"type":"string"}}}}','{"properties":{"insights":{"type":"object"}}}','per_execution',0,1),
  ('instagram.trigger_new_post', 'instagram','trigger_new_post',  'New Post (Trigger)',   'Fires when a new post is created on the connected Instagram account.',    'trigger','{}','{"properties":{"post_id":{"type":"string"},"media_type":{"type":"string"},"timestamp":{"type":"string"}}}','none',0,1),

  -- ── X (TWITTER) ───────────────────────────────────────────────────────────
  ('x_twitter.post_tweet',       'x_twitter','post_tweet',        'Post Tweet',           'Post a text tweet (up to 280 chars).',                                   'action','{"properties":{"text":{"type":"string","maxLength":280},"reply_to_id":{"type":"string"}}}','{"properties":{"tweet_id":{"type":"string"},"url":{"type":"string"}}}','per_execution',0,0),
  ('x_twitter.post_thread',      'x_twitter','post_thread',       'Post Thread',          'Post a series of connected tweets as a thread.',                         'action','{"properties":{"tweets":{"type":"array","items":{"type":"string","maxLength":280}}}}','{"properties":{"thread_ids":{"type":"array"},"first_tweet_url":{"type":"string"}}}','per_execution',0,0),
  ('x_twitter.post_with_media',  'x_twitter','post_with_media',   'Post with Media',      'Post a tweet with an image or video attachment.',                        'action','{"properties":{"text":{"type":"string"},"media_url":{"type":"string"},"media_type":{"type":"string","enum":["image","video","gif"]}}}','{"properties":{"tweet_id":{"type":"string"}}}','per_execution',0,0),
  ('x_twitter.get_analytics',    'x_twitter','get_analytics',     'Get Tweet Analytics',  'Fetch impressions, engagements, link clicks for a tweet.',               'action','{"properties":{"tweet_id":{"type":"string"}}}','{"properties":{"impressions":{"type":"integer"},"engagements":{"type":"integer"},"link_clicks":{"type":"integer"}}}','per_execution',0,0),
  ('x_twitter.search_tweets',    'x_twitter','search_tweets',     'Search Tweets',        'Search recent tweets by keyword or hashtag.',                            'action','{"properties":{"query":{"type":"string"},"max_results":{"type":"integer","default":10}}}','{"properties":{"tweets":{"type":"array"}}}','per_execution',0,0),

  -- ── LINKEDIN ──────────────────────────────────────────────────────────────
  ('linkedin.post_article',      'linkedin','post_article',       'Share Article Post',   'Share an article link as a LinkedIn post (person or company page).',      'action','{"properties":{"text":{"type":"string"},"article_url":{"type":"string"},"post_as":{"type":"string","enum":["person","organization"]}}}','{"properties":{"post_urn":{"type":"string"},"post_url":{"type":"string"}}}','per_execution',0,1),
  ('linkedin.post_image',        'linkedin','post_image',         'Post with Image',      'Share text + image on LinkedIn.',                                        'action','{"properties":{"text":{"type":"string"},"image_url":{"type":"string"},"post_as":{"type":"string","enum":["person","organization"]}}}','{"properties":{"post_urn":{"type":"string"}}}','per_execution',0,1),
  ('linkedin.create_ad',         'linkedin','create_ad',          'Create LinkedIn Ad',   'Create a Sponsored Content campaign targeting by job title/industry.',    'action','{"properties":{"campaign_name":{"type":"string"},"budget_daily_cents":{"type":"integer"},"targeting":{"type":"object"},"creative_url":{"type":"string"},"headline":{"type":"string"}}}','{"properties":{"campaign_id":{"type":"string"},"status":{"type":"string"}}}','actual',0,1),
  ('linkedin.get_page_analytics','linkedin','get_page_analytics', 'Get Page Analytics',   'Fetch follower growth, impressions, engagement for a Company Page.',      'action','{"properties":{"time_range":{"type":"string","enum":["LAST_7_DAYS","LAST_30_DAYS","LAST_90_DAYS"]}}}','{"properties":{"followers":{"type":"integer"},"impressions":{"type":"integer"}}}','per_execution',0,1),

  -- ── FACEBOOK ADS (connector-backed, replaces raw node types from 0036) ────
  ('facebook_ads.estimate_cost', 'facebook_ads','estimate_cost',  'Estimate Cost',        'Estimate reach and spend for a campaign without creating it.',            'action','{"properties":{"targeting_keywords":{"type":"array"},"budget_daily_cents":{"type":"integer"},"campaign_objective":{"type":"string"},"duration_days":{"type":"integer","default":7}}}','{"properties":{"estimated_reach_min":{"type":"integer"},"estimated_reach_max":{"type":"integer"},"estimated_total_spend_cents":{"type":"integer"},"cpc_estimate_cents":{"type":"integer"}}}','per_execution',0,1),
  ('facebook_ads.create_campaign','facebook_ads','create_campaign','Create Campaign',      'Create an ad campaign with targeting and budget.',                       'action','{"properties":{"campaign_name":{"type":"string"},"campaign_objective":{"type":"string"},"targeting_keywords":{"type":"array"},"budget_daily_cents":{"type":"integer"},"start_time":{"type":"string"},"end_time":{"type":"string"},"ad_creative_source":{"type":"string","enum":["article_meta","custom"]},"headline":{"type":"string"}}}','{"properties":{"campaign_id":{"type":"string"},"adset_id":{"type":"string"},"ad_id":{"type":"string"},"status":{"type":"string"}}}','actual',0,1),
  ('facebook_ads.boost_post',    'facebook_ads','boost_post',     'Boost Post',           'Boost an existing Facebook page post.',                                  'action','{"properties":{"page_post_id":{"type":"string"},"budget_total_cents":{"type":"integer"},"duration_days":{"type":"integer"},"targeting_keywords":{"type":"array"}}}','{"properties":{"boost_id":{"type":"string"}}}','actual',0,1),
  ('facebook_ads.get_insights',  'facebook_ads','get_insights',   'Get Campaign Insights','Fetch spend, reach, clicks, CPM for an existing campaign.',              'action','{"properties":{"campaign_id":{"type":"string"},"date_preset":{"type":"string","default":"last_7d"}}}','{"properties":{"spend":{"type":"number"},"reach":{"type":"integer"},"clicks":{"type":"integer"},"cpm":{"type":"number"}}}','per_execution',0,1),

  -- ── GOOGLE ADS ────────────────────────────────────────────────────────────
  ('google_ads.create_campaign', 'google_ads','create_campaign',  'Create Campaign',      'Create a Google Ads Search or Display campaign.',                        'action','{"properties":{"campaign_name":{"type":"string"},"keywords":{"type":"array"},"budget_daily_cents":{"type":"integer"},"campaign_type":{"type":"string","enum":["SEARCH","DISPLAY","SMART"]}}}','{"properties":{"campaign_id":{"type":"string"},"status":{"type":"string"}}}','actual',0,1),
  ('google_ads.add_keywords',    'google_ads','add_keywords',     'Add Keywords',         'Add keywords to an existing Google Ads ad group.',                       'action','{"properties":{"ad_group_id":{"type":"string"},"keywords":{"type":"array","items":{"type":"object","properties":{"text":{"type":"string"},"match_type":{"type":"string","enum":["BROAD","PHRASE","EXACT"]}}}}}}','{"properties":{"added_count":{"type":"integer"}}}','per_execution',0,1),
  ('google_ads.get_performance', 'google_ads','get_performance',  'Get Performance',      'Fetch impressions, clicks, cost, conversions for a campaign.',           'action','{"properties":{"campaign_id":{"type":"string"},"date_range":{"type":"string","default":"LAST_7_DAYS"}}}','{"properties":{"impressions":{"type":"integer"},"clicks":{"type":"integer"},"cost_micros":{"type":"integer"},"conversions":{"type":"number"}}}','per_execution',0,1),

  -- ── GOOGLE MAPS ───────────────────────────────────────────────────────────
  ('google_maps.geocode',        'google_maps','geocode',         'Geocode Address',      'Convert a text address to latitude/longitude coordinates.',              'action','{"properties":{"address":{"type":"string"},"region":{"type":"string"}}}','{"properties":{"lat":{"type":"number"},"lng":{"type":"number"},"formatted_address":{"type":"string"},"place_id":{"type":"string"}}}','per_unit',2000,0),
  ('google_maps.reverse_geocode','google_maps','reverse_geocode', 'Reverse Geocode',      'Convert lat/lng to a human-readable address.',                           'action','{"properties":{"lat":{"type":"number"},"lng":{"type":"number"}}}','{"properties":{"formatted_address":{"type":"string"},"components":{"type":"object"}}}','per_unit',2000,0),
  ('google_maps.find_place',     'google_maps','find_place',      'Find Place',           'Search for a business or place by name/type near a location.',           'action','{"properties":{"query":{"type":"string"},"location":{"type":"string"},"radius_meters":{"type":"integer","default":5000}}}','{"properties":{"places":{"type":"array"}}}','per_unit',17000,0),
  ('google_maps.distance_matrix','google_maps','distance_matrix', 'Distance Matrix',      'Get travel time and distance between origins and destinations.',         'action','{"properties":{"origins":{"type":"array","items":{"type":"string"}},"destinations":{"type":"array","items":{"type":"string"}},"mode":{"type":"string","enum":["driving","walking","transit","bicycling"],"default":"driving"}}}','{"properties":{"rows":{"type":"array"}}}','per_unit',10000,0),

  -- ── OPENAI ────────────────────────────────────────────────────────────────
  ('openai.complete',            'openai','complete',             'Chat Completion',      'Send a prompt to GPT-4/o and get a completion response.',                'action','{"properties":{"model":{"type":"string","default":"gpt-4o"},"system_prompt":{"type":"string"},"user_message":{"type":"string"},"max_tokens":{"type":"integer","default":1024},"temperature":{"type":"number","default":0.7}}}','{"properties":{"content":{"type":"string"},"tokens_used":{"type":"integer"},"model":{"type":"string"}}}','per_token',3,0),
  ('openai.embed',               'openai','embed',                'Create Embeddings',    'Generate text embeddings for semantic search or clustering.',             'action','{"properties":{"input":{"type":"string"},"model":{"type":"string","default":"text-embedding-3-small"}}}','{"properties":{"embedding":{"type":"array","items":{"type":"number"}},"tokens_used":{"type":"integer"}}}','per_token',0,0),
  ('openai.image_gen',           'openai','image_gen',           'Generate Image',        'Generate an image from a text prompt using DALL·E 3.',                   'action','{"properties":{"prompt":{"type":"string"},"size":{"type":"string","default":"1024x1024"},"quality":{"type":"string","default":"standard"}}}','{"properties":{"image_url":{"type":"string"}}}','per_unit',4000,0),

  -- ── SLACK ─────────────────────────────────────────────────────────────────
  ('slack.post_message',         'slack','post_message',         'Post Message',         'Post a message to a Slack channel.',                                     'action','{"properties":{"channel":{"type":"string"},"text":{"type":"string"},"blocks":{"type":"array"},"username":{"type":"string"}}}','{"properties":{"ts":{"type":"string"},"channel":{"type":"string"}}}','per_execution',0,0),
  ('slack.post_dm',              'slack','post_dm',              'Send Direct Message',  'Send a DM to a specific Slack user.',                                    'action','{"properties":{"user_id":{"type":"string"},"text":{"type":"string"}}}','{"properties":{"ts":{"type":"string"}}}','per_execution',0,0),
  ('slack.trigger_new_message',  'slack','trigger_new_message',  'New Message (Trigger)','Fires when a new message appears in a specified channel.',                'trigger','{"properties":{"channel":{"type":"string"}}}','{"properties":{"text":{"type":"string"},"user":{"type":"string"},"ts":{"type":"string"}}}','none',0,0),

  -- ── HUBSPOT ───────────────────────────────────────────────────────────────
  ('hubspot.create_contact',     'hubspot','create_contact',     'Create Contact',       'Create a new HubSpot contact.',                                          'action','{"properties":{"email":{"type":"string"},"firstname":{"type":"string"},"lastname":{"type":"string"},"company":{"type":"string"},"website":{"type":"string"},"properties":{"type":"object"}}}','{"properties":{"contact_id":{"type":"string"},"vid":{"type":"integer"}}}','per_execution',0,1),
  ('hubspot.update_contact',     'hubspot','update_contact',     'Update Contact',       'Update fields on an existing HubSpot contact.',                          'action','{"properties":{"contact_id":{"type":"string"},"properties":{"type":"object"}}}','{"properties":{"contact_id":{"type":"string"}}}','per_execution',0,1),
  ('hubspot.create_deal',        'hubspot','create_deal',        'Create Deal',          'Create a deal and optionally associate it with a contact.',              'action','{"properties":{"dealname":{"type":"string"},"amount":{"type":"number"},"pipeline":{"type":"string"},"dealstage":{"type":"string"},"contact_id":{"type":"string"}}}','{"properties":{"deal_id":{"type":"string"}}}','per_execution',0,1),
  ('hubspot.add_to_list',        'hubspot','add_to_list',        'Add to List',          'Add a contact to a HubSpot static list.',                                'action','{"properties":{"list_id":{"type":"string"},"contact_id":{"type":"string"}}}','{"properties":{"success":{"type":"boolean"}}}','per_execution',0,1),

  -- ── CUSTOM WEBHOOK ────────────────────────────────────────────────────────
  ('custom_webhook.outbound',    'custom_webhook','outbound',    'Send Webhook',         'POST JSON payload to any URL.',                                          'action','{"properties":{"url":{"type":"string"},"method":{"type":"string","enum":["POST","PUT","PATCH","GET"],"default":"POST"},"headers":{"type":"object"},"body":{"type":"object"},"timeout_seconds":{"type":"integer","default":30}}}','{"properties":{"status_code":{"type":"integer"},"response_body":{"type":"string"},"latency_ms":{"type":"integer"}}}','per_execution',0,0),
  ('custom_webhook.inbound',     'custom_webhook','inbound',     'Inbound Webhook (Trigger)','Fires when someone POSTs to this workflow''s webhook URL.',           'trigger','{}','{"properties":{"body":{"type":"object"},"headers":{"type":"object"},"query":{"type":"object"}}}','none',0,0),

  -- ── CUSTOM HTTP ───────────────────────────────────────────────────────────
  ('custom_http.request',        'custom_http','request',        'HTTP Request',         'Make a fully customizable HTTP request to any REST endpoint.',           'action','{"properties":{"method":{"type":"string","enum":["GET","POST","PUT","PATCH","DELETE"]},"url":{"type":"string"},"headers":{"type":"object"},"query_params":{"type":"object"},"body":{"type":"object"},"timeout_seconds":{"type":"integer","default":30}}}','{"properties":{"status_code":{"type":"integer"},"headers":{"type":"object"},"body":{"type":"object"},"latency_ms":{"type":"integer"}}}','per_execution',0,0),

  -- ── MCP SERVER ────────────────────────────────────────────────────────────
  ('mcp_server.call_tool',       'mcp_server','call_tool',       'Call MCP Tool',        'Execute a named tool on a registered MCP server. Tool inputs/outputs defined by the server''s schema.','action','{"properties":{"tool_name":{"type":"string","description":"Tool name as registered in mcp_server_registry.tools_schema"},"input":{"type":"object","description":"Tool-specific input matching the tool''s inputSchema"}}}','{"properties":{"result":{"type":"object"},"is_error":{"type":"boolean"}}}','per_execution',0,1),

  -- ── CUSTOM AI AGENT ───────────────────────────────────────────────────────
  ('custom_ai_agent.run',        'custom_ai_agent','run',        'Run Agent',            'Execute a custom AI agent with context variables as input.',             'action','{"properties":{"agent_id":{"type":"string","description":"custom_agents.id"},"input":{"type":"object"}}}','{"properties":{"output":{"type":"object"},"tokens_used":{"type":"integer"},"steps_taken":{"type":"integer"}}}','per_token',0,0);

-- ═══════════════════════════════════════════════════════════════════════════════
-- PART 12 — SEED: OAUTH PROVIDER CONFIGS FOR MAJOR PLATFORMS
-- client_id_secret_name and client_secret_name refer to Cloudflare Worker Secrets
-- that are set via `wrangler secret put` — NEVER stored in D1.
-- ═══════════════════════════════════════════════════════════════════════════════

INSERT OR IGNORE INTO connector_oauth_providers
  (id, connector_definition_id, authorization_url, token_url, revoke_url,
   default_scopes, pkce_supported, client_id_secret_name, client_secret_name)
VALUES
  ('oauth_instagram',   'instagram',    'https://api.instagram.com/oauth/authorize',     'https://api.instagram.com/oauth/access_token',    NULL,       '["instagram_business_basic","instagram_business_content_publish","instagram_business_manage_insights"]',0,'INSTAGRAM_CLIENT_ID','INSTAGRAM_CLIENT_SECRET'),
  ('oauth_x_twitter',   'x_twitter',    'https://twitter.com/i/oauth2/authorize',        'https://api.twitter.com/2/oauth2/token',          'https://api.twitter.com/2/oauth2/revoke','["tweet.read","tweet.write","users.read","offline.access"]',1,'X_CLIENT_ID','X_CLIENT_SECRET'),
  ('oauth_linkedin',    'linkedin',     'https://www.linkedin.com/oauth/v2/authorization','https://www.linkedin.com/oauth/v2/accessToken',  NULL,       '["r_liteprofile","r_emailaddress","w_member_social","r_organization_social","w_organization_social","rw_ads"]',0,'LINKEDIN_CLIENT_ID','LINKEDIN_CLIENT_SECRET'),
  ('oauth_facebook_ads','facebook_ads', 'https://www.facebook.com/v18.0/dialog/oauth',   'https://graph.facebook.com/v18.0/oauth/access_token',NULL,   '["ads_management","ads_read","business_management","public_profile"]',0,'FACEBOOK_APP_ID','FACEBOOK_APP_SECRET'),
  ('oauth_google_ads',  'google_ads',   'https://accounts.google.com/o/oauth2/v2/auth',  'https://oauth2.googleapis.com/token',             'https://oauth2.googleapis.com/revoke','["https://www.googleapis.com/auth/adwords"]',1,'GOOGLE_ADS_CLIENT_ID','GOOGLE_ADS_CLIENT_SECRET'),
  ('oauth_google_maps_ga4','google_analytics_4','https://accounts.google.com/o/oauth2/v2/auth','https://oauth2.googleapis.com/token','https://oauth2.googleapis.com/revoke','["https://www.googleapis.com/auth/analytics.readonly"]',1,'GOOGLE_CLIENT_ID','GOOGLE_CLIENT_SECRET'),
  ('oauth_slack',       'slack',        'https://slack.com/oauth/v2/authorize',           'https://slack.com/api/oauth.v2.access',          NULL,       '["channels:read","chat:write","channels:history","users:read"]',0,'SLACK_CLIENT_ID','SLACK_CLIENT_SECRET'),
  ('oauth_hubspot',     'hubspot',      'https://app.hubspot.com/oauth/authorize',        'https://api.hubapi.com/oauth/v1/token',          NULL,       '["crm.objects.contacts.read","crm.objects.contacts.write","crm.objects.deals.read","crm.objects.deals.write","crm.lists.read","crm.lists.write"]',0,'HUBSPOT_CLIENT_ID','HUBSPOT_CLIENT_SECRET'),
  ('oauth_salesforce',  'salesforce',   'https://login.salesforce.com/services/oauth2/authorize','https://login.salesforce.com/services/oauth2/token',NULL,'["api","refresh_token","offline_access"]',1,'SALESFORCE_CLIENT_ID','SALESFORCE_CLIENT_SECRET'),
  ('oauth_github',      'github',       'https://github.com/login/oauth/authorize',       'https://github.com/login/oauth/access_token',    NULL,       '["repo","read:user","user:email"]',0,'GITHUB_CLIENT_ID','GITHUB_CLIENT_SECRET'),
  ('oauth_notion',      'notion',       'https://api.notion.com/v1/oauth/authorize',      'https://api.notion.com/v1/oauth/token',          NULL,       '[]',0,'NOTION_CLIENT_ID','NOTION_CLIENT_SECRET'),
  ('oauth_google_sheets','google_sheets','https://accounts.google.com/o/oauth2/v2/auth', 'https://oauth2.googleapis.com/token',            'https://oauth2.googleapis.com/revoke','["https://www.googleapis.com/auth/spreadsheets"]',1,'GOOGLE_CLIENT_ID','GOOGLE_CLIENT_SECRET'),
  ('oauth_tiktok',      'tiktok',       'https://www.tiktok.com/v2/auth/authorize/',      'https://open.tiktokapis.com/v2/oauth/token/',    NULL,       '["user.info.basic","video.list","video.publish"]',1,'TIKTOK_CLIENT_KEY','TIKTOK_CLIENT_SECRET'),
  ('oauth_shopify',     'shopify',      'https://{shop_domain}/admin/oauth/authorize',    'https://{shop_domain}/admin/oauth/access_token', NULL,       '["read_products","write_products","read_orders","write_orders","read_customers","write_customers"]',0,'SHOPIFY_CLIENT_ID','SHOPIFY_CLIENT_SECRET'),
  ('oauth_microsoft_teams','microsoft_teams','https://login.microsoftonline.com/common/oauth2/v2.0/authorize','https://login.microsoftonline.com/common/oauth2/v2.0/token',NULL,'["https://graph.microsoft.com/ChannelMessage.Send","https://graph.microsoft.com/User.Read","offline_access"]',1,'MICROSOFT_CLIENT_ID','MICROSOFT_CLIENT_SECRET');

INSERT INTO _migrations (filename) VALUES ('0037_generic_connector_framework.sql');
