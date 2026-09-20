# Delivery roadmap

## Phase 0 — foundation (current)

Research, product contract, threat model, privacy inventory, Flutter workspace, CI, backend architecture. Exit: Android build works; iOS project is ready for later macOS validation.

## Phase 1 — offline clickable MVP

Design system; onboarding/age/rules; profile editor; synthetic discovery; match/chat/call-readiness UI; complete block/report/unmatch flows. Exit: automated tests and Android emulator walkthrough.

## Phase 2 — account and profile service

Passwordless/OIDC auth, sessions, PostgreSQL/PostGIS, signed moderated media, coarse location/privacy zones, account pause/delete/export. Exit: authorization/abuse tests, security review, retention schedule, recovery drill.

## Phase 3 — matching and chat

Idempotent likes/matches, real-time bounded chat, rate limits, scam defenses, media consent/detection, block propagation, audited moderation console and appeals. Exit: load/abuse tests and no cross-block leakage.

## Phase 4 — voice/video beta

Managed WebRTC provider review, match-scoped short-lived tokens, mutual readiness, push ringing, call controls/recovery, in-call block/report, coarse diagnostics, no recording. Exit: real Android/iPhone interop over Wi-Fi/cellular and race-condition testing.

## Phase 5 — subscriptions

StoreKit 2, Play Billing, verified entitlements/notifications, transparent paywalls, restore/grace/refund/cancel flows, regional pricing. Exit: both store sandboxes and legal review pass.

## Phase 6 — launch

Photo/liveness and optional ID vendor review, regional age assurance, policies/safety center, pen test, incident response, support/moderation staffing, closed beta, staged release.

No public launch before moderation and under-age prevention work.

