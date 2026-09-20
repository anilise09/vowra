# Project Ember

Project Ember is the working codename for an 18+ cross-platform dating app for Android and iPhone. Matching, messaging, blocking, reporting, and match-gated voice/video calling belong to the free core.

The launch name is intentionally undecided until trademark, domain, and store-name checks are complete.

## Status

CP-001 is complete: research, safety/product contracts, Android/iOS Flutter scaffolding, and the first offline prototype slice. See `CHECKPOINTS.md`, `docs/COMPETITIVE_RESEARCH.md`, `docs/PRODUCT_PLAN.md`, `docs/ROADMAP.md`, and `docs/SECURITY_AND_SAFETY.md`.

## Intended stack

- Flutter/Dart mobile client (Android and iOS)
- TypeScript backend with PostgreSQL and PostGIS
- Signed media uploads with asynchronous moderation
- Managed WebRTC provider for the MVP
- StoreKit 2 and Google Play Billing

No production service, billing integration, or real user-data collection exists yet.
