import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { fail, noContent, requireAccount, requireDatingAccess, type Services } from '../context.js';
import type { Db } from '../db.js';
import { messageRules, normalizeMessage } from '../rules.js';

const uuid = z.string().uuid();
const sendBody = z.object({ text: z.string().max(5000) }).strict();
const pageQuery = z.object({
  before: z.string().datetime().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
});

interface MatchRow {
  id: string;
  peer: string;
  status: 'active' | 'unmatched' | 'blocked';
}

/**
 * Finds a match only if the caller is a participant. A match the caller is not
 * in is indistinguishable from one that does not exist.
 */
async function participantMatch(db: Db, me: string, rawId: string): Promise<MatchRow> {
  const id = uuid.safeParse(rawId);
  if (!id.success) return fail(404, 'not_found');
  const [match] = await db.query<MatchRow>(
    `SELECT id, status,
            CASE WHEN account_low = $2 THEN account_high ELSE account_low END AS peer
     FROM matches WHERE id = $1 AND (account_low = $2 OR account_high = $2)`,
    [id.data, me],
  );
  return match ?? fail(404, 'not_found');
}

/** Active match and no block either way, checked at the moment of use. */
async function openConversation(db: Db, me: string, rawId: string): Promise<MatchRow> {
  const match = await participantMatch(db, me, rawId);
  const blocked = await db.query(
    `SELECT 1 FROM blocks WHERE (blocker = $1 AND blocked = $2) OR (blocker = $2 AND blocked = $1)`,
    [me, match.peer],
  );
  if (match.status !== 'active' || blocked.length > 0) fail(409, 'conversation_closed');
  return match;
}

export function chatRoutes(app: FastifyInstance, services: Services) {
  const { db, clock } = services;

  app.get('/v1/matches', async (request) => {
    const me = requireDatingAccess(request);
    const matches = await db.query(
      `SELECT m.id AS match_id, m.created_at, p.display_name AS peer_name, p.public_age AS peer_age,
              (SELECT body FROM messages WHERE match_id = m.id ORDER BY created_at DESC LIMIT 1)
                AS last_message
       FROM matches m
       JOIN profiles p ON p.account_id =
            CASE WHEN m.account_low = $1 THEN m.account_high ELSE m.account_low END
       WHERE (m.account_low = $1 OR m.account_high = $1) AND m.status = 'active'
         AND NOT EXISTS (SELECT 1 FROM blocks b WHERE
               (b.blocker = m.account_low AND b.blocked = m.account_high)
            OR (b.blocker = m.account_high AND b.blocked = m.account_low))
       ORDER BY m.created_at DESC`,
      [me.id],
    );
    return { matches };
  });

  app.delete('/v1/matches/:matchId', async (request, reply) => {
    const me = requireAccount(request);
    const match = await participantMatch(db, me.id, (request.params as { matchId: string }).matchId);
    if (match.status === 'active') {
      await db.query("UPDATE matches SET status = 'unmatched' WHERE id = $1", [match.id]);
    }
    return noContent(reply);
  });

  app.get('/v1/matches/:matchId/messages', async (request) => {
    const me = requireDatingAccess(request);
    const match = await openConversation(
      db,
      me.id,
      (request.params as { matchId: string }).matchId,
    );
    const { before, limit } = pageQuery.parse(request.query);
    const rows = await db.query<{ id: string; author_id: string; body: string; created_at: Date }>(
      `SELECT id, author_id, body, created_at FROM messages
       WHERE match_id = $1 AND ($2::timestamptz IS NULL OR created_at < $2)
       ORDER BY created_at DESC LIMIT $3`,
      [match.id, before ?? null, limit],
    );
    return {
      messages: rows.reverse().map((m) => ({
        id: m.id,
        mine: m.author_id === me.id,
        text: m.body,
        sent_at: new Date(m.created_at).toISOString(),
      })),
    };
  });

  app.post('/v1/matches/:matchId/messages', async (request, reply) => {
    const me = requireDatingAccess(request);
    const body = sendBody.safeParse(request.body);
    if (!body.success) fail(400, 'invalid_request');
    const normalized = normalizeMessage(body.data!.text);
    if ('error' in normalized) return fail(422, normalized.error);
    const now = clock.now();
    return db.transaction(async (tx) => {
      const match = await openConversation(
        tx,
        me.id,
        (request.params as { matchId: string }).matchId,
      );
      const [recent] = await tx.query<{ count: number }>(
        `SELECT count(*)::int AS count FROM messages
         WHERE match_id = $1 AND author_id = $2 AND created_at > $3`,
        [match.id, me.id, new Date(now.getTime() - 60_000)],
      );
      if ((recent?.count ?? 0) >= messageRules.maxPerMinute) fail(429, 'slow_down');
      const id = crypto.randomUUID();
      await tx.query(
        'INSERT INTO messages (id, match_id, author_id, body, created_at) VALUES ($1, $2, $3, $4, $5)',
        [id, match.id, me.id, normalized.text, now],
      );
      return reply
        .code(201)
        .send({ id, mine: true, text: normalized.text, sent_at: now.toISOString() });
    });
  });
}
