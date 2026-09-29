import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { hashToken, newToken, pkceChallenge } from '../crypto.js';
import { audit, fail, noContent, requireAccount, type Services } from '../context.js';
import type { Db } from '../db.js';
import { RateLimiter } from '../rate_limit.js';

/** Identical for known, unknown, throttled and recovery requests: no existence oracle. */
export const initiationMessage = {
  message: 'If the account can continue, instructions will be sent.',
} as const;

const requestBody = z
  .object({
    identifier: z.string().trim().toLowerCase().email().max(254),
    purpose: z.enum(['sign_in', 'recovery']),
    code_challenge: z.string().min(43).max(128),
    state: z.string().min(16).max(128),
  })
  .strict();

const exchangeBody = z
  .object({
    proof: z.string().min(20).max(200),
    code_verifier: z.string().min(43).max(128),
    state: z.string().min(16).max(128),
  })
  .strict();

const rotateBody = z.object({ refresh_token: z.string().min(20).max(200) }).strict();

export async function issueSession(
  db: Db,
  services: Services,
  accountId: string,
  familyId?: string,
) {
  const now = services.clock.now();
  const family = familyId ?? crypto.randomUUID();
  if (!familyId) {
    await db.query(
      'INSERT INTO session_families (id, account_id, created_at) VALUES ($1, $2, $3)',
      [family, accountId, now],
    );
  }
  const access = newToken();
  const refresh = newToken();
  const expires = new Date(now.getTime() + services.accessTtlSeconds * 1000);
  const sessionId = crypto.randomUUID();
  await db.query(
    `INSERT INTO sessions (id, family_id, account_id, access_hash, access_expires_at,
                           refresh_hash, created_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7)`,
    [sessionId, family, accountId, hashToken(access), expires, hashToken(refresh), now],
  );
  return {
    session_id: sessionId,
    access_token: access,
    access_expires_at: expires.toISOString(),
    refresh_token: refresh,
  };
}

export function authRoutes(app: FastifyInstance, services: Services) {
  const { db, sealer, clock } = services;
  const perIdentifier = new RateLimiter(5, 15 * 60_000, clock);
  const perNetwork = new RateLimiter(30, 15 * 60_000, clock);

  app.post('/v1/auth/requests', async (request, reply) => {
    const body = requestBody.safeParse(request.body);
    if (!body.success) fail(400, 'invalid_request');
    const { identifier, purpose, code_challenge, state } = body.data!;
    const lookup = sealer.lookup(identifier);
    const allowed =
      perIdentifier.take(`${purpose}:${lookup}`) && perNetwork.take(`ip:${request.ip}`);
    if (allowed) {
      const known =
        (await db.query('SELECT 1 FROM accounts WHERE email_lookup = $1', [lookup])).length > 0;
      // Recovery only proceeds for an existing account; sign-in may create one.
      if (purpose === 'sign_in' || known) {
        const proof = newToken();
        const now = clock.now();
        await db.query(
          `INSERT INTO auth_requests (id, email_lookup, email_sealed, purpose, proof_hash,
                                      code_challenge, state_nonce, expires_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
          [
            crypto.randomUUID(),
            lookup,
            sealer.seal(identifier),
            purpose,
            hashToken(proof),
            code_challenge,
            state,
            new Date(now.getTime() + services.proofTtlSeconds * 1000),
          ],
        );
        await services.delivery.sendProof(identifier, proof, purpose);
      }
    }
    return reply.code(202).send(initiationMessage);
  });

  app.post('/v1/auth/exchange', async (request) => {
    const body = exchangeBody.safeParse(request.body);
    if (!body.success) fail(400, 'invalid_request');
    const { proof, code_verifier, state } = body.data!;
    const now = clock.now();
    // Single use, committed before any check: a failed attempt still spends the
    // proof, so it cannot be retried with guessed verifiers.
    const [found] = await db.query<{
      email_lookup: string;
      email_sealed: string;
      purpose: 'sign_in' | 'recovery';
      code_challenge: string;
      state_nonce: string;
    }>(
      `UPDATE auth_requests SET used_at = $2
       WHERE proof_hash = $1 AND used_at IS NULL AND expires_at > $2
       RETURNING email_lookup, email_sealed, purpose, code_challenge, state_nonce`,
      [hashToken(proof), now],
    );
    if (
      !found ||
      found.state_nonce !== state ||
      found.code_challenge !== pkceChallenge(code_verifier)
    ) {
      return fail(400, 'invalid_proof');
    }
    const outcome = await db.transaction(async (tx) => {
      let [account] = await tx.query<{ id: string; age_state: string }>(
        'SELECT id, age_state FROM accounts WHERE email_lookup = $1',
        [found.email_lookup],
      );
      if (!account) {
        if (found.purpose === 'recovery') return null;
        account = { id: crypto.randomUUID(), age_state: 'assurance_required' };
        await tx.query(
          `INSERT INTO accounts (id, email_lookup, email_sealed, created_at)
           VALUES ($1, $2, $3, $4)`,
          [account.id, found.email_lookup, found.email_sealed, now],
        );
      }
      if (found.purpose === 'recovery') {
        // Recovery signs out every existing session first.
        await tx.query(
          'UPDATE session_families SET revoked_at = $2 WHERE account_id = $1 AND revoked_at IS NULL',
          [account.id, now],
        );
      }
      await audit(tx, account.id, `auth_${found.purpose}`, now);
      const session = await issueSession(tx, services, account.id);
      return { ...session, account_id: account.id, age_state: account.age_state };
    });
    return outcome ?? fail(400, 'invalid_proof');
  });

  app.post('/v1/session/rotate', async (request) => {
    const body = rotateBody.safeParse(request.body);
    if (!body.success) fail(400, 'invalid_request');
    const now = clock.now();
    // Errors are returned as values and thrown only after commit, so the
    // family revocation on reuse is never rolled back.
    const outcome = await db.transaction(async (tx) => {
      const [session] = await tx.query<{
        id: string;
        family_id: string;
        account_id: string;
        refresh_used_at: Date | null;
        revoked_at: Date | null;
        family_revoked_at: Date | null;
      }>(
        `SELECT s.id, s.family_id, s.account_id, s.refresh_used_at, s.revoked_at,
                f.revoked_at AS family_revoked_at
         FROM sessions s JOIN session_families f ON f.id = s.family_id
         WHERE s.refresh_hash = $1`,
        [hashToken(body.data!.refresh_token)],
      );
      if (!session || session.family_revoked_at) return null;
      if (session.refresh_used_at || session.revoked_at) {
        // Reuse of a spent refresh token: revoke the whole family.
        await tx.query('UPDATE session_families SET revoked_at = $2 WHERE id = $1', [
          session.family_id,
          now,
        ]);
        await audit(tx, session.account_id, 'refresh_reuse_detected', now);
        return null;
      }
      await tx.query('UPDATE sessions SET refresh_used_at = $2, revoked_at = $2 WHERE id = $1', [
        session.id,
        now,
      ]);
      return issueSession(tx, services, session.account_id, session.family_id);
    });
    return outcome ?? fail(401, 'session_revoked');
  });

  app.delete('/v1/session', async (request, reply) => {
    const account = requireAccount(request);
    const now = clock.now();
    // Signing out ends this device's whole sign-in, not only its current token.
    await db.query('UPDATE sessions SET revoked_at = $2 WHERE id = $1', [account.sessionId, now]);
    await db.query(
      'UPDATE session_families SET revoked_at = $2 WHERE id = $1 AND revoked_at IS NULL',
      [account.familyId, now],
    );
    return noContent(reply);
  });

  app.delete('/v1/sessions', async (request, reply) => {
    const account = requireAccount(request);
    const now = clock.now();
    await db.query(
      'UPDATE session_families SET revoked_at = $2 WHERE account_id = $1 AND revoked_at IS NULL',
      [account.id, now],
    );
    await audit(db, account.id, 'sign_out_everywhere', now);
    return noContent(reply);
  });
}
