# Account data lifecycle and location contract

Status: pause, deletion, data export, approximate area and privacy zones are implemented (the server is switched off and never deployed).

## Principles

- Pause, export, and deletion apply to the authenticated account only; no caller-supplied account ID is accepted.
- Export and deletion require recent reauthentication. A local button or cached session state is never authority.
- Retention periods and deletion-recovery windows are server configuration reviewed with privacy counsel; the client never hardcodes or promises a duration.
- Deletion removes ordinary product data. Narrow abuse-prevention evidence may be retained only under a documented lawful purpose, access policy, and expiry schedule.
- Precise location never appears in a public profile, API response, log, analytic event, notification, or support view.

## Pause and resume

`POST /v1/me/pause` removes the account from discovery and stops new likes, matches, non-safety notifications, and call invitations before returning success. Existing conversations stay available to both people, and block/report and account controls remain reachable.

Decision (2026-09-27, BE-2): pause keeps existing chats. Pausing is a break from meeting new people, not from people already matched; this is what the app has always told people ("Your matches can still message you") and how leading dating apps treat pausing. Anyone who wants no contact at all can unmatch, block, or delete the account. Pause does not erase data or cancel a store subscription; those facts are disclosed separately.

`DELETE /v1/me/pause` resumes only after the server repeats age, moderation, session, and eligibility checks. A client cannot set lifecycle state directly.

## Data export

`POST /v1/me/exports` creates one bounded export request after recent reauthentication and rate limiting. The export excludes other people's private data, internal anti-abuse logic, raw identity/age-assurance artifacts not legally exportable, and secrets. Conversation data is scoped to the requesting participant and applicable law.

Implemented 2026-09-28 (BE-9) as a smaller first step: `GET /v1/me/export` returns the JSON directly, because the server stores no photos or other media yet and a person's data is a few kilobytes. It needs a sign-in within the reauthentication window (the same check as deletion), allows 5 copies per rolling day (`429 rate_limited` after), is sent with `Cache-Control: no-store`, is recorded as a `data_exported` audit event (kind and time only), and still works while deletion is pending. It contains the account (email opened from its sealed copy, dates, age and lifecycle states, and any suspension with its reason and the person's own appeals), the full own profile including the private "Show me", own swipes with kind and time only, matches with the other person's display name and only the messages the person sent, blocks and reports made (dates, reasons, states; no target), sign-ins and security events. It leaves out other people's messages, profiles and account IDs, the person's own account ID, email lookup keys, tokens and proofs, and internal moderation notes. The asynchronous archive below replaces it once media is stored.

The client receives an opaque request ID and state. A ready export is downloaded through a short-lived, single-use authenticated endpoint; a permanent public URL is never returned or logged. Export archives are encrypted at rest, expire automatically, and are removed after the configured window.

## Deletion

`POST /v1/me/deletion` schedules deletion after recent reauthentication and returns the server-configured effective time. Scheduling immediately pauses discovery/contact, revokes provider-link attempts, and queues session revocation. The client displays the server time rather than assuming a recovery window.

Implemented (BE-3b): "recent" means a sign-in (a new session family) within `VAWRA_REAUTH_WINDOW`, default 10 minutes; otherwise the answer is `403 reauthentication_required` and the app asks for a new email code. Scheduling revokes every session, this device included, hides the account from discovery, likes-you and match lists, and closes its conversations for the other person. The grace period is `VAWRA_DELETION_GRACE`, a 7-day placeholder until counsel sets it. Resuming from pause cannot undo a scheduled deletion. An hourly job then deletes the account row, which cascades to the profile, sessions, swipes, blocks, reports, and every match with both people's messages; audit rows lose the account id and pending sign-in requests for the email are removed.

Open decision for counsel: reports filed against a deleted account are removed with it today. Keeping narrow abuse evidence needs the documented purpose, access policy and expiry described below before it is built.

`DELETE /v1/me/deletion` cancels only while the server says the request is reversible and requires reauthentication. After deletion becomes effective, recovery must not silently reconstruct the account from analytics, backups, purchase records, or another person's conversation copy.

Backups age out under a documented schedule and are not restored selectively for ordinary product use. Legal holds and narrowly retained abuse evidence are segregated, access-controlled, audited, purpose-limited, and automatically reviewed for expiry. They cannot reactivate or rediscover the deleted account.

## Retention schedule (implemented BE-13, 2026-09-29; values pending legal review)

An hourly job (`backend/src/jobs/retention.ts`) removes what is no longer needed:

| What | Kept for | Why |
|---|---|---|
| Used or expired sign-in codes | 1 day | nothing needs them afterwards |
| Sign-in throttle counters (HMAC keys only) | 1 day | abuse protection across server instances |
| Ended sign-ins (signed out, deleted, suspended) | 30 days | investigating account takeovers |
| Rotated session records | 30 days | detecting reuse of an old refresh token |
| A sign-in on a device unused for 90 days | ends | the device signs in again |
| Photo uploads never sent | 1 day | an abandoned grant |
| Rejected photo records (files deleted at once) | 90 days | answering a question about the rejection |
| Call records (the two people, kind, times, outcome; never content) | 90 days | answering a report about a call |
| Call setup messages | until the call ends, in memory only | connecting the call |
| Security audit events (kind and time only) | 365 days | investigating abuse |
| Decided reports and appeals, with notes | 730 days | repeat-abuse history |

Backups are rotated after seven days (`docs/RECOVERY.md`), so deleted data leaves them too.

## Location and privacy zones

Location is optional until a reviewed product flow explicitly requires it. Permission denial leaves safe non-location account controls usable. A future client encrypts an exact sample to a pinned server key before transport; `EncryptedLocationEnvelope` contains ciphertext, key ID, and capture time, never latitude/longitude fields.

The server rejects stale/replayed samples, decrypts only in the location service, stores exact coordinates encrypted with restricted access, and returns only a coarse distance band plus discoverability/privacy-zone flags. It applies minimum band sizes, jitter or bucketing, query-rate limits, movement plausibility, and privacy zones to resist triangulation. Other clients never receive exact coordinates, exact distance, precise last-seen location, home/work zone geometry, or raw history.

Implemented 2026-09-28 (BE-10) as a stricter first step than the envelope above: the exact position never leaves the phone. The app asks Android for coarse location only (never precise or background; the plugin's background-service permission is removed from the manifest), and only when the person turns Distance on in Settings. The phone rounds the position to the centre of a grid cell about 2 km across (`lib/domain/location_grid.dart`) and sends that centre with `PUT /v1/me/location`; the server rounds again with the identical grid (`backend/src/location.ts`), so even a modified client cannot store an exact point, and seals the cell with the data key. Other people get only a band computed between cell centres (under 5, 5-10, 10-25, 25-50, 50-100, over 100 km), and only when both people have an area and the viewed person's "show a coarse distance band" is on; no coordinates, sealed values or exact distances are returned. Against triangulation: the 2 km cell, wide bands, a new area at most every 15 minutes (`429 slow_down`), and a refusal of moves faster than 1000 km/h (`422 implausible_move`). `DELETE /v1/me/location` removes the area at once; the area is part of the profile row, so account deletion removes it; the person's own export includes the cell. While on, the app refreshes the area quietly at start with the permission already given, never prompting. Privacy zones were implemented 2026-09-29 (BE-14) on the phone only: up to three private places, stored encrypted on the phone and never sent. Within about 3 km of one, the app sends no area and removes the one on the server, so distance is hidden there; away from them it works as usual. Settings shows "Hidden right now: you're at a private place".

Deleting or pausing an account removes it from location-backed discovery immediately. Exact history follows the deletion schedule unless a documented safety/legal exception applies.

## Authorization and audit

Every lifecycle operation binds to the validated session account and records a bounded security audit event without profile text, message bodies, coordinates, identity artifacts, or provider proofs. Support tooling cannot bypass reauthentication or change deletion/age/moderation state without a separately authorized, audited procedure.

Before implementation: obtain legal retention decisions by region, write the data inventory and processor list, choose export encryption and location-envelope designs, specify recovery windows and backup expiry, add concurrent-state/idempotency tests, and complete privacy/security review.
