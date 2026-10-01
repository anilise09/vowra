-- Moderators prove a second factor (an authenticator app) before any
-- moderation action. The secret is sealed; last_step stops a code being used twice.
CREATE TABLE moderator_second_factor (
  account_id    uuid PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
  secret_sealed text NOT NULL,
  confirmed_at  timestamptz,
  last_step     bigint,
  created_at    timestamptz NOT NULL
);

-- A verified moderator sign-in stays verified for a short while; signing out ends it.
ALTER TABLE session_families ADD COLUMN mod_verified_until timestamptz;
