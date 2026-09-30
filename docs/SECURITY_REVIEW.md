# Security review

Review 1: 2026-09-29, by the Claude Code session that built the server (BE-1 to BE-13), against the
code at that date. This is an internal engineering review, not an independent audit or pen test;
both remain launch gates (`docs/ROADMAP.md`, Phase 6).

Each area lists what was checked in the code, what was found, and what happened. "Fixed" items
landed in BE-13 with tests.

## Authentication and sessions

Checked: passwordless sign-in with PKCE (S256), six-digit one-time codes found by the requesting
device's state and stored only as a keyed hash (HMAC with the lookup key, bound to the request),
five tries per code before it is spent, the same answer when an email cannot be sent,
10-minute code lifetime, the same response whether or not an account exists, per-identifier (5)
and per-network (30) request limits per 15 minutes, 15-minute access tokens and single-use refresh
tokens stored hashed, reuse of an old refresh token revoking the whole sign-in, a recent sign-in
(10 minutes) for deletion, export and moderation decisions.

Found and fixed:
- Signing out ended only the current token record; the sign-in chain stayed, so signed-out devices
  left rows forever. Sign-out now ends the chain (`DELETE /v1/session`).
- A sign-in on an abandoned device never expired. A device unused for 90 days now signs in again
  (retention job).
- The in-memory rate limiter never forgot keys, so many distinct keys could grow memory without end.
  BE-13 made it forget finished windows; BE-20 replaced it with bounded database counters.

Accepted:
- Rotated refresh-token records are kept 30 days for reuse detection; an older stolen token is
  refused as unknown instead of also revoking the sign-in.

Open:
- Sign-in throttling now uses atomic database counters shared by server instances (BE-20),
  with HMAC keys for identifiers and networks and one-day cleanup. A multi-host staging
  run on production PostgreSQL is still required before scaling out.
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

## Calls (added BE-18 and BE-19)

Checked:
- A call needs an open conversation and both people's yes for that match. It ends at once on a
  block, unmatch, suspension, deletion request or taking back readiness. Every call request also
  re-checks the conversation, so a missed hook still ends the call.
- Setup messages go only to the other person, stay in server memory only, are dropped when the
  call ends, and are limited in size (20,000 characters) and number (400 per person per call).
  The live-update nudge carries only the call's id. Nothing about a call's content is stored.
- Production is relay-only (`iceTransportPolicy: relay` with per-person TURN credentials that
  last two hours), so neither phone learns the other's IP address. Direct calls exist only behind
  `VAWRA_CALLS_DEV_P2P=1`.
- The app asks for the camera and microphone only when a call starts or is answered, and the
  merged Android manifest adds nothing beyond CAMERA, RECORD_AUDIO, MODIFY_AUDIO_SETTINGS and
  ACCESS_NETWORK_STATE (an install-time permission WebRTC needs; without it the app aborted as a
  call connected). `test/android_manifest_test.dart` pins the exact list.
  Leaving the call page in any way ends the call.

Open:
- TURN credentials cannot be revoked before they expire; a blocked person keeps a working relay
  login for up to two hours, though no call reaches the blocker. Shorter credentials or a relay
  with revocation can close this.
- WebRTC encrypts media between the phones (DTLS-SRTP); the relay cannot read it. The app does
  not yet show a safety number to compare, which only matters against a malicious server.

## Dependencies

Checked: `npm audit --omit=dev` reports 0 vulnerabilities (2026-09-29). Flutter dependencies are
from pub.dev with a committed lockfile.

Open:
- Add automated dependency alerts (for example Dependabot on the GitHub repository) and review
  them at each checkpoint.

## Still to do before launch

An independent penetration test, a threat-model review with the chosen providers (email, storage,
scanning, push, calls), the device-attestation decision, a multi-host rate-limit test, production
HTTPS and backups, and a staff sign-in for moderators separate from member accounts.
