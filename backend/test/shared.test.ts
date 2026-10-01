import { afterEach, describe, expect, it } from 'vitest';
import type { Nudge } from '../src/nudges.js';
import type { PushMessage, PushSender } from '../src/push.js';
import { runRetention } from '../src/jobs/retention.js';
import { type Harness, member, type Person, startHarness, swipe } from './harness.js';

/**
 * Two servers on one database, as production runs behind a load balancer:
 * whatever reaches one must reach people connected to the other.
 */
let one: Harness | undefined;
let two: Harness | undefined;
afterEach(async () => {
  await two?.close();
  await one?.close();
  one = two = undefined;
});

class Recorder implements PushSender {
  sent: PushMessage[] = [];
  async send(_token: string, message: PushMessage) {
    this.sent.push(message);
    return 'sent' as const;
  }
}

async function twoServers(push?: Recorder) {
  one = await startHarness({ shared: true, ...(push ? { push: { android: push } } : {}) });
  two = await startHarness({ join: one, ...(push ? { push: { android: push } } : {}) });
  return { one, two };
}

const call = (h: Harness, p: Person, method: 'GET' | 'POST' | 'PUT', url: string, payload?: object) =>
  h.app.inject({ method, url, headers: p.auth, ...(payload ? { payload } : {}) });

/** NOTIFY is delivered asynchronously; wait for it, briefly. */
async function eventually(check: () => boolean, ms = 3000) {
  const until = Date.now() + ms;
  while (!check()) {
    if (Date.now() > until) throw new Error('timed out');
    await new Promise((r) => setTimeout(r, 10));
  }
}

async function matched(h: Harness) {
  const ana = await member(h, 'Ana');
  const ben = await member(h, 'Ben');
  await swipe(h, ana, ben);
  const matchId = (await swipe(h, ben, ana)).json().match_id as string;
  return { ana, ben, matchId };
}

describe('two servers, one database', () => {
  it('a message sent through one server nudges someone connected to the other', async () => {
    const { one, two } = await twoServers();
    const { ana, ben, matchId } = await matched(one);
    const onOne: Nudge[] = [];
    one.nudges.subscribe(ben.accountId, (n) => onOne.push(n));
    // Ana's request lands on the second server.
    expect((await call(two, ana, 'POST', `/v1/matches/${matchId}/messages`, { text: 'Hi!' })).statusCode).toBe(201);
    await eventually(() => onOne.some((n) => n.kind === 'message'));
    expect(onOne.filter((n) => n.kind === 'message')).toEqual([{ kind: 'message', match_id: matchId }]);
  });

  it('no push for someone whose app is open on the other server', async () => {
    const push = new Recorder();
    const { one, two } = await twoServers(push);
    const { ana, ben, matchId } = await matched(one);
    await call(one, ben, 'POST', '/v1/me/devices', { platform: 'android', token: 'fcm:' + 'b'.repeat(150) });
    const stream = await one.presence.track(ben.accountId);
    expect(await two.presence.connected(ben.accountId)).toBe(true);
    await call(two, ana, 'POST', `/v1/matches/${matchId}/messages`, { text: 'Hi!' });
    await two.notifier.idle();
    expect(push.sent).toHaveLength(0);
    // Once the app closes, the same event pushes.
    await stream.end();
    expect(await two.presence.connected(ben.accountId)).toBe(false);
    one.clock.advance(61_000);
    await call(two, ana, 'POST', `/v1/matches/${matchId}/messages`, { text: 'Still there?' });
    await two.notifier.idle();
    expect(push.sent.map((m) => m.event)).toEqual(['message']);
  });

  it('a call rung on one server is answered and set up through the other, and cleared after', async () => {
    const { one, two } = await twoServers();
    const { ana, ben, matchId } = await matched(one);
    for (const p of [ana, ben]) await call(one, p, 'PUT', `/v1/matches/${matchId}/call-ready`, { ready: true });
    const callId = (await call(one, ana, 'POST', `/v1/matches/${matchId}/calls`, { kind: 'audio' })).json().call_id;
    expect((await call(two, ben, 'POST', `/v1/calls/${callId}/answer`)).json().state).toBe('active');
    await call(one, ana, 'POST', `/v1/calls/${callId}/signals`, { type: 'offer', data: 'v=0 offer' });
    const inbox = (await call(two, ben, 'GET', `/v1/calls/${callId}/signals`)).json();
    expect(inbox.signals).toEqual([{ seq: expect.any(Number), type: 'offer', data: 'v=0 offer' }]);
    // Nobody reads their own; the setup is gone when the call ends.
    expect((await call(one, ana, 'GET', `/v1/calls/${callId}/signals`)).json().signals).toEqual([]);
    await call(two, ben, 'POST', `/v1/calls/${callId}/end`);
    expect(await one.db.query('SELECT 1 FROM call_signals')).toHaveLength(0);
  });

  it('the hourly job clears what a stopped server left behind', async () => {
    const { one } = await twoServers();
    const { ana, ben, matchId } = await matched(one);
    await one.db.query(
      `INSERT INTO stream_presence (stream_id, account_id, instance_id, seen_at)
       VALUES ($1, $2, 'gone', now() - interval '1 hour')`,
      [crypto.randomUUID(), ana.accountId],
    );
    for (const p of [ana, ben]) await call(one, p, 'PUT', `/v1/matches/${matchId}/call-ready`, { ready: true });
    const callId = (await call(one, ana, 'POST', `/v1/matches/${matchId}/calls`, { kind: 'audio' })).json().call_id;
    await call(one, ana, 'POST', `/v1/calls/${callId}/signals`, { type: 'offer', data: 'x' });
    // The call ended without its setup being cleared (a server stopped mid-way).
    await one.db.query("UPDATE calls SET state = 'ended' WHERE id = $1", [callId]);
    const removed = await runRetention(one.db, one.clock);
    expect(removed).toMatchObject({ stalePresence: 1, endedCallSignals: 1 });
  });
});

describe('the real live-update route', () => {
  it('records an open app for every server, and forgets it when the app closes', async () => {
    const { randomBytes } = await import('node:crypto');
    const { mkdtempSync, rmSync } = await import('node:fs');
    const { tmpdir } = await import('node:os');
    const { join } = await import('node:path');
    const { loadConfig } = await import('../src/config.js');
    const { startServer } = await import('../src/start.js');
    const env = { VAWRA_DATA_KEY: randomBytes(32).toString('base64'), VAWRA_LOOKUP_KEY: randomBytes(32).toString('base64') };
    const dir = mkdtempSync(join(tmpdir(), 'vawra-shared-'));
    const outbox: { email: string; proof: string; purpose: string }[] = [];
    const running = await startServer({ ...loadConfig(env), port: 0, dataDir: undefined, mediaDir: join(dir, 'm') }, env, {
      logger: false,
      sharedState: true,
      delivery: { sendProof: async (email, proof, purpose) => void outbox.push({ email, proof, purpose }) },
    });
    try {
      const ana = await member({ app: running.app, db: running.db, outbox } as never, 'Ana');
      const rows = () => running.db.query('SELECT 1 FROM stream_presence WHERE account_id = $1', [ana.accountId]);
      const controller = new AbortController();
      const stream = await fetch(`http://127.0.0.1:${running.port}/v1/events`, { headers: ana.auth, signal: controller.signal });
      const reader = stream.body!.getReader();
      await reader.read();
      expect(await rows()).toHaveLength(1);
      controller.abort();
      const until = Date.now() + 3000;
      while ((await rows()).length > 0 && Date.now() < until) await new Promise((r) => setTimeout(r, 20));
      expect(await rows()).toHaveLength(0);
    } finally {
      await running.close();
      rmSync(dir, { recursive: true, force: true });
    }
  });
});
