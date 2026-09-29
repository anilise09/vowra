-- Moderation: moderators, suspensions and appeals. Decision notes and who
-- decided are internal: never returned to members or put in their export.
ALTER TABLE accounts ADD COLUMN role text NOT NULL DEFAULT 'member'
  CHECK (role IN ('member','moderator'));

ALTER TABLE accounts DROP CONSTRAINT accounts_lifecycle_check;
ALTER TABLE accounts ADD CONSTRAINT accounts_lifecycle_check
  CHECK (lifecycle IN ('active','paused','deletion_scheduled','suspended'));
ALTER TABLE accounts ADD COLUMN suspended_at timestamptz;
ALTER TABLE accounts ADD COLUMN suspension_reason text;
ALTER TABLE accounts ADD COLUMN suspended_by uuid REFERENCES accounts(id) ON DELETE SET NULL;
ALTER TABLE accounts ADD COLUMN lifecycle_before_suspension text;

-- reports.state: pending_review, dismissed, or actioned (the account was suspended).
ALTER TABLE reports ADD COLUMN decided_at timestamptz;
ALTER TABLE reports ADD COLUMN decided_by uuid REFERENCES accounts(id) ON DELETE SET NULL;
ALTER TABLE reports ADD COLUMN decision_note text;

CREATE TABLE appeals (
  id            uuid PRIMARY KEY,
  account_id    uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  message       text NOT NULL,
  state         text NOT NULL DEFAULT 'open' CHECK (state IN ('open','upheld','overturned')),
  created_at    timestamptz NOT NULL,
  decided_at    timestamptz,
  decided_by    uuid REFERENCES accounts(id) ON DELETE SET NULL,
  decision_note text
);
-- One open appeal per account at a time.
CREATE UNIQUE INDEX appeals_one_open ON appeals (account_id) WHERE state = 'open';
