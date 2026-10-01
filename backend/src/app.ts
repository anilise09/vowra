import Fastify, { type FastifyInstance } from 'fastify';
import { hashToken } from './crypto.js';
import { pendingMigrations } from './db.js';
import { ApiError, type Account, type Services } from './context.js';
import { authRoutes } from './routes/auth.js';
import { callRoutes } from './routes/calls.js';
import { deviceRoutes } from './routes/devices.js';
import { chatRoutes } from './routes/chat.js';
import { discoveryRoutes } from './routes/discovery.js';
import { eventRoutes } from './routes/events.js';
import { lifecycleRoutes } from './routes/lifecycle.js';
import { locationRoutes } from './routes/location.js';
import { mediaRoutes } from './routes/media.js';
import { moderationRoutes } from './routes/moderation.js';
import { profileRoutes } from './routes/profile.js';
import { safetyRoutes } from './routes/safety.js';
import { staffRoutes } from './routes/staff.js';

export interface AppOptions {
  logger?: boolean;
  /** True while the server is shutting down: readiness fails so traffic moves away. */
  isDraining?: () => boolean;
}

export function buildApp(services: Services, options: AppOptions = {}): FastifyInstance {
  const app = Fastify({
    genReqId: () => crypto.randomUUID(),
    bodyLimit: 64 * 1024,
    logger: options.logger
      ? {
          // Never log credentials, proofs or message/profile bodies.
          redact: ['req.headers.authorization', 'req.headers.cookie'],
          serializers: {
            req: (req) => ({ method: req.method, url: req.url.split('?')[0], id: req.id }),
          },
        }
      : false,
  });

  // Accept an empty body sent with a JSON content type (common in clients
  // for body-less POST/DELETE); anything else must be valid JSON.
  app.removeContentTypeParser('application/json');
  app.addContentTypeParser('application/json', { parseAs: 'string' }, (_request, body, done) => {
    const text = (body as string).trim();
    if (text === '') return done(null, undefined);
    try {
      done(null, JSON.parse(text));
    } catch {
      const error = new Error('invalid JSON') as Error & { statusCode: number };
      error.statusCode = 400;
      done(error, undefined);
    }
  });

  app.addHook('onRequest', async (request) => {
    const header = request.headers.authorization;
    if (!header?.startsWith('Bearer ')) return;
    const [row] = await services.db.query<{
      id: string;
      session_id: string;
      family_id: string;
      access_expires_at: Date;
      age_state: Account['ageState'];
      lifecycle: Account['lifecycle'];
      role: Account['role'];
    }>(
      `SELECT a.id, s.id AS session_id, s.family_id, s.access_expires_at, a.age_state, a.lifecycle,
              a.role
       FROM sessions s
       JOIN session_families f ON f.id = s.family_id
       JOIN accounts a ON a.id = s.account_id
       WHERE s.access_hash = $1 AND s.revoked_at IS NULL AND f.revoked_at IS NULL
         AND s.access_expires_at > $2`,
      [hashToken(header.slice(7)), services.clock.now()],
    );
    if (row) {
      request.account = {
        id: row.id,
        sessionId: row.session_id,
        familyId: row.family_id,
        accessExpiresAt: new Date(row.access_expires_at),
        ageState: row.age_state,
        lifecycle: row.lifecycle,
        role: row.role,
      };
    }
  });

  app.setErrorHandler((raw, request, reply) => {
    const error = raw as Error & { statusCode?: number };
    if (error instanceof ApiError) {
      return reply.code(error.status).send({ error: error.code, request_id: request.id });
    }
    const status = error.statusCode;
    if (status && status >= 400 && status < 500) {
      return reply.code(status).send({ error: 'invalid_request', request_id: request.id });
    }
    request.log.error({ err: { message: error.message, name: error.name } }, 'unhandled');
    return reply.code(500).send({ error: 'internal', request_id: request.id });
  });

  // Account data must never sit in a shared cache, and nothing is sniffed as another type.
  app.addHook('onSend', async (_request, reply) => {
    reply.header('x-content-type-options', 'nosniff');
    if (!reply.hasHeader('cache-control')) reply.header('cache-control', 'no-store');
  });

  // Liveness: the process answers. Readiness: it can serve traffic right now.
  app.get('/v1/health', async () => ({ ok: true }));
  app.get('/v1/ready', async (_request, reply) => {
    if (options.isDraining?.()) return reply.code(503).send({ ready: false, reason: 'shutting_down' });
    try {
      await services.db.query('SELECT 1');
      if ((await pendingMigrations(services.db)).length > 0) {
        return reply.code(503).send({ ready: false, reason: 'migrations_pending' });
      }
    } catch {
      return reply.code(503).send({ ready: false, reason: 'database' });
    }
    return { ready: true };
  });
  // First, so its second-factor check covers every moderation route below.
  staffRoutes(app, services);
  authRoutes(app, services);
  profileRoutes(app, services);
  discoveryRoutes(app, services);
  chatRoutes(app, services);
  safetyRoutes(app, services);
  lifecycleRoutes(app, services);
  locationRoutes(app, services);
  moderationRoutes(app, services);
  mediaRoutes(app, services);
  callRoutes(app, services);
  deviceRoutes(app, services);
  eventRoutes(app, services);
  return app;
}
