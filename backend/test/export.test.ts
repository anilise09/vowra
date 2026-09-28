import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { type Harness, member, type Person, signIn, startHarness, swipe } from './harness.js';

let h: Harness;
beforeEach(async () => (h = await startHarness()));
afterEach(async () => h.close());

const MINUTE = 60_000;

const call = (
  p: Person,
  method: 'GET' | 'POST' | 'DELETE' | 'PATCH',
  url: string,
  payload?: object,
) =>
  h.app.inject({ method, url, headers: p.auth, ...(payload ? { payload } : {}) });

/** The same session family, rotated after time has passed: an old sign-in. */
async function rotate(p: Person): Promise<Person> {
  const body = (
    await h.app.inject({
      method: 'POST',
      url: '/v1/session/rotate',
      payload: { refresh_token: p.refresh },
    })
  ).json();
  return {
    ...p,
    access: body.access_token,
    refresh: body.refresh_token,
    auth: { authorization: `Bearer ${body.access_token}` },
  };
}

describe('download my data', () => {
  it('holds everything about me, and nothing private about anyone else', async () => {
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    const cy = await member(h, 'Cy');
    await call(ana, 'PATCH', '/v1/me/profile', {
      bio: 'Weekend hikes and a sourdough habit.',
      gender: 'woman',
      show_me: ['man'],
    });
    for (const man of [ben, cy]) await call(man, 'PATCH', '/v1/me/profile', { gender: 'man' });
    await swipe(h, ana, ben);
    const matchId = (await swipe(h, ben, ana)).json().match_id;
    await call(ana, 'POST', `/v1/matches/${matchId}/messages`, { text: 'Hi Ben!' });
    await call(ben, 'POST', `/v1/matches/${matchId}/messages`, { text: 'Secret from Ben' });
    await swipe(h, ana, cy, 'pass');
    await call(ana, 'POST', '/v1/reports', { account_id: cy.accountId, reason: 'scam' });

    const res = await call(ana, 'GET', '/v1/me/export');
    expect(res.statusCode).toBe(200);
    expect(res.headers['cache-control']).toBe('no-store');
    const data = res.json();
    expect(data.account.email).toBe('ana@example.test');
    expect(data.profile).toMatchObject({
      display_name: 'Ana',
      bio: 'Weekend hikes and a sourdough habit.',
      gender: 'woman',
      show_me: ['man'],
    });
    expect(data.swipes.map((s: { kind: string }) => s.kind).sort()).toEqual(['like', 'pass']);
    expect(data.matches).toHaveLength(1);
    expect(data.matches[0]).toMatchObject({ with: 'Ben', status: 'active' });
    expect(data.matches[0].messages_you_sent.map((m: { text: string }) => m.text)).toEqual(['Hi Ben!']);
    expect(data.reports_you_made).toHaveLength(1);
    expect(data.sign_ins.length).toBeGreaterThan(0);

    const text = res.body;
    expect(text).not.toContain('Secret from Ben');
    for (const other of [ben, cy]) expect(text).not.toContain(other.accountId);
    expect(text).not.toContain('ben@example.test');
    expect(text).not.toContain(ana.accountId);
    expect(text).not.toMatch(/email_sealed|email_lookup|proof|refresh|access_hash/);
  });

  it('needs a recent sign-in, like deletion', async () => {
    const ana = await member(h, 'Ana');
    h.clock.advance(11 * MINUTE);
    const stale = await rotate(ana);
    const res = await call(stale, 'GET', '/v1/me/export');
    expect(res.statusCode).toBe(403);
    expect(res.json().error).toBe('reauthentication_required');
    const fresh = await signIn(h, ana.email);
    expect((await call(fresh, 'GET', '/v1/me/export')).statusCode).toBe(200);
  });

  it('works while deletion is pending, and is recorded', async () => {
    const ana = await member(h, 'Ana');
    await call(ana, 'POST', '/v1/me/deletion');
    const back = await signIn(h, ana.email);
    const data = (await call(back, 'GET', '/v1/me/export')).json();
    expect(data.account.lifecycle).toBe('deletion_scheduled');
    expect(data.account.deletion_effective_at).toBeTruthy();
    const [row] = await h.db.query<{ n: number }>(
      "SELECT count(*)::int AS n FROM audit_events WHERE account_id = $1 AND kind = 'data_exported'",
      [ana.accountId],
    );
    expect(row!.n).toBe(1);
  });

  it('allows a few copies a day, then asks the person to wait', async () => {
    const ana = await member(h, 'Ana');
    for (let i = 0; i < 5; i++) {
      expect((await call(ana, 'GET', '/v1/me/export')).statusCode).toBe(200);
    }
    const sixth = await call(ana, 'GET', '/v1/me/export');
    expect(sixth.statusCode).toBe(429);
    expect(sixth.json().error).toBe('rate_limited');
    h.clock.advance(24 * 60 * MINUTE + 1);
    const later = await signIn(h, ana.email);
    expect((await call(later, 'GET', '/v1/me/export')).statusCode).toBe(200);
  });

  it('refuses without a session', async () => {
    const res = await h.app.inject({ method: 'GET', url: '/v1/me/export' });
    expect(res.statusCode).toBe(401);
  });
});
