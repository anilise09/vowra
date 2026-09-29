# Backup and recovery

Status: development drill in place (BE-13, 2026-09-29). Production backups come from the database
host once one is chosen; this document then gains the host's point-in-time recovery steps.

## What a backup holds

- The database as a snapshot (`db.tar.gz`) and the photo files (`media/`), in one folder per backup
  under `backend/.data/backups/`, named by time.
- Emails and approximate areas inside it stay sealed. The keys (`backend/.data/dev.env`, or the
  production secret store) are never part of a backup, so a stolen backup does not reveal them.
- The newest seven backups are kept; older ones are deleted when a new one is made. An account
  deleted today therefore leaves every backup within seven days of its deletion date.

## Drill (development)

Stop the server first (PGlite allows one process), then from `backend/`:

```
set -a; . .data/dev.env; set +a
npm run dev:backup                 # writes .data/backups/<time>/
npm run dev:restore                # lists backups
npm run dev:restore -- <time>      # moves the current data aside, loads the backup, runs migrations
```

The current database and photos are moved aside (`.data/pglite.before-restore-<time>`), never
deleted, until the restored copy has been checked; delete the set-aside copy afterwards.

## Drill results

| Date | Data | Backup | Restore | Checked after |
|---|---|---|---|---|
| 2026-09-29 | 267 accounts (260 demo members, 7 test members) | 9.7 s, 6.1 MB | 3.7 s | an existing session still worked; a fresh sign-in reached Discover |

An automated test (`backend/test/retention.test.ts`) also backs up a database with profiles, a like
and a photo file, restores it into a new database and compares them, on every test run.

## Production, before launch

- Choose a host with automatic encrypted backups and point-in-time recovery, and object storage
  with versioning for photos; record their retention so it matches the seven-day rule above or the
  reviewed legal schedule.
- Run and time a full restore into a separate environment before launch, then every quarter.
- The keys live in the host's secret store with their own backup, held separately from data backups.
