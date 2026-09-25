# Vawra

Vawra is an 18+ cross-platform dating app for Android and iPhone. Matching, messaging, blocking, reporting, and match-gated voice/video calling belong to the free core.

Vawra is the current product name and visual identity. Public launch under that name still depends on trademark, domain, and store-name clearance.

## Status

CP-049 is complete: Vawra now has an original ribbon-V/negative-space-heart identity, coordinated coral/plum/blush tokens, branded onboarding and app chrome, and complete Android/iOS launcher icon sets. The stable package identifiers remain unchanged so installs update the existing prototype. `flutter analyze` passed, all 55 tests passed, the Android debug APK built, and the branded build was installed and launched on the connected Samsung SM-S928W without an app fatal crash. Portrait generation remains paused until coding and UI design are further along; representation-expansion progress remains 160 / 220. See `docs/BRAND_IDENTITY.md`, `docs/MEDIA_UPLOAD_CONTRACT.md`, and `CHECKPOINTS.md`.

## Intended stack

- Flutter/Dart mobile client (Android and iOS)
- TypeScript backend with PostgreSQL and PostGIS
- Signed media uploads with asynchronous moderation
- Managed WebRTC provider for the MVP
- StoreKit 2 and Google Play Billing

No production service, billing integration, or real user-data collection exists yet.
