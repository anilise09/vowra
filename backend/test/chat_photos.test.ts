import { createHash, randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { type Harness, member, type Person, startHarness, swipe } from './harness.js';

let h: Harness;
beforeEach(async () => (h = await startHarness()));
afterEach(async () => h.close());

const call = (p: Person, method: 'GET' | 'POST' | 'PUT' | 'DELETE', url: string, payload?: object) =>
  h.app.inject({ method, url, headers: p.auth, ...(payload ? { payload } : {}) });

const image = () =>
  sharp({ create: { width: 320, height: 240, channels: 3, background: '#88aacc' } }).jpeg().toBuffer();

async function matched() {
  const ana = await member(h, 'Ana');
  const ben = await member(h, 'Ben');
  await swipe(h, ana, ben);
  const matchId = (await swipe(h, ben, ana)).json().match_id as string;
  return { ana, ben, matchId };
}

async function send(from: Person, matchId: string) {
  const bytes = await image();
  const grant = await call(from, 'POST', `/v1/matches/${matchId}/photos`, {
    client_upload_id: randomUUID(),
    mime_type: 'image/jpeg',
    byte_length: bytes.length,
    sha256: createHash('sha256').update(bytes).digest('hex'),
  });
  if (grant.statusCode !== 200) return grant;
  return h.app.inject({
    method: 'PUT',
    url: grant.json().upload_url,
    headers: { 'content-type': 'image/jpeg' },
    payload: bytes,
  });
}

async function moderator() {
  const mod = await member(h, 'Mo');
  await h.db.query("UPDATE accounts SET role = 'moderator' WHERE id = $1", [mod.accountId]);
  return mod;
}

const thread = async (p: Person, matchId: string) =>
  (await call(p, 'GET', `/v1/matches/${matchId}/messages`)).json().messages;

async function approveAll(mod: Person) {
  for (const photo of (await call(mod, 'GET', '/v1/mod/photos')).json().photos) {
    await call(mod, 'POST', `/v1/mod/photos/${photo.photo_id}/decision`, { outcome: 'approved' });
  }
}

describe('photos in a conversation', () => {
  it('only after the receiver allows them', async () => {
    const { ana, ben, matchId } = await matched();
    expect((await send(ana, matchId)).json().error).toBe('photos_not_allowed');
    await call(ben, 'PUT', `/v1/matches/${matchId}/photo-consent`, { allow: true });
    const flags = (await call(ana, 'GET', '/v1/matches')).json().matches[0];
    expect(flags).toMatchObject({ photos_allowed_by_them: true, photos_allowed_by_me: false });
    expect((await send(ana, matchId)).json()).toEqual({ state: 'pending_review' });
  });

  it('arrive as a message only once a moderator approves', async () => {
    const { ana, ben, matchId } = await matched();
    await call(ben, 'PUT', `/v1/matches/${matchId}/photo-consent`, { allow: true });
    await send(ana, matchId);
    expect(await thread(ben, matchId)).toEqual([]);

    const mod = await moderator();
    const [queued] = (await call(mod, 'GET', '/v1/mod/photos')).json().photos;
    expect(queued.context).toBe('chat');
    await approveAll(mod);

    const [forBen] = await thread(ben, matchId);
    expect(forBen).toMatchObject({ mine: false, text: '' });
    expect((await h.app.inject({ method: 'GET', url: forBen.photo.url })).statusCode).toBe(200);
    const [forAna] = await thread(ana, matchId);
    expect(forAna.mine).toBe(true);
    expect((await call(ben, 'GET', '/v1/matches')).json().matches[0].last_message).toBe('Photo');
  });

  it('are never profile photos', async () => {
    const { ana, ben, matchId } = await matched();
    await call(ben, 'PUT', `/v1/matches/${matchId}/photo-consent`, { allow: true });
    await send(ana, matchId);
    await approveAll(await moderator());
    expect((await call(ana, 'GET', '/v1/me/photos')).json().photos).toEqual([]);
    const cy = await member(h, 'Cy');
    const seen = (await call(cy, 'GET', '/v1/discovery')).json().people.find(
      (p: { account_id: string }) => p.account_id === ana.accountId,
    );
    expect(seen.photos).toEqual([]);
  });

  it('turning photos off before review stops delivery', async () => {
    const { ana, ben, matchId } = await matched();
    await call(ben, 'PUT', `/v1/matches/${matchId}/photo-consent`, { allow: true });
    await send(ana, matchId);
    await call(ben, 'PUT', `/v1/matches/${matchId}/photo-consent`, { allow: false });
    await approveAll(await moderator());
    expect(await thread(ben, matchId)).toEqual([]);
  });

  it('a block or unmatch ends access to delivered photos', async () => {
    const { ana, ben, matchId } = await matched();
    await call(ben, 'PUT', `/v1/matches/${matchId}/photo-consent`, { allow: true });
    await send(ana, matchId);
    await approveAll(await moderator());
    const [photo] = await thread(ben, matchId);
    expect((await h.app.inject({ method: 'GET', url: photo.photo.url })).statusCode).toBe(200);
    await call(ben, 'DELETE', `/v1/matches/${matchId}`);
    expect((await h.app.inject({ method: 'GET', url: photo.photo.url })).statusCode).toBe(404);
  });

  it('someone outside the match cannot ask to send one', async () => {
    const { ben, matchId } = await matched();
    await call(ben, 'PUT', `/v1/matches/${matchId}/photo-consent`, { allow: true });
    const cy = await member(h, 'Cy');
    expect((await send(cy, matchId)).statusCode).toBe(404);
  });
});
