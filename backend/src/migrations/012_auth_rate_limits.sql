-- One atomic counter per sign-in identifier or network, shared by server instances.
-- Keys are HMAC lookups; email addresses and IP addresses are never stored here.
CREATE TABLE auth_rate_limit_windows (
  key_hash text PRIMARY KEY,
  window_start timestamptz NOT NULL,
  hits integer NOT NULL CHECK (hits > 0)
);
CREATE INDEX auth_rate_limit_windows_started ON auth_rate_limit_windows (window_start);
