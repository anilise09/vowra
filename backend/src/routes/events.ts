import type { FastifyInstance } from 'fastify';
import { fail, requireDatingAccess, type Services } from '../context.js';

/** Open streams per account: a phone or two plus a tablet, not a flood. */
export const maxStreamsPerAccount = 5;
const heartbeatMs = 25_000;

/**
 * GET /v1/events: a Server-Sent Events stream of nudges for the signed-in
 * account. It closes when the access token expires, so a stream never outlives
 * its session; the app reconnects with a fresh token.
 */
export function eventRoutes(app: FastifyInstance, services: Services) {
  app.get('/v1/events', async (request, reply) => {
    const me = requireDatingAccess(request, { allowPaused: true });
    if (services.nudges.listeners(me.id) >= maxStreamsPerAccount) fail(429, 'too_many_streams');

    reply.hijack();
    const res = reply.raw;
    res.writeHead(200, {
      'content-type': 'text/event-stream; charset=utf-8',
      'cache-control': 'no-store',
      connection: 'keep-alive',
      'x-accel-buffering': 'no',
    });
    res.write('retry: 5000\n: connected\n\n');

    const unsubscribe = services.nudges.subscribe(me.id, (nudge) => {
      res.write(`event: nudge\ndata: ${JSON.stringify(nudge)}\n\n`);
    });
    const heartbeat = setInterval(() => res.write(': ping\n\n'), heartbeatMs);
    const untilExpiry = Math.max(0, me.accessExpiresAt.getTime() - services.clock.now().getTime());
    const expiry = setTimeout(() => res.end(), untilExpiry);

    const close = () => {
      clearInterval(heartbeat);
      clearTimeout(expiry);
      unsubscribe();
    };
    request.raw.on('close', close);
    res.on('close', close);
  });
}
