# Deploying the Vawra server

Status: the server is ready to be packaged and started on a host (BE-20, 2026-09-30). No host is
chosen yet, and the image has not been built here (Docker is not installed on the development
laptop). Providers still to choose are listed at the end.

## What runs

One Node 22 process per instance (`backend/Dockerfile`), stateless apart from:

- **PostgreSQL** (`DATABASE_URL`): all account, profile, match, chat, moderation and call data.
- **Media**: processed photos. Today a directory (`VAWRA_MEDIA_DIR`, the `/data` volume in the
  image); an S3-compatible object store replaces it before more than one instance runs.
- **In-memory state** that must become shared before running more than one instance: the
  live-update nudge bus and call setup messages (see `docs/SECURITY_REVIEW.md`). Sign-in
  throttling is already shared through PostgreSQL. Until the remaining state moves, run exactly
  one instance.

## Settings

Required everywhere:

| Variable | Meaning |
|---|---|
| `VAWRA_SERVER_ENABLED=1` | The server refuses to start without it. |
| `VAWRA_DATA_KEY` | 32 random bytes, base64. Seals emails, areas and photo links. |
| `VAWRA_LOOKUP_KEY` | A different 32 random bytes, base64. Keys email lookups. |

Generate a key with `node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"`
and keep both in the host's secret store; losing the data key loses sealed data.

Production (`VAWRA_ENV=production`, set in the image) additionally requires `DATABASE_URL` and
`VAWRA_HOST` (the image sets `0.0.0.0`), and refuses `VAWRA_DEV_OUTBOX`, `VAWRA_CALLS_DEV_P2P`
and an access token longer than an hour. Every problem is listed at once and the process exits;
no secret is ever printed.

Optional:

| Variable | Default | Meaning |
|---|---|---|
| `VAWRA_PORT` | 8797 | Listen port. |
| `VAWRA_MEDIA_DIR` | `.data/media` (`/data/media` in the image) | Photo files. |
| `VAWRA_ACCESS_TTL` | 900 | Access token lifetime, seconds. |
| `VAWRA_PROOF_TTL` | 600 | Sign-in code lifetime, seconds. |
| `VAWRA_REAUTH_WINDOW` | 600 | How recent a sign-in must be for deletion, export and moderation. |
| `VAWRA_DELETION_GRACE` | 604800 | Seven days before a requested deletion runs. |
| `VAWRA_DRAIN_SECONDS` | 10 in production, 0 otherwise | How long readiness fails before shutdown. |
| `VAWRA_TURN_URLS`, `VAWRA_TURN_SECRET` | none | TURN relay for calls; without them calls stay off. |
| `VAWRA_FCM_CREDENTIALS_B64` | none | Android push: the Firebase service-account JSON, base64. |
| `VAWRA_APNS_KEY_B64`, `VAWRA_APNS_KEY_ID`, `VAWRA_APNS_TEAM_ID`, `VAWRA_APNS_TOPIC`, `VAWRA_APNS_PRODUCTION` | none | iPhone push: the .p8 key (base64), its id, the team id, the app's bundle id, and `1` for the production gateway. All or none. |
| `VAWRA_SMTP_URL`, `VAWRA_EMAIL_FROM` | none (required in production) | Sign-in codes by email through any SMTP provider: `smtps://user:password@smtp.example.com:465` (or `smtp://...:587`, which must upgrade with STARTTLS) and `Vawra <no-reply@example.com>`. TLS is always required and certificates are verified. |

## Health

- `GET /v1/health`: liveness. The process answers. The image's `HEALTHCHECK` uses it.
- `GET /v1/ready`: readiness. The database answers and every migration this build ships is
  applied; `503` with a reason (`database`, `migrations_pending`, `shutting_down`) otherwise.
  Point the load balancer here.

## Start, update, stop

- **Migrations** run at start inside one transaction under an advisory lock, so instances
  starting together never apply one twice. A failed migration rolls back and the process exits.
- **Stopping** (SIGTERM): readiness fails at once, the server keeps serving for
  `VAWRA_DRAIN_SECONDS` while traffic moves away, then stops listening, ends open live-update
  streams (apps reconnect elsewhere), finishes requests in flight and the hourly job, and closes
  the database. A stop that takes longer than the drain plus 20 seconds is forced.
- **Hourly job**: scheduled deletions and the retention schedule run at start and every hour.

## Moderators

Only an operator on the host can make or remove a moderator, or reset a lost authenticator:
`npm run admin:moderator -- grant|revoke|reset-2fa <email> --confirm` (the person signs in to the
app once first). Each change is an audit event. A new moderator then sets up an authenticator app
in the app's Moderation page before any moderation action.

## Build and run

```sh
cd backend
docker build -t vawra-server .
docker run --rm -p 8797:8797 -v vawra-data:/data \
  -e VAWRA_SERVER_ENABLED=1 -e DATABASE_URL=postgres://... \
  -e VAWRA_DATA_KEY=... -e VAWRA_LOOKUP_KEY=... vawra-server
```

The image runs as the unprivileged `node` user; `/data` is its only writable place.

## Still to choose (owner)

Hosting with managed PostgreSQL and backups; an email provider for sign-in codes; S3-compatible
object storage with scanning; Firebase and an Apple push key for notifications; a TURN relay for
calls; an age-assurance provider (with legal review). Each is an adapter behind an interface the
server already has.
