import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { fail, noContent, requireAccount, type Services } from '../context.js';

const deviceBody = z
  .object({
    platform: z.enum(['android', 'ios']),
    // FCM tokens are about 160 characters, APNs tokens 64 hex; allow room, not abuse.
    token: z.string().min(32).max(4096).regex(/^[\w:.\-]+$/),
  })
  .strict();

const prefsBody = z
  .object({
    matches: z.boolean(),
    messages: z.boolean(),
    likes: z.boolean(),
    calls: z.boolean(),
  })
  .partial()
  .strict();

const uuid = z.string().uuid();
/** A phone or two plus a tablet, per sign-in chain there is only ever one. */
const maxDevicesPerAccount = 10;

export function deviceRoutes(app: FastifyInstance, services: Services) {
  const { db, sealer, clock } = services;

  /**
   * Registers this phone for push. The token belongs to the current sign-in:
   * signing out, suspension or deletion ends it. The same token registering
   * again (a new sign-in, or another account on a shared phone) moves it.
   */
  app.post('/v1/me/devices', async (request) => {
    const me = requireAccount(request);
    const body = deviceBody.safeParse(request.body);
    if (!body.success) fail(400, 'invalid_request');
    const { platform, token } = body.data!;
    const now = clock.now();
    const lookup = sealer.lookup(`push:${token}`);
    const id = await db.transaction(async (tx) => {
      await tx.query('DELETE FROM devices WHERE token_lookup = $1', [lookup]);
      // One device per sign-in chain: a refreshed token replaces the old one.
      await tx.query('DELETE FROM devices WHERE family_id = $1', [me.familyId]);
      const [count] = await tx.query<{ n: number }>('SELECT count(*)::int AS n FROM devices WHERE account_id = $1', [
        me.id,
      ]);
      if ((count?.n ?? 0) >= maxDevicesPerAccount) {
        // The longest-unused device makes room.
        await tx.query(
          `DELETE FROM devices WHERE id = (SELECT id FROM devices WHERE account_id = $1
           ORDER BY last_seen_at LIMIT 1)`,
          [me.id],
        );
      }
      const deviceId = crypto.randomUUID();
      await tx.query(
        `INSERT INTO devices (id, account_id, family_id, platform, token_sealed, token_lookup, created_at, last_seen_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $7)`,
        [deviceId, me.id, me.familyId, platform, sealer.seal(token), lookup, now],
      );
      return deviceId;
    });
    return { device_id: id };
  });

  app.delete('/v1/me/devices/:id', async (request, reply) => {
    const me = requireAccount(request);
    const id = uuid.safeParse((request.params as { id: string }).id);
    if (!id.success) fail(404, 'not_found');
    await db.query('DELETE FROM devices WHERE id = $1 AND account_id = $2', [id.data, me.id]);
    return noContent(reply);
  });

  app.get('/v1/me/notifications', async (request) => {
    const me = requireAccount(request);
    const [row] = await db.query<{ matches: boolean; messages: boolean; likes: boolean; calls: boolean }>(
      'SELECT matches, messages, likes, calls FROM notification_prefs WHERE account_id = $1',
      [me.id],
    );
    return row ?? { matches: true, messages: true, likes: true, calls: true };
  });

  app.put('/v1/me/notifications', async (request) => {
    const me = requireAccount(request);
    const body = prefsBody.safeParse(request.body);
    if (!body.success || Object.keys(body.data!).length === 0) fail(400, 'invalid_request');
    const next = { matches: true, messages: true, likes: true, calls: true };
    const [row] = await db.query<typeof next>(
      'SELECT matches, messages, likes, calls FROM notification_prefs WHERE account_id = $1',
      [me.id],
    );
    Object.assign(next, row ?? {}, body.data);
    await db.query(
      `INSERT INTO notification_prefs (account_id, matches, messages, likes, calls, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (account_id) DO UPDATE SET matches = $2, messages = $3, likes = $4, calls = $5, updated_at = $6`,
      [me.id, next.matches, next.messages, next.likes, next.calls, clock.now()],
    );
    return next;
  });
}
