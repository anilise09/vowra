-- Vawra core schema. Opaque random UUIDs everywhere; no sequential IDs.

CREATE TABLE accounts (
  id              uuid PRIMARY KEY,
  email_lookup    text NOT NULL UNIQUE,        -- keyed HMAC of the normalized email
  email_sealed    text NOT NULL,               -- AES-256-GCM ciphertext for delivery only
  age_state       text NOT NULL DEFAULT 'assurance_required'
                  CHECK (age_state IN ('assurance_required','pending_review','adult_verified','rejected')),
  lifecycle       text NOT NULL DEFAULT 'active' CHECK (lifecycle IN ('active','paused')),
  created_at      timestamptz NOT NULL
);

CREATE TABLE profiles (
  account_id              uuid PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
  display_name            text NOT NULL,
  relationship_intent     text NOT NULL,
  bio                     text NOT NULL DEFAULT '',
  interests               text[] NOT NULL DEFAULT '{}',
  show_distance_band      boolean NOT NULL DEFAULT true,
  call_ready_by_default   boolean NOT NULL DEFAULT false,
  public_age              integer,             -- set only from age assurance, never from the client
  updated_at              timestamptz NOT NULL
);

CREATE TABLE auth_requests (
  id              uuid PRIMARY KEY,
  email_lookup    text NOT NULL,
  email_sealed    text NOT NULL,
  purpose         text NOT NULL CHECK (purpose IN ('sign_in','recovery')),
  proof_hash      text NOT NULL UNIQUE,
  code_challenge  text NOT NULL,
  state_nonce     text NOT NULL,
  expires_at      timestamptz NOT NULL,
  used_at         timestamptz
);

CREATE TABLE session_families (
  id          uuid PRIMARY KEY,
  account_id  uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL,
  revoked_at  timestamptz
);

CREATE TABLE sessions (
  id                 uuid PRIMARY KEY,
  family_id          uuid NOT NULL REFERENCES session_families(id) ON DELETE CASCADE,
  account_id         uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  access_hash        text NOT NULL UNIQUE,
  access_expires_at  timestamptz NOT NULL,
  refresh_hash       text NOT NULL UNIQUE,
  refresh_used_at    timestamptz,
  created_at         timestamptz NOT NULL,
  revoked_at         timestamptz
);

CREATE TABLE swipes (
  from_account  uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  to_account    uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  kind          text NOT NULL CHECK (kind IN ('like','super_like','pass')),
  created_at    timestamptz NOT NULL,
  PRIMARY KEY (from_account, to_account),
  CHECK (from_account <> to_account)
);

CREATE TABLE matches (
  id            uuid PRIMARY KEY,
  account_low   uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  account_high  uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  status        text NOT NULL DEFAULT 'active' CHECK (status IN ('active','unmatched','blocked')),
  created_at    timestamptz NOT NULL,
  UNIQUE (account_low, account_high),
  CHECK (account_low < account_high)
);

CREATE TABLE messages (
  id          uuid PRIMARY KEY,
  match_id    uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  author_id   uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  body        text NOT NULL,
  created_at  timestamptz NOT NULL
);
CREATE INDEX messages_by_match ON messages (match_id, created_at);

CREATE TABLE blocks (
  blocker     uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  blocked     uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL,
  PRIMARY KEY (blocker, blocked),
  CHECK (blocker <> blocked)
);

CREATE TABLE reports (
  id          uuid PRIMARY KEY,
  reporter    uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  target      uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  reason      text NOT NULL,
  message_id  uuid,                             -- optional reference only; no text is copied
  state       text NOT NULL DEFAULT 'pending_review',
  created_at  timestamptz NOT NULL
);

-- Bounded security audit: kind and time only, never profile text, messages or proofs.
CREATE TABLE audit_events (
  id          uuid PRIMARY KEY,
  account_id  uuid,
  kind        text NOT NULL,
  created_at  timestamptz NOT NULL
);
