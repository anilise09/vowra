import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { fail, requireDatingAccess, type Services } from '../context.js';
import type { Db } from '../db.js';
import { abuseRules, swipeRules } from '../rules.js';
import { compatibility, type CompatibilityProfile } from '../compatibility.js';
import { type Cell, distanceBand, distanceKm } from '../location.js';
import { openCell } from './location.js';
import { photosFor } from './media.js';

/** How many eligible people are ranked for one page of Discover. */
const candidatePool = 300;

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
  AND EXISTS (SELECT 1 FROM profiles elig_me, profiles elig_them
              WHERE elig_me.account_id = ${me} AND elig_them.account_id = ${other}
                AND (cardinality(elig_me.show_me) = 0 OR elig_them.gender = ANY(elig_me.show_me))
                AND (cardinality(elig_them.show_me) = 0 OR elig_me.gender = ANY(elig_them.show_me)))
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

  const myCell = async (me: string) => {
    const [row] = await db.query<{ location_sealed: string | null }>(
      'SELECT location_sealed FROM profiles WHERE account_id = $1',
      [me],
    );
    return openCell(services, row?.location_sealed ?? null);
  };

  /**
   * Replaces the sealed area with a coarse band. A band needs both areas and
   * the other person's "show a coarse distance band" setting.
   */
  const withBand = <T extends { location_sealed?: string | null; show_distance_band?: boolean }>(
    mine: Cell | null,
    person: T,
  ) => {
    const { location_sealed, show_distance_band, ...rest } = person;
    const theirs = show_distance_band ? openCell(services, location_sealed ?? null) : null;
    return {
      ...rest,
      distance_band: mine && theirs ? distanceBand(distanceKm(mine, theirs)) : null,
    };
  };

  app.get('/v1/discovery', async (request) => {
    const me = requireDatingAccess(request);
    await requireProfile(db, me.id);
    const { limit } = listQuery.parse(request.query);
    const [mine] = await db.query<CompatibilityProfile>(
      'SELECT relationship_intent, interests, lifestyle FROM profiles WHERE account_id = $1',
      [me.id],
    );
    const candidates = await db.query<
      CompatibilityProfile & {
        account_id: string;
        location_sealed: string | null;
        show_distance_band: boolean;
      }
    >(
      `SELECT a.id AS account_id, p.display_name, p.public_age, p.relationship_intent,
              p.bio, p.interests, p.lifestyle, p.prompts, p.demo_portrait,
              CASE WHEN p.show_gender THEN p.gender END AS gender,
              p.location_sealed, p.show_distance_band
       FROM accounts a JOIN profiles p ON p.account_id = a.id
       WHERE ${mutuallyEligible('$1::uuid', 'a.id')}
         AND NOT EXISTS (SELECT 1 FROM swipes s WHERE s.from_account = $1 AND s.to_account = a.id)
       ORDER BY a.created_at
       LIMIT $2`,
      [me.id, candidatePool],
    );
    const mineCell = await myCell(me.id);
    // Ranked by visible compatibility only; ties keep the oldest account first.
    const ranked = candidates
      .map((person, order) => ({ person, order, fit: compatibility(mine!, person) }))
      .sort((x, y) => y.fit.score - x.fit.score || x.order - y.order)
      .slice(0, limit);
    const photos = await photosFor(services, me.id, ranked.map((r) => r.person.account_id));
    const people = ranked.map(({ person, fit }) => ({
      ...withBand(mineCell, person),
      reasons: fit.reasons,
      photos: photos.get(person.account_id) ?? [],
    }));
    return { people };
  });

  app.post('/v1/discovery/:accountId/swipe', async (request) => {
    const result = await swipe(request);
    const me = request.account!.id;
    const other = (request.params as { accountId: string }).accountId;
    if (result.matched) {
      services.nudges.publish(me, { kind: 'match', match_id: result.match_id });
      services.nudges.publish(other, { kind: 'match', match_id: result.match_id });
      services.notifier.notify(other, 'match', { match_id: result.match_id! });
    } else if (result.liked) {
      services.nudges.publish(other, { kind: 'like' });
      services.notifier.notify(other, 'like');
    }
    return result.matched
      ? { matched: true, match_id: result.match_id }
      : { matched: false };
  });

  async function swipe(
    request: FastifyRequest,
  ): Promise<{ matched: boolean; match_id?: string; liked?: boolean }> {
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
      if (kind !== 'pass') {
        const [likes] = await tx.query<{ count: number }>(
          `SELECT count(*)::int AS count FROM swipes
           WHERE from_account = $1 AND kind IN ('like','super_like') AND created_at > $2
             AND to_account <> $3`,
          [me.id, new Date(now.getTime() - 24 * 60 * 60_000), other],
        );
        if ((likes?.count ?? 0) >= abuseRules.likesPerDay) fail(429, 'like_limit');
      }
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
      const fresh = await tx.query(
        `INSERT INTO swipes (from_account, to_account, kind, created_at) VALUES ($1, $2, $3, $4)
         ON CONFLICT (from_account, to_account) DO NOTHING RETURNING 1`,
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
      if (!liked(mine?.kind) || !liked(theirs?.kind)) {
        // A new like is news for them; a repeated or pass decision is not.
        return { matched: false, liked: fresh.length > 0 && liked(mine?.kind) };
      }
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
  }

  /** People who liked me and whom I have not answered. Free in Vawra. */
  app.get('/v1/likes-you', async (request) => {
    const me = requireDatingAccess(request);
    const rows = await db.query<{
      account_id: string;
      location_sealed: string | null;
      show_distance_band: boolean;
    }>(
      `SELECT a.id AS account_id, p.display_name, p.public_age, p.relationship_intent, p.bio,
              p.interests, p.lifestyle, p.prompts, p.demo_portrait,
              CASE WHEN p.show_gender THEN p.gender END AS gender,
              p.location_sealed, p.show_distance_band,
              s.kind = 'super_like' AS super_like
       FROM swipes s JOIN accounts a ON a.id = s.from_account JOIN profiles p ON p.account_id = a.id
       WHERE s.to_account = $1 AND s.kind IN ('like','super_like')
         AND ${mutuallyEligible('$1::uuid', 'a.id')}
         AND NOT EXISTS (SELECT 1 FROM swipes mine WHERE mine.from_account = $1 AND mine.to_account = a.id)
       ORDER BY s.created_at DESC`,
      [me.id],
    );
    const mineCell = await myCell(me.id);
    const photos = await photosFor(services, me.id, rows.map((r) => r.account_id));
    return {
      people: rows.map((person) => ({
        ...withBand(mineCell, person),
        photos: photos.get(person.account_id) ?? [],
      })),
    };
  });
}
