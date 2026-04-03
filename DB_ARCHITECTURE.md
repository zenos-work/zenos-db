# Zenos DB Architecture — Full-Stack Decision Record

**Version:** 1.0
**Date:** 2026-03-31
**Status:** Adopted

---

## 1 · Problem Statement

Zenos must support three distinct tiers of data requirements simultaneously:

| Tier | Data Shape | Access Pattern | Scale |
|---|---|---|---|
| **Core platform** | Relational (users, articles, tags, follows) | OLTP, low-latency reads | 10M+ rows |
| **Workflow orchestrator** (n8n-like) | Graph/DAG definitions + variable-shape node configs | Write-once definitions; high-frequency execution logs | 100K+ workflow runs/day |
| **Analytics event stream** | Append-only, wide schema, time-series | Write-heavy, aggregation queries | 10M+ events/day |

No single database technology optimally serves all three. The architecture is therefore **hybrid**.

---

## 2 · Technology Decisions

### 2.1 Primary Relational Store — Cloudflare D1 (SQLite)

**Use for:** All structured, relational data with FK integrity.

| Migration | Domain |
|---|---|
| 0001–0027 | Core MVP: users, articles, tags, comments, bookmarks, likes, follows, notifications, moderation, FTS5 search, membership, series, reactions, ranking |
| 0028 | Enterprise orgs, teams, API keys, SSO config, audit log |
| 0029 | Workflow orchestrator metadata (ownership, versioning, run summaries, node catalog) |
| 0030 | Lead generation: forms, leads, CRM pipeline, email sequences |
| 0031 | Content distribution, scheduling, syndication, RSS feeds |
| 0032 | Newsletters, subscribers, issues, send events |
| 0033 | Analytics events, conversion goals, attribution, A/B experiments, campaigns |
| 0034 | Courses, modules, lessons, enrollments, certificates |
| 0035 | Community spaces, marketplace items, referrals, podcasts |

**Why D1 (SQLite)?**
- Zero cost at Cloudflare scale for most plan tiers
- Runs co-located with Workers → ~0ms query latency
- SQLite FTS5 already used for article search
- Migrations are trivially versioned with sequential `.sql` files

**Limitations addressed by NoSQL tier:**
- SQLite has no native JSON indexing (use `json_extract` in queries as needed)
- SQLite is single-writer; workflow execution state needs concurrent writes → Durable Objects

---

### 2.2 Key-Value Store — Cloudflare Workers KV

**Use for:** Blobs that are large, irregular-shaped, or write-once-read-many.

| KV Key Pattern | Contents | TTL |
|---|---|---|
| `workflow_def:{workflow_id}:{version}` | Full DAG JSON `{nodes:[...], edges:[...]}` — complete canvas definition | None (permanent) |
| `workflow_def:latest:{workflow_id}` | Pointer to latest version (for fast read) | None |
| `wf_node_cfg:{node_id}` | Non-sensitive node display config as JSON | None |
| `wf_secret:{integration_id}` | **Encrypted** integration credentials (SMTP password, API token) | None |
| `wf_run_context:{run_id}` | Live variable context during execution (hot path) | 24h (auto-expire after run) |
| `org_settings:{org_id}` | Org-level feature flags and UI theme JSON | None |
| `form_schema:{form_id}` | Large form field schema JSON | None |
| `session:{token}` | Auth sessions (already in use) | 7 days |

**Why KV for workflow definitions?**
- DAG JSON can be 50–500 KB (100+ nodes, thousands of edges)
- D1 has a 10 MB max row limit but storing large blobs in relational rows is poor practice
- KV gives O(1) lookup by key, globally replicated reads
- Version history in D1 (`workflow_versions` table) acts as the source-of-truth for versioned snapshots

**Security note:** Credentials stored in KV MUST be encrypted at the application layer (AES-256-GCM) before write. The KV key reference (`kv_secret_key` column in `workflow_integrations`) is stored in D1 but the ciphertext lives in KV. The encryption key is stored as a Cloudflare Worker Secret (`wrangler secret put`), never in D1 or KV.

---

### 2.3 Stateful Real-Time Execution — Cloudflare Durable Objects

**Use for:** Live workflow execution state machine (the n8n-like runtime engine).

```
┌───────────────────────────────────────────────────────────┐
│  WorkflowRunDO  (one Durable Object per in-flight run)    │
│                                                           │
│  state = {                                                │
│    run_id: "...",                                         │
│    current_node: "node_abc",                              │
│    context_vars: {...},         ← live variable table     │
│    pending_steps: ["..."],      ← queue of next nodes     │
│    waiting_until: null,         ← for DELAY nodes         │
│    retry_counts: {node_id: 2}                             │
│  }                                                        │
│                                                           │
│  Methods: advance(), retry(), cancel(), getStatus()       │
└───────────────────────────────────────────────────────────┘
          │
          │ on complete/fail
          ▼
   D1: workflow_runs (summary row)
   D1: workflow_run_steps (per-node trace)
```

**Why Durable Objects?**
- Single-instance strongly-consistent storage (no race conditions on state transitions)
- Built-in alarm API for DELAY/WAIT UNTIL nodes (no external cron needed)
- Sub-millisecond state reads within the same Worker request
- Automatic hibernation when idle (zero cost when not running)
- Supports up to 128 KB of stored state per DO instance

**Lifecycle:**
1. Trigger fires → Worker creates `WorkflowRunDO` with `run_id`
2. DO executes node-by-node, updating internal state
3. DELAY nodes set a DO Alarm; DO hibernates, wakes at alarm time
4. On terminal state (success/fail) → DO writes summary to D1 `workflow_runs` and steps to `workflow_run_steps`, then self-destructs

---

### 2.4 Analytics Hot Path — Cloudflare Workers Analytics Engine

**Use for:** High-volume realtime event ingestion (page views, clicks, article reads).

```
Event fires in browser → Worker → Analytics Engine (write)
                                           │
                         ┌─────────────────┘
                         │ (async, batched)
                         ▼
              D1: analytics_events  ← enriched, processed events
```

- Analytics Engine accepts millions of events/day at near-zero cost
- D1 `analytics_events` table holds enriched/de-duplicated events used for funnel analysis
- Raw events in Analytics Engine are queried via `workers-analytics-engine-sql-api` for real-time dashboards

---

## 3 · NoSQL Recommendation for Non-Cloudflare Deployments

If Zenos ever migrates off Cloudflare (or needs a self-hosted development stack), the following replacements apply:

| Cloudflare Service | Self-Hosted Equivalent | Cost |
|---|---|---|
| D1 (SQLite) | **Turso** (libSQL, SQLite-compatible, distributed) | Free tier: 500 DBs, 9 GB |
| Workers KV | **Upstash Redis** (KV) | Free tier: 10K requests/day |
| Durable Objects | **Cloudflare DO** (no true OSS equivalent) | Alternative: **RiverQueue** + Redis for workflow state |
| Analytics Engine | **ClickHouse Cloud** (columnar, OLAP) | Free tier: 1M rows/month |

**Recommendation:** For the workflow engine specifically, if you move to a fully self-hosted stack:
- Use **PostgreSQL with JSONB** for workflow definitions (JSONB indexes on DAG JSON)
- Use **Redis Streams** or **BullMQ** for the execution queue
- Use **PostgreSQL advisory locks** or **Redlock** for per-run mutual exclusion

---

## 4 · Schema Design Principles Applied

1. **TEXT PRIMARY KEY (UUIDs)** — matches existing conventions, safe for D1 distributed writes from Workers
2. **JSON blobs for dynamic config** — stored as `TEXT` columns with naming convention `*_config`, `*_schema`, `*_metadata`. Use `json_extract()` in queries sparingly.
3. **Denormalized counters** (`*_count` columns) — updated asynchronously to avoid hot-row contention. Eventual consistency is acceptable here.
4. **Append-only tables** — `audit_log`, `analytics_events`, `lead_events`, `workflow_run_steps` never UPDATE or DELETE rows.
5. **Soft deletes via `status` column** — no hard deletes for business entities (leads, workflows, articles).
6. **Composite indexes on (org_id, …)** — all multi-tenant tables index by `org_id` first for tenant isolation queries.
7. **Encrypted at rest for PII** — `lead` email addresses, `api_keys.key_hash`, integration credentials in KV are encrypted at application layer.

---

## 5 · Migration Sequence & Dependency Map

```
0001–0027  Core Platform  ──────────────────────────────────────┐
                                                                  │
0028  Enterprise Orgs  ──────────────────────────────────────┐   │
      (depends on: users)                                    │   │
                                                             │   │
0029  Workflow Orchestrator  ─────────────────────────────┐  │   │
      (depends on: 0028 orgs, users)                      │  │   │
                                                          │  │   │
0030  Lead Generation & CRM  ─────────────────────────┐  │  │   │
      (depends on: 0028, 0029 workflows, articles)     │  │  │   │
                                                       │  │  │   │
0031  Content Distribution  ──────────────────────┐   │  │  │   │
      (depends on: 0028, 0029, articles)           │   │  │  │   │
                                                   │   │  │  │   │
0032  Newsletters  ────────────────────────────┐   │   │  │  │   │
      (depends on: 0028, 0029 integrations,    │   │   │  │  │   │
       0030 leads, articles)                   │   │   │  │  │   │
                                               │   │   │  │  │   │
0033  Analytics & Funnel  ─────────────────┐   │   │   │  │  │   │
      (depends on: 0028, 0029, 0030)        │   │   │   │  │  │   │
                                            │   │   │   │  │  │   │
0034  Courses & Learning  ──────────────┐   │   │   │   │  │  │   │
      (depends on: users, articles,     │   │   │   │   │  │  │   │
       membership tiers from 0027)      │   │   │   │   │  │  │   │
                                        │   │   │   │   │  │  │   │
0035  Community & Marketplace ──────┐   │   │   │   │   │  │  │   │
      (depends on: 0028, 0029, 0034) │   │   │   │   │   │  │  │   │
                                    └───┴───┴───┴───┴──┴──┘  │   │
                                                              └───┘
```

---

## 6 · n8n-like Workflow Engine — Data Flow

```
TRIGGER                NODE EXECUTION          LEAD/CONTENT ROUTING
───────               ─────────────────       ──────────────────────
article_published  →  workflow_runs (D1)   →  lead_capture_forms
lead_captured      →  workflow_run_steps   →  leads (D1)
form_submitted     →  WorkflowRunDO (DO)   →  lead_pipeline_entries
webhook_inbound    →    │                  →  email_sequence_enrollments
schedule_cron      →    │                  →  content_distribution_jobs
                        │                  →  newsletter_subscribers
                        │                  →  analytics_events
                        ▼
                   Integration Actions:
                   - send_email         → via ESP (KV credentials)
                   - post_webhook       → HTTP POST to external CRM
                   - push_to_crm        → HubSpot/Salesforce connector
                   - post_social        → distribution_channels
                   - notify_team        → notifications (D1)
```

---

## 7 · End-to-End Pipeline Walkthrough: Keywords → Facebook Ads with HITL + Lead Approval

This section traces exactly how the DB components from migrations 0028–0036 serve a real enterprise use case:

> **Goal:** Every time I publish an article, automatically extract keywords, let my editor review and edit them, push to Facebook Ads, show me the projected cost, and only do all of this after my lead has approved the workflow itself.

### Step 0 — Build the pipeline (drag and drop)

The user opens the Workflow Builder canvas. Each node dragged onto the canvas creates a row in `workflow_nodes` (D1). Edges between nodes create rows in `workflow_edges` (D1). The full serialized DAG (positions, node configs, edge metadata) is written as a JSON blob to Cloudflare KV under key `workflow_def:{workflow_id}:{version}`. The D1 `workflow_versions` table records the version pointer.

```
CANVAS SAVES → workflow_nodes (position, type, display_config)
             → workflow_edges (source_node_id → target_node_id)
             → workflow_versions (definition JSON blob → KV)
             → workflows.definition_version incremented
```

**Scope** — the user sets `workflows.scope_type = 'all_author_content'` so the workflow fires automatically on every article they publish. No per-article manual trigger needed.

---

### Step 1 — Lead approval of the workflow definition

The user submits the workflow for approval. This creates a row in `workflow_approvals` with `status='pending'` and sets `workflows.approval_status='pending_approval'`.

The lead sees the pending request in their admin queue (query: `SELECT * FROM workflow_approvals WHERE assigned_to = ? AND status = 'pending'`). They review the DAG definition (fetched from KV), write a `review_note`, and approve:

```sql
UPDATE workflow_approvals
   SET status='approved', reviewed_by=lead_user_id, reviewed_at=datetime('now'), review_note='LGTM'
 WHERE id = approval_id;

UPDATE workflows
   SET approval_status='approved', approved_by=lead_user_id, approved_at=datetime('now'), status='active'
 WHERE id = workflow_id;
```

**Once `status='active'` + `approval_status='approved'`, the workflow is live.** Only now will it auto-trigger.

---

### Step 2 — Trigger fires on article publish

`article_published` event → backend Worker checks `workflows` table:

```sql
SELECT * FROM workflows
 WHERE trigger_type = 'trigger.article_published'
   AND status = 'active'
   AND approval_status = 'approved'
   AND (
     scope_type = 'all_author_content' AND owner_id = :author_id
     OR scope_type = 'org_wide'        AND org_id   = :org_id
     OR scope_type = 'tagged_content'  -- further filter by scope_filter JSON
   );
```

For each matching workflow, the Worker spawns a `WorkflowRunDO` (Durable Object) and writes a `workflow_runs` row with `status='running'` and `trigger_payload = {article_id, title, author_id, ...}`.

---

### Step 3 — extract_keywords node executes

The DO advances to the `action.extract_keywords` node. It calls CF Workers AI (or the configured model). On completion:

- `workflow_run_steps` row: `status='success'`, `output_data = {keywords: [{term:"...",score:0.9}, ...]}`
- `workflow_run_costs` row: `cost_model='per_token'`, `units_consumed=850` (tokens used), `cost_microcents=0` (free with CF Workers AI)

---

### Step 4 — human_review node PAUSES execution

The DO hits the `action.human_review` node. It:

1. Inserts a row into `workflow_human_tasks`:
   ```
   status       = 'pending'
   task_title   = 'Review keywords for: {article.title}'
   input_data   = {keywords: [{term:"SaaS marketing", score:0.9}, ...]}
   editable_data = {keywords: [...]}  ← reviewer can modify this
   assigned_to  = editor_user_id      ← from node config
   deadline_at  = NOW + 48h
   ```
2. Sets `workflow_runs.waiting_for_task_id = task_id`
3. Sets a DO Alarm for 48 hours (auto-timeout)
4. **Hibernates** (zero cost while waiting)

The editor logs in and sees the task in their inbox:
```sql
SELECT * FROM workflow_human_tasks
 WHERE assigned_to = :user_id AND status = 'pending'
 ORDER BY priority DESC, deadline_at ASC;
```

Editor opens the task, sees the keyword list, removes "generic term", adds "B2B SaaS lead gen", clicks **Submit**.

The Worker:
```sql
UPDATE workflow_human_tasks
   SET status='completed', decision='modified',
       reviewer_id=editor_id, completed_at=datetime('now'),
       output_data='{"keywords":["B2B SaaS lead gen","content marketing","pipeline"]}'
 WHERE id = task_id;

UPDATE workflow_runs SET waiting_for_task_id = NULL WHERE id = run_id;
```

Then calls `DO.resume(run_id, output_data)`. The DO wakes from hibernation and injects the edited keywords into the run context.

---

### Step 5 — keyword_filter transform

Pure compute node. Deduplicates, ranks, applies blocklist from node config. No external API call, no cost row written.

---

### Step 6 — facebook_ads_estimate_cost node

Calls Facebook Marketing API with `{targeting_keywords, budget_daily_cents, duration_days}`.

- `workflow_run_steps.output_data = {estimated_total_spend_cents: 4200, cpc_estimate_cents: 85, estimated_reach_min: 12000}`
- `workflow_run_costs` row: `cost_model='per_execution'`, `cost_microcents=0` (read call, no spend)

---

### Step 7 — condition.cost_within_budget branches

Node config: `budget_cap_cents = 5000`. Estimate was 4200 ≤ 5000 → **YES branch** taken.

If NO branch: `action.notify_team` fires and run ends here. Cost alert logged.

---

### Step 8 — facebook_ads_create node

Calls Facebook Marketing API, creates campaign. On success:

- `workflow_run_steps.output_data = {campaign_id:"1234", status:"ACTIVE", budget_daily_cents:600}`
- `workflow_run_costs` row: `cost_model='actual'`, `cost_actual_microcents=4200000` (= USD 4.20 actual committed spend), `external_ref='fb_campaign_1234'`
- `workflow_cost_summary` updated asynchronously

---

### Step 9 — notify_team node

Sends in-app notification to article author:
> "✓ Facebook campaign live for _'What is B2B SaaS Lead Gen?'_ — estimated reach 12,000–18,000, daily budget $6.00, total committed $42.00."

---

### Step 10 — Run completes

DO writes final state:
```sql
UPDATE workflow_runs
   SET status='success', finished_at=datetime('now'), duration_ms=3200,
       steps_total=7, steps_succeeded=7, final_context='{"campaign_id":"1234",...}'
 WHERE id = run_id;

UPDATE workflows
   SET total_runs = total_runs+1, success_runs = success_runs+1,
       last_run_at = datetime('now'), last_run_status='success'
 WHERE id = workflow_id;
```

Cost rollup job updates `org_cost_monthly_rollup` for the current month.

---

### Full table map for this pipeline

```
workflow built by user
  workflows                    (ownership, scope, approval_status)
  workflow_nodes               (one row per canvas node)
  workflow_edges               (connections between nodes)
  workflow_versions            (DAG snapshot → also in KV)
  KV: workflow_def:{id}:{v}   (full JSON graph blob)

lead approves workflow
  workflow_approvals           (pending → approved, review_note)
  workflows.approval_status    (draft → pending_approval → approved)

article published → workflow triggers
  workflow_runs                (run record, trigger_payload)
  Durable Object               (live state machine)

extract_keywords node
  workflow_run_steps           (output: keyword list)
  workflow_run_costs           (0 cost if CF AI)

human_review node PAUSES
  workflow_human_tasks         (task assigned to editor)
  workflow_runs.waiting_for_task_id

reviewer edits keywords
  workflow_human_tasks         (output_data: edited list, decision='modified')
  Durable Object resumes

facebook_ads_estimate_cost
  workflow_run_steps           (estimated_total_spend_cents)
  workflow_run_costs           (cost_model='per_execution', 0 for read)

condition.cost_within_budget
  workflow_run_steps           (branching decision logged)

facebook_ads_create
  workflow_run_steps           (campaign_id, status)
  workflow_run_costs           (cost_model='actual', actual_microcents)
  workflow_cost_summary        (aggregate updated)
  org_cost_monthly_rollup      (monthly spend updated)

notify_team
  notifications                (in-app, links to campaign)

run finishes
  workflow_runs                (status='success', duration_ms)
  workflows                    (total_runs++, last_run_at)
```

---

## 7b · workflow_runs State Machine

```
            article_published
                   │
                   ▼
              ┌─────────┐
              │ running │◄────────── DO.resume(task_id, outcome)
              └────┬────┘                    ▲
                   │                         │
       human_review node hit                 │ reviewer submits
                   │                         │
                   ▼                         │
         ┌──────────────────┐    ┌──────────────────┐
         │ waiting_for_human│───►│  human_task:      │
         │ (DO hibernates)  │    │  status=completed │
         └──────────────────┘    └──────────────────┘
                   │
         timeout alarm fires
                   │
                   ▼
           ┌─────────────┐
           │  timed_out  │   (if on_timeout='fail')
           └─────────────┘

         Normal completion:
            running → success
            running → failed
            running → cancelled (manual)
```

---

## 7c · Workflow Approval State Machine

```
       author saves draft
              │
              ▼
         ┌─────────────────┐
         │ approval_status  │
         │   = 'draft'      │
         │ status = 'draft' │
         └────────┬─────────┘
                  │ submit for approval
                  ▼
    ┌──────────────────────────┐
    │ approval_status          │
    │   = 'pending_approval'   │────────────► lead reviews
    └──────────────────────────┘                   │
                  ▲                         ┌──────┴──────┐
                  │ changes requested       │              │
            ┌─────┴────────────────┐   approved      rejected
            │ approval_status      │       │              │
            │  = 'changes_         │       ▼              ▼
            │    requested'        │  ┌──────────┐  ┌──────────┐
            └──────────────────────┘  │ approved │  │ rejected │
                                      │ status=  │  │ status=  │
                                      │ 'active' │  │ 'draft'  │
                                      └──────────┘  └──────────┘
```

---

## 8 · Table Count by Domain

| Migration | Tables Added | Cumulative |
|---|---|---|
| 0001–0027 (existing) | ~30 | 30 |
| 0028 Enterprise Orgs | 7 | 37 |
| 0029 Workflow Orchestrator | 9 | 46 |
| 0030 Lead Gen & CRM | 10 | 56 |
| 0031 Content Distribution | 6 | 62 |
| 0032 Newsletters | 6 | 68 |
| 0033 Analytics & Funnel | 9 | 77 |
| 0034 Courses | 8 | 85 |
| 0035 Community & Marketplace | 9 | 94 |
| 0036 HITL + Approval + Costs | 6 new + ALTER workflows + new node types | **100** |
| 0037 Generic Connector Framework | 10 new + 4 ALTER TABLE | **110** |

**Migration 0036 additions:**
- `workflow_human_tasks` — HITL pause queue (GAP-1)
- `workflow_approvals` — lead approval requests (GAP-2)
- `workflow_run_costs` — per-step cost entries (GAP-3)
- `workflow_node_cost_rates` — per-node cost rate config (GAP-3)
- `workflow_cost_summary` — per-workflow aggregate (GAP-3)
- `org_cost_monthly_rollup` — monthly billing rollup (GAP-3)
- New columns on `workflows`: `approval_status`, `approval_required`, `approved_by`, `approved_at`, `approval_note`, `scope_type`, `scope_filter`
- New column on `workflow_runs`: `waiting_for_task_id`
- 9 new node types seeded: `extract_keywords`, `human_review`, `keyword_filter`, `keywords_changed`, `facebook_ads_estimate_cost`, `cost_within_budget`, `facebook_ads_create`, `facebook_ads_boost_post`, `google_ads_create`

---

## 8 · What You Do NOT Need a Separate NoSQL DB For

Common reasons teams reach for MongoDB/DynamoDB, and why D1+KV covers them:

| "Need" | Solution in Zenos architecture |
|---|---|
| Variable-shape document storage | `TEXT` JSON columns in D1 + `json_extract()` |
| Workflow DAG graph storage | KV blobs (no FK traversal needed at query time) |
| High-volume event writes | Cloudflare Analytics Engine (free, unlimited) |
| Encrypted secrets store | KV + Worker Secrets (zero cost) |
| Real-time stateful execution | Durable Objects Alarms (zero cost at low volume) |
| Session store | KV with TTL (already in use) |

**Bottom line:** A full MongoDB Atlas cluster (~$57/mo minimum) is unnecessary. The Cloudflare-native stack covers all NoSQL requirements at **zero incremental cost** up to significant scale.

---

## 9 · Generic Connector Framework (Migration 0037)

### 9.1 Why This Matters

Migration 0036 added Facebook Ads and Google Ads as hard-coded **node types**.
That approach breaks the moment you want Instagram, X, LinkedIn, Google Maps, Slack,
HubSpot, a custom MCP server, or a proprietary internal API — every new platform
would require a schema migration.

Migration 0037 replaces that with a **registry-driven architecture** where **any**
external system can be connected without touching the DB schema again.

---

### 9.2 Core Objects and Relationships

```
connector_definitions          ← What a connector IS (driver / template)
       │
       ├── connector_actions   ← Individual operations it exposes
       │     e.g. instagram.post_image, google_maps.geocode, mcp_server.call_tool
       │
       ├── connector_oauth_providers  ← OAuth 2.0 endpoints (one per platform)
       │
       └── connector_instances (per org, per connection)
                 │
                 ├── connector_oauth_tokens  ← OAuth tokens (references to KV)
                 │
                 └──▷ workflow_node_connector_bindings
                           │
                           ├── workflow_nodes (the canvas node)
                           └── connector_actions (which operation to call)
```

**Special subtypes of `connector_definitions`:**

| source_type | Backed by |
|---|---|
| `builtin` | Hard-coded Zenos SDK connector |
| `mcp_server` | Entry in `mcp_server_registry` |
| `custom_openapi` | OpenAPI 3.x spec URL; actions auto-generated from endpoints |
| `custom_agent` | Entry in `custom_agents` |
| `custom_http` | Raw HTTP; user defines each request in `connector_actions` |
| `custom_webhook` | Inbound (trigger) or outbound (action) HTTP hook |
| `community` | Published via `connector_marketplace_listings` |

---

### 9.3 Auth Methods Supported

| auth_method | Used For |
|---|---|
| `none` | Public APIs (e.g. Cloudflare Workers AI) |
| `api_key` | Google Maps, OpenAI, Anthropic, Airtable, SendGrid |
| `oauth2` | Instagram, X, LinkedIn, Facebook Ads, Slack, HubSpot, Salesforce, GitHub, … |
| `oauth2_pkce` | Any OAuth 2.0 platform requiring PKCE (X, Google with PKCE, Shopify) |
| `bearer` | Static token (Discord Bot, internal services) |
| `basic` | Legacy APIs (HTTP Basic) |
| `jwt` | JWT-per-request signing |
| `hmac` | HMAC request signing (Webhooks, Stripe events) |
| `mcp_sse` | MCP over Server-Sent Events |
| `mcp_stdio` | MCP over stdin/stdout (via Worker proxy) |
| `mcp_http` | MCP over HTTP Streaming |
| `custom` | Fully custom (defined in `auth_config_schema`) |

**Credentials are NEVER stored in D1.** The flow is:
1. User enters credentials on the settings screen
2. Worker encrypts with AES-256-GCM (key from `wrangler secret`)
3. Ciphertext stored in KV at key `connector_creds:{connector_instance_id}`
4. `connector_instances.kv_secret_key` column stores only the KV key reference

---

### 9.4 How a Canvas Node Calls Any Connector

When the Durable Object executor reaches a canvas node:

```
1. Look up workflow_node_connector_bindings WHERE workflow_node_id = <this node>
2. Load connector_instances using connector_instance_id
   → read kv_secret_key to fetch encrypted credentials from KV
   → decrypt credentials with Worker Secret key
3. Load connector_actions using connector_action_id
   → get input_schema, output_schema, cost_model
4. Resolve param_bindings to build the action input
   e.g. {"caption": "{{context.article_title}} — check it out!"}
5. Execute the connector action:
   - For builtin connectors → Zenos SDK call
   - For custom_http / custom_webhook → outbound fetch()
   - For mcp_server → POST to MCP endpoint (tools/call JSON-RPC)
   - For custom_agent → POST to agent endpoint or run inline
6. Write output to workflow run context in KV
   → using output_bindings to name the variables
7. Write step cost to workflow_run_costs (if rate_microcents > 0)
```

**The executor doesn't need to know what platform it's calling — just execute one
interface through `workflow_node_connector_bindings`.**

---

### 9.5 MCP Server Registration Flow

```
User registers MCP server
         │
         ▼
INSERT mcp_server_registry (name, transport, endpoint_url, auth_method, kv_secret_key)
         │
         ▼
Worker calls GET {endpoint_url}/mcp (initialize + tools/list)
         │
         ▼
UPDATE mcp_server_registry SET tools_schema = <discovered tools JSON>
         │
         ▼
Auto-INSERT connector_definitions (source_type='mcp_server', id='mcp:{server_name}')
         │
         ▼
Auto-INSERT connector_actions for each discovered tool
   id = 'mcp:{server_name}.{tool_name}'
   input_schema = tool.inputSchema from MCP response
   node_category = 'action'
         │
         ▼
New action nodes appear in the canvas palette immediately — no deploy needed
```

**KV key patterns for MCP:**
- `connector_creds:{connector_instance_id}` — encrypted bearer token for the endpoint
- `mcp_capabilities:{mcp_server_id}` — cached full capabilities JSON (TTL: 1h)

---

### 9.6 Custom AI Agent Registration Flow

```
User creates custom agent
         │
         ▼
INSERT custom_agents (name, agent_type, model_config, ...)
   agent_type options:
     - llm_chain     → single LLM call with system prompt
     - rag_agent     → LLM + vector retrieval (knowledge_base_id)
     - tool_use_agent → LLM with tool-calling loop
     - mcp_agent     → agent that calls MCP server tools
     - custom_http   → external agent API endpoint
         │
         ▼
Worker auto-INSERTs connector_definitions (source_type='custom_agent')
Worker auto-INSERTs connector_actions (id='{agent_slug}.run')
   input_schema  = custom_agents.input_schema
   output_schema = custom_agents.output_schema
         │
         ▼
Agent node appears in canvas palette
User drags it onto canvas → creates workflow_nodes row
User configures param_bindings → creates workflow_node_connector_bindings row
```

---

### 9.7 Adding ANY New Platform (Zero Schema Change)

To integrate, say, **TikTok Ads** (which wasn't seeded until 0037):

```sql
-- No DDL changes needed. Just:
INSERT INTO connector_definitions (id, name, slug, source_type, auth_method, category, ...)
VALUES ('tiktok_ads', 'TikTok Ads', 'tiktok_ads', 'builtin', 'oauth2', 'advertising', ...);

INSERT INTO connector_actions (id, connector_definition_id, action_key, name, ...)
VALUES ('tiktok_ads.create_campaign', 'tiktok_ads', 'create_campaign', 'Create Campaign', ...);

INSERT INTO connector_oauth_providers (id, connector_definition_id, authorization_url, ...)
VALUES ('oauth_tiktok_ads', 'tiktok_ads', 'https://ads.tiktok.com/marketing_api/auth', ...);
```

That's it. The canvas, executor, and settings UI all discover these rows dynamically.

---

### 9.8 Seeded Connectors in Migration 0037

| Category | Connectors |
|---|---|
| Social Media | Instagram, X (Twitter), LinkedIn, Facebook Pages, TikTok, Pinterest, YouTube |
| Advertising | Facebook Ads, Google Ads, TikTok Ads |
| Maps & Location | Google Maps |
| Email Marketing | Mailchimp, SendGrid, Klaviyo |
| CRM | HubSpot, Salesforce, Pipedrive |
| Communication | Slack, Discord, Microsoft Teams, WhatsApp Business |
| AI | OpenAI, Anthropic Claude, Cloudflare Workers AI |
| Analytics | Google Analytics 4, Mixpanel |
| Productivity | Notion, Airtable, Google Sheets |
| E-commerce | Shopify, Stripe |
| Developer Tools | GitHub, Jira |
| Generic / Custom | Custom Webhook, Custom HTTP, Custom OpenAPI, MCP Server, Custom AI Agent |

**37 connector definitions + 50+ connector actions + 15 OAuth provider configs seeded.**

---

### 9.9 KV Key Patterns (updated for 0037)

| Pattern | Contents |
|---|---|
| `connector_creds:{connector_instance_id}` | Encrypted auth credentials JSON (API keys, bearer tokens, HMAC secrets) |
| `oauth_token:{connector_oauth_token_id}:access` | OAuth access token (encrypted) |
| `oauth_token:{connector_oauth_token_id}:refresh` | OAuth refresh token (encrypted) |
| `mcp_capabilities:{mcp_server_id}` | Cached MCP server capabilities JSON (TTL: 1h) |
| `connector_openapi_spec:{connector_instance_id}` | Cached OpenAPI spec for custom_openapi connectors (TTL: 24h) |
