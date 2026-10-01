import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { staffRules } from '../src/routes/staff.js';
import { base32Decode, base32Encode, otpauthUri, stepAt, totpCode, verifyTotp } from '../src/totp.js';
import { type Harness, makeModerator, member, type Person, signIn, startHarness } from './harness.js';

describe('one-time codes (RFC 6238)', () => {
  // The RFC's SHA-1 test key, "12345678901234567890".
  const secret = base32Encode(Buffer.from('12345678901234567890'));

  it('matches the published test values', () => {
    expect(secret).toBe('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
    expect(base32Decode(secret).toString()).toBe('12345678901234567890');
    // The RFC lists eight digits; authenticator apps show the last six.
    expect(totpCode(secret, stepAt(new Date(59_000)))).toBe('287082');
    expect(totpCode(secret, stepAt(new Date(1_111_111_109_000)))).toBe('081804');
    expect(totpCode(secret, stepAt(new Date(2_000_000_000_000)))).toBe('279037');
  });

  it('allows one step of clock drift, and never the same step twice', () => {
    const now = new Date(1_111_111_109_000);
    const step = stepAt(now);
    const previous = totpCode(secret, step - 1);
    expect(verifyTotp(secret, previous, now, null)).toBe(step - 1);
    expect(verifyTotp(secret, totpCode(secret, step - 2), now, null)).toBeNull();
    expect(verifyTotp(secret, totpCode(secret, step), now, step)).toBeNull();
    expect(verifyTotp(secret, previous, now, step - 1)).toBeNull();
    expect(verifyTotp(secret, 'abcdef', now, null)).toBeNull();
  });

  it('gives authenticator apps a standard link', () => {
    expect(otpauthUri('ABC', 'moderator')).toBe(
      'otpauth://totp/Vawra%20Moderation%3Amoderator?secret=ABC&issuer=Vawra+Moderation&algorithm=SHA1&digits=6&period=30',
    );
  });
});

describe('moderator second factor', () => {
  let h: Harness;
  beforeEach(async () => (h = await startHarness()));
  afterEach(async () => h.close());

  const call = (p: Person, method: 'GET' | 'POST', url: string, payload?: object) =>
    h.app.inject({ method, url, headers: p.auth, ...(payload ? { payload } : {}) });
  const codeNow = (secret: string, offset = 0) => totpCode(secret, stepAt(h.clock.now()) + offset);
  const asModerator = async (name: string) => {
    const p = await member(h, name);
    await h.db.query("UPDATE accounts SET role = 'moderator' WHERE id = $1", [p.accountId]);
    return p;
  };

  it('every moderation route needs it; others still see nothing at all', async () => {
    const mo = await asModerator('Mo');
    const ana = await member(h, 'Ana');
    for (const url of ['/v1/mod/reports', '/v1/mod/appeals', '/v1/mod/photos']) {
      const res = await call(mo, 'GET', url);
      expect(res.statusCode).toBe(403);
      expect(res.json().error).toBe('second_factor_setup_required');
      expect((await call(ana, 'GET', url)).statusCode).toBe(404);
    }
    expect((await call(ana, 'GET', '/v1/mod/second-factor')).statusCode).toBe(404);
    expect((await call(ana, 'POST', '/v1/mod/second-factor/setup')).statusCode).toBe(404);
  });

  it('setup needs a recent sign-in and a working authenticator, then opens moderation', async () => {
    const mo = await asModerator('Mo');
    h.clock.advance(11 * 60_000);
    const fresh = await signIn(h, 'mo@example.test');
    // An old sign-in cannot start setup.
    expect((await call(mo, 'POST', '/v1/mod/second-factor/setup')).json().error).toBe('reauthentication_required');
    const setup = await call(fresh, 'POST', '/v1/mod/second-factor/setup');
    expect(setup.statusCode).toBe(200);
    const { secret, otpauth_uri } = setup.json();
    expect(otpauth_uri).toContain(`secret=${secret}`);
    // The secret is never stored in clear.
    expect(JSON.stringify(await h.db.query('SELECT * FROM moderator_second_factor'))).not.toContain(secret);
    expect((await call(fresh, 'POST', '/v1/mod/second-factor/confirm', { code: '000000' })).json().error).toBe(
      'invalid_code',
    );
    const confirmed = await call(fresh, 'POST', '/v1/mod/second-factor/confirm', { code: codeNow(secret) });
    expect(confirmed.json()).toMatchObject({ enabled: true });
    expect((await call(fresh, 'GET', '/v1/mod/reports')).statusCode).toBe(200);
    // Once on, it cannot be replaced from the app.
    expect((await call(fresh, 'POST', '/v1/mod/second-factor/setup')).json().error).toBe('already_enabled');
  });

  it('a verified sign-in lasts half an hour, through token refresh; then a new code is needed, once', async () => {
    const mo = await member(h, 'Mo');
    await makeModerator(h, mo);
    const [row] = await h.db.query<{ secret_sealed: string }>('SELECT secret_sealed FROM moderator_second_factor');
    const secret = h.sealer.open(row!.secret_sealed);
    expect((await call(mo, 'GET', '/v1/mod/reports')).statusCode).toBe(200);

    h.clock.advance((staffRules.verifiedMinutes + 1) * 60_000);
    const rotated = await h.app.inject({
      method: 'POST',
      url: '/v1/session/rotate',
      payload: { refresh_token: mo.refresh },
    });
    const again: Person = { ...mo, auth: { authorization: `Bearer ${rotated.json().access_token}` } };
    const blocked = await call(again, 'GET', '/v1/mod/reports');
    expect(blocked.statusCode).toBe(403);
    expect(blocked.json().error).toBe('second_factor_required');
    const code = codeNow(secret, 1);
    expect((await call(again, 'POST', '/v1/mod/second-factor/verify', { code })).statusCode).toBe(200);
    expect((await call(again, 'GET', '/v1/mod/reports')).statusCode).toBe(200);
    // The same code cannot be used again, on any sign-in.
    expect((await call(again, 'POST', '/v1/mod/second-factor/verify', { code })).json().error).toBe('invalid_code');
    const status = (await call(again, 'GET', '/v1/mod/second-factor')).json();
    expect(status.enabled).toBe(true);
    expect(status.verified_until).not.toBeNull();
  });

  it('a new sign-in starts unverified, and guessing is cut off after five tries', async () => {
    const mo = await member(h, 'Mo');
    await makeModerator(h, mo);
    const other = await signIn(h, 'mo@example.test');
    expect((await call(other, 'GET', '/v1/mod/reports')).json().error).toBe('second_factor_required');
    // Every try counts, the successful one at setup included: four more wrong ones, then a stop.
    for (let i = 1; i < staffRules.triesPer15Minutes; i++) {
      expect((await call(other, 'POST', '/v1/mod/second-factor/verify', { code: '000000' })).statusCode).toBe(400);
    }
    expect((await call(other, 'POST', '/v1/mod/second-factor/verify', { code: '000000' })).statusCode).toBe(429);
    const failures = await h.db.query("SELECT 1 FROM audit_events WHERE kind = 'mod_2fa_failed'");
    expect(failures).toHaveLength(staffRules.triesPer15Minutes - 1);
  });
});
