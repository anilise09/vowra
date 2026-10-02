import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { pkceChallenge } from '../src/crypto.js';
import { initiationMessage, signInCodeRules } from '../src/routes/auth.js';
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

  it('sign-in and recovery share one budget per address: 5 a quarter hour, 10 a day', async () => {
    await signIn(h, 'busy@example.test');
    const sent = () => h.outbox.filter((m) => m.email === 'busy@example.test').length;
    const before = sent();
    for (const purpose of ['recovery', 'sign_in', 'recovery', 'sign_in', 'recovery', 'sign_in']) {
      await request('busy@example.test', purpose);
    }
    // signIn above used one of the five.
    expect(sent() - before).toBe(4);
    for (let quarter = 0; quarter < 3; quarter++) {
      h.clock.advance(15 * 60_000);
      for (let i = 0; i < 5; i++) await request('busy@example.test');
    }
    expect(sent()).toBe(signInCodeRules.requestsPerDay);
    // A new day, new codes.
    h.clock.advance(24 * 60 * 60_000);
    await request('busy@example.test');
    expect(sent()).toBe(signInCodeRules.requestsPerDay + 1);
  });

  it('answers without waiting for the email, and does the same work for unknown recovery', async () => {
    let release!: () => void;
    const held = new Promise<void>((resolve) => (release = resolve));
    let hold = false;
    const slow = await startHarness({ beforeDelivery: () => (hold ? held : Promise.resolve()) });
    try {
      await signIn(slow, 'known@example.test');
      hold = true;
      const ask = (identifier: string, purpose: string) =>
        slow.app.inject({
          method: 'POST',
          url: '/v1/auth/requests',
          payload: { identifier, purpose, code_challenge: pkceChallenge(verifier()), state: state() },
        });
      const answered = await Promise.race([
        Promise.all([ask('known@example.test', 'recovery'), ask('nobody@example.test', 'recovery')]),
        new Promise<null>((resolve) => setTimeout(() => resolve(null), 2000)),
      ]);
      expect(answered?.map((r) => r.statusCode)).toEqual([202, 202]);
      // Both stored a request: the same database work whether or not the account exists.
      const rows = await slow.db.query<{ n: number }>(
        "SELECT count(*)::int AS n FROM auth_requests WHERE purpose = 'recovery'",
      );
      expect(rows[0]!.n).toBe(2);
    } finally {
      release();
      await slow.close();
    }
    // Once released, the known address got its recovery code; the unknown one got nothing.
    expect(slow.outbox.filter((m) => m.email === 'known@example.test' && m.purpose === 'recovery')).toHaveLength(1);
    expect(slow.outbox.filter((m) => m.email === 'nobody@example.test')).toHaveLength(0);
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

    expect(proof).toMatch(/^\d{6}$/);
    // The right code is useless without this device's verifier or state.
    expect((await exchange({ proof, code_verifier: verifier(), state: s })).statusCode).toBe(400);
    expect((await exchange({ proof, code_verifier: v, state: state() })).statusCode).toBe(400);
    // A typo is forgiven: the right code and verifier still work, once.
    const wrong = proof === '000000' ? '000001' : '000000';
    expect((await exchange({ proof: wrong, code_verifier: v, state: s })).statusCode).toBe(400);
    expect((await exchange({ proof, code_verifier: v, state: s })).statusCode).toBe(200);
    expect((await exchange({ proof, code_verifier: v, state: s })).statusCode).toBe(400);
  });

  it('spends a code after five wrong tries, and never stores it in clear', async () => {
    const v = verifier();
    const s = state();
    await request('guess@example.test', 'sign_in', v, s);
    const proof = h.outbox.at(-1)!.proof;
    const [row] = await h.db.query<{ proof_hash: string }>(
      'SELECT proof_hash FROM auth_requests ORDER BY expires_at DESC LIMIT 1',
    );
    expect(row!.proof_hash).not.toContain(proof);
    const exchange = (code: string) =>
      h.app.inject({ method: 'POST', url: '/v1/auth/exchange', payload: { proof: code, code_verifier: v, state: s } });
    let tries = 0;
    for (let n = 0; tries < 5; n++) {
      const guess = String(n).padStart(6, '0');
      if (guess === proof) continue;
      expect((await exchange(guess)).statusCode).toBe(400);
      tries++;
    }
    // The fifth wrong try spent it: even the right code no longer works.
    expect((await exchange(proof)).statusCode).toBe(400);
    // Only six digits are accepted at all.
    expect((await exchange('12345')).json().error).toBe('invalid_request');
  });

  it('ten wrong codes in a day pause sign-in for that address, even with the right code', async () => {
    const exchange = (code: string, v: string, s: string) =>
      h.app.inject({ method: 'POST', url: '/v1/auth/exchange', payload: { proof: code, code_verifier: v, state: s } });
    const fresh = async (email: string) => {
      const [v, s] = [verifier(), state()];
      await request(email, 'sign_in', v, s);
      return { v, s, proof: h.outbox.at(-1)!.proof };
    };
    const wrongFor = (proof: string, n: number) => String((Number(proof) + 1 + n) % 1_000_000).padStart(6, '0');
    let wrong = 0;
    while (wrong < signInCodeRules.wrongCodesPerDay) {
      const r = await fresh('target@example.test');
      for (let i = 0; i < signInCodeRules.attempts && wrong < signInCodeRules.wrongCodesPerDay; i++, wrong++) {
        expect((await exchange(wrongFor(r.proof, i), r.v, r.s)).statusCode).toBe(400);
      }
    }
    const right = await fresh('target@example.test');
    const paused = await exchange(right.proof, right.v, right.s);
    expect(paused.statusCode).toBe(429);
    expect(paused.json().error).toBe('sign_in_paused');
    // The request is spent too.
    expect((await exchange(right.proof, right.v, right.s)).statusCode).toBe(400);
    // Other addresses are not affected.
    const other = await fresh('bystander@example.test');
    expect((await exchange(other.proof, other.v, other.s)).statusCode).toBe(200);
    // The next day the right code works again.
    h.clock.advance(24 * 60 * 60_000);
    const later = await fresh('target@example.test');
    expect((await exchange(later.proof, later.v, later.s)).statusCode).toBe(200);
  });

  it('a code from one request never opens another', async () => {
    const [v1, s1, v2, s2] = [verifier(), state(), verifier(), state()];
    await request('one@example.test', 'sign_in', v1, s1);
    const first = h.outbox.at(-1)!.proof;
    await request('two@example.test', 'sign_in', v2, s2);
    const second = h.outbox.at(-1)!.proof;
    if (first !== second) {
      const res = await h.app.inject({
        method: 'POST',
        url: '/v1/auth/exchange',
        payload: { proof: first, code_verifier: v2, state: s2 },
      });
      expect(res.statusCode).toBe(400);
    }
    const ok = await h.app.inject({
      method: 'POST',
      url: '/v1/auth/exchange',
      payload: { proof: second, code_verifier: v2, state: s2 },
    });
    expect(ok.statusCode).toBe(200);
  });

  it('answers the same when the email cannot be sent', async () => {
    const failing = await startHarness({ failDelivery: true });
    try {
      const res = await failing.app.inject({
        method: 'POST',
        url: '/v1/auth/requests',
        payload: { identifier: 'down@example.test', purpose: 'sign_in', code_challenge: pkceChallenge(verifier()), state: state() },
      });
      expect(res.statusCode).toBe(202);
      expect(res.json()).toEqual(initiationMessage);
    } finally {
      await failing.close();
    }
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
