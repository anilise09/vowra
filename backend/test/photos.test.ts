import { createHash, randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { runDueDeletions } from '../src/jobs/deletions.js';
import { type Harness, member, type Person, signIn, startHarness, makeModerator } from './harness.js';

let h: Harness;
beforeEach(async () => (h = await startHarness()));
afterEach(async () => h.close());

const MINUTE = 60_000;

const call = (p: Person, method: 'GET' | 'POST' | 'PUT' | 'DELETE', url: string, payload?: object) =>
  h.app.inject({ method, url, headers: p.auth, ...(payload ? { payload } : {}) });

/** A small JPEG carrying a camera name and a GPS position in its metadata. */
const photoWithGps = () =>
  sharp({ create: { width: 640, height: 480, channels: 3, background: '#c86b85' } })
    .withExif({
      IFD0: { Make: 'TestCam', Model: 'Secret Model' },
      IFD3: { GPSLatitudeRef: 'N', GPSLatitude: '49/1 53/1 42/1', GPSLongitudeRef: 'W', GPSLongitude: '97/1 8/1 18/1' },
    })
    .jpeg()
    .toBuffer();

const sha = (b: Buffer) => createHash('sha256').update(b).digest('hex');

async function ask(p: Person, bytes: Buffer, mime = 'image/jpeg', extra: object = {}) {
  return call(p, 'POST', '/v1/me/photos', {
    client_upload_id: randomUUID(),
    mime_type: mime,
    byte_length: bytes.length,
    sha256: sha(bytes),
    ...extra,
  });
}

const put = (url: string, bytes: Buffer, mime = 'image/jpeg') =>
  h.app.inject({ method: 'PUT', url, headers: { 'content-type': mime }, payload: bytes });

async function upload(p: Person, bytes?: Buffer) {
  const b = bytes ?? (await photoWithGps());
  const grant = (await ask(p, b)).json();
  const res = await put(grant.upload_url, b);
  expect(res.statusCode).toBe(200);
  return grant.photo_id as string;
}

async function moderator(name: string) {
  const p = await member(h, name);
  await makeModerator(h, p);
  return p;
}

const photosSeenBy = async (viewer: Person, owner: Person) =>
  (await call(viewer, 'GET', '/v1/discovery')).json().people.find(
    (p: { account_id: string }) => p.account_id === owner.accountId,
  )?.photos;

const fetch = (url: string) => h.app.inject({ method: 'GET', url });

describe('profile photos', () => {
  it('stay hidden until approved, and lose all metadata on the way in', async () => {
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    const original = await photoWithGps();
    expect((await sharp(original).metadata()).exif).toBeDefined();

    const id = await upload(ana, original);
    const mine = (await call(ana, 'GET', '/v1/me/photos')).json().photos;
    expect(mine).toEqual([expect.objectContaining({ photo_id: id, state: 'pending_review' })]);
    expect((await fetch(mine[0].url)).statusCode).toBe(200);
    expect(await photosSeenBy(ben, ana)).toEqual([]);

    const stored = h.media.files.get(id)!;
    const meta = await sharp(stored).metadata();
    expect(meta.format).toBe('webp');
    expect(meta.exif).toBeUndefined();
    expect(stored.includes(Buffer.from('Secret Model'))).toBe(false);

    const mod = await moderator('Mo');
    const [queued] = (await call(mod, 'GET', '/v1/mod/photos')).json().photos;
    expect(queued.photo_id).toBe(id);
    expect((await fetch(queued.url)).headers['content-type']).toBe('image/webp');
    const decided = await call(mod, 'POST', `/v1/mod/photos/${id}/decision`, { outcome: 'approved' });
    expect(decided.json()).toEqual({ state: 'approved' });

    const seen = await photosSeenBy(ben, ana);
    expect(seen).toHaveLength(1);
    const img = await fetch(seen[0].url);
    expect(img.statusCode).toBe(200);
    expect(img.headers['cache-control']).toBe('private, max-age=300');
  });

  it('a grant is single-use, short-lived, and checks size, type and content', async () => {
    const ana = await member(h, 'Ana');
    const bytes = await photoWithGps();

    const reused = (await ask(ana, bytes)).json();
    expect((await put(reused.upload_url, bytes)).statusCode).toBe(200);
    expect((await put(reused.upload_url, bytes)).json().error).toBe('invalid_grant');

    const raced = (await ask(ana, bytes)).json();
    const racedAttempts = await Promise.all([
      put(raced.upload_url, bytes),
      put(raced.upload_url, bytes),
    ]);
    expect(racedAttempts.map((r) => r.statusCode).sort()).toEqual([200, 403]);

    const wrongHash = (await ask(ana, bytes, 'image/jpeg', { sha256: 'a'.repeat(64) })).json();
    expect((await put(wrongHash.upload_url, bytes)).json().error).toBe('hash_mismatch');

    const wrongSize = (await ask(ana, bytes, 'image/jpeg', { byte_length: bytes.length + 1 })).json();
    expect((await put(wrongSize.upload_url, bytes)).json().error).toBe('size_mismatch');

    const wrongType = (await ask(ana, bytes)).json();
    expect((await put(wrongType.upload_url, bytes, 'image/png')).statusCode).toBe(415);

    const text = Buffer.from('<?php echo "not an image"; ?>');
    const fake = (await ask(ana, text)).json();
    expect((await put(fake.upload_url, text)).json().error).toBe('wrong_type');

    const truncated = bytes.subarray(0, 400);
    const broken = (await ask(ana, truncated)).json();
    expect((await put(broken.upload_url, truncated)).json().error).toBe('unreadable_image');

    const late = (await ask(ana, bytes)).json();
    h.clock.advance(11 * MINUTE);
    expect((await put(late.upload_url, bytes)).json().error).toBe('invalid_grant');

    const forged = late.upload_url.replace(/grant=.*/, 'grant=forged');
    expect((await put(forged, bytes)).statusCode).toBe(403);
  });

  it('does not orphan a file when its owner deletes during processing', async () => {
    const ana = await member(h, 'Ana');
    const bytes = await photoWithGps();
    const grant = (await ask(ana, bytes)).json();
    let entered!: () => void;
    let release!: () => void;
    const processing = new Promise<void>((resolve) => (entered = resolve));
    const resume = new Promise<void>((resolve) => (release = resolve));
    const store = h.media.put.bind(h.media);
    h.media.put = async (id, processed) => {
      entered();
      await resume;
      await store(id, processed);
    };

    const uploading = put(grant.upload_url, bytes);
    await processing;
    await call(ana, 'DELETE', `/v1/me/photos/${grant.photo_id}`);
    release();
    expect((await uploading).statusCode).toBe(403);
    expect(h.media.files.has(grant.photo_id)).toBe(false);
    expect(await h.db.query('SELECT 1 FROM media WHERE id = $1', [grant.photo_id])).toEqual([]);
  });

  it('refuses images too large to decode safely', async () => {
    const ana = await member(h, 'Ana');
    // 48 million pixels of one colour: a small file that would be huge in memory.
    const bomb = await sharp({ create: { width: 8000, height: 6000, channels: 3, background: '#fff' } })
      .png({ compressionLevel: 9 })
      .toBuffer();
    expect(bomb.length).toBeLessThan(10 * 1024 * 1024);
    const grant = (await ask(ana, bomb, 'image/png')).json();
    expect((await put(grant.upload_url, bomb, 'image/png')).json().error).toBe('unreadable_image');
  });

  it('links stop working after a block or a suspension, and cannot be forged', async () => {
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    const id = await upload(ana);
    const mod = await moderator('Mo');
    await call(mod, 'POST', `/v1/mod/photos/${id}/decision`, { outcome: 'approved' });
    const [photo] = await photosSeenBy(ben, ana);
    expect((await fetch(photo.url)).statusCode).toBe(200);
    expect((await fetch(photo.url.replace(/s=[^&]+/, 's=AAAA'))).statusCode).toBe(404);
    expect((await fetch(photo.url.replace(/p=view/, 'p=review'))).statusCode).toBe(404);

    await call(ana, 'POST', '/v1/blocks', { account_id: ben.accountId });
    expect((await fetch(photo.url)).statusCode).toBe(404);

    const cy = await member(h, 'Cy');
    const [forCy] = await photosSeenBy(cy, ana);
    await h.db.query("UPDATE accounts SET lifecycle = 'suspended' WHERE id = $1", [ana.accountId]);
    expect((await fetch(forCy.url)).statusCode).toBe(404);
  });

  it('links expire', async () => {
    const ana = await member(h, 'Ana');
    await upload(ana);
    const [mine] = (await call(ana, 'GET', '/v1/me/photos')).json().photos;
    h.clock.advance(16 * MINUTE);
    expect((await fetch(mine.url)).statusCode).toBe(404);
  });

  it('six photos at most; rejected ones do not count and are removed', async () => {
    const ana = await member(h, 'Ana');
    const ids: string[] = [];
    for (let i = 0; i < 6; i++) ids.push(await upload(ana));
    const seventh = await ask(ana, await photoWithGps());
    expect(seventh.json().error).toBe('photo_limit');

    const mod = await moderator('Mo');
    expect(
      (await call(mod, 'POST', `/v1/mod/photos/${ids[0]}/decision`, { outcome: 'rejected' })).statusCode,
    ).toBe(400);
    await call(mod, 'POST', `/v1/mod/photos/${ids[0]}/decision`, { outcome: 'rejected', reason: 'someone_else' });
    expect(h.media.files.has(ids[0]!)).toBe(false);
    const mine = (await call(ana, 'GET', '/v1/me/photos')).json().photos;
    expect(mine[0]).toMatchObject({ state: 'rejected', reject_reason: 'someone_else' });
    expect((await ask(ana, await photoWithGps())).statusCode).toBe(200);
  });

  it('keeps the six-photo limit when two servers create the last slot together', async () => {
    const ana = await member(h, 'Ana');
    const bytes = await photoWithGps();
    for (let i = 0; i < 5; i++) expect((await ask(ana, bytes)).statusCode).toBe(200);

    const attempts = await Promise.all([ask(ana, bytes), ask(ana, bytes)]);
    expect(attempts.map((r) => r.statusCode).sort()).toEqual([200, 409]);
    expect(
      await h.db.query('SELECT id FROM media WHERE owner = $1 AND state <> $2', [ana.accountId, 'rejected']),
    ).toHaveLength(6);
  });

  it('moderators: members get 404, never their own photos, a recent sign-in to decide', async () => {
    const ana = await member(h, 'Ana');
    expect((await call(ana, 'GET', '/v1/mod/photos')).statusCode).toBe(404);
    const mod = await moderator('Mo');
    const own = await upload(mod);
    expect((await call(mod, 'GET', '/v1/mod/photos')).json().photos).toEqual([]);
    expect((await call(mod, 'POST', `/v1/mod/photos/${own}/decision`, { outcome: 'approved' })).json().error).toBe(
      'conflict_of_interest',
    );
    const id = await upload(ana);
    h.clock.advance(11 * MINUTE);
    const stale = await call(mod, 'POST', `/v1/mod/photos/${id}/decision`, { outcome: 'approved' });
    // The access token is still valid (15 minutes) but the sign-in is not recent (10).
    expect(stale.json().error).toBe('reauthentication_required');
  });

  it('the owner orders and deletes; deletion removes the file', async () => {
    const ana = await member(h, 'Ana');
    const first = await upload(ana);
    const second = await upload(ana);
    await call(ana, 'PUT', '/v1/me/photos/order', { photo_ids: [second, first] });
    const order = (await call(ana, 'GET', '/v1/me/photos')).json().photos.map((p: { photo_id: string }) => p.photo_id);
    expect(order).toEqual([second, first]);
    const ben = await member(h, 'Ben');
    expect((await call(ben, 'DELETE', `/v1/me/photos/${first}`)).statusCode).toBe(204);
    expect(h.media.files.has(first)).toBe(true);
    await call(ana, 'DELETE', `/v1/me/photos/${first}`);
    expect(h.media.files.has(first)).toBe(false);
  });

  it('an account deletion removes the photo files too; the export lists them', async () => {
    const ana = await member(h, 'Ana');
    const id = await upload(ana);
    const fresh = await signIn(h, ana.email);
    const data = (await call(fresh, 'GET', '/v1/me/export')).json();
    expect(data.photos).toEqual([expect.objectContaining({ state: 'pending_review' })]);
    await call(fresh, 'POST', '/v1/me/deletion');
    h.clock.advance(8 * 24 * 60 * MINUTE);
    await runDueDeletions(h.db, h.clock, h.media);
    expect(h.media.files.has(id)).toBe(false);
  });
});
