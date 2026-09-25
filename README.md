# Vawra

Vawra is an 18+ cross-platform dating app for Android and iPhone. Matching, messaging, blocking, reporting, and match-gated voice/video calling belong to the free core.

Vawra is the current product name and visual identity. Public launch under that name still depends on trademark, domain, and store-name clearance.

## Status

CP-051 is complete: the owner-supplied Vawra company identity is now the active in-app and launcher identity, an original silk-ribbon background gives the welcome screen a premium visual layer, and discovery respects Samsung's edge-to-edge status-bar inset. Android and iOS icon sizes were regenerated from the approved couple/heart mark. `flutter analyze` passes, all 57 tests pass, the Android debug APK builds, and the final welcome and discovery screens were visually verified on the connected Samsung SM-S928W. Public launch under the Vawra name still depends on legal trademark, domain, and store-name clearance. Portrait generation remains paused; representation-expansion progress remains 160 / 220. See `docs/COMPETITIVE_UI_RESEARCH.md`, `docs/BRAND_IDENTITY.md`, and `CHECKPOINTS.md`.

## Intended stack

- Flutter/Dart mobile client (Android and iOS)
- TypeScript backend with PostgreSQL and PostGIS
- Signed media uploads with asynchronous moderation
- Managed WebRTC provider for the MVP
- StoreKit 2 and Google Play Billing

No production service, billing integration, or real user-data collection exists yet.
