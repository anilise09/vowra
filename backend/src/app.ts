import Fastify, { type FastifyInstance } from 'fastify';
import { hashToken } from './crypto.js';
import { ApiError, type Account, type Services } from './context.js';
import { authRoutes } from './routes/auth.js';
import { chatRoutes } from './routes/chat.js';
import { discoveryRoutes } from './routes/discovery.js';
import { lifecycleRoutes } from './routes/lifecycle.js';
import { profileRoutes } from './routes/profile.js';
import { safetyRoutes } from './routes/safety.js';

export function buildApp(services: Services, options: { logger?: boolean } = {}): FastifyInstance {
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

  app.addHook('onRequest', async (request) => {
    const header = request.headers.authorization;
    if (!header?.startsWith('Bearer ')) return;
    const [row] = await services.db.query<{
      id: string;
      session_id: string;
      family_id: string;
      age_state: Account['ageState'];
      lifecycle: Account['lifecycle'];
    }>(
      `SELECT a.id, s.id AS session_id, s.family_id, a.age_state, a.lifecycle
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
        ageState: row.age_state,
        lifecycle: row.lifecycle,
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

  app.get('/v1/health', async () => ({ ok: true }));
  authRoutes(app, services);
  profileRoutes(app, services);
  discoveryRoutes(app, services);
  chatRoutes(app, services);
  safetyRoutes(app, services);
  lifecycleRoutes(app, services);
  return app;
}
