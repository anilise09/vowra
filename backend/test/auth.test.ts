import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { pkceChallenge } from '../src/crypto.js';
import { initiationMessage } from '../src/routes/auth.js';
import { DbRateLimiter } from '../src/rate_limit.js';
import { type Harness, signIn, startHarness, state, verifier } from './harness.js';

let h: Harness;
beforeEach(async () => (h = await startHarness()));
afterEach(async () => h.close());

const request = (identifier: string, purpose = 'sign_in', v = verifier(), s = state()) =>
  h.app.inject({
    method: 'POST',
    url: '/v1/auth/requests',
    payload: { identifier, purpose, code_challenge: pkceChallenge(v), state: s },
  });

describe('sign-in requests', () => {
  it('shares an atomic limit across server instances, then resets after the window', async () => {
    const first = new DbRateLimiter(h.db, 5, 15 * 60_000, h.clock);
    const second = new DbRateLimiter(h.db, 5, 15 * 60_000, h.clock);
    const key = h.sealer.lookup('auth:sign_in:shared@example.test');
    const attempts = await Promise.all(
      Array.from({ length: 8 }, (_, i) => (i % 2 === 0 ? first : second).take(key)),
    );
    expect(attempts.filter(Boolean)).toHaveLength(5);
    expect(await second.take(key)).toBe(false);
    h.clock.advance(15 * 60_000);
    expect(await first.take(key)).toBe(true);
  });

  it('answer identically for known, unknown, recovery and throttled requests', async () => {
    await signIn(h, 'known@example.test');
    const bodies = new Set<string>();
    const statuses = new Set<number>();
    for (const [email, purpose] of [
      ['known@example.test', 'sign_in'],
      ['nobody@example.test', 'sign_in'],
      ['nobody@example.test', 'recovery'],
      ['known@example.test', 'recovery'],
    ]) {
      const res = await request(email!, purpose);
      bodies.add(res.body);
      statuses.add(res.statusCode);
    }
    for (let i = 0; i < 8; i++) {
      const res = await request('flood@example.test');
      bodies.add(res.body);
      statuses.add(res.statusCode);
    }
    expect([...statuses]).toEqual([202]);
    expect([...bodies]).toEqual([JSON.stringify(initiationMessage)]);
    // Recovery for an unknown account sends nothing; throttling stops delivery.
    expect(h.outbox.filter((m) => m.email === 'nobody@example.test' && m.purpose === 'recovery')).toHaveLength(0);
    expect(h.outbox.filter((m) => m.email === 'flood@example.test')).toHaveLength(5);
  });

  it('never stores the email, network address or tokens in clear', async () => {
    const p = await signIn(h, 'secret.person@example.test');
    const dump = JSON.stringify([
      await h.db.query('SELECT * FROM accounts'),
      await h.db.query('SELECT * FROM auth_requests'),
      await h.db.query('SELECT * FROM sessions'),
      await h.db.query('SELECT * FROM auth_rate_limit_windows'),
    ]);
    expect(dump).not.toContain('secret.person');
    expect(dump).not.toContain('127.0.0.1');
    expect(dump).not.toContain(p.access);
    expect(dump).not.toContain(p.refresh);
  });
});

describe('proof exchange', () => {
  it('needs the matching PKCE verifier and state, and works only once', async () => {
    const v = verifier();
    const s = state();
    await request('pkce@example.test', 'sign_in', v, s);
    const proof = h.outbox.at(-1)!.proof;
    const exchange = (payload: object) =>
      h.app.inject({ method: 'POST', url: '/v1/auth/exchange', payload });

    const wrongVerifier = await exchange({ proof, code_verifier: verifier(), state: s });
    expect(wrongVerifier.statusCode).toBe(400);
    // A failed attempt still spends the proof: no guessing loop.
    const afterFailure = await exchange({ proof, code_verifier: v, state: s });
    expect(afterFailure.statusCode).toBe(400);
  });

  it('rejects an expired proof', async () => {
    const v = verifier();
    const s = state();
    await request('late@example.test', 'sign_in', v, s);
    h.clock.advance(11 * 60_000);
    const res = await h.app.inject({
      method: 'POST',
      url: '/v1/auth/exchange',
      payload: { proof: h.outbox.at(-1)!.proof, code_verifier: v, state: s },
    });
    expect(res.statusCode).toBe(400);
    expect(res.json().error).toBe('invalid_proof');
  });

  it('starts new accounts behind the age gate', async () => {
    const p = await signIn(h, 'new@example.test');
    const me = await h.app.inject({ method: 'GET', url: '/v1/me/profile', headers: p.auth });
    expect(me.json()).toMatchObject({ age_state: 'assurance_required', profile: null });
  });
});

describe('sessions', () => {
  it('rotation revokes the family when an old refresh token is reused', async () => {
    const p = await signIn(h, 'rotate@example.test');
    const rotate = (token: string) =>
      h.app.inject({ method: 'POST', url: '/v1/session/rotate', payload: { refresh_token: token } });

    const first = await rotate(p.refresh);
    expect(first.statusCode).toBe(200);
    const fresh = first.json();

    const replay = await rotate(p.refresh);
    expect(replay.statusCode).toBe(401);
    // The attacker's replay also kills the legitimate new session.
    const stillIn = await h.app.inject({
      method: 'GET',
      url: '/v1/me/profile',
      headers: { authorization: `Bearer ${fresh.access_token}` },
    });
    expect(stillIn.statusCode).toBe(401);
    expect((await rotate(fresh.refresh_token)).statusCode).toBe(401);
  });

  it('access tokens expire and sign-out everywhere revokes every session', async () => {
    const a = await signIn(h, 'multi@example.test');
    const b = await signIn(h, 'multi@example.test');
    expect(b.accountId).toBe(a.accountId);

    const out = await h.app.inject({ method: 'DELETE', url: '/v1/sessions', headers: a.auth });
    expect(out.statusCode).toBe(204);
    for (const p of [a, b]) {
      const res = await h.app.inject({ method: 'GET', url: '/v1/me/profile', headers: p.auth });
      expect(res.statusCode).toBe(401);
    }

    const c = await signIn(h, 'multi@example.test');
    h.clock.advance(16 * 60_000);
    const expired = await h.app.inject({ method: 'GET', url: '/v1/me/profile', headers: c.auth });
    expect(expired.statusCode).toBe(401);
  });

  it('recovery signs out existing sessions', async () => {
    const p = await signIn(h, 'recover@example.test');
    const v = verifier();
    const s = state();
    await request('recover@example.test', 'recovery', v, s);
    const res = await h.app.inject({
      method: 'POST',
      url: '/v1/auth/exchange',
      payload: { proof: h.outbox.at(-1)!.proof, code_verifier: v, state: s },
    });
    expect(res.statusCode).toBe(200);
    const old = await h.app.inject({ method: 'GET', url: '/v1/me/profile', headers: p.auth });
    expect(old.statusCode).toBe(401);
  });
});
