# Checkpoints

## CP-017 — Pakistani expansion half-batch (2026-09-21)

- Added five fictional adult Pakistani women and five fictional adult Pakistani men with explicit fixture background metadata.
- Reviewed and bundled ten distinct portraits while preserving unique profile names, unique asset references, and visible prototype disclosure.
- Advanced overall representation-expansion progress to 30 / 220, with the Pakistani target at 5 / 10 women and 5 / 10 men.
- Built the debug APK and installed it only on the connected Samsung phone; the AVD remained untouched and full testing stayed deferred.

Next: complete the remaining five Pakistani women and five Pakistani men, then proceed through the other requested backgrounds in auditable batches.

## CP-016 — Indian expansion completed (2026-09-21)

- Added five more fictional adult Indian women and five more fictional adult Indian men with explicit fixture background metadata.
- Completed the Indian expansion target at 10 women and 10 men; overall expansion progress is 20 / 220.
- Reviewed and bundled ten distinct portraits while preserving unique profile names, unique asset references, and visible prototype disclosure.
- Built the debug APK and installed it only on the connected Samsung phone; the AVD remained untouched and full testing stayed deferred.

Next: begin the Pakistani expansion target in reviewed, auditable batches.

## CP-015 — Indian expansion half-batch (2026-09-21)

- Began the requested 220-profile representation expansion with five fictional adult Indian women and five fictional adult Indian men.
- Added explicit optional background metadata to synthetic discovery fixtures and displays it on expansion profiles instead of relying on appearance-based inference.
- Reviewed and bundled ten distinct portraits; expansion progress is 10 / 220, with the Indian target at 5 / 10 women and 5 / 10 men.
- Built the debug APK and installed it only on the connected Samsung phone; the AVD remained untouched and full testing stayed deferred.

Next: complete the remaining five Indian women and five Indian men, then proceed through the other requested backgrounds in auditable batches.

## CP-014 — Original 50/50 profile target completed (2026-09-20)

- Added the final five fictional adult women and five fictional adult men with distinct reviewed portraits and discovery metadata.
- Completed the original dataset target at 50 women and 50 men; Jordan remains an additional inclusive portrait fixture outside those counts.
- Verified every discovery portrait reference is unique and every referenced asset exists.
- Built the debug APK and installed it only on the connected Samsung phone; the AVD remained untouched and full testing stayed deferred.

Next: begin the requested 11-background expansion, adding 10 women and 10 men for each background in reviewed, auditable batches.

## CP-013 — Ninth reviewed AI portrait batch (2026-09-20)

- Added five fictional adult women and five fictional adult men with distinct reviewed portraits and discovery metadata.
- Advanced the original dataset to 45 women and 45 men; 5 of each remain.
- Kept this batch separate from the later 11-background expansion for auditable totals.
- Built the debug APK and installed it only on the connected Samsung phone; the AVD remained untouched and full testing stayed deferred.

Next: complete the final five women and five men in the original target, then begin the requested 11-background expansion.

## CP-012 — Eighth reviewed AI portrait batch (2026-09-20)

- Added five fictional adult women and five fictional adult men with distinct reviewed portraits and discovery metadata.
- Advanced the original dataset to 40 women and 40 men; 10 of each remain.
- Kept this batch separate from the later 11-background expansion for auditable totals.
- Built the debug APK and installed it only on the connected Samsung phone; the AVD remained untouched and full testing stayed deferred.

Next: complete the final 10 women and 10 men in the original target, then begin the requested 11-background expansion.

## CP-009 — Fifth reviewed AI portrait batch (2026-09-20)

- Added five fictional adult women and five fictional adult men with distinct reviewed portraits and discovery metadata.
- Advanced the original dataset to 25 women and 25 men; 25 of each remain.
- Kept this batch outside the later 11-background expansion for auditable totals.

Next: validate, deploy to the connected phone, and continue toward 50/50.

## CP-008 — Fourth reviewed AI portrait batch (2026-09-20)

- Added five fictional adult women and five fictional adult men with distinct generated portraits and discovery metadata.
- Rejected and regenerated one portrait containing readable background signage before bundling it.
- Advanced the original dataset to 20 women and 20 men; 30 of each remain before the original 50/50 target is complete.
- Kept this batch outside the later 11-background expansion so both progress totals remain auditable.

Next: validate CP-008, deploy it to the connected phone, and continue reviewed portrait batches toward 50/50.

## CP-007 — Third reviewed AI portrait batch and phone deployment (2026-09-20)

- Installed and launched CP-006 successfully on the connected Samsung SM-S928W before beginning new work.
- Added five fictional adult women and five fictional adult men with distinct generated portraits and discovery metadata.
- Advanced the original dataset to 15 women and 15 men; 35 of each remain before the original 50/50 target is complete.
- Kept this batch outside the later 11-background expansion so both progress totals remain auditable.

Next: validate CP-007, deploy it to the connected phone, and continue reviewed portrait batches toward 50/50.

## CP-006 — Second reviewed AI portrait batch (2026-09-20)

- Added five fictional adult women and five fictional adult men with distinct generated portraits and complete discovery metadata.
- Advanced the original dataset to 10 women and 10 men; 40 of each remain before the original 50/50 target is complete.
- Recorded the expanded representation target: 10 women and 10 men for each of 11 requested backgrounds, totaling 220 additional reviewed profiles after the original target.
- Preserved the visible `PROTOTYPE PROFILE · NOT A REAL PERSON` disclosure on every discovery card.

Next: continue the original 50/50 set in reviewed batches, then build the 11-background expansion with explicit dataset validation and preference-aware filtering.

## CP-005 — First reviewed AI portrait batch (2026-09-20)

- Began the requested 50-women/50-men synthetic profile dataset without duplicating faces or implying they are real users.
- Generated, reviewed, and bundled distinct portraits for five women and five men; retained Jordan as an additional inclusive portrait outside the requested count.
- Added ten complete discovery profiles with varied adult ages, relationship intents, coarse distance bands, biographies, interests, and portrait semantics.
- Discovery still displays `PROTOTYPE PROFILE · NOT A REAL PERSON` above every profile.
- Dataset progress and the reusable generation/review contract are recorded in `docs/PROTOTYPE_PROFILE_DATASET.md`; 45 women and 45 men remain and are explicitly not claimed complete.
- Twelve tests pass, Flutter analysis is clean, and the Android debug APK builds with the bundled assets.

Next: continue reviewed portrait batches until the 50/50 target is met, then add automated dataset count/unique-asset tests and a gender/preference-aware synthetic discovery filter.

## CP-004 — Bounded local messaging and anti-spam rules (2026-09-20)

- Added a message domain model and memory-only repository scoped by match ID.
- Messages are trimmed, repeated horizontal whitespace is normalized, unsupported control characters and blank content are rejected, and public text is capped at 1,000 characters.
- A connection must still be active at send time; blocked or unmatched conversations reject the write before storage.
- Prototype throttling permits at most five current-user messages per rolling minute per match.
- Retention is bounded to the latest 100 in-memory messages per conversation; app restart clears them.
- Replaced hard-coded chat bubbles with repository-backed synthetic messages and wired the composer through the policy boundary.
- Twelve unit/widget tests pass, Flutter analysis is clean, and the Android debug APK builds.

Next: add structured report reasons, minimal evidence references and an audited moderation-state model; never silently attach an entire conversation or notify the reported account.

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
