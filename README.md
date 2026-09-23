# Project Ember

Project Ember is the working codename for an 18+ cross-platform dating app for Android and iPhone. Matching, messaging, blocking, reporting, and match-gated voice/video calling belong to the free core.

The launch name is intentionally undecided until trademark, domain, and store-name checks are complete.

## Status

CP-038 is complete: local safety reports now carry a moderation-state model with stable backend keys, starting as local pending review and remaining explicit that no production review team is connected. Conversation and discovery report cards show the local review state without notifying the other person or creating fake engagement. Common mojibake punctuation in touched app strings was normalized so prototype labels and distance ranges render correctly. ASUS/device testing was skipped for this checkpoint at the user's request because work is currently active on that device. Portrait generation remains paused until coding and UI design are further along. The original 50-women/50-men target is complete, and the Indian, Pakistani, Bangladeshi, Chinese, Japanese, Filipino, Korean, and Mexican expansion targets are complete. Overall representation-expansion progress is 160 / 220. Explicit fixture background metadata is shown in discovery. See `docs/PROTOTYPE_PROFILE_DATASET.md` for exact counts, plus `CHECKPOINTS.md`, `docs/COMPETITIVE_RESEARCH.md`, `docs/PRODUCT_PLAN.md`, `docs/ROADMAP.md`, and `docs/SECURITY_AND_SAFETY.md`.

## Intended stack

- Flutter/Dart mobile client (Android and iOS)
- TypeScript backend with PostgreSQL and PostGIS
- Signed media uploads with asynchronous moderation
- Managed WebRTC provider for the MVP
- StoreKit 2 and Google Play Billing

No production service, billing integration, or real user-data collection exists yet.
