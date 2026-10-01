# Deploying the Vawra server

Status: the server is ready to be packaged and started on a host (BE-20, 2026-09-30). No host is
chosen yet, and the image has not been built here (Docker is not installed on the development
laptop). Providers still to choose are listed at the end.

## What runs

One Node 22 process per instance (`backend/Dockerfile`), stateless apart from:

- **PostgreSQL** (`DATABASE_URL`): all account, profile, match, chat, moderation and call data.
- **Media**: processed photos, in any S3-compatible object store (`VAWRA_S3_*`: Amazon S3,
  Cloudflare R2, Backblaze B2, MinIO), which more than one instance needs; without it, a directory
  (`VAWRA_MEDIA_DIR`, the `/data` volume in the image) for a single instance.
- **Shared state, through PostgreSQL** (BE-27), so any number of instances can run behind a load
  balancer: live-update nudges (LISTEN/NOTIFY on `vawra_nudges`), who has the app open (a
  heartbeat table, so pushes skip people connected to any instance), call setup messages (an
  unlogged table, deleted when the call ends) and sign-in throttling. Photos need the object
  store for more than one instance. Two harmless limits stay per instance: the typing-indicator
  throttle and the one-push-a-minute message limit (so two instances can push twice in a minute).
- **Database connections**: each instance keeps a pool of 10 plus one listening connection.

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
| `VAWRA_MEDIA_DIR` | `.data/media` (`/data/media` in the image) | Photo files, when no object store is set. |
| `VAWRA_S3_ENDPOINT`, `VAWRA_S3_BUCKET`, `VAWRA_S3_REGION`, `VAWRA_S3_ACCESS_KEY_ID`, `VAWRA_S3_SECRET_ACCESS_KEY` | none | Photo storage in an S3-compatible store, all or none: the service address (`https://s3.ca-central-1.amazonaws.com`, `https://<account>.r2.cloudflarestorage.com`), the bucket, its region (`auto` for R2) and a key that can only read, write and delete in that bucket. Objects stay private; the server checks access and streams them. |
| `VAWRA_S3_PREFIX`, `VAWRA_S3_VIRTUAL_HOST`, `VAWRA_S3_SSE` | none, automatic, none | A key prefix such as `photos/`; `1`/`0` to force the bucket into the host name or the path (Amazon defaults to the host name); `AES256` to ask the store to encrypt at rest. |
| `VAWRA_ACCESS_TTL` | 900 | Access token lifetime, seconds. |
| `VAWRA_PROOF_TTL` | 600 | Sign-in code lifetime, seconds. |
| `VAWRA_REAUTH_WINDOW` | 600 | How recent a sign-in must be for deletion, export and moderation. |
| `VAWRA_DELETION_GRACE` | 604800 | Seven days before a requested deletion runs. |
| `VAWRA_DRAIN_SECONDS` | 10 in production, 0 otherwise | How long readiness fails before shutdown. |
| `VAWRA_TURN_URLS`, `VAWRA_TURN_SECRET` | none | TURN relay for calls; without them calls stay off. |
| `VAWRA_FCM_CREDENTIALS_B64` | none | Android push: the Firebase service-account JSON, base64. |
| `VAWRA_APNS_KEY_B64`, `VAWRA_APNS_KEY_ID`, `VAWRA_APNS_TEAM_ID`, `VAWRA_APNS_TOPIC`, `VAWRA_APNS_PRODUCTION` | none | iPhone push: the .p8 key (base64), its id, the team id, the app's bundle id, and `1` for the production gateway. All or none. |
| `VAWRA_AGE_CHECK_URL`, `VAWRA_AGE_WEBHOOK_SECRET` | none | The age-check provider's hosted check (with `{reference}`) and the webhook secret (32+ characters), both or neither. Without them nobody's age can be confirmed, so dating stays closed; choosing the provider needs legal review. |
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
