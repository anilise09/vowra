# Vawra

Vawra is an 18+ cross-platform dating app for Android and iPhone. Matching, messaging, blocking, reporting, and match-gated voice/video calling belong to the free core.

Vawra is the current product name and visual identity. Public launch under that name still depends on trademark, domain, and store-name clearance.

## Status

CP-050 is complete: current Tinder, Bumble, Hinge, and Feeld patterns were reviewed from first-party sources, then Vawra's welcome and discovery experience was rebuilt around an original intent-first, photo-led system. The checkpoint adds a reusable theme, immersive profile card, first-viewport decision controls, compact filter/safety chrome, refined navigation, and phone-sized golden baselines. The safety and prototype disclosures remain truthful but no longer dominate the primary hierarchy. `flutter analyze` passes, all 57 tests pass, and the Android debug APK builds. The redesigned APK is installed on the connected Samsung SM-S928W; visual inspection on the locked physical screen remains pending until the owner unlocks it. Portrait generation remains paused; representation-expansion progress remains 160 / 220. See `docs/COMPETITIVE_UI_RESEARCH.md`, `docs/BRAND_IDENTITY.md`, and `CHECKPOINTS.md`.

## Intended stack

- Flutter/Dart mobile client (Android and iOS)
- TypeScript backend with PostgreSQL and PostGIS
- Signed media uploads with asynchronous moderation
- Managed WebRTC provider for the MVP
- StoreKit 2 and Google Play Billing

No production service, billing integration, or real user-data collection exists yet.
