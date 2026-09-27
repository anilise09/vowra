import { randomBytes } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { buildApp } from '../src/app.js';
import { pkceChallenge, Sealer } from '../src/crypto.js';
import { migrate, openPglite, type Db } from '../src/db.js';

export interface Harness {
  app: FastifyInstance;
  db: Db;
  sealer: Sealer;
  clock: { now(): Date; advance(ms: number): void };
  outbox: { email: string; proof: string; purpose: string }[];
  close(): Promise<void>;
}

export async function startHarness(): Promise<Harness> {
  const db = await openPglite();
  await migrate(db);
  let now = new Date('2026-09-27T12:00:00Z').getTime();
  const clock = { now: () => new Date(now), advance: (ms: number) => void (now += ms) };
  const outbox: Harness['outbox'] = [];
  const sealer = new Sealer(randomBytes(32), randomBytes(32));
  const app = buildApp({
    db,
    sealer,
    clock,
    delivery: { sendProof: async (email, proof, purpose) => void outbox.push({ email, proof, purpose }) },
    accessTtlSeconds: 900,
    proofTtlSeconds: 600,
    reauthWindowSeconds: 600,
    deletionGraceSeconds: 7 * 24 * 60 * 60,
  });
  await app.ready();
  return { app, db, sealer, clock, outbox, close: async () => (await app.close(), await db.close()) };
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
