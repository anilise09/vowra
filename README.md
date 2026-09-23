# Project Ember

Project Ember is the working codename for an 18+ cross-platform dating app for Android and iPhone. Matching, messaging, blocking, reporting, and match-gated voice/video calling belong to the free core.

The launch name is intentionally undecided until trademark, domain, and store-name checks are complete.

## Status

CP-037 is complete: discovery now supports the requested swipe model. Swipe up likes the current synthetic profile and removes it from the local deck, swipe left rejects and excludes it from discovery, and swipe right advances to the next profile without treating the profile as rejected. The UI explains the prototype notification and connection model: a real launch would notify the liked person, mutual likes can connect and message in the free core, and premium direct intros remain a future design concept in this local prototype. No real notifications, matches, billing, or messages are sent. ASUS/device testing was skipped for this checkpoint at the user's request because work is currently active on that device. Portrait generation remains paused until coding and UI design are further along. The original 50-women/50-men target is complete, and the Indian, Pakistani, Bangladeshi, Chinese, Japanese, Filipino, Korean, and Mexican expansion targets are complete. Overall representation-expansion progress is 160 / 220. Explicit fixture background metadata is shown in discovery. See `docs/PROTOTYPE_PROFILE_DATASET.md` for exact counts, plus `CHECKPOINTS.md`, `docs/COMPETITIVE_RESEARCH.md`, `docs/PRODUCT_PLAN.md`, `docs/ROADMAP.md`, and `docs/SECURITY_AND_SAFETY.md`.

## Intended stack

- Flutter/Dart mobile client (Android and iOS)
- TypeScript backend with PostgreSQL and PostGIS
- Signed media uploads with asynchronous moderation
- Managed WebRTC provider for the MVP
- StoreKit 2 and Google Play Billing

No production service, billing integration, or real user-data collection exists yet.
