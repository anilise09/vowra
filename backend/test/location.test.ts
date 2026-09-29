import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { distanceBand, distanceKm, snapToCell } from '../src/location.js';
import { type Harness, member, type Person, signIn, startHarness } from './harness.js';

let h: Harness;
beforeEach(async () => (h = await startHarness()));
afterEach(async () => h.close());

const MINUTE = 60_000;
// A made-up test point, and one about 7.5 km north of it.
const here = { lat: 49.8951, lng: -97.1384 };
const north = { lat: 49.8951 + 0.0675, lng: -97.1384 };

const call = (p: Person, method: 'GET' | 'PUT' | 'DELETE' | 'PATCH', url: string, payload?: object) =>
  h.app.inject({ method, url, headers: p.auth, ...(payload ? { payload } : {}) });

const bandFor = async (viewer: Person, other: Person) =>
  (await call(viewer, 'GET', '/v1/discovery')).json().people.find(
    (p: { account_id: string }) => p.account_id === other.accountId,
  )?.distance_band;

describe('the approximate-area grid', () => {
  it('rounds any point in a cell to the same centre, about 2 km apart', () => {
    const a = snapToCell(here.lat, here.lng);
    for (const [dLat, dLng] of [[0.008, 0.012], [-0.008, -0.012], [0.004, -0.004]]) {
      expect(snapToCell(a.lat + dLat!, a.lng + dLng!)).toEqual(a);
    }
    expect(snapToCell(a.lat, a.lng)).toEqual(a);
    const next = snapToCell(a.lat + 0.018, a.lng);
    expect(distanceKm(a, next)).toBeGreaterThan(1.5);
    expect(distanceKm(a, next)).toBeLessThan(2.5);
    expect(distanceKm(a, snapToCell(here.lat, here.lng))).toBe(0);
  });

  it('keeps every centre a valid point, even at the date line', () => {
    for (const lng of [179.999, -179.999, 180, -180]) {
      const c = snapToCell(51.5, lng);
      expect(c.lng).toBeGreaterThanOrEqual(-180);
      expect(c.lng).toBeLessThanOrEqual(180);
    }
  });

  it('uses wide bands', () => {
    expect([0, 4.9, 5, 9.9, 24, 49, 99, 100, 4000].map(distanceBand)).toEqual([
      'Under 5 km away',
      'Under 5 km away',
      '5–10 km away',
      '5–10 km away',
      '10–25 km away',
      '25–50 km away',
      '50–100 km away',
      'Over 100 km away',
      'Over 100 km away',
    ]);
  });
});

describe('approximate area', () => {
  it('shows a band only when both have an area, never the area itself', async () => {
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    expect(await bandFor(ana, ben)).toBeNull();

    const set = await call(ana, 'PUT', '/v1/me/location', here);
    expect(set.statusCode).toBe(200);
    expect(set.json()).toEqual({ updated_at: expect.any(String), cell_km: 2 });
    expect(await bandFor(ana, ben)).toBeNull();

    await call(ben, 'PUT', '/v1/me/location', north);
    expect(await bandFor(ana, ben)).toBe('5–10 km away');
    expect(await bandFor(ben, ana)).toBe('5–10 km away');

    const raw = (await call(ana, 'GET', '/v1/discovery')).body;
    expect(raw).not.toMatch(/location_sealed|show_distance_band|"lat"|"lng"/);
    expect(raw).not.toContain('49.9');
    const me = (await call(ana, 'GET', '/v1/me/profile')).json();
    expect(me.location_updated_at).toEqual(expect.any(String));
    expect(JSON.stringify(me)).not.toMatch(/"lat"|"lng"|location_sealed/);
  });

  it('stores only the cell centre, sealed', async () => {
    const ana = await member(h, 'Ana');
    await call(ana, 'PUT', '/v1/me/location', { lat: 49.89513, lng: -97.13841 });
    const [row] = await h.db.query<{ location_sealed: string }>(
      'SELECT location_sealed FROM profiles WHERE account_id = $1',
      [ana.accountId],
    );
    expect(row!.location_sealed).not.toContain('49.');
    expect(JSON.parse(h.sealer.open(row!.location_sealed))).toEqual(snapToCell(49.89513, -97.13841));
  });

  it('the other person decides whether their distance shows', async () => {
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    await call(ana, 'PUT', '/v1/me/location', here);
    await call(ben, 'PUT', '/v1/me/location', north);
    await call(ben, 'PATCH', '/v1/me/profile', { show_distance_band: false });
    expect(await bandFor(ana, ben)).toBeNull();
    expect(await bandFor(ben, ana)).toBe('5–10 km away');
  });

  it('"Likes you" carries the band too', async () => {
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    await call(ana, 'PUT', '/v1/me/location', here);
    await call(ben, 'PUT', '/v1/me/location', north);
    await h.app.inject({
      method: 'POST',
      url: `/v1/discovery/${ana.accountId}/swipe`,
      headers: ben.auth,
      payload: { kind: 'like' },
    });
    const likes = (await call(ana, 'GET', '/v1/likes-you')).json().people;
    expect(likes[0].distance_band).toBe('5–10 km away');
    expect(JSON.stringify(likes)).not.toContain('location_sealed');
  });

  it('a new area at most every 15 minutes, and no teleporting', async () => {
    const ana = await member(h, 'Ana');
    expect((await call(ana, 'PUT', '/v1/me/location', here)).statusCode).toBe(200);
    // The same area again is fine (the app refreshes on start).
    expect((await call(ana, 'PUT', '/v1/me/location', here)).statusCode).toBe(200);
    const soon = await call(ana, 'PUT', '/v1/me/location', north);
    expect(soon.statusCode).toBe(429);
    expect(soon.json().error).toBe('slow_down');
    h.clock.advance(16 * MINUTE);
    const later = await signIn(h, ana.email);
    expect((await call(later, 'PUT', '/v1/me/location', north)).statusCode).toBe(200);
    h.clock.advance(60 * MINUTE);
    // About 13,500 km in an hour.
    const again = await signIn(h, ana.email);
    const far = await call(again, 'PUT', '/v1/me/location', { lat: -33.87, lng: 151.21 });
    expect(far.statusCode).toBe(422);
    expect(far.json().error).toBe('implausible_move');
  });

  it('turning it off removes the band at once', async () => {
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    await call(ana, 'PUT', '/v1/me/location', here);
    await call(ben, 'PUT', '/v1/me/location', north);
    expect((await call(ben, 'DELETE', '/v1/me/location')).statusCode).toBe(204);
    expect(await bandFor(ana, ben)).toBeNull();
    expect((await call(ben, 'GET', '/v1/me/profile')).json().location_updated_at).toBeNull();
  });

  it('is in the person’s own export, as the cell only', async () => {
    const ana = await member(h, 'Ana');
    await call(ana, 'PUT', '/v1/me/location', here);
    const fresh = await signIn(h, ana.email);
    const data = (await call(fresh, 'GET', '/v1/me/export')).json();
    expect(data.approximate_area).toMatchObject({ ...snapToCell(here.lat, here.lng), cell_km: 2 });
  });

  it('rejects bad input and needs a session and a profile', async () => {
    const ana = await member(h, 'Ana');
    for (const payload of [
      { lat: 91, lng: 0 },
      { lat: 0, lng: 181 },
      { lat: '49', lng: '-97' },
      { lat: 49, lng: -97, accuracy: 3 },
      {},
    ]) {
      expect((await call(ana, 'PUT', '/v1/me/location', payload)).statusCode).toBe(400);
    }
    expect(
      (await h.app.inject({ method: 'PUT', url: '/v1/me/location', payload: here })).statusCode,
    ).toBe(401);
    const noProfile = await signIn(h, 'new@example.test');
    expect((await call(noProfile, 'PUT', '/v1/me/location', here)).statusCode).toBe(409);
  });
});
