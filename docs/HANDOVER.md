# Vawra handover

Written 2026-09-28 by the Claude Code session that built BE-1 to BE-9, UI-1/UI-2, the device
tests and Web-2. Read this first, then `AGENTS.md` (the non-negotiable rules) and the top of
`CHECKPOINTS.md` (newest first).

## What Vawra is, and where

- An 18+ dating app: Flutter app (package `ember_app`) plus a TypeScript/Fastify server in
  `backend/`. Repository `D:\Projects\dating-app` (a junction from
  `C:\Users\anili\Projects\dating-app`), GitHub `anilise09/vowra`, branch `main`. The repository
  is **public**.
- A product-site preview in `website/` is **live and public** at https://anilise09.github.io/vowra/
  (GitHub Pages from the `gh-pages` branch, whose tree is only `website/`). It says clearly that
  Vawra is in development and that every person shown is a synthetic test profile.
- Owner's status page (Claude artifact, private to the owner):
  https://claude.ai/artifact/37ZnorBUe98RvPtXP7bDrG. Republish it when work lands.
- Codex also works in this checkout, only when the owner asks. It committed another session's
  untracked files once, so commit with a pathspec (`git commit -- <paths>`) and keep unfinished
  files out of `website/` and other tracked folders.

## State at handover (main at 0602d57 plus this handover)

Works end to end against the local server:

- Welcome and 18+ gate, sign-in with a one-time email code (PKCE; codes are written to
  `backend/.data/outbox.log` because no email provider is chosen), refresh token kept in secure
  storage.
- 9-step onboarding including "How do you identify?" and "Who would you like to meet?" (BE-8).
  Two-way matching on the server; "Show me" is never returned to anyone else; gender shows only
  if the person turns it on.
- Discover ranked by what people share, with "Why you might click" (BE-5), free undo of a pass,
  3 free Super Likes a day, preferences, Explore hubs.
- Matches, chat with openers (BE-7), unread counts, "Your turn", read receipts and typing only
  when both opt in (BE-6), live nudges over `GET /v1/events` instead of polling (BE-4).
- Block and report (always free), pause, account deletion with a 7-day grace period (BE-3b),
  "Download a copy of your data" (BE-9: recent sign-in, 5 a day, own data only).
- Apple-style swipe physics and layouts for every phone, foldable and tablet (UI-1/UI-2);
  Codex's brand and Discover polish (UI-3 to UI-6) is the **approved current UI: keep it**.
- 260 labelled sample profiles (130 women, 130 men, reviewed gender per portrait in
  `lib/data/demo_genders.dart`), shipped as WebP; the app is 138 MB for three CPU types.

Last device test: the owner's Asus, 2026-09-28 (see the "Device" checkpoint). Everything passed;
one layout bug on the export page was found there and fixed.

Test counts at handover: Flutter 192 passed, 1 existing skip; backend 62 passed; analysis and
type-check clean; `website/check.ps1` passes.

## Since the handover: phases 2, 3 and 4 (2026-09-29)

The owner asked for roadmap phases 2 (accounts and profiles), 3 (matching and chat) and 4 (voice
and video beta). Everything that needs no outside account, money or legal decision is built,
one checkpoint each (details in `CHECKPOINTS.md`):

- BE-10 distance from an approximate 2 km area; BE-14 private places (distance hidden there,
  the places never leave the phone).
- BE-11 moderation (reports, suspension, appeals); BE-12 profile photos checked by a person first;
  BE-16 photos in chat, allowed per match, checked, blurred until tapped.
- BE-13 retention schedule, backup and restore drill, `docs/SECURITY_REVIEW.md`,
  `docs/RECOVERY.md`; BE-15 scam warnings in chat; BE-17 block-leakage and load tests
  (`docs/LOAD_TEST.md`).
- BE-18 calls on the server, BE-19 calls in the app: both people opt in per match, voice or video,
  ringing, answer without video, mute, camera, flip, speaker, report and "End call and block"
  inside the call. Calls are relay-only in production (TURN: `VAWRA_TURN_URLS`,
  `VAWRA_TURN_SECRET`) so neither person learns the other's IP address. Without a relay the app
  hides calls; `VAWRA_CALLS_DEV_P2P=1` allows direct calls for development only. Nothing is
  recorded. An incoming call rings only while the app is open, until push notifications exist.
  First real calls (BE-19b): the Android 15 emulator against headless Chromium, video and voice
  both ways; the browser side is a scratch script (headless Chromium with a fake camera, signed in
  through `tools/dev/vawra_driver.mjs` sessions), not yet in the repository.

Still needing the owner or a provider: a TURN relay for real calls, push notifications (incoming
calls with the app closed), email, hosting, object storage and scanning, age assurance (legal),
monetisation (legal hold), physical Apple-device access, and a real two-phone call test (both
phones are currently reserved by another session).

## Since the handover: first iOS Simulator flow (2026-09-30)

- Mac access is no longer a blocker. Flutter 3.47.5, Xcode 26.6, the iOS 26.5 runtime and a
  user-local CocoaPods 1.17.0 are installed on the Intel Mac.
- `integration_test/ios_smoke_test.dart` plus its `test_driver/` adapter passes on a dedicated
  iPhone 17e simulator: adult/rules gate, all offline onboarding steps, Discover, synthetic match,
  chat send, Profile and Settings through the destructive-account row.
- The same full flow also passes on an iPhone 17 Pro Max simulator at Apple's maximum accessibility
  text size with Reduce Motion enabled. The test explicitly proves the text scale reached Flutter
  and checks UIKit's Reduce Motion state through a simulator-only channel. Physical iPhone/iPad,
  connected accounts and real calls are still not validated on Apple hardware.
- Flutter analysis is clean. All non-golden host tests pass (218;
  one expected live-server skip). The 14 pixel baselines were authored on Windows and show only
  0.43-1.60% text/vector-edge rasterization differences on macOS, so they were inspected and left
  unchanged.

## Since the handover: the backend made ready for production (2026-09-30)

The owner asked for the full backend by the end of the week. Built and tested on 30 September,
each a checkpoint in `CHECKPOINTS.md`, published to `main`:

- BE-20 strict production settings, `/v1/ready`, clean shutdown, `backend/Dockerfile`,
  `docs/DEPLOY.md`; BE-20b migrations on Windows line endings.
- BE-23 six-digit email sign-in codes through any SMTP provider (the app takes digits only).
- BE-24 push notifications, server side (Firebase and Apple; generic text, opt-outs).
- BE-25 moderators need an authenticator app; `npm run admin:moderator` on the host.
- BE-26 photos in any S3-compatible store (signing checked against Amazon's examples).
- BE-27 several servers at once, sharing live updates, presence and call setup through PostgreSQL.
- BE-28 a provider-neutral age-check slot (signed webhook; only the outcome and age kept).

Work happens in a separate worktree (`D:/Projects/dating-app-wt-claude`, branch
`claude/backend-providers`, commits signed "Claude") because Codex works in the main checkout on
its own branches. What only the owner can provide: the providers (hosting with PostgreSQL, SMTP,
an object store, Firebase and an Apple push key, a TURN relay, an age-check provider with legal
review) and a yes to install PostgreSQL and Docker on this laptop to prove the backend on the real
database and build the image. App sides still waiting on providers: push registration (needs
Firebase) and the "check my age" button (needs the provider).

## Running it

Flutter is not on PATH: `export PATH="/c/Users/anili/Tools/flutter/bin:$PATH"` (Git Bash).

App checks (run all before every commit that touches the app):

```
flutter analyze
flutter test                      # device matrix, goldens, server flow, everything
```

On this Mac, Flutter is `/Users/user/Tools/flutter/bin/flutter` and the user-local CocoaPods bin
is `~/.gem/ruby/2.6.0/bin`. The proven iOS Simulator smoke-test path builds once for a generic
simulator, then runs the prebuilt app (replace the device id):

```
flutter build ios --simulator --debug --target integration_test/ios_smoke_test.dart --no-pub
flutter drive --driver=test_driver/ios_smoke_test.dart \
  --target=integration_test/ios_smoke_test.dart -d <simulator-id> \
  --use-application-binary=build/ios/iphonesimulator/Runner.app --no-pub
```

For the Pro Max accessibility gate, configure that simulator to maximum Dynamic Type and Reduce
Motion first, then add both
`--dart-define=VAWRA_EXPECT_LARGE_TEXT=true` and
`--dart-define=VAWRA_EXPECT_REDUCED_MOTION=true` to the build command. The Reduce Motion probe is
available only in a simulator build; it is compiled out for physical devices and production.

Use a dedicated simulator if another session has an app in front. Concurrent Xcode builds can
leave an `actool` subprocess behind after interruption; verify the Vawra process tree is empty
before retrying rather than deleting DerivedData or disturbing another workspace's simulator.

Goldens change only on purpose: inspect `test/failures/*` before `--update-goldens`, and review
the new image.

Server (`backend/`, Node + PGlite; no Postgres or Docker on this laptop, do not install them
without asking the owner):

```
cd backend
npx tsc --noEmit -p . && npx vitest run
npm run build
set -a; . .data/dev.env; set +a          # local development keys (git-ignored, never commit)
export VAWRA_SERVER_ENABLED=1 VAWRA_DEV_OUTBOX=1 VAWRA_PORT=8797
exec node dist/src/server.js
```

- Port 8797 (8787 belongs to QuietWall's website dev server).
- PGlite allows one process: stop the server (kill the node PID listening on 8797) before
  `npm run dev:seed-demo [-- --remove | --near <email>]`, `npm run dev:assure -- <email> <age>`
  (marks a local test account adult, because no age-assurance provider exists yet) or
  `npm run dev:moderator -- <email> [--remove]` (local moderator role).
- `backend/.data/dev.env` holds the keys that seal the local database's emails. If it is lost,
  make new 32-byte base64 keys and start a fresh `.data/pglite`.
- Dev drivers in `tools/dev/`: `vawra_driver.mjs` (sign up and drive synthetic test members:
  signup, signin, like, like-all, say, patch, share, typing, read, area, get, post, show) and `adb_ui.py` (dump, tap,
  type, shot on a phone). Test members: `alex.test@vawra.test` (the Asus is signed in as Alex;
  Alex is a local moderator, so Settings shows Moderation),
  `sam.test`, `priya.test`, `maya.test`, `elena.test`, `sofia.test`, `noor.test`, all synthetic.

Phone build against the local server:

```
flutter build apk --profile --dart-define=VAWRA_API=http://127.0.0.1:8797
adb -s <serial> install -r build/app/outputs/flutter-apk/app-profile.apk
adb -s <serial> reverse tcp:8797 tcp:8797
```

- Delete `build/app/outputs/apk/profile/app-profile.apk` before a build after large asset
  changes: the incremental packager once left 600 MB of dead space in the APK.
- Wireless adb can report a failed install that succeeded: compare the md5 of the installed
  `base.apk` with the build.
- Asus ASUS_I003DD: wireless adb; the port changes, find it with `adb mdns services`.
  Samsung SM-S928W: USB `R3CXB03G3MH`; installs need `--user 0`. QuietWall sessions also use both
  phones (a QuietWall VPN start/stop drops wireless adb).

Website: `powershell -ExecutionPolicy Bypass -File website/check.ps1`. App screens for the site
come from `flutter test tool/site_screens_test.dart --update-goldens` (writes to
`build/site_screens/`; see `website/README.md` for why three screens are phone captures).
Republish after a change to `website/` on main:

```
git fetch origin gh-pages:refs/remotes/origin/gh-pages
NEW=$(git commit-tree HEAD:website -p origin/gh-pages -m "Website: <what changed>")
git push origin $NEW:refs/heads/gh-pages
```

## Owner rules and preferences

- The owner's phones lock after 30 seconds (company policy) and the owner cannot keep touching
  them during tests. Before any test on a phone, keep it awake with
  `python C:\Users\anili\Tools\phone-awake\phone_awake.py hold <serial> --minutes N` (or `on`,
  then `off` when done); it raises the screen timeout and restores 30 s afterwards. Run `status`
  first and `off` any phone left raised. It never unlocks a phone: ask the owner for that.
- `AGENTS.md` first: synthetic fixtures only, never fake users, likes, matches, messages or
  "Active" status; block, report, messaging and matching stay free; calls need a match and
  acceptance; client claims are untrusted; age assurance is a launch gate.
- Monetization is legally on hold: no payment or subscription code.
- Never commit secrets. Never put the owner's personal details (passwords, email, immigration or
  residency) in repo files, commits or published pages.
- Phones: before any tap or screenshot, check there is no call
  (`dumpsys telephony.registry` mCallState, `dumpsys telecom`) and what is in front
  (`dumpsys window | grep mCurrentFocus`). If another app is in front, another session or the
  owner may be using the phone: ask the owner. Never open banking, payment or trading apps. Pull
  files to the laptop and delete them from the phone; delete at once any capture that caught a
  call.
- The owner judges by feel on the phone, not by test counts; prove a feature on a device
  (on, off, on) before calling it done.
- Only claim what is verified: the website and app never promise launch dates, store
  availability, real members or unbuilt features (calls are "planned, not built").
- Commit at each checkpoint with a `CHECKPOINTS.md` entry (newest first) and push. This repo uses
  its own labels (BE-, UI-, Web-, Size, Device, Fix); QuietWall's CP numbers are not used here.

## Gotchas that cost time

- Bash heredocs eat backslashes: write edit scripts to a file first.
- Dart does not allow a `case` pattern inside a conditional expression; compute a variable first.
- Fastify rejects a JSON content type on an empty body: the client sends the header only with a
  body (the fake server in `test/support/fake_vawra_server.dart` is strict about it too).
- In widget tests, text styles with no font family (button and chip labels) render as blocks,
  even with Roboto loaded; that is why some website screens come from the phone.
- Do not run `npx prettier` in `backend/`: there is no config, and the defaults rewrite the
  single-quote style. Keep lines near 100 characters by hand.
- The server-connected app keeps a live link open, so `pumpAndSettle` can hang in tests; pump
  for a fixed time instead (see `_settle` in `test/server_flow_test.dart`).

## Waiting on the owner

1. Seven untracked `assets/profiles/np_*.png` portraits (from 22 Sep, not referenced) are bundled
   because `pubspec.yaml` includes the folder: about 18 MB. Keep them as sample people (review a
   gender for each, add to `lib/main.dart` and `demo_genders.dart`, convert to WebP) or remove.
   Also untracked and of unknown origin: `.agents/`, `skills-lock.json`,
   `assets/branding/vawra_company_mark_trimmed.png`. Do not commit or delete them without asking.
2. Physical iPhone/iPad access for Apple-hardware testing. The iPhone 17e critical flow and the
   iPhone 17 Pro Max maximum-text/Reduce-Motion flow pass in the simulator; physical Apple hardware
   remains open.
3. Providers, each needing the owner's account or money: email for sign-in codes, hosting with
   PostgreSQL, an object store plus malware scanning and automated photo classification (photos
   work today with a local disk store and human review), push notifications (Firebase and an
   Apple push key), a TURN relay for calls (a managed one, or coturn on the host). Age
   assurance also needs legal review.
4. Whether the public repository and the live website preview stay public before the Vawra name
   and domain are cleared.

## Next work that needs nobody

- No roadmap feature is currently both unblocked and validation-ready without an owner/provider
  decision. Distance and private places have passed on the owner's Asus; the remaining Apple step
  needs physical iPhone/iPad access.
- Moderation is built (BE-11) but moderators are made with a local dev command; a real staff
  sign-in (separate from member accounts, with two-person access for sensitive evidence) comes
  with hosting.
- A staging load run on real hosting (`npm run load` measures in process; see `docs/LOAD_TEST.md`).

## State left on the machine

- The local server may still be running on 8797 (started from this session). The demo database
  holds the 260 demo members (re-seeded with WebP portraits and genders) and the test members
  above.
- The Asus has the call build (8df5362) installed, signed in as Alex ("Show me: Everyone"), with
  approximate location allowed and distance on, camera and microphone allowed, and the port link
  to 8797. Calls and distance were tested there on 2026-09-30 (see CHECKPOINTS.md).
- The 260 sample people are seeded around Alex's approximate area (`dev:seed-demo --near`).

## Phases 2-4 without provider accounts (2026-10-01, Claude)

On `claude/backend-providers` (details in CHECKPOINTS.md, BE-30 and "App - Age check"):
- App: the age check ("Confirm my age" opens the provider; review and refusal screens) and
  notification choices saved to the account. `npm run dev:age-provider` is a dev stand-in.
- Relay-only calls proven with `tools/dev/relay-check` (local TURN relay, two headless browsers),
  also across two servers sharing PostgreSQL. `node relay.mjs` runs the relay alone for a phone.
- Backend tests on real PostgreSQL: `VAWRA_TEST_DATABASE_URL=postgres://postgres@127.0.0.1:5433/postgres`.
  Portable PostgreSQL 18.4 in D:\Tools\pgsql (start: `pg_ctl -D D:/Tools/pgsql/data -o "-p 5433
  -c listen_addresses=127.0.0.1"`). Found and fixed a migration race between servers starting together.
- Asus: notification choices checked across a restart; age check opened in a Custom Tab and "under
  review" shown. Account agecheck1@example.test (synthetic) is left in review: its one-time
  reference was not logged then (the stand-in logs it now).

Next, when the Asus is plugged in again: a new account through to an age-check pass; photos and
moderation on the phone; a relay-only call between the Asus app and a headless browser (relay on
the laptop's Wi-Fi address; node.exe may already accept incoming connections). The Samsung is
QuietWall's (Rook install), not for Vawra. Owner decisions still open: publishing this branch to
main, Docker Desktop (needs admin), provider accounts.

## Resume here (2026-10-02, Claude)

- main = fc556b6 (everything to SEC-2) plus, on `claude/backend-providers`, ffaa144 and 80ebde1:
  in development, real addresses get real email once SMTP is set (test members' reserved
  addresses stay in the outbox), and `backend/scripts/dev-email.ps1` for the owner's Gmail.
- The owner's login fix: the laptop test server had stopped, and codes only went to the outbox.
  Gmail SMTP (the owner's app password) is now in the git-ignored backend/.data/dev.env and Gmail
  accepted it. The owner should revoke that app password and make a new one with the script,
  because it was typed into chat. The owner's phone must be on USB (adb reverse 8797/8798) for the
  test build; the owner has not yet confirmed a successful sign-in.
- Start the test server from D:\Projects\dating-appackend: source .data/dev.env, then
  VAWRA_SERVER_ENABLED=1 VAWRA_DEV_OUTBOX=1 VAWRA_PORT=8797 VAWRA_CALLS_DEV_P2P=1
  VAWRA_AGE_CHECK_URL=http://127.0.0.1:8798/start?ref={reference} VAWRA_AGE_WEBHOOK_SECRET=<local>
  node D:/Projects/dating-app-wt-claude/backend/dist/src/server.js; the stand-in age check is
  `npm run dev:age-provider` with the same secret. Portable PostgreSQL: D:\Tools\pgsql (port 5433).
- Next: confirm the owner can sign in; Asus tests (age-check pass, photos and moderation,
  relay-only call with the app); merge ffaa144/80ebde1 to main with the owner's yes.
