# Project Ember

Project Ember is the working codename for an 18+ cross-platform dating app for Android and iPhone. Matching, messaging, blocking, reporting, and match-gated voice/video calling belong to the free core.

The launch name is intentionally undecided until trademark, domain, and store-name checks are complete.

## Status

CP-046 is complete locally: session and recovery contracts now cover non-enumerating passwordless/OIDC initiation, PKCE/state-bound exchange, rotation and replay revocation, current-session logout, sign-out-everywhere, and recovery boundaries. Client contract types redact identifiers and provider proofs, and the unconfigured API fails closed. `flutter analyze` passed, all 44 tests passed, and the Android debug APK built. No provider, credential storage, network client, production account, or device walkthrough was added. Portrait generation remains paused until coding and UI design are further along. The original 50-women/50-men target is complete, and the Indian, Pakistani, Bangladeshi, Chinese, Japanese, Filipino, Korean, and Mexican expansion targets are complete. Overall representation-expansion progress is 160 / 220. See `docs/SESSION_CONTRACT.md`, `docs/BACKEND_API_CONTRACT.md`, `docs/PROTOTYPE_PROFILE_DATASET.md`, and `CHECKPOINTS.md` for current details.

## Intended stack

- Flutter/Dart mobile client (Android and iOS)
- TypeScript backend with PostgreSQL and PostGIS
- Signed media uploads with asynchronous moderation
- Managed WebRTC provider for the MVP
- StoreKit 2 and Google Play Billing

No production service, billing integration, or real user-data collection exists yet.
