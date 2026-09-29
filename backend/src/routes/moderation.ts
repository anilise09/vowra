import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { audit, fail, requireAccount, requireModerator, type Services } from '../context.js';
import { requireRecentSignIn } from './lifecycle.js';

const uuid = z.string().uuid();
const reportDecision = z
  .object({ outcome: z.enum(['dismissed', 'suspended']), note: z.string().max(500).optional() })
  .strict();
const appealDecision = z
  .object({ outcome: z.enum(['upheld', 'overturned']), note: z.string().max(500).optional() })
  .strict();
const appealBody = z.object({ message: z.string().trim().min(1).max(1000) }).strict();

const iso = (d: Date | string | null) => (d == null ? null : new Date(d).toISOString());

/**
 * Reports are reviewed by moderators. Every decision needs a recent sign-in,
 * is audited, and never involves the moderator's own reports. A suspended
 * person can appeal once at a time, and a different moderator decides it.
 */
export function moderationRoutes(app: FastifyInstance, services: Services) {
  const { db, clock } = services;

  app.get('/v1/mod/reports', async (request) => {
    const mod = requireModerator(request);
    const rows = await db.query<Record<string, unknown>>(
      `SELECT r.id AS report_id, r.reason, r.created_at AS reported_at,
              r.target AS account_id, p.display_name, p.bio, p.prompts, a.lifecycle AS status,
              msg.body AS message_text, msg.created_at AS message_sent_at,
              (SELECT count(*)::int FROM reports r2 WHERE r2.target = r.target) AS reports_against,
              (SELECT count(*)::int FROM reports r3 WHERE r3.reporter = r.reporter)
                AS reporter_report_count
       FROM reports r
       JOIN accounts a ON a.id = r.target
       LEFT JOIN profiles p ON p.account_id = r.target
       LEFT JOIN messages msg ON msg.id = r.message_id
       WHERE r.state = 'pending_review' AND r.reporter <> $1 AND r.target <> $1
       ORDER BY r.created_at
       LIMIT 50`,
      [mod.id],
    );
    // The reporter is never identified; only how often they report.
    return {
      reports: rows.map(({ message_text, message_sent_at, reported_at, ...r }) => ({
        ...r,
        reported_at: iso(reported_at as Date),
        message: message_text
          ? { text: message_text, sent_at: iso(message_sent_at as Date) }
          : null,
      })),
    };
  });

  app.post('/v1/mod/reports/:id/decision', async (request) => {
    const mod = requireModerator(request);
    await requireRecentSignIn(services, mod);
    const id = uuid.safeParse((request.params as { id: string }).id);
    const body = reportDecision.safeParse(request.body);
    if (!id.success || !body.success) fail(400, 'invalid_request');
    const { outcome, note } = body.data!;
    const now = clock.now();
    const peers = await db.transaction(async (tx) => {
      const [report] = await tx.query<{
        reporter: string;
        target: string;
        reason: string;
        state: string;
      }>('SELECT reporter, target, reason, state FROM reports WHERE id = $1 FOR UPDATE', [id.data]);
      if (!report) return fail(404, 'not_found');
      if (report.reporter === mod.id || report.target === mod.id) fail(409, 'conflict_of_interest');
      if (report.state !== 'pending_review') fail(409, 'already_decided');
      if (outcome === 'dismissed') {
        await tx.query(
          `UPDATE reports SET state = 'dismissed', decided_at = $2, decided_by = $3,
                  decision_note = $4 WHERE id = $1`,
          [id.data, now, mod.id, note ?? null],
        );
        await audit(tx, mod.id, 'mod_dismissed', now);
        return [];
      }
      const [target] = await tx.query<{ lifecycle: string }>(
        'SELECT lifecycle FROM accounts WHERE id = $1 FOR UPDATE',
        [report.target],
      );
      // Someone already leaving or suspended keeps that state; the report is still actioned.
      if (target?.lifecycle === 'active' || target?.lifecycle === 'paused') {
        await tx.query(
          `UPDATE accounts SET lifecycle_before_suspension = lifecycle, lifecycle = 'suspended',
                  suspended_at = $2, suspension_reason = $3, suspended_by = $4
           WHERE id = $1`,
          [report.target, now, report.reason, mod.id],
        );
        // Signed out everywhere at once.
        await tx.query(
          'UPDATE session_families SET revoked_at = $2 WHERE account_id = $1 AND revoked_at IS NULL',
          [report.target, now],
        );
        await audit(tx, report.target, 'suspended', now);
      }
      // Every open report about this person is settled by the suspension.
      await tx.query(
        `UPDATE reports SET state = 'actioned', decided_at = $2, decided_by = $3,
                decision_note = CASE WHEN id = $4 THEN $5 ELSE decision_note END
         WHERE target = $1 AND state = 'pending_review'`,
        [report.target, now, mod.id, id.data, note ?? null],
      );
      await audit(tx, mod.id, 'mod_suspended', now);
      const matches = await tx.query<{ peer: string }>(
        `SELECT CASE WHEN account_low = $1 THEN account_high ELSE account_low END AS peer
         FROM matches WHERE (account_low = $1 OR account_high = $1) AND status = 'active'`,
        [report.target],
      );
      return matches.map((m) => m.peer);
    });
    // Their matches' chat lists refresh; the conversation is closed.
    for (const peer of peers) services.nudges.publish(peer, { kind: 'match' });
    return { state: outcome === 'dismissed' ? 'dismissed' : 'actioned' };
  });

  app.get('/v1/mod/appeals', async (request) => {
    const mod = requireModerator(request);
    const rows = await db.query<Record<string, unknown> & { suspended_by: string | null }>(
      `SELECT ap.id AS appeal_id, ap.message, ap.created_at, a.id AS account_id,
              p.display_name, a.suspended_at, a.suspension_reason, a.suspended_by
       FROM appeals ap
       JOIN accounts a ON a.id = ap.account_id
       LEFT JOIN profiles p ON p.account_id = a.id
       WHERE ap.state = 'open' AND ap.account_id <> $1
       ORDER BY ap.created_at`,
      [mod.id],
    );
    return {
      appeals: rows.map(({ suspended_by, created_at, suspended_at, ...a }) => ({
        ...a,
        created_at: iso(created_at as Date),
        suspended_at: iso(suspended_at as Date),
        // A different moderator must decide it.
        suspended_by_you: suspended_by === mod.id,
      })),
    };
  });

  app.post('/v1/mod/appeals/:id/decision', async (request) => {
    const mod = requireModerator(request);
    await requireRecentSignIn(services, mod);
    const id = uuid.safeParse((request.params as { id: string }).id);
    const body = appealDecision.safeParse(request.body);
    if (!id.success || !body.success) fail(400, 'invalid_request');
    const { outcome, note } = body.data!;
    const now = clock.now();
    await db.transaction(async (tx) => {
      const [appeal] = await tx.query<{ account_id: string; state: string }>(
        'SELECT account_id, state FROM appeals WHERE id = $1 FOR UPDATE',
        [id.data],
      );
      if (!appeal) return fail(404, 'not_found');
      if (appeal.account_id === mod.id) fail(409, 'conflict_of_interest');
      if (appeal.state !== 'open') fail(409, 'already_decided');
      const [account] = await tx.query<{ suspended_by: string | null }>(
        'SELECT suspended_by FROM accounts WHERE id = $1',
        [appeal.account_id],
      );
      if (account?.suspended_by === mod.id) fail(409, 'second_moderator_required');
      await tx.query(
        `UPDATE appeals SET state = $2, decided_at = $3, decided_by = $4, decision_note = $5
         WHERE id = $1`,
        [id.data, outcome, now, mod.id, note ?? null],
      );
      if (outcome === 'overturned') {
        await tx.query(
          `UPDATE accounts SET lifecycle = COALESCE(lifecycle_before_suspension, 'active'),
                  lifecycle_before_suspension = NULL, suspended_at = NULL,
                  suspension_reason = NULL, suspended_by = NULL
           WHERE id = $1 AND lifecycle = 'suspended'`,
          [appeal.account_id],
        );
        await audit(tx, appeal.account_id, 'suspension_overturned', now);
      }
      await audit(tx, mod.id, `mod_appeal_${outcome}`, now);
    });
    return { state: outcome };
  });

  /** A suspended person asks for another look, once at a time. */
  app.post('/v1/me/appeal', async (request, reply) => {
    const account = requireAccount(request);
    if (account.lifecycle !== 'suspended') fail(409, 'not_suspended');
    const body = appealBody.safeParse(request.body);
    if (!body.success) fail(400, 'invalid_request');
    const now = clock.now();
    const open = await db.query("SELECT 1 FROM appeals WHERE account_id = $1 AND state = 'open'", [
      account.id,
    ]);
    if (open.length > 0) fail(409, 'appeal_open');
    await db.query(
      'INSERT INTO appeals (id, account_id, message, created_at) VALUES ($1, $2, $3, $4)',
      [crypto.randomUUID(), account.id, body.data!.message, now],
    );
    await audit(db, account.id, 'appeal', now);
    return reply.code(202).send({ state: 'open', created_at: now.toISOString() });
  });
}
