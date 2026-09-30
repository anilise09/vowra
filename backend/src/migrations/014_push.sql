-- Push notifications. A device token belongs to one sign-in (session family):
-- signing out, a suspension or deletion ends it at once. Tokens are sealed;
-- the lookup is an HMAC so the same phone registering again replaces its row.
CREATE TABLE devices (
  id            uuid PRIMARY KEY,
  account_id    uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  family_id     uuid NOT NULL REFERENCES session_families(id) ON DELETE CASCADE,
  platform      text NOT NULL CHECK (platform IN ('android','ios')),
  token_sealed  text NOT NULL,
  token_lookup  text NOT NULL UNIQUE,
  created_at    timestamptz NOT NULL,
  last_seen_at  timestamptz NOT NULL
);
CREATE INDEX devices_account ON devices (account_id);

-- What someone wants to be told about when the app is closed. No row means all on.
CREATE TABLE notification_prefs (
  account_id  uuid PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
  matches     boolean NOT NULL DEFAULT true,
  messages    boolean NOT NULL DEFAULT true,
  likes       boolean NOT NULL DEFAULT true,
  calls       boolean NOT NULL DEFAULT true,
  updated_at  timestamptz NOT NULL
);
