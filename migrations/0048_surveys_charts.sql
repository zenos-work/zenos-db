-- Migration for Surveys and Charts

CREATE TABLE surveys (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    author_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    article_id TEXT REFERENCES articles(id) ON DELETE CASCADE,
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_surveys_author ON surveys(author_id);
CREATE INDEX idx_surveys_article ON surveys(article_id);

CREATE TABLE survey_questions (
    id TEXT PRIMARY KEY,
    survey_id TEXT NOT NULL REFERENCES surveys(id) ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    question_type TEXT NOT NULL, -- 'MULTIPLE_CHOICE', 'SHORT_ANSWER', 'RATING'
    options_json TEXT, -- JSON array
    is_required INTEGER NOT NULL DEFAULT 1,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_survey_questions_survey ON survey_questions(survey_id);

CREATE TABLE survey_responses (
    id TEXT PRIMARY KEY,
    survey_id TEXT NOT NULL REFERENCES surveys(id) ON DELETE CASCADE,
    question_id TEXT NOT NULL REFERENCES survey_questions(id) ON DELETE CASCADE,
    user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
    session_id TEXT, -- for anonymous users
    answer_text TEXT,
    answer_option_index INTEGER,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX idx_survey_responses_user ON survey_responses(question_id, user_id) WHERE user_id IS NOT NULL;
CREATE UNIQUE INDEX idx_survey_responses_session ON survey_responses(question_id, session_id) WHERE user_id IS NULL AND session_id IS NOT NULL;
CREATE INDEX idx_survey_responses_survey ON survey_responses(survey_id);

CREATE TABLE charts (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    chart_type TEXT NOT NULL, -- 'BAR', 'LINE', 'PIE'
    data_json TEXT NOT NULL,
    config_json TEXT,
    author_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    article_id TEXT REFERENCES articles(id) ON DELETE CASCADE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_charts_author ON charts(author_id);
CREATE INDEX idx_charts_article ON charts(article_id);
