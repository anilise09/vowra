# Account data lifecycle and location contract

Status: design contract only. No production account, export worker, deletion job, location collection, privacy-zone service, or network client exists.

## Principles

- Pause, export, and deletion apply to the authenticated account only; no caller-supplied account ID is accepted.
- Export and deletion require recent reauthentication. A local button or cached session state is never authority.
- Retention periods and deletion-recovery windows are server configuration reviewed with privacy counsel; the client never hardcodes or promises a duration.
- Deletion removes ordinary product data. Narrow abuse-prevention evidence may be retained only under a documented lawful purpose, access policy, and expiry schedule.
- Precise location never appears in a public profile, API response, log, analytic event, notification, or support view.

## Pause and resume

`POST /v1/me/pause` removes the account from discovery and stops new likes, matches, non-safety notifications, and call invitations before returning success. Existing conversations become unavailable to the paused account, but block/report and account controls remain reachable. Pause does not erase data or cancel a store subscription; those facts are disclosed separately.

`DELETE /v1/me/pause` resumes only after the server repeats age, moderation, session, and eligibility checks. A client cannot set lifecycle state directly.

## Data export

`POST /v1/me/exports` creates one bounded export request after recent reauthentication and rate limiting. The export excludes other people's private data, internal anti-abuse logic, raw identity/age-assurance artifacts not legally exportable, and secrets. Conversation data is scoped to the requesting participant and applicable law.

The client receives an opaque request ID and state. A ready export is downloaded through a short-lived, single-use authenticated endpoint; a permanent public URL is never returned or logged. Export archives are encrypted at rest, expire automatically, and are removed after the configured window.

## Deletion

`POST /v1/me/deletion` schedules deletion after recent reauthentication and returns the server-configured effective time. Scheduling immediately pauses discovery/contact, revokes provider-link attempts, and queues session revocation. The client displays the server time rather than assuming a recovery window.

`DELETE /v1/me/deletion` cancels only while the server says the request is reversible and requires reauthentication. After deletion becomes effective, recovery must not silently reconstruct the account from analytics, backups, purchase records, or another person's conversation copy.

Backups age out under a documented schedule and are not restored selectively for ordinary product use. Legal holds and narrowly retained abuse evidence are segregated, access-controlled, audited, purpose-limited, and automatically reviewed for expiry. They cannot reactivate or rediscover the deleted account.

## Location and privacy zones

Location is optional until a reviewed product flow explicitly requires it. Permission denial leaves safe non-location account controls usable. A future client encrypts an exact sample to a pinned server key before transport; `EncryptedLocationEnvelope` contains ciphertext, key ID, and capture time, never latitude/longitude fields.

The server rejects stale/replayed samples, decrypts only in the location service, stores exact coordinates encrypted with restricted access, and returns only a coarse distance band plus discoverability/privacy-zone flags. It applies minimum band sizes, jitter or bucketing, query-rate limits, movement plausibility, and privacy zones to resist triangulation. Other clients never receive exact coordinates, exact distance, precise last-seen location, home/work zone geometry, or raw history.

Deleting or pausing an account removes it from location-backed discovery immediately. Exact history follows the deletion schedule unless a documented safety/legal exception applies.

## Authorization and audit

Every lifecycle operation binds to the validated session account and records a bounded security audit event without profile text, message bodies, coordinates, identity artifacts, or provider proofs. Support tooling cannot bypass reauthentication or change deletion/age/moderation state without a separately authorized, audited procedure.

Before implementation: obtain legal retention decisions by region, write the data inventory and processor list, choose export encryption and location-envelope designs, specify recovery windows and backup expiry, add concurrent-state/idempotency tests, and complete privacy/security review.
