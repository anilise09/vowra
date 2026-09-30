# Checkpoints

## BE-23 - Sign-in codes by email: six digits, any SMTP provider (2026-09-30)

- Sign-in codes are now six digits instead of a 43-character token, so people can type them. The
  server finds the pending request by the phone's `state`, never by the code, and compares a keyed
  hash of the code bound to that request (a leaked table cannot be brute-forced); the PKCE
  verifier must match too. A typo is forgiven; the fifth wrong try spends the code, so at most five
  guesses per code and five codes per email per 15 minutes.
- Email through any SMTP provider (`VAWRA_SMTP_URL`, `VAWRA_EMAIL_FROM`): TLS always, certificates
  verified, plain text and a simple branded HTML version, no links, marked auto-generated.
  Production refuses to start without it. If the mail server is down, the app still gets the same
  answer (no account-existence hint) and the failure is logged.
- The app's code field takes digits only, at most six, with the number keypad, and signs in as the
  sixth digit is typed; a tap right after cannot send the code twice.
- Tests: 5 email tests against a real local SMTP server (including refusing a server that cannot
  encrypt), 4 new sign-in tests, 1 app test. Seven planted defects (attempt limit, code stored in
  clear, delivery failure not caught, TLS requirement, production email check, auto-submit,
  digits-only) each fail them.
- Backend 169 tests, app 230 (1 existing skip) pass. Phone builds made before today still ask for
  the long code; the next build takes six digits.

## BE-20b - Migrations survive Windows line endings (2026-09-30)

- On a checkout with Windows line endings (Git's default on Windows) every migration failed: the
  comment remover stopped at the carriage return, so comment text reached PostgreSQL as SQL
  ("syntax error at or near no"). Lines now split on either ending. A new test splits the same
  migration both ways; without the fix it fails, and so did 126 tests in such a checkout.
- Backend 161 tests pass.

## Device - First real iOS Simulator critical flow (2026-09-30)

- On the Intel Mac, installed CocoaPods 1.17.0 for the local toolchain and built Vawra with
  Flutter 3.47.5 and Xcode 26.6 for the iOS 26.5 Simulator. No signing account or production
  service was needed.
- Added a real `integration_test` flow and its `flutter drive` adapter. On a dedicated iPhone 17e
  simulator it accepts the adult/rules gate, completes every offline onboarding step, opens
  Discover, likes into the synthetic match, sends a chat message, visits Profile and reaches the
  destructive-account section in Settings.
- The first device run found a test-only mistake: the delete row is below Settings' lazy viewport,
  so looking for it without scrolling returned no widget. The flow now scrolls the real Settings
  list before asserting the row; the rebuilt app then passed end to end in 60 seconds.
- Evidence: `flutter analyze` is clean; the generic simulator debug build passes; the iPhone 17e
  drive says `All tests passed`; 214 non-golden Flutter tests plus the export large-text case pass,
  with the existing live-server test skipped because `VAWRA_LIVE_API` is unset.
- The full suite's 14 Windows-authored pixel baselines differ by 0.43-1.60% on macOS. The inspected
  isolated diff is confined to text/vector edges, while all layout and interaction assertions pass;
  the approved goldens were not overwritten on a different rendering platform.
- This is the first real Apple-simulator validation, not a full iOS sign-off. Large-iPhone,
  larger-text, reduced-motion, physical iPhone/iPad, connected-server and real-call checks remain.

## BE-20 follow-up - sign-in throttling shared by every server (2026-09-30)

- Replaced the per-process sign-in limiter with atomic database counters, so adding another
  server cannot multiply the email-address or network attempt allowance. Concurrent attempts
  from two limiter instances admit exactly the configured five requests, then the window resets.
- Counter keys are HMAC lookups: neither email addresses nor network addresses are stored in the
  throttle table. Expired windows are removed by the hourly retention job after one day.
- Migration `012_auth_rate_limits.sql`; the deployment, load-test, data-lifecycle and security
  notes now describe the shared store and the remaining multi-instance work accurately.
- Backend type-check and production build pass; all 160 backend tests pass.

## BE-20 - Ready to deploy: strict settings, readiness, clean shutdown, image (2026-09-30)

- Settings are checked at start and every problem is listed at once, never a secret: keys must be
  32 bytes and different, numbers must make sense. `VAWRA_ENV=production` also refuses the
  development database, the development sign-in outbox, direct calls, a default listen address
  and access tokens over an hour.
- `GET /v1/ready`: the database answers and every migration this build ships is applied; `503`
  with the reason otherwise, and while shutting down. `/v1/health` stays the liveness check.
- Migrations run in one transaction under an advisory lock, so instances starting together never
  apply one twice.
- Clean stop on SIGTERM: readiness fails, a drain period lets traffic move away (10 s in
  production), open live-update streams end instead of holding the shutdown, requests in flight
  and the hourly job finish, the database closes; forced after drain plus 20 s.
- Startup moved into `startServer()` so it is tested for real: 9 new tests, including a shutdown
  with a signed-in live stream open. Six planted defects (stream hook, draining, pending-migration
  check, production outbox refusal, key length, migration idempotence) each fail them.
- `backend/Dockerfile` (Node 22, non-root, `/data` volume, health check) and `docs/DEPLOY.md`.
  The image is not built here: Docker is not installed on this laptop. A build with only the
  files the image copies compiles.
- Backend 160 tests pass.

## Web-3 - The website catches up with the app (2026-09-30)

- Home: three new "What's new" cards with screens captured on the Asus today (a voice call, the
  scam warning, the Distance sheet with private places); the safety list now says what is built
  (checked photos, opt-in chat photos, calls both opt in and never recorded, moderation with
  appeals) instead of "calls are not built yet"; four new FAQs (calls, location, photos,
  deleting an account).
- New pages: `safety.html` (community guidelines, the safety tools, reports and moderation,
  meeting safely) and `privacy.html` (what is kept and never collected, who sees what, the
  retention table, your controls, security), marked as not yet the legal privacy policy.
- Fixed: the footer logo was squashed (width set, height left at the HTML value); long safety
  points wrapped under their number.
- `website/check.ps1` now covers all three pages: links and anchors across pages, assets, no forms
  or outside requests, the launch disclosure on every page, no launch wording, calls described
  only with both opt-in and never recorded, the privacy page's draft status, logo proportions.
  Four planted defects (squashed logo, "calls are not built", a broken anchor, a missing
  disclosure) each fail it.
- Checked in Chromium at 1280 and 390 wide: every image loads, no sideways scrolling.

## BE-15b - Dates and times are not phone numbers (2026-09-30)

- Found on the Asus: a message with a timestamp ("2026-09-27 18:14:48") got the "Moving to
  another app?" warning because the phone-number pattern read the date and hour as ten digits.
  Dates (2026-10-03, 03.10.2026, 2026/10/03) and clock times (19:30, 18:14:48.98) are now removed
  before looking for a phone number; real numbers ("204 555 0182", "+1 (204) 555-0182",
  "2045550182") are still flagged. Six new cases; the date cases fail without the fix.

## Device - Calls and distance on the owner's Asus (2026-09-30)

- The call build (8df5362, arm64 profile, checksum checked after install) on the Asus, signed in as
  Alex, against the local server with development direct calls; the other end was headless
  Chromium with a fake camera and microphone, signed in as the test member Maya.
- "Open to a call" on the phone saved to the server; Maya's opt-in reached the phone live and
  woke the voice and video buttons (before that they explained both must opt in).
- Maya's video call rang on the Asus and was answered there, with camera and microphone allowed
  at that moment on the phone. In 30 s the browser decoded 324 frames (5.7 MB) from the Asus
  camera plus audio, and sent video and audio back. When the browser hung up, the phone's call
  page closed by itself and the camera was released.
- Alex's voice call from the chat rang in the browser and connected about a second after it
  answered; audio both ways; only Mute, Phone and End shown; Phone switched to Speaker; ending it
  on the phone ended it in the browser. The microphone stopped at the end; the camera was never
  opened.
- Distance: approximate location only (precise location is not held). Turning distance on sent
  the rounded area; the server returns only when it was updated. The 260 sample people were
  re-seeded around that area on the server side (`dev:seed-demo --near`), so the area never
  passed through a command line. Cards then showed bands ("5-10 km away"; 49 of 50 people).
- Private places, on/off/on: "Hide my distance at this place" cleared the area on the server and
  no bands showed anywhere, with Settings saying "Hidden right now: you're at a private place";
  removing the place and "Update my area" brought the area and the bands back.
- Left on the phone: the build, Alex's "Open to a call" on for Maya (Maya's is off), distance on,
  no private places, the test-server port link. Nothing was saved to the phone's storage.

## BE-19b - First real calls: emulator and browser (2026-09-29)

- A real call end to end without the owner's phones: Vawra on the Android 15 emulator (as the
  test member Maya) and headless Chromium with a fake camera and microphone (as Alex) speaking
  the same server routes, through the local server with development direct calls.
- Found a crash no laptop test could: WebRTC aborts the app as a call connects unless the app
  holds ACCESS_NETWORK_STATE (an install-time permission with no prompt; WebRTC uses it to follow
  Wi-Fi and mobile handovers). Added, with a test that pins the exact permission list and fails
  when any is removed (checked by removing it).
- After the fix: Alex's video call rang on the emulator ("Incoming video call", Accept, Decline,
  "Answer without video"), was accepted and connected; in 20 s the browser decoded 224 video
  frames (406 KB) and 44 KB of audio from the emulator and sent 629 KB of video; the emulator
  showed the browser's picture full screen and its own camera in the corner. When the browser
  hung up, the emulator's call page closed by itself.
- Maya's voice call from the chat's voice button rang in the browser, connected in about 3 s,
  audio both ways, only Mute, Phone and End shown; Mute switched to Unmute; hanging up in the app
  ended the call on both sides.
- A soft dark fade now sits over the other person's video behind the name, clock and buttons,
  so they stay readable on a bright picture.
- Not yet on physical phones or through a TURN relay (none exists yet).

## BE-19 - Calls in the app: voice and video (2026-09-29)

- The chat's "Open to a call" switch is saved on the server, and the other person's answer shows
  as it changes. Voice and video buttons wake only when both are open to a call; while the server
  cannot relay calls they are hidden, switch included.
- Calling: a full-screen call page with ringing, connecting, a running clock, "Reconnecting…",
  and how it ended ("No answer", "Maya can't talk right now", "The connection was lost"). Mute,
  camera off, flip camera, speaker; video calls start on the speaker, voice calls at the ear.
  "Report" and "End call and block" work from inside the call. The page says the call is private
  and never recorded; leaving the page in any way ends the call.
- Incoming calls ring on screen while the app is open (Accept, Decline, "Answer without video");
  with the app closed they need push notifications, which come with a provider.
- The camera and microphone are asked for only when a call starts or is answered (Android CAMERA,
  RECORD_AUDIO; iOS usage texts). Refusing ends the call with how to allow them. Calls run on
  WebRTC (`flutter_webrtc`) behind a small `CallMedia` interface, relay-only when the server says
  so.
- Tests: eight widget tests with a stand-in camera and network (outgoing video, a ring nobody
  answers, a dropped connection, incoming answered without video, decline and a caller who gives
  up, refused camera, block and report inside a call, hidden without a relay). Two real bugs
  found by them and fixed: a call left running if its page was torn down (sign-out), and a stale
  "call in progress" marker that stopped the next call ringing.
- Breaking each app rule in turn (10 breaks: ending the call when the page goes, relay-only,
  hidden switch, closing the camera at the end, the ring timeout, voice at the ear, telling the
  server about a decline, noticing a caller gave up, a lost connection, saving readiness) fails a
  test every time.
- The chat baseline image now pre-loads the portrait like the other baselines (it had passed by
  timing luck) and shows the new voice button.
- Flutter 227 passed, 1 existing skip; analysis clean. Debug and release Android builds pass;
  the merged manifest adds only CAMERA, RECORD_AUDIO and MODIFY_AUDIO_SETTINGS. WebRTC adds
  about 17 MB to the three-CPU release APK (138 to 155 MB), about 6 MB per phone from the store.
- Live check against the local server: refused until both are ready, then ring, offer, answer,
  setup message delivered, hang-up, ended.
- Not yet tested on phones: a real call needs two phones and both are reserved by another session.

## BE-18 - Calls: the server side (2026-09-29)

- Each person says per match that they are open to a call; a call rings only when both have, the
  conversation is open, neither person is already in a call and the caller has started fewer than
  10 in the last hour. Ringing, answer, decline, cancel, hang-up; unanswered after 45 s is missed.
- The phones' setup messages pass through the server in memory only, to the other person only,
  and vanish when the call ends (400 per person per call). The live-update nudge says only which
  call changed. Nothing about a call's content is stored: the record is who, kind, times and
  outcome, kept 90 days; a call still live after 6 hours is closed by the hourly job.
- Production calls are relay-only (TURN, with per-person two-hour credentials), so neither person
  learns the other's IP address. Without a relay, calls are off and the app is told so; direct
  calls exist only behind the development switch `VAWRA_CALLS_DEV_P2P=1`.
- A block, unmatch, suspension, deletion request or taking back readiness ends a live call at
  once; every call step also re-checks the conversation, so a missed hook still ends it. To the
  other phone a block looks like any hang-up.
- 15 new tests. Breaking each rule in turn (13 breaks: the four end-of-contact hooks, the re-check,
  busy, readiness, own-messages filter, callee-only answer, hourly limit, flood limit, relay
  requirement, strangers) fails a test every time; the suspension test first passed with its hook
  removed, because the re-check covered it, and now reads the stored state directly.
- Backend 144 tests pass.

## BE-17 - Load and abuse testing (2026-09-29)

- Blocks never leak: a seeded random test (three sequences, 60 steps, six members) checks after
  every step that each blocked pair cannot see or reach each other anywhere: Discover, Likes you,
  chat lists, sending, reading, liking; unblocking never reopens a chat. Removing the block check
  from Discover's eligibility rule fails it at once. Runs with the normal suite.
- `npm run load`: 100 members, about 300 matches, 3000 mixed requests. Reads stay fast (median
  4-17 ms); with 25 people at once, likes and messages queue for about 0.6 s, and one at a time they
  take 7-8 ms, with the same throughput (about 115 a second) either way. The cause is the
  development database running one transaction at a time, not the service code; production
  PostgreSQL runs them in parallel. Written up in `docs/LOAD_TEST.md` with what still needs a
  staging run on real hosting.
- Backend 129 tests pass.

## BE-16 - Photos in chat: allowed per match, checked first, blurred until tapped (2026-09-29)

- In a chat, "Allow photos from Maya" (off by default) lets that one person send you photos. The
  photo button explains kindly when the other person hasn't allowed yours.
- A sent photo goes through the same one-time upload, checks, metadata removal and moderator review
  as a profile photo ("Sent for a quick check. It appears in the chat once approved."). It arrives
  only if the match is still open and photos are still allowed, blurred ("Photo · Tap to see")
  until the receiver taps it, with "Report this photo" once seen. The chat list says "Photo".
- Links re-check that the viewer is one of the two people in an open, unblocked match; unmatching
  or blocking ends access. Chat photos never show as profile photos or count toward the six.
- No sexually explicit media anywhere: moderators reject it in chats as in profiles.
- Tests: backend 126 (consent required, delivery only after approval, not a profile photo, consent
  withdrawn before review stops delivery, unmatch ends access, outsiders refused); delivering
  without consent or leaking chat photos into profiles each fails a test. Flutter 219 (consent
  switch, blurred then revealed with report, refusal when not allowed, sending when allowed).

## BE-15 - Scam warnings in chat (2026-09-29)

- A message that asks for money, gift cards, crypto or payment apps, moves the chat to another app
  or to a phone number or email, or carries a link now shows a gentle warning under it, for the
  person receiving it only ("Asked for money? Never send money, gift cards or crypto to someone
  you haven't met."), with a Report button that preselects "Scam" and this message. Nothing is
  blocked and the sender is not told.
- Screening is on the server (`backend/src/safety_hints.ts`) and aims at requests, not mentions: "I
  sent my mum money for her birthday" is not flagged.
- Also fixed: in server builds the chat report said "Prototype only ... not sent to a review team",
  which stopped being true with BE-11. It now says the report goes privately to Vawra's moderators,
  who see only the message included, and the button reads "Send report".
- Tests: backend 120 (14 risky examples flagged, 6 innocent ones not, warnings only to the
  receiver); Flutter 217 (warning under the risky message only, one-tap report with the message
  and "Scam", live wording).

## BE-14 - Private places: distance hidden at home, and the server never knows where (2026-09-29)

- Settings > Distance > Private places: "Hide my distance at this place" adds where you are (up to
  three). Within about 3 km of a private place the app sends no area and removes the one on the
  server, so nobody sees a distance to you there; Settings says "Hidden right now: you're at a
  private place". Away from them distance works as before. Remove a place any time.
- Private places, and whether you want distance at all, live only on the phone (encrypted secure
  storage); the server never learns them. Tests check that no request after a place becomes
  private carries it.
- Tests: Flutter 216 (one existing skip): hidden at a private place with the old area removed,
  normal away from them, add and remove, the private coordinates never in any request. Ignoring
  private places on start fails a test. Phase 2 work that needs no provider is now done.

## BE-13 - Retention, backup and recovery, and a security review (2026-09-29)

- Retention: an hourly job clears used sign-in codes, ended sign-ins, rotated tokens, unsent
  uploads, rejected photo records, old audit rows and long-decided reports, on a written schedule
  (`DATA_LIFECYCLE_CONTRACT.md`). A device unused for 90 days signs in again.
- Backup and recovery: `npm run dev:backup` / `dev:restore` snapshot and restore the local
  database with the photo files, keeping seven. Drill on the real local data: 267 accounts, backup
  9.7 s and 6.1 MB, restore 3.7 s; afterwards an existing session and a fresh sign-in both worked
  (`docs/RECOVERY.md`). An automated test restores a backup into a new database on every run.
- Security review 1 (`docs/SECURITY_REVIEW.md`), with fixes:
  - sign-out now ends the device's whole sign-in, not only its current token;
  - the in-memory rate limiter forgets finished windows (it grew without end);
  - likes stop at 300 a day and reports at 20 a day (bots and queue floods); passes and blocks stay
    unlimited, and the app explains both limits;
  - every response carries `nosniff` and `no-store` unless a route sets its own caching;
  - Android backup and device-to-device transfer are off, so tokens and cached data stay on the
    phone (checked in the built APK).
  Open items are listed there: shared rate-limit store, device attestation, production HTTPS and
  encrypted backups, a staff sign-in, and an independent pen test.
- Tests: backend 99 (retention and the live sign-in surviving it, idle expiry, backup-restore
  round trip, rotation, like and report limits, limiter memory, headers). Flutter 213.

## BE-12 - Profile photos, checked by a person before anyone sees them (2026-09-29)

- Profile > Photos: pick up to 6 from the phone's gallery (the system picker; no new Android
  permission). Each shows "Waiting for review" until a moderator approves it; a rejected photo says
  why in plain words. Tap a photo to make it the main one or delete it.
- The server accepts an upload only through a one-time, 10-minute link bound to the exact type,
  size and SHA-256; it checks the file signature, decodes with a 40-megapixel cap, and re-encodes to
  WebP with all metadata removed (GPS, camera, dates). The original is never stored.
- Moderators get a Photos tab: Approve, or Not approved with a reason. Rejected files are deleted.
- Viewing uses 15-minute signed links bound to the photo, the viewer and the purpose; the server
  re-checks access on every read, so a block, suspension or deletion ends it even for old links.
  Cards, Likes you and the details sheet show approved photos; account deletion removes the files.
- Local stand-ins for now: a disk store instead of an object store, and human review instead of
  malware scanning and automated classification (recorded in `MEDIA_UPLOAD_CONTRACT.md`).
- Found on the way: the widget-test fake server decoded every request body as text, which corrupts
  binary uploads; it now keeps raw bytes.
- Tests: backend 91 (metadata really gone, single-use grants, size/hash/type/signature, truncated
  files, a 48-megapixel PNG, forged and expired links, access after block and suspension, the
  6-photo limit, moderator rules, ordering, deletion). Keeping metadata, skipping the access
  re-check, or lifting the pixel cap each fails a test (a reused grant is blocked twice, by the
  grant and by the state). App 213 (one existing skip): upload and review badge, cancelling the
  picker, main/delete, photos on cards (removing them fails a test), moderator approve and reject.
  The APK still asks for only INTERNET and coarse location. Not yet on a phone.

## BE-11 - Moderation: review reports, suspend, appeal (2026-09-29)

- Reports were stored but nobody could act on them. Moderators (a role on the account) now get a
  Moderation page from Settings: pending reports with the reason, the person's name and bio, how
  often they have been reported, how many reports the reporter has made, and only the one
  reported message as evidence. The reporter is never named. Dismiss or Suspend, each confirmed,
  with an optional note for moderators.
- Suspending signs the person out everywhere, hides them from Discover and Likes you, closes
  their conversations and settles every open report about them. Signing in again shows "Your
  account is suspended", why and since when, and an appeal form; downloading their data,
  deleting the account and signing out stay available. Pause, resume and delete-then-cancel
  cannot lift a suspension.
- One open appeal at a time; the moderator who suspended someone cannot decide their appeal, so
  a second person always looks. Overturning restores the account as it was.
- Every decision needs a recent sign-in (an older one confirms with a code and comes back to the
  page), is audited, and never touches the moderator's own reports. `/v1/mod/*` answers 404 to
  members. Notes and who decided never reach the member or their export.
- `npm run dev:moderator -- <email> [--remove]` makes a local test account a moderator (local
  database only; there is no staff sign-in yet).
- Found by the tests and fixed: the decision dialog disposed its note field while still closing,
  which throws on a phone.
- Tests: backend 82 (visibility, evidence, own-report conflict, dismiss, suspend effects, recent
  sign-in, appeals and the second moderator, input, export, delete-and-cancel); letting moderators
  see their own reports, dropping the second-moderator rule, skipping the sign-out or leaving
  chats open each fails a test. App 208 passed (one existing skip): suspended screen and appeals,
  no Moderation row for members, evidence and confirm, the code step, the second-moderator rule
  in the UI; removing the suspended screen fails three tests. Not yet on a phone.

## BE-10 - Distance from an approximate area, never an exact spot (2026-09-29)

- Cards used to say "Distance hidden" for everyone. Settings > Discover now has "Distance": turned
  on, the phone rounds its location to a square about 2 km across and only that is sent; people
  see a band ("Under 5 km away", "5–10 km away" ... "Over 100 km away"), never an area or an exact
  distance. It is off until the person turns it on, and turning it off removes it at once.
- Android asks for coarse location only; the location plugin's background-service permission is
  removed from the merged manifest. The release manifest also gains INTERNET, which it lacked
  (only debug and profile builds had it, so a release build could not reach the server).
- Server: migration 007, `PUT`/`DELETE /v1/me/location`, the same grid re-applied on the server,
  the cell sealed at rest, bands in Discover and Likes you only when both have an area and the
  viewed person shows distance, one new area per 15 minutes, no teleporting, the cell in the
  person's own export. A bug found on the way: cell centres at the date line fell outside
  -180..180 and would have been refused; now wrapped, with a test.
- The quiet refresh on app start only uses a permission already given and never prompts.
- `npm run dev:seed-demo -- --near <test email>` gives demo members made-up areas 1-150 km from
  that test member's area (remove and re-seed first), so every band can be seen in testing.
- Also: the export page lists Distance on/off, and the export's daily limit now says "5 times a
  day" instead of the sign-in wording.
- Tests: backend 73 (grid, bands, sealing, the other person's setting, likes-you, limits, clearing,
  export, input); removing the server's rounding or ignoring the other person's setting each fails
  a test. App: Dart grid matches the server's output exactly; distance on/off, refused permission,
  the 15-minute message, bands on cards, quiet refresh never prompting (making it prompt fails a
  test). Flutter 201 passed (one existing skip). Not yet tested on a phone.
- The built APK asks for exactly INTERNET and ACCESS_COARSE_LOCATION (checked with aapt).
- Build and test reliability: `kotlin.incremental=false` in `android/gradle.properties` (Kotlin's
  cache failed with plugins on C: and the build on D:), and the backend runs 4 test files at a time
  (10 at once starved each other; a 3 s test timed out at 30 s).

## Web-2 - The website preview, fixed in place (2026-09-28)

- Review of Codex's Web-1 site found: a broken "It's a match" screen on the live preview (button
  text drawn as blocks; it was an unfinished render from Claude's screen harness that Web-1
  committed), fonts named but never loaded, 6.3 MB of PNG images, none of BE-8/BE-9 shown, and
  video calls described as if they existed. Codex's design is kept.
- Screens are now 720px WebP (7 images, about 330 KB in all; the page's images went from 6.3 MB to
  under 0.4 MB). "Connect" shows the openers chat instead of the match screen. A new "New in the
  app" section shows why-you-might-click, "Who would you like to meet?" and "Your data", from the
  Asus device test.
- Manrope and Playfair Display italic are served from the site with their OFL licences; checked in
  Chrome that both load, no image is broken and nothing scrolls sideways at 1366px and 390px.
- The calls line now says calls are planned and not built. The preview caption no longer sits
  unreadably over the phone. Favicon 7 KB (was the 1.2 MB mark).
- `website/check.ps1` also checks image weight (200 KB cap), WebP screens, the font files and
  licences, and that calls are not described as existing; removing a font or restoring the old
  calls line fails it.
- The screen harness is `tool/site_screens_test.dart` (outside the test suite) and writes to
  `build/`, so unfinished renders can no longer land in `website/`.

## Web-1 - Vawra product-site preview (2026-09-28)

- Built a standalone static website in `website/`, adapting the owner-shared QuietWall
  artifact's product-site structure to Vawra: hero, real prototype screen preview,
  experience/features, safety commitments, FAQs and responsive navigation.
- Reused the approved transparent Vawra lockup and existing current app screenshots.
  Every displayed person is a synthetic prototype fixture; the website says so and
  does not imply a live service, available app-store release, waitlist or paid plan.
- No tracking, forms, remote fonts or external runtime assets. The gallery supports
  pointer and keyboard tab switching, the mobile menu has expanded state, and CSS
  includes compact-phone, tablet and reduced-motion rules.
- `website/check.ps1` passes (links, assets, screen mappings, disclosures and CSS
  rules). The live GitHub Pages preview was checked in Chrome at desktop and
  390px phone width; the images load and a decorative horizontal overflow found
  on the phone was corrected. Further device/browser review is still useful.
- A clearly labeled prototype preview is published at
  https://anilise09.github.io/vowra/ from the `gh-pages` branch. This is not
  a public launch of the dating service.
- Publishing remains blocked on trademark/domain clearance and production legal,
  privacy, security and age-assurance gates.

## Device - BE-8, BE-9 and the WebP build on the owner's Asus (2026-09-28)

- Asus ASUS_I003DD over wireless adb, profile build against the local test server; install checked
  by md5. Phone checked for calls and foreground app before every step.
- Portraits: WebP cards look as sharp as before on the phone.
- "Show me" on an existing account (Alex): set "I am: Man, Show me: Women" in the Profile editor,
  saved; Discover dropped the man on top and showed women. The export confirmed both were saved.
- New member (Sam, synthetic): all 9 onboarding steps, including "How do you identify?" (Continue
  stays off until chosen) and "Who would you like to meet?" (Men; Everyone cleared itself). After
  the age gate (cleared with the local `dev:assure` tool), the first 8 Discover cards were all men,
  checked against the fixture. The details sheet shows "Gender: Man" for demo members.
- Download my data: an old session asks for a code first; after it the page opens, Copy shows
  "Copied", and Back returns to Settings.
- Found on the phone and fixed: the export page's label/value rows drifted towards the centre and
  the Account card did not span the page (a Wrap with spaceBetween). Now two fixed columns and
  full-width cards; a new test checks the columns line up and fails on the old layout, plus a
  visual baseline and a 1.8x text check. Flutter 192 passed (one existing skip).
- Left as found: the phone is signed in as Alex again with "Show me: Everyone"; no files on the
  phone. The phone's clipboard holds Alex's synthetic export from the Copy check.

## BE-9 - Download a copy of your data (2026-09-28)

- Settings > Privacy has "Download a copy of your data" (server builds only), and so does the
  "Your account will be deleted" screen, so a person can take their data before it goes. The
  page shows the account, profile, activity counts and matches in plain sections, lists what is
  not in the file, and "Copy the full file" puts the JSON on the clipboard. Nothing is written to
  the phone.
- `GET /v1/me/export` needs a recent sign-in, like deletion; an older sign-in confirms with a code
  first, and Back then returns to Settings. 5 copies a day, `no-store`, audited by kind and time.
- The file holds only the person's own data: the messages they sent (never what others sent them),
  the other person's display name only, no account IDs, no lookup keys or tokens.
- This is a smaller first step than the contract's asynchronous archive, recorded there: the server
  stores no media yet. The archive replaces it when photos arrive.
- Tests: backend contents and exclusions, recent sign-in, pending deletion, daily limit (removing
  the sign-in check or leaking the other person's messages each fails a test); app export from
  Settings with copy, the code confirmation and Back, and from the deletion screen (skipping the
  return to Settings fails a test). Checked on the local server with a synthetic member. Flutter
  190 passed (one existing skip), backend 62.

## Size - The app drops from 729 MB to 138 MB (2026-09-28)

- The 260 sample portraits (plus one extra photo) were 615 MB of PNG. They are now WebP at quality
  85 and full resolution: 44 MB. A side-by-side crop is indistinguishable; the changed visual
  baselines differ by at most 13/255 per pixel (mean under 1), with no layout movement.
- The first rebuild still reported 720 MB although the APK held only 138 MB: Gradle's incremental
  packager left the old entries as dead space. A clean package gives 138.3 MB for all three CPU
  types; a per-CPU store build will be smaller still.
- Every reference moved to `.webp` (app, fixture, generator, tests). The local test server's demo
  members were re-seeded so their portraits point at the new files.
- Seven untracked `np_*.png` portraits (about 18 MB, not referenced anywhere) still sit in
  `assets/profiles/`, so they are bundled; left untouched pending the owner's call.

## BE-8 - "I am" and "Show me": two-way gender matching (2026-09-28)

- Discover used to show everyone regardless of who a person wanted to meet. Onboarding now asks
  "How do you identify?" (Woman, Man, Non-binary; required) and "Who would you like to meet?"
  (Everyone, or any mix of Women, Men and Non-binary people; picking all three is Everyone).
  Setup is 9 steps. Both screens reuse the existing choice-card style; the current UI is kept.
- Matching is two-way on the server: two people see each other only if each is in the other's
  "Show me" (empty = everyone). The same check guards Discover, swipes and "Likes you". Someone
  with no gender set only appears to people open to everyone.
- "Show me" is private: it is only used for matching and never returned to anyone else. Gender is
  shown on a card's details only if the person turns on "Show my gender on my profile" (off by
  default). The Profile editor carries all three fields, so saving never wipes them.
- The 260 sample profiles got a reviewed gender each (`lib/data/demo_genders.dart`, from looking
  at every portrait); the export fails if one is missing. Demo members show their gender and are
  open to everyone. Prototype mode filters the sample people by your "Show me" too.
- Migration `006_gender_show_me.sql`. Tests: backend two-way matrix, swipe and likes-you guards,
  privacy of `show_me`, gender only when shown, invalid values (removing the reverse check fails
  two tests); app contract keys, API round-trip, onboarding to Profile editor (dropping "Show me"
  in the editor fails it), two new visual baselines. Flutter 187 passed (one existing skip),
  backend 57, analysis and type-check clean.

## UI-6 - Mobile page and platform audit (2026-09-28)

- Inspected the actual Welcome and seven onboarding steps on a dedicated Android 14 virtual
  device. The Welcome panel left excessive blank space on a tall screen; it now reaches the
  bottom of the safe viewport and still scrolls on compact phones. Added a regression test and
  updated the Welcome visual baseline.
- Expanded the device matrix from 18 to 22 cases: four iOS-style Flutter rendering runs add
  iPhone/Pro Max safe areas and normal/larger text. These are Windows widget tests, **not** an
  Apple simulator or physical-device validation.
- Full Flutter suite: 182 passed with one existing skip. Backend: 53 tests and type-check pass.
  Flutter analysis is clean and a debug APK builds. No Higgsfield credits used.
- A separate virtual device became unstable as Discover opened (system UI ANR); it was stopped.
  The existing shared emulator was not used further because QuietWall was in its foreground.
  Interactive Discover and other tabs on a phone and actual iOS simulator testing remain pending.
  See `docs/UI_PLATFORM_AUDIT.md` for the exact coverage and Mac handoff.

## UI-5 - Discover action hierarchy and connected Profile copy (2026-09-28)

- Discover's Pass and Like controls are now equal-sized primary actions, with plum Pass and
  coral Like matching the swipe meanings. Undo and details remain smaller secondary controls.
- Super Like is now a smaller blue star with a blue remaining-count badge. The shared-reason
  sparkle on the card remains distinct. Existing three-per-day behavior and swipe physics did
  not change.
- The shared Profile editor now distinguishes offline prototype copy from a connected account:
  the connected version explains that edits are saved when the user taps Save.
- Added focused assertions for action sizes, icon colors and icon identity, and for the
  connected Profile copy. Updated the deliberate Discover visual baseline.
- Verified `flutter analyze --no-pub` with no issues, all 177 Flutter tests with one existing
  skip (including the 18-case device matrix), and a debug APK build. The new APK has not been
  installed or reviewed interactively on the Samsung while the owner is on a call.

## UI-4 - Owner-directed brand and Apple-style polish (2026-09-28)

- The owner rejected UI-3 as too generic, especially the typed company name. Discover now uses a
  transparent horizontal extraction of the approved couple/heart mark and Vawra wordmark from
  the owner-supplied identity sheet; Welcome uses the same lockup without a white tile or border.
- Welcome now shows that logo in the first viewport over the existing ribbon artwork, with a
  gentle whole-background contrast wash and a calm reading panel. Removed the old floating
  circles/portraits composition. A visual test preloads its artwork before comparison.
- Discover has a restrained warm canvas, legible frosted disclosure and controls, one translucent
  action rail, and a shared glass-like navigation shell in both prototype and connected flows.
  The fifth action is clearly profile information, never a pre-match message. Existing gesture
  physics, reduced-motion behavior, coarse distance and free safety actions are unchanged.
- The owner's sample's unverified badge and unsupported percentage score were not copied. The
  synthetic/test-person disclosure remains on each card.
- Verified all 177 Flutter tests (one pre-existing skip), including 18 device/text-size cases,
  the 1.8x sweep, swipe physics and visual baselines. The visual tests now await bundled image
  decoding so a missing-image frame cannot be approved accidentally.
- Built and installed this revision on the owner's Samsung SM-S928W without clearing app data.
  Inspected the Welcome screen at native device size: the approved lockup appears over the
  artwork with no white tile or border; the reading panel and controls fit without overflow.
  Discover's final composition is covered by updated visual baselines and device-matrix tests,
  but has not yet been reviewed interactively on this physical handset.
- Final `flutter analyze --no-pub` found no issues; `git diff --check` found no whitespace errors.

## UI-3 - Reference-led Discover composition (2026-09-28)

- Reworked Discover from the owner's supplied sample: a quiet Vawra wordmark header, more room
  for the portrait, a warm five-action dock, and light navigation chrome. Removed the nonfunctional
  story preview strip. The fifth dock action opens profile details, not a pre-match message.
- Kept Vawra's own colors and synthetic portraits. The sample's verification badge, precise
  distance and percentage alignment score were not copied: none is supported by the product.
  The card can show its existing server-explained shared reason and an optional one-line intro.
- The dock adapts button diameter to narrow widths, the card remains width-capped on tablets,
  and decorative press motion is disabled when the system requests reduced motion.
- Verified `flutter analyze --no-pub` with no issues; all 177 Flutter tests passed with one
  existing skipped test, including the 18-case device matrix, 1.8x text, swipe feel and physics.
  Updated the affected visual baselines, inspected the Discover baseline, and built a debug APK.
  A phone was not
  connected to ADB, so physical-device inspection is still pending.

## UI-2 - Fits every phone, foldable and tablet (2026-09-28)

- New `test/device_matrix_test.dart` walks onboarding, Discover, profile details, a match and its
  chat, Explore, Matches, Profile and Settings on 9 devices (320x568 small phone, 360x640, S24 Ultra,
  Pixel/iPhone, Pro Max, Fold cover, Fold open, tablet portrait and landscape) with their status and
  navigation bars, at 1.0x and 1.3x text (the 1.8x sweep stays separate). Any overflow, or a control
  still covered after scrolling to it, fails. Before this checkpoint 17 of 18 runs failed; now 18/18.
- Fixed what it found: Explore tiles had a fixed shape their text outgrew (now sized from the text
  size, titles up to three lines, never cut); the "It's a match" screen overflowed short screens
  (now scrolls when it does not fit, still centred when it does); the date-safely guide sheet on
  very short screens; long labels in two photo pills (now shortened with an ellipsis).
- Tablets and open foldables: the app keeps a readable column (up to 720 wide, centred, Apple's
  readable content width) and the swipe card is capped at 560 instead of stretching to 1248.
- Phones stay upright (like other dating apps); tablets and open foldables turn freely; the rule
  re-applies when a foldable opens or closes.
- Coming back from an Explore hub returns to the same place in the grid (found by a test).
- The match screen no longer calls real accounts "Prototype match"; demo members say "Test profile".
  With reduced motion the match heart is simply there instead of popping.
- The Explore golden was updated after checking old and new side by side: same look, tiles ~13%
  taller so every title shows in full.

## UI-1 - Apple-style physics for the swipe card (2026-09-28)

Using the apple-design skill (WWDC "Designing Fluid Interfaces"), the look stays as approved and the
feel changes:

- Interruptible: catching the card while it springs back holds it where it was caught (the new
  gesture starts from the on-screen position, no jump). X and Y are separate springs.
- Momentum decides: a release projects where the flick is going (Apple's exponential-decay
  projection, rate 0.99) before deciding, so a quick flick from near the centre commits, and a
  flick back toward the centre cancels even past the line.
- No seam between drag and animation: the card springs home from the release speed (damping 0.8,
  response 0.35, a little bounce only because momentum preceded it) and flies off at the finger's
  speed instead of a fixed 260 ms.
- Tilt follows where it was held (lower half tilts the other way); dragging down meets soft
  rubber-band resistance instead of moving freely.
- One haptic tick when crossing the like/nope line, and the impact on the same frame the card
  leaves.
- Reduced motion (system "remove animations"): a short fade instead of flying and no bounce.
- `lib/features/discovery/swipe_physics.dart` (pure, 8 tests) and 5 widget tests of the feel;
  removing "stop on grab" fails the interrupt test.

## Dev - The 260 sample profiles on the local test server (2026-09-27)

- The owner asked where the 250+ profiles went: they are the prototype's bundled synthetic people,
  and the server build shows only accounts on the server. `npm run dev:seed-demo` now loads all 260
  into the local test database as age-verified demo members with their bundled portraits (idempotent;
  `--remove` takes them out). The fixture is exported from `lib/main.dart` by
  `tools/export_demo_profiles.py`; goals and bios fit the server's rules, two stray interests are
  dropped or mapped; habits are assigned deterministically so reasons stay stable.
- Safeguards: the seed refuses a real database, the `demo_portrait` column cannot be set through
  the API (strict PATCH, tested), only `assets/profiles/` paths are shown, and the app labels these
  people "TEST PROFILE · NOT A REAL PERSON".
- Loaded on the laptop's test server: Alex's Discover now starts with the closest fits, each with
  a portrait and reasons (e.g. Junjie, "You both like Books, Music and Travel").
- Gap this exposed: Discover has no gender / "who I want to meet" setting yet, so everyone sees
  everyone. Next.

## Fix - Chats open at the newest message and follow new ones (2026-09-27)

- Seen on the owner's Samsung: Maya's message arrived in 0.4 s but below the visible area, and a
  long chat opened at the top. The thread is now a reversed list (offset 0 is the newest message),
  sized to its content and pinned to the top, so short chats look exactly as approved (the chat
  golden is unchanged) and long chats open at the latest message. New messages and "is typing" are
  followed only when the person is already near the bottom, or when the message is their own.
- A first attempt that jumped to the list's estimated end fell short on long chats (lazy layout);
  the new test caught it.
- Also confirmed on the Samsung against the local server: signed in stays signed in across an
  update and relaunch; the "Why you might click" pill and details; unread badges; "Seen" and
  "Maya is typing..." when both share; a message pushed from another account arriving in 0.4 s.

## Fix - Found on the owner's Samsung: body-less requests and system-button insets (2026-09-27)

- Real bug, missed by every test: the app sent `Content-Type: application/json` on requests with no
  body, and the real server (Fastify) rejects that with 400. It silently broke marking chats read,
  typing, pause and account deletion. Fixed in the app (the header only with a body) and on the
  server (an empty body with a JSON content type is accepted; invalid JSON still gets 400). The
  in-memory test server now rejects the same way Fastify does: with the old client code 17+ app tests
  fail. A backend test covers body-less POSTs (it fails without the server fix).
- Samsung three-button navigation hid part of the bottom bar and the profile sheet's Pass/Like row.
  Both now sit above the system buttons (bottom safe area). New `test/insets_test.dart` simulates a
  48 dp navigation bar; removing the sheet's safe area makes it fail. Goldens are unchanged.

## BE-7 - Openers from what you share (2026-09-27)

- An empty chat now suggests up to three first lines under "Start with something you share": the
  other person's prompt answers first ("Okay, I am asking: tell me about my sourdough starter!"),
  then shared interests ("You like books too! What are you reading at the moment?..."). Tapping one
  fills the message box; nothing is sent until the person sends it, and the suggestions go away
  after the first message.
- `/v1/matches` adds `shared_interests` (computed on the server, the peer's full interest list is
  not sent) and `peer_prompts`. Lines are written by hand in `lib/domain/openers.dart`; no text
  generation service is involved.
- Tests: backend shape (and that the peer's interest list is not exposed), opener wording and order,
  and an app flow where tapping an opener sends nothing until Send.

## BE-6 - Better conversations: unread, "Your turn", mutual read receipts and typing (2026-09-27)

- Chats now show an unread count per conversation and in the Chats tab, and "Your turn" when the
  other person wrote last; conversations are ordered by the latest message. Opening a chat marks it
  read once a new message from them is on screen (not while the app is in the background), and your
  other devices clear their badge through a nudge.
- Read receipts and typing are free and mutual: they appear only when both people turn on "Read
  receipts and typing" in Settings (Tinder sells read receipts). The server checks both settings for
  every "Seen" and every typing signal, answers the same whether or not the other person shares, and
  lets typing through at most every 3 seconds per chat. Typing travels as a content-free nudge;
  "Maya is typing..." clears after 6 s or when her message arrives.
- Server: `match_reads` table, `unread`, `last_message_mine` and latest-first order on
  `/v1/matches`, `seen` on your messages only when both share, `POST /v1/matches/{id}/read`,
  `POST /v1/matches/{id}/typing`, `GET`/`PATCH /v1/me/settings`.
- Tests: 6 backend (unread and turn, ordering, Seen needs both, typing needs both and is throttled,
  settings strictness, participants only; making receipts one-sided fails a test) and 4 app flows
  (unread then Your turn, Seen and typing only when shared, typing throttled, settings switch;
  removing mark-as-read fails a test).

## BE-5 - "Why you might click": Discover ranked by what people share, and says so (2026-09-27)

- Tinder's ranking is a black box. Vawra now orders Discover by visible, additive compatibility
  only: same goal (+3) or long-term and open-to-long-term (+2), each shared interest (+1), each
  matching habit (+0.5). Never popularity, swipe rates or looks. Rules and wording live in
  `backend/src/compatibility.ts`; ties keep the oldest account first.
- Discover returns up to three reasons per person (goal, shared interests, habits). The card shows
  the most telling one as a pill (shared interests first, since the goal has its own line), and the
  profile details list them under "Why you might click", with a line saying Vawra never ranks by
  popularity or looks. Unknown reason kinds from a server are ignored.
- Tests: scoring and wording, a Discover order test in which three extra likes for one person
  change nothing (removing the sort makes it fail), and an app flow for the pill and details.

## BE-4 - Learned from Tinder's open source: nudges instead of polling (2026-09-27)

- Researched all 18 public repositories at github.com/Tinder and their linked engineering
  articles; findings and what Vawra does with each are in `docs/TINDER_GITHUB_LEARNINGS.md`.
  Ideas only: their code is Match Group's (modified BSD-3) and nothing was copied.
- Biggest lesson applied: Tinder replaced 2-second polling with "nudges", tiny content-free "something
  changed" pushes after which the app fetches normally. Vawra now has `GET /v1/events`, an
  authenticated Server-Sent Events stream of `{kind: message|match|like, match_id}`, with no text,
  names or photos. A like nudges the person liked, a match both people, a message the other person
  and the sender's other devices; blocking is never announced; a stream ends with its access token;
  five streams per account; an in-process bus behind an interface for a shared broker later.
- App: the connection is a pure state machine (idea from Tinder's StateMachine/Scarlet) run by a
  small driver; reconnects use exponential back-off with full jitter (1 s base, 60 s cap); every
  (re)connect triggers a catch-up refresh; the stream and timers stop a second after the app goes to
  the background and resume when it returns (Scarlet's lifecycle idea). Chats reload on their nudge;
  timers remain only as a safety net (30 s per chat and 60 s for matches while streaming, the old 3 s
  and 10 s when the stream is down).
- Measured live against the local server with the real Dart client: a message reached the other
  app as a nudge in 25-39 ms (three runs), where polling took up to 3 s.
- Tests: 7 backend stream tests (auth, no content, isolation, the sender's other devices, like and
  match, block silence, token expiry, stream limit), 7 app unit tests (state machine table,
  back-off bounds and spread, SSE parser) and 5 app flows (instant reply, silent change waits for
  the safety refresh, fallback without a stream, reconnect with catch-up, background and resume),
  plus an opt-in live test. Injected defects (announcing a block, putting text in a nudge, a chat
  ignoring nudges, not stopping in the background) each made a test fail.
- Found while testing: the safety timers measured wall-clock time, which tests cannot advance; they
  now count ticks, same behaviour on devices.
- The dev server's default port moved from 8787 to 8797: QuietWall's website dev server uses 8787
  on this laptop and silently answered Vawra's requests.

## BE-3c - Habits and prompts are saved to the account and shown to others (2026-09-27)

- Profile contract gains two optional public fields: `lifestyle` (one answer per topic from the
  app's fixed lists) and `prompts` (up to two answers to distinct fixed questions, 1-150
  characters). The server repeats the lists and limits; anything else is refused. Recorded in
  docs/BACKEND_API_CONTRACT.md and in the app's `ProfileMutation`, which the API client now uses to
  build every profile save.
- Discovery and likes-you return them, and a real person's profile details now show a Habits row
  and each prompt; unknown values from a server are ignored, never shown raw. An empty bio no
  longer shows an empty "About" section; distance for real people says it isn't shown yet.
- Corrected my earlier note: the bio (the onboarding intro) was already saved; the onboarding
  privacy line now says answers are saved to the account.
- Tests: 2 backend (lists and limits), 2 app (round trip, details view). Removing the prompts from
  the card makes the details test fail.

## BE-3b - Account deletion from inside the app (2026-09-27)

- Server: `POST /v1/me/deletion` needs a sign-in within the last 10 minutes (server setting); an
  older session gets `reauthentication_required` and the app asks for an email code first. It then
  signs the account out on every device, hides it from discovery, likes-you and match lists,
  closes its chats for the other person, and returns the server's date (7-day placeholder until
  counsel sets it). `DELETE /v1/me/deletion` keeps the account (paused stays paused) until that
  date; after it, `410`. Resuming from pause can't undo a deletion (checked by removing the guard:
  the test fails).
- Deletion job (at server start and hourly) removes the account and everything tied to it,
  including both people's messages in its matches, its sign-in requests and the account id in audit
  rows; the same email can later start a new account.
- App: Settings > Delete profile explains the waiting period, confirms the person with a code when
  the sign-in is old, then shows "Your account will be deleted on <server date>" and that they are
  signed out everywhere. Signing in before the date shows the date with "Keep my account".
- Contract updated: pause keeps existing chats (recorded as a decision; the app always promised
  it); deletion implementation details; reports against a deleted account are removed with it
  until counsel decides on narrow abuse-evidence retention.
- Tests: 6 backend deletion tests (29 backend total) and 3 app flows (schedule, confirm with a
  code first, keep the account). The confirm flow test fails when confirming skips the deletion.
- Backend tests' setup timeout raised to 60 s: each test starts its own database and the laptop
  was at 99% CPU, which timed out setup, not the code.

## BE-3a - Stay signed in across restarts; one refresh at a time (2026-09-27)

- The refresh token (and account id) is kept in platform-protected storage
  (`flutter_secure_storage`: Android Keystore, iOS Keychain), as SESSION_CONTRACT requires. The
  access token is never stored; a restart rotates the saved token for a fresh one.
- App start in account mode shows the Vawra mark while it resumes: a live session opens Discover
  (or profile setup / the age check), a session the server ended is forgotten and Welcome shows,
  and an unreachable server offers "Try again" without losing the saved session.
- Fixed a real sign-out bug found while doing this: Discover loads three things at once, and near
  expiry each call rotated the same refresh token, which the server correctly treats as reuse and
  revokes the whole session. Rotation is now shared; a test with three parallel calls proves one
  rotation, and fails with 3 when the fix is removed.
- Sign-out clears the stored token. 115 app tests, analyzer clean; new dependency only
  (`flutter_secure_storage`), no existing package changed.
- Device check incomplete: on the Android 17 AVD the build installed and the start screen moved to
  Welcome with no saved session, but the laptop hit 96% CPU with ~1 GB free (two emulators), input
  started dropping characters, so I shut my emulator down before the restart check. Repeat the
  restart check on a device when the machine is quieter, and measure cold-start time there (the
  overloaded AVD skipped ~5 s of frames on start).

## BE-2 - The app talks to the real backend (2026-09-27)

- Build with `--dart-define=VAWRA_API=<url>` and the app uses a Vawra account; without it, it is the
  unchanged offline prototype (all 109 prototype tests pass as before).
- New `lib/data/api/vawra_api.dart`: email sign-in with a one-time code bound to the device by PKCE
  S256 and state, session rotation a minute before expiry (a refused rotation signs out), profile
  (only the six contract fields, never age), pause, discovery, swipes, likes-you, matches,
  messages, block, report, sign out.
- New `lib/server/server_flow.dart`: sign-in screen; first sign-in reuses the onboarding and saves
  the profile; an honest age-check screen (dating stays closed until the server records a passed
  check); home with Discover, Matches, Chats and Profile reusing the approved UI; a chat list for
  every match; threads refresh every 3 s (no real-time service yet); Settings says what the server
  keeps, adds Sign out, and explains that account deletion needs the next update.
- Server people show a neutral "no photo yet" placeholder until the media service exists; the
  "prototype" labels, report and block wording change to real-account wording for them.
- Backend: three free Super Likes per rolling day enforced on the server; pausing keeps existing
  chats (the app already promised this, the server refused it); likes-you returns full profile
  fields; matches return the peer's account id. 23 backend tests.
- Tests: API client tests (PKCE, state, rotation, sign-out on refusal, contract fields) and
  server-mode widget flows against an in-memory stand-in (wrong code, new account to match and
  chat, sign out). A deliberately broken message refresh made the flow test fail, so it can.
- End to end on the Android 17 Pixel AVD against the local server: code from the dev outbox, new
  profile saved, age gate held, local age stand-in, three synthetic members in Discover, a like that
  matched, a message from the other account shown in Chats, a reply stored on the server, and the
  next message arriving by refresh. The AVD's emulator crashed once mid-run (qemu, known on this
  laptop) and the run continued after relaunch; the server state was intact.
- Found on device and fixed: onboarding still said "This prototype keeps your answers on this
  device only" in account mode.

Next: keep the session in platform-protected storage so a restart stays signed in; account
deletion with re-authentication; move habits and intro to the server; profile photos with the
media service. Release builds need INTERNET and an HTTPS server before any public test. The APK is
~725 MB because of the bundled portraits and needs compressing before distribution.

## BE-1 - Backend core: sign-in, sessions, profile, discovery, matches, chat, safety (2026-09-27)

- New `backend/` (TypeScript, Node 22, Fastify, zod). PostgreSQL through PGlite for development and
  tests (no install or admin rights); `DATABASE_URL` switches to a real PostgreSQL server.
- Ships switched off: refuses to start without `VAWRA_SERVER_ENABLED=1`, binds 127.0.0.1, requires
  data and lookup keys. No production deployment exists.
- Implements the contracts' first slice: non-enumerating passwordless requests, one-time PKCE-bound
  proofs, rotating refresh with family revocation on reuse, sign out and sign out everywhere,
  recovery revoking sessions; own-profile read/patch limited to the six contract fields with the
  app's validation; pause/resume; age gate on all dating features; eligible-only discovery,
  idempotent swipes (like, super like, pass), reciprocal-only matches, free likes-you; participant-
  only chat with validation and 5-a-minute limit; block fan-out in one transaction; private reports
  with a checked message reference; bounded audit events.
- Emails are sealed (AES-256-GCM) and looked up by keyed hash; tokens and proofs are stored hashed.
- 21 tests over real HTTP routes. They caught and fixed three real bugs before commit: an SQL
  alias clash that leaked paused and unverified people into discovery, a failed proof exchange
  being rolled back to unused, and refresh-reuse revocation being rolled back.
- Smoke-tested the built server: off by default, health, sign-in, age-gated discovery, no tokens or
  emails in logs, listening on 127.0.0.1 only.

Next (BE-2): connect the app to the backend behind a development switch; the app keeps its
synthetic prototype when the server is unavailable. Providers (email, OIDC, age assurance,
location, media) wait for review.

## CP-066 - On-device extras: emoji and quick replies, notifications, travel mode (2026-09-27)

- Chat: an emoji button opens a panel with an Emoji grid and Quick replies (conversation starters that
  fill the message box). Messages made only of up to three emoji show large without a bubble.
- Settings > Notifications: New matches, Messages, Likes you, Safety tips switches, kept between visits,
  with an honest "Nothing is sent yet" note (no notification service exists).
- Settings > Travel mode: pick a city by hand, never from GPS; Discover shows "Browsing in <city>" with a
  close button. The banner says plainly that sample profiles stay the same for now.
- The owner declined spending image credits and chose these on-device items over starting the backend
  or paywall mock-ups. Monetization, verification, photo upload, active status, Missed Connections and
  Double Date remain blocked for the reasons in the teardown gap table.
- Checked on Pixel_10_Pro_XL_34: emoji panel, big-emoji message, Settings sections, travel city. The
  emulator crashed twice with an access violation in qemu itself (not the app; config already stable).
- Verified: `flutter analyze` no issues, 99 tests pass (3 new), goldens refreshed, debug APK builds.

## CP-065 - Several photos per card, ready but unused (2026-09-27)

- Cards show a segment bar and flip photos on a tap to the right or left of the photo; the details sheet
  has a swipeable photo pager with dots. Photos come from `lib/data/profile_photos.dart`, empty for now.
- The owner chose not to spend Higgsfield credits on extra portraits, so every profile still has one
  photo and the bar stays hidden. Adding entries to the map turns the feature on with no other change.
- Verified: `flutter analyze` no issues, 96 tests pass (2 new).

## CP-064 - Explore hubs, chat list and conversation, prompts; checked on an AVD (2026-09-26)

- Explore tab (5th tab): nine hubs built only from what people chose (2 relationship goals, 7 interests)
  with live counts; each opens its own swipe deck with a back arrow.
- Chats: a list with a new-matches row and conversation rows (last message, time); the conversation has a
  header with back, call and safety menu, a compact call-readiness switch, day and time labels, "Sent"
  under own messages, double-tap heart reactions, and a composer pinned to the bottom with a send button.
  A gentle "Are you sure?" appears before sending a message with hurtful words (edit or send anyway).
  "Send a message" on the match screen opens the conversation directly.
- Profile prompts: up to two, picked from Vawra's own questions, answered in 150 characters, shown on the
  preview and counted in Profile strength (now 4 items).
- Walked the build on Pixel_10_Pro_XL_34 (Android 14): sign-up, tutorial, deck, Explore, Foodies hub,
  match, safety guide, conversation, prompt editing. The AVD went offline near the end without a crash
  report; the prompt preview is covered by tests.
- The teardown now ends with a gap table: what is done and what is blocked, and why.
- Verified: `flutter analyze` no issues, 94 tests pass (4 new), goldens refreshed, debug APK builds.

## CP-063 - On-device fixes from a real Asus walkthrough (2026-09-26)

- Walked the new build on the Asus: sign-up, tutorial, drag with LIKE stamp and tilt, match celebration,
  swipe-up Super Like (count 3 -> 2). Found and fixed two bugs the widget tests could not see:
  sign-up steps were vertically centred (large empty gap above the question), and the keyboard did not
  open on the age step because the name field kept focus during the page transition. Steps now anchor to
  the top and each text step requests focus explicitly; choice steps close the keyboard.
- Match celebration background is now opaque, and the Welcome panel reaches the bottom edge.
- Verified: `flutter analyze` no issues, 90 tests pass, goldens refreshed, APK installed on the Asus.

## CP-062 - Real swipe deck, Super Like, match celebration, swipe tutorial (2026-09-26)

- Owner feedback: swiping had no motion and Super Like was missing. The teardown recorded screens but the
  UI pass missed interaction feel; this checkpoint fixes that.
- New `SwipeCardStack`: the card follows the finger, tilts around a low pivot, shows LIKE / NOPE / SUPER
  LIKE stamps that fade in with distance, flies off with momentum (distance or fling velocity), springs
  back elastically when released early, and the next card grows into place behind it. Buttons drive the
  same animation (a short lean, then fly-off) and press in when tapped; light haptics on each decision.
- Super Like: swipe up or the blue star button. 3 free a day (count badge); when none are left, the swipe
  springs back and says so. Recorded as a like with a super flag. Details now open from the arrow button.
- "It's a match!" full-screen celebration with both people, an animated heart or star, the prototype
  disclosure, "Send a message" (opens Chats) and "Keep swiping". Replaces the old snackbar.
- First-visit tutorial overlay on the first card explains right/left/up and the details arrow.
- Discover no longer scrolls: header, story row (only when there is room), the card, the action row.
  Local like-event previews moved to the Matches tab; reported cards show "Report recorded: …".
- Verified: `flutter analyze` no issues, 90 tests pass (3 new swipe tests, 2 new goldens), large-text sweep
  covers the tutorial, debug APK builds.

## CP-061 - Photos card, photo tips, and a large-text sweep (2026-09-26)

- Profile tab: a Photos card states honestly that upload is coming and every photo will be checked first,
  and opens Photo tips ("Works well" / "Best avoided") written in Vawra's words with icons, no stock photos.
- New large-text test walks every main screen, sheet and dialog at 1.8x text on a 412x915 phone; it found
  and fixed two real bugs: the Discover story row clipped names (now sized from the text scale) and the
  Date-safely guide overflowed by 433 px (pages now scroll and the sheet height follows the screen).
- Test helpers scroll to Welcome consent boxes before tapping, so they work at any text size.
- Verified: `flutter analyze` no issues, 85 tests pass (2 new), goldens refreshed, debug APK builds.

Next: install on a phone and walk every screen at normal and large text; photo upload waits for the
media pipeline; Explore-style browsing waits for real users.

## CP-060 - Free "Likes you", free undo, distance filter, end of deck (2026-09-26)

- Matches tab: a "Likes you · Free" row shows people who liked you (Tinder paywalls this) with Pass and
  Like-back buttons; liking back creates the match through the normal swipe path. Clearer empty states.
- Discover: a free Undo button restores the most recent pass only (likes are never undone) and puts that
  person back on top. Preferences gain a distance filter (Any, up to 5/10/20/50 km) that compares only
  the far edge of each profile's band. The end of the deck now explains why it is empty and offers
  "Change preferences" and "See passed profiles again".
- Verified: `flutter analyze` no issues, 83 tests pass (5 new), discovery and connections goldens refreshed.

## CP-059 - Settings page with free pause and honest deletion (2026-09-26)

- A gear on the Profile tab opens Settings, grouped by purpose: Discover ("Show me on Discover"), Safety
  (date-safely guide, Safety center), Privacy (plain statement of what the prototype keeps), Account.
- Pausing is free: Discover shows a "Your profile is paused" banner with Resume; matches can still message.
- Delete profile is one honest dialog that says exactly what is removed, offers "Pause instead" once (not
  when already paused), then clears all in-memory data and returns to Welcome. No survey loop.
- Verified: `flutter analyze` no issues, 78 tests pass (2 new behaviour tests, 1 new golden; profile
  golden refreshed for the new header), debug APK builds.

Next: install on a phone and walk every new screen at normal and large text.

## CP-058 - Profile preview, profile strength, and editable habits (2026-09-26)

- "Preview my card" opens "How others see you": the person's own card built from the current form (name in
  bold with lighter age, intent, distance-band note, intro, interests, habits), with a placeholder where
  photos will go once uploads exist.
- A "Profile strength" card counts the optional pieces live (intro, 3+ interests, habits) with a progress
  bar and check chips; everything stays optional.
- The habits from sign-up are editable in the profile via a shared picker and are kept on save.
- Verified: `flutter analyze` no issues, 75 tests pass (3 new), profile golden refreshed.

Next: a settings page (discovery settings, pause profile for free, honest delete-profile flow).

## CP-057 - Sign-up additions from the teardown (2026-09-26)

- New optional "A few habits" step (drinking, smoking, exercise, pets): one choice per topic, tap again to
  clear, an icon and divider per group, Skip, and a live "Continue n/4" count. Answers are stored on the
  local profile and kept through profile edits; they are not yet part of the server profile contract.
- Headlines use the person's name after step 1; interests show "Continue n/5"; the intro step has a tip
  card. Fixed the Skip label wrapping onto two lines at large text sizes.
- Verified: `flutter analyze` no issues, 72 tests pass (1 new behaviour test, 1 new golden).

Next: profile tab with "Preview my card" and completion prompts; then a settings page.

## CP-056 - Full Tinder teardown and first UI pass from it (2026-09-26)

- Recorded Tinder 17.35.0 end to end on the owner's Asus: sign-in, all 21 onboarding steps, swipe deck,
  expanded profile, Explore hubs, Likes, Chat and its safety guide, Safety Toolkit, profile hub, photo
  editor and tips, every Settings row, all paywalls with prices, and the deletion flow. Findings, measured
  colours and a take/change/refuse list are in `docs/TINDER_UI_TEARDOWN.md`; raw captures stay local and
  git-ignored because they show other people. No likes or messages were sent; location stayed
  approximate and one-time; tracking and contacts were refused.
- Discovery card: name in bold with a lighter age, icon rows for intent and distance band, and the
  details button beside the name.
- Profile details: stacked section cards (Looking for, About, Interests, Distance, your report) ending in
  full-width "Block [name]" and red "Report [name]" rows with "free and private, never told".
- Chats: a header with a safety shield, a plainer empty state, and a three-page "Date safely" guide in
  Vawra's own words that opens on the first visit to Chats and can be reopened from the shield.
- Verified: `flutter analyze` no issues, 70 tests pass (2 new), discovery and chat goldens refreshed,
  debug APK builds. Not yet installed on a phone.

Next: install and walk through on a phone; then onboarding additions from the teardown (a promises step,
optional lifestyle chip groups with icons, bio tip card) and a profile hub with a "Preview my card" view.

## CP-055 - Progressive one-question onboarding (2026-09-26)

- Welcome now leads into a six-step profile setup instead of straight into discovery, following the
  one-question-per-screen pattern observed in the CP-054 walkthrough: name, age, relationship intent (large
  choice cards), interests (1-5), an optional short intro with Skip, and privacy/call defaults.
- A coral progress bar, "Step N of 6" label, Back that keeps earlier answers, and a single full-width Continue
  that stays disabled until the step is valid. Skip appears only on the optional intro.
- Adult boundary held in setup: a typed age under 18 shows "Vawra is only for adults 18+." and cannot proceed;
  the age field accepts digits only. Distance band defaults on (band only), calls default off.
- The finished profile is saved to the in-memory profile repository and pre-fills the Profile tab. The bio is
  now optional everywhere; a written bio still needs 20-300 characters. Interests share one domain list.
- Fixed a screen-reader crash found by the tests: the progress bar reports a numeric value, not step text.
- Verified: `flutter analyze` no issues, 68 tests pass (8 new onboarding tests), welcome/profile goldens
  refreshed and an onboarding golden added, debug APK builds. Not yet installed on the Samsung.

Next: install on the Samsung and walk the setup at normal and large text; then plain-language empty states for
Matches and Chats, and a photo step once the media-upload pipeline exists.

## CP-054 - Tinder/Bumble walkthrough and photo-first discovery gestures (2026-09-26)

- Walked through Tinder and Bumble on the owner's Samsung phone and recorded the observed discovery, navigation,
  profile-detail, onboarding, and empty/premium-state patterns in `docs/COMPETITIVE_UI_RESEARCH.md`. No
  competitor likes or messages were sent; the temporary Tinder account was deleted. Raw captures stay local in
  the git-ignored `screenshots/` folder because they show the owner's own account screens.
- Discovery now gives the photo about two thirds of the screen. Swipe right likes, swipe left passes, and swipe
  up (or the visible arrow) opens a scrollable details sheet with bio, interests, intent, distance band, private
  report, block, and Pass/Like. The separate "next profile" action is gone from the card.
- The direct-intro preview moved from the discovery scroll into the Safety Center sheet; the precise-location
  statement is shown there and in the details sheet.
- Work started by Codex and finished and verified by Claude Code: `flutter analyze` no issues, all 60 tests pass,
  discovery golden refreshed.

Next: progressive one-question-per-screen onboarding with visible progress and skippable optional steps.

## CP-053 - Owner-directed welcome and discovery composition (2026-09-25)

- Reworked welcome around the supplied dating-app reference: floating circular portraits, a central transparent
  Vawra mark, soft blush/lavender shapes, and a clean rounded onboarding panel with one primary action.
- Added a circular story/profile preview row to discovery, retained the immersive full-photo profile card, and
  replaced the default bottom bar with a navy floating pill and coral selected state. Chat bubbles now use the
  same navy, coral, blush, and soft-lavender visual language.
- Created `vawra_company_mark_clean.png`, a tightly cropped transparent in-app mark with stray pixels removed.
  Standalone logo use has no white background, containing tile, border, or shadow. Launcher assets remain
  unchanged.
- Preserved adult/consent gating, synthetic-profile disclosure, coarse-distance privacy, safety actions, and
  existing match/message/call rules. Added compact-height behavior and an explicit vertical-scroll target so
  the richer layout remains usable and testable on short viewports.
- Refreshed all five phone-sized golden baselines. Verified `flutter analyze` with no issues, all 60 tests, and
  a fresh debug APK build. Installed the exact APK on Samsung SM-S928W and visually verified both welcome and
  discovery, including the transparent mark, story row, photo card, and floating navigation.

Next: gather owner feedback from the installed build, then apply only specific requested refinements before
expanding this visual system into additional production flows.

## CP-052 - Reference-informed connections, chat, and profile redesign (2026-09-25)

- Reviewed the owner-supplied dating UI reference and the current Dribbble dating-app UI gallery. Reused broad
  interaction principles—layered photo cards, compact conversation chrome, asymmetric bubbles, and low-chrome
  navigation—without copying a specific composition or trade dress.
- Removed the white tile, border, and shadow from standalone in-app company-mark presentations. Welcome,
  discovery, and profile surfaces now show only the transparent approved mark.
- Rebuilt Connections around a full-photo mutual-match card with clear status and a single conversation action.
  Rebuilt Chat with a photo avatar, compact mutual-call control, softer asymmetric message bubbles, persistent
  safety actions, and a quieter composer. Reframed Profile editing with a branded hero and grouped privacy/call
  controls while retaining validation and prototype disclosures.
- Removed the generic per-tab app bars and gave each destination its own phone-safe hierarchy. Added 412 x 915
  golden baselines for Connections, Chat, and Profile; these caught and fixed narrow-phone overflows in the chat
  status line, intent dropdown, and interests heading.
- Verified `flutter analyze` with no issues, all 60 tests, and a fresh debug APK build. Physical Samsung
  installation is pending because the previously connected SM-S928W was not visible to ADB at final handoff.

Next: reconnect the Samsung, install this exact APK, and complete normal/large-text physical walkthroughs.

## CP-051 - Approved company mark, welcome artwork, and Samsung inset fix (2026-09-24)

- Adopted the owner-supplied Vawra company identity sheet as the visual authority. Extracted the approved
  couple/heart mark to `assets/branding/vawra_company_mark.png`, switched the welcome and discovery headers to
  it, and regenerated every existing Android and iOS launcher icon size on the Blush Canvas. The former mark
  remains in the repository only as design provenance.
- Added an original portrait welcome background using layered coral, plum, lavender, blush, and ivory ribbon
  forms. A restrained white wash preserves headline and consent-control contrast while allowing the artwork to
  remain visible edge to edge.
- Used an unlocked Samsung SM-S928W walkthrough to find and fix a discovery-header collision with the Android
  edge-to-edge status bar. Re-captured the welcome and discovery screens after the fix; the header, profile card,
  first-viewport actions, and bottom navigation are unobstructed.
- Documented trademark-use discipline: the approved identity may be used as a brand identifier, but Vawra must
  not claim registration or show `®` without confirmation of an active registration in the relevant market.
- Regenerated the 412 x 915 visual baselines and verified `flutter analyze` (no issues), `flutter test` (57
  passed), a fresh Android debug build, successful Samsung installation, and physical-device visual inspection.

Next: apply the same visual system to Matches, Chats, and profile editing, including normal and large-text
device walkthroughs.

## CP-050 - Competitor-researched welcome and discovery redesign (2026-09-24)

- Reviewed current first-party Tinder, Bumble, Hinge, and Feeld product material and official store
  screenshots. Recorded reusable principles, former Vawra weaknesses, sources, and anti-copying boundaries in
  `docs/COMPETITIVE_UI_RESEARCH.md`.
- Added a reusable Vawra Material 3 theme with explicit coral/plum/blush/ink tokens, stronger typography,
  rounded cards and inputs, expressive chips, clearer buttons, bottom sheets, and a refined navigation bar.
- Rebuilt the welcome flow as a focused brand moment with a calmer gradient, stronger emotional hierarchy,
  compact adult/consent confirmation, and a single clear entry action. The prototype still creates no account
  and uploads no data.
- Rebuilt discovery around a large portrait-led card. Name, age, relationship intent, coarse distance,
  biography, and interests now scan in a deliberate hierarchy; filter and safety actions remain immediately
  accessible; and Pass, Next, and Like are visible in the first phone viewport. Exact location remains hidden,
  synthetic-profile disclosure remains explicit, and existing swipe/report/block/match behavior is preserved.
- Added 412 x 915 welcome/discovery golden baselines. The visual pass caught and fixed a compact-height welcome
  issue, a narrow-header overflow, swipe/scroll competition, lazy-section reachability, and first-viewport
  action placement. Verified with `flutter analyze` (no issues), `flutter test` (57 passed), and a fresh debug
  APK build. The redesigned APK was installed on the connected Samsung SM-S928W; the handset locked before the
  final physical screenshot, and no lock-screen bypass was attempted.

Next: apply the same component system to Matches, Chats, and profile editing; then conduct an unlocked Samsung
walkthrough at normal and large text sizes before treating the mobile visual redesign as complete.

## CP-049 - Vawra visual identity and cross-platform app icons (2026-09-24)

- Replaced the generic Flutter mark and visible Project Ember codename with Vawra branding while preserving
  the existing Android/iOS package identifiers so the prototype updates in place.
- Created an original two-ribbon mark whose silhouette suggests a `V` and whose negative space suggests a
  heart. Added the transparent master, complete Android launcher sizes, complete iPhone/iPad launcher sizes,
  and an opaque blush launcher canvas that remains legible under platform masks.
- Added the Vawra mark to onboarding and the main app bar, aligned the app theme to coral/plum/blush brand
  tokens, updated adult-only validation copy, and documented the identity rules and generation record in
  `docs/BRAND_IDENTITY.md`.
- Added a widget regression assertion for the bundled brand asset and visible product name. Verified with
  `flutter analyze` (no issues), `flutter test` (55 passed), and a fresh debug APK build. Installed and
  launched the branded build on the connected Samsung SM-S928W; Vawra was the resumed activity, the mark
  rendered on-device, and the scoped post-launch check found no app fatal crash.

Next: continue the secure profile-media work on top of the CP-048 contract, beginning with server-side
authorization/moderation event schemas and idempotency rules before any photo picker or real upload provider.

## CP-048 - Signed media upload and moderation quarantine contract (2026-09-24)

- Added `docs/MEDIA_UPLOAD_CONTRACT.md` for short-lived single-object upload grants, private quarantine,
  checksum/size enforcement, malware and safe-decoding stages, approved-only delivery, explicit-media
  consent, block/unmatch revocation, deletion, narrowly retained abuse evidence, and authorization that
  never treats an opaque ID as permission.
- Added bounded media request, signed-grant, and moderation snapshot contracts. Profile media structurally
  rejects sexually explicit declarations; matched explicit attachments require recipient consent; signed
  URLs are redacted from logs; and only the server-issued `approved` state can be displayed.
- Added a fail-closed `MediaUploadApi`. No camera/gallery integration, object store, upload worker, scanner,
  moderation provider, network dependency, real media, storage key, or permanent URL was introduced.
- Added contract tests for payload allowlists, explicit-media placement, match-consent signaling, grant
  expiry/size/HTTPS limits, URL redaction, approved-only visibility, and unconfigured API behavior. The
  visibility test was proven by temporarily allowing every non-deleted state: it failed on quarantined
  media, then passed after restoring the approved-only rule. Verified with `flutter analyze` (no issues),
  `flutter test` (55 passed), and a debug APK build. No device walkthrough was performed.

Next: define the server-side media authorization and moderation event schemas, idempotency/race rules,
and cross-account abuse tests before selecting providers or adding a photo picker. Then return to the
profile-media UI with the secure state model already fixed underneath it.

## CP-047 - Account lifecycle and location privacy contract (2026-09-24)

- Added `docs/DATA_LIFECYCLE_CONTRACT.md` for authenticated pause/resume, bounded exports, recently reauthenticated scheduled deletion/cancellation, backup expiry, and narrowly purpose-limited abuse-evidence retention. Legal retention and recovery periods remain deliberately server-configured and undecided.
- Added lifecycle/export state contracts and a fail-closed `AccountLifecycleApi`. Only an active account may use dating features; deletion cancellation and export download readiness depend on unexpired server-provided times rather than client assumptions.
- Added `EncryptedLocationEnvelope` and coarse `LocationPrivacySnapshot`. The client contract has no latitude/longitude fields, redacts ciphertext from logs, and permits only a dedicated encrypted payload; precise coordinates are never a profile or response field.
- Added contract tests for lifecycle gating, server-timed deletion/export behavior, encrypted-location shape/redaction, and unconfigured API behavior. Verified with `flutter analyze` (no issues), `flutter test` (49 passed), and a debug APK build. No real account, location sample, export, deletion, retention schedule, or network service was enabled.

Next: define signed media-upload and moderation-quarantine contracts, including content hashes, short-lived upload grants, malware scanning, consent-aware explicit-media handling, deletion, and authorization without exposing storage keys or permanent URLs.

## CP-046 - Session and recovery trust contract (2026-09-24)

- Added `docs/SESSION_CONTRACT.md` for passwordless/OIDC initiation, PKCE/state-bound proof exchange, short-lived rotating sessions, replay-family revocation, recent-reauthentication requirements, current-session logout, sign-out-everywhere, and non-enumerating recovery.
- Added client contract types that redact account identifiers and authorization-code/PKCE/state secrets from logs. Public request receipts have one generic shape for known and unknown accounts, and only a live server-issued `active` session is locally eligible for authenticated requests.
- Added `SessionApi` and a deliberately unconfigured implementation that fails sign-in, proof exchange, rotation, logout, and recovery-related requests until reviewed providers and secure platform storage exist. No credentials, network client, account provider, or real-user data were added.
- Added contract tests for non-enumeration, secret redaction, expiry/state gating, and fail-closed behavior. Verified with `flutter analyze` (no issues), `flutter test` (44 passed), and a debug APK build. Device testing was not performed for this checkpoint.

Next: define account data-lifecycle contracts for pause, export, deletion, recovery windows, narrowly retained abuse evidence, and location/privacy-zone handling before creating a backend service or collecting real data.

## CP-045 - Account/profile trust contract (2026-09-24)

- Added `docs/BACKEND_API_CONTRACT.md` with the first server-authoritative account/profile boundary: authenticated `/me` operations, opaque IDs plus per-object authorization, age-assurance states, coarse-location rules, and fail-closed requirements for later discovery, match, messaging, block, call, entitlement, and moderation contracts.
- Added `ProfileMutation`, whose contract payload contains only editable public profile fields. Client age, date of birth, coordinates, account ID, verification, entitlement, and match claims are structurally absent; relationship-intent keys are now stable backend values.
- Added `AccountProfileApi` and a deliberately unconfigured implementation. It cannot pretend a profile was fetched or persisted before a reviewed account service exists. No network dependency, provider, secret, or real-user collection was introduced.
- Added contract tests for the exact mutation allowlist, stable age-access states, adult-feature gating, and fail-closed API behavior. Verified with `flutter analyze` (no issues), `flutter test` (40 passed), and a debug APK build. Device testing was not performed for this checkpoint.

Next: specify session lifecycle and recovery contracts (passwordless/OIDC exchange, rotation, revocation, sign-out-everywhere, and non-enumerating errors) before selecting or integrating an authentication provider. Keep production accounts and real-user data disabled.

## CP-044 - Coordinated discovery safety boundary (2026-09-24)

- Added `DiscoverySafetyService` and `LocalDiscoverySafetyService` so discovery reports and profile blocks no longer mutate unrelated screen collections directly.
- A single local block operation now removes the profile from discovery and closes a matching active connection through `MatchRepository`; messaging and call readiness fail closed immediately. Blocking an unrelated profile preserves the active match.
- Discovery report storage remains memory-only and is exposed through an immutable view. Updated block confirmation and feedback copy to describe both discovery and active-contact effects without implying that a real account or moderation team is connected.
- Added service and repository invariant tests. Verified with `flutter analyze` (no issues), `flutter test` (37 passed), and a debug APK build. Device testing was not performed for this checkpoint.

Next: define the first backend-facing account/profile and authorization contracts before adding any network client, keeping all fixtures synthetic and requiring server-side authorization for age, identity, location, entitlement, match, messaging, and block claims. Keep portrait generation deferred until the end of this coding/UI pass.

## CP-043 - Local discovery interaction repository (2026-09-23)

- Added `DiscoveryInteractionRepository` and `MemoryDiscoveryInteractionRepository` so liked, rejected, and blocked profile state plus local like-event previews no longer live as directly mutable collections in the screen state.
- Repository views are immutable. Duplicate likes and likes for already rejected or blocked profiles fail without appending events, while a valid mutual-like fixture still emits the existing backend-shaped event sequence and creates the free-core match through `MatchRepository`.
- Kept all data memory-only and synthetic: no real notification, network write, account, billing, or engagement was introduced.
- Added repository invariant tests and preserved the existing discovery/match widget coverage. Verified with `flutter analyze` (no issues), `flutter test` (33 passed), and a debug APK build. Device testing was not performed for this checkpoint.

Next: move local discovery report/block coordination behind a service boundary so a block can be applied atomically across discovery and any active match before beginning real backend contracts. Keep portrait generation deferred until the end of this coding/UI pass.

## CP-042 - Honest premium direct-intro preview (2026-09-23)

- Closed CP-041's pending build evidence: a fresh `flutter build apk --debug` completed successfully instead of stalling in Gradle.
- Expanded the discovery connection-rules card with an explicitly disabled premium direct-intro preview. The copy says no message is sent, no purchase is offered, and recipient acceptance would still be required before messaging.
- Preserved the free-core invariant: mutual likes can always message without premium. No production billing, entitlement, notification, or message-sending path was added.
- Added policy and widget coverage for the disabled control and safety/free-core copy. Verified with `flutter analyze` (no issues), `flutter test` (30 passed), and a final debug APK build. Device testing was not performed for this checkpoint.

Next: move local like/profile interaction state behind a small repository boundary while preserving truthful local-only events, mutual-like-only match creation, immediate blocks, and free mutual-match messaging. Keep portrait generation deferred until the end of this coding/UI pass.

## CP-041 - Local match repository layer (2026-09-23)

- Added `MatchRepository` and `MemoryMatchRepository` so mutual-like match creation and match updates move out of raw UI state and into a small backend-shaped local service layer.
- Wired discovery, match, and chat flows through the repository while preserving CP-040 behavior: no starter match, mutual-like creation from incoming-like fixtures, free messaging for mutual likes, and immediate block/unmatch/report state changes.
- Added repository unit tests for incoming-like match creation and block invariants. Verified with `flutter analyze` (no issues) and `flutter test` (29 passed). `flutter build apk --debug` was attempted twice but stalled during Gradle assemble, so debug APK build evidence is pending for this checkpoint. Device testing, including the paired ASUS phone, was skipped at the user's request.

Next: rerun the debug APK build in a fresh Gradle session, then add UI copy for premium direct-intro placeholders without enabling production billing or bypassing safety gates. Keep portrait generation deferred until the end of this coding/UI pass.

## CP-040 - Mutual-like match creation (2026-09-23)

- Removed the always-present starter match. The app now starts with no active chat/match and creates a local `MatchConnection` only when the user likes a synthetic profile with an incoming-like fixture.
- Added profile asset identity to `MatchConnection` and a `syntheticMutualLike` factory so future backend wiring can map match creation to profile IDs instead of the previous hardcoded starter match.
- Preserved core safety and access behavior after match creation: mutual likes can message in the free core, call requests still require readiness, reports remain local pending review, and block/unmatch immediately close contact.
- Covered the new flow with widget/domain tests. Verified with `flutter analyze` (no issues), `flutter test` (27 passed), and `flutter build apk --debug` (built). Device testing, including the paired ASUS phone, was skipped for this checkpoint at the user's request because work is currently active there.

Next: continue backend-shaped architecture by splitting local match state into a small repository/service layer, then add UI copy for premium direct-intro placeholders without enabling production billing or bypassing safety gates. Keep portrait generation deferred until the end of this coding/UI pass.

## CP-039 - Local like event previews (2026-09-22)

- Added `LocalLikeEvent` with stable event keys for `outbound_like`, `notification_preview`, and `mutual_like`. Liking a profile records local event previews instead of sending a real notification or creating fake engagement.
- Discovery now shows a compact Local activity card with the latest like events. The copy states that these are on-device previews, not real notifications.
- Liking the existing synthetic match records a mutual-like event and shows product copy that mutual likes can connect and message in the free core.
- Covered outbound notification preview and mutual-like events with unit/widget tests. Verified with `flutter analyze` (no issues), `flutter test` (26 passed), and `flutter build apk --debug` (built). Device testing, including the paired ASUS phone, was skipped for this checkpoint at the user's request because work is currently active there.

Next: continue match architecture polish by separating synthetic match creation from the hardcoded starter match, while preserving free messaging for mutual likes and keeping block/report behavior immediate. Keep portrait generation deferred until the end of this coding/UI pass.

## CP-038 - Local moderation state model (2026-09-22)

- Added `LocalModerationState` to safety reports with stable backend-oriented keys: `local_pending`, `ready_for_review`, `reviewed_no_action`, and `actioned`. Conversation reports and discovery profile reports default to `local_pending`.
- Updated chat and discovery report UI copy to show the local review state while still saying that reports stay on device and are not sent to a connected review team. The other person is not notified.
- Normalized common mojibake punctuation in app strings touched during this pass so prototype separators and distance ranges render as intended.
- Covered moderation-state defaults and backend keys with unit tests. Verified with `flutter analyze` (no issues), `flutter test` (24 passed), and `flutter build apk --debug` (built). Device testing, including the paired ASUS phone, was skipped for this checkpoint at the user's request because work is currently active there.

Next: continue swipe/match architecture polish by introducing a local notification/event model for likes and mutual-like transitions without sending real notifications or creating fake user engagement. Keep portrait generation deferred until the end of this coding/UI pass.

## CP-037 - Discovery swipe interaction model (2026-09-22)

- Added local discovery swipe actions: swipe up likes and advances, swipe left rejects and excludes the profile from discovery, and swipe right advances without counting as a rejection. The visible action buttons now mirror the same Like, Reject, and Next behavior.
- Added in-memory liked-profile state so liked synthetic profiles disappear from the deck for the current session. The confirmation copy is explicit that a production launch would notify the liked person; the prototype does not send real notifications or create fake engagement.
- Added a conversation-access policy preview for the requested product design: mutual likes can connect and message in the free core, while premium direct intros are represented as a future design concept rather than active production billing or messaging.
- Covered the new policy and swipe behavior with widget/unit tests. Verified with `flutter analyze` (no issues), `flutter test` (22 passed), and `flutter build apk --debug` (built). Device testing, including the paired ASUS phone, was skipped for this checkpoint at the user's request because work is currently active there.

Next: continue the coding/UI phase by adding a small local moderation-state model that can later map cleanly to backend review states, then continue swipe/match architecture polish. Keep portrait generation deferred until the end of this coding/UI pass.

## CP-036 — Profile UI extraction and emulator smoke (2026-09-22)

- Moved the profile editor into `lib/features/profile/profile_editor.dart`, preserving display-name, adult-age, bio, relationship-intent, interest, coarse-distance, and default call-readiness behavior.
- `main.dart` now delegates discovery, match, chat, and profile UI to feature modules while keeping app state, synthetic fixture data, repositories, and top-level navigation wiring.
- Verified with `flutter analyze` (no issues), `flutter test` (18 passed), and `flutter build apk --debug` (built).
- Installed and launched the debug APK on the available Pixel-style emulator `emulator-5554`; confirmed the consent gate, discovery card, bottom tabs, and extracted profile editor were reachable. Logcat checks after launch/navigation showed no app `FATAL EXCEPTION`.
- After initial ADB pairing retries returned a protocol fault, the ASUS wireless device came online as `10.0.0.246:37889` (`ASUS_I003DD`). Installed and launched the debug APK there, confirmed the consent gate, discovery card, bottom tabs, and extracted profile editor were reachable, and found no app `FATAL EXCEPTION` in the post-navigation logcat check.

Next: add a small local moderation-state model that can later map cleanly to backend review states, then continue UI polish. Keep portrait generation deferred until the coding/UI phase is further along.

## CP-035 — Match and chat UI extraction (2026-09-22)

- Moved the match list and conversation UI into `lib/features/matches/match_tabs.dart`, including the call-readiness panel, message composer, private report dialog, block confirmation, and unmatch confirmation.
- Updated widget tests to import `ChatTab` from the matches feature module directly. `main.dart` now keeps match/chat state and delegates the user-facing match surfaces.
- Preserved the CP-031 through CP-033 behavior: reports require a reason, optional message evidence is an ID reference only, calls stay match-gated and readiness-gated, and block/unmatch still close contact.
- Verified with `flutter analyze` (no issues), `flutter test` (18 passed), and `flutter build apk --debug` (built). No emulator or physical-device walkthrough was performed for this checkpoint.

Next: extract the profile editor from `main.dart`, then add a small local moderation-state model that can later map cleanly to backend review states. Keep portrait generation deferred until the coding/UI phase is further along.

## CP-034 — Discovery UI extraction (2026-09-22)

- Moved the synthetic discovery card, preference sheet, profile report dialog, and profile block confirmation into `DiscoveryDeck` under `lib/features/discovery/`.
- Moved the synthetic fixture shape into `DemoProfile` under `lib/domain/` and shared the empty-state UI through `lib/features/shared/empty_tab.dart`. `main.dart` now keeps app state and fixture data while delegating the discovery UI surface.
- Preserved the CP-033 safety behavior: profile reports still require a reason and stay local to the device session, and blocked synthetic profiles are removed from discovery immediately.
- Verified with `flutter analyze` (no issues), `flutter test` (18 passed), and `flutter build apk --debug` (built). No emulator or physical-device walkthrough was performed for this checkpoint.

Next: continue architecture cleanup by extracting chat/match/profile widgets from `main.dart`, then add a small local moderation-state model that can later map cleanly to backend review states. Keep portrait generation deferred until the coding/UI phase is further along.

## CP-033 — Discovery safety actions (2026-09-22)

- Added profile-scoped discovery reports so reporting a swipe card no longer reuses the match-report model. Reports require a reason, stay in memory for the current device session, and make clear that no review team is connected.
- Added a compact profile safety menu on discovery portraits with private report and block actions. Blocking is confirmed, removes the synthetic profile from the local discovery deck immediately, and does not pretend to contact a real account.
- Verified the reason-required report flow and local block removal with widget tests. `flutter analyze` found no issues, all 18 Flutter tests passed, and the Android debug APK built. No emulator or physical-device walkthrough was performed for this checkpoint.

Next: continue Phase 1 UI architecture by extracting discovery/chat/profile widgets from `main.dart`, then add a small local moderation-state model that can later map cleanly to backend review states. Keep portrait generation deferred until the coding/UI phase is further along.

## CP-032 — Local discovery preferences (2026-09-22)

- Added a local age-range and relationship-intent preference model for synthetic discovery cards. The sheet can apply or reset filters; discovery resets its card index and shows an honest empty state when no fixture matches.
- Added a visible prototype-profile count and clarified that preference choices remain on the device. Corrected Safety Center copy that previously implied block/report controls were available from screens the prototype has not implemented.
- Verified boundary/filter behavior and the sheet flow with tests. `flutter analyze` found no issues, all 16 Flutter tests passed, and the Android debug APK built. No emulator or physical-device walkthrough was performed for this checkpoint.

Next: continue Phase 1 UI and safety flows, including reporting/blocking entry points from discovery, then tackle real backend/authorization architecture. Keep portrait generation deferred until the coding/UI phase is further along.

## CP-031 — Private prototype reporting flow (2026-09-22)

- Paused portrait generation and the remaining Nepali, Sri Lankan, and South African profile batches so coding and UI work can proceed first. The existing 160 / 220 expansion count is unchanged.
- Added a structured in-memory safety report with a required reason and an optional reference to the latest received message. The report does not copy conversation text or notify the peer.
- Replaced the one-tap report action with a reason picker and explicit evidence opt-in. The chat confirmation clearly says that this prototype has no connected review team and retains the report only for the current app session.
- Verified with `flutter analyze` (no issues), `flutter test` (14 passed), and `flutter build apk --debug` (built). This is build/test evidence, not device validation.

Next: continue Phase 1 coding and UI design, including discovery preferences and complete safety entry points. Generate and review the remaining portraits at the end, then complete device walkthroughs. Do not present local reports as submitted to moderators.

## CP-030 — Mexican expansion completed (2026-09-21)

- Added five more fictional adult Mexican women and five more fictional adult Mexican men with explicit fixture background metadata.
- Completed the Mexican expansion target at 10 women and 10 men; overall expansion progress is 160 / 220.
- Reviewed all ten new portraits as a deliberately varied set across age, skin tone, face shape, hair, build, eyewear, facial hair, clothing, and setting while preserving the adult, one-subject, no-text asset contract.
- Built the debug APK and installed it only on the connected Samsung phone; the AVD remained untouched and full testing stayed deferred.

Next: begin the Nepali expansion target in reviewed, visually distinct batches.

## CP-029 — Mexican expansion half-batch (2026-09-21)

- Added five fictional adult Mexican women and five fictional adult Mexican men with explicit fixture background metadata.
- Reviewed the batch as a deliberately varied set across age, skin tone, face shape, hair, build, eyewear, facial hair, clothing, and setting without relying on nationality stereotypes.
- Advanced overall representation-expansion progress to 150 / 220, with the Mexican target at 5 / 10 women and 5 / 10 men.
- Built the debug APK and installed it only on the connected Samsung phone; the AVD remained untouched and full testing stayed deferred.

Next: complete the remaining five Mexican women and five Mexican men.

## CP-028 — Korean expansion completed (2026-09-21)

- Added five more fictional adult Korean women and five more fictional adult Korean men with explicit fixture background metadata.
- Completed the Korean expansion target at 10 women and 10 men; overall expansion progress is 140 / 220.
- Reviewed all ten new portraits as a deliberately varied set across age, face shape, hair, build, eyewear, facial hair, clothing, and setting while preserving the adult, one-subject, no-text asset contract.
- Built the debug APK and installed it only on the connected Samsung phone; the AVD remained untouched and full testing stayed deferred.

Next: begin the Mexican expansion target in reviewed, visually distinct batches.

## CP-027 — Korean expansion half-batch (2026-09-21)

- Added five fictional adult Korean women and five fictional adult Korean men with explicit fixture background metadata.
- Reviewed the batch as a set for visual uniqueness, varying age, face shape, hair, build, eyewear, facial hair, clothing, and setting.
- Advanced overall representation-expansion progress to 130 / 220, with the Korean target at 5 / 10 women and 5 / 10 men.
- Built the debug APK and installed it only on the connected Samsung phone; the AVD remained untouched and full testing stayed deferred.

Next: complete the remaining five Korean women and five Korean men.

## CP-026 — Filipino expansion completed (2026-09-21)

- Added five more fictional adult Filipino women and five more fictional adult Filipino men with explicit fixture background metadata.
- Completed the Filipino expansion target at 10 women and 10 men; overall expansion progress is 120 / 220.
- Applied a stricter visual uniqueness review across both Filipino batches, varying age, face shape, hair, build, eyewear, facial hair, clothing, and setting while preserving the adult, one-subject, no-text asset contract.
- Built the debug APK and installed it only on the connected Samsung phone; the AVD remained untouched and full testing stayed deferred.

Next: begin the Korean expansion target in reviewed, visually distinct batches.

## CP-025 — Filipino expansion half-batch (2026-09-21)

- Added five fictional adult Filipino women and five fictional adult Filipino men with explicit fixture background metadata.
- Reviewed and bundled ten distinct portraits while preserving unique profile names, unique asset references, and visible prototype disclosure.
- Advanced overall representation-expansion progress to 110 / 220, with the Filipino target at 5 / 10 women and 5 / 10 men.
- Built the debug APK and installed it only on the connected Samsung phone; the AVD remained untouched and full testing stayed deferred.

Next: complete the remaining five Filipino women and five Filipino men, then proceed through the other requested backgrounds in auditable batches.

## CP-024 — Japanese expansion completed (2026-09-21)

- Added five more fictional adult Japanese women and five more fictional adult Japanese men with explicit fixture background metadata.
- Completed the Japanese expansion target at 10 women and 10 men; overall expansion progress is 100 / 220.
- Reviewed and bundled ten distinct portraits while preserving unique profile names, unique asset references, and visible prototype disclosure.
- Built the debug APK and installed it only on the connected Samsung phone; the AVD remained untouched and full testing stayed deferred.

Next: begin the Filipino expansion target in reviewed, auditable batches.

## CP-023 — Japanese expansion half-batch (2026-09-21)

- Added five fictional adult Japanese women and five fictional adult Japanese men with explicit fixture background metadata.
- Reviewed and bundled ten distinct portraits while preserving unique profile names, unique asset references, and visible prototype disclosure.
- Advanced overall representation-expansion progress to 90 / 220, with the Japanese target at 5 / 10 women and 5 / 10 men.
- Built the debug APK and installed it only on the connected Samsung phone; the AVD remained untouched and full testing stayed deferred.

Next: complete the remaining five Japanese women and five Japanese men, then proceed through the other requested backgrounds in auditable batches.

## CP-022 — Chinese expansion completed (2026-09-21)

- Added five more fictional adult Chinese women and five more fictional adult Chinese men with explicit fixture background metadata.
- Completed the Chinese expansion target at 10 women and 10 men; overall expansion progress is 80 / 220.
- Reviewed and bundled ten distinct portraits while preserving unique profile names, unique asset references, and visible prototype disclosure.
- Built the debug APK and installed it only on the connected Samsung phone; the AVD remained untouched and full testing stayed deferred.

Next: begin the Japanese expansion target in reviewed, auditable batches.

## CP-021 — Chinese expansion half-batch (2026-09-21)

- Added five fictional adult Chinese women and five fictional adult Chinese men with explicit fixture background metadata.
- Reviewed and bundled ten distinct portraits while preserving unique profile names, unique asset references, and visible prototype disclosure.
- Advanced overall representation-expansion progress to 70 / 220, with the Chinese target at 5 / 10 women and 5 / 10 men.
- Built the debug APK and installed it only on the connected Samsung phone; the AVD remained untouched and full testing stayed deferred.

Next: complete the remaining five Chinese women and five Chinese men, then proceed through the other requested backgrounds in auditable batches.

## CP-020 — Bangladeshi expansion completed (2026-09-21)

- Added five more fictional adult Bangladeshi women and five more fictional adult Bangladeshi men with explicit fixture background metadata.
- Completed the Bangladeshi expansion target at 10 women and 10 men; overall expansion progress is 60 / 220.
- Reviewed and bundled ten distinct portraits while preserving unique profile names, unique asset references, and visible prototype disclosure.
- Built the debug APK and installed it only on the reconnected Samsung phone; the AVD remained untouched and full testing stayed deferred.

Next: begin the Chinese expansion target in reviewed, auditable batches.

## CP-019 — Bangladeshi expansion half-batch (2026-09-21)

- Added five fictional adult Bangladeshi women and five fictional adult Bangladeshi men with explicit fixture background metadata.
- Reviewed and bundled ten distinct portraits while preserving unique profile names, unique asset references, and visible prototype disclosure.
- Advanced overall representation-expansion progress to 50 / 220, with the Bangladeshi target at 5 / 10 women and 5 / 10 men.
- Built the debug APK and installed it only on the connected Samsung phone; the AVD remained untouched and full testing stayed deferred.

Next: complete the remaining five Bangladeshi women and five Bangladeshi men, then proceed through the other requested backgrounds in auditable batches.

## CP-018 — Pakistani expansion completed (2026-09-21)

- Added five more fictional adult Pakistani women and five more fictional adult Pakistani men with explicit fixture background metadata.
- Completed the Pakistani expansion target at 10 women and 10 men; overall expansion progress is 40 / 220.
- Reviewed and bundled ten distinct portraits while preserving unique profile names, unique asset references, and visible prototype disclosure.
- Built the debug APK and installed it only on the connected Samsung phone; the AVD remained untouched and full testing stayed deferred.

Next: begin the Bangladeshi expansion target in reviewed, auditable batches.

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
