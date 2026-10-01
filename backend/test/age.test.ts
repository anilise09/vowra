import { afterEach, describe, expect, it } from 'vitest';
import { ageCheckProblems, ageCheckRules, signAgeWebhook } from '../src/routes/age.js';
import { type Harness, makeProfile, type Person, signIn, startHarness } from './harness.js';

const secret = 'a-shared-secret-of-at-least-32-characters!';
const ageCheck = { urlTemplate: 'https://checks.example.test/start?ref={reference}', webhookSecret: secret };

let h: Harness | undefined;
afterEach(async () => {
  await h?.close();
  h = undefined;
});

const call = (p: Person, method: 'GET' | 'POST', url: string, payload?: object) =>
  h!.app.inject({ method, url, headers: p.auth, ...(payload ? { payload } : {}) });

/** What a provider adapter would send: the exact body, signed with the time. */
function webhook(body: object, options: { secret?: string; at?: number; raw?: string } = {}) {
  const raw = options.raw ?? JSON.stringify(body);
  const at = options.at ?? Math.floor(h!.clock.now().getTime() / 1000);
  return h!.app.inject({
    method: 'POST',
    url: '/v1/webhooks/age-check',
    headers: { 'content-type': 'application/json', 'vawra-signature': signAgeWebhook(options.secret ?? secret, at, raw) },
    payload: raw,
  });
}

async function started(name = 'Ana') {
  const p = await signIn(h!, `${name.toLowerCase()}@example.test`);
  await makeProfile(h!, p, name);
  const res = await call(p, 'POST', '/v1/me/age-check');
  expect(res.statusCode).toBe(200);
  const reference = decodeURIComponent(new URL(res.json().url).searchParams.get('ref')!);
  return { p, reference };
}

const state = async (p: Person) => (await call(p, 'GET', '/v1/me/profile')).json();

describe('age checks', () => {
  it('a passed check opens dating and sets the age shown on the profile', async () => {
    h = await startHarness({ ageCheck });
    const { p, reference } = await started();
    expect((await state(p)).age_state).toBe('assurance_required');
    expect((await webhook({ reference, outcome: 'passed', age: 29 })).statusCode).toBe(200);
    const me = await state(p);
    expect(me.age_state).toBe('adult_verified');
    expect(me.profile.public_age).toBe(29);
    // Only the outcome and age are kept: no documents, no date of birth, and the reference hashed.
    const [row] = await h.db.query<Record<string, unknown>>('SELECT * FROM age_checks');
    expect(Object.keys(row!).sort()).toEqual(
      ['account_id', 'created_at', 'decided_at', 'id', 'reference_hash', 'status', 'verified_age'].sort(),
    );
    expect(JSON.stringify(row)).not.toContain(reference);
    expect((await call(p, 'POST', '/v1/me/age-check')).json().error).toBe('already_verified');
  });

  it('refuses anything not signed with the secret, or signed too long ago', async () => {
    h = await startHarness({ ageCheck });
    const { p, reference } = await started();
    const body = { reference, outcome: 'passed', age: 29 };
    expect((await webhook(body, { secret: 'not-the-secret-not-the-secret-not-the' })).json().error).toBe('bad_signature');
    const old = Math.floor(h.clock.now().getTime() / 1000) - ageCheckRules.signatureToleranceSeconds - 1;
    expect((await webhook(body, { at: old })).json().error).toBe('stale_signature');
    // A changed body breaks the signature.
    const signed = signAgeWebhook(secret, Math.floor(h.clock.now().getTime() / 1000), JSON.stringify(body));
    const tampered = await h.app.inject({
      method: 'POST',
      url: '/v1/webhooks/age-check',
      headers: { 'content-type': 'application/json', 'vawra-signature': signed },
      payload: JSON.stringify({ ...body, age: 45 }),
    });
    expect(tampered.json().error).toBe('bad_signature');
    expect((await state(p)).age_state).toBe('assurance_required');
  });

  it('under 18 fails, a pass without an age goes to review, and a decided check stays decided', async () => {
    h = await startHarness({ ageCheck });
    const young = await started('Kid');
    await webhook({ reference: young.reference, outcome: 'passed', age: 16 });
    expect((await state(young.p)).age_state).toBe('rejected');
    // A later "pass" for the same check changes nothing.
    await webhook({ reference: young.reference, outcome: 'passed', age: 30 });
    expect((await state(young.p)).age_state).toBe('rejected');
    expect((await call(young.p, 'POST', '/v1/me/age-check')).json().error).toBe('age_check_failed');

    const unsure = await started('Sam');
    await webhook({ reference: unsure.reference, outcome: 'passed' });
    expect((await state(unsure.p)).age_state).toBe('pending_review');
    // Review can still end in a pass.
    await webhook({ reference: unsure.reference, outcome: 'passed', age: 33 });
    expect((await state(unsure.p)).age_state).toBe('adult_verified');
  });

  it('an unknown reference is not found; starts are limited; without a provider it is unavailable', async () => {
    h = await startHarness({ ageCheck });
    expect((await webhook({ reference: 'x'.repeat(43), outcome: 'passed', age: 30 })).statusCode).toBe(404);
    const p = await signIn(h, 'many@example.test');
    for (let i = 0; i < ageCheckRules.startsPerDay; i++) {
      expect((await call(p, 'POST', '/v1/me/age-check')).statusCode).toBe(200);
    }
    expect((await call(p, 'POST', '/v1/me/age-check')).json().error).toBe('slow_down');
    await h.close();
    h = await startHarness();
    const q = await signIn(h, 'none@example.test');
    expect((await call(q, 'POST', '/v1/me/age-check')).json().error).toBe('age_check_unavailable');
  });

  it('a check that finishes before the profile exists still sets its age', async () => {
    h = await startHarness({ ageCheck });
    const p = await signIn(h, 'early@example.test');
    const res = await call(p, 'POST', '/v1/me/age-check');
    const reference = decodeURIComponent(new URL(res.json().url).searchParams.get('ref')!);
    await webhook({ reference, outcome: 'passed', age: 41 });
    await makeProfile(h, p, 'Early');
    expect((await state(p)).profile.public_age).toBe(41);
  });

  it('settings come together and are refused when weak', () => {
    expect(ageCheckProblems({}, true)).toEqual([]);
    expect(ageCheckProblems({ VAWRA_AGE_CHECK_URL: 'https://x/{reference}' }, false).join()).toMatch(/need both/);
    expect(ageCheckProblems({ VAWRA_AGE_CHECK_URL: 'https://x/start', VAWRA_AGE_WEBHOOK_SECRET: secret }, false).join()).toMatch(
      /must contain \{reference\}/,
    );
    expect(ageCheckProblems({ VAWRA_AGE_CHECK_URL: 'http://x/{reference}', VAWRA_AGE_WEBHOOK_SECRET: secret }, true).join()).toMatch(
      /https/,
    );
    expect(ageCheckProblems({ VAWRA_AGE_CHECK_URL: 'https://x/{reference}', VAWRA_AGE_WEBHOOK_SECRET: 'short' }, false).join()).toMatch(
      /at least 32/,
    );
  });
});
