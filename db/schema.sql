-- PostgreSQL 15+ reference schema. Apply through Alembic after review.
-- Design contract, not a production-ready migration with full audit/RLS policies.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE,
    password_hash TEXT,
    display_name TEXT NOT NULL DEFAULT '',
    locale TEXT NOT NULL DEFAULT 'zh-CN',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    platform TEXT NOT NULL CHECK (platform IN ('ios','android','harmony')),
    device_public_id TEXT NOT NULL,
    last_seen_at TIMESTAMPTZ,
    UNIQUE(user_id, device_public_id)
);

CREATE TABLE exams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    language_code TEXT NOT NULL
);

CREATE TABLE exam_editions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_id UUID NOT NULL REFERENCES exams(id),
    edition_code TEXT NOT NULL,
    display_name TEXT NOT NULL,
    effective_from DATE,
    effective_until DATE,
    blueprint JSONB NOT NULL DEFAULT '{}'::jsonb,
    score_policy JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(exam_id, edition_code)
);

CREATE TABLE content_packages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_edition_id UUID NOT NULL REFERENCES exam_editions(id),
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    level TEXT,
    license_code TEXT,
    license_expires_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'draft'
      CHECK (status IN ('draft','review','published','archived')),
    package_version INTEGER NOT NULL DEFAULT 1 CHECK (package_version > 0),
    offline_allowed BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    published_at TIMESTAMPTZ
);

CREATE TABLE sections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    package_id UUID NOT NULL REFERENCES content_packages(id),
    name TEXT NOT NULL,
    skill TEXT NOT NULL,
    position INTEGER NOT NULL DEFAULT 0,
    config JSONB NOT NULL DEFAULT '{}'::jsonb,
    UNIQUE(package_id, position)
);

CREATE TABLE stimuli (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    package_id UUID NOT NULL REFERENCES content_packages(id),
    kind TEXT NOT NULL CHECK (kind IN ('passage','audio','image','mixed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE stimulus_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stimulus_id UUID NOT NULL REFERENCES stimuli(id),
    version_no INTEGER NOT NULL CHECK (version_no > 0),
    body JSONB NOT NULL DEFAULT '{}'::jsonb,
    status TEXT NOT NULL DEFAULT 'draft'
      CHECK (status IN ('draft','review','published','archived')),
    published_at TIMESTAMPTZ,
    UNIQUE(stimulus_id, version_no)
);

CREATE TABLE questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    section_id UUID NOT NULL REFERENCES sections(id),
    public_code TEXT NOT NULL UNIQUE,
    interaction TEXT NOT NULL CHECK (interaction IN
      ('single_choice','multiple_choice','cloze','reorder','short_text','essay','audio_response')),
    skill TEXT NOT NULL,
    difficulty SMALLINT CHECK (difficulty BETWEEN 1 AND 5),
    tags TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE question_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id UUID NOT NULL REFERENCES questions(id),
    stimulus_version_id UUID REFERENCES stimulus_versions(id),
    version_no INTEGER NOT NULL CHECK (version_no > 0),
    body JSONB NOT NULL,
    answer_schema JSONB NOT NULL DEFAULT '{}'::jsonb,
    answer_key JSONB NOT NULL DEFAULT '{}'::jsonb,
    scoring_policy JSONB NOT NULL DEFAULT '{}'::jsonb,
    explanation JSONB NOT NULL DEFAULT '{}'::jsonb,
    status TEXT NOT NULL DEFAULT 'draft'
      CHECK (status IN ('draft','review','published','archived')),
    content_hash TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    published_at TIMESTAMPTZ,
    UNIQUE(question_id, version_no)
);

CREATE TABLE media_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kind TEXT NOT NULL CHECK (kind IN ('audio','image','video','recording')),
    storage_key TEXT NOT NULL UNIQUE,
    sha256 CHAR(64),
    mime_type TEXT NOT NULL,
    size_bytes BIGINT NOT NULL CHECK (size_bytes >= 0),
    duration_ms BIGINT,
    access_policy TEXT NOT NULL DEFAULT 'private'
      CHECK (access_policy IN ('public','licensed','private')),
    owner_user_id UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE stimulus_media (
    stimulus_version_id UUID NOT NULL REFERENCES stimulus_versions(id),
    asset_id UUID NOT NULL REFERENCES media_assets(id),
    role TEXT NOT NULL,
    position INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY(stimulus_version_id, asset_id, role)
);

CREATE TABLE question_media (
    question_version_id UUID NOT NULL REFERENCES question_versions(id),
    asset_id UUID NOT NULL REFERENCES media_assets(id),
    role TEXT NOT NULL,
    position INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY(question_version_id, asset_id, role)
);

CREATE TABLE practice_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    exam_edition_id UUID NOT NULL REFERENCES exam_editions(id),
    package_id UUID REFERENCES content_packages(id),
    mode TEXT NOT NULL CHECK (mode IN ('practice','mock','review')),
    status TEXT NOT NULL DEFAULT 'created'
      CHECK (status IN ('created','active','paused','submitted','grading','graded','expired')),
    total_items INTEGER NOT NULL DEFAULT 0,
    started_at TIMESTAMPTZ,
    deadline_at TIMESTAMPTZ,
    submitted_at TIMESTAMPTZ,
    score_raw NUMERIC(10,3),
    score_display TEXT,
    scoring_rule_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_sessions_user_created ON practice_sessions(user_id, created_at DESC);

CREATE TABLE session_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES practice_sessions(id),
    question_version_id UUID NOT NULL REFERENCES question_versions(id),
    position INTEGER NOT NULL CHECK (position >= 0),
    max_points NUMERIC(10,3) NOT NULL DEFAULT 1 CHECK (max_points >= 0),
    UNIQUE(session_id, position)
);

CREATE TABLE attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    session_item_id UUID NOT NULL REFERENCES session_items(id),
    client_attempt_id UUID NOT NULL UNIQUE,
    device_id UUID REFERENCES devices(id),
    answer JSONB NOT NULL,
    grade_status TEXT NOT NULL DEFAULT 'pending'
      CHECK (grade_status IN ('pending','correct','incorrect','partial','graded','invalid')),
    earned_points NUMERIC(10,3),
    feedback JSONB,
    occurred_at TIMESTAMPTZ NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_attempts_user_time ON attempts(user_id, received_at DESC);
CREATE INDEX idx_attempts_item ON attempts(session_item_id);

CREATE TABLE question_progress (
    user_id UUID NOT NULL REFERENCES users(id),
    question_id UUID NOT NULL REFERENCES questions(id),
    attempt_count INTEGER NOT NULL DEFAULT 0,
    correct_count INTEGER NOT NULL DEFAULT 0,
    mastery NUMERIC(5,4) NOT NULL DEFAULT 0,
    last_attempt_at TIMESTAMPTZ,
    last_wrong_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY(user_id, question_id)
);

CREATE TABLE review_schedule (
    user_id UUID NOT NULL REFERENCES users(id),
    question_id UUID NOT NULL REFERENCES questions(id),
    algorithm TEXT NOT NULL DEFAULT 'simple-v1',
    algorithm_state JSONB NOT NULL DEFAULT '{}'::jsonb,
    due_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY(user_id, question_id)
);
CREATE INDEX idx_review_due ON review_schedule(user_id, due_at);

CREATE TABLE speech_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    attempt_id UUID NOT NULL UNIQUE REFERENCES attempts(id),
    asset_id UUID REFERENCES media_assets(id),
    kind TEXT NOT NULL CHECK (kind IN ('speaking','writing')),
    state TEXT NOT NULL DEFAULT 'queued'
      CHECK (state IN ('queued','processing','completed','failed','needs_review')),
    evaluator_version TEXT,
    result JSONB,
    error_code TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at TIMESTAMPTZ
);

CREATE TABLE purchase_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    platform TEXT NOT NULL CHECK (platform IN ('apple','google','huawei')),
    external_transaction_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    purchased_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    verified_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    UNIQUE(platform, external_transaction_id)
);

CREATE TABLE entitlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    source_order_id UUID REFERENCES purchase_orders(id),
    benefit_key TEXT NOT NULL,
    valid_from TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_entitlement_user ON entitlements(user_id, benefit_key, expires_at);

CREATE TABLE sync_events (
    seq BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    device_id UUID REFERENCES devices(id),
    client_event_id UUID NOT NULL,
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, client_event_id)
);
CREATE INDEX idx_sync_events_user_seq ON sync_events(user_id, seq);

-- Security invariants handled by domain service/migrations:
-- (a) Published question version is immutable; corrections create a new version.
-- (b) All session_item references belong to their session's edition/package.
-- (c) Only the owning user may submit/read a session or related attempts.
-- (d) score updates and event outbox happen in one DB transaction.
-- (e) store refresh token hashes, admin audit trail, content licenses and invoices in additional tables.
-- (f) Serialize sync_events inserts per user by locking users row in the same transaction,
--     so a user cursor cannot skip late-committing events with a lower allocated seq.
-- (g) A published stimulus_version must remain immutable, just like question_version.
