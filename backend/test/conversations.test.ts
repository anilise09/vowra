import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import type { Nudge } from '../src/nudges.js';
import { type Harness, member, type Person, startHarness, swipe } from './harness.js';

let h: Harness;
beforeEach(async () => (h = await startHarness()));
afterEach(async () => h.close());

const call = (p: Person, method: 'GET' | 'POST' | 'PATCH', url: string, payload?: object) =>
  h.app.inject({ method, url, headers: p.auth, ...(payload ? { payload } : {}) });

async function pair(): Promise<{ ana: Person; ben: Person; matchId: string }> {
  const ana = await member(h, 'Ana');
  const ben = await member(h, 'Ben');
  await swipe(h, ana, ben);
  const matchId = (await swipe(h, ben, ana)).json().match_id;
  return { ana, ben, matchId };
}

const say = (p: Person, matchId: string, text: string) => {
  h.clock.advance(1000);
  return call(p, 'POST', `/v1/matches/${matchId}/messages`, { text });
};

const matchesOf = async (p: Person) => (await call(p, 'GET', '/v1/matches')).json().matches;

function listen(p: Person): Nudge[] {
  const got: Nudge[] = [];
  h.nudges.subscribe(p.accountId, (n) => got.push(n));
  return got;
}

const share = (p: Person, on: boolean) =>
  call(p, 'PATCH', '/v1/me/settings', { share_read_receipts: on });

describe('conversations', () => {
  it('counts unread messages and says whose turn it is', async () => {
    const { ana, ben, matchId } = await pair();
    expect((await matchesOf(ben))[0]).toMatchObject({ unread: 0, last_message: null });

    await say(ana, matchId, 'Hi Ben');
    await say(ana, matchId, 'How is your week?');
    expect((await matchesOf(ben))[0]).toMatchObject({
      unread: 2,
      last_message: 'How is your week?',
      last_message_mine: false,
    });
    expect((await matchesOf(ana))[0]).toMatchObject({ unread: 0, last_message_mine: true });

    expect((await call(ben, 'POST', `/v1/matches/${matchId}/read`)).statusCode).toBe(204);
    expect((await matchesOf(ben))[0].unread).toBe(0);
    await say(ana, matchId, 'Still there?');
    expect((await matchesOf(ben))[0].unread).toBe(1);
  });

  it('tells each person what they share, for opening lines', async () => {
    const { ana, ben } = await pair();
    await call(ana, 'PATCH', '/v1/me/profile', { interests: ['Books', 'Music', 'Travel'] });
    await call(ben, 'PATCH', '/v1/me/profile', {
      interests: ['Music', 'Books', 'Arts'],
      prompts: [{ question: 'Ask me about…', answer: 'my sourdough starter' }],
    });
    const [m] = await matchesOf(ana);
    expect(m.shared_interests).toEqual(['Books', 'Music']);
    expect(m.peer_prompts).toEqual([{ question: 'Ask me about…', answer: 'my sourdough starter' }]);
    expect(m).not.toHaveProperty('peer_interests');
  });

  it('lists the most recent conversation first', async () => {
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    const cy = await member(h, 'Cy');
    for (const other of [ben, cy]) {
      h.clock.advance(1000);
      await swipe(h, ana, other);
      await swipe(h, other, ana);
    }
    const [first, second] = await matchesOf(ana);
    expect(first.peer_name).toBe('Cy'); // newest match
    await say(ben, second.match_id, 'Hello again');
    expect((await matchesOf(ana)).map((m: { peer_name: string }) => m.peer_name)).toEqual([
      'Ben',
      'Cy',
    ]);
  });

  it('"Seen" and read nudges need both people to share receipts', async () => {
    const { ana, ben, matchId } = await pair();
    const anaNudges = listen(ana);
    await say(ana, matchId, 'Hi Ben');
    const seen = async () =>
      (await call(ana, 'GET', `/v1/matches/${matchId}/messages`)).json().messages[0].seen;

    await share(ana, true);
    await call(ben, 'POST', `/v1/matches/${matchId}/read`);
    expect(await seen()).toBeUndefined(); // Ben does not share
    expect(anaNudges.filter((n) => n.kind === 'read')).toEqual([]);

    await share(ben, true);
    expect(await seen()).toBe(true);
    await say(ana, matchId, 'Second');
    const messages = (await call(ana, 'GET', `/v1/matches/${matchId}/messages`)).json().messages;
    expect(messages.map((m: { seen: boolean }) => m.seen)).toEqual([true, false]);
    await call(ben, 'POST', `/v1/matches/${matchId}/read`);
    expect(anaNudges.filter((n) => n.kind === 'read')).toEqual([
      { kind: 'read', match_id: matchId },
    ]);

    // Turning it off hides it again, both ways.
    await share(ben, false);
    expect(await seen()).toBeUndefined();
  });

  it('typing reaches the other person only when both share, at most every 3 s', async () => {
    const { ana, ben, matchId } = await pair();
    const benNudges = listen(ben);
    const typing = () => call(ana, 'POST', `/v1/matches/${matchId}/typing`);

    expect((await typing()).statusCode).toBe(204);
    expect(benNudges).toEqual([]); // nobody shares yet
    await share(ana, true);
    await share(ben, true);
    h.clock.advance(3000);
    await typing();
    await typing();
    await typing();
    expect(benNudges).toEqual([{ kind: 'typing', match_id: matchId }]);
    h.clock.advance(3000);
    await typing();
    expect(benNudges).toHaveLength(2);
  });

  it('settings accept only the known switch', async () => {
    const ana = await member(h, 'Ana');
    expect((await call(ana, 'GET', '/v1/me/settings')).json()).toEqual({
      share_read_receipts: false,
    });
    expect((await share(ana, true)).json()).toEqual({ share_read_receipts: true });
    expect((await call(ana, 'PATCH', '/v1/me/settings', { admin: true })).statusCode).toBe(400);
  });

  it('body-less POSTs work even with a JSON content type', async () => {
    const { ana, ben, matchId } = await pair();
    const json = { ...ana.auth, 'content-type': 'application/json' };
    for (const url of [`/v1/matches/${matchId}/read`, `/v1/matches/${matchId}/typing`, '/v1/me/pause']) {
      const res = await h.app.inject({ method: 'POST', url, headers: json });
      expect([url, res.statusCode]).toEqual([url, 204]);
    }
    const broken = await h.app.inject({
      method: 'POST',
      url: `/v1/matches/${matchId}/messages`,
      headers: { ...ben.auth, 'content-type': 'application/json' },
      payload: '{not json',
    });
    expect(broken.statusCode).toBe(400);
  });

  it('only participants can mark read or send typing', async () => {
    const { matchId } = await pair();
    const stranger = await member(h, 'Cy');
    for (const path of ['read', 'typing']) {
      const res = await call(stranger, 'POST', `/v1/matches/${matchId}/${path}`);
      expect(res.statusCode).toBe(404);
    }
  });
});
