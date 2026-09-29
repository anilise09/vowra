# Vawra

Vawra is an 18+ cross-platform dating app for Android and iPhone. Matching, messaging, blocking, reporting, and match-gated voice/video calling belong to the free core.

Vawra is the current product name and visual identity. Public launch under that name still depends on trademark, domain, and store-name clearance.

## Status

A responsive, static Vawra product-site preview is in `website/`. It uses the approved
transparent company lockup and current synthetic-prototype screenshots, with an
interactive screen gallery and explicit pre-launch disclosures. It has not been
published or visually verified in a browser on this machine.

UI-5 uses the approved transparent company lockup and aligns Discover's primary Pass and Like
actions with their swipe meanings. The latest audit anchors Welcome's reading panel on tall
phones and passes 22 Android/iOS-style device-and-text-size runs plus the full Flutter suite.
Real iOS Simulator and physical-phone review of this exact build remain pending. See
`CHECKPOINTS.md` and `docs/UI_PLATFORM_AUDIT.md`.

The offline prototype has synthetic profiles, onboarding, swipe discovery, Explore, matches,
chat and safety flows. A local-only backend adds accounts, age-gated discovery, real matches
and live chat behind a build flag. Production accounts, calls, billing and media uploads are
not enabled. See `CHECKPOINTS.md`, `docs/TINDER_UI_TEARDOWN.md` and `backend/README.md` for details.

## Intended stack

- Flutter/Dart mobile client (Android and iOS)
- TypeScript backend with PostgreSQL and PostGIS
- Signed media uploads with asynchronous moderation
- Managed WebRTC provider for the MVP
- StoreKit 2 and Google Play Billing

A first backend slice exists in `backend/` (BE-1: sign-in, sessions, profile, discovery, matches, chat, safety), switched off by default and never deployed. Since BE-2 the app can use it: build with `--dart-define=VAWRA_API=<url>` for email sign-in, a server profile, real matches and chat (see `backend/README.md`); without that define it stays the offline prototype. No production service, billing integration, or real user-data collection exists yet.
