# Checkpoints

## CP-001 — Research, safety contract, and Flutter foundation (2026-09-20)

- Researched Tinder, Bumble, Hinge, and Pure using official feature, subscription, calling, and safety documentation.
- Chose a freemium hypothesis that keeps matching, messaging, calling, and safety free while monetizing discovery convenience and optional visibility.
- Documented the product plan, six-phase roadmap, privacy/safety baseline, and non-negotiable engineering rules.
- Installed Flutter stable 3.47.5 and generated Android/iOS projects under the neutral Project Ember codename.
- Replaced the counter template with an offline safety-led vertical slice: 18+ and community-rule consent, explicitly synthetic discovery profiles, coarse distance bands, navigation placeholders, and a Safety Center.
- Flutter analysis passes with no issues, both widget tests pass, and `flutter build apk --debug` produces an APK.
- iOS files are generated but cannot be compiled or signed on Windows; real iPhone validation requires macOS/Xcode later.

Next: separate the prototype into feature/domain/data layers, implement profile creation with synthetic local persistence, then build match/chat/call-readiness state machines before any backend or real-user data.

