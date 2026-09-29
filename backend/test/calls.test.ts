import { createHmac } from 'node:crypto';
import { afterEach, describe, expect, it } from 'vitest';
import { callConfigFrom, callRules } from '../src/calls.js';
import { type Harness, member, type Person, startHarness, swipe } from './harness.js';

let h: Harness;
let open = false;
afterEach(async () => {
  if (open) await h.close();
  open = false;
});
const start = async (options?: Parameters<typeof startHarness>[0]) => {
  h = await startHarness(options);
  open = true;
};

const call = (p: Person, method: 'GET' | 'POST' | 'PUT' | 'DELETE', url: string, payload?: object) =>
  h.app.inject({ method, url, headers: p.auth, ...(payload ? { payload } : {}) });

async function matched() {
  const ana = await member(h, 'Ana');
  const ben = await member(h, 'Ben');
  await swipe(h, ana, ben);
  const matchId = (await swipe(h, ben, ana)).json().match_id as string;
  return { ana, ben, matchId };
}

/** Both people have said they are open to a call. */
async function ready() {
  const pair = await matched();
  for (const p of [pair.ana, pair.ben]) {
    expect((await call(p, 'PUT', `/v1/matches/${pair.matchId}/call-ready`, { ready: true })).statusCode).toBe(204);
  }
  return pair;
}

const ring = (from: Person, matchId: string, kind = 'video') =>
  call(from, 'POST', `/v1/matches/${matchId}/calls`, { kind });

const stateOf = async (p: Person, callId: string) => (await call(p, 'GET', `/v1/calls/${callId}`)).json().state;

describe('calls', () => {
  it('rings only when both people are open to a call', async () => {
    await start();
    const { ana, ben, matchId } = await matched();
    expect((await ring(ana, matchId)).json().error).toBe('not_ready');
    await call(ana, 'PUT', `/v1/matches/${matchId}/call-ready`, { ready: true });
    expect((await ring(ana, matchId)).json().error).toBe('not_ready');
    const list = (await call(ben, 'GET', '/v1/matches')).json();
    expect(list.calls_available).toBe(true);
    expect(list.matches[0]).toMatchObject({ call_ready_by_me: false, call_ready_by_them: true });
    await call(ben, 'PUT', `/v1/matches/${matchId}/call-ready`, { ready: true });
    const res = await ring(ana, matchId);
    expect(res.statusCode).toBe(200);
    expect(res.json()).toMatchObject({ state: 'ringing', role: 'caller', kind: 'video' });
  });

  it('is off without a relay, and the list says so', async () => {
    await start({ callConfig: null });
    const { ana, matchId } = await ready();
    expect((await ring(ana, matchId)).json().error).toBe('calls_unavailable');
    expect((await call(ana, 'GET', '/v1/matches')).json().calls_available).toBe(false);
  });

  it('answer, setup messages and hang-up; strangers see nothing', async () => {
    await start();
    const { ana, ben, matchId } = await ready();
    const cy = await member(h, 'Cy');
    const callId = (await ring(ana, matchId)).json().call_id as string;
    const seen: unknown[] = [];
    h.nudges.subscribe(ben.accountId, (n) => seen.push(n));

    // Only the callee answers; nobody else can see or touch the call.
    expect((await call(ana, 'POST', `/v1/calls/${callId}/answer`)).json().error).toBe('not_ringing');
    expect((await call(cy, 'GET', `/v1/calls/${callId}`)).statusCode).toBe(404);
    expect((await call(cy, 'POST', `/v1/calls/${callId}/signals`, { type: 'offer', data: 'x' })).statusCode).toBe(404);

    // The offer waits for Ben; the nudge carries no content.
    await call(ana, 'POST', `/v1/calls/${callId}/signals`, { type: 'offer', data: 'v=0 offer' });
    expect(seen).toEqual([{ kind: 'call', call_id: callId }]);
    const answered = await call(ben, 'POST', `/v1/calls/${callId}/answer`);
    expect(answered.json()).toMatchObject({ state: 'active', role: 'callee' });
    const inbox = (await call(ben, 'GET', `/v1/calls/${callId}/signals`)).json();
    expect(inbox.signals).toEqual([{ seq: expect.any(Number), type: 'offer', data: 'v=0 offer' }]);
    // Your own messages never come back to you.
    expect((await call(ana, 'GET', `/v1/calls/${callId}/signals`)).json().signals).toEqual([]);
    await call(ben, 'POST', `/v1/calls/${callId}/signals`, { type: 'answer', data: 'v=0 answer' });
    const after = inbox.signals[0].seq;
    expect((await call(ben, 'GET', `/v1/calls/${callId}/signals?after=${after}`)).json().signals).toEqual([]);
    expect((await call(ana, 'GET', `/v1/calls/${callId}/signals`)).json().signals[0].type).toBe('answer');

    expect((await call(ben, 'POST', `/v1/calls/${callId}/end`)).statusCode).toBe(204);
    expect(await stateOf(ana, callId)).toBe('ended');
    // Setup messages are gone with the call.
    expect((await call(ana, 'GET', `/v1/calls/${callId}/signals`)).json().signals).toEqual([]);
    expect((await call(ana, 'POST', `/v1/calls/${callId}/signals`, { type: 'candidate', data: 'c' })).json().error).toBe(
      'call_over',
    );
    // Only times and the outcome are kept.
    const [row] = await h.db.query<Record<string, unknown>>('SELECT * FROM calls WHERE id = $1', [callId]);
    expect(Object.keys(row!).sort()).toEqual(
      ['answered_at', 'callee', 'caller', 'created_at', 'end_reason', 'ended_at', 'id', 'kind', 'match_id', 'state'].sort(),
    );
  });

  it('decline, cancel and a ring that runs out', async () => {
    await start();
    const { ana, ben, matchId } = await ready();
    let id = (await ring(ana, matchId)).json().call_id;
    await call(ben, 'POST', `/v1/calls/${id}/decline`);
    expect(await stateOf(ana, id)).toBe('declined');

    id = (await ring(ana, matchId)).json().call_id;
    await call(ana, 'POST', `/v1/calls/${id}/end`);
    expect(await stateOf(ben, id)).toBe('cancelled');

    id = (await ring(ana, matchId)).json().call_id;
    h.clock.advance((callRules.ringSeconds + 1) * 1000);
    expect(await stateOf(ben, id)).toBe('missed');
    expect((await call(ben, 'POST', `/v1/calls/${id}/answer`)).json().error).toBe('not_ringing');
  });

  it('one call at a time, and at most ten an hour', async () => {
    await start();
    const { ana, ben, matchId } = await ready();
    const first = (await ring(ana, matchId)).json().call_id;
    expect((await ring(ben, matchId)).json().error).toBe('busy');
    await call(ana, 'POST', `/v1/calls/${first}/end`);
    for (let i = 1; i < callRules.callsPerHour; i++) {
      const id = (await ring(ana, matchId)).json().call_id;
      await call(ana, 'POST', `/v1/calls/${id}/end`);
    }
    expect((await ring(ana, matchId)).json().error).toBe('call_limit');
    // An hour on (moved in the data, so the test sign-ins stay fresh).
    await h.db.query("UPDATE calls SET created_at = created_at - interval '61 minutes'");
    expect((await ring(ana, matchId)).statusCode).toBe(200);
  });

  it('rejects bad setup messages and floods', async () => {
    await start();
    const { ana, matchId } = await ready();
    const id = (await ring(ana, matchId)).json().call_id;
    const post = (payload: object) => call(ana, 'POST', `/v1/calls/${id}/signals`, payload);
    expect((await post({ type: 'hangup', data: '' })).statusCode).toBe(400);
    expect((await post({ type: 'offer', data: 'x'.repeat(callRules.signalBytes + 1) })).statusCode).toBe(400);
    expect((await post({ type: 'offer', data: 'x', extra: 1 })).statusCode).toBe(400);
    for (let i = 0; i < callRules.signalsPerCall; i++) await post({ type: 'candidate', data: `c${i}` });
    expect((await post({ type: 'candidate', data: 'one more' })).json().error).toBe('slow_down');
  });

  for (const [how, act] of [
    ['a block', async (a: Person, b: Person) => call(b, 'POST', '/v1/blocks', { account_id: a.accountId })],
    ['an unmatch', async (a: Person, _b: Person, matchId: string) => call(a, 'DELETE', `/v1/matches/${matchId}`)],
    ['taking back readiness', async (_a: Person, b: Person, matchId: string) =>
      call(b, 'PUT', `/v1/matches/${matchId}/call-ready`, { ready: false })],
    ['asking to delete the account', async (a: Person) => call(a, 'POST', '/v1/me/deletion')],
  ] as const) {
    it(`${how} ends a live call at once`, async () => {
      await start();
      const { ana, ben, matchId } = await ready();
      const id = (await ring(ana, matchId)).json().call_id;
      await call(ben, 'POST', `/v1/calls/${id}/answer`);
      await call(ana, 'POST', `/v1/calls/${id}/signals`, { type: 'candidate', data: 'c' });
      const told: unknown[] = [];
      h.nudges.subscribe(ben.accountId, (n) => told.push(n));
      await act(ana, ben, matchId);
      const [row] = await h.db.query<{ state: string }>('SELECT state FROM calls WHERE id = $1', [id]);
      expect(row!.state).toBe('ended');
      expect(told).toContainEqual({ kind: 'call', call_id: id });
    });
  }

  it('a suspension ends the suspended person’s calls', async () => {
    await start();
    const { ana, ben, matchId } = await ready();
    const mod = await member(h, 'Mo');
    await h.db.query("UPDATE accounts SET role = 'moderator' WHERE id = $1", [mod.accountId]);
    const id = (await ring(ana, matchId)).json().call_id;
    await call(ben, 'POST', '/v1/reports', { account_id: ana.accountId, reason: 'harassment' });
    const [report] = await h.db.query<{ id: string }>('SELECT id FROM reports');
    const decided = await call(mod, 'POST', `/v1/mod/reports/${report!.id}/decision`, { outcome: 'suspended' });
    expect(decided.statusCode).toBe(200);
    // Read straight from the data: asking through Ben's app would end it anyway.
    const [row] = await h.db.query<{ state: string }>('SELECT state FROM calls WHERE id = $1', [id]);
    expect(row!.state).toBe('cancelled');
  });

  it('a block the call routes missed still ends the call on its next step', async () => {
    await start();
    const { ana, ben, matchId } = await ready();
    const id = (await ring(ana, matchId)).json().call_id;
    await call(ben, 'POST', `/v1/calls/${id}/answer`);
    // Written straight to the database, as if the block's own hook had failed.
    await h.db.query("UPDATE matches SET status = 'blocked' WHERE id = $1", [matchId]);
    expect((await call(ana, 'GET', `/v1/calls/${id}/signals`)).json().state).toBe('ended');
    expect((await call(ana, 'POST', `/v1/calls/${id}/signals`, { type: 'candidate', data: 'c' })).json().error).toBe(
      'call_over',
    );
  });

  it('relay credentials are per person, short-lived and signed', async () => {
    await start();
    const { ana, matchId } = await ready();
    const ice = (await ring(ana, matchId)).json().ice;
    expect(ice.policy).toBe('relay');
    const [turn] = ice.servers;
    const [expiry, who] = turn.username.split(':');
    expect(who).toBe(ana.accountId);
    expect(Number(expiry) * 1000 - h.clock.now().getTime()).toBe(2 * 60 * 60 * 1000);
    expect(turn.credential).toBe(createHmac('sha1', 'test-turn-secret').update(turn.username).digest('base64'));
  });
});

describe('call settings', () => {
  it('relay when TURN is set, direct only behind the development switch, else off', () => {
    expect(callConfigFrom({})).toBeNull();
    expect(callConfigFrom({ VAWRA_TURN_URLS: 'turn:a' })).toBeNull();
    expect(callConfigFrom({ VAWRA_TURN_URLS: 'turn:a, turns:b', VAWRA_TURN_SECRET: 's' })).toMatchObject({
      policy: 'relay',
      stun: [],
      turn: { urls: ['turn:a', 'turns:b'] },
    });
    expect(callConfigFrom({ VAWRA_CALLS_DEV_P2P: '1' })?.policy).toBe('all');
    // TURN wins over the development switch.
    expect(callConfigFrom({ VAWRA_CALLS_DEV_P2P: '1', VAWRA_TURN_URLS: 'turn:a', VAWRA_TURN_SECRET: 's' })?.policy).toBe(
      'relay',
    );
  });
});
