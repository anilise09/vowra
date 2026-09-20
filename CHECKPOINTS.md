# Checkpoints

## CP-003 — Match, conversation, and call-consent invariants (2026-09-20)

- Added an explicit match state machine with active, unmatched, and blocked states.
- Messaging requires an active match. Video-call requests require an active match plus both people's call-readiness opt-in.
- Block and unmatch are terminal for contact and clear both readiness flags; later UI actions cannot silently reactivate them.
- Reporting preserves a private evidence flag without notifying the synthetic peer or automatically forcing a block.
- Replaced Matches and Chats placeholders with a clearly synthetic match, sample conversation, mutual-readiness controls, private reporting, and confirmed block/unmatch actions.
- The call button performs no camera, microphone, token, or network action; it states this explicitly.
- Nine unit/widget tests pass, Flutter analysis is clean, and the Android debug APK builds.

Next: extract feature widgets from `main.dart`, add a bounded message composer/repository and deterministic anti-spam rules, then model report reasons and evidence capture without storing unnecessary conversation content.

## CP-002 — Validated local profile creation (2026-09-20)

- Added a profile domain model with bounded display-name and bio validation and an explicit 18–99 adult age rule.
- Added relationship intent, interests, coarse-distance visibility, and match-level call-readiness preferences.
- Added a prototype-only memory repository; identity data is not written to disk or uploaded.
- Replaced the Profile placeholder with a complete responsive editor and clear prototype-retention disclosure.
- End-to-end testing exposed a lazy-list lifecycle flaw that could dispose off-screen fields before save and skip their validators. The form now keeps every field mounted, so age validation cannot depend on scroll position.
- Five unit/widget tests pass, Flutter analysis is clean, and the Android debug APK builds.

Next: implement explicit match, conversation, block, unmatch, and mutual call-readiness state machines with synthetic fixtures and authorization-style invariant tests.

## CP-001 — Research, safety contract, and Flutter foundation (2026-09-20)

- Researched Tinder, Bumble, Hinge, and Pure using official feature, subscription, calling, and safety documentation.
- Chose a freemium hypothesis that keeps matching, messaging, calling, and safety free while monetizing discovery convenience and optional visibility.
- Documented the product plan, six-phase roadmap, privacy/safety baseline, and non-negotiable engineering rules.
- Installed Flutter stable 3.47.5 and generated Android/iOS projects under the neutral Project Ember codename.
- Replaced the counter template with an offline safety-led vertical slice: 18+ and community-rule consent, explicitly synthetic discovery profiles, coarse distance bands, navigation placeholders, and a Safety Center.
- Flutter analysis passes with no issues, both widget tests pass, and `flutter build apk --debug` produces an APK.
- iOS files are generated but cannot be compiled or signed on Windows; real iPhone validation requires macOS/Xcode later.

Next: separate the prototype into feature/domain/data layers, implement profile creation with synthetic local persistence, then build match/chat/call-readiness state machines before any backend or real-user data.
