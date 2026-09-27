-- Scheduled deletion (docs/DATA_LIFECYCLE_CONTRACT.md). The grace period is
-- server configuration; the account is removed by the deletion job.
ALTER TABLE accounts DROP CONSTRAINT accounts_lifecycle_check;
ALTER TABLE accounts ADD CONSTRAINT accounts_lifecycle_check
  CHECK (lifecycle IN ('active','paused','deletion_scheduled'));
ALTER TABLE accounts ADD COLUMN deletion_effective_at timestamptz;
-- What to return to if the person keeps their account.
ALTER TABLE accounts ADD COLUMN lifecycle_before_deletion text;
