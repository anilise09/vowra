-- Profile photos. Nothing is visible to anyone else until a moderator
-- approves it. Only the processed image is stored (metadata stripped); the
-- uploaded original is never kept.
CREATE TABLE media (
  id               uuid PRIMARY KEY,
  owner            uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  audience         text NOT NULL DEFAULT 'profile' CHECK (audience IN ('profile')),
  state            text NOT NULL
                   CHECK (state IN ('awaiting_upload','pending_review','approved','rejected')),
  client_upload_id text NOT NULL,
  mime_type        text NOT NULL,
  byte_length      integer NOT NULL,
  sha256           text NOT NULL,
  grant_hash       text,                 -- single-use upload grant, hashed
  grant_expires_at timestamptz,
  position         integer NOT NULL DEFAULT 0,
  width            integer,
  height           integer,
  reject_reason    text,
  created_at       timestamptz NOT NULL,
  decided_at       timestamptz,
  decided_by       uuid REFERENCES accounts(id) ON DELETE SET NULL,
  UNIQUE (owner, client_upload_id)
);
CREATE INDEX media_by_owner ON media (owner, position);
CREATE INDEX media_pending ON media (state, created_at);
