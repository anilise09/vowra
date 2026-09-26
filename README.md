# Vawra

Vawra is an 18+ cross-platform dating app for Android and iPhone. Matching, messaging, blocking, reporting, and match-gated voice/video calling belong to the free core.

Vawra is the current product name and visual identity. Public launch under that name still depends on trademark, domain, and store-name clearance.

## Status

CP-055 is complete: after the 18+ and consent gate, new users set up their profile one question at a time (name, age, intent, interests, an optional intro, privacy and call defaults) with a progress bar and Skip only on optional steps. Discovery (CP-054) is photo-first: swipe right to like, left to pass, up for a details sheet. Both follow a hands-on Tinder/Bumble walkthrough recorded in `docs/COMPETITIVE_UI_RESEARCH.md`. `flutter analyze` passes and all 68 tests pass; the debug APK builds but this build has not yet been installed on the Samsung SM-S928W. Public launch under the Vawra name still depends on legal trademark, domain, and store-name clearance. Portrait generation remains paused; representation-expansion progress remains 160 / 220. See `docs/COMPETITIVE_UI_RESEARCH.md`, `docs/BRAND_IDENTITY.md`, and `CHECKPOINTS.md`.

## Intended stack

- Flutter/Dart mobile client (Android and iOS)
- TypeScript backend with PostgreSQL and PostGIS
- Signed media uploads with asynchronous moderation
- Managed WebRTC provider for the MVP
- StoreKit 2 and Google Play Billing

No production service, billing integration, or real user-data collection exists yet.
