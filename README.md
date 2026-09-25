# Vawra

Vawra is an 18+ cross-platform dating app for Android and iPhone. Matching, messaging, blocking, reporting, and match-gated voice/video calling belong to the free core.

Vawra is the current product name and visual identity. Public launch under that name still depends on trademark, domain, and store-name clearance.

## Status

CP-052 is complete: the Vawra visual system now covers welcome, discovery, connections, chat, and profile editing. The update adds a layered full-photo match card, compact avatar-led chat, asymmetric message bubbles, grouped profile controls, destination-specific phone-safe hierarchy, and borderless transparent company-mark usage inside the app. Five phone-sized golden baselines protect the main surfaces. `flutter analyze` passes, all 60 tests pass, and the Android debug APK builds. Final installation is pending because the Samsung SM-S928W disconnected from ADB after the prior physical walkthrough. Public launch under the Vawra name still depends on legal trademark, domain, and store-name clearance. Portrait generation remains paused; representation-expansion progress remains 160 / 220. See `docs/COMPETITIVE_UI_RESEARCH.md`, `docs/BRAND_IDENTITY.md`, and `CHECKPOINTS.md`.

## Intended stack

- Flutter/Dart mobile client (Android and iOS)
- TypeScript backend with PostgreSQL and PostGIS
- Signed media uploads with asynchronous moderation
- Managed WebRTC provider for the MVP
- StoreKit 2 and Google Play Billing

No production service, billing integration, or real user-data collection exists yet.
