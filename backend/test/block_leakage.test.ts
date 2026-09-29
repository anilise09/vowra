import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { type Harness, member, type Person, startHarness, swipe } from './harness.js';

/**
 * Random sequences of likes, messages, blocks and unblocks; after every step,
 * no blocked pair can see or reach each other anywhere. Seeded, so a failure
 * replays exactly.
 */
let h: Harness;
beforeEach(async () => (h = await startHarness()));
afterEach(async () => h.close());

function rng(seed: number) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 2 ** 32;
  };
}

const call = (p: Person, method: 'GET' | 'POST' | 'DELETE', url: string, payload?: object) =>
  h.app.inject({ method, url, headers: p.auth, ...(payload ? { payload } : {}) });

async function checkPair(a: Person, b: Person, matchIds: Map<string, string>) {
  const ids = (res: { json(): { people?: { account_id: string }[] } }) =>
    (res.json().people ?? []).map((p) => p.account_id);
  for (const [viewer, other] of [
    [a, b],
    [b, a],
  ] as const) {
    expect(ids(await call(viewer, 'GET', '/v1/discovery?limit=50'))).not.toContain(other.accountId);
    expect(ids(await call(viewer, 'GET', '/v1/likes-you'))).not.toContain(other.accountId);
    const matches = (await call(viewer, 'GET', '/v1/matches')).json().matches as { peer_account_id: string }[];
    expect(matches.map((m) => m.peer_account_id)).not.toContain(other.accountId);
    const key = [viewer.accountId, other.accountId].sort().join(':');
    const matchId = matchIds.get(key);
    if (matchId) {
      const send = await call(viewer, 'POST', `/v1/matches/${matchId}/messages`, { text: 'Are you there?' });
      expect(send.json().error).toBe('conversation_closed');
      expect((await call(viewer, 'GET', `/v1/matches/${matchId}/messages`)).json().error).toBe(
        'conversation_closed',
      );
    }
    const like = await swipe(h, viewer, other);
    expect(like.statusCode).toBe(404);
  }
}

describe('blocks never leak', () => {
  for (const seed of [7, 42, 2026]) {
    it(`random sequence ${seed}`, async () => {
      const random = rng(seed);
      const people: Person[] = [];
      for (const name of ['Ana', 'Ben', 'Cy', 'Dee', 'Eli', 'Fay']) people.push(await member(h, name));
      const pick = () => people[Math.floor(random() * people.length)]!;
      const blocked = new Set<string>();
      const matchIds = new Map<string, string>();
      const pairKey = (x: Person, y: Person) => [x.accountId, y.accountId].sort().join(':');

      for (let step = 0; step < 60; step++) {
        const a = pick();
        const b = pick();
        if (a === b) continue;
        const key = pairKey(a, b);
        const roll = random();
        if (roll < 0.45) {
          const res = await swipe(h, a, b, random() < 0.2 ? 'super_like' : 'like');
          if (res.json().match_id) matchIds.set(key, res.json().match_id);
        } else if (roll < 0.65 && matchIds.has(key)) {
          await call(a, 'POST', `/v1/matches/${matchIds.get(key)}/messages`, { text: `step ${step}` });
        } else if (roll < 0.85) {
          await call(a, 'POST', '/v1/blocks', { account_id: b.accountId });
          blocked.add(key);
        } else {
          // Unblocking never revives anything: the pair stays apart until they
          // meet again through Discover.
          await call(a, 'DELETE', `/v1/blocks/${b.accountId}`);
          await call(b, 'DELETE', `/v1/blocks/${a.accountId}`);
          if (blocked.delete(key) && matchIds.has(key)) {
            const send = await call(a, 'POST', `/v1/matches/${matchIds.get(key)}/messages`, { text: 'back?' });
            expect(send.json().error).toBe('conversation_closed');
          }
        }
        for (const pair of blocked) {
          const [x, y] = pair.split(':');
          await checkPair(
            people.find((p) => p.accountId === x)!,
            people.find((p) => p.accountId === y)!,
            matchIds,
          );
        }
      }
      expect(blocked.size + matchIds.size).toBeGreaterThan(0);
    }, 180_000);
  }
});
