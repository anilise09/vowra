import type { FastifyReply, FastifyRequest } from 'fastify';
import type { Db } from './db.js';
import type { Sealer } from './crypto.js';

export interface Clock {
  now(): Date;
}

/** How a one-time sign-in proof reaches the person. No provider is chosen yet. */
export interface Delivery {
  sendProof(email: string, proof: string, purpose: 'sign_in' | 'recovery'): Promise<void>;
}

export interface Services {
  db: Db;
  sealer: Sealer;
  clock: Clock;
  delivery: Delivery;
  accessTtlSeconds: number;
  proofTtlSeconds: number;
}

export interface Account {
  id: string;
  sessionId: string;
  familyId: string;
  ageState: 'assurance_required' | 'pending_review' | 'adult_verified' | 'rejected';
  lifecycle: 'active' | 'paused';
}

declare module 'fastify' {
  interface FastifyRequest {
    account?: Account;
  }
}

/** Stable error body; never says whether another account exists. */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
  ) {
    super(code);
  }
}

export const fail = (status: number, code: string): never => {
  throw new ApiError(status, code);
};

export function requireAccount(request: FastifyRequest): Account {
  return request.account ?? fail(401, 'unauthenticated');
}

/**
 * Dating features stay closed until the server records a passed age check.
 * Pausing hides a person from new people only: existing matches can still
 * chat, so conversation routes pass `allowPaused`.
 */
export function requireDatingAccess(
  request: FastifyRequest,
  { allowPaused = false }: { allowPaused?: boolean } = {},
): Account {
  const account = requireAccount(request);
  if (account.ageState !== 'adult_verified') fail(403, 'age_assurance_required');
  if (account.lifecycle === 'paused' && allowPaused) return account;
  if (account.lifecycle !== 'active') fail(409, 'account_paused');
  return account;
}

export async function audit(db: Db, accountId: string | null, kind: string, at: Date) {
  await db.query(
    'INSERT INTO audit_events (id, account_id, kind, created_at) VALUES ($1, $2, $3, $4)',
    [crypto.randomUUID(), accountId, kind, at],
  );
}

export const noContent = (reply: FastifyReply) => reply.code(204).send();
