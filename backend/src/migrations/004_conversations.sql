-- How far each person has read each conversation (unread counts, "Your turn",
-- and read receipts when both people share them).
CREATE TABLE match_reads (
  match_id    uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  account_id  uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  read_at     timestamptz NOT NULL,
  PRIMARY KEY (match_id, account_id)
);

-- Read receipts and typing are shown only when both people turn this on.
ALTER TABLE accounts ADD COLUMN share_read_receipts boolean NOT NULL DEFAULT false;
