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
  // Open streams end when the server closes, so shutting down never waits on them;
  // each app reconnects to another server.
  const open = new Set<() => void>();
  app.addHook('preClose', async () => {
    for (const end of [...open]) end();
  });

  app.get('/v1/events', async (request, reply) => {
    const me = requireDatingAccess(request, { allowPaused: true });
    if (services.nudges.listeners(me.id) >= maxStreamsPerAccount) fail(429, 'too_many_streams');
    // Shared with every server, so a push is not sent to someone who has the app open.
    const presence = await services.presence.track(me.id);

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
    const heartbeat = setInterval(() => {
      res.write(': ping\n\n');
      presence.beat().catch(() => {});
    }, heartbeatMs);
    const untilExpiry = Math.max(0, me.accessExpiresAt.getTime() - services.clock.now().getTime());
    const expiry = setTimeout(() => res.end(), untilExpiry);

    let closed = false;
    const close = () => {
      if (closed) return;
      closed = true;
      clearInterval(heartbeat);
      clearTimeout(expiry);
      unsubscribe();
      open.delete(end);
      presence.end().catch(() => {});
    };
    const end = () => {
      close();
      res.end();
    };
    open.add(end);
    request.raw.on('close', close);
    res.on('close', close);
  });
}
