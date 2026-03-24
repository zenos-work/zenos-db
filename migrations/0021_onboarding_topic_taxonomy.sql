-- Migration: 0021_onboarding_topic_taxonomy
-- Adds onboarding taxonomy metadata and seeds default category/topic tags.

ALTER TABLE tags ADD COLUMN category_slug TEXT;
ALTER TABLE tags ADD COLUMN is_onboarding_category INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_tags_category_slug ON tags(category_slug);
CREATE INDEX IF NOT EXISTS idx_tags_onboarding_category ON tags(is_onboarding_category);

-- Broad onboarding categories managed by admin workflows.
INSERT OR IGNORE INTO tags (id, name, slug, tag_type, category_slug, is_onboarding_category, created_at) VALUES
    ('tag-onboard-technology', 'Technology', 'technology', 'topic', NULL, 1, datetime('now')),
    ('tag-onboard-programming', 'Programming', 'programming', 'topic', NULL, 1, datetime('now')),
    ('tag-onboard-wellness', 'Wellness', 'wellness', 'topic', NULL, 1, datetime('now')),
    ('tag-onboard-life', 'Life', 'life', 'topic', NULL, 1, datetime('now')),
    ('tag-onboard-society', 'Society', 'society', 'topic', NULL, 1, datetime('now')),
    ('tag-onboard-culture', 'Culture', 'culture', 'topic', NULL, 1, datetime('now')),
    ('tag-onboard-business', 'Business', 'business', 'topic', NULL, 1, datetime('now'));

-- Technology
INSERT OR IGNORE INTO tags (id, name, slug, tag_type, category_slug, is_onboarding_category, created_at) VALUES
    ('tag-onboard-ai', 'AI', 'ai', 'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-artificial-intelligence', 'Artificial Intelligence', 'artificial-intelligence', 'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-cybersecurity', 'Cybersecurity', 'cybersecurity', 'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-aws', 'AWS', 'aws', 'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-llm', 'LLM', 'llm', 'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-chatgpt', 'ChatGPT', 'chatgpt', 'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-ux', 'UX', 'ux', 'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-ux-design', 'UX Design', 'ux-design', 'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-android', 'Android', 'android', 'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-ios', 'iOS', 'ios', 'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-apple', 'Apple', 'apple', 'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-ai-agent', 'AI Agent', 'ai-agent', 'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-future', 'Future', 'future', 'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-tech', 'Tech', 'tech', 'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-kubernetes', 'Kubernetes', 'kubernetes', 'topic', 'technology', 0, datetime('now'));

-- Programming
INSERT OR IGNORE INTO tags (id, name, slug, tag_type, category_slug, is_onboarding_category, created_at) VALUES
    ('tag-onboard-data-science', 'Data Science', 'data-science', 'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-software-development', 'Software Development', 'software-development', 'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-python', 'Python', 'python', 'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-software-engineering', 'Software Engineering', 'software-engineering', 'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-machine-learning', 'Machine Learning', 'machine-learning', 'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-devops', 'DevOps', 'devops', 'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-web-development', 'Web Development', 'web-development', 'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-data-engineering', 'Data Engineering', 'data-engineering', 'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-java', 'Java', 'java', 'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-javascript', 'JavaScript', 'javascript', 'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-flutter', 'Flutter', 'flutter', 'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-deep-learning', 'Deep Learning', 'deep-learning', 'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-react', 'React', 'react', 'topic', 'programming', 0, datetime('now'));

-- Wellness
INSERT OR IGNORE INTO tags (id, name, slug, tag_type, category_slug, is_onboarding_category, created_at) VALUES
    ('tag-onboard-psychology', 'Psychology', 'psychology', 'topic', 'wellness', 0, datetime('now')),
    ('tag-onboard-self-improvement', 'Self Improvement', 'self-improvement', 'topic', 'wellness', 0, datetime('now')),
    ('tag-onboard-mental-health', 'Mental Health', 'mental-health', 'topic', 'wellness', 0, datetime('now')),
    ('tag-onboard-productivity', 'Productivity', 'productivity', 'topic', 'wellness', 0, datetime('now')),
    ('tag-onboard-spirituality', 'Spirituality', 'spirituality', 'topic', 'wellness', 0, datetime('now')),
    ('tag-onboard-personal-growth', 'Personal Growth', 'personal-growth', 'topic', 'wellness', 0, datetime('now')),
    ('tag-onboard-mindfulness', 'Mindfulness', 'mindfulness', 'topic', 'wellness', 0, datetime('now')),
    ('tag-onboard-fitness', 'Fitness', 'fitness', 'topic', 'wellness', 0, datetime('now')),
    ('tag-onboard-personal-development', 'Personal Development', 'personal-development', 'topic', 'wellness', 0, datetime('now')),
    ('tag-onboard-motivation', 'Motivation', 'motivation', 'topic', 'wellness', 0, datetime('now')),
    ('tag-onboard-sports', 'Sports', 'sports', 'topic', 'wellness', 0, datetime('now'));

-- Life
INSERT OR IGNORE INTO tags (id, name, slug, tag_type, category_slug, is_onboarding_category, created_at) VALUES
    ('tag-onboard-relationships', 'Relationships', 'relationships', 'topic', 'life', 0, datetime('now')),
    ('tag-onboard-love', 'Love', 'love', 'topic', 'life', 0, datetime('now')),
    ('tag-onboard-life-lessons', 'Life Lessons', 'life-lessons', 'topic', 'life', 0, datetime('now')),
    ('tag-onboard-health', 'Health', 'health', 'topic', 'life', 0, datetime('now')),
    ('tag-onboard-this-happened-to-me', 'This Happened To Me', 'this-happened-to-me', 'topic', 'life', 0, datetime('now')),
    ('tag-onboard-travel', 'Travel', 'travel', 'topic', 'life', 0, datetime('now')),
    ('tag-onboard-lifestyle', 'Lifestyle', 'lifestyle', 'topic', 'life', 0, datetime('now')),
    ('tag-onboard-family', 'Family', 'family', 'topic', 'life', 0, datetime('now')),
    ('tag-onboard-parenting', 'Parenting', 'parenting', 'topic', 'life', 0, datetime('now')),
    ('tag-onboard-faith', 'Faith', 'faith', 'topic', 'life', 0, datetime('now')),
    ('tag-onboard-healing', 'Healing', 'healing', 'topic', 'life', 0, datetime('now')),
    ('tag-onboard-sexuality', 'Sexuality', 'sexuality', 'topic', 'life', 0, datetime('now'));

-- Society
INSERT OR IGNORE INTO tags (id, name, slug, tag_type, category_slug, is_onboarding_category, created_at) VALUES
    ('tag-onboard-politics', 'Politics', 'politics', 'topic', 'society', 0, datetime('now')),
    ('tag-onboard-women', 'Women', 'women', 'topic', 'society', 0, datetime('now')),
    ('tag-onboard-history', 'History', 'history', 'topic', 'society', 0, datetime('now')),
    ('tag-onboard-news', 'News', 'news', 'topic', 'society', 0, datetime('now')),
    ('tag-onboard-war', 'War', 'war', 'topic', 'society', 0, datetime('now')),
    ('tag-onboard-economics', 'Economics', 'economics', 'topic', 'society', 0, datetime('now')),
    ('tag-onboard-religion', 'Religion', 'religion', 'topic', 'society', 0, datetime('now')),
    ('tag-onboard-christianity', 'Christianity', 'christianity', 'topic', 'society', 0, datetime('now')),
    ('tag-onboard-feminism', 'Feminism', 'feminism', 'topic', 'society', 0, datetime('now')),
    ('tag-onboard-geopolitics', 'Geopolitics', 'geopolitics', 'topic', 'society', 0, datetime('now')),
    ('tag-onboard-world', 'World', 'world', 'topic', 'society', 0, datetime('now')),
    ('tag-onboard-justice', 'Justice', 'justice', 'topic', 'society', 0, datetime('now')),
    ('tag-onboard-equality', 'Equality', 'equality', 'topic', 'society', 0, datetime('now')),
    ('tag-onboard-ukraine-war', 'Ukraine War', 'ukraine-war', 'topic', 'society', 0, datetime('now'));

-- Culture
INSERT OR IGNORE INTO tags (id, name, slug, tag_type, category_slug, is_onboarding_category, created_at) VALUES
    ('tag-onboard-science', 'Science', 'science', 'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-writing', 'Writing', 'writing', 'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-philosophy', 'Philosophy', 'philosophy', 'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-education', 'Education', 'education', 'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-books', 'Books', 'books', 'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-humor', 'Humor', 'humor', 'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-space', 'Space', 'space', 'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-inspiration', 'Inspiration', 'inspiration', 'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-creativity', 'Creativity', 'creativity', 'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-art', 'Art', 'art', 'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-music', 'Music', 'music', 'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-gaming', 'Gaming', 'gaming', 'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-math', 'Math', 'math', 'topic', 'culture', 0, datetime('now'));

-- Business
INSERT OR IGNORE INTO tags (id, name, slug, tag_type, category_slug, is_onboarding_category, created_at) VALUES
    ('tag-onboard-money', 'Money', 'money', 'topic', 'business', 0, datetime('now')),
    ('tag-onboard-entrepreneurship', 'Entrepreneurship', 'entrepreneurship', 'topic', 'business', 0, datetime('now')),
    ('tag-onboard-leadership', 'Leadership', 'leadership', 'topic', 'business', 0, datetime('now')),
    ('tag-onboard-startup', 'Startup', 'startup', 'topic', 'business', 0, datetime('now')),
    ('tag-onboard-careers', 'Careers', 'careers', 'topic', 'business', 0, datetime('now')),
    ('tag-onboard-finance', 'Finance', 'finance', 'topic', 'business', 0, datetime('now')),
    ('tag-onboard-investing', 'Investing', 'investing', 'topic', 'business', 0, datetime('now')),
    ('tag-onboard-work', 'Work', 'work', 'topic', 'business', 0, datetime('now')),
    ('tag-onboard-marketing', 'Marketing', 'marketing', 'topic', 'business', 0, datetime('now')),
    ('tag-onboard-cryptocurrency', 'Cryptocurrency', 'cryptocurrency', 'topic', 'business', 0, datetime('now'));

UPDATE tags
SET category_slug = NULL,
    is_onboarding_category = 1
WHERE slug IN ('technology', 'programming', 'wellness', 'life', 'society', 'culture', 'business');

UPDATE tags
SET category_slug = 'technology',
    is_onboarding_category = 0
WHERE slug IN (
    'ai', 'artificial-intelligence', 'cybersecurity', 'aws', 'llm', 'chatgpt', 'ux',
    'ux-design', 'android', 'ios', 'apple', 'ai-agent', 'future', 'tech', 'kubernetes'
);

UPDATE tags
SET category_slug = 'programming',
    is_onboarding_category = 0
WHERE slug IN (
    'data-science', 'software-development', 'python', 'software-engineering',
    'machine-learning', 'devops', 'web-development', 'data-engineering', 'java',
    'javascript', 'flutter', 'deep-learning', 'react'
);

UPDATE tags
SET category_slug = 'wellness',
    is_onboarding_category = 0
WHERE slug IN (
    'psychology', 'self-improvement', 'mental-health', 'productivity', 'spirituality',
    'personal-growth', 'mindfulness', 'fitness', 'personal-development', 'motivation', 'sports'
);

UPDATE tags
SET category_slug = 'life',
    is_onboarding_category = 0
WHERE slug IN (
    'relationships', 'love', 'life-lessons', 'health', 'this-happened-to-me', 'travel',
    'lifestyle', 'family', 'parenting', 'faith', 'healing', 'sexuality'
);

UPDATE tags
SET category_slug = 'society',
    is_onboarding_category = 0
WHERE slug IN (
    'politics', 'women', 'history', 'news', 'war', 'economics', 'religion', 'christianity',
    'feminism', 'geopolitics', 'world', 'justice', 'equality', 'ukraine-war'
);

UPDATE tags
SET category_slug = 'culture',
    is_onboarding_category = 0
WHERE slug IN (
    'science', 'writing', 'philosophy', 'education', 'books', 'humor', 'space',
    'inspiration', 'creativity', 'art', 'music', 'gaming', 'math'
);

UPDATE tags
SET category_slug = 'business',
    is_onboarding_category = 0
WHERE slug IN (
    'money', 'entrepreneurship', 'leadership', 'startup', 'careers', 'finance',
    'investing', 'work', 'marketing', 'cryptocurrency'
);

INSERT INTO _migrations (filename)
VALUES ('0021_onboarding_topic_taxonomy.sql');
