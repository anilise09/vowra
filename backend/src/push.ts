import { createSign, createPrivateKey } from 'node:crypto';
import { connect } from 'node:http2';
import type { Sealer } from './crypto.js';
import type { Db } from './db.js';
import type { Presence } from './shared.js';

/**
 * Push notifications for when the app is closed. The text never names anyone
 * or quotes anything, because it shows on a lock screen: "New message", not
 * who or what. A call is a silent, high-priority wake-up the app turns into a
 * ringing screen.
 */
export type PushEvent = 'match' | 'message' | 'like' | 'call';

export interface PushMessage {
  event: PushEvent;
  /** Shown on screen; empty for a call, which the app presents itself. */
  title: string;
  body: string;
  data: Record<string, string>;
  /** Seconds the push service may hold it for an offline phone. */
  ttlSeconds: number;
}

export type PushResult = 'sent' | 'invalid_token' | 'failed';

export interface PushSender {
  send(token: string, message: PushMessage): Promise<PushResult>;
}

const texts: Record<Exclude<PushEvent, 'call'>, string> = {
  match: 'You have a new match',
  message: 'You have a new message',
  like: 'Someone likes you',
};

export function pushMessage(event: PushEvent, data: Record<string, string>): PushMessage {
  if (event === 'call') return { event, title: '', body: '', data: { type: 'call', ...data }, ttlSeconds: 45 };
  return { event, title: 'Vawra', body: texts[event], data: { type: event, ...data }, ttlSeconds: 24 * 60 * 60 };
}

const base64url = (value: Buffer | string) => Buffer.from(value).toString('base64url');

/** A signed JWT: RS256 for Google, ES256 for Apple. */
function jwt(header: object, claims: object, key: string, algorithm: 'RS256' | 'ES256') {
  const input = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claims))}`;
  const signer = createSign('SHA256');
  signer.update(input);
  const signature =
    algorithm === 'ES256'
      ? signer.sign({ key: createPrivateKey(key), dsaEncoding: 'ieee-p1363' })
      : signer.sign(createPrivateKey(key));
  return `${input}.${base64url(signature)}`;
}

export interface FcmCredentials {
  project_id: string;
  client_email: string;
  private_key: string;
}

/** Android and web: Firebase Cloud Messaging HTTP v1 with a service account. */
export class FcmSender implements PushSender {
  private token?: { value: string; expires: number };

  constructor(
    private readonly credentials: FcmCredentials,
    private readonly urls = {
      oauth: 'https://oauth2.googleapis.com/token',
      send: `https://fcm.googleapis.com/v1/projects/${credentials.project_id}/messages:send`,
    },
    private readonly now = () => Date.now(),
  ) {}

  private async accessToken(): Promise<string> {
    if (this.token && this.token.expires > this.now() + 60_000) return this.token.value;
    const issued = Math.floor(this.now() / 1000);
    const assertion = jwt(
      { alg: 'RS256', typ: 'JWT' },
      {
        iss: this.credentials.client_email,
        scope: 'https://www.googleapis.com/auth/firebase.messaging',
        aud: this.urls.oauth,
        iat: issued,
        exp: issued + 3600,
      },
      this.credentials.private_key,
      'RS256',
    );
    const res = await fetch(this.urls.oauth, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
    });
    if (!res.ok) throw new Error(`FCM sign-in failed: ${res.status}`);
    const body = (await res.json()) as { access_token: string; expires_in: number };
    this.token = { value: body.access_token, expires: this.now() + body.expires_in * 1000 };
    return body.access_token;
  }

  async send(token: string, message: PushMessage): Promise<PushResult> {
    const call = message.event === 'call';
    const payload = {
      message: {
        token,
        data: message.data,
        ...(call ? {} : { notification: { title: message.title, body: message.body } }),
        android: {
          priority: call ? 'HIGH' : 'NORMAL',
          ttl: `${message.ttlSeconds}s`,
          // One notification per kind: a burst of messages replaces, not stacks.
          ...(call ? {} : { notification: { tag: message.event } }),
        },
      },
    };
    const res = await fetch(this.urls.send, {
      method: 'POST',
      headers: { authorization: `Bearer ${await this.accessToken()}`, 'content-type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (res.ok) return 'sent';
    const text = await res.text();
    if (res.status === 404 || (res.status === 400 && text.includes('INVALID_ARGUMENT') && text.includes('token')) || text.includes('UNREGISTERED')) {
      return 'invalid_token';
    }
    return 'failed';
  }
}

export interface ApnsCredentials {
  keyId: string;
  teamId: string;
  /** The .p8 key's contents. */
  key: string;
  /** The app's bundle identifier. */
  topic: string;
  production: boolean;
}

/** iPhone and iPad: Apple Push Notification service over HTTP/2 with a token key. */
export class ApnsSender implements PushSender {
  private token?: { value: string; issued: number };

  constructor(
    private readonly credentials: ApnsCredentials,
    private readonly origin = credentials.production
      ? 'https://api.push.apple.com'
      : 'https://api.sandbox.push.apple.com',
    private readonly now = () => Date.now(),
  ) {}

  /** Apple accepts a token for an hour and refuses one refreshed too often: renew every 50 minutes. */
  private bearer(): string {
    if (this.token && this.now() - this.token.issued < 50 * 60_000) return this.token.value;
    const issued = this.now();
    const value = jwt(
      { alg: 'ES256', kid: this.credentials.keyId },
      { iss: this.credentials.teamId, iat: Math.floor(issued / 1000) },
      this.credentials.key,
      'ES256',
    );
    this.token = { value, issued };
    return value;
  }

  send(token: string, message: PushMessage): Promise<PushResult> {
    const call = message.event === 'call';
    const body = JSON.stringify({
      aps: call
        ? { 'content-available': 1 }
        : { alert: { title: message.title, body: message.body }, sound: 'default', 'thread-id': message.event },
      ...message.data,
    });
    return new Promise((resolve) => {
      const session = connect(this.origin);
      session.on('error', () => resolve('failed'));
      const request = session.request({
        ':method': 'POST',
        ':path': `/3/device/${encodeURIComponent(token)}`,
        authorization: `bearer ${this.bearer()}`,
        'apns-topic': this.credentials.topic,
        'apns-push-type': call ? 'background' : 'alert',
        'apns-priority': call ? '5' : '10',
        'apns-expiration': String(Math.floor(this.now() / 1000) + message.ttlSeconds),
        'content-type': 'application/json',
      });
      let status = 0;
      let text = '';
      request.on('response', (headers) => (status = Number(headers[':status'])));
      request.on('data', (chunk) => (text += chunk));
      request.on('end', () => {
        session.close();
        if (status === 200) resolve('sent');
        else if (status === 410 || (status === 400 && /BadDeviceToken|DeviceTokenNotForTopic/.test(text))) resolve('invalid_token');
        else resolve('failed');
      });
      request.on('error', () => {
        session.close();
        resolve('failed');
      });
      request.end(body);
    });
  }
}

/** Push settings from the environment; each platform is optional. */
export function pushSendersFrom(env: NodeJS.ProcessEnv): { android?: PushSender; ios?: PushSender } {
  const senders: { android?: PushSender; ios?: PushSender } = {};
  if (env.VAWRA_FCM_CREDENTIALS_B64) {
    const credentials = JSON.parse(Buffer.from(env.VAWRA_FCM_CREDENTIALS_B64, 'base64').toString('utf8')) as FcmCredentials;
    senders.android = new FcmSender(credentials);
  }
  if (env.VAWRA_APNS_KEY_B64 && env.VAWRA_APNS_KEY_ID && env.VAWRA_APNS_TEAM_ID && env.VAWRA_APNS_TOPIC) {
    senders.ios = new ApnsSender({
      key: Buffer.from(env.VAWRA_APNS_KEY_B64, 'base64').toString('utf8'),
      keyId: env.VAWRA_APNS_KEY_ID,
      teamId: env.VAWRA_APNS_TEAM_ID,
      topic: env.VAWRA_APNS_TOPIC,
      production: env.VAWRA_APNS_PRODUCTION === '1',
    });
  }
  return senders;
}

/** Problems with the push settings: half-configured platforms are refused, never silently off. */
export function pushProblems(env: NodeJS.ProcessEnv): string[] {
  const problems: string[] = [];
  if (env.VAWRA_FCM_CREDENTIALS_B64) {
    try {
      const c = JSON.parse(Buffer.from(env.VAWRA_FCM_CREDENTIALS_B64, 'base64').toString('utf8')) as Partial<FcmCredentials>;
      if (!c.project_id || !c.client_email || !c.private_key) {
        problems.push('VAWRA_FCM_CREDENTIALS_B64 must be a Firebase service-account key (project_id, client_email, private_key).');
      }
    } catch {
      problems.push('VAWRA_FCM_CREDENTIALS_B64 must be the service-account JSON, base64-encoded.');
    }
  }
  const apns = ['VAWRA_APNS_KEY_B64', 'VAWRA_APNS_KEY_ID', 'VAWRA_APNS_TEAM_ID', 'VAWRA_APNS_TOPIC'];
  const set = apns.filter((name) => env[name]);
  if (set.length > 0 && set.length < apns.length) {
    problems.push(`Apple push needs all of ${apns.join(', ')}; missing ${apns.filter((n) => !env[n]).join(', ')}.`);
  }
  return problems;
}

const prefColumn: Record<PushEvent, 'matches' | 'messages' | 'likes' | 'calls'> = {
  match: 'matches',
  message: 'messages',
  like: 'likes',
  call: 'calls',
};

/**
 * Decides whether and where to push. Only when the person has no live
 * connection (an open app already shows it), only for what they left on, and
 * at most one message push per conversation a minute.
 */
export class Notifier {
  private readonly lastMessagePush = new Map<string, number>();
  private readonly inFlight = new Set<Promise<void>>();

  constructor(
    private readonly db: Db,
    private readonly sealer: Sealer,
    private readonly presence: Presence,
    private readonly senders: { android?: PushSender; ios?: PushSender },
    private readonly now: () => Date,
    private readonly log: (message: string, detail?: object) => void = () => {},
  ) {}

  /** Fire and forget: a push never slows down or fails the request that caused it. */
  notify(accountId: string, event: PushEvent, data: Record<string, string> = {}): void {
    if (!this.senders.android && !this.senders.ios) return;
    const work = this.deliver(accountId, event, data)
      .catch((error: Error) => this.log('push failed', { message: error.message }))
      .finally(() => this.inFlight.delete(work));
    this.inFlight.add(work);
  }

  /** For tests and shutdown: waits for pushes already started. */
  async idle(): Promise<void> {
    while (this.inFlight.size > 0) await Promise.all([...this.inFlight]);
  }

  private async deliver(accountId: string, event: PushEvent, data: Record<string, string>) {
    if (await this.presence.connected(accountId)) return;
    if (event === 'message') {
      const key = `${accountId}:${data.match_id ?? ''}`;
      const last = this.lastMessagePush.get(key) ?? 0;
      const now = this.now().getTime();
      if (now - last < 60_000) return;
      this.lastMessagePush.set(key, now);
      if (this.lastMessagePush.size > 50_000) this.lastMessagePush.clear();
    }
    const [prefs] = await this.db.query<Record<string, boolean>>(
      'SELECT matches, messages, likes, calls FROM notification_prefs WHERE account_id = $1',
      [accountId],
    );
    if (prefs && prefs[prefColumn[event]] === false) return;
    // Only devices whose sign-in is still live.
    const devices = await this.db.query<{ id: string; platform: 'android' | 'ios'; token_sealed: string }>(
      `SELECT d.id, d.platform, d.token_sealed FROM devices d
       JOIN session_families f ON f.id = d.family_id AND f.revoked_at IS NULL
       JOIN accounts a ON a.id = d.account_id AND a.lifecycle IN ('active','paused')
       WHERE d.account_id = $1`,
      [accountId],
    );
    const message = pushMessage(event, data);
    for (const device of devices) {
      const sender = this.senders[device.platform];
      if (!sender) continue;
      const result = await sender.send(this.sealer.open(device.token_sealed), message);
      if (result === 'invalid_token') await this.db.query('DELETE FROM devices WHERE id = $1', [device.id]);
      if (result === 'failed') this.log('push not delivered', { platform: device.platform, event });
    }
  }
}
