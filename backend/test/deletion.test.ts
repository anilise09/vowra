import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { runDueDeletions } from '../src/jobs/deletions.js';
import { type Harness, member, type Person, signIn, startHarness, swipe } from './harness.js';

let h: Harness;
beforeEach(async () => (h = await startHarness()));
afterEach(async () => h.close());

const MINUTE = 60_000;
const DAY = 24 * 60 * MINUTE;

const call = (p: Person, method: 'GET' | 'POST' | 'DELETE', url: string, payload?: object) =>
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

async function matched(a: Person, b: Person): Promise<string> {
  await swipe(h, a, b);
  return (await swipe(h, b, a)).json().match_id;
}

const count = async (sql: string, args: unknown[]) =>
  (await h.db.query<{ n: number }>(`SELECT count(*)::int AS n FROM ${sql}`, args))[0]!.n;

describe('account deletion', () => {
  it('needs a recent sign-in, not just any live session', async () => {
    const me = await member(h, 'Ana');
    h.clock.advance(11 * MINUTE);
    const stale = await rotate(me);
    const res = await call(stale, 'POST', '/v1/me/deletion');
    expect(res.statusCode).toBe(403);
    expect(res.json().error).toBe('reauthentication_required');

    const fresh = await signIn(h, me.email);
    const ok = await call(fresh, 'POST', '/v1/me/deletion');
    expect(ok.statusCode).toBe(202);
    expect(ok.json()).toEqual({
      state: 'scheduled',
      effective_at: new Date(h.clock.now().getTime() + 7 * DAY).toISOString(),
    });
  });

  it('hides the person, closes their chats and signs them out everywhere', async () => {
    const me = await member(h, 'Ana');
    const other = await member(h, 'Ben');
    const newcomer = await member(h, 'Cy');
    const secondDevice = await signIn(h, me.email);
    const matchId = await matched(me, other);

    expect((await call(me, 'POST', '/v1/me/deletion')).statusCode).toBe(202);

    for (const session of [me, secondDevice]) {
      expect((await call(session, 'GET', '/v1/me/profile')).statusCode).toBe(401);
    }
    const seen = (await call(newcomer, 'GET', '/v1/discovery')).json().people;
    expect(seen.map((p: { account_id: string }) => p.account_id)).not.toContain(me.accountId);
    expect((await call(other, 'GET', '/v1/matches')).json().matches).toEqual([]);
    const send = await call(other, 'POST', `/v1/matches/${matchId}/messages`, { text: 'Hello?' });
    expect(send.json().error).toBe('conversation_closed');
  });

  it('signing in again shows the date, and dating stays closed', async () => {
    const me = await member(h, 'Ana');
    const first = (await call(me, 'POST', '/v1/me/deletion')).json().effective_at;
    const back = await signIn(h, me.email);
    const profile = (await call(back, 'GET', '/v1/me/profile')).json();
    expect(profile).toMatchObject({ lifecycle: 'deletion_scheduled', deletion_effective_at: first });
    expect((await call(back, 'GET', '/v1/discovery')).json().error).toBe('deletion_scheduled');
    // Resume is not a back door out of deletion.
    expect((await call(back, 'DELETE', '/v1/me/pause')).json().error).toBe('deletion_scheduled');
    // Asking again keeps the first date.
    h.clock.advance(MINUTE);
    const again = await signIn(h, me.email);
    expect((await call(again, 'POST', '/v1/me/deletion')).json().effective_at).toBe(first);
  });

  it('keeping the account restores it as it was, paused included', async () => {
    const me = await member(h, 'Ana');
    expect((await call(me, 'POST', '/v1/me/pause', {})).statusCode).toBe(204);
    await call(me, 'POST', '/v1/me/deletion');
    const back = await signIn(h, me.email);
    expect((await call(back, 'DELETE', '/v1/me/deletion')).statusCode).toBe(204);
    const profile = (await call(back, 'GET', '/v1/me/profile')).json();
    expect(profile).toMatchObject({ lifecycle: 'paused', deletion_effective_at: null });
    expect((await call(back, 'DELETE', '/v1/me/deletion')).json().error).toBe(
      'no_deletion_scheduled',
    );
  });

  it('cannot be cancelled once the time has passed', async () => {
    const me = await member(h, 'Ana');
    await call(me, 'POST', '/v1/me/deletion');
    h.clock.advance(7 * DAY + MINUTE);
    const back = await signIn(h, me.email);
    const res = await call(back, 'DELETE', '/v1/me/deletion');
    expect(res.statusCode).toBe(410);
  });

  it('the job removes everything once due, and nothing before', async () => {
    const me = await member(h, 'Ana');
    const other = await member(h, 'Ben');
    const matchId = await matched(me, other);
    await call(me, 'POST', `/v1/matches/${matchId}/messages`, { text: 'Hi Ben, how are you?' });
    await call(other, 'POST', `/v1/matches/${matchId}/messages`, { text: 'Good! You?' });
    await call(other, 'POST', '/v1/reports', { account_id: me.accountId, reason: 'other' });
    const fresh = await signIn(h, me.email);
    await call(fresh, 'POST', '/v1/me/deletion');

    h.clock.advance(7 * DAY - MINUTE);
    expect(await runDueDeletions(h.db, h.clock)).toBe(0);
    expect(await count('accounts WHERE id = $1', [me.accountId])).toBe(1);

    h.clock.advance(2 * MINUTE);
    expect(await runDueDeletions(h.db, h.clock)).toBe(1);
    const lookup = h.sealer.lookup(me.email);
    expect(await count('accounts WHERE id = $1', [me.accountId])).toBe(0);
    expect(await count('profiles WHERE account_id = $1', [me.accountId])).toBe(0);
    expect(await count('matches WHERE id = $1', [matchId])).toBe(0);
    // Both people's copies go, so nothing can rebuild the account.
    expect(await count('messages WHERE match_id = $1', [matchId])).toBe(0);
    expect(await count('swipes WHERE from_account = $1 OR to_account = $1', [me.accountId])).toBe(0);
    expect(await count('sessions WHERE account_id = $1', [me.accountId])).toBe(0);
    expect(await count('auth_requests WHERE email_lookup = $1', [lookup])).toBe(0);
    expect(await count('audit_events WHERE account_id = $1', [me.accountId])).toBe(0);
    expect(await count("audit_events WHERE kind = 'account_deleted'", [])).toBe(1);
    // The other person keeps their own account.
    const otherNow = await signIn(h, other.email);
    expect((await call(otherNow, 'GET', '/v1/matches')).json().matches).toEqual([]);

    // The same email can start over as a brand-new account.
    const again = await signIn(h, me.email);
    expect(again.accountId).not.toBe(me.accountId);
  });
});
