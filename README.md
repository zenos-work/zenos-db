# zenos-db
Cloudflare D1 migrations &amp; seed scripts




## Entity Relationship Diagram
```mermaid
erDiagram
    users {
        TEXT id PK
        TEXT email
        TEXT name
        TEXT avatar_url
        TEXT google_id
        TEXT role
        INTEGER is_active
        TEXT terms_accepted_at
        TEXT created_at
        TEXT updated_at
    }

    articles {
        TEXT id PK
        TEXT author_id FK
        TEXT approved_by FK
        TEXT title
        TEXT slug
        TEXT subtitle
        TEXT content_type
        TEXT content
        TEXT cover_image_url
        INTEGER read_time_minutes
        TEXT status
        TEXT rejection_note
        INTEGER views_count
        INTEGER likes_count
        INTEGER comments_count
        INTEGER is_featured
        TEXT published_at
        TEXT created_at
        TEXT updated_at
        TEXT last_verified_at
        TEXT expires_at
        TEXT moderation_state
        TEXT moderation_note
        TEXT seo_title
        TEXT seo_description
        TEXT canonical_url
        TEXT og_image_url
        TEXT seo_schema_type
    }

    tags {
        TEXT id PK
        TEXT name
        TEXT slug
        TEXT tag_type
        TEXT created_at
    }

    content_types {
        TEXT id PK
        TEXT slug
        TEXT name
        TEXT description
        INTEGER is_active
        INTEGER is_system
        INTEGER sort_order
        TEXT created_by FK
        TEXT created_at
        TEXT updated_at
    }

    article_tags {
        TEXT article_id FK
        TEXT tag_id FK
    }

    comments {
        TEXT id PK
        TEXT article_id FK
        TEXT author_id FK
        TEXT parent_id FK
        TEXT content
        INTEGER is_deleted
        INTEGER is_hidden
        TEXT moderation_reason
        TEXT moderated_by FK
        TEXT moderated_at
        INTEGER flag_count
        TEXT created_at
        TEXT updated_at
    }

    bookmarks {
        TEXT user_id FK
        TEXT article_id FK
        TEXT created_at
    }

    likes {
        TEXT user_id FK
        TEXT article_id FK
        TEXT created_at
    }

    follows {
        TEXT follower_id FK
        TEXT following_id FK
        TEXT created_at
    }

    notifications {
        TEXT id PK
        TEXT user_id FK
        TEXT actor_id FK
        TEXT type
        TEXT article_id FK
        TEXT comment_id FK
        TEXT message
        INTEGER is_read
        TEXT created_at
    }

    article_events {
        TEXT id PK
        TEXT article_id FK
        TEXT actor_user_id FK
        TEXT event_type
        INTEGER event_value
        TEXT event_source
        TEXT metadata_json
        TEXT created_at
    }

    article_success_hourly {
        TEXT article_id FK
        TEXT bucket_hour
        INTEGER views_count
        INTEGER likes_count
        INTEGER comments_count
        INTEGER outcome_events_count
        INTEGER outcome_tag_count
        REAL engagement_score
        REAL success_rate
        TEXT created_at
        TEXT updated_at
    }

    user_preferences {
        TEXT user_id FK
        TEXT topics
        TEXT theme
        INTEGER notifications_enabled
        TEXT created_at
        TEXT updated_at
    }

    _migrations {
        INTEGER id PK
        TEXT filename
        TEXT applied_at
    }

    users ||--o{ articles : "authors"
    users ||--o{ articles : "approves"
    users ||--o{ content_types : "creates"
    users ||--o{ comments : "writes"
    users ||--o{ bookmarks : "saves"
    users ||--o{ likes : "likes"
    users ||--o{ notifications : "receives"
    users ||--o{ notifications : "triggers"
    users ||--o{ follows : "follows"
    users ||--o{ follows : "followed by"
    users ||--|| user_preferences : "has"

    content_types ||--o{ articles : "classifies by slug"

    articles ||--o{ article_tags : "tagged with"
    articles ||--o{ comments : "has"
    articles ||--o{ bookmarks : "bookmarked in"
    articles ||--o{ likes : "liked in"
    articles ||--o{ notifications : "referenced in"
    articles ||--o{ article_events : "captures interactions for"
    articles ||--o{ article_success_hourly : "aggregated success snapshots"

    tags ||--o{ article_tags : "applied to"

    comments ||--o{ comments : "replies to"
    comments ||--o{ notifications : "referenced in"
```

## Schema Notes

Default content bootstrap:
- Migration `0016_seed_system_default_articles.sql` inserts a `Zenos System` author plus published default stories for Tour, How-to, Software Writing, and Spotlight surfaces.
- These are real articles stored in D1 so landing pages, feeds, search, and article routes can render actual content in empty environments.

| Table | Purpose | Key Constraint |
|---|---|---|
| `users` | Auth + profiles | `role` CHECK: SUPERADMIN\|APPROVER\|AUTHOR\|READER |
| `articles` | Content store | `status` CHECK: DRAFT→SUBMITTED→APPROVED/REJECTED→PUBLISHED→ARCHIVED; includes moderation + SEO metadata |
| `content_types` | Dynamic article taxonomy | Runtime-managed by SUPERADMIN; `slug` UNIQUE and consumed by `articles.content_type` |
| `tags` | Taxonomy | `name` + `slug` UNIQUE; `tag_type` CHECK: topic\|outcome |
| `article_tags` | Article↔Tag join | Composite PK `(article_id, tag_id)` |
| `comments` | Threaded comments | `parent_id` self-references for replies; moderation flags support abuse handling |
| `bookmarks` | User saved articles | Composite PK `(user_id, article_id)` |
| `likes` | Article likes | Composite PK `(user_id, article_id)` |
| `follows` | User follows | CHECK `follower_id != following_id` |
| `notifications` | Activity feed | `actor_id` nullable for system notifications |
| `article_events` | SR-011 lightweight event stream | `event_type` CHECK: VIEW\|LIKE\|COMMENT\|OUTCOME |
| `article_success_hourly` | SR-011 hourly success aggregates | Composite PK `(article_id, bucket_hour)` |
| `user_preferences` | Topics + settings | 1:1 with users, `theme` CHECK: light\|dark\|system |
| `_migrations` | Migration tracker | Applied automatically by migrate.sh |

## SR-011 Analytics Path

- The backend records lightweight interaction events into `article_events` during read and engagement actions.
- A scheduled Cloudflare Worker Cron trigger runs hourly aggregation into `article_success_hourly`.
- Aggregates combine event counts and outcome-tag coverage into an `engagement_score` and capped `success_rate`.

## Article Status Lifecycle
```
DRAFT → SUBMITTED → APPROVED → PUBLISHED → ARCHIVED
                 ↘ REJECTED → DRAFT (re-edit and resubmit)
```
