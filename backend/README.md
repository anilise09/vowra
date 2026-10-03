# Vawra backend

Account, profile, discovery, match, chat and safety service for Vawra. It follows
`../docs/BACKEND_API_CONTRACT.md`, `SESSION_CONTRACT.md` and `DATA_LIFECYCLE_CONTRACT.md`.

**It ships switched off.** It refuses to start unless `VAWRA_SERVER_ENABLED=1`, listens on
127.0.0.1 by default, and needs two 32-byte keys. There is no production deployment.

## Run tests

```
npm install
npm test          # vitest, real HTTP routes on in-memory PostgreSQL (PGlite)
npm run typecheck
```

## Run locally

```
npm run build
node ../tools/dev/init_local_backend_env.mjs
# Load backend/.data/dev.env into the shell, then:
npm start                               # http://127.0.0.1:8797
```

The generated file is git-ignored, mode `0600`, and is never replaced once it
exists. The equivalent manual environment is:

```
npm run build
set VAWRA_SERVER_ENABLED=1
set VAWRA_DEV_OUTBOX=1                 # development only: sign-in proofs go to .data/outbox.log
set VAWRA_DATA_KEY=<32 random bytes, base64>
set VAWRA_LOOKUP_KEY=<32 random bytes, base64>
npm start                               # http://127.0.0.1:8797
```

Without `DATABASE_URL` it stores data in `.data/pglite` (PostgreSQL compiled to WebAssembly: no
install, no admin rights). Set `DATABASE_URL` to use a real PostgreSQL server instead.

No age-assurance provider is reviewed yet, so dating features stay closed for every account. For
local testing only: `npm run dev:assure -- <email> <age>` marks a local account as verified. It is
a command on the developer's machine, never an HTTP endpoint, and refuses a real database.
Stop the server first: PGlite is single-process, so two processes must never open `.data/pglite`
at once.

For a full deck to test with, `npm run dev:seed-demo` adds the app's 260 synthetic sample profiles
as age-verified demo members with their bundled portraits (`--remove` takes them all out again).
Also local-only and refused on a real database; the portrait column cannot be set through the
API, and the app labels these people "TEST PROFILE · NOT A REAL PERSON". The fixture comes from
`python tools/export_demo_profiles.py`.

## Run the app against it

```
flutter build apk --profile --dart-define=VAWRA_API=http://127.0.0.1:8797
adb reverse tcp:8797 tcp:8797          # per device; phones and emulators reach the laptop
```

Debug and profile builds allow plain HTTP only to 127.0.0.1, localhost and 10.0.2.2
(`android/app/src/{debug,profile}/res/xml/network_security_config.xml`); release builds stay
HTTPS-only. Without `VAWRA_API` the app is the offline prototype.

### Server-connected iOS simulator smoke test

The iOS test signs a single synthetic `.test` account into the real local
backend, loads the labelled synthetic discovery deck, opens account settings,
and signs out. It does not like or message any profile. Start the backend with
the development outbox, create and locally age-assure the test account, seed
the demo deck, then start the loopback-only code bridge:

```
VAWRA_OUTBOX_EMAIL=ios.simulator@vawra.test node tools/dev/outbox_bridge.mjs
```

Run `integration_test/ios_server_smoke_test.dart` with these Dart defines:
`VAWRA_TEST_API=http://127.0.0.1:8797`,
`VAWRA_TEST_CODE_BRIDGE=http://127.0.0.1:8798`, and
`VAWRA_TEST_EMAIL=ios.simulator@vawra.test`. The bridge refuses real email
addresses, binds only to loopback, and ignores codes issued before it started.

## What exists (BE-1)

| Area | Endpoints |
| --- | --- |
| Sign-in | `POST /v1/auth/requests` (same answer for every identifier; emails a six-digit code), `POST /v1/auth/exchange` (the code + PKCE verifier + state) |
| Sessions | `POST /v1/session/rotate` (reuse revokes the family), `DELETE /v1/session`, `DELETE /v1/sessions` |
| Profile | `GET`/`PATCH /v1/me/profile` (only the contract fields, including habits and prompts), `POST`/`DELETE /v1/me/pause` |
| Discovery | `GET /v1/discovery`, `POST /v1/discovery/{id}/swipe` (like, super_like, pass; idempotent), `GET /v1/likes-you` |
| Chat | `GET /v1/matches`, `DELETE /v1/matches/{id}`, `GET`/`POST /v1/matches/{id}/messages` |
| Safety | `POST /v1/blocks`, `GET /v1/blocks`, `DELETE /v1/blocks/{id}`, `POST /v1/reports` |

Rules added with the app connection (BE-2): three free Super Likes in any rolling 24 hours
(`429 super_like_limit`); a paused person is hidden from new people but keeps their matches and
chats; likes-you carries the same profile fields as discovery.

Deletion (BE-3b): `POST /v1/me/deletion` needs a sign-in within `VAWRA_REAUTH_WINDOW` (default 600 s),
signs the account out everywhere, hides it and closes its chats, and returns the server's date
(`VAWRA_DELETION_GRACE`, default 7 days, a placeholder until counsel sets it). Signing in before then
allows `DELETE /v1/me/deletion`. The server runs the deletion job at start and hourly.

Nudges (BE-4): `GET /v1/events` is a Server-Sent Events stream of content-free nudges
(`message`, `match`, `like`); the app refetches through the normal routes. See
`docs/TINDER_GITHUB_LEARNINGS.md`. `test/live/nudge_live_test.dart` checks it end to end against a
running server.

Security properties covered by tests: no account-existence oracle; emails sealed with AES-256-GCM
and looked up by keyed hash; tokens stored only as hashes; six-digit sign-in codes stored only as a
keyed hash, found by the device's state, single-use and spent after five wrong tries; refresh reuse revokes the family; age gate on every dating feature; mutual
eligibility and either-direction blocks on discovery, swipes and chat; participant-only match
access that looks identical to "not found"; message validation and 5-a-minute limit; block closes
matches in one transaction; reports keep only a valid message reference; logs carry no credentials.

## Not built yet

Email delivery provider, OIDC providers, age-assurance provider, location service and privacy
zones, media uploads, push notifications (the nudge stream covers an open app), calls, data export,
entitlements. Each waits for its provider review as the contracts require.
