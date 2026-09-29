-- Voice and video calls. Nothing about a call's content is stored: only who
-- called whom, the kind, when it rang, was answered and ended, and how.

-- Each person says per match that they are open to a call.
CREATE TABLE call_readiness (
  match_id    uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  account_id  uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL,
  PRIMARY KEY (match_id, account_id)
);

CREATE TABLE calls (
  id           uuid PRIMARY KEY,
  match_id     uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  caller       uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  callee       uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  kind         text NOT NULL CHECK (kind IN ('video','audio')),
  state        text NOT NULL CHECK (state IN ('ringing','active','ended','declined','missed','cancelled')),
  created_at   timestamptz NOT NULL,
  answered_at  timestamptz,
  ended_at     timestamptz,
  end_reason   text
);
CREATE INDEX calls_live ON calls (caller, callee) WHERE state IN ('ringing','active');
CREATE INDEX calls_by_caller ON calls (caller, created_at);
