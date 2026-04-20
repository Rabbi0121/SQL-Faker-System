BEGIN;

CREATE SCHEMA IF NOT EXISTS fake;

CREATE TABLE IF NOT EXISTS fake.locales (
    locale_code TEXT PRIMARY KEY,
    locale_name TEXT NOT NULL,
    country_code TEXT NOT NULL,
    default_email_domain TEXT NOT NULL,
    phone_country_code TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS fake.names (
    name_id BIGSERIAL PRIMARY KEY,
    locale_code TEXT NOT NULL REFERENCES fake.locales(locale_code),
    name_type TEXT NOT NULL CHECK (name_type IN ('title', 'first', 'middle', 'last')),
    gender TEXT NOT NULL CHECK (gender IN ('M', 'F', 'N')),
    value TEXT NOT NULL,
    weight INTEGER NOT NULL DEFAULT 1 CHECK (weight > 0),
    UNIQUE (locale_code, name_type, gender, value)
);

CREATE INDEX IF NOT EXISTS idx_names_lookup
    ON fake.names (locale_code, name_type, gender, name_id);

CREATE TABLE IF NOT EXISTS fake.lexicon (
    lex_id BIGSERIAL PRIMARY KEY,
    locale_code TEXT NOT NULL REFERENCES fake.locales(locale_code),
    token_type TEXT NOT NULL,
    value TEXT NOT NULL,
    weight INTEGER NOT NULL DEFAULT 1 CHECK (weight > 0),
    UNIQUE (locale_code, token_type, value)
);

CREATE INDEX IF NOT EXISTS idx_lexicon_lookup
    ON fake.lexicon (locale_code, token_type, lex_id);

COMMIT;
