import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { audit, fail, requireModerator, type Services } from '../context.js';
import { DbRateLimiter } from '../rate_limit.js';
import { newTotpSecret, otpauthUri, verifyTotp } from '../totp.js';
import { requireRecentSignIn } from './lifecycle.js';

/** How long a moderator stays verified after entering a code; signing out ends it sooner. */
export const staffRules = { verifiedMinutes: 30, triesPer15Minutes: 5 };

const codeBody = z.object({ code: z.string().regex(/^\d{6}$/) }).strict();

/**
 * Moderators need a second factor, an authenticator app, before any
 * moderation action: reports, appeals, photos and whatever /v1/mod/ route
 * comes next. The check sits in one hook for every /v1/mod/ route, so a new
 * moderation route cannot forget it. People who are not moderators still get
 * the route's own "not found", so the console's existence is not revealed.
 */
export function staffRoutes(app: FastifyInstance, services: Services) {
  const { db, sealer, clock } = services;
  const tries = new DbRateLimiter(db, staffRules.triesPer15Minutes, 15 * 60_000, clock);

  app.addHook('preHandler', async (request, reply) => {
    const url = request.routeOptions.url ?? '';
    if (!url.startsWith('/v1/mod/') || url.startsWith('/v1/mod/second-factor')) return;
    const account = request.account;
    if (!account || account.role !== 'moderator') return; // the route answers 404
    const [row] = await db.query<{ confirmed_at: Date | null; mod_verified_until: Date | null }>(
      `SELECT m.confirmed_at, f.mod_verified_until
       FROM session_families f
       LEFT JOIN moderator_second_factor m ON m.account_id = $2
       WHERE f.id = $1`,
      [account.familyId, account.id],
    );
    if (!row?.confirmed_at) {
      return reply.code(403).send({ error: 'second_factor_setup_required', request_id: request.id });
    }
    if (!row.mod_verified_until || new Date(row.mod_verified_until) <= clock.now()) {
      return reply.code(403).send({ error: 'second_factor_required', request_id: request.id });
    }
  });

  const verifiedFor = async (familyId: string) => {
    const until = new Date(clock.now().getTime() + staffRules.verifiedMinutes * 60_000);
    await db.query('UPDATE session_families SET mod_verified_until = $2 WHERE id = $1', [familyId, until]);
    return until;
  };

  /** Whether a second factor is set up, and until when this sign-in is verified. */
  app.get('/v1/mod/second-factor', async (request) => {
    const mod = requireModerator(request);
    const [row] = await db.query<{ confirmed_at: Date | null; mod_verified_until: Date | null }>(
      `SELECT m.confirmed_at, f.mod_verified_until
       FROM session_families f LEFT JOIN moderator_second_factor m ON m.account_id = $2
       WHERE f.id = $1`,
      [mod.familyId, mod.id],
    );
    const until = row?.mod_verified_until ? new Date(row.mod_verified_until) : null;
    return {
      enabled: Boolean(row?.confirmed_at),
      verified_until: until && until > clock.now() ? until.toISOString() : null,
    };
  });

  /**
   * Starts setup: a new secret, shown once, for the authenticator app. Needs a
   * recent sign-in. Replacing a confirmed factor is not possible here; an
   * operator resets it (`npm run admin:moderator -- reset-2fa`).
   */
  app.post('/v1/mod/second-factor/setup', async (request) => {
    const mod = requireModerator(request);
    await requireRecentSignIn(services, mod);
    const [existing] = await db.query<{ confirmed_at: Date | null }>(
      'SELECT confirmed_at FROM moderator_second_factor WHERE account_id = $1',
      [mod.id],
    );
    if (existing?.confirmed_at) fail(409, 'already_enabled');
    const secret = newTotpSecret();
    await db.query(
      `INSERT INTO moderator_second_factor (account_id, secret_sealed, created_at) VALUES ($1, $2, $3)
       ON CONFLICT (account_id) DO UPDATE SET secret_sealed = $2, created_at = $3, last_step = NULL`,
      [mod.id, sealer.seal(secret), clock.now()],
    );
    await audit(db, mod.id, 'mod_2fa_setup_started', clock.now());
    return { secret, otpauth_uri: otpauthUri(secret, 'moderator') };
  });

  /** Proves the authenticator works; turns the second factor on and verifies this sign-in. */
  app.post('/v1/mod/second-factor/confirm', async (request) => {
    const mod = requireModerator(request);
    const body = codeBody.safeParse(request.body);
    if (!body.success) fail(400, 'invalid_request');
    if (!(await tries.take(sealer.lookup(`mod-2fa:${mod.id}`)))) fail(429, 'slow_down');
    const [row] = await db.query<{ secret_sealed: string; confirmed_at: Date | null }>(
      'SELECT secret_sealed, confirmed_at FROM moderator_second_factor WHERE account_id = $1',
      [mod.id],
    );
    if (!row || row.confirmed_at) fail(409, 'no_pending_setup');
    const now = clock.now();
    const step = verifyTotp(sealer.open(row!.secret_sealed), body.data!.code, now, null);
    if (step === null) fail(400, 'invalid_code');
    await db.query(
      'UPDATE moderator_second_factor SET confirmed_at = $2, last_step = $3 WHERE account_id = $1',
      [mod.id, now, step],
    );
    await audit(db, mod.id, 'mod_2fa_enabled', now);
    return { enabled: true, verified_until: (await verifiedFor(mod.familyId)).toISOString() };
  });

  /** Enters a code for this sign-in; moderation opens for the next half hour. */
  app.post('/v1/mod/second-factor/verify', async (request) => {
    const mod = requireModerator(request);
    const body = codeBody.safeParse(request.body);
    if (!body.success) fail(400, 'invalid_request');
    if (!(await tries.take(sealer.lookup(`mod-2fa:${mod.id}`)))) fail(429, 'slow_down');
    const now = clock.now();
    // The row is locked so two requests cannot both spend the same code.
    const until = await db.transaction(async (tx) => {
      const [row] = await tx.query<{ secret_sealed: string; confirmed_at: Date | null; last_step: string | null }>(
        'SELECT secret_sealed, confirmed_at, last_step FROM moderator_second_factor WHERE account_id = $1 FOR UPDATE',
        [mod.id],
      );
      if (!row?.confirmed_at) return 'setup';
      const last = row.last_step === null ? null : Number(row.last_step);
      const step = verifyTotp(sealer.open(row.secret_sealed), body.data!.code, now, last);
      if (step === null) return 'invalid';
      await tx.query('UPDATE moderator_second_factor SET last_step = $2 WHERE account_id = $1', [mod.id, step]);
      const verifiedUntil = new Date(now.getTime() + staffRules.verifiedMinutes * 60_000);
      await tx.query('UPDATE session_families SET mod_verified_until = $2 WHERE id = $1', [mod.familyId, verifiedUntil]);
      return verifiedUntil;
    });
    if (until === 'setup') fail(403, 'second_factor_setup_required');
    if (until === 'invalid') {
      await audit(db, mod.id, 'mod_2fa_failed', now);
      fail(400, 'invalid_code');
    }
    await audit(db, mod.id, 'mod_2fa_verified', now);
    return { verified_until: (until as Date).toISOString() };
  });
}
