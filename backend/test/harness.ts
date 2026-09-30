import { randomBytes } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { buildApp } from '../src/app.js';
import { pkceChallenge, Sealer } from '../src/crypto.js';
import { migrate, openPglite, type Db } from '../src/db.js';
import { type CallConfig, SignalBox } from '../src/calls.js';
import { MemoryNudgeBus } from '../src/nudges.js';
import { Notifier, type PushSender } from '../src/push.js';
import { MediaGrants, MemoryMediaStore } from '../src/media.js';

export interface Harness {
  app: FastifyInstance;
  db: Db;
  sealer: Sealer;
  clock: { now(): Date; advance(ms: number): void };
  outbox: { email: string; proof: string; purpose: string }[];
  nudges: MemoryNudgeBus;
  media: MemoryMediaStore;
  notifier: Notifier;
  close(): Promise<void>;
}

/** A relay-only call setup, as production has, with a throwaway TURN secret. */
export const testCallConfig: CallConfig = {
  policy: 'relay',
  stun: [],
  turn: { urls: ['turn:turn.example.test:3478?transport=udp'], secret: Buffer.from('test-turn-secret') },
};

export async function startHarness(
  options: {
    callConfig?: CallConfig | null;
    failDelivery?: boolean;
    push?: { android?: PushSender; ios?: PushSender };
  } = {},
): Promise<Harness> {
  const db = await openPglite();
  await migrate(db);
  let now = new Date('2026-09-27T12:00:00Z').getTime();
  const clock = { now: () => new Date(now), advance: (ms: number) => void (now += ms) };
  const outbox: Harness['outbox'] = [];
  const sealer = new Sealer(randomBytes(32), randomBytes(32));
  const nudges = new MemoryNudgeBus();
  const notifier = new Notifier(db, sealer, nudges, options.push ?? {}, () => clock.now());
  const media = new MemoryMediaStore();
  const app = buildApp({
    nudges,
    media,
    grants: new MediaGrants(randomBytes(32)),
    signals: new SignalBox(),
    notifier,
    callConfig: options.callConfig === undefined ? testCallConfig : options.callConfig,
    db,
    sealer,
    clock,
    delivery: {
      sendProof: async (email, proof, purpose) => {
        if (options.failDelivery) throw new Error('mail server unreachable');
        outbox.push({ email, proof, purpose });
      },
    },
    accessTtlSeconds: 900,
    proofTtlSeconds: 600,
    reauthWindowSeconds: 600,
    deletionGraceSeconds: 7 * 24 * 60 * 60,
  });
  await app.ready();
  return {
    app,
    db,
    sealer,
    clock,
    outbox,
    nudges,
    media,
    notifier,
    close: async () => (await app.close(), await notifier.idle(), await db.close()),
  };
}

export const verifier = () => randomBytes(32).toString('base64url');
export const state = () => randomBytes(16).toString('base64url');

export interface Person {
  email: string;
  accountId: string;
  access: string;
  refresh: string;
  auth: { authorization: string };
}

/** Full passwordless sign-in: request, read the outbox, exchange with PKCE. */
export async function signIn(h: Harness, email: string): Promise<Person> {
  const v = verifier();
  const s = state();
  await h.app.inject({
    method: 'POST',
    url: '/v1/auth/requests',
    payload: { identifier: email, purpose: 'sign_in', code_challenge: pkceChallenge(v), state: s },
  });
  const proof = [...h.outbox].reverse().find((m) => m.email === email)!.proof;
  const res = await h.app.inject({
    method: 'POST',
    url: '/v1/auth/exchange',
    payload: { proof, code_verifier: v, state: s },
  });
  const body = res.json();
  return {
    email,
    accountId: body.account_id,
    access: body.access_token,
    refresh: body.refresh_token,
    auth: { authorization: `Bearer ${body.access_token}` },
  };
}

/** Test stand-in for a reviewed age-assurance provider. */
export async function markAdult(h: Harness, p: Person, age = 30) {
  await h.db.query("UPDATE accounts SET age_state = 'adult_verified' WHERE id = $1", [p.accountId]);
  await h.db.query('UPDATE profiles SET public_age = $2 WHERE account_id = $1', [p.accountId, age]);
}

export async function makeProfile(h: Harness, p: Person, name: string) {
  const res = await h.app.inject({
    method: 'PATCH',
    url: '/v1/me/profile',
    headers: p.auth,
    payload: { display_name: name, relationship_intent: 'long_term', interests: ['Books'] },
  });
  if (res.statusCode !== 200) throw new Error(`profile failed: ${res.body}`);
}

/** Signed in, profiled and adult-verified: ready to use dating features. */
export async function member(h: Harness, name: string): Promise<Person> {
  const p = await signIn(h, `${name.toLowerCase()}@example.test`);
  await makeProfile(h, p, name);
  await markAdult(h, p);
  return p;
}

export async function swipe(h: Harness, from: Person, to: Person, kind = 'like') {
  return h.app.inject({
    method: 'POST',
    url: `/v1/discovery/${to.accountId}/swipe`,
    headers: from.auth,
    payload: { kind },
  });
}
