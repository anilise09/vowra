import { createHmac, timingSafeEqual } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { newToken } from '../crypto.js';
import { audit, fail, requireAccount, type Services } from '../context.js';
import { DbRateLimiter } from '../rate_limit.js';

/**
 * Age checks through an outside provider, kept provider-neutral: the app opens
 * the provider's hosted check with a one-time reference; the provider (or a
 * small adapter in front of it) tells Vawra the outcome on a signed webhook.
 * Vawra keeps only the outcome and the age confirmed, never documents, photos
 * or a date of birth. Which provider, and the legal review, are the owner's.
 *   VAWRA_AGE_CHECK_URL       https://provider.example/check?ref={reference}
 *   VAWRA_AGE_WEBHOOK_SECRET  a shared secret of at least 32 characters
 */
export interface AgeCheckConfig {
  urlTemplate: string;
  webhookSecret: string;
}

export const ageCheckRules = { startsPerDay: 5, signatureToleranceSeconds: 300, linkMinutes: 60 };

export function ageCheckProblems(env: NodeJS.ProcessEnv, production: boolean): string[] {
  const url = env.VAWRA_AGE_CHECK_URL;
  const secret = env.VAWRA_AGE_WEBHOOK_SECRET;
  if (!url && !secret) return [];
  const problems: string[] = [];
  if (!url || !secret) problems.push('Age checks need both VAWRA_AGE_CHECK_URL and VAWRA_AGE_WEBHOOK_SECRET.');
  if (url) {
    if (!url.includes('{reference}')) problems.push('VAWRA_AGE_CHECK_URL must contain {reference}.');
    try {
      const parsed = new URL(url.replace('{reference}', 'x'));
      if (production && parsed.protocol !== 'https:') problems.push('VAWRA_AGE_CHECK_URL must use https:// in production.');
    } catch {
      problems.push('VAWRA_AGE_CHECK_URL is not a valid URL.');
    }
  }
  if (secret && secret.length < 32) problems.push('VAWRA_AGE_WEBHOOK_SECRET must be at least 32 characters.');
  return problems;
}

export function ageCheckConfigFrom(env: NodeJS.ProcessEnv): AgeCheckConfig | null {
  if (!env.VAWRA_AGE_CHECK_URL || !env.VAWRA_AGE_WEBHOOK_SECRET) return null;
  return { urlTemplate: env.VAWRA_AGE_CHECK_URL, webhookSecret: env.VAWRA_AGE_WEBHOOK_SECRET };
}

/** `t=<unix seconds>,v1=<hex HMAC-SHA256 of "t.body">`, the scheme a provider adapter signs with. */
export function signAgeWebhook(secret: string, timestamp: number, body: string): string {
  const v1 = createHmac('sha256', secret).update(`${timestamp}.${body}`).digest('hex');
  return `t=${timestamp},v1=${v1}`;
}

const outcomeBody = z
  .object({
    reference: z.string().min(20).max(200),
    outcome: z.enum(['passed', 'failed', 'review']),
    age: z.number().int().min(0).max(130).optional(),
  })
  .strict();

const states = { passed: 'adult_verified', failed: 'rejected', review: 'pending_review' } as const;

export function ageRoutes(app: FastifyInstance, services: Services) {
  const { db, sealer, clock } = services;
  const config = services.ageCheck;
  const starts = new DbRateLimiter(db, ageCheckRules.startsPerDay, 24 * 60 * 60_000, clock);

  /** Starts a check: a one-time link to the provider's hosted check. */
  app.post('/v1/me/age-check', async (request) => {
    const me = requireAccount(request);
    if (me.ageState === 'adult_verified') fail(409, 'already_verified');
    if (me.ageState === 'rejected') fail(409, 'age_check_failed');
    if (!config) fail(503, 'age_check_unavailable');
    if (!(await starts.take(sealer.lookup(`age-check:${me.id}`)))) fail(429, 'slow_down');
    const reference = newToken();
    const now = clock.now();
    await db.query(
      `INSERT INTO age_checks (id, account_id, reference_hash, status, created_at)
       VALUES ($1, $2, $3, 'started', $4)`,
      [crypto.randomUUID(), me.id, sealer.lookup(`age-ref:${reference}`), now],
    );
    await audit(db, me.id, 'age_check_started', now);
    return {
      url: config!.urlTemplate.replace('{reference}', encodeURIComponent(reference)),
      expires_at: new Date(now.getTime() + ageCheckRules.linkMinutes * 60_000).toISOString(),
    };
  });

  // The webhook reads the raw body: the signature covers the exact bytes sent.
  app.register(async (scope) => {
    scope.removeContentTypeParser('application/json');
    scope.addContentTypeParser('application/json', { parseAs: 'buffer' }, (_request, body, done) => done(null, body));

    scope.post('/v1/webhooks/age-check', async (request, reply) => {
      if (!config) return fail(404, 'not_found');
      const raw = request.body as Buffer | undefined;
      const header = String(request.headers['vawra-signature'] ?? '');
      const parts = Object.fromEntries(header.split(',').map((p) => p.split('=') as [string, string]));
      const timestamp = Number(parts.t);
      const now = clock.now();
      if (!raw || !parts.v1 || !Number.isInteger(timestamp)) return fail(401, 'bad_signature');
      if (Math.abs(now.getTime() / 1000 - timestamp) > ageCheckRules.signatureToleranceSeconds) {
        return fail(401, 'stale_signature');
      }
      const expected = Buffer.from(signAgeWebhook(config.webhookSecret, timestamp, raw.toString('utf8')).split('v1=')[1]!);
      const given = Buffer.from(parts.v1);
      if (expected.length !== given.length || !timingSafeEqual(expected, given)) return fail(401, 'bad_signature');

      let parsed: z.infer<typeof outcomeBody>;
      try {
        const body = outcomeBody.safeParse(JSON.parse(raw.toString('utf8')));
        if (!body.success) return fail(400, 'invalid_request');
        parsed = body.data;
      } catch {
        return fail(400, 'invalid_request');
      }
      // A pass must confirm an adult age: under 18 is a fail, no age goes to a person to review.
      const outcome =
        parsed.outcome !== 'passed' ? parsed.outcome : parsed.age === undefined ? 'review' : parsed.age >= 18 ? 'passed' : 'failed';
      const result = await db.transaction(async (tx) => {
        const [check] = await tx.query<{ id: string; account_id: string; status: string }>(
          'SELECT id, account_id, status FROM age_checks WHERE reference_hash = $1 FOR UPDATE',
          [sealer.lookup(`age-ref:${parsed.reference}`)],
        );
        if (!check) return 'unknown';
        // Decided checks stay decided; repeats are accepted and change nothing.
        if (check.status === 'passed' || check.status === 'failed') return 'repeat';
        await tx.query('UPDATE age_checks SET status = $2, verified_age = $3, decided_at = $4 WHERE id = $1', [
          check.id,
          outcome,
          outcome === 'passed' ? parsed.age : null,
          now,
        ]);
        await tx.query(
          `UPDATE accounts SET age_state = $2 WHERE id = $1 AND age_state <> 'adult_verified'`,
          [check.account_id, states[outcome]],
        );
        if (outcome === 'passed') {
          await tx.query('UPDATE profiles SET public_age = $2 WHERE account_id = $1', [check.account_id, parsed.age]);
        }
        await audit(tx, check.account_id, `age_check_${outcome}`, now);
        return 'applied';
      });
      if (result === 'unknown') return fail(404, 'not_found');
      return reply.code(200).send({ ok: true });
    });
  });
}
