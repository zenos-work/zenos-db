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
    }

    tags {
        TEXT id PK
        TEXT name
        TEXT slug
        TEXT created_at
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
    users ||--o{ comments : "writes"
    users ||--o{ bookmarks : "saves"
    users ||--o{ likes : "likes"
    users ||--o{ notifications : "receives"
    users ||--o{ notifications : "triggers"
    users ||--o{ follows : "follows"
    users ||--o{ follows : "followed by"
    users ||--|| user_preferences : "has"

    articles ||--o{ article_tags : "tagged with"
    articles ||--o{ comments : "has"
    articles ||--o{ bookmarks : "bookmarked in"
    articles ||--o{ likes : "liked in"
    articles ||--o{ notifications : "referenced in"

    tags ||--o{ article_tags : "applied to"

    comments ||--o{ comments : "replies to"
    comments ||--o{ notifications : "referenced in"
```

## Schema Notes

| Table | Purpose | Key Constraint |
|---|---|---|
| `users` | Auth + profiles | `role` CHECK: SUPERADMIN\|APPROVER\|AUTHOR\|READER |
| `articles` | Content store | `status` CHECK: DRAFT→SUBMITTED→APPROVED/REJECTED→PUBLISHED→ARCHIVED |
| `tags` | Taxonomy | `name` + `slug` UNIQUE |
| `article_tags` | Article↔Tag join | Composite PK `(article_id, tag_id)` |
| `comments` | Threaded comments | `parent_id` self-references for replies |
| `bookmarks` | User saved articles | Composite PK `(user_id, article_id)` |
| `likes` | Article likes | Composite PK `(user_id, article_id)` |
| `follows` | User follows | CHECK `follower_id != following_id` |
| `notifications` | Activity feed | `actor_id` nullable for system notifications |
| `user_preferences` | Topics + settings | 1:1 with users, `theme` CHECK: light\|dark\|system |
| `_migrations` | Migration tracker | Applied automatically by migrate.sh |

## Article Status Lifecycle
```
DRAFT → SUBMITTED → APPROVED → PUBLISHED → ARCHIVED
                 ↘ REJECTED → DRAFT (re-edit and resubmit)
```
