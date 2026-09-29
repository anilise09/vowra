-- Photos in a conversation. The receiver opts in per match; each photo is
-- reviewed like a profile photo and becomes a message only once approved.
ALTER TABLE media DROP CONSTRAINT media_audience_check;
ALTER TABLE media ADD CONSTRAINT media_audience_check CHECK (audience IN ('profile','conversation'));
ALTER TABLE media ADD COLUMN match_id uuid REFERENCES matches(id) ON DELETE CASCADE;

ALTER TABLE messages ADD COLUMN media_id uuid REFERENCES media(id) ON DELETE SET NULL;

-- account_id allows photos from the other person in match_id.
CREATE TABLE photo_consent (
  match_id    uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  account_id  uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL,
  PRIMARY KEY (match_id, account_id)
);
