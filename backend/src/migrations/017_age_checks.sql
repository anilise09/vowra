-- Age checks through an outside provider. Vawra keeps the outcome and the age
-- it confirms, never documents, photos or a date of birth. The reference
-- given to the provider is stored only as a keyed hash.
CREATE TABLE age_checks (
  id              uuid PRIMARY KEY,
  account_id      uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  reference_hash  text NOT NULL UNIQUE,
  status          text NOT NULL CHECK (status IN ('started','passed','failed','review')),
  verified_age    integer CHECK (verified_age BETWEEN 18 AND 120),
  created_at      timestamptz NOT NULL,
  decided_at      timestamptz
);
CREATE INDEX age_checks_account ON age_checks (account_id, created_at);
