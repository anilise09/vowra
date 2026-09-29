import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { fail, noContent, requireAccount, requireDatingAccess, type Services } from '../context.js';
import type { Db } from '../db.js';
import { messageRules, normalizeMessage } from '../rules.js';

const uuid = z.string().uuid();

/** One typing signal per person per conversation every few seconds. */
const typingEveryMs = 3000;
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
  // Someone who asked to be deleted, or was suspended, can no longer be contacted.
  const leaving = await db.query(
    "SELECT 1 FROM accounts WHERE id = $1 AND lifecycle IN ('deletion_scheduled','suspended')",
    [match.peer],
  );
  if (match.status !== 'active' || blocked.length > 0 || leaving.length > 0) {
    fail(409, 'conversation_closed');
  }
  return match;
}

/** Read receipts and typing flow only when both people share them. */
async function bothShare(db: Db, me: string, peer: string): Promise<boolean> {
  const rows = await db.query<{ n: number }>(
    'SELECT count(*)::int AS n FROM accounts WHERE id IN ($1, $2) AND share_read_receipts',
    [me, peer],
  );
  return rows[0]?.n === 2;
}

export function chatRoutes(app: FastifyInstance, services: Services) {
  const { db, clock } = services;
  const lastTyping = new Map<string, number>();

  app.get('/v1/matches', async (request) => {
    const me = requireDatingAccess(request, { allowPaused: true });
    const [mine] = await db.query<{ interests: string[] }>(
      'SELECT interests FROM profiles WHERE account_id = $1',
      [me.id],
    );
    const matches = await db.query<
      Record<string, unknown> & {
        last_message_mine: boolean | null;
        last_message_at: Date | null;
        peer_interests: string[];
      }
    >(
      `SELECT m.id AS match_id, m.created_at, p.account_id AS peer_account_id,
              p.display_name AS peer_name, p.public_age AS peer_age,
              p.interests AS peer_interests, p.prompts AS peer_prompts,
              p.demo_portrait AS peer_demo_portrait,
              last.body AS last_message, last.author_id = $1 AS last_message_mine,
              last.created_at AS last_message_at,
              (SELECT count(*)::int FROM messages u
                WHERE u.match_id = m.id AND u.author_id <> $1
                  AND u.created_at > COALESCE(
                    (SELECT read_at FROM match_reads r WHERE r.match_id = m.id AND r.account_id = $1),
                    '-infinity'::timestamptz)) AS unread
       FROM matches m
       LEFT JOIN LATERAL (SELECT body, author_id, created_at FROM messages
                          WHERE match_id = m.id ORDER BY created_at DESC LIMIT 1) last ON true
       JOIN profiles p ON p.account_id =
            CASE WHEN m.account_low = $1 THEN m.account_high ELSE m.account_low END
       JOIN accounts peer ON peer.id = p.account_id
            AND peer.lifecycle NOT IN ('deletion_scheduled','suspended')
       WHERE (m.account_low = $1 OR m.account_high = $1) AND m.status = 'active'
         AND NOT EXISTS (SELECT 1 FROM blocks b WHERE
               (b.blocker = m.account_low AND b.blocked = m.account_high)
            OR (b.blocker = m.account_high AND b.blocked = m.account_low))
       ORDER BY COALESCE(last.created_at, m.created_at) DESC`,
      [me.id],
    );
    return {
      // Shared interests and their prompts let the app suggest a first line.
      matches: matches.map(({ peer_interests, ...m }) => ({
        ...m,
        shared_interests: peer_interests.filter((i) => mine?.interests.includes(i)).sort(),
        last_message_mine: m.last_message_mine ?? null,
        last_message_at: m.last_message_at ? new Date(m.last_message_at).toISOString() : null,
      })),
    };
  });

  app.delete('/v1/matches/:matchId', async (request, reply) => {
    const me = requireAccount(request);
    const match = await participantMatch(db, me.id, (request.params as { matchId: string }).matchId);
    if (match.status === 'active') {
      await db.query("UPDATE matches SET status = 'unmatched' WHERE id = $1", [match.id]);
      services.nudges.publish(me.id, { kind: 'match', match_id: match.id });
      services.nudges.publish(match.peer, { kind: 'match', match_id: match.id });
    }
    return noContent(reply);
  });

  app.get('/v1/matches/:matchId/messages', async (request) => {
    const me = requireDatingAccess(request, { allowPaused: true });
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
    // "Seen" appears on your messages only when both of you share receipts.
    const [peerRead] = (await bothShare(db, me.id, match.peer))
      ? await db.query<{ read_at: Date }>(
          'SELECT read_at FROM match_reads WHERE match_id = $1 AND account_id = $2',
          [match.id, match.peer],
        )
      : [];
    const seenUntil = peerRead ? new Date(peerRead.read_at).getTime() : null;
    return {
      messages: rows.reverse().map((m) => {
        const mine = m.author_id === me.id;
        return {
          id: m.id,
          mine,
          text: m.body,
          sent_at: new Date(m.created_at).toISOString(),
          ...(mine && seenUntil !== null
            ? { seen: new Date(m.created_at).getTime() <= seenUntil }
            : {}),
        };
      }),
    };
  });

  /** Marks the conversation read up to now. */
  app.post('/v1/matches/:matchId/read', async (request, reply) => {
    const me = requireDatingAccess(request, { allowPaused: true });
    const match = await openConversation(
      db,
      me.id,
      (request.params as { matchId: string }).matchId,
    );
    await db.query(
      `INSERT INTO match_reads (match_id, account_id, read_at) VALUES ($1, $2, $3)
       ON CONFLICT (match_id, account_id) DO UPDATE SET read_at = GREATEST(match_reads.read_at, $3)`,
      [match.id, me.id, clock.now()],
    );
    // Your other devices clear their badge; the other person hears only if
    // you both share receipts.
    services.nudges.publish(me.id, { kind: 'read', match_id: match.id });
    if (await bothShare(db, me.id, match.peer)) {
      services.nudges.publish(match.peer, { kind: 'read', match_id: match.id });
    }
    return noContent(reply);
  });

  /** A content-free "typing" signal, delivered only when both share. */
  app.post('/v1/matches/:matchId/typing', async (request, reply) => {
    const me = requireDatingAccess(request, { allowPaused: true });
    const match = await openConversation(
      db,
      me.id,
      (request.params as { matchId: string }).matchId,
    );
    const key = `${me.id}:${match.id}`;
    const now = clock.now().getTime();
    if (now - (lastTyping.get(key) ?? 0) >= typingEveryMs) {
      lastTyping.set(key, now);
      if (await bothShare(db, me.id, match.peer)) {
        services.nudges.publish(match.peer, { kind: 'typing', match_id: match.id });
      }
    }
    // The same answer either way: it never reveals the other person's setting.
    return noContent(reply);
  });

  app.post('/v1/matches/:matchId/messages', async (request, reply) => {
    const me = requireDatingAccess(request, { allowPaused: true });
    const body = sendBody.safeParse(request.body);
    if (!body.success) fail(400, 'invalid_request');
    const normalized = normalizeMessage(body.data!.text);
    if ('error' in normalized) return fail(422, normalized.error);
    const now = clock.now();
    const sent = await db.transaction(async (tx) => {
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
      return { id, match, text: normalized.text };
    });
    // The other person and this person's other devices.
    services.nudges.publish(sent.match.peer, { kind: 'message', match_id: sent.match.id });
    services.nudges.publish(me.id, { kind: 'message', match_id: sent.match.id });
    return reply
      .code(201)
      .send({ id: sent.id, mine: true, text: sent.text, sent_at: now.toISOString() });
  });
}
