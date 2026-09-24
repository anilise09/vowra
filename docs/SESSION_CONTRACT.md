# Session and account-recovery contract

Status: design contract only. No authentication provider, production account, recovery delivery, network client, or credential storage is enabled.

## Goals

- Passwordless email and reviewed OIDC providers can establish a revocable server session.
- Unknown and known account identifiers receive the same public response shape and wording.
- Provider proofs are one-time, short-lived, audience-bound, state-bound, and PKCE-bound.
- Session rotation limits replay; revocation and sign-out-everywhere take effect before success is reported.
- Recovery cannot silently replace age assurance, identity evidence, blocks, moderation state, or verified purchase ownership.

## Public initiation

`POST /v1/auth/requests` accepts an identifier and purpose (`sign_in` or `recovery`). The public success response is always:

```json
{"message":"If the account can continue, instructions will be sent."}
```

The response never contains `account_exists`, account ID, provider enrollment, age/verification status, or a different message for unknown accounts. Rate limiting combines identifier, device-risk, and network signals without returning an existence oracle. Delivery is asynchronous and contains a short-lived, single-use proof.

## Provider exchange

`POST /v1/auth/exchange` accepts a passwordless or OIDC authorization code, PKCE verifier, and state nonce in the request body. Proofs never appear in a query string, logs, analytics, crash reports, clipboard, or local persistence. The server validates issuer, audience, redirect URI, nonce/state, PKCE, expiry, and one-time use before issuing a session.

OIDC email claims alone do not merge accounts. Linking another provider requires an authenticated, recently reauthenticated session and confirmation through the existing account channel. Provider subject identifiers are scoped to the issuer and stored encrypted where feasible.

## Session lifecycle

- Access credentials are short-lived and held only in platform-protected storage by a future client implementation.
- Rotation is single-use: accepting a new refresh credential revokes its predecessor. Reuse revokes the credential family and requires reauthentication.
- The client receives opaque session/account IDs, expiry, and state only. It does not receive password hashes, provider tokens, recovery secrets, or risk scores.
- Sensitive operations require recent reauthentication even when the base session is active.
- Server authorization is repeated on every request; a locally cached `active` state is never authority.

`POST /v1/session/rotate` rotates the current credential family. `DELETE /v1/session` revokes the current session. `DELETE /v1/sessions` revokes every session for the authenticated account, including the caller, before returning success.

## Recovery

Recovery starts through the same non-enumerating request endpoint. Completion requires a short-lived single-use proof and risk checks; suspicious cases fail safely or enter human review. Recovery revokes existing sessions and pending provider-link attempts. It does not change date of birth, age-assurance status, identity verification, blocks, reports, moderation actions, or entitlements.

No knowledge-based questions, security questions, phone-number exposure, support-agent plaintext secrets, or recovery codes stored in plaintext are allowed. If recovery codes are added later, show them once, store only strong hashes, make each code single-use, and require explicit regeneration to invalidate the remaining set.

## Client behavior

The Dart contract redacts identifiers and provider secrets from `toString()`. `UnconfiguredSessionApi` fails every operation; the prototype must never display a local login, rotation, logout, or recovery action as server-confirmed.

Before implementation: choose providers, define cookie/token storage per platform, complete account-linking and takeover threat models, specify expiry/rate limits, add concurrent-rotation and replay tests, add cross-account authorization tests, and complete privacy/security review.
