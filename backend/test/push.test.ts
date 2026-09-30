import { createVerify, generateKeyPairSync, type KeyObject } from 'node:crypto';
import { createServer as createHttpServer, type Server } from 'node:http';
import { createServer as createHttp2Server, type Http2Server, type ServerHttp2Stream } from 'node:http2';
import type { AddressInfo } from 'node:net';
import { afterEach, describe, expect, it } from 'vitest';
import {
  ApnsSender,
  FcmSender,
  type PushMessage,
  type PushResult,
  type PushSender,
  pushMessage,
  pushProblems,
} from '../src/push.js';
import { type Harness, member, type Person, startHarness, swipe } from './harness.js';

/** Records what would have been pushed; can pretend a token went stale. */
class FakeSender implements PushSender {
  sent: { token: string; message: PushMessage }[] = [];
  result: PushResult = 'sent';
  async send(token: string, message: PushMessage) {
    this.sent.push({ token, message });
    return this.result;
  }
}

const androidToken = 'fcm:APA91b' + 'x'.repeat(140);
const iosToken = 'a'.repeat(64);

let h: Harness | undefined;
afterEach(async () => {
  await h?.close();
  h = undefined;
});

async function setup() {
  const android = new FakeSender();
  const ios = new FakeSender();
  h = await startHarness({ push: { android, ios } });
  return { h, android, ios };
}

const call = (h: Harness, p: Person, method: 'GET' | 'POST' | 'PUT' | 'DELETE', url: string, payload?: object) =>
  h.app.inject({ method, url, headers: p.auth, ...(payload ? { payload } : {}) });

const register = (h: Harness, p: Person, platform: 'android' | 'ios', token: string) =>
  call(h, p, 'POST', '/v1/me/devices', { platform, token });

/** Waits for pushes already started by a request. */
const settled = (h: Harness) => h.notifier.idle();

describe('devices and settings', () => {
  it('registers a phone with its token sealed, and refuses junk', async () => {
    const { h } = await setup();
    const ana = await member(h, 'Ana');
    expect((await register(h, ana, 'android', androidToken)).statusCode).toBe(200);
    expect((await register(h, ana, 'android', 'short')).statusCode).toBe(400);
    expect((await register(h, ana, 'android', 'x'.repeat(40) + ' <script>')).statusCode).toBe(400);
    const rows = await h.db.query<Record<string, string>>('SELECT * FROM devices');
    expect(rows).toHaveLength(1);
    expect(JSON.stringify(rows)).not.toContain('APA91b');
  });

  it('one device per sign-in, and the same token moves to whoever registered it last', async () => {
    const { h } = await setup();
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    await register(h, ana, 'android', androidToken);
    await register(h, ana, 'android', androidToken.replace('x', 'y'));
    expect(await h.db.query('SELECT 1 FROM devices')).toHaveLength(1);
    await register(h, ben, 'android', androidToken.replace('x', 'y'));
    const owners = await h.db.query<{ account_id: string }>('SELECT account_id FROM devices');
    expect(owners.map((o) => o.account_id)).toEqual([ben.accountId]);
  });

  it('settings default to everything on and change one at a time', async () => {
    const { h } = await setup();
    const ana = await member(h, 'Ana');
    expect((await call(h, ana, 'GET', '/v1/me/notifications')).json()).toEqual({
      matches: true,
      messages: true,
      likes: true,
      calls: true,
    });
    const changed = await call(h, ana, 'PUT', '/v1/me/notifications', { likes: false });
    expect(changed.json()).toEqual({ matches: true, messages: true, likes: false, calls: true });
    expect((await call(h, ana, 'PUT', '/v1/me/notifications', {})).statusCode).toBe(400);
    expect((await call(h, ana, 'PUT', '/v1/me/notifications', { sms: true })).statusCode).toBe(400);
  });
});

describe('when a push goes out', () => {
  it('a like and a match reach the other person only, with no names', async () => {
    const { h, android } = await setup();
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    await register(h, ana, 'android', androidToken);
    await register(h, ben, 'android', androidToken.replace('x', 'b'));
    await swipe(h, ana, ben);
    await settled(h);
    expect(android.sent.map((s) => [s.token === androidToken ? 'ana' : 'ben', s.message.event])).toEqual([['ben', 'like']]);
    await swipe(h, ben, ana);
    await settled(h);
    // The match goes to Ana; Ben made it and is in the app.
    expect(android.sent.at(-1)!.token).toBe(androidToken);
    expect(android.sent.at(-1)!.message).toMatchObject({ event: 'match', body: 'You have a new match' });
    expect(JSON.stringify(android.sent)).not.toMatch(/Ana|Ben/);
  });

  it('a message says only that there is one, at most once a minute per chat', async () => {
    const { h, ios } = await setup();
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    await swipe(h, ana, ben);
    const matchId = (await swipe(h, ben, ana)).json().match_id as string;
    await register(h, ben, 'ios', iosToken);
    const say = (text: string) => call(h, ana, 'POST', `/v1/matches/${matchId}/messages`, { text });
    await say('Secret plans for Saturday');
    await say('Also, bring snacks');
    await settled(h);
    const messages = ios.sent.filter((s) => s.message.event === 'message');
    expect(messages).toHaveLength(1);
    expect(messages[0]!.message.body).toBe('You have a new message');
    expect(JSON.stringify(messages)).not.toContain('Saturday');
    h.clock.advance(61_000);
    await say('Still there?');
    await settled(h);
    expect(ios.sent.filter((s) => s.message.event === 'message')).toHaveLength(2);
  });

  it('no push while the app is open and connected', async () => {
    const { h, android } = await setup();
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    await register(h, ben, 'android', androidToken);
    const unsubscribe = h.nudges.subscribe(ben.accountId, () => {});
    await swipe(h, ana, ben);
    await settled(h);
    expect(android.sent).toHaveLength(0);
    unsubscribe();
  });

  it('respects what the person turned off', async () => {
    const { h, android } = await setup();
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    await register(h, ben, 'android', androidToken);
    await call(h, ben, 'PUT', '/v1/me/notifications', { likes: false });
    await swipe(h, ana, ben);
    await settled(h);
    expect(android.sent).toHaveLength(0);
  });

  it('a call is a silent high-priority wake-up that expires with the ring', async () => {
    const { h, android } = await setup();
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    await swipe(h, ana, ben);
    const matchId = (await swipe(h, ben, ana)).json().match_id as string;
    for (const p of [ana, ben]) await call(h, p, 'PUT', `/v1/matches/${matchId}/call-ready`, { ready: true });
    await register(h, ben, 'android', androidToken);
    const callId = (await call(h, ana, 'POST', `/v1/matches/${matchId}/calls`, { kind: 'video' })).json().call_id;
    await settled(h);
    const push = android.sent.find((s) => s.message.event === 'call')!;
    expect(push.message).toEqual({
      event: 'call',
      title: '',
      body: '',
      data: { type: 'call', call_id: callId, match_id: matchId },
      ttlSeconds: 45,
    });
  });

  it('signing out, suspension and a stale token each stop pushes', async () => {
    const { h, android } = await setup();
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    const cy = await member(h, 'Cy');
    await register(h, ben, 'android', androidToken);
    await call(h, ben, 'DELETE', '/v1/session');
    await swipe(h, ana, ben);
    await settled(h);
    expect(android.sent).toHaveLength(0);

    // A stale token is deleted the first time the push service says so.
    await register(h, cy, 'android', androidToken.replace('x', 'c'));
    android.result = 'invalid_token';
    await swipe(h, ana, cy);
    await settled(h);
    expect(android.sent).toHaveLength(1);
    expect(await h.db.query('SELECT 1 FROM devices WHERE account_id = $1', [cy.accountId])).toHaveLength(0);

    // Suspended people get nothing.
    android.result = 'sent';
    const dee = await member(h, 'Dee');
    await register(h, dee, 'android', androidToken.replace('x', 'd'));
    await h.db.query("UPDATE accounts SET lifecycle = 'suspended' WHERE id = $1", [dee.accountId]);
    // Straight to the notifier: the routes already refuse to reach a suspended person.
    h.notifier.notify(dee.accountId, 'message', { match_id: 'm' });
    await settled(h);
    expect(android.sent).toHaveLength(1);
  });

  it('the data download lists calls, settings and devices, never the token', async () => {
    const { h } = await setup();
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    await swipe(h, ana, ben);
    const matchId = (await swipe(h, ben, ana)).json().match_id as string;
    for (const p of [ana, ben]) await call(h, p, 'PUT', `/v1/matches/${matchId}/call-ready`, { ready: true });
    const callId = (await call(h, ana, 'POST', `/v1/matches/${matchId}/calls`, { kind: 'audio' })).json().call_id;
    await call(h, ana, 'POST', `/v1/calls/${callId}/end`);
    await register(h, ana, 'android', androidToken);
    await call(h, ana, 'PUT', '/v1/me/notifications', { messages: false });
    const exported = (await call(h, ana, 'GET', '/v1/me/export')).json();
    expect(exported.calls).toEqual([
      expect.objectContaining({ kind: 'audio', you_were: 'caller', with: 'Ben', outcome: 'cancelled' }),
    ]);
    expect(exported.notifications).toMatchObject({ messages: false, matches: true });
    expect(exported.push_devices).toEqual([expect.objectContaining({ platform: 'android' })]);
    expect(JSON.stringify(exported)).not.toContain('APA91b');
  });
});

describe('the push services', () => {
  const rsa = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const ec = generateKeyPairSync('ec', { namedCurve: 'P-256' });
  const pem = (key: KeyObject) => key.export({ type: 'pkcs8', format: 'pem' }).toString();
  let server: Server | Http2Server | undefined;
  afterEach(async () => {
    await new Promise<void>((resolve) => (server ? server.close(() => resolve()) : resolve()));
    server = undefined;
  });

  const verifyJwt = (token: string, key: KeyObject, ieee: boolean) => {
    const [header, claims, signature] = token.split('.');
    const verifier = createVerify('SHA256');
    verifier.update(`${header}.${claims}`);
    const ok = verifier.verify(
      ieee ? { key, dsaEncoding: 'ieee-p1363' } : key,
      Buffer.from(signature!, 'base64url'),
    );
    return { ok, claims: JSON.parse(Buffer.from(claims!, 'base64url').toString()) };
  };

  it('Firebase: a signed service-account sign-in, then the message; a dead token is reported', async () => {
    const seen: { path: string; body: string; auth?: string }[] = [];
    let status = 200;
    server = createHttpServer((req, res) => {
      let body = '';
      req.on('data', (c) => (body += c));
      req.on('end', () => {
        seen.push({ path: req.url!, body, auth: req.headers.authorization });
        if (req.url === '/token') {
          res.setHeader('content-type', 'application/json');
          res.end(JSON.stringify({ access_token: 'google-token', expires_in: 3600 }));
        } else {
          res.statusCode = status;
          res.end(status === 404 ? '{"error":{"status":"NOT_FOUND","details":[{"errorCode":"UNREGISTERED"}]}}' : '{}');
        }
      });
    });
    await new Promise<void>((resolve) => server!.listen(0, '127.0.0.1', () => resolve()));
    const origin = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
    const sender = new FcmSender(
      { project_id: 'vawra-test', client_email: 'push@vawra-test.iam', private_key: pem(rsa.privateKey) },
      { oauth: `${origin}/token`, send: `${origin}/send` },
    );
    expect(await sender.send(androidToken, pushMessage('message', { match_id: 'm1' }))).toBe('sent');
    expect(await sender.send(androidToken, pushMessage('call', { call_id: 'c1' }))).toBe('sent');
    // One sign-in for both messages.
    expect(seen.filter((s) => s.path === '/token')).toHaveLength(1);
    const assertion = new URLSearchParams(seen[0]!.body).get('assertion')!;
    const jwt = verifyJwt(assertion, rsa.publicKey, false);
    expect(jwt.ok).toBe(true);
    expect(jwt.claims).toMatchObject({ iss: 'push@vawra-test.iam', scope: expect.stringContaining('firebase.messaging') });
    const sends = seen.filter((s) => s.path === '/send');
    expect(sends[0]!.auth).toBe('Bearer google-token');
    const message = JSON.parse(sends[0]!.body).message;
    expect(message).toMatchObject({
      token: androidToken,
      notification: { title: 'Vawra', body: 'You have a new message' },
      data: { type: 'message', match_id: 'm1' },
    });
    const ring = JSON.parse(sends[1]!.body).message;
    expect(ring.notification).toBeUndefined();
    expect(ring.android).toMatchObject({ priority: 'HIGH', ttl: '45s' });
    status = 404;
    expect(await sender.send(androidToken, pushMessage('like', {}))).toBe('invalid_token');
    status = 503;
    expect(await sender.send(androidToken, pushMessage('like', {}))).toBe('failed');
  });

  it('Apple: a signed token, the right topic and priority; a dead token is reported', async () => {
    const seen: { headers: Record<string, unknown>; body: string }[] = [];
    let status = 200;
    server = createHttp2Server();
    (server as Http2Server).on('stream', (stream: ServerHttp2Stream, headers) => {
      let body = '';
      stream.on('data', (c) => (body += c));
      stream.on('end', () => {
        seen.push({ headers: { ...headers }, body });
        stream.respond({ ':status': status });
        stream.end(status === 410 ? '{"reason":"Unregistered"}' : '');
      });
    });
    await new Promise<void>((resolve) => server!.listen(0, '127.0.0.1', () => resolve()));
    const origin = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
    const sender = new ApnsSender(
      { keyId: 'KEY123', teamId: 'TEAM456', key: pem(ec.privateKey), topic: 'com.vawra.app', production: false },
      origin,
    );
    expect(await sender.send(iosToken, pushMessage('match', { match_id: 'm1' }))).toBe('sent');
    expect(await sender.send(iosToken, pushMessage('call', { call_id: 'c1' }))).toBe('sent');
    const first = seen[0]!;
    expect(first.headers[':path']).toBe(`/3/device/${iosToken}`);
    expect(first.headers['apns-topic']).toBe('com.vawra.app');
    expect(first.headers['apns-push-type']).toBe('alert');
    const jwt = verifyJwt(String(first.headers.authorization).replace('bearer ', ''), ec.publicKey, true);
    expect(jwt.ok).toBe(true);
    expect(jwt.claims).toMatchObject({ iss: 'TEAM456' });
    expect(JSON.parse(first.body)).toMatchObject({ aps: { alert: { body: 'You have a new match' } }, type: 'match' });
    expect(seen[1]!.headers['apns-push-type']).toBe('background');
    status = 410;
    expect(await sender.send(iosToken, pushMessage('like', {}))).toBe('invalid_token');
  });

  it('half-set push settings are refused, not silently off', () => {
    expect(pushProblems({})).toEqual([]);
    expect(pushProblems({ VAWRA_APNS_KEY_ID: 'K' }).join()).toMatch(/Apple push needs all of/);
    expect(pushProblems({ VAWRA_FCM_CREDENTIALS_B64: 'not json' }).join()).toMatch(/service-account/);
    const incomplete = Buffer.from(JSON.stringify({ project_id: 'p' })).toString('base64');
    expect(pushProblems({ VAWRA_FCM_CREDENTIALS_B64: incomplete }).join()).toMatch(/project_id, client_email, private_key/);
  });
});

describe('retention', () => {
  it('removes push tokens of ended sign-ins within the hour', async () => {
    const { h } = await setup();
    const ana = await member(h, 'Ana');
    await register(h, ana, 'android', androidToken);
    await call(h, ana, 'DELETE', '/v1/session');
    const { runRetention } = await import('../src/jobs/retention.js');
    const removed = await runRetention(h.db, h.clock);
    expect(removed).toMatchObject({ signedOutDevices: 1 });
    expect(await h.db.query('SELECT 1 FROM devices')).toHaveLength(0);
  });
});
