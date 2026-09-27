import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { fail, requireDatingAccess, type Services } from '../context.js';
import type { Db } from '../db.js';
import { swipeRules } from '../rules.js';

const uuid = z.string().uuid();
const swipeBody = z.object({ kind: z.enum(['like', 'super_like', 'pass']) }).strict();
const listQuery = z.object({ limit: z.coerce.number().int().min(1).max(50).default(20) });

/**
 * The only definition of "can these two see each other": both adult-verified,
 * both active, both with a profile, and no block in either direction.
 */
export const mutuallyEligible = (me: string, other: string) => `
  ${other} <> ${me}
  AND EXISTS (SELECT 1 FROM accounts elig_a JOIN profiles elig_p ON elig_p.account_id = elig_a.id
              WHERE elig_a.id = ${other} AND elig_a.age_state = 'adult_verified'
                AND elig_a.lifecycle = 'active')
  AND NOT EXISTS (SELECT 1 FROM blocks elig_b
                  WHERE (elig_b.blocker = ${me} AND elig_b.blocked = ${other})
                     OR (elig_b.blocker = ${other} AND elig_b.blocked = ${me}))`;
// Aliases are prefixed elig_ so they never shadow the caller's own aliases
// (an earlier "a" alias made "a.id = a.id" always true and leaked paused and
// unverified people into discovery).

export async function isEligible(db: Db, me: string, other: string): Promise<boolean> {
  const rows = await db.query(`SELECT 1 WHERE ${mutuallyEligible('$1::uuid', '$2::uuid')}`, [
    me,
    other,
  ]);
  return rows.length > 0;
}

/** You need your own profile before you can see or be seen. */
async function requireProfile(db: Db, me: string) {
  const rows = await db.query('SELECT 1 FROM profiles WHERE account_id = $1', [me]);
  if (rows.length === 0) fail(409, 'profile_incomplete');
}

export function discoveryRoutes(app: FastifyInstance, services: Services) {
  const { db, clock } = services;

  app.get('/v1/discovery', async (request) => {
    const me = requireDatingAccess(request);
    await requireProfile(db, me.id);
    const { limit } = listQuery.parse(request.query);
    const people = await db.query(
      `SELECT a.id AS account_id, p.display_name, p.public_age, p.relationship_intent,
              p.bio, p.interests, p.lifestyle, p.prompts
       FROM accounts a JOIN profiles p ON p.account_id = a.id
       WHERE ${mutuallyEligible('$1::uuid', 'a.id')}
         AND NOT EXISTS (SELECT 1 FROM swipes s WHERE s.from_account = $1 AND s.to_account = a.id)
       ORDER BY a.created_at
       LIMIT $2`,
      [me.id, limit],
    );
    // Distance stays null until the reviewed location service exists.
    return { people: people.map((p) => ({ ...p, distance_band: null })) };
  });

  app.post('/v1/discovery/:accountId/swipe', async (request) => {
    const me = requireDatingAccess(request);
    await requireProfile(db, me.id);
    const target = uuid.safeParse((request.params as { accountId: string }).accountId);
    const body = swipeBody.safeParse(request.body);
    if (!body.success) fail(400, 'invalid_request');
    // Unknown, ineligible and blocked targets all look the same.
    if (!target.success || !(await isEligible(db, me.id, target.data))) fail(404, 'not_found');
    const other = target.data!;
    const now = clock.now();
    const kind = body.data!.kind;
    return db.transaction(async (tx) => {
      if (kind === 'super_like') {
        // A repeat of an existing decision is idempotent and does not count.
        const [spent] = await tx.query<{ count: number }>(
          `SELECT count(*)::int AS count FROM swipes
           WHERE from_account = $1 AND kind = 'super_like' AND created_at > $2
             AND to_account <> $3`,
          [me.id, new Date(now.getTime() - 24 * 60 * 60_000), other],
        );
        if ((spent?.count ?? 0) >= swipeRules.superLikesPerDay) fail(429, 'super_like_limit');
      }
      // Idempotent: the first decision stands.
      await tx.query(
        `INSERT INTO swipes (from_account, to_account, kind, created_at) VALUES ($1, $2, $3, $4)
         ON CONFLICT (from_account, to_account) DO NOTHING`,
        [me.id, other, kind, now],
      );
      const [mine] = await tx.query<{ kind: string }>(
        'SELECT kind FROM swipes WHERE from_account = $1 AND to_account = $2',
        [me.id, other],
      );
      const [theirs] = await tx.query<{ kind: string }>(
        'SELECT kind FROM swipes WHERE from_account = $1 AND to_account = $2',
        [other, me.id],
      );
      const liked = (kind?: string) => kind === 'like' || kind === 'super_like';
      if (!liked(mine?.kind) || !liked(theirs?.kind)) return { matched: false };
      const [low, high] = me.id < other ? [me.id, other] : [other, me.id];
      await tx.query(
        `INSERT INTO matches (id, account_low, account_high, created_at) VALUES ($1, $2, $3, $4)
         ON CONFLICT (account_low, account_high) DO NOTHING`,
        [crypto.randomUUID(), low, high, now],
      );
      const [match] = await tx.query<{ id: string; status: string }>(
        'SELECT id, status FROM matches WHERE account_low = $1 AND account_high = $2',
        [low, high],
      );
      return match?.status === 'active' ? { matched: true, match_id: match.id } : { matched: false };
    });
  });

  /** People who liked me and whom I have not answered. Free in Vawra. */
  app.get('/v1/likes-you', async (request) => {
    const me = requireDatingAccess(request);
    const people = await db.query(
      `SELECT a.id AS account_id, p.display_name, p.public_age, p.relationship_intent, p.bio,
              p.interests, p.lifestyle, p.prompts, s.kind = 'super_like' AS super_like
       FROM swipes s JOIN accounts a ON a.id = s.from_account JOIN profiles p ON p.account_id = a.id
       WHERE s.to_account = $1 AND s.kind IN ('like','super_like')
         AND ${mutuallyEligible('$1::uuid', 'a.id')}
         AND NOT EXISTS (SELECT 1 FROM swipes mine WHERE mine.from_account = $1 AND mine.to_account = a.id)
       ORDER BY s.created_at DESC`,
      [me.id],
    );
    return { people };
  });
}
