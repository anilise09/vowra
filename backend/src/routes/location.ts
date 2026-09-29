import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { fail, noContent, requireAccount, type Services } from '../context.js';
import {
  type Cell,
  cellKm,
  distanceKm,
  maxSpeedKmh,
  moveIntervalSeconds,
  snapToCell,
} from '../location.js';

const areaBody = z
  .object({
    lat: z.number().finite().min(-90).max(90),
    lng: z.number().finite().min(-180).max(180),
  })
  .strict();

export function openCell(services: Services, sealed: string | null): Cell | null {
  return sealed ? (JSON.parse(services.sealer.open(sealed)) as Cell) : null;
}

export function locationRoutes(app: FastifyInstance, services: Services) {
  const { db, clock } = services;

  /**
   * Sets the approximate area. The app sends a cell centre already; the
   * server rounds again, so even an exact point is never stored.
   */
  app.put('/v1/me/location', async (request) => {
    const account = requireAccount(request);
    const body = areaBody.safeParse(request.body);
    if (!body.success) fail(400, 'invalid_request');
    const cell = snapToCell(body.data!.lat, body.data!.lng);
    const [row] = await db.query<{ location_sealed: string | null; location_updated_at: Date | null }>(
      'SELECT location_sealed, location_updated_at FROM profiles WHERE account_id = $1',
      [account.id],
    );
    if (!row) fail(409, 'profile_incomplete');
    const now = clock.now();
    const previous = openCell(services, row!.location_sealed);
    if (previous && row!.location_updated_at) {
      const km = distanceKm(previous, cell);
      const seconds = (now.getTime() - new Date(row!.location_updated_at).getTime()) / 1000;
      if (km > 0 && seconds < moveIntervalSeconds) fail(429, 'slow_down');
      if (km / Math.max(seconds / 3600, 1 / 60) > maxSpeedKmh) fail(422, 'implausible_move');
    }
    await db.query(
      'UPDATE profiles SET location_sealed = $2, location_updated_at = $3 WHERE account_id = $1',
      [account.id, services.sealer.seal(JSON.stringify(cell)), now],
    );
    return { updated_at: now.toISOString(), cell_km: cellKm };
  });

  app.delete('/v1/me/location', async (request, reply) => {
    const account = requireAccount(request);
    await db.query(
      'UPDATE profiles SET location_sealed = NULL, location_updated_at = NULL WHERE account_id = $1',
      [account.id],
    );
    return noContent(reply);
  });
}
