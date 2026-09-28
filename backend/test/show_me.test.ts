import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { type Harness, member, type Person, startHarness, swipe } from './harness.js';

let h: Harness;
beforeEach(async () => (h = await startHarness()));
afterEach(async () => h.close());

const patch = (p: Person, payload: object) =>
  h.app.inject({ method: 'PATCH', url: '/v1/me/profile', headers: p.auth, payload });

async function person(name: string, gender: string, showMe: string[], showGender = false) {
  const p = await member(h, name);
  const res = await patch(p, { gender, show_me: showMe, show_gender: showGender });
  expect(res.statusCode).toBe(200);
  return p;
}

const seen = async (p: Person) =>
  ((await h.app.inject({ method: 'GET', url: '/v1/discovery', headers: p.auth })).json()
    .people as { display_name: string; gender?: string | null }[]);
const names = async (p: Person) => (await seen(p)).map((x) => x.display_name).sort();

describe('who you meet', () => {
  it('two-way: each person must fit the other’s "show me"', async () => {
    const ana = await person('Ana', 'woman', ['man']);
    const ben = await person('Ben', 'man', ['woman']);
    const cy = await person('Cy', 'man', ['man']);
    const dee = await person('Dee', 'woman', ['woman']);
    const eli = await person('Eli', 'nonbinary', []); // open to everyone
    const fay = await person('Fay', 'woman', []);

    expect(await names(ana)).toEqual(['Ben']); // Cy wants men; Eli is not a man
    expect(await names(ben)).toEqual(['Ana', 'Fay']);
    expect(await names(cy)).toEqual([]); // no man here wants men
    expect(await names(dee)).toEqual(['Fay']);
    expect(await names(eli)).toEqual(['Fay']); // everyone else excludes non-binary
    expect(await names(fay)).toEqual(['Ben', 'Dee', 'Eli']);
  });

  it('the same rule guards swipes and likes-you, not just the list', async () => {
    const ana = await person('Ana', 'woman', ['woman']);
    const ben = await person('Ben', 'man', []);
    expect((await swipe(h, ben, ana)).statusCode).toBe(404);
    const likes = await h.app.inject({ method: 'GET', url: '/v1/likes-you', headers: ana.auth });
    expect(likes.json().people).toEqual([]);
  });

  it('gender is shown only when chosen; "show me" is never shown to anyone', async () => {
    const ana = await person('Ana', 'woman', [], true);
    await person('Ben', 'man', ['woman'], false);
    const viewer = await person('Viewer', 'woman', []);
    const people = await seen(viewer);
    expect(people.find((p) => p.display_name === 'Ana')?.gender).toBe('woman');
    expect(people.find((p) => p.display_name === 'Ben')?.gender).toBeNull();
    for (const p of people) expect(p).not.toHaveProperty('show_me');
    // The owner can read their own settings back.
    const mine = (await h.app.inject({ method: 'GET', url: '/v1/me/profile', headers: ana.auth }))
      .json().profile;
    expect(mine).toMatchObject({ gender: 'woman', show_me: [], show_gender: true });
  });

  it('refuses values outside the list', async () => {
    const ana = await member(h, 'Ana');
    for (const payload of [{ gender: 'robot' }, { show_me: ['women'] }, { show_gender: 'yes' }]) {
      expect((await patch(ana, payload)).statusCode).toBe(400);
    }
  });
});
