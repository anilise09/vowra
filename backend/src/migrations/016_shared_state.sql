-- State that several servers share. Who has the app open: one row per open
-- live-update stream, refreshed by its heartbeat; a server that stops without
-- saying leaves rows the hourly job removes.
CREATE TABLE stream_presence (
  stream_id    uuid PRIMARY KEY,
  account_id   uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  instance_id  text NOT NULL,
  seen_at      timestamptz NOT NULL
);
CREATE INDEX stream_presence_account ON stream_presence (account_id, seen_at);

-- Call setup messages, kept only while the call lasts. Unlogged: not written
-- to the crash log, and emptied if the database restarts.
CREATE UNLOGGED TABLE call_signals (
  seq         bigserial PRIMARY KEY,
  call_id     uuid NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
  sender      uuid NOT NULL,
  type        text NOT NULL,
  data        text NOT NULL,
  created_at  timestamptz NOT NULL
);
CREATE INDEX call_signals_call ON call_signals (call_id, seq);
