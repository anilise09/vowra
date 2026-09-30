# Backend account and profile contract

Status: design contract only. No production service, network client, authentication provider, age-assurance provider, or real-user data collection exists.

## Trust boundary

The mobile client is untrusted. The server derives the acting account from a validated, revocable session; an account identifier supplied by a client never grants access. Age, identity, verification, location, entitlement, match, message, call, and block claims require server-side authorization from their own authoritative records.

Opaque identifiers are random and non-enumerable. Every object lookup still checks ownership or participation; opacity is not authorization. Responses and logs use stable error codes and request IDs without leaking whether another account exists.

## First endpoints

### `GET /v1/me/profile`

Returns only the authenticated account's profile. There is no account ID path or query parameter. The response may include a server-calculated public age and an age-access state, but never date of birth, age-assurance evidence, precise coordinates, private identity evidence, provider tokens, or internal moderation signals.

### `PATCH /v1/me/profile`

Accepts only:

- `display_name`
- `relationship_intent`
- `bio`
- `interests`
- `show_distance_band`
- `call_ready_by_default`
- `lifestyle`: optional habits, at most one answer per topic from fixed lists (drinking, smoking, exercise, pets; `lib/domain/lifestyle.dart`)
- `prompts`: up to two answers (1-150 characters, no control characters) to distinct questions from a fixed list (`lib/domain/profile_prompt.dart`)
- `gender`: one of `woman`, `man`, `nonbinary` (sent only once chosen; there is no "unset")
- `show_me`: any of the same values, de-duplicated and sorted; empty means everyone
- `show_gender`: whether `gender` appears to other people (default false)

Added 2026-09-28 (BE-8): discovery, swipes and "Likes you" require a two-way match of `gender` against `show_me` on both sides. `show_me` is sensitive (it can reveal orientation): it is returned only to its owner by `GET /v1/me/profile` and never to anyone else. Other people receive `gender` only when `show_gender` is true.

Added 2026-09-27 (BE-3c): habits and prompts are public profile details the person chooses to show, like the bio. Free text is limited to prompt answers and the bio; topics, answers and questions are fixed lists repeated on the server.

The client contract in `ProfileMutation` intentionally cannot send age, date of birth, coordinates, account ID, verification, entitlement, match, block, or moderation state. The server repeats all public-text validation, normalizes bounded fields, and applies rate limits. A successful edit does not prove adulthood or unlock dating features.

### `GET /v1/me/export`

A copy of what the server holds about the authenticated account (details and exclusions in `DATA_LIFECYCLE_CONTRACT.md`). Requires a recent sign-in (`403 reauthentication_required` otherwise) and allows 5 per day (`429 rate_limited`). Added 2026-09-28 (BE-9).

## Age and identity

Typing an adult age in the app is user input, not age assurance. Dating features remain denied until the server records a successful result from a reviewed regional age-assurance flow. The app receives only one of `assurance_required`, `pending_review`, `adult_verified`, or `rejected`; it never receives evidence documents or biometric material from the service.

Photo or optional ID verification can establish limited claims such as likeness or document checks. It must never be presented as proof that a person is safe. Raw provider artifacts, secrets, and signing keys stay out of the client.

## Location

Profile mutation contains no location. Added 2026-09-28 (BE-10): `PUT /v1/me/location` takes `{lat, lng}` (a cell centre from the app's 2 km grid; the server rounds again and seals it) and returns `{updated_at, cell_km}`, never the coordinates; `DELETE /v1/me/location` removes it. `GET /v1/me/profile` adds `location_updated_at` (null when off). Discovery and likes-you add `distance_band` (a string such as `"5–10 km away"`, or null). Limits: one new area per 15 minutes (`429 slow_down`), no moves over 1000 km/h (`422 implausible_move`). Details in `DATA_LIFECYCLE_CONTRACT.md`. A later dedicated location endpoint may accept a short-lived encrypted update after explicit permission. Exact coordinates remain encrypted at rest, are never returned to another client, and are converted server-side to coarse distance bands with privacy zones and anti-triangulation controls.

## Authorization invariants for later contracts

- Discovery returns only mutually eligible accounts and excludes either-direction blocks.
- Likes are idempotent; only two authorized reciprocal likes create one match.
- Messages require both participants, an active match, and no either-direction block. Messaging and safety controls remain free.
- Block is a server transaction that immediately fans out across discovery, matches, chat delivery, notifications, and call tokens before reporting success.
- Call tokens are short-lived, participant-bound, match-bound, and issued only after current mutual readiness and acceptance checks.
- Entitlements come only from verified store/provider records. They cannot grant messaging, reporting, blocking, or other safety access.
- Moderation access is least-privilege and audited; ordinary analytics never receive message bodies, identity evidence, precise location, or call content.

## Profile photos (added 2026-09-29, BE-12)

`POST /v1/me/photos` `{client_upload_id, mime_type (jpeg|png|webp), byte_length (<= 10 MB), sha256}` returns `{photo_id, upload_url, expires_at}`; the link works once, for 10 minutes. `PUT` the exact bytes there with the same content type. `GET /v1/me/photos` lists your photos with `state` (`pending_review`, `approved`, `rejected` with `reject_reason`); `PUT /v1/me/photos/order`, `DELETE /v1/me/photos/:id`. Discovery and likes-you add `photos: [{photo_id, url}]` (approved only, links for the viewer). `GET /v1/mod/photos` and `POST /v1/mod/photos/:id/decision` `{outcome: approved|rejected, reason?}` for moderators (recent sign-in, audited, never their own). Errors: `photo_limit`, `upload_limit`, `invalid_grant`, `size_mismatch`, `hash_mismatch`, `wrong_type`, `unreadable_image`. Details in `MEDIA_UPLOAD_CONTRACT.md`.

## Photos in a conversation (added 2026-09-29, BE-16)

`PUT /v1/matches/:id/photo-consent` `{allow}` sets whether you accept photos from the other person; `/v1/matches` adds `photos_allowed_by_me` and `photos_allowed_by_them`. `POST /v1/matches/:id/photos` (same body as profile photos) returns an upload grant when the other person allows photos, else `409 photos_not_allowed`. After moderator approval the photo is a message with `text: ""` and `photo: {url}`; the chat list shows "Photo". The moderator queue marks each photo `context: profile | chat`.

## Voice and video calls (added 2026-09-29, BE-18)

- `PUT /v1/matches/:id/call-ready` `{ready}`: you are open to calls in this conversation. `/v1/matches` adds `call_ready_by_me`, `call_ready_by_them` and a top-level `calls_available` (false while the server has no relay, so the app hides calls). Taking readiness back ends any live call in that conversation.
- `POST /v1/matches/:id/calls` `{kind: video|audio}` rings the other person. Needs an open conversation, both people ready (`409 not_ready`), nobody in either pair already in a call (`409 busy`) and at most 10 calls started per hour (`429 call_limit`); `503 calls_unavailable` without a relay. Returns `{call_id, match_id, kind, state, role, started_at, ice}`.
- `GET /v1/calls/:id`; `POST /v1/calls/:id/answer` and `/decline` (callee, while ringing, else `409 not_ringing`); `POST /v1/calls/:id/end` (either person; before an answer it is a cancel). A ring unanswered after 45 s is `missed`. States: `ringing`, `active`, `ended`, `declined`, `missed`, `cancelled`. The reason a call ended is never shown to the other person.
- `POST /v1/calls/:id/signals` `{type: offer|answer|candidate, data <= 20000 chars}` and `GET /v1/calls/:id/signals?after=<seq>` carry the phones' setup messages. They are held in server memory only, never stored, returned only to the other person, and dropped when the call ends; 400 per person per call (`429 slow_down`), `409 call_over` after the end. Each one sends the other person a `call` nudge with only `call_id`.
- `ice` is `{policy, servers}`. With `VAWRA_TURN_URLS` and `VAWRA_TURN_SECRET` set the policy is `relay`: all media goes through the TURN relay so neither person learns the other's IP address, with per-person credentials valid for two hours (TURN REST scheme). Without them calls are off, unless `VAWRA_CALLS_DEV_P2P=1` allows direct calls for development, which expose each phone's address to the other.
- A block, unmatch, suspension or deletion request ends live calls at once; every call step also re-checks that the conversation is still open. Nothing about a call's content is recorded: the record is the two people, kind, times and outcome, kept 90 days.

## Push notifications (added 2026-09-30, BE-24)

- `POST /v1/me/devices` `{platform: android|ios, token}` registers this phone for push and returns `{device_id}`. The token belongs to the current sign-in: signing out, suspension or deletion ends it, and the hourly job removes tokens of ended sign-ins. One device per sign-in; the same token registering again moves to the newest account; at most 10 devices per account. Tokens are stored sealed. `DELETE /v1/me/devices/:id` removes one.
- `GET /v1/me/notifications` and `PUT /v1/me/notifications` `{matches?, messages?, likes?, calls?}` (booleans; everything is on by default).
- A push goes out for a new like, a new match (to the person who did not make it), a new message (at most one per conversation a minute) and an incoming call, only when the person has no live connection (`/v1/events`), only for what they left on, and only to devices of a live sign-in on an active or paused account. The text never names anyone or quotes anything ("You have a new message"); a call is a silent high-priority message `{type: call, call_id, match_id}` that expires after 45 seconds. A token the push service reports as dead is deleted.
- Android through Firebase Cloud Messaging HTTP v1 (`VAWRA_FCM_CREDENTIALS_B64`, a service-account key); iPhone through APNs with a token key (`VAWRA_APNS_KEY_B64`, `VAWRA_APNS_KEY_ID`, `VAWRA_APNS_TEAM_ID`, `VAWRA_APNS_TOPIC`, `VAWRA_APNS_PRODUCTION=1`). Either may be left out; a half-set platform is refused at start.
- The data download adds `calls`, `notifications` and `push_devices` (platform and dates only).

## Moderation (added 2026-09-29, BE-11)

- `accounts.role` is `member` or `moderator`. Every `/v1/mod/*` route answers `404` to anyone who is not a moderator, so the console's existence is not revealed.
- `GET /v1/mod/reports`: pending reports, oldest first, never including reports filed by or about the moderator. Each shows the reason, the reported person's name, bio and status, how many reports concern them, how many reports the reporter has made, and only the one reported message (if the report pointed at one). The reporter is never identified.
- `POST /v1/mod/reports/:id/decision` `{outcome: dismissed|suspended, note?}`: needs a recent sign-in; `409 conflict_of_interest` for the moderator's own reports, `409 already_decided` for decided ones. Suspending sets `lifecycle = suspended`, revokes every session, closes their conversations (their matches' lists refresh), hides them from Discover and Likes you, and settles every open report about them as `actioned`. Someone already leaving or suspended keeps that state.
- `GET /v1/mod/appeals` and `POST /v1/mod/appeals/:id/decision` `{outcome: upheld|overturned, note?}`: needs a recent sign-in; the moderator who suspended the account cannot decide its appeal (`409 second_moderator_required`). Overturning restores the lifecycle the person had before.
- `POST /v1/me/appeal` `{message}` (1-1000 characters): only while suspended (`409 not_suspended`), one open appeal at a time (`409 appeal_open`).
- A suspended person can still sign in, read `GET /v1/me/profile` (with `suspension: {since, reason, appeal}`), download their data and ask for deletion; dating routes, pause and resume answer `409 account_suspended`. Asking for deletion and cancelling it does not lift a suspension.
- Decision notes and which moderator decided are internal: never returned to members or put in their export. Every decision and appeal is an audit event (kind and time only).

## Failure behavior

The client fails closed when the service is unavailable, the session is invalid, age assurance is incomplete, or the server rejects a mutation. It may keep the existing memory-only synthetic prototype available in development builds, but it must never display a local write as a persisted account change.

Before a real implementation: choose providers, define retention/deletion and recovery, threat-model sessions and account takeover, specify request/response schemas and rate limits, add cross-account authorization tests, and complete privacy/security review.

## Media boundary

Profile and matched-conversation media follow `MEDIA_UPLOAD_CONTRACT.md`. The authenticated client may
request only a short-lived, single-object quarantine upload grant. It never receives bucket credentials,
storage keys, permanent URLs, or authority to choose moderation state. Every status, delivery, attach,
replace, reorder, and delete operation is reauthorized against the session account and current audience.
Only server-approved media may be displayed.
