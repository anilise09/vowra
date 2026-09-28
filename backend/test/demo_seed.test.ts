import { readFileSync } from 'node:fs';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { type DemoProfile, removeDemo, seedDemo } from '../src/demo_seed.js';
import { type Harness, member, startHarness } from './harness.js';

const people = JSON.parse(
  readFileSync(new URL('../fixtures/demo_profiles.json', import.meta.url), 'utf8'),
) as DemoProfile[];

let h: Harness;
beforeEach(async () => (h = await startHarness()));
afterEach(async () => h.close());

describe('demo members for the local test server', () => {
  it('loads all 260 sample profiles once, valid for the real rules', async () => {
    expect(people).toHaveLength(260);
    expect(await seedDemo(h.db, h.sealer, people, h.clock.now())).toBe(260);
    expect(await seedDemo(h.db, h.sealer, people, h.clock.now())).toBe(0);

    const me = await member(h, 'Tester');
    const res = await h.app.inject({
      method: 'GET',
      url: '/v1/discovery?limit=50',
      headers: me.auth,
    });
    const seen = res.json().people as { demo_portrait: string; interests: string[] }[];
    expect(seen).toHaveLength(50);
    for (const p of seen) {
      expect(p.demo_portrait).toMatch(/^assets\/profiles\/.+\.png$/);
      for (const i of p.interests) {
        expect(['Arts', 'Books', 'Cooking', 'Fitness', 'Music', 'Outdoors', 'Travel']).toContain(i);
      }
    }
  }, 120_000);

  it('a portrait can never be set through the API', async () => {
    const me = await member(h, 'Tester');
    const res = await h.app.inject({
      method: 'PATCH',
      url: '/v1/me/profile',
      headers: me.auth,
      payload: { demo_portrait: 'assets/profiles/maya.png' },
    });
    expect(res.statusCode).toBe(400);
    expect(res.json().error).toBe('unknown_field');
  });

  it('removal takes only demo members', async () => {
    const me = await member(h, 'Tester');
    await seedDemo(h.db, h.sealer, people.slice(0, 5), h.clock.now());
    expect(await removeDemo(h.db)).toBe(5);
    const [row] = await h.db.query<{ n: number }>('SELECT count(*)::int AS n FROM accounts');
    expect(row?.n).toBe(1);
    expect((await h.app.inject({ method: 'GET', url: '/v1/me/profile', headers: me.auth })).statusCode).toBe(200);
  });
});
