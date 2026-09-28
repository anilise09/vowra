# Vawra mobile UI and platform audit (2026-09-28)

## What is verified

| Area | Evidence | Limit |
| --- | --- | --- |
| Welcome and seven-step offline onboarding | Android 14 emulator walkthrough through the final step; Flutter widget and visual tests | The dedicated emulator became unstable as Discover opened, so no full runtime walkthrough is claimed. |
| Discover, details, swipe tutorial, match, chat, Explore, Profile, Settings | Automated `device_matrix_test.dart` walks these screens at 9 Android-sized viewports and two text sizes; `large_text_test.dart` checks 1.8x; visual and swipe tests pass | Automated layout and interaction coverage is not a substitute for a physical-device visual review. |
| iPhone-style layouts | Four extra Flutter test runs use iOS platform rendering, iPhone/Pro Max sizes, realistic safe areas, and 1.0x/1.3x text | These run on Windows' Flutter test engine, not Apple's iOS Simulator or an iPhone. |
| Connected-account UI | `server_flow_test.dart` covers sign-in, age gate, profile, match, chat, safety and account flows; the same navigation shell is used by offline and connected homes | No live connected-device walkthrough in this audit. |
| Backend contract | `npm test` (53 tests) and `npm run typecheck` pass | Backend remains local-only and switched off by default. |

The tall-phone Welcome screenshot revealed excessive white space below the consent controls.
The reading panel now reaches the bottom of the safe viewport while remaining scrollable on
short screens. Its visual baseline and a direct regression assertion were updated. No new
photos or animations were needed; Higgsfield generations used: **0**.

## Still pending

- Install the latest debug APK on the owner's Samsung when it is free, then inspect Welcome,
  Discover actions and gestures, Explore, Matches, Chats, Profile, and Settings at native size.
  The previous installed build does **not** include the UI-5 action changes or this Welcome fix.
- On the owner's Intel Mac, run an actual Xcode iOS Simulator build and repeat that walkthrough
  at compact and large iPhone sizes, normal and larger text, and reduced motion. Windows cannot
  run the Apple simulator. Physical iPhone/iPad testing follows later, as requested.
  Select a Flutter Intel/x64 SDK and an Xcode version supported by the Mac's installed macOS;
  Flutter currently warns that Intel Mac support is being phased out. Check the current
  [Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup),
  [Flutter Intel download note](https://docs.flutter.dev/install/manual), and
  [Apple Xcode requirements](https://developer.apple.com/xcode/system-requirements) at setup time.
- Production launch gates remain separate: reviewed age assurance, moderated photo uploads,
  media/provider and legal review, real-device call interop, billing/store review, security and
  moderation readiness. UI fixtures must not be mistaken for production members or activity.
