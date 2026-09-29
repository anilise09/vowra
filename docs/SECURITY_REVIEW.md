# Security review

Review 1: 2026-09-29, by the Claude Code session that built the server (BE-1 to BE-13), against the
code at that date. This is an internal engineering review, not an independent audit or pen test;
both remain launch gates (`docs/ROADMAP.md`, Phase 6).

Each area lists what was checked in the code, what was found, and what happened. "Fixed" items
landed in BE-13 with tests.

## Authentication and sessions

Checked: passwordless sign-in with PKCE (S256), one-time proofs stored only as SHA-256 hashes,
10-minute proof lifetime, the same response whether or not an account exists, per-identifier (5)
and per-network (30) request limits per 15 minutes, 15-minute access tokens and single-use refresh
tokens stored hashed, reuse of an old refresh token revoking the whole sign-in, a recent sign-in
(10 minutes) for deletion, export and moderation decisions.

Found and fixed:
- Signing out ended only the current token record; the sign-in chain stayed, so signed-out devices
  left rows forever. Sign-out now ends the chain (`DELETE /v1/session`).
- A sign-in on an abandoned device never expired. A device unused for 90 days now signs in again
  (retention job).
- The in-memory rate limiter never forgot keys, so many distinct keys could grow memory without end.
  It now forgets finished windows.

Accepted:
- Rotated refresh-token records are kept 30 days for reuse detection; an older stolen token is
  refused as unknown instead of also revoking the sign-in.

Open:
- The rate limiter lives in one process's memory. Running more than one server needs a shared
  store (for example the database or Redis) before scaling out.
- No sign-up friction beyond the email code (no device attestation such as Play Integrity or App
  Attest). Needed before launch against bot sign-ups.

## Access control

Checked: every route derives the account from the session, never from a client ID; per-object
checks for matches, messages, photos, reports and appeals; blocked, paused, suspended and deleting
accounts drop out of Discover, Likes you, chat and photo links; moderator routes answer 404 to
members; moderators cannot act on their own reports, photos or appeals, and a second moderator
decides an appeal. Tests cover each (backend/test).

Found: nothing new beyond what earlier checkpoints fixed (the `elig_` alias leak, BE-5).

## Abuse and rate limits

Checked: messages (5 a minute), Super Likes (3 a day), photo uploads (30 a day), location (one new
area per 15 minutes), data exports (5 a day), live-update streams (5 per account), sign-in requests.

Found and fixed:
- Likes had no limit, so a bot could like everyone. Likes and Super Likes now stop at 300 a day
  (`429 like_limit`); passes are free.
- Reports had no limit, so one account could flood the moderation queue. Reports now stop at 20 a
  day (`429 report_limit`); blocking stays unlimited.

## Input and output

Checked: every body is a strict zod schema (unknown fields rejected), 64 KB JSON limit, bounded
string lengths, photos only through the media pipeline (signature check, pixel cap, re-encode,
metadata removed), generic error bodies with a request id and no stack traces, JSON parse errors as
400.

Found and fixed:
- JSON responses had no cache or content-type protection. Every response now carries
  `X-Content-Type-Options: nosniff`, and `Cache-Control: no-store` unless a route sets its own
  (photo links use `private, max-age=300`).

## Data protection

Checked: emails and approximate areas sealed with AES-256-GCM; email lookups by keyed HMAC; keys
from the environment and refused if not 32 bytes; logs redact authorization headers and drop query
strings (upload grants and photo links never reach logs); exports hold only the person's own data;
the retention schedule and seven-day backup rotation (`docs/RECOVERY.md`).

Found and fixed:
- Android's default backup was on, so sign-in tokens and cached data could go to cloud backups or a
  device-to-device transfer. Backup and transfer are now off (`allowBackup="false"` and
  `data_extraction_rules.xml`); signing in again on a new phone restores the account from the server.

Accepted, recorded as a product decision:
- Messages are stored readable by the server, not end-to-end encrypted, so moderators can see the
  one message a report points at. Revisit with legal and safety review.

Open:
- Development backups are not encrypted as files (their emails and areas are sealed, names and
  messages are not). Production must use the host's encrypted backups.

## Transport

Checked: the server binds to 127.0.0.1 by default. Release builds get the platform default that
blocks plain HTTP (Android 9+ and iOS App Transport Security); only debug and profile builds carry a
network setting that allows plain HTTP to local test addresses.

Open:
- Production needs HTTPS in front of the server (the host's TLS terminator) and HSTS. Certificate
  pinning in the app is a later decision; it complicates key rotation.

## Dependencies

Checked: `npm audit --omit=dev` reports 0 vulnerabilities (2026-09-29). Flutter dependencies are
from pub.dev with a committed lockfile.

Open:
- Add automated dependency alerts (for example Dependabot on the GitHub repository) and review
  them at each checkpoint.

## Still to do before launch

An independent penetration test, a threat-model review with the chosen providers (email, storage,
scanning, push, calls), the device-attestation decision, the shared rate-limit store, production
HTTPS and backups, and a staff sign-in for moderators separate from member accounts.
