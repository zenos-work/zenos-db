-- 0037_seed_data.sql — System user, system tags, onboarding taxonomy, content types,
-- system articles, article tags, ranking weights
-- (merged: 0016 + 0017 + 0019(seed) + 0021 + 0024(seed))

-- ─── SYSTEM USER ─────────────────────────────────────────────────────────────
INSERT OR IGNORE INTO users (
    id, email, name, avatar_url, google_id, role, is_active, created_at, updated_at
) VALUES (
    'system-zenos-author', 'system@zenos.work', 'Zenos System',
    NULL, NULL, 'AUTHOR', 1, datetime('now'), datetime('now')
);

-- ─── SYSTEM TAGS ─────────────────────────────────────────────────────────────
INSERT OR IGNORE INTO tags (id, name, slug, tag_type, category_slug, is_onboarding_category, created_at) VALUES
    ('tag-tour',            'Tour',             'tour',             'topic', NULL, 0, datetime('now')),
    ('tag-howto',           'How To',           'how-to',           'topic', NULL, 0, datetime('now')),
    ('tag-software-writing','Software Writing', 'software-writing', 'topic', NULL, 0, datetime('now')),
    ('tag-editorial',       'Editorial',        'editorial',        'topic', NULL, 0, datetime('now'));

-- ─── ONBOARDING TAXONOMY — CATEGORIES ────────────────────────────────────────
INSERT OR IGNORE INTO tags (id, name, slug, tag_type, category_slug, is_onboarding_category, created_at) VALUES
    ('tag-onboard-technology',  'Technology',  'technology',  'topic', NULL, 1, datetime('now')),
    ('tag-onboard-programming', 'Programming', 'programming', 'topic', NULL, 1, datetime('now')),
    ('tag-onboard-wellness',    'Wellness',    'wellness',    'topic', NULL, 1, datetime('now')),
    ('tag-onboard-life',        'Life',        'life',        'topic', NULL, 1, datetime('now')),
    ('tag-onboard-society',     'Society',     'society',     'topic', NULL, 1, datetime('now')),
    ('tag-onboard-culture',     'Culture',     'culture',     'topic', NULL, 1, datetime('now')),
    ('tag-onboard-business',    'Business',    'business',    'topic', NULL, 1, datetime('now'));

-- ─── ONBOARDING TAXONOMY — Technology ────────────────────────────────────────
INSERT OR IGNORE INTO tags (id, name, slug, tag_type, category_slug, is_onboarding_category, created_at) VALUES
    ('tag-onboard-ai',                    'AI',                    'ai',                    'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-artificial-intelligence','Artificial Intelligence','artificial-intelligence','topic', 'technology', 0, datetime('now')),
    ('tag-onboard-cybersecurity',         'Cybersecurity',         'cybersecurity',         'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-aws',                   'AWS',                   'aws',                   'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-llm',                   'LLM',                   'llm',                   'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-chatgpt',               'ChatGPT',               'chatgpt',               'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-ux',                    'UX',                    'ux',                    'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-ux-design',             'UX Design',             'ux-design',             'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-android',               'Android',               'android',               'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-ios',                   'iOS',                   'ios',                   'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-apple',                 'Apple',                 'apple',                 'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-ai-agent',              'AI Agent',              'ai-agent',              'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-future',                'Future',                'future',                'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-tech',                  'Tech',                  'tech',                  'topic', 'technology', 0, datetime('now')),
    ('tag-onboard-kubernetes',            'Kubernetes',            'kubernetes',            'topic', 'technology', 0, datetime('now'));

-- ─── ONBOARDING TAXONOMY — Programming ───────────────────────────────────────
INSERT OR IGNORE INTO tags (id, name, slug, tag_type, category_slug, is_onboarding_category, created_at) VALUES
    ('tag-onboard-data-science',          'Data Science',          'data-science',          'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-software-development',  'Software Development',  'software-development',  'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-python',                'Python',                'python',                'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-software-engineering',  'Software Engineering',  'software-engineering',  'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-machine-learning',      'Machine Learning',      'machine-learning',      'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-devops',                'DevOps',                'devops',                'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-web-development',       'Web Development',       'web-development',       'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-data-engineering',      'Data Engineering',      'data-engineering',      'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-java',                  'Java',                  'java',                  'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-javascript',            'JavaScript',            'javascript',            'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-flutter',               'Flutter',               'flutter',               'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-deep-learning',         'Deep Learning',         'deep-learning',         'topic', 'programming', 0, datetime('now')),
    ('tag-onboard-react',                 'React',                 'react',                 'topic', 'programming', 0, datetime('now'));

-- ─── ONBOARDING TAXONOMY — Wellness ──────────────────────────────────────────
INSERT OR IGNORE INTO tags (id, name, slug, tag_type, category_slug, is_onboarding_category, created_at) VALUES
    ('tag-onboard-psychology',            'Psychology',            'psychology',            'topic', 'wellness', 0, datetime('now')),
    ('tag-onboard-self-improvement',      'Self Improvement',      'self-improvement',      'topic', 'wellness', 0, datetime('now')),
    ('tag-onboard-mental-health',         'Mental Health',         'mental-health',         'topic', 'wellness', 0, datetime('now')),
    ('tag-onboard-productivity',          'Productivity',          'productivity',          'topic', 'wellness', 0, datetime('now')),
    ('tag-onboard-spirituality',          'Spirituality',          'spirituality',          'topic', 'wellness', 0, datetime('now')),
    ('tag-onboard-personal-growth',       'Personal Growth',       'personal-growth',       'topic', 'wellness', 0, datetime('now')),
    ('tag-onboard-mindfulness',           'Mindfulness',           'mindfulness',           'topic', 'wellness', 0, datetime('now')),
    ('tag-onboard-fitness',               'Fitness',               'fitness',               'topic', 'wellness', 0, datetime('now')),
    ('tag-onboard-personal-development',  'Personal Development',  'personal-development',  'topic', 'wellness', 0, datetime('now')),
    ('tag-onboard-motivation',            'Motivation',            'motivation',            'topic', 'wellness', 0, datetime('now')),
    ('tag-onboard-sports',                'Sports',                'sports',                'topic', 'wellness', 0, datetime('now'));

-- ─── ONBOARDING TAXONOMY — Life ──────────────────────────────────────────────
INSERT OR IGNORE INTO tags (id, name, slug, tag_type, category_slug, is_onboarding_category, created_at) VALUES
    ('tag-onboard-relationships',         'Relationships',         'relationships',         'topic', 'life', 0, datetime('now')),
    ('tag-onboard-love',                  'Love',                  'love',                  'topic', 'life', 0, datetime('now')),
    ('tag-onboard-life-lessons',          'Life Lessons',          'life-lessons',          'topic', 'life', 0, datetime('now')),
    ('tag-onboard-health',                'Health',                'health',                'topic', 'life', 0, datetime('now')),
    ('tag-onboard-this-happened-to-me',   'This Happened To Me',   'this-happened-to-me',   'topic', 'life', 0, datetime('now')),
    ('tag-onboard-travel',                'Travel',                'travel',                'topic', 'life', 0, datetime('now')),
    ('tag-onboard-lifestyle',             'Lifestyle',             'lifestyle',             'topic', 'life', 0, datetime('now')),
    ('tag-onboard-family',                'Family',                'family',                'topic', 'life', 0, datetime('now')),
    ('tag-onboard-parenting',             'Parenting',             'parenting',             'topic', 'life', 0, datetime('now')),
    ('tag-onboard-faith',                 'Faith',                 'faith',                 'topic', 'life', 0, datetime('now')),
    ('tag-onboard-healing',               'Healing',               'healing',               'topic', 'life', 0, datetime('now')),
    ('tag-onboard-sexuality',             'Sexuality',             'sexuality',             'topic', 'life', 0, datetime('now'));

-- ─── ONBOARDING TAXONOMY — Society ───────────────────────────────────────────
INSERT OR IGNORE INTO tags (id, name, slug, tag_type, category_slug, is_onboarding_category, created_at) VALUES
    ('tag-onboard-politics',              'Politics',              'politics',              'topic', 'society', 0, datetime('now')),
    ('tag-onboard-women',                 'Women',                 'women',                 'topic', 'society', 0, datetime('now')),
    ('tag-onboard-history',               'History',               'history',               'topic', 'society', 0, datetime('now')),
    ('tag-onboard-news',                  'News',                  'news',                  'topic', 'society', 0, datetime('now')),
    ('tag-onboard-war',                   'War',                   'war',                   'topic', 'society', 0, datetime('now')),
    ('tag-onboard-economics',             'Economics',             'economics',             'topic', 'society', 0, datetime('now')),
    ('tag-onboard-religion',              'Religion',              'religion',              'topic', 'society', 0, datetime('now')),
    ('tag-onboard-christianity',          'Christianity',          'christianity',          'topic', 'society', 0, datetime('now')),
    ('tag-onboard-feminism',              'Feminism',              'feminism',              'topic', 'society', 0, datetime('now')),
    ('tag-onboard-geopolitics',           'Geopolitics',           'geopolitics',           'topic', 'society', 0, datetime('now')),
    ('tag-onboard-world',                 'World',                 'world',                 'topic', 'society', 0, datetime('now')),
    ('tag-onboard-justice',               'Justice',               'justice',               'topic', 'society', 0, datetime('now')),
    ('tag-onboard-equality',              'Equality',              'equality',              'topic', 'society', 0, datetime('now')),
    ('tag-onboard-ukraine-war',           'Ukraine War',           'ukraine-war',           'topic', 'society', 0, datetime('now'));

-- ─── ONBOARDING TAXONOMY — Culture ───────────────────────────────────────────
INSERT OR IGNORE INTO tags (id, name, slug, tag_type, category_slug, is_onboarding_category, created_at) VALUES
    ('tag-onboard-science',               'Science',               'science',               'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-writing',               'Writing',               'writing',               'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-philosophy',            'Philosophy',            'philosophy',             'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-education',             'Education',             'education',             'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-books',                 'Books',                 'books',                 'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-humor',                 'Humor',                 'humor',                 'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-space',                 'Space',                 'space',                 'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-inspiration',           'Inspiration',           'inspiration',           'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-creativity',            'Creativity',            'creativity',            'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-art',                   'Art',                   'art',                   'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-music',                 'Music',                 'music',                 'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-gaming',                'Gaming',                'gaming',                'topic', 'culture', 0, datetime('now')),
    ('tag-onboard-math',                  'Math',                  'math',                  'topic', 'culture', 0, datetime('now'));

-- ─── ONBOARDING TAXONOMY — Business ──────────────────────────────────────────
INSERT OR IGNORE INTO tags (id, name, slug, tag_type, category_slug, is_onboarding_category, created_at) VALUES
    ('tag-onboard-money',                 'Money',                 'money',                 'topic', 'business', 0, datetime('now')),
    ('tag-onboard-entrepreneurship',      'Entrepreneurship',      'entrepreneurship',      'topic', 'business', 0, datetime('now')),
    ('tag-onboard-leadership',            'Leadership',            'leadership',            'topic', 'business', 0, datetime('now')),
    ('tag-onboard-startup',               'Startup',               'startup',               'topic', 'business', 0, datetime('now')),
    ('tag-onboard-careers',               'Careers',               'careers',               'topic', 'business', 0, datetime('now')),
    ('tag-onboard-finance',               'Finance',               'finance',               'topic', 'business', 0, datetime('now')),
    ('tag-onboard-investing',             'Investing',             'investing',              'topic', 'business', 0, datetime('now')),
    ('tag-onboard-work',                  'Work',                  'work',                  'topic', 'business', 0, datetime('now')),
    ('tag-onboard-marketing',             'Marketing',             'marketing',             'topic', 'business', 0, datetime('now')),
    ('tag-onboard-cryptocurrency',        'Cryptocurrency',        'cryptocurrency',        'topic', 'business', 0, datetime('now'));

-- ─── CONTENT TYPES ───────────────────────────────────────────────────────────
INSERT OR IGNORE INTO content_types (id, slug, name, description, is_active, is_system, sort_order)
VALUES
    ('ct-article',    'article',    'Article',    'General long-form editorial content',           1, 1, 10),
    ('ct-how-to',     'how-to',     'How-to',     'Instructional or tutorial-driven content',      1, 1, 20),
    ('ct-case-study', 'case-study', 'Case Study', 'Experience-backed implementation stories',     1, 1, 30),
    ('ct-research',   'research',   'Research',   'Evidence-driven analysis and findings',         1, 1, 40);

-- ─── RANKING WEIGHTS ─────────────────────────────────────────────────────────
INSERT OR IGNORE INTO ranking_weights (
    id, likes_weight, shares_weight, comments_weight, dislikes_weight, views_weight, recency_weight
) VALUES (1, 1.0, 2.0, 1.5, -1.0, 0.1, 0.25);

-- ─── SYSTEM ARTICLES ─────────────────────────────────────────────────────────
INSERT OR IGNORE INTO articles (
    id, author_id, approved_by, title, slug, subtitle, content,
    cover_image_url, read_time_minutes, status, rejection_note,
    views_count, likes_count, comments_count, is_featured,
    published_at, created_at, updated_at, last_verified_at, expires_at,
    moderation_state, moderation_note,
    seo_title, seo_description, canonical_url, og_image_url, seo_schema_type
) VALUES
    (
        'system-article-tour',
        'system-zenos-author', NULL,
        'Platform Tour: Start in minutes',
        'platform-tour-start-in-minutes',
        'Take a quick guided tour of writing, review, and publish workflows.',
        '{"type":"doc","content":[{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"A fast way to learn the platform"}]},{"type":"paragraph","content":[{"type":"text","text":"Zenos helps writers and editors move from draft to publish in one connected workflow."}]},{"type":"paragraph","content":[{"type":"text","text":"This tour article is intentionally seeded so new environments always show real content in discovery surfaces."}]}]}',
        'https://images.unsplash.com/photo-1497215728101-856f4ea42174?auto=format&fit=crop&w=1600&q=80',
        3, 'PUBLISHED', NULL, 320, 28, 6, 1,
        datetime('now','-1 day'), datetime('now','-1 day'), datetime('now','-1 day'),
        datetime('now','-1 day'), '5000-12-31 23:59:00',
        'APPROVED_BY_ADMIN', 'Seeded system article',
        'Platform Tour: Start in minutes | Zenos.work',
        'Take a guided tour through writing, review, approval, and publish workflows in Zenos.',
        'https://zenos.work/article/platform-tour-start-in-minutes',
        'https://images.unsplash.com/photo-1497215728101-856f4ea42174?auto=format&fit=crop&w=1600&q=80',
        'Article'
    ),
    (
        'system-article-howto',
        'system-zenos-author', NULL,
        'How-to Guide: Ship quality content',
        'how-to-guide-ship-quality-content',
        'Learn the practical steps to draft, review, and publish without bottlenecks.',
        '{"type":"doc","content":[{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"How teams ship quality content"}]},{"type":"paragraph","content":[{"type":"text","text":"Start with a clear draft, add structured tags, and keep metadata healthy before review."}]},{"type":"paragraph","content":[{"type":"text","text":"Approvers and authors can collaborate with less friction when the workflow is explicit and consistent."}]}]}',
        'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?auto=format&fit=crop&w=1600&q=80',
        3, 'PUBLISHED', NULL, 290, 24, 5, 1,
        datetime('now','-2 day'), datetime('now','-2 day'), datetime('now','-2 day'),
        datetime('now','-2 day'), '5000-12-31 23:59:00',
        'APPROVED_BY_ADMIN', 'Seeded system article',
        'How-to Guide: Ship quality content | Zenos.work',
        'A practical guide to drafting, validating, reviewing, and publishing quality content in Zenos.',
        'https://zenos.work/article/how-to-guide-ship-quality-content',
        'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?auto=format&fit=crop&w=1600&q=80',
        'HowTo'
    ),
    (
        'system-article-software-writing',
        'system-zenos-author', NULL,
        'Software Writing: Build docs users trust',
        'software-writing-build-docs-users-trust',
        'Create clear technical writing with standards, governance, and consistency.',
        '{"type":"doc","content":[{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Documentation users can trust"}]},{"type":"paragraph","content":[{"type":"text","text":"Software writing benefits from consistent structure, verification dates, and review checkpoints."}]},{"type":"paragraph","content":[{"type":"text","text":"This seeded article ensures technical writing examples are available from day one."}]}]}',
        'https://images.unsplash.com/photo-1518773553398-650c184e0bb3?auto=format&fit=crop&w=1600&q=80',
        3, 'PUBLISHED', NULL, 275, 22, 4, 0,
        datetime('now','-3 day'), datetime('now','-3 day'), datetime('now','-3 day'),
        datetime('now','-3 day'), '5000-12-31 23:59:00',
        'APPROVED_BY_ADMIN', 'Seeded system article',
        'Software Writing: Build docs users trust | Zenos.work',
        'Use structured editorial workflows to create technical writing users can trust.',
        'https://zenos.work/article/software-writing-build-docs-users-trust',
        'https://images.unsplash.com/photo-1518773553398-650c184e0bb3?auto=format&fit=crop&w=1600&q=80',
        'TechArticle'
    ),
    (
        'system-article-spotlight',
        'system-zenos-author', NULL,
        'Editorial Spotlight: Inside the Zenos workflow',
        'editorial-spotlight-inside-the-zenos-workflow',
        'See how system-authored stories keep discovery surfaces populated from day one.',
        '{"type":"doc","content":[{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Why seeded stories matter"}]},{"type":"paragraph","content":[{"type":"text","text":"Empty discovery pages create a poor first impression in fresh environments."}]},{"type":"paragraph","content":[{"type":"text","text":"System-authored spotlight stories provide immediate, realistic content for feeds and article routes."}]},{"type":"paragraph","content":[{"type":"text","text":"As editorial teams publish their own work, these seeded stories can remain as onboarding examples."}]}]}',
        'https://images.unsplash.com/photo-1461749280684-dccba630e2f6?auto=format&fit=crop&w=1600&q=80',
        3, 'PUBLISHED', NULL, 240, 19, 3, 0,
        datetime('now','-4 day'), datetime('now','-4 day'), datetime('now','-4 day'),
        datetime('now','-4 day'), '5000-12-31 23:59:00',
        'APPROVED_BY_ADMIN', 'Seeded system article',
        'Editorial Spotlight: Inside the Zenos workflow | Zenos.work',
        'A system-authored spotlight article that keeps landing surfaces populated with real content.',
        'https://zenos.work/article/editorial-spotlight-inside-the-zenos-workflow',
        'https://images.unsplash.com/photo-1461749280684-dccba630e2f6?auto=format&fit=crop&w=1600&q=80',
        'Article'
    );

-- ─── ARTICLE TAGS FOR SYSTEM ARTICLES ────────────────────────────────────────
INSERT OR IGNORE INTO article_tags (article_id, tag_id) VALUES
    ('system-article-tour',             'tag-tour'),
    ('system-article-tour',             'tag-editorial'),
    ('system-article-howto',            'tag-howto'),
    ('system-article-howto',            'tag-editorial'),
    ('system-article-software-writing', 'tag-software-writing'),
    ('system-article-software-writing', 'tag-editorial'),
    ('system-article-spotlight',        'tag-editorial');

INSERT INTO _migrations (filename) VALUES ('0037_seed_data.sql');
