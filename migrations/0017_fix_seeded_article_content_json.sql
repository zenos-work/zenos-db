-- Migration: 0017_fix_seeded_article_content_json
-- Fixes seeded system article content payloads to valid TipTap JSON.

UPDATE articles
SET content = '{"type":"doc","content":[{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"A fast way to learn the platform"}]},{"type":"paragraph","content":[{"type":"text","text":"Zenos helps writers and editors move from draft to publish in one connected workflow."}]},{"type":"paragraph","content":[{"type":"text","text":"This tour article is intentionally seeded so new environments always show real content in discovery surfaces."}]}]}'
WHERE id = 'system-article-tour';

UPDATE articles
SET content = '{"type":"doc","content":[{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"How teams ship quality content"}]},{"type":"paragraph","content":[{"type":"text","text":"Start with a clear draft, add structured tags, and keep metadata healthy before review."}]},{"type":"paragraph","content":[{"type":"text","text":"Approvers and authors can collaborate with less friction when the workflow is explicit and consistent."}]}]}'
WHERE id = 'system-article-howto';

UPDATE articles
SET content = '{"type":"doc","content":[{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Documentation users can trust"}]},{"type":"paragraph","content":[{"type":"text","text":"Software writing benefits from consistent structure, verification dates, and review checkpoints."}]},{"type":"paragraph","content":[{"type":"text","text":"This seeded article ensures technical writing examples are available from day one."}]}]}'
WHERE id = 'system-article-software-writing';

UPDATE articles
SET content = '{"type":"doc","content":[{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Why seeded stories matter"}]},{"type":"paragraph","content":[{"type":"text","text":"Empty discovery pages create a poor first impression in fresh environments."}]},{"type":"paragraph","content":[{"type":"text","text":"System-authored spotlight stories provide immediate, realistic content for feeds and article routes."}]},{"type":"paragraph","content":[{"type":"text","text":"As editorial teams publish their own work, these seeded stories can remain as onboarding examples."}]}]}'
WHERE id = 'system-article-spotlight';

INSERT INTO _migrations (filename)
VALUES ('0017_fix_seeded_article_content_json.sql');
