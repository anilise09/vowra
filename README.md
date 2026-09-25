# Vawra

Vawra is an 18+ cross-platform dating app for Android and iPhone. Matching, messaging, blocking, reporting, and match-gated voice/video calling belong to the free core.

Vawra is the current product name and visual identity. Public launch under that name still depends on trademark, domain, and store-name clearance.

## Status

CP-053 is complete: welcome and discovery now follow the owner-approved visual direction with floating portrait previews, a split onboarding composition, a photo-first discovery card, circular story previews, and a floating navy navigation bar. Standalone in-app branding uses the tightly cropped transparent company mark with no white tile, border, shadow, or stray pixels. Five phone-sized golden baselines protect the main surfaces. `flutter analyze` passes, all 60 tests pass, the Android debug APK builds, and the exact build is installed and visually verified on the Samsung SM-S928W. Public launch under the Vawra name still depends on legal trademark, domain, and store-name clearance. Portrait generation remains paused; representation-expansion progress remains 160 / 220. See `docs/COMPETITIVE_UI_RESEARCH.md`, `docs/BRAND_IDENTITY.md`, and `CHECKPOINTS.md`.

## Intended stack

- Flutter/Dart mobile client (Android and iOS)
- TypeScript backend with PostgreSQL and PostGIS
- Signed media uploads with asynchronous moderation
- Managed WebRTC provider for the MVP
- StoreKit 2 and Google Play Billing

No production service, billing integration, or real user-data collection exists yet.
