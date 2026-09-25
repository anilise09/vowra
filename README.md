# Project Ember

Project Ember is the working codename for an 18+ cross-platform dating app for Android and iPhone. Matching, messaging, blocking, reporting, and match-gated voice/video calling belong to the free core.

The launch name is intentionally undecided until trademark, domain, and store-name checks are complete.

## Status

CP-048 is complete locally: signed media-upload and moderation-quarantine contracts now cover bounded upload facts, short-lived redacted grants, private quarantine, approved-only visibility, consent-aware matched attachments, deletion, and fail-closed authorization. No camera/gallery integration, storage account, scanner, moderation provider, real media, or network service exists. `flutter analyze` passed, all 55 tests passed, and the Android debug APK built. No device walkthrough was performed. Portrait generation remains paused until coding and UI design are further along; representation-expansion progress remains 160 / 220. See `docs/MEDIA_UPLOAD_CONTRACT.md`, `docs/DATA_LIFECYCLE_CONTRACT.md`, `docs/BACKEND_API_CONTRACT.md`, and `CHECKPOINTS.md`.

## Intended stack

- Flutter/Dart mobile client (Android and iOS)
- TypeScript backend with PostgreSQL and PostGIS
- Signed media uploads with asynchronous moderation
- Managed WebRTC provider for the MVP
- StoreKit 2 and Google Play Billing

No production service, billing integration, or real user-data collection exists yet.
