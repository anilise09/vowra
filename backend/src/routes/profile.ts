import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { audit, fail, noContent, requireAccount, type Services } from '../context.js';
import { intents, interests, validateBio, validateName } from '../rules.js';

/** The only fields a client may change. Age, location, verification, etc. are absent. */
const profilePatch = z
  .object({
    display_name: z.string().max(200),
    relationship_intent: z.enum(intents),
    bio: z.string().max(2000),
    interests: z.array(z.enum(interests)).max(interests.length),
    show_distance_band: z.boolean(),
    call_ready_by_default: z.boolean(),
  })
  .partial()
  .strict();

interface ProfileRow {
  display_name: string;
  relationship_intent: string;
  bio: string;
  interests: string[];
  show_distance_band: boolean;
  call_ready_by_default: boolean;
  public_age: number | null;
}

export function profileRoutes(app: FastifyInstance, services: Services) {
  const { db, clock } = services;

  const load = async (accountId: string) =>
    (
      await db.query<ProfileRow>(
        `SELECT display_name, relationship_intent, bio, interests, show_distance_band,
                call_ready_by_default, public_age
         FROM profiles WHERE account_id = $1`,
        [accountId],
      )
    )[0] ?? null;

  app.get('/v1/me/profile', async (request) => {
    const account = requireAccount(request);
    const [row] = await db.query<{ deletion_effective_at: Date | null }>(
      'SELECT deletion_effective_at FROM accounts WHERE id = $1',
      [account.id],
    );
    return {
      age_state: account.ageState,
      lifecycle: account.lifecycle,
      deletion_effective_at: row?.deletion_effective_at
        ? new Date(row.deletion_effective_at).toISOString()
        : null,
      profile: await load(account.id),
    };
  });

  app.patch('/v1/me/profile', async (request) => {
    const account = requireAccount(request);
    const parsed = profilePatch.safeParse(request.body);
    if (!parsed.success) {
      const unknownField = parsed.error.issues.some((i) => i.code === 'unrecognized_keys');
      fail(400, unknownField ? 'unknown_field' : 'invalid_request');
    }
    const patch = parsed.data!;
    if (patch.display_name !== undefined) {
      const problem = validateName(patch.display_name);
      if (problem) fail(422, problem);
      patch.display_name = patch.display_name.trim();
    }
    if (patch.bio !== undefined) {
      const problem = validateBio(patch.bio);
      if (problem) fail(422, problem);
      patch.bio = patch.bio.trim();
    }
    if (patch.interests) patch.interests = [...new Set(patch.interests)].sort();

    const existing = await load(account.id);
    const now = clock.now();
    if (!existing) {
      if (!patch.display_name || !patch.relationship_intent) fail(422, 'profile_incomplete');
      await db.query(
        `INSERT INTO profiles (account_id, display_name, relationship_intent, bio, interests,
                               show_distance_band, call_ready_by_default, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [
          account.id,
          patch.display_name,
          patch.relationship_intent,
          patch.bio ?? '',
          patch.interests ?? [],
          patch.show_distance_band ?? true,
          patch.call_ready_by_default ?? false,
          now,
        ],
      );
    } else {
      const merged = { ...existing, ...patch };
      await db.query(
        `UPDATE profiles SET display_name = $2, relationship_intent = $3, bio = $4,
                interests = $5, show_distance_band = $6, call_ready_by_default = $7,
                updated_at = $8
         WHERE account_id = $1`,
        [
          account.id,
          merged.display_name,
          merged.relationship_intent,
          merged.bio,
          merged.interests,
          merged.show_distance_band,
          merged.call_ready_by_default,
          now,
        ],
      );
    }
    return { profile: await load(account.id) };
  });

  // Pause is free and always reachable; resume repeats the eligibility checks.
  app.post('/v1/me/pause', async (request, reply) => {
    const account = requireAccount(request);
    if (account.lifecycle === 'deletion_scheduled') fail(409, 'deletion_scheduled');
    await db.query("UPDATE accounts SET lifecycle = 'paused' WHERE id = $1 AND lifecycle = 'active'", [
      account.id,
    ]);
    await audit(db, account.id, 'paused', clock.now());
    return noContent(reply);
  });

  app.delete('/v1/me/pause', async (request, reply) => {
    const account = requireAccount(request);
    if (account.ageState !== 'adult_verified') fail(403, 'age_assurance_required');
    // Resuming never undoes a scheduled deletion; only DELETE /v1/me/deletion does.
    if (account.lifecycle === 'deletion_scheduled') fail(409, 'deletion_scheduled');
    await db.query("UPDATE accounts SET lifecycle = 'active' WHERE id = $1 AND lifecycle = 'paused'", [
      account.id,
    ]);
    await audit(db, account.id, 'resumed', clock.now());
    return noContent(reply);
  });
}
