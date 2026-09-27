import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  type Harness,
  makeProfile,
  member,
  type Person,
  signIn,
  startHarness,
  swipe,
} from './harness.js';

let h: Harness;
beforeEach(async () => (h = await startHarness()));
afterEach(async () => h.close());

const get = (p: Person, url: string) => h.app.inject({ method: 'GET', url, headers: p.auth });
const post = (p: Person, url: string, payload: object) =>
  h.app.inject({ method: 'POST', url, headers: p.auth, payload });
const discoverable = async (p: Person) =>
  ((await get(p, '/v1/discovery')).json().people as { account_id: string }[]).map((x) => x.account_id);

async function matched(a: Person, b: Person): Promise<string> {
  await swipe(h, a, b);
  return (await swipe(h, b, a)).json().match_id;
}

describe('profile', () => {
  it('accepts only the contract fields', async () => {
    const p = await signIn(h, 'fields@example.test');
    for (const extra of [{ age: 19 }, { account_id: p.accountId }, { age_state: 'adult_verified' }]) {
      const res = await h.app.inject({
        method: 'PATCH',
        url: '/v1/me/profile',
        headers: p.auth,
        payload: { display_name: 'Alex', relationship_intent: 'casual', ...extra },
      });
      expect(res.statusCode).toBe(400);
      expect(res.json().error).toBe('unknown_field');
    }
  });

  it('repeats the app validation rules', async () => {
    const p = await signIn(h, 'rules@example.test');
    const patch = (payload: object) =>
      h.app.inject({ method: 'PATCH', url: '/v1/me/profile', headers: p.auth, payload });
    expect((await patch({ display_name: 'A', relationship_intent: 'casual' })).json().error).toBe(
      'name_too_short',
    );
    expect((await patch({ display_name: 'Alex' })).json().error).toBe('profile_incomplete');
    expect(
      (await patch({ display_name: 'Alex', relationship_intent: 'casual', bio: 'Too short' })).json()
        .error,
    ).toBe('bio_too_short');
    const ok = await patch({ display_name: '  Alex ', relationship_intent: 'casual', bio: '' });
    expect(ok.json().profile).toMatchObject({ display_name: 'Alex', public_age: null });
  });
});

describe('age gate', () => {
  it('keeps every dating feature closed until age assurance passes', async () => {
    const p = await signIn(h, 'unverified@example.test');
    await makeProfile(h, p, 'Unverified');
    const other = await member(h, 'Maya');
    for (const res of [
      await get(p, '/v1/discovery'),
      await get(p, '/v1/matches'),
      await get(p, '/v1/likes-you'),
      await swipe(h, p, other),
    ]) {
      expect(res.statusCode).toBe(403);
      expect(res.json().error).toBe('age_assurance_required');
    }
    // Unverified people are also invisible to others.
    expect(await discoverable(other)).not.toContain(p.accountId);
  });
});

describe('discovery, likes and matches', () => {
  it('shows only eligible people and never self', async () => {
    const me = await member(h, 'Me');
    const shown = await member(h, 'Shown');
    const paused = await member(h, 'Paused');
    await post(paused, '/v1/me/pause', {});
    const noProfile = await signIn(h, 'noprofile@example.test');
    const people = await discoverable(me);
    expect(people).toContain(shown.accountId);
    expect(people).not.toContain(me.accountId);
    expect(people).not.toContain(paused.accountId);
    expect(people).not.toContain(noProfile.accountId);
  });

  it('likes are idempotent and only two likes make one match', async () => {
    const a = await member(h, 'Ana');
    const b = await member(h, 'Ben');
    expect((await swipe(h, a, b)).json()).toEqual({ matched: false });
    expect((await swipe(h, a, b, 'pass')).json()).toEqual({ matched: false }); // first decision stands
    const second = (await swipe(h, b, a, 'super_like')).json();
    expect(second.matched).toBe(true);
    expect((await swipe(h, b, a)).json().match_id).toBe(second.match_id);
    expect(await h.db.query('SELECT * FROM matches')).toHaveLength(1);
    // Once decided, people leave the deck.
    expect(await discoverable(a)).not.toContain(b.accountId);
  });

  it('a pass never creates a match', async () => {
    const a = await member(h, 'Ana');
    const b = await member(h, 'Ben');
    await swipe(h, a, b, 'pass');
    expect((await swipe(h, b, a)).json()).toEqual({ matched: false });
  });

  it('likes-you lists unanswered incoming likes, free', async () => {
    const me = await member(h, 'Me');
    const fan = await member(h, 'Fan');
    await swipe(h, fan, me, 'super_like');
    const likes = (await get(me, '/v1/likes-you')).json().people;
    expect(likes).toEqual([
      expect.objectContaining({ account_id: fan.accountId, super_like: true }),
    ]);
  });

  it('unknown and blocked targets look exactly the same', async () => {
    const a = await member(h, 'Ana');
    const b = await member(h, 'Ben');
    await post(b, '/v1/blocks', { account_id: a.accountId });
    const blocked = await swipe(h, a, b);
    const unknown = await h.app.inject({
      method: 'POST',
      url: `/v1/discovery/${crypto.randomUUID()}/swipe`,
      headers: a.auth,
      payload: { kind: 'like' },
    });
    expect(blocked.statusCode).toBe(404);
    expect(unknown.statusCode).toBe(404);
    expect(blocked.json().error).toBe(unknown.json().error);
  });
});

describe('chat', () => {
  it('only the two participants can read or write', async () => {
    const a = await member(h, 'Ana');
    const b = await member(h, 'Ben');
    const outsider = await member(h, 'Eve');
    const matchId = await matched(a, b);

    expect((await post(a, `/v1/matches/${matchId}/messages`, { text: '  Hi   there ' })).json())
      .toMatchObject({ text: 'Hi there', mine: true });
    const theirView = (await get(b, `/v1/matches/${matchId}/messages`)).json().messages;
    expect(theirView).toEqual([expect.objectContaining({ text: 'Hi there', mine: false })]);

    const peek = await get(outsider, `/v1/matches/${matchId}/messages`);
    const write = await post(outsider, `/v1/matches/${matchId}/messages`, { text: 'hello' });
    const missing = await get(outsider, `/v1/matches/${crypto.randomUUID()}/messages`);
    for (const res of [peek, write, missing]) {
      expect(res.statusCode).toBe(404);
      expect(res.json().error).toBe('not_found');
    }
  });

  it('validates text and limits five messages a minute', async () => {
    const a = await member(h, 'Ana');
    const b = await member(h, 'Ben');
    const matchId = await matched(a, b);
    const send = (text: string) => post(a, `/v1/matches/${matchId}/messages`, { text });
    expect((await send('   ')).json().error).toBe('message_empty');
    expect((await send('x'.repeat(1001))).json().error).toBe('message_too_long');
    for (let i = 0; i < 5; i++) expect((await send(`hello ${i}`)).statusCode).toBe(201);
    expect((await send('one more')).statusCode).toBe(429);
    h.clock.advance(61_000);
    expect((await send('later')).statusCode).toBe(201);
  });

  it('block closes the conversation both ways, immediately', async () => {
    const a = await member(h, 'Ana');
    const b = await member(h, 'Ben');
    const matchId = await matched(a, b);
    expect((await post(a, '/v1/blocks', { account_id: b.accountId })).statusCode).toBe(204);

    for (const p of [a, b]) {
      expect((await post(p, `/v1/matches/${matchId}/messages`, { text: 'hi' })).statusCode).toBe(409);
      expect((await get(p, '/v1/matches')).json().matches).toEqual([]);
      expect(await discoverable(p)).toEqual([]);
    }
    // Unblocking never revives the old conversation.
    await h.app.inject({ method: 'DELETE', url: `/v1/blocks/${b.accountId}`, headers: a.auth });
    expect((await post(a, `/v1/matches/${matchId}/messages`, { text: 'hi' })).statusCode).toBe(409);
  });

  it('unmatch closes the conversation', async () => {
    const a = await member(h, 'Ana');
    const b = await member(h, 'Ben');
    const matchId = await matched(a, b);
    await h.app.inject({ method: 'DELETE', url: `/v1/matches/${matchId}`, headers: b.auth });
    expect((await post(a, `/v1/matches/${matchId}/messages`, { text: 'hi' })).statusCode).toBe(409);
  });
});

describe('reports', () => {
  it('are free, private, and keep only a valid message reference', async () => {
    const a = await member(h, 'Ana');
    const b = await member(h, 'Ben');
    const matchId = await matched(a, b);
    const theirMessage = (await post(b, `/v1/matches/${matchId}/messages`, { text: 'send money' }))
      .json().id;
    const mine = (await post(a, `/v1/matches/${matchId}/messages`, { text: 'no' })).json().id;

    const good = await post(a, '/v1/reports', {
      account_id: b.accountId,
      reason: 'scam',
      message_id: theirMessage,
    });
    expect(good.json()).toEqual({ state: 'pending_review' });
    await post(a, '/v1/reports', { account_id: b.accountId, reason: 'scam', message_id: mine });
    const rows = await h.db.query<{ message_id: string | null }>(
      'SELECT message_id FROM reports ORDER BY created_at',
    );
    expect(rows.map((r) => r.message_id).sort()).toEqual([null, theirMessage].sort());

    // Unknown targets get the same answer and store nothing.
    const unknown = await post(a, '/v1/reports', { account_id: crypto.randomUUID(), reason: 'other' });
    expect(unknown.json()).toEqual({ state: 'pending_review' });
    expect(await h.db.query('SELECT * FROM reports')).toHaveLength(2);
  });
});
