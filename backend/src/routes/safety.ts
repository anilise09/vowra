import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { audit, fail, noContent, requireAccount, type Services } from '../context.js';
import { reportReasons } from '../rules.js';

const blockBody = z.object({ account_id: z.string().uuid() }).strict();
const reportBody = z
  .object({
    account_id: z.string().uuid(),
    reason: z.enum(reportReasons),
    message_id: z.string().uuid().optional(),
  })
  .strict();

/** Blocking and reporting are free, need no age check, and never tell the other person. */
export function safetyRoutes(app: FastifyInstance, services: Services) {
  const { db, clock } = services;

  app.post('/v1/blocks', async (request, reply) => {
    const me = requireAccount(request);
    const body = blockBody.safeParse(request.body);
    if (!body.success) fail(400, 'invalid_request');
    const other = body.data!.account_id;
    if (other === me.id) fail(400, 'invalid_request');
    const now = clock.now();
    // One transaction: the block, closed matches and the audit all land before success.
    await db.transaction(async (tx) => {
      const exists = await tx.query('SELECT 1 FROM accounts WHERE id = $1', [other]);
      if (exists.length === 0) return; // same response for unknown accounts
      await tx.query(
        `INSERT INTO blocks (blocker, blocked, created_at) VALUES ($1, $2, $3)
         ON CONFLICT DO NOTHING`,
        [me.id, other, now],
      );
      const [low, high] = me.id < other ? [me.id, other] : [other, me.id];
      await tx.query(
        "UPDATE matches SET status = 'blocked' WHERE account_low = $1 AND account_high = $2",
        [low, high],
      );
      await audit(tx, me.id, 'block', now);
    });
    // Only the blocker's own devices: the blocked person is never told.
    services.nudges.publish(me.id, { kind: 'match' });
    return noContent(reply);
  });

  app.post('/v1/reports', async (request, reply) => {
    const me = requireAccount(request);
    const body = reportBody.safeParse(request.body);
    if (!body.success) fail(400, 'invalid_request');
    const { account_id: target, reason, message_id } = body.data!;
    if (target === me.id) fail(400, 'invalid_request');
    const now = clock.now();
    const exists = await db.query('SELECT 1 FROM accounts WHERE id = $1', [target]);
    if (exists.length > 0) {
      // A message reference is kept only if it is the reported person's message
      // in a conversation the reporter is part of. No text is copied.
      let reference: string | null = null;
      if (message_id) {
        const owned = await db.query(
          `SELECT 1 FROM messages msg JOIN matches m ON m.id = msg.match_id
           WHERE msg.id = $1 AND msg.author_id = $2
             AND (m.account_low = $3 OR m.account_high = $3)`,
          [message_id, target, me.id],
        );
        reference = owned.length > 0 ? message_id : null;
      }
      await db.query(
        `INSERT INTO reports (id, reporter, target, reason, message_id, created_at)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [crypto.randomUUID(), me.id, target, reason, reference, now],
      );
      await audit(db, me.id, 'report', now);
    }
    return reply.code(202).send({ state: 'pending_review' });
  });

  app.get('/v1/blocks', async (request) => {
    const me = requireAccount(request);
    const rows = await db.query<{ blocked: string }>(
      'SELECT blocked FROM blocks WHERE blocker = $1 ORDER BY created_at DESC',
      [me.id],
    );
    return { blocked: rows.map((r) => r.blocked) };
  });

  app.delete('/v1/blocks/:accountId', async (request, reply) => {
    const me = requireAccount(request);
    const id = z.string().uuid().safeParse((request.params as { accountId: string }).accountId);
    if (id.success) {
      // Unblocking never revives an old match or conversation.
      await db.query('DELETE FROM blocks WHERE blocker = $1 AND blocked = $2', [me.id, id.data]);
    }
    return noContent(reply);
  });
}
