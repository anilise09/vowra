-- Six-digit sign-in codes: each is found by the requesting device's state and
-- allows a few attempts before it is spent. The code itself is stored only as
-- a keyed hash (HMAC with the lookup key, bound to the request id).
ALTER TABLE auth_requests ADD COLUMN attempts integer NOT NULL DEFAULT 0;
CREATE INDEX auth_requests_open_state ON auth_requests (state_nonce) WHERE used_at IS NULL;
