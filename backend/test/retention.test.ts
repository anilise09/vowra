import { mkdtempSync, rmSync, writeFileSync, mkdirSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { backupTo, listBackups, pruneBackups, readBackup } from '../src/backup.js';
import { openPglite, migrate } from '../src/db.js';
import { retention, runRetention } from '../src/jobs/retention.js';
import { RateLimiter } from '../src/rate_limit.js';
import { type Harness, member, type Person, signIn, startHarness, swipe } from './harness.js';

let h: Harness;
beforeEach(async () => (h = await startHarness()));
afterEach(async () => h.close());

const DAY = 24 * 60 * 60 * 1000;
const count = async (table: string, where = 'true', params: unknown[] = []) =>
  (await h.db.query<{ n: number }>(`SELECT count(*)::int AS n FROM ${table} WHERE ${where}`, params))[0]!.n;

const call = (p: Person, method: 'GET' | 'POST', url: string, payload?: object) =>
  h.app.inject({ method, url, headers: p.auth, ...(payload ? { payload } : {}) });

/** Rows for made-up accounts, straight into the database, for limit tests. */
async function strangers(n: number): Promise<string[]> {
  const ids: string[] = [];
  for (let i = 0; i < n; i++) {
    const id = crypto.randomUUID();
    await h.db.query(
      `INSERT INTO accounts (id, email_lookup, email_sealed, created_at) VALUES ($1, $2, 'x', now())`,
      [id, `lookup-${id}`],
    );
    ids.push(id);
  }
  return ids;
}

describe('retention', () => {
  it('removes ended sign-ins, old codes, unsent uploads and old audit rows; keeps live ones', async () => {
    const ana = await member(h, 'Ana');
    await call(ana, 'POST', '/v1/auth/requests'); // noise
    await h.app.inject({ method: 'DELETE', url: '/v1/session', headers: ana.auth });
    const live = await signIn(h, ana.email);
    await h.db.query(
      `INSERT INTO media (id, owner, state, client_upload_id, mime_type, byte_length, sha256, created_at)
       VALUES ($1, $2, 'awaiting_upload', 'u1', 'image/jpeg', 10, $3, now())`,
      [crypto.randomUUID(), ana.accountId, 'a'.repeat(64)],
    );
    expect(await count('session_families', 'revoked_at IS NOT NULL')).toBe(1);

    // Nothing is old enough yet.
    const early = await runRetention(h.db, h.clock);
    expect(early.sessionFamilies).toBe(0);
    expect(early.unsentUploads).toBe(0);

    h.clock.advance((retention.endedSessionsDays + 1) * DAY);
    await h.db.query("UPDATE audit_events SET created_at = now() - interval '400 days'");
    await h.db.query("UPDATE media SET created_at = now() - interval '2 days'");
    const removed = await runRetention(h.db, h.clock);
    expect(removed.sessionFamilies).toBe(1);
    expect(removed.signInRequests).toBeGreaterThan(0);
    expect(removed.unsentUploads).toBe(1);
    expect(removed.auditEvents).toBeGreaterThan(0);

    // The live sign-in is untouched and still works after its access token is refreshed.
    expect(await count('session_families', 'revoked_at IS NULL')).toBe(1);
    const rotated = await h.app.inject({
      method: 'POST',
      url: '/v1/session/rotate',
      payload: { refresh_token: live.refresh },
    });
    expect(rotated.statusCode).toBe(200);

    // Unused for 91 days: that device signs in again.
    h.clock.advance(91 * DAY);
    const idle = await runRetention(h.db, h.clock);
    expect(idle.idleSignIns).toBe(1);
    const stale = await h.app.inject({
      method: 'POST',
      url: '/v1/session/rotate',
      payload: { refresh_token: rotated.json().refresh_token },
    });
    expect(stale.statusCode).toBe(401);
  });

  it('keeps pending reports, removes long-decided ones', async () => {
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    await call(ana, 'POST', '/v1/reports', { account_id: ben.accountId, reason: 'other' });
    await call(ben, 'POST', '/v1/reports', { account_id: ana.accountId, reason: 'other' });
    await h.db.query(
      "UPDATE reports SET state = 'dismissed', decided_at = now() - interval '800 days' WHERE reporter = $1",
      [ana.accountId],
    );
    await runRetention(h.db, h.clock);
    expect(await count('reports')).toBe(1);
    expect(await count('reports', "state = 'pending_review'")).toBe(1);
  });
});

describe('backup and restore', () => {
  let dir: string;
  beforeEach(() => (dir = mkdtempSync(join(tmpdir(), 'vawra-backup-'))));
  afterEach(() => rmSync(dir, { recursive: true, force: true }));

  it('a backup restores to the same data, photos included', async () => {
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    await swipe(h, ana, ben);
    const mediaDir = join(dir, 'media');
    mkdirSync(mediaDir);
    writeFileSync(join(mediaDir, 'photo.webp'), 'photo-bytes');

    const name = await backupTo(join(dir, 'backups'), h.db, mediaDir, h.clock.now());
    const backup = readBackup(join(dir, 'backups'), name);
    const restored = await openPglite(undefined, backup.db);
    await migrate(restored);
    const names = await restored.query<{ display_name: string }>(
      'SELECT display_name FROM profiles ORDER BY display_name',
    );
    expect(names.map((r) => r.display_name)).toEqual(['Ana', 'Ben']);
    expect((await restored.query('SELECT 1 FROM swipes')).length).toBe(1);
    expect(readFileSync(join(backup.mediaDir, 'photo.webp'), 'utf8')).toBe('photo-bytes');
    await restored.close();
  });

  it('keeps the newest seven', async () => {
    const root = join(dir, 'backups');
    for (let i = 0; i < 9; i++) {
      mkdirSync(join(root, `2026-09-${String(10 + i).padStart(2, '0')}`), { recursive: true });
      writeFileSync(join(root, `2026-09-${String(10 + i).padStart(2, '0')}`, 'db.tar.gz'), 'x');
    }
    pruneBackups(root, 7);
    expect(listBackups(root)).toEqual([
      '2026-09-12', '2026-09-13', '2026-09-14', '2026-09-15', '2026-09-16', '2026-09-17', '2026-09-18',
    ]);
  });
});

describe('abuse limits', () => {
  it('likes stop at 300 a day; passes do not', async () => {
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    const cy = await member(h, 'Cy');
    for (const id of await strangers(300)) {
      await h.db.query("INSERT INTO swipes (from_account, to_account, kind, created_at) VALUES ($1, $2, 'like', now())", [
        ana.accountId,
        id,
      ]);
    }
    await h.db.query("UPDATE swipes SET created_at = $1", [h.clock.now()]);
    const res = await swipe(h, ana, ben);
    expect(res.json().error).toBe('like_limit');
    expect((await swipe(h, ana, cy, 'pass')).statusCode).toBe(200);
    h.clock.advance(DAY + 1);
    const later = await signIn(h, ana.email);
    expect((await swipe(h, later, ben)).statusCode).toBe(200);
  });

  it('reports stop at 20 a day', async () => {
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    for (const id of await strangers(20)) {
      await h.db.query(
        "INSERT INTO reports (id, reporter, target, reason, created_at) VALUES ($1, $2, $3, 'other', $4)",
        [crypto.randomUUID(), ana.accountId, id, h.clock.now()],
      );
    }
    const res = await call(ana, 'POST', '/v1/reports', { account_id: ben.accountId, reason: 'scam' });
    expect(res.json().error).toBe('report_limit');
  });

  it('account data is never cached and never type-sniffed', async () => {
    const ana = await member(h, 'Ana');
    const res = await call(ana, 'GET', '/v1/me/profile');
    expect(res.headers['cache-control']).toBe('no-store');
    expect(res.headers['x-content-type-options']).toBe('nosniff');
  });

  it('the in-memory limiter forgets finished windows', () => {
    let now = 0;
    const limiter = new RateLimiter(1, 1000, { now: () => new Date(now) });
    for (let i = 0; i <= 10_000; i++) limiter.take(`key-${i}`);
    expect(limiter.size).toBe(10_001);
    now = 5000;
    limiter.take('new');
    expect(limiter.size).toBe(1);
  });
});
