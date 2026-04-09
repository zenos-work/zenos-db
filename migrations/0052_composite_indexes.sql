-- Migration: 0052_composite_indexes
--
-- Adds missing composite indexes on existing tables to optimise the most
-- common query patterns identified in the API handlers and frontend screens.
-- These are additive (no schema changes) — safe to apply at any time.

-- ═══════════════════════════════════════════════════════════════════════════════
-- ARTICLES
-- ═══════════════════════════════════════════════════════════════════════════════
-- Feed query: published articles by author, newest first
CREATE INDEX IF NOT EXISTS idx_articles_author_status_pub
  ON articles(author_id, status, published_at DESC);

-- Org-scoped article listing
CREATE INDEX IF NOT EXISTS idx_articles_org_status
  ON articles(org_id, status, published_at DESC);

-- Content-type filtering (category pages)
CREATE INDEX IF NOT EXISTS idx_articles_content_type_status
  ON articles(content_type, status, published_at DESC);

-- Security-level filtering for workflow content binding
CREATE INDEX IF NOT EXISTS idx_articles_org_security
  ON articles(org_id, security_level);

-- Scheduled publish queue (Workers cron picks up these)
CREATE INDEX IF NOT EXISTS idx_articles_scheduled
  ON articles(status, scheduled_publish_date)
  WHERE status = 'scheduled';

-- ═══════════════════════════════════════════════════════════════════════════════
-- USER READING HISTORY
-- ═══════════════════════════════════════════════════════════════════════════════
-- "Continue reading" query
CREATE INDEX IF NOT EXISTS idx_reading_history_user_progress
  ON user_reading_history(user_id, progress, last_read_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════════
-- NEWSLETTERS
-- ═══════════════════════════════════════════════════════════════════════════════
-- Subscriber lookup by email + status (double-opt-in flow)
CREATE INDEX IF NOT EXISTS idx_newsletter_subs_email_status
  ON newsletter_subscriptions(email, status);

-- All confirmed subscribers for a newsletter (send job)
CREATE INDEX IF NOT EXISTS idx_newsletter_subs_list_status
  ON newsletter_subscriptions(newsletter_id, status)
  WHERE status = 'confirmed';

-- Newsletter issue listing
CREATE INDEX IF NOT EXISTS idx_newsletter_issues_nl_status
  ON newsletter_issues(newsletter_id, status, scheduled_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════════
-- COMMENTS
-- ═══════════════════════════════════════════════════════════════════════════════
-- Thread listing for an article, top-level first
CREATE INDEX IF NOT EXISTS idx_comments_article_parent
  ON comments(article_id, parent_id, created_at ASC);

-- Flagged comments moderation queue
CREATE INDEX IF NOT EXISTS idx_comments_flagged
  ON comments(flag_count DESC, created_at DESC)
  WHERE flag_count > 0;

-- ═══════════════════════════════════════════════════════════════════════════════
-- REACTIONS
-- ═══════════════════════════════════════════════════════════════════════════════
-- "Did current user react?" check
CREATE INDEX IF NOT EXISTS idx_reactions_user_target
  ON reactions(user_id, target_type, target_id);

-- Aggregate reactions per article
CREATE INDEX IF NOT EXISTS idx_reactions_target_type
  ON reactions(target_type, target_id, reaction_type);

-- ═══════════════════════════════════════════════════════════════════════════════
-- FOLLOWS
-- ═══════════════════════════════════════════════════════════════════════════════
-- Followers list (who follows X?)
CREATE INDEX IF NOT EXISTS idx_follows_following_type
  ON follows(following_id, following_type, created_at DESC);

-- Following list (who does X follow?)
CREATE INDEX IF NOT EXISTS idx_follows_follower_type
  ON follows(follower_id, following_type, created_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════════
-- NOTIFICATIONS
-- ═══════════════════════════════════════════════════════════════════════════════
-- Unread badge count
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON notifications(user_id, is_read, created_at DESC)
  WHERE is_read = 0;

-- Notification grouping
CREATE INDEX IF NOT EXISTS idx_notifications_group_key
  ON notifications(group_key, created_at DESC)
  WHERE group_key IS NOT NULL;

-- ═══════════════════════════════════════════════════════════════════════════════
-- WORKFLOW RUNS
-- ═══════════════════════════════════════════════════════════════════════════════
-- Active runs per workflow (dashboard gauge)
CREATE INDEX IF NOT EXISTS idx_wf_runs_workflow_status
  ON workflow_runs(workflow_id, status, created_at DESC);

-- Org-level run history
CREATE INDEX IF NOT EXISTS idx_wf_runs_org_created
  ON workflow_runs(org_id, created_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════════
-- WORKFLOW HUMAN TASKS
-- ═══════════════════════════════════════════════════════════════════════════════
-- Assignee task inbox
CREATE INDEX IF NOT EXISTS idx_wf_htasks_assignee_status
  ON workflow_human_tasks(assigned_to, status, created_at DESC)
  WHERE status IN ('pending','in_progress');

-- ═══════════════════════════════════════════════════════════════════════════════
-- WORKFLOW APPROVALS
-- ═══════════════════════════════════════════════════════════════════════════════
-- Pending approvals for a user
CREATE INDEX IF NOT EXISTS idx_wf_approvals_approver_status
  ON workflow_approvals(approver_id, status)
  WHERE status = 'pending';

-- ═══════════════════════════════════════════════════════════════════════════════
-- CONTENT REPORTS (from 0043)
-- ═══════════════════════════════════════════════════════════════════════════════
-- Moderation queue: pending reports, oldest first
CREATE INDEX IF NOT EXISTS idx_content_reports_modqueue
  ON content_reports(status, created_at ASC)
  WHERE status IN ('pending','under_review');

-- ═══════════════════════════════════════════════════════════════════════════════
-- AUTHOR EARNINGS / PAYOUTS (from 0047)
-- ═══════════════════════════════════════════════════════════════════════════════
-- Monthly earnings report
CREATE INDEX IF NOT EXISTS idx_author_earnings_author_period
  ON author_earnings(author_id, period_start DESC);

-- Payout status dashboard
CREATE INDEX IF NOT EXISTS idx_author_payouts_author_status
  ON author_payouts(author_id, status, requested_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════════
-- ORG MEMBERS
-- ═══════════════════════════════════════════════════════════════════════════════
-- All members of an org with role
CREATE INDEX IF NOT EXISTS idx_org_members_org_role
  ON org_members(org_id, org_role);

-- User's org memberships
CREATE INDEX IF NOT EXISTS idx_org_members_user_id
  ON org_members(user_id, joined_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════════
-- MARKETPLACE
-- ═══════════════════════════════════════════════════════════════════════════════
-- Marketplace browse: category + active items
CREATE INDEX IF NOT EXISTS idx_marketplace_category_status
  ON marketplace_items(category, status, created_at DESC);

-- Seller's listings
CREATE INDEX IF NOT EXISTS idx_marketplace_seller
  ON marketplace_items(seller_id, status);

-- ═══════════════════════════════════════════════════════════════════════════════
-- BOOKMARKS
-- ═══════════════════════════════════════════════════════════════════════════════
-- User's bookmarks, newest first
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_created
  ON bookmarks(user_id, created_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════════
-- TAGS
-- ═══════════════════════════════════════════════════════════════════════════════
-- Tag lookup for article
CREATE INDEX IF NOT EXISTS idx_article_tags_article
  ON article_tags(article_id);

CREATE INDEX IF NOT EXISTS idx_article_tags_tag
  ON article_tags(tag_id);
