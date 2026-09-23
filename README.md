# Project Ember

Project Ember is the working codename for an 18+ cross-platform dating app for Android and iPhone. Matching, messaging, blocking, reporting, and match-gated voice/video calling belong to the free core.

The launch name is intentionally undecided until trademark, domain, and store-name checks are complete.

## Status

CP-036 is complete: profile editing UI has been extracted from the oversized app shell into a feature module while preserving validation, interest selection, coarse-distance preference, and call-readiness default behavior. Discovery, match, chat, and profile UI are now feature-owned, with `main.dart` focused on app state and fixture wiring. Emulator smoke testing installed and launched the debug APK, reached discovery, and reached the extracted profile editor without app crashes. Wireless ASUS phone testing on `10.0.0.246:37889` also installed and launched the debug APK, reached discovery, and reached the extracted profile editor without app crashes. Portrait generation is paused until coding and UI design are further along. The original 50-women/50-men target is complete, and the Indian, Pakistani, Bangladeshi, Chinese, Japanese, Filipino, Korean, and Mexican expansion targets are complete. Overall representation-expansion progress is 160 / 220. Explicit fixture background metadata is shown in discovery. See `docs/PROTOTYPE_PROFILE_DATASET.md` for exact counts, plus `CHECKPOINTS.md`, `docs/COMPETITIVE_RESEARCH.md`, `docs/PRODUCT_PLAN.md`, `docs/ROADMAP.md`, and `docs/SECURITY_AND_SAFETY.md`.

## Intended stack

- Flutter/Dart mobile client (Android and iOS)
- TypeScript backend with PostgreSQL and PostGIS
- Signed media uploads with asynchronous moderation
- Managed WebRTC provider for the MVP
- StoreKit 2 and Google Play Billing

No production service, billing integration, or real user-data collection exists yet.
