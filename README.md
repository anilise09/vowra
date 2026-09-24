# Project Ember

Project Ember is the working codename for an 18+ cross-platform dating app for Android and iPhone. Matching, messaging, blocking, reporting, and match-gated voice/video calling belong to the free core.

The launch name is intentionally undecided until trademark, domain, and store-name checks are complete.

## Status

CP-047 is complete locally: account lifecycle and location contracts now cover pause/resume, bounded export, scheduled deletion/cancellation, server-defined recovery windows, narrowly retained abuse evidence, encrypted exact-location submission, and coarse-only responses. The unconfigured API fails closed and no real account, location, export, deletion, or network service exists. `flutter analyze` passed, all 49 tests passed, and the Android debug APK built. No device walkthrough was performed. Portrait generation remains paused until coding and UI design are further along; representation-expansion progress remains 160 / 220. See `docs/DATA_LIFECYCLE_CONTRACT.md`, `docs/SESSION_CONTRACT.md`, `docs/BACKEND_API_CONTRACT.md`, and `CHECKPOINTS.md`.

## Intended stack

- Flutter/Dart mobile client (Android and iOS)
- TypeScript backend with PostgreSQL and PostGIS
- Signed media uploads with asynchronous moderation
- Managed WebRTC provider for the MVP
- StoreKit 2 and Google Play Billing

No production service, billing integration, or real user-data collection exists yet.
