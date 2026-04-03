-- Migration: 0034_courses_learning_paths
-- Future MVP: Courses, modules, lessons (article-based), enrollments, certificates.
-- Designed to reuse existing articles as lesson content.

-- ─── COURSES ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS courses (
  id              TEXT PRIMARY KEY,
  org_id          TEXT REFERENCES organizations(id) ON DELETE CASCADE,
  instructor_id   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  title           TEXT NOT NULL,
  slug            TEXT NOT NULL UNIQUE,
  description     TEXT,
  cover_image_url TEXT,
  intro_video_url TEXT,

  level           TEXT NOT NULL DEFAULT 'beginner'
                  CHECK(level IN ('beginner','intermediate','advanced','all')),
  language        TEXT NOT NULL DEFAULT 'en',
  tags            TEXT NOT NULL DEFAULT '[]',   -- JSON array

  -- Pricing
  price_cents     INTEGER NOT NULL DEFAULT 0,   -- 0 = free
  membership_tier TEXT,                          -- minimum tier to access, NULL = open

  status          TEXT NOT NULL DEFAULT 'draft'
                  CHECK(status IN ('draft','published','archived')),

  -- Aggregates
  enrollment_count INTEGER NOT NULL DEFAULT 0,
  rating_avg       REAL NOT NULL DEFAULT 0,
  rating_count     INTEGER NOT NULL DEFAULT 0,
  total_duration_minutes INTEGER NOT NULL DEFAULT 0,

  published_at    TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_courses_instructor_id ON courses(instructor_id);
CREATE INDEX IF NOT EXISTS idx_courses_org_id        ON courses(org_id);
CREATE INDEX IF NOT EXISTS idx_courses_status        ON courses(status);
CREATE INDEX IF NOT EXISTS idx_courses_slug          ON courses(slug);

-- ─── COURSE MODULES (sections) ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS course_modules (
  id           TEXT PRIMARY KEY,
  course_id    TEXT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  description  TEXT,
  sort_order   INTEGER NOT NULL DEFAULT 0,
  is_free      INTEGER NOT NULL DEFAULT 0,  -- free preview?
  created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_course_modules_course_id ON course_modules(course_id);

-- ─── COURSE LESSONS (article-backed) ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS course_lessons (
  id              TEXT PRIMARY KEY,
  module_id       TEXT NOT NULL REFERENCES course_modules(id) ON DELETE CASCADE,
  course_id       TEXT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  title           TEXT NOT NULL,
  sort_order      INTEGER NOT NULL DEFAULT 0,
  lesson_type     TEXT NOT NULL DEFAULT 'article'
                  CHECK(lesson_type IN ('article','video','quiz','assignment','live')),

  -- Content: reuse existing articles or embed video
  article_id      TEXT REFERENCES articles(id) ON DELETE SET NULL,
  video_url       TEXT,
  duration_minutes INTEGER NOT NULL DEFAULT 0,
  is_free         INTEGER NOT NULL DEFAULT 0,
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_lessons_module_id  ON course_lessons(module_id);
CREATE INDEX IF NOT EXISTS idx_lessons_course_id  ON course_lessons(course_id);
CREATE INDEX IF NOT EXISTS idx_lessons_article_id ON course_lessons(article_id);

-- ─── QUIZZES (attached to lessons) ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS lesson_quizzes (
  id          TEXT PRIMARY KEY,
  lesson_id   TEXT NOT NULL UNIQUE REFERENCES course_lessons(id) ON DELETE CASCADE,
  pass_score  INTEGER NOT NULL DEFAULT 70,  -- percentage required to pass
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS quiz_questions (
  id             TEXT PRIMARY KEY,
  quiz_id        TEXT NOT NULL REFERENCES lesson_quizzes(id) ON DELETE CASCADE,
  question_text  TEXT NOT NULL,
  question_type  TEXT NOT NULL DEFAULT 'mcq'
                 CHECK(question_type IN ('mcq','true_false','short_answer')),
  options        TEXT NOT NULL DEFAULT '[]',  -- JSON: [{id,text,is_correct}]
  sort_order     INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_quiz_questions_quiz_id ON quiz_questions(quiz_id);

-- ─── COURSE ENROLLMENTS ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS course_enrollments (
  id            TEXT PRIMARY KEY,
  course_id     TEXT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status        TEXT NOT NULL DEFAULT 'enrolled'
                CHECK(status IN ('enrolled','in_progress','completed','dropped','refunded')),
  enrolled_at   TEXT NOT NULL DEFAULT (datetime('now')),
  completed_at  TEXT,
  -- Payment
  paid_cents    INTEGER NOT NULL DEFAULT 0,
  payment_id    TEXT,   -- Stripe payment intent id
  UNIQUE(course_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_enrollments_course_id ON course_enrollments(course_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_user_id   ON course_enrollments(user_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_status    ON course_enrollments(status);

-- ─── LESSON PROGRESS ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS lesson_progress (
  enrollment_id   TEXT NOT NULL REFERENCES course_enrollments(id) ON DELETE CASCADE,
  lesson_id       TEXT NOT NULL REFERENCES course_lessons(id) ON DELETE CASCADE,
  status          TEXT NOT NULL DEFAULT 'not_started'
                  CHECK(status IN ('not_started','in_progress','completed')),
  progress_pct    INTEGER NOT NULL DEFAULT 0,
  quiz_score      INTEGER,     -- if lesson has a quiz: score achieved
  completed_at    TEXT,
  last_viewed_at  TEXT,
  PRIMARY KEY (enrollment_id, lesson_id)
);

CREATE INDEX IF NOT EXISTS idx_lesson_progress_enrollment ON lesson_progress(enrollment_id);
CREATE INDEX IF NOT EXISTS idx_lesson_progress_lesson     ON lesson_progress(lesson_id);

-- ─── CERTIFICATES ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS certificates (
  id              TEXT PRIMARY KEY,
  course_id       TEXT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  user_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  enrollment_id   TEXT NOT NULL REFERENCES course_enrollments(id) ON DELETE CASCADE,
  certificate_url TEXT,           -- R2 URL of the generated PDF
  issued_at       TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(course_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_certificates_user_id   ON certificates(user_id);
CREATE INDEX IF NOT EXISTS idx_certificates_course_id ON certificates(course_id);

INSERT INTO _migrations (filename) VALUES ('0034_courses_learning_paths.sql');
