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

The client contract in `ProfileMutation` intentionally cannot send age, date of birth, coordinates, account ID, verification, entitlement, match, block, or moderation state. The server repeats all public-text validation, normalizes bounded fields, and applies rate limits. A successful edit does not prove adulthood or unlock dating features.

## Age and identity

Typing an adult age in the app is user input, not age assurance. Dating features remain denied until the server records a successful result from a reviewed regional age-assurance flow. The app receives only one of `assurance_required`, `pending_review`, `adult_verified`, or `rejected`; it never receives evidence documents or biometric material from the service.

Photo or optional ID verification can establish limited claims such as likeness or document checks. It must never be presented as proof that a person is safe. Raw provider artifacts, secrets, and signing keys stay out of the client.

## Location

Profile mutation contains no location. A later dedicated location endpoint may accept a short-lived encrypted update after explicit permission. Exact coordinates remain encrypted at rest, are never returned to another client, and are converted server-side to coarse distance bands with privacy zones and anti-triangulation controls.

## Authorization invariants for later contracts

- Discovery returns only mutually eligible accounts and excludes either-direction blocks.
- Likes are idempotent; only two authorized reciprocal likes create one match.
- Messages require both participants, an active match, and no either-direction block. Messaging and safety controls remain free.
- Block is a server transaction that immediately fans out across discovery, matches, chat delivery, notifications, and call tokens before reporting success.
- Call tokens are short-lived, participant-bound, match-bound, and issued only after current mutual readiness and acceptance checks.
- Entitlements come only from verified store/provider records. They cannot grant messaging, reporting, blocking, or other safety access.
- Moderation access is least-privilege and audited; ordinary analytics never receive message bodies, identity evidence, precise location, or call content.

## Failure behavior

The client fails closed when the service is unavailable, the session is invalid, age assurance is incomplete, or the server rejects a mutation. It may keep the existing memory-only synthetic prototype available in development builds, but it must never display a local write as a persisted account change.

Before a real implementation: choose providers, define retention/deletion and recovery, threat-model sessions and account takeover, specify request/response schemas and rate limits, add cross-account authorization tests, and complete privacy/security review.

## Media boundary

Profile and matched-conversation media follow `MEDIA_UPLOAD_CONTRACT.md`. The authenticated client may
request only a short-lived, single-object quarantine upload grant. It never receives bucket credentials,
storage keys, permanent URLs, or authority to choose moderation state. Every status, delivery, attach,
replace, reorder, and delete operation is reauthorized against the session account and current audience.
Only server-approved media may be displayed.
