import type { FastifyInstance } from 'fastify';
import { audit, fail, noContent, requireAccount, type Account, type Services } from '../context.js';

/**
 * Deletion needs a sign-in within the reauthentication window: a stolen or
 * forgotten session on some device is never enough on its own.
 */
async function requireRecentSignIn(services: Services, account: Account) {
  const [family] = await services.db.query<{ created_at: Date }>(
    'SELECT created_at FROM session_families WHERE id = $1',
    [account.familyId],
  );
  const signedInAt = family ? new Date(family.created_at).getTime() : 0;
  if (services.clock.now().getTime() - signedInAt > services.reauthWindowSeconds * 1000) {
    fail(403, 'reauthentication_required');
  }
}

export function lifecycleRoutes(app: FastifyInstance, services: Services) {
  const { db, clock } = services;

  app.post('/v1/me/deletion', async (request, reply) => {
    const account = requireAccount(request);
    await requireRecentSignIn(services, account);
    const now = clock.now();
    const effective = await db.transaction(async (tx) => {
      const [row] = await tx.query<{ lifecycle: string; deletion_effective_at: Date | null }>(
        'SELECT lifecycle, deletion_effective_at FROM accounts WHERE id = $1 FOR UPDATE',
        [account.id],
      );
      // Asking twice keeps the first date.
      if (row?.lifecycle === 'deletion_scheduled' && row.deletion_effective_at) {
        return new Date(row.deletion_effective_at);
      }
      const at = new Date(now.getTime() + services.deletionGraceSeconds * 1000);
      await tx.query(
        `UPDATE accounts SET lifecycle_before_deletion = lifecycle,
                lifecycle = 'deletion_scheduled', deletion_effective_at = $2
         WHERE id = $1`,
        [account.id, at],
      );
      // Signed out everywhere, this device included.
      await tx.query(
        'UPDATE session_families SET revoked_at = $2 WHERE account_id = $1 AND revoked_at IS NULL',
        [account.id, now],
      );
      await audit(tx, account.id, 'deletion_scheduled', now);
      return at;
    });
    return reply.code(202).send({ state: 'scheduled', effective_at: effective.toISOString() });
  });

  app.delete('/v1/me/deletion', async (request, reply) => {
    const account = requireAccount(request);
    await requireRecentSignIn(services, account);
    const now = clock.now();
    const [row] = await db.query<{ deletion_effective_at: Date | null }>(
      "SELECT deletion_effective_at FROM accounts WHERE id = $1 AND lifecycle = 'deletion_scheduled'",
      [account.id],
    );
    if (!row?.deletion_effective_at) return fail(409, 'no_deletion_scheduled');
    if (new Date(row.deletion_effective_at) <= now) return fail(410, 'deletion_effective');
    await db.query(
      `UPDATE accounts SET lifecycle = COALESCE(lifecycle_before_deletion, 'active'),
              lifecycle_before_deletion = NULL, deletion_effective_at = NULL
       WHERE id = $1 AND lifecycle = 'deletion_scheduled'`,
      [account.id],
    );
    await audit(db, account.id, 'deletion_cancelled', now);
    return noContent(reply);
  });
}
